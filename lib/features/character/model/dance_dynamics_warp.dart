import 'dart:math' as math;

import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/dance_dynamics.dart';

/// Beats per 32-frame phrase loop, in clip time (the catalog moves' accents
/// land on this 8-way grid — frames 0/4/8/12/16/20/24/28 of the 32-frame
/// phrase). The beat-local warp re-syncs every dancer at each of these
/// boundaries regardless of dynamics.
const int kDanceBeatsPerPhraseLoop = 8;

/// Per-lane upper-body microtiming in normalized clip phase. The lead owns the
/// beat; backup-left anticipates by roughly 24ms and backup-right drags by
/// roughly 32ms at Moving's production clock (one 6s authored loop played over
/// four real seconds). Only upper-body channels and hand IK receive this shift;
/// the support chain stays on the shared beat clock.
const List<double> kDanceLaneUpperBodyPhaseOffsets = [0, 0.006, -0.008];

/// Per-lane hand-path amplitude for the Moving family (lead, backup-left,
/// backup-right): a STATIC spread applied through `effortModulatedClip`'s
/// mean-preserving amplitude dial. Moving opts out of the beat-breathing
/// effort modulation, which left unison statements running pixel-identical
/// arm paths (the ±24-32ms lane offsets are sub-frame — invisible); a
/// 5-12% inter-cat spread is enough that no two cats hit the same reach
/// while the authored path shape survives on every lane. The spread is
/// deliberately ONE-SIDED (nobody exceeds the authored 1.0): the lead owns
/// the fullest reach — backups layering beneath the hero is the natural
/// staging — and scaling any lane above 1.0 pushed the hottest phrases'
/// arm velocities past the full-song continuity bands.
const List<double> kMovingLaneAmplitudeScale = [1.0, 0.88, 0.95];

/// CALL-AND-RESPONSE echo, in normalized clip phase: the side-answer phrase,
/// when scored on the RIGHT FLANK, answers ONE BEAT behind the lead's call
/// instead of moving simultaneously (round-2/3 cartoon/coach finding).
/// Negative = the lane samples earlier content, i.e. arrives late. One beat
/// on Moving's eight-beat loop = 1/8. Applied by baking a shifted
/// SCORE-LEVEL clip variant (see `DancePerformance`'s echo side-answer):
/// applying it as a production-stage wrapper popped a 0.125s upper-body
/// teleport at the dance→idle exit, because a phase offset wrapped around a
/// BLENDED clip shifts the outgoing side by the two clips' duration ratio
/// rather than by its own phase.
///
/// The displacement is a FULL beat (not the half-beat first tried): the
/// shifted contact spans put the variant's first support handoff at
/// `shift × loop` seconds after a statement entry, and a half-beat put that
/// handoff INSIDE the entry blend window — the to-side anchor changed feet
/// mid-blend and the flank's foot measured 7.4-11.2 units/frame² against
/// the 7-unit band at every chorus entry. At one beat the handoff lands
/// ~0.52s in, clear of every blend window — and a beat-late answer reads
/// more clearly as an answer anyway.
const double kMovingEchoPhase = -1 / 8 - 0.008;

/// The right flank's echo displacement in BEATS — the value a
/// [wholeClipPhaseShiftedClip] of [kMovingEchoPhase] carries as
/// `Clip.echoBeats`. The reprise accent hold keys on it to pick the one-beat
/// answer voice out of a continuously-lerping blend.
const double kMovingEchoAnswerBeats =
    -kMovingEchoPhase * kDanceBeatsPerPhraseLoop;

/// The GREY (left-flank) canon delay: TWO beats behind the lead's call in
/// the hook statement — a featured, unmistakable answer voice (round-3
/// coach: "the trio reads lead + echo + filler"), distinct from the right
/// flank's one-beat echo so the three voices never collapse into two. Two
/// beats is span-grid-aligned (the quarter-note support rota maps onto
/// itself), so the canon variant has no seam stubs at all.
///
/// Both displacements carry a few extra milliseconds of HUMANIZATION
/// (kMovingEchoPhase −25ms, canon +29ms): with pure beat-grid shifts every
/// cat's foot strikes land on the identical frame at every shared beat —
/// round-4 biomech measured 0-frame plant coincidence across the trio and
/// read it as "drill-team symmetry under one master clock; human backup
/// dancers land 20-60ms apart even on unison choreography". Widened to
/// ±0.008 phase (±34ms of clip time) with OPPOSITE signs in round 6: the
/// round-5 deltas moved the cats off the grid but left some lead-flank
/// pairs inside one 30fps frame bucket. The deltas remain far smaller than
/// any blend window, so support handoffs stay clear of statement entries.
const double kMovingCanonPhase = -2 / 8 + 0.008;

/// Extra upper-body delay on the grey canon quote, re-locking its arms to
/// its feet: the source phrase's arm accents ride ~50-80ms hot of its
/// footwork — style on the lead, smear on the quote (round-6 animator).
const double kMovingCanonArmRelock = -0.015;

/// Returns [clip] with EVERYTHING shifted by [phaseShift] — every joint
/// channel, hand and foot IK target, the root, and the phase-ranged data
/// (contact spans, ground spans, z-order windows) — so the whole dancer,
/// steps and weight changes included, performs the same phrase displaced in
/// time. This is the full-body call-and-response variant: shifting only the
/// upper body reads as a timing offset (round-3 measured whole-body
/// correlation still peaking at lag 0 because the shared feet dominate);
/// shifting the whole clip makes the answer a separate visible event.
///
/// Spans/windows that cross the loop seam are split in two; the runtime's
/// same-bone first/last wrap-join re-fuses the contact pair. Because the
/// motion AND its contact metadata shift together, the span-vs-authored-feet
/// consistency that protects the support anchor is preserved by
/// construction (gated by test).
Clip wholeClipPhaseShiftedClip(Clip clip, double phaseShift) {
  if (phaseShift == 0 || !clip.loop || clip.duration <= 0) return clip;

  double shifted(double p) {
    var s = p + phaseShift;
    s -= s.floorToDouble();
    return s < 0 ? s + 1 : s;
  }

  // Content authored at phase q appears at playback phase q + delay.
  final delay = -phaseShift;
  double moved(double edge) {
    var e = edge + delay;
    e -= e.floorToDouble();
    return e < 0 ? e + 1 : e;
  }

  List<GroundSpan> shiftSpans(List<GroundSpan> spans) {
    final out = <GroundSpan>[];
    for (final s in spans) {
      final a = moved(s.start);
      // A span ending exactly at 1 must keep ending at the seam, not at 0.
      final rawB = moved(s.end);
      final b = s.end > s.start && rawB <= a ? rawB + 1 : rawB;
      if (b <= 1) {
        out.add(GroundSpan(s.bone, a, b));
      } else {
        out
          ..add(GroundSpan(s.bone, a, 1))
          ..add(GroundSpan(s.bone, 0, b - 1));
      }
    }
    out.sort((x, y) => x.start.compareTo(y.start));
    return out;
  }

  List<ZOrderSwapWindow> shiftWindows(List<ZOrderSwapWindow> windows) {
    final out = <ZOrderSwapWindow>[];
    for (final w in windows) {
      final a = moved(w.start);
      final rawB = moved(w.end);
      final b = w.end > w.start && rawB <= a ? rawB + 1 : rawB;
      ZOrderSwapWindow part(double s, double e) => ZOrderSwapWindow(
        boneA: w.boneA,
        boneB: w.boneB,
        start: s,
        end: e,
        swap: w.swap,
        shadeBehind: w.shadeBehind,
      );
      if (b <= 1) {
        out.add(part(a, b));
      } else {
        out
          ..add(part(a, 1))
          ..add(part(0, b - 1));
      }
    }
    out.sort((x, y) => x.start.compareTo(y.start));
    return out;
  }

  return Clip(
    name: clip.name,
    family: clip.family,
    echoBeats: -phaseShift * kDanceBeatsPerPhraseLoop,
    duration: clip.duration,
    channels: {
      for (final entry in clip.channels.entries)
        entry.key: PhaseWarpedJointChannel(entry.value, shifted),
    },
    loop: clip.loop,
    root: PhaseShiftedRootChannel(clip.root, phaseShift),
    locomotionSpeed: clip.locomotionSpeed,
    groundSpans: shiftSpans(clip.groundSpans),
    contactSpans: shiftSpans(clip.contactSpans),
    contactPinning: clip.contactPinning,
    limbTargets: [
      for (final target in clip.limbTargets)
        target.withChannel(
          PhaseWarpedIkTargetChannel(target.channel, shifted),
        ),
    ],
    supportFootWorldAnchor: clip.supportFootWorldAnchor,
    supportFootWorldAnchorStrength: clip.supportFootWorldAnchorStrength,
    supportFootWorldAnchorVerticalBoost:
        clip.supportFootWorldAnchorVerticalBoost,
    danceHeadBobScale: clip.danceHeadBobScale,
    danceHeadLevelClampMin: clip.danceHeadLevelClampMin,
    armReachScale: clip.armReachScale,
    headLateralStabilize: clip.headLateralStabilize,
    enforceSoleFloor: clip.enforceSoleFloor,
    transitionPlan: clip.transitionPlan,
    zOrderSwaps: shiftWindows(clip.zOrderSwaps),
    dynamics: clip.dynamics,
  );
}

/// Width of the Moving upper-body loop recovery at either side of the phrase
/// seam, in normalized six-second clip phase. At production's 1.5x clock this
/// is about 180ms: enough to carry arm momentum through the wrap without
/// softening the phrase's interior accents or changing any support timing.
const double kMovingUpperBodySeamEaseWidth = 0.045;

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
    family: clip.family,
    echoBeats: clip.echoBeats,
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
    armReachScale: clip.armReachScale,
    headLateralStabilize: clip.headLateralStabilize,
    enforceSoleFloor: clip.enforceSoleFloor,
    transitionPlan: clip.transitionPlan,
    zOrderSwaps: clip.zOrderSwaps,
    dynamics: clip.dynamics,
  );
}

/// Returns [clip] with a constant cyclic phase offset applied only to
/// [upperBodyBoneIds] and matching hand IK targets.
///
/// This creates crew microtiming without the foot pops caused by shifting a
/// whole dancer's sampled time. Every support/contact-critical channel remains
/// the original object and therefore samples bit-identically.
///
/// The offset is deliberately CONSTANT in clip phase. A phase-varying offset
/// ("breathing" microtiming) was tried and reverted: any offset that is a
/// function of the sampled phase changes value discontinuously at a blend
/// boundary, where the wrapper's clock switches from the outgoing to the
/// incoming clip — the full-song production probe measured the resulting
/// upper-body jump at 5.1 units/frame² against the 3.1 transition band. If
/// per-event microtiming returns, it must blend across both transition clocks
/// the way `shoulderWoundClip` blends its additive wind.
Clip upperBodyPhaseOffsetClip(
  Clip clip,
  double phaseOffset, {
  required Set<String> upperBodyBoneIds,
}) {
  if (phaseOffset == 0 || !clip.loop || clip.duration <= 0) return clip;

  double shiftedPhase(double p) {
    var shifted = p + phaseOffset;
    shifted -= shifted.floorToDouble();
    return shifted < 0 ? shifted + 1 : shifted;
  }

  final channels = {
    for (final entry in clip.channels.entries)
      entry.key: upperBodyBoneIds.contains(entry.key)
          ? PhaseWarpedJointChannel(entry.value, shiftedPhase)
          : entry.value,
  };
  final limbTargets = [
    for (final target in clip.limbTargets)
      upperBodyBoneIds.contains(target.endBoneId)
          ? target.withChannel(
              PhaseWarpedIkTargetChannel(target.channel, shiftedPhase),
            )
          : target,
  ];

  return Clip(
    name: clip.name,
    family: clip.family,
    echoBeats: clip.echoBeats,
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
    armReachScale: clip.armReachScale,
    headLateralStabilize: clip.headLateralStabilize,
    enforceSoleFloor: clip.enforceSoleFloor,
    transitionPlan: clip.transitionPlan,
    zOrderSwaps: clip.zOrderSwaps,
    dynamics: clip.dynamics,
  );
}

/// Settles a cyclic upper body into its shared phase-0/1 pose near the seam.
///
/// Authored Moving clips already return to the same pose at phase 0/1, but
/// several arrive with an outgoing tangent opposite their opening tangent.
/// Played at 1.5x, that position-continuous reversal can still read as a
/// one-frame arm teleport. Pose-space settling reaches zero velocity at the
/// seam and rejoins the original pose with zero velocity/acceleration error at
/// [width], without ever speeding the sampling clock to catch up. Root, legs,
/// feet, contacts, and support anchors are deliberately untouched.
Clip upperBodyLoopSeamEasedClip(
  Clip clip, {
  required Set<String> upperBodyBoneIds,
  double width = kMovingUpperBodySeamEaseWidth,
}) {
  if (!clip.loop || clip.duration <= 0 || width <= 0) {
    return clip;
  }
  assert(width < 0.5, 'loop-seam settle width must be below half a loop');

  final channels = {
    for (final entry in clip.channels.entries)
      entry.key: upperBodyBoneIds.contains(entry.key)
          ? LoopSeamSettledJointChannel(entry.value, width: width)
          : entry.value,
  };
  final limbTargets = [
    for (final target in clip.limbTargets)
      upperBodyBoneIds.contains(target.endBoneId)
          ? target.withChannel(
              LoopSeamSettledIkTargetChannel(target.channel, width: width),
            )
          : target,
  ];

  return Clip(
    name: clip.name,
    family: clip.family,
    echoBeats: clip.echoBeats,
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
    armReachScale: clip.armReachScale,
    headLateralStabilize: clip.headLateralStabilize,
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
    family: clip.family,
    echoBeats: clip.echoBeats,
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
    supportFootWorldAnchorVerticalBoost:
        clip.supportFootWorldAnchorVerticalBoost,
    danceHeadBobScale: clip.danceHeadBobScale,
    danceHeadLevelClampMin: clip.danceHeadLevelClampMin,
    armReachScale: clip.armReachScale,
    headLateralStabilize: clip.headLateralStabilize,
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
    family: clip.family,
    echoBeats: clip.echoBeats,
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
    supportFootWorldAnchorVerticalBoost:
        clip.supportFootWorldAnchorVerticalBoost,
    danceHeadBobScale: clip.danceHeadBobScale,
    danceHeadLevelClampMin: clip.danceHeadLevelClampMin,
    armReachScale: clip.armReachScale,
    headLateralStabilize: clip.headLateralStabilize,
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
///
/// [bobDuck] > 0 additionally scales the authored root MOTION (its deviation
/// from the loop mean, see [ScaledRootChannel]) down by that fraction for the
/// frame — the authored groove momentarily YIELDS to the hit. Without it, a
/// strong onset landing where the authored bob is rising reads counter-phase:
/// the lights flare while the body travels up through them (the full-song
/// audit measured the export's biggest bloom riding a rising lead in the
/// finale). Ducking the bob hands the vertical to the accent envelope exactly
/// while the hit owns the moment, then returns it as the envelope decays.
Clip accentDroppedClip(
  Clip clip,
  double dropDy, {
  double bobDuck = 0,
  double chestCompress = 0,
}) {
  if ((dropDy == 0 && bobDuck == 0 && chestCompress == 0) ||
      clip.duration <= 0) {
    return clip;
  }
  final ducked = bobDuck > 0
      ? ScaledRootChannel(clip.root, (1 - bobDuck).clamp(0.0, 1.0))
      : clip.root;
  // The hit's mass travels THROUGH the trunk: a small chest compression on
  // the same envelope as the plié (round-2 biomech: "torso pitch and hip
  // angle stay rigid through the hit — spring-loaded rather than
  // muscle-damped"; animator: accents carried "by limbs and head only").
  final channels = chestCompress > 0
      ? {
          for (final entry in clip.channels.entries)
            entry.key: (entry.key == 'chest' || entry.key == 'torso')
                ? CompressedJointChannel(
                    entry.value,
                    (1 - chestCompress).clamp(0.0, 1.0),
                  )
                : entry.value,
        }
      : clip.channels;
  return Clip(
    name: clip.name,
    family: clip.family,
    echoBeats: clip.echoBeats,
    duration: clip.duration,
    channels: channels,
    loop: clip.loop,
    root: RootDyOffsetChannel(ducked, dropDy),
    locomotionSpeed: clip.locomotionSpeed,
    groundSpans: clip.groundSpans,
    contactSpans: clip.contactSpans,
    contactPinning: clip.contactPinning,
    limbTargets: clip.limbTargets,
    supportFootWorldAnchor: clip.supportFootWorldAnchor,
    supportFootWorldAnchorStrength: clip.supportFootWorldAnchorStrength,
    supportFootWorldAnchorVerticalBoost:
        clip.supportFootWorldAnchorVerticalBoost,
    danceHeadBobScale: clip.danceHeadBobScale,
    danceHeadLevelClampMin: clip.danceHeadLevelClampMin,
    armReachScale: clip.armReachScale,
    headLateralStabilize: clip.headLateralStabilize,
    enforceSoleFloor: clip.enforceSoleFloor,
    transitionPlan: clip.transitionPlan,
    zOrderSwaps: clip.zOrderSwaps,
    dynamics: clip.dynamics,
  );
}

/// Returns [clip] with per-frame additive offsets on the two hand IK targets
/// — the flourish layer that varies what the hands do on each hit (per-onset
/// ornament flavors + rare double/quad-time pickup fills; the values are
/// computed per frame by `DancePerformance.laneHandFlourishFor` and are
/// continuous in song time by construction). Offsetting the IK TARGET moves
/// the whole arm through the solver, so the elbow follows naturally and the
/// authored path shape underneath is untouched. Identity when the flourish
/// is zero.
Clip handFlourishedClip(
  Clip clip,
  ({double lx, double ly, double rx, double ry}) flourish, {
  String leftHandBoneId = 'hand.L',
  String rightHandBoneId = 'hand.R',
}) {
  if ((flourish.lx == 0 &&
          flourish.ly == 0 &&
          flourish.rx == 0 &&
          flourish.ry == 0) ||
      clip.duration <= 0) {
    return clip;
  }
  LimbIkTarget offset(LimbIkTarget target, double dx, double dy) =>
      target.withChannel(
        LayeredIkTargetChannel([
          target.channel,
          FixedIkTargetChannel(x: dx, y: dy),
        ]),
      );
  var changed = false;
  final limbTargets = clip.limbTargets.map((target) {
    if (target.endBoneId == leftHandBoneId) {
      changed = true;
      return offset(target, flourish.lx, flourish.ly);
    }
    if (target.endBoneId == rightHandBoneId) {
      changed = true;
      return offset(target, flourish.rx, flourish.ry);
    }
    return target;
  }).toList();
  if (!changed) return clip;
  return Clip(
    name: clip.name,
    family: clip.family,
    echoBeats: clip.echoBeats,
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
    supportFootWorldAnchorVerticalBoost:
        clip.supportFootWorldAnchorVerticalBoost,
    danceHeadBobScale: clip.danceHeadBobScale,
    danceHeadLevelClampMin: clip.danceHeadLevelClampMin,
    armReachScale: clip.armReachScale,
    headLateralStabilize: clip.headLateralStabilize,
    enforceSoleFloor: clip.enforceSoleFloor,
    transitionPlan: clip.transitionPlan,
    zOrderSwaps: clip.zOrderSwaps,
    dynamics: clip.dynamics,
  );
}

/// How far the Moving family's vertical bounce lane is retarded, in seconds.
/// The v91 musicality panel measured the deepest plié bottom landing 113 to
/// 155ms BEFORE the beat in every dance section (tight IQRs, confirmed by an
/// independent vertical-velocity phase profile) — the body rising through
/// the beat instead of landing weight into it, "eager" against the track's
/// laid-back pocket. Limb-accent apexes measured on-grid (+5..+67ms), so
/// only the root's dy is delayed: sway, turn, footwork and contact phases
/// keep the authored clock.
const double kMovingBobRetardSec = 0.12;

/// Returns [clip] with its root dy sampled [delaySec] late (wrapping the
/// loop) — see [kMovingBobRetardSec]. Identity for non-looping clips and
/// zero delay.
Clip bobRetardedClip(Clip clip, double delaySec) {
  if (delaySec == 0 || !clip.loop || clip.duration <= 0) return clip;
  return Clip(
    name: clip.name,
    family: clip.family,
    echoBeats: clip.echoBeats,
    duration: clip.duration,
    channels: clip.channels,
    loop: clip.loop,
    root: DelayedDyRootChannel(clip.root, delaySec / clip.duration),
    locomotionSpeed: clip.locomotionSpeed,
    groundSpans: clip.groundSpans,
    contactSpans: clip.contactSpans,
    contactPinning: clip.contactPinning,
    limbTargets: clip.limbTargets,
    supportFootWorldAnchor: clip.supportFootWorldAnchor,
    supportFootWorldAnchorStrength: clip.supportFootWorldAnchorStrength,
    supportFootWorldAnchorVerticalBoost:
        clip.supportFootWorldAnchorVerticalBoost,
    danceHeadBobScale: clip.danceHeadBobScale,
    danceHeadLevelClampMin: clip.danceHeadLevelClampMin,
    armReachScale: clip.armReachScale,
    headLateralStabilize: clip.headLateralStabilize,
    enforceSoleFloor: clip.enforceSoleFloor,
    transitionPlan: clip.transitionPlan,
    zOrderSwaps: clip.zOrderSwaps,
    dynamics: clip.dynamics,
  );
}

/// How far the toe beans swing apart at full splay (radians), how much they
/// swell (scale multiplier at full splay), and how far the thumb swings OPEN
/// from its resting curl. Together they turn the closed resting paw into a
/// visibly open hand — skeletally, so the opening is as continuous as the
/// envelope driving it (no sprite swap, no pop).
const double kDancePawToeSplayRad = 0.6;
const double kDancePawToeSplayScale = 0.28;
const double kDancePawThumbOpenRad = 0.55;

/// Returns [clip] with per-frame paw ARTICULATION layered onto the hand,
/// toe-bean, and thumb joint channels: wrist rotation (the paw lags/aligns
/// instead of riding the forearm like a mitten on a stick) and a 0..1 splay
/// that swings the toe beans apart, swells them, and opens the thumb from
/// its resting curl. Values come per frame from
/// `DancePerformance.lanePawPoseFor` and are continuous in song time by
/// construction. The left/right rigs are mirrored, so rotations flip sign
/// per side. Identity when the paws are at rest.
Clip pawArticulatedClip(
  Clip clip,
  ({double wristL, double splayL, double wristR, double splayR}) paw,
) {
  if ((paw.wristL == 0 &&
          paw.splayL == 0 &&
          paw.wristR == 0 &&
          paw.splayR == 0) ||
      clip.duration <= 0) {
    return clip;
  }
  JointChannel layered(JointChannel? base, double rotation, double scale) {
    final fixed = FixedJointChannel(
      rotation: rotation,
      scaleX: scale,
      scaleY: scale,
    );
    return base == null ? fixed : LayeredJointChannel([base, fixed]);
  }

  final channels = Map<String, JointChannel>.of(clip.channels);
  void articulate(
    String side, // 'L' or 'R'
    double wrist,
    double splay,
  ) {
    if (wrist == 0 && splay == 0) return;
    final sign = side == 'L' ? 1.0 : -1.0;
    final hand = 'hand.$side';
    channels[hand] = layered(channels[hand], wrist, 1);
    final toeSwing = kDancePawToeSplayRad * splay;
    final toeScale = 1 + kDancePawToeSplayScale * splay;
    channels['paw_toe1.$side'] = layered(
      channels['paw_toe1.$side'],
      sign * -toeSwing,
      toeScale,
    );
    channels['paw_toe2.$side'] = layered(
      channels['paw_toe2.$side'],
      sign * toeSwing,
      toeScale,
    );
    channels['thumb.$side'] = layered(
      channels['thumb.$side'],
      sign * kDancePawThumbOpenRad * splay,
      1,
    );
  }

  articulate('L', paw.wristL, paw.splayL);
  articulate('R', paw.wristR, paw.splayR);
  return Clip(
    name: clip.name,
    family: clip.family,
    echoBeats: clip.echoBeats,
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
    supportFootWorldAnchorVerticalBoost:
        clip.supportFootWorldAnchorVerticalBoost,
    danceHeadBobScale: clip.danceHeadBobScale,
    danceHeadLevelClampMin: clip.danceHeadLevelClampMin,
    armReachScale: clip.armReachScale,
    headLateralStabilize: clip.headLateralStabilize,
    enforceSoleFloor: clip.enforceSoleFloor,
    transitionPlan: clip.transitionPlan,
    zOrderSwaps: clip.zOrderSwaps,
    dynamics: clip.dynamics,
  );
}

/// Peak quiet-step body load, in root units: how far the pelvis dips when a
/// foot is authored fully airborne (scaled by lift height up to
/// [kDanceSingleSupportLiftRef]). Independent of the accent envelope — real
/// weight transfers load the stance even where the music is quiet (round-2
/// biomech: "a weight transfer with zero pelvic dip still reads faintly
/// weightless where the groove is quiet").
const double kDanceSingleSupportDipUnits = 3.2;

/// Foot lift (rig units above its planted level) that earns the full
/// single-support dip.
const double kDanceSingleSupportLiftRef = 20;

/// Returns [clip] with a small phase-driven root dip while either foot is
/// authored off the deck — the body LOADS its quiet steps. The envelope is
/// precomputed from the authored foot IK targets at 64 samples (each foot's
/// planted level is its own loop maximum y) and interpolated linearly, so
/// the dip follows exactly the footwork that is already there. Applied
/// inside the production-clip cache; same clip back when the clip has no
/// foot targets or never lifts.
Clip singleSupportLoadedClip(
  Clip clip, {
  double dipUnits = kDanceSingleSupportDipUnits,
}) {
  if (!clip.loop || clip.duration <= 0 || dipUnits == 0) return clip;
  final feet = [
    for (final t in clip.limbTargets)
      if (t.endBoneId.startsWith('foot')) t.channel,
  ];
  if (feet.isEmpty) return clip;

  const n = 64;
  final lift = List<double>.filled(n, 0);
  for (final foot in feet) {
    var planted = double.negativeInfinity;
    final ys = List<double>.generate(n, (i) => foot.sample(i / n).y);
    for (final y in ys) {
      if (y > planted) planted = y;
    }
    for (var i = 0; i < n; i++) {
      final raised = planted - ys[i];
      if (raised > lift[i]) lift[i] = raised;
    }
  }
  var any = false;
  final dip = List<double>.generate(n, (i) {
    final u = (lift[i] / kDanceSingleSupportLiftRef).clamp(0.0, 1.0);
    final d = dipUnits * u * u * (3 - 2 * u);
    if (d > 0.01) any = true;
    return d;
  });
  if (!any) return clip;

  double dipOf(double p) {
    final x = (p - p.floorToDouble()) * n;
    final i = x.floor() % n;
    final f = x - x.floorToDouble();
    return dip[i] * (1 - f) + dip[(i + 1) % n] * f;
  }

  return Clip(
    name: clip.name,
    family: clip.family,
    echoBeats: clip.echoBeats,
    duration: clip.duration,
    channels: clip.channels,
    loop: clip.loop,
    root: EnvelopeRootDyChannel(clip.root, dipOf),
    locomotionSpeed: clip.locomotionSpeed,
    groundSpans: clip.groundSpans,
    contactSpans: clip.contactSpans,
    contactPinning: clip.contactPinning,
    limbTargets: clip.limbTargets,
    supportFootWorldAnchor: clip.supportFootWorldAnchor,
    supportFootWorldAnchorStrength: clip.supportFootWorldAnchorStrength,
    supportFootWorldAnchorVerticalBoost:
        clip.supportFootWorldAnchorVerticalBoost,
    danceHeadBobScale: clip.danceHeadBobScale,
    danceHeadLevelClampMin: clip.danceHeadLevelClampMin,
    armReachScale: clip.armReachScale,
    headLateralStabilize: clip.headLateralStabilize,
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

/// The Moving SPINE GROOVE: a chest hinge pumping at BEAT rate with the head
/// nodding just behind it. The wind above is texture (1.7 degrees at 1.5
/// cycles per bar) — the afrobeats panel measured through it: "the groove
/// lives only below the waist; head dead level, chest never hinges — legs
/// say Afrobeats, the upper body says corporate mascot." A pulse-locked
/// hinge (~2.6 degrees per beat) with the head trailing ~75ms turns the
/// column into a wave up the body. Head lag is expressed in loop phase
/// (0.019 of the 8-beat loop ≈ 75ms at this track's ~119 BPM).
const double kMovingSpineHingeRad = 0.045;
const double kMovingSpineHeadNodRad = 0.028;
const int kMovingSpineBeatHarmonic = 8;
const double kMovingSpineHeadLagPhase = 0.019;

/// Returns [clip] with the Moving spine groove layered on (chest hinge at
/// beat rate + lagged head nod, see the constants above), scaled by
/// [energyLevel] so the valley pumps quietly and the drops pump full. Same
/// blend-safe additive construction as [shoulderWoundClip]: inside a
/// transition the sine is blended across BOTH sides' clocks, never freshly
/// phased on the incoming clock. Moving family only; same clip back
/// otherwise.
Clip spineGroovedClip(Clip clip, int lane, double energyLevel) {
  if (!clip.loop || clip.duration <= 0 || !clip.belongsToFamily('moving')) {
    return clip;
  }
  final scale = 0.45 + 0.55 * energyLevel.clamp(0.0, 1.0);
  final lanePhase = lane * 0.11;
  JointChannel grooved(
    JointChannel base, {
    required double amplitude,
    required double phase,
  }) {
    final plan = clip.transitionPlan;
    if (plan == null) {
      return WoundJointChannel(
        base,
        amplitude: amplitude,
        harmonic: kMovingSpineBeatHarmonic,
        phase: phase,
      );
    }
    JointChannel pumpChannel() => SineChannel(
      harmonicAmplitude: amplitude,
      harmonicMultiplier: kMovingSpineBeatHarmonic.toDouble(),
      harmonicPhase: phase,
    );
    return LayeredJointChannel([
      base,
      BlendedJointChannel(
        from: pumpChannel(),
        to: pumpChannel(),
        weight: plan.weight,
        fromTimeShift: plan.fromTimeShiftSeconds,
        fromDuration: plan.from.duration,
        toDuration: plan.to.duration,
      ),
    ]);
  }

  var changed = false;
  final channels = <String, JointChannel>{};
  clip.channels.forEach((id, ch) {
    if (id == 'torso' || id == 'chest') {
      channels[id] = grooved(
        ch,
        amplitude: kMovingSpineHingeRad * scale,
        phase: lanePhase,
      );
      changed = true;
    } else if (id == 'head') {
      channels[id] = grooved(
        ch,
        amplitude: kMovingSpineHeadNodRad * scale,
        phase: lanePhase - kMovingSpineHeadLagPhase,
      );
      changed = true;
    } else {
      channels[id] = ch;
    }
  });
  if (!changed) return clip;
  return Clip(
    name: clip.name,
    family: clip.family,
    echoBeats: clip.echoBeats,
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
    supportFootWorldAnchorVerticalBoost:
        clip.supportFootWorldAnchorVerticalBoost,
    danceHeadBobScale: clip.danceHeadBobScale,
    danceHeadLevelClampMin: clip.danceHeadLevelClampMin,
    armReachScale: clip.armReachScale,
    headLateralStabilize: clip.headLateralStabilize,
    enforceSoleFloor: clip.enforceSoleFloor,
    transitionPlan: clip.transitionPlan,
    zOrderSwaps: clip.zOrderSwaps,
    dynamics: clip.dynamics,
  );
}

/// Returns [clip] with a small continuous sine roll added to the clavicles
/// (opposite phase L/R = a shoulder roll) and the chest, so the upper body keeps
/// winding even between authored poses. Live-path; same clip back if disabled or
/// no shoulder/chest channel is present.
Clip shoulderWoundClip(Clip clip, int lane) {
  if (!clip.loop || clip.duration <= 0 || kDanceShoulderWindAmplitude == 0) {
    return clip;
  }
  final lanePhase = lane * 0.17;
  JointChannel wound(
    JointChannel base, {
    required double amplitude,
    required int harmonic,
    required double phase,
  }) {
    final plan = clip.transitionPlan;
    if (plan == null) {
      return WoundJointChannel(
        base,
        amplitude: amplitude,
        harmonic: harmonic,
        phase: phase,
      );
    }
    // The choreography channels inside a blended clip sample the outgoing
    // phrase on its shifted clock. Layering a fresh sine around that blend used
    // the incoming clock for the wind even at weight zero, phase-jumping the
    // clavicles and therefore both hands at every score cut. Blend the additive
    // wind itself across the same two clocks, then layer it onto the pose.
    JointChannel windChannel() => SineChannel(
      harmonicAmplitude: amplitude,
      harmonicMultiplier: harmonic.toDouble(),
      harmonicPhase: phase,
    );
    return LayeredJointChannel([
      base,
      BlendedJointChannel(
        from: windChannel(),
        to: windChannel(),
        weight: plan.weight,
        fromTimeShift: plan.fromTimeShiftSeconds,
        fromDuration: plan.from.duration,
        toDuration: plan.to.duration,
      ),
    ]);
  }

  var changed = false;
  final channels = <String, JointChannel>{};
  clip.channels.forEach((id, ch) {
    if (id == 'clavicle.L') {
      channels[id] = wound(
        ch,
        amplitude: kDanceShoulderWindAmplitude,
        harmonic: kDanceShoulderWindHarmonic,
        phase: lanePhase,
      );
      changed = true;
    } else if (id == 'clavicle.R') {
      channels[id] = wound(
        ch,
        amplitude: -kDanceShoulderWindAmplitude,
        harmonic: kDanceShoulderWindHarmonic,
        phase: lanePhase,
      );
      changed = true;
    } else if (id == 'torso' || id == 'chest') {
      channels[id] = wound(
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
    family: clip.family,
    echoBeats: clip.echoBeats,
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
    supportFootWorldAnchorVerticalBoost:
        clip.supportFootWorldAnchorVerticalBoost,
    danceHeadBobScale: clip.danceHeadBobScale,
    danceHeadLevelClampMin: clip.danceHeadLevelClampMin,
    armReachScale: clip.armReachScale,
    headLateralStabilize: clip.headLateralStabilize,
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
  double radius = kDanceFastBaseOrbitRadius,
  int revs = kDanceFastBaseOrbitRevs,
}) {
  if (!clip.loop ||
      clip.duration <= 0 ||
      radius == 0 ||
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
            radius: radius,
            revs: revs,
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
    family: clip.family,
    echoBeats: clip.echoBeats,
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
    supportFootWorldAnchorVerticalBoost:
        clip.supportFootWorldAnchorVerticalBoost,
    danceHeadBobScale: clip.danceHeadBobScale,
    danceHeadLevelClampMin: clip.danceHeadLevelClampMin,
    armReachScale: clip.armReachScale,
    headLateralStabilize: clip.headLateralStabilize,
    enforceSoleFloor: clip.enforceSoleFloor,
    transitionPlan: clip.transitionPlan,
    zOrderSwaps: clip.zOrderSwaps,
    dynamics: clip.dynamics,
  );
}
