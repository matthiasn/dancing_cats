import 'package:dancing_cats/features/character/runtime/dance_timing.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
