import 'dart:math' as math;

import 'package:dancing_cats/features/character/model/affine2d.dart';
import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/face.dart';
import 'package:dancing_cats/features/character/runtime/character_scene.dart';

/// Frame-by-frame continuity probe for resolved character motion.
///
/// This deliberately lives after [CharacterScene], not in the lower-level clip
/// evaluator: snaps can come from clip channels, contact pinning, head
/// stabilization, autonomic layers, or base transforms. The analyzer measures
/// the resolved world-space bone origins that the renderer actually sees.
class TemporalMotionAnalyzer {
  const TemporalMotionAnalyzer(this.scene);

  final CharacterScene scene;

  TemporalMotionReport analyze({
    required Clip clip,
    required int samples,
    required List<String> boneIds,
    Expression expression = Expression.neutral,
    Affine2D base = Affine2D.identity,
  }) {
    if (samples <= 0) {
      throw ArgumentError.value(samples, 'samples', 'must be positive');
    }
    if (boneIds.isEmpty) {
      throw ArgumentError.value(boneIds, 'boneIds', 'must not be empty');
    }

    final segments = <TemporalMotionSegment>[];
    final accelerations = <TemporalMotionAcceleration>[];
    final jerks = <TemporalMotionJerk>[];
    final previousByBone = <String, TemporalMotionSegment>{};
    final previousAccelerationByBone = <String, TemporalMotionAcceleration>{};

    final angularSegments = <TemporalMotionAngularSegment>[];
    final angularAccelerations = <TemporalMotionAngularAcceleration>[];
    final angularJerks = <TemporalMotionAngularJerk>[];
    final previousAngularByBone = <String, TemporalMotionAngularSegment>{};
    final previousAngularAccelerationByBone =
        <String, TemporalMotionAngularAcceleration>{};
    // Unwrapped (accumulated, not wrapped to +/-pi) world-space angle per bone,
    // so a bone whose rotation crosses the atan2 branch cut doesn't register a
    // fake near-2*pi jerk spike. Seeded from frame 0 below.
    final unwrappedAngleByBone = <String, double>{};

    var previous = scene.frameAt(
      clip: clip,
      timeSeconds: 0,
      expression: expression,
      base: base,
    );
    for (final boneId in boneIds) {
      final transform = previous.world[boneId];
      if (transform == null) {
        throw StateError('Bone "$boneId" was not resolved for ${clip.name}.');
      }
      unwrappedAngleByBone[boneId] = math.atan2(transform.b, transform.a);
    }

    for (var frame = 1; frame <= samples; frame++) {
      final timeSeconds = clip.duration * frame / samples;
      final current = scene.frameAt(
        clip: clip,
        timeSeconds: timeSeconds,
        expression: expression,
        base: base,
      );

      for (final boneId in boneIds) {
        final previousTransform = previous.world[boneId];
        final currentTransform = current.world[boneId];
        if (previousTransform == null || currentTransform == null) {
          throw StateError('Bone "$boneId" was not resolved for ${clip.name}.');
        }

        final dx = currentTransform.tx - previousTransform.tx;
        final dy = currentTransform.ty - previousTransform.ty;
        final segment = TemporalMotionSegment(
          boneId: boneId,
          fromFrame: frame - 1,
          toFrame: frame,
          fromPhase: (frame - 1) / samples,
          toPhase: frame / samples,
          dx: dx,
          dy: dy,
          distance: math.sqrt(dx * dx + dy * dy),
        );
        segments.add(segment);

        final previousSegment = previousByBone[boneId];
        if (previousSegment != null) {
          final ax = segment.dx - previousSegment.dx;
          final ay = segment.dy - previousSegment.dy;
          final acceleration = TemporalMotionAcceleration(
            boneId: boneId,
            fromFrame: previousSegment.fromFrame,
            throughFrame: previousSegment.toFrame,
            toFrame: segment.toFrame,
            fromPhase: previousSegment.fromPhase,
            throughPhase: previousSegment.toPhase,
            toPhase: segment.toPhase,
            dx: ax,
            dy: ay,
            magnitude: math.sqrt(ax * ax + ay * ay),
          );
          accelerations.add(acceleration);

          final previousAcceleration = previousAccelerationByBone[boneId];
          if (previousAcceleration != null) {
            final jx = acceleration.dx - previousAcceleration.dx;
            final jy = acceleration.dy - previousAcceleration.dy;
            jerks.add(
              TemporalMotionJerk(
                boneId: boneId,
                fromFrame: previousAcceleration.fromFrame,
                throughFrameA: previousAcceleration.throughFrame,
                throughFrameB: acceleration.throughFrame,
                toFrame: acceleration.toFrame,
                fromPhase: previousAcceleration.fromPhase,
                throughPhaseA: previousAcceleration.throughPhase,
                throughPhaseB: acceleration.throughPhase,
                toPhase: acceleration.toPhase,
                dx: jx,
                dy: jy,
                magnitude: math.sqrt(jx * jx + jy * jy),
              ),
            );
          }
          previousAccelerationByBone[boneId] = acceleration;
        }
        previousByBone[boneId] = segment;

        // World-space angle (atan2(b, a)), not local JointPose.rotation: a
        // forearm's visual rotation compounds parent rotation too, and world
        // angle is what a viewer actually perceives as a "snap".
        final rawAngle = math.atan2(currentTransform.b, currentTransform.a);
        final previousUnwrapped = unwrappedAngleByBone[boneId]!;
        final wrappedDelta = _wrapToPi(rawAngle - _wrapToPi(previousUnwrapped));
        final unwrappedAngle = previousUnwrapped + wrappedDelta;
        unwrappedAngleByBone[boneId] = unwrappedAngle;

        final angularSegment = TemporalMotionAngularSegment(
          boneId: boneId,
          fromFrame: frame - 1,
          toFrame: frame,
          fromPhase: (frame - 1) / samples,
          toPhase: frame / samples,
          dAngle: wrappedDelta,
          magnitude: wrappedDelta.abs(),
        );
        angularSegments.add(angularSegment);

        final previousAngularSegment = previousAngularByBone[boneId];
        if (previousAngularSegment != null) {
          final aAngle = angularSegment.dAngle - previousAngularSegment.dAngle;
          final angularAcceleration = TemporalMotionAngularAcceleration(
            boneId: boneId,
            fromFrame: previousAngularSegment.fromFrame,
            throughFrame: previousAngularSegment.toFrame,
            toFrame: angularSegment.toFrame,
            fromPhase: previousAngularSegment.fromPhase,
            throughPhase: previousAngularSegment.toPhase,
            toPhase: angularSegment.toPhase,
            dAngle: aAngle,
            magnitude: aAngle.abs(),
          );
          angularAccelerations.add(angularAcceleration);

          final previousAngularAcceleration =
              previousAngularAccelerationByBone[boneId];
          if (previousAngularAcceleration != null) {
            final jAngle =
                angularAcceleration.dAngle - previousAngularAcceleration.dAngle;
            angularJerks.add(
              TemporalMotionAngularJerk(
                boneId: boneId,
                fromFrame: previousAngularAcceleration.fromFrame,
                throughFrameA: previousAngularAcceleration.throughFrame,
                throughFrameB: angularAcceleration.throughFrame,
                toFrame: angularAcceleration.toFrame,
                fromPhase: previousAngularAcceleration.fromPhase,
                throughPhaseA: previousAngularAcceleration.throughPhase,
                throughPhaseB: angularAcceleration.throughPhase,
                toPhase: angularAcceleration.toPhase,
                dAngle: jAngle,
                magnitude: jAngle.abs(),
              ),
            );
          }
          previousAngularAccelerationByBone[boneId] = angularAcceleration;
        }
        previousAngularByBone[boneId] = angularSegment;
      }
      previous = current;
    }

    return TemporalMotionReport(
      clipName: clip.name,
      samples: samples,
      segments: segments,
      accelerations: accelerations,
      jerks: jerks,
      angularSegments: angularSegments,
      angularAccelerations: angularAccelerations,
      angularJerks: angularJerks,
    );
  }

  /// Wraps [angle] into `(-pi, pi]`.
  static double _wrapToPi(double angle) {
    var wrapped = angle % (2 * math.pi);
    if (wrapped > math.pi) wrapped -= 2 * math.pi;
    if (wrapped <= -math.pi) wrapped += 2 * math.pi;
    return wrapped;
  }
}

/// The result of [TemporalMotionAnalyzer.analyze]: two parallel
/// displacement→acceleration→jerk chains over the sampled clip — one in
/// world-space position (`segments`/`accelerations`/`jerks`), one in
/// world-space bone angle (`angularSegments`/`angularAccelerations`/
/// `angularJerks`, unwrapped across the atan2 branch cut). Neither chain
/// carries a built-in pass/fail threshold; callers (tests, review tooling)
/// read `worst*`/`top*` and decide what "too fast" or "too jumpy" means for
/// the move being judged.
class TemporalMotionReport {
  const TemporalMotionReport({
    required this.clipName,
    required this.samples,
    required this.segments,
    required this.accelerations,
    required this.jerks,
    required this.angularSegments,
    required this.angularAccelerations,
    required this.angularJerks,
  });

  final String clipName;
  final int samples;
  final List<TemporalMotionSegment> segments;
  final List<TemporalMotionAcceleration> accelerations;
  final List<TemporalMotionJerk> jerks;
  final List<TemporalMotionAngularSegment> angularSegments;
  final List<TemporalMotionAngularAcceleration> angularAccelerations;
  final List<TemporalMotionAngularJerk> angularJerks;

  TemporalMotionSegment get worstDisplacement => _maxBy(
    segments,
    (segment) => segment.distance,
    'segments',
  );

  TemporalMotionAcceleration get worstAcceleration => _maxBy(
    accelerations,
    (acceleration) => acceleration.magnitude,
    'accelerations',
  );

  TemporalMotionJerk get worstJerk =>
      _maxBy(jerks, (jerk) => jerk.magnitude, 'jerks');

  TemporalMotionAngularSegment get worstAngularVelocity => _maxBy(
    angularSegments,
    (segment) => segment.magnitude,
    'angularSegments',
  );

  TemporalMotionAngularAcceleration get worstAngularAcceleration => _maxBy(
    angularAccelerations,
    (acceleration) => acceleration.magnitude,
    'angularAccelerations',
  );

  TemporalMotionAngularJerk get worstAngularJerk =>
      _maxBy(angularJerks, (jerk) => jerk.magnitude, 'angularJerks');

  List<TemporalMotionSegment> topDisplacements(int count) =>
      _topBy(segments, count, (segment) => segment.distance);

  List<TemporalMotionAcceleration> topAccelerations(int count) =>
      _topBy(accelerations, count, (acceleration) => acceleration.magnitude);

  List<TemporalMotionJerk> topJerks(int count) =>
      _topBy(jerks, count, (jerk) => jerk.magnitude);

  List<TemporalMotionAngularSegment> topAngularVelocities(int count) =>
      _topBy(angularSegments, count, (segment) => segment.magnitude);

  List<TemporalMotionAngularAcceleration> topAngularAccelerations(
    int count,
  ) => _topBy(
    angularAccelerations,
    count,
    (acceleration) => acceleration.magnitude,
  );

  List<TemporalMotionAngularJerk> topAngularJerks(int count) =>
      _topBy(angularJerks, count, (jerk) => jerk.magnitude);

  /// Finds robotic "hold, hold, snap" transitions.
  ///
  /// This is intentionally a query rather than a built-in violation: planted
  /// feet and choreographed freezes can be valid, while a hand/torso that stays
  /// nearly still for several samples and then jumps reads like a static
  /// keyframe pop. Callers choose the watched bones and thresholds for the move.
  List<TemporalMotionStutter> stutterTransitions({
    double holdDistance = 0.25,
    double releaseDistance = 8,
    int minHoldSegments = 2,
  }) {
    if (holdDistance < 0) {
      throw ArgumentError.value(
        holdDistance,
        'holdDistance',
        'must be non-negative',
      );
    }
    if (releaseDistance < 0) {
      throw ArgumentError.value(
        releaseDistance,
        'releaseDistance',
        'must be non-negative',
      );
    }
    if (minHoldSegments <= 0) {
      throw ArgumentError.value(
        minHoldSegments,
        'minHoldSegments',
        'must be positive',
      );
    }

    final byBone = <String, List<TemporalMotionSegment>>{};
    for (final segment in segments) {
      byBone.putIfAbsent(segment.boneId, () => []).add(segment);
    }

    final result = <TemporalMotionStutter>[];
    for (final entry in byBone.entries) {
      final boneSegments = [...entry.value]
        ..sort((a, b) => a.fromFrame.compareTo(b.fromFrame));
      var i = 0;
      while (i < boneSegments.length) {
        if (boneSegments[i].distance > holdDistance) {
          i++;
          continue;
        }

        final start = i;
        while (i < boneSegments.length &&
            boneSegments[i].distance <= holdDistance) {
          i++;
        }
        final endExclusive = i;
        final runLength = endExclusive - start;
        if (runLength < minHoldSegments) continue;

        final before = start > 0 ? boneSegments[start - 1] : null;
        final after = endExclusive < boneSegments.length
            ? boneSegments[endExclusive]
            : null;
        final entryDistance = before?.distance ?? 0;
        final exitDistance = after?.distance ?? 0;
        final adjacentTravel = math.max(entryDistance, exitDistance);
        if (adjacentTravel < releaseDistance) continue;

        result.add(
          TemporalMotionStutter(
            boneId: entry.key,
            holdFromFrame: boneSegments[start].fromFrame,
            holdToFrame: boneSegments[endExclusive - 1].toFrame,
            holdFromPhase: boneSegments[start].fromPhase,
            holdToPhase: boneSegments[endExclusive - 1].toPhase,
            holdSegments: runLength,
            entryDistance: entryDistance,
            exitDistance: exitDistance,
            adjacentTravel: adjacentTravel,
          ),
        );
      }
    }

    result.sort((a, b) => b.adjacentTravel.compareTo(a.adjacentTravel));
    return result;
  }

  /// Finds abrupt speed pulses that are not necessarily preceded by a full hold.
  ///
  /// A limb can avoid the "hold, hold, snap" pattern and still read robotic if
  /// adjacent segment speeds jump sharply. This query catches that second case:
  /// consecutive world-space segments for the same bone whose vector change,
  /// speed delta, and speed ratio all exceed caller-selected thresholds.
  List<TemporalMotionVelocitySpike> velocitySpikes({
    double minAcceleration = 8,
    double minSpeedDelta = 4,
    double minSpeedRatio = 1.75,
    double minSegmentDistance = 1,
  }) {
    if (minAcceleration < 0) {
      throw ArgumentError.value(
        minAcceleration,
        'minAcceleration',
        'must be non-negative',
      );
    }
    if (minSpeedDelta < 0) {
      throw ArgumentError.value(
        minSpeedDelta,
        'minSpeedDelta',
        'must be non-negative',
      );
    }
    if (minSpeedRatio < 1) {
      throw ArgumentError.value(
        minSpeedRatio,
        'minSpeedRatio',
        'must be at least 1',
      );
    }
    if (minSegmentDistance < 0) {
      throw ArgumentError.value(
        minSegmentDistance,
        'minSegmentDistance',
        'must be non-negative',
      );
    }

    final byBone = <String, List<TemporalMotionSegment>>{};
    for (final segment in segments) {
      byBone.putIfAbsent(segment.boneId, () => []).add(segment);
    }

    final result = <TemporalMotionVelocitySpike>[];
    for (final entry in byBone.entries) {
      final boneSegments = [...entry.value]
        ..sort((a, b) => a.fromFrame.compareTo(b.fromFrame));
      for (var i = 1; i < boneSegments.length; i++) {
        final before = boneSegments[i - 1];
        final after = boneSegments[i];
        final faster = math.max(before.distance, after.distance);
        if (faster < minSegmentDistance) continue;

        final speedDelta = (after.distance - before.distance).abs();
        final slower = math.min(before.distance, after.distance);
        final speedRatio = slower <= 1e-9 ? double.infinity : faster / slower;
        final ax = after.dx - before.dx;
        final ay = after.dy - before.dy;
        final acceleration = math.sqrt(ax * ax + ay * ay);
        if (acceleration < minAcceleration) continue;
        if (speedDelta < minSpeedDelta) continue;
        if (speedRatio < minSpeedRatio) continue;

        result.add(
          TemporalMotionVelocitySpike(
            boneId: entry.key,
            fromFrame: before.fromFrame,
            throughFrame: before.toFrame,
            toFrame: after.toFrame,
            fromPhase: before.fromPhase,
            throughPhase: before.toPhase,
            toPhase: after.toPhase,
            beforeDistance: before.distance,
            afterDistance: after.distance,
            speedDelta: speedDelta,
            speedRatio: speedRatio,
            accelerationMagnitude: acceleration,
          ),
        );
      }
    }

    result.sort(
      (a, b) => b.accelerationMagnitude.compareTo(a.accelerationMagnitude),
    );
    return result;
  }

  /// Finds sharp path corners where a bone abruptly changes travel direction.
  ///
  /// Velocity spikes catch speed discontinuities; this catches a different
  /// robotic look: two adjacent segments with enough travel, a large turn angle,
  /// and an arced path much longer than the direct chord. Those hard elbows in a
  /// hand path read like a keyed puppet even when the speed is not extreme.
  List<TemporalMotionPathCorner> pathCorners({
    double minTurnDegrees = 95,
    double minAcceleration = 8,
    double minArcRatio = 1.25,
    double minSegmentDistance = 1,
  }) {
    if (minTurnDegrees < 0 || minTurnDegrees > 180) {
      throw ArgumentError.value(
        minTurnDegrees,
        'minTurnDegrees',
        'must be in 0..180',
      );
    }
    if (minAcceleration < 0) {
      throw ArgumentError.value(
        minAcceleration,
        'minAcceleration',
        'must be non-negative',
      );
    }
    if (minArcRatio < 1) {
      throw ArgumentError.value(
        minArcRatio,
        'minArcRatio',
        'must be at least 1',
      );
    }
    if (minSegmentDistance < 0) {
      throw ArgumentError.value(
        minSegmentDistance,
        'minSegmentDistance',
        'must be non-negative',
      );
    }

    final byBone = <String, List<TemporalMotionSegment>>{};
    for (final segment in segments) {
      byBone.putIfAbsent(segment.boneId, () => []).add(segment);
    }

    final result = <TemporalMotionPathCorner>[];
    for (final entry in byBone.entries) {
      final boneSegments = [...entry.value]
        ..sort((a, b) => a.fromFrame.compareTo(b.fromFrame));
      for (var i = 1; i < boneSegments.length; i++) {
        final before = boneSegments[i - 1];
        final after = boneSegments[i];
        if (before.distance < minSegmentDistance ||
            after.distance < minSegmentDistance) {
          continue;
        }

        final dot = before.dx * after.dx + before.dy * after.dy;
        final denom = before.distance * after.distance;
        if (denom <= 1e-9) continue;
        final cosTurn = (dot / denom).clamp(-1.0, 1.0);
        final turnRadians = math.acos(cosTurn);
        final turnDegrees = turnRadians * 180 / math.pi;
        if (turnDegrees < minTurnDegrees) continue;

        final ax = after.dx - before.dx;
        final ay = after.dy - before.dy;
        final acceleration = math.sqrt(ax * ax + ay * ay);
        if (acceleration < minAcceleration) continue;

        final chordDx = before.dx + after.dx;
        final chordDy = before.dy + after.dy;
        final chordDistance = math.sqrt(chordDx * chordDx + chordDy * chordDy);
        final arcDistance = before.distance + after.distance;
        final arcRatio = chordDistance <= 1e-9
            ? double.infinity
            : arcDistance / chordDistance;
        if (arcRatio < minArcRatio) continue;

        result.add(
          TemporalMotionPathCorner(
            boneId: entry.key,
            fromFrame: before.fromFrame,
            throughFrame: before.toFrame,
            toFrame: after.toFrame,
            fromPhase: before.fromPhase,
            throughPhase: before.toPhase,
            toPhase: after.toPhase,
            beforeDistance: before.distance,
            afterDistance: after.distance,
            chordDistance: chordDistance,
            arcDistance: arcDistance,
            arcRatio: arcRatio,
            turnDegrees: turnDegrees,
            accelerationMagnitude: acceleration,
          ),
        );
      }
    }

    result.sort((a, b) {
      final byAcceleration = b.accelerationMagnitude.compareTo(
        a.accelerationMagnitude,
      );
      if (byAcceleration != 0) return byAcceleration;
      return b.turnDegrees.compareTo(a.turnDegrees);
    });
    return result;
  }

  /// Compares the final sampled segment of a looping clip with the first.
  ///
  /// The frame-by-frame acceleration list only compares adjacent samples inside
  /// `0..duration`. A dance loop can still have a visible tick if the last
  /// segment's velocity does not line up with the first segment's velocity at
  /// the phase-0 seam. This query makes that seam explicit for catalogue clips.
  ///
  /// [maxInLoopJumpRatio], when set, makes the check **continuity-aware**: the
  /// raw magnitude of the seam's velocity change cannot, on its own, tell a true
  /// discontinuity (a tick) from a fast-but-C¹-continuous accent that merely
  /// *lands on* the loop point (a punchy downbeat hit — the whole point of the
  /// inertialized spring). So a seam is only flagged when its velocity change
  /// also exceeds the worst velocity change the SAME bone already makes between
  /// adjacent segments elsewhere in the loop, times this ratio. A genuine tick
  /// is anomalous versus the rest of the motion; a downbeat accent no sharper
  /// than the loop's other accents is not. When null, the legacy pure-magnitude
  /// behaviour is kept.
  List<TemporalMotionLoopSeamJump> loopSeamVelocityJumps({
    double minVelocityJump = 6,
    double minSegmentDistance = 1,
    double? maxInLoopJumpRatio,
  }) {
    if (minVelocityJump < 0) {
      throw ArgumentError.value(
        minVelocityJump,
        'minVelocityJump',
        'must be non-negative',
      );
    }
    if (minSegmentDistance < 0) {
      throw ArgumentError.value(
        minSegmentDistance,
        'minSegmentDistance',
        'must be non-negative',
      );
    }
    if (maxInLoopJumpRatio != null && maxInLoopJumpRatio < 0) {
      throw ArgumentError.value(
        maxInLoopJumpRatio,
        'maxInLoopJumpRatio',
        'must be non-negative',
      );
    }

    final byBone = <String, List<TemporalMotionSegment>>{};
    for (final segment in segments) {
      byBone.putIfAbsent(segment.boneId, () => []).add(segment);
    }

    final result = <TemporalMotionLoopSeamJump>[];
    for (final entry in byBone.entries) {
      final boneSegments = [...entry.value]
        ..sort((a, b) => a.fromFrame.compareTo(b.fromFrame));
      if (boneSegments.length < 2) continue;
      final first = boneSegments.first;
      final last = boneSegments.last;
      final faster = math.max(first.distance, last.distance);
      if (faster < minSegmentDistance) continue;

      final dx = first.dx - last.dx;
      final dy = first.dy - last.dy;
      final velocityJump = math.sqrt(dx * dx + dy * dy);
      if (velocityJump < minVelocityJump) continue;

      // Continuity-aware gate: allow a seam velocity change up to the worst
      // adjacent-segment velocity change the motion already makes in-loop
      // (scaled) — that is a continuous accent landing on the seam, not a tick.
      if (maxInLoopJumpRatio != null) {
        var inLoopMaxJump = 0.0;
        for (var i = 0; i < boneSegments.length - 1; i++) {
          final a = boneSegments[i];
          final b = boneSegments[i + 1];
          final jdx = b.dx - a.dx;
          final jdy = b.dy - a.dy;
          final jump = math.sqrt(jdx * jdx + jdy * jdy);
          if (jump > inLoopMaxJump) inLoopMaxJump = jump;
        }
        if (velocityJump <= inLoopMaxJump * maxInLoopJumpRatio) continue;
      }

      final speedDelta = (first.distance - last.distance).abs();
      final slower = math.min(first.distance, last.distance);
      final speedRatio = slower <= 1e-9 ? double.infinity : faster / slower;
      result.add(
        TemporalMotionLoopSeamJump(
          boneId: entry.key,
          lastFromFrame: last.fromFrame,
          lastToFrame: last.toFrame,
          firstFromFrame: first.fromFrame,
          firstToFrame: first.toFrame,
          lastFromPhase: last.fromPhase,
          lastToPhase: last.toPhase,
          firstFromPhase: first.fromPhase,
          firstToPhase: first.toPhase,
          lastDistance: last.distance,
          firstDistance: first.distance,
          speedDelta: speedDelta,
          speedRatio: speedRatio,
          velocityJump: velocityJump,
        ),
      );
    }

    result.sort((a, b) => b.velocityJump.compareTo(a.velocityJump));
    return result;
  }

  static T _maxBy<T>(
    List<T> values,
    double Function(T value) score,
    String label,
  ) {
    if (values.isEmpty) {
      throw StateError('No temporal motion $label were recorded.');
    }
    var best = values.first;
    var bestScore = score(best);
    for (final value in values.skip(1)) {
      final valueScore = score(value);
      if (valueScore > bestScore) {
        best = value;
        bestScore = valueScore;
      }
    }
    return best;
  }

  static List<T> _topBy<T>(
    List<T> values,
    int count,
    double Function(T value) score,
  ) {
    if (count <= 0) return const [];
    final sorted = [...values]..sort((a, b) => score(b).compareTo(score(a)));
    return sorted.take(count).toList(growable: false);
  }
}

class TemporalMotionSegment {
  const TemporalMotionSegment({
    required this.boneId,
    required this.fromFrame,
    required this.toFrame,
    required this.fromPhase,
    required this.toPhase,
    required this.dx,
    required this.dy,
    required this.distance,
  });

  final String boneId;
  final int fromFrame;
  final int toFrame;
  final double fromPhase;
  final double toPhase;
  final double dx;
  final double dy;
  final double distance;
}

class TemporalMotionAcceleration {
  const TemporalMotionAcceleration({
    required this.boneId,
    required this.fromFrame,
    required this.throughFrame,
    required this.toFrame,
    required this.fromPhase,
    required this.throughPhase,
    required this.toPhase,
    required this.dx,
    required this.dy,
    required this.magnitude,
  });

  final String boneId;
  final int fromFrame;
  final int throughFrame;
  final int toFrame;
  final double fromPhase;
  final double throughPhase;
  final double toPhase;
  final double dx;
  final double dy;
  final double magnitude;
}

class TemporalMotionJerk {
  const TemporalMotionJerk({
    required this.boneId,
    required this.fromFrame,
    required this.throughFrameA,
    required this.throughFrameB,
    required this.toFrame,
    required this.fromPhase,
    required this.throughPhaseA,
    required this.throughPhaseB,
    required this.toPhase,
    required this.dx,
    required this.dy,
    required this.magnitude,
  });

  final String boneId;
  final int fromFrame;
  final int throughFrameA;
  final int throughFrameB;
  final int toFrame;
  final double fromPhase;
  final double throughPhaseA;
  final double throughPhaseB;
  final double toPhase;
  final double dx;
  final double dy;
  final double magnitude;
}

class TemporalMotionStutter {
  const TemporalMotionStutter({
    required this.boneId,
    required this.holdFromFrame,
    required this.holdToFrame,
    required this.holdFromPhase,
    required this.holdToPhase,
    required this.holdSegments,
    required this.entryDistance,
    required this.exitDistance,
    required this.adjacentTravel,
  });

  final String boneId;
  final int holdFromFrame;
  final int holdToFrame;
  final double holdFromPhase;
  final double holdToPhase;
  final int holdSegments;
  final double entryDistance;
  final double exitDistance;
  final double adjacentTravel;
}

class TemporalMotionVelocitySpike {
  const TemporalMotionVelocitySpike({
    required this.boneId,
    required this.fromFrame,
    required this.throughFrame,
    required this.toFrame,
    required this.fromPhase,
    required this.throughPhase,
    required this.toPhase,
    required this.beforeDistance,
    required this.afterDistance,
    required this.speedDelta,
    required this.speedRatio,
    required this.accelerationMagnitude,
  });

  final String boneId;
  final int fromFrame;
  final int throughFrame;
  final int toFrame;
  final double fromPhase;
  final double throughPhase;
  final double toPhase;
  final double beforeDistance;
  final double afterDistance;
  final double speedDelta;
  final double speedRatio;
  final double accelerationMagnitude;
}

class TemporalMotionPathCorner {
  const TemporalMotionPathCorner({
    required this.boneId,
    required this.fromFrame,
    required this.throughFrame,
    required this.toFrame,
    required this.fromPhase,
    required this.throughPhase,
    required this.toPhase,
    required this.beforeDistance,
    required this.afterDistance,
    required this.chordDistance,
    required this.arcDistance,
    required this.arcRatio,
    required this.turnDegrees,
    required this.accelerationMagnitude,
  });

  final String boneId;
  final int fromFrame;
  final int throughFrame;
  final int toFrame;
  final double fromPhase;
  final double throughPhase;
  final double toPhase;
  final double beforeDistance;
  final double afterDistance;
  final double chordDistance;
  final double arcDistance;
  final double arcRatio;
  final double turnDegrees;
  final double accelerationMagnitude;
}

class TemporalMotionLoopSeamJump {
  const TemporalMotionLoopSeamJump({
    required this.boneId,
    required this.lastFromFrame,
    required this.lastToFrame,
    required this.firstFromFrame,
    required this.firstToFrame,
    required this.lastFromPhase,
    required this.lastToPhase,
    required this.firstFromPhase,
    required this.firstToPhase,
    required this.lastDistance,
    required this.firstDistance,
    required this.speedDelta,
    required this.speedRatio,
    required this.velocityJump,
  });

  final String boneId;
  final int lastFromFrame;
  final int lastToFrame;
  final int firstFromFrame;
  final int firstToFrame;
  final double lastFromPhase;
  final double lastToPhase;
  final double firstFromPhase;
  final double firstToPhase;
  final double lastDistance;
  final double firstDistance;
  final double speedDelta;
  final double speedRatio;
  final double velocityJump;
}

class TemporalMotionAngularSegment {
  const TemporalMotionAngularSegment({
    required this.boneId,
    required this.fromFrame,
    required this.toFrame,
    required this.fromPhase,
    required this.toPhase,
    required this.dAngle,
    required this.magnitude,
  });

  final String boneId;
  final int fromFrame;
  final int toFrame;
  final double fromPhase;
  final double toPhase;

  /// Unwrapped world-space angle delta, in radians.
  final double dAngle;
  final double magnitude;
}

class TemporalMotionAngularAcceleration {
  const TemporalMotionAngularAcceleration({
    required this.boneId,
    required this.fromFrame,
    required this.throughFrame,
    required this.toFrame,
    required this.fromPhase,
    required this.throughPhase,
    required this.toPhase,
    required this.dAngle,
    required this.magnitude,
  });

  final String boneId;
  final int fromFrame;
  final int throughFrame;
  final int toFrame;
  final double fromPhase;
  final double throughPhase;
  final double toPhase;
  final double dAngle;
  final double magnitude;
}

class TemporalMotionAngularJerk {
  const TemporalMotionAngularJerk({
    required this.boneId,
    required this.fromFrame,
    required this.throughFrameA,
    required this.throughFrameB,
    required this.toFrame,
    required this.fromPhase,
    required this.throughPhaseA,
    required this.throughPhaseB,
    required this.toPhase,
    required this.dAngle,
    required this.magnitude,
  });

  final String boneId;
  final int fromFrame;
  final int throughFrameA;
  final int throughFrameB;
  final int toFrame;
  final double fromPhase;
  final double throughPhaseA;
  final double throughPhaseB;
  final double toPhase;
  final double dAngle;
  final double magnitude;
}
