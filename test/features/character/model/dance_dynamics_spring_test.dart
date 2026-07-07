import 'dart:math' as math;

import 'package:dancing_cats/features/character/model/dance_dynamics.dart';
import 'package:flutter_test/flutter_test.dart';

/// Physics bar for the arm-transition spring: the mapping [danceSpring] and the
/// closed-form [dampedTransitionResponse]. A physicist judging the motion
/// checks that the trajectory is the response of a real second-order system —
/// these tests pin that on the primitive, so the two applications (hand-target
/// follow-through, rotational settle) inherit correctness.
void main() {
  group('danceSpring maps Laban dials to (ωₙ, ζ)', () {
    test("neutral reproduces today's critically-damped response", () {
      final s = danceSpring(DanceDynamics.neutral);
      // Regression-safe: neutral dials == the shipped follow-through's ζ=1,
      // ωₙ=11, so layering the spring changes nothing until a dial is set.
      expect(s.omegaN, closeTo(kSpringOmegaBase, 1e-9));
      expect(s.zeta, closeTo(kSpringZetaMid, 1e-9));
      expect(kSpringOmegaBase, 11);
      expect(kSpringZetaMid, 1);
    });

    test('Flow dials ζ: Bound → over-damped, Free → under-damped', () {
      expect(danceSpring(const DanceDynamics(flow: -1)).zeta, greaterThan(1));
      expect(danceSpring(const DanceDynamics(flow: 1)).zeta, lessThan(1));
      // Monotone in Flow.
      expect(
        danceSpring(const DanceDynamics(flow: 0.5)).zeta,
        lessThan(danceSpring(const DanceDynamics(flow: -0.5)).zeta),
      );
    });

    test('Time dials ωₙ: Sudden faster, Sustained slower', () {
      expect(
        danceSpring(const DanceDynamics(time: 1)).omegaN,
        greaterThan(kSpringOmegaBase),
      );
      expect(
        danceSpring(const DanceDynamics(time: -1)).omegaN,
        lessThan(kSpringOmegaBase),
      );
    });

    test('ζ and ωₙ stay inside their clamps for any dial combination', () {
      for (final v in [-1.0, -0.5, 0.0, 0.5, 1.0]) {
        final s = danceSpring(DanceDynamics(flow: v, time: v, weight: v));
        expect(s.zeta, inInclusiveRange(0.4, 1.6));
        expect(s.omegaN, inInclusiveRange(8, 16));
      }
    });

    test(
      'the authored catalogue is all Bound → ζ ≥ 1 (no ringing by default)',
      () {
        // Every catalogue move authors flow < 0, so none rings; the overshoot
        // lobe is opt-in via a Free (positive Flow) dial.
        for (final flow in [-0.45, -0.4, -0.35, -0.15, -0.1]) {
          expect(
            danceSpring(DanceDynamics(flow: flow)).zeta,
            greaterThanOrEqualTo(1),
          );
        }
      },
    );
  });

  group('dampedTransitionResponse — exact-frame / taper contract', () {
    const fd = 0.125; // a representative 32-frame beat step (seconds)

    test('is exactly zero AT the key (dt=0) for any (ωₙ, ζ)', () {
      for (final z in [0.4, 1.0, 1.6]) {
        expect(dampedTransitionResponse(0, fd, 12, z), 0);
      }
    });

    test('is exactly zero at the NEXT key and beyond, for any (ωₙ, ζ)', () {
      for (final z in [0.4, 1.0, 1.6]) {
        expect(dampedTransitionResponse(fd, fd, 12, z), 0);
        expect(dampedTransitionResponse(fd * 1.5, fd, 12, z), 0);
      }
    });
  });

  group('dampedTransitionResponse — second-order response (INV-1)', () {
    // A huge frameDuration keeps taper ≈ 1 over the tested window, isolating
    // the pure impulse response from the linear taper-to-zero-at-next-key.
    const fdBig = 1e6;
    const omegaN = 12.0;

    test(
      'critical (ζ=1) matches v0·t·e^(−ωₙt): single hump peaking at 1/ωₙ',
      () {
        double analytic(double t) => t * math.exp(-omegaN * t);
        for (final t in [0.01, 0.05, 1 / omegaN, 0.2, 0.4]) {
          expect(
            dampedTransitionResponse(t, fdBig, omegaN, 1),
            closeTo(analytic(t), 1e-6),
          );
        }
        final peak = dampedTransitionResponse(1 / omegaN, fdBig, omegaN, 1);
        expect(
          peak,
          greaterThan(dampedTransitionResponse(0.5 / omegaN, fdBig, omegaN, 1)),
        );
        expect(
          peak,
          greaterThan(dampedTransitionResponse(2 / omegaN, fdBig, omegaN, 1)),
        );
        // No overshoot lobe: never negative.
        for (var i = 1; i <= 200; i++) {
          expect(
            dampedTransitionResponse(i / 200, fdBig, omegaN, 1),
            greaterThanOrEqualTo(0),
          );
        }
      },
    );

    test('over-damped (ζ>1) never overshoots; under-damped (ζ<1) does', () {
      for (var i = 1; i <= 200; i++) {
        expect(
          dampedTransitionResponse(i / 200, fdBig, omegaN, 1.4),
          greaterThanOrEqualTo(0),
        );
      }
      var sawNegative = false;
      for (var i = 1; i <= 400; i++) {
        if (dampedTransitionResponse(i / 200, fdBig, omegaN, 0.4) < 0) {
          sawNegative = true;
        }
      }
      expect(sawNegative, isTrue);
    });

    test('under-damped first-overshoot ratio = e^(−ζπ/√(1−ζ²))', () {
      const zeta = 0.4;
      final omegaD = omegaN * math.sqrt(1 - zeta * zeta);
      // Analytic extrema of e^(−ζωₙt)·sin(ω_d·t): tan(ω_d·t)=√(1−ζ²)/ζ, +nπ.
      final t1 = math.atan(math.sqrt(1 - zeta * zeta) / zeta) / omegaD;
      final t2 = t1 + math.pi / omegaD;
      final k1 = dampedTransitionResponse(t1, fdBig, omegaN, zeta);
      final k2 = dampedTransitionResponse(t2, fdBig, omegaN, zeta);
      final expectedRatio = math.exp(
        -zeta * math.pi / math.sqrt(1 - zeta * zeta),
      );
      expect((k2 / k1).abs(), closeTo(expectedRatio, 1e-3));
    });

    test('continuous across the ζ=1 branch seam', () {
      const t = 0.05;
      final crit = dampedTransitionResponse(t, fdBig, omegaN, 1);
      final under = dampedTransitionResponse(t, fdBig, omegaN, 0.99);
      final over = dampedTransitionResponse(t, fdBig, omegaN, 1.01);
      expect(under, closeTo(crit, crit.abs() * 0.02));
      expect(over, closeTo(crit, crit.abs() * 0.02));
    });
  });

  group('dampedTransitionResponse — energy dissipation (INV-2)', () {
    // The pseudo-energy E = ½(ẋ² + ωₙ²x²) of the passive response must never
    // rise within a segment (dE/dt = −2ζωₙẋ² ≤ 0). This catches an oscillation
    // becoming a second snap, and any ad-hoc gain that would re-inject energy.
    // Tested untapered (the taper is a deliberate boundary cut, not the system).
    const fdBig = 1e6;
    const omegaN = 12.0;
    const h = 1e-5;

    void expectMonotoneEnergyDecay(double zeta) {
      double x(double t) => dampedTransitionResponse(t, fdBig, omegaN, zeta);
      double energy(double t) {
        final xt = x(t);
        final xdot = (x(t + h) - x(t - h)) / (2 * h);
        return 0.5 * (xdot * xdot + omegaN * omegaN * xt * xt);
      }

      var prev = double.infinity;
      for (var i = 1; i <= 300; i++) {
        final e = energy(i / 300);
        expect(
          e,
          lessThanOrEqualTo(prev * (1 + 1e-4) + 1e-9),
          reason: 'energy must not rise (ζ=$zeta, t=${i / 300})',
        );
        prev = e;
      }
    }

    test(
      'critical, over-damped and under-damped all dissipate monotonically',
      () {
        expectMonotoneEnergyDecay(1);
        expectMonotoneEnergyDecay(1.4);
        expectMonotoneEnergyDecay(0.4);
      },
    );
  });
}
