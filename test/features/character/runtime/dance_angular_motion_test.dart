import 'package:dancing_cats/features/character/demo/dance_performance.dart';
import 'package:dancing_cats/features/character/runtime/character_scene.dart';
import 'package:dancing_cats/features/character/runtime/temporal_motion_analyzer.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards world-space bone *rotation* continuity, on the real shipped clock.
///
/// `TemporalMotionAnalyzer`'s existing jerk gate (`dance_smoothness_test.dart`)
/// only tracks bone *position*; a joint can reverse its rotation abruptly
/// without its end-effector position spiking as hard. This gate tracks the
/// bone's world-space angle instead, and applies [kDanceRealTempoSpeedup] so
/// the measured rates match what the beat-warped live/exported app actually
/// plays, not the raw authored clip clock.
///
/// Thresholds are calibrated against sekem (this session's un-complained-about
/// reference clip) with roughly 3-4x headroom, not reverse-engineered to only
/// catch one clip. At these thresholds azonto's wheel-mime and pounce's swipe
/// currently exceed the acceleration ceiling — real findings, not test bugs.
///
/// zanku's hand.R punch-guard used to fail this ceiling too (worst ~3.4):
/// root-caused to the guard hold sitting at ~12% of arm reach (the two-bone
/// solver's near-degenerate fold zone) against a shoulder that itself swings
/// widely during that beat. The overshoot-and-settle pass alone didn't fix
/// it — none of these failures are a clean "decelerate then hold" pattern on
/// the rotation channel, they're the IK reach geometry itself. Widening the
/// guard's reach at every occurrence (bars 1 and 2) fixed it outright.
void main() {
  test('catalogue bone rotation keeps angular velocity below the snap band', () {
    final scene = CharacterScene(buildCatInSuitRig());
    final analyzer = TemporalMotionAnalyzer(scene);
    final speedup = kDanceRealTempoSpeedup;

    // pouncingCat hand.L's swipe currently measures ~4.5 against the 2.5
    // ceiling below - this gate never existed before, so that's a newly
    // surfaced finding rather than a regression. Tracked as an open item
    // alongside the acceleration exclusions in the test below.
    const known = {'${CatBones.handL}/pouncingCat'};

    for (final clip in [
      CatClips.shaku,
      CatClips.zanku,
      CatClips.azonto,
      CatClips.sekem,
      CatClips.buga,
      CatClips.pouncingCat,
    ]) {
      final report = analyzer.analyze(
        clip: clip,
        samples: 192,
        boneIds: const [CatBones.handL, CatBones.handR, CatBones.torso],
      );
      for (final bone in const [CatBones.handL, CatBones.handR, CatBones.torso]) {
        if (known.contains('$bone/${clip.name}')) continue;
        final worstVelocity =
            report.angularSegments
                .where((segment) => segment.boneId == bone)
                .map((segment) => segment.magnitude)
                .reduce((a, b) => a > b ? a : b) *
            speedup;
        expect(
          worstVelocity,
          lessThan(2.5),
          reason:
              '${clip.name} $bone worst real-tempo angular velocity should '
              'stay well clear of a full-radian-per-sample rotation snap',
        );
      }
    }
  });

  test(
    'catalogue bone rotation keeps angular acceleration below the snap band',
    () {
      final scene = CharacterScene(buildCatInSuitRig());
      final analyzer = TemporalMotionAnalyzer(scene);
      final speedup = kDanceRealTempoSpeedup;
      final speedupSquared = speedup * speedup;

      // azonto hand.L and pounce hand.L/hand.R currently fail this ceiling
      // (worst real-tempo values approximately 2.0, 8.0, 4.2 respectively
      // against the 1.5 ceiling below) — see the file doc comment above.
      const known = {
        '${CatBones.handL}/azonto',
        '${CatBones.handL}/pouncingCat',
        '${CatBones.handR}/pouncingCat',
      };

      for (final clip in [
        CatClips.shaku,
        CatClips.zanku,
        CatClips.azonto,
        CatClips.sekem,
        CatClips.buga,
        CatClips.pouncingCat,
      ]) {
        final report = analyzer.analyze(
          clip: clip,
          samples: 192,
          boneIds: const [CatBones.handL, CatBones.handR, CatBones.torso],
        );
        for (final bone in const [
          CatBones.handL,
          CatBones.handR,
          CatBones.torso,
        ]) {
          if (known.contains('$bone/${clip.name}')) continue;
          final worstAcceleration =
              report.angularAccelerations
                  .where((acceleration) => acceleration.boneId == bone)
                  .map((acceleration) => acceleration.magnitude)
                  .reduce((a, b) => a > b ? a : b) *
              speedupSquared;
          expect(
            worstAcceleration,
            lessThan(1.5),
            reason:
                '${clip.name} $bone worst real-tempo angular acceleration '
                'should stay well clear of a hard rotational stop',
          );
        }
      }
    },
  );
}
