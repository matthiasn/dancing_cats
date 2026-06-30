import 'dart:math' as math;

import 'package:dancing_cats/features/scenery/runtime/scenery_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;

extension _AnySceneryMath on glados.Any {
  glados.Generator<double> get realDouble =>
      glados.DoubleAnys(this).doubleInRange(-1000, 1000);

  glados.Generator<int> get index =>
      glados.IntAnys(this).intInRange(-10000, 10000);
}

void main() {
  group('fract', () {
    test('returns the fractional part for positive values', () {
      expect(fract(2.25), closeTo(0.25, 1e-12));
      expect(fract(0), 0);
      expect(fract(0.999), closeTo(0.999, 1e-12));
    });

    test('stays in [0, 1) for NEGATIVE values (the bug fix)', () {
      // A bare `value - value.floor()` would return -0.25 here; the negative-safe
      // version wraps to 0.75 so looping time/phase never goes negative.
      expect(fract(-0.25), closeTo(0.75, 1e-12));
      expect(fract(-1.1), closeTo(0.9, 1e-12));
      expect(fract(-3), 0);
    });

    test('is always within [0, 1)', () {
      for (final v in [-12.7, -0.001, 0.0, 5.5, 100.49]) {
        final f = fract(v);
        expect(f, greaterThanOrEqualTo(0));
        expect(f, lessThan(1));
      }
    });
  });

  group('smoothstep', () {
    test('pins the endpoints and is symmetric about the midpoint', () {
      expect(smoothstep(0), 0);
      expect(smoothstep(1), 1);
      expect(smoothstep(0.5), closeTo(0.5, 1e-12));
      expect(smoothstep(0.25) + smoothstep(0.75), closeTo(1, 1e-12));
    });

    test('clamps inputs outside [0, 1]', () {
      expect(smoothstep(-2), 0);
      expect(smoothstep(3), 1);
    });

    test('eases in and out (slower near the ends than the middle)', () {
      expect(smoothstep(0.1), lessThan(0.1));
      expect(smoothstep(0.9), greaterThan(0.9));
    });
  });

  group('hashUnit', () {
    test('is deterministic and lands in [0, 1) for many indices', () {
      for (var i = -50; i < 50; i++) {
        final h = hashUnit(i);
        expect(h, hashUnit(i), reason: 'same index → same value');
        expect(h, greaterThanOrEqualTo(0));
        expect(h, lessThan(1));
      }
    });

    test('scatters: distinct indices generally differ', () {
      final values = {for (var i = 0; i < 64; i++) hashUnit(i)};
      // A good hash should not collapse 64 indices into a handful of buckets.
      expect(values.length, greaterThan(60));
    });

    test('matches the fract(sin(n)*43758.5453) definition', () {
      expect(
        hashUnit(7),
        closeTo(fract(math.sin(8 * 12.9898) * 43758.5453), 1e-12),
      );
    });
  });

  group('properties (generative)', () {
    glados.Glados<double>(
      glados.any.realDouble,
      glados.ExploreConfig(numRuns: 300),
    ).test('fract always lands in [0, 1)', (x) {
      final f = fract(x);
      expect(f, greaterThanOrEqualTo(0), reason: 'x=$x');
      expect(f, lessThan(1), reason: 'x=$x');
    }, tags: 'glados');

    glados.Glados<double>(
      glados.any.realDouble,
      glados.ExploreConfig(numRuns: 300),
    ).test('fract is invariant under a unit shift', (x) {
      expect(fract(x), closeTo(fract(x + 1), 1e-9), reason: 'x=$x');
    }, tags: 'glados');

    glados.Glados<int>(
      glados.any.index,
      glados.ExploreConfig(numRuns: 300),
    ).test('hashUnit always lands in [0, 1) and is deterministic', (i) {
      final h = hashUnit(i);
      expect(h, greaterThanOrEqualTo(0), reason: 'i=$i');
      expect(h, lessThan(1), reason: 'i=$i');
      expect(h, hashUnit(i), reason: 'i=$i');
    }, tags: 'glados');

    glados.Glados<double>(
      glados.any.realDouble,
      glados.ExploreConfig(numRuns: 300),
    ).test('smoothstep always lands in [0, 1]', (t) {
      expect(smoothstep(t), inInclusiveRange(0, 1), reason: 't=$t');
    }, tags: 'glados');
  });
}
