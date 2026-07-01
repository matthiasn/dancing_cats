import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dancing_cats/features/scenery/layers/backdrop_layer.dart';
import 'package:dancing_cats/features/scenery/runtime/scenery_geometry.dart';
import 'package:flutter/rendering.dart';

/// Blinking red aircraft-warning beacons on the tallest towers and the bridge
/// pylon. Positions are normalized cover-fit art coordinates for the de-baked
/// Lagos city, so each beacon lands on its tower top at any viewport aspect.
///
/// Additive ([BlendMode.plus]) so the beacons only add glow; each blinks on a
/// staggered ~1.6 s phase so they don't pulse in unison. Freezes with reduced
/// motion.
class AircraftBeaconLayer implements BackdropLayer {
  const AircraftBeaconLayer({this.beacons = kLagosBeacons, this.periodSeconds = 1.6});

  /// Tower-top positions in normalized cover-fit art space.
  final List<Offset> beacons;

  /// Blink period (seconds).
  final double periodSeconds;

  @override
  void paint(Canvas canvas, BackdropContext ctx) {
    if (beacons.isEmpty) return;
    final cover = coverFit(ctx.size);
    final time = ctx.reducedMotion ? 0.0 : ctx.timeSeconds;
    final r = cover.width * 0.0016;
    const red = Color(0xFFFF3222);
    for (var i = 0; i < beacons.length; i++) {
      final phase = ((time / periodSeconds) + i * 0.41) % 1.0;
      // Sharp on-pulse for the first ~40% of the cycle, a dim ember otherwise.
      final amp = phase < 0.4 ? 0.5 + 0.5 * math.sin(phase / 0.4 * math.pi) : 0.06;
      final c = cover.project(beacons[i].dx, beacons[i].dy);
      canvas
        ..drawCircle(
          c,
          r * 5.5,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = ui.Gradient.radial(c, r * 5.5, [
              red.withValues(alpha: 0.5 * amp),
              red.withValues(alpha: 0),
            ]),
        )
        ..drawCircle(
          c,
          r * 1.3,
          Paint()
            ..blendMode = BlendMode.plus
            ..color = red.withValues(alpha: 0.95 * amp),
        );
    }
  }
}

/// Tower-top + bridge-pylon beacon anchors for the de-baked Lagos skyline.
const List<Offset> kLagosBeacons = [
  Offset(0.145, 0.235), // the tall spire (left cluster)
  Offset(0.225, 0.27),
  Offset(0.295, 0.26),
  Offset(0.63, 0.35), // cable-stayed bridge pylon
];
