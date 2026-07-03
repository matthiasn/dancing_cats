import 'package:dancing_cats/features/character/model/afrobeats_move.dart';
import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/dance_phrase.dart';

/// One authored body-groove track ([keys]) split into independently-timed
/// root/pelvis/chest channels, so a single beat lands as a natural
/// lead-then-follow wave through the body instead of every segment moving in
/// lockstep.
///
/// Mirrors the private lead/lag styling pattern hand-written per shipped move
/// in `cat_in_suit.dart` (e.g. `_bodyRootLeadChannel`/`_bodyPelvisLeadChannel`/
/// `_bodyChestFollowChannel`): the root leads the beat by [rootMicroFrames],
/// the pelvis leads by its own [pelvisMicroFrames], and the chest follows by
/// [chestMicroFrames] while its rotation/scale are damped by
/// [chestRotationGain]/[chestScaleGain] so the follow-through reads softer
/// than the initiating root/pelvis snap.
class DanceBodyMotionTrack {
  const DanceBodyMotionTrack({
    required this.keys,
    required this.pelvisBoneId,
    required this.chestBoneId,
    this.rootMicroFrames = -0.35,
    this.pelvisMicroFrames = -0.55,
    this.chestMicroFrames = 0.55,
    this.chestRotationGain = 0.88,
    this.chestScaleGain = 0.92,
    this.smooth = true,
  });

  final List<DanceBodyKey> keys;

  /// Rig bone id the pelvis channel is written to.
  final String pelvisBoneId;

  /// Rig bone id the chest channel is written to.
  final String chestBoneId;
  final double rootMicroFrames;
  final double pelvisMicroFrames;
  final double chestMicroFrames;

  /// Linear damping applied to each key's `chestRotation`: `1` leaves it
  /// unchanged, `0` zeroes it out.
  final double chestRotationGain;

  /// Damping applied to chest `scaleX`/`scaleY` around their neutral `1`:
  /// `1` leaves it unchanged, `0` flattens it to no scale change.
  final double chestScaleGain;
  final bool smooth;
}

/// Full data needed to assemble a [Clip] for one move: an [AfrobeatsMove] for
/// feel/dynamics/styling, plus every lower-level construct the shipped moves
/// in `cat_in_suit.dart` currently hand-assemble (dense per-bone keyframes,
/// body lead/lag styling, IK limb target paths, support/contact spans, and
/// the per-clip engine levers).
///
/// This is compiled by `assembleMoveClip` (`dance_move_compiler.dart`). It is
/// purely additive infrastructure — no shipped move constructs or consumes a
/// [DanceMoveDescriptor] yet.
class DanceMoveDescriptor {
  const DanceMoveDescriptor({
    required this.move,
    required this.duration,
    this.loop = true,
    this.locomotionSpeed,
    this.contactPinning,
    this.jointTracks = const {},
    this.bodyMotion,
    this.limbTargetTracks = const {},
    this.supports = const [],
    this.extraJointChannels = const {},
    this.supportFootWorldAnchor,
    this.supportFootWorldAnchorStrength,
    this.danceHeadBobScale,
    this.danceHeadLevelClampMin,
    this.zOrderSwaps = const [],
    this.transitionPlan,
    this.baseClip,
  });

  /// Feel/dynamics/styling — unchanged, reused as-is.
  final AfrobeatsMove move;

  final double duration;
  final bool loop;

  /// `null` defers to [baseClip]'s value (or the `Clip` default when there is
  /// no base).
  final double? locomotionSpeed;
  final ContactPinning? contactPinning;

  /// Dense per-bone keyframe data, keyed by bone id. Each entry compiles to
  /// one `KeyframeChannel` via `DancePhrase.jointChannel`.
  final Map<String, List<DanceJointKey>> jointTracks;

  /// Optional body lead/lag styling track (root/pelvis/chest).
  final DanceBodyMotionTrack? bodyMotion;

  /// IK target path data, keyed by the limb's `endBoneId` (e.g. a hand or
  /// foot bone id). Each entry compiles to a `KeyframeIkTargetChannel` and is
  /// bound onto the matching entry of the rig's limb list at assembly time
  /// (see `assembleMoveClip`'s `rigLimbTargets` parameter).
  final Map<String, List<DanceIkTargetKey>> limbTargetTracks;

  /// Declared support-foot windows, converted to `Clip.contactSpans` via the
  /// existing `DanceSupportSpan.toGroundSpan`.
  final List<DanceSupportSpan> supports;

  /// Escape hatch for bespoke, non-frame-keyed channels (e.g. a procedural
  /// sine-driven ear/tail follow-through) that don't fit the frame-key model.
  /// Overlaid last, so these win over any same-named [jointTracks] entry.
  final Map<String, JointChannel> extraJointChannels;

  final bool? supportFootWorldAnchor;
  final double? supportFootWorldAnchorStrength;
  final double? danceHeadBobScale;
  final double? danceHeadLevelClampMin;
  final List<ZOrderSwapWindow> zOrderSwaps;
  final ClipTransitionPlan? transitionPlan;

  /// Optional starting point: unset fields/tracks above fall back to this
  /// clip's channels/root/duration/contactPinning, mirroring how shipped
  /// moves diff against a shared `_danceBase` clip.
  final Clip? baseClip;
}
