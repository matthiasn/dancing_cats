import 'dart:math' as math;

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
      // An inertialized channel already bakes the move's Time/Flow into its
      // hold → snap → settle timing; phase-warping its sampling clock on top
      // would double-count Time and shift the hits off their beats. It owns the
      // hand timing, so the Effort warp leaves it alone.
      warpBoneIds.contains(target.endBoneId) &&
              target.channel is! InertializedIkTargetChannel
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

/// Hand IK-target bones the effort/amplitude modulation acts on (the fast,
/// expressive hands — the legs/feet keep their own grounded motion). These are
/// the rig's dotted bone-id strings (`CatBones.handL`/`handR` = 'hand.L'/'hand.R').
const Set<String> kDanceEffortHandBoneIds = {'hand.L', 'hand.R'};

/// Deterministic per-loop amplitude "breath": a periodic (loop-seamless)
/// pseudo-irregular envelope in ~[-1, 1] so effort varies BEAT TO BEAT — some
/// beats reach the extreme, others hold back — instead of a flat scale (owner:
/// "not just flat, there should be deterministic variance"). Integer harmonics
/// keep it periodic over the loop (scaleOf(0)==scaleOf(1)); the non-1:2 ratios
/// (3/5/8) keep it from repeating every beat; [lanePhase] offsets each dancer so
/// the trio doesn't breathe in lockstep. Deterministic — reproducible across
/// renders and testable, not random jitter.
double danceEffortVariance(double p, double lanePhase) {
  final t = 2 * math.pi * p;
  return 0.55 * math.sin(3 * t + lanePhase) +
      0.30 * math.sin(5 * t + 1.7 * lanePhase) +
      0.15 * math.sin(8 * t + 2.3 * lanePhase);
}

/// How strongly the SONG-ENERGY arc scales movement size — the owner's "increase
/// the arc with a factor" dial. At this factor a calm section (level 0) scales
/// the base DOWN to (1 − factor) and a hot section (level 1) UP to (1 + factor);
/// mid-energy (0.5) is neutral. Driven by the RAW section-energy level, not the
/// move's Effort weight — the moves' own base weights (zanku 0.7, buga 0.5…)
/// dominate that, and the ±0.35 modulation budget clamps the energy out, so the
/// weight path only gave ~±13%. This is the isolated, amplifiable arc.
const double kDanceEffortEnergyArc = 0.48;

/// Effort amplitude scale as a function of loop phase for one dancer: a
/// song-energy base times the deterministic beat-to-beat [danceEffortVariance]
/// breath. Fast timing is untouched — only how BIG each move gets changes.
/// [energyLevel] is the raw 0..1 section energy.
///
/// The base only ever SHRINKS the authored motion (hot section = full authored
/// ≈ 1.0, calm = down to `1 − arc`). The catalogue's authored hand poses already
/// sit near the arm's max reach, so scaling ABOVE 1.0 shoved the IK target ~40%
/// past reach and the elbow clamped/flipped into impossible poses. So the arc is
/// "calm is smaller, hot is full," never "hot is bigger," and the clamp keeps a
/// hair of variance headroom below reach.
double Function(double) danceEffortScaleOf(double energyLevel, int lane) {
  final base = 1.0 - kDanceEffortEnergyArc * (1 - energyLevel.clamp(0, 1));
  final lanePhase = lane * 2.1; // distinct, deterministic per dancer
  const varGain = 0.22;
  return (p) => (base * (1 + varGain * danceEffortVariance(p, lanePhase)))
      .clamp(0.3, 1.02);
}

/// Returns [clip] with its [boneIds] hand IK targets amplitude-modulated by the
/// phase-dependent [scaleOf] (see [AmplitudeScaledIkTargetChannel]) — the effort
/// dial with deterministic variance. Timing/frequency is untouched (the fast
/// base motion stays); only how big each hand move gets changes over the loop.
/// Returns the SAME clip when no hand target matches or the clip is a one-shot.
Clip effortModulatedClip(
  Clip clip,
  double Function(double p) scaleOf, {
  Set<String> boneIds = kDanceEffortHandBoneIds,
}) {
  if (!clip.loop || clip.duration <= 0 || clip.limbTargets.isEmpty) return clip;
  var changed = false;
  final limbTargets = [
    for (final target in clip.limbTargets)
      if (boneIds.contains(target.endBoneId)) ...[
        () {
          changed = true;
          return target.withChannel(
            AmplitudeScaledIkTargetChannel(target.channel, scaleOf),
          );
        }(),
      ] else
        target,
  ];
  if (!changed) return clip;
  return Clip(
    name: clip.name,
    duration: clip.duration,
    channels: clip.channels,
    loop: clip.loop,
    root: clip.root,
    locomotionSpeed: clip.locomotionSpeed,
    groundSpans: clip.groundSpans,
    contactSpans: clip.contactSpans,
    contactPinning: clip.contactPinning,
    limbTargets: limbTargets,
    supportFootWorldAnchor: clip.supportFootWorldAnchor,
    supportFootWorldAnchorStrength: clip.supportFootWorldAnchorStrength,
    supportFootWorldAnchorVerticalBoost: clip.supportFootWorldAnchorVerticalBoost,
    danceHeadBobScale: clip.danceHeadBobScale,
    danceHeadLevelClampMin: clip.danceHeadLevelClampMin,
    enforceSoleFloor: clip.enforceSoleFloor,
    transitionPlan: clip.transitionPlan,
    zOrderSwaps: clip.zOrderSwaps,
    dynamics: clip.dynamics,
  );
}

/// How the song energy scales the WHOLE-BODY groove (sway, bob, dips) — the
/// owner's "whole-body amplitude". Low energy shrinks the groove (eased through
/// the breakdown), high energy fills it out. Clamped so a hot section can't
/// throw the dips past a plausible depth. Neutral-ish (~1) at chorus energy.
double danceBodyGrooveScaleOf(double energyLevel) =>
    (0.6 + 0.4 * energyLevel.clamp(0, 1)).clamp(0.6, 1.05);

/// Returns [clip] with its root MOTION (sway/bob/dips) scaled by [scale],
/// mean-preserving (see [ScaledRootChannel]) — whole-body amplitude reacting to
/// the song energy. Same clip back at scale 1 or for a one-shot/empty clip.
Clip bodyGrooveScaledClip(Clip clip, double scale) {
  if (scale == 1.0 || !clip.loop || clip.duration <= 0) return clip;
  return Clip(
    name: clip.name,
    duration: clip.duration,
    channels: clip.channels,
    loop: clip.loop,
    root: ScaledRootChannel(clip.root, scale),
    locomotionSpeed: clip.locomotionSpeed,
    groundSpans: clip.groundSpans,
    contactSpans: clip.contactSpans,
    contactPinning: clip.contactPinning,
    limbTargets: clip.limbTargets,
    supportFootWorldAnchor: clip.supportFootWorldAnchor,
    supportFootWorldAnchorStrength: clip.supportFootWorldAnchorStrength,
    supportFootWorldAnchorVerticalBoost: clip.supportFootWorldAnchorVerticalBoost,
    danceHeadBobScale: clip.danceHeadBobScale,
    danceHeadLevelClampMin: clip.danceHeadLevelClampMin,
    enforceSoleFloor: clip.enforceSoleFloor,
    transitionPlan: clip.transitionPlan,
    zOrderSwaps: clip.zOrderSwaps,
    dynamics: clip.dynamics,
  );
}

/// How many root-units the strongest accent drops the body — turned into a
/// knee-bending plié by the support-foot anchor (see [RootDyOffsetChannel]).
const double kDanceAccentDropUnits = 16;

/// Returns [clip] with a constant [dropDy] added to its root — the music accent
/// as a grounded body dip (the support-foot anchor bends the knee into a plié,
/// feet stay planted). Same clip back at 0.
Clip accentDroppedClip(Clip clip, double dropDy) {
  if (dropDy == 0 || clip.duration <= 0) return clip;
  return Clip(
    name: clip.name,
    duration: clip.duration,
    channels: clip.channels,
    loop: clip.loop,
    root: RootDyOffsetChannel(clip.root, dropDy),
    locomotionSpeed: clip.locomotionSpeed,
    groundSpans: clip.groundSpans,
    contactSpans: clip.contactSpans,
    contactPinning: clip.contactPinning,
    limbTargets: clip.limbTargets,
    supportFootWorldAnchor: clip.supportFootWorldAnchor,
    supportFootWorldAnchorStrength: clip.supportFootWorldAnchorStrength,
    supportFootWorldAnchorVerticalBoost: clip.supportFootWorldAnchorVerticalBoost,
    danceHeadBobScale: clip.danceHeadBobScale,
    danceHeadLevelClampMin: clip.danceHeadLevelClampMin,
    enforceSoleFloor: clip.enforceSoleFloor,
    transitionPlan: clip.transitionPlan,
    zOrderSwaps: clip.zOrderSwaps,
    dynamics: clip.dynamics,
  );
}

/// Always-on shoulder + chest WIND (coach: the Afrobeats pocket is upper-body-
/// led — the shoulders/chest roll continuously so the torso is never a static
/// posed post while the hips bounce underneath). Small, loop-seamless (integer
/// harmonics), per-lane phase so the trio isn't in lockstep.
const double kDanceShoulderWindAmplitude = 0.026;
const double kDanceChestWindAmplitude = 0.03;
const int kDanceShoulderWindHarmonic = 2;

/// Returns [clip] with a small continuous sine roll added to the clavicles
/// (opposite phase L/R = a shoulder roll) and the chest, so the upper body keeps
/// winding even between authored poses. Live-path; same clip back if disabled or
/// no shoulder/chest channel is present.
Clip shoulderWoundClip(Clip clip, int lane) {
  if (!clip.loop || clip.duration <= 0 || kDanceShoulderWindAmplitude == 0) {
    return clip;
  }
  final lanePhase = lane * 0.17;
  var changed = false;
  final channels = <String, JointChannel>{};
  clip.channels.forEach((id, ch) {
    if (id == 'clavicle.L') {
      channels[id] = WoundJointChannel(
        ch,
        amplitude: kDanceShoulderWindAmplitude,
        harmonic: kDanceShoulderWindHarmonic,
        phase: lanePhase,
      );
      changed = true;
    } else if (id == 'clavicle.R') {
      channels[id] = WoundJointChannel(
        ch,
        amplitude: -kDanceShoulderWindAmplitude,
        harmonic: kDanceShoulderWindHarmonic,
        phase: lanePhase,
      );
      changed = true;
    } else if (id == 'torso' || id == 'chest') {
      channels[id] = WoundJointChannel(
        ch,
        amplitude: kDanceChestWindAmplitude,
        harmonic: 3,
        phase: lanePhase + 0.12,
      );
      changed = true;
    } else {
      channels[id] = ch;
    }
  });
  if (!changed) return clip;
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
    limbTargets: clip.limbTargets,
    supportFootWorldAnchor: clip.supportFootWorldAnchor,
    supportFootWorldAnchorStrength: clip.supportFootWorldAnchorStrength,
    supportFootWorldAnchorVerticalBoost: clip.supportFootWorldAnchorVerticalBoost,
    danceHeadBobScale: clip.danceHeadBobScale,
    danceHeadLevelClampMin: clip.danceHeadLevelClampMin,
    enforceSoleFloor: clip.enforceSoleFloor,
    transitionPlan: clip.transitionPlan,
    zOrderSwaps: clip.zOrderSwaps,
    dynamics: clip.dynamics,
  );
}

/// Radius/revs of the always-on FAST-BASE hand orbit (owner: real dance hands
/// carry continuous fast motion, 2-4x the per-beat pose rate). Small radius so
/// it reads as alive/rolling without whipping the elbow; integer revs keep it
/// loop-seamless. Tunable by eye in the app. Set radius 0 to disable.
const double kDanceFastBaseOrbitRadius = 8;
const int kDanceFastBaseOrbitRevs = 5;

/// Returns [clip] with its [boneIds] hand IK targets carrying a small fast
/// [OrbitedIkTargetChannel] orbit — the "fast base always on" layer. Per-lane
/// phase (trio not in lockstep) and opposite L/R phase (the two hands
/// counter-rotate — "around each other"). Applied UNDER the effort amplitude
/// scale so it breathes with the song energy. Same clip back when disabled or
/// no hand target matches.
Clip fastBaseOrbitedClip(
  Clip clip,
  int lane, {
  Set<String> boneIds = kDanceEffortHandBoneIds,
}) {
  if (!clip.loop ||
      clip.duration <= 0 ||
      kDanceFastBaseOrbitRadius == 0 ||
      clip.limbTargets.isEmpty) {
    return clip;
  }
  final lanePhase = lane * 1.3;
  final limbTargets = <LimbIkTarget>[];
  var changed = false;
  for (final target in clip.limbTargets) {
    if (boneIds.contains(target.endBoneId)) {
      // Both hands share the orbit phase (a parallel wobble), NOT opposite: an
      // opposite phase made the two hands sweep toward centre and read as
      // rotating THROUGH each other. Parallel keeps their gap and never crosses.
      limbTargets.add(
        target.withChannel(
          OrbitedIkTargetChannel(
            target.channel,
            radius: kDanceFastBaseOrbitRadius,
            revs: kDanceFastBaseOrbitRevs,
            phase: lanePhase,
          ),
        ),
      );
      changed = true;
    } else {
      limbTargets.add(target);
    }
  }
  if (!changed) return clip;
  return Clip(
    name: clip.name,
    duration: clip.duration,
    channels: clip.channels,
    loop: clip.loop,
    root: clip.root,
    locomotionSpeed: clip.locomotionSpeed,
    groundSpans: clip.groundSpans,
    contactSpans: clip.contactSpans,
    contactPinning: clip.contactPinning,
    limbTargets: limbTargets,
    supportFootWorldAnchor: clip.supportFootWorldAnchor,
    supportFootWorldAnchorStrength: clip.supportFootWorldAnchorStrength,
    supportFootWorldAnchorVerticalBoost: clip.supportFootWorldAnchorVerticalBoost,
    danceHeadBobScale: clip.danceHeadBobScale,
    danceHeadLevelClampMin: clip.danceHeadLevelClampMin,
    enforceSoleFloor: clip.enforceSoleFloor,
    transitionPlan: clip.transitionPlan,
    zOrderSwaps: clip.zOrderSwaps,
    dynamics: clip.dynamics,
  );
}
