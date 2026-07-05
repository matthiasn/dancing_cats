import 'dart:ui' as ui;

import 'package:dancing_cats/features/scenery/layers/backdrop_layer.dart';
import 'package:dancing_cats/features/scenery/layers/drone_show_layer.dart'
    show
        kDroneLaunchEndX,
        kDroneLaunchGapEndX,
        kDroneLaunchGapStartX,
        kDroneLaunchStartX,
        kDroneShowCycleSeconds;
import 'package:dancing_cats/features/scenery/runtime/scenery_geometry.dart';
import 'package:dancing_cats/features/scenery/runtime/scenery_math.dart';
import 'package:flutter/rendering.dart';

/// Number of strobe units in the bridge cordon.
const int kBridgePoliceUnitCount = 13;

/// Police road-closure strobes on the cable-stayed bridge deck.
///
/// A cordon of flashing emergency lights — dominantly **blue** with a few red
/// accents — lines the bridge roadway to stop traffic so the drone formation can
/// launch from the cleared deck. The cordon is timed to the drone-show loop
/// ([kDroneShowCycleSeconds]): it rolls in while the previous formation is still
/// dispersing, holds at full while the drones sit on the road, then clears out as
/// the aircraft climb away — so by the time the show is in the sky the road is
/// dark again. Stateless and deterministic from [BackdropContext.timeSeconds];
/// suppressed entirely under reduce-motion (strobes are exactly the flashing the
/// setting exists to calm).
class BridgePoliceLayer implements BackdropLayer {
  const BridgePoliceLayer({
    this.cycleSeconds = kDroneShowCycleSeconds,
    this.unitCount = kBridgePoliceUnitCount,
  });

  /// Length of the drone-show loop this cordon is timed against.
  final double cycleSeconds;

  /// How many strobe units span the roadway.
  final int unitCount;

  @override
  void paint(Canvas canvas, BackdropContext ctx) {
    if (ctx.reducedMotion) return;
    final safeCycle = cycleSeconds <= 0 ? kDroneShowCycleSeconds : cycleSeconds;
    final cordon = trafficStopIntensity(fract(ctx.timeSeconds / safeCycle));
    if (cordon <= 0) return;

    final cover = coverFit(ctx.size);
    final units = policeCordonPoints(count: unitCount);
    final r = cover.width * 0.0016;
    final blue = ctx.palette.policeBlue;
    final red = ctx.palette.policeRed;
    final haloPaint = ui.Paint()..blendMode = ui.BlendMode.plus;
    final corePaint = ui.Paint()..blendMode = ui.BlendMode.plus;
    final reflectPaint = ui.Paint()..blendMode = ui.BlendMode.plus;

    for (final unit in units) {
      final intensity = policeStrobe(ctx.timeSeconds, unit.phase) * cordon;
      final c = cover.project(unit.position.dx, unit.position.dy);
      final color = unit.isRed ? red : blue;
      // A tight steep-falloff halo around a hot near-white core — a vehicle LED
      // bar, not a soft bubble.
      haloPaint.shader = ui.Gradient.radial(
        c,
        r * 3.4,
        [
          color.withValues(alpha: 0.40 * intensity),
          color.withValues(alpha: 0.10 * intensity),
          color.withValues(alpha: 0),
        ],
        [0.0, 0.4, 1.0],
      );
      corePaint.color = ui.Color.lerp(
        color,
        const ui.Color(0xFFFFFFFF),
        0.6,
      )!.withValues(alpha: 0.82 * intensity);
      // A short vertical smear below the lamp: the strobe glancing off the wet
      // roadway, so the cordon sits ON the deck instead of floating over it.
      canvas
        ..drawCircle(c, r * 3.4, haloPaint)
        ..save()
        ..translate(c.dx, c.dy + r * 1.4)
        ..scale(0.5, 2.2)
        ..drawCircle(
          Offset.zero,
          r * 2.2,
          reflectPaint
            ..shader = ui.Gradient.radial(
              Offset.zero,
              r * 2.2,
              [
                color.withValues(alpha: 0.18 * intensity),
                color.withValues(alpha: 0),
              ],
              [0.0, 1.0],
            ),
        )
        ..restore()
        ..drawCircle(c, r * 0.85, corePaint);
    }
  }
}

/// One strobe unit in the cordon.
class PoliceCordonUnit {
  const PoliceCordonUnit({
    required this.position,
    required this.phase,
    required this.isRed,
  });

  /// Normalized (0..1) position on the artwork canvas.
  final ui.Offset position;

  /// Strobe phase offset in seconds, so the units don't flash in unison.
  final double phase;

  /// Whether this unit carries the red accent (the rest are blue).
  final bool isRed;
}

/// Deterministic cordon units concentrated at the drone show's two launch
/// bases on the bridge roadway.
///
/// The line straddles the painted railing-top edge of the deck (railing top
/// ≈ y 0.4646 on the 2026-07 plate; light bars y ≈ 0.469-0.471 — the same
/// road the drones launch from), so each strobe reads as the roof bar of a
/// vehicle standing ON the road: peeking over the parapet, neither embedded
/// in the bridge girder nor floating above it. Units cluster at the LEFT and
/// RIGHT launch bases ([kDroneLaunchStartX]–[kDroneLaunchGapStartX] and
/// [kDroneLaunchGapEndX]–[kDroneLaunchEndX]) rather than spreading evenly
/// across the full former span: since the drones no longer stage under the
/// cable-stayed pylon's fanned cables, a cordon light there would be closing
/// off empty road. A small deterministic vertical jitter keeps the lamps
/// natural rather than ruler straight. Most units are blue; a sparse few are
/// red accents.
List<PoliceCordonUnit> policeCordonPoints({
  int count = kBridgePoliceUnitCount,
}) {
  if (count <= 0) return const [];
  const startY = 0.4693;
  const endY = 0.4713;
  return List<PoliceCordonUnit>.generate(count, (i) {
    final u = count <= 1 ? 0.5 : i / (count - 1);
    final jitter = (hashUnit(i + 41) - 0.5) * 0.004;
    // Two evenly spread red accents in a mostly-blue cordon.
    final isRed = i == (count * 0.3).round() || i == (count * 0.78).round();
    return PoliceCordonUnit(
      position: ui.Offset(
        _cordonX(u),
        startY + u * (endY - startY) + jitter,
      ),
      phase: hashUnit(i * 3 + 7) * 0.9,
      isRed: isRed,
    );
  }, growable: false);
}

/// Maps cordon progress [u] (0..1) to x, mirroring the drone launch bases'
/// split (`_launchX` in drone_show_layer.dart) so the police lights and the
/// drones close off exactly the same two stretches of road.
double _cordonX(double u) {
  if (u < 0.5) {
    return kDroneLaunchStartX +
        (u / 0.5) * (kDroneLaunchGapStartX - kDroneLaunchStartX);
  }
  final local = (u - 0.5) / 0.5;
  return kDroneLaunchGapEndX + local * (kDroneLaunchEndX - kDroneLaunchGapEndX);
}

/// Cordon brightness for the drone-loop position [cycleProgress] (0..1).
///
/// The launch instant is `cycleProgress == 0` (drones held on the road). The
/// cordon ramps in over the preceding ~0.10 of the loop, holds full from just
/// before launch through the on-road hold, then ramps back out as the drones
/// climb away — keyed so the lights are gone well before the formation reaches
/// the sky. Pure for unit testing.
double trafficStopIntensity(double cycleProgress) {
  final p = fract(cycleProgress);
  // Signed distance to the launch instant, in loop fractions [-0.5, 0.5).
  final d = p <= 0.5 ? p : p - 1.0;
  if (d < -0.20 || d >= 0.12) return 0;
  if (d < -0.10) return smoothstep((d + 0.20) / 0.10); // roll in
  if (d < 0.04) return 1; // full hold across the launch
  return 1 - smoothstep((d - 0.04) / 0.08); // clear out as drones climb
}

/// Instantaneous strobe value for an LED police bar at [time] seconds, offset by
/// [phase]. Models a quad-flash burst: four crisp pulses bunched into the first
/// ~0.4 of a 0.9 s period that peg the lamp to full, over a dim [_strobeFloor]
/// presence the rest of the cycle. The floor means every unit stays softly lit
/// between flashes, so a cordon of these reads as a populated line of vehicles
/// (not one or two lone dots in any given still) while the bright peaks still
/// give the staccato strobe. Range `[_strobeFloor, 1]`. Pure for unit testing.
double policeStrobe(double time, double phase) {
  const period = 0.9;
  const flash = 0.05;
  const gap = 0.05;
  final t = fract((time + phase) / period) * period;
  for (var i = 0; i < 4; i++) {
    final start = i * (flash + gap);
    if (t >= start && t < start + flash) return 1;
  }
  return _strobeFloor;
}

/// Dim always-on presence between strobe flashes (see [policeStrobe]).
const double _strobeFloor = 0.3;

// Shared scenery math (`hashUnit`, `smoothstep`) now lives in scenery_math.dart.
