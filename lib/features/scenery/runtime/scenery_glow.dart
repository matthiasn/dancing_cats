import 'dart:ui';

/// Shared additive "point light" glow shared by the scenery layers, kept in
/// one place so the layers can't drift apart (they previously each
/// hand-rolled the same halo + solid-core shape with their own copy of the
/// gradient/paint boilerplate — see [paintGlowPointLight]).

/// Paints a soft radial-gradient halo plus a hot, near-white solid core —
/// the additive "point light" shape behind city-lights lamps, aircraft
/// warning beacons, police strobes, drone lights and jet lamps. Both passes
/// use [BlendMode.plus] so they only ever add glow.
///
/// Every visual knob is an explicit parameter — nothing here is tuned by
/// this function, only shaped by it — so each caller's per-light character
/// (a tight steep-falloff LED bar vs. a soft warm lamp) stays exactly as
/// authored; only the shared shape (gradient halo, stops `[0, haloMidStop,
/// 1]`, then a flat core circle) is factored out.
///
/// [haloPaint]/[corePaint] let a caller reuse one `Paint` per shape across a
/// loop (e.g. a drone show's ~280 lights per frame) instead of allocating a
/// fresh pair for every light; when omitted, fresh paints are allocated.
void paintGlowPointLight(
  Canvas canvas, {
  required Offset center,
  required Color color,
  required double haloRadius,
  required double haloInnerAlpha,
  required double haloMidAlpha,
  required double haloMidStop,
  required double coreRadius,
  required Color coreColor,
  required double coreAlpha,
  Paint? haloPaint,
  Paint? corePaint,
}) {
  final halo = (haloPaint ?? Paint())
    ..blendMode = BlendMode.plus
    ..shader = Gradient.radial(
      center,
      haloRadius,
      [
        color.withValues(alpha: haloInnerAlpha),
        color.withValues(alpha: haloMidAlpha),
        color.withValues(alpha: 0),
      ],
      [0.0, haloMidStop, 1.0],
    );
  final core = (corePaint ?? Paint())
    ..blendMode = BlendMode.plus
    ..shader = null
    ..color = coreColor.withValues(alpha: coreAlpha);
  canvas
    ..drawCircle(center, haloRadius, halo)
    ..drawCircle(center, coreRadius, core);
}
