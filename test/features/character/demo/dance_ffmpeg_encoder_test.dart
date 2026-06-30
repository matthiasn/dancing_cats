import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dancing_cats/features/character/demo/dance_ffmpeg_encoder.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal in-memory [IOSink] that records what the encoder pipes to ffmpeg's
/// stdin, so [DanceFfmpegEncoder.writeFrame] / [DanceFfmpegEncoder.finish] can
/// be exercised without a real process. Only the members the encoder uses are
/// implemented.
class _FakeStdin implements IOSink {
  final BytesBuilder written = BytesBuilder();
  int flushCount = 0;
  bool closed = false;

  @override
  void add(List<int> data) => written.add(data);

  @override
  Future<void> flush() async => flushCount++;

  @override
  Future<void> close() async => closed = true;

  @override
  Future<void> get done => Future<void>.value();

  @override
  Encoding encoding = utf8;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Controllable fake [Process] — chooses the exit code, emits canned stderr, and
/// records whether it was killed.
class _FakeProcess implements Process {
  _FakeProcess({this.exit = 0, this.stderrText = ''});

  final int exit;
  final String stderrText;
  final _FakeStdin fakeStdin = _FakeStdin();
  bool killed = false;

  @override
  IOSink get stdin => fakeStdin;

  @override
  Stream<List<int>> get stdout => const Stream<List<int>>.empty();

  @override
  Stream<List<int>> get stderr => stderrText.isEmpty
      ? const Stream.empty()
      : Stream.value(utf8.encode(stderrText));

  @override
  Future<int> get exitCode async => exit;

  @override
  int get pid => 4242;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  group('DanceFfmpegEncoder.buildArgs', () {
    List<String> args({int fps = 30, String out = '/tmp/out.mp4'}) =>
        DanceFfmpegEncoder.buildArgs(
          width: 1920,
          height: 1080,
          fps: fps,
          startSec: 12.5,
          durationSec: 8.25,
          outputPath: out,
          audioPath: '/music/track.mp3',
          crf: 18,
          audioKbps: 256,
          x264Preset: 'slow',
        );

    test('encodes raw rgba in at the requested size and rate', () {
      final a = args();
      expect(a, containsAllInOrder(['-f', 'rawvideo']));
      expect(a, containsAllInOrder(['-pix_fmt', 'rgba']));
      expect(a, containsAllInOrder(['-s:v', '1920x1080']));
      expect(a, containsAllInOrder(['-framerate', '30']));
      expect(a, containsAllInOrder(['-i', 'pipe:0']));
    });

    test(
      'trims the muxed audio window to [startSec, startSec+durationSec]',
      () {
        final a = args();
        expect(a, containsAllInOrder(['-ss', '12.500000']));
        expect(a, containsAllInOrder(['-t', '8.250000']));
        expect(a, containsAllInOrder(['-i', '/music/track.mp3']));
        expect(a, contains('-shortest'));
      },
    );

    test('tags bt709 colour on all three axes', () {
      final a = args();
      expect(a, containsAllInOrder(['-colorspace', 'bt709']));
      expect(a, containsAllInOrder(['-color_primaries', 'bt709']));
      expect(a, containsAllInOrder(['-color_trc', 'bt709']));
    });

    test('carries the x264/aac knobs through', () {
      final a = args();
      expect(a, containsAllInOrder(['-c:v', 'libx264']));
      expect(a, containsAllInOrder(['-preset', 'slow']));
      expect(a, containsAllInOrder(['-crf', '18']));
      expect(a, containsAllInOrder(['-c:a', 'aac']));
      expect(a, containsAllInOrder(['-b:a', '256k']));
    });

    test('keyframe interval -g is half the fps, floored at 1', () {
      expect(args(), containsAllInOrder(['-g', '15']));
      expect(args(fps: 1), containsAllInOrder(['-g', '1']));
    });

    test('the output path is the final argument', () {
      expect(args(out: '/out/video.mp4').last, '/out/video.mp4');
    });
  });

  group('DanceFfmpegEncoder lifecycle', () {
    late Directory tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('enc_test'));
    tearDown(() => tmp.deleteSync(recursive: true));

    Future<DanceFfmpegEncoder> startWith(_FakeProcess proc, {String? out}) {
      String? seenExe;
      List<String>? seenArgs;
      return DanceFfmpegEncoder.start(
        width: 16,
        height: 16,
        fps: 24,
        startSec: 0,
        durationSec: 1,
        outputPath: out ?? '${tmp.path}/nested/clip.mp4',
        audioPath: '${tmp.path}/a.wav',
        crf: 20,
        audioKbps: 128,
        x264Preset: 'veryfast',
        executable: 'fake-ffmpeg',
        startProcess: (exe, a) async {
          seenExe = exe;
          seenArgs = a;
          expect(seenExe, 'fake-ffmpeg');
          expect(seenArgs, isNotEmpty);
          return proc;
        },
      );
    }

    test(
      'start creates the output parent dir and launches the process',
      () async {
        final proc = _FakeProcess();
        await startWith(proc);
        expect(Directory('${tmp.path}/nested').existsSync(), isTrue);
      },
    );

    test('writeFrame pipes the bytes to stdin and flushes', () async {
      final proc = _FakeProcess();
      final enc = await startWith(proc);
      await enc.writeFrame(Uint8List.fromList([1, 2, 3, 4]));
      await enc.writeFrame(Uint8List.fromList([5, 6]));
      expect(proc.fakeStdin.written.takeBytes(), [1, 2, 3, 4, 5, 6]);
      expect(proc.fakeStdin.flushCount, 2);
    });

    test('finish closes stdin and completes on a zero exit', () async {
      final proc = _FakeProcess();
      final enc = await startWith(proc);
      await enc.finish();
      expect(proc.fakeStdin.closed, isTrue);
    });

    test('finish throws with the captured stderr on a non-zero exit', () async {
      final proc = _FakeProcess(exit: 3, stderrText: 'boom: bad codec');
      final enc = await startWith(proc);
      await expectLater(
        enc.finish(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('exit 3'), contains('boom: bad codec')),
          ),
        ),
      );
    });

    test('kill is idempotent and signals the process once', () async {
      final proc = _FakeProcess();
      (await startWith(proc))
        ..kill()
        ..kill();
      expect(proc.killed, isTrue);
    });
  });
}
