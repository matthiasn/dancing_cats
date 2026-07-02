import 'package:dancing_cats/features/character/model/bone.dart';
import 'package:dancing_cats/features/character/model/rig_spec.dart';
import 'package:dancing_cats/features/character/model/trunk_surface.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildTrunkSurface', () {
    const bones = [
      Bone(id: CatBones.hips, parent: null, pivotX: 0, pivotY: 0, z: 0),
      Bone(
        id: CatBones.torso,
        parent: CatBones.hips,
        pivotX: 0,
        pivotY: -50,
        z: 1,
      ),
      Bone(
        id: CatBones.chest,
        parent: CatBones.torso,
        pivotX: 10,
        pivotY: -40,
        z: 2,
      ),
      Bone(
        id: CatBones.clavicleL,
        parent: CatBones.chest,
        pivotX: -26,
        pivotY: -8,
        z: 3,
      ),
      Bone(
        id: CatBones.clavicleR,
        parent: CatBones.chest,
        pivotX: 26,
        pivotY: -8,
        z: 3,
      ),
    ];

    const stations = [
      TrunkStation(boneId: CatBones.hips, y: 0, halfWidth: 22),
      TrunkStation(boneId: CatBones.torso, y: -42, halfWidth: 25),
      TrunkStation(boneId: CatBones.chest, x: 4, y: -84, halfWidth: 18),
    ];

    test('derives station weights and local coordinates from rest origins', () {
      final mesh = buildTrunkSurface(
        id: 'test.trunk',
        bones: bones,
        stations: stations,
        z: 7,
        color: 0xFF112233,
        neighborShare: 0.3,
        outlineColor: 0xFF000000,
        outlineWidth: 2,
        formRound: true,
        boundaryCornerSmoothing: 0.18,
        hiddenBoneIds: const [CatBones.torso],
        shadeGroup: 'suit',
      );

      expect(mesh.id, 'test.trunk');
      expect(mesh.z, 7);
      expect(mesh.color, 0xFF112233);
      expect(mesh.outlineColor, 0xFF000000);
      expect(mesh.outlineWidth, 2);
      expect(mesh.formRound, isTrue);
      expect(mesh.boundaryCornerSmoothing, 0.18);
      expect(mesh.hiddenBoneIds, [CatBones.torso]);
      expect(mesh.shadeGroup, 'suit');
      expect(mesh.boundary, [0, 1, 2, 3, 4, 5]);
      expect(mesh.inkSeams, isEmpty);

      final bottomLeft = mesh.vertices[0].influences;
      expect(bottomLeft.map((influence) => influence.boneId), [
        CatBones.hips,
        CatBones.torso,
      ]);
      expect(bottomLeft.map((influence) => influence.weight), [0.7, 0.3]);
      expect(bottomLeft[0].x, -22);
      expect(bottomLeft[0].y, 0);
      expect(bottomLeft[1].x, -22);
      expect(bottomLeft[1].y, 50);

      final middleLeft = mesh.vertices[1].influences;
      expect(middleLeft.map((influence) => influence.boneId), [
        CatBones.torso,
        CatBones.hips,
        CatBones.chest,
      ]);
      expect(middleLeft.map((influence) => influence.weight), [
        closeTo(0.7, 1e-12),
        closeTo(0.15, 1e-12),
        closeTo(0.15, 1e-12),
      ]);
      expect(middleLeft[0].x, -25);
      expect(middleLeft[0].y, 8);
      expect(middleLeft[2].x, -35);
      expect(middleLeft[2].y, 48);
    });

    test('applies custom crown weights and emits mirrored seam tips', () {
      final mesh = buildTrunkSurface(
        id: 'test.crowned',
        bones: bones,
        stations: stations,
        z: 4,
        color: 0xFF445566,
        crown: const [(x: -24, y: -104), (x: -6, y: -112)],
        crownWeights: const [
          {CatBones.clavicleL: 0.75, CatBones.chest: 0.25},
          {CatBones.chest: 1},
        ],
        crownWeightsMirrored: const [
          {CatBones.chest: 1},
          {CatBones.clavicleR: 0.75, CatBones.chest: 0.25},
        ],
        crownSeamWidth: 1.5,
        crownSeamZ: 9,
        crownSeamTip: const (x: -32, y: -96),
        crownSeamTipWeights: const {
          CatBones.clavicleL: 0.8,
          CatBones.chest: 0.2,
        },
        crownSeamTipWeightsMirrored: const {
          CatBones.clavicleR: 0.8,
          CatBones.chest: 0.2,
        },
      );

      expect(mesh.vertices, hasLength(12));
      expect(mesh.boundary, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
      expect(mesh.inkSeamWidth, 1.5);
      expect(mesh.inkSeamZ, 9);
      expect(mesh.inkSeams, [
        [10, 3, 4],
        [11, 6, 5],
      ]);

      expect(_weightsByBone(mesh.vertices[3]), {
        CatBones.clavicleL: 0.75,
        CatBones.chest: 0.25,
      });
      expect(_weightsByBone(mesh.vertices[6]), {
        CatBones.clavicleR: 0.75,
        CatBones.chest: 0.25,
      });
      expect(_weightsByBone(mesh.vertices[10]), {
        CatBones.clavicleL: 0.8,
        CatBones.chest: 0.2,
      });
      expect(_weightsByBone(mesh.vertices[11]), {
        CatBones.clavicleR: 0.8,
        CatBones.chest: 0.2,
      });
    });

    test('rejects custom weights that reference a missing bone', () {
      expect(
        () => buildTrunkSurface(
          id: 'test.bad',
          bones: bones,
          stations: stations,
          z: 0,
          color: 0xFFFFFFFF,
          crown: const [(x: -10, y: -100)],
          crownWeights: const [
            {'missing.bone': 1},
          ],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('references missing bone "missing.bone"'),
          ),
        ),
      );
    });
  });
}

Map<String, double> _weightsByBone(SkinnedMeshVertex vertex) => {
  for (final influence in vertex.influences) influence.boneId: influence.weight,
};
