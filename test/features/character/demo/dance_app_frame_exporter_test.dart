import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dancing_cats/features/character/demo/dance_app_frame_exporter.dart';
import 'package:dancing_cats/features/character/demo/dance_ffmpeg_encoder.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal in-memory stdin for the fake ffmpeg process.
class _FakeStdin implements IOSink {
  int frames = 0;
  bool closed = false;

  @override
  void add(List<int> data) => frames++;

  @override
  Future<void> flush() async {}

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

class _FakeProcess implements Process {
  _FakeProcess();

  final _FakeStdin fakeStdin = _FakeStdin();
  bool killed = false;

  @override
  IOSink get stdin => fakeStdin;

  @override
  Stream<List<int>> get stdout => const Stream<List<int>>.empty();

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  Future<int> get exitCode async => 0;

  @override
  int get pid => 7;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Future<DanceFfmpegEncoder> _startFake(_FakeProcess proc, Directory tmp) =>
    DanceFfmpegEncoder.start(
      width: 16,
      height: 16,
      fps: 4,
      startSec: 0,
      durationSec: 1,
      outputPath: '${tmp.path}/out.mp4',
      audioPath: '${tmp.path}/a.wav',
      crf: 20,
      audioKbps: 128,
      x264Preset: 'veryfast',
      startProcess: (exe, args) async => proc,
    );

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('exp_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test(
    'runs the render→capture→encode loop and finishes the encoder',
    () async {
      final proc = _FakeProcess();
      var ready = false;
      ({double start, double dt})? preroll;
      final rendered = <double>[];
      var captures = 0;
      final logs = <String>[];

      final exporter = DanceAppFrameExporter(
        waitReady: () async => ready = true,
        prerollClock: (start, dt) => preroll = (start: start, dt: dt),
        renderFrame: (pos, dt) async => rendered.add(pos),
        captureFrame: () async {
          captures++;
          return Uint8List.fromList([captures]);
        },
        startEncoder: () => _startFake(proc, tmp),
        log: logs.add,
      );

      // 0.5 s at 4 fps → 2 frames, dt 0.25, starting at 1.0.
      await exporter.run(start: 1, durationSec: 0.5, fps: 4);

      expect(ready, isTrue, reason: 'waits for readiness first');
      expect(preroll, (
        start: 1.0,
        dt: 0.25,
      ), reason: 'prerolls from the start');
      expect(rendered, [1.0, 1.25], reason: 'renders each frame position');
      expect(captures, 2);
      expect(
        proc.fakeStdin.frames,
        2,
        reason: 'pipes every frame to the encoder',
      );
      expect(proc.fakeStdin.closed, isTrue, reason: 'finishes (closes stdin)');
      expect(proc.killed, isFalse);
      expect(logs, ['rendered 1/2 frames', 'rendered 2/2 frames']);
    },
  );

  test(
    'honours an explicit progressEvery and always logs the last frame',
    () async {
      final logs = <String>[];
      await DanceAppFrameExporter(
        waitReady: () async {},
        prerollClock: (_, _) {},
        renderFrame: (_, _) async {},
        captureFrame: () async => Uint8List(0),
        startEncoder: () => _startFake(_FakeProcess(), tmp),
        log: logs.add,
      ).run(start: 0, durationSec: 1, fps: 4, progressEvery: 2);

      // 4 frames; logs at 0, 2, and the forced last frame (3).
      expect(logs, [
        'rendered 1/4 frames',
        'rendered 3/4 frames',
        'rendered 4/4 frames',
      ]);
    },
  );

  test('kills the encoder and rethrows if a frame fails mid-export', () async {
    final proc = _FakeProcess();
    final exporter = DanceAppFrameExporter(
      waitReady: () async {},
      prerollClock: (_, _) {},
      renderFrame: (_, _) async {},
      captureFrame: () async => throw StateError('capture boom'),
      startEncoder: () => _startFake(proc, tmp),
    );

    await expectLater(
      exporter.run(start: 0, durationSec: 1, fps: 4),
      throwsA(isA<StateError>()),
    );
    expect(proc.killed, isTrue, reason: 'aborts the encoder on failure');
    expect(proc.fakeStdin.closed, isFalse, reason: 'did not finish cleanly');
  });
}
