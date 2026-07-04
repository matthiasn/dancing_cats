import 'package:dancing_cats/features/scenery/layers/atmospheric_haze_layer.dart';
import 'package:dancing_cats/features/scenery/layers/bridge_police_layer.dart';
import 'package:dancing_cats/features/scenery/layers/city_lights_layer.dart';
import 'package:dancing_cats/features/scenery/layers/cloud_parallax_layer.dart';
import 'package:dancing_cats/features/scenery/layers/deck_glow_layer.dart';
import 'package:dancing_cats/features/scenery/layers/distant_jet_layer.dart';
import 'package:dancing_cats/features/scenery/layers/drone_show_layer.dart';
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
      'composites plate -> clouds -> jet -> ocean -> yacht -> deck -> drones',
      () {
        final raw = BackdropScene.blueHourWaterfront().layers;
        // Every background layer is wrapped in a ParallaxLayer; the separable
        // ones additionally carry a GradedLayer target OUTSIDE the parallax
        // (ADR 0002). Unwrap both and assert ordering on the inner children.
        final planes = <ParallaxLayer>[];
        for (final l in raw) {
          final inner = l is GradedLayer ? l.child : l;
          expect(inner, isA<ParallaxLayer>());
          planes.add(inner as ParallaxLayer);
        }
        final layers = [for (final p in planes) p.child];
        final plate = layers.indexWhere(
          (l) => l is ImageLayer && l.assetKey == SceneryAssets.cloudlessPlate,
        );
        final cloud = layers.indexWhere((l) => l is CloudParallaxLayer);
        final deck = layers.lastIndexWhere((l) => l is ImageLayer);
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
        double depthAt(int i) => planes[i].depth;
        expect(depthAt(deck), greaterThan(depthAt(plate))); // stage nearer
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
      // The vignette is a grade target (screen-space, no baked twin), so it
      // arrives wrapped under its GradedLayer id.
      expect(scene.foregroundLayers, [isA<GradedLayer>()]);
      final vignette = scene.foregroundLayers.single as GradedLayer;
      expect(vignette.target, 'vignette');
      expect(vignette.child, isA<VignetteLayer>());
    });

    test('grade targets cover only separable layers (no baked twins)', () {
      final scene = BackdropScene.blueHourWaterfront();
      final targets = <String>[
        for (final l in [...scene.layers, ...scene.foregroundLayers])
          if (l is GradedLayer) l.target,
      ];
      expect(targets, [for (final t in kBlueHourGradeTargets) t.id]);
      // The baked-twin re-draws must never be individually gradable —
      // grading one copy of a structure that also lives inside the base
      // plate halos every feathered edge (ADR 0002 §3).
      expect(targets, isNot(contains('base-plate')));
      expect(targets, isNot(contains('skyline')));
      expect(targets, isNot(contains('yacht')));
      expect(targets, isNot(contains('deck')));
      // Additive light passes are flagged so their grade drops Offset.
      final additive = <String>[
        for (final l in scene.layers)
          if (l is GradedLayer && l.additive) l.target,
      ];
      expect(
        additive,
        containsAll(<String>[
          'ocean',
          'city-lights',
          'deck-glow',
          'police',
          'drones-sky',
          'drones-launch',
        ]),
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
