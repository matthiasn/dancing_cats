import 'dart:math' as math;

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

    test('detects a high hand target without shoulder-girdle response', () {
      final validator = MotionConstraintValidator(
        CharacterScene(
          RigSpec(
            name: 'no-shoulder-socket',
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
        name: 'synthetic-static-raised-shoulder',
        duration: 1,
        channels: {},
        limbTargets: [
          LimbIkTarget(
            upperBoneId: CatBones.armUpperL,
            lowerBoneId: CatBones.armLowerL,
            endBoneId: CatBones.handL,
            anchorBoneId: CatBones.hips,
            channel: FixedIkTargetChannel(x: -72, y: -90),
          ),
        ],
      );

      final report = validator.analyze(
        clip: clip,
        ikSamples: 4,
        contactSamplesPerSpan: 1,
      );

      expect(report.shoulderResponses, hasLength(4));
      expect(report.weakestRaisedShoulderResponse?.socketResponse, 0);
      expect(
        report.violations.map((violation) => violation.category),
        contains(MotionConstraintCategory.shoulderResponse),
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
        shoulderResponses: [],
        shoulderMeshBridges: [],
        jointEnvelopes: [],
        limitEngagements: [],
      );

      expect(
        report.violations.map((violation) => violation.category),
        contains(MotionConstraintCategory.limbBendDirection),
      );
    });

    test('detects resolved joints outside the dancer envelope', () {
      final validator = MotionConstraintValidator(
        CharacterScene(buildCatInSuitRig()),
      );
      const clip = Clip(
        name: 'synthetic-impossible-torso',
        duration: 1,
        channels: {
          CatBones.torso: KeyframeChannel([
            Keyframe(p: 0, rotation: 1.35, scaleX: 1.72, scaleY: 0.48),
            Keyframe(p: 1, rotation: 1.35, scaleX: 1.72, scaleY: 0.48),
          ]),
        },
      );

      final report = validator.analyze(
        clip: clip,
        ikSamples: 4,
        contactSamplesPerSpan: 1,
      );
      final jointViolations = report.violations.where(
        (violation) =>
            violation.category == MotionConstraintCategory.jointEnvelope,
      );

      expect(report.jointEnvelopes, isNotEmpty);
      expect(report.worstJointEnvelope?.boneId, CatBones.torso);
      expect(jointViolations, isNotEmpty);
      expect(jointViolations.first.boneId, CatBones.torso);
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

    test('catalogue raised hand targets carry shoulder response', () {
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
        final report = validator.analyze(clip: clip, ikSamples: 64);
        final shoulderViolations = report.violations.where(
          (violation) =>
              violation.category == MotionConstraintCategory.shoulderResponse,
        );

        expect(
          shoulderViolations,
          isEmpty,
          reason:
              '${clip.name} should not send hands above shoulder height while '
              'leaving the clavicle/socket controls static: '
              '${shoulderViolations.take(4).map((v) => '${v.boneId}@${v.phase.toStringAsFixed(3)} ${v.message}').join(' | ')}',
        );
      }
    });

    test('catalogue clips keep resolved joints inside dancer envelopes', () {
      final validator = MotionConstraintValidator(
        CharacterScene(buildCatInSuitRig()),
      );

      for (final clip in [
        CatClips.shaku,
        CatClips.zanku,
        CatClips.azonto,
        CatClips.buga,
        CatClips.sekem,
        CatClips.pouncingCat,
      ]) {
        final report = validator.analyze(clip: clip, ikSamples: 64);
        final jointViolations = report.violations.where(
          (violation) =>
              violation.category == MotionConstraintCategory.jointEnvelope,
        );

        expect(
          jointViolations,
          isEmpty,
          reason:
              '${clip.name} should stay inside the resolved joint envelope; '
              '${jointViolations.take(4).map((v) => '${v.boneId}@${v.phase.toStringAsFixed(3)} ${v.message}').join(' | ')}',
        );
      }
    });

    test('buga raised presents deform clavicle and shoulder sockets', () {
      final validator = MotionConstraintValidator(
        CharacterScene(buildCatInSuitRig()),
      );

      final report = validator.analyze(
        clip: CatClips.buga,
        ikSamples: 64,
      );
      final shoulderViolations = report.violations.where(
        (violation) =>
            violation.category == MotionConstraintCategory.shoulderResponse,
      );
      final rightResponses =
          report.shoulderResponses
              .where((response) => response.endBoneId == CatBones.handR)
              .toList()
            ..sort((a, b) => b.socketResponse.compareTo(a.socketResponse));
      final leftResponses =
          report.shoulderResponses
              .where((response) => response.endBoneId == CatBones.handL)
              .toList()
            ..sort((a, b) => b.socketResponse.compareTo(a.socketResponse));

      expect(
        shoulderViolations,
        isEmpty,
        reason:
            'Buga overhead hands should pull clavicle/socket controls with '
            'them instead of hinging from a static jacket edge: '
            '${shoulderViolations.take(4).map((v) => '${v.boneId}@${v.phase.toStringAsFixed(3)} ${v.message}').join(' | ')}',
      );
      expect(rightResponses, isNotEmpty);
      expect(leftResponses, isNotEmpty);
      expect(rightResponses.first.socketResponse, greaterThan(0.28));
      expect(leftResponses.first.socketResponse, greaterThan(0.28));
      expect(rightResponses.first.clavicleRotation, lessThan(-0.2));
      expect(leftResponses.first.clavicleRotation, greaterThan(0.2));
    });

    test('arm ribbon shoulder joint stays welded to the clavicle', () {
      // The old sleeve MESH could open a gap between its shoulder cap and the
      // jacket armhole in raised poses (the "shoulderMeshBridge" checks). The
      // ribbon sleeve removes that failure mode structurally: its root joint
      // IS the clavicle and its second joint (the socket) is rigidly
      // clavicle-parented, so the deltoid dome and the chest-anchored jacket
      // armhole travel together in EVERY pose. This test pins that structure
      // (and that no mesh bridges are left to sample).
      final rig = buildCatInSuitRig();
      final scene = CharacterScene(rig);
      final report = MotionConstraintValidator(scene).analyze(
        clip: CatClips.buga,
        ikSamples: 64,
      );
      expect(report.shoulderMeshBridges, isEmpty);
      expect(
        report.violations.map((violation) => violation.category),
        isNot(contains(MotionConstraintCategory.shoulderMeshBridge)),
      );

      for (final side in ['L', 'R']) {
        final ribbon = rig.ribbons.singleWhere(
          (ribbon) => ribbon.id == 'arm.$side.ribbon',
        );
        final rootId = ribbon.jointBoneIds.first;
        final socketId = ribbon.jointBoneIds[1];
        expect(
          rootId.toLowerCase(),
          contains('clavicle'),
          reason: 'the ribbon must be rooted on the shoulder girdle itself',
        );
        expect(rig.bone(socketId)!.parent, rootId);
        // The anti-hinge contract: the root section (clavicle→socket) is a
        // fixed strut riding the girdle. It must not stretch or collapse in
        // solved poses — the arm's bend belongs BELOW it, over socket→bicep.
        for (final phase in [0.0, 0.25, 0.375, 0.5, 0.75, 0.875]) {
          final frame = scene.frameAt(
            clip: CatClips.buga,
            timeSeconds: CatClips.buga.duration * phase,
          );
          final root = frame.world[rootId]!.origin;
          final socket = frame.world[socketId]!.origin;
          final dx = socket.x - root.x;
          final dy = socket.y - root.y;
          expect(
            math.sqrt(dx * dx + dy * dy),
            inInclusiveRange(7, 13),
            reason:
                'the deltoid root section must stay a near-rest-length strut '
                'on the girdle (rest offset 10) instead of deforming with '
                'the arm swing',
          );
        }
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

    test('rejects non-positive sampling densities', () {
      final validator = MotionConstraintValidator(
        CharacterScene(buildCatInSuitRig()),
      );
      expect(
        () => validator.analyze(clip: CatClips.shaku, contactSamplesPerSpan: 0),
        throwsArgumentError,
      );
      expect(
        () => validator.analyze(clip: CatClips.shaku, ikSamples: 0),
        throwsArgumentError,
      );
    });

    test('meters coupled arm anti-fold corrections as limiter clipping', () {
      final validator = MotionConstraintValidator(
        CharacterScene(_twoArmFoldRig()),
      );
      // Adduct the left upper arm 0.9 rad across the chest, then ask the
      // forearm to break 1.4 rad back outboard — the contralateral
      // "elbow at the sternum, paw flared out" fold that no single-joint
      // range can see. The scene's coupled anti-fold rule must undo the
      // full 1.4 rad, and the validator must meter that correction exactly
      // like a routine leaning on a hinge stop.
      const clip = Clip(
        name: 'synthetic-contralateral-fold',
        duration: 1,
        channels: {
          CatBones.armUpperL: KeyframeChannel([
            Keyframe(p: 0, rotation: -0.9),
            Keyframe(p: 1, rotation: -0.9),
          ]),
          CatBones.armLowerL: KeyframeChannel([
            Keyframe(p: 0, rotation: 1.4),
            Keyframe(p: 1, rotation: 1.4),
          ]),
        },
      );

      final report = validator.analyze(
        clip: clip,
        ikSamples: 2,
        contactSamplesPerSpan: 1,
      );

      expect(report.limitEngagements, hasLength(2));
      final worst = report.worstLimitEngagement!;
      expect(worst.boneId, '${CatBones.armLowerL} anti-fold');
      expect(worst.askedRotation, closeTo(1.4, 1e-9));
      expect(worst.clampedRotation, closeTo(0, 1e-9));
      expect(worst.engagement, closeTo(1.4, 1e-9));
      expect(
        report.violations.map((violation) => violation.category),
        contains(MotionConstraintCategory.jointLimitClipping),
      );
    });

    test('measures a raised sleeve mesh with a detached armhole bridge', () {
      // The production rig replaced the skinned sleeve with a ribbon, so the
      // shoulderMeshBridge checks are structurally dormant there. This probe
      // rig re-creates the old failure mode: an `arm.L.mesh` whose armhole
      // corner vertices sit far from the shoulder-cap vertices, so a raised
      // hand target measures a wide-open gap and a triangle-fan edge.
      final validator = MotionConstraintValidator(
        CharacterScene(_detachedSleeveMeshRig()),
      );
      const clip = Clip(
        name: 'synthetic-detached-sleeve',
        duration: 1,
        channels: {},
        limbTargets: [
          LimbIkTarget(
            upperBoneId: CatBones.armUpperL,
            lowerBoneId: CatBones.armLowerL,
            endBoneId: CatBones.handL,
            anchorBoneId: CatBones.hips,
            channel: FixedIkTargetChannel(x: -40, y: -80),
          ),
        ],
      );

      final report = validator.analyze(
        clip: clip,
        ikSamples: 2,
        contactSamplesPerSpan: 1,
      );

      expect(report.shoulderMeshBridges, hasLength(2));
      final worst = report.worstShoulderMeshBridge!;
      expect(worst.armMeshId, 'arm.L.mesh');
      expect(worst.endBoneId, CatBones.handL);
      expect(worst.targetY, -80);
      expect(worst.gap, greaterThan(report.profile.maxRaisedShoulderMeshGap));
      expect(worst.shoulderToBicepRatio, greaterThan(0));
      expect(
        worst.maxUpperArmEdge,
        greaterThan(report.profile.maxRaisedUpperArmMeshEdge),
      );
      expect(
        report.violations.map((violation) => violation.category),
        contains(MotionConstraintCategory.shoulderMeshBridge),
      );
    });

    test('reports an over-folded elbow from resolved limb samples', () {
      const report = MotionConstraintReport(
        clipName: 'synthetic-folded-elbow',
        profile: MotionConstraintProfile(),
        contactDrifts: [],
        supportBalances: [],
        ikReaches: [],
        ikTargetResiduals: [],
        limbBends: [
          MotionLimbBend(
            clipName: 'synthetic-folded-elbow',
            upperBoneId: CatBones.armUpperL,
            lowerBoneId: CatBones.armLowerL,
            endBoneId: CatBones.handL,
            phase: 0.5,
            weight: 1,
            expectedBendDirection: -1,
            actualBendDirection: -1,
            signedArea: 400,
            bendDegrees: 1.2,
            straightnessDegrees: 178.8,
          ),
          MotionLimbBend(
            clipName: 'synthetic-folded-elbow',
            upperBoneId: CatBones.armUpperR,
            lowerBoneId: CatBones.armLowerR,
            endBoneId: CatBones.handR,
            phase: 0.5,
            weight: 1,
            expectedBendDirection: -1,
            actualBendDirection: -1,
            signedArea: 900,
            bendDegrees: 96,
            straightnessDegrees: 84,
          ),
        ],
        limbLanes: [],
        shoulderResponses: [],
        shoulderMeshBridges: [],
        jointEnvelopes: [],
        limitEngagements: [],
      );

      expect(report.tightestLimbBend!.bendDegrees, 1.2);
      final foldViolations = report.violations.where(
        (violation) =>
            violation.category == MotionConstraintCategory.limbBend &&
            violation.message.contains('folds to'),
      );
      expect(foldViolations, hasLength(1));
      expect(foldViolations.first.boneId, CatBones.handL);
      expect(foldViolations.first.severity, closeTo(1.8, 1e-9));
    });
  });
}

/// Two mirrored shoulder→elbow→hand chains so the scene's coupled arm
/// anti-fold rule is discoverable, plus one rotation-limited bone so the
/// joint-limit engagement sampler runs at all.
RigSpec _twoArmFoldRig() => RigSpec(
  name: 'anti-fold-test-arms',
  bones: const [
    Bone(id: CatBones.hips, parent: null, pivotX: 0, pivotY: 0, z: 0),
    Bone(
      id: CatBones.armUpperL,
      parent: CatBones.hips,
      pivotX: -30,
      pivotY: 0,
      z: 1,
    ),
    Bone(
      id: CatBones.armLowerL,
      parent: CatBones.armUpperL,
      pivotX: 0,
      pivotY: 40,
      z: 2,
    ),
    Bone(
      id: CatBones.handL,
      parent: CatBones.armLowerL,
      pivotX: 0,
      pivotY: 30,
      z: 3,
    ),
    Bone(
      id: CatBones.armUpperR,
      parent: CatBones.hips,
      pivotX: 30,
      pivotY: 0,
      z: 4,
    ),
    Bone(
      id: CatBones.armLowerR,
      parent: CatBones.armUpperR,
      pivotX: 0,
      pivotY: 40,
      z: 5,
    ),
    Bone(
      id: CatBones.handR,
      parent: CatBones.armLowerR,
      pivotX: 0,
      pivotY: 30,
      z: 6,
      rotationLimit: JointRotationLimit(-3, 3),
    ),
  ],
);

/// One left arm plus an 18-vertex `arm.L.mesh` sleeve. Vertices 0/1/16/17 are
/// the armhole corners the bridge check measures against; parking them far
/// from the shoulder-side cluster (vertices 2..15) makes every raised-pose
/// bridge metric fail at once. All vertices ride the static hips bone so the
/// measured geometry does not depend on the IK solve.
RigSpec _detachedSleeveMeshRig() => RigSpec(
  name: 'detached-sleeve-mesh',
  bones: const [
    Bone(id: CatBones.hips, parent: null, pivotX: 0, pivotY: 0, z: 0),
    Bone(
      id: CatBones.armUpperL,
      parent: CatBones.hips,
      pivotX: -30,
      pivotY: 0,
      z: 1,
    ),
    Bone(
      id: CatBones.armLowerL,
      parent: CatBones.armUpperL,
      pivotX: 0,
      pivotY: 40,
      z: 2,
    ),
    Bone(
      id: CatBones.handL,
      parent: CatBones.armLowerL,
      pivotX: 0,
      pivotY: 30,
      z: 3,
    ),
  ],
  meshes: [
    SkinnedMeshSpec(
      id: 'arm.L.mesh',
      vertices: [
        for (final (x, y) in const <(double, double)>[
          (140, 160), // 0: armhole corner, detached
          (150, 160), // 1: armhole corner, detached
          (-40, 6), // 2..15: shoulder/bicep cluster near the joint
          (-44, 12),
          (-42, 20),
          (-38, 28),
          (-32, 34),
          (-26, 36),
          (-20, 34),
          (-16, 28),
          (-14, 20),
          (-16, 12),
          (-20, 6),
          (-26, 4),
          (-31, 5),
          (-36, 4),
          (140, 170), // 16: armhole corner, detached
          (150, 170), // 17: armhole corner, detached
        ])
          SkinnedMeshVertex([
            MeshInfluence(boneId: CatBones.hips, x: x, y: y, weight: 1),
          ]),
      ],
      boundary: const [
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, //
      ],
      z: 1,
      color: 0xFF223344,
    ),
  ],
);
