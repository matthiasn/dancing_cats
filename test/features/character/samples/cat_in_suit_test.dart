import 'dart:math' as math;

import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/runtime/character_scene.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildCatInSuitRig', () {
    final rig = buildCatInSuitRig();

    test('builds a valid skeleton with a face', () {
      expect(rig.name, 'cat_in_suit');
      expect(rig.face, isNotNull);
      expect(rig.face!.anchorBoneId, CatBones.head);
      // Topological order covers every bone (no missing parents thrown).
      expect(rig.topoOrder.length, rig.bones.length);
    });

    test('the head and neck carry drawables and the head anchors the face', () {
      expect(rig.bone(CatBones.head)?.drawable, isNotNull);
      expect(rig.bone(CatBones.neck)?.drawable, isNotNull);
    });

    test('a white shirt collar frames the neck under the tie', () {
      final shirtColor = rig.bone(CatBones.shirtV)?.drawable?.color;
      for (final id in [CatBones.collarL, CatBones.collarR]) {
        final collar = rig.bone(id);
        expect(collar?.parent, CatBones.torso);
        // Same off-white shirt fabric as the chest V, so the head reads as
        // rising out of a collar rather than pasted onto the jacket.
        expect(collar?.drawable?.color, shirtColor);
        // Flat-shaded so the key can't streak the small bright shape.
        expect(collar?.drawable?.celShade, isFalse);
      }
      // The two points mirror left/right about the centreline.
      expect(
        rig.bone(CatBones.collarL)!.pivotX,
        -rig.bone(CatBones.collarR)!.pivotX,
      );
    });

    test('hand-parented cuffs expose the wrists during crossed-arm poses', () {
      final shirtColor = rig.bone(CatBones.shirtV)?.drawable?.color;
      final cuffL = rig.bone(CatBones.wristCuffL);
      final cuffR = rig.bone(CatBones.wristCuffR);

      expect(cuffL?.parent, CatBones.handL);
      expect(cuffR?.parent, CatBones.handR);
      expect(cuffL?.drawable?.color, shirtColor);
      expect(cuffR?.drawable?.color, shirtColor);
      expect(cuffL?.z, lessThan(rig.bone(CatBones.handL)!.z));
      expect(cuffR?.z, lessThan(rig.bone(CatBones.handR)!.z));
    });

    test('elbow creases read as subtle sleeve shadows, not hard bars', () {
      final creaseL = rig.bone(CatBones.armElbowCreaseL);
      final creaseR = rig.bone(CatBones.armElbowCreaseR);

      expect(creaseL?.parent, CatBones.armLowerL);
      expect(creaseR?.parent, CatBones.armLowerR);
      expect(creaseL?.drawable?.height, lessThan(creaseL!.drawable!.width));
      expect(creaseR?.drawable?.height, lessThan(creaseR!.drawable!.width));
      expect(creaseL.drawable!.width, lessThanOrEqualTo(5));
      expect(creaseR.drawable!.width, lessThanOrEqualTo(5));
      expect(creaseL.drawable!.height, lessThanOrEqualTo(0.9));
      expect(creaseR.drawable!.height, lessThanOrEqualTo(0.9));
      expect(creaseL.drawable!.outlineColor, isNull);
      expect(creaseR.drawable!.outlineColor, isNull);
      expect(creaseL.drawable!.outlineWidth, 0);
      expect(creaseR.drawable!.outlineWidth, 0);
      expect(creaseL.z, greaterThan(rig.bone(CatBones.armUpperL)!.z));
      expect(creaseR.z, greaterThan(rig.bone(CatBones.armUpperR)!.z));
    });

    test('sleeve values separate crossed arms from the jacket shell', () {
      final torso = rig.bone(CatBones.torso)!.drawable!.color;
      final farSleeve = rig.ribbons
          .singleWhere((ribbon) => ribbon.id == 'arm.R.ribbon')
          .color;
      final nearSleeve = rig.ribbons
          .singleWhere((ribbon) => ribbon.id == 'arm.L.ribbon')
          .color;

      expect(
        _luma(farSleeve) - _luma(torso),
        greaterThan(24),
        reason:
            'the far sleeve must not melt into the navy jacket during Shaku '
            'crosses',
      );
      expect(
        _luma(nearSleeve) - _luma(farSleeve),
        greaterThan(14),
        reason:
            'near and far sleeves need a value step so crossed forearms read '
            'as two separate limbs',
      );
    });

    test('sleeves keep a heroic taper instead of a sausage tube', () {
      final arm = rig.ribbons.singleWhere((ribbon) {
        return ribbon.id == 'arm.L.ribbon';
      });
      final bicepPlane = rig.bone(CatBones.armBicepL)!.drawable!;
      final forearmPlane = rig.bone(CatBones.armForearmL)!.drawable!;
      final cuff = rig.bone(CatBones.wristCuffL)!.drawable!;
      final hand = rig.bone(CatBones.handL)!.drawable!;

      expect(
        arm.jointBoneIds,
        const [
          CatBones.armUpperL,
          CatBones.armBicepL,
          CatBones.armLowerL,
          CatBones.armForearmL,
          CatBones.handL,
        ],
      );
      expect(arm.halfWidths, const [7.0, 10.0, 4.4, 6.0, 2.9]);
      expect(arm.formRound, isFalse);
      expect(arm.roundCaps, isFalse);
      expect(arm.halfWidths[1], greaterThan(arm.halfWidths.first));
      expect(
        arm.halfWidths[2],
        lessThan(arm.halfWidths[1] * 0.5),
        reason: 'the elbow should pinch clearly below the bicep mass',
      );
      expect(
        arm.halfWidths.last,
        lessThan(arm.halfWidths[3] * 0.5),
        reason: 'the wrist must taper after the forearm before the cuff break',
      );
      expect(
        arm.halfWidths[3],
        greaterThan(arm.halfWidths[2] * 1.35),
        reason: 'the forearm should wedge back out after the elbow pinch',
      );
      for (final plane in [bicepPlane, forearmPlane]) {
        expect(plane.width, lessThan(arm.halfWidths[1] * 0.45));
        expect(plane.height, greaterThan(plane.width * 3));
        expect(plane.outlineColor, isNull);
        expect(plane.outlineWidth, 0);
        expect(plane.celShade, isFalse);
      }
      expect(cuff.width, lessThan(hand.width));
      expect(cuff.width, lessThanOrEqualTo(18));
    });

    test('shoes carry a subtle sole edge for footwork readability', () {
      expect(rig.bone(CatBones.shoeHighlightL)?.parent, CatBones.footL);
      expect(rig.bone(CatBones.shoeHighlightR)?.parent, CatBones.footR);
      expect(rig.bone(CatBones.shoeHighlightL)?.drawable?.width, 25);
      expect(
        rig.bone(CatBones.shoeHighlightL)?.drawable?.width,
        lessThan(rig.bone(CatBones.footL)?.drawable?.width ?? 0),
      );
      // A wider but still subtle sole edge, NOT a bright strip that reads as a
      // skeletal mark in the stage-lit shoe.
      expect(rig.bone(CatBones.shoeHighlightR)?.drawable?.color, 0xFF3C4058);
    });

    test('the sole edge never lowers the shoe contact point', () {
      // The contact/grounding solver keys off the lowest drawn point of the
      // foot; the sole-edge highlight must stay above the sole bottom so it
      // can't shift grounding or the support-foot lock.
      for (final pair in const [
        (CatBones.footR, CatBones.shoeHighlightR),
        (CatBones.footL, CatBones.shoeHighlightL),
      ]) {
        final shoe = rig.bone(pair.$1)!.drawable!;
        final welt = rig.bone(pair.$2)!.drawable!;
        expect(
          welt.dy + welt.height / 2,
          lessThan(shoe.dy + shoe.height / 2),
          reason: 'sole edge stays above the sole bottom',
        );
      }
    });

    test('hips are the single root', () {
      final roots = rig.bones.where((b) => b.parent == null).toList();
      expect(roots.length, 1);
      expect(roots.single.id, CatBones.hips);
    });

    test('uses soft surfaces for limbs, tail, jacket, and hips', () {
      expect(
        rig.ribbons.map((r) => r.id),
        containsAll([
          'tail.ribbon',
          'leg.L.ribbon',
          'leg.R.ribbon',
          'arm.L.ribbon',
          'arm.R.ribbon',
        ]),
      );
      expect(
        rig.meshes.map((m) => m.id),
        containsAll([
          'jacket.mesh',
          'hips.mesh',
        ]),
      );
      expect(rig.ribbonHiddenBoneIds, contains(CatBones.tail3));
      expect(rig.hiddenDrawableBoneIds, contains(CatBones.legLowerL));
      expect(rig.hiddenDrawableBoneIds, contains(CatBones.torso));
      expect(rig.hiddenDrawableBoneIds, contains(CatBones.hips));
    });

    test('can build a distinct fur palette for paired cats', () {
      final rig = buildCatInSuitRig(palette: CatInSuitPalette.silverTabby);

      expect(
        rig.bone(CatBones.head)?.drawable?.color,
        CatInSuitPalette.silverTabby.fur,
      );
      expect(
        rig.bone(CatBones.handL)?.drawable?.color,
        CatInSuitPalette.silverTabby.fur,
      );
      expect(
        rig.ribbons.singleWhere((r) => r.id == 'tail.ribbon').color,
        CatInSuitPalette.silverTabby.fur,
      );
      expect(rig.face?.muzzleColor, CatInSuitPalette.silverTabby.muzzle);
    });

    test('dark brown palette reads near black', () {
      final rig = buildCatInSuitRig(palette: CatInSuitPalette.darkBrown);

      expect(
        rig.bone(CatBones.head)?.drawable?.color,
        CatInSuitPalette.darkBrown.fur,
      );
      expect(CatInSuitPalette.darkBrown.fur, 0xFF302820);
      expect(CatInSuitPalette.darkBrown.furDark, 0xFF17110D);
      expect(rig.face?.browColor, CatInSuitPalette.darkBrown.brow);
      expect(CatInSuitPalette.darkBrown.brow, 0xFFF1E2C9);
    });

    test('can build a lead variant with stronger limbs', () {
      final base = buildCatInSuitRig();
      final lead = buildCatInSuitRig(
        legWidthScale: kDanceLeadLegWidthScale,
        armWidthScale: kDanceLeadArmWidthScale,
      );

      final baseLeg = base.ribbons.singleWhere((r) => r.id == 'leg.L.ribbon');
      final leadLeg = lead.ribbons.singleWhere((r) => r.id == 'leg.L.ribbon');
      final baseArm = base.ribbons.singleWhere((r) => r.id == 'arm.L.ribbon');
      final leadArm = lead.ribbons.singleWhere((r) => r.id == 'arm.L.ribbon');
      final baseTail = base.ribbons.singleWhere((r) => r.id == 'tail.ribbon');
      final leadTail = lead.ribbons.singleWhere((r) => r.id == 'tail.ribbon');

      // Athletic trouser profile: full thigh, sharp knee pinch, fitted calf,
      // then a narrow ankle. The knee/ankle taper keeps negative space between
      // legs in crouched dance poses without drifting into bodybuilder mass.
      expect(baseLeg.halfWidths, const [12.4, 11.1, 7.2, 9.2, 5.5]);
      expect(
        leadLeg.halfWidths.first,
        closeTo(12.4 * kDanceLeadLegWidthScale, 0.001),
      );
      // The calf control (index 3) remains fuller than the knee pinch, but both
      // are slimmer than the old trouser tube.
      expect(
        leadLeg.halfWidths[3],
        closeTo(9.2 * kDanceLeadLegWidthScale, 0.001),
      );
      expect(
        leadLeg.halfWidths[3],
        greaterThan(leadLeg.halfWidths[2]),
        reason: 'the calf must bulge past the knee dip',
      );
      expect(baseArm.halfWidths, const [7.0, 10.0, 4.4, 6.0, 2.9]);
      expect(
        leadArm.halfWidths[1],
        closeTo(10.0 * kDanceLeadArmWidthScale, 0.001),
      );
      expect(
        leadArm.halfWidths[2],
        lessThan(leadArm.halfWidths[1] * 0.6),
        reason: 'the elbow valley should keep crossed arms readable',
      );
      expect(
        leadArm.halfWidths[3],
        closeTo(6.0 * kDanceLeadArmWidthScale, 0.001),
      );
      expect(leadTail.halfWidths, baseTail.halfWidths);
    });
  });

  group('CatClips', () {
    test('exposes the show-focused public motion set', () {
      expect(
        CatClips.all.map((c) => c.name).toSet(),
        {
          'kick',
          'shaku',
          'zanku',
          'azonto',
          'buga',
          'pouncingCat',
          'sekem',
          'idle',
        },
      );
    });

    test('cyclic clips loop and one-shots do not', () {
      expect(CatClips.shaku.loop, isTrue);
      expect(CatClips.zanku.loop, isTrue);
      expect(CatClips.azonto.loop, isTrue);
      expect(CatClips.buga.loop, isTrue);
      expect(CatClips.pouncingCat.loop, isTrue);
      expect(CatClips.sekem.loop, isTrue);
      expect(CatClips.idle.loop, isTrue);
      expect(CatClips.kick.loop, isFalse);
    });

    test('shaku drives both legs and both arms', () {
      final channels = CatClips.shaku.channels;
      expect(channels.containsKey(CatBones.legUpperL), isTrue);
      expect(channels.containsKey(CatBones.legUpperR), isTrue);
      expect(channels.containsKey(CatBones.armUpperL), isTrue);
      expect(channels.containsKey(CatBones.armUpperR), isTrue);
    });

    test('kick and shaku drive the expected performance bones', () {
      expect(CatClips.kick.channels.containsKey(CatBones.legUpperR), isTrue);
      expect(CatClips.kick.channels.containsKey(CatBones.armUpperL), isTrue);
      expect(CatClips.shaku.channels.containsKey(CatBones.legUpperL), isTrue);
      expect(CatClips.shaku.channels.containsKey(CatBones.armLowerR), isTrue);
      expect(CatClips.shaku.channels.containsKey(CatBones.tail6), isTrue);
      expect(CatClips.shaku.channels.containsKey(CatBones.earL), isTrue);
      expect(CatClips.shaku.channels.containsKey(CatBones.earR), isTrue);
      expect(
        CatClips.shaku.limbTargets.map((target) => target.endBoneId),
        [CatBones.handL, CatBones.handR, CatBones.footL, CatBones.footR],
      );
    });

    test('shaku ears flick independently while staying bounded', () {
      final earL = CatClips.shaku.channels[CatBones.earL]!;
      final earR = CatClips.shaku.channels[CatBones.earR]!;
      var minL = double.infinity;
      var maxL = double.negativeInfinity;
      var minR = double.infinity;
      var maxR = double.negativeInfinity;
      var maxPairDifference = 0.0;

      for (var i = 0; i <= 32; i++) {
        final p = i / 32;
        final leftPose = earL.sample(p);
        final rightPose = earR.sample(p);
        final l = leftPose.rotation;
        final r = rightPose.rotation;
        minL = math.min(minL, l);
        maxL = math.max(maxL, l);
        minR = math.min(minR, r);
        maxR = math.max(maxR, r);
        maxPairDifference = math.max(maxPairDifference, (l - r).abs());
      }

      expect(
        maxL - minL,
        greaterThan(0.02),
        reason: 'left ear should keep a subtle bounded flick',
      );
      expect(
        maxR - minR,
        greaterThan(0.02),
        reason: 'right ear should keep a subtle bounded flick',
      );
      expect(
        maxPairDifference,
        greaterThan(0.03),
        reason: 'ears should not move as a mirrored rigid head ornament',
      );
      expect(
        [minL.abs(), maxL.abs(), minR.abs(), maxR.abs()],
        everyElement(lessThan(0.16)),
        reason:
            'ear flicks must stay subtle enough that the deep bases remain '
            'hidden behind the crown',
      );
    });

    test(
      'backup dance clips remain public show-role clips',
      () {
        expect(CatClips.danceBackupLeft.name, 'danceBackupLeft');
        expect(CatClips.danceBackupRight.name, 'danceBackupRight');
        expect(CatClips.danceBackupLeft.duration, CatClips.shaku.duration);
        expect(CatClips.danceBackupRight.duration, CatClips.shaku.duration);
      },
    );

    test(
      'shaku support lock delays handoff until the visible load arrives',
      () {
        final phrase = CatClips.dancePhrase;
        final spans = CatClips.shaku.contactSpans;
        expect(phrase.frameCount, 32);
        expect(spans.map((span) => span.bone), [
          CatBones.footL,
          CatBones.footL,
          CatBones.footR,
          CatBones.footL,
        ]);
        expect(spans.map((span) => span.start), [
          0,
          10 / 32,
          22 / 32,
          30.125 / 32,
        ]);
        expect(spans.map((span) => span.end), [
          10 / 32,
          22 / 32,
          30.125 / 32,
          1,
        ]);
        expect(spans[1].end, greaterThan(20 / 32));
        expect(spans[2].start, greaterThan(20 / 32));
        expect(spans[2].end, greaterThan(30 / 32));
        expect(phrase.supports.map((support) => support.label), [
          'left-foot Shaku low pocket',
          'right-foot answer pocket',
          'left-foot loop pickup',
        ]);
        expect(phrase.supportAtFrame(4).freeFootBoneId, CatBones.footR);
        expect(phrase.supportAtFrame(20).freeFootBoneId, CatBones.footL);
        expect(phrase.supportAtFrame(32).footBoneId, CatBones.footL);
        expect(phrase.supports.map((support) => support.loadFrame), [
          4,
          20,
          31,
        ]);
        expect(phrase.supports.map((support) => support.releaseFrame), [
          8,
          24,
          32,
        ]);
        expect(phrase.sections.map((section) => section.name), [
          'Shaku pocket',
          'Shaku rebound',
          'answer pocket',
          'toe-flick release',
          'loop pickup',
        ]);
        expect(phrase.moves.map((move) => move.name), [
          'lead Shaku pocket hit',
          'lead rebound shoulder scoop',
          'right-side camera answer',
          'right-foot groove pocket',
          'left-side camera answer',
          'toe-flick hook reset',
        ]);
        expect(phrase.sectionAtFrame(4).name, 'Shaku pocket');
        expect(phrase.sectionAtFrame(20).name, 'answer pocket');
        expect(phrase.sectionAtFrame(31).name, 'loop pickup');
        expect(phrase.moveAtFrame(4).featuredDancer, 'lead');
        expect(phrase.moveAtFrame(12).name, 'right-side camera answer');
        expect(phrase.moveAtFrame(20).name, 'right-foot groove pocket');
        expect(phrase.moveAtFrame(24).featuredDancer, 'left');
        expect(phrase.moveAtFrame(31).name, 'toe-flick hook reset');
      },
    );

    test('shaku crosses wrists, opens elbows, and recovers as shaku', () {
      final phrase = CatClips.dancePhrase;
      final shaku = CatClips.shaku;
      final handL = _targetFor(shaku, CatBones.handL).channel;
      final handR = _targetFor(shaku, CatBones.handR).channel;
      final footL = _targetFor(shaku, CatBones.footL).channel;
      final footR = _targetFor(shaku, CatBones.footR).channel;

      expect(
        shaku.supportFootWorldAnchorStrength,
        greaterThanOrEqualTo(0.74),
        reason:
            'Shaku support feet need enough world anchor to let the torso '
            'pocket read without skate during the arm crosses',
      );

      for (final frame in [0, 4, 8, 16, 20, 24, 32]) {
        final p = frame / phrase.frameCount;
        final leftFoot = footL.sample(p);
        final rightFoot = footR.sample(p);
        expect(
          rightFoot.x - leftFoot.x,
          greaterThan(114),
          reason:
              'Shaku frame $frame should keep a broad base under the bulky '
              'suit body instead of crossing the feet under the hips',
        );
      }

      final wristCrossLeft = handL.sample(17 / phrase.frameCount);
      final wristCrossRight = handR.sample(17 / phrase.frameCount);
      expect(wristCrossLeft.x, greaterThan(12));
      expect(wristCrossRight.x, lessThan(-12));
      expect(
        (wristCrossLeft.x - wristCrossRight.x).abs(),
        greaterThan(35),
        reason:
            'Shaku should cross at the wrists in separated lanes without '
            'returning to the old impossible folded-forearm reach',
      );
      expect(
        wristCrossLeft.y - wristCrossRight.y,
        lessThan(-35),
        reason:
            'one Shaku wrist should ride higher while the opposite paw stays '
            'lower, keeping the crossing arms readable as an X',
      );
      expect(
        wristCrossLeft.y,
        lessThan(-42),
        reason: 'the wrist-cross should live at chest height',
      );

      final sweepLeft = handL.sample(21 / phrase.frameCount);
      final sweepRight = handR.sample(21 / phrase.frameCount);
      expect(sweepLeft.x, lessThan(-8));
      expect(sweepRight.x, greaterThan(8));
      expect(
        sweepRight.x - sweepLeft.x,
        greaterThan(25),
        reason:
            'every second Shaku beat should roll through separated high/low '
            'lanes instead of overlapping both paws on the sternum',
      );

      final sideHitLeft = handL.sample(22 / phrase.frameCount);
      final sideHitRight = handR.sample(22 / phrase.frameCount);
      expect(sideHitLeft.x, lessThan(0));
      expect(sideHitRight.x, greaterThan(0));
      expect(
        sideHitRight.x - sideHitLeft.x,
        greaterThan(16),
        reason:
            'the Shaku release beat should hit as a wrist-roll cross rather '
            'than a physically vague open-elbow pump',
      );

      for (final frame in [6, 11, 14, 19, 22, 27, 30]) {
        final left = handL.sample(frame / phrase.frameCount);
        final right = handR.sample(frame / phrase.frameCount);
        expect(
          left.x,
          lessThan(-36),
          reason:
              'Shaku frame $frame should keep the left fist off the jacket '
              'centreline so the arm does not merge into the torso shell',
        );
        expect(
          right.x,
          greaterThan(36),
          reason:
              'Shaku frame $frame should keep the right fist off the jacket '
              'centreline so the arm does not merge into the torso shell',
        );
        expect(
          right.x - left.x,
          greaterThan(72),
          reason:
              'Shaku frame $frame should carve negative space between the '
              'guard fists and the suit body',
        );
      }

      final recoveryCrossLeft = handL.sample(29 / phrase.frameCount);
      final recoveryCrossRight = handR.sample(29 / phrase.frameCount);
      expect(
        recoveryCrossLeft.x,
        lessThan(0),
        reason:
            'the final phrase should recover through shaku arm vocabulary, '
            'not a generic forward punch',
      );
      expect(recoveryCrossLeft.y, greaterThan(0));
      expect(
        recoveryCrossRight.x,
        greaterThan(0),
        reason:
            'the opposite paw should stay in the compact wrist-roll phrase, '
            'not open into a generic chest pump',
      );
      expect(recoveryCrossRight.y, lessThan(-34));
      expect(
        recoveryCrossRight.x - recoveryCrossLeft.x,
        greaterThan(30),
        reason:
            'the final recovery should keep the high/low Shaku lanes legible',
      );

      expect(
        _targetDistance(handL, 28, 29),
        lessThan(36),
        reason:
            'the final shaku recovery should travel smoothly instead of '
            'snapping through the loop pickup',
      );

      final loopLeft = handL.sample(32 / phrase.frameCount);
      final loopRight = handR.sample(32 / phrase.frameCount);
      expect(loopLeft.x, lessThan(-25));
      expect(loopRight.x, greaterThan(25));
      expect(
        loopLeft.y,
        greaterThan(-36),
        reason: 'the next loop should recover to the low open-ready left hand',
      );
      expect(
        loopRight.y,
        lessThan(-42),
        reason:
            'the opposite hand should recover to the high half of the Shaku '
            'high/low loop, not collapse into a same-plane guard',
      );
    });

    test('zanku taps, digs low, pops the knee, and lands into a stomp', () {
      final phrase = CatClips.dancePhrase;
      final zanku = CatClips.zanku;
      final footL = _targetFor(zanku, CatBones.footL).channel;
      final footR = _targetFor(zanku, CatBones.footR).channel;
      final handL = _targetFor(zanku, CatBones.handL).channel;
      final handR = _targetFor(zanku, CatBones.handR).channel;
      final hips = zanku.channels[CatBones.hips]!;
      final torso = zanku.channels[CatBones.torso]!;

      expect(
        zanku.supportFootWorldAnchorStrength,
        greaterThanOrEqualTo(0.82),
        reason:
            'Zanku support feet need a firmer world anchor so the stomp reads '
            'as a plant instead of a side-view slide',
      );

      final rightLift = footR.sample(1 / phrase.frameCount);
      final rightFlick = footR.sample(2 / phrase.frameCount);
      final rightRecoil = footR.sample(3 / phrase.frameCount);
      final rightStomp = zanku.root.sample(4 / phrase.frameCount);
      final rightSettle = zanku.root.sample(5 / phrase.frameCount);
      final rightFlickLift = zanku.root.sample(2 / phrase.frameCount);
      expect(
        rightLift.y,
        inInclusiveRange(108, 112),
        reason:
            'Zanku should show a compact pre-stomp pickup before the heel-toe '
            'flick, not a walking stride',
      );
      expect(
        rightFlick.x,
        inInclusiveRange(82, 86),
        reason:
            'Zanku should show a readable heel-toe knock outside the trouser '
            'mass without becoming a side kick',
      );
      expect(rightFlick.y, inInclusiveRange(122, 125));
      expect(
        rightRecoil.x,
        lessThan(rightFlick.x - 10),
        reason: 'the free foot should scrape back under the body after tapping',
      );
      expect(
        rightStomp.dy - rightFlickLift.dy,
        inInclusiveRange(21, 33),
        reason:
            'Zanku should drop into a stronger grounded stomp pocket, not hop '
            'or float after the right-leg flick',
      );
      expect(
        rightStomp.dx,
        inInclusiveRange(20, 25),
        reason:
            'the right Zanku stomp should carry the pelvis toward support '
            'without throwing the whole body into a side-view plank',
      );
      expect(
        rightSettle.dx,
        inInclusiveRange(14, 21),
        reason:
            'Zanku should dwell over the right support for a frame after the '
            'plant while staying compact enough for profile balance',
      );
      expect(
        rightSettle.dy,
        greaterThan(rightFlickLift.dy + 5),
        reason:
            'the frame after the right stomp should still carry visible body '
            'weight before the rebound',
      );
      final rightHipLead = hips.sample(3.75 / phrase.frameCount).rotation;
      final rightHipOnStomp = hips.sample(4 / phrase.frameCount).rotation;
      expect(
        rightHipLead,
        greaterThan(0.3),
        reason:
            'the right Zanku stomp should be led by a hip commit just before '
            'the foot lands',
      );
      expect(
        rightHipLead,
        greaterThan(rightHipOnStomp),
        reason: 'the hip should lead the stomp instead of peaking late',
      );
      final rightChestOnStomp = torso.sample(4 / phrase.frameCount).rotation;
      final rightChestFollow = torso.sample(4.9 / phrase.frameCount).rotation;
      expect(
        rightChestOnStomp,
        greaterThan(-0.24),
        reason:
            'the chest should not be fully parked in its counter-rotation on '
            'the same frame as the hip-led stomp',
      );
      expect(
        rightChestFollow,
        lessThan(rightChestOnStomp - 0.08),
        reason:
            'the chest should keep answering after the hip instead of landing '
            'as a simultaneous full-body pose',
      );

      final leftLift = footL.sample(21 / phrase.frameCount);
      final leftFlick = footL.sample(22 / phrase.frameCount);
      final leftRecoil = footL.sample(23 / phrase.frameCount);
      final leftStomp = zanku.root.sample(24 / phrase.frameCount);
      final leftSettle = zanku.root.sample(25 / phrase.frameCount);
      final leftFlickLift = zanku.root.sample(22 / phrase.frameCount);
      expect(
        leftLift.y,
        inInclusiveRange(104, 110),
        reason:
            'Zanku should show a compact pre-stomp pickup before the heel-toe '
            'flick, not a walking stride',
      );
      expect(
        leftFlick.x,
        inInclusiveRange(-85, -80),
        reason:
            'Zanku should show a readable heel-toe knock outside the trouser '
            'mass without becoming a side kick',
      );
      expect(leftFlick.y, inInclusiveRange(122, 125));
      expect(
        leftRecoil.x,
        greaterThan(leftFlick.x + 10),
        reason: 'the free foot should scrape back under the body after tapping',
      );
      expect(
        leftStomp.dy - leftFlickLift.dy,
        inInclusiveRange(24, 36),
        reason:
            'Zanku should drop into a stronger grounded stomp pocket, not hop '
            'or float after the left-leg flick',
      );
      expect(
        leftStomp.dx,
        inInclusiveRange(-27, -20),
        reason:
            'the left Zanku stomp should carry the pelvis toward support '
            'without throwing the whole body into a side-view plank',
      );
      expect(
        leftSettle.dx,
        inInclusiveRange(-21, -14),
        reason:
            'the mirrored Zanku plant should also dwell over support instead '
            'of rebounding immediately through centre or overbalancing',
      );
      expect(
        leftSettle.dy,
        greaterThan(leftFlickLift.dy + 5),
        reason:
            'the frame after the left stomp should still carry visible body '
            'weight before the rebound',
      );
      final leftHipLead = hips.sample(23.75 / phrase.frameCount).rotation;
      final leftHipOnStomp = hips.sample(24 / phrase.frameCount).rotation;
      expect(
        leftHipLead,
        lessThan(-0.28),
        reason:
            'the left Zanku stomp should be led by a mirrored hip commit just '
            'before the foot lands',
      );
      expect(
        leftHipLead,
        lessThan(leftHipOnStomp),
        reason:
            'the mirrored hip should lead the stomp instead of peaking late',
      );
      final leftChestOnStomp = torso.sample(24 / phrase.frameCount).rotation;
      final leftChestFollow = torso.sample(24.9 / phrase.frameCount).rotation;
      expect(
        leftChestOnStomp,
        lessThan(0.24),
        reason:
            'the mirrored chest should also avoid arriving fully on the hip '
            'stomp frame',
      );
      expect(
        leftChestFollow,
        greaterThan(leftChestOnStomp + 0.08),
        reason:
            'the mirrored chest counter should roll in after the hip commit',
      );

      final freezeLeftFoot = footL.sample(28 / phrase.frameCount);
      final freezeRightFoot = footR.sample(28 / phrase.frameCount);
      expect(
        freezeRightFoot.y,
        greaterThanOrEqualTo(120),
        reason: 'the exact Zanku freeze should keep the right foot grounded',
      );
      expect(
        freezeRightFoot.x,
        greaterThan(60),
        reason:
            'the exact Zanku freeze needs a clear right support foot under the '
            'COM, not a tiny hidden contact',
      );
      expect(
        freezeLeftFoot.x,
        lessThan(-72),
        reason:
            'the exact Zanku freeze should show a left heel-toe knock, not '
            'collapse into a neutral/walking stance or a side kick',
      );
      expect(
        freezeLeftFoot.y,
        inInclusiveRange(123, 126),
        reason: 'the scraped freeze foot should skim the floor',
      );

      final freezeLeftHand = handL.sample(28 / phrase.frameCount);
      final freezeRightHand = handR.sample(28 / phrase.frameCount);
      expect(freezeLeftHand.x, lessThan(-68));
      expect(
        freezeLeftHand.y,
        inInclusiveRange(-10, -2),
        reason:
            'the exact Zanku freeze should punch the left counter-hit down/out '
            'from a rib guard, not dangle below the jacket',
      );
      expect(
        freezeRightHand.y,
        lessThan(-50),
        reason:
            'the exact Zanku freeze should keep the off hand high as a compact '
            'rib/chest guard, not hang neutrally below the jacket',
      );

      final promotedKick = footR.sample(26 / phrase.frameCount);
      expect(
        promotedKick.y,
        inInclusiveRange(82, 86),
        reason:
            'Zanku needs one legible knock-door accent in the phrase; otherwise '
            'the move reads as a generic in-place groove',
      );
      expect(
        promotedKick.x,
        inInclusiveRange(24, 32),
        reason:
            'the promoted accent should lift forward under the body, not become '
            'a wide side kick',
      );

      for (final frame in [2, 4, 14, 26, 28, 30]) {
        expect(
          handL.sample(frame / phrase.frameCount).x,
          lessThan(-35),
          reason:
              'Zanku left hand must stay in the left lane on frame $frame; '
              'cross-body IK makes the shoulders fold impossibly',
        );
        expect(
          handR.sample(frame / phrase.frameCount).x,
          greaterThan(35),
          reason:
              'Zanku right hand must stay in the right lane on frame $frame; '
              'cross-body IK makes the shoulders fold impossibly',
        );
      }
    });

    test('azonto keeps a grounded wide base under the point-out groove', () {
      final phrase = CatClips.dancePhrase;
      final azonto = CatClips.azonto;
      final footL = _targetFor(azonto, CatBones.footL).channel;
      final footR = _targetFor(azonto, CatBones.footR).channel;
      final handL = _targetFor(azonto, CatBones.handL).channel;
      final handR = _targetFor(azonto, CatBones.handR).channel;
      final hips = azonto.channels[CatBones.hips]!;
      final torso = azonto.channels[CatBones.torso]!;

      for (final frame in [0, 4, 8, 12, 16, 20, 24, 28]) {
        final p = frame / phrase.frameCount;
        final left = footL.sample(p);
        final right = footR.sample(p);
        expect(
          left.x,
          lessThan(-40),
          reason:
              'Azonto frame $frame needs the left foot visibly on its own side, '
              'not crossing under the hips',
        );
        expect(
          right.x,
          greaterThan(40),
          reason:
              'Azonto frame $frame needs the right foot visibly on its own side, '
              'not crossing under the hips',
        );
        expect(
          right.x - left.x,
          greaterThan(84),
          reason:
              'Azonto frame $frame should keep a support polygon under the hip '
              'swivel instead of balancing on bunched feet',
        );
        expect(left.y, greaterThanOrEqualTo(100));
        expect(right.y, greaterThanOrEqualTo(100));
      }

      for (final frame in [0, 4, 12, 18, 22, 26, 32]) {
        final p = frame / phrase.frameCount;
        final left = handL.sample(p);
        final right = handR.sample(p);
        expect(
          left.x,
          lessThan(-28),
          reason:
              'Azonto frame $frame should keep the tucked left wrist off the '
              'jacket centreline so the arm does not read as a suit blob',
        );
        expect(
          right.x,
          greaterThan(28),
          reason:
              'Azonto frame $frame should keep the tucked right wrist off the '
              'jacket centreline so the arm does not read as a suit blob',
        );
      }

      final tuck = azonto.root.sample(2 / phrase.frameCount);
      final pointHit = azonto.root.sample(4 / phrase.frameCount);
      expect(
        pointHit.dy - tuck.dy,
        greaterThan(18),
        reason:
            'Azonto point-outs should ride a visible knee/hip pocket instead of '
            'reading as arms over an idle body',
      );
      expect(
        hips.sample(4 / phrase.frameCount).rotation,
        greaterThan(0.65),
        reason: 'the Azonto point hit should be driven from the waist',
      );
      expect(
        torso.sample(4.5 / phrase.frameCount).rotation,
        lessThan(-0.34),
        reason:
            'the chest should follow as a delayed counter-rotation, not land '
            'on the same frame as the hips',
      );
    });

    test(
      'buga keeps prep hands separated instead of folding arms through belly',
      () {
        final phrase = CatClips.dancePhrase;
        final buga = CatClips.buga;
        final handL = _targetFor(buga, CatBones.handL).channel;
        final handR = _targetFor(buga, CatBones.handR).channel;

        for (final frame in [0, 4, 8, 11, 16, 20, 24, 27]) {
          final p = frame / phrase.frameCount;
          final left = handL.sample(p);
          final right = handR.sample(p);

          expect(
            right.x - left.x,
            greaterThan(55),
            reason:
                'Buga prep frame $frame should keep hands as separated rib '
                'guards, not a centreline clasp that implies impossible elbows',
          );
          expect(
            left.y,
            lessThan(-25),
            reason: 'left hand should stay above the belt on prep frame $frame',
          );
          expect(
            right.y,
            lessThan(-25),
            reason:
                'right hand should stay above the belt on prep frame $frame',
          );
        }

        final rightPresentOffHand = handL.sample(12 / phrase.frameCount);
        expect(
          rightPresentOffHand.x,
          lessThan(-40),
          reason:
              'when the right arm presents, the left hand must drop outside/back '
              'instead of clasping at the belly',
        );
        expect(rightPresentOffHand.y, lessThan(-24));

        final leftPresentOffHand = handR.sample(28 / phrase.frameCount);
        expect(
          leftPresentOffHand.x,
          greaterThan(40),
          reason:
              'when the left arm presents, the right hand must drop outside/back '
              'instead of clasping at the belly',
        );
        expect(leftPresentOffHand.y, lessThan(-24));
      },
    );

    test('buga raises the presenting arm, overshoots, then releases', () {
      final phrase = CatClips.dancePhrase;
      final buga = CatClips.buga;
      final handL = _targetFor(buga, CatBones.handL).channel;
      final handR = _targetFor(buga, CatBones.handR).channel;

      for (final frame in [10, 12, 14]) {
        final right = handR.sample(frame / phrase.frameCount);
        expect(
          right.x,
          greaterThan(68),
          reason: 'right Buga present should be visible by frame $frame',
        );
        expect(right.y, lessThan(-64));
      }

      for (final frame in [26, 28, 30]) {
        final left = handL.sample(frame / phrase.frameCount);
        expect(
          left.x,
          lessThan(-68),
          reason: 'left Buga present should be visible by frame $frame',
        );
        expect(left.y, lessThan(-64));
      }

      expect(
        handR.sample(13 / phrase.frameCount).y,
        lessThan(handR.sample(12 / phrase.frameCount).y),
        reason: 'right Buga present should overshoot past the hit',
      );
      expect(
        handL.sample(29 / phrase.frameCount).y,
        lessThan(handL.sample(28 / phrase.frameCount).y),
        reason: 'left Buga present should overshoot past the hit',
      );
      expect(
        _targetDistance(handR, 14, 15),
        greaterThan(40),
        reason:
            'right Buga show-off should release after the readable peak instead '
            'of freezing through the next groove count',
      );
      expect(
        _targetDistance(handL, 30, 31),
        greaterThan(40),
        reason:
            'left Buga show-off should release after the readable peak instead '
            'of freezing through the next groove count',
      );

      expect(
        buga.supportFootWorldAnchorStrength,
        greaterThanOrEqualTo(0.82),
        reason:
            'Buga show-off hits need a strong support plant so the side reach '
            'does not read as a fall',
      );
      final rootHit = buga.root.sample(12 / phrase.frameCount);
      final rootMirrorHit = buga.root.sample(28 / phrase.frameCount);
      expect(
        rootHit.dy,
        greaterThanOrEqualTo(0),
        reason:
            'the right-arm Buga hit should rise from the load without lifting '
            'the body above the planted feet',
      );
      expect(
        rootMirrorHit.dy,
        greaterThanOrEqualTo(0),
        reason:
            'the mirrored Buga hit should stay similarly planted at the peak',
      );
      expect(
        rootHit.dx.abs(),
        lessThanOrEqualTo(27),
        reason:
            'Buga should celebrate from a planted stance, not throw the root '
            'far outside the feet on the right-arm hit',
      );
      expect(
        rootMirrorHit.dx.abs(),
        lessThanOrEqualTo(27),
        reason:
            'the mirrored Buga hit should stay similarly planted instead of '
            'becoming a lateral fall',
      );
      final legHit = buga.channels[CatBones.legLowerL]!.sample(
        12 / phrase.frameCount,
      );
      expect(
        legHit.rotation,
        lessThan(-0.68),
        reason:
            'Buga hit knees should remain flexed enough to carry weight, not '
            'lock straight at the celebration peak',
      );
      final footL = _targetFor(buga, CatBones.footL).channel;
      final footR = _targetFor(buga, CatBones.footR).channel;
      final rightHitSupport = footL.sample(12 / phrase.frameCount);
      final rightHitCounter = footR.sample(12 / phrase.frameCount);
      expect(rightHitSupport.x, lessThanOrEqualTo(-103));
      expect(rightHitSupport.y, greaterThanOrEqualTo(103));
      expect(rightHitCounter.x, greaterThanOrEqualTo(105));
      expect(rightHitCounter.y, greaterThanOrEqualTo(103));

      final leftHitSupport = footR.sample(28 / phrase.frameCount);
      final leftHitCounter = footL.sample(28 / phrase.frameCount);
      expect(leftHitSupport.x, greaterThanOrEqualTo(107));
      expect(leftHitSupport.y, greaterThanOrEqualTo(103));
      expect(leftHitCounter.x, lessThanOrEqualTo(-105));
      expect(leftHitCounter.y, greaterThanOrEqualTo(103));
      expect(buga.contactSpans[0].bone, CatBones.footR);
      expect(buga.contactSpans[0].start, 0);
      expect(buga.contactSpans[0].end, 0.25);
      expect(buga.contactSpans[1].bone, CatBones.footL);
      expect(buga.contactSpans[1].start, 0.25);
      expect(buga.contactSpans[1].end, 0.5);
    });

    test(
      'sekem widens the stance and alternates own-side low and high hits',
      () {
        final phrase = CatClips.dancePhrase;
        final sekem = CatClips.sekem;
        final footL = _targetFor(sekem, CatBones.footL).channel;
        final footR = _targetFor(sekem, CatBones.footR).channel;
        final handL = _targetFor(sekem, CatBones.handL).channel;
        final handR = _targetFor(sekem, CatBones.handR).channel;
        final footLRotation = sekem.channels[CatBones.footL]!;
        final footRRotation = sekem.channels[CatBones.footR]!;
        final handLRotation = sekem.channels[CatBones.handL]!;
        final handRRotation = sekem.channels[CatBones.handR]!;

        final leftPlant = footL.sample(0);
        final rightPlant = footR.sample(4 / phrase.frameCount);
        expect(leftPlant.x, lessThan(-56));
        expect(rightPlant.x, greaterThan(56));
        expect(leftPlant.y, greaterThanOrEqualTo(102));
        expect(rightPlant.y, greaterThanOrEqualTo(102));
        expect(
          sekem.supportFootWorldAnchorStrength,
          greaterThanOrEqualTo(0.78),
          reason:
              'Sekem needs a firmer support anchor so the wider stomp base '
              'does not skate under the side-view body lean',
        );

        final leftPlantHand = handL.sample(0);
        final rightPlantHand = handR.sample(0);
        expect(
          leftPlantHand.x,
          lessThan(-62),
          reason:
              'Sekem left hand should stay in the left anatomical lane; '
              'cross-body targets make the arms fold impossibly',
        );
        expect(
          leftPlantHand.y,
          greaterThan(32),
          reason: 'the low Sekem hand should visibly sit on the beltline',
        );
        expect(
          rightPlantHand.x,
          greaterThan(100),
          reason:
              'the opposite hand should paddle outward in its own lane so '
              'the move reads as Sekem without folded forearms',
        );
        expect(rightPlantHand.y, inInclusiveRange(-42, -34));

        final leftPullbackApproach = handL.sample(2 / phrase.frameCount);
        final leftPullback = handL.sample(2.55 / phrase.frameCount);
        final rightRecover = handR.sample(2.55 / phrase.frameCount);
        expect(
          leftPullbackApproach.x,
          lessThan(-84),
          reason:
              'the delayed Sekem pullback may not sweep through the torso '
              'while the paw is still approaching its late hit',
        );
        expect(
          leftPullback.x,
          inInclusiveRange(-100, -92),
          reason:
              'the left Sekem offbeat should rebound up in the left lane on '
              'its delayed wrist follow-through, not on the integer frame',
        );
        expect(
          leftPullback.x,
          lessThan(-64),
          reason: 'left Sekem sweep must never cross the torso centreline',
        );
        expect(
          rightRecover.x,
          greaterThan(92),
          reason:
              'the right Sekem recover must stay outside the right shoulder '
              'line; centerline targets create impossible folded arms',
        );

        final rightPickup = footR.sample(2 / phrase.frameCount);
        expect(
          rightPickup.x,
          inInclusiveRange(64, 68),
          reason:
              'Sekem pickup should scrape outside the trouser mass while '
              'staying low; lifting the foot high would turn it into a side-kick',
        );
        expect(
          rightPickup.y,
          inInclusiveRange(100, 103),
          reason: 'Sekem should skim the floor, not lift into a side-kick',
        );

        final leftPoint = handL.sample(4.55 / phrase.frameCount);
        final rightSweep = handR.sample(4.55 / phrase.frameCount);
        expect(
          leftPoint.x,
          lessThan(-100),
          reason:
              'the next plant should swap: left hand becomes the outward '
              'paddle',
        );
        expect(
          leftPoint.y,
          inInclusiveRange(-42, -34),
          reason:
              'the outward Sekem hit should sit at chest/shoulder level, '
              'not punch into an impossible high fold',
        );
        expect(
          rightSweep.x,
          greaterThan(62),
          reason:
              'the next plant should swap levels while right hand stays in '
              'the right anatomical lane',
        );
        expect(
          rightSweep.y,
          greaterThan(32),
          reason: 'the low Sekem hand should visibly sit on the beltline',
        );
        final rightSweepInward = handR.sample(6.55 / phrase.frameCount);
        expect(
          rightSweepInward.x,
          greaterThan(92),
          reason: 'right Sekem sweep must never cross the torso centreline',
        );
        final leftPickup = footL.sample(6 / phrase.frameCount);
        expect(
          leftPickup.x,
          inInclusiveRange(-68, -64),
          reason:
              'Sekem pickup should scrape outside the trouser mass while '
              'staying low; lifting the foot high would turn it into a side-kick',
        );
        expect(
          leftPickup.y,
          inInclusiveRange(100, 103),
          reason: 'Sekem should skim the floor, not lift into a side-kick',
        );
        expect(
          handLRotation.sample(4 / phrase.frameCount).rotation,
          inInclusiveRange(0.18, 0.26),
          reason:
              'Sekem needs a loose paddle wrist, not a twisted high-punch '
              'fist',
        );
        expect(
          handRRotation.sample(4 / phrase.frameCount).rotation,
          inInclusiveRange(0.28, 0.36),
          reason:
              'Sekem needs loose wrist rotation on the waist scoop, not '
              'stiff jogging fists',
        );
        expect(
          footRRotation.sample(2 / phrase.frameCount).rotation,
          inInclusiveRange(-0.18, -0.14),
          reason:
              'the low right scrape should mark the toe without becoming a kick',
        );
        expect(
          footLRotation.sample(6 / phrase.frameCount).rotation,
          inInclusiveRange(0.14, 0.18),
          reason:
              'the low left scrape should mark the toe without becoming a kick',
        );

        final leftGroove = sekem.root.sample(0);
        final leftSettle = sekem.root.sample(1 / phrase.frameCount);
        final leftRecoil = sekem.root.sample(2 / phrase.frameCount);
        final rightPreload = sekem.root.sample(3 / phrase.frameCount);
        final rightGroove = sekem.root.sample(4 / phrase.frameCount);
        final hips = sekem.channels[CatBones.hips]!;
        final torso = sekem.channels[CatBones.torso]!;
        expect(
          leftGroove.dx,
          inInclusiveRange(-25, -20),
          reason:
              'Sekem should visibly dwell over the left plant without '
              'overthrowing the body in quarter/profile review',
        );
        expect(
          rightGroove.dx,
          inInclusiveRange(20, 25),
          reason:
              'Sekem should visibly dwell over the right plant without '
              'overthrowing the body in quarter/profile review',
        );
        expect(
          leftGroove.dy - leftRecoil.dy,
          inInclusiveRange(26, 32),
          reason:
              'Sekem needs a grounded downbeat squash without the old '
              'overcompressed side-view shell shape',
        );
        expect(
          leftSettle.dy,
          greaterThan(leftRecoil.dy + 12),
          reason:
              'Sekem should catch weight for a frame after the plant instead of '
              'rebounding evenly from downbeat to offbeat',
        );
        expect(
          leftSettle.dx,
          lessThan(leftRecoil.dx - 4),
          reason:
              'the one-frame settle should remain over the planted side before '
              'the body travels to the next support',
        );
        expect(
          rightPreload.dx,
          greaterThan(leftRecoil.dx + 14),
          reason:
              'Sekem should pre-load the next support before the foot plants, '
              'not wait for the plant frame to move the pelvis',
        );
        expect(
          rightGroove.dy,
          greaterThan(rightPreload.dy + 9.5),
          reason:
              'the next plant still needs a visibly deeper squash than the '
              'pre-load frame',
        );
        final rightHipLead = hips.sample(3.75 / phrase.frameCount).rotation;
        final rightHipPlant = hips.sample(4 / phrase.frameCount).rotation;
        expect(
          rightHipLead,
          greaterThan(rightHipPlant),
          reason:
              'the hip should lead into the right Sekem plant instead of '
              'peaking on the same frame as the foot',
        );
        final rightChestOnPlant = torso.sample(4 / phrase.frameCount).rotation;
        final rightChestFollow = torso.sample(4.9 / phrase.frameCount).rotation;
        expect(
          rightChestFollow,
          lessThan(rightChestOnPlant - 0.06),
          reason:
              'the torso should counter after the hip lead instead of landing '
              'as one rigid suit shape',
        );

        final leftHipLead = hips.sample(7.75 / phrase.frameCount).rotation;
        final leftHipPlant = hips.sample(8 / phrase.frameCount).rotation;
        expect(
          leftHipLead,
          lessThan(leftHipPlant),
          reason:
              'the mirrored hip commit should also arrive before the plant '
              'frame',
        );
      },
    );

    test('sekem hand targets never create a folded forearm cross', () {
      final phrase = CatClips.dancePhrase;
      final sekem = CatClips.sekem;
      final handL = _targetFor(sekem, CatBones.handL).channel;
      final handR = _targetFor(sekem, CatBones.handR).channel;

      for (var frame = 0; frame <= phrase.frameCount; frame += 2) {
        final p = frame / phrase.frameCount;
        final left = handL.sample(p);
        final right = handR.sample(p);

        expect(
          left.x,
          lessThanOrEqualTo(-64),
          reason:
              'Sekem frame $frame must keep the left paw outside the left '
              'shoulder line; centerline hands read as impossible arm folding',
        );
        expect(
          right.x,
          greaterThanOrEqualTo(64),
          reason:
              'Sekem frame $frame must keep the right paw outside the right '
              'shoulder line; centerline hands read as impossible arm folding',
        );
        expect(
          right.x - left.x,
          greaterThan(135),
          reason:
              'Sekem frame $frame should show two separate arm lanes, not a '
              'clasp or X through the jacket',
        );
      }
    });

    test('sekem solved arms bend through one anatomical lane', () {
      final scene = CharacterScene(buildCatInSuitRig());
      for (
        var frame = 0;
        frame <= CatClips.dancePhrase.frameCount;
        frame += 2
      ) {
        final p = frame / CatClips.dancePhrase.frameCount;
        final solved = scene.frameAt(
          clip: CatClips.sekem,
          timeSeconds: p * CatClips.sekem.duration,
        );
        final w = solved.world;

        double horizontalFold(String shoulder, String elbow, String hand) {
          final shoulderX = w[shoulder]!.origin.x;
          final elbowX = w[elbow]!.origin.x;
          final handX = w[hand]!.origin.x;
          return (elbowX - shoulderX) * (handX - elbowX);
        }

        final leftShoulder = w[CatBones.armUpperL]!.origin.x;
        final leftElbow = w[CatBones.armLowerL]!.origin.x;
        final leftHand = w[CatBones.handL]!.origin.x;
        final rightShoulder = w[CatBones.armUpperR]!.origin.x;
        final rightElbow = w[CatBones.armLowerR]!.origin.x;
        final rightHand = w[CatBones.handR]!.origin.x;

        expect(
          horizontalFold(
            CatBones.armUpperL,
            CatBones.armLowerL,
            CatBones.handL,
          ),
          greaterThanOrEqualTo(0),
          reason:
              'Sekem frame $frame should not reverse the left forearm back '
              'through its upper arm; that renders as an impossible folded X',
        );
        expect(
          horizontalFold(
            CatBones.armUpperR,
            CatBones.armLowerR,
            CatBones.handR,
          ),
          greaterThanOrEqualTo(0),
          reason:
              'Sekem frame $frame should not reverse the right forearm back '
              'through its upper arm; that renders as an impossible folded X',
        );
        expect(
          leftElbow,
          lessThanOrEqualTo(leftShoulder),
          reason:
              'Sekem frame $frame should keep the left elbow outside/left of '
              'its shoulder; inward elbows make the sleeve cross the torso',
        );
        expect(
          leftHand,
          lessThanOrEqualTo(leftElbow),
          reason:
              'Sekem frame $frame should keep the left paw past the left '
              'elbow, not folded back inward across the jacket',
        );
        expect(
          rightElbow,
          greaterThanOrEqualTo(rightShoulder),
          reason:
              'Sekem frame $frame should keep the right elbow outside/right of '
              'its shoulder; inward elbows make the sleeve cross the torso',
        );
        expect(
          rightHand,
          greaterThanOrEqualTo(rightElbow),
          reason:
              'Sekem frame $frame should keep the right paw past the right '
              'elbow, not folded back inward across the jacket',
        );
      }
    });

    test('pouncing cat compresses, pushes, lands, and rebounds compactly', () {
      final phrase = CatClips.dancePhrase;
      final pounce = CatClips.pouncingCat;
      final handL = _targetFor(pounce, CatBones.handL).channel;
      final handR = _targetFor(pounce, CatBones.handR).channel;
      final footL = _targetFor(pounce, CatBones.footL).channel;
      final footR = _targetFor(pounce, CatBones.footR).channel;

      final crouch = pounce.root.sample(4 / phrase.frameCount);
      final push = pounce.root.sample(8 / phrase.frameCount);
      final landing = pounce.root.sample(12 / phrase.frameCount);
      final rebound = pounce.root.sample(16 / phrase.frameCount);
      final mirrorCrouch = pounce.root.sample(20 / phrase.frameCount);
      final mirrorPush = pounce.root.sample(24 / phrase.frameCount);

      expect(
        crouch.dy - push.dy,
        greaterThan(55),
        reason: 'the cat hook should show a clear compress-to-push contrast',
      );
      expect(
        landing.dy,
        greaterThan(push.dy + 55),
        reason: 'the landing should squash after the push accent',
      );
      expect(
        landing.dx,
        inInclusiveRange(10, 18),
        reason:
            'the first landing should settle to the right side while staying '
            'inside the planted catch base',
      );
      expect(
        rebound.dy,
        greaterThan(push.dy + 32),
        reason: 'the rebound should stay in the dance pocket after the landing',
      );
      expect(
        mirrorCrouch.dy - mirrorPush.dy,
        greaterThan(55),
        reason: 'the mirrored cell should keep the same compress-to-push hook',
      );

      final firstAccentLeft = handL.sample(8 / phrase.frameCount);
      final firstAccentRight = handR.sample(8 / phrase.frameCount);
      expect(
        firstAccentLeft.x,
        inInclusiveRange(8, 28),
        reason:
            'the first cat accent should keep the left paw as a bent chest '
            'guard, not fire both paws straight forward',
      );
      expect(
        firstAccentRight.x,
        inInclusiveRange(84, 100),
        reason:
            'the outer paw should lead as a compact elbow/wrist accent, not a '
            'long straight attack pose',
      );
      expect(firstAccentLeft.y, lessThan(-68));
      expect(firstAccentRight.y, inInclusiveRange(-60, -48));

      final mirrorAccentLeft = handL.sample(24 / phrase.frameCount);
      final mirrorAccentRight = handR.sample(24 / phrase.frameCount);
      expect(
        mirrorAccentLeft.x,
        inInclusiveRange(-100, -84),
        reason:
            'the mirrored outer paw should stay compact and dance-like, not '
            'turn into a long side punch',
      );
      expect(
        mirrorAccentRight.x,
        inInclusiveRange(-28, -8),
        reason:
            'the mirrored hit should keep the right paw as a bent chest guard',
      );
      expect(
        (mirrorAccentRight.x - mirrorAccentLeft.x).abs(),
        inInclusiveRange(70, 100),
        reason:
            'the mirrored accent needs clear lead paw plus guard separation '
            'without a full attack reach',
      );

      for (final frame in [4, 12, 20, 28]) {
        final p = frame / phrase.frameCount;
        final leftFoot = footL.sample(p);
        final rightFoot = footR.sample(p);
        expect(
          rightFoot.x - leftFoot.x,
          greaterThan(58),
          reason: 'pounce frame $frame needs a stable stance, not crossed feet',
        );
        expect(
          leftFoot.y,
          greaterThanOrEqualTo(98),
          reason: 'pounce frame $frame should stay grounded on the left foot',
        );
        expect(
          rightFoot.y,
          greaterThanOrEqualTo(98),
          reason: 'pounce frame $frame should stay grounded on the right foot',
        );
      }

      final firstCatchLeft = footL.sample(12 / phrase.frameCount);
      final firstCatchRight = footR.sample(12 / phrase.frameCount);
      expect(
        firstCatchRight.x - firstCatchLeft.x,
        greaterThan(116),
        reason:
            'the first pounce landing should catch on a wide base, not under '
            'a drifting torso',
      );
      final mirrorCatchLeft = footL.sample(28 / phrase.frameCount);
      final mirrorCatchRight = footR.sample(28 / phrase.frameCount);
      expect(
        mirrorCatchRight.x - mirrorCatchLeft.x,
        greaterThan(116),
        reason:
            'the mirrored pounce landing should catch on a wide base, not under '
            'a drifting torso',
      );
      expect(
        pounce.supportFootWorldAnchorStrength,
        greaterThanOrEqualTo(0.78),
        reason:
            'pounce landings need a stronger planted-foot anchor so the catch '
            'reads as loaded rather than skating',
      );
      expect(
        landing.dx.abs(),
        lessThan((firstCatchRight.x - firstCatchLeft.x) * 0.16),
        reason:
            'the first pounce landing root should sit inside the catch base, '
            'not outside the planted feet',
      );
      final mirrorLanding = pounce.root.sample(28 / phrase.frameCount);
      expect(
        mirrorLanding.dx.abs(),
        lessThan((mirrorCatchRight.x - mirrorCatchLeft.x) * 0.16),
        reason:
            'the mirrored pounce landing root should also sit inside the catch '
            'base instead of falling sideways',
      );

      final firstGuardLeft = handL.sample(12 / phrase.frameCount);
      final firstGuardRight = handR.sample(12 / phrase.frameCount);
      expect(firstGuardLeft.x, lessThan(-44));
      expect(firstGuardRight.x, greaterThan(48));
      final mirrorGuardLeft = handL.sample(28 / phrase.frameCount);
      final mirrorGuardRight = handR.sample(28 / phrase.frameCount);
      expect(mirrorGuardLeft.x, lessThan(-48));
      expect(mirrorGuardRight.x, greaterThan(44));

      final rightPush = footR.sample(8 / phrase.frameCount);
      final leftPush = footL.sample(24 / phrase.frameCount);
      expect(rightPush.x, inInclusiveRange(70, 86));
      expect(leftPush.x, inInclusiveRange(-86, -70));
      expect(
        rightPush.y,
        inInclusiveRange(76, 86),
        reason:
            'the push should lift modestly through the pounce hook without a '
            'long side kick',
      );
      expect(leftPush.y, inInclusiveRange(76, 86));

      expect(
        _targetDistance(handL, 12, 14),
        lessThan(58),
        reason: 'the groove rebound should have an intermediate arm stage',
      );
      expect(
        _targetDistance(handL, 14, 16),
        lessThan(70),
        reason:
            'the cat groove should rebound smoothly rather than teleport arms',
      );
    });

    test('show clips animate in place', () {
      expect(CatClips.kick.locomotes, isFalse);
      expect(CatClips.shaku.locomotes, isFalse);
      expect(CatClips.zanku.locomotes, isFalse);
      expect(CatClips.azonto.locomotes, isFalse);
      expect(CatClips.buga.locomotes, isFalse);
      expect(CatClips.pouncingCat.locomotes, isFalse);
      expect(CatClips.sekem.locomotes, isFalse);
      expect(CatClips.idle.locomotes, isFalse);
    });
  });
}

LimbIkTarget _targetFor(Clip clip, String endBoneId) =>
    clip.limbTargets.singleWhere((target) => target.endBoneId == endBoneId);

double _luma(int argb) {
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _targetDistance(IkTargetChannel channel, int fromFrame, int toFrame) {
  final from = channel.sample(fromFrame / CatClips.dancePhrase.frameCount);
  final to = channel.sample(toFrame / CatClips.dancePhrase.frameCount);
  final dx = to.x - from.x;
  final dy = to.y - from.y;
  return math.sqrt(dx * dx + dy * dy);
}
