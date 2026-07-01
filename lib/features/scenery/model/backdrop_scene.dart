import 'dart:ui' show Color, Size;

import 'package:dancing_cats/features/scenery/layers/atmospheric_haze_layer.dart';
import 'package:dancing_cats/features/scenery/layers/backdrop_layer.dart';
import 'package:dancing_cats/features/scenery/layers/bridge_police_layer.dart';
import 'package:dancing_cats/features/scenery/layers/city_lights_layer.dart';
import 'package:dancing_cats/features/scenery/layers/cloud_parallax_layer.dart';
import 'package:dancing_cats/features/scenery/layers/deck_glow_layer.dart';
import 'package:dancing_cats/features/scenery/layers/distant_jet_layer.dart';
import 'package:dancing_cats/features/scenery/layers/drone_show_layer.dart';
import 'package:dancing_cats/features/scenery/layers/image_layer.dart';
import 'package:dancing_cats/features/scenery/layers/ocean_layer.dart';
import 'package:dancing_cats/features/scenery/layers/parallax_layer.dart';
import 'package:dancing_cats/features/scenery/layers/sky_layer.dart';
import 'package:dancing_cats/features/scenery/layers/vignette_layer.dart';
import 'package:dancing_cats/features/scenery/model/scenery_assets.dart';

/// Parallax depth ladder for the blue-hour scene: `0` locks a plane at infinity
/// (no drift), `1` moves it fully with the dancers. Monotonic far → near, so as
/// the dance camera dollies the planes drift and grow against one another and
/// the scene reads as real depth instead of one flat plate. Fed to each layer's
/// [ParallaxLayer] wrapper; the dance stage / offline composer inject the actual
/// camera → matrix mapping (see `CharacterPainter.danceParallaxMatrixForShotAtDepth`).
const double _depthSky = 0.06; // base plate, far clouds, the distant jet
const double _depthCloudsMid = 0.09;
const double _depthCloudsNear = 0.12;
const double _depthCity = 0.13; // skyline, bridge, city lights, police strobes
const double _depthOcean = 0.16;
const double _depthYacht = 0.24; // moored nearer than the far skyline
const double _depthDrones = 0.10; // hovering just off the bridge, near the sky
const double _depthHaze = 0.30; // waterline aerial haze, between mid and deck
const double _depthDeck = 0.5; // foreground deck, palms, planters, lantern glow

/// An ordered, back-to-front stack of [BackdropLayer]s plus the bitmap assets
/// the scene needs decoded. [layers] are painted behind the consumer's content;
/// [foregroundLayers] are painted in front of it (occluders).
class BackdropScene {
  const BackdropScene({
    required this.layers,
    this.foregroundLayers = const [],
    this.imageAssets = const [],
    this.sceneSize = kSceneryCanvasSize,
  });

  /// The painted Lagos-lagoon blue-hour scene, back to front: the cloudless
  /// master-derived base plate, three exact-pixel cloud layers drifting at
  /// different depths, a subtle distant jet crossing behind the skyline early
  /// in the loop, the animated ocean, solid skyline/bridge/yacht structure
  /// re-drawn OVER atmosphere/water so clouds/foam never slide across them,
  /// the additive city/yacht night lights, the foreground deck/palms, the warm
  /// lantern glow pooling on the now-lit deck, and finally both drone-show
  /// passes above the painted structures so bridge cables cannot slice holes in
  /// the ascent. All sit behind the dancers (they are background layers).
  factory BackdropScene.blueHourWaterfront() {
    return const BackdropScene(
      // Each background layer is wrapped in a [ParallaxLayer] at its depth on the
      // ladder above, so the dance camera drifts every plane by a different
      // amount (far barely moves, the deck tracks the cast). The foreground
      // vignette is intentionally NOT wrapped — it is a screen-space effect.
      layers: [
        ParallaxLayer(ImageLayer(SceneryAssets.cloudlessPlate), depth: _depthSky),
        ParallaxLayer(
          CloudParallaxLayer(
            SceneryAssets.cloudsFar,
            opacity: 0.84,
            dxPerSecond: 0.00165,
            dyAmplitude: 0.001,
            dyCycleSeconds: 72,
            phase: 0.17,
          ),
          depth: _depthSky,
        ),
        ParallaxLayer(
          CloudParallaxLayer(
            SceneryAssets.cloudsMid,
            opacity: 0.84,
            dxPerSecond: 0.0021,
            dyAmplitude: 0.0015,
            dyCycleSeconds: 58,
            phase: 0.43,
          ),
          depth: _depthCloudsMid,
        ),
        ParallaxLayer(
          CloudParallaxLayer(
            SceneryAssets.cloudsNear,
            opacity: 0.9,
            dxPerSecond: 0.002775,
            dyCycleSeconds: 46,
            phase: 0.71,
          ),
          depth: _depthCloudsNear,
        ),
        // Small 747-ish wide-body crossing in the far sky. It sits behind the
        // fixed skyline/yacht redraws and far below the dancer plane, giving the
        // opening seconds a readable motion cue without becoming foreground
        // spectacle.
        ParallaxLayer(DistantJetLayer(), depth: _depthSky),
        // Animated water first; the additive ocean and additive city lights
        // commute, so the only thing the order buys us is letting the opaque
        // yacht sit BETWEEN them.
        ParallaxLayer(OceanLayer(foamDensity: 0.3), depth: _depthOcean),
        // Re-draw fixed skyline + bridge over the drifting cloud layers and
        // ocean shimmer, preserving the original depth ordering.
        ParallaxLayer(ImageLayer(SceneryAssets.cityBridge), depth: _depthCity),
        // The moored yacht silhouette, re-drawn over the ocean so its hull
        // covers the foam that would otherwise wash up its side. The yacht sits
        // NEARER than the far skyline, so it must read at least as sharp and as
        // clear as the city — a heavy defocus + cool dim made a mid-distance
        // object foggier than the distant towers (a depth inversion). Keep only
        // a light cool exposure pull so it doesn't blaze as a foreground hero,
        // and NO blur, so the depth ladder stays monotonic. The warm cabin
        // windows are added after this (CityLightsLayer) so the glow reads on top.
        ParallaxLayer(
          ImageLayer(
            SceneryAssets.yacht,
            modulate: Color(0xFFD0D5DE),
          ),
          depth: _depthYacht,
        ),
        // More windows lit (brighter highrises) than the 0.6 default; drawn
        // after the yacht so the warm cabin glow reads on top of the hull.
        ParallaxLayer(CityLightsLayer(windowAmount: 0.8), depth: _depthCity),
        // Aerial-perspective haze banded on the waterline: lifts + cools the
        // distant skyline/bridge/yacht so the midground recedes behind the
        // sharp, un-hazed foreground deck + trio (the establishing-shot depth
        // cue). Sits over the structures + lights but under the deck/palms.
        ParallaxLayer(AtmosphericHazeLayer(), depth: _depthHaze),
        ParallaxLayer(ImageLayer(SceneryAssets.foreground), depth: _depthDeck),
        ParallaxLayer(DeckGlowLayer(), depth: _depthDeck),
        // Police cordon on the bridge roadway: blue (and a few red) emergency
        // strobes that stop traffic while the drones stage on the cleared deck,
        // timed to the drone loop so they roll in before launch and clear out as
        // the formation climbs away. Drawn just under the drones (both are the
        // post-haze "active light show" passes) so the dancers still occlude any
        // strobe behind them.
        ParallaxLayer(BridgePoliceLayer(), depth: _depthCity),
        // Drones are the highest backdrop art pass: the takeoff starts as
        // unlit dark dots and switches on above the cable-stayed bridge, so
        // painted bridge cables/trees must not cut gaps through the aircraft.
        ParallaxLayer(DroneShowLayer.sky(), depth: _depthDrones),
        ParallaxLayer(DroneShowLayer.launchRoad(), depth: _depthCity),
      ],
      foregroundLayers: [VignetteLayer(dim: 0.12)],
      imageAssets: [
        SceneryAssets.cloudlessPlate,
        SceneryAssets.masterPlate,
        SceneryAssets.cloudsFar,
        SceneryAssets.cloudsMid,
        SceneryAssets.cloudsNear,
        SceneryAssets.cityBridge,
        SceneryAssets.cityWindows,
        SceneryAssets.yacht,
        SceneryAssets.foreground,
        SceneryAssets.lufthansa747,
      ],
    );
  }

  /// A fully procedural blue-hour sky (gradient, moon, stars, drifting clouds)
  /// with no painted assets — the reusable shader variant / art-free fallback.
  factory BackdropScene.proceduralBlueHour() {
    return const BackdropScene(layers: [SkyLayer()]);
  }

  /// Layers painted behind the content, in order (earlier = further back).
  final List<BackdropLayer> layers;

  /// Layers painted in front of the content (foreground occluders).
  final List<BackdropLayer> foregroundLayers;

  /// Asset paths the scene's [ImageLayer]s need decoded before they can paint.
  final List<String> imageAssets;

  /// Native coordinate space the layers paint in; cover-fit to the viewport so
  /// painted art, mask sampling and light anchors all stay aligned.
  final Size sceneSize;
}
