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
///
/// A move typically layers SEVERAL of these (one per authored key set — a
/// base groove, a signature accent, a per-move pocket boost, ...) via
/// [DanceBodyMotion.tracks]; each track keeps its own timing/gain so the
/// layers can lead/lag independently before being summed.
class DanceBodyMotionTrack {
  const DanceBodyMotionTrack({
    required this.keys,
    this.rootMicroFrames = -0.35,
    this.pelvisMicroFrames = -0.55,
    this.chestMicroFrames = 0.55,
    this.chestRotationGain = 0.88,
    this.chestScaleGain = 0.92,
    this.rootSmooth = true,
    this.pelvisSmooth = true,
    this.chestSmooth = true,
  });

  final List<DanceBodyKey> keys;
  final double rootMicroFrames;
  final double pelvisMicroFrames;
  final double chestMicroFrames;

  /// Linear damping applied to each key's `chestRotation`: `1` leaves it
  /// unchanged, `0` zeroes it out.
  final double chestRotationGain;

  /// Damping applied to chest `scaleX`/`scaleY` around their neutral `1`:
  /// `1` leaves it unchanged, `0` flattens it to no scale change.
  final double chestScaleGain;

  /// Each channel's `smooth` is independent, matching the private
  /// `_bodyRootLeadChannel`/`_bodyPelvisLeadChannel`/`_bodyChestFollowChannel`
  /// helpers, which are three separate calls each with their own `smooth`.
  final bool rootSmooth;
  final bool pelvisSmooth;
  final bool chestSmooth;
}

/// A move's full body-groove composition: one or more independently-timed
/// [DanceBodyMotionTrack]s (each an authored `DanceBodyKey` set, e.g. a base
/// groove plus a signature accent plus a per-move pocket boost) summed
/// together, optionally topped with pure-procedural texture layers that
/// carry no authored key data (e.g. a small always-on `SineChannel`
/// micro-wobble) — mirroring how every shipped move stacks N key-driven
/// layers followed by M texture-only layers on root/hips/torso via
/// `LayeredRootChannel`/`LayeredJointChannel`.
class DanceBodyMotion {
  const DanceBodyMotion({
    required this.tracks,
    required this.pelvisBoneId,
    required this.chestBoneId,
    this.extraRootLayers = const [],
    this.extraPelvisLayers = const [],
    this.extraChestLayers = const [],
  });

  final List<DanceBodyMotionTrack> tracks;

  /// Rig bone id the pelvis channel is written to.
  final String pelvisBoneId;

  /// Rig bone id the chest channel is written to.
  final String chestBoneId;

  /// Pure-procedural root layers (no authored key data), appended after
  /// every [tracks] entry's compiled root channel.
  final List<RootChannel> extraRootLayers;

  /// Pure-procedural pelvis layers, appended after every [tracks] entry's
  /// compiled pelvis channel.
  final List<JointChannel> extraPelvisLayers;

  /// Pure-procedural chest layers, appended after every [tracks] entry's
  /// compiled chest channel.
  final List<JointChannel> extraChestLayers;
}

/// Dense per-bone keyframe data for one bone, compiled via
/// `DancePhrase.jointChannel`.
///
/// [layerOnBase] additively layers the compiled channel on top of the
/// matching bone's channel from `DanceMoveDescriptor.baseClip` (via
/// `LayeredJointChannel`) instead of replacing it outright — for a move that
/// adds a small accent on top of a shared base's procedural motion for that
/// bone rather than owning the bone's channel entirely.
class DanceJointTrack {
  const DanceJointTrack(
    this.keys, {
    this.smooth = false,
    this.layerOnBase = false,
  });

  final List<DanceJointKey> keys;
  final bool smooth;
  final bool layerOnBase;
}

/// IK target path data for one limb, compiled via
/// `DancePhrase.ikTargetChannel`.
class DanceIkTargetTrack {
  const DanceIkTargetTrack(
    this.keys, {
    this.smooth = true,
    this.cyclic = false,
    this.microFrames = 0,
  });

  final List<DanceIkTargetKey> keys;
  final bool smooth;
  final bool cyclic;

  /// Whole-channel sub-frame timing offset, passed straight through to
  /// `DancePhrase.ikTargetChannel`'s own `microFrames` parameter.
  final double microFrames;
}

/// Full data needed to assemble a [Clip] for one move: an [AfrobeatsMove] for
/// feel/dynamics/styling, plus every lower-level construct a move needs
/// (dense per-bone keyframes, body lead/lag styling, IK limb target paths,
/// support/contact spans, and the per-clip engine levers).
///
/// This is compiled by `assembleMoveClip` (`dance_move_compiler.dart`). All 6
/// catalog moves in `cat_in_suit.dart` (`buga`, `shaku`, `zanku`, `azonto`,
/// `pouncingCat`, `sekem`) are assembled this way, from their own authored
/// key data.
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
    this.rawContactSpans = const [],
    this.extraJointChannels = const {},
    this.rawRoot,
    this.supportFootWorldAnchor,
    this.supportFootWorldAnchorStrength,
    this.supportFootWorldAnchorVerticalBoost,
    this.danceHeadBobScale,
    this.danceHeadLevelClampMin,
    this.enforceSoleFloor,
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

  /// Dense per-bone keyframe data, keyed by bone id.
  final Map<String, DanceJointTrack> jointTracks;

  /// Optional body lead/lag styling composition (root/pelvis/chest).
  final DanceBodyMotion? bodyMotion;

  /// IK target path data, keyed by the limb's `endBoneId` (e.g. a hand or
  /// foot bone id). Each entry compiles to a `KeyframeIkTargetChannel` and is
  /// bound onto the matching entry of the rig's limb list at assembly time
  /// (see `assembleMoveClip`'s `rigLimbTargets` parameter).
  final Map<String, DanceIkTargetTrack> limbTargetTracks;

  /// Declared support-foot windows, converted to `Clip.contactSpans` via the
  /// existing `DanceSupportSpan.toGroundSpan`.
  final List<DanceSupportSpan> supports;

  /// Escape hatch for contact spans authored directly in phase units, when a
  /// span boundary needs sub-frame precision `DanceSupportSpan`'s integer
  /// `startFrame`/`endFrame` can't express (e.g. a boundary at frame 30.125).
  /// Appended after [supports]' converted spans.
  final List<GroundSpan> rawContactSpans;

  /// Escape hatch for bespoke, non-frame-keyed channels (e.g. a procedural
  /// sine-driven ear/tail follow-through) that don't fit the frame-key model.
  /// Overlaid last, so these win over any same-named [jointTracks] entry.
  final Map<String, JointChannel> extraJointChannels;

  /// Escape hatch for a pre-built, non-frame-keyed root channel (e.g. a
  /// one-shot phase-authored `KeyframeRootChannel` for a move with no
  /// [bodyMotion] track). Takes priority over [bodyMotion]'s compiled root
  /// and [baseClip]'s root when set.
  final RootChannel? rawRoot;

  final bool? supportFootWorldAnchor;
  final double? supportFootWorldAnchorStrength;

  /// See [Clip.supportFootWorldAnchorVerticalBoost].
  final double? supportFootWorldAnchorVerticalBoost;
  final double? danceHeadBobScale;
  final double? danceHeadLevelClampMin;

  /// See [Clip.enforceSoleFloor] — opt-in per routine.
  final bool? enforceSoleFloor;
  final List<ZOrderSwapWindow> zOrderSwaps;
  final ClipTransitionPlan? transitionPlan;

  /// Optional starting point: unset fields/tracks above fall back to this
  /// clip's channels/root/duration/contactPinning, mirroring how shipped
  /// moves diff against a shared `_danceBase` clip.
  final Clip? baseClip;
}
