import 'package:dancing_cats/features/character/model/dance_dynamics.dart';
import 'package:dancing_cats/features/character/model/easing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;

void main() {
  List<double> sample(EaseCurve f, {int n = 100}) => [
    for (var i = 0; i <= n; i++) f(i / n),
  ];

  double minOf(Iterable<double> xs) => xs.reduce((a, b) => a < b ? a : b);
  double maxOf(Iterable<double> xs) => xs.reduce((a, b) => a > b ? a : b);

  group('dynamicsCurve — neutral is regression-safe', () {
    test('neutral dynamics reproduces easeInOut exactly', () {
      final f = dynamicsCurve(DanceDynamics.neutral);
      for (var i = 0; i <= 100; i++) {
        final t = i / 100;
        expect(f(t), closeTo(Ease.easeInOut.apply(t), 1e-12));
      }
    });
  });

  group('dynamicsCurve — endpoints are exact', () {
    test('every curve passes through (0,0) and (1,1)', () {
      const cases = [
        DanceDynamics(weight: 1),
        DanceDynamics(weight: -1),
        DanceDynamics(time: 1),
        DanceDynamics(time: -1),
        DanceDynamics(flow: 1),
        DanceDynamics(flow: -1),
        DanceDynamics(weight: 1, time: 1, flow: 1),
        DanceDynamics(weight: -1, time: -1, flow: -1),
      ];
      for (final d in cases) {
        final f = dynamicsCurve(d);
        expect(f(0), closeTo(0, 1e-12), reason: 'start for $d');
        expect(f(1), closeTo(1, 1e-12), reason: 'end for $d');
      }
    });
  });

  group('dynamicsCurve — anticipation comes from Weight', () {
    test('a Strong accent dips below the start (wind-up)', () {
      final f = dynamicsCurve(const DanceDynamics(weight: 0.8));
      final earlyMin = minOf([for (var i = 1; i < 40; i++) f(i / 100)]);
      expect(
        earlyMin,
        lessThan(0),
        reason: 'the limb should pull back before driving to the peak',
      );
    });

    test('non-Strong accents never dip below the start', () {
      const cases = [
        DanceDynamics(weight: -0.8),
        DanceDynamics(time: 0.8),
        DanceDynamics(flow: 0.8),
      ];
      for (final d in cases) {
        expect(
          minOf(sample(dynamicsCurve(d))),
          greaterThan(-1e-9),
          reason: 'no wind-up expected for $d',
        );
      }
    });

    test('more Weight produces a deeper wind-up', () {
      double dip(double w) => minOf(
        [
          for (var i = 1; i < 40; i++)
            dynamicsCurve(DanceDynamics(weight: w))(i / 100),
        ],
      );
      expect(dip(0.9), lessThan(dip(0.4)));
      expect(dip(0.4), lessThan(0));
    });
  });

  group('dynamicsCurve — overshoot comes from Flow', () {
    test('a Free accent rises past the target then settles back', () {
      final f = dynamicsCurve(const DanceDynamics(flow: 0.8));
      final lateMax = maxOf([for (var i = 60; i < 100; i++) f(i / 100)]);
      expect(lateMax, greaterThan(1), reason: 'should overshoot past the peak');
      expect(f(1), closeTo(1, 1e-12), reason: 'and settle exactly on it');
    });

    test('non-Free accents never overshoot the target', () {
      const cases = [
        DanceDynamics(flow: -0.8),
        DanceDynamics(weight: 0.8),
        DanceDynamics(time: -0.8),
      ];
      for (final d in cases) {
        expect(
          maxOf(sample(dynamicsCurve(d))),
          lessThan(1 + 1e-9),
          reason: 'no overshoot expected for $d',
        );
      }
    });
  });

  group('dynamicsCurve — snap vs sustain comes from Time', () {
    // The steepest segment is where the joint moves fastest. A Sudden accent
    // should place it late (accelerate into the peak); a Sustained one early.
    double steepestAt(DanceDynamics d) {
      final f = dynamicsCurve(d);
      var bestX = 0.0;
      var bestSlope = double.negativeInfinity;
      for (var i = 0; i < 200; i++) {
        final x0 = i / 200;
        final x1 = (i + 1) / 200;
        final slope = (f(x1) - f(x0)) / (x1 - x0);
        if (slope > bestSlope) {
          bestSlope = slope;
          bestX = (x0 + x1) / 2;
        }
      }
      return bestX;
    }

    test('Sudden snaps late, Sustained eases early', () {
      expect(steepestAt(const DanceDynamics(time: 0.8)), greaterThan(0.5));
      expect(steepestAt(const DanceDynamics(time: -0.8)), lessThan(0.5));
    });

    test('neutral is symmetric — steepest at the middle', () {
      expect(steepestAt(DanceDynamics.neutral), closeTo(0.5, 0.06));
    });
  });

  group('dynamicsCurve — Glados invariants', () {
    final anyDynamics = glados.any
        .combine3<double, double, double, DanceDynamics>(
          glados.DoubleAnys(glados.any).doubleInRange(-1, 1),
          glados.DoubleAnys(glados.any).doubleInRange(-1, 1),
          glados.DoubleAnys(glados.any).doubleInRange(-1, 1),
          (w, t, f) => DanceDynamics(weight: w, time: t, flow: f),
        );

    glados.Glados(anyDynamics, glados.ExploreConfig(numRuns: 300)).test(
      'endpoints exact, curve finite and bounded for any dials',
      (d) {
        final f = dynamicsCurve(d);
        expect(f(0), closeTo(0, 1e-9));
        expect(f(1), closeTo(1, 1e-9));
        for (var i = 0; i <= 50; i++) {
          final v = f(i / 50);
          expect(v.isFinite, isTrue);
          expect(v, inInclusiveRange(-0.5, 1.5));
        }
      },
      tags: 'glados',
    );
  });

  group('DanceDynamics — value algebra', () {
    test('operator+ sums axis-wise without clamping', () {
      const a = DanceDynamics(weight: 0.7, time: -0.2, flow: 0.5);
      const b = DanceDynamics(weight: 0.6, time: -0.9, flow: -0.5);
      final sum = a + b;
      expect(sum.weight, closeTo(1.3, 1e-12));
      expect(sum.time, closeTo(-1.1, 1e-12));
      expect(sum.flow, closeTo(0, 1e-12));
    });

    test('scale multiplies every axis', () {
      const d = DanceDynamics(weight: 0.4, time: -0.6, flow: 0.2);
      final half = d.scale(0.5);
      expect(half.weight, closeTo(0.2, 1e-12));
      expect(half.time, closeTo(-0.3, 1e-12));
      expect(half.flow, closeTo(0.1, 1e-12));
      expect(d.scale(0), DanceDynamics.neutral);
    });

    test('clamped caps each axis independently at ±limit', () {
      const d = DanceDynamics(weight: 1.3, time: -1.1, flow: 0.2);
      final c = d.clamped();
      expect(c.weight, 1);
      expect(c.time, -1);
      expect(c.flow, closeTo(0.2, 1e-12));
      final budgeted = d.clamped(limit: 0.35);
      expect(budgeted.weight, closeTo(0.35, 1e-12));
      expect(budgeted.time, closeTo(-0.35, 1e-12));
      expect(budgeted.flow, closeTo(0.2, 1e-12));
    });

    test('lerp hits both endpoints exactly and the midpoint', () {
      const a = DanceDynamics(weight: -0.4, time: 0.8, flow: -0.2);
      const b = DanceDynamics(weight: 0.6, time: -0.2, flow: 0.4);
      expect(DanceDynamics.lerp(a, b, 0), a);
      expect(DanceDynamics.lerp(a, b, 1), b);
      final mid = DanceDynamics.lerp(a, b, 0.5);
      expect(mid.weight, closeTo(0.1, 1e-12));
      expect(mid.time, closeTo(0.3, 1e-12));
      expect(mid.flow, closeTo(0.1, 1e-12));
    });

    test('equality and hashCode are value-based', () {
      const a = DanceDynamics(weight: 0.1, time: 0.2, flow: 0.3);
      const b = DanceDynamics(weight: 0.1, time: 0.2, flow: 0.3);
      const c = DanceDynamics(weight: 0.1, time: 0.2, flow: 0.4);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a.toString(), contains('0.2'));
    });
  });

  group('effectiveDanceDynamics — composition with a modulation budget', () {
    test('neutral modulation returns the move base unchanged', () {
      const base = DanceDynamics(weight: 0.7, time: 0.6, flow: -0.45);
      expect(
        effectiveDanceDynamics(
          moveBase: base,
          catProfile: DanceDynamics.neutral,
          sectionEnergy: DanceDynamics.neutral,
        ),
        base,
      );
    });

    test('cat + section offsets are capped to the budget before adding', () {
      const base = DanceDynamics(weight: 0.5);
      final eff = effectiveDanceDynamics(
        moveBase: base,
        catProfile: const DanceDynamics(weight: 0.3),
        sectionEnergy: const DanceDynamics(weight: 0.3),
      );
      // 0.3 + 0.3 = 0.6 caps at the 0.35 budget, then adds to the base.
      expect(eff.weight, closeTo(0.5 + kDanceDynamicsModulationBudget, 1e-12));
    });

    test('the result clamps to the valid -1..1 range', () {
      final eff = effectiveDanceDynamics(
        moveBase: const DanceDynamics(weight: 0.9),
        catProfile: const DanceDynamics(weight: 0.3),
        sectionEnergy: const DanceDynamics(weight: 0.3),
      );
      expect(eff.weight, 1);
    });

    test(
      'a defining axis (|axis| >= 0.4) can never invert under any '
      'in-range modulation',
      () {
        // Worst-case adversarial offsets on every axis, both directions.
        const bases = [
          DanceDynamics(weight: 0.4),
          DanceDynamics(weight: -0.4),
          DanceDynamics(time: 0.4),
          DanceDynamics(time: -0.4),
          DanceDynamics(flow: 0.4),
          DanceDynamics(flow: -0.4),
        ];
        for (final base in bases) {
          for (final sign in const [-1.0, 1.0]) {
            final eff = effectiveDanceDynamics(
              moveBase: base,
              catProfile: DanceDynamics(
                weight: sign,
                time: sign,
                flow: sign,
              ),
              sectionEnergy: DanceDynamics(
                weight: sign,
                time: sign,
                flow: sign,
              ),
            );
            for (final (baseAxis, effAxis) in [
              (base.weight, eff.weight),
              (base.time, eff.time),
              (base.flow, eff.flow),
            ]) {
              if (baseAxis == 0) continue;
              expect(
                effAxis.sign,
                baseAxis.sign,
                reason:
                    'base $base with modulation sign $sign must keep its '
                    'Effort character',
              );
            }
          }
        }
      },
    );
  });

  group('dynamicsTimeWarp — beat-local sampling-clock warp', () {
    test('neutral dynamics is the exact identity', () {
      final warp = dynamicsTimeWarp(DanceDynamics.neutral);
      for (var i = 0; i <= 100; i++) {
        final u = i / 100;
        expect(warp(u), u, reason: 'identity must be exact, not approximate');
      }
    });

    test('zero gain is the exact identity for any dials', () {
      final warp = dynamicsTimeWarp(
        const DanceDynamics(weight: 1, time: 1, flow: 1),
        gain: 0,
      );
      for (var i = 0; i <= 100; i++) {
        final u = i / 100;
        expect(warp(u), u);
      }
    });

    test('endpoints are exact for any dials — dancers re-sync every beat', () {
      const cases = [
        DanceDynamics(weight: 1),
        DanceDynamics(time: 1),
        DanceDynamics(time: -1),
        DanceDynamics(flow: 1),
        DanceDynamics(weight: 1, time: 1, flow: 1),
        DanceDynamics(weight: -1, time: -1, flow: -1),
      ];
      for (final d in cases) {
        final warp = dynamicsTimeWarp(d);
        expect(warp(0), closeTo(0, 1e-12), reason: 'beat start for $d');
        expect(warp(1), closeTo(1, 1e-12), reason: 'beat end for $d');
      }
    });

    test('Sudden samples behind the shared clock through the approach', () {
      final warp = dynamicsTimeWarp(const DanceDynamics(time: 0.8));
      final early = [for (var i = 10; i < 50; i++) warp(i / 100) - i / 100];
      expect(
        minOf(early),
        lessThan(0),
        reason: 'a Sudden dancer holds back, then snaps late into the hit',
      );
    });

    test('Strong dips below the beat start (retrograde wind-up)', () {
      final warp = dynamicsTimeWarp(const DanceDynamics(weight: 1));
      final early = [for (var i = 1; i < 40; i++) warp(i / 100)];
      expect(minOf(early), lessThan(0));
    });

    test('Free runs past the beat end before returning', () {
      final warp = dynamicsTimeWarp(const DanceDynamics(flow: 1));
      final late = [for (var i = 60; i < 100; i++) warp(i / 100)];
      expect(maxOf(late), greaterThan(1));
      expect(warp(1), closeTo(1, 1e-12));
    });

    test('gain scales the deviation from the unwarped clock linearly', () {
      const d = DanceDynamics(time: 0.8);
      final half = dynamicsTimeWarp(d, gain: 0.5);
      final full = dynamicsTimeWarp(d);
      for (var i = 0; i <= 100; i++) {
        final u = i / 100;
        expect(half(u) - u, closeTo((full(u) - u) * 0.5, 1e-12));
      }
    });

    final anyDynamics = glados.any
        .combine3<double, double, double, DanceDynamics>(
          glados.DoubleAnys(glados.any).doubleInRange(-1, 1),
          glados.DoubleAnys(glados.any).doubleInRange(-1, 1),
          glados.DoubleAnys(glados.any).doubleInRange(-1, 1),
          (w, t, f) => DanceDynamics(weight: w, time: t, flow: f),
        );

    glados.Glados(anyDynamics, glados.ExploreConfig(numRuns: 300)).test(
      'endpoints exact, deviation bounded by gain * 0.72 for any dials',
      (d) {
        final warp = dynamicsTimeWarp(d, gain: 0.35);
        expect(warp(0), closeTo(0, 1e-9));
        expect(warp(1), closeTo(1, 1e-9));
        for (var i = 0; i <= 50; i++) {
          final u = i / 50;
          final v = warp(u);
          expect(v.isFinite, isTrue);
          // The pointwise gap between dynamicsCurve and easeInOut maxes out at
          // ~0.717 (measured by exhaustive 0.1-grid scan over the dial cube;
          // worst case is Strong + Sudden + Bound, where the late-skewed snap
          // lags the symmetric ease hardest mid-beat). The warp deviation is
          // that gap times the gain.
          expect((v - u).abs(), lessThanOrEqualTo(0.35 * 0.72));
        }
      },
      tags: 'glados',
    );
  });
}
