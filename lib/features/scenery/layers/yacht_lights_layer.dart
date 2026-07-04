import 'dart:math' as math;

import 'package:dancing_cats/features/scenery/layers/backdrop_layer.dart';
import 'package:dancing_cats/features/scenery/model/scenery_assets.dart';
import 'package:dancing_cats/features/scenery/runtime/scenery_geometry.dart';
import 'package:dancing_cats/features/scenery/runtime/scenery_glow.dart';
import 'package:dancing_cats/features/scenery/runtime/scenery_shaders.dart';
import 'package:flutter/rendering.dart';

/// The moored yacht's night lighting, split OUT of `CityLightsLayer` so it can
/// ride the yacht group's own (nearer, docked) parallax plane instead of the far
/// skyline plane — the whole vessel, hull and glow, moves as one.
///
/// Two parts, both pinned to the painted hull through the same [coverFit] mapping
/// the base plate uses:
///   * the warm cabin-window glow + cool sky rim + cool lower-hull fill, drawn by
///     the shared city-lights shader in its YACHT mode (`uYachtOnly = 1`), reading
///     the yacht-only window field (`yacht_windows`, cabin markers in the blue
///     channel);
///   * steady navigation / anchor lights and warm deck courtesy lamps (canvas
///     glows), so it reads as a lit, occupied vessel.
/// Everything blends with [BlendMode.plus] so it only adds glow. Drawn as part of
/// `YachtGroupLayer`, after the hull bitmap, so the lamps sit on the hull.
class YachtLightsLayer implements BackdropLayer {
  const YachtLightsLayer({this.windowAmount = 0.8, this.flicker = 0.3});

  /// Fraction/intensity of cabin windows lit (matches the old city-lights value).
  final double windowAmount;

  /// Flicker depth (0 = steady).
  final double flicker;

  @override
  void paint(Canvas canvas, BackdropContext ctx) {
    final cover = coverFit(ctx.size);
    _paintCabinWindows(canvas, ctx, cover);
    _paintNavLights(canvas, ctx, cover);
  }

  /// Cabin windows + hull rim/fill via the city-lights shader in yacht mode. The
  /// yacht window field carries no city markers, so the shader's city sections
  /// contribute nothing even though the same program is bound.
  void _paintCabinWindows(Canvas canvas, BackdropContext ctx, Rect cover) {
    final program = ctx.cityLightsProgram;
    final windowField = ctx.images[SceneryAssets.yachtWindows];
    final yachtMask = ctx.images[SceneryAssets.yacht];
    final basePlate = ctx.images[SceneryAssets.cloudlessPlate];
    if (program == null ||
        windowField == null ||
        yachtMask == null ||
        basePlate == null) {
      return;
    }
    final p = ctx.palette;
    final shader = program.fragmentShader()
      ..setFloat(0, ctx.size.width)
      ..setFloat(1, ctx.size.height)
      ..setFloat(2, ctx.timeSeconds)
      ..setFloat(3, windowAmount)
      ..setFloat(4, ctx.reducedMotion ? 0 : flicker)
      ..setFloat(5, ctx.beatPulse)
      ..setFloat(6, cover.left)
      ..setFloat(7, cover.top)
      ..setFloat(8, cover.width)
      ..setFloat(9, cover.height);
    setSceneryColor(shader, 10, p.windowSodium);
    setSceneryColor(shader, 14, p.windowLed);
    setSceneryColor(shader, 18, p.yachtCabinGlow);
    shader
      ..setFloat(22, 1) // uYachtOnly = 1 → yacht pass
      ..setImageSampler(0, windowField)
      ..setImageSampler(1, yachtMask)
      ..setImageSampler(2, basePlate);
    canvas.drawRect(
      Offset.zero & ctx.size,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = shader,
    );
  }

  /// Steady navigation / anchor lights and warm deck courtesy lamps on the moored
  /// yacht, placed from the painted art (mast tip, bow, stern, main-deck rail).
  void _paintNavLights(Canvas canvas, BackdropContext ctx, Rect cover) {
    final p = ctx.palette;
    final time = ctx.reducedMotion ? 0.0 : ctx.timeSeconds;
    // A gentle breath on the masthead anchor light so it twinkles through haze.
    final breath = 0.82 + 0.18 * math.sin(time * 1.3);
    final r = cover.width * 0.0016;
    Offset at(double x, double y) => cover.project(x, y);

    void lamp(Offset c, Color color, double amp, double scale) {
      paintGlowPointLight(
        canvas,
        center: c,
        color: color,
        haloRadius: r * 4.2 * scale,
        haloInnerAlpha: 0.42 * amp,
        haloMidAlpha: 0.10 * amp,
        haloMidStop: 0.42,
        coreRadius: r * 0.95 * scale,
        coreColor: Color.lerp(color, const Color(0xFFFFFFFF), 0.5)!,
        coreAlpha: 0.9 * amp,
      );
    }

    // Navigation / anchor lights: white masthead anchor light (top of the mast),
    // red port sidelight at the bow (the port side faces the viewer), white stern
    // light at the transom.
    lamp(at(0.871, 0.350), p.shipMast, breath, 1.1);
    lamp(at(0.667, 0.578), p.shipPort, 1, 1);
    lamp(at(0.965, 0.586), p.shipMast, 1, 0.95);

    // Warm deck courtesy lamps along the main-deck rail.
    const deckLamps = [
      Offset(0.74, 0.55),
      Offset(0.80, 0.545),
      Offset(0.86, 0.55),
    ];
    for (final d in deckLamps) {
      lamp(at(d.dx, d.dy), p.yachtCabinGlow, 0.7, 0.55);
    }
  }
}
