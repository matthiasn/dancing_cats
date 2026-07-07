import 'dart:math' as math;

import 'package:dancing_cats/features/character/model/easing.dart';
import 'package:meta/meta.dart';

/// Laban-Effort *dynamics* for a dance accent: the "how" of a beat gesture,
/// kept separate from the "what" (which bone moves where, authored as the
/// keyframe values). Each factor is a signed dial in -1..1 whose extremes are
/// the opposing Effort Elements:
///
/// - [weight]: Light (-1) .. Strong (+1) — a Strong accent winds up before it
///   drives (anticipation) and arrives harder.
/// - [time]: Sustained (-1) .. Sudden (+1) — a Sudden accent snaps late
///   (accelerates into the peak); a Sustained one eases in early and
///   decelerates.
/// - [flow]: Bound (-1) .. Free (+1) — a Free accent overshoots the target and
///   settles back (follow-through); a Bound one arrives and holds without
///   overshoot.
///
/// Effort *Space* (direct/indirect) is deliberately omitted: the computational
/// Laban-Movement-Analysis literature found it the least reliable of the four
/// factors, so only Weight/Time/Flow are exposed. [neutral] (all zero)
/// reproduces a plain `easeInOut` exactly, so layering dynamics onto an existing
/// accent is opt-in and regression-free.
///
/// Const-constructible so it can live in `const` choreography data; the curve it
/// implies is built at clip-assembly time by [dynamicsCurve].
@immutable
class DanceDynamics {
  const DanceDynamics({this.weight = 0, this.time = 0, this.flow = 0});

  /// Axis-wise linear interpolation, for blending dynamics across stage
  /// transitions exactly like `blendedClip` blends its scalar clip fields.
  /// The `a·(1−t) + b·t` form makes both endpoints bit-exact, so a finished
  /// transition lands on precisely the target dynamics.
  DanceDynamics.lerp(DanceDynamics a, DanceDynamics b, double t)
    : weight = a.weight * (1 - t) + b.weight * t,
      time = a.time * (1 - t) + b.time * t,
      flow = a.flow * (1 - t) + b.flow * t;

  /// Light (-1) .. Strong (+1).
  final double weight;

  /// Sustained (-1) .. Sudden (+1).
  final double time;

  /// Bound (-1) .. Free (+1).
  final double flow;

  /// The do-nothing dynamics: maps to `easeInOut`, with no anticipation,
  /// overshoot, or snap. Used as the regression-safe default.
  static const DanceDynamics neutral = DanceDynamics();

  bool get isNeutral => weight == 0 && time == 0 && flow == 0;

  /// Axis-wise sum, unclamped. Composition (move base + cat profile + section
  /// energy) clamps once at the end via [clamped] / [effectiveDanceDynamics],
  /// not per term, so offsets cancel before they saturate.
  DanceDynamics operator +(DanceDynamics other) => DanceDynamics(
    weight: weight + other.weight,
    time: time + other.time,
    flow: flow + other.flow,
  );

  /// Axis-wise scale by [k], unclamped.
  DanceDynamics scale(double k) =>
      DanceDynamics(weight: weight * k, time: time * k, flow: flow * k);

  /// Axis-wise clamp to `±limit`.
  DanceDynamics clamped({double limit = 1}) => DanceDynamics(
    weight: weight.clamp(-limit, limit),
    time: time.clamp(-limit, limit),
    flow: flow.clamp(-limit, limit),
  );

  @override
  bool operator ==(Object other) =>
      other is DanceDynamics &&
      other.weight == weight &&
      other.time == time &&
      other.flow == flow;

  @override
  int get hashCode => Object.hash(weight, time, flow);

  @override
  String toString() =>
      'DanceDynamics(weight: $weight, time: $time, flow: $flow)';
}

/// Per-axis cap on the combined per-cat + section-energy modulation, so no
/// composition can invert a move's authored Effort character (the catalog
/// moves author their defining axes at |axis| >= ~0.4). A perceptual dial per
/// ADR CHAR-0001 D6, sized below every defining-axis magnitude.
const double kDanceDynamicsModulationBudget = 0.35;

/// Composes the effective per-cat dynamics for one moment of the performance:
///
///     effective = clamp(moveBase + clampMag(catProfile + sectionEnergy))
///
/// The cat-profile and section-energy offsets are summed first and capped to
/// `±budget` per axis — additive, so the trio's personality spread survives
/// quiet sections instead of scaling toward clone-identical neutral — then the
/// move's authored base is added and the result clamps to the valid -1..1
/// range. With `budget < |defining axis|` the move's Effort character can
/// never invert (a Bound move can't read Free on any cat at any energy).
DanceDynamics effectiveDanceDynamics({
  required DanceDynamics moveBase,
  required DanceDynamics catProfile,
  required DanceDynamics sectionEnergy,
  double budget = kDanceDynamicsModulationBudget,
}) =>
    (moveBase + (catProfile + sectionEnergy).clamped(limit: budget)).clamped();

/// Peak anticipation depth — the fraction of the value range the curve dips
/// below the start — at full Strong [DanceDynamics.weight]. ~0.30 reads as a
/// clear wind-up without looking broken.
const double _kAnticipationScale = 0.30;

/// Peak overshoot height — the fraction past the target the curve rises — at
/// full Free [DanceDynamics.flow].
const double _kOvershootScale = 0.30;

/// Normaliser for the early/late shaping bumps: `1 / max(x·(1-x)³)`, whose
/// maximum sits at `x = 0.25` (= 0.10546875). Multiplying the bumps by this
/// makes [_kAnticipationScale]/[_kOvershootScale] read directly as each bump's
/// peak contribution.
const double _kBumpNorm = 9.481481481481482;

/// Builds the [EaseCurve] for [d] using the EMOTE recipe adapted to a single
/// inter-keyframe segment:
///
/// - the inflection point `tᵢ = 0.5 + 0.4·max(strong, sudden) − 0.4·max(light,
///   sustained)` (clamped to 0.15..0.85) skews where the curve is steepest —
///   late for a Sudden/Strong snap, early for a Light/Sustained settle —
///   realised as a power time-warp that maps `tᵢ → 0.5` of an `easeInOut`;
/// - a Strong [DanceDynamics.weight] subtracts an early bump so the curve dips
///   below 0 (anticipation wind-up);
/// - a Free [DanceDynamics.flow] adds a late bump so the curve rises above 1
///   (overshoot / follow-through) before returning to exactly 1.
///
/// Pure and deterministic; the endpoints are exact. [DanceDynamics.neutral]
/// returns `easeInOut` unchanged.
EaseCurve dynamicsCurve(DanceDynamics d) {
  if (d.isNeutral) return (t) => Ease.easeInOut.apply(t);

  final strong = math.max(d.weight, 0);
  final light = math.max(-d.weight, 0);
  final sudden = math.max(d.time, 0);
  final sustained = math.max(-d.time, 0);
  final free = math.max(d.flow, 0);

  final inflection =
      (0.5 + 0.4 * math.max(strong, sudden) - 0.4 * math.max(light, sustained))
          .clamp(0.15, 0.85);
  final anticipation = _kAnticipationScale * strong;
  final overshoot = _kOvershootScale * free;
  // Power warp that sends `inflection → 0.5`, so the easeInOut's steepest point
  // lands at the inflection. gamma == 1 (the identity) when inflection == 0.5.
  final gamma = math.log(0.5) / math.log(inflection);

  return (t) {
    final x = t < 0 ? 0.0 : (t > 1 ? 1.0 : t);
    final warped = math.pow(x, gamma).toDouble();
    final base = 0.5 - 0.5 * math.cos(math.pi * warped);
    final early = anticipation * _kBumpNorm * x * math.pow(1 - x, 3).toDouble();
    final late = overshoot * _kBumpNorm * math.pow(x, 3).toDouble() * (1 - x);
    return base - early + late;
  };
}

/// Natural frequency ωₙ (rad/s, on the authored clip clock) of the arm-
/// transition spring at neutral [DanceDynamics.time]. Matches the shipped
/// critically-damped follow-through rate (`_kOvershootOmegaN` in
/// `character_scene.dart`) so that [DanceDynamics.neutral] reproduces today's
/// settle exactly — the spring is regression-safe by construction.
const double kSpringOmegaBase = 11;

/// Damping ratio ζ at neutral [DanceDynamics.flow]: critically damped (`1`) —
/// one rise-and-decay hump, no overshoot lobe — matching today's follow-
/// through. [DanceDynamics.flow] dials it toward under- or over-damped.
const double kSpringZetaMid = 1;

/// [DanceDynamics.time] → ωₙ gain: a Sudden accent (+1) stiffens the spring
/// (snaps late/fast into the hit), a Sustained one softens it (eases in early).
const double _kSpringOmegaTimeGain = 0.45;

/// ωₙ clamp. The floor keeps the impulse response basically spent before the
/// taper-to-zero at the next key engages (so hard-zeroing never re-introduces a
/// velocity kink); the ceiling keeps it from snapping inside a single frame.
const double _kSpringOmegaMin = 8;
const double _kSpringOmegaMax = 16;

/// [DanceDynamics.flow] → ζ gain: a Free accent (+1) lowers ζ (underdamped —
/// one visible overshoot-and-settle lobe, the "alive" end), a Bound one raises
/// it (overdamped — a clean arrival that holds, the "snappy" end).
const double _kSpringZetaFlowGain = 0.6;

/// ζ clamp. The floor stays comfortably above 0 so the envelope `e^(−ζωₙt)`
/// always decays within one overshoot lobe (never rings into a second snap);
/// the ceiling caps how dead an over-damped arrival gets.
const double _kSpringZetaMin = 0.4;
const double _kSpringZetaMax = 1.6;

/// The second-order spring parameters — natural frequency ωₙ (rad/s, authored
/// clock) and damping ratio ζ — driving the closed-form arm-transition response
/// (`_dampedTransitionResponse` in `character_scene.dart`).
typedef DanceSpring = ({double omegaN, double zeta});

/// Maps [DanceDynamics] to the arm-transition spring (ωₙ, ζ), the physics
/// inputs shared by the hand-target follow-through and the rotational
/// overshoot-settle:
///
/// - [DanceDynamics.flow] → ζ ("snappy ↔ alive"): Bound (−1) → over-damped
///   (clean arrival, no overshoot), Free (+1) → under-damped (one overshoot
///   lobe). This is the first lever that gives the Flow dial teeth on the arm
///   *pose* path (it previously only fed the time warp).
/// - [DanceDynamics.time] → ωₙ (snap speed): Sudden (+1) faster, Sustained (−1)
///   slower.
///
/// [DanceDynamics.neutral] returns `(ωₙ: kSpringOmegaBase, ζ: kSpringZetaMid)` =
/// `(11, 1)` — today's critically-damped response — so layering the spring is
/// opt-in and regression-free. Pure and deterministic.
DanceSpring danceSpring(DanceDynamics d) {
  final zeta = (kSpringZetaMid - _kSpringZetaFlowGain * d.flow).clamp(
    _kSpringZetaMin,
    _kSpringZetaMax,
  );
  final omegaN = (kSpringOmegaBase * (1 + _kSpringOmegaTimeGain * d.time))
      .clamp(
        _kSpringOmegaMin,
        _kSpringOmegaMax,
      );
  return (omegaN: omegaN, zeta: zeta);
}

/// Closed-form damped free response to an initial velocity — the physics
/// primitive shared by the hand-target follow-through and the rotational
/// settle. Solves `ẍ + 2ζωₙẋ + ωₙ²x = 0` with `x(0)=0, ẋ(0)=1`, evaluated [dt]
/// seconds after a keyframe boundary, then a linear taper forces it to exactly
/// zero at the NEXT boundary ([frameDuration] away):
///
///     kernel(dt) = e^(−ζ·[omegaN]·dt) · Φ(dt) · taper,  taper = 1 − dt/frameDuration
///     Φ(dt) = sin(ω_d·dt)/ω_d   (ζ<1, ω_d = ωₙ√(1−ζ²))  — one overshoot lobe
///           = dt                (ζ≈1)                     — critical, one hump
///           = sinh(β·dt)/β       (ζ>1, β = ωₙ√(ζ²−1))     — over-damped hump
///
/// The caller multiplies this per-unit-velocity kernel by the measured arrival
/// velocity `v0` (a scalar rotation rate, or per-component for a 2D hand
/// target). Key properties, all independent of ([omegaN], [zeta]):
///
/// - `Φ(0)=0` ⇒ exactly zero AT the keyframe (crest preserved, exact-frame-safe);
/// - the linear taper ⇒ exactly zero at the NEXT keyframe (the non-regression
///   property the exact-frame tests depend on: only the interpolated region is
///   ever perturbed);
/// - continuous across ζ=1 (both the under- and over-damped branches tend to
///   `dt` as ζ→1; the small band around 1 just avoids a 0/0).
///
/// Pure function of its arguments.
double dampedTransitionResponse(
  double dt,
  double frameDuration,
  double omegaN,
  double zeta,
) {
  if (dt <= 0 || frameDuration <= 0) return 0;
  final taper = 1 - dt / frameDuration;
  if (taper <= 0) return 0;
  final double phi;
  if ((zeta - 1).abs() < 1e-3) {
    phi = dt;
  } else if (zeta < 1) {
    final omegaD = omegaN * math.sqrt(1 - zeta * zeta);
    phi = math.sin(omegaD * dt) / omegaD;
  } else {
    final beta = omegaN * math.sqrt(zeta * zeta - 1);
    phi = (math.exp(beta * dt) - math.exp(-beta * dt)) / (2 * beta);
  }
  return math.exp(-zeta * omegaN * dt) * phi * taper;
}

/// Per-factor attenuation of the dials before they enter the time warp.
/// Weight-as-retrograde (the anticipation dip briefly runs time backwards)
/// reads much stronger in the warp domain than Time-as-skew, so it gets a
/// lower dial; all three are perceptual constants tuned on rendered motion.
const double kTimeWarpWeightGain = 0.6;
const double kTimeWarpTimeGain = 1;
const double kTimeWarpFlowGain = 1;

/// Builds a beat-local unit-interval TIME warp from [d]: a map `u -> u'` for
/// the phase within one beat, to be applied to a channel's *sampling clock*
/// (not, like [dynamicsCurve], to an interpolation value).
///
/// The warp is the **deviation form**
///
///     warp(u) = u + gain · (dynamicsCurve(d')(u) − easeInOut(u))
///
/// (`d'` = [d] with the per-factor gains applied), which has two properties a
/// raw `dynamicsCurve` used as a time map would not:
///
/// - [DanceDynamics.neutral] is the exact identity (both curves coincide), so
///   layering the warp is opt-in and regression-free;
/// - the endpoints are exact (`warp(0) == 0`, `warp(1) == 1`), so every beat
///   boundary maps to itself and warped dancers re-sync on every count.
///
/// Between the endpoints, a Sudden [DanceDynamics.time] samples behind the
/// unwarped clock then catches up steeply (the pose snaps late into the hit),
/// a Strong [DanceDynamics.weight] dips *below* the beat start (a brief
/// retrograde wind-up into the previous beat), and a Free [DanceDynamics.flow]
/// runs past the beat end before returning (follow-through). Callers wrap the
/// out-of-range excursions across the loop seam.
EaseCurve dynamicsTimeWarp(DanceDynamics d, {double gain = 1}) {
  final scaled = DanceDynamics(
    weight: d.weight * kTimeWarpWeightGain,
    time: d.time * kTimeWarpTimeGain,
    flow: d.flow * kTimeWarpFlowGain,
  );
  if (scaled.isNeutral || gain == 0) return (u) => u;
  final curve = dynamicsCurve(scaled);
  return (u) => u + gain * (curve(u) - Ease.easeInOut.apply(u));
}
