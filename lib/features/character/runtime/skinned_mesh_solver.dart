import 'package:dancing_cats/features/character/model/affine2d.dart';
import 'package:dancing_cats/features/character/model/rig_spec.dart';

/// Resolves a skinned mesh into world-space vertices using the same linear
/// blend skinning model the renderer paints.
///
/// Returns `null` when any influence bone is absent from [world], matching the
/// renderer's behavior of skipping incomplete meshes.
List<({double x, double y})>? resolveSkinnedMeshVertices(
  SkinnedMeshSpec mesh,
  Map<String, Affine2D> world,
) {
  final points = <({double x, double y})>[];
  for (final vertex in mesh.vertices) {
    var x = 0.0;
    var y = 0.0;
    for (final influence in vertex.influences) {
      final transform = world[influence.boneId];
      if (transform == null) return null;
      final p = transform.transformPoint(influence.x, influence.y);
      x += p.x * influence.weight;
      y += p.y * influence.weight;
    }
    points.add((x: x, y: y));
  }
  return points;
}
