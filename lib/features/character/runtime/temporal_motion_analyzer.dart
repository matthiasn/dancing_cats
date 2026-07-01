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

    var previous = scene.frameAt(
      clip: clip,
      timeSeconds: 0,
      expression: expression,
      base: base,
    );
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
      }
      previous = current;
    }

    return TemporalMotionReport(
      clipName: clip.name,
      samples: samples,
      segments: segments,
      accelerations: accelerations,
      jerks: jerks,
    );
  }
}

class TemporalMotionReport {
  const TemporalMotionReport({
    required this.clipName,
    required this.samples,
    required this.segments,
    required this.accelerations,
    required this.jerks,
  });

  final String clipName;
  final int samples;
  final List<TemporalMotionSegment> segments;
  final List<TemporalMotionAcceleration> accelerations;
  final List<TemporalMotionJerk> jerks;

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

  List<TemporalMotionSegment> topDisplacements(int count) =>
      _topBy(segments, count, (segment) => segment.distance);

  List<TemporalMotionAcceleration> topAccelerations(int count) =>
      _topBy(accelerations, count, (acceleration) => acceleration.magnitude);

  List<TemporalMotionJerk> topJerks(int count) =>
      _topBy(jerks, count, (jerk) => jerk.magnitude);

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
  List<TemporalMotionLoopSeamJump> loopSeamVelocityJumps({
    double minVelocityJump = 6,
    double minSegmentDistance = 1,
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
