import 'dart:math' as math;

/// A planar two-bone IK solve: the world-space angles of the upper and lower
/// segments that place the limb's end effector at (or as near as it can reach
/// toward) the target.
typedef TwoBoneIkSolution = ({double upperAngle, double lowerAngle});

/// Solves a planar two-bone limb (shoulder → elbow → upper segment, elbow →
/// wrist → lower segment) reaching from ([shoulderX], [shoulderY]) toward
/// ([targetX], [targetY]).
///
/// [upperLength]/[lowerLength] are the segment lengths and [bendDirection] (±1)
/// chooses which way the elbow breaks. The target distance is clamped to the
/// limb's reachable range, the law of cosines gives the shoulder angle and the
/// elbow position, and the two segment angles follow. Returns null for a
/// degenerate limb — a non-positive segment length or a target coincident with
/// the shoulder.
///
/// Pure math (no rig, no Flutter), so it lives in the engine beside the FK
/// solver and is unit-testable on its own; `CharacterScene` supplies the bone
/// positions/lengths and converts these world angles into local joint poses.
TwoBoneIkSolution? solveTwoBoneIk({
  required double shoulderX,
  required double shoulderY,
  required double targetX,
  required double targetY,
  required double upperLength,
  required double lowerLength,
  required double bendDirection,
}) {
  if (upperLength <= 0 || lowerLength <= 0) return null;

  final toTargetX = targetX - shoulderX;
  final toTargetY = targetY - shoulderY;
  final targetDistance = math.sqrt(
    toTargetX * toTargetX + toTargetY * toTargetY,
  );
  if (targetDistance <= 1e-6) return null;

  final minReach = (upperLength - lowerLength).abs() + 1e-6;
  final maxReach = upperLength + lowerLength - 1e-6;
  final solvedDistance = targetDistance.clamp(minReach, maxReach);
  final targetAngle = math.atan2(toTargetY, toTargetX);
  final shoulderCos =
      (upperLength * upperLength +
          solvedDistance * solvedDistance -
          lowerLength * lowerLength) /
      (2 * upperLength * solvedDistance);
  final shoulderOffset = math.acos(shoulderCos.clamp(-1.0, 1.0));
  final upperAngle = targetAngle + bendDirection * shoulderOffset;
  final elbowX = shoulderX + math.cos(upperAngle) * upperLength;
  final elbowY = shoulderY + math.sin(upperAngle) * upperLength;
  final lowerAngle = math.atan2(targetY - elbowY, targetX - elbowX);
  return (upperAngle: upperAngle, lowerAngle: lowerAngle);
}
