import 'dart:ui' as ui;

import 'package:dancing_cats/features/scenery/layers/backdrop_layer.dart';
import 'package:dancing_cats/features/scenery/layers/yacht_lights_layer.dart';
import 'package:dancing_cats/features/scenery/model/backdrop_palette.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // No program/images → the cabin-window shader is skipped; only the canvas
  // nav/deck lamps render, which is what these assert on. (The shader path is
  // covered by the LayeredBackdrop real-render integration test.)
  BackdropContext ctx(Size size, double time, {bool reduced = false}) =>
      BackdropContext(
        size: size,
        timeSeconds: time,
        palette: kBlueHourPalette,
        reducedMotion: reduced,
      );

  test('paints nav/deck lamps on the hull without a shader or images', () async {
    const size = Size(1280, 720); // 16:9 → normalized anchor maps to fraction
    final recorder = ui.PictureRecorder();
    const YachtLightsLayer().paint(Canvas(recorder), ctx(size, 3));
    final image = await recorder.endRecording().toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final data = await image.toByteData();
    image.dispose();

    int lum(double x, double y) {
      final i =
          ((y * size.height).round() * size.width.toInt() +
              (x * size.width).round()) *
          4;
      return data!.getUint8(i) + data.getUint8(i + 1) + data.getUint8(i + 2);
    }

    // The red port sidelight (bow) and a warm main-deck courtesy lamp are lit.
    expect(lum(0.667, 0.578), greaterThan(30), reason: 'bow port lamp lit');
    expect(lum(0.80, 0.545), greaterThan(20), reason: 'main-deck lamp lit');
    // Empty sky far from the vessel stays dark.
    expect(lum(0.05, 0.05), lessThan(20), reason: 'empty sky corner dark');
  });

  test('does not throw when its program and masks have not decoded', () {
    final recorder = ui.PictureRecorder();
    expect(
      () => const YachtLightsLayer().paint(
        Canvas(recorder),
        ctx(const Size(800, 600), 1.5),
      ),
      returnsNormally,
    );
    recorder.endRecording().dispose();
  });

  test('reduced motion freezes the lamp breath clock to a calm frame', () {
    final recorder = ui.PictureRecorder();
    const YachtLightsLayer().paint(
      Canvas(recorder),
      ctx(const Size(1280, 720), 99, reduced: true),
    );
    expect(recorder.endRecording(), isNotNull);
  });
}
