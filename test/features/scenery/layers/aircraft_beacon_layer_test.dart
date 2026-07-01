import 'dart:ui' as ui;

import 'package:dancing_cats/features/scenery/layers/aircraft_beacon_layer.dart';
import 'package:dancing_cats/features/scenery/layers/backdrop_layer.dart';
import 'package:dancing_cats/features/scenery/model/backdrop_palette.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

BackdropContext _ctx({double time = 0, bool reduced = false}) =>
    BackdropContext(
      size: const Size(320, 180),
      timeSeconds: time,
      palette: kBlueHourPalette,
      reducedMotion: reduced,
    );

/// Rasterizes the layer and returns the max red channel over the frame — a
/// blinking red beacon shows up as red pixels.
Future<int> _maxRed(AircraftBeaconLayer layer, BackdropContext ctx) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(
      const Rect.fromLTWH(0, 0, 320, 180),
      Paint()..color = const Color(0xFF000000),
    );
  layer.paint(canvas, ctx);
  final image = await recorder.endRecording().toImage(320, 180);
  final bytes = (await image.toByteData())!.buffer.asUint8List();
  image.dispose();
  var maxR = 0;
  for (var i = 0; i + 3 < bytes.length; i += 4) {
    if (bytes[i] > maxR) maxR = bytes[i];
  }
  return maxR;
}

void main() {
  test('default Lagos beacon anchors cover the high-rise field', () {
    expect(kLagosBeacons.length, greaterThanOrEqualTo(8));
    for (final beacon in kLagosBeacons) {
      expect(beacon.dx, inInclusiveRange(0, 1));
      expect(beacon.dy, inInclusiveRange(0, 1));
      expect(beacon.dy, lessThan(0.42));
    }
  });

  testWidgets('lights red beacons on the towers', (tester) async {
    await tester.runAsync(() async {
      // At the start of the cycle the first beacon is on → red pixels appear.
      final red = await _maxRed(const AircraftBeaconLayer(), _ctx());
      expect(red, greaterThan(40));
    });
  });

  testWidgets('blinks — a beacon dims between pulses', (tester) async {
    await tester.runAsync(() async {
      // A single beacon: on near t=0, near-dark mid-cycle (phase ~0.5).
      const layer = AircraftBeaconLayer(beacons: [Offset(0.5, 0.3)]);
      final on = await _maxRed(layer, _ctx(time: 0.05));
      final off = await _maxRed(layer, _ctx(time: 1)); // phase ~0.625 → ember
      expect(on, greaterThan(off));
    });
  });

  testWidgets('empty beacon list is a no-op', (tester) async {
    await tester.runAsync(() async {
      final red = await _maxRed(const AircraftBeaconLayer(beacons: []), _ctx());
      expect(red, 0);
    });
  });

  testWidgets('reduced motion freezes the blink clock', (tester) async {
    await tester.runAsync(() async {
      // With reduced motion the clock is pinned to 0 regardless of time.
      final a = await _maxRed(
        const AircraftBeaconLayer(),
        _ctx(time: 9, reduced: true),
      );
      final b = await _maxRed(const AircraftBeaconLayer(), _ctx(reduced: true));
      expect(a, b);
    });
  });
}
