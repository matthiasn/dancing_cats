import 'dart:convert';
import 'dart:io';

import 'package:dancing_cats/features/character/demo/dance_camera_director.dart';
import 'package:dancing_cats/features/character/demo/dance_loaders.dart';
import 'package:dancing_cats/features/character/demo/dance_performance.dart';
import 'package:dancing_cats/features/character/demo/dance_playback_stepper.dart';
import 'package:dancing_cats/features/character/model/beat_map.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for the camera's "nothing abrupt" contract, measured over
/// the REAL demo track end to end (the temporal-diff analysis that motivated
/// the anticipated-dolly director found its worst events at the section
/// punches: a ~335 ref-px instant pan flip at the bridge hand-off whipped at
/// ~815 ref-px/s, and a 0.47 zoom/s snap into the first chorus). These bounds
/// hold the whole track to genuine dolly speeds — a reintroduced punch, target
/// step, or mid-section re-staging blows them immediately.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const fps = 60;
  const dt = 1.0 / fps;

  late DancePerformance perf;
  late double duration;

  setUpAll(() async {
    final json =
        jsonDecode(File('assets/sample_track/moving.json').readAsStringSync())
            as Map<String, Object?>;
    final map = BeatMap.fromJson(json);
    final audio = json['audio'] as Map<String, Object?>?;
    duration =
        (audio?['duration_sec'] as num?)?.toDouble() ?? map.beatTimesSec.last;
    perf = DancePerformance.fromBeatMapJson(
      json: json,
      map: map,
      trackDurationSec: duration,
      words: await loadDanceWords('assets/sample_track/moving.words.json'),
    );
  });

  test('the director TARGET never steps anywhere in the track', () {
    // Adjacent-frame target deltas at 60fps. The old director stepped its
    // target by up to 0.24 zoom / 335 ref px in one frame at section
    // boundaries and build thresholds; the anticipated dolly keeps every
    // transition inside these per-frame budgets (≈0.24 zoom/s, ≈180 px/s —
    // the intro build-in peaks at ≈0.16 zoom/s by design).
    Shot shotAt(double pos) {
      final stage = perf.stageAt(pos);
      return cameraShot(perf.directorContext(pos, energetic: stage.energetic));
    }

    var prev = shotAt(0);
    for (var f = 1; f < (duration * fps).ceil(); f++) {
      final pos = f * dt;
      final s = shotAt(pos);
      expect(
        (s.zoom - prev.zoom).abs(),
        lessThan(0.004),
        reason: 'target zoom stepped at t=${pos.toStringAsFixed(2)}s',
      );
      expect(
        (s.dx - prev.dx).abs(),
        lessThan(3.2),
        reason: 'target pan stepped at t=${pos.toStringAsFixed(2)}s '
            '(3.0→3.2 for the 1.5x/2-bar dance-dynamics tempo: the camera '
            'covers the same pan over a shorter loop, so per-frame step rises)',
      );
      expect(
        (s.dy - prev.dy).abs(),
        lessThan(1.0),
        reason: 'target dy stepped at t=${pos.toStringAsFixed(2)}s',
      );
      prev = s;
    }
  });

  test('the EASED camera stays at dolly speeds for the whole track', () {
    // The stepper's rig output is what reaches the painter. Bound its
    // velocity: the old punches peaked at ~0.47 zoom/s and ~815 ref-px/s; a
    // high-end dolly stays well under half of either. dy moves only in the
    // calm trims, so its budget is small.
    final stepper = DancePlaybackStepper();
    var prev = (zoom: 1.0, dx: 0.0, dy: 0.0);
    var maxZoomVel = 0.0;
    var maxPanVel = 0.0;
    for (var f = 0; f < (duration * fps).ceil(); f++) {
      final pos = f * dt;
      stepper.advance(perf, const [], pos, dt);
      final s = stepper.shot;
      if (f > 0) {
        maxZoomVel = (s.zoom - prev.zoom).abs() * fps > maxZoomVel
            ? (s.zoom - prev.zoom).abs() * fps
            : maxZoomVel;
        maxPanVel = (s.dx - prev.dx).abs() * fps > maxPanVel
            ? (s.dx - prev.dx).abs() * fps
            : maxPanVel;
      }
      prev = s;
    }
    expect(
      maxZoomVel,
      lessThan(0.20),
      reason: 'peak zoom velocity (zoom/s) left dolly range',
    );
    expect(
      maxPanVel,
      lessThan(200),
      reason: 'peak pan velocity (ref px/s) left dolly range',
    );
  });

  test('each chorus drop OWNS its phrase: the eased launch crest lands on the '
      'beat and above the approach peak', () {
    // The drops in the demo track (from its lyric section spans).
    const drops = [9.76, 42.022, 90.064];
    final stepper = DancePlaybackStepper();
    final zooms = <double>[];
    for (var f = 0; f < (duration * fps).ceil(); f++) {
      stepper.advance(perf, const [], f * dt, dt);
      zooms.add(stepper.shot.zoom);
    }
    double vz(int f) => (zooms[f + 1] - zooms[f]) * fps;
    for (final drop in drops) {
      final beat = (drop * fps).round();
      // Peak |zoom velocity| near the drop must land ON it (within a couple of
      // frames' tolerance), not half a beat later — the launch preroll exists
      // exactly for this.
      var crestFrame = beat - (1.2 * fps).round();
      for (var f = crestFrame; f < beat + (1.2 * fps).round(); f++) {
        if (vz(f).abs() > vz(crestFrame).abs()) crestFrame = f;
      }
      final crestOffset = (crestFrame - beat) / fps;
      expect(
        crestOffset,
        inInclusiveRange(-0.25, 0.25),
        reason: 'drop at ${drop}s: launch crest at ${crestOffset}s',
      );
      // And the launch must out-run the approach glide, so the accent — not
      // the runway — is the fastest camera moment of its phrase.
      var approachPeak = 0.0;
      for (var f = beat - 6 * fps; f < beat - fps ~/ 2; f++) {
        if (vz(f).abs() > approachPeak) approachPeak = vz(f).abs();
      }
      expect(
        vz(crestFrame).abs(),
        greaterThan(approachPeak),
        reason: 'drop at ${drop}s: approach outran the launch',
      );
    }
  });
}
