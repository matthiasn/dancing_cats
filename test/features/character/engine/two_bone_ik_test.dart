import 'dart:math' as math;

import 'package:dancing_cats/features/character/engine/two_bone_ik.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;

extension _AnyIk on glados.Any {
  /// A reachable solve case: two segment lengths, a target direction, and a
  /// fraction placing the target strictly inside the limb's reachable range.
  glados.Generator<({double u, double l, double dir, double frac})>
  get reachable => glados.CombinableAny(this).combine4(
    glados.DoubleAnys(this).doubleInRange(1, 20),
    glados.DoubleAnys(this).doubleInRange(1, 20),
    glados.DoubleAnys(this).doubleInRange(0, 6.2831),
    glados.DoubleAnys(this).doubleInRange(0.05, 0.95),
    (u, l, dir, frac) => (u: u, l: l, dir: dir, frac: frac),
  );
}

/// Reconstructs the end-effector (wrist) world position from a solve, so a test
/// can assert the limb actually reaches the target.
({double x, double y}) _wrist(
  TwoBoneIkSolution s, {
  required double shoulderX,
  required double shoulderY,
  required double upperLength,
  required double lowerLength,
}) {
  final elbowX = shoulderX + math.cos(s.upperAngle) * upperLength;
  final elbowY = shoulderY + math.sin(s.upperAngle) * upperLength;
  return (
    x: elbowX + math.cos(s.lowerAngle) * lowerLength,
    y: elbowY + math.sin(s.lowerAngle) * lowerLength,
  );
}

void main() {
  group('solveTwoBoneIk', () {
    test('returns null for a non-positive segment length', () {
      expect(
        solveTwoBoneIk(
          shoulderX: 0,
          shoulderY: 0,
          targetX: 3,
          targetY: 0,
          upperLength: 0,
          lowerLength: 4,
          bendDirection: 1,
        ),
        isNull,
      );
      expect(
        solveTwoBoneIk(
          shoulderX: 0,
          shoulderY: 0,
          targetX: 3,
          targetY: 0,
          upperLength: 3,
          lowerLength: -2,
          bendDirection: 1,
        ),
        isNull,
      );
    });

    test('returns null when the target sits on the shoulder', () {
      expect(
        solveTwoBoneIk(
          shoulderX: 1,
          shoulderY: 1,
          targetX: 1,
          targetY: 1,
          upperLength: 3,
          lowerLength: 4,
          bendDirection: 1,
        ),
        isNull,
      );
    });

    test('reaches a target inside its range (3-4-5 limb)', () {
      final s = solveTwoBoneIk(
        shoulderX: 0,
        shoulderY: 0,
        targetX: 5,
        targetY: 0,
        upperLength: 3,
        lowerLength: 4,
        bendDirection: 1,
      );
      expect(s, isNotNull);
      final w = _wrist(
        s!,
        shoulderX: 0,
        shoulderY: 0,
        upperLength: 3,
        lowerLength: 4,
      );
      expect(w.x, closeTo(5, 1e-9));
      expect(w.y, closeTo(0, 1e-9));
    });

    test('bendDirection flips the elbow to the opposite side', () {
      ({double x, double y}) elbow(double bend) {
        final s = solveTwoBoneIk(
          shoulderX: 0,
          shoulderY: 0,
          targetX: 5,
          targetY: 0,
          upperLength: 3,
          lowerLength: 4,
          bendDirection: bend,
        )!;
        return (x: math.cos(s.upperAngle) * 3, y: math.sin(s.upperAngle) * 3);
      }

      expect(elbow(1).y, greaterThan(0));
      expect(elbow(-1).y, lessThan(0));
    });

    test('a target beyond reach straightens the limb to its max reach', () {
      const upper = 3.0;
      const lower = 4.0;
      final s = solveTwoBoneIk(
        shoulderX: 0,
        shoulderY: 0,
        targetX: 100,
        targetY: 0,
        upperLength: upper,
        lowerLength: lower,
        bendDirection: 1,
      )!;
      final w = _wrist(
        s,
        shoulderX: 0,
        shoulderY: 0,
        upperLength: upper,
        lowerLength: lower,
      );
      // Clamped to maxReach (≈ upper + lower) and pointed at the target (+x).
      expect(math.sqrt(w.x * w.x + w.y * w.y), closeTo(upper + lower, 1e-2));
      expect(w.y, closeTo(0, 1e-2));
      expect(w.x, greaterThan(6.9));
    });
  });

  group('solveTwoBoneIk properties (generative)', () {
    glados.Glados<({double u, double l, double dir, double frac})>(
      glados.any.reachable,
      glados.ExploreConfig(numRuns: 300),
    ).test('reaches any target strictly inside its range', (c) {
      final minReach = (c.u - c.l).abs() + 1e-6;
      final maxReach = c.u + c.l - 1e-6;
      final dist = minReach + c.frac * (maxReach - minReach);
      final tx = math.cos(c.dir) * dist;
      final ty = math.sin(c.dir) * dist;
      final tag = 'u=${c.u} l=${c.l} dir=${c.dir} frac=${c.frac}';
      final s = solveTwoBoneIk(
        shoulderX: 0,
        shoulderY: 0,
        targetX: tx,
        targetY: ty,
        upperLength: c.u,
        lowerLength: c.l,
        bendDirection: 1,
      );
      expect(s, isNotNull, reason: tag);
      // Reconstruct the wrist from the solved angles; it must land on the target.
      final ex = math.cos(s!.upperAngle) * c.u;
      final ey = math.sin(s.upperAngle) * c.u;
      final wx = ex + math.cos(s.lowerAngle) * c.l;
      final wy = ey + math.sin(s.lowerAngle) * c.l;
      expect(wx, closeTo(tx, 1e-6), reason: tag);
      expect(wy, closeTo(ty, 1e-6), reason: tag);
    }, tags: 'glados');
  });

  group('elbow abduction (soft continuous open)', () {
    // A reachable mid-range target; the rigid solve is the baseline.
    const u = 10.0;
    const l = 8.0;
    const tx = 11.0;
    const ty = 4.0;
    TwoBoneIkSolution solveAbd(double abduction) => solveTwoBoneIk(
      shoulderX: 0,
      shoulderY: 0,
      targetX: tx,
      targetY: ty,
      upperLength: u,
      lowerLength: l,
      bendDirection: 1,
      abduction: abduction,
    )!;

    // Perpendicular distance of the elbow from the shoulder->target line — how
    // far the elbow is swung "off the ribs".
    double elbowPerp(TwoBoneIkSolution s) {
      final ex = math.cos(s.upperAngle) * u;
      final ey = math.sin(s.upperAngle) * u;
      final len = math.sqrt(tx * tx + ty * ty);
      return (ex * ty - ey * tx).abs() / len; // |E x T| / |T|
    }

    test('abduction 0 reproduces the exact rigid solve', () {
      final rigid = solveTwoBoneIk(
        shoulderX: 0,
        shoulderY: 0,
        targetX: tx,
        targetY: ty,
        upperLength: u,
        lowerLength: l,
        bendDirection: 1,
      )!;
      final abd0 = solveAbd(0);
      expect(abd0.upperAngle, closeTo(rigid.upperAngle, 1e-12));
      expect(abd0.lowerAngle, closeTo(rigid.lowerAngle, 1e-12));
    });

    test('positive abduction swings the elbow further off the reach line', () {
      expect(elbowPerp(solveAbd(0.3)), greaterThan(elbowPerp(solveAbd(0))));
    });

    test('it is a SOFT solve — the wrist falls short in proportion to |angle|',
        () {
      final targetDist = math.sqrt(tx * tx + ty * ty);
      double wristReach(double abd) {
        final w = _wrist(
          solveAbd(abd),
          shoulderX: 0,
          shoulderY: 0,
          upperLength: u,
          lowerLength: l,
        );
        return math.sqrt(w.x * w.x + w.y * w.y);
      }

      // 0 hits exactly; a bigger angle undershoots further.
      expect(wristReach(0), closeTo(targetDist, 1e-9));
      expect(wristReach(0.4), lessThan(wristReach(0.2)));
      expect(wristReach(0.2), lessThan(targetDist));
    });

    test('it is continuous — a tiny angle change moves the elbow a tiny amount',
        () {
      final a = solveAbd(0.20);
      final b = solveAbd(0.21);
      expect((a.upperAngle - b.upperAngle).abs(), lessThan(0.02));
    });
  });
}
