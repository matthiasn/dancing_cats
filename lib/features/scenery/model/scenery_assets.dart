import 'dart:ui' show Size;

/// Native authoring size of the painted scenery art (master plate + masks).
/// All layers and the `SkylineManifest` anchors are expressed in this space and
/// cover-fit to the viewport, so art, mask sampling and lights stay aligned.
const Size kSceneryCanvasSize = Size(2560, 1440);

/// Asset paths for the painted blue-hour waterfront layers.
///
/// [cloudlessPlate] is the immutable full-frame base plate (no clouds, no
/// duplicated foreground palms). Cloud pixels are reintroduced through
/// [cloudsFar], [cloudsMid] and [cloudsNear] so they can drift independently.
/// [cityWindows] and [yachtWindows] are registered window fields baked FROM the
/// base plate (see `tools/scenery_art/bake_city_windows.py`) — the city-lights
/// shader lights their painted windows directly. They are the two halves of the
/// old combined field: [cityWindows] holds the skyline windows (red channel) and
/// [yachtWindows] the yacht cabin windows (blue channel), split so the yacht's
/// glow can be lit on the yacht group's own plane. [yacht] and [foreground] are
/// alpha-cut structure
/// layers re-drawn over the animated atmosphere/water so moving effects stay
/// behind the solid painted objects. [cityBridge] is the alpha-cut skyline
/// silhouette; it is NO LONGER painted as a redraw layer (the city and sky share
/// one plane and the clean plate already carries a sharp skyline) — it is decoded
/// solely as the distant jet's `dstOut` OCCLUDER mask, since the opaque base
/// plate has no transparent sky to cut the aircraft against. [lufthansa747] is a
/// cropped transparent overlay asset used by the distant-jet layer.
abstract final class SceneryAssets {
  static const cloudlessPlate = 'assets/scenery/blue_hour_cloudless.webp';
  static const cloudsFar = 'assets/scenery/clouds_far.webp';
  static const cloudsMid = 'assets/scenery/clouds_mid.webp';
  static const cloudsNear = 'assets/scenery/clouds_near.webp';
  static const cityWindows = 'assets/scenery/city_windows.webp';
  static const yachtWindows = 'assets/scenery/yacht_windows.webp';
  static const cityBridge = 'assets/scenery/city_bridge.webp';
  static const yacht = 'assets/scenery/yacht.webp';
  static const foreground = 'assets/scenery/foreground.webp';
  static const lufthansa747 = 'assets/scenery/lufthansa_747.png';
}
