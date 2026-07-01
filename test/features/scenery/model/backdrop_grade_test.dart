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

    glados.Glados(glados.any.gradeCase, glados.ExploreConfig(numRuns: 200))
        .test('any wheel input yields a finite, bounded grade', (c) {
          final grade = gradeFromWheels(
            gain: GradeWheel(balance: Offset(c.a, c.b), master: c.a),
            lift: GradeWheel(balance: Offset(c.b, c.c), master: c.b),
            gamma: GradeWheel(balance: Offset(c.c, c.a), master: c.c),
            saturation: c.d,
          );
          for (final v in [
            grade.slope.r,
            grade.slope.g,
            grade.slope.b,
            grade.offset.r,
            grade.power.r,
          ]) {
            expect(v.isFinite, isTrue);
          }
          // Power stays positive and bounded so the gamma can never run away.
          expect(grade.power.r, inInclusiveRange(0.2, 3.0));
          expect(grade.saturation, greaterThanOrEqualTo(0));
        }, tags: 'glados');
  });
}
