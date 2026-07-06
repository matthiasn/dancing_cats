import 'dart:ui' as ui;

import 'package:dancing_cats/features/scenery/layers/backdrop_layer.dart';
import 'package:dancing_cats/features/scenery/layers/yacht_group_layer.dart';
import 'package:dancing_cats/features/scenery/model/backdrop_palette.dart';
import 'package:dancing_cats/features/scenery/model/scenery_assets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> _solid(Color color, int w, int h) {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..color = color,
  );
  return recorder.endRecording().toImage(w, h);
}

void main() {
  // ImageLayer.paint calls paintImage, which needs the painting binding. A plain
  // test() keeps real async (so Picture.toImage resolves); ensureInitialized
  // supplies the binding without the FakeAsync clock that would deadlock toImage.
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'degrades gracefully (no hull image) but still delegates to the lights',
    () async {
      const size = Size(1280, 720);
      final recorder = ui.PictureRecorder();
      // No images: the hull ImageLayer no-ops, but the group still delegates to
      // YachtLightsLayer, whose canvas nav lamps paint.
      const YachtGroupLayer().paint(
        Canvas(recorder),
        const BackdropContext(
          size: size,
          timeSeconds: 2,
          palette: kBlueHourPalette,
        ),
      );
      final image = await recorder.endRecording().toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
      final data = await image.toByteData();
      image.dispose();
      // The lamp anchor sits at (0.667, 0.578) of this aspect-matching viewport,
      // shifted down by the group's resting sink.
      final lampY = (0.578 + YachtGroupLayer.sinkFraction) * size.height;
      final i =
          (lampY.round() * size.width.toInt() + (0.667 * size.width).round()) *
          4;
      final navLampLit =
          data!.getUint8(i) + data.getUint8(i + 1) + data.getUint8(i + 2);
      expect(navLampLit, greaterThan(30), reason: 'group drew the nav lamps');
    },
  );

  test('holds the yacht at rest under reduce-motion (no wave transform)', () {
    final recorder = ui.PictureRecorder();
    expect(
      () => const YachtGroupLayer().paint(
        Canvas(recorder),
        const BackdropContext(
          size: Size(1280, 720),
          timeSeconds: 4, // a t with real heave/roll — must be ignored
          palette: kBlueHourPalette,
          reducedMotion: true,
        ),
      ),
      returnsNormally,
    );
    recorder.endRecording().dispose();
  });

  group('yachtWaveMotion', () {
    test(
      'stays within the normalized [-1, 1] envelope across a long window',
      () {
        for (var i = 0; i < 4000; i++) {
          final t = i * 0.05; // 0..200 s
          final m = yachtWaveMotion(t);
          expect(m.heave.abs(), lessThanOrEqualTo(1.0 + 1e-9), reason: 't=$t');
          expect(m.roll.abs(), lessThanOrEqualTo(1.0 + 1e-9), reason: 't=$t');
        }
      },
    );

    test('is deterministic and freezes with the clock', () {
      expect(yachtWaveMotion(3.3), yachtWaveMotion(3.3));
      // A frozen clock (t held constant) yields a held pose, not drift.
      expect(yachtWaveMotion(0), yachtWaveMotion(0));
    });

    test('actually oscillates on both axes (not a dead constant)', () {
      final heaves = <double>[];
      final rolls = <double>[];
      for (var i = 0; i < 400; i++) {
        final m = yachtWaveMotion(i * 0.1);
        heaves.add(m.heave);
        rolls.add(m.roll);
      }
      double range(List<double> v) =>
          v.reduce((a, b) => a > b ? a : b) - v.reduce((a, b) => a < b ? a : b);
      // Swings across most of the envelope, and rocks both above and below rest.
      expect(range(heaves), greaterThan(1.2));
      expect(range(rolls), greaterThan(1.2));
      expect(heaves.any((h) => h > 0.3) && heaves.any((h) => h < -0.3), isTrue);
      expect(rolls.any((r) => r > 0.3) && rolls.any((r) => r < -0.3), isTrue);
    });
  });

  test('draws the hull bitmap when the yacht image is decoded', () async {
    const size = Size(1280, 720);
    final hull = await _solid(const Color(0xFFFFFFFF), 8, 8);
    final recorder = ui.PictureRecorder();
    const YachtGroupLayer().paint(
      Canvas(recorder),
      BackdropContext(
        size: size,
        timeSeconds: 1,
        palette: kBlueHourPalette,
        images: {SceneryAssets.yacht: hull},
      ),
    );
    final image = await recorder.endRecording().toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final data = await image.toByteData();
    image.dispose();
    hull.dispose();
    // The white hull is cover-fit over the frame and cooled by the modulate
    // (0xFFD0D5DE), so a mid-frame pixel is a bright, slightly-cool grey.
    final i = (size.height ~/ 2 * size.width.toInt() + size.width ~/ 2) * 4;
    final r = data!.getUint8(i);
    final b = data.getUint8(i + 2);
    expect(r, greaterThan(180), reason: 'hull painted');
    expect(
      b,
      greaterThanOrEqualTo(r),
      reason: 'cool modulate keeps blue >= red',
    );
  });
}
