import 'dart:typed_data';

import 'package:dancing_cats/features/scenery/model/scope_histogram.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _pixels(List<List<int>> rgb) {
  final out = Uint8List(rgb.length * 4);
  for (var i = 0; i < rgb.length; i++) {
    out[i * 4] = rgb[i][0];
    out[i * 4 + 1] = rgb[i][1];
    out[i * 4 + 2] = rgb[i][2];
    out[i * 4 + 3] = 255;
  }
  return out;
}

void main() {
  group('ScopeHistogram.empty', () {
    test('has no data and zeroed bins', () {
      final h = ScopeHistogram.empty(32);
      expect(h.bins, 32);
      expect(h.hasData, isFalse);
      expect(h.peak, 0);
      expect(h.r.every((c) => c == 0), isTrue);
      expect(h.crush.r, 0);
      expect(h.clip.b, 0);
    });
  });

  group('buildScopeHistogram', () {
    test('an empty buffer yields an empty histogram', () {
      final h = buildScopeHistogram(Uint8List(0), bins: 16);
      expect(h.hasData, isFalse);
      expect(h.peak, 0);
    });

    test('all-black pixels pile into the darkest bin and read as crushed', () {
      final h = buildScopeHistogram(
        _pixels(List.filled(10, [0, 0, 0])),
        bins: 8,
      );
      expect(h.r.first, 10);
      expect(h.r.sublist(1).every((c) => c == 0), isTrue);
      expect(h.crush.r, 1.0);
      expect(h.clip.r, 0.0);
      expect(h.peak, 10);
      expect(h.hasData, isTrue);
    });

    test('all-white pixels pile into the brightest bin and read as clipped', () {
      final h = buildScopeHistogram(
        _pixels(List.filled(6, [255, 255, 255])),
        bins: 8,
      );
      expect(h.r.last, 6);
      expect(h.clip.g, 1.0);
      expect(h.crush.g, 0.0);
    });

    test('per-channel binning is independent', () {
      // One bright-red pixel: red clips, green/blue crush.
      final h = buildScopeHistogram(
        _pixels([
          [255, 0, 0],
        ]),
        bins: 4,
      );
      expect(h.r.last, 1);
      expect(h.g.first, 1);
      expect(h.b.first, 1);
      expect(h.clip.r, 1.0);
      expect(h.crush.g, 1.0);
    });

    test('mid greys land in a middle bin', () {
      final h = buildScopeHistogram(
        _pixels([
          [128, 128, 128],
        ]),
        bins: 4,
      );
      // 128 * 4 >> 8 = 2.
      expect(h.g[2], 1);
      expect(h.crush.g, 0.0);
      expect(h.clip.g, 0.0);
    });

    test('trailing bytes that do not complete a pixel are ignored', () {
      final buf = Uint8List.fromList([255, 255, 255]); // 3 bytes, no full pixel
      final h = buildScopeHistogram(buf, bins: 8);
      expect(h.hasData, isFalse);
    });
  });

  group('ScopeHistogram equality', () {
    test('same samples compare equal with matching hashCodes', () {
      final a = buildScopeHistogram(_pixels(List.filled(4, [10, 20, 30])));
      final b = buildScopeHistogram(_pixels(List.filled(4, [10, 20, 30])));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different samples are unequal', () {
      final a = buildScopeHistogram(_pixels(List.filled(4, [10, 20, 30])));
      final b = buildScopeHistogram(_pixels(List.filled(4, [40, 50, 60])));
      expect(a, isNot(b));
    });
  });
}
