import 'package:dancing_cats/features/character/model/bone.dart';
import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/easing.dart';
import 'package:dancing_cats/features/character/model/rig_spec.dart';
import 'package:dancing_cats/features/character/runtime/character_scene.dart';
import 'package:dancing_cats/features/character/runtime/motion_constraint_validator.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MotionConstraintValidator', () {
    test('detects authored IK targets beyond the limb reach envelope', () {
      final validator = MotionConstraintValidator(
        CharacterScene(buildCatInSuitRig()),
      );
      const clip = Clip(
        name: 'synthetic-impossible-arm',
        duration: 1,
        channels: {},
        limbTargets: [
          LimbIkTarget(
            upperBoneId: CatBones.armUpperL,
            lowerBoneId: CatBones.armLowerL,
            endBoneId: CatBones.handL,
            anchorBoneId: CatBones.torso,
            channel: FixedIkTargetChannel(x: 420, y: -160),
          ),
        ],
      );

      final report = validator.analyze(
        clip: clip,
        ikSamples: 4,
        contactSamplesPerSpan: 1,
      );

      expect(report.ikReaches, hasLength(4));
      expect(report.worstIkReach!.reachRatio, greaterThan(1));
      expect(
        report.violations.map((violation) => violation.category),
        contains(MotionConstraintCategory.ikReach),
      );
    });

    test('detects solved endpoints that miss their IK target', () {
      final validator = MotionConstraintValidator(
        CharacterScene(buildCatInSuitRig()),
      );
      const clip = Clip(
        name: 'synthetic-target-residual',
        duration: 1,
        channels: {},
        limbTargets: [
          LimbIkTarget(
            upperBoneId: CatBones.armUpperL,
            lowerBoneId: CatBones.armLowerL,
            endBoneId: CatBones.handL,
            anchorBoneId: CatBones.torso,
            channel: FixedIkTargetChannel(x: 420, y: -160),
          ),
        ],
      );

      final report = validator.analyze(
        clip: clip,
        profile: const MotionConstraintProfile(maxIkTargetResidual: 2),
        ikSamples: 4,
        contactSamplesPerSpan: 1,
      );

      expect(report.ikTargetResiduals, hasLength(4));
      expect(report.worstIkTargetResidual!.distance, greaterThan(2));
      expect(
        report.violations.map((violation) => violation.category),
        contains(MotionConstraintCategory.ikTargetResidual),
      );
    });

    test('detects a same-side hand target with a reversed elbow lane', () {
      final validator = MotionConstraintValidator(
        CharacterScene(
          RigSpec(
            name: 'folded-test-arm',
            bones: const [
              Bone(
                id: CatBones.hips,
                parent: null,
                pivotX: 0,
                pivotY: 0,
                z: 0,
              ),
              Bone(
                id: CatBones.armUpperL,
                parent: CatBones.hips,
                pivotX: 0,
                pivotY: 0,
                z: 1,
              ),
              Bone(
                id: CatBones.armLowerL,
                parent: CatBones.armUpperL,
                pivotX: 0,
                pivotY: 60,
                z: 2,
              ),
              Bone(
                id: CatBones.handL,
                parent: CatBones.armLowerL,
                pivotX: 0,
                pivotY: 40,
                z: 3,
              ),
            ],
          ),
        ),
      );
      const clip = Clip(
        name: 'synthetic-folded-lane',
        duration: 1,
        channels: {},
        limbTargets: [
          LimbIkTarget(
            upperBoneId: CatBones.armUpperL,
            lowerBoneId: CatBones.armLowerL,
            endBoneId: CatBones.handL,
            anchorBoneId: CatBones.hips,
            channel: FixedIkTargetChannel(x: -50, y: 20),
          ),
        ],
      );

      final report = validator.analyze(
        clip: clip,
        ikSamples: 4,
        contactSamplesPerSpan: 1,
      );

      expect(report.limbLanes, hasLength(4));
      expect(
        report.worstLimbLane!.reversalDistance,
        greaterThan(report.profile.maxLimbLaneReversal),
      );
      expect(
        report.violations.map((violation) => violation.category),
        contains(MotionConstraintCategory.limbLane),
      );
    });

    test('detects a solved limb locked too close to straight', () {
      final validator = MotionConstraintValidator(
        CharacterScene(
          RigSpec(
            name: 'locked-test-arm',
            bones: const [
              Bone(
                id: CatBones.hips,
                parent: null,
                pivotX: 0,
                pivotY: 0,
                z: 0,
              ),
              Bone(
                id: CatBones.armUpperL,
                parent: CatBones.hips,
                pivotX: 0,
                pivotY: 0,
                z: 1,
              ),
              Bone(
                id: CatBones.armLowerL,
                parent: CatBones.armUpperL,
                pivotX: 0,
                pivotY: 60,
                z: 2,
              ),
              Bone(
                id: CatBones.handL,
                parent: CatBones.armLowerL,
                pivotX: 0,
                pivotY: 40,
                z: 3,
              ),
            ],
          ),
        ),
      );
      const clip = Clip(
        name: 'synthetic-locked-arm',
        duration: 1,
        channels: {},
        limbTargets: [
          LimbIkTarget(
            upperBoneId: CatBones.armUpperL,
            lowerBoneId: CatBones.armLowerL,
            endBoneId: CatBones.handL,
            anchorBoneId: CatBones.hips,
            channel: FixedIkTargetChannel(x: 0, y: 110),
          ),
        ],
      );

      final report = validator.analyze(
        clip: clip,
        profile: const MotionConstraintProfile(maxLimbBendDegrees: 170),
        ikSamples: 4,
        contactSamplesPerSpan: 1,
      );

      expect(report.limbBends, hasLength(4));
      expect(report.straightestLimbBend!.bendDegrees, greaterThan(170));
      expect(
        report.violations.map((violation) => violation.category),
        contains(MotionConstraintCategory.limbBend),
      );
    });

    test('reports bend-side mismatch from resolved limb samples', () {
      const report = MotionConstraintReport(
        clipName: 'synthetic-bend-flip',
        profile: MotionConstraintProfile(),
        contactDrifts: [],
        supportBalances: [],
        ikReaches: [],
        ikTargetResiduals: [],
        limbBends: [
          MotionLimbBend(
            clipName: 'synthetic-bend-flip',
            upperBoneId: CatBones.armUpperL,
            lowerBoneId: CatBones.armLowerL,
            endBoneId: CatBones.handL,
            phase: 0.25,
            weight: 1,
            expectedBendDirection: -1,
            actualBendDirection: 1,
            signedArea: -1200,
            bendDegrees: 95,
            straightnessDegrees: 85,
          ),
        ],
        limbLanes: [],
      );

      expect(
        report.violations.map((violation) => violation.category),
        contains(MotionConstraintCategory.limbBendDirection),
      );
    });

    test('detects support-foot drift during a declared stable contact', () {
      final validator = MotionConstraintValidator(
        CharacterScene(buildCatInSuitRig()),
      );
      const clip = Clip(
        name: 'synthetic-foot-skate',
        duration: 1,
        channels: {},
        root: KeyframeRootChannel([
          RootKeyframe(p: 0),
          RootKeyframe(p: 1, dx: 80, ease: Ease.linear),
        ]),
        contactSpans: [GroundSpan(CatBones.footL, 0, 1)],
      );

      final report = validator.analyze(
        clip: clip,
        profile: const MotionConstraintProfile(maxStableContactDrift: 1),
        contactSamplesPerSpan: 5,
        ikSamples: 1,
      );

      expect(report.contactDrifts, hasLength(5));
      expect(report.worstContactDrift!.distance, greaterThan(1));
      expect(
        report.violations.map((violation) => violation.category),
        contains(MotionConstraintCategory.footContact),
      );
    });

    test('detects pelvis drifting outside the support envelope', () {
      final validator = MotionConstraintValidator(
        CharacterScene(buildCatInSuitRig()),
      );
      const clip = Clip(
        name: 'synthetic-off-support',
        duration: 1,
        channels: {},
        root: KeyframeRootChannel([
          RootKeyframe(p: 0, dx: 140),
          RootKeyframe(p: 1, dx: 140),
        ]),
        contactSpans: [GroundSpan(CatBones.footR, 0, 1)],
      );

      final report = validator.analyze(
        clip: clip,
        profile: const MotionConstraintProfile(maxSupportOffset: 5),
        contactSamplesPerSpan: 3,
        ikSamples: 1,
      );

      expect(report.supportBalances, hasLength(3));
      expect(report.worstSupportBalance!.offsetX.abs(), greaterThan(5));
      expect(
        report.violations.map((violation) => violation.category),
        contains(MotionConstraintCategory.supportBalance),
      );
    });

    test('catalogue hand targets stay inside the hard arm reach limit', () {
      final validator = MotionConstraintValidator(
        CharacterScene(buildCatInSuitRig()),
      );

      for (final clip in [
        CatClips.shaku,
        CatClips.zanku,
        CatClips.azonto,
        CatClips.buga,
        CatClips.sekem,
      ]) {
        final report = validator.analyze(clip: clip);
        final impossibleHands = report.ikReaches.where(
          (reach) =>
              (reach.endBoneId == CatBones.handL ||
                  reach.endBoneId == CatBones.handR) &&
              reach.reachRatio > 1.0,
        );
        final worstHands =
            report.ikReaches
                .where(
                  (reach) =>
                      reach.endBoneId == CatBones.handL ||
                      reach.endBoneId == CatBones.handR,
                )
                .toList()
              ..sort((a, b) => b.reachRatio.compareTo(a.reachRatio));
        final worst = worstHands.first;

        expect(
          impossibleHands,
          isEmpty,
          reason:
              '${clip.name} worst ${worst.endBoneId} p='
              '${worst.phase.toStringAsFixed(4)} ratio='
              '${worst.reachRatio.toStringAsFixed(3)} must not ask a hand IK '
              'target to exceed the arm chain; the solver would clamp it into '
              'a stick-arm pose',
        );
      }
    });

    test(
      'catalogue hand targets preserve elbow bend and authored bend side',
      () {
        final validator = MotionConstraintValidator(
          CharacterScene(buildCatInSuitRig()),
        );

        for (final clip in [
          CatClips.shaku,
          CatClips.zanku,
          CatClips.azonto,
          CatClips.buga,
          CatClips.sekem,
        ]) {
          final report = validator.analyze(clip: clip);
          final directionViolations = report.violations.where(
            (violation) =>
                violation.category ==
                    MotionConstraintCategory.limbBendDirection &&
                (violation.boneId == CatBones.handL ||
                    violation.boneId == CatBones.handR),
          );
          final highWeightHandBends =
              report.limbBends
                  .where(
                    (bend) =>
                        bend.weight > 0.98 &&
                        (bend.endBoneId == CatBones.handL ||
                            bend.endBoneId == CatBones.handR),
                  )
                  .toList()
                ..sort((a, b) => b.bendDegrees.compareTo(a.bendDegrees));

          expect(
            directionViolations,
            isEmpty,
            reason:
                '${clip.name} should not solve a limb onto the opposite bend '
                'side from its authored IK target; first violations: '
                '${directionViolations.take(3).map((v) => v.message).join(' | ')}',
          );
          expect(
            highWeightHandBends,
            isNotEmpty,
            reason: '${clip.name} should expose high-weight hand bend samples',
          );
          final straightest = highWeightHandBends.first;
          expect(
            straightest.bendDegrees,
            lessThan(178),
            reason:
                '${clip.name} ${straightest.endBoneId} should keep a visible '
                'elbow bend at high target weight; p='
                '${straightest.phase.toStringAsFixed(4)} bend='
                '${straightest.bendDegrees.toStringAsFixed(1)} actualDir='
                '${straightest.actualBendDirection}',
          );
        }
      },
    );

    test('catalogue high-weight hand targets resolve near their controls', () {
      final validator = MotionConstraintValidator(
        CharacterScene(buildCatInSuitRig()),
      );

      for (final clip in [
        CatClips.shaku,
        CatClips.zanku,
        CatClips.azonto,
        CatClips.buga,
        CatClips.sekem,
      ]) {
        final report = validator.analyze(clip: clip);
        final handResiduals =
            report.ikTargetResiduals
                .where(
                  (residual) =>
                      residual.weight > 0.98 &&
                      (residual.endBoneId == CatBones.handL ||
                          residual.endBoneId == CatBones.handR),
                )
                .toList()
              ..sort((a, b) => b.distance.compareTo(a.distance));

        expect(
          handResiduals,
          isNotEmpty,
          reason: '${clip.name} should expose high-weight hand IK samples',
        );
        final worst = handResiduals.first;
        expect(
          worst.distance,
          lessThan(14),
          reason:
              '${clip.name} ${worst.endBoneId} should visibly land near its '
              'high-weight IK control; p=${worst.phase.toStringAsFixed(4)} '
              'weight=${worst.weight.toStringAsFixed(3)} '
              'distance=${worst.distance.toStringAsFixed(1)} '
              'end=(${worst.endX.toStringAsFixed(1)}, ${worst.endY.toStringAsFixed(1)}) '
              'target=(${worst.targetX.toStringAsFixed(1)}, ${worst.targetY.toStringAsFixed(1)})',
        );
      }
    });

    test('sekem same-side hand targets keep a solved anatomical lane', () {
      final validator = MotionConstraintValidator(
        CharacterScene(buildCatInSuitRig()),
      );

      final report = validator.analyze(clip: CatClips.sekem);
      final laneViolations = report.violations.where(
        (violation) => violation.category == MotionConstraintCategory.limbLane,
      );

      expect(
        laneViolations,
        isEmpty,
        reason:
            'Sekem should not solve reachable same-side hand targets into folded '
            'forearms; worst ${report.worstLimbLane?.endBoneId} '
            'p=${report.worstLimbLane?.phase.toStringAsFixed(4)} '
            'reversal=${report.worstLimbLane?.reversalDistance.toStringAsFixed(1)} '
            'shoulder=${report.worstLimbLane?.shoulderX.toStringAsFixed(1)} '
            'elbow=${report.worstLimbLane?.elbowX.toStringAsFixed(1)} '
            'hand=${report.worstLimbLane?.endX.toStringAsFixed(1)}',
      );
    });
  });
}
