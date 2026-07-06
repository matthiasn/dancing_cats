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
/// catch one clip.
///
/// None of these failures were a clean "decelerate then hold" pattern the
/// overshoot-and-settle pass targets — they were all the two-bone IK
/// solver's near-degenerate reach zone (arm folded close to the shoulder),
/// the same root cause diagnosed for azonto/sekem earlier this session.
/// zanku's hand.R punch-guard and pouncingCat's cross-body swipe (both
/// hands) fixed outright by widening reach at the offending keys — for
/// pouncingCat specifically, full Kochanek-Bartels tension at the dip-
/// adjacent key plus a small widen, since position changes alone rippled
/// through the smooth spline and made adjacent segments worse rather than
/// better.
///
/// azonto hand.L's frame 30->31 transition (hip chamber sweeping up past the
/// shoulder toward the wheel-grip) resisted a plain reposition: widening
/// frame 31 alone, both endpoints together, or a wide-arc via-point all made
/// it WORSE, up to 3-4x. Damping the shared root-motion layer azonto reuses
/// from shaku (`_shakuGrooveCalm`) didn't help either — even zeroing it out
/// entirely (scoped to azonto only) barely moved the number, since the
/// target and the shoulder are both anchored to the same moving torso frame
/// and translation mostly cancels out in their RELATIVE geometry. The actual
/// fix: `_shoulderCorrectiveEngagement` (character_scene.dart) ramps the
/// clavicle shrug on based on the hand target's raw Y — frame 31's y: -66
/// crossed that ramp's threshold in the same single frame the arm was
/// already fighting the near-degenerate reach, compounding two independent
/// snaps at once. Spreading the rise across two frames instead of one
/// (frame 31 eased to y: -40, frame 32 still lands the full y: -88) let the
/// shoulder-engagement ramp and the arm's own transition resolve on
/// different beats instead of stacking.
void main() {
  test(
    'catalogue bone rotation keeps angular velocity below the snap band',
    () {
      final scene = CharacterScene(buildCatInSuitRig());
      final analyzer = TemporalMotionAnalyzer(scene);
      const speedup = kDanceRealTempoSpeedup;

      const known = <String>{};

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
    },
  );

  test(
    'catalogue bone rotation keeps angular acceleration below the snap band',
    () {
      final scene = CharacterScene(buildCatInSuitRig());
      final analyzer = TemporalMotionAnalyzer(scene);
      const speedup = kDanceRealTempoSpeedup;
      const speedupSquared = speedup * speedup;

      const known = <String>{};

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
