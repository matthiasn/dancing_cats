import 'dart:math' as math;

/// Small pure-math helpers shared by the scenery layers, kept in one place so
/// the layers can't drift apart (they previously hand-rolled these, and the
/// `fract` variants had silently diverged — see [fract]).

/// Fractional part of [value], always in `[0, 1)` — even for negative inputs.
///
/// A bare `value - value.floor()` returns a *negative* result below zero, which
/// breaks looping time/phase wrapping whenever the argument can go negative
/// (e.g. a hash output, or a phase offset by a lead/lag). This is the canonical,
/// negative-safe version every layer should use.
double fract(double value) {
  final f = value - value.floorToDouble();
  return f < 0 ? f + 1 : f;
}

/// The smoothstep S-curve `t·t·(3 − 2t)` with [t] clamped to `[0, 1]`. The shared
/// easing for the layers' 0..1 fades, roll-ins and settles.
double smoothstep(double t) {
  final x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

/// A deterministic pseudo-random unit value in `[0, 1)` for an integer [index]
/// — the classic `fract(sin(n) · 43758.5453)` GLSL hash. Used to scatter
/// per-light jitter, phases and offsets without storing a table. Relies on
/// [fract] being negative-safe (the hash output is frequently negative).
double hashUnit(int index) =>
    fract(math.sin((index + 1) * 12.9898) * 43758.5453);
