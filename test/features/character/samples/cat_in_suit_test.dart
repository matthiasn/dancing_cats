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
      final collarL = rig.bone(CatBones.collarL);
      final collarR = rig.bone(CatBones.collarR);
      expect(collarL?.parent, CatBones.clavicleL);
      expect(collarR?.parent, CatBones.clavicleR);
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
      expect(rig.bone(CatBones.armUpperL)?.parent, CatBones.clavicleL);
      expect(rig.bone(CatBones.armUpperR)?.parent, CatBones.clavicleR);
      expect(rig.bone(CatBones.lapelL)?.parent, CatBones.clavicleL);
      expect(rig.bone(CatBones.lapelR)?.parent, CatBones.clavicleR);

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
        // The first TWO joints (clavicle, socket) are both clavicle-anchored:
        // the ribbon's root section cannot rotate with the arm, so the bend
        // reads as a fabric crease below the deltoid instead of the shoulder
        // cap sweeping around a rivet.
        expect(ribbon.jointBoneIds, [
          side.clavicle,
          side.socket,
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

        // The socket is rigidly clavicle-parented: the root strut cannot
        // rotate with the arm, and the deltoid dome travels with the armhole
        // in every pose, so no pose can open a gap.
        final socket = rig.bone(side.socket)!;
        expect(socket.parent, side.clavicle);
      }
    });

    test('ribbon sleeves stay welded to the girdle in solved poses', () {
      final scene = CharacterScene(buildCatInSuitRig());
      for (final ribbonId in const ['arm.L.ribbon', 'arm.R.ribbon']) {
        final ribbon = scene.rig.ribbons.singleWhere((r) => r.id == ribbonId);
        final rootId = ribbon.jointBoneIds.first;
        final socketId = ribbon.jointBoneIds[1];
        for (final clip in [CatClips.shaku, CatClips.sekem, CatClips.buga]) {
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
              inInclusiveRange(7, 13),
              reason:
                  '${clip.name} frame $frame: the clavicle→socket root strut '
                  'must ride the girdle at near rest length so the deltoid '
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
      // no sleeve/trouser/lapel can drift into reading as a different material.
      int chan(int argb, int shift) => (argb >> shift) & 0xFF;
      for (final surface in [
        rig.meshes.singleWhere((m) => m.id == 'jacket.mesh').color,
        rig.ribbons.singleWhere((r) => r.id == 'arm.L.ribbon').color,
        rig.ribbons.singleWhere((r) => r.id == 'arm.R.ribbon').color,
        rig.ribbons.singleWhere((r) => r.id == 'leg.L.ribbon').color,
        rig.ribbons.singleWhere((r) => r.id == 'leg.R.ribbon').color,
        rig.bone(CatBones.lapelL)!.drawable!.color,
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

    test('sleeves are the jacket cloth, separated by ink lines', () {
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
          isTrue,
          reason:
              'crossing limbs separate from same-colour cloth by their drawn '
              'ink line, like hand-drawn animation',
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

      // Index 0 is the CLAVICLE ROOT: deliberately narrow so the round
      // start cap (the armhole gap-proofing dome) hides inside the jacket
      // shoulder instead of bulging past its silhouette as a bump. The
      // visible shoulder mass is the DELTOID at index 1.
      final root = ribbon.halfWidths[0];
      final deltoid = ribbon.halfWidths[1];
      final bicep = ribbon.halfWidths[2];
      final elbow = ribbon.halfWidths[3];
      final forearm = ribbon.halfWidths[4];
      final wrist = ribbon.halfWidths[5];

      expect(
        root,
        lessThan(deltoid),
        reason:
            'the clavicle root must tuck under the jacket shoulder — a root '
            'as wide as the deltoid caps in a ball above the silhouette',
      );
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
      expect(
        wrist,
        lessThan(forearm * 0.72),
        reason: 'the wrist should taper before the cuff and paw',
      );
      expect(
        wrist,
        lessThan(deltoid * 0.55),
        reason: 'shoulder-to-wrist taper carries the heroic silhouette',
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

    test('catalogue hand paths flow through their keys (C1 smooth)', () {
      // Hands used to be per-segment eased (a dead stop at every key) with a
      // SoftenedIkTargetChannel blur stacked on top to hide the corners — a
      // workaround that also blunted accent hits and shifted key poses. The
      // channels are smooth splines now: velocity-continuous THROUGH the
      // authored keys, no blur wrapper.
      for (final clip in [
        CatClips.zanku,
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
      // Per-clip shrug ceilings: groove clips keep the girdle subtle, while
      // sekem's whole identity is the shoulder-led pump (panel round 1: the
      // frozen yoke was scored down) so its clavicles may jerk visibly.
      const shrugCeiling = {'shaku': 0.07, 'zanku': 0.2, 'sekem': 0.45};
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

    test('shaku holds the handcuff X and flashes the open scoop', () {
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
            'pocket read without skate during the held X',
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

      // The X is the base posture: crossed on every non-flash frame, wrists
      // stacked close to the sternum midline with the top wrist alternating by
      // bar. Duty cycle ~75%.
      var crossedFrames = 0;
      for (var frame = 0; frame < 32; frame++) {
        final p = frame / phrase.frameCount;
        final left = handL.sample(p);
        final right = handR.sample(p);
        if (left.x > 0 && right.x < 0) crossedFrames++;
      }
      expect(
        crossedFrames,
        greaterThanOrEqualTo(20),
        reason:
            'the handcuffed X must be the HELD base posture (the audit and '
            'the panel both flagged the inverted duty cycle) — most of the '
            'loop lives crossed',
      );

      for (final frame in [0, 4, 8, 16, 20, 24]) {
        final p = frame / phrase.frameCount;
        final left = handL.sample(p);
        final right = handR.sample(p);
        expect(
          left.x - right.x,
          greaterThan(8),
          reason:
              'Shaku frame $frame: wrists overlap near the sternum while the '
              'forearms make the X',
        );
        expect(
          math.max(left.x.abs(), right.x.abs()),
          lessThan(18),
          reason:
              'Shaku frame $frame: the handcuffed stack stays near the midline, '
              'not parked out at the shoulders',
        );
        expect(
          (left.y - right.y).abs(),
          greaterThan(8),
          reason:
              'Shaku frame $frame: the fists stagger in height so the X '
              'reads as crossed forearms, not a stacked clasp',
        );
        expect(
          left.y,
          lessThan(-42),
          reason: 'Shaku frame $frame: the X lives at sternum height',
        );
      }

      // The open scoop is PUNCTUATION: a two-frame flash on the accented
      // beat, fully open, re-crossed by the next downbeat.
      for (final frame in [12, 13, 28, 29]) {
        final p = frame / phrase.frameCount;
        final left = handL.sample(p);
        final right = handR.sample(p);
        expect(
          left.x,
          lessThan(-24),
          reason: 'Shaku frame $frame: the flash opens the left arm out',
        );
        expect(
          right.x,
          greaterThan(56),
          reason: 'Shaku frame $frame: the flash opens the right arm out',
        );
      }
      final reCrossed = handL.sample(16 / phrase.frameCount);
      expect(
        reCrossed.x,
        greaterThan(2),
        reason:
            'the X must be re-crossed (with its two-frame close and '
            'overcross settle) by the downbeat after the flash',
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

      // Bar 1 is the steering-wheel mime: the grips stay SEPARATED on their
      // own sides and trade heights in opposing arcs (panel round 1: close
      // stacked grips read as one blob clutching the tie).
      for (final frame in [0, 4, 8, 12]) {
        final p = frame / phrase.frameCount;
        final left = handL.sample(p);
        final right = handR.sample(p);
        expect(
          left.x,
          inExclusiveRange(-38, -18),
          reason:
              'Azonto frame $frame: the left paw should grip the mimed wheel '
              'in front of the body, not point out',
        );
        expect(
          right.x,
          inExclusiveRange(18, 38),
          reason:
              'Azonto frame $frame: the right paw should grip the mimed wheel '
              'in front of the body, not point out',
        );
        expect(left.y, inExclusiveRange(-90, 32));
        expect(right.y, inExclusiveRange(-90, 32));
        expect(
          (left.y - right.y).abs(),
          greaterThanOrEqualTo(4),
          reason:
              'Azonto frame $frame: the grips must trade heights in opposing '
              'arcs so the wheel visibly turns',
        );
      }

      // Bar 2 alternates FULL-EXTENSION cross-body jabs: the jabbing paw
      // crosses the midline and breaks the far silhouette line while the
      // other paw chambers at the hip crest (panel round 1: half-reach jabs
      // fold the elbow across the belly and the sleeve reads as a stump).
      for (final (frame, jab, chamber, crossSign) in [
        (16, handL, handR, 1),
        (20, handR, handL, -1),
        (24, handL, handR, 1),
        (28, handR, handL, -1),
      ]) {
        final p = frame / phrase.frameCount;
        final hit = jab.sample(p);
        final held = chamber.sample(p);
        expect(
          hit.x * crossSign,
          greaterThan(22),
          reason:
              'Azonto frame $frame: the jab must cross the midline to full '
              'extension past the far shoulder line',
        );
        expect(
          hit.y,
          lessThanOrEqualTo(-42),
          reason: 'Azonto frame $frame: the jab lands at chest height',
        );
        expect(
          held.x.abs(),
          greaterThan(24),
          reason:
              'Azonto frame $frame: the idle paw chambers at the hip on its '
              'own side',
        );
        expect(
          held.y,
          greaterThan(-26),
          reason: 'Azonto frame $frame: the chamber sits at hip height',
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

    test('buga peacock snaps open on the hits and releases', () {
      final phrase = CatClips.dancePhrase;
      final buga = CatClips.buga;
      final handL = _targetFor(buga, CatBones.handL).channel;
      final handR = _targetFor(buga, CatBones.handR).channel;

      // Full wingspan through each held hit; frame 30 is already the bar-2
      // release, so it stays wide but no longer carries the low bow height.
      for (final frame in [12, 14, 28]) {
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

      // The bow releases after the strut instead of freezing into the next
      // groove count.
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

      // DOUBLE shrug: both clavicles lift together on BOTH hits, and the
      // sleeve caps + biceps carry the girdle response on each side.
      final clavicleR = buga.channels[CatBones.clavicleR]!;
      final clavicleL = buga.channels[CatBones.clavicleL]!;
      final shoulderSocketR = buga.channels[CatBones.shoulderSocketR]!;
      final shoulderSocketL = buga.channels[CatBones.shoulderSocketL]!;
      final bicepR = buga.channels[CatBones.armBicepR]!;
      final bicepL = buga.channels[CatBones.armBicepL]!;
      for (final hitFrame in [13, 29]) {
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
        expect(bicepR.sample(p).scaleX, greaterThan(1.12));
        expect(bicepL.sample(p).scaleX, greaterThan(1.12));
      }

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

        // Round-4 Sekem: through bar 1 the left paw stays pinned at the
        // sternum while the right arm is free to punch down past the hip.
        final leftPlantHand = handL.sample(0);
        final rightPlantHand = handR.sample(0);
        expect(
          leftPlantHand.x,
          inInclusiveRange(-16, -4),
          reason: 'Sekem bar 1: the left paw is pinned at the sternum',
        );
        expect(leftPlantHand.y, inInclusiveRange(-54, -40));
        expect(
          rightPlantHand.x,
          inInclusiveRange(36, 60),
          reason: 'Sekem bar 1: the right paw punches past the hip',
        );
        expect(rightPlantHand.y, inInclusiveRange(10, 36));

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

        // The anchors trade sides once per bar: after frame 16 the right paw
        // takes the sternum pin and the left becomes the free hip pump.
        final leftSwapped = handL.sample(20 / phrase.frameCount);
        final rightSwapped = handR.sample(20 / phrase.frameCount);
        expect(
          leftSwapped.x,
          inInclusiveRange(-58, -36),
          reason: 'Sekem bar 2: the left paw pumps past the hip',
        );
        expect(leftSwapped.y, inInclusiveRange(0, 18));
        expect(
          rightSwapped.x,
          inInclusiveRange(4, 16),
          reason: 'Sekem bar 2: the right paw takes the sternum pin',
        );
        expect(rightSwapped.y, inInclusiveRange(-54, -40));
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

      // Anchor duty cycle: one paw pins while the other pumps; sides swap once
      // per bar.
      for (final frame in [0, 4, 8, 12]) {
        final p = frame / phrase.frameCount;
        expect(
          handL.sample(p).x,
          inInclusiveRange(-16, -4),
          reason: 'Sekem frame $frame: left paw pinned at the sternum',
        );
        expect(
          handR.sample(p).x,
          inInclusiveRange(36, 58),
          reason: 'Sekem frame $frame: right paw owns the free hip pump',
        );
      }
      for (final frame in [16, 20, 24, 28]) {
        final p = frame / phrase.frameCount;
        expect(
          handR.sample(p).x,
          inInclusiveRange(4, 16),
          reason: 'Sekem frame $frame: right paw takes the sternum pin',
        );
        expect(
          handL.sample(p).x,
          inInclusiveRange(-58, -36),
          reason: 'Sekem frame $frame: left paw owns the free hip pump',
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
