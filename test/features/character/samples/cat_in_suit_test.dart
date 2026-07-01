import 'dart:math' as math;

import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/rig_spec.dart';
import 'package:dancing_cats/features/character/runtime/character_scene.dart';
import 'package:dancing_cats/features/character/runtime/skinned_mesh_solver.dart';
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
      final clavicleL = rig.bone(CatBones.clavicleL);
      final clavicleR = rig.bone(CatBones.clavicleR);
      final socketL = rig.bone(CatBones.shoulderSocketL);
      final socketR = rig.bone(CatBones.shoulderSocketR);
      expect(clavicleL?.parent, CatBones.torso);
      expect(clavicleR?.parent, CatBones.torso);
      expect(clavicleL?.drawable, isNull);
      expect(clavicleR?.drawable, isNull);
      expect(clavicleL?.pivotX, -clavicleR!.pivotX);
      expect(clavicleL?.pivotY, clavicleR.pivotY);

      expect(socketL?.parent, CatBones.clavicleL);
      expect(socketR?.parent, CatBones.clavicleR);
      expect(socketL?.drawable, isNotNull);
      expect(socketR?.drawable, isNotNull);
      expect(socketL?.z, lessThan(rig.bone(CatBones.armUpperL)!.z));
      expect(socketR?.z, lessThan(rig.bone(CatBones.armUpperR)!.z));
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
      expect(
        jacket.vertices
            .expand((vertex) => vertex.influences)
            .map((influence) => influence.boneId),
        containsAll([CatBones.clavicleL, CatBones.clavicleR]),
      );

      for (final index in [0, 1, 13, 14]) {
        expect(
          jacket.vertices[index].influences.map((i) => i.boneId),
          contains(CatBones.clavicleL),
          reason: 'left jacket shoulder vertex $index should deform with L',
        );
      }
      for (final index in [2, 3, 4, 5]) {
        expect(
          jacket.vertices[index].influences.map((i) => i.boneId),
          contains(CatBones.clavicleR),
          reason: 'right jacket shoulder vertex $index should deform with R',
        );
      }
    });

    test('arm meshes are single weighted jacket-sleeve surfaces', () {
      expect(
        rig.ribbons.map((ribbon) => ribbon.id),
        isNot(contains('arm.L.ribbon')),
      );
      expect(
        rig.ribbons.map((ribbon) => ribbon.id),
        isNot(contains('arm.R.ribbon')),
      );
      expect(
        rig.meshes.map((mesh) => mesh.id),
        isNot(contains('shoulder.L.cap')),
      );
      expect(
        rig.meshes.map((mesh) => mesh.id),
        isNot(contains('shoulder.R.cap')),
      );
      expect(
        rig.meshes.map((mesh) => mesh.id),
        isNot(contains('shoulder.L.fold')),
      );
      expect(
        rig.meshes.map((mesh) => mesh.id),
        isNot(contains('shoulder.R.fold')),
      );

      for (final side in const [
        (
          meshId: 'arm.L.mesh',
          shadowId: 'arm.L.shadow',
          clavicle: CatBones.clavicleL,
          socket: CatBones.shoulderSocketL,
          upper: CatBones.armUpperL,
          bicep: CatBones.armBicepL,
          lower: CatBones.armLowerL,
          forearm: CatBones.armForearmL,
          hand: CatBones.handL,
          crease: CatBones.armElbowCreaseL,
        ),
        (
          meshId: 'arm.R.mesh',
          shadowId: 'arm.R.shadow',
          clavicle: CatBones.clavicleR,
          socket: CatBones.shoulderSocketR,
          upper: CatBones.armUpperR,
          bicep: CatBones.armBicepR,
          lower: CatBones.armLowerR,
          forearm: CatBones.armForearmR,
          hand: CatBones.handR,
          crease: CatBones.armElbowCreaseR,
        ),
      ]) {
        final mesh = rig.meshes.singleWhere((m) => m.id == side.meshId);
        final drawOrder = rig.meshDrawOrder.map((m) => m.id).toList();
        final socket = rig.bone(side.socket)!;
        final upper = rig.bone(side.upper)!;

        expect(socket.parent, side.clavicle);
        expect(upper.parent, side.clavicle);
        expect(upper.pivotX, 0);
        expect(upper.pivotY, 0);
        expect(
          mesh.hiddenBoneIds,
          containsAll([
            side.socket,
            side.upper,
            side.bicep,
            side.lower,
            side.forearm,
            side.crease,
          ]),
        );
        expect(mesh.boundary, List<int>.generate(15, (index) => index));
        expect(mesh.outlineColor, isNotNull);
        expect(mesh.outlineWidth, greaterThanOrEqualTo(2));
        expect(mesh.formRound, isFalse);
        expect(
          drawOrder.indexOf(side.meshId),
          lessThan(drawOrder.indexOf(side.shadowId)),
          reason:
              '${side.meshId} owns the visible sleeve silhouette; the shadow is '
              'only an internal fabric contour',
        );
        expect(
          mesh.vertices[0].influences.map((i) => i.boneId),
          containsAll([CatBones.torso, side.clavicle]),
          reason:
              '${side.meshId} begins on the jacket shoulder, not at a floating '
              'arm cap',
        );
        expect(
          mesh.vertices[1].influences.map((i) => i.boneId),
          containsAll([CatBones.torso, side.clavicle, side.socket, side.upper]),
          reason:
              '${side.meshId} must blend the jacket shoulder into the arm root',
        );
        expect(
          mesh.vertices[2].influences.map((i) => i.boneId),
          containsAll([side.socket, side.upper, side.bicep]),
          reason: '${side.meshId} shoulder volume must ride with the upper arm',
        );
        expect(
          mesh.vertices[6].influences.map((i) => i.boneId),
          containsAll([side.lower, side.forearm]),
          reason:
              '${side.meshId} carries the forearm in the same surface, not a '
              'separate ribbon',
        );
        expect(mesh.vertices[7].influences.single.boneId, side.hand);
        expect(mesh.vertices[8].influences.single.boneId, side.hand);
        expect(
          mesh.vertices[13].influences.map((i) => i.boneId),
          containsAll([CatBones.torso, side.clavicle, side.upper, side.bicep]),
          reason:
              '${side.meshId} returns through a torso-weighted armhole instead '
              'of closing through a detached sleeve strip',
        );
        expect(
          mesh.vertices[14].influences.map((i) => i.boneId),
          containsAll([CatBones.torso, side.clavicle, side.socket]),
        );
        expect(
          _maxAbsLocalX(mesh.vertices[2]),
          greaterThanOrEqualTo(socket.drawable!.width * 0.5),
        );
        expect(
          _maxAbsLocalX(mesh.vertices[6]),
          greaterThan(_maxAbsLocalX(mesh.vertices[10])),
          reason:
              '${side.meshId} should swell through the forearm and pinch at the '
              'inside elbow instead of becoming a sausage tube',
        );
      }
    });

    test('single sleeve meshes stay attached in solved wide-arm poses', () {
      final scene = CharacterScene(buildCatInSuitRig());
      for (final side in const [
        (
          armId: 'arm.L.mesh',
          label: 'left',
        ),
        (
          armId: 'arm.R.mesh',
          label: 'right',
        ),
      ]) {
        final armMesh = scene.rig.meshes.singleWhere((m) => m.id == side.armId);
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
            final arm = resolveSkinnedMeshVertices(armMesh, solved.world)!;
            final armholeSpan = _minPointSetDistance(
              _vertexSubset(arm, const [0, 1, 12, 13, 14]),
              _vertexSubset(arm, const [2, 3, 10, 11]),
            );

            expect(
              armholeSpan,
              lessThan(42),
              reason:
                  '${clip.name} frame $frame ${side.label} sleeve must stay '
                  'inside one armhole mesh; wider spans render as a detached '
                  'arm or bat membrane',
            );
          }
        }
      }
    });

    test('paired background cats use the same full sleeve meshes', () {
      for (final rig in [
        buildCatInSuitRig(palette: CatInSuitPalette.silverTabby),
        buildCatInSuitRig(palette: CatInSuitPalette.darkBrown),
      ]) {
        expect(
          rig.ribbons.map((ribbon) => ribbon.id),
          isNot(contains('arm.L.ribbon')),
        );
        expect(
          rig.ribbons.map((ribbon) => ribbon.id),
          isNot(contains('arm.R.ribbon')),
        );
        for (final side in const [
          (
            meshId: 'arm.L.mesh',
            shadowId: 'arm.L.shadow',
            socket: CatBones.shoulderSocketL,
            clavicle: CatBones.clavicleL,
            upper: CatBones.armUpperL,
            bicep: CatBones.armBicepL,
            lower: CatBones.armLowerL,
            forearm: CatBones.armForearmL,
          ),
          (
            meshId: 'arm.R.mesh',
            shadowId: 'arm.R.shadow',
            socket: CatBones.shoulderSocketR,
            clavicle: CatBones.clavicleR,
            upper: CatBones.armUpperR,
            bicep: CatBones.armBicepR,
            lower: CatBones.armLowerR,
            forearm: CatBones.armForearmR,
          ),
        ]) {
          final mesh = rig.meshes.singleWhere((mesh) => mesh.id == side.meshId);
          final shadow = rig.meshes.singleWhere((mesh) {
            return mesh.id == side.shadowId;
          });
          expect(mesh.boundary, List<int>.generate(15, (index) => index));
          expect(mesh.outlineColor, isNotNull);
          expect(
            mesh.vertices.expand((v) => v.influences).map((i) => i.boneId),
            containsAll([
              CatBones.torso,
              side.clavicle,
              side.socket,
              side.upper,
              side.bicep,
              side.lower,
              side.forearm,
            ]),
            reason:
                '${side.meshId} must keep the same full weighted sleeve surface '
                'on backup palettes too',
          );
          expect(
            shadow.vertices.expand((v) => v.influences).map((i) => i.boneId),
            containsAll([side.socket, side.upper]),
            reason:
                '${side.shadowId} must deform with the same backup sleeve mesh',
          );
        }
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
        expect(rig.hiddenDrawableBoneIds, contains(guide?.id));
      }
    });

    test('sleeve values stay in the same suit fabric family', () {
      final torso = rig.bone(CatBones.torso)!.drawable!.color;
      final farSleeve = rig.meshes
          .singleWhere((mesh) => mesh.id == 'arm.R.mesh')
          .color;
      final nearSleeve = rig.meshes
          .singleWhere((mesh) => mesh.id == 'arm.L.mesh')
          .color;

      expect(
        (_luma(farSleeve) - _luma(torso)).abs(),
        lessThan(10),
        reason:
            'sleeves should read as the same navy suit fabric, not a separate '
            'purple arm material',
      );
      expect(
        _luma(nearSleeve) - _luma(farSleeve),
        inInclusiveRange(4, 14),
        reason:
            'near/far sleeve value can help depth, but not enough to look like '
            'different fabric',
      );
    });

    test('sleeve contours are skinned fabric shadows, not detached bones', () {
      for (final side in const [
        (
          meshId: 'arm.L.mesh',
          shadowId: 'arm.L.shadow',
          socket: CatBones.shoulderSocketL,
          upper: CatBones.armUpperL,
          bicep: CatBones.armBicepL,
          lower: CatBones.armLowerL,
          forearm: CatBones.armForearmL,
          hand: CatBones.handL,
        ),
        (
          meshId: 'arm.R.mesh',
          shadowId: 'arm.R.shadow',
          socket: CatBones.shoulderSocketR,
          upper: CatBones.armUpperR,
          bicep: CatBones.armBicepR,
          lower: CatBones.armLowerR,
          forearm: CatBones.armForearmR,
          hand: CatBones.handR,
        ),
      ]) {
        final mesh = rig.meshes.singleWhere((m) => m.id == side.meshId);
        final shadow = rig.meshes.singleWhere((m) => m.id == side.shadowId);
        final drawOrder = rig.meshDrawOrder.map((m) => m.id).toList();

        expect(shadow.boundary, hasLength(8));
        expect(shadow.boundary, isNot(anyOf(contains(0), contains(9))));
        expect(shadow.outlineColor, isNull);
        expect(shadow.outlineWidth, 0);
        expect(shadow.formRound, isFalse);
        expect(shadow.z, mesh.z);
        expect(
          drawOrder.indexOf(side.shadowId),
          greaterThan(drawOrder.indexOf(side.meshId)),
          reason: '${side.shadowId} must draw over the base sleeve fill',
        );
        expect(
          _luma(shadow.color),
          lessThan(_luma(mesh.color) * 0.72),
          reason: 'the contour should read as a drawn dark edge in the fabric',
        );
        expect(
          shadow.vertices.expand((v) => v.influences).map((i) => i.boneId),
          containsAll([
            side.socket,
            side.upper,
            side.bicep,
            side.lower,
            side.forearm,
            side.hand,
          ]),
          reason:
              '${side.shadowId} must stay welded to the full sleeve chain, '
              'not float as a separate elbow detail',
        );
      }
    });

    test('sleeves keep a heroic taper instead of a sausage tube', () {
      final mesh = rig.meshes.singleWhere((mesh) => mesh.id == 'arm.L.mesh');
      final shadow = rig.meshes.singleWhere(
        (mesh) => mesh.id == 'arm.L.shadow',
      );
      final cuff = rig.bone(CatBones.wristCuffL)!.drawable!;
      final hand = rig.bone(CatBones.handL)!.drawable!;

      expect(mesh.boundary, hasLength(15));
      expect(mesh.formRound, isFalse);
      expect(mesh.outlineColor, isNotNull);
      expect(mesh.outlineWidth, greaterThanOrEqualTo(2));
      expect(
        mesh.hiddenBoneIds,
        containsAll([
          CatBones.shoulderSocketL,
          CatBones.armUpperL,
          CatBones.armBicepL,
          CatBones.armLowerL,
          CatBones.armForearmL,
          CatBones.armElbowCreaseL,
        ]),
      );
      expect(
        _maxAbsLocalX(mesh.vertices[3]),
        greaterThan(_maxAbsLocalX(mesh.vertices[2]) * 0.8),
        reason:
            'the sleeve should swell through the bicep instead of reading as a '
            'constant-width tube',
      );
      expect(
        _maxAbsLocalX(mesh.vertices[10]),
        lessThan(_maxAbsLocalX(mesh.vertices[3]) * 0.55),
        reason:
            'the inside elbow needs a visible pinch so the arm bends as anatomy',
      );
      expect(
        _maxAbsLocalX(mesh.vertices[6]),
        greaterThan(_maxAbsLocalX(mesh.vertices[10])),
        reason: 'the forearm should wedge back out after the elbow pinch',
      );
      expect(
        _maxAbsLocalX(mesh.vertices[7]),
        lessThan(_maxAbsLocalX(mesh.vertices[6]) * 0.72),
        reason: 'the wrist should taper before the cuff and paw',
      );
      expect(
        mesh.vertices[1].influences.map((i) => i.boneId),
        containsAll([
          CatBones.torso,
          CatBones.clavicleL,
          CatBones.shoulderSocketL,
          CatBones.armUpperL,
        ]),
        reason:
            'the sleeve shoulder must be part of the jacket mesh, not a '
            'floating cap',
      );
      expect(
        mesh.vertices[13].influences.map((i) => i.boneId),
        containsAll([
          CatBones.torso,
          CatBones.clavicleL,
          CatBones.armUpperL,
          CatBones.armBicepL,
        ]),
        reason:
            'the returning armhole edge must stay weighted to both torso and arm',
      );
      expect(
        shadow.boundary,
        isNot(anyOf(contains(0), contains(9))),
        reason:
            'the sleeve shadow should not close through the shoulder root; it '
            'is only a low-alpha edge accent',
      );
      expect(
        _alpha(shadow.color),
        lessThanOrEqualTo(0x40),
        reason:
            'high-alpha sleeve shadow fills read as hard bat plates in the '
            'raised-arm Shaku pose',
      );
      expect(hand.width, greaterThan(22));
      expect(hand.height, greaterThan(20));
      expect(cuff.width, lessThan(hand.width));
      expect(cuff.width, greaterThanOrEqualTo(18));
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
        ]),
      );
      expect(rig.ribbons.map((r) => r.id), isNot(contains('arm.L.ribbon')));
      expect(rig.ribbons.map((r) => r.id), isNot(contains('arm.R.ribbon')));
      expect(
        rig.meshes.map((m) => m.id),
        containsAll([
          'jacket.mesh',
          'jacket.side.L',
          'jacket.side.R',
          'hips.mesh',
          'arm.L.mesh',
          'arm.L.shadow',
          'arm.R.mesh',
          'arm.R.shadow',
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
      final baseArm = base.meshes.singleWhere((m) => m.id == 'arm.L.mesh');
      final leadArm = lead.meshes.singleWhere((m) => m.id == 'arm.L.mesh');
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
      const outerBicep = 3;
      const innerElbow = 10;
      const outerForearm = 6;

      expect(
        _maxAbsLocalX(leadArm.vertices[outerBicep]),
        closeTo(
          _maxAbsLocalX(baseArm.vertices[outerBicep]) * kDanceLeadArmWidthScale,
          0.001,
        ),
      );
      expect(
        _maxAbsLocalX(leadArm.vertices[innerElbow]),
        lessThan(_maxAbsLocalX(leadArm.vertices[outerBicep]) * 0.65),
        reason:
            'the elbow valley should keep crossed arms readable without '
            'becoming stringy',
      );
      expect(
        _maxAbsLocalX(leadArm.vertices[outerForearm]),
        closeTo(
          _maxAbsLocalX(baseArm.vertices[outerForearm]) *
              kDanceLeadArmWidthScale,
          0.001,
        ),
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

    test('high-arm catalogue moves use rounded multi-pass hand paths', () {
      for (final clip in [
        CatClips.zanku,
        CatClips.azonto,
        CatClips.buga,
        CatClips.sekem,
      ]) {
        for (final hand in [CatBones.handL, CatBones.handR]) {
          expect(
            _targetFor(clip, hand).channel,
            isA<SoftenedIkTargetChannel>().having(
              (channel) => channel.passes,
              'passes',
              greaterThanOrEqualTo(2),
            ),
            reason:
                '${clip.name} $hand should round nearby hand targets enough '
                'to avoid robotic shoulder/arm pops',
          );
        }
      }
    });

    test('dance clips carry alternating shoulder overlap', () {
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
          everyElement(lessThan(0.07)),
          reason: 'shoulder controls should stay subtle, not shrug wildly',
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
      expect(
        recoveryCrossLeft.y,
        greaterThan(-24),
        reason:
            'the final recovery should stay in an outside guard lane instead '
            'of dropping into the belly/waist cluster',
      );
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
        greaterThan(-42),
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
      expect(freezeLeftHand.x, lessThan(-68));
      expect(
        freezeLeftHand.y,
        inInclusiveRange(-16, -4),
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
        greaterThan(32),
        reason:
            'right Buga show-off should release after the readable peak instead '
            'of freezing through the next groove count',
      );
      expect(
        _targetDistance(handL, 30, 31),
        greaterThan(32),
        reason:
            'left Buga show-off should release after the readable peak instead '
            'of freezing through the next groove count',
      );

      expect(
        buga.supportFootWorldAnchorStrength,
        greaterThanOrEqualTo(0.9),
        reason:
            'Buga show-off hits need a strong support plant so the side reach '
            'does not read as a fall',
      );
      final clavicleR = buga.channels[CatBones.clavicleR]!;
      final clavicleL = buga.channels[CatBones.clavicleL]!;
      final shoulderSocketR = buga.channels[CatBones.shoulderSocketR]!;
      final shoulderSocketL = buga.channels[CatBones.shoulderSocketL]!;
      final bicepR = buga.channels[CatBones.armBicepR]!;
      final bicepL = buga.channels[CatBones.armBicepL]!;
      expect(
        clavicleR.sample(13 / phrase.frameCount).rotation,
        lessThan(-0.28),
        reason:
            'the right Buga overhead present should lift through the shoulder '
            'girdle, not hinge from a fixed jacket edge',
      );
      expect(
        clavicleL.sample(29 / phrase.frameCount).rotation,
        greaterThan(0.28),
        reason:
            'the mirrored Buga overhead present should lift through the left '
            'shoulder girdle as well',
      );
      final rightSocketPeak = shoulderSocketR.sample(13 / phrase.frameCount);
      expect(
        rightSocketPeak.rotation,
        lessThan(-0.22),
        reason:
            'the right Buga sleeve cap should rotate/deform with the raised '
            'arm instead of staying as a static shoulder patch',
      );
      expect(rightSocketPeak.scaleX, greaterThan(1.19));
      expect(rightSocketPeak.scaleY, lessThan(0.92));
      final leftSocketPeak = shoulderSocketL.sample(29 / phrase.frameCount);
      expect(
        leftSocketPeak.rotation,
        greaterThan(0.22),
        reason:
            'the mirrored Buga sleeve cap should rotate/deform with the raised '
            'left arm instead of staying as a static shoulder patch',
      );
      expect(leftSocketPeak.scaleX, greaterThan(1.19));
      expect(leftSocketPeak.scaleY, lessThan(0.92));
      expect(
        shoulderSocketR.sample(0).rotation,
        lessThan(-0.07),
        reason:
            'Buga loops into a raised right arm, so frame 0 needs shoulder '
            'response too; otherwise the loop boundary detaches the sleeve',
      );
      expect(
        shoulderSocketL.sample(16 / phrase.frameCount).rotation,
        greaterThan(0.07),
        reason:
            'the mirrored raised-arm phrase begins at frame 16, so the left '
            'socket should already be engaged before the big hit',
      );
      expect(
        bicepR.sample(13 / phrase.frameCount).scaleX,
        greaterThan(1.14),
        reason:
            'the upper sleeve should carry bicep mass during the raised-arm '
            'show-off instead of tapering into a thin rotating strip',
      );
      expect(bicepL.sample(29 / phrase.frameCount).scaleX, greaterThan(1.14));
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

        final leftPlantHand = handL.sample(0);
        final rightPlantHand = handR.sample(0);
        expect(
          leftPlantHand.x,
          lessThanOrEqualTo(-64),
          reason:
              'Sekem left hand should stay in the left anatomical lane; '
              'cross-body targets make the arms fold impossibly',
        );
        expect(
          leftPlantHand.y,
          greaterThan(-4),
          reason: 'the low Sekem hand should visibly sit in a compact scoop',
        );
        expect(
          rightPlantHand.x,
          greaterThan(78),
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
          lessThan(-72),
          reason:
              'the delayed Sekem pullback may not sweep through the torso '
              'while the paw is still approaching its late hit',
        );
        expect(
          leftPullback.x,
          inInclusiveRange(-96, -86),
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
          greaterThan(74),
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
          lessThan(-82),
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
          greaterThan(-4),
          reason: 'the low Sekem hand should visibly sit in a compact scoop',
        );
        final rightSweepInward = handR.sample(6.55 / phrase.frameCount);
        expect(
          rightSweepInward.x,
          greaterThan(74),
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
              'through its upper arm; that renders as an impossible folded X '
              '(shoulder=${leftShoulder.toStringAsFixed(1)}, '
              'elbow=${leftElbow.toStringAsFixed(1)}, '
              'hand=${leftHand.toStringAsFixed(1)})',
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
              'through its upper arm; that renders as an impossible folded X '
              '(shoulder=${rightShoulder.toStringAsFixed(1)}, '
              'elbow=${rightElbow.toStringAsFixed(1)}, '
              'hand=${rightHand.toStringAsFixed(1)})',
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

int _alpha(int argb) => (argb >> 24) & 0xFF;

double _maxAbsLocalX(SkinnedMeshVertex vertex) =>
    vertex.influences.map((influence) => influence.x.abs()).reduce(math.max);

List<({double x, double y})> _vertexSubset(
  List<({double x, double y})> vertices,
  List<int> indices,
) => [
  for (final index in indices)
    if (index >= 0 && index < vertices.length) vertices[index],
];

double _minPointSetDistance(
  List<({double x, double y})> a,
  List<({double x, double y})> b,
) {
  var best = double.infinity;
  for (final pa in a) {
    for (final pb in b) {
      best = math.min(best, _pointDistance(pa, pb));
    }
  }
  return best;
}

double _pointDistance(({double x, double y}) a, ({double x, double y}) b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  return math.sqrt(dx * dx + dy * dy);
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
