/// Pure dance-timing primitives and the built-in virtual-camera shot, factored
/// out of `CharacterPainter` so this (Flutter-free, deterministic) phrasing math
/// is unit-testable and shared cleanly by the painter's camera and
/// ensemble-formation passes. The painter keeps the canvas/matrix application.
library;

import 'dart:math' as math;

/// Fractional phase in `[0, 1)` of [timeSeconds] within a [duration]-long loop,
/// negative-safe (a bare `cycle - cycle.floor()` goes negative below zero).
double cyclePhase(double timeSeconds, double duration) {
  final cycle = timeSeconds / duration;
  final p = cycle - cycle.floorToDouble();
  return p < 0 ? p + 1 : p;
}

/// The smoothstep S-curve `t·t·(3 − 2t)` with [t] clamped to `[0, 1]`.
double smoothstep(double t) {
  final x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

/// Smoothstep-eased sample of a periodic [keys] table (ascending `(p, v)` pairs
/// spanning the cycle) at phase [p]. Walks the interior segments; the last
/// segment is the natural fall-through, so the sampler is total (a value past
/// the final key clamps onto it) without an unreachable out-of-range branch.
double smoothKeys(double p, List<({double p, double v})> keys) {
  for (var i = 0; i < keys.length - 2; i++) {
    final a = keys[i];
    final b = keys[i + 1];
    if (p <= b.p) {
      return a.v + (b.v - a.v) * smoothstep((p - a.p) / (b.p - a.p));
    }
  }
  final a = keys[keys.length - 2];
  final b = keys[keys.length - 1];
  final t = smoothstep(((p - a.p) / (b.p - a.p)).clamp(0.0, 1.0));
  return a.v + (b.v - a.v) * t;
}

/// Euclidean distance between two points expressed as `(x, y)` records —
/// the shape solved bone world origins and IK targets pass around, so
/// bone-length/reach math (two-bone IK, contact/anchor solving) can stay in
/// that record shape without every caller unpacking to raw doubles.
double pointDistance(({double x, double y}) a, ({double x, double y}) b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  return math.sqrt(dx * dx + dy * dy);
}

/// The built-in dance camera's shot at [timeSeconds] over a [duration]-long
/// cycle, as a `(zoom, dx, dy)` offset the painter applies to the canvas.
///
/// Shot plan: establish the trio, push into the lead's face/torso, truck across
/// the side dancers, then pull back. The smoothstep easing keeps it on rails
/// rather than feeling like a fast handheld pan.
({double zoom, double dx, double dy}) danceCameraShot(
  double timeSeconds,
  double duration,
) {
  final p = cyclePhase(timeSeconds, duration);
  return (
    zoom: smoothKeys(p, const [
      (p: 0, v: 1.0),
      (p: 1 / 8, v: 1.18),
      (p: 1 / 4, v: 1.52),
      (p: 3 / 8, v: 1.78),
      (p: 1 / 2, v: 2.08),
      (p: 5 / 8, v: 1.82),
      (p: 3 / 4, v: 1.58),
      (p: 7 / 8, v: 1.22),
      (p: 1, v: 1.0),
    ]),
    dx: smoothKeys(p, const [
      (p: 0, v: 0.0),
      (p: 1 / 8, v: -18.0),
      (p: 1 / 4, v: -86.0),
      (p: 3 / 8, v: -142.0),
      (p: 1 / 2, v: -112.0),
      (p: 5 / 8, v: 24.0),
      (p: 3 / 4, v: 142.0),
      (p: 7 / 8, v: 62.0),
      (p: 1, v: 0.0),
    ]),
    dy: smoothKeys(p, const [
      (p: 0, v: 0.0),
      (p: 1 / 8, v: -18.0),
      (p: 1 / 4, v: -50.0),
      (p: 3 / 8, v: -82.0),
      (p: 1 / 2, v: -88.0),
      (p: 5 / 8, v: -76.0),
      (p: 3 / 4, v: -50.0),
      (p: 7 / 8, v: -18.0),
      (p: 1, v: 0.0),
    ]),
  );
}
