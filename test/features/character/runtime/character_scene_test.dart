import 'dart:math' as math;

import 'package:dancing_cats/features/character/engine/autonomic.dart';
import 'package:dancing_cats/features/character/model/affine2d.dart';
import 'package:dancing_cats/features/character/model/bone.dart';
import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/rig_spec.dart';
import 'package:dancing_cats/features/character/runtime/character_scene.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CharacterScene', () {
    test('frameAt resolves a world transform for every bone', () {
      final rig = buildCatInSuitRig();
      final scene = CharacterScene(rig);
      final frame = scene.frameAt(clip: CatClips.shaku, timeSeconds: 0.4);
      expect(frame.world.length, rig.bones.length);
      for (final bone in rig.bones) {
        expect(frame.world.containsKey(bone.id), isTrue);
      }
    });

    test('raised hand targets engage the shoulder girdle', () {
      final scene = CharacterScene(buildCatInSuitRig());
      const clip = Clip(
        name: 'synthetic-raised-hand',
        duration: 1,
        channels: {},
        limbTargets: [
          LimbIkTarget(
            upperBoneId: CatBones.armUpperR,
            lowerBoneId: CatBones.armLowerR,
            endBoneId: CatBones.handR,
            anchorBoneId: CatBones.torso,
            channel: FixedIkTargetChannel(x: 74, y: -96),
          ),
        ],
      );

      final raw = scene.evaluator.evaluate(clip, 0);
      expect(raw.jointOf(CatBones.clavicleR).rotation, 0);

      final posed = scene.poseAt(
        clip: clip,
        timeSeconds: 0,
        includeAutonomic: false,
      );
      final clavicle = posed.jointOf(CatBones.clavicleR);
      final socket = posed.jointOf(CatBones.shoulderSocketR);

      expect(
        clavicle.rotation,
        lessThan(-0.06),
        reason:
            'the shoulder girdle should shrug toward a raised hand before IK '
            'solves the elbow/wrist — a rotation carries the deltoid, '
            'armhole, and ribbon sleeve root with it',
      );
      expect(
        clavicle.rotation,
        greaterThan(-0.2),
        reason: 'the shrug is a nudge, not an over-rotated hinge',
      );
      // The sleeve is a ribbon with a fixed anatomical width profile: no pass
      // may inflate joint scales per pose to fake sleeve volume anymore.
      expect(socket.scaleX, 1);
      expect(socket.scaleY, 1);
      expect(clavicle.scaleX, 1);
      expect(clavicle.scaleY, 1);
    });

    test('pose modifier stack exposes anatomy-safe solve order', () {
      final scene = CharacterScene(buildCatInSuitRig());

      expect(
        scene.poseModifierPasses.map((pass) => pass.id),
        [
          'breath',
          'support-balance',
          'secondary-follow',
          'ear-life',
          'spine-distribute',
          'girdle-follow',
          'shoulder-girdle',
          'limb-ik',
          'joint-limits',
          'contact-lock',
          'sole-flex',
        ],
        reason:
            'body modifiers should run as an ordered constraint pipeline: '
            'primary body timing, balance, secondary follow-through, spine '
            'distribution, shoulder response, IK, then contact',
      );
      expect(
        scene.poseModifierPasses.map((pass) => pass.mix),
        everyElement(1),
      );
      expect(
        scene.poseModifierPasses.map((pass) => pass.description),
        everyElement(isNotEmpty),
      );
    });

    test('joint limits make reversed hinges impossible', () {
      final scene = CharacterScene(buildCatInSuitRig());
      // A clip that demands a BACKWARD knee and a wrap-around elbow.
      const clip = Clip(
        name: 'synthetic-reversed-hinges',
        duration: 1,
        channels: {
          CatBones.legLowerL: SineChannel(bias: 1.4),
          CatBones.armLowerR: SineChannel(bias: 3.05),
        },
      );
      final posed = scene.poseAt(
        clip: clip,
        timeSeconds: 0,
        includeAutonomic: false,
      );
      expect(
        posed.jointOf(CatBones.legLowerL).rotation,
        closeTo(0.1, 1e-9),
        reason: 'a knee can never bend backwards, whatever the clip asks',
      );
      expect(
        posed.jointOf(CatBones.armLowerR).rotation,
        lessThanOrEqualTo(2.9),
        reason: 'an elbow cannot fold past its deepest legal curl (the limit '
            'applies to the WRAPPED angle, so a +2pi representation of a '
            'legal pose is never corrupted)',
      );
    });

    test('dance secondary pass adds tail-tip and ear follow-through', () {
      final scene = CharacterScene(buildCatInSuitRig());
      final clip = CatClips.zanku;
      const samples = 96;
      var maxRootTailExtra = 0.0;
      var maxTipTailExtra = 0.0;
      var maxLeftEarExtra = 0.0;
      var maxRightEarExtra = 0.0;
      var maxTipTailRotation = 0.0;
      var maxEarRotation = 0.0;

      for (var i = 0; i < samples; i++) {
        final phase = i / samples;
        final pose = scene.poseAt(
          clip: clip,
          timeSeconds: clip.duration * phase,
          includeAutonomic: false,
        );
        final rawTailRoot = clip.channels[CatBones.tail0]!.sample(phase);
        final rawTailTip = clip.channels[CatBones.tail6]!.sample(phase);
        final rawEarL = clip.channels[CatBones.earL]!.sample(phase);
        final rawEarR = clip.channels[CatBones.earR]!.sample(phase);
        final tailRoot = pose.jointOf(CatBones.tail0);
        final tailTip = pose.jointOf(CatBones.tail6);
        final earL = pose.jointOf(CatBones.earL);
        final earR = pose.jointOf(CatBones.earR);

        maxRootTailExtra = math.max(
          maxRootTailExtra,
          (tailRoot.rotation - rawTailRoot.rotation).abs(),
        );
        maxTipTailExtra = math.max(
          maxTipTailExtra,
          (tailTip.rotation - rawTailTip.rotation).abs(),
        );
        maxLeftEarExtra = math.max(
          maxLeftEarExtra,
          (earL.rotation - rawEarL.rotation).abs(),
        );
        maxRightEarExtra = math.max(
          maxRightEarExtra,
          (earR.rotation - rawEarR.rotation).abs(),
        );
        maxTipTailRotation = math.max(
          maxTipTailRotation,
          tailTip.rotation.abs(),
        );
        maxEarRotation = math.max(
          maxEarRotation,
          math.max(earL.rotation.abs(), earR.rotation.abs()),
        );
      }

      expect(
        maxTipTailExtra,
        greaterThan(maxRootTailExtra * 2.4),
        reason:
            'secondary tail motion should build toward the tip instead of '
            'swinging as one stiff appendage',
      );
      expect(
        maxTipTailExtra,
        greaterThan(0.035),
        reason: 'tail tip needs visible inertial lag on dance body accents',
      );
      expect(
        maxLeftEarExtra,
        greaterThan(0.01),
        reason: 'left ear should answer the body groove at runtime',
      );
      expect(
        maxRightEarExtra,
        greaterThan(0.01),
        reason: 'right ear should answer the body groove at runtime',
      );
      expect(
        maxTipTailRotation,
        lessThan(0.34),
        reason: 'tail follow-through should stay secondary to the dance',
      );
      expect(
        maxEarRotation,
        lessThan(0.12),
        reason: 'ear follow-through should not become rubbery flapping',
      );
    });

    test('transition contact lock blends outgoing and incoming supports', () {
      const hips = 'hips';
      const footL = 'foot.L';
      const footR = 'foot.R';
      final scene = CharacterScene(
        RigSpec(
          name: 'transition-contact-rig',
          bones: const [
            Bone(id: hips, parent: null, pivotX: 0, pivotY: 0, z: 0),
            Bone(
              id: footL,
              parent: hips,
              pivotX: -20,
              pivotY: 0,
              z: 1,
              drawable: BoneDrawable(
                kind: BoneShapeKind.ellipse,
                width: 10,
                height: 10,
                color: 0xFFFFFFFF,
              ),
            ),
            Bone(
              id: footR,
              parent: hips,
              pivotX: 20,
              pivotY: 0,
              z: 1,
              drawable: BoneDrawable(
                kind: BoneShapeKind.ellipse,
                width: 10,
                height: 10,
                color: 0xFFFFFFFF,
              ),
            ),
          ],
        ),
      );
      const from = Clip(
        name: 'from-contact',
        duration: 1,
        channels: {},
        root: KeyframeRootChannel([
          RootKeyframe(p: 0),
          RootKeyframe(p: 1, dx: 40),
        ]),
        contactSpans: [GroundSpan(footL, 0, 1)],
      );
      const to = Clip(
        name: 'to-contact',
        duration: 1,
        channels: {},
        root: KeyframeRootChannel([
          RootKeyframe(p: 0, dx: 60),
          RootKeyframe(p: 1, dx: -20),
        ]),
        contactSpans: [GroundSpan(footR, 0, 1)],
      );

      final transition = blendedClip(from: from, to: to, weight: 0.25);
      final outgoingOnly = Clip(
        name: 'legacy-outgoing-contact',
        duration: transition.duration,
        channels: transition.channels,
        root: transition.root,
        contactSpans: from.contactSpans,
      );
      final incomingOnly = Clip(
        name: 'legacy-incoming-contact',
        duration: transition.duration,
        channels: transition.channels,
        root: transition.root,
        contactSpans: to.contactSpans,
      );

      final blendedRoot = scene
          .poseAt(
            clip: transition,
            timeSeconds: 0.5,
            includeAutonomic: false,
          )
          .rootDx;
      final outgoingRoot = scene
          .poseAt(
            clip: outgoingOnly,
            timeSeconds: 0.5,
            includeAutonomic: false,
          )
          .rootDx;
      final incomingRoot = scene
          .poseAt(
            clip: incomingOnly,
            timeSeconds: 0.5,
            includeAutonomic: false,
          )
          .rootDx;

      expect(
        (blendedRoot - outgoingRoot).abs(),
        greaterThan(0.5),
        reason:
            'transition contact solving should include some incoming support '
            'instead of behaving like the old outgoing-only midpoint switch',
      );
      expect(
        blendedRoot,
        closeTo(11.5, 1e-9),
        reason:
            'the transition root correction should use source clip contact '
            'anchors with complementary weights, not the blended root channel '
            'as its own contact anchor',
      );
      expect(incomingRoot, outgoingRoot);
    });

    test('public character clips animate in place', () {
      final scene = CharacterScene(buildCatInSuitRig());

      for (final clip in CatClips.all) {
        final frame = scene.frameAt(clip: clip, timeSeconds: 2);
        expect(frame.locomotionX, 0, reason: '${clip.name} should not travel');
        expect(
          scene.locomotionOffset(clip, 2),
          0,
          reason: '${clip.name} should stay centred for the dance showcase',
        );
      }
    });

    test('contact spans damp support-foot drift for one-shot clips', () {
      final scene = CharacterScene(buildCatInSuitRig());

      for (final span in CatClips.kick.contactSpans) {
        final lockedAnchor = _supportPoint(
          scene,
          CatClips.kick,
          span.bone,
          span.start * CatClips.kick.duration,
        );
        final rawAnchor = _rawSupportPoint(
          scene,
          CatClips.kick,
          span.bone,
          span.start * CatClips.kick.duration,
        );

        var lockedDrift = 0.0;
        var rawDrift = 0.0;
        for (var i = 1; i <= 8; i++) {
          final p = span.start + (span.end - span.start) * i / 9;
          lockedDrift = math.max(
            lockedDrift,
            _distance(
              _supportPoint(
                scene,
                CatClips.kick,
                span.bone,
                p * CatClips.kick.duration,
              ),
              lockedAnchor,
            ),
          );
          rawDrift = math.max(
            rawDrift,
            _distance(
              _rawSupportPoint(
                scene,
                CatClips.kick,
                span.bone,
                p * CatClips.kick.duration,
              ),
              rawAnchor,
            ),
          );
        }

        expect(
          lockedDrift,
          lessThan(rawDrift * 0.45),
          reason:
              'kick support correction should visibly reduce '
              '${span.bone} slide without hard-locking into a pop',
        );
        expect(
          lockedDrift,
          lessThan(12),
          reason: 'kick support foot residual slide should stay subtle',
        );
      }
    });

    test('looping performance contact spans keep support drift bounded', () {
      final scene = CharacterScene(buildCatInSuitRig());
      var lockedVerticalDrift = 0.0;
      var lockedLateralDrift = 0.0;

      for (final span in CatClips.shaku.contactSpans) {
        final mid = (span.start + span.end) / 2;
        final width = (span.end - span.start) / 3;
        final lockedAnchor = _supportPoint(
          scene,
          CatClips.shaku,
          span.bone,
          mid * CatClips.shaku.duration,
        );
        for (var i = -3; i <= 3; i++) {
          final p = mid + width * i / 6;
          final locked = _supportPoint(
            scene,
            CatClips.shaku,
            span.bone,
            p * CatClips.shaku.duration,
          );
          lockedVerticalDrift = math.max(
            lockedVerticalDrift,
            (locked.y - lockedAnchor.y).abs(),
          );
          lockedLateralDrift = math.max(
            lockedLateralDrift,
            (locked.x - lockedAnchor.x).abs(),
          );
        }
      }

      expect(
        lockedVerticalDrift,
        lessThan(8.5),
        reason:
            'Shaku supports include visible shoe rolls and scuffs, but the '
            'contact foot should not pop vertically through a hold',
      );
      expect(
        lockedLateralDrift,
        lessThan(38),
        reason:
            'dance support feet may glide laterally with the groove, but not '
            'snap across the body',
      );
    });

    test('the opt-in support-foot world anchor plants local Shaku holds', () {
      final scene = CharacterScene(buildCatInSuitRig());
      double driftOf(Clip clip, GroundSpan span) {
        final spanLength = span.end - span.start;
        final anchorP = span.start + spanLength * 0.5;
        final anchor = _supportPoint(
          scene,
          clip,
          span.bone,
          anchorP * clip.duration,
        );
        var drift = 0.0;
        for (final localP in const [0.4, 0.5, 0.6]) {
          final p = _supportPoint(
            scene,
            clip,
            span.bone,
            (span.start + spanLength * localP) * clip.duration,
          );
          drift = math.max(drift, (p.x - anchor.x).abs());
        }
        return drift;
      }

      // Shaku now uses local support holds: the first bar can reset its support
      // lock before the late right-foot handoff without being treated as skate.
      for (final span in CatClips.shaku.contactSpans) {
        if (span.end - span.start < 0.08) continue;
        expect(
          driftOf(CatClips.shaku, span),
          lessThan(20),
          reason: '${span.bone} should stay planted inside its local hold',
        );
      }
    });

    test('catalogue dance contacts hold stable through mid-stance', () {
      final scene = CharacterScene(buildCatInSuitRig());

      for (final clip in [
        CatClips.zanku,
        CatClips.azonto,
        CatClips.buga,
        CatClips.sekem,
      ]) {
        for (final span in clip.contactSpans) {
          final spanLength = span.end - span.start;
          final anchorP = span.start + spanLength * 0.5;
          final anchor = _supportPoint(
            scene,
            clip,
            span.bone,
            anchorP * clip.duration,
          );

          var lateralDrift = 0.0;
          var verticalDrift = 0.0;
          for (final localP in const [0.4, 0.5, 0.6]) {
            final support = _supportPoint(
              scene,
              clip,
              span.bone,
              (span.start + spanLength * localP) * clip.duration,
            );
            lateralDrift = math.max(
              lateralDrift,
              (support.x - anchor.x).abs(),
            );
            verticalDrift = math.max(
              verticalDrift,
              (support.y - anchor.y).abs(),
            );
          }

          final maxLateralDrift = spanLength <= 0.26 ? 18 : 20;
          expect(
            lateralDrift,
            lessThan(maxLateralDrift),
            reason:
                '${clip.name} ${span.bone} should stay visibly planted while '
                'the pelvis loads the middle of the support span',
          );
          expect(
            verticalDrift,
            lessThan(10),
            reason:
                '${clip.name} ${span.bone} should not pop off the floor during '
                'the middle of a support span',
          );
        }
      }
    });

    test('catalogue dance support keeps hips over the planted shoe', () {
      final scene = CharacterScene(buildCatInSuitRig());

      for (final clip in [
        CatClips.zanku,
        CatClips.azonto,
        CatClips.buga,
        CatClips.sekem,
      ]) {
        final envelope = _catalogueSupportEnvelope(clip);
        for (final span in clip.contactSpans) {
          final spanLength = span.end - span.start;
          for (final localP in const [0.35, 0.5, 0.65]) {
            final timeSeconds =
                (span.start + spanLength * localP) * clip.duration;
            final frame = scene.frameAt(
              clip: clip,
              timeSeconds: timeSeconds,
            );
            final hip = frame.world[CatBones.hips]!.origin;
            final support = _supportPoint(
              scene,
              clip,
              span.bone,
              timeSeconds,
            );

            expect(
              (hip.x - support.x).abs(),
              lessThanOrEqualTo(envelope),
              reason:
                  '${clip.name} ${span.bone} should keep the pelvis loaded '
                  'over the active support foot through mid-stance',
            );
          }
        }
      }
    });

    test(
      'dance keeps broad contact holds floor-plausible and loop continuous',
      () {
        final scene = CharacterScene(buildCatInSuitRig());

        for (final span in CatClips.shaku.contactSpans) {
          final spanLength = span.end - span.start;
          final anchorP = span.start + spanLength * 0.18;
          final anchor = _supportPoint(
            scene,
            CatClips.shaku,
            span.bone,
            anchorP * CatClips.shaku.duration,
          );

          var verticalDrift = 0.0;
          var lateralDrift = 0.0;
          for (var i = 2; i <= 6; i++) {
            final p = span.start + spanLength * i / 8;
            final support = _supportPoint(
              scene,
              CatClips.shaku,
              span.bone,
              p * CatClips.shaku.duration,
            );
            verticalDrift = math.max(
              verticalDrift,
              (support.y - anchor.y).abs(),
            );
            lateralDrift = math.max(
              lateralDrift,
              (support.x - anchor.x).abs(),
            );
          }

          expect(
            verticalDrift,
            lessThan(19),
            reason:
                '${span.bone} may roll and scuff in the current Shaku groove, '
                'but should not visibly launch off the floor during a hold',
          );
          expect(
            lateralDrift,
            lessThan(38),
            reason:
                '${span.bone} can travel laterally with the groove, but '
                'should not snap across the body during a contact hold',
          );
        }

        final lastSpan = CatClips.shaku.contactSpans.last;
        final seamBefore = _supportPoint(
          scene,
          CatClips.shaku,
          lastSpan.bone,
          CatClips.shaku.duration * 31 / 32,
        );
        final seamAfter = _supportPoint(
          scene,
          CatClips.shaku,
          lastSpan.bone,
          CatClips.shaku.duration,
        );
        expect(
          (seamBefore.y - seamAfter.y).abs(),
          lessThan(8.5),
          reason:
              'the loop-pickup support foot should stay vertically grounded '
              'instead of popping off the floor after the low hook',
        );
        final seamCarry = _supportPoint(
          scene,
          CatClips.shaku,
          lastSpan.bone,
          CatClips.shaku.duration / 16,
        );
        expect(
          (seamBefore.y - seamCarry.y).abs(),
          lessThan(8.5),
          reason:
              'matching first/last loop contacts should stay vertically '
              'continuous across the low-hook wrap',
        );
        expect(
          (seamBefore.x - seamCarry.x).abs(),
          lessThan(43),
          reason:
              'the low-hook wrap can carry lateral groove, but should not drag '
              'the support foot across the body',
        );
      },
    );

    test('dance keeps torso attached to hips across the full phrase', () {
      final scene = CharacterScene(buildCatInSuitRig());

      for (var frameIndex = 0; frameIndex < 32; frameIndex += 1) {
        final p = frameIndex / 32;
        final frame = scene.frameAt(
          clip: CatClips.shaku,
          timeSeconds: p * CatClips.shaku.duration,
        );
        final hip = frame.world[CatBones.hips]!.origin;
        final torso = frame.world[CatBones.torso]!.origin;

        expect(
          (torso.x - hip.x).abs(),
          lessThan(1.5),
          reason:
              'the torso and hips should stay visibly attached at dance '
              'frame $frameIndex',
        );
      }
    });

    test('dance keeps planted shoe orientation stable through support', () {
      final scene = CharacterScene(buildCatInSuitRig());

      for (final clip in [
        CatClips.shaku,
        CatClips.danceBackupLeft,
        CatClips.danceBackupRight,
      ]) {
        for (final span in clip.contactSpans) {
          final spanLength = span.end - span.start;
          final anchorFrame = scene.frameAt(
            clip: clip,
            timeSeconds: span.start * clip.duration,
          );
          final anchorRotation = _worldRotation(anchorFrame.world[span.bone]!);

          for (final localP in [0.35, 0.5, 0.65]) {
            final frame = scene.frameAt(
              clip: clip,
              timeSeconds: (span.start + spanLength * localP) * clip.duration,
            );
            final rotation = _worldRotation(frame.world[span.bone]!);

            expect(
              _angleDistance(rotation, anchorRotation),
              lessThan(1.5),
              reason:
                  '${clip.name} ${span.bone} may use an authored toe/heel roll '
                  'while bearing weight, but should not hard-flip through the '
                  'support span',
            );
          }
        }
      }
    });

    test('dance keeps the pelvis inside the stylized support envelope', () {
      final scene = CharacterScene(buildCatInSuitRig());
      final phrase = CatClips.dancePhrase;

      for (var frameIndex = 0; frameIndex < 16; frameIndex++) {
        final p = frameIndex / 16;
        final support = phrase.supportAtPhase(p);
        final frame = scene.frameAt(
          clip: CatClips.shaku,
          timeSeconds: p * CatClips.shaku.duration,
        );
        final hip = frame.world[CatBones.hips]!.origin;
        final supportPoint = _supportPoint(
          scene,
          CatClips.shaku,
          support.footBoneId,
          p * CatClips.shaku.duration,
        );

        expect(
          (hip.x - supportPoint.x).abs(),
          lessThan(110),
          reason:
              'dance frame $frameIndex may use the widened Shaku stance, but '
              'the pelvis should stay inside a plausible support envelope for '
              '${support.footBoneId}',
        );
      }
    });

    test('dance crew keeps the active support groove under the hips', () {
      final scene = CharacterScene(buildCatInSuitRig());

      for (final frameIndex in [16, 19, 20]) {
        final timeSeconds = CatClips.shaku.duration * frameIndex / 32;
        final frame = scene.frameAt(
          clip: CatClips.shaku,
          timeSeconds: timeSeconds,
        );
        final hip = frame.world[CatBones.hips]!.origin;
        final support = _supportPoint(
          scene,
          CatClips.shaku,
          CatBones.footL,
          timeSeconds,
        );

        expect(
          (hip.x - support.x).abs(),
          lessThan(60),
          reason:
              'shaku frame $frameIndex should keep the delayed left support '
              'under the hip until the body actually transfers right',
        );
      }

      for (final frameIndex in [24, 28, 30]) {
        final timeSeconds = CatClips.shaku.duration * frameIndex / 32;
        final frame = scene.frameAt(
          clip: CatClips.shaku,
          timeSeconds: timeSeconds,
        );
        final hip = frame.world[CatBones.hips]!.origin;
        final support = _supportPoint(
          scene,
          CatClips.shaku,
          CatBones.footR,
          timeSeconds,
        );

        expect(
          (hip.x - support.x).abs(),
          lessThan(48),
          reason:
              'shaku frame $frameIndex should keep the late right support '
              'visibly loaded under the hip',
        );
      }

      for (final clip in [
        CatClips.danceBackupLeft,
        CatClips.danceBackupRight,
      ]) {
        for (final frameIndex in [19, 20, 21, 22, 23]) {
          final timeSeconds = CatClips.shaku.duration * frameIndex / 32;
          final frame = scene.frameAt(clip: clip, timeSeconds: timeSeconds);
          final hip = frame.world[CatBones.hips]!.origin;
          final support = _supportPoint(
            scene,
            clip,
            CatBones.footR,
            timeSeconds,
          );

          expect(
            (hip.x - support.x).abs(),
            lessThan(68),
            reason:
                '${clip.name} frame $frameIndex should keep the right-support '
                'groove visibly loaded under the hip, not sliding out from '
                'under the dancer',
          );
        }
      }
    });

    test('dance loads declared torso pockets over support frames', () {
      final scene = CharacterScene(buildCatInSuitRig());
      final phrase = CatClips.dancePhrase;

      for (final support in phrase.supports) {
        final p = support.loadFrame / phrase.frameCount;
        final frame = scene.frameAt(
          clip: CatClips.shaku,
          timeSeconds: p * CatClips.shaku.duration,
        );
        final torsoScaleY = _axisScaleY(frame.world[CatBones.torso]!);

        expect(
          torsoScaleY,
          lessThanOrEqualTo(support.pocketScaleY + 0.025),
          reason:
              '${support.label} should visibly compress the torso at its '
              'declared load frame',
        );
      }
    });

    test('is deterministic: identical scenes resolve identical frames', () {
      final a = CharacterScene(
        buildCatInSuitRig(),
        autonomic: AutonomicLayer(),
      );
      final b = CharacterScene(
        buildCatInSuitRig(),
        autonomic: AutonomicLayer(),
      );
      final fa = a.frameAt(clip: CatClips.zanku, timeSeconds: 0.7);
      final fb = b.frameAt(clip: CatClips.zanku, timeSeconds: 0.7);
      expect(fa.world['head'], fb.world['head']);
      expect(fa.world['hand.L'], fb.world['hand.L']);
      expect(fa.face.eyeOpenLeft, fb.face.eyeOpenLeft);
    });

    test('performance clips keep the head stable over the moving torso', () {
      final scene = CharacterScene(buildCatInSuitRig());

      for (final clip in [
        CatClips.shaku,
        CatClips.kick,
        CatClips.shaku,
        CatClips.danceBackupLeft,
        CatClips.danceBackupRight,
      ]) {
        final headStats = _rotationStats(scene, clip, CatBones.head);
        final torsoStats = _rotationStats(scene, clip, CatBones.torso);
        final headRange = headStats.max - headStats.min;
        final torsoRange = torsoStats.max - torsoStats.min;

        expect(
          headRange,
          lessThan(torsoRange * 0.55),
          reason:
              '${clip.name} should counter-rotate the head instead of letting '
              'the face wobble with the torso',
        );
        expect(
          headRange,
          lessThan(0.24),
          reason:
              '${clip.name} head should bank with the body as a damped slice '
              'of the lean (~10°), never a full rubber bobble',
        );
      }
    });

    test('dance keeps the head rigid while the torso squashes', () {
      final scene = CharacterScene(buildCatInSuitRig());
      const samples = 120;
      var minTorsoScaleY = double.infinity;
      var maxTorsoScaleY = double.negativeInfinity;
      var minHeadY = double.infinity;
      var maxHeadY = double.negativeInfinity;
      var maxHeadStep = 0.0;
      ({double x, double y})? previousHeadOrigin;

      for (var i = 0; i < samples; i++) {
        final frame = scene.frameAt(
          clip: CatClips.shaku,
          timeSeconds: CatClips.shaku.duration * i / samples,
        );
        final head = frame.world[CatBones.head]!;
        final torso = frame.world[CatBones.torso]!;
        final headScaleX = _axisScaleX(head);
        final headScaleY = _axisScaleY(head);
        final torsoScaleY = _axisScaleY(torso);

        minTorsoScaleY = math.min(minTorsoScaleY, torsoScaleY);
        maxTorsoScaleY = math.max(maxTorsoScaleY, torsoScaleY);
        minHeadY = math.min(minHeadY, head.ty);
        maxHeadY = math.max(maxHeadY, head.ty);
        final headOrigin = (x: head.tx, y: head.ty);
        final previous = previousHeadOrigin;
        if (previous != null) {
          final dx = headOrigin.x - previous.x;
          final dy = headOrigin.y - previous.y;
          maxHeadStep = math.max(maxHeadStep, math.sqrt(dx * dx + dy * dy));
        }
        previousHeadOrigin = headOrigin;
        expect(
          headScaleX,
          closeTo(1, 1e-6),
          reason: 'frame $i should not squash/stretch the skull horizontally',
        );
        expect(
          headScaleY,
          closeTo(1, 1e-6),
          reason: 'frame $i should not squash/stretch the skull vertically',
        );
      }

      expect(
        maxTorsoScaleY - minTorsoScaleY,
        greaterThan(0.055),
        reason: 'the test should cover visible but non-rubbery torso squash',
      );
      expect(
        maxHeadY - minHeadY,
        lessThan(36),
        reason:
            'dance head travel should read like a rigid skull riding the body, '
            'not a rubber bobble',
      );
      expect(
        maxHeadStep,
        lessThan(9.8),
        reason:
            'the Shaku chest bite should not whip the rigid skull sideways '
            'between dense frame samples',
      );
    });

    test('limb targets solve hand goals in anchor-bone space', () {
      final scene = CharacterScene(buildCatInSuitRig());
      const targetX = -88.0;
      const targetY = -12.0;
      const clip = Clip(
        name: 'left-hand-target',
        duration: 1,
        channels: {},
        limbTargets: [
          LimbIkTarget(
            upperBoneId: CatBones.armUpperL,
            lowerBoneId: CatBones.armLowerL,
            endBoneId: CatBones.handL,
            anchorBoneId: CatBones.torso,
            bendDirection: -1,
            channel: FixedIkTargetChannel(x: targetX, y: targetY),
          ),
        ],
      );

      final frame = scene.frameAt(clip: clip, timeSeconds: 0);
      final expected = frame.world[CatBones.torso]!.transformPoint(
        targetX,
        targetY,
      );
      final actual = frame.world[CatBones.handL]!.origin;

      expect(
        _distance(actual, expected),
        lessThan(1.5),
        reason:
            'IK should let choreography place a hand in torso space without '
            'manually solving shoulder and elbow rotations',
      );
    });

    test('blink reaches the face via the autonomic layer', () {
      final scene = CharacterScene(buildCatInSuitRig());
      var minOpen = 1.0;
      for (var i = 0; i < 600; i++) {
        final f = scene.frameAt(clip: CatClips.idle, timeSeconds: i * 0.05);
        if (f.face.eyeOpenLeft < minOpen) minOpen = f.face.eyeOpenLeft;
      }
      expect(minOpen, lessThan(0.1));
    });

    test('foot-locked locomotion advances by a constant per-cycle stride', () {
      final scene = CharacterScene(buildCatInSuitRig());
      // groundSpans (with a brief double-support GAP at 0.4..0.6) switch
      // locomotionOffset onto the foot-lock table path: it builds & smooths the
      // per-step travel curve from the legs' world sweep and integrates it.
      const clip = Clip(
        name: 'ground-walk',
        duration: 1,
        channels: {
          CatBones.legUpperL: SineChannel(amplitude: 0.5),
          CatBones.legUpperR: SineChannel(amplitude: 0.5, phase: 0.5),
        },
        groundSpans: [
          GroundSpan(CatBones.footL, 0, 0.4),
          GroundSpan(CatBones.footR, 0.6, 1),
        ],
      );

      final atStart = scene.locomotionOffset(clip, 0);
      final half = scene.locomotionOffset(clip, 0.5);
      final full = scene.locomotionOffset(clip, 1);
      final twoCycles = scene.locomotionOffset(clip, 2);

      expect(
        atStart,
        closeTo(0, 1e-9),
        reason: 'the foot-lock table starts at a zero cumulative offset',
      );
      expect(half.isFinite, isTrue);
      expect(full.isFinite, isTrue);
      // Each whole cycle adds exactly the table's preserved per-cycle stride.
      expect(
        twoCycles - full,
        closeTo(full - atStart, 1e-6),
        reason: 'foot-locked travel advances by a constant per-cycle stride',
      );
      // Memoized + deterministic: a repeat call resolves the same sample.
      expect(scene.locomotionOffset(clip, 0.5), half);
    });

    test('a zero-duration foot-lock clip yields a zero locomotion offset', () {
      final scene = CharacterScene(buildCatInSuitRig());
      const clip = Clip(
        name: 'ground-zero',
        duration: 0,
        channels: {},
        groundSpans: [GroundSpan(CatBones.footL, 0, 1)],
      );
      expect(scene.locomotionOffset(clip, 1), 0);
    });

    test('eyeOpenScale further closes the eyelids on the resolved face', () {
      final scene = CharacterScene(buildCatInSuitRig());
      final open = scene.frameAt(clip: CatClips.shaku, timeSeconds: 0.4);
      final narrowed = scene.frameAt(
        clip: CatClips.shaku,
        timeSeconds: 0.4,
        eyeOpenScale: 0.3,
      );
      expect(
        narrowed.face.eyeOpenLeft,
        closeTo(open.face.eyeOpenLeft * 0.3, 1e-9),
        reason: 'eyeOpenScale multiplies the autonomic eyelid openness',
      );
      expect(
        narrowed.face.eyeOpenRight,
        closeTo(open.face.eyeOpenRight * 0.3, 1e-9),
      );
    });

    test('a root-upper IK chain solves against the root-rotation fallback', () {
      // An IK target whose UPPER bone is the rig root drives the parentId == null
      // arm of _parentWorldRotation (the parent-world rotation falls back to the
      // pose's root rotation).
      final rig = RigSpec(
        name: 'ik-root',
        bones: const [
          Bone(
            id: 'root',
            parent: null,
            pivotX: 100,
            pivotY: 60,
            z: 0,
            drawable: BoneDrawable(
              kind: BoneShapeKind.capsule,
              width: 12,
              height: 50,
              dy: 25,
              color: 0xFF808080,
            ),
          ),
          Bone(
            id: 'mid',
            parent: 'root',
            pivotX: 0,
            pivotY: 50,
            z: 1,
            drawable: BoneDrawable(
              kind: BoneShapeKind.capsule,
              width: 10,
              height: 50,
              dy: 25,
              color: 0xFF707070,
            ),
          ),
          Bone(
            id: 'tip',
            parent: 'mid',
            pivotX: 0,
            pivotY: 50,
            z: 2,
            drawable: BoneDrawable(
              kind: BoneShapeKind.ellipse,
              width: 12,
              height: 12,
              color: 0xFF606060,
            ),
          ),
        ],
      );
      final scene = CharacterScene(rig);
      const targetX = 30.0;
      const targetY = 70.0;
      const clip = Clip(
        name: 'root-ik',
        duration: 1,
        channels: {},
        limbTargets: [
          LimbIkTarget(
            upperBoneId: 'root',
            lowerBoneId: 'mid',
            endBoneId: 'tip',
            anchorBoneId: 'root',
            channel: FixedIkTargetChannel(x: targetX, y: targetY),
          ),
        ],
      );

      final rest = scene.frameAt(
        clip: const Clip(name: 'rest', duration: 1, channels: {}),
        timeSeconds: 0,
      );
      final solved = scene.frameAt(clip: clip, timeSeconds: 0);
      // The target is authored in the (root) anchor space at solve time, which
      // matches the un-rotated rest root.
      final expected = rest.world['root']!.transformPoint(targetX, targetY);
      final solvedTip = solved.world['tip']!.origin;
      final restTip = rest.world['tip']!.origin;

      expect(
        _distance(solvedTip, expected),
        lessThan(3),
        reason: 'root-upper IK still reaches the anchor-space target',
      );
      expect(
        _distance(solvedTip, expected),
        lessThan(_distance(restTip, expected)),
        reason: 'the IK pulls the end bone toward the target vs the rest pose',
      );
    });
  });
}

({double min, double max}) _rotationStats(
  CharacterScene scene,
  Clip clip,
  String boneId,
) {
  const samples = 48;
  var min = double.infinity;
  var max = double.negativeInfinity;
  for (var i = 0; i < samples; i++) {
    final frame = scene.frameAt(
      clip: clip,
      timeSeconds: clip.duration * i / samples,
    );
    final rotation = _worldRotation(frame.world[boneId]!);
    min = math.min(min, rotation);
    max = math.max(max, rotation);
  }
  return (min: min, max: max);
}

double _worldRotation(Affine2D transform) =>
    math.atan2(transform.b, transform.a);

double _axisScaleX(Affine2D transform) =>
    math.sqrt(transform.a * transform.a + transform.b * transform.b);

double _axisScaleY(Affine2D transform) =>
    math.sqrt(transform.c * transform.c + transform.d * transform.d);

double _angleDistance(double a, double b) =>
    math.atan2(math.sin(a - b), math.cos(a - b)).abs();

({double x, double y}) _supportPoint(
  CharacterScene scene,
  Clip clip,
  String boneId,
  double timeSeconds,
) {
  final frame = scene.frameAt(clip: clip, timeSeconds: timeSeconds);
  final transform = frame.world[boneId]!;
  final drawable = scene.rig.bone(boneId)!.drawable!;
  return transform.transformPoint(
    drawable.dx,
    drawable.dy + drawable.height / 2,
  );
}

({double x, double y}) _rawSupportPoint(
  CharacterScene scene,
  Clip clip,
  String boneId,
  double timeSeconds,
) {
  final world = scene.solver.solve(scene.evaluator.evaluate(clip, timeSeconds));
  final transform = world[boneId]!;
  final drawable = scene.rig.bone(boneId)!.drawable!;
  return transform.transformPoint(
    drawable.dx,
    drawable.dy + drawable.height / 2,
  );
}

double _catalogueSupportEnvelope(Clip clip) => switch (clip.name) {
  'zanku' => 58,
  'sekem' => 62,
  'azonto' => 70,
  'buga' => 70,
  _ => 76,
};

double _distance(({double x, double y}) a, ({double x, double y}) b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  return math.sqrt(dx * dx + dy * dy);
}
