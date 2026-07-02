import 'package:dancing_cats/features/scenery/model/backdrop_grade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;

extension _AnyGrade on glados.Any {
  /// Four wheel/saturation values in a generous range, for the grade invariants.
  glados.Generator<({double a, double b, double c, double d})> get gradeCase =>
      glados.CombinableAny(this).combine4(
        glados.DoubleAnys(this).doubleInRange(-1.5, 1.5),
        glados.DoubleAnys(this).doubleInRange(-1.5, 1.5),
        glados.DoubleAnys(this).doubleInRange(-1.5, 1.5),
        glados.DoubleAnys(this).doubleInRange(-1.5, 1.5),
        (a, b, c, d) => (a: a, b: b, c: c, d: d),
      );
}

void main() {
  group('BackdropGrade', () {
    test('the identity grade is neutral', () {
      expect(BackdropGrade.identity.isNeutral, isTrue);
    });

    test('equality and hashCode compare all coefficients', () {
      const a = BackdropGrade(saturation: 0.5);
      const b = BackdropGrade(saturation: 0.5);
      const c = BackdropGrade(saturation: 0.6);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('equality distinguishes contrast and pivot', () {
      expect(
        const BackdropGrade(contrast: 1.2),
        isNot(const BackdropGrade(contrast: 1.3)),
      );
      expect(
        const BackdropGrade(contrast: 1.2, pivot: 0.4),
        isNot(const BackdropGrade(contrast: 1.2, pivot: 0.5)),
      );
      expect(
        const BackdropGrade(contrast: 1.2).hashCode,
        const BackdropGrade(contrast: 1.2).hashCode,
      );
    });

    test('any changed coefficient makes it non-neutral', () {
      expect(
        const BackdropGrade(slope: (r: 1.1, g: 1.0, b: 1.0)).isNeutral,
        isFalse,
      );
      expect(
        const BackdropGrade(offset: (r: 0.1, g: 0.0, b: 0.0)).isNeutral,
        isFalse,
      );
      expect(
        const BackdropGrade(power: (r: 0.9, g: 1.0, b: 1.0)).isNeutral,
        isFalse,
      );
      expect(const BackdropGrade(saturation: 0.5).isNeutral, isFalse);
      expect(const BackdropGrade(contrast: 1.2).isNeutral, isFalse);
    });

    test('a changed pivot alone (contrast 1) stays neutral', () {
      // Pivot is irrelevant when contrast is 1 — no tonal change.
      expect(const BackdropGrade(pivot: 0.6).isNeutral, isTrue);
    });
  });

  group('GradeWheel', () {
    test('equality and hashCode are value-based (keyframes rely on it)', () {
      const a = GradeWheel(balance: Offset(0.2, -0.1), master: 0.3);
      // Runtime-built twin (not const-canonicalised) must still compare equal.
      double runtime(double v) => v;
      final b = GradeWheel(
        balance: const Offset(0.2, -0.1),
        master: runtime(0.3),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(const GradeWheel(balance: Offset(0.2, -0.1), master: 0.4)),
      );
      expect(
        a,
        isNot(const GradeWheel(balance: Offset(0.2, 0.1), master: 0.3)),
      );
    });
  });

  group('BackdropGrade.responseAt', () {
    test('the identity grade is the identity transfer curve', () {
      for (final x in [0.0, 0.25, 0.5, 1.0]) {
        final r = BackdropGrade.identity.responseAt(x);
        expect(r.r, closeTo(x, 1e-9));
        expect(r.g, closeTo(x, 1e-9));
        expect(r.b, closeTo(x, 1e-9));
      }
    });

    test('a positive offset lifts the shadow end above input', () {
      const g = BackdropGrade(offset: (r: 0.2, g: 0.2, b: 0.2));
      expect(g.responseAt(0).r, greaterThan(0));
    });

    test('the response is clamped into 0..1', () {
      const g = BackdropGrade(
        slope: (r: 3, g: 3, b: 3),
        offset: (r: 0.5, g: 0.5, b: 0.5),
      );
      final hi = g.responseAt(1);
      expect(hi.r, lessThanOrEqualTo(1));
      const dark = BackdropGrade(offset: (r: -1, g: -1, b: -1));
      expect(dark.responseAt(0).r, greaterThanOrEqualTo(0));
    });

    test('contrast steepens the curve about the pivot', () {
      const g = BackdropGrade(contrast: 1.6);
      // Below the pivot the contrast pushes darker; above it, brighter.
      expect(g.responseAt(0.1).r, lessThan(0.1));
      expect(g.responseAt(0.9).r, greaterThan(0.9));
    });

    test('equality distinguishes different grades', () {
      expect(
        const BackdropGrade(saturation: 0.5),
        isNot(const BackdropGrade(saturation: 0.6)),
      );
    });
  });

  group('GradeWheel', () {
    test('is neutral only when centred and unlifted', () {
      expect(const GradeWheel().isNeutral, isTrue);
      expect(const GradeWheel(master: 0.1).isNeutral, isFalse);
      expect(const GradeWheel(balance: Offset(0.1, 0)).isNeutral, isFalse);
    });
  });

  group('wheelTint', () {
    test('a centred puck is a no-op', () {
      expect(wheelTint(Offset.zero), (r: 0.0, g: 0.0, b: 0.0));
    });

    test('pushing straight up adds red and pulls green/blue (warm)', () {
      // Red sits at the top; dy is negative for "up".
      final t = wheelTint(const Offset(0, -1));
      expect(t.r, closeTo(1, 1e-9));
      expect(t.g, closeTo(-0.5, 1e-9));
      expect(t.b, closeTo(-0.5, 1e-9));
    });

    test('the balance is roughly luma-neutral (sums to ~0)', () {
      for (final p in [const Offset(0.6, 0.2), const Offset(-0.4, 0.7)]) {
        final t = wheelTint(p);
        expect(t.r + t.g + t.b, closeTo(0, 1e-9));
      }
    });

    test('radius beyond the wheel edge is clamped to 1', () {
      final t = wheelTint(const Offset(0, -4)); // far past the rim, straight up
      expect(t.r, closeTo(1, 1e-9)); // as if radius 1
    });
  });

  group('gradeFromWheels', () {
    test('all-neutral wheels build the identity grade', () {
      expect(gradeFromWheels().isNeutral, isTrue);
    });

    test('the gain master brightens the highlights (slope > 1)', () {
      final g = gradeFromWheels(gain: const GradeWheel(master: 0.5));
      expect(g.slope.r, greaterThan(1));
      expect(g.slope.g, greaterThan(1));
      expect(g.slope.b, greaterThan(1));
    });

    test('the lift master lifts the shadows (offset > 0)', () {
      final g = gradeFromWheels(lift: const GradeWheel(master: 0.5));
      expect(g.offset.r, greaterThan(0));
    });

    test('a positive gamma master lifts the mids (power < 1)', () {
      final g = gradeFromWheels(gamma: const GradeWheel(master: 0.5));
      expect(g.power.r, lessThan(1));
    });

    test('a warm gain balance pushes slope toward red', () {
      final g = gradeFromWheels(
        gain: const GradeWheel(balance: Offset(0, -1)),
      );
      expect(g.slope.r, greaterThan(g.slope.g));
      expect(g.slope.r, greaterThan(g.slope.b));
    });

    test('saturation passes through and clamps at zero', () {
      expect(gradeFromWheels(saturation: 1.4).saturation, 1.4);
      expect(gradeFromWheels(saturation: -1).saturation, 0);
    });

    test('contrast passes through to the grade', () {
      expect(gradeFromWheels(contrast: 1.3).contrast, 1.3);
    });

    test('the contrast pivot passes through to the grade', () {
      expect(gradeFromWheels(pivot: 0.55).pivot, 0.55);
    });

    test('a warm temperature pushes slope toward red, away from blue', () {
      final g = gradeFromWheels(temperature: 0.8);
      expect(g.slope.r, greaterThan(g.slope.b));
    });

    test('a cool temperature pushes slope toward blue, away from red', () {
      final g = gradeFromWheels(temperature: -0.8);
      expect(g.slope.b, greaterThan(g.slope.r));
    });

    test('a positive tint pushes magenta (red+blue) over green', () {
      final g = gradeFromWheels(tint: 0.8);
      expect(g.slope.r, greaterThan(g.slope.g));
      expect(g.slope.b, greaterThan(g.slope.g));
    });

    glados.Glados(glados.any.gradeCase, glados.ExploreConfig(numRuns: 200))
        .test('any wheel input yields a finite, bounded grade', (c) {
          final grade = gradeFromWheels(
            gain: GradeWheel(balance: Offset(c.a, c.b), master: c.a),
            lift: GradeWheel(balance: Offset(c.b, c.c), master: c.b),
            gamma: GradeWheel(balance: Offset(c.c, c.a), master: c.c),
            saturation: c.d,
            temperature: c.a,
            tint: c.b,
            contrast: c.c,
          );
          for (final v in [
            grade.slope.r,
            grade.slope.g,
            grade.slope.b,
            grade.offset.r,
            grade.power.r,
            grade.contrast,
          ]) {
            expect(v.isFinite, isTrue);
          }
          // Power stays positive and bounded so the gamma can never run away.
          expect(grade.power.r, inInclusiveRange(0.2, 3.0));
          expect(grade.saturation, greaterThanOrEqualTo(0));
        }, tags: 'glados');
  });
}
