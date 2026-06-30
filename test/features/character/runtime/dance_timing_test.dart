import 'package:dancing_cats/features/character/runtime/dance_timing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;

extension _AnyTiming on glados.Any {
  glados.Generator<double> get phaseTime =>
      glados.DoubleAnys(this).doubleInRange(-100, 100);

  glados.Generator<double> get unit01 =>
      glados.DoubleAnys(this).doubleInRange(0, 1);

  glados.Generator<({double t, double d})> get cycleCase =>
      glados.CombinableAny(this).combine2(
        glados.DoubleAnys(this).doubleInRange(-100, 100),
        glados.DoubleAnys(this).doubleInRange(0.05, 10),
        (t, d) => (t: t, d: d),
      );
}

void main() {
  group('cyclePhase', () {
    test('wraps time into [0, 1) of the loop', () {
      expect(cyclePhase(0.25, 1), closeTo(0.25, 1e-12));
      expect(cyclePhase(1.25, 1), closeTo(0.25, 1e-12));
      expect(cyclePhase(2, 1), closeTo(0, 1e-12));
      expect(cyclePhase(3, 2), closeTo(0.5, 1e-12));
    });

    test('is negative-safe (stays in [0, 1) below zero)', () {
      expect(cyclePhase(-0.25, 1), closeTo(0.75, 1e-12));
      expect(cyclePhase(-1, 1), closeTo(0, 1e-12));
    });
  });

  group('smoothstep', () {
    test('pins endpoints, eases the middle, and clamps out-of-range', () {
      expect(smoothstep(0), 0);
      expect(smoothstep(1), 1);
      expect(smoothstep(0.5), closeTo(0.5, 1e-12));
      expect(smoothstep(-1), 0);
      expect(smoothstep(2), 1);
      expect(smoothstep(0.1), lessThan(0.1));
    });
  });

  group('smoothKeys', () {
    const keys = [(p: 0.0, v: 0.0), (p: 0.5, v: 10.0), (p: 1.0, v: 0.0)];

    test('hits the keys and eases between them', () {
      expect(smoothKeys(0, keys), closeTo(0, 1e-12));
      expect(smoothKeys(0.5, keys), closeTo(10, 1e-12));
      // Quarter into the first segment: smoothstep(0.5) * 10 = 5.
      expect(smoothKeys(0.25, keys), closeTo(5, 1e-12));
    });

    test('the last key is the fall-through (a value at/after it clamps)', () {
      expect(smoothKeys(1, keys), closeTo(0, 1e-12));
      expect(smoothKeys(1.5, keys), closeTo(0, 1e-12));
    });
  });

  group('danceCameraShot', () {
    test('starts neutral at the top of the cycle', () {
      final shot = danceCameraShot(0, 1);
      expect(shot.zoom, closeTo(1, 1e-9));
      expect(shot.dx, closeTo(0, 1e-9));
      expect(shot.dy, closeTo(0, 1e-9));
    });

    test('peaks the push-in at mid-cycle', () {
      final shot = danceCameraShot(0.5, 1);
      expect(shot.zoom, closeTo(2.08, 1e-9), reason: 'tightest at the lead');
      expect(shot.dx, closeTo(-112, 1e-9));
      expect(shot.dy, closeTo(-88, 1e-9));
    });

    test('is periodic over the cycle', () {
      expect(danceCameraShot(2.5, 1).zoom, closeTo(2.08, 1e-9));
    });
  });

  group('properties (generative)', () {
    glados.Glados<({double t, double d})>(
      glados.any.cycleCase,
      glados.ExploreConfig(numRuns: 200),
    ).test('cyclePhase always lands in [0, 1)', (c) {
      final p = cyclePhase(c.t, c.d);
      expect(p, greaterThanOrEqualTo(0), reason: 't=${c.t} d=${c.d}');
      expect(p, lessThan(1), reason: 't=${c.t} d=${c.d}');
    }, tags: 'glados');

    glados.Glados<({double t, double d})>(
      glados.any.cycleCase,
      glados.ExploreConfig(numRuns: 200),
    ).test('cyclePhase is periodic over one duration', (c) {
      expect(
        cyclePhase(c.t, c.d),
        closeTo(cyclePhase(c.t + c.d, c.d), 1e-9),
        reason: 't=${c.t} d=${c.d}',
      );
    }, tags: 'glados');

    glados.Glados<double>(
      glados.any.phaseTime,
      glados.ExploreConfig(numRuns: 200),
    ).test('smoothstep stays in [0, 1]', (t) {
      expect(smoothstep(t), inInclusiveRange(0, 1), reason: 't=$t');
    }, tags: 'glados');

    glados.Glados<double>(
      glados.any.unit01,
      glados.ExploreConfig(numRuns: 200),
    ).test('smoothstep is symmetric about 0.5', (t) {
      expect(
        smoothstep(t) + smoothstep(1 - t),
        closeTo(1, 1e-9),
        reason: 't=$t',
      );
    }, tags: 'glados');

    glados.Glados<({double t, double d})>(
      glados.any.cycleCase,
      glados.ExploreConfig(numRuns: 200),
    ).test('danceCameraShot zoom stays within the authored key range', (c) {
      // Smoothstep interpolation never overshoots adjacent keys, so the zoom
      // stays within the table's [1.0, 2.08] span.
      final z = danceCameraShot(c.t, c.d).zoom;
      expect(z, greaterThanOrEqualTo(1.0 - 1e-9), reason: 't=${c.t} d=${c.d}');
      expect(z, lessThanOrEqualTo(2.08 + 1e-9), reason: 't=${c.t} d=${c.d}');
    }, tags: 'glados');
  });
}
