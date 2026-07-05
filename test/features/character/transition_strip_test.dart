import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:dancing_cats/features/character/model/beat_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dance_frame_composer.dart';

/// Transition-strip capture: renders every distinct MOVE HANDOFF the real
/// set list performs, through the production pipeline — the same
/// [DanceFrameComposer] (real `DancePerformance` + real
/// `DancePlaybackStepper`, so `kDanceMoveTransitionSeconds` and the staged
/// `ClipBlendMask` are exercised exactly as shipped).
///
/// The 9-path campaign scored every move's LOOP; nothing scores the
/// handoffs between them. This harness finds each unique lead-clip pair the
/// track actually performs (first occurrence), then renders a short window
/// straddling the boundary so a review panel can judge the blend.
///
/// | Env var               | Meaning                            | Default |
/// | ---------------------- | ---------------------------------- | ------- |
/// | `TRANSITION_STRIPS`     | enable (1/0)                       | 0       |
/// | `TRANSITION_STRIP_DIR`  | output directory                   | `build/character_transition_strips` |
/// | `TRANSITION_FPS`        | frames per second in the window    | 24      |
/// | `TRANSITION_PRE`        | seconds rendered before the cut    | 0.75    |
/// | `TRANSITION_POST`       | seconds rendered after the cut     | 1.25    |
/// | `TRANSITION_WIDTH`      | frame width (16:9 height derived)  | 960     |
///
/// ```sh
/// TRANSITION_STRIPS=1 fvm flutter test \
///   test/features/character/transition_strip_test.dart
/// ```
///
/// Output per pair: `seq_<from>__<to>/f%03d.png` plus `manifest.json`
/// recording each boundary's audio time, the frame instant of the cut, and
/// the full trio signatures — enough for ffmpeg GIF stitching and labeled
/// contact sheets downstream.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final env = Platform.environment;
  final enabled = env['TRANSITION_STRIPS'] == '1';

  test(
    'renders every distinct set-list move handoff through the stepper',
    () async {
      final fps = int.tryParse(env['TRANSITION_FPS'] ?? '') ?? 24;
      final pre = double.tryParse(env['TRANSITION_PRE'] ?? '') ?? 0.75;
      final post = double.tryParse(env['TRANSITION_POST'] ?? '') ?? 1.25;
      final width = int.tryParse(env['TRANSITION_WIDTH'] ?? '') ?? 960;
      final height = (width * 9 / 16).round();
      final outputDir = Directory(
        env['TRANSITION_STRIP_DIR'] ?? 'build/character_transition_strips',
      )..createSync(recursive: true);

      final json =
          jsonDecode(File('assets/sample_track/moving.json').readAsStringSync())
              as Map<String, Object?>;
      final beatMap = BeatMap.fromJson(json);
      final audio = json['audio'] as Map<String, Object?>?;
      final trackDuration =
          (audio?['duration_sec'] as num?)?.toDouble() ??
          beatMap.beatTimesSec.last;

      final composer = await DanceFrameComposer.load(
        json: json,
        beatMap: beatMap,
        trackDurationSec: trackDuration,
        wordsPath: 'assets/sample_track/moving.words.json',
        cuesPath: 'assets/sample_track/moving.cues.json',
        size: Size(width.toDouble(), height.toDouble()),
        captions: false,
      );

      // Scan the pure stage derivation for boundaries: any change of the
      // trio signature while both sides dance (idle handoffs use the longer
      // rest window and are a different review question).
      String signature(double pos) {
        final stage = composer.perf.stageAt(pos);
        return [
          if (stage.energetic) 'D' else 'R',
          stage.lead.name,
          for (final clip in stage.ensemble) clip.name,
        ].join('|');
      }

      const scanDt = 1 / 30.0;
      final boundaries =
          <({double pos, String pair, String fromSig, String toSig})>[];
      var prevSig = signature(0);
      for (var t = scanDt; t < trackDuration; t += scanDt) {
        final sig = signature(t);
        if (sig != prevSig) {
          final from = prevSig.split('|');
          final to = sig.split('|');
          if (from[0] == 'D' && to[0] == 'D') {
            boundaries.add((
              pos: t,
              pair: '${from[1]}__${to[1]}',
              fromSig: prevSig,
              toSig: sig,
            ));
          }
          prevSig = sig;
        }
      }

      // First occurrence per LEAD pair — the panel judges the lead handoff;
      // the manifest keeps the full trio signatures for context.
      final seen = <String>{};
      final picks = [
        for (final b in boundaries)
          if (b.pos > pre + 3 &&
              b.pos + post < trackDuration &&
              seen.add(b.pair))
            b,
      ];
      expect(picks, isNotEmpty, reason: 'no dance->dance handoffs found');

      final manifest = <Map<String, Object?>>[];
      final dt = 1 / fps;
      for (final b in picks) {
        final dir = Directory('${outputDir.path}/seq_${b.pair}')
          ..createSync(recursive: true);
        final start = b.pos - pre;
        // Preroll settles the camera rig and hands the stepper the true
        // outgoing stage, so the boundary fires inside the render window
        // exactly as it does in the app.
        for (var t = start - 3; t < start; t += dt) {
          composer.advance(t, dt);
        }
        final frames = ((pre + post) * fps).round();
        for (var i = 0; i < frames; i++) {
          final t = start + i * dt;
          final rendered = await composer.renderFrame(
            t,
            dt,
            includePng: true,
          );
          File(
            '${dir.path}/f${i.toString().padLeft(3, '0')}.png',
          ).writeAsBytesSync(rendered.png!);
        }
        manifest.add({
          'pair': b.pair,
          'boundary_sec': b.pos,
          'cut_frame': (pre * fps).round(),
          'fps': fps,
          'frames': frames,
          'from': b.fromSig,
          'to': b.toSig,
        });
        // ignore: avoid_print
        print(
          'transition ${b.pair} @ ${b.pos.toStringAsFixed(2)}s '
          '(${manifest.length}/${picks.length})',
        );
      }
      File(
        '${outputDir.path}/manifest.json',
      ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));
      composer.dispose();

      // The harness is only honest if the windows really contain a cut.
      expect(manifest, hasLength(picks.length));
      expect(
        picks.map((b) => b.pair).toSet().length,
        picks.length,
        reason: 'pairs must be unique',
      );
    },
    skip: enabled ? false : 'Set TRANSITION_STRIPS=1 to render handoffs',
    timeout: const Timeout(Duration(minutes: 30)),
  );

  test('the set list performs at least four distinct dance handoffs', () async {
    // Boundary discovery must not silently collapse (e.g. a set-list edit
    // that parks the whole song on one trio) — the transitions review
    // depends on real handoffs existing. Pure stageAt scan, no rendering.
    final json =
        jsonDecode(File('assets/sample_track/moving.json').readAsStringSync())
            as Map<String, Object?>;
    final beatMap = BeatMap.fromJson(json);
    final audio = json['audio'] as Map<String, Object?>?;
    final trackDuration =
        (audio?['duration_sec'] as num?)?.toDouble() ??
        beatMap.beatTimesSec.last;
    final composer = await DanceFrameComposer.load(
      json: json,
      beatMap: beatMap,
      trackDurationSec: trackDuration,
      wordsPath: 'assets/sample_track/moving.words.json',
      cuesPath: 'assets/sample_track/moving.cues.json',
      size: const Size(320, 180),
      captions: false,
    );
    final pairs = <String>{};
    var prev = '';
    for (var t = 0.0; t < trackDuration; t += 1 / 30.0) {
      final stage = composer.perf.stageAt(t);
      final sig = [
        if (stage.energetic) 'D' else 'R',
        stage.lead.name,
        for (final clip in stage.ensemble) clip.name,
      ].join('|');
      if (prev.isNotEmpty && sig != prev) {
        final from = prev.split('|');
        final to = sig.split('|');
        if (from[0] == 'D' && to[0] == 'D' && from[1] != to[1]) {
          pairs.add('${from[1]}->${to[1]}');
        }
      }
      prev = sig;
    }
    composer.dispose();
    expect(
      pairs.length,
      greaterThanOrEqualTo(4),
      reason:
          'the designed set should hand off between at least four distinct '
          'lead pairs; found: ${pairs.join(', ')}',
    );
  });
}
