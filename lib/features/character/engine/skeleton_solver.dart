import 'package:dancing_cats/features/character/model/affine2d.dart';
import 'package:dancing_cats/features/character/model/bone.dart';
import 'package:dancing_cats/features/character/model/pose.dart';
import 'package:dancing_cats/features/character/model/rig_spec.dart';

/// Forward kinematics: turns a [RigSpec] + a [Pose] into a world [Affine2D] for
/// every bone. Pure Dart and allocation-light — the math hot path the plan
/// requires to be trivial on low-end devices.
class SkeletonSolver {
  SkeletonSolver(this.rig);

  final RigSpec rig;

  /// Per-bone multiplier on the bone's local `pivotY` (its length down from its
  /// parent), keyed by bone id. Empty (the default) is a byte-identical no-op.
  /// Used for a per-CLIP limb-reach override: scaling the arm-chain bones'
  /// pivotY lengthens the drawn arm AND — because the two-bone IK derives its
  /// segment lengths from the SOLVED bone origins — the IK reach, consistently,
  /// so a move whose signature gesture is reach-maxed can extend without the
  /// hand missing its target. Set per-frame from the active clip; a move that
  /// does not opt in leaves this empty and is unchanged.
  Map<String, double> limbPivotYScale = const {};

  /// Computes the world transform of each bone, keyed by bone id.
  ///
  /// [base] places the character in the world (locomotion + canvas position);
  /// it defaults to the identity. The root pose offset ([Pose.rootDx] etc.) is
  /// applied on top of [base] so body bob and lean move the whole skeleton.
  Map<String, Affine2D> solve(Pose pose, {Affine2D base = Affine2D.identity}) {
    final world = <String, Affine2D>{};
    final rootBase = base
        .multiply(Affine2D.translation(pose.rootDx, pose.rootDy))
        .multiply(Affine2D.rotation(pose.rootRotation));

    final scales = limbPivotYScale;
    for (final bone in rig.topoOrder) {
      final jp = pose.jointOf(bone.id);
      final pivotYScale = scales.isEmpty ? 1.0 : (scales[bone.id] ?? 1.0);
      final local = Affine2D.trs(
        pivotX: bone.pivotX,
        pivotY: bone.pivotY * pivotYScale,
        rotation: bone.restRotation + jp.rotation,
        scaleX: bone.restScaleX * jp.scaleX,
        scaleY: bone.restScaleY * jp.scaleY,
      );
      final parentId = bone.parent;
      final parentWorld = parentId == null ? rootBase : world[parentId]!;
      world[bone.id] = parentWorld.multiply(local);
    }
    return world;
  }

  /// Convenience: the world-space position of a bone's pivot (its joint).
  /// Handy for tests (assert the hand lands where the math says) and for the
  /// gap-detection gauntlet later.
  ({double x, double y}) jointWorldPosition(
    Map<String, Affine2D> world,
    String boneId,
  ) {
    final w = world[boneId]!;
    return w.origin;
  }

  /// The world-space position of a point [localX], [localY] expressed in a
  /// bone's local space.
  ({double x, double y}) localToWorld(
    Map<String, Affine2D> world,
    String boneId,
    double localX,
    double localY,
  ) => world[boneId]!.transformPoint(localX, localY);

  /// Returns the bone that owns a given [BoneDrawable] reference identity,
  /// kept for symmetry with the painter; unused drawables are tolerated.
  Bone? boneFor(String id) => rig.bone(id);
}
