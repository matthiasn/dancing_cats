import 'dart:ui' show BlendMode;

import 'package:dancing_cats/features/scenery/layers/atmospheric_haze_layer.dart';
import 'package:dancing_cats/features/scenery/layers/backdrop_layer.dart';
import 'package:dancing_cats/features/scenery/layers/bridge_police_layer.dart';
import 'package:dancing_cats/features/scenery/layers/city_lights_layer.dart';
import 'package:dancing_cats/features/scenery/layers/cloud_parallax_layer.dart';
import 'package:dancing_cats/features/scenery/layers/deck_glow_layer.dart';
import 'package:dancing_cats/features/scenery/layers/distant_jet_layer.dart';
import 'package:dancing_cats/features/scenery/layers/drone_show_layer.dart';
import 'package:dancing_cats/features/scenery/layers/emissive_layer.dart';
import 'package:dancing_cats/features/scenery/layers/graded_layer.dart';
import 'package:dancing_cats/features/scenery/layers/image_layer.dart';
import 'package:dancing_cats/features/scenery/layers/ocean_layer.dart';
import 'package:dancing_cats/features/scenery/layers/parallax_layer.dart';
import 'package:dancing_cats/features/scenery/layers/sky_layer.dart';
import 'package:dancing_cats/features/scenery/layers/vignette_layer.dart';
import 'package:dancing_cats/features/scenery/model/backdrop_scene.dart';
import 'package:dancing_cats/features/scenery/model/scenery_assets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackdropScene.blueHourWaterfront', () {
    test('wraps the cloudless painted plate as its base parallax plane', () {
      final scene = BackdropScene.blueHourWaterfront();
      expect(scene.layers, isNotEmpty);
      // Every background layer is a depth-assigning ParallaxLayer now.
      final base = scene.layers.first;
      expect(base, isA<ParallaxLayer>());
      base as ParallaxLayer;
      expect(base.child, isA<ImageLayer>());
      expect((base.child as ImageLayer).assetKey, SceneryAssets.cloudlessPlate);
      // The base plate rides the far background plane shared by all backdrop art
      // (so a re-draw never slides off its baked twin).
      expect(base.depth, lessThan(0.2));
    });

    test('declares cloud, light, and structure assets to decode', () {
      final scene = BackdropScene.blueHourWaterfront();
      expect(
        scene.imageAssets,
        containsAll(<String>[
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
        ]),
      );
    });

    test(
      'composites plate -> clouds -> jet -> ocean -> city/yacht -> deck -> drones',
      () {
        final planes = BackdropScene.blueHourWaterfront().layers;
        // Every background layer is wrapped in a ParallaxLayer; assert ordering
        // on the wrapped children.
        for (final l in planes) {
          expect(l, isA<ParallaxLayer>());
        }
        final layers = [for (final p in planes.cast<ParallaxLayer>()) p.child];
        final plate = layers.indexWhere(
          (l) => l is ImageLayer && l.assetKey == SceneryAssets.cloudlessPlate,
        );
        final cloud = layers.indexWhere((l) => l is CloudParallaxLayer);
        final deck = layers.lastIndexWhere((l) => l is ImageLayer);
        final city = layers.indexWhere(
          (l) => l is ImageLayer && l.assetKey == SceneryAssets.cityBridge,
        );
        final yacht = layers.indexWhere(
          (l) => l is ImageLayer && l.assetKey == SceneryAssets.yacht,
        );
        final lights = layers.indexWhere((l) => l is CityLightsLayer);
        final ocean = layers.indexWhere((l) => l is OceanLayer);
        final jet = layers.indexWhere((l) => l is DistantJetLayer);
        final skyDrones = layers.indexWhere(
          (l) =>
              l is DroneShowLayer &&
              l.visiblePhases.contains(DroneShowPhase.beam),
        );
        final launchDrones = layers.indexWhere(
          (l) =>
              l is DroneShowLayer &&
              l.visiblePhases.contains(DroneShowPhase.launch),
        );
        final glow = layers.indexWhere((l) => l is DeckGlowLayer);
        final haze = layers.indexWhere((l) => l is AtmosphericHazeLayer);
        final police = layers.indexWhere((l) => l is BridgePoliceLayer);
        // Coarse depth PLANES, not a per-layer ladder: the whole backdrop
        // (plate, skyline, yacht, ocean) shares ONE background depth so re-draws
        // never slide off their baked twins. The deck rides a nearer stage plane;
        // the dynamic jet — no baked twin — rides the farthest plane of all.
        double depthAt(int i) => (planes[i] as ParallaxLayer).depth;
        expect(depthAt(deck), greaterThan(depthAt(plate))); // stage nearer
        expect(depthAt(city), closeTo(depthAt(plate), 1e-9)); // one backdrop plane
        expect(depthAt(yacht), closeTo(depthAt(plate), 1e-9));
        expect(depthAt(ocean), closeTo(depthAt(plate), 1e-9));
        expect(depthAt(jet), lessThan(depthAt(plate))); // farthest of all
        expect(plate, 0);
        expect(cloud, greaterThan(plate));
        expect(jet, greaterThan(cloud));
        expect(jet, lessThan(ocean));
        // Animated water sits over the painted plate.
        expect(ocean, greaterThan(plate));
        expect(ocean, greaterThan(cloud));
        // The fixed skyline/bridge is re-drawn over drifting clouds so the clouds
        // stay behind the city instead of sliding across tower silhouettes.
        expect(city, greaterThan(ocean));
        // The moored yacht is re-drawn OVER the ocean so its solid hull occludes
        // the foam, and the city lights (incl. the lit cabin windows) draw on top
        // of the yacht so the warm cabin glow is not hidden behind the hull.
        expect(yacht, greaterThan(ocean));
        expect(lights, greaterThan(yacht));
        // Aerial-perspective haze veils the distant structures + city lights
        // (sits over them) but stays UNDER the foreground deck, so the deck and
        // the dancers in front of it keep full contrast (the depth cue).
        expect(haze, greaterThan(lights));
        expect(haze, lessThan(deck));
        // The foreground deck is the LAST bitmap, drawn over the ocean so foam
        // never streaks the planks; the lantern glow pools on the now-lit deck.
        expect(deck, greaterThan(ocean));
        expect(glow, greaterThan(deck));
        // The police road-closure cordon sits over the deck glow and under the
        // drones — both are post-haze active light passes — so the strobes read
        // on the bridge roadway just before the formation launches off it.
        expect(police, greaterThan(glow));
        expect(police, lessThan(skyDrones));
        // Drone passes are the highest background art pass: bridge cables,
        // palms and deck masks must not slice gaps through the ascent.
        expect(skyDrones, greaterThan(glow));
        expect(launchDrones, greaterThan(skyDrones));
      },
    );

    test('darkens the frame edges with a foreground vignette', () {
      final scene = BackdropScene.blueHourWaterfront();
      expect(scene.foregroundLayers, [isA<VignetteLayer>()]);
    });
  });

  group('BackdropScene.lagosLayeredWaterfront', () {
    // Unwrap a stack entry — a bare ParallaxLayer, or one wrapped in an
    // EmissiveLayer / GradedLayer — to its ParallaxLayer.
    ParallaxLayer? parallaxOf(BackdropLayer l) {
      final inner = switch (l) {
        EmissiveLayer(:final child) => child,
        GradedLayer(:final child) => child,
        _ => l,
      };
      return inner is ParallaxLayer ? inner : null;
    }

    ImageLayer? imageOf(BackdropLayer l) {
      final child = parallaxOf(l)?.child;
      return child is ImageLayer ? child : null;
    }

    // ImageLayers from the NORMAL / per-layer-graded layers (not emissive).
    List<ImageLayer> normalImages() => [
      for (final l in BackdropScene.lagosLayeredWaterfront().layers)
        if (l is! EmissiveLayer && imageOf(l) != null) imageOf(l)!,
    ];

    // ImageLayers from the EMISSIVE (out-of-grade) layers, in stack order.
    List<ImageLayer> emissiveImages() => [
      for (final l in BackdropScene.lagosLayeredWaterfront().layers)
        if (l is EmissiveLayer && imageOf(l) != null) imageOf(l)!,
    ];

    double depthOf(String assetKey) {
      for (final l in BackdropScene.lagosLayeredWaterfront().layers) {
        if (imageOf(l)?.assetKey == assetKey) return parallaxOf(l)!.depth;
      }
      throw StateError('no ParallaxLayer for $assetKey');
    }

    test('every background layer rides a parallax plane', () {
      final scene = BackdropScene.lagosLayeredWaterfront();
      expect(scene.layers, isNotEmpty);
      for (final l in scene.layers) {
        expect(parallaxOf(l), isNotNull);
      }
    });

    test('a dusk haze veils the distant structures (mist / smog)', () {
      final hasHaze = BackdropScene.lagosLayeredWaterfront().layers.any((l) {
        final inner = l is EmissiveLayer ? l.child : l;
        return inner is ParallaxLayer && inner.child is AtmosphericHazeLayer;
      });
      expect(hasHaze, isTrue);
    });

    test('composites base -> city -> yacht -> deck -> palms, front to back', () {
      expect([for (final l in normalImages()) l.assetKey], [
        SceneryAssets.lagosSkyOcean,
        SceneryAssets.lagosCityBridge,
        SceneryAssets.lagosYacht,
        SceneryAssets.lagosDeck,
        SceneryAssets.lagosPalms,
      ]);
    });

    test('the yacht hull is cooled/dimmed so it stops clipping white', () {
      final yacht = normalImages().firstWhere(
        (l) => l.assetKey == SceneryAssets.lagosYacht,
      );
      expect(yacht.modulate, isNotNull);
    });

    test('lit windows are emissive: held out of the grade, added, and warm', () {
      final emissive = emissiveImages();
      // Both window fields are present (each as a crisp layer plus a blurred
      // bloom twin) and nothing else is emissive.
      expect(
        emissive.map((l) => l.assetKey).toSet(),
        {SceneryAssets.lagosCityWindows, SceneryAssets.lagosYachtWindows},
      );
      // Every emissive layer is an additive, warm (amber) practical.
      for (final l in emissive) {
        expect(l.blend, BlendMode.plus);
        expect(l.modulate, isNotNull);
        expect(l.modulate!.r, greaterThan(l.modulate!.b)); // warm
      }
      // Each field has a blurred bloom twin for halation.
      expect(
        emissive.where((l) => l.blurSigma > 0).length,
        greaterThanOrEqualTo(2),
      );
    });

    test('the nearer yacht is drawn after the city windows, so it occludes them', () {
      // The city-window EmissiveLayers sit BEFORE the (normal, graded) yacht in
      // the stack, so the yacht grades and draws over them — no city lights bleed
      // onto the hull.
      final layers = BackdropScene.lagosLayeredWaterfront().layers;
      final lastCityLight = layers.lastIndexWhere(
        (l) =>
            l is EmissiveLayer &&
            imageOf(l)?.assetKey == SceneryAssets.lagosCityWindows,
      );
      final yachtIndex = layers.indexWhere(
        (l) =>
            l is! EmissiveLayer &&
            imageOf(l)?.assetKey == SceneryAssets.lagosYacht,
      );
      expect(lastCityLight, greaterThanOrEqualTo(0));
      expect(yachtIndex, greaterThan(lastCityLight));
    });

    test('the deck is graded on its own WARM curve (independent of the field)', () {
      final deckLayer = BackdropScene.lagosLayeredWaterfront().layers.firstWhere(
        (l) => imageOf(l)?.assetKey == SceneryAssets.lagosDeck,
      );
      // Per-layer graded, and its grade is warm (slope red > blue) so the wood
      // stays warm brown against the cool blue-hour field.
      expect(deckLayer, isA<GradedLayer>());
      final grade = (deckLayer as GradedLayer).grade;
      expect(grade.slope.r, greaterThan(grade.slope.b));
      expect(grade.isNeutral, isFalse);
    });

    test('warm lantern light pools on the deck as an emissive practical', () {
      final hasDeckGlow = BackdropScene.lagosLayeredWaterfront().layers.any(
        (l) => l is EmissiveLayer && parallaxOf(l)?.child is DeckGlowLayer,
      );
      expect(hasDeckGlow, isTrue);
    });

    test('each plane rides its own depth: palms nearest, sky farthest', () {
      // De-baked layers have no baked twin, so depth strictly increases toward
      // the viewer: sky < city < yacht < deck < palms.
      final sky = depthOf(SceneryAssets.lagosSkyOcean);
      final city = depthOf(SceneryAssets.lagosCityBridge);
      final yacht = depthOf(SceneryAssets.lagosYacht);
      final deck = depthOf(SceneryAssets.lagosDeck);
      final palms = depthOf(SceneryAssets.lagosPalms);
      expect(sky, lessThan(city));
      expect(city, lessThan(yacht));
      expect(yacht, lessThan(deck));
      expect(deck, lessThan(palms));
      // The city windows share the city plane; the yacht windows the yacht one.
      expect(depthOf(SceneryAssets.lagosCityWindows), city);
      expect(depthOf(SceneryAssets.lagosYachtWindows), yacht);
    });

    test('declares all seven de-baked layers to decode', () {
      expect(
        BackdropScene.lagosLayeredWaterfront().imageAssets,
        containsAll(<String>[
          SceneryAssets.lagosSkyOcean,
          SceneryAssets.lagosCityBridge,
          SceneryAssets.lagosCityWindows,
          SceneryAssets.lagosYacht,
          SceneryAssets.lagosYachtWindows,
          SceneryAssets.lagosDeck,
          SceneryAssets.lagosPalms,
        ]),
      );
    });

    test('darkens the frame edges with a foreground vignette', () {
      expect(
        BackdropScene.lagosLayeredWaterfront().foregroundLayers,
        [isA<VignetteLayer>()],
      );
    });
  });

  group('BackdropScene.proceduralBlueHour', () {
    test(
      'uses the shader sky as its back-most layer with no bitmap assets',
      () {
        final scene = BackdropScene.proceduralBlueHour();
        expect(scene.layers.first, isA<SkyLayer>());
        expect(scene.imageAssets, isEmpty);
      },
    );
  });

  group('BackdropScene', () {
    test('preserves the provided layer order', () {
      const a = SkyLayer();
      const b = SkyLayer(moonX: 0.1);
      const scene = BackdropScene(layers: [a, b]);
      expect(scene.layers, [a, b]);
      expect(scene.foregroundLayers, isEmpty);
    });
  });
}
