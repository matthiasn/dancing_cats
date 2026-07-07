import 'package:dancing_cats/features/character/demo/dance_performance.dart';
import 'package:dancing_cats/features/character/model/dance_dynamics.dart';
import 'package:dancing_cats/features/character/model/dance_dynamics_warp.dart';
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
            lessThan(2.3),
            reason:
                '${clip.name} $bone worst real-tempo angular acceleration '
                'should stay clear of a hard rotational stop. Raised 1.8→2.3 '
                'for the 1.5x dance-dynamics tempo (owner: "look and feel like '
                'actual afrobeats... loosen constraints if needed"): the loop '
                'runs at 2-bar/1.5x now, so the same authored motion measures '
                'faster on the shipped clock — this stays a real stop-go guard '
                'with headroom, not a disabled one. Real dance hands whip fast '
                'into an on-beat accent (owner: "hands move fast in dance"), '
                'which the old smooth-motion bound forbade; a genuine stop-go '
                'regression still spikes far higher.',
          );
        }
      }
    },
  );

  // ELBOW gate (owner: the elbow snaps into position too suddenly, and no test
  // caught it because the gates above watch hand/torso, not arm_lower). The
  // two-bone-IK elbow (arm_lower) rotates FASTER than the hand it serves, and a
  // fast hand hit whips it hard; a robotic 1-frame snap sends it far past a
  // natural whip. Watch it on the SHIPPED (warped) clock — the elbow snap is a
  // live-playback artifact the raw-clip gates never see.
  test('catalogue elbow (arm_lower) never snaps past a natural whip', () {
    final scene = CharacterScene(buildCatInSuitRig());
    final analyzer = TemporalMotionAnalyzer(scene);
    const speedup = kDanceRealTempoSpeedup;
    const elbows = [CatBones.armLowerL, CatBones.armLowerR];

    final clips = {
      'shaku': CatClips.shaku,
      'zanku': CatClips.zanku,
      'azonto': CatClips.azonto,
      'sekem': CatClips.sekem,
      'buga': CatClips.buga,
      'pouncingCat': CatClips.pouncingCat,
    };
    for (final entry in clips.entries) {
      final eff = effectiveDanceDynamics(
        moveBase: entry.value.dynamics,
        catProfile: kDanceLaneDynamicsProfiles[0],
        sectionEnergy: sectionEnergyDynamics(0.85),
      );
      final warped = upperBodyDynamicsWarpedClip(
        entry.value,
        eff,
        warpBoneIds: kDanceUpperBodyWarpBoneIds,
      );
      final report = analyzer.analyze(
        clip: warped,
        samples: 192,
        boneIds: elbows,
      );
      for (final bone in elbows) {
        final worst = report.angularSegments
            .where((s) => s.boneId == bone)
            .map((s) => s.magnitude)
            .reduce((a, b) => a > b ? a : b) *
            speedup;
        // ignore: avoid_print
        print('elbow ${entry.key.padRight(12)} $bone  worst ${worst.toStringAsFixed(3)}');
        // Current clean catalogue peaks at ~0.7 (sekem); a robotic 1-frame hit
        // snap drove this well past 1.5. Raised 1.5→2.1 for the 1.5x
        // dance-dynamics tempo (owner: "look and feel like actual afrobeats...
        // loosen constraints if needed") — the 2-bar loop scales the same
        // authored elbow motion up on the shipped clock; still ~3x over the
        // clean ~0.7 max so a genuine snap fails loudly. Ratchet down later.
        expect(
          worst,
          lessThan(2.1),
          reason:
              '${entry.key} $bone elbow angular velocity should read as a '
              'natural whip, not a sudden snap (a fast 1-frame hit snap sends '
              'it far past this — the defect that slipped through when only '
              'hand/torso were gated)',
        );
      }
    }
  });
}
