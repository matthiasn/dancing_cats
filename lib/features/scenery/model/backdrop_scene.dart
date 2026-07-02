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

/// Parallax depth PLANES — deliberately coarse. The painted base plate has the
/// skyline, yacht and deck baked in, and the scene re-draws those same
/// structures as separate layers over the animated clouds/ocean for correct
/// depth ordering. Parallaxing a re-draw independently of the base would slide
/// it off its baked twin and reveal a DOUBLED skyline / yacht. So the ENTIRE
/// backdrop moves as ONE far plane; only the foreground deck (the stage the cast
/// dances on) rides its own nearer plane, and the lone distant jet — a DYNAMIC
/// layer with no baked twin — rides its own farthest plane behind everything.
/// `0` locks a plane at infinity, `1` moves it with the dancers (see
/// `CharacterPainter.danceParallaxMatrixForShotAtDepth`). Five planes in all,
/// front to back: lead cat (1.0) › backup cats (0.9) › stage › background › jet.
const double _depthAircraft = 0.04; // the lone jet — farthest of all, near-locked
const double _depthBackground = 0.12; // all backdrop art, moving as one plane
const double _depthStage = 0.5; // the foreground deck + its lantern glow.
// Restored from the gentled 0.35: that cut was tuned under the old snap-zoom
// punches (a fast near plane read as jumping at the viewer). The camera is now
// all slow anticipated dollies, so the deck can carry real near-plane travel —
// the review panel measured the nearest plane under-travelling the cast on the
// showcase truck/traverse, flattening the depth the moves exist to sell. True
// >1 foreground overtravel (palms sweeping past the lens) needs the de-baked
// palm plane that is being prepared as separate artwork.

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
      // Each layer is wrapped in a [ParallaxLayer] on one of the coarse planes
      // above — the whole backdrop shares _depthBackground so re-draws never
      // slide off their baked twins; the deck rides _depthStage and the jet
      // _depthAircraft. The dancers move most; far barely moves. The foreground
      // vignette is intentionally NOT wrapped — it is a screen-space effect.
      layers: [
        ParallaxLayer(ImageLayer(SceneryAssets.cloudlessPlate), depth: _depthBackground),
        ParallaxLayer(
          CloudParallaxLayer(
            SceneryAssets.cloudsFar,
            opacity: 0.84,
            dxPerSecond: 0.00165,
            dyAmplitude: 0.001,
            dyCycleSeconds: 72,
            phase: 0.17,
          ),
          depth: _depthBackground,
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
          depth: _depthBackground,
        ),
        ParallaxLayer(
          CloudParallaxLayer(
            SceneryAssets.cloudsNear,
            opacity: 0.9,
            dxPerSecond: 0.002775,
            dyCycleSeconds: 46,
            phase: 0.71,
          ),
          depth: _depthBackground,
        ),
        // Small 747-ish wide-body crossing in the far sky. It sits behind the
        // fixed skyline/yacht redraws and far below the dancer plane, giving the
        // opening seconds a readable motion cue without becoming foreground
        // spectacle.
        ParallaxLayer(DistantJetLayer(), depth: _depthAircraft),
        // Animated water first; the additive ocean and additive city lights
        // commute, so the only thing the order buys us is letting the opaque
        // yacht sit BETWEEN them.
        ParallaxLayer(OceanLayer(foamDensity: 0.3), depth: _depthBackground),
        // Re-draw fixed skyline + bridge over the drifting cloud layers and
        // ocean shimmer, preserving the original depth ordering.
        ParallaxLayer(ImageLayer(SceneryAssets.cityBridge), depth: _depthBackground),
        // The moored yacht silhouette, re-drawn over the ocean so its hull
        // covers the foam that would otherwise wash up its side. The yacht sits
        // NEARER than the far skyline, so it must read at least as sharp and as
        // clear as the city — a heavy defocus + cool dim made a mid-distance
        // object foggier than the distant towers (a depth inversion). Keep only
        // a light cool exposure pull so it doesn't blaze as a foreground hero,
        // and NO blur, so it reads as a clean mid-distance object. The warm cabin
        // windows are added after this (CityLightsLayer) so the glow reads on top.
        ParallaxLayer(
          ImageLayer(
            SceneryAssets.yacht,
            modulate: Color(0xFFD0D5DE),
          ),
          depth: _depthBackground,
        ),
        // More windows lit (brighter highrises) than the 0.6 default; drawn
        // after the yacht so the warm cabin glow reads on top of the hull.
        ParallaxLayer(CityLightsLayer(windowAmount: 0.8), depth: _depthBackground),
        // Aerial-perspective haze banded on the waterline: lifts + cools the
        // distant skyline/bridge/yacht so the midground recedes behind the
        // sharp, un-hazed foreground deck + trio (the establishing-shot depth
        // cue). Sits over the structures + lights but under the deck/palms.
        ParallaxLayer(AtmosphericHazeLayer(), depth: _depthBackground),
        ParallaxLayer(ImageLayer(SceneryAssets.foreground), depth: _depthStage),
        ParallaxLayer(DeckGlowLayer(), depth: _depthStage),
        // Police cordon on the bridge roadway: blue (and a few red) emergency
        // strobes that stop traffic while the drones stage on the cleared deck,
        // timed to the drone loop so they roll in before launch and clear out as
        // the formation climbs away. Drawn just under the drones (both are the
        // post-haze "active light show" passes) so the dancers still occlude any
        // strobe behind them.
        ParallaxLayer(BridgePoliceLayer(), depth: _depthBackground),
        // Drones are the highest backdrop art pass: the takeoff starts as
        // unlit dark dots and switches on above the cable-stayed bridge, so
        // painted bridge cables/trees must not cut gaps through the aircraft.
        ParallaxLayer(DroneShowLayer.sky(), depth: _depthBackground),
        ParallaxLayer(DroneShowLayer.launchRoad(), depth: _depthBackground),
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
