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

  test('degrades gracefully (no hull image) but still delegates to the lights', () async {
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
    final i =
        ((0.578 * size.height).round() * size.width.toInt() +
            (0.667 * size.width).round()) *
        4;
    final navLampLit =
        data!.getUint8(i) + data.getUint8(i + 1) + data.getUint8(i + 2);
    expect(navLampLit, greaterThan(30), reason: 'group drew the nav lamps');
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
    expect(b, greaterThanOrEqualTo(r), reason: 'cool modulate keeps blue >= red');
  });
}
