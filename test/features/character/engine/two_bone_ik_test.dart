import 'dart:math' as math;

import 'package:dancing_cats/features/character/engine/two_bone_ik.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
