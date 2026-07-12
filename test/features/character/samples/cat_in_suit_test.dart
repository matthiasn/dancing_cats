import 'dart:math' as math;

import 'package:dancing_cats/features/character/model/affine2d.dart';
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
      final collarL = rig.bone(CatBones.collarL);
      final collarR = rig.bone(CatBones.collarR);
      // Chest-parented (2026-07-05): as clavicle children the wings rode
      // the shoulder see-saw — a probe measured 27-43 unit VERTICAL splits
      // between the two wings, which the owner saw live as "the collar is
      // flying around". A shirt collar sits on the chest.
      expect(collarL?.parent, CatBones.chest);
      expect(collarR?.parent, CatBones.chest);
      for (final collar in [collarL, collarR]) {
        // Same off-white shirt fabric as the chest V, so the head reads as
        // rising out of a collar rather than pasted onto the jacket.
        expect(collar?.drawable?.color, shirtColor);
        // Flat-shaded so the key can't streak the small bright shape.
        expect(collar?.drawable?.celShade, isFalse);
      }
      // The two points mirror left/right about the centreline.
      expect(
        collarL!.pivotX,
        -collarR!.pivotX,
      );
    });

    test('shoulder controls break up the jacket shell', () {
      final chest = rig.bone(CatBones.chest);
      final clavicleL = rig.bone(CatBones.clavicleL);
      final clavicleR = rig.bone(CatBones.clavicleR);
      final socketL = rig.bone(CatBones.shoulderSocketL);
      final socketR = rig.bone(CatBones.shoulderSocketR);

      // The trunk is a two-joint spine: torso (lumbar) → chest (thoracic).
      // The shoulder girdle hangs off the chest so a thoracic counter-bend
      // carries the shoulders/arms/head, not the whole jacket shell.
      expect(chest?.parent, CatBones.torso);
      expect(chest?.drawable, isNull);
      expect(clavicleL?.parent, CatBones.chest);
      expect(clavicleR?.parent, CatBones.chest);
      expect(clavicleL?.drawable, isNull);
      expect(clavicleR?.drawable, isNull);
      expect(clavicleL?.pivotX, -clavicleR!.pivotX);
      expect(clavicleL?.pivotY, clavicleR.pivotY);
      expect(rig.bone(CatBones.neck)?.parent, CatBones.chest);

      expect(socketL?.parent, CatBones.clavicleL);
      expect(socketR?.parent, CatBones.clavicleR);
      expect(rig.bone(CatBones.armUpperL)?.parent, CatBones.shoulderSocketL);
      expect(rig.bone(CatBones.armUpperR)?.parent, CatBones.shoulderSocketR);

      final jacket = rig.meshes.singleWhere((mesh) => mesh.id == 'jacket.mesh');
      expect(
        jacket.formRound,
        isFalse,
        reason:
            'the suit front should read as tailored cloth panels, not a '
            'rounded hard shell',
      );
      // The generated trunk surface rides all three spine joints, so trunk
      // rotation distributes through the fabric instead of tilting a plate.
      expect(
        jacket.vertices
            .expand((vertex) => vertex.influences)
            .map((influence) => influence.boneId)
            .toSet(),
        containsAll([CatBones.hips, CatBones.torso, CatBones.chest]),
      );
      // The old hand-authored side panels are gone; the cel shade models the
      // side planes now.
      expect(
        rig.meshes.map((mesh) => mesh.id),
        isNot(contains('jacket.side.L')),
      );
      expect(
        rig.meshes.map((mesh) => mesh.id),
        isNot(contains('jacket.side.R')),
      );
    });

    test('arms are continuous ribbon sleeves through the joint chain', () {
      for (final side in const [
        (
          ribbonId: 'arm.L.ribbon',
          clavicle: CatBones.clavicleL,
          socket: CatBones.shoulderSocketL,
          upper: CatBones.armUpperL,
          bicep: CatBones.armBicepL,
          lower: CatBones.armLowerL,
          forearm: CatBones.armForearmL,
          hand: CatBones.handL,
        ),
        (
          ribbonId: 'arm.R.ribbon',
          clavicle: CatBones.clavicleR,
          socket: CatBones.shoulderSocketR,
          upper: CatBones.armUpperR,
          bicep: CatBones.armBicepR,
          lower: CatBones.armLowerR,
          forearm: CatBones.armForearmR,
          hand: CatBones.handR,
        ),
      ]) {
        final ribbon = rig.ribbons.singleWhere((r) => r.id == side.ribbonId);
        // One centreline through shoulder→bicep→elbow→forearm→wrist: the arm
        // bends through a curve at the elbow like the legs already do,
        // instead of folding as separate weighted patches.
        // One anatomical chain: the clavicle ends at the shoulder socket, a
        // short armUpper root carries the deltoid, and the bicep/elbow/forearm
        // continue to the wrist. The rendered ribbon and IK humerus therefore
        // cannot choose different shoulder origins.
        expect(ribbon.jointBoneIds, [
          side.socket,
          side.upper,
          side.bicep,
          side.lower,
          side.forearm,
          side.hand,
        ]);
        expect(
          ribbon.hiddenBoneIds,
          containsAll([side.socket, side.upper, side.lower]),
          reason: 'the ribbon replaces the rigid capsule drawables',
        );
        expect(ribbon.outlineColor, isNotNull);
        expect(ribbon.outlineWidth, greaterThanOrEqualTo(2));
        expect(
          ribbon.roundCaps,
          isTrue,
          reason: 'the start cap is the deltoid dome; the end cap the wrist',
        );

        // The socket rides the sternum-pivot clavicle and the humerus begins
        // under that socket, rather than existing as a sibling chain.
        final socket = rig.bone(side.socket)!;
        expect(socket.parent, side.clavicle);
        expect(rig.bone(side.upper)!.parent, side.socket);
      }
    });

    test('ribbon sleeves stay welded to the girdle in solved poses', () {
      final scene = CharacterScene(buildCatInSuitRig());
      for (final ribbonId in const ['arm.L.ribbon', 'arm.R.ribbon']) {
        final ribbon = scene.rig.ribbons.singleWhere((r) => r.id == ribbonId);
        final rootId = ribbon.jointBoneIds.first;
        final socketId = ribbon.jointBoneIds[1];
        for (final clip in [
          CatClips.movingGroove,
          CatClips.shaku,
          CatClips.sekem,
          CatClips.buga,
        ]) {
          for (
            var frame = 0;
            frame <= CatClips.dancePhrase.frameCount;
            frame += 2
          ) {
            final phase = frame / CatClips.dancePhrase.frameCount;
            final solved = scene.frameAt(
              clip: clip,
              timeSeconds: phase * clip.duration,
            );
            final root = solved.world[rootId]!.origin;
            final socket = solved.world[socketId]!.origin;
            final dx = socket.x - root.x;
            final dy = socket.y - root.y;
            expect(
              math.sqrt(dx * dx + dy * dy),
              inInclusiveRange(4, 7),
              reason:
                  '${clip.name} frame $frame: the socket→humerus root strut '
                  'must stay at its six-unit rest length so the deltoid '
                  'reads welded to the jacket in every pose',
            );
          }
        }
      }
    });

    test('paired background cats use the same ribbon sleeves', () {
      final base = buildCatInSuitRig();
      for (final rig in [
        buildCatInSuitRig(palette: CatInSuitPalette.silverTabby),
        buildCatInSuitRig(palette: CatInSuitPalette.darkBrown),
      ]) {
        for (final ribbonId in const ['arm.L.ribbon', 'arm.R.ribbon']) {
          final ribbon = rig.ribbons.singleWhere((r) => r.id == ribbonId);
          final baseRibbon = base.ribbons.singleWhere((r) => r.id == ribbonId);
          expect(
            ribbon.halfWidths,
            baseRibbon.halfWidths,
            reason:
                '$ribbonId must keep the same anatomical profile on backup '
                'palettes; only fur/face colours vary per cat',
          );
          expect(ribbon.jointBoneIds, baseRibbon.jointBoneIds);
          expect(ribbon.color, baseRibbon.color);
        }
        expect(
          rig.meshes.map((mesh) => mesh.id).toSet(),
          {'jacket.mesh', 'hips.mesh'},
        );
      }
    });

    test(
      'forearm-parented cuffs close the sleeves without following paw spin',
      () {
        final shirtColor = rig.bone(CatBones.shirtV)?.drawable?.color;
        final cuffL = rig.bone(CatBones.wristCuffL);
        final cuffR = rig.bone(CatBones.wristCuffR);

        expect(cuffL?.parent, CatBones.armLowerL);
        expect(cuffR?.parent, CatBones.armLowerR);
        expect(cuffL?.drawable?.color, shirtColor);
        expect(cuffR?.drawable?.color, shirtColor);
        expect(cuffL?.z, lessThan(rig.bone(CatBones.handL)!.z));
        expect(cuffR?.z, lessThan(rig.bone(CatBones.handR)!.z));
      },
    );

    test('arm guide bones do not render as hard elbow details', () {
      final bicepL = rig.bone(CatBones.armBicepL);
      final bicepR = rig.bone(CatBones.armBicepR);
      final forearmL = rig.bone(CatBones.armForearmL);
      final forearmR = rig.bone(CatBones.armForearmR);
      final creaseL = rig.bone(CatBones.armElbowCreaseL);
      final creaseR = rig.bone(CatBones.armElbowCreaseR);

      expect(bicepL?.parent, CatBones.armUpperL);
      expect(bicepR?.parent, CatBones.armUpperR);
      expect(forearmL?.parent, CatBones.armLowerL);
      expect(forearmR?.parent, CatBones.armLowerR);
      expect(creaseL?.parent, CatBones.armLowerL);
      expect(creaseR?.parent, CatBones.armLowerR);
      for (final guide in [
        bicepL,
        bicepR,
        forearmL,
        forearmR,
        creaseL,
        creaseR,
      ]) {
        expect(
          guide?.drawable,
          isNull,
          reason:
              '${guide?.id} is a ribbon guide/control only; tiny visible bars '
              'read as bone artifacts inside the elbow',
        );
      }
      // The drawable-carrying arm capsules are all replaced by the ribbons.
      expect(
        rig.hiddenDrawableBoneIds,
        containsAll([
          CatBones.shoulderSocketL,
          CatBones.shoulderSocketR,
          CatBones.armUpperL,
          CatBones.armUpperR,
          CatBones.armLowerL,
          CatBones.armLowerR,
        ]),
      );
    });

    test('every navy surface derives from the one suit fabric', () {
      // The fabric concept: one base cloth, planes separated by VALUE only.
      // Derived surfaces must scale R, G, and B by one factor (same hue), so
      // no sleeve/trouser can drift into reading as a different material.
      int chan(int argb, int shift) => (argb >> shift) & 0xFF;
      for (final surface in [
        rig.meshes.singleWhere((m) => m.id == 'jacket.mesh').color,
        rig.ribbons.singleWhere((r) => r.id == 'arm.L.ribbon').color,
        rig.ribbons.singleWhere((r) => r.id == 'arm.R.ribbon').color,
        rig.ribbons.singleWhere((r) => r.id == 'leg.L.ribbon').color,
        rig.ribbons.singleWhere((r) => r.id == 'leg.R.ribbon').color,
      ]) {
        final factor = chan(surface, 16) / chan(kSuitFabric.base, 16);
        expect(
          chan(surface, 8) / chan(kSuitFabric.base, 8),
          closeTo(factor, 0.03),
          reason: 'green must scale by the same factor as red (same hue)',
        );
        expect(
          chan(surface, 0) / chan(kSuitFabric.base, 0),
          closeTo(factor, 0.03),
          reason: 'blue must scale by the same factor as red (same hue)',
        );
      }
    });

    test('sleeves are jacket cloth separated by contact shadow', () {
      final torso = rig.bone(CatBones.torso)!.drawable!.color;
      for (final id in const ['arm.L.ribbon', 'arm.R.ribbon']) {
        final sleeve = rig.ribbons.singleWhere((ribbon) => ribbon.id == id);
        expect(
          sleeve.color,
          torso,
          reason:
              'a sleeve is the SAME cloth as its jacket — the old near/far '
              'value steps read as lighter fabric patches where the sleeve '
              'root sits on the yoke',
        );
        expect(
          sleeve.inkOverFill,
          isFalse,
          reason:
              'crossed-arm poses must not trace the sleeve boundary as a '
              'false internal elbow contour over the jacket',
        );
        expect(
          sleeve.overlapShadow,
          isTrue,
          reason:
              'same-colour sleeves still need overlap separation when they '
              'cross the torso',
        );
      }
      final nearLeg = rig.ribbons.singleWhere((r) => r.id == 'leg.L.ribbon');
      final farLeg = rig.ribbons.singleWhere((r) => r.id == 'leg.R.ribbon');
      expect(nearLeg.inkOverFill, isTrue);
      expect(farLeg.inkOverFill, isTrue);
      expect(
        farLeg.color,
        nearLeg.color,
        reason:
            'both trouser legs are the SAME cloth — the far leg separates by '
            'its overlap-clipped ink line, not a darker fabric value',
      );
      expect(
        _luma(nearLeg.color),
        lessThan(_luma(torso)),
        reason: 'trousers stay a darker plane of the same suit fabric',
      );
    });

    test('no auxiliary sleeve patch surfaces remain', () {
      // The sleeve is ONE ribbon per arm. The old build stacked extra skinned
      // patches on top (shadow contours, shoulder caps/folds) that were tuned
      // per pose and broke in between — the celShade pass models the sleeve
      // volume now, so nothing auxiliary may come back.
      expect(
        rig.meshes.map((mesh) => mesh.id).toSet(),
        {'jacket.mesh', 'hips.mesh'},
      );
      expect(
        rig.ribbons.map((ribbon) => ribbon.id).toSet(),
        {
          'tail.ribbon',
          'leg.L.ribbon',
          'leg.R.ribbon',
          'arm.L.ribbon',
          'arm.R.ribbon',
        },
      );
    });

    test('sleeves keep a heroic taper instead of a sausage tube', () {
      final ribbon = rig.ribbons.singleWhere((r) => r.id == 'arm.L.ribbon');
      final cuff = rig.bone(CatBones.wristCuffL)!.drawable!;
      final hand = rig.bone(CatBones.handL)!.drawable!;

      // Index 0 is the SHOULDER SOCKET (the round armhole cap); index 1 is the
      // short DELTOID root. They stay close in width
      // so the cap reads as one continuous mass with the shoulder instead of
      // a pinched neck-then-bulge (the "separate clavicle" tell).
      final deltoid = ribbon.halfWidths[1];
      final bicep = ribbon.halfWidths[2];
      final elbow = ribbon.halfWidths[3];
      final forearm = ribbon.halfWidths[4];
      final wrist = ribbon.halfWidths[5];

      expect(
        deltoid,
        greaterThan(bicep * 0.9),
        reason:
            'the shoulder attachment carries mass comparable to the bicep — '
            'never the thinnest point of the arm (the old dangling-sausage '
            'tell). The bicep itself may peak slightly past the deltoid on '
            'this muscular build.',
      );
      expect(
        bicep,
        greaterThan(elbow),
        reason: 'the elbow needs a visible pinch so the arm bends as anatomy',
      );
      expect(
        forearm,
        greaterThan(elbow),
        reason: 'the forearm should swell back out after the elbow pinch',
      );
      // Ratios recalibrated (0.72 -> 0.82, 0.55 -> 0.63) with the cuff
      // termination: the terminal spec width is now the fabric OPENING at
      // the cuff band (the sleeve no longer runs to the palm), and the R21
      // rigging panel asked it to hold ~60% of the bicep so extended arms
      // stop deflating — while still visibly tapering from the forearm
      // swell and keeping the heroic shoulder-to-wrist falloff.
      expect(
        wrist,
        lessThan(forearm * 0.82),
        reason: 'the sleeve still tapers from the forearm swell to the cuff',
      );
      expect(
        wrist,
        lessThan(deltoid * 0.63),
        reason: 'shoulder-to-wrist taper carries the heroic silhouette',
      );
      expect(
        wrist,
        greaterThanOrEqualTo(bicep * 0.55),
        reason:
            'the cuff opening keeps real volume — an extended arm must not '
            'deflate to a sliver above the cuff (R21 rigging)',
      );
      expect(hand.width, greaterThan(22));
      expect(hand.height, greaterThan(20));
      expect(cuff.width, lessThan(hand.width));
      expect(cuff.width, greaterThanOrEqualTo(18));
    });

    test('arms carry an asymmetric muscle profile', () {
      for (final id in const ['arm.L.ribbon', 'arm.R.ribbon']) {
        final arm = rig.ribbons.singleWhere((r) => r.id == id);
        final front = arm.halfWidths;
        final back = arm.backHalfWidths!;
        // [clavicle, deltoid, bicep, elbow, forearm, wrist]
        expect(
          front[2],
          greaterThan(back[2]),
          reason: 'the BICEP bulges on the front of the upper arm',
        );
        expect(
          front[4],
          greaterThan(back[4]),
          reason: 'the forearm swell (brachioradialis) reads on the front',
        );
        expect(
          front[3] + back[3],
          lessThan(front[2] + back[2]),
          reason: 'the elbow pinches between bicep and forearm masses',
        );
        expect(
          front[5] + back[5],
          lessThan(front[4] + back[4]),
          reason: 'the wrist tapers out of the forearm',
        );
      }
    });

    test('legs carry an asymmetric muscle profile', () {
      for (final id in const ['leg.L.ribbon', 'leg.R.ribbon']) {
        final leg = rig.ribbons.singleWhere((r) => r.id == id);
        final front = leg.halfWidths;
        final back = leg.backHalfWidths!;
        // [pelvis root, hip, quad, knee, calf, ankle]
        expect(
          front[2],
          greaterThan(back[2]),
          reason: 'the QUAD bulges on the front of the thigh',
        );
        expect(
          back[4],
          greaterThan(front[4]),
          reason: 'the CALF bulges on the back of the shin',
        );
        expect(
          front[3] + back[3],
          lessThan(front[2] + back[2]),
          reason: 'the knee pinches between thigh and calf masses',
        );
        expect(
          front[5] + back[5],
          lessThan(front[4] + back[4]),
          reason: 'the ankle tapers hard out of the calf',
        );
        // The ribbon roots INSIDE the pelvis: the thigh flows out of the hip
        // mass instead of hinging off a joint bolted to the pelvis rim.
        expect(leg.jointBoneIds.first.toLowerCase(), contains('hip_blend'));
      }
    });

    test('shoes read as colour-blocked 90s high-tops with flexing soles', () {
      for (final side in const [
        (
          foot: CatBones.footL,
          toe: CatBones.shoeToeL,
          flex: CatBones.toeFlexL,
          sole: CatBones.shoeHighlightL,
          soleFront: CatBones.shoeSoleFrontL,
          counter: CatBones.shoeCounterL,
        ),
        (
          foot: CatBones.footR,
          toe: CatBones.shoeToeR,
          flex: CatBones.toeFlexR,
          sole: CatBones.shoeHighlightR,
          soleFront: CatBones.shoeSoleFrontR,
          counter: CatBones.shoeCounterR,
        ),
      ]) {
        final last = rig.bone(side.foot)!.drawable!;
        final toe = rig.bone(side.toe)!;
        final flex = rig.bone(side.flex)!;
        final sole = rig.bone(side.sole)!.drawable!;
        final soleFront = rig.bone(side.soleFront)!.drawable!;
        final counter = rig.bone(side.counter)!.drawable!;

        // White leather body with the era's colour blocking: toe box and
        // collar share one accent panel colour (NO brand marks of any kind).
        expect(_luma(last.color), greaterThan(200));
        expect(toe.drawable!.color, counter.color);
        expect(
          _luma(toe.drawable!.color),
          lessThan(_luma(last.color) * 0.5),
          reason: 'the accent panels contrast the white body',
        );
        // The upper is ONE union silhouette: flat panels, no interior ink.
        for (final part in [last, toe.drawable!, counter]) {
          expect(part.inkOverFill, isFalse);
          expect(part.celShade, isFalse);
          expect(part.outlineColor, isNotNull);
        }
        // The sole is split at the BALL of the foot and bends there: the
        // front half rides the toe_flex joint the sole-flex pass drives.
        expect(flex.parent, side.foot);
        expect(
          flex.pivotX,
          lessThan(-8),
          reason: 'the flex pivot sits at the ball, forward of the heel',
        );
        expect(
          last.dx - last.width / 2,
          greaterThanOrEqualTo(flex.pivotX - 1),
          reason:
              'the rigid vamp must stop at the flex hinge; otherwise its '
              'rounded toe appears as a second ball under the bent sole',
        );
        expect(toe.parent, side.flex);
        expect(
          sole.width + soleFront.width,
          greaterThanOrEqualTo(last.width),
          reason: 'the two sole halves together run the full last',
        );
        for (final half in [sole, soleFront]) {
          expect(half.inkOverFill, isTrue);
          expect(_luma(half.color), greaterThan(150));
        }
      }
    });

    test('Moving soles retain a visible ball-of-foot bend', () {
      final scene = CharacterScene(rig);
      final clips = [
        CatClips.movingGroove,
        CatClips.movingGrooveLowCounter,
        CatClips.movingGrooveSideAnswer,
        CatClips.movingChorusTravel,
        CatClips.movingChorusOpen,
        CatClips.movingVerseGroove,
        CatClips.movingVerseWindow,
        CatClips.movingBreakdownGroove,
        CatClips.movingBridgeRock,
        CatClips.movingBodyRoll,
      ];
      var best = (delta: 0.0, clip: '', phase: 0.0, side: '');
      for (final clip in clips) {
        for (var i = 0; i < 240; i++) {
          final phase = i / 240;
          final world = scene
              .frameAt(clip: clip, timeSeconds: phase * clip.duration)
              .world;
          for (final side in [
            (foot: CatBones.footL, flex: CatBones.toeFlexL, name: 'L'),
            (foot: CatBones.footR, flex: CatBones.toeFlexR, name: 'R'),
          ]) {
            final foot = world[side.foot]!;
            final flex = world[side.flex]!;
            final delta = math
                .atan2(
                  math.sin(
                    math.atan2(flex.b, flex.a) - math.atan2(foot.b, foot.a),
                  ),
                  math.cos(
                    math.atan2(flex.b, flex.a) - math.atan2(foot.b, foot.a),
                  ),
                )
                .abs();
            if (delta > best.delta) {
              best = (
                delta: delta,
                clip: clip.name,
                phase: phase,
                side: side.name,
              );
            }
          }
        }
      }
      expect(
        best.delta,
        greaterThan(0.7),
        reason:
            'the front sole should still visibly flex; strongest pose was '
            '${best.clip} ${best.side} at phase ${best.phase}',
      );
    });

    test('the sole edge never lowers the shoe contact point', () {
      // The contact/grounding solver keys off the lowest drawn point of the
      // foot; the sole-edge highlight must stay above the sole bottom so it
      // can't shift grounding or the support-foot lock.
      for (final pair in const [
        (CatBones.footR, CatBones.shoeHighlightR),
        (CatBones.footL, CatBones.shoeHighlightL),
        (CatBones.footR, CatBones.shoeToeR),
        (CatBones.footL, CatBones.shoeToeL),
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
        containsAll(['jacket.mesh', 'hips.mesh']),
      );
      expect(rig.ribbonHiddenBoneIds, contains(CatBones.tail3));
      expect(rig.hiddenDrawableBoneIds, contains(CatBones.legLowerL));
      expect(rig.hiddenDrawableBoneIds, contains(CatBones.armUpperL));
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

    test('limb thickness follows the dancer plane scale', () {
      // Thickness is a pure function of the staged plane, not a hand-cast
      // constant: the front reference plane carries full anatomical mass and
      // upstage planes thin on a gentle quarter-power curve, preserving the
      // negative space a small silhouette needs to read.
      expect(limbThicknessForPlaneScale(1), 1);
      final upstage = limbThicknessForPlaneScale(0.49);
      expect(upstage, lessThan(1));
      expect(upstage, greaterThan(0.78));
      expect(
        limbThicknessForPlaneScale(0.3),
        lessThan(limbThicknessForPlaneScale(0.6)),
        reason: 'thickness must be monotone in plane scale',
      );
      expect(
        limbThicknessForPlaneScale(0.01),
        greaterThanOrEqualTo(0.78),
        reason: 'a hard floor keeps far dancers from going stringy',
      );

      final base = buildCatInSuitRig();
      final far = buildCatInSuitRig(
        legWidthScale: upstage,
        armWidthScale: upstage,
      );

      expect(
        base.ribbons.singleWhere((r) => r.id == 'leg.L.ribbon').halfWidths,
        const [15.0, 14.2, 15.6, 8.6, 9.2, 5.5],
      );
      expect(
        base.ribbons.singleWhere((r) => r.id == 'leg.L.ribbon').backHalfWidths,
        const [15.0, 13.0, 11.2, 8.2, 12.2, 5.3],
      );
      final baseArm = base.ribbons.singleWhere((r) => r.id == 'arm.L.ribbon');
      final farArm = far.ribbons.singleWhere((r) => r.id == 'arm.L.ribbon');
      final baseLeg = base.ribbons.singleWhere((r) => r.id == 'leg.L.ribbon');
      final farLeg = far.ribbons.singleWhere((r) => r.id == 'leg.L.ribbon');
      for (var i = 0; i < baseArm.halfWidths.length; i++) {
        expect(
          farArm.halfWidths[i],
          closeTo(baseArm.halfWidths[i] * upstage, 0.001),
        );
        expect(
          farArm.backHalfWidths![i],
          closeTo(baseArm.backHalfWidths![i] * upstage, 0.001),
        );
      }
      for (var i = 0; i < baseLeg.halfWidths.length; i++) {
        expect(
          farLeg.halfWidths[i],
          closeTo(baseLeg.halfWidths[i] * upstage, 0.001),
        );
        expect(
          farLeg.backHalfWidths![i],
          closeTo(baseLeg.backHalfWidths![i] * upstage, 0.001),
        );
      }
      // The paw follows its limb ("hands too") — the pad, cuff, and toes scale
      // with the arm so an upstage cat does not wave front-plane mitts.
      expect(
        far.bone(CatBones.handL)!.drawable!.width,
        closeTo(base.bone(CatBones.handL)!.drawable!.width * upstage, 0.001),
      );
      expect(
        far.bone(CatBones.wristCuffL)!.drawable!.width,
        closeTo(
          base.bone(CatBones.wristCuffL)!.drawable!.width * upstage,
          0.001,
        ),
      );
      // Tail is a silhouette accent shared by the whole cast.
      expect(
        far.ribbons.singleWhere((r) => r.id == 'tail.ribbon').halfWidths,
        base.ribbons.singleWhere((r) => r.id == 'tail.ribbon').halfWidths,
      );
    });
  });

  group('CatClips', () {
    test('exposes the show-focused public motion set', () {
      expect(
        CatClips.all.map((c) => c.name).toSet(),
        {
          'kick',
          'movingHookLead',
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
      expect(CatClips.movingGroove.loop, isTrue);
      expect(CatClips.shaku.loop, isTrue);
      expect(CatClips.zanku.loop, isTrue);
      expect(CatClips.azonto.loop, isTrue);
      expect(CatClips.buga.loop, isTrue);
      expect(CatClips.pouncingCat.loop, isTrue);
      expect(CatClips.sekem.loop, isTrue);
      expect(CatClips.idle.loop, isTrue);
      expect(CatClips.kick.loop, isFalse);
    });

    test(
      'Moving hook compiles its pose cells into grounded steps and accents',
      () {
        final moving = CatClips.movingGroove;
        final footL = _targetFor(moving, CatBones.footL).channel;
        final footR = _targetFor(moving, CatBones.footR).channel;
        final handL = _targetFor(moving, CatBones.handL).channel;
        final handR = _targetFor(moving, CatBones.handR).channel;

        // The free shoe touches in, gets airborne again, then lands as the next
        // support. This guards against the old floor-height touch->plant scrape.
        expect(footR.sample(4 / 32).y, greaterThan(100));
        expect(footR.sample(6 / 32).y, lessThan(100));
        expect(footR.sample(8 / 32).y, greaterThan(105));
        expect(footL.sample(12 / 32).y, greaterThan(100));
        expect(footL.sample(14 / 32).y, lessThan(100));
        expect(footL.sample(16 / 32).y, greaterThan(105));

        double radiusFromRestShoulder(IkTargetPose target) {
          final shoulderX = target.x.isNegative ? -35.0 : 35.0;
          return math.sqrt(
            math.pow(target.x - shoulderX, 2) + math.pow(target.y + 56, 2),
          );
        }

        // A full reach is welcome, but it must be an elbow-led UNFURL followed
        // by a tangential outside exit—not a reversal that reels the paw back
        // along the same line.
        final rightStart = handR.sample(0 / 32);
        final rightLead = handR.sample(2 / 32);
        final rightReach = handR.sample(4 / 32);
        final rightExit = handR.sample(6 / 32);
        expect(rightLead.x, greaterThan(rightStart.x));
        expect(rightReach.x, greaterThan(rightStart.x + 35));
        expect(rightReach.y, lessThan(rightStart.y - 35));
        expect(
          radiusFromRestShoulder(rightReach) -
              radiusFromRestShoulder(rightStart),
          greaterThan(15),
        );
        expect(
          (radiusFromRestShoulder(rightExit) -
                  radiusFromRestShoulder(rightReach))
              .abs(),
          lessThan(6),
          reason: 'the reached paw should travel around, not spring inward',
        );
        expect(rightExit.y, greaterThan(rightReach.y + 18));
        expect(rightExit.x, greaterThanOrEqualTo(rightReach.x));

        // The second four bars answer on the left and open into "ooh" rather
        // than replaying the first half of the phrase.
        // The left track intentionally trails by 0.55 authored frames.
        final leftPrep = handL.sample((14 + 0.55) / 32);
        final leftReach = handL.sample((20 + 0.55) / 32);
        expect(
          radiusFromRestShoulder(leftReach) - radiusFromRestShoulder(leftPrep),
          greaterThan(15),
        );
        final oohLeft = handL.sample((20 + 0.55) / 32);
        final oohRight = handR.sample((20 + 0.2) / 32);
        expect(oohLeft.y, lessThan(-125));
        expect(oohLeft.x, greaterThan(-70));
        expect(oohRight.y, greaterThan(-80));
        expect(oohRight.x - oohLeft.x, greaterThan(150));

        // No authored hand target is allowed to make the old puppet-arm leap.
        // One frame is half a musical beat in this phrase, so this guards the
        // path itself rather than relying on runtime smoothing to hide jumps.
        for (final hand in [handL, handR]) {
          for (var frame = 1; frame <= 32; frame++) {
            final previous = hand.sample((frame - 1) / 32);
            final current = hand.sample(frame / 32);
            final travel = math.sqrt(
              math.pow(current.x - previous.x, 2) +
                  math.pow(current.y - previous.y, 2),
            );
            expect(
              travel,
              lessThan(45),
              reason: 'hand target jumps $travel units at frame $frame',
            );
          }
        }

        expect(moving.channels, contains(CatBones.handL));
        expect(moving.channels, contains(CatBones.handR));
      },
    );

    test('Moving phrases never ask the arm solver for an impossible fold', () {
      final scene = CharacterScene(buildCatInSuitRig());
      for (final moving in [
        CatClips.movingGroove,
        CatClips.movingGrooveLowCounter,
        CatClips.movingGrooveSideAnswer,
        CatClips.movingVerseGroove,
        CatClips.movingVerseWindow,
        CatClips.movingBreakdownGroove,
        CatClips.movingChorusTravel,
        CatClips.movingChorusOpen,
        CatClips.movingBridgeRock,
        CatClips.movingBodyRoll,
      ]) {
        for (var i = 0; i < 96; i++) {
          final p = i / 96;
          final raw = scene.preClampPoseAt(
            clip: moving,
            timeSeconds: p * moving.duration,
          );
          expect(
            scene.armFoldCorrections(raw),
            isEmpty,
            reason:
                '${moving.name} p=$p must stay inside the planar arm ROM; any '
                'anti-fold correction means the authored elbow is impossible',
          );
        }
      }
    });

    test('Moving travel and bridge are distinct whole-body sentences', () {
      final travel = CatClips.movingChorusTravel;
      final bridge = CatClips.movingBridgeRock;
      final travelFootR = _targetFor(travel, CatBones.footR).channel;
      final bridgeFootR = _targetFor(bridge, CatBones.footR).channel;
      final travelHandL = _targetFor(travel, CatBones.handL).channel;
      final bridgeHandL = _targetFor(bridge, CatBones.handL).channel;

      // The chorus sends the free shoe beyond the stance; the bridge draws it
      // inward. These are opposite weight pathways, not different arms over
      // the same step-touch.
      expect(travelFootR.sample(4 / 32).x, greaterThan(80));
      expect(bridgeFootR.sample(8 / 32).x, lessThan(45));

      // Both phrases release one paw to the real hip line between accents,
      // preventing the repeated two-fists-at-shoulders guard silhouette.
      expect(travelHandL.sample(0).y, greaterThan(-15));
      expect(bridgeHandL.sample(0).y, greaterThan(-5));

      // Paws and shoulder girdles articulate with the pathways instead of
      // inheriting the old Moving clip's neutral 0→0 wrist and mismatched
      // hook clavicle timing.
      expect(
        travel.channels[CatBones.handL]!.sample(7 / 32).rotation.abs(),
        greaterThan(0.15),
      );
      expect(
        bridge.channels[CatBones.handL]!.sample(25 / 32).rotation.abs(),
        greaterThan(0.12),
      );
      expect(
        travel.channels[CatBones.clavicleL]!.sample(5 / 32).rotation,
        greaterThan(0.015),
      );
    });

    test('Moving body roll stays low-armed over long planted phrases', () {
      final roll = CatClips.movingBodyRoll;
      expect(roll.contactSpans, hasLength(2));
      for (final span in roll.contactSpans) {
        expect(span.end - span.start, closeTo(0.5, 1e-9));
      }

      for (final handId in [CatBones.handL, CatBones.handR]) {
        final hand = _targetFor(roll, handId).channel;
        for (var i = 0; i < 64; i++) {
          expect(
            hand.sample(i / 64).y,
            greaterThan(-40),
            reason: '$handId should stay below the rib line throughout',
          );
        }
      }
      expect(
        _targetFor(roll, CatBones.footR).channel.sample(6 / 32).x,
        lessThan(45),
        reason:
            'the free shoe should visibly drag inward during the long plant',
      );

      final handL = _targetFor(roll, CatBones.handL).channel;
      final handR = _targetFor(roll, CatBones.handR).channel;
      final bar1L = handL.sample(8 / 32);
      final bar1R = handR.sample(8 / 32);
      final bar2L = handL.sample(24 / 32);
      final bar2R = handR.sample(24 / 32);
      expect(
        bar1R.x.abs() - bar1L.x.abs(),
        greaterThan(35),
        reason: 'bar 1 should open right while the left paw scoops inward',
      );
      expect(
        bar2L.x.abs() - bar2R.x.abs(),
        greaterThan(35),
        reason: 'bar 2 should trade roles instead of repeating the silhouette',
      );
      expect(bar1L.y, lessThan(bar1R.y));
      expect(bar2R.y, lessThan(bar2L.y));
    });

    test('Moving bridge bounce trades a broad reach between bars', () {
      final bridge = CatClips.movingBreakdownGroove;
      final handL = _targetFor(bridge, CatBones.handL).channel;
      final handR = _targetFor(bridge, CatBones.handR).channel;
      final leftReach = handL.sample(8 / 32);
      final leftCounter = handR.sample(8 / 32);
      final rightCounter = handL.sample(16 / 32);
      final rightReach = handR.sample(16 / 32);

      expect(leftReach.x, lessThan(-115));
      expect(
        leftCounter.x,
        lessThan(90),
        reason: 'bar 1 keeps the right paw loose while the left arm reaches',
      );
      expect(rightReach.x, greaterThan(115));
      expect(
        rightCounter.x.abs(),
        lessThan(90),
        reason: 'bar 2 must trade roles instead of mirroring two wide arms',
      );
    });

    test(
      'Moving bridge rock lets the ribs lead a delayed head counter-focus',
      () {
        final head = CatClips.movingBridgeRock.channels[CatBones.head]!;

        expect(head.sample(0).rotation, lessThan(-0.05));
        expect(head.sample(12 / 32).rotation, greaterThan(0.05));
        expect(head.sample(20 / 32).rotation, lessThan(-0.06));
        expect(head.sample(28 / 32).rotation, greaterThan(0.06));
        expect(
          head.sample(1).rotation,
          closeTo(head.sample(0).rotation, 1e-9),
          reason: 'the loop seam must return without a head snap',
        );
      },
    );

    test('Moving verse window focus follows the active shoulder', () {
      final head = CatClips.movingVerseWindow.channels[CatBones.head]!;

      expect(head.sample(14 / 32).rotation, lessThan(-0.05));
      expect(head.sample(26 / 32).rotation, greaterThan(0.05));
      expect(
        head.sample(1).rotation,
        closeTo(head.sample(0).rotation, 1e-9),
        reason: 'the focus change must preserve the cyclic head seam',
      );
    });

    test('later Moving choruses open with a planted-side lead and catch', () {
      final open = CatClips.movingChorusOpen;
      final handLLead = _targetFor(
        open,
        CatBones.handL,
      ).channel.sample(8 / 32);
      final handRDelay = _targetFor(
        open,
        CatBones.handR,
      ).channel.sample(8 / 32);
      final handRCatch = _targetFor(
        open,
        CatBones.handR,
      ).channel.sample(12 / 32);
      final footR = _targetFor(open, CatBones.footR).channel.sample(4 / 32);

      expect(handLLead.x, lessThan(-105));
      expect(handLLead.y, lessThan(handRDelay.y - 30));
      expect(
        handRCatch.y,
        lessThan(handRDelay.y - 30),
        reason: 'the opposite arm must arrive after the planted-side lead',
      );
      expect(footR.x, greaterThan(88));
      expect(
        footR.y,
        greaterThan(100),
        reason: 'the outside shoe should press wide near the deck, not kick',
      );
    });

    test('every scored Moving phrase articulates both paws', () {
      for (final clip in [
        CatClips.movingGroove,
        CatClips.movingGrooveLowCounter,
        CatClips.movingGrooveSideAnswer,
        CatClips.movingChorusTravel,
        CatClips.movingChorusOpen,
        CatClips.movingVerseGroove,
        CatClips.movingVerseWindow,
        CatClips.movingBreakdownGroove,
        CatClips.movingBridgeRock,
        CatClips.movingBodyRoll,
      ]) {
        for (final handId in [CatBones.handL, CatBones.handR]) {
          expect(
            _rotationRange(clip.channels[handId]!),
            greaterThan(0.08),
            reason:
                '${clip.name} $handId must change facing through its arm path, '
                'not inherit a neutral 0→0 mitten',
          );
        }
      }
    });

    test('Moving side-answer crown keeps a visibly bent elbow', () {
      final scene = CharacterScene(buildCatInSuitRig());
      final moving = CatClips.movingGrooveSideAnswer;
      var maxRightElbowDegrees = 0.0;

      for (var i = 0; i <= 192; i++) {
        final p = i / 192;
        final world = scene
            .frameAt(clip: moving, timeSeconds: p * moving.duration)
            .world;
        final shoulder = world[CatBones.armUpperR]!.origin;
        final elbow = world[CatBones.armLowerR]!.origin;
        final wrist = world[CatBones.handR]!.origin;
        final upperX = shoulder.x - elbow.x;
        final upperY = shoulder.y - elbow.y;
        final lowerX = wrist.x - elbow.x;
        final lowerY = wrist.y - elbow.y;
        final cosine =
            (upperX * lowerX + upperY * lowerY) /
            (math.sqrt(upperX * upperX + upperY * upperY) *
                math.sqrt(lowerX * lowerX + lowerY * lowerY));
        maxRightElbowDegrees = math.max(
          maxRightElbowDegrees,
          math.acos(cosine.clamp(-1.0, 1.0)) * 180 / math.pi,
        );
      }

      // The rejected version measured 179.98° here: technically solvable,
      // but visibly a rigid stick. Preserve generous overhead reach while
      // retaining enough flex for the elbow to lead and settle naturally.
      expect(maxRightElbowDegrees, lessThan(155));

      final apex = scene
          .frameAt(
            clip: moving,
            timeSeconds: (14 / 32) * moving.duration,
          )
          .world;
      expect(
        apex[CatBones.handR]!.origin.y,
        lessThan(apex[CatBones.head]!.origin.y - 20),
        reason: 'the bent arm must still read clearly above the head',
      );
    });

    test(
      'Moving recoveries separate a loose low hand from the high phrase',
      () {
        final scene = CharacterScene(buildCatInSuitRig());

        double elbowDegrees(
          Map<String, Affine2D> world,
          String shoulderId,
          String elbowId,
          String wristId,
        ) {
          final shoulder = world[shoulderId]!.origin;
          final elbow = world[elbowId]!.origin;
          final wrist = world[wristId]!.origin;
          final upperX = shoulder.x - elbow.x;
          final upperY = shoulder.y - elbow.y;
          final lowerX = wrist.x - elbow.x;
          final lowerY = wrist.y - elbow.y;
          final cosine =
              (upperX * lowerX + upperY * lowerY) /
              (math.sqrt(upperX * upperX + upperY * upperY) *
                  math.sqrt(lowerX * lowerX + lowerY * lowerY));
          return math.acos(cosine.clamp(-1.0, 1.0)) * 180 / math.pi;
        }

        final answer = CatClips.movingGrooveSideAnswer;
        final answerRecovery = scene
            .frameAt(
              clip: answer,
              timeSeconds: (28 / 32) * answer.duration,
            )
            .world;
        expect(
          answerRecovery[CatBones.handR]!.origin.y,
          greaterThan(answerRecovery[CatBones.armUpperR]!.origin.y + 20),
          reason:
              'the crown must pour into a visibly low loose hand instead of '
              'springing back beside the shoulder',
        );
        expect(
          elbowDegrees(
            answerRecovery,
            CatBones.armUpperR,
            CatBones.armLowerR,
            CatBones.handR,
          ),
          lessThan(155),
          reason: 'the low waterfall still needs a relaxed, flexed elbow',
        );

        final window = CatClips.movingVerseWindow;
        final windowCounter = scene
            .frameAt(
              clip: window,
              timeSeconds: (24 / 32) * window.duration,
            )
            .world;
        final high = windowCounter[CatBones.handL]!.origin;
        final low = windowCounter[CatBones.handR]!.origin;
        expect(
          low.y - high.y,
          greaterThan(85),
          reason:
              'bar 2 should read as one face-window arm over a pendular low '
              'counter, not two fists waving at shoulder height',
        );
        expect(
          low.y,
          greaterThan(windowCounter[CatBones.armUpperR]!.origin.y + 20),
        );
        expect(
          elbowDegrees(
            windowCounter,
            CatBones.armUpperR,
            CatBones.armLowerR,
            CatBones.handR,
          ),
          lessThan(155),
        );

        final leftTarget = _targetFor(window, CatBones.handL).channel;
        for (var frame = 27; frame <= 32; frame++) {
          final from = leftTarget.sample((frame - 1) / 32);
          final to = leftTarget.sample(frame / 32);
          final travel = math.sqrt(
            math.pow(to.x - from.x, 2) + math.pow(to.y - from.y, 2),
          );
          expect(
            travel,
            lessThan(23),
            reason:
                'VerseWindow recovery frame $frame travels $travel target '
                'units; the raised paw must pour down, not displace',
          );
        }
      },
    );

    test('Moving signature puts the rendered left paw above the head', () {
      final scene = CharacterScene(buildCatInSuitRig());
      final moving = CatClips.movingGroove;
      final world = scene
          .frameAt(
            clip: moving,
            timeSeconds: ((20 + 0.55) / 32) * moving.duration,
          )
          .world;
      final handY = world[CatBones.handL]!.origin.y;
      final headY = world[CatBones.head]!.origin.y;
      // The paw itself extends roughly ten units above its origin. Requiring
      // the origin 46 units above the skull origin puts the visible paw cap
      // above the head mass rather than merely beside the ear.
      expect(
        handY,
        lessThan(headY - 46),
        reason:
            'overhead payoff must be visible in the rendered rig: '
            'handY=$handY headY=$headY',
      );
    });

    test('Moving groove keeps each cuff on the sleeve side of the paw', () {
      final scene = CharacterScene(buildCatInSuitRig());
      final moving = CatClips.movingGroove;
      const arms = [
        (
          hand: CatBones.handL,
          cuff: CatBones.wristCuffL,
          elbow: CatBones.armLowerL,
        ),
        (
          hand: CatBones.handR,
          cuff: CatBones.wristCuffR,
          elbow: CatBones.armLowerR,
        ),
      ];
      for (var i = 0; i < 96; i++) {
        final p = i / 96;
        final world = scene
            .frameAt(clip: moving, timeSeconds: p * moving.duration)
            .world;
        for (final arm in arms) {
          final handTransform = world[arm.hand]!;
          final cuffTransform = world[arm.cuff]!;
          final elbowTransform = world[arm.elbow]!;
          final hand = handTransform.origin;
          final cuff = cuffTransform.origin;
          final elbow = elbowTransform.origin;
          final cuffX = cuff.x - hand.x;
          final cuffY = cuff.y - hand.y;
          final sleeveX = elbow.x - hand.x;
          final sleeveY = elbow.y - hand.y;
          final alignment =
              (cuffX * sleeveX + cuffY * sleeveY) /
              (math.sqrt(cuffX * cuffX + cuffY * cuffY) *
                  math.sqrt(sleeveX * sleeveX + sleeveY * sleeveY));
          expect(
            alignment,
            greaterThan(0.82),
            reason:
                'movingGroove p=$p ${arm.cuff} must sit back toward the '
                'forearm, not rotate into the palm or away from the sleeve',
          );
          final cuffAngle = math.atan2(cuffTransform.b, cuffTransform.a);
          final sleeveAngle = math.atan2(elbowTransform.b, elbowTransform.a);
          final angleDelta = math.atan2(
            math.sin(cuffAngle - sleeveAngle),
            math.cos(cuffAngle - sleeveAngle),
          );
          expect(
            angleDelta.abs(),
            lessThan(1e-9),
            reason:
                'movingGroove p=$p ${arm.cuff} must inherit the sleeve axis, '
                'never the independently lagging paw rotation',
          );
        }
      }
    });

    test(
      'Moving groove arm geometry stays inside a human-looking envelope',
      () {
        final scene = CharacterScene(buildCatInSuitRig());
        final moving = CatClips.movingGroove;
        const arms = [
          (
            socket: CatBones.shoulderSocketL,
            shoulder: CatBones.armUpperL,
            elbow: CatBones.armLowerL,
            wrist: CatBones.handL,
          ),
          (
            socket: CatBones.shoulderSocketR,
            shoulder: CatBones.armUpperR,
            elbow: CatBones.armLowerR,
            wrist: CatBones.handR,
          ),
        ];
        var minElbowDegrees = double.infinity;
        var maxElbowDegrees = double.negativeInfinity;
        var maxElbowAt = '';
        var maxElbowOutsideWrist = 0.0;
        var maxElbowOutsideAt = '';
        var maxShoulderDriverMismatch = 0.0;
        final minSocketRelativeY = <String, double>{};
        final maxSocketRelativeY = <String, double>{};

        for (var i = 0; i < 192; i++) {
          final p = i / 192;
          final world = scene
              .frameAt(clip: moving, timeSeconds: p * moving.duration)
              .world;
          final chestInverse = world[CatBones.chest]!.inverse()!;
          for (final pair in [
            (clavicle: CatBones.clavicleL, lever: CatBones.shoulderLineL),
            (clavicle: CatBones.clavicleR, lever: CatBones.shoulderLineR),
          ]) {
            final clavicle = world[pair.clavicle]!;
            final lever = world[pair.lever]!;
            final delta = math.atan2(
              math.sin(
                math.atan2(lever.b, lever.a) -
                    math.atan2(clavicle.b, clavicle.a),
              ),
              math.cos(
                math.atan2(lever.b, lever.a) -
                    math.atan2(clavicle.b, clavicle.a),
              ),
            );
            maxShoulderDriverMismatch = math.max(
              maxShoulderDriverMismatch,
              delta.abs(),
            );
          }
          for (final arm in arms) {
            final socket = world[arm.socket]!.origin;
            final shoulder = world[arm.shoulder]!.origin;
            final elbow = world[arm.elbow]!.origin;
            final wrist = world[arm.wrist]!.origin;
            final upperX = shoulder.x - elbow.x;
            final upperY = shoulder.y - elbow.y;
            final lowerX = wrist.x - elbow.x;
            final lowerY = wrist.y - elbow.y;
            final cosine =
                (upperX * lowerX + upperY * lowerY) /
                (math.sqrt(upperX * upperX + upperY * upperY) *
                    math.sqrt(lowerX * lowerX + lowerY * lowerY));
            final elbowDegrees =
                math.acos(cosine.clamp(-1.0, 1.0)) * 180 / math.pi;
            minElbowDegrees = math.min(minElbowDegrees, elbowDegrees);
            if (elbowDegrees > maxElbowDegrees) {
              maxElbowDegrees = elbowDegrees;
              maxElbowAt = 'p=${p.toStringAsFixed(3)} ${arm.wrist}';
            }

            final side = wrist.x >= shoulder.x ? 1.0 : -1.0;
            final outside = (elbow.x - wrist.x) * side;
            if (outside > maxElbowOutsideWrist) {
              maxElbowOutsideWrist = outside;
              maxElbowOutsideAt = 'p=${p.toStringAsFixed(3)} ${arm.wrist}';
            }
            // Measure the socket in chest-local coordinates. A world-Y
            // subtraction still counts the whole thorax rotating under the
            // arm; this assertion is specifically about shoulder articulation.
            final socketRelativeY = chestInverse
                .transformPoint(socket.x, socket.y)
                .y;
            minSocketRelativeY[arm.wrist] = math.min(
              minSocketRelativeY[arm.wrist] ?? double.infinity,
              socketRelativeY,
            );
            maxSocketRelativeY[arm.wrist] = math.max(
              maxSocketRelativeY[arm.wrist] ?? double.negativeInfinity,
              socketRelativeY,
            );
          }
        }

        // ignore: avoid_print
        print(
          'moving arm envelope: elbow '
          '${minElbowDegrees.toStringAsFixed(1)}..'
          '${maxElbowDegrees.toStringAsFixed(1)} deg ($maxElbowAt), '
          'outside-wrist ${maxElbowOutsideWrist.toStringAsFixed(1)} '
          '($maxElbowOutsideAt), '
          'socket-relative-y '
          '${minSocketRelativeY.entries.map((entry) => '${entry.key} '
              '${entry.value.toStringAsFixed(1)}..'
              '${maxSocketRelativeY[entry.key]!.toStringAsFixed(1)}').join(', ')}',
        );
        expect(minElbowDegrees, greaterThan(25));
        expect(maxElbowDegrees, lessThan(175));
        // The overhead pathway legitimately lets the elbow sit just outside
        // the paw centre while the shoulder elevates; keep it inside one sleeve
        // half-width so it still reads as a connected arm, not a lateral fold.
        expect(maxElbowOutsideWrist, lessThan(15.5));
        expect(
          maxShoulderDriverMismatch,
          lessThan(1e-9),
          reason:
              'movingGroove jacket shoulder and anatomical socket must have '
              'one clavicle driver—no extra gain, lag, or humeral lift',
        );
        for (final apex in [
          (
            phase: (4 + 0.2) / 32,
            shoulder: CatBones.armUpperR,
            elbow: CatBones.armLowerR,
            wrist: CatBones.handR,
          ),
          (
            phase: (20 + 0.55) / 32,
            shoulder: CatBones.armUpperL,
            elbow: CatBones.armLowerL,
            wrist: CatBones.handL,
          ),
        ]) {
          final world = scene
              .frameAt(
                clip: moving,
                timeSeconds: apex.phase * moving.duration,
              )
              .world;
          final shoulder = world[apex.shoulder]!.origin;
          final elbow = world[apex.elbow]!.origin;
          final wrist = world[apex.wrist]!.origin;
          expect(
            elbow.y,
            inInclusiveRange(shoulder.y - 55, shoulder.y + 18),
            reason:
                '${apex.elbow} may rise with a real overhead reach, but must '
                'stay connected to the shoulder rather than teleporting upward',
          );
          expect(
            wrist.y,
            lessThan(shoulder.y - 4),
            reason:
                '${apex.wrist} should land above shoulder level on the call '
                'without forcing the humerus into the old vertical pose',
          );
          expect(
            wrist.y,
            lessThan(elbow.y - 10),
            reason:
                '${apex.wrist} must continue above its raised elbow at the '
                'call apex; a horizontal forearm reads as an elbow-led flap',
          );
          final upperDx = elbow.x - shoulder.x;
          final upperDy = elbow.y - shoulder.y;
          final abductionDegrees =
              math.acos(
                (upperDy / math.sqrt(upperDx * upperDx + upperDy * upperDy))
                    .clamp(-1.0, 1.0),
              ) *
              180 /
              math.pi;
          expect(
            abductionDegrees,
            inInclusiveRange(60, 175),
            reason:
                '${apex.shoulder} upper arm must follow the call or overhead '
                'orbit without collapsing into a downward hang',
          );
        }
        for (final arm in arms) {
          expect(
            maxSocketRelativeY[arm.wrist]! - minSocketRelativeY[arm.wrist]!,
            inInclusiveRange(2, 14),
            reason: '${arm.socket} should articulate without popping',
          );
        }
      },
    );

    test('shaku drives both legs and both arms', () {
      final channels = CatClips.shaku.channels;
      expect(channels.containsKey(CatBones.legUpperL), isTrue);
      expect(channels.containsKey(CatBones.legUpperR), isTrue);
      expect(channels.containsKey(CatBones.armUpperL), isTrue);
      expect(channels.containsKey(CatBones.armUpperR), isTrue);
    });

    test('catalogue hand paths flow through their keys (C1 smooth)', () {
      // Hands used to be per-segment eased (a dead stop at every key) with a
      // SoftenedIkTargetChannel blur stacked on top to hide the corners — a
      // workaround that also blunted accent hits and shifted key poses. The
      // channels are smooth splines now: velocity-continuous THROUGH the
      // authored keys, no blur wrapper.
      // zanku joined shaku on the inertialized spring channel (R32 sparse-key
      // arm re-author), so it is exempt here like shaku — its velocity
      // continuity is covered by the inertialized-seam test instead.
      for (final clip in [
        CatClips.azonto,
        CatClips.buga,
        CatClips.sekem,
      ]) {
        for (final hand in [CatBones.handL, CatBones.handR]) {
          final channel = _targetFor(clip, hand).channel;
          expect(
            channel,
            isA<KeyframeIkTargetChannel>().having(
              (channel) => channel.smooth,
              'smooth',
              isTrue,
            ),
            reason:
                '${clip.name} $hand must interpolate smoothly through its '
                'keys, not stop at each one behind a corner blur',
          );
        }
      }
    });

    test('dance clips carry alternating shoulder overlap', () {
      // Per-clip shrug ceilings: zanku keeps the girdle subtle, while sekem AND
      // (as of the R13 re-author) shaku are shoulder-LED digs — the clavicle
      // drops the socket on each count so the hand can dig with the elbow bent
      // — so their clavicles may swing visibly, like sekem's pump.
      const shrugCeiling = {'shaku': 0.45, 'zanku': 0.2, 'sekem': 0.45};
      for (final clip in [CatClips.shaku, CatClips.zanku, CatClips.sekem]) {
        final left = clip.channels[CatBones.clavicleL];
        final right = clip.channels[CatBones.clavicleR];
        expect(left, isNotNull, reason: '${clip.name} needs left shoulder');
        expect(right, isNotNull, reason: '${clip.name} needs right shoulder');

        var minLeft = double.infinity;
        var maxLeft = double.negativeInfinity;
        var minRight = double.infinity;
        var maxRight = double.negativeInfinity;
        var maxPairDifference = 0.0;
        for (var i = 0; i <= 32; i++) {
          final p = i / 32;
          final l = left!.sample(p).rotation;
          final r = right!.sample(p).rotation;
          minLeft = math.min(minLeft, l);
          maxLeft = math.max(maxLeft, l);
          minRight = math.min(minRight, r);
          maxRight = math.max(maxRight, r);
          maxPairDifference = math.max(maxPairDifference, (l - r).abs());
        }

        expect(
          maxLeft - minLeft,
          greaterThan(0.04),
          reason: '${clip.name} should have visible left shoulder overlap',
        );
        expect(
          maxRight - minRight,
          greaterThan(0.04),
          reason: '${clip.name} should have visible right shoulder overlap',
        );
        expect(
          maxPairDifference,
          greaterThan(0.035),
          reason:
              '${clip.name} shoulders should not move as one rigid torso yoke',
        );
        expect(
          [minLeft.abs(), maxLeft.abs(), minRight.abs(), maxRight.abs()],
          everyElement(lessThan(shrugCeiling[clip.name]!)),
          reason: 'shoulder controls should stay in character for the move',
        );
      }
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

    test('catalogue ears and tails keep bounded secondary follow-through', () {
      for (final clip in [
        CatClips.shaku,
        CatClips.zanku,
        CatClips.azonto,
        CatClips.buga,
        CatClips.pouncingCat,
        CatClips.sekem,
      ]) {
        final earLRange = _rotationRange(clip.channels[CatBones.earL]!);
        final earRRange = _rotationRange(clip.channels[CatBones.earR]!);
        expect(
          earLRange,
          greaterThan(0.055),
          reason: '${clip.name} left ear should not look pinned to the skull',
        );
        expect(
          earRRange,
          greaterThan(0.055),
          reason: '${clip.name} right ear should not look pinned to the skull',
        );
        expect(
          [earLRange, earRRange],
          everyElement(lessThan(0.16)),
          reason: '${clip.name} ears should flop, not dominate the dance',
        );

        final rootRange = _rotationRange(clip.channels[CatBones.tail0]!);
        final midRange = _rotationRange(clip.channels[CatBones.tail3]!);
        final lateRange = _rotationRange(clip.channels[CatBones.tail5]!);
        final tipRange = _rotationRange(clip.channels[CatBones.tail6]!);
        expect(
          midRange,
          greaterThan(rootRange * 1.4),
          reason: '${clip.name} tail should build motion away from the hips',
        );
        expect(
          lateRange,
          greaterThan(midRange * 1.04),
          reason:
              '${clip.name} late tail should keep building drag before the tip',
        );
        expect(
          tipRange,
          greaterThan(lateRange * 1.05),
          reason: '${clip.name} tail tip should lag as follow-through',
        );
        expect(
          tipRange,
          lessThan(0.42),
          reason: '${clip.name} tail should stay secondary, not become the act',
        );
      }
    });

    test('catalogue tail tips carry reactive secondary motion', () {
      for (final clip in [
        CatClips.zanku,
        CatClips.azonto,
        CatClips.buga,
        CatClips.pouncingCat,
        CatClips.sekem,
      ]) {
        final mid = clip.channels[CatBones.tail3];
        final late = clip.channels[CatBones.tail5];
        final tip = clip.channels[CatBones.tail6];

        expect(mid, isA<SineChannel>());
        expect(late, isA<SineChannel>());
        expect(tip, isA<SineChannel>());
        final midChannel = mid! as SineChannel;
        final lateChannel = late! as SineChannel;
        final tipChannel = tip! as SineChannel;

        expect(
          lateChannel.phase,
          greaterThan(midChannel.phase + 0.1),
          reason:
              '${clip.name} late tail links need phase delay so the tail reads '
              'as a drag chain, not one rigid curved plank',
        );
        expect(
          tipChannel.phase,
          greaterThan(lateChannel.phase + 0.12),
          reason:
              '${clip.name} tail tip should be visibly delayed behind the hips',
        );
        expect(
          midChannel.harmonicAmplitude.abs(),
          greaterThan(0.006),
          reason:
              '${clip.name} mid-tail should react to the body groove instead '
              'of moving as a single lazy sine',
        );
        expect(
          tipChannel.harmonicMultiplier,
          greaterThanOrEqualTo(8),
          reason:
              '${clip.name} tail tip should lag and flick behind the torso '
              'instead of reading stiff',
        );
        expect(
          tipChannel.harmonicAmplitude.abs(),
          greaterThan(midChannel.harmonicAmplitude.abs() * 1.8),
          reason:
              '${clip.name} tail tip should lag and flick behind the torso '
              'instead of reading stiff',
        );
      }
    });

    test('catalogue arms stay seated in their shoulder sockets', () {
      final scene = CharacterScene(buildCatInSuitRig());
      for (final clip in [
        CatClips.shaku,
        CatClips.zanku,
        CatClips.buga,
        CatClips.sekem,
      ]) {
        for (var frame = 0; frame <= 32; frame++) {
          final sample = scene.frameAt(
            clip: clip,
            timeSeconds: clip.duration * frame / 32,
          );
          for (final side in const [
            (
              socket: CatBones.shoulderSocketL,
              upper: CatBones.armUpperL,
            ),
            (
              socket: CatBones.shoulderSocketR,
              upper: CatBones.armUpperR,
            ),
          ]) {
            final socket = sample.world[side.socket]!.origin;
            final upper = sample.world[side.upper]!.origin;
            final dx = socket.x - upper.x;
            final dy = socket.y - upper.y;
            final distance = math.sqrt(dx * dx + dy * dy);
            expect(
              distance,
              lessThan(7),
              reason:
                  '${clip.name} frame $frame ${side.upper} must stay seated '
                  'inside the clavicle-owned shoulder cap',
            );
          }
        }
      }
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
        // Handoff re-timed 22 -> 14.5 for the tap-step re-author: the left
        // foot lifts into airborne taps at 14 and the right foot plants
        // dead at 15, with the bar-period weight sway committing the
        // pelvis rightward from 16 — the support solver now follows the
        // foot that actually carries the weight (see _shakuContactSpans).
        expect(spans.map((span) => span.start), [
          0,
          10 / 32,
          14.5 / 32,
          30.125 / 32,
        ]);
        expect(spans.map((span) => span.end), [
          10 / 32,
          14.5 / 32,
          30.125 / 32,
          1,
        ]);
        expect(spans[1].end, greaterThan(13 / 32));
        expect(spans[2].start, greaterThan(13 / 32));
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

    test('shaku saws crossed fists antiphase near the midline', () {
      // R23 re-author (5-lens panel, avg 6.4): the wide one-arm side-reach
      // (open to ±44 while the other hand parked) was hype-man vocabulary, not
      // shaku — coach/animator/mocap/physicist ALL flagged it as the wrong move
      // and it was the technical lens's one rig-y junction too. Shaku carries
      // BOTH fists near the chest, COMPACT (within shoulder width), sawing past
      // the midline ANTIPHASE and stacked one forearm above the other (a height
      // offset → open sky between them, never the folded-flat centre blob). This
      // test pins that intent in place of the old open-out/generator-pull.
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
            'pocket read without skate through the pump',
      );

      for (final frame in [0, 4, 8, 16, 20, 24, 32]) {
        final p = frame / phrase.frameCount;
        final leftFoot = footL.sample(p);
        final rightFoot = footR.sample(p);
        expect(
          rightFoot.x - leftFoot.x,
          greaterThan(58),
          reason:
              'Shaku frame $frame keeps a compact hip-width shuffle (the R26 '
              'coach: the 0.82 stance still read as an azonto stride, so it was '
              'tightened toward hip-width) while the feet never cross under the '
              'pelvis (separation stays positive and >~half a body width)',
        );
      }

      const beats = [0, 4, 8, 12, 16, 20, 24, 28];
      for (final frame in beats) {
        final p = frame / phrase.frameCount;
        final left = handL.sample(p);
        final right = handR.sample(p);
        // COMPACT: both fists stay near the midline (within shoulder width),
        // never the old ±44 side-reach lockout.
        expect(
          left.x.abs(),
          lessThan(26),
          reason: 'Shaku frame $frame: the LEFT fist stays compact near centre',
        );
        expect(
          right.x.abs(),
          lessThan(26),
          reason:
              'Shaku frame $frame: the RIGHT fist stays compact near centre',
        );
        // STACKED: the right forearm rides below the left so the two never fold
        // flat onto the same chest plane (open sky between them).
        expect(
          right.y - left.y,
          greaterThan(12),
          reason:
              'Shaku frame $frame: the fists stay stacked (R below L) so the '
              'forearms keep open sky between them, not a centre blob',
        );
      }

      // ANTIPHASE crossing: on L's counts the left fist is left-of-centre and
      // the right fist right-of-centre; on the off-beats they SWAP — the two
      // fists cross past the midline, they do not park on one side.
      for (final frame in [0, 8, 16, 24]) {
        final p = frame / phrase.frameCount;
        expect(
          handL.sample(p).x,
          lessThan(0),
          reason: 'Shaku frame $frame: left fist left-of-centre',
        );
        expect(
          handR.sample(p).x,
          greaterThan(0),
          reason: 'Shaku frame $frame: right fist right-of-centre',
        );
      }
      for (final frame in [4, 12, 20, 28]) {
        final p = frame / phrase.frameCount;
        expect(
          handL.sample(p).x,
          greaterThan(0),
          reason: 'Shaku frame $frame: left fist crossed right-of-centre',
        );
        expect(
          handR.sample(p).x,
          lessThan(0),
          reason: 'Shaku frame $frame: right fist crossed left-of-centre',
        );
      }

      // Both hands genuinely CROSS the midline over the loop (neither parks on
      // one side): each fist's x spans from clearly-left to clearly-right.
      final leftXs = beats.map((f) => handL.sample(f / phrase.frameCount).x);
      final rightXs = beats.map((f) => handR.sample(f / phrase.frameCount).x);
      expect(leftXs.reduce(math.min), lessThan(-10));
      expect(leftXs.reduce(math.max), greaterThan(10));
      expect(rightXs.reduce(math.min), lessThan(-10));
      expect(rightXs.reduce(math.max), greaterThan(10));

      // Bar 2 escalates: the saw opens a touch wider than bar 1.
      expect(
        handL.sample(16 / phrase.frameCount).x.abs(),
        greaterThanOrEqualTo(handL.sample(0).x.abs()),
        reason: 'the bar-2 saw is at least as wide as bar 1',
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
        greaterThanOrEqualTo(0.9),
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
        inInclusiveRange(40, 52),
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
      final rightSupportHold = footR.sample(5 / phrase.frameCount);
      expect(
        rightSupportHold.x,
        closeTo(62, 0.8),
        reason:
            'the right Zanku support foot should stay planted through the '
            'post-stomp hold instead of spline-sliding toward the next scrape',
      );
      expect(rightSupportHold.y, greaterThanOrEqualTo(124.5));
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
        inInclusiveRange(96, 110),
        reason:
            'Zanku should show a compact pre-stomp pickup before the heel-toe '
            'flick, not a walking stride — task #39 widened the lower bound '
            'so bar 2 (this frame) can lift noticeably higher than bar 1, '
            'reading as building weight commitment rather than a repeat',
      );
      expect(
        leftFlick.x,
        inInclusiveRange(-92, -80),
        reason:
            'Zanku should show a readable heel-toe knock outside the trouser '
            'mass without becoming a side kick — task #39 widened this so '
            "bar 2's knock can reach further out than bar 1's",
      );
      expect(leftFlick.y, inInclusiveRange(118, 125));
      expect(
        leftRecoil.x,
        greaterThan(leftFlick.x + 10),
        reason: 'the free foot should scrape back under the body after tapping',
      );
      expect(
        leftStomp.dy - leftFlickLift.dy,
        inInclusiveRange(40, 56),
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
      final leftSupportHold = footL.sample(25 / phrase.frameCount);
      expect(
        leftSupportHold.x,
        closeTo(-64, 0.8),
        reason:
            'the left Zanku support foot should stay planted through the '
            'post-stomp hold instead of spline-sliding toward the next scrape',
      );
      expect(leftSupportHold.y, greaterThanOrEqualTo(124.5));
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
      expect(freezeLeftHand.x, lessThan(-24));
      expect(
        freezeLeftHand.y,
        inInclusiveRange(-16, 2),
        reason:
            'the exact Zanku freeze should punch the left counter-hit down/out '
            'from a rib guard, not dangle below the jacket',
      );
      expect(
        freezeRightHand.y,
        inInclusiveRange(-16, 2),
        reason:
            'the exact Zanku freeze should drive both fists down into the '
            'landing accent, not hang neutrally below the jacket',
      );

      final promotedKick = footR.sample(26 / phrase.frameCount);
      expect(
        promotedKick.y,
        inInclusiveRange(40, 52),
        reason:
            'the gbese is the phrase climax: the knee drives up with the foot '
            'flicking at hip-to-waist height (panel round 1: a shin-height '
            'kick reads as just another step)',
      );
      expect(
        promotedKick.x,
        inInclusiveRange(22, 32),
        reason:
            'the gbese lifts forward under the body, not out into a wide '
            'side kick',
      );

      for (final frame in [2, 4, 14, 26, 28, 30]) {
        expect(
          handL.sample(frame / phrase.frameCount).x,
          lessThan(-24),
          reason:
              'Zanku left hand must stay in the left lane on frame $frame; '
              'cross-body IK makes the shoulders fold impossibly',
        );
        expect(
          handR.sample(frame / phrase.frameCount).x,
          greaterThan(24),
          reason:
              'Zanku right hand must stay in the right lane on frame $frame; '
              'cross-body IK makes the shoulders fold impossibly',
        );
      }
    });

    test('azonto keeps a grounded wide base under the mime groove', () {
      final phrase = CatClips.dancePhrase;
      final azonto = CatClips.azonto;
      final footL = _targetFor(azonto, CatBones.footL).channel;
      final footR = _targetFor(azonto, CatBones.footR).channel;
      final handL = _targetFor(azonto, CatBones.handL).channel;
      final handR = _targetFor(azonto, CatBones.handR).channel;
      final hips = azonto.channels[CatBones.hips]!;
      final torso = azonto.channels[CatBones.torso]!;

      expect(
        azonto.supportFootWorldAnchorStrength,
        greaterThanOrEqualTo(0.86),
        reason:
            'Azonto needs a firmer support anchor now that the pelvis visibly '
            'dwells over alternating step-touch plants',
      );
      expect(
        azonto.contactSpans.map((span) => span.bone),
        [
          CatBones.footL,
          CatBones.footR,
          CatBones.footL,
          CatBones.footR,
          CatBones.footL,
          CatBones.footR,
          CatBones.footL,
          CatBones.footR,
        ],
      );

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

      // BARREL ROLL v6 (sagittal): the fists roll around each other in the DEPTH
      // plane, so the SCREEN path is pure vertical antiphase at a CONSTANT x — no
      // lateral target motion, so the elbows do NOT swing in and out (owner:
      // "too much elbow in and out laterally, just rotate hands around each
      // other"). Both hands share x, so they OVERLAP at the mid-line crossings
      // and one passes BEHIND the other (z-order swap + paw depth-scale).
      // Assert: a tall vertical sweep, ~zero horizontal travel, antiphase paws.
      var minLx = 1e9;
      var maxLx = -1e9;
      var minLy = 1e9;
      var maxLy = -1e9;
      for (var f = 0; f <= 32; f++) {
        final s = handL.sample(f / phrase.frameCount);
        minLx = math.min(minLx, s.x);
        maxLx = math.max(maxLx, s.x);
        minLy = math.min(minLy, s.y);
        maxLy = math.max(maxLy, s.y);
      }
      expect(
        maxLy - minLy,
        greaterThan(20),
        reason: 'Azonto: the left paw rolls through a vertical loop',
      );
      expect(
        maxLx - minLx,
        lessThan(4),
        reason:
            'Azonto: the roll is SAGITTAL — the hand target has ~zero lateral '
            'travel so the elbows do not swing in and out; the fists circle '
            'AROUND each other in depth, not by punching apart sideways',
      );
      // The defining feature of the barrel roll: the paws overlap, so one must
      // pass BEHIND the other — the clip swaps their z-order across the roll.
      expect(
        azonto.zOrderSwaps.where(
          (w) =>
              {w.boneA, w.boneB}.containsAll({CatBones.handL, CatBones.handR}),
        ),
        isNotEmpty,
        reason: 'Azonto barrel roll swaps the paws front/behind as they roll',
      );
      // On the off-beats (the loop y-extremes) the two paws sit on OPPOSITE
      // sides of the hub in y — one high, one low — i.e. rolling around each
      // other, half a lap apart.
      const hubY = -42.0;
      for (final frame in [2, 6, 10, 14, 18, 22, 26, 30]) {
        final p = frame / phrase.frameCount;
        final l = handL.sample(p);
        final r = handR.sample(p);
        expect(
          (l.y - hubY) * (r.y - hubY),
          lessThan(0),
          reason:
              'Azonto frame $frame: one paw over the top while the other is '
              'under — vertically antiphase (rolling around each other)',
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
        greaterThan(0.3),
        reason: 'the Azonto hip pop should be driven from the waist',
      );
      expect(
        torso.sample(4.5 / phrase.frameCount).rotation,
        lessThan(-0.15),
        reason:
            'the chest should follow as a delayed counter-rotation, not land '
            'on the same frame as the hips',
      );
      expect(
        footL.sample(2 / phrase.frameCount).x,
        closeTo(footL.sample(0).x, 0.5),
        reason:
            'the left Azonto support foot should hold while the right foot '
            'does the small redirect',
      );
      expect(
        footR.sample(6 / phrase.frameCount).x,
        closeTo(footR.sample(4 / phrase.frameCount).x, 0.5),
        reason:
            'the right Azonto support foot should hold while the left foot '
            'does the small redirect',
      );
    });

    test('buga peacock keeps both paws mirrored, wide, and above the belt', () {
      final phrase = CatClips.dancePhrase;
      final buga = CatClips.buga;
      final handL = _targetFor(buga, CatBones.handL).channel;
      final handR = _targetFor(buga, CatBones.handR).channel;

      for (final frame in [0, 4, 8, 12, 16, 20, 24, 28]) {
        final p = frame / phrase.frameCount;
        final left = handL.sample(p);
        final right = handR.sample(p);

        expect(
          right.x - left.x,
          greaterThan(72),
          reason:
              'Buga frame $frame: the peacock keeps both paws wide of the '
              'body — never a centreline clasp',
        );
        expect(
          (left.x + right.x).abs(),
          lessThan(16),
          reason:
              'Buga frame $frame: the bow is a UNISON mirror — both arms '
              'open together (the researched signature), not an alternating '
              'one-arm present',
        );
        for (final hand in [left, right]) {
          expect(
            hand.y,
            inExclusiveRange(-40, 26),
            reason:
                'Buga frame $frame: peacock paws live between thigh-hang and '
                'the wide out-down bow — never overhead (a raised target '
                'folds the elbow above the shoulder and the sleeve reads as '
                'a fin)',
          );
        }
      }

      // The lo counts are a relaxed thigh-hang (high reach, soft elbow) so
      // the bow READS as an opening; paws must sit below the belt line.
      for (final frame in [0, 4, 8, 20, 24]) {
        final p = frame / phrase.frameCount;
        expect(
          handL.sample(p).y,
          greaterThanOrEqualTo(6),
          reason: 'Buga lo frame $frame: left paw hangs by the thigh',
        );
        expect(
          handR.sample(p).y,
          greaterThanOrEqualTo(6),
          reason: 'Buga lo frame $frame: right paw hangs by the thigh',
        );
      }
    });

    test('buga presents once (bar 1), then vibes — no second hit', () {
      final phrase = CatClips.dancePhrase;
      final buga = CatClips.buga;
      final handL = _targetFor(buga, CatBones.handL).channel;
      final handR = _targetFor(buga, CatBones.handR).channel;

      // The ONE highlight: the bar-1 peacock opens to full wingspan through its
      // held hit (frames 12/14). Chill re-choreograph for "Moving" — the second
      // bar-2 present was dropped so the flaunt lands rare, not every bar.
      for (final frame in [12, 14]) {
        final p = frame / phrase.frameCount;
        expect(
          handR.sample(p).x,
          greaterThanOrEqualTo(88),
          reason: 'right wing must be fully open on hit frame $frame',
        );
        expect(
          handL.sample(p).x,
          lessThanOrEqualTo(-98),
          reason: 'left wing must be fully open on hit frame $frame',
        );
        expect(
          handR.sample(p).y,
          inExclusiveRange(-40, -28),
          reason: 'the bow presents out-DOWN on hit frame $frame',
        );
      }

      // Bar 2 is a relaxed groove now, NOT a second present: the old frame-28
      // hit is a low, settled paw — well inside the wingspan, below the bow.
      final p28 = 28 / phrase.frameCount;
      expect(
        handR.sample(p28).x,
        lessThan(72),
        reason: 'bar 2 no longer throws a second peacock present',
      );
      expect(
        handR.sample(p28).y,
        greaterThan(0),
        reason: 'bar 2 paws stay low/relaxed, not up in the bow',
      );

      // The bar-1 bow releases after the strut instead of freezing into the
      // next groove count.
      expect(
        _targetDistance(handR, 14, 16),
        greaterThan(12),
        reason: 'the right wing should visibly release after the held hit',
      );
      expect(
        _targetDistance(handL, 14, 16),
        greaterThan(12),
        reason: 'the left wing should visibly release after the held hit',
      );

      expect(
        buga.supportFootWorldAnchorStrength,
        greaterThanOrEqualTo(0.9),
        reason:
            'Buga show-off hits need a strong support plant so the wide bow '
            'does not read as a fall',
      );

      // Shrug on the ONE hit (bar 1): both clavicles lift together and the
      // sleeve caps carry the girdle response. Bar 2's shrug was dropped with
      // its present in the chill re-choreograph (asserted absent below).
      final clavicleR = buga.channels[CatBones.clavicleR]!;
      final clavicleL = buga.channels[CatBones.clavicleL]!;
      final shoulderSocketR = buga.channels[CatBones.shoulderSocketR]!;
      final shoulderSocketL = buga.channels[CatBones.shoulderSocketL]!;
      for (final hitFrame in [13]) {
        final p = hitFrame / phrase.frameCount;
        expect(
          clavicleR.sample(p).rotation,
          lessThan(-0.24),
          reason: 'right clavicle must shrug on the frame-$hitFrame hit',
        );
        expect(
          clavicleL.sample(p).rotation,
          greaterThan(0.24),
          reason: 'left clavicle must shrug on the frame-$hitFrame hit',
        );
        final rightSocket = shoulderSocketR.sample(p);
        expect(rightSocket.rotation, lessThan(-0.2));
        expect(rightSocket.scaleX, greaterThan(1.17));
        expect(rightSocket.scaleY, lessThanOrEqualTo(0.92));
        final leftSocket = shoulderSocketL.sample(p);
        expect(leftSocket.rotation, greaterThan(0.2));
        expect(leftSocket.scaleX, greaterThan(1.17));
        expect(leftSocket.scaleY, lessThanOrEqualTo(0.92));
      }

      // Bar 2 holds its relaxed baseline — no second shrug.
      final p29 = 29 / phrase.frameCount;
      expect(
        shoulderSocketR.sample(p29).rotation,
        greaterThan(-0.2),
        reason: 'bar 2 shoulder holds baseline — no second shrug',
      );

      final rootHit = buga.root.sample(12 / phrase.frameCount);
      final rootMirrorHit = buga.root.sample(28 / phrase.frameCount);
      expect(
        rootHit.dy,
        greaterThanOrEqualTo(-1),
        reason:
            'the Buga hit should rise from the load without lifting the body '
            'above the planted feet',
      );
      expect(
        rootMirrorHit.dy,
        greaterThanOrEqualTo(-1),
        reason: 'the second Buga hit should stay similarly planted at the peak',
      );
      expect(
        rootHit.dx.abs(),
        lessThanOrEqualTo(27),
        reason:
            'Buga should celebrate from a planted stance, not throw the root '
            'far outside the feet on the hit',
      );
      expect(
        rootMirrorHit.dx.abs(),
        lessThanOrEqualTo(27),
        reason:
            'the second Buga hit should stay similarly planted instead of '
            'becoming a lateral fall',
      );
      final legHit = buga.channels[CatBones.legLowerL]!.sample(
        12 / phrase.frameCount,
      );
      expect(
        legHit.rotation,
        lessThan(-0.6),
        reason:
            'Buga hit knees should remain flexed enough to carry weight, not '
            'lock straight at the celebration peak',
      );
      final footL = _targetFor(buga, CatBones.footL).channel;
      final footR = _targetFor(buga, CatBones.footR).channel;
      final rightHitSupport = footL.sample(12 / phrase.frameCount);
      final rightHitCounter = footR.sample(12 / phrase.frameCount);
      expect(rightHitSupport.x, lessThanOrEqualTo(-98));
      expect(rightHitSupport.y, greaterThanOrEqualTo(103));
      expect(rightHitCounter.x, greaterThanOrEqualTo(100));
      expect(rightHitCounter.y, greaterThanOrEqualTo(103));

      final leftHitSupport = footR.sample(28 / phrase.frameCount);
      final leftHitCounter = footL.sample(28 / phrase.frameCount);
      expect(leftHitSupport.x, greaterThanOrEqualTo(102));
      expect(leftHitSupport.y, greaterThanOrEqualTo(103));
      expect(leftHitCounter.x, lessThanOrEqualTo(-100));
      expect(leftHitCounter.y, greaterThanOrEqualTo(103));
      expect(buga.contactSpans[0].bone, CatBones.footR);
      expect(buga.contactSpans[0].start, 0);
      expect(buga.contactSpans[0].end, 0.25);
      expect(buga.contactSpans[1].bone, CatBones.footL);
      expect(buga.contactSpans[1].start, 0.25);
      expect(buga.contactSpans[1].end, 0.375);
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
          greaterThanOrEqualTo(0.9),
          reason:
              'Sekem needs a firmer support anchor so the wider stomp base '
              'does not skate under the side-view body lean',
        );
        expect(
          footL.sample(2 / phrase.frameCount).x,
          closeTo(leftPlant.x, 0.5),
          reason:
              'Sekem must not scrape the declared left support foot during its '
              'own support window',
        );
        expect(
          footL.sample(2 / phrase.frameCount).y,
          closeTo(leftPlant.y, 0.5),
          reason: 'left Sekem support should stay on the floor mid-window',
        );
        expect(
          footR.sample(6 / phrase.frameCount).x,
          closeTo(rightPlant.x, 0.5),
          reason:
              'Sekem must not scrape the declared right support foot during '
              'its own support window',
        );
        expect(
          footR.sample(6 / phrase.frameCount).y,
          closeTo(rightPlant.y, 0.5),
          reason: 'right Sekem support should stay on the floor mid-window',
        );

        // Both paws pump on their OWN side every beat (no sternum pin — the
        // old glued-arm idiom scored 5). On count 1 the right paw digs down-out
        // past its hip while the left recovers up; they alternate each beat.
        final leftPlantHand = handL.sample(0);
        final rightPlantHand = handR.sample(0);
        expect(
          rightPlantHand.x,
          inInclusiveRange(30, 48),
          reason: 'Sekem count 1: the right paw digs down-out past its own hip',
        );
        expect(
          rightPlantHand.y,
          greaterThan(20),
          reason: 'Sekem count 1: the right dig drives DOWN past the hip',
        );
        expect(
          leftPlantHand.x,
          inInclusiveRange(-42, -22),
          reason:
              'Sekem count 1: the left paw stays on its own side, no sternum pin',
        );
        expect(
          leftPlantHand.y,
          lessThan(0),
          reason:
              'Sekem count 1: the left paw recovers UP while the right digs',
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

        // The pump alternates phase: at frame 20 the LEFT paw is the one
        // digging down past its hip while the right recovers up.
        final leftSwapped = handL.sample(20 / phrase.frameCount);
        final rightSwapped = handR.sample(20 / phrase.frameCount);
        expect(
          leftSwapped.x,
          inInclusiveRange(-48, -30),
          reason: 'Sekem frame 20: the left paw digs down-out past its own hip',
        );
        expect(
          leftSwapped.y,
          greaterThan(20),
          reason: 'Sekem frame 20: the left dig drives DOWN past the hip',
        );
        expect(
          rightSwapped.x,
          inInclusiveRange(22, 40),
          reason: 'Sekem frame 20: the right paw recovers on its own side',
        );
        expect(
          rightSwapped.y,
          lessThan(0),
          reason:
              'Sekem frame 20: the right paw recovers UP while the left digs',
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
          handLRotation.sample(4 / phrase.frameCount).rotation.abs(),
          lessThan(0.14),
          reason: 'the pinned Sekem paw lies quietly on the chest',
        );
        expect(
          handRRotation.sample(4 / phrase.frameCount).rotation.abs(),
          lessThan(0.14),
          reason: 'the tucked Sekem paw lies quietly at the waist',
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
          closeTo(rightHipPlant, 0.01),
          reason:
              'the hip commit should arrive with the right Sekem plant instead '
              'of lagging behind the foot',
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
          closeTo(leftHipPlant, 0.01),
          reason:
              'the mirrored hip commit should arrive with the left Sekem plant '
              'instead of lagging behind the foot',
        );
      },
    );

    test('sekem holds its anchors and pumps the shoulders on every beat', () {
      final phrase = CatClips.dancePhrase;
      final sekem = CatClips.sekem;
      final handL = _targetFor(sekem, CatBones.handL).channel;
      final handR = _targetFor(sekem, CatBones.handR).channel;

      // Both paws pump every beat on their OWN side, antiphase: the digging
      // paw drives down-out past its hip while the other recovers UP; they
      // swap which is digging each beat (no sternum pin).
      for (final (frame, digPaw, digSign, upPaw) in [
        (0, handR, 1, handL),
        (4, handL, -1, handR),
        (8, handR, 1, handL),
        (12, handL, -1, handR),
        (16, handR, 1, handL),
        (20, handL, -1, handR),
        (24, handR, 1, handL),
        (28, handL, -1, handR),
      ]) {
        final p = frame / phrase.frameCount;
        final dig = digPaw.sample(p);
        final up = upPaw.sample(p);
        expect(
          dig.x * digSign,
          inInclusiveRange(30, 48),
          reason:
              'Sekem frame $frame: the digging paw drives down-out past its own hip',
        );
        expect(
          dig.y,
          greaterThan(20),
          reason: 'Sekem frame $frame: the dig goes DOWN past the hip',
        );
        expect(
          up.y,
          lessThan(0),
          reason:
              'Sekem frame $frame: the other paw recovers UP (antiphase pump, not pinned)',
        );
      }

      // The shoulder-led engine: alternating downward digs on the beats.
      final clavicleR = sekem.channels[CatBones.clavicleR]!;
      final clavicleL = sekem.channels[CatBones.clavicleL]!;
      expect(
        clavicleR.sample(0).rotation,
        greaterThan(0.3),
        reason: 'the right shoulder digs down into count 1',
      );
      expect(
        clavicleL.sample(4 / phrase.frameCount).rotation,
        lessThan(-0.3),
        reason: 'the left shoulder answers with its own down-dig on count 2',
      );
      expect(
        clavicleR.sample(4 / phrase.frameCount).rotation,
        greaterThan(-0.06),
        reason: 'the right shoulder settles while the left pumps',
      );
      expect(
        clavicleL.sample(0).rotation,
        lessThan(0.1),
        reason: 'the left shoulder stays low while the right pumps',
      );
    });

    test('sekem anchored arms never engage the anti-fold rule', () {
      final scene = CharacterScene(buildCatInSuitRig());
      for (var i = 0; i < 64; i++) {
        final p = i / 64;
        final raw = scene.preClampPoseAt(
          clip: CatClips.sekem,
          timeSeconds: p * CatClips.sekem.duration,
        );
        expect(
          scene.armFoldCorrections(raw),
          isEmpty,
          reason:
              'Sekem p=$p: the sternum pin and back-waist tuck must live '
              'inside the coupled arm-fold ROM with headroom',
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
        inInclusiveRange(push.dy + 25, push.dy + 48),
        reason:
            'the landing absorbs in the KNEES under a level head — the old '
            'full-depth landing dive made the skull ride every bounce '
            '(panel round 1: the Amapiano level-head contrast never '
            'materialized)',
      );
      // The glide beats hold the head level (within a narrow band) so the
      // one compress per bar reads as THE accent.
      final glideA = pounce.root.sample(13 / phrase.frameCount);
      final glideB = pounce.root.sample(15 / phrase.frameCount);
      expect(
        (glideA.dy - glideB.dy).abs(),
        lessThan(8),
        reason: 'the glide rides level between accents',
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
        inInclusiveRange(30, 48),
        reason:
            'the cross-body swipe apex must clear the head silhouette '
            '(panel round 1: the swipe died against the muzzle as face-on-fur '
            'mush) — up-and-out past the far ear, not parked at the chest',
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
        inInclusiveRange(-48, -30),
        reason:
            'the mirrored swipe apex must clear the head silhouette on the '
            'other side',
      );
      expect(
        (mirrorAccentRight.x - mirrorAccentLeft.x).abs(),
        inInclusiveRange(44, 100),
        reason:
            'the mirrored accent needs clear lead paw plus swipe separation '
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

double _rotationRange(JointChannel channel) {
  var min = double.infinity;
  var max = double.negativeInfinity;
  for (var i = 0; i <= 64; i++) {
    final rotation = channel.sample(i / 64).rotation;
    min = math.min(min, rotation);
    max = math.max(max, rotation);
  }
  return max - min;
}

double _targetDistance(IkTargetChannel channel, int fromFrame, int toFrame) {
  final from = channel.sample(fromFrame / CatClips.dancePhrase.frameCount);
  final to = channel.sample(toFrame / CatClips.dancePhrase.frameCount);
  final dx = to.x - from.x;
  final dy = to.y - from.y;
  return math.sqrt(dx * dx + dy * dy);
}
