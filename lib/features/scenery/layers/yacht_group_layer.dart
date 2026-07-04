import 'package:dancing_cats/features/scenery/layers/backdrop_layer.dart';
import 'package:dancing_cats/features/scenery/layers/image_layer.dart';
import 'package:dancing_cats/features/scenery/layers/yacht_lights_layer.dart';
import 'package:dancing_cats/features/scenery/model/scenery_assets.dart';
import 'package:flutter/rendering.dart';

/// The moored yacht as ONE group: the hull bitmap and its night lighting drawn
/// together, so a single enclosing transform moves the whole vessel. The base
/// plate no longer bakes in a yacht, so this de-baked group is free to ride its
/// own plane — the scene wraps it in a `ParallaxLayer` on the nearer, docked
/// (foreground) plane, and a later wave transform will bob it independently of
/// the deck.
///
/// Two independent images, hull then lighting (the lit cabin windows / lamps must
/// read on top of the hull):
///   * [SceneryAssets.yacht] — the hull silhouette, drawn with a light cool
///     exposure pull ([_hullModulate]) so it recedes a touch and doesn't blaze as
///     a foreground hero, matching the value it carried as a flat scene layer;
///   * [YachtLightsLayer] — cabin windows, hull rim/fill and nav/deck lamps.
class YachtGroupLayer implements BackdropLayer {
  const YachtGroupLayer();

  /// Light cool exposure pull on the hull (BlendMode.modulate), preserved from
  /// when the yacht was a flat scene layer.
  static const _hullModulate = Color(0xFFD0D5DE);

  @override
  void paint(Canvas canvas, BackdropContext ctx) {
    const ImageLayer(
      SceneryAssets.yacht,
      modulate: _hullModulate,
    ).paint(canvas, ctx);
    const YachtLightsLayer().paint(canvas, ctx);
  }
}
