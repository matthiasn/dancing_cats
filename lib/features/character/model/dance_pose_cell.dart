import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/dance_phrase.dart';
import 'package:dancing_cats/features/character/model/easing.dart';

/// One animator-facing whole-body pose in a frame-addressed dance phrase.
///
/// A pose cell keeps support, centre-of-mass styling, limb endpoints, elbow
/// intent, and hand/foot orientation adjacent in the source. The lower-level
/// compiler still consumes ordinary [DanceBodyKey], [DanceIkTargetKey], and
/// [DanceJointKey] lists; the helpers below derive those tracks from this
/// coherent pose description.
class DancePoseCell {
  const DancePoseCell({
    required this.frame,
    required this.intent,
    required this.supportFootIds,
    required this.body,
    this.limbs = const {},
    this.joints = const {},
  });

  final int frame;
  final String intent;

  /// Feet carrying weight from this cell until the next cell. Two ids mean
  /// double support; an empty list means an explicitly airborne pose.
  final List<String> supportFootIds;

  final DancePoseBody body;

  /// IK end-bone id -> authored limb pose.
  final Map<String, DancePoseLimb> limbs;

  /// FK bone id -> orientation/scale layered on the whole-body silhouette.
  final Map<String, DancePoseJoint> joints;
}

class DancePoseBody {
  const DancePoseBody({
    this.rootDx,
    this.rootDy,
    this.rootRotation,
    this.pelvisRotation,
    this.chestRotation,
    this.chestScaleX,
    this.chestScaleY,
    this.ease = Ease.easeInOut,
    this.microFrames = 0,
  });

  final double? rootDx;
  final double? rootDy;
  final double? rootRotation;
  final double? pelvisRotation;
  final double? chestRotation;
  final double? chestScaleX;
  final double? chestScaleY;
  final Ease ease;
  final double microFrames;
}

class DancePoseLimb {
  const DancePoseLimb({
    required this.x,
    required this.y,
    this.weight = 1,
    this.ease = Ease.easeInOut,
    this.microFrames = 0,
    this.tension = 0,
    this.bendDirection,
    this.elbowAbduction = 0,
  });

  final double x;
  final double y;
  final double weight;
  final Ease ease;
  final double microFrames;
  final double tension;
  final int? bendDirection;
  final double elbowAbduction;
}

class DancePoseJoint {
  const DancePoseJoint({
    this.rotation = 0,
    this.scaleX = 1,
    this.scaleY = 1,
    this.ease = Ease.easeInOut,
    this.microFrames = 0,
    this.tension = 0,
  });

  final double rotation;
  final double scaleX;
  final double scaleY;
  final Ease ease;
  final double microFrames;
  final double tension;
}

List<DanceBodyKey> bodyKeysFromPoseCells(List<DancePoseCell> cells) => [
  for (final cell in cells)
    DanceBodyKey(
      cell.frame,
      rootDx: cell.body.rootDx,
      rootDy: cell.body.rootDy,
      rootRotation: cell.body.rootRotation,
      pelvisRotation: cell.body.pelvisRotation,
      chestRotation: cell.body.chestRotation,
      chestScaleX: cell.body.chestScaleX,
      chestScaleY: cell.body.chestScaleY,
      ease: cell.body.ease,
      microFrames: cell.body.microFrames,
    ),
];

List<DanceIkTargetKey> limbKeysFromPoseCells(
  List<DancePoseCell> cells,
  String endBoneId,
) {
  final keys = <DanceIkTargetKey>[];
  for (final cell in cells) {
    final limb = cell.limbs[endBoneId];
    if (limb == null) continue;
    keys.add(
      DanceIkTargetKey(
        cell.frame,
        x: limb.x,
        y: limb.y,
        weight: limb.weight,
        ease: limb.ease,
        microFrames: limb.microFrames,
        tension: limb.tension,
        bendDirection: limb.bendDirection,
        elbowAbduction: limb.elbowAbduction,
      ),
    );
  }
  return keys;
}

List<DanceJointKey> jointKeysFromPoseCells(
  List<DancePoseCell> cells,
  String boneId,
) {
  final keys = <DanceJointKey>[];
  for (final cell in cells) {
    final joint = cell.joints[boneId];
    if (joint == null) continue;
    keys.add(
      DanceJointKey(
        cell.frame,
        rotation: joint.rotation,
        scaleX: joint.scaleX,
        scaleY: joint.scaleY,
        ease: joint.ease,
        microFrames: joint.microFrames,
        tension: joint.tension,
      ),
    );
  }
  return keys;
}

/// Converts the pose cells' support declarations into continuous contact spans.
///
/// Adjacent cells that keep the same support foot MUST share one span.  A span
/// boundary is not merely overlay metadata: the runtime samples a new planted
/// world anchor at every boundary.  Splitting a sustained plant at every
/// in-between pose therefore makes the floor anchor chase the animated foot,
/// and the painter's final floor pin cancels the authored pelvis compression.
/// Coalescing identical adjacent support sets preserves the dancer's plant
/// until the choreography actually transfers weight.
List<GroundSpan> contactSpansFromPoseCells(
  List<DancePoseCell> cells,
  int frameCount,
) {
  if (cells.isEmpty) return const [];
  final ordered = [...cells]..sort((a, b) => a.frame.compareTo(b.frame));
  final spans = <GroundSpan>[];
  final activeStarts = <String, int>{};
  var previous = <String>{};
  for (final cell in ordered) {
    final current = cell.supportFootIds.toSet();
    for (final footId in previous.difference(current)) {
      final start = activeStarts.remove(footId);
      if (start != null && cell.frame > start) {
        spans.add(
          GroundSpan(footId, start / frameCount, cell.frame / frameCount),
        );
      }
    }
    for (final footId in current.difference(previous)) {
      activeStarts[footId] = cell.frame;
    }
    previous = current;
  }
  for (final entry in activeStarts.entries) {
    if (frameCount > entry.value) {
      spans.add(
        GroundSpan(entry.key, entry.value / frameCount, 1),
      );
    }
  }
  spans.sort((a, b) => a.start.compareTo(b.start));
  return spans;
}
