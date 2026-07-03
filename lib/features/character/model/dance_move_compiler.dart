import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/dance_move_descriptor.dart';
import 'package:dancing_cats/features/character/model/dance_phrase.dart';

/// Assembles a full [Clip] from a [DanceMoveDescriptor] against a shared
/// [phrase]'s frame-addressed timing.
///
/// This is the move-level counterpart to `DancePhrase`'s lower-level channel
/// builders (`jointChannel`, `bodyRootChannel`, `ikTargetChannel`, ...): where
/// those turn one list of keys into one channel, this turns a whole move
/// descriptor into a complete, playable [Clip] — the step every shipped move
/// in `cat_in_suit.dart` currently does by hand, mixing phrase-builder calls
/// with raw engine primitives inline in its own getter.
///
/// [rigLimbTargets] supplies the rig's bone-chain bindings (upper/lower/end/
/// anchor bone ids + bend direction) for each limb, since those are rig
/// constants shared by every move — only the IK target *channel* varies per
/// move. A track in [DanceMoveDescriptor.limbTargetTracks] whose key matches
/// a `rigLimbTargets` entry's `endBoneId` rebinds that entry's channel via
/// `LimbIkTarget.withChannel`; entries with no matching track keep the rig's
/// default channel unchanged.
Clip assembleMoveClip(
  DancePhrase phrase,
  DanceMoveDescriptor descriptor, {
  List<LimbIkTarget> rigLimbTargets = const [],
}) {
  final base = descriptor.baseClip;

  final channels = <String, JointChannel>{...?base?.channels};

  descriptor.jointTracks.forEach((boneId, track) {
    final compiled = phrase.jointChannel(track.keys, smooth: track.smooth);
    channels[boneId] = track.layerOnBase
        ? LayeredJointChannel([channels[boneId]!, compiled])
        : compiled;
  });

  var root = base?.root ?? const SineRootChannel();
  final bodyMotion = descriptor.bodyMotion;
  if (bodyMotion != null) {
    root = LayeredRootChannel([
      for (final track in bodyMotion.tracks)
        phrase.bodyRootChannel(
          _reKeyedBodyKeys(track.keys, microFrames: track.rootMicroFrames),
          smooth: track.rootSmooth,
        ),
      ...bodyMotion.extraRootLayers,
    ]);

    channels[bodyMotion.pelvisBoneId] = LayeredJointChannel([
      for (final track in bodyMotion.tracks)
        phrase.bodyPelvisChannel(
          _reKeyedBodyKeys(track.keys, microFrames: track.pelvisMicroFrames),
          smooth: track.pelvisSmooth,
        ),
      ...bodyMotion.extraPelvisLayers,
    ]);
    channels[bodyMotion.chestBoneId] = LayeredJointChannel([
      for (final track in bodyMotion.tracks)
        phrase.bodyChestChannel(
          _dampedChestKeys(
            track.keys,
            microFrames: track.chestMicroFrames,
            rotationGain: track.chestRotationGain,
            scaleGain: track.chestScaleGain,
          ),
          smooth: track.chestSmooth,
        ),
      ...bodyMotion.extraChestLayers,
    ]);
  }

  final limbTargets = [
    for (final limb in rigLimbTargets)
      if (descriptor.limbTargetTracks[limb.endBoneId] case final track?)
        limb.withChannel(
          phrase.ikTargetChannel(
            track.keys,
            smooth: track.smooth,
            cyclic: track.cyclic,
            microFrames: track.microFrames,
          ),
        )
      else
        limb,
  ];

  channels.addAll(descriptor.extraJointChannels);

  return Clip(
    name: descriptor.move.name,
    duration: descriptor.duration,
    channels: channels,
    loop: descriptor.loop,
    root: root,
    locomotionSpeed:
        descriptor.locomotionSpeed ?? base?.locomotionSpeed ?? 0,
    contactSpans: [
      for (final support in descriptor.supports) support.toGroundSpan(phrase),
      ...descriptor.rawContactSpans,
    ],
    contactPinning:
        descriptor.contactPinning ??
        base?.contactPinning ??
        ContactPinning.activeSpan,
    limbTargets: limbTargets,
    supportFootWorldAnchor:
        descriptor.supportFootWorldAnchor ??
        base?.supportFootWorldAnchor ??
        false,
    supportFootWorldAnchorStrength:
        descriptor.supportFootWorldAnchorStrength ??
        base?.supportFootWorldAnchorStrength ??
        0.6,
    danceHeadBobScale:
        descriptor.danceHeadBobScale ?? base?.danceHeadBobScale ?? 1,
    danceHeadLevelClampMin:
        descriptor.danceHeadLevelClampMin ??
        base?.danceHeadLevelClampMin ??
        -2,
    transitionPlan: descriptor.transitionPlan ?? base?.transitionPlan,
    zOrderSwaps: descriptor.zOrderSwaps.isNotEmpty
        ? descriptor.zOrderSwaps
        : base?.zOrderSwaps ?? const [],
  );
}

double? _scaleValue(double? value, double gain) =>
    value == null ? null : value * gain;

double? _scaleMultiplier(double? value, double gain) =>
    value == null ? null : 1 + (value - 1) * gain;

List<DanceBodyKey> _reKeyedBodyKeys(
  List<DanceBodyKey> keys, {
  required double microFrames,
}) => [
  for (final key in keys)
    DanceBodyKey(
      key.frame,
      rootDx: key.rootDx,
      rootDy: key.rootDy,
      rootRotation: key.rootRotation,
      pelvisRotation: key.pelvisRotation,
      chestRotation: key.chestRotation,
      chestScaleX: key.chestScaleX,
      chestScaleY: key.chestScaleY,
      ease: key.ease,
      microFrames: microFrames,
    ),
];

List<DanceBodyKey> _dampedChestKeys(
  List<DanceBodyKey> keys, {
  required double microFrames,
  required double rotationGain,
  required double scaleGain,
}) => [
  for (final key in keys)
    if (key.hasChest)
      DanceBodyKey(
        key.frame,
        chestRotation: _scaleValue(key.chestRotation, rotationGain),
        chestScaleX: _scaleMultiplier(key.chestScaleX, scaleGain),
        chestScaleY: _scaleMultiplier(key.chestScaleY, scaleGain),
        ease: key.ease,
        microFrames: microFrames,
      ),
];
