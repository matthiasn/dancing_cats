import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/dance_dynamics.dart';

/// Beats per 32-frame phrase loop, in clip time (the catalog moves' accents
/// land on this 8-way grid — frames 0/4/8/12/16/20/24/28 of the 32-frame
/// phrase). The beat-local warp re-syncs every dancer at each of these
/// boundaries regardless of dynamics.
const int kDanceBeatsPerPhraseLoop = 8;

/// Global strength of the upper-body Effort time warp. A perceptual dial
/// (ADR CHAR-0001 D6) tuned by eye on rendered 60fps motion per ADR
/// CHAR-0003's rollout: `0` was the plumbing PR's provable-no-op value.
/// `0.35` was the tuning PR's starting point; a 4-lens motion-review panel
/// found the differentiation real but too subtle/intermittent to read at
/// normal viewing scale (lane-to-lane hand-position deltas exceeded 5 units
/// on only ~4% of the loop), so this raised to `0.5` (~13% of the loop),
/// the owner-approved trade-off point before jerk cost on zanku (the
/// catalog's most extreme Strong/Sudden move) grows too fast — see the
/// warped-jerk ceiling note in `dance_dynamics_split_clock_test.dart`.
const double kDanceDynamicsTimeWarpGain = 0.5;

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
    supportFootWorldAnchorVerticalBoost:
        clip.supportFootWorldAnchorVerticalBoost,
    danceHeadBobScale: clip.danceHeadBobScale,
    danceHeadLevelClampMin: clip.danceHeadLevelClampMin,
    enforceSoleFloor: clip.enforceSoleFloor,
    transitionPlan: clip.transitionPlan,
    zOrderSwaps: clip.zOrderSwaps,
    dynamics: clip.dynamics,
  );
}
