import 'package:dancing_cats/features/scenery/layers/atmospheric_haze_layer.dart';
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
      // The base plate sits on the far (sky) plane, so it barely drifts.
      expect(base.depth, lessThan(0.1));
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
        // The depth ladder is a monotonic front-to-back stack: the deck tracks
        // the cast most, then the near midground (yacht) beats the far skyline,
        // which still drifts more than the base sky plate.
        double depthAt(int i) => (planes[i] as ParallaxLayer).depth;
        expect(depthAt(deck), greaterThan(depthAt(yacht)));
        expect(depthAt(yacht), greaterThan(depthAt(city)));
        expect(depthAt(city), greaterThan(depthAt(plate)));
        expect(depthAt(deck), greaterThan(depthAt(ocean)));
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
