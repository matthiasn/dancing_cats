import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/dance_dynamics.dart';

/// Beats per 32-frame phrase loop, in clip time (the catalog moves' accents
/// land on this 8-way grid — frames 0/4/8/12/16/20/24/28 of the 32-frame
/// phrase). The beat-local warp re-syncs every dancer at each of these
/// boundaries regardless of dynamics.
const int kDanceBeatsPerPhraseLoop = 8;

/// Global strength of the upper-body Effort time warp. `0` (the value this
/// ships with until the tuning commit) makes [upperBodyDynamicsWarpedClip]
/// return its input clip unchanged — every call site downstream of this
/// constant is already wired but inert.
const double kDanceDynamicsTimeWarpGain = 0;

/// Returns [clip] with its [warpBoneIds] channels and hand IK targets wrapped
/// in a beat-local Effort time warp for [effective] dynamics — every other
/// bone (in particular the root, legs, and feet) keeps sampling [clip]'s
/// unwarped, shared clock.
///
/// Returns the SAME [clip] instance (not an equal copy — `identical`) when
/// [effective] is neutral, [gain] is zero, or the clip is a one-shot/empty —
/// this is what makes the mechanism a provable no-op before the tuning
/// commit populates real dynamics, and a cheap early-out at steady state
/// after.
Clip upperBodyDynamicsWarpedClip(
  Clip clip,
  DanceDynamics effective, {
  required Set<String> warpBoneIds,
  int beatsPerLoop = kDanceBeatsPerPhraseLoop,
  double gain = kDanceDynamicsTimeWarpGain,
}) {
  if (effective.isNeutral || gain == 0 || !clip.loop || clip.duration <= 0) {
    return clip;
  }

  final unitWarp = dynamicsTimeWarp(effective, gain: gain);

  // Maps a full-clip phase (0..1) through the per-beat warp, wrapping any
  // anticipation dip / overshoot across the cyclic loop seam so it always
  // resolves to a valid 0..1 phase for the wrapped inner channel.
  double warpPhase(double p) {
    final scaledPhase = p * beatsPerLoop;
    final beatIndex = scaledPhase.floorToDouble();
    final beatLocal = scaledPhase - beatIndex;
    var warped = (beatIndex + unitWarp(beatLocal)) / beatsPerLoop;
    warped -= warped.floorToDouble();
    return warped < 0 ? warped + 1 : warped;
  }

  final channels = {
    for (final entry in clip.channels.entries)
      entry.key: warpBoneIds.contains(entry.key)
          ? PhaseWarpedJointChannel(entry.value, warpPhase)
          : entry.value,
  };

  final limbTargets = [
    for (final target in clip.limbTargets)
      warpBoneIds.contains(target.endBoneId)
          ? target.withChannel(
              PhaseWarpedIkTargetChannel(target.channel, warpPhase),
            )
          : target,
  ];

  return Clip(
    name: clip.name,
    duration: clip.duration,
    channels: channels,
    loop: clip.loop,
    root: clip.root,
    locomotionSpeed: clip.locomotionSpeed,
    groundSpans: clip.groundSpans,
    contactSpans: clip.contactSpans,
    contactPinning: clip.contactPinning,
    limbTargets: limbTargets,
    supportFootWorldAnchor: clip.supportFootWorldAnchor,
    supportFootWorldAnchorStrength: clip.supportFootWorldAnchorStrength,
    danceHeadBobScale: clip.danceHeadBobScale,
    danceHeadLevelClampMin: clip.danceHeadLevelClampMin,
    enforceSoleFloor: clip.enforceSoleFloor,
    transitionPlan: clip.transitionPlan,
    zOrderSwaps: clip.zOrderSwaps,
    dynamics: clip.dynamics,
  );
}
