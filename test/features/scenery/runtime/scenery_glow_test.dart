import 'dart:ui';

import 'package:dancing_cats/features/scenery/runtime/scenery_glow.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Color> _pixelAt(
  void Function(Canvas canvas) paint,
  Size size,
  Offset point,
) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & size)
    ..drawRect(Offset.zero & size, Paint()..color = const Color(0x00000000));
  paint(canvas);
  final image = await recorder.endRecording().toImage(
    size.width.round(),
    size.height.round(),
  );
  final bytes = await image.toByteData();
  final data = bytes!.buffer.asUint8List();
  final x = point.dx.round().clamp(0, size.width.round() - 1);
  final y = point.dy.round().clamp(0, size.height.round() - 1);
  final i = (y * size.width.round() + x) * 4;
  return Color.fromARGB(data[i + 3], data[i], data[i + 1], data[i + 2]);
}

void main() {
  group('paintGlowPointLight', () {
    const size = Size(60, 60);
    const center = Offset(30, 30);

    test('sets BlendMode.plus on both the halo and the core paint', () {
      final canvas = Canvas(PictureRecorder());
      final halo = Paint();
      final core = Paint();
      paintGlowPointLight(
        canvas,
        center: center,
        color: const Color(0xFFFF0000),
        haloRadius: 10,
        haloInnerAlpha: 0.4,
        haloMidAlpha: 0.1,
        haloMidStop: 0.4,
        coreRadius: 3,
        coreColor: const Color(0xFFFFFFFF),
        coreAlpha: 0.8,
        haloPaint: halo,
        corePaint: core,
      );
      expect(halo.blendMode, BlendMode.plus);
      expect(core.blendMode, BlendMode.plus);
    });

    test('reuses the caller-supplied paint objects (no fresh allocation)', () {
      final canvas = Canvas(PictureRecorder());
      final halo = Paint();
      final core = Paint();
      expect(halo.shader, isNull);
      expect(core.color, const Color(0xFF000000));
      paintGlowPointLight(
        canvas,
        center: center,
        color: const Color(0xFF00FF00),
        haloRadius: 10,
        haloInnerAlpha: 0.4,
        haloMidAlpha: 0.1,
        haloMidStop: 0.4,
        coreRadius: 3,
        coreColor: const Color(0xFF123456),
        coreAlpha: 0.8,
        haloPaint: halo,
        corePaint: core,
      );
      // The SAME objects were mutated in place — proof the loop-reuse path
      // (hundreds of drones/lights per frame) never allocates a fresh pair.
      expect(halo.shader, isNotNull);
      expect(core.color.a, closeTo(0.8, 1e-6));
      expect(core.color.r, closeTo(const Color(0xFF123456).r, 1e-6));
      expect(core.color.g, closeTo(const Color(0xFF123456).g, 1e-6));
      expect(core.color.b, closeTo(const Color(0xFF123456).b, 1e-6));
    });

    test('a reused core paint drops any stale shader from a prior draw', () {
      final canvas = Canvas(PictureRecorder());
      final core = Paint()
        ..shader = Gradient.radial(center, 5, const [
          Color(0xFFFFFFFF),
          Color(0x00000000),
        ]);
      paintGlowPointLight(
        canvas,
        center: center,
        color: const Color(0xFF00FF00),
        haloRadius: 10,
        haloInnerAlpha: 0.4,
        haloMidAlpha: 0.1,
        haloMidStop: 0.4,
        coreRadius: 3,
        coreColor: const Color(0xFFAABBCC),
        coreAlpha: 1,
        corePaint: core,
      );
      // Otherwise a reused Paint would keep painting its OLD gradient under
      // the new flat colour, since Canvas prefers a non-null shader.
      expect(core.shader, isNull);
      const expected = Color(0xFFAABBCC);
      expect(core.color.a, closeTo(expected.a, 1e-6));
      expect(core.color.r, closeTo(expected.r, 1e-6));
      expect(core.color.g, closeTo(expected.g, 1e-6));
      expect(core.color.b, closeTo(expected.b, 1e-6));
    });

    test('allocates fresh paints and renders when none are supplied', () async {
      final pixel = await _pixelAt((canvas) {
        paintGlowPointLight(
          canvas,
          center: center,
          color: const Color(0xFFFF0000),
          haloRadius: 20,
          haloInnerAlpha: 0.9,
          haloMidAlpha: 0.3,
          haloMidStop: 0.4,
          coreRadius: 8,
          coreColor: const Color(0xFFFFFFFF),
          coreAlpha: 1,
        );
      }, size, center);
      // The core is opaque white blended additively over transparent black —
      // reads back as a fully lit, non-transparent pixel at the light centre.
      expect(pixel.a, greaterThan(0));
      expect(pixel.r, greaterThan(0.5));
      expect(pixel.g, greaterThan(0.5));
      expect(pixel.b, greaterThan(0.5));
    });

    test('the halo fades to fully transparent at its outer radius', () async {
      // Far outside the halo radius, additive blending over transparent black
      // should leave the pixel untouched (alpha 0).
      final pixel = await _pixelAt((canvas) {
        paintGlowPointLight(
          canvas,
          center: center,
          color: const Color(0xFFFF0000),
          haloRadius: 5,
          haloInnerAlpha: 0.9,
          haloMidAlpha: 0.3,
          haloMidStop: 0.4,
          coreRadius: 2,
          coreColor: const Color(0xFFFFFFFF),
          coreAlpha: 1,
        );
      }, size, const Offset(30, 55)); // well outside a 5px-radius halo at (30,30)
      expect(pixel.a, 0);
    });
  });
}
