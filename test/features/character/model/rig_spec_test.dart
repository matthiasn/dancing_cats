import 'package:dancing_cats/features/character/model/bone.dart';
import 'package:dancing_cats/features/character/model/rig_spec.dart';
import 'package:flutter_test/flutter_test.dart';

/// Returns [value] unchanged, but as a *runtime* value the compiler cannot fold
/// into a constant. Used to force a `const` constructor to run at runtime (so
/// its body is counted by coverage) instead of being const-canonicalised away.
T _runtime<T>(T value) => value;

/// Two parent->child bones every ribbon/mesh fixture below can reference.
const _twoBones = [
  Bone(id: 'a', parent: null, pivotX: 0, pivotY: 0, z: 0),
  Bone(id: 'b', parent: 'a', pivotX: 0, pivotY: 10, z: 1),
];

RigSpec _rigWithRibbons(List<LimbRibbonSpec> ribbons) =>
    RigSpec(name: 'r', bones: _twoBones, ribbons: ribbons);

RigSpec _rigWithMeshes(List<SkinnedMeshSpec> meshes) =>
    RigSpec(name: 'r', bones: _twoBones, meshes: meshes);

/// A fully-valid triangular mesh skinned to bone `a` (weights sum to 1).
SkinnedMeshSpec _validMesh(String id, {required int z}) => SkinnedMeshSpec(
  id: id,
  vertices: const [
    SkinnedMeshVertex([MeshInfluence(boneId: 'a', x: 0, y: 0, weight: 1)]),
    SkinnedMeshVertex([MeshInfluence(boneId: 'a', x: 1, y: 0, weight: 1)]),
    SkinnedMeshVertex([MeshInfluence(boneId: 'a', x: 0, y: 1, weight: 1)]),
  ],
  boundary: const [0, 1, 2],
  z: z,
  color: 0xFFFFFFFF,
);

void main() {
  group('RigSpec', () {
    test('topoOrder visits every parent before its children', () {
      // Deliberately list children before parents to prove ordering.
      final rig = RigSpec(
        name: 'r',
        bones: const [
          Bone(id: 'hand', parent: 'lower', pivotX: 0, pivotY: 0, z: 2),
          Bone(id: 'lower', parent: 'upper', pivotX: 0, pivotY: 0, z: 1),
          Bone(id: 'upper', parent: null, pivotX: 0, pivotY: 0, z: 0),
        ],
      );
      final order = rig.topoOrder.map((b) => b.id).toList();
      expect(order.indexOf('upper'), lessThan(order.indexOf('lower')));
      expect(order.indexOf('lower'), lessThan(order.indexOf('hand')));
    });

    test('drawOrder sorts by ascending z', () {
      final rig = RigSpec(
        name: 'r',
        bones: const [
          Bone(id: 'front', parent: null, pivotX: 0, pivotY: 0, z: 9),
          Bone(id: 'back', parent: 'front', pivotX: 0, pivotY: 0, z: 1),
        ],
      );
      expect(rig.drawOrder.map((b) => b.id).toList(), ['back', 'front']);
    });

    test('bone() looks up by id', () {
      final rig = RigSpec(
        name: 'r',
        bones: const [
          Bone(id: 'a', parent: null, pivotX: 0, pivotY: 0, z: 0),
        ],
      );
      expect(rig.bone('a')?.id, 'a');
      expect(rig.bone('nope'), isNull);
    });

    test('throws when a bone references a missing parent', () {
      expect(
        () => RigSpec(
          name: 'r',
          bones: const [
            Bone(id: 'a', parent: 'ghost', pivotX: 0, pivotY: 0, z: 0),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('throws on a duplicate bone id instead of silently dropping one', () {
      expect(
        () => RigSpec(
          name: 'r',
          bones: const [
            Bone(id: 'dup', parent: null, pivotX: 0, pivotY: 0, z: 0),
            Bone(id: 'dup', parent: null, pivotX: 1, pivotY: 1, z: 1),
          ],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Duplicate bone id'),
          ),
        ),
      );
    });

    test('exposes unmodifiable bone collections', () {
      final rig = RigSpec(
        name: 'r',
        bones: const [
          Bone(id: 'a', parent: null, pivotX: 0, pivotY: 0, z: 0),
        ],
        ribbons: [
          LimbRibbonSpec(
            id: 'ribbon',
            jointBoneIds: const ['a', 'a'],
            halfWidths: const [4, 3],
            z: 0,
            color: 0xFFFFFFFF,
          ),
        ],
        meshes: [
          SkinnedMeshSpec(
            id: 'mesh',
            vertices: const [
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'a', x: 0, y: 0, weight: 1),
              ]),
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'a', x: 1, y: 0, weight: 1),
              ]),
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'a', x: 0, y: 1, weight: 1),
              ]),
            ],
            boundary: const [0, 1, 2],
            z: 0,
            color: 0xFFFFFFFF,
          ),
        ],
      );
      expect(rig.bones.clear, throwsUnsupportedError);
      expect(rig.drawOrder.clear, throwsUnsupportedError);
      expect(rig.topoOrder.clear, throwsUnsupportedError);
      expect(rig.ribbons.clear, throwsUnsupportedError);
      expect(rig.ribbonDrawOrder.clear, throwsUnsupportedError);
      expect(rig.meshes.clear, throwsUnsupportedError);
      expect(rig.meshDrawOrder.clear, throwsUnsupportedError);
      expect(rig.ribbonHiddenBoneIds.clear, throwsUnsupportedError);
      expect(rig.hiddenDrawableBoneIds.clear, throwsUnsupportedError);
    });

    test('throws on a parent cycle instead of overflowing the stack', () {
      expect(
        () => RigSpec(
          name: 'r',
          bones: const [
            Bone(id: 'a', parent: 'b', pivotX: 0, pivotY: 0, z: 0),
            Bone(id: 'b', parent: 'a', pivotX: 0, pivotY: 0, z: 1),
          ],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('cycle'),
          ),
        ),
      );
    });

    test('sorts ribbons and exposes hidden bone ids', () {
      final rig = RigSpec(
        name: 'r',
        bones: const [
          Bone(id: 'upper', parent: null, pivotX: 0, pivotY: 0, z: 0),
          Bone(id: 'lower', parent: 'upper', pivotX: 0, pivotY: 10, z: 1),
          Bone(id: 'hand', parent: 'lower', pivotX: 0, pivotY: 10, z: 2),
        ],
        ribbons: [
          LimbRibbonSpec(
            id: 'front',
            jointBoneIds: const ['upper', 'lower', 'hand'],
            hiddenBoneIds: const ['upper', 'lower'],
            halfWidths: const [8, 6, 4],
            z: 8,
            color: 0xFFFFFFFF,
          ),
          LimbRibbonSpec(
            id: 'back',
            jointBoneIds: const ['upper', 'lower', 'hand'],
            halfWidths: const [8, 6, 4],
            z: 4,
            color: 0xFFFFFFFF,
          ),
        ],
      );

      expect(rig.ribbonDrawOrder.map((r) => r.id), ['back', 'front']);
      expect(rig.ribbonHiddenBoneIds, {'upper', 'lower'});
    });

    test('sorts skinned meshes and exposes hidden drawable ids', () {
      final rig = RigSpec(
        name: 'r',
        bones: const [
          Bone(id: 'root', parent: null, pivotX: 0, pivotY: 0, z: 0),
          Bone(id: 'child', parent: 'root', pivotX: 0, pivotY: 10, z: 1),
        ],
        meshes: [
          SkinnedMeshSpec(
            id: 'front',
            vertices: const [
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'root', x: 0, y: 0, weight: 1),
              ]),
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'child', x: 1, y: 0, weight: 1),
              ]),
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'root', x: 0, y: 1, weight: 1),
              ]),
            ],
            boundary: const [0, 1, 2],
            hiddenBoneIds: const ['child'],
            z: 8,
            color: 0xFFFFFFFF,
          ),
          SkinnedMeshSpec(
            id: 'back',
            vertices: const [
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'root', x: 0, y: 0, weight: 1),
              ]),
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'child', x: 1, y: 0, weight: 1),
              ]),
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'root', x: 0, y: 1, weight: 1),
              ]),
            ],
            boundary: const [0, 1, 2],
            z: 4,
            color: 0xFFFFFFFF,
          ),
        ],
      );

      expect(rig.meshDrawOrder.map((m) => m.id), ['back', 'front']);
      expect(rig.hiddenDrawableBoneIds, {'child'});
    });

    test('throws when a ribbon references a missing bone', () {
      expect(
        () => RigSpec(
          name: 'r',
          bones: const [
            Bone(id: 'a', parent: null, pivotX: 0, pivotY: 0, z: 0),
          ],
          ribbons: [
            LimbRibbonSpec(
              id: 'bad',
              jointBoneIds: const ['a', 'missing'],
              halfWidths: const [5, 4],
              z: 0,
              color: 0xFFFFFFFF,
            ),
          ],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('missing bone'),
          ),
        ),
      );
    });

    test('throws when a skinned mesh references a missing bone', () {
      expect(
        () => RigSpec(
          name: 'r',
          bones: const [
            Bone(id: 'a', parent: null, pivotX: 0, pivotY: 0, z: 0),
          ],
          meshes: [
            SkinnedMeshSpec(
              id: 'bad',
              vertices: const [
                SkinnedMeshVertex([
                  MeshInfluence(boneId: 'a', x: 0, y: 0, weight: 1),
                ]),
                SkinnedMeshVertex([
                  MeshInfluence(boneId: 'missing', x: 1, y: 0, weight: 1),
                ]),
                SkinnedMeshVertex([
                  MeshInfluence(boneId: 'a', x: 0, y: 1, weight: 1),
                ]),
              ],
              boundary: const [0, 1, 2],
              z: 0,
              color: 0xFFFFFFFF,
            ),
          ],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('missing bone'),
          ),
        ),
      );
    });

    test('throws when skinned mesh vertex weights do not sum to one', () {
      expect(
        () => RigSpec(
          name: 'r',
          bones: const [
            Bone(id: 'a', parent: null, pivotX: 0, pivotY: 0, z: 0),
          ],
          meshes: [
            SkinnedMeshSpec(
              id: 'bad',
              vertices: const [
                SkinnedMeshVertex([
                  MeshInfluence(boneId: 'a', x: 0, y: 0, weight: 0.5),
                ]),
                SkinnedMeshVertex([
                  MeshInfluence(boneId: 'a', x: 1, y: 0, weight: 1),
                ]),
                SkinnedMeshVertex([
                  MeshInfluence(boneId: 'a', x: 0, y: 1, weight: 1),
                ]),
              ],
              boundary: const [0, 1, 2],
              z: 0,
              color: 0xFFFFFFFF,
            ),
          ],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('sum to 1'),
          ),
        ),
      );
    });

    test('throws on a duplicate ribbon id', () {
      expect(
        () => _rigWithRibbons([
          LimbRibbonSpec(
            id: 'dup',
            jointBoneIds: const ['a', 'b'],
            halfWidths: const [4, 3],
            z: 0,
            color: 0xFFFFFFFF,
          ),
          LimbRibbonSpec(
            id: 'dup',
            jointBoneIds: const ['a', 'b'],
            halfWidths: const [4, 3],
            z: 1,
            color: 0xFFFFFFFF,
          ),
        ]),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Duplicate ribbon id'),
          ),
        ),
      );
    });

    test('throws when a ribbon has fewer than two joints', () {
      expect(
        () => _rigWithRibbons([
          LimbRibbonSpec(
            id: 'short',
            jointBoneIds: const ['a'],
            halfWidths: const [4],
            z: 0,
            color: 0xFFFFFFFF,
          ),
        ]),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('at least two joints'),
          ),
        ),
      );
    });

    test('throws when ribbon joints and half-widths disagree in length', () {
      expect(
        () => _rigWithRibbons([
          LimbRibbonSpec(
            id: 'mismatch',
            jointBoneIds: const ['a', 'b'],
            halfWidths: const [4, 3, 2],
            z: 0,
            color: 0xFFFFFFFF,
          ),
        ]),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf(contains('2 joints'), contains('3 half-widths')),
          ),
        ),
      );
    });

    test('throws when ribbon back half-widths disagree in length', () {
      expect(
        () => _rigWithRibbons([
          LimbRibbonSpec(
            id: 'back-mismatch',
            jointBoneIds: const ['a', 'b'],
            halfWidths: const [4, 3],
            backHalfWidths: const [4, 3, 2],
            z: 0,
            color: 0xFFFFFFFF,
          ),
        ]),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf(contains('2 joints'), contains('3 back half-widths')),
          ),
        ),
      );
    });

    test('throws when a ribbon back half-width is not positive', () {
      expect(
        () => _rigWithRibbons([
          LimbRibbonSpec(
            id: 'back-width',
            jointBoneIds: const ['a', 'b'],
            halfWidths: const [4, 3],
            backHalfWidths: const [4, 0],
            z: 0,
            color: 0xFFFFFFFF,
          ),
        ]),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('back half-widths must be positive'),
          ),
        ),
      );
    });

    test('throws when a ribbon has non-positive samplesPerSegment', () {
      expect(
        () => _rigWithRibbons([
          LimbRibbonSpec(
            id: 'samples',
            jointBoneIds: const ['a', 'b'],
            halfWidths: const [4, 3],
            z: 0,
            color: 0xFFFFFFFF,
            samplesPerSegment: 0,
          ),
        ]),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('samplesPerSegment must be positive'),
          ),
        ),
      );
    });

    test('throws when a ribbon half-width is not positive', () {
      expect(
        () => _rigWithRibbons([
          LimbRibbonSpec(
            id: 'width',
            jointBoneIds: const ['a', 'b'],
            halfWidths: const [4, 0],
            z: 0,
            color: 0xFFFFFFFF,
          ),
        ]),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('half-widths must be positive'),
          ),
        ),
      );
    });

    test('throws on a duplicate mesh id', () {
      expect(
        () =>
            _rigWithMeshes([_validMesh('dup', z: 0), _validMesh('dup', z: 1)]),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Duplicate mesh id'),
          ),
        ),
      );
    });

    test('throws when a mesh has fewer than three vertices', () {
      expect(
        () => _rigWithMeshes([
          SkinnedMeshSpec(
            id: 'thin',
            vertices: const [
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'a', x: 0, y: 0, weight: 1),
              ]),
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'a', x: 1, y: 0, weight: 1),
              ]),
            ],
            boundary: const [0, 1],
            z: 0,
            color: 0xFFFFFFFF,
          ),
        ]),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('at least three vertices'),
          ),
        ),
      );
    });

    test('throws when a mesh has no boundary loop', () {
      expect(
        () => _rigWithMeshes([
          SkinnedMeshSpec(
            id: 'noloop',
            vertices: const [
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'a', x: 0, y: 0, weight: 1),
              ]),
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'a', x: 1, y: 0, weight: 1),
              ]),
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'a', x: 0, y: 1, weight: 1),
              ]),
            ],
            boundary: const [0, 1],
            z: 0,
            color: 0xFFFFFFFF,
          ),
        ]),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('needs a boundary loop'),
          ),
        ),
      );
    });

    test('throws when a mesh boundary index is out of range', () {
      expect(
        () => _rigWithMeshes([
          SkinnedMeshSpec(
            id: 'oob',
            vertices: const [
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'a', x: 0, y: 0, weight: 1),
              ]),
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'a', x: 1, y: 0, weight: 1),
              ]),
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'a', x: 0, y: 1, weight: 1),
              ]),
            ],
            boundary: const [0, 1, 5],
            z: 0,
            color: 0xFFFFFFFF,
          ),
        ]),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('boundary index 5 is out of range'),
          ),
        ),
      );
    });

    test('throws when a mesh ink seam has fewer than two points', () {
      expect(
        () => _rigWithMeshes([
          SkinnedMeshSpec(
            id: 'short-seam',
            vertices: const [
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'a', x: 0, y: 0, weight: 1),
              ]),
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'a', x: 1, y: 0, weight: 1),
              ]),
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'a', x: 0, y: 1, weight: 1),
              ]),
            ],
            boundary: const [0, 1, 2],
            inkSeams: const [
              [1],
            ],
            z: 0,
            color: 0xFFFFFFFF,
          ),
        ]),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('ink seams need at least two points'),
          ),
        ),
      );
    });

    test('throws when a mesh ink seam index is out of range', () {
      expect(
        () => _rigWithMeshes([
          SkinnedMeshSpec(
            id: 'bad-seam',
            vertices: const [
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'a', x: 0, y: 0, weight: 1),
              ]),
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'a', x: 1, y: 0, weight: 1),
              ]),
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'a', x: 0, y: 1, weight: 1),
              ]),
            ],
            boundary: const [0, 1, 2],
            inkSeams: const [
              [0, 5],
            ],
            z: 0,
            color: 0xFFFFFFFF,
          ),
        ]),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('ink seam index 5 is out of range'),
          ),
        ),
      );
    });

    test('throws when a mesh vertex has no influences', () {
      expect(
        () => _rigWithMeshes([
          SkinnedMeshSpec(
            id: 'unweighted',
            vertices: const [
              SkinnedMeshVertex([]),
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'a', x: 1, y: 0, weight: 1),
              ]),
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'a', x: 0, y: 1, weight: 1),
              ]),
            ],
            boundary: const [0, 1, 2],
            z: 0,
            color: 0xFFFFFFFF,
          ),
        ]),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('unweighted vertex'),
          ),
        ),
      );
    });

    test('throws when a mesh influence weight is not positive', () {
      expect(
        () => _rigWithMeshes([
          SkinnedMeshSpec(
            id: 'badweight',
            vertices: const [
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'a', x: 0, y: 0, weight: 0),
              ]),
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'a', x: 1, y: 0, weight: 1),
              ]),
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'a', x: 0, y: 1, weight: 1),
              ]),
            ],
            boundary: const [0, 1, 2],
            z: 0,
            color: 0xFFFFFFFF,
          ),
        ]),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('weights must be positive'),
          ),
        ),
      );
    });

    test('throws when a mesh hides a missing bone', () {
      expect(
        () => _rigWithMeshes([
          SkinnedMeshSpec(
            id: 'hide',
            vertices: const [
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'a', x: 0, y: 0, weight: 1),
              ]),
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'a', x: 1, y: 0, weight: 1),
              ]),
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'a', x: 0, y: 1, weight: 1),
              ]),
            ],
            boundary: const [0, 1, 2],
            hiddenBoneIds: const ['ghost'],
            z: 0,
            color: 0xFFFFFFFF,
          ),
        ]),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('references missing bone "ghost"'),
          ),
        ),
      );
    });

    test('a runtime cel-shade spec keeps defaults and attaches to a rig', () {
      // Non-const argument forces the const CelShadeSpec constructor to run at
      // runtime so its body is counted.
      final shade = CelShadeSpec(shadowFactor: _runtime(0.5));
      expect(shade.shadowFactor, 0.5);
      expect(shade.coolTint, 0xFF243349);
      expect(shade.coverage, closeTo(0.42, 1e-9));

      final rig = RigSpec(name: 'r', bones: _twoBones, celShade: shade);
      expect(rig.celShade, same(shade));
    });
  });
}
