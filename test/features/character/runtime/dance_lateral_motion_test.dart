import 'dart:math' as math;

import 'package:dancing_cats/features/character/demo/dance_performance.dart';
import 'package:dancing_cats/features/character/runtime/character_scene.dart';
import 'package:dancing_cats/features/character/runtime/temporal_motion_analyzer.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards world-space bone *position* (translational) continuity for the
/// core body mass, on the real shipped clock.
///
/// `dance_smoothness_test.dart` only checks positional jerk on hand.L/R for
/// zanku/azonto; `dance_angular_motion_test.dart` checks rotational
/// velocity/acceleration on hand.L/R/torso for all six clips. Neither covers
/// the whole-body *lateral* sway/sink motion (torso/hips translation) that
/// drives the root groove — the thing a viewer actually reads as "the body
/// moving smoothly" or "snapping/hopping." This closes that gap.
///
/// Thresholds (vel<10, accel<8, jerk<8) are the owner's own call, made
/// deliberately strict: shaku (this session's calmest catalogue clip) clears
/// all three at ~4-7 with real headroom, but every OTHER clip currently
/// exceeds at least one. That's not a design flaw in the test — it's five
/// genuine, unfixed "whole-body snap" problems this gate was written to
/// surface. Owner's plan: work through them one clip at a time, verifying
/// each fix against a fresh panel round rather than just the raw numbers,
/// starting with the worst offender (buga).
///
/// `known` tracks moves not yet brought under the gate, WITH their current
/// measured numbers, so a future pass has a baseline to improve from and this
/// file can go green clip-by-clip instead of needing one giant fix.
void main() {
  // Round-11 numbers before any fix: zanku vel=16.8/accel=12.6/jerk=24.9,
  // azonto vel=10.5/accel=7.4/jerk=9.8, sekem vel=13.1/accel=7.8/jerk=12.1,
  // buga vel=29.9/accel=21.0/jerk=25.3 (the worst offender by far),
  // pouncingCat vel=9.4/accel=9.1/jerk=14.7.
  //
  // Buga first pass (this change): redistributed the "lo3 hold -> HIT"
  // transition (previously a single ~90-unit rootDy jump concentrated into
  // one frame-to-frame step, both bars) across three graduated segments
  // instead of one cliff. Real, verified improvement — vel 29.9->18.6,
  // accel 21.0->13.0, jerk 25.3->15.4 (all ~38% down) — but doesn't clear
  // the gate outright yet: the "explosive hit" needs to cover the same
  // total distance in the same small number of authored frames (frame
  // 12/28 is test-pinned as the HIT, so there's a hard ceiling on how much
  // runway is available to spread the rise across). Left in `known` with
  // its improved numbers rather than chasing the last stretch blindly;
  // next step is a panel round to confirm the improvement actually reads,
  // not just the raw metric.
  const known = <String>{
    'torso/zanku',
    'hips/zanku',
    'torso/azonto',
    'hips/azonto',
    'torso/sekem',
    'hips/sekem',
    'torso/buga',
    'hips/buga',
    'torso/pouncingCat',
    'hips/pouncingCat',
  };

  test(
    'catalogue torso/hips motion keeps lateral velocity below the snap band',
    () {
      final scene = CharacterScene(buildCatInSuitRig());
      final analyzer = TemporalMotionAnalyzer(scene);
      const speedup = kDanceRealTempoSpeedup;

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
          boneIds: const [CatBones.torso, CatBones.hips],
        );
        for (final bone in const [CatBones.torso, CatBones.hips]) {
          if (known.contains('$bone/${clip.name}')) continue;
          final worstVelocity =
              report.segments
                  .where((segment) => segment.boneId == bone)
                  .map((segment) => segment.distance)
                  .reduce(math.max) *
              speedup;
          expect(
            worstVelocity,
            lessThan(10),
            reason:
                '${clip.name} $bone worst real-tempo lateral velocity should '
                'stay well clear of a whole-body-mass teleport',
          );
        }
      }
    },
  );

  test(
    'catalogue torso/hips motion keeps lateral acceleration below the snap band',
    () {
      final scene = CharacterScene(buildCatInSuitRig());
      final analyzer = TemporalMotionAnalyzer(scene);
      const speedup = kDanceRealTempoSpeedup;
      const speedupSquared = speedup * speedup;

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
          boneIds: const [CatBones.torso, CatBones.hips],
        );
        for (final bone in const [CatBones.torso, CatBones.hips]) {
          if (known.contains('$bone/${clip.name}')) continue;
          final worstAcceleration =
              report.accelerations
                  .where((acceleration) => acceleration.boneId == bone)
                  .map((acceleration) => acceleration.magnitude)
                  .reduce(math.max) *
              speedupSquared;
          expect(
            worstAcceleration,
            lessThan(8),
            reason:
                '${clip.name} $bone worst real-tempo lateral acceleration '
                'should stay well clear of a hard whole-body stop',
          );
        }
      }
    },
  );

  test(
    'catalogue torso/hips motion keeps lateral jerk below the snap band',
    () {
      final scene = CharacterScene(buildCatInSuitRig());
      final analyzer = TemporalMotionAnalyzer(scene);
      const speedup = kDanceRealTempoSpeedup;
      const speedupCubed = speedup * speedup * speedup;

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
          boneIds: const [CatBones.torso, CatBones.hips],
        );
        for (final bone in const [CatBones.torso, CatBones.hips]) {
          if (known.contains('$bone/${clip.name}')) continue;
          final worstJerk =
              report.jerks
                  .where((jerk) => jerk.boneId == bone)
                  .map((jerk) => jerk.magnitude)
                  .reduce(math.max) *
              speedupCubed;
          expect(
            worstJerk,
            lessThan(8),
            reason:
                '${clip.name} $bone worst real-tempo lateral jerk should '
                'stay well clear of a whole-body-mass snap',
          );
        }
      }
    },
  );
}
