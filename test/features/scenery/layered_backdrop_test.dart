import 'dart:async';
import 'dart:ui' as ui;

import 'package:dancing_cats/features/scenery/layered_backdrop.dart';
import 'package:dancing_cats/features/scenery/model/backdrop_scene.dart';
import 'package:dancing_cats/features/scenery/model/scenery_assets.dart';
import 'package:dancing_cats/features/scenery/runtime/scenery_shaders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.FragmentProgram> _failingLoader() =>
    Future<ui.FragmentProgram>.error(StateError('shader unavailable'));

// A second, distinct failing loader so didUpdateWidget sees the sky program
// loader change (tear-offs of the same function compare equal).
Future<ui.FragmentProgram> _otherFailingLoader() =>
    Future<ui.FragmentProgram>.error(StateError('other shader unavailable'));

Future<ui.Image> _solid(Color color, int w, int h) {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..color = color,
  );
  return recorder.endRecording().toImage(w, h);
}

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox.expand(child: child)),
);

void main() {
  tearDown(SceneryShaderProgramCache.reset);

  testWidgets('renders without error before the shaders load (no fallback)', (
    tester,
  ) async {
    // Hard rule: no CPU fallback. When the shader programs fail/aren't loaded,
    // those layers draw nothing — the backdrop still composites without error
    // (it does NOT substitute a lower-fidelity stand-in).
    await tester.pumpWidget(
      _host(
        LayeredBackdrop(
          scene: BackdropScene.proceduralBlueHour(),
          timeOverride: 1.5,
          skyProgramLoader: _failingLoader,
          oceanProgramLoader: _failingLoader,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('drives the real sky shader without a uniform mismatch', (
    tester,
  ) async {
    // A wrong float count would throw a RangeError in paint.
    final sky = await ui.FragmentProgram.fromAsset(SceneryShaderAssets.sky);

    await tester.pumpWidget(
      _host(
        LayeredBackdrop(
          scene: BackdropScene.proceduralBlueHour(),
          timeOverride: 2,
          skyProgramLoader: () async => sky,
          oceanProgramLoader: _failingLoader,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('decodes the painted scene assets via the injected loader', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final requested = <String>[];
      // A fresh image per asset — the widget owns and disposes each one.
      Future<ui.Image> loader(String path) async {
        requested.add(path);
        return _solid(const Color(0xFF112233), 4, 4);
      }

      await tester.pumpWidget(
        _host(
          LayeredBackdrop(
            scene: BackdropScene.blueHourWaterfront(),
            timeOverride: 0,
            skyProgramLoader: _failingLoader,
            oceanProgramLoader: _failingLoader,
            imageLoader: loader,
          ),
        ),
      );
      await tester.pump();

      expect(requested, contains(SceneryAssets.cloudlessPlate));
      expect(tester.takeException(), isNull);
      // The widget owns and disposes the decoded image on teardown.
    });
  });

  testWidgets('notifies after the first resource-complete frame paints', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final sky = await ui.FragmentProgram.fromAsset(SceneryShaderAssets.sky);
      final ocean = await ui.FragmentProgram.fromAsset(
        SceneryShaderAssets.ocean,
      );
      final cityLights = await ui.FragmentProgram.fromAsset(
        SceneryShaderAssets.cityLights,
      );

      var ready = false;
      await tester.pumpWidget(
        _host(
          LayeredBackdrop(
            scene: BackdropScene.blueHourWaterfront(),
            timeOverride: 0,
            skyProgramLoader: () async => sky,
            oceanProgramLoader: () async => ocean,
            cityLightsProgramLoader: () async => cityLights,
            imageLoader: (_) => _solid(const Color(0xFF112233), 4, 4),
            onReady: () => ready = true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(ready, isTrue);
    });
  });

  testWidgets('self-drives a clock when no time is injected', (tester) async {
    await tester.pumpWidget(
      _host(
        LayeredBackdrop(
          scene: BackdropScene.proceduralBlueHour(),
          skyProgramLoader: _failingLoader,
          oceanProgramLoader: _failingLoader,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    expect(tester.takeException(), isNull);
  });

  testWidgets('holds a calm frame under reduce-motion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: SizedBox.expand(
              child: LayeredBackdrop(
                scene: BackdropScene.proceduralBlueHour(),
                skyProgramLoader: _failingLoader,
                oceanProgramLoader: _failingLoader,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));

    expect(tester.takeException(), isNull);
  });

  testWidgets('decodes scene bitmaps through the default rootBundle loader', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // No imageLoader is injected, so the widget must fall back to its bundled
      // rootBundle decoder. With the real shader programs supplied, onReady only
      // fires once that default loader has decoded the scene's lone asset.
      final sky = await ui.FragmentProgram.fromAsset(SceneryShaderAssets.sky);
      final ocean = await ui.FragmentProgram.fromAsset(
        SceneryShaderAssets.ocean,
      );
      final cityLights = await ui.FragmentProgram.fromAsset(
        SceneryShaderAssets.cityLights,
      );

      var ready = false;
      await tester.pumpWidget(
        _host(
          LayeredBackdrop(
            scene: const BackdropScene(
              layers: [],
              imageAssets: [SceneryAssets.cityWindows],
            ),
            timeOverride: 0,
            skyProgramLoader: () async => sky,
            oceanProgramLoader: () async => ocean,
            cityLightsProgramLoader: () async => cityLights,
            onReady: () => ready = true,
          ),
        ),
      );

      for (var i = 0; i < 40 && !ready; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
        await tester.pump();
      }

      expect(
        ready,
        isTrue,
        reason: 'the default rootBundle loader decoded the bundled asset',
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('reloads programs and images when the config changes', (
    tester,
  ) async {
    Widget build({
      required SceneryShaderProgramLoader sky,
      required List<String> assets,
    }) => _host(
      LayeredBackdrop(
        scene: BackdropScene(layers: const [], imageAssets: assets),
        timeOverride: 0,
        skyProgramLoader: sky,
        oceanProgramLoader: _failingLoader,
        imageLoader: (_) => Future<ui.Image>.error(StateError('skip decode')),
      ),
    );

    await tester.pumpWidget(
      build(
        sky: _failingLoader,
        assets: const ['assets/scenery/clouds_far.webp'],
      ),
    );
    await tester.pump();
    // A new sky loader AND a new asset list both trip didUpdateWidget's
    // reload branches (programs reload, images reload).
    await tester.pumpWidget(
      build(
        sky: _otherFailingLoader,
        assets: const ['assets/scenery/clouds_mid.webp'],
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('stops the self-clock ticker when an external clock takes over', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        LayeredBackdrop(
          scene: BackdropScene.proceduralBlueHour(),
          skyProgramLoader: _failingLoader,
          oceanProgramLoader: _failingLoader,
        ),
      ),
    );
    // Self-driven: the ticker is running.
    await tester.pump(const Duration(milliseconds: 16));

    // Hand it an external clock (timeOverride) → didUpdateWidget re-syncs and
    // stops the now-unneeded ticker.
    await tester.pumpWidget(
      _host(
        LayeredBackdrop(
          scene: BackdropScene.proceduralBlueHour(),
          timeOverride: 1.5,
          skyProgramLoader: _failingLoader,
          oceanProgramLoader: _failingLoader,
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('repaint check reaches the image-version clause when stable', (
    tester,
  ) async {
    // Reuse one scene instance + identical params, so every painter field
    // compares equal and shouldRepaint falls through to its last (image
    // version) clause instead of short-circuiting earlier.
    final scene = BackdropScene.proceduralBlueHour();
    LayeredBackdrop widget() => LayeredBackdrop(
      scene: scene,
      timeOverride: 2,
      beatPulse: 0.5,
      skyProgramLoader: _failingLoader,
      oceanProgramLoader: _failingLoader,
      cityLightsProgramLoader: _failingLoader,
    );

    await tester.pumpWidget(_host(widget()));
    await tester.pump();
    await tester.pumpWidget(_host(widget()));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('disposes a late image that resolves after teardown', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final completer = Completer<ui.Image>();
      await tester.pumpWidget(
        _host(
          LayeredBackdrop(
            scene: const BackdropScene(
              layers: [],
              imageAssets: ['assets/scenery/clouds_far.webp'],
            ),
            timeOverride: 0,
            skyProgramLoader: _failingLoader,
            oceanProgramLoader: _failingLoader,
            imageLoader: (_) => completer.future,
          ),
        ),
      );
      await tester.pump();

      // Tear the backdrop down before the decode resolves.
      await tester.pumpWidget(_host(const SizedBox.shrink()));

      final image = await _solid(const Color(0xFF010203), 2, 2);
      completer.complete(image);
      await Future<void>.delayed(Duration.zero);
      await tester.pump();

      expect(
        image.debugDisposed,
        isTrue,
        reason:
            'an image that arrives after unmount must be disposed, not kept',
      );
    });
  });
}
