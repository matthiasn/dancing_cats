import 'dart:math' as math;

import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/pose.dart';
import 'package:dancing_cats/features/character/model/rig_spec.dart';
import 'package:dancing_cats/features/character/runtime/character_scene.dart';
import 'package:dancing_cats/features/character/runtime/skinned_mesh_solver.dart';

/// Test-time anatomy and contact validator for resolved character motion.
///
/// This deliberately measures the same frame data the renderer sees. It does not
/// try to be a physics engine; it turns recurring review-panel complaints into
/// numbers that can be ratcheted down as the choreography improves.
class MotionConstraintValidator {
  const MotionConstraintValidator(this.scene);

  final CharacterScene scene;

  MotionConstraintReport analyze({
    required Clip clip,
    MotionConstraintProfile profile = const MotionConstraintProfile(),
    int contactSamplesPerSpan = 7,
    int ikSamples = 32,
  }) {
    if (contactSamplesPerSpan <= 0) {
      throw ArgumentError.value(
        contactSamplesPerSpan,
        'contactSamplesPerSpan',
        'must be positive',
      );
    }
    if (ikSamples <= 0) {
      throw ArgumentError.value(ikSamples, 'ikSamples', 'must be positive');
    }

    final contacts = _sampleStableContacts(
      clip,
      profile,
      contactSamplesPerSpan,
    );
    final supports = _sampleSupportBalance(
      clip,
      profile,
      contactSamplesPerSpan,
    );
    final reaches = _sampleIkReach(clip, profile, ikSamples);
    final targetResiduals = _sampleIkTargetResiduals(clip, profile, ikSamples);
    final limbBends = _sampleLimbBends(clip, profile, ikSamples);
    final limbLanes = _sampleLimbLanes(clip, profile, ikSamples);
    final shoulderResponses = _sampleRaisedShoulderResponses(
      clip,
      profile,
      ikSamples,
    );
    final shoulderMeshBridges = _sampleRaisedShoulderMeshBridges(
      clip,
      profile,
      ikSamples,
    );
    final jointEnvelopes = _sampleJointEnvelopes(clip, profile, ikSamples);

    return MotionConstraintReport(
      clipName: clip.name,
      profile: profile,
      contactDrifts: contacts,
      supportBalances: supports,
      ikReaches: reaches,
      ikTargetResiduals: targetResiduals,
      limbBends: limbBends,
      limbLanes: limbLanes,
      shoulderResponses: shoulderResponses,
      shoulderMeshBridges: shoulderMeshBridges,
      jointEnvelopes: jointEnvelopes,
    );
  }

  List<MotionJointEnvelope> _sampleJointEnvelopes(
    Clip clip,
    MotionConstraintProfile profile,
    int samples,
  ) {
    if (profile.jointEnvelopeRules.isEmpty) return const [];
    final checks = <MotionJointEnvelope>[];
    for (var i = 0; i < samples; i++) {
      final phase = i / samples;
      final pose = scene.poseAt(
        clip: clip,
        timeSeconds: _phaseTime(clip, phase),
        includeAutonomic: false,
      );
      for (final bone in scene.rig.bones) {
        final rule = _jointEnvelopeRuleFor(bone.id, profile);
        if (rule == null) continue;
        final joint = pose.jointOf(bone.id);
        checks.add(
          MotionJointEnvelope(
            clipName: clip.name,
            boneId: bone.id,
            phase: phase,
            rotation: joint.rotation,
            scaleX: joint.scaleX,
            scaleY: joint.scaleY,
            maxAbsRotation: rule.maxAbsRotation,
            maxScaleDelta: rule.maxScaleDelta,
          ),
        );
      }
    }
    return checks;
  }

  List<MotionContactDrift> _sampleStableContacts(
    Clip clip,
    MotionConstraintProfile profile,
    int samplesPerSpan,
  ) {
    if (clip.contactSpans.isEmpty) return const [];
    final checks = <MotionContactDrift>[];
    for (final span in clip.contactSpans) {
      final spanLength = span.end - span.start;
      if (spanLength <= 0) continue;

      final stableStart = span.start + spanLength * profile.contactEdgeFraction;
      final stableEnd = span.end - spanLength * profile.contactEdgeFraction;
      if (stableEnd < stableStart) continue;

      final anchorPhase = span.start + spanLength * 0.5;
      final anchorFrame = scene.frameAt(
        clip: clip,
        timeSeconds: _phaseTime(clip, anchorPhase),
      );
      final anchor = _contactPoint(scene.rig, anchorFrame, span.bone);
      if (anchor == null) continue;

      for (var i = 0; i < samplesPerSpan; i++) {
        final t = samplesPerSpan == 1 ? 0.5 : i / (samplesPerSpan - 1);
        final phase = stableStart + (stableEnd - stableStart) * t;
        final frame = scene.frameAt(
          clip: clip,
          timeSeconds: _phaseTime(clip, phase),
        );
        final support = _contactPoint(scene.rig, frame, span.bone);
        if (support == null) continue;
        final dx = support.x - anchor.x;
        final dy = support.y - anchor.y;
        checks.add(
          MotionContactDrift(
            clipName: clip.name,
            boneId: span.bone,
            phase: _unitPhase(phase),
            anchorPhase: _unitPhase(anchorPhase),
            dx: dx,
            dy: dy,
            distance: _distance(dx, dy),
          ),
        );
      }
    }
    return checks;
  }

  List<MotionLimbLane> _sampleLimbLanes(
    Clip clip,
    MotionConstraintProfile profile,
    int samples,
  ) {
    if (clip.limbTargets.isEmpty) return const [];
    final checks = <MotionLimbLane>[];
    for (var i = 0; i < samples; i++) {
      final phase = i / samples;
      final timeSeconds = _phaseTime(clip, phase);
      final frame = scene.frameAt(clip: clip, timeSeconds: timeSeconds);
      for (final target in clip.limbTargets) {
        final sample = target.channel.sample(phase);
        if (sample.weight < profile.minIkWeight) continue;
        final side = _sameSideSign(target.endBoneId, sample.x, profile);
        if (side == 0) continue;
        final upperWorld = frame.world[target.upperBoneId];
        final lowerWorld = frame.world[target.lowerBoneId];
        final endWorld = frame.world[target.endBoneId];
        if (upperWorld == null || lowerWorld == null || endWorld == null) {
          continue;
        }

        final shoulderX = upperWorld.origin.x;
        final elbowX = lowerWorld.origin.x;
        final endX = endWorld.origin.x;
        final elbowReversal = side < 0
            ? _positive(elbowX - shoulderX)
            : _positive(shoulderX - elbowX);
        final endReversal = side < 0
            ? _positive(endX - elbowX)
            : _positive(elbowX - endX);
        checks.add(
          MotionLimbLane(
            clipName: clip.name,
            upperBoneId: target.upperBoneId,
            lowerBoneId: target.lowerBoneId,
            endBoneId: target.endBoneId,
            phase: phase,
            side: side,
            targetX: sample.x,
            shoulderX: shoulderX,
            elbowX: elbowX,
            endX: endX,
            elbowReversal: elbowReversal,
            endReversal: endReversal,
            reversalDistance: math.max(elbowReversal, endReversal),
            horizontalFold: (elbowX - shoulderX) * (endX - elbowX),
          ),
        );
      }
    }
    return checks;
  }

  List<MotionLimbBend> _sampleLimbBends(
    Clip clip,
    MotionConstraintProfile profile,
    int samples,
  ) {
    if (clip.limbTargets.isEmpty) return const [];
    final checks = <MotionLimbBend>[];
    for (var i = 0; i < samples; i++) {
      final phase = i / samples;
      final timeSeconds = _phaseTime(clip, phase);
      final frame = scene.frameAt(clip: clip, timeSeconds: timeSeconds);
      for (final target in clip.limbTargets) {
        final sample = target.channel.sample(phase);
        if (sample.weight < profile.minIkWeight) continue;
        final upperWorld = frame.world[target.upperBoneId];
        final lowerWorld = frame.world[target.lowerBoneId];
        final endWorld = frame.world[target.endBoneId];
        if (upperWorld == null || lowerWorld == null || endWorld == null) {
          continue;
        }

        final upper = upperWorld.origin;
        final middle = lowerWorld.origin;
        final end = endWorld.origin;
        final upperDx = middle.x - upper.x;
        final upperDy = middle.y - upper.y;
        final lowerDx = end.x - middle.x;
        final lowerDy = end.y - middle.y;
        final upperLength = _distance(upperDx, upperDy);
        final lowerLength = _distance(lowerDx, lowerDy);
        if (upperLength <= 1e-6 || lowerLength <= 1e-6) continue;

        final elbowToUpperX = upper.x - middle.x;
        final elbowToUpperY = upper.y - middle.y;
        final elbowToEndX = end.x - middle.x;
        final elbowToEndY = end.y - middle.y;
        final dot = elbowToUpperX * elbowToEndX + elbowToUpperY * elbowToEndY;
        final denom = upperLength * lowerLength;
        final bendRadians = math.acos((dot / denom).clamp(-1.0, 1.0));
        final bendDegrees = bendRadians * 180 / math.pi;
        final signedArea = upperDx * lowerDy - upperDy * lowerDx;
        final actualBendDirection =
            signedArea.abs() < profile.minBendDirectionArea
            ? 0
            : signedArea < 0
            ? 1
            : -1;
        checks.add(
          MotionLimbBend(
            clipName: clip.name,
            upperBoneId: target.upperBoneId,
            lowerBoneId: target.lowerBoneId,
            endBoneId: target.endBoneId,
            phase: phase,
            weight: sample.weight,
            expectedBendDirection: target.bendDirection,
            actualBendDirection: actualBendDirection,
            signedArea: signedArea,
            bendDegrees: bendDegrees,
            straightnessDegrees: 180 - bendDegrees,
          ),
        );
      }
    }
    return checks;
  }

  List<MotionSupportBalance> _sampleSupportBalance(
    Clip clip,
    MotionConstraintProfile profile,
    int samplesPerSpan,
  ) {
    if (clip.contactSpans.isEmpty) return const [];
    final rootId = scene.rig.bones.firstWhere((bone) => bone.parent == null).id;
    final checks = <MotionSupportBalance>[];
    for (final span in clip.contactSpans) {
      final spanLength = span.end - span.start;
      if (spanLength <= 0) continue;

      final stableStart = span.start + spanLength * profile.contactEdgeFraction;
      final stableEnd = span.end - spanLength * profile.contactEdgeFraction;
      if (stableEnd < stableStart) continue;

      for (var i = 0; i < samplesPerSpan; i++) {
        final t = samplesPerSpan == 1 ? 0.5 : i / (samplesPerSpan - 1);
        final phase = stableStart + (stableEnd - stableStart) * t;
        final frame = scene.frameAt(
          clip: clip,
          timeSeconds: _phaseTime(clip, phase),
        );
        final hip = frame.world[rootId]?.origin;
        final support = _contactPoint(scene.rig, frame, span.bone);
        if (hip == null || support == null) continue;
        checks.add(
          MotionSupportBalance(
            clipName: clip.name,
            supportBoneId: span.bone,
            rootBoneId: rootId,
            phase: _unitPhase(phase),
            offsetX: hip.x - support.x,
            offsetY: hip.y - support.y,
          ),
        );
      }
    }
    return checks;
  }

  List<MotionIkTargetResidual> _sampleIkTargetResiduals(
    Clip clip,
    MotionConstraintProfile profile,
    int samples,
  ) {
    if (clip.limbTargets.isEmpty) return const [];
    final checks = <MotionIkTargetResidual>[];
    for (var i = 0; i < samples; i++) {
      final phase = i / samples;
      final timeSeconds = _phaseTime(clip, phase);
      final frame = scene.frameAt(clip: clip, timeSeconds: timeSeconds);
      for (final target in clip.limbTargets) {
        final sample = target.channel.sample(phase);
        if (sample.weight < profile.minIkWeight) continue;
        final endWorld = frame.world[target.endBoneId];
        final anchorWorld = frame.world[target.anchorBoneId];
        if (endWorld == null || anchorWorld == null) continue;

        final endPoint = endWorld.origin;
        final targetPoint = anchorWorld.transformPoint(sample.x, sample.y);
        final dx = endPoint.x - targetPoint.x;
        final dy = endPoint.y - targetPoint.y;
        checks.add(
          MotionIkTargetResidual(
            clipName: clip.name,
            upperBoneId: target.upperBoneId,
            lowerBoneId: target.lowerBoneId,
            endBoneId: target.endBoneId,
            anchorBoneId: target.anchorBoneId,
            phase: phase,
            weight: sample.weight,
            endX: endPoint.x,
            endY: endPoint.y,
            targetX: targetPoint.x,
            targetY: targetPoint.y,
            dx: dx,
            dy: dy,
            distance: _distance(dx, dy),
          ),
        );
      }
    }
    return checks;
  }

  List<MotionIkReach> _sampleIkReach(
    Clip clip,
    MotionConstraintProfile profile,
    int samples,
  ) {
    if (clip.limbTargets.isEmpty) return const [];
    final checks = <MotionIkReach>[];
    for (var i = 0; i < samples; i++) {
      final phase = i / samples;
      final pose = scene.evaluator.evaluate(clip, _phaseTime(clip, phase));
      final world = scene.solver.solve(pose);
      for (final target in clip.limbTargets) {
        final sample = target.channel.sample(phase);
        if (sample.weight < profile.minIkWeight) continue;
        final upperWorld = world[target.upperBoneId];
        final lowerWorld = world[target.lowerBoneId];
        final endWorld = world[target.endBoneId];
        final anchorWorld = world[target.anchorBoneId];
        if (upperWorld == null ||
            lowerWorld == null ||
            endWorld == null ||
            anchorWorld == null) {
          continue;
        }

        final shoulder = upperWorld.origin;
        final elbow = lowerWorld.origin;
        final wrist = endWorld.origin;
        final targetPoint = anchorWorld.transformPoint(sample.x, sample.y);
        final upperLength = _pointDistance(shoulder, elbow);
        final lowerLength = _pointDistance(elbow, wrist);
        final chainLength = upperLength + lowerLength;
        if (chainLength <= 1e-6) continue;
        final reach = _pointDistance(shoulder, targetPoint);
        checks.add(
          MotionIkReach(
            clipName: clip.name,
            upperBoneId: target.upperBoneId,
            lowerBoneId: target.lowerBoneId,
            endBoneId: target.endBoneId,
            anchorBoneId: target.anchorBoneId,
            phase: phase,
            weight: sample.weight,
            reach: reach,
            chainLength: chainLength,
            reachRatio: reach / chainLength,
          ),
        );
      }
    }
    return checks;
  }

  List<MotionShoulderResponse> _sampleRaisedShoulderResponses(
    Clip clip,
    MotionConstraintProfile profile,
    int samples,
  ) {
    if (clip.limbTargets.isEmpty) return const [];
    final checks = <MotionShoulderResponse>[];
    for (var i = 0; i < samples; i++) {
      final phase = i / samples;
      final timeSeconds = _phaseTime(clip, phase);
      final pose = scene.poseAt(
        clip: clip,
        timeSeconds: timeSeconds,
        includeAutonomic: false,
      );
      for (final target in clip.limbTargets) {
        if (!_isHand(target.endBoneId)) continue;
        final targetPose = target.channel.sample(phase);
        if (targetPose.weight < profile.minIkWeight ||
            targetPose.y > profile.raisedHandTargetY) {
          continue;
        }
        final upper = scene.rig.bone(target.upperBoneId);
        final clavicleId = upper?.parent;
        if (clavicleId == null) continue;

        final claviclePose = pose.jointOf(clavicleId);
        final socketId = _shoulderSocketIdFor(clavicleId, target.upperBoneId);
        final socketPose = socketId == null
            ? JointPose.identity
            : pose.jointOf(socketId);
        final socketResponse =
            socketPose.rotation.abs() +
            (socketPose.scaleX - 1).abs() +
            (socketPose.scaleY - 1).abs();
        final totalResponse = claviclePose.rotation.abs() + socketResponse;

        checks.add(
          MotionShoulderResponse(
            clipName: clip.name,
            upperBoneId: target.upperBoneId,
            endBoneId: target.endBoneId,
            clavicleBoneId: clavicleId,
            socketBoneId: socketId,
            phase: phase,
            targetY: targetPose.y,
            clavicleRotation: claviclePose.rotation,
            socketRotation: socketPose.rotation,
            socketScaleX: socketPose.scaleX,
            socketScaleY: socketPose.scaleY,
            socketResponse: socketResponse,
            totalResponse: totalResponse,
          ),
        );
      }
    }
    return checks;
  }

  List<MotionShoulderMeshBridge> _sampleRaisedShoulderMeshBridges(
    Clip clip,
    MotionConstraintProfile profile,
    int samples,
  ) {
    if (clip.limbTargets.isEmpty || scene.rig.meshes.isEmpty) return const [];
    final checks = <MotionShoulderMeshBridge>[];
    for (var i = 0; i < samples; i++) {
      final phase = i / samples;
      final timeSeconds = _phaseTime(clip, phase);
      final frame = scene.frameAt(clip: clip, timeSeconds: timeSeconds);
      for (final target in clip.limbTargets) {
        if (!_isHand(target.endBoneId)) continue;
        final targetPose = target.channel.sample(phase);
        if (targetPose.weight < profile.minIkWeight ||
            targetPose.y > profile.raisedHandTargetY) {
          continue;
        }
        final suffix = _sideSuffix(target.endBoneId);
        if (suffix == null) continue;
        final side = suffix.substring(1);
        final armMesh = _meshById('arm.$side.mesh');
        if (armMesh == null) continue;

        final arm = resolveSkinnedMeshVertices(armMesh, frame.world);
        if (arm == null) continue;
        final armShoulder = _vertexSubset(
          arm,
          _armSideShoulderIndices(arm.length),
        );
        final armhole = _vertexSubset(
          arm,
          _torsoSideArmholeIndices(arm.length),
        );
        if (armShoulder.isEmpty || armhole.isEmpty) continue;
        final upperWorld = frame.world[target.upperBoneId];
        final lowerWorld = frame.world[target.lowerBoneId];
        if (upperWorld == null || lowerWorld == null) continue;
        final axisDx = lowerWorld.origin.x - upperWorld.origin.x;
        final axisDy = lowerWorld.origin.y - upperWorld.origin.y;
        final axisLength = _distance(axisDx, axisDy);
        if (axisLength <= 1e-6) continue;
        final normalX = -axisDy / axisLength;
        final normalY = axisDx / axisLength;
        final shoulderIndices = _armShoulderCapIndices(arm.length);
        final bicepIndices = _armBicepIndices(arm.length);
        final upperArmIndices = {...shoulderIndices, ...bicepIndices};

        final gap = _minPointSetDistance(armShoulder, armhole);
        checks.add(
          MotionShoulderMeshBridge(
            clipName: clip.name,
            endBoneId: target.endBoneId,
            armMeshId: armMesh.id,
            foldMeshId: armMesh.id,
            phase: phase,
            targetY: targetPose.y,
            gap: gap,
            shoulderSpan: _projectedSpan(
              arm,
              shoulderIndices,
              normalX,
              normalY,
            ),
            bicepSpan: _projectedSpan(arm, bicepIndices, normalX, normalY),
            maxUpperArmEdge: _maxAdjacentBoundaryEdgeTouching(
              arm,
              armMesh.boundary,
              upperArmIndices,
            ),
          ),
        );
      }
    }
    return checks;
  }

  double _phaseTime(Clip clip, double phase) {
    if (clip.duration <= 0) return 0;
    final p = clip.loop ? _unitPhase(phase) : phase.clamp(0.0, 1.0);
    return p * clip.duration;
  }

  ({double x, double y})? _contactPoint(
    RigSpec rig,
    CharacterFrame frame,
    String boneId,
  ) {
    final transform = frame.world[boneId];
    final drawable = rig.bone(boneId)?.drawable;
    if (transform == null || drawable == null) return null;
    return transform.transformPoint(
      drawable.dx,
      drawable.dy + drawable.height / 2,
    );
  }

  double _pointDistance(({double x, double y}) a, ({double x, double y}) b) =>
      _distance(a.x - b.x, a.y - b.y);

  double _distance(double dx, double dy) => math.sqrt(dx * dx + dy * dy);

  double _positive(double value) => value > 0 ? value : 0;

  double _unitPhase(double phase) => phase - phase.floorToDouble();

  int _sameSideSign(
    String endBoneId,
    double targetX,
    MotionConstraintProfile profile,
  ) {
    if (!endBoneId.toLowerCase().contains('hand')) return 0;
    if (targetX.abs() < profile.minSameSideTargetX) return 0;
    if (endBoneId.endsWith('.L') && targetX < 0) return -1;
    if (endBoneId.endsWith('.R') && targetX > 0) return 1;
    return 0;
  }

  bool _isHand(String boneId) => boneId.toLowerCase().contains('hand');

  SkinnedMeshSpec? _meshById(String id) {
    for (final mesh in scene.rig.meshes) {
      if (mesh.id == id) return mesh;
    }
    return null;
  }

  MotionJointEnvelopeRule? _jointEnvelopeRuleFor(
    String boneId,
    MotionConstraintProfile profile,
  ) {
    final id = boneId.toLowerCase();
    for (final rule in profile.jointEnvelopeRules) {
      if (id.contains(rule.boneIdToken.toLowerCase())) return rule;
    }
    return null;
  }

  List<({double x, double y})> _vertexSubset(
    List<({double x, double y})> vertices,
    List<int> indices,
  ) => [
    for (final index in indices)
      if (index >= 0 && index < vertices.length) vertices[index],
  ];

  List<int> _armShoulderCapIndices(int vertexCount) => vertexCount >= 20
      ? const [0, 1, 2, 17, 18, 19]
      : vertexCount >= 18
      ? const [0, 1, 2, 15, 16, 17]
      : const [0, 1, 2, 12, 13, 14];

  List<int> _armBicepIndices(int vertexCount) => vertexCount >= 20
      ? const [2, 3, 4, 5, 6, 14, 15, 16, 17]
      : vertexCount >= 18
      ? const [2, 3, 4, 5, 13, 14, 15]
      : const [2, 3, 4, 10, 11, 12];

  List<int> _armSideShoulderIndices(int vertexCount) => vertexCount >= 20
      ? const [2, 3, 4, 15, 16, 17]
      : vertexCount >= 18
      ? const [2, 3, 4, 13, 14, 15]
      : const [2, 3, 11, 12];

  List<int> _torsoSideArmholeIndices(int vertexCount) => vertexCount >= 20
      ? const [0, 1, 18, 19]
      : vertexCount >= 18
      ? const [0, 1, 16, 17]
      : const [0, 1, 13, 14];

  double _projectedSpan(
    List<({double x, double y})> vertices,
    List<int> indices,
    double normalX,
    double normalY,
  ) {
    var minProjection = double.infinity;
    var maxProjection = -double.infinity;
    for (final index in indices) {
      if (index < 0 || index >= vertices.length) continue;
      final point = vertices[index];
      final projection = point.x * normalX + point.y * normalY;
      minProjection = math.min(minProjection, projection);
      maxProjection = math.max(maxProjection, projection);
    }
    if (minProjection == double.infinity) return 0;
    return maxProjection - minProjection;
  }

  double _maxAdjacentBoundaryEdgeTouching(
    List<({double x, double y})> vertices,
    List<int> boundary,
    Set<int> included,
  ) {
    var longest = 0.0;
    for (var i = 0; i < boundary.length; i++) {
      final aIndex = boundary[i];
      final bIndex = boundary[(i + 1) % boundary.length];
      if (!included.contains(aIndex) && !included.contains(bIndex)) continue;
      if (aIndex < 0 ||
          bIndex < 0 ||
          aIndex >= vertices.length ||
          bIndex >= vertices.length) {
        continue;
      }
      longest = math.max(
        longest,
        _pointDistance(vertices[aIndex], vertices[bIndex]),
      );
    }
    return longest;
  }

  double _minPointSetDistance(
    List<({double x, double y})> a,
    List<({double x, double y})> b,
  ) {
    var best = double.infinity;
    for (final pa in a) {
      for (final pb in b) {
        best = math.min(best, _pointDistance(pa, pb));
      }
    }
    return best;
  }

  String? _shoulderSocketIdFor(String clavicleId, String upperBoneId) {
    final suffix = _sideSuffix(upperBoneId);
    for (final bone in scene.rig.bones) {
      if (bone.parent != clavicleId) continue;
      if (!bone.id.toLowerCase().contains('shoulder')) continue;
      if (suffix != null && !bone.id.endsWith(suffix)) continue;
      return bone.id;
    }
    return null;
  }

  String? _sideSuffix(String boneId) {
    final index = boneId.lastIndexOf('.');
    if (index < 0 || index == boneId.length - 1) return null;
    return boneId.substring(index);
  }
}

class MotionJointEnvelopeRule {
  const MotionJointEnvelopeRule({
    required this.boneIdToken,
    this.maxAbsRotation,
    this.maxScaleDelta,
  }) : assert(boneIdToken.length > 0, 'bone token must not be empty'),
       assert(
         maxAbsRotation != null || maxScaleDelta != null,
         'at least one joint envelope limit must be set',
       ),
       assert(
         maxAbsRotation == null || maxAbsRotation >= 0,
         'max rotation must be non-negative',
       ),
       assert(
         maxScaleDelta == null || maxScaleDelta >= 0,
         'max scale delta must be non-negative',
       );

  /// Lower-case substring matched against resolved bone ids.
  ///
  /// Rules are evaluated in order, so specific controls such as
  /// `shoulder_socket` should appear before broader tokens if those are ever
  /// added.
  final String boneIdToken;

  /// Maximum absolute local joint rotation in radians.
  final double? maxAbsRotation;

  /// Maximum absolute deviation from neutral scale on either axis.
  final double? maxScaleDelta;
}

const defaultMotionJointEnvelopeRules = <MotionJointEnvelopeRule>[
  MotionJointEnvelopeRule(boneIdToken: 'head', maxAbsRotation: 0.18),
  MotionJointEnvelopeRule(boneIdToken: 'neck', maxAbsRotation: 0.25),
  MotionJointEnvelopeRule(
    boneIdToken: 'torso',
    maxAbsRotation: 0.75,
    maxScaleDelta: 0.42,
  ),
  MotionJointEnvelopeRule(
    boneIdToken: 'hips',
    maxAbsRotation: 1.1,
    maxScaleDelta: 0.08,
  ),
  MotionJointEnvelopeRule(
    boneIdToken: 'clavicle',
    maxAbsRotation: 0.55,
    maxScaleDelta: 0.08,
  ),
  MotionJointEnvelopeRule(
    boneIdToken: 'shoulder_socket',
    maxAbsRotation: 0.5,
    maxScaleDelta: 0.3,
  ),
  MotionJointEnvelopeRule(
    boneIdToken: 'arm_bicep',
    maxAbsRotation: 0.25,
    maxScaleDelta: 0.25,
  ),
  MotionJointEnvelopeRule(boneIdToken: 'arm_upper', maxAbsRotation: 4.25),
  MotionJointEnvelopeRule(boneIdToken: 'arm_lower', maxAbsRotation: 4.4),
  MotionJointEnvelopeRule(boneIdToken: 'leg_upper', maxAbsRotation: 1.55),
  MotionJointEnvelopeRule(boneIdToken: 'leg_lower', maxAbsRotation: 2.45),
  MotionJointEnvelopeRule(boneIdToken: 'foot', maxAbsRotation: 1.3),
];

class MotionConstraintProfile {
  const MotionConstraintProfile({
    this.contactEdgeFraction = 0.24,
    this.maxStableContactDrift = 18,
    this.maxStableVerticalDrift = 10,
    this.maxSupportOffset = 58,
    this.maxIkReachRatio = 0.96,
    this.maxIkTargetResidual = 18,
    this.minLimbBendDegrees = 3,
    this.maxLimbBendDegrees = 178,
    this.minBendDirectionArea = 10,
    this.maxLimbLaneReversal = 5,
    this.minSameSideTargetX = 48,
    this.minIkWeight = 0.05,
    this.raisedHandTargetY = -60,
    this.minRaisedShoulderResponse = 0.18,
    this.minRaisedSocketResponse = 0.06,
    this.maxRaisedShoulderMeshGap = 24,
    this.minRaisedShoulderMeshSpan = 12,
    this.minRaisedShoulderToBicepRatio = 0.66,
    this.maxRaisedUpperArmMeshEdge = 40,
    this.jointEnvelopeRules = defaultMotionJointEnvelopeRules,
  }) : assert(
         contactEdgeFraction >= 0 && contactEdgeFraction < 0.5,
         'contact edge fraction must be in [0, 0.5)',
       ),
       assert(
         maxStableContactDrift >= 0,
         'max stable contact drift must be non-negative',
       ),
       assert(
         maxStableVerticalDrift >= 0,
         'max stable vertical drift must be non-negative',
       ),
       assert(maxSupportOffset >= 0, 'max support offset must be non-negative'),
       assert(maxIkReachRatio > 0, 'max IK reach ratio must be positive'),
       assert(
         maxIkTargetResidual >= 0,
         'max IK target residual must be non-negative',
       ),
       assert(minLimbBendDegrees >= 0, 'min limb bend must be non-negative'),
       assert(
         maxLimbBendDegrees <= 180 && maxLimbBendDegrees > 0,
         'max limb bend must be in 0..180',
       ),
       assert(
         minBendDirectionArea >= 0,
         'min bend direction area must be non-negative',
       ),
       assert(maxLimbLaneReversal >= 0, 'limb reversal must be non-negative'),
       assert(
         minSameSideTargetX >= 0,
         'same-side target x must be non-negative',
       ),
       assert(
         minIkWeight >= 0 && minIkWeight <= 1,
         'min IK weight must be in 0..1',
       ),
       assert(
         minRaisedShoulderResponse >= 0,
         'raised shoulder response must be non-negative',
       ),
       assert(
         minRaisedSocketResponse >= 0,
         'raised socket response must be non-negative',
       ),
       assert(
         maxRaisedShoulderMeshGap >= 0,
         'raised shoulder mesh gap must be non-negative',
       ),
       assert(
         minRaisedShoulderMeshSpan >= 0,
         'raised shoulder mesh span must be non-negative',
       ),
       assert(
         minRaisedShoulderToBicepRatio >= 0,
         'raised shoulder-to-bicep ratio must be non-negative',
       ),
       assert(
         maxRaisedUpperArmMeshEdge >= 0,
         'raised upper-arm mesh edge must be non-negative',
       );

  /// Fraction at each contact-span edge ignored as handoff/toe-roll time.
  final double contactEdgeFraction;

  /// Maximum stable support-foot drift from the middle of the same hold.
  final double maxStableContactDrift;

  /// Maximum vertical pop for a support foot during the stable hold.
  final double maxStableVerticalDrift;

  /// Maximum horizontal root/pelvis distance from the active support foot.
  final double maxSupportOffset;

  /// Maximum authored target reach relative to the limb chain length.
  ///
  /// Values near 1.0 leave no elbow/knee bend, which is where the panel starts
  /// reading stick arms and locked legs even before the target becomes impossible.
  final double maxIkReachRatio;

  /// Maximum solved endpoint distance from its high-weight authored IK target.
  ///
  /// This measures the rendered frame after all pose passes, not just whether
  /// the target was theoretically reachable. Large residuals mean the arm/leg is
  /// visually detached from the choreographic control point.
  final double maxIkTargetResidual;

  /// Minimum allowed interior angle at a solved elbow/knee.
  ///
  /// Very small angles mean the limb has folded into itself. This is a broad
  /// anatomy guard, not a style target.
  final double minLimbBendDegrees;

  /// Maximum allowed interior angle at a solved elbow/knee.
  ///
  /// Angles near 180 are mathematically reachable but visually read as locked
  /// stick limbs and leave no muscular bend for dance weight.
  final double maxLimbBendDegrees;

  /// Ignore bend-direction signs when the limb is nearly straight.
  ///
  /// Signed triangle area gets numerically meaningless when shoulder/elbow/wrist
  /// are almost collinear; locked-limb validation handles those frames instead.
  final double minBendDirectionArea;

  /// Maximum allowed same-side lane reversal in world pixels.
  ///
  /// Larger values mean either the elbow has crossed inside its shoulder or the
  /// hand has folded back inside its elbow, which creates the folded-X sleeve bug
  /// even when the target is reachable.
  final double maxLimbLaneReversal;

  /// Minimum authored x-offset before a target counts as intentionally same-side.
  final double minSameSideTargetX;

  /// Ignore near-disabled IK targets.
  final double minIkWeight;

  /// Local hand-target y threshold for an arm that is visibly above shoulder
  /// height and therefore must pull the shoulder girdle with it.
  final double raisedHandTargetY;

  /// Minimum combined clavicle + socket response for an overhead hand target.
  final double minRaisedShoulderResponse;

  /// Minimum socket/corrective deformation for an overhead hand target.
  final double minRaisedSocketResponse;

  /// Maximum nearest visible gap inside a raised sleeve's single armhole mesh.
  final double maxRaisedShoulderMeshGap;

  /// Minimum cross-axis width of the resolved sleeve shoulder cap.
  ///
  /// This stays deliberately below the bicep span target: the validator should
  /// catch wire-thin detachment, not force padded shoulder blocks.
  final double minRaisedShoulderMeshSpan;

  /// Minimum shoulder/armhole width relative to the resolved bicep width.
  final double minRaisedShoulderToBicepRatio;

  /// Maximum adjacent edge length around the raised sleeve shoulder/bicep
  /// contour. Long edges are what make the continuous sleeve read as a triangle
  /// fan instead of a shaped garment mesh.
  final double maxRaisedUpperArmMeshEdge;

  /// Resolved local-joint envelopes used to catch impossible authored poses.
  final List<MotionJointEnvelopeRule> jointEnvelopeRules;
}

class MotionConstraintReport {
  const MotionConstraintReport({
    required this.clipName,
    required this.profile,
    required this.contactDrifts,
    required this.supportBalances,
    required this.ikReaches,
    required this.ikTargetResiduals,
    required this.limbBends,
    required this.limbLanes,
    required this.shoulderResponses,
    required this.shoulderMeshBridges,
    required this.jointEnvelopes,
  });

  final String clipName;
  final MotionConstraintProfile profile;
  final List<MotionContactDrift> contactDrifts;
  final List<MotionSupportBalance> supportBalances;
  final List<MotionIkReach> ikReaches;
  final List<MotionIkTargetResidual> ikTargetResiduals;
  final List<MotionLimbBend> limbBends;
  final List<MotionLimbLane> limbLanes;
  final List<MotionShoulderResponse> shoulderResponses;
  final List<MotionShoulderMeshBridge> shoulderMeshBridges;
  final List<MotionJointEnvelope> jointEnvelopes;

  MotionContactDrift? get worstContactDrift =>
      _maxOrNull(contactDrifts, (check) => check.distance);

  MotionSupportBalance? get worstSupportBalance =>
      _maxOrNull(supportBalances, (check) => check.offsetX.abs());

  MotionIkReach? get worstIkReach =>
      _maxOrNull(ikReaches, (check) => check.reachRatio);

  MotionIkTargetResidual? get worstIkTargetResidual =>
      _maxOrNull(ikTargetResiduals, (check) => check.distance);

  MotionLimbBend? get straightestLimbBend =>
      _maxOrNull(limbBends, (check) => check.bendDegrees);

  MotionLimbBend? get tightestLimbBend =>
      _maxOrNull(limbBends, (check) => -check.bendDegrees);

  MotionLimbLane? get worstLimbLane =>
      _maxOrNull(limbLanes, (check) => check.reversalDistance);

  MotionShoulderResponse? get weakestRaisedShoulderResponse => _maxOrNull(
    shoulderResponses,
    (check) => -math.min(check.totalResponse, check.socketResponse),
  );

  MotionShoulderMeshBridge? get worstShoulderMeshBridge =>
      _maxOrNull(shoulderMeshBridges, (check) => check.gap);

  MotionJointEnvelope? get worstJointEnvelope =>
      _maxOrNull(jointEnvelopes, (check) => check.severity);

  List<MotionConstraintViolation> get violations {
    final result = <MotionConstraintViolation>[];
    for (final check in contactDrifts) {
      final driftSeverity = check.distance - profile.maxStableContactDrift;
      final verticalSeverity = check.dy.abs() - profile.maxStableVerticalDrift;
      if (driftSeverity > 0 || verticalSeverity > 0) {
        result.add(
          MotionConstraintViolation(
            category: MotionConstraintCategory.footContact,
            clipName: clipName,
            boneId: check.boneId,
            phase: check.phase,
            severity: math.max(driftSeverity, verticalSeverity),
            message:
                '${check.boneId} drifts ${check.distance.toStringAsFixed(1)} '
                'px during stable support',
          ),
        );
      }
    }
    for (final check in supportBalances) {
      final severity = check.offsetX.abs() - profile.maxSupportOffset;
      if (severity > 0) {
        result.add(
          MotionConstraintViolation(
            category: MotionConstraintCategory.supportBalance,
            clipName: clipName,
            boneId: check.supportBoneId,
            phase: check.phase,
            severity: severity,
            message:
                '${check.rootBoneId} is ${check.offsetX.abs().toStringAsFixed(1)} '
                'px from ${check.supportBoneId}',
          ),
        );
      }
    }
    for (final check in ikReaches) {
      final severity = check.reachRatio - profile.maxIkReachRatio;
      if (severity > 0) {
        result.add(
          MotionConstraintViolation(
            category: MotionConstraintCategory.ikReach,
            clipName: clipName,
            boneId: check.endBoneId,
            phase: check.phase,
            severity: severity,
            message:
                '${check.endBoneId} target uses '
                '${check.reachRatio.toStringAsFixed(2)}x limb reach',
          ),
        );
      }
    }
    for (final check in ikTargetResiduals) {
      final severity = check.distance - profile.maxIkTargetResidual;
      if (severity > 0) {
        result.add(
          MotionConstraintViolation(
            category: MotionConstraintCategory.ikTargetResidual,
            clipName: clipName,
            boneId: check.endBoneId,
            phase: check.phase,
            severity: severity,
            message:
                '${check.endBoneId} resolves '
                '${check.distance.toStringAsFixed(1)} px from its IK target',
          ),
        );
      }
    }
    for (final check in limbBends) {
      final straightSeverity = check.bendDegrees - profile.maxLimbBendDegrees;
      if (straightSeverity > 0) {
        result.add(
          MotionConstraintViolation(
            category: MotionConstraintCategory.limbBend,
            clipName: clipName,
            boneId: check.endBoneId,
            phase: check.phase,
            severity: straightSeverity,
            message:
                '${check.lowerBoneId} is locked at '
                '${check.bendDegrees.toStringAsFixed(1)} degrees',
          ),
        );
      }
      final foldSeverity = profile.minLimbBendDegrees - check.bendDegrees;
      if (foldSeverity > 0) {
        result.add(
          MotionConstraintViolation(
            category: MotionConstraintCategory.limbBend,
            clipName: clipName,
            boneId: check.endBoneId,
            phase: check.phase,
            severity: foldSeverity,
            message:
                '${check.lowerBoneId} folds to '
                '${check.bendDegrees.toStringAsFixed(1)} degrees',
          ),
        );
      }
      if (check.actualBendDirection != 0 &&
          check.actualBendDirection != check.expectedBendDirection) {
        result.add(
          MotionConstraintViolation(
            category: MotionConstraintCategory.limbBendDirection,
            clipName: clipName,
            boneId: check.endBoneId,
            phase: check.phase,
            severity: check.signedArea.abs(),
            message:
                '${check.lowerBoneId} bends opposite its authored side '
                '(expected ${check.expectedBendDirection}, '
                'actual ${check.actualBendDirection})',
          ),
        );
      }
    }
    for (final check in limbLanes) {
      final severity = check.reversalDistance - profile.maxLimbLaneReversal;
      if (severity > 0) {
        result.add(
          MotionConstraintViolation(
            category: MotionConstraintCategory.limbLane,
            clipName: clipName,
            boneId: check.endBoneId,
            phase: check.phase,
            severity: severity,
            message:
                '${check.endBoneId} reverses through ${check.lowerBoneId} '
                'on a same-side target',
          ),
        );
      }
    }
    for (final check in shoulderResponses) {
      final totalSeverity =
          profile.minRaisedShoulderResponse - check.totalResponse;
      final socketSeverity =
          profile.minRaisedSocketResponse - check.socketResponse;
      if (totalSeverity > 0 || socketSeverity > 0) {
        result.add(
          MotionConstraintViolation(
            category: MotionConstraintCategory.shoulderResponse,
            clipName: clipName,
            boneId: check.endBoneId,
            phase: check.phase,
            severity: math.max(totalSeverity, socketSeverity),
            message:
                '${check.endBoneId} targets high at y='
                '${check.targetY.toStringAsFixed(1)} without enough '
                'clavicle/socket response',
          ),
        );
      }
    }
    for (final check in shoulderMeshBridges) {
      final gapSeverity = check.gap - profile.maxRaisedShoulderMeshGap;
      final spanSeverity =
          profile.minRaisedShoulderMeshSpan - check.shoulderSpan;
      final ratioSeverity =
          (profile.minRaisedShoulderToBicepRatio - check.shoulderToBicepRatio) *
          profile.minRaisedShoulderMeshSpan;
      final edgeSeverity =
          check.maxUpperArmEdge - profile.maxRaisedUpperArmMeshEdge;
      final severity = [
        gapSeverity,
        spanSeverity,
        ratioSeverity,
        edgeSeverity,
      ].reduce(math.max);
      if (severity > 0) {
        result.add(
          MotionConstraintViolation(
            category: MotionConstraintCategory.shoulderMeshBridge,
            clipName: clipName,
            boneId: check.endBoneId,
            phase: check.phase,
            severity: severity,
            message:
                '${check.armMeshId} raised shoulder gap='
                '${check.gap.toStringAsFixed(1)} px, span='
                '${check.shoulderSpan.toStringAsFixed(1)} px, '
                'shoulder/bicep='
                '${check.shoulderToBicepRatio.toStringAsFixed(2)}, '
                'edge=${check.maxUpperArmEdge.toStringAsFixed(1)} px',
          ),
        );
      }
    }
    for (final check in jointEnvelopes) {
      final severity = check.severity;
      if (severity > 0) {
        result.add(
          MotionConstraintViolation(
            category: MotionConstraintCategory.jointEnvelope,
            clipName: clipName,
            boneId: check.boneId,
            phase: check.phase,
            severity: severity,
            message:
                '${check.boneId} exceeds dancer joint envelope: '
                'rot=${check.rotation.toStringAsFixed(2)} '
                'limit=${check.maxAbsRotation?.toStringAsFixed(2) ?? 'n/a'}, '
                'scale=(${check.scaleX.toStringAsFixed(2)}, '
                '${check.scaleY.toStringAsFixed(2)}) '
                'deltaLimit=${check.maxScaleDelta?.toStringAsFixed(2) ?? 'n/a'}',
          ),
        );
      }
    }
    result.sort((a, b) => b.severity.compareTo(a.severity));
    return result;
  }

  static T? _maxOrNull<T>(List<T> values, double Function(T value) score) {
    if (values.isEmpty) return null;
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
}

class MotionContactDrift {
  const MotionContactDrift({
    required this.clipName,
    required this.boneId,
    required this.phase,
    required this.anchorPhase,
    required this.dx,
    required this.dy,
    required this.distance,
  });

  final String clipName;
  final String boneId;
  final double phase;
  final double anchorPhase;
  final double dx;
  final double dy;
  final double distance;
}

class MotionSupportBalance {
  const MotionSupportBalance({
    required this.clipName,
    required this.supportBoneId,
    required this.rootBoneId,
    required this.phase,
    required this.offsetX,
    required this.offsetY,
  });

  final String clipName;
  final String supportBoneId;
  final String rootBoneId;
  final double phase;
  final double offsetX;
  final double offsetY;
}

class MotionIkReach {
  const MotionIkReach({
    required this.clipName,
    required this.upperBoneId,
    required this.lowerBoneId,
    required this.endBoneId,
    required this.anchorBoneId,
    required this.phase,
    required this.weight,
    required this.reach,
    required this.chainLength,
    required this.reachRatio,
  });

  final String clipName;
  final String upperBoneId;
  final String lowerBoneId;
  final String endBoneId;
  final String anchorBoneId;
  final double phase;
  final double weight;
  final double reach;
  final double chainLength;
  final double reachRatio;
}

class MotionIkTargetResidual {
  const MotionIkTargetResidual({
    required this.clipName,
    required this.upperBoneId,
    required this.lowerBoneId,
    required this.endBoneId,
    required this.anchorBoneId,
    required this.phase,
    required this.weight,
    required this.endX,
    required this.endY,
    required this.targetX,
    required this.targetY,
    required this.dx,
    required this.dy,
    required this.distance,
  });

  final String clipName;
  final String upperBoneId;
  final String lowerBoneId;
  final String endBoneId;
  final String anchorBoneId;
  final double phase;
  final double weight;
  final double endX;
  final double endY;
  final double targetX;
  final double targetY;
  final double dx;
  final double dy;
  final double distance;
}

class MotionLimbBend {
  const MotionLimbBend({
    required this.clipName,
    required this.upperBoneId,
    required this.lowerBoneId,
    required this.endBoneId,
    required this.phase,
    required this.weight,
    required this.expectedBendDirection,
    required this.actualBendDirection,
    required this.signedArea,
    required this.bendDegrees,
    required this.straightnessDegrees,
  });

  final String clipName;
  final String upperBoneId;
  final String lowerBoneId;
  final String endBoneId;
  final double phase;
  final double weight;
  final int expectedBendDirection;

  /// `0` means the limb was too close to straight to infer a side robustly.
  final int actualBendDirection;

  final double signedArea;
  final double bendDegrees;
  final double straightnessDegrees;
}

class MotionLimbLane {
  const MotionLimbLane({
    required this.clipName,
    required this.upperBoneId,
    required this.lowerBoneId,
    required this.endBoneId,
    required this.phase,
    required this.side,
    required this.targetX,
    required this.shoulderX,
    required this.elbowX,
    required this.endX,
    required this.elbowReversal,
    required this.endReversal,
    required this.reversalDistance,
    required this.horizontalFold,
  });

  final String clipName;
  final String upperBoneId;
  final String lowerBoneId;
  final String endBoneId;
  final double phase;
  final int side;
  final double targetX;
  final double shoulderX;
  final double elbowX;
  final double endX;
  final double elbowReversal;
  final double endReversal;
  final double reversalDistance;
  final double horizontalFold;
}

class MotionShoulderResponse {
  const MotionShoulderResponse({
    required this.clipName,
    required this.upperBoneId,
    required this.endBoneId,
    required this.clavicleBoneId,
    required this.socketBoneId,
    required this.phase,
    required this.targetY,
    required this.clavicleRotation,
    required this.socketRotation,
    required this.socketScaleX,
    required this.socketScaleY,
    required this.socketResponse,
    required this.totalResponse,
  });

  final String clipName;
  final String upperBoneId;
  final String endBoneId;
  final String clavicleBoneId;
  final String? socketBoneId;
  final double phase;
  final double targetY;
  final double clavicleRotation;
  final double socketRotation;
  final double socketScaleX;
  final double socketScaleY;
  final double socketResponse;
  final double totalResponse;
}

class MotionShoulderMeshBridge {
  const MotionShoulderMeshBridge({
    required this.clipName,
    required this.endBoneId,
    required this.armMeshId,
    required this.foldMeshId,
    required this.phase,
    required this.targetY,
    required this.gap,
    required this.shoulderSpan,
    required this.bicepSpan,
    required this.maxUpperArmEdge,
  });

  final String clipName;
  final String endBoneId;
  final String armMeshId;
  final String foldMeshId;
  final double phase;
  final double targetY;
  final double gap;
  final double shoulderSpan;
  final double bicepSpan;
  final double maxUpperArmEdge;

  double get shoulderToBicepRatio =>
      bicepSpan <= 1e-6 ? double.infinity : shoulderSpan / bicepSpan;
}

class MotionJointEnvelope {
  const MotionJointEnvelope({
    required this.clipName,
    required this.boneId,
    required this.phase,
    required this.rotation,
    required this.scaleX,
    required this.scaleY,
    required this.maxAbsRotation,
    required this.maxScaleDelta,
  });

  final String clipName;
  final String boneId;
  final double phase;
  final double rotation;
  final double scaleX;
  final double scaleY;
  final double? maxAbsRotation;
  final double? maxScaleDelta;

  double get rotationSeverity =>
      maxAbsRotation == null ? 0 : rotation.abs() - maxAbsRotation!;

  double get scaleSeverity {
    if (maxScaleDelta == null) return 0;
    return math.max((scaleX - 1).abs(), (scaleY - 1).abs()) - maxScaleDelta!;
  }

  double get severity => math.max(rotationSeverity, scaleSeverity);
}

enum MotionConstraintCategory {
  footContact,
  supportBalance,
  ikReach,
  ikTargetResidual,
  limbBend,
  limbBendDirection,
  limbLane,
  shoulderResponse,
  shoulderMeshBridge,
  jointEnvelope,
}

class MotionConstraintViolation {
  const MotionConstraintViolation({
    required this.category,
    required this.clipName,
    required this.boneId,
    required this.phase,
    required this.severity,
    required this.message,
  });

  final MotionConstraintCategory category;
  final String clipName;
  final String boneId;
  final double phase;
  final double severity;
  final String message;
}
