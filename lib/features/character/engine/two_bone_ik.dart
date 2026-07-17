import 'dart:math' as math;

/// A planar two-bone IK solve: the world-space angles of the upper and lower
/// segments that place the limb's end effector at (or as near as it can reach
/// toward) the target.
typedef TwoBoneIkSolution = ({double upperAngle, double lowerAngle});

/// Where the end-range soft knee starts, as a fraction of the limb's full
/// reach, and the asymptotic maximum it compresses toward. The old hard
/// clamp at full reach parked the joint DEAD STRAIGHT for every
/// out-of-reach target (deliberately used by the hit-and-hold poses) and
/// kinked the solve's derivative exactly at the boundary — measured as
/// freeze-frame "peg limbs" at pose apexes and kick extremes, and a
/// one-frame paw/cuff hitch (45.05s) as a melting reach re-entered range.
/// The knee is C1 (slope 1 at its start, exponential approach to the
/// asymptote), so extension eases into ~172 degrees instead of locking at
/// 180, and nothing changes for targets under ~95.5% reach.
const double kIkSoftKneeStart = 0.955;
const double kIkSoftMaxReach = 0.9975;

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
/// [abduction] (radians, default 0) swings the elbow off the rigid solution by
/// rotating the upper segment around the shoulder by this signed angle, then
/// re-aiming the forearm at the target. In a RIGID planar two-bone solve the
/// elbow is fully determined by (shoulder, target, lengths, bend side), so this
/// is the only continuous way to open the elbow away from the body: it is a
/// deliberate SOFT solve — the wrist lands `lowerLength` from the swung elbow
/// along the elbow→target ray, so it falls slightly short of the target in
/// proportion to |abduction| (a few px for the small angles used to open a
/// tucked mime-wheel). Continuous, so — unlike a [bendDirection] flip — it never
/// snaps. 0 reproduces the exact rigid solution (backward-compatible).
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
  double abduction = 0,
}) {
  if (upperLength <= 0 || lowerLength <= 0) return null;

  final toTargetX = targetX - shoulderX;
  final toTargetY = targetY - shoulderY;
  final targetDistance = math.sqrt(
    toTargetX * toTargetX + toTargetY * toTargetY,
  );
  if (targetDistance <= 1e-6) return null;

  final minReach = (upperLength - lowerLength).abs() + 1e-6;
  final fullReach = upperLength + lowerLength;
  final kneeStart = fullReach * kIkSoftKneeStart;
  final softMax = fullReach * kIkSoftMaxReach;
  final span = softMax - kneeStart;
  final softened = targetDistance <= kneeStart
      ? targetDistance
      : kneeStart + span * (1 - math.exp(-(targetDistance - kneeStart) / span));
  final solvedDistance = softened.clamp(minReach, softMax);
  final targetAngle = math.atan2(toTargetY, toTargetX);
  final shoulderCos =
      (upperLength * upperLength +
          solvedDistance * solvedDistance -
          lowerLength * lowerLength) /
      (2 * upperLength * solvedDistance);
  final shoulderOffset = math.acos(shoulderCos.clamp(-1.0, 1.0));
  final upperAngle = targetAngle + bendDirection * shoulderOffset + abduction;
  final elbowX = shoulderX + math.cos(upperAngle) * upperLength;
  final elbowY = shoulderY + math.sin(upperAngle) * upperLength;
  final lowerAngle = math.atan2(targetY - elbowY, targetX - elbowX);
  return (upperAngle: upperAngle, lowerAngle: lowerAngle);
}
