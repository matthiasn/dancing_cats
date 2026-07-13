import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dancing_cats/features/scenery/drop_bloom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _w = 200;
const _h = 200;

// Paint the flare over black so the additive wash is directly readable as lit
// pixels.
Future<Uint8List> _render(double accent, {List<double>? laneAccents}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(
      Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
      Paint()..color = const Color(0xFF000000),
    );
  // Render through the live painter so its paint() delegation is exercised
  // alongside the shared paint function.
  DropBloomPainter(
    accent,
    laneAccents: laneAccents,
  ).paint(canvas, Size(_w.toDouble(), _h.toDouble()));
  final img = await recorder.endRecording().toImage(_w, _h);
  final bytes = (await img.toByteData())!.buffer.asUint8List();
  img.dispose();
  return bytes;
}

double _lumAt(Uint8List b, double nx, double ny) {
  final x = (nx * _w).round().clamp(0, _w - 1);
  final y = (ny * _h).round().clamp(0, _h - 1);
  final i = (y * _w + x) * 4;
  return (b[i] + b[i + 1] + b[i + 2]) / 3;
}

// The flares sit on the dancers' band; sample each voice at its own anchor.
double _voiceLum(Uint8List b, int lane) =>
    _lumAt(b, kDropBloomLaneAnchors[lane], 0.60);

void main() {
  group('paintDropBloom per-voice flares', () {
    test("a lone canon answer lifts mostly its own voice's zone", () async {
      // Only the centre voice (the lead calling) is hot — screen order.
      final b = await _render(0, laneAccents: const [0, 1, 0]);

      final left = _voiceLum(b, 0);
      final centre = _voiceLum(b, 1);
      final right = _voiceLum(b, 2);

      expect(centre, greaterThan(20), reason: 'the hot voice must be lit');
      // The flanks catch only the flare's falloff — geometrically
      // 1 - 0.20/0.34 ≈ 41% of the hot voice, where the old global dome
      // lifted every zone at full strength and masked the cascade.
      expect(left / centre, inInclusiveRange(0.31, 0.51));
      expect(right / centre, inInclusiveRange(0.31, 0.51));
      expect((left - right).abs(), lessThan(3), reason: 'symmetric leakage');
    });

    test('a tutti hit sums back to the dome it replaced', () async {
      final tutti = await _render(0, laneAccents: const [1, 1, 1]);
      final dome = await _render(1); // the global single-flare fallback

      // At frame centre the three stacked flares reproduce the old peak
      // (0.15 + 2·0.15·(1 − 0.20/0.34) ≈ 0.27 vs the dome's 0.26)...
      final tuttiCentre = _voiceLum(tutti, 1);
      final domeCentre = _voiceLum(dome, 1);
      expect(tuttiCentre / domeCentre, inInclusiveRange(0.92, 1.18));

      // ...and the flank voices lose none of the drop's punch: each now owns
      // a full flare instead of sitting in the dome's falloff.
      for (final lane in [0, 2]) {
        expect(_voiceLum(tutti, lane), greaterThanOrEqualTo(_voiceLum(dome, lane)));
      }
    });

    test('sub-threshold lane accents paint nothing', () async {
      final b = await _render(0, laneAccents: const [0.019, 0, 0.019]);
      for (final lane in [0, 1, 2]) {
        expect(_voiceLum(b, lane), 0);
      }
    });

    test('the global fallback keeps the original dome shape', () async {
      final b = await _render(1);
      final centre = _voiceLum(b, 1);
      final flank = _voiceLum(b, 0);
      expect(centre, greaterThan(20));
      expect(flank, greaterThan(0));
      expect(flank, lessThan(centre));
    });
  });

  group('DropBloomPainter', () {
    test('repaints on accent or per-voice change, not on identical input', () {
      const base = DropBloomPainter(0.5, laneAccents: [0.5, 0.2, 0]);
      expect(
        const DropBloomPainter(0.5, laneAccents: [0.5, 0.2, 0])
            .shouldRepaint(base),
        isFalse,
      );
      expect(
        const DropBloomPainter(0.6, laneAccents: [0.5, 0.2, 0])
            .shouldRepaint(base),
        isTrue,
      );
      expect(
        const DropBloomPainter(0.5, laneAccents: [0.5, 0.2, 0.1])
            .shouldRepaint(base),
        isTrue,
      );
      expect(const DropBloomPainter(0.5).shouldRepaint(base), isTrue);
    });
  });
}
