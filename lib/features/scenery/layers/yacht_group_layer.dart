import 'dart:math' as math;

import 'package:dancing_cats/features/scenery/layers/backdrop_layer.dart';
import 'package:dancing_cats/features/scenery/layers/image_layer.dart';
import 'package:dancing_cats/features/scenery/layers/yacht_lights_layer.dart';
import 'package:dancing_cats/features/scenery/model/scenery_assets.dart';
import 'package:dancing_cats/features/scenery/runtime/scenery_geometry.dart';
import 'package:flutter/rendering.dart';

/// The moored yacht as ONE group: the hull bitmap and its night lighting drawn
/// together under a shared transform, so a single motion moves the whole vessel —
/// hull, cabin glow and lamps in lock-step. The base plate no longer bakes in a
/// yacht, so this de-baked group rides its own plane: the scene wraps it in a
/// `ParallaxLayer` on the nearer, docked (foreground) plane.
///
/// On top of that placement it applies a gentle WAVE motion — a slow vertical
/// heave and a slight roll (rock/tilt) about the waterline — so the moored
/// vessel breathes with a very moderate sea instead of sitting glued to
/// the water. The transform wraps BOTH images, and the cabin-window shader stays
/// registered under it (FlutterFragCoord is pre-transform), so the glow rides the
/// hull as it rocks. Reduce-motion draws it at rest.
///
/// Two independent images, hull then lighting (the lit cabin windows / lamps must
/// read on top of the hull):
///   * [SceneryAssets.yacht] — the hull silhouette, drawn with a light cool
///     exposure pull ([_hullModulate]) so it recedes a touch and doesn't blaze as
///     a foreground hero, matching the value it carried as a flat scene layer;
///   * [YachtLightsLayer] — cabin windows, hull rim/fill and nav/deck lamps.
class YachtGroupLayer implements BackdropLayer {
  const YachtGroupLayer();

  /// Constant downward placement offset for the whole group, as a fraction of
  /// the cover-fit art height. The de-baked hull art sits a touch high against
  /// the 2026-07 plate's water/pier line, so the group rests slightly lower in
  /// frame. Placement, not motion: applied under reduce-motion too.
  static const double sinkFraction = 0.02;

  /// Light cool exposure pull on the hull (BlendMode.modulate), preserved from
  /// when the yacht was a flat scene layer.
  static const _hullModulate = Color(0xFFD0D5DE);

  /// Peak heave, as a fraction of the cover-fit art height (~0.3% ≈ a couple px):
  /// a big yacht barely lifts in a moderate sea.
  static const _heaveHeightFraction = 0.003;

  /// Peak roll, radians (~0.95°) — a barely-there rock, not a storm.
  static const _rollRadians = 0.0165;

  /// Cover-space pivot the roll rocks about: the yacht's mid-length at the
  /// waterline (it pivots around where it floats, not the frame or its mast).
  static const _rockPivot = Offset(0.805, 0.58);

  @override
  void paint(Canvas canvas, BackdropContext ctx) {
    final cover = coverFit(ctx.size);
    canvas
      ..save()
      ..translate(0, sinkFraction * cover.height);
    if (!ctx.reducedMotion) {
      final motion = yachtWaveMotion(ctx.timeSeconds);
      final pivot = cover.project(_rockPivot.dx, _rockPivot.dy);
      canvas
        ..translate(0, motion.heave * _heaveHeightFraction * cover.height)
        ..translate(pivot.dx, pivot.dy)
        ..rotate(motion.roll * _rollRadians)
        ..translate(-pivot.dx, -pivot.dy);
    }
    const ImageLayer(
      SceneryAssets.yacht,
      modulate: _hullModulate,
    ).paint(canvas, ctx);
    const YachtLightsLayer().paint(canvas, ctx);
    canvas.restore();
  }
}

/// Wave-driven rigid-body motion for the moored yacht at a very moderate sea
/// state: a normalized HEAVE (up/down) and ROLL (rock/tilt), each in ~[-1, 1] and
/// scaled by [YachtGroupLayer] to a small pixel heave and a few degrees of roll.
///
/// Each axis sums two out-of-phase sines at incommensurate periods (~4.7/7.3 s
/// heave, ~6.1/9.4 s roll), and the two axes share no period, so the motion never
/// visibly repeats or syncs between axes — a single sine reads as a mechanical
/// metronome, real swell does not. Pure (no clock/RNG), so it is deterministic
/// and unit-testable; [t] is seconds and freezes with the scene clock.
({double heave, double roll}) yachtWaveMotion(double t) {
  const twoPi = 2 * math.pi;
  final heave =
      0.62 * math.sin(twoPi * t / 4.7) +
      0.38 * math.sin(twoPi * t / 7.3 + 1.1);
  final roll =
      0.68 * math.sin(twoPi * t / 6.1 + 0.6) +
      0.32 * math.sin(twoPi * t / 9.4 + 2.0);
  return (heave: heave, roll: roll);
}
