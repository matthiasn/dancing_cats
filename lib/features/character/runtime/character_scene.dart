import 'dart:math' as math;

import 'package:dancing_cats/features/character/engine/autonomic.dart';
import 'package:dancing_cats/features/character/engine/clip_evaluator.dart';
import 'package:dancing_cats/features/character/engine/face_solver.dart';
import 'package:dancing_cats/features/character/engine/skeleton_solver.dart';
import 'package:dancing_cats/features/character/engine/two_bone_ik.dart';
import 'package:dancing_cats/features/character/model/affine2d.dart';
import 'package:dancing_cats/features/character/model/bone.dart';
import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/face.dart';
import 'package:dancing_cats/features/character/model/pose.dart';
import 'package:dancing_cats/features/character/model/rig_spec.dart';
import 'package:dancing_cats/features/character/runtime/dance_timing.dart';
import 'package:dancing_cats/features/character/runtime/pose_modifier_stack.dart';

/// One fully-resolved frame: world transforms for every bone, the face state to
/// draw, and how far the character has travelled (locomotion). Everything the
/// renderer needs and nothing it doesn't.
class CharacterFrame {
  const CharacterFrame({
    required this.world,
    required this.face,
    required this.locomotionX,
  });

  final Map<String, Affine2D> world;
  final FaceState face;

  /// How far the character has travelled along x for this clip+time, in local
  /// units. Phase 1 deliberately animates in place (each film-strip cell is a
  /// phase sample, and the live widget loops on the spot), so **no caller wires
  /// this yet** — it is the kinematic hook the Phase-2 "walks across the screen"
  /// surface will fold into its placement transform.
  final double locomotionX;
}

/// Ties the engine pieces together: evaluate a clip, layer the autonomic
/// "alive" signals, run forward kinematics, resolve the face. Deterministic in
/// time, so a film strip and the live widget produce identical frames.
class CharacterScene {
  CharacterScene(this.rig, {AutonomicLayer? autonomic})
    : solver = SkeletonSolver(rig),
      autonomic = autonomic ?? AutonomicLayer() {
    _poseModifierStack = PoseModifierStack([
      PoseModifierPass(
        id: 'breath',
        description: 'Add subtle autonomic breathing to the root.',
        modifier: (context, pose) => _breathingPose(context.breath, pose),
      ),
      PoseModifierPass(
        id: 'support-balance',
        description: 'Bias the pelvis back inside the declared support foot.',
        modifier: (context, pose) =>
            _supportBalancedPose(context.clip, context.timeSeconds, pose),
      ),
      PoseModifierPass(
        id: 'secondary-follow',
        description: 'Lag tail and ears from the body groove.',
        modifier: (context, pose) =>
            _secondaryFollowPose(context.clip, context.timeSeconds, pose),
      ),
      PoseModifierPass(
        id: 'ear-life',
        description:
            'Flick the ear tips on sparse autonomic twitches — always on, '
            'dance or idle.',
        modifier: _earLifePose,
      ),
      PoseModifierPass(
        id: 'spine-distribute',
        description:
            'Split the authored torso rotation across the lumbar and '
            'thoracic joints so the trunk bends instead of tilting.',
        modifier: (context, pose) =>
            _spineDistributedPose(context.clip, context.timeSeconds, pose),
      ),
      PoseModifierPass(
        id: 'girdle-follow',
        description:
            'Ripple a lagged share of the trunk drive through the clavicles '
            'so the shoulder line answers the groove.',
        modifier: (context, pose) =>
            _girdleFollowPose(context.clip, context.timeSeconds, pose),
      ),
      PoseModifierPass(
        id: 'shoulder-girdle',
        description: 'Engage clavicle, socket, and bicep volume before IK.',
        modifier: (context, pose) =>
            _shoulderCorrectedPose(context.clip, context.timeSeconds, pose),
      ),
      PoseModifierPass(
        id: 'limb-ik',
        description: 'Solve hand and foot two-bone IK targets.',
        modifier: (context, pose) =>
            _limbTargetedPose(context.clip, context.timeSeconds, pose),
      ),
      PoseModifierPass(
        id: 'joint-limits',
        description:
            'Clamp every limited joint into its anatomical range of motion.',
        modifier: (context, pose) => _jointLimitedPose(pose),
      ),
      PoseModifierPass(
        id: 'contact-lock',
        description: 'Apply final support contact root correction.',
        modifier: (context, pose) =>
            _contactLockedPose(context.clip, context.timeSeconds, pose),
      ),
      PoseModifierPass(
        id: 'sole-flex',
        description:
            'Bend each sneaker at the ball of the foot when the heel lifts '
            'while the ball still bears on the floor.',
        modifier: (context, pose) => _soleFlexedPose(pose),
      ),
    ]);
  }

  final RigSpec rig;
  final SkeletonSolver solver;
  final ClipEvaluator evaluator = const ClipEvaluator();
  final FaceSolver faceSolver = const FaceSolver();
  final AutonomicLayer autonomic;
  late final PoseModifierStack _poseModifierStack;

  /// Local-space pose modifier passes in solve order.
  List<PoseModifierPass> get poseModifierPasses => _poseModifierStack.passes;

  /// Memoized foot-lock offset tables, keyed by clip name (built once per clip).
  final Map<String, _LocoTable> _locoTables = {};

  /// The clip's world-space horizontal travel at [timeSeconds]. For clips with
  /// [Clip.groundSpans] this is **foot-locked**: travel is the negative of the
  /// planted foot's leg-sweep, so the planted foot holds world position (no
  /// skate) and the COM sway still reads. Clips without spans fall back to the
  /// evaluator's constant-speed travel. Deterministic (the table is a pure
  /// function of the rig + clip), so film-strip renders stay reproducible.
  double locomotionOffset(Clip clip, double timeSeconds) {
    if (clip.groundSpans.isEmpty) {
      return evaluator.locomotionOffset(clip, timeSeconds);
    }
    final table = _locoTables.putIfAbsent(
      clip.name,
      () => _buildLocoTable(clip),
    );
    if (clip.duration <= 0) return 0;
    final phase = timeSeconds / clip.duration;
    final cycles = phase.floorToDouble();
    final frac = phase - cycles; // 0..1, handles negative time too
    return cycles * table.cycleAdvance + table.sample(frac);
  }

  /// Builds the foot-lock travel curve. Per step it advances by the planted
  /// foot's leg-sweep delta (`foot.x - root.x`; root carries the COM sway, so
  /// subtracting it keeps the sway while the foot pins). The raw curve tracks the
  /// foot EXACTLY but its velocity is non-constant (fast at toe-off, slow at each
  /// contact) — pinning the foot perfectly makes the BODY lurch twice per cycle.
  /// So the per-step velocity is **low-pass smoothed** (periodically): the body
  /// travels smoothly while the foot still pins to within the smoothing residual
  /// (a few px). The total per-cycle advance is preserved (smoothing conserves
  /// the sum), so the loop stays seamless.
  _LocoTable _buildLocoTable(Clip clip) {
    const n = 240;
    final rootId = rig.bones.firstWhere((b) => b.parent == null).id;

    double legSweep(String foot, double p) {
      final world = solver.solve(evaluator.evaluate(clip, p * clip.duration));
      return world[foot]!.transformPoint(0, 0).x -
          world[rootId]!.transformPoint(0, 0).x;
    }

    String footAt(double p) {
      for (final s in clip.groundSpans) {
        if (p >= s.start && p < s.end) return s.bone;
      }
      return clip.groundSpans.last.bone;
    }

    // 1. Raw per-step travel velocity (delta[i] = advance from i/n to (i+1)/n).
    final delta = List<double>.filled(n, 0);
    var prevFoot = footAt(0);
    var prevSweep = legSweep(prevFoot, 0);
    for (var i = 0; i < n; i++) {
      final p = (i + 1) / n;
      final foot = footAt(p >= 1 ? 0.999999 : p);
      if (foot == prevFoot) {
        delta[i] = legSweep(foot, p) - prevSweep;
        prevSweep += delta[i];
      } else {
        // Handoff: continue position; start tracking the new (just-planted) foot.
        prevFoot = foot;
        prevSweep = legSweep(foot, p);
      }
    }
    // 2. Periodic low-pass on the velocity — this is what turns the per-contact
    //    lurch into a smooth travel. The owner prefers smooth over pixel-pinned,
    //    so the window is generous.
    final smooth = _smoothPeriodic(delta, window: 46, passes: 3);
    // 3. Re-integrate into the cumulative offset table.
    final samples = List<double>.filled(n + 1, 0);
    for (var i = 0; i < n; i++) {
      samples[i + 1] = samples[i] + smooth[i];
    }
    return _LocoTable(samples, samples[n]);
  }

  /// Box-filter low-pass over a periodic (wrapping) signal, applied [passes]
  /// times. Conserves the sum (so the integrated travel keeps its total stride).
  static List<double> _smoothPeriodic(
    List<double> v, {
    required int window,
    int passes = 1,
  }) {
    final n = v.length;
    var cur = v;
    for (var pass = 0; pass < passes; pass++) {
      final next = List<double>.filled(n, 0);
      for (var i = 0; i < n; i++) {
        var sum = 0.0;
        for (var k = -window; k <= window; k++) {
          sum += cur[((i + k) % n + n) % n];
        }
        next[i] = sum / (2 * window + 1);
      }
      cur = next;
    }
    return cur;
  }

  /// Distance (in local units) from the rig origin down to the lowest drawn
  /// pixel of the **rest** pose — i.e. how far the feet sit below the hips.
  /// Used to ground the character so the feet land on the floor instead of the
  /// origin (which would push the legs off the bottom of the canvas).
  late final double restFeetOffset = lowestDrawnY(
    solver.solve(const Pose(joints: {})),
  );

  /// The lowest drawn world-Y across all parts for a solved [world] — a proxy
  /// for where the feet currently are. Drives both rest grounding and the live
  /// contact shadow (which shrinks/fades as the feet lift off the floor).
  double lowestDrawnY(Map<String, Affine2D> world) {
    var maxY = double.negativeInfinity;
    for (final bone in rig.bones) {
      final d = bone.drawable;
      if (d == null) continue;
      // Bottom-centre of the drawable, in the bone's local space, mapped to
      // world. A good proxy for the lowest painted pixel of that part.
      final p = world[bone.id]!.transformPoint(d.dx, d.dy + d.height / 2);
      if (p.y > maxY) maxY = p.y;
    }
    return maxY;
  }

  /// Resolves the frame for [clip] at [timeSeconds]. [expression] sets the base
  /// emotion (blink/eye-darts are layered on top); [base] places the character
  /// in the target canvas.
  ///
  /// [eyeOpenScale] further multiplies eyelid openness (1 = no change, 0 =
  /// shut). It composes with the autonomic blink and lets a caller drive a
  /// *manual* blink (the demo's blink button / keyboard) without disturbing the
  /// deterministic autonomic schedule.
  CharacterFrame frameAt({
    required Clip clip,
    required double timeSeconds,
    Expression expression = Expression.neutral,
    Affine2D base = Affine2D.identity,
    double eyeOpenScale = 1,
  }) {
    final auto = autonomic.sampleAt(timeSeconds);
    final posed = _resolvedPose(
      clip,
      timeSeconds,
      breath: auto.breath,
      earTwitchLeft: auto.earTwitchLeft,
      earTwitchRight: auto.earTwitchRight,
    );

    final rawWorld = solver.solve(posed, base: base);
    final footStabilizedWorld = _danceSupportFootStabilizedWorld(
      clip,
      timeSeconds,
      rawWorld,
    );
    final world = _rigidHeadWorld(
      clip,
      footStabilizedWorld,
      timeSeconds: timeSeconds,
      baseScale: _verticalScale(base),
      rootDx: posed.rootDx,
      rootDy: posed.rootDy,
    );
    var face = faceSolver.applyAutonomic(expression.state, auto);
    if (eyeOpenScale != 1) {
      face = face.copyWith(
        eyeOpenLeft: face.eyeOpenLeft * eyeOpenScale,
        eyeOpenRight: face.eyeOpenRight * eyeOpenScale,
      );
    }
    final locomotion = locomotionOffset(clip, timeSeconds);
    return CharacterFrame(world: world, face: face, locomotionX: locomotion);
  }

  /// Returns the final local-space pose that [frameAt] will solve and draw.
  ///
  /// Validators use this instead of raw clip sampling so runtime correctives
  /// such as shoulder-girdle response are checked against rendered behavior.
  Pose poseAt({
    required Clip clip,
    required double timeSeconds,
    bool includeAutonomic = true,
  }) {
    if (!includeAutonomic) {
      return _resolvedPose(clip, timeSeconds, breath: 0);
    }
    // (see also [preClampPoseAt] for the joint-limit engagement meter)
    final auto = autonomic.sampleAt(timeSeconds);
    return _resolvedPose(
      clip,
      timeSeconds,
      breath: auto.breath,
      earTwitchLeft: auto.earTwitchLeft,
      earTwitchRight: auto.earTwitchRight,
    );
  }

  /// The pose as it stands going INTO the joint-limits clamp — what the clip
  /// and solvers actually asked for. The motion validator diffs this against
  /// [poseAt] to measure LIMIT ENGAGEMENT: any difference means the routine
  /// leaned on the runtime limiter (clipping) instead of being authored
  /// inside the anatomical range, and should be re-choreographed.
  Pose preClampPoseAt({required Clip clip, required double timeSeconds}) {
    final pose = evaluator.evaluate(clip, timeSeconds);
    final context = PoseModifierContext(
      clip: clip,
      timeSeconds: timeSeconds,
      breath: 0,
    );
    return _poseModifierStack.apply(
      context,
      pose,
      stopBefore: 'joint-limits',
    );
  }

  Pose _resolvedPose(
    Clip clip,
    double timeSeconds, {
    required double breath,
    double earTwitchLeft = 0,
    double earTwitchRight = 0,
  }) {
    final pose = evaluator.evaluate(clip, timeSeconds);
    final context = PoseModifierContext(
      clip: clip,
      timeSeconds: timeSeconds,
      breath: breath,
      earTwitchLeft: earTwitchLeft,
      earTwitchRight: earTwitchRight,
    );
    return _poseModifierStack.apply(context, pose);
  }

  Pose _breathingPose(double breath, Pose pose) {
    if (breath == 0) return pose;
    return Pose(
      joints: pose.joints,
      rootDx: pose.rootDx,
      rootDy: pose.rootDy + breath * 1.4,
      rootRotation: pose.rootRotation,
    );
  }

  Pose _secondaryFollowPose(Clip clip, double timeSeconds, Pose pose) {
    if (!_isDanceFamily(clip) || clip.duration <= 0) return pose;

    final tailIds = _tailBoneIds();
    final earIds = _outerEarBoneIds();
    if (tailIds.isEmpty && earIds.isEmpty) return pose;

    final dt = clip.duration / 64;
    final previous = evaluator.evaluate(clip, timeSeconds - dt);
    final next = evaluator.evaluate(clip, timeSeconds + dt);
    final lateralVelocity = (next.rootDx - previous.rootDx) * 0.5;
    final verticalImpulse = previous.rootDy - 2 * pose.rootDy + next.rootDy;
    final bodyRotation =
        pose.rootRotation +
        _jointRotationForAny(pose, const ['hips', 'pelvis']) * 0.4 +
        _jointRotationForAny(pose, const ['torso', 'chest']) * 0.3;
    final followDrive =
        (-lateralVelocity * 0.014) -
        bodyRotation * 0.28 +
        verticalImpulse * 0.006;
    if (followDrive.abs() < 0.0001) return pose;

    final phase = _clipPhase(clip, timeSeconds);
    final joints = Map<String, JointPose>.of(pose.joints);
    var changed = false;

    for (var i = 0; i < tailIds.length; i++) {
      final t = tailIds.length == 1 ? 1.0 : i / (tailIds.length - 1);
      final lag = _clampMagnitude(followDrive * (0.08 + 0.96 * t), 0.065);
      final ripple =
          math.sin(2 * math.pi * (phase * 4 - t * 0.18)) *
          followDrive.abs() *
          (0.04 + 0.28 * t);
      final delta = lag + ripple;
      if (delta.abs() < 0.0001) continue;
      joints[tailIds[i]] = _addJointRotation(pose.jointOf(tailIds[i]), delta);
      changed = true;
    }

    final earDrive = _clampMagnitude(
      followDrive * 0.34 + lateralVelocity * 0.0025,
      0.024,
    );
    for (final earId in earIds) {
      final side = _sideSign(earId);
      final sidePhase = side >= 0 ? 0.13 : 0.63;
      final flick =
          math.sin(2 * math.pi * (phase * 4 + sidePhase)) *
          followDrive.abs() *
          0.18;
      // The TIP lags and whips well past the base — the tail's gradient,
      // in miniature: bendy cartilage, not a stiff felt triangle.
      final isTip = earId.toLowerCase().contains('tip');
      final gain = isTip ? 2.6 : 1.0;
      final clampAt = isTip ? 0.2 : 0.06;
      final delta = _clampMagnitude(side * earDrive * gain + flick * gain, clampAt);
      if (delta.abs() < 0.0001) continue;
      joints[earId] = _addJointRotation(pose.jointOf(earId), delta);
      changed = true;
    }

    if (!changed) return pose;
    return Pose(
      joints: joints,
      rootDx: pose.rootDx,
      rootDy: pose.rootDy,
      rootRotation: pose.rootRotation,
    );
  }

  /// Distributes the clip's authored `torso` (lumbar) rotation up the spine.
  ///
  /// Clips keep authoring one trunk channel; this pass hands [_kThoracicShare]
  /// of that rotation to the thoracic `chest` joint, sampled with a slight lag
  /// on looping clips so the ribcage/shoulder mass follows through behind the
  /// pelvis. The summed world orientation at the shoulders stays what the clip
  /// authored (exactly so when the lag is zero) — the trunk now *bends* through
  /// two centres instead of swinging as one rigid plate. Rigs without a chest
  /// bone are untouched.
  Pose _spineDistributedPose(Clip clip, double timeSeconds, Pose pose) {
    final chestId = _chestBoneId;
    if (chestId == null) return pose;
    final torsoId = rig.bone(chestId)!.parent!;
    final authored = pose.jointOf(torsoId);

    final lag = clip.loop && clip.duration > 0
        ? clip.duration / 32
        : 0.0;
    final source = lag > 0
        ? evaluator.evaluate(clip, timeSeconds - lag).jointOf(torsoId).rotation
        : authored.rotation;
    final chestDelta = _kThoracicShare * source;
    final torsoRotation = authored.rotation * (1 - _kThoracicShare);
    if (chestDelta.abs() < 0.0001 &&
        (authored.rotation - torsoRotation).abs() < 0.0001) {
      return pose;
    }

    final joints = Map<String, JointPose>.of(pose.joints);
    joints[torsoId] = JointPose(
      rotation: torsoRotation,
      scaleX: authored.scaleX,
      scaleY: authored.scaleY,
    );
    joints[chestId] = _addJointRotation(pose.jointOf(chestId), chestDelta);
    return Pose(
      joints: joints,
      rootDx: pose.rootDx,
      rootDy: pose.rootDy,
      rootRotation: pose.rootRotation,
    );
  }

  /// Fraction of the authored trunk rotation carried by the thoracic joint.
  static const double _kThoracicShare = 0.45;

  /// Shoulders answer the trunk a beat late: the clavicles pick up a clamped
  /// share of how much the trunk has MOVED over the last [_girdleLagFraction]
  /// of the clip (a lagged difference — pure in time, so film strips stay
  /// deterministic). When the chest whips into a new direction the shoulder
  /// line trails and catches up, instead of the whole girdle arriving with the
  /// trunk like a welded plate. Composes with authored clavicle keys and the
  /// raised-arm shrug ([_shoulderCorrectedPose]).
  Pose _girdleFollowPose(Clip clip, double timeSeconds, Pose pose) {
    if (!_isDanceFamily(clip) || clip.duration <= 0) return pose;
    final clavicleIds = _clavicleBoneIds;
    if (clavicleIds.isEmpty) return pose;

    final lag = clip.duration * _girdleLagFraction;
    final delta = _clampMagnitude(
      (_trunkDriveEstimate(clip, timeSeconds - lag) -
              _trunkDriveEstimate(clip, timeSeconds)) *
          0.35,
      0.045,
    );
    if (delta.abs() < 0.0005) return pose;

    final joints = Map<String, JointPose>.of(pose.joints);
    for (final clavicleId in clavicleIds) {
      joints[clavicleId] = _addJointRotation(pose.jointOf(clavicleId), delta);
    }
    return Pose(
      joints: joints,
      rootDx: pose.rootDx,
      rootDy: pose.rootDy,
      rootRotation: pose.rootRotation,
    );
  }

  static const double _girdleLagFraction = 1 / 24;

  /// The head trails a touch longer than the shoulders — the follow-through
  /// travels UP the body (trunk → girdle → skull), each stage a little later.
  static const double _headLagFraction = 1 / 16;

  late final List<String> _clavicleBoneIds = [
    for (final bone in rig.bones)
      if (bone.id.toLowerCase().contains('clavicle')) bone.id,
  ];

  /// Cheap estimate of the trunk's world bank at [timeSeconds], straight from
  /// the raw clip pose (no FK solve): the rotation chain that reaches the neck
  /// root. Used by the lagged-difference follow terms (girdle, head), where
  /// only the CHANGE of bank over a short lag matters.
  double _trunkDriveEstimate(Clip clip, double timeSeconds) {
    final pose = evaluator.evaluate(clip, timeSeconds);
    return pose.rootRotation +
        _jointRotationForAny(pose, const ['hips', 'pelvis']) +
        _jointRotationForAny(pose, const ['torso', 'chest']);
  }

  /// The thoracic spine bone: a child of the torso whose id names the chest.
  late final String? _chestBoneId = () {
    for (final bone in rig.bones) {
      if (bone.parent != null && bone.id.toLowerCase().contains('chest')) {
        return bone.id;
      }
    }
    return null;
  }();

  /// Rotates the clavicle toward a raised/wide hand target before IK solves
  /// the elbow and wrist — the shoulder girdle shrugging with the reach, which
  /// carries the deltoid, armhole, and sleeve root along.
  ///
  /// This is the ONLY girdle corrective now. The old pass additionally
  /// inflated socket/bicep scales per pose to patch hand-authored sleeve
  /// meshes whose profile collapsed outside their tuned range; the ribbon
  /// sleeve keeps its anatomical width profile in every pose, so no fabric
  /// inflation exists anymore.
  /// Autonomic ear twitches: a quick flick-and-settle on the ear TIP (with a
  /// small echo at the base), each ear on its own sparse schedule. Runs for
  /// every clip — an idle cat that never flicks an ear reads as a plush toy.
  Pose _earLifePose(PoseModifierContext context, Pose pose) {
    if (context.earTwitchLeft <= 0 && context.earTwitchRight <= 0) return pose;
    final joints = Map<String, JointPose>.of(pose.joints);
    var changed = false;
    void twitch(String tipToken, double pulse, double side) {
      if (pulse <= 0) return;
      for (final bone in rig.bones) {
        final id = bone.id.toLowerCase();
        if (!id.contains('ear')) continue;
        final isTip = id.contains('tip');
        final suffixMatch = tipToken == '.l'
            ? id.endsWith('.l')
            : id.endsWith('.r');
        if (!suffixMatch || id.contains('inner')) continue;
        final delta = side * pulse * (isTip ? 0.24 : 0.07);
        joints[bone.id] = _addJointRotation(pose.jointOf(bone.id), delta);
        changed = true;
      }
    }

    twitch('.l', context.earTwitchLeft, -1);
    twitch('.r', context.earTwitchRight, 1);
    if (!changed) return pose;
    return Pose(
      joints: joints,
      rootDx: pose.rootDx,
      rootDy: pose.rootDy,
      rootRotation: pose.rootRotation,
    );
  }

  Pose _shoulderCorrectedPose(Clip clip, double timeSeconds, Pose pose) {
    if (clip.limbTargets.isEmpty) return pose;

    final phase = evaluator.phaseAt(clip, timeSeconds);
    final joints = Map<String, JointPose>.of(pose.joints);
    var changed = false;

    for (final target in clip.limbTargets) {
      if (!_isHandBone(target.endBoneId)) continue;
      final sample = target.channel.sample(phase);
      final weight = sample.weight.clamp(0.0, 1.0);
      if (weight <= 0) continue;

      final engagement = _shoulderCorrectiveEngagement(sample) * weight;
      if (engagement <= 0) continue;

      final upper = rig.bone(target.upperBoneId);
      if (upper == null || upper.parent == null) continue;
      final side = _sideSign(target.endBoneId);
      if (side == 0) continue;

      // Only a real girdle bone may shrug. In a rig whose arm hangs straight
      // off the trunk there is nothing anatomical to rotate — and the motion
      // validator should keep flagging that rig, not have this pass twist the
      // trunk to fake a response.
      final clavicleId = upper.parent!;
      if (!clavicleId.toLowerCase().contains('clavicle')) continue;
      joints[clavicleId] = _ensureSignedRotation(
        pose: joints[clavicleId] ?? JointPose.identity,
        signedRotation: side * 0.13 * engagement,
      );
      changed = true;
    }

    if (!changed) return pose;
    return Pose(
      joints: joints,
      rootDx: pose.rootDx,
      rootDy: pose.rootDy,
      rootRotation: pose.rootRotation,
    );
  }

  Pose _limbTargetedPose(Clip clip, double timeSeconds, Pose pose) {
    if (clip.limbTargets.isEmpty) return pose;

    final phase = evaluator.phaseAt(clip, timeSeconds);
    final joints = Map<String, JointPose>.of(pose.joints);
    var currentPose = pose;

    // Opt-in (per [Clip.supportFootWorldAnchor]): hold the active support foot
    // toward its planted world position so the body grooves over it.
    final footAnchor = _supportFootWorldAnchor(clip, phase);

    for (final target in clip.limbTargets) {
      final sample = target.channel.sample(phase);
      final weight = sample.weight.clamp(0.0, 1.0);
      if (weight <= 0) continue;

      final planted = footAnchor != null && target.endBoneId == footAnchor.bone;
      final solved = _solveLimbTarget(
        target,
        sample,
        currentPose,
        weight,
        worldAnchor: planted ? (x: footAnchor.x, y: footAnchor.y) : null,
        anchorBlend: planted ? footAnchor.blend : 0,
      );
      if (solved == null) continue;

      void commitSolution(({JointPose upper, JointPose lower}) solution) {
        joints[target.upperBoneId] = solution.upper;
        joints[target.lowerBoneId] = solution.lower;
        currentPose = Pose(
          joints: joints,
          rootDx: pose.rootDx,
          rootDy: pose.rootDy,
          rootRotation: pose.rootRotation,
        );
      }

      commitSolution(solved);

      // Full-strength targets are choreographic controls, not soft hints. Run a
      // single corrective pass from the just-updated pose so wrists/feet land
      // closer to their controls when parent rotations and support anchors have
      // moved the chain during the first solve.
      if (weight >= 0.98 && target.anchorBoneId != target.upperBoneId) {
        final refined = _solveLimbTarget(
          target,
          sample,
          currentPose,
          weight,
          worldAnchor: planted ? (x: footAnchor.x, y: footAnchor.y) : null,
          anchorBlend: planted ? footAnchor.blend : 0,
        );
        if (refined != null) {
          commitSolution(refined);
        }
      }

    }

    return currentPose;
  }

  /// Pulls the pelvis back inside a plausible support envelope before foot IK.
  ///
  /// Translating the final solved world would move the support foot and pelvis
  /// together, so it would not fix balance. Applying this as a root-bias before
  /// [LimbIkTarget] support anchoring lets the stance leg bend against the planted
  /// foot while the upper body comes back over the base of support.
  Pose _supportBalancedPose(Clip clip, double timeSeconds, Pose pose) {
    final transition = clip.transitionPlan;
    if (transition != null) {
      return _transitionSupportBalancedPose(
        clip,
        timeSeconds,
        pose,
        transition,
      );
    }
    if (!_isDanceFamily(clip) ||
        !clip.supportFootWorldAnchor ||
        clip.contactSpans.isEmpty) {
      return pose;
    }
    final phase = _clipPhase(clip, timeSeconds);
    final contact = _activeContactAt(clip, phase);
    if (contact == null) return pose;

    final anchorPose = evaluator.evaluate(
      clip,
      contact.anchorPhase * clip.duration,
    );
    final anchorWorld = solver.solve(anchorPose);
    final support = _contactPoint(anchorWorld, contact.span.bone);
    if (support == null) return pose;

    final rootId = rig.bones.firstWhere((bone) => bone.parent == null).id;
    final currentWorld = solver.solve(pose);
    final hip = currentWorld[rootId]?.origin;
    if (hip == null) return pose;

    final delta = hip.x - support.x;
    final envelope = _supportComEnvelope(clip, contact.span);
    if (delta.abs() <= envelope) return pose;

    final targetDelta = delta < 0 ? -envelope : envelope;
    final blend = _supportComBlend(clip, contact.span, contact.strengthPhase);
    if (blend <= 0) return pose;

    return Pose(
      joints: pose.joints,
      rootDx: pose.rootDx + (targetDelta - delta) * blend,
      rootDy: pose.rootDy,
      rootRotation: pose.rootRotation,
    );
  }

  Pose _transitionSupportBalancedPose(
    Clip clip,
    double timeSeconds,
    Pose pose,
    ClipTransitionPlan transition,
  ) {
    final p = _clipPhase(clip, timeSeconds);
    final weight = _smoothUnit(transition.weight);
    final dx =
        _supportBalanceRootDelta(
          source: transition.from,
          phase: p,
          pose: pose,
          scale: 1 - weight,
        ) +
        _supportBalanceRootDelta(
          source: transition.to,
          phase: p,
          pose: pose,
          scale: weight,
        );
    if (dx.abs() < 0.001) return pose;
    return Pose(
      joints: pose.joints,
      rootDx: pose.rootDx + dx,
      rootDy: pose.rootDy,
      rootRotation: pose.rootRotation,
    );
  }

  double _supportBalanceRootDelta({
    required Clip source,
    required double phase,
    required Pose pose,
    required double scale,
  }) {
    if (scale <= 0 ||
        !_isDanceFamily(source) ||
        !source.supportFootWorldAnchor ||
        source.contactSpans.isEmpty) {
      return 0;
    }
    final contact = _activeContactAt(source, phase);
    if (contact == null) return 0;

    final anchorPose = evaluator.evaluate(
      source,
      contact.anchorPhase * source.duration,
    );
    final anchorWorld = solver.solve(anchorPose);
    final support = _contactPoint(anchorWorld, contact.span.bone);
    if (support == null) return 0;

    final rootId = rig.bones.firstWhere((bone) => bone.parent == null).id;
    final currentWorld = solver.solve(pose);
    final hip = currentWorld[rootId]?.origin;
    if (hip == null) return 0;

    final delta = hip.x - support.x;
    final envelope = _supportComEnvelope(source, contact.span);
    if (delta.abs() <= envelope) return 0;

    final targetDelta = delta < 0 ? -envelope : envelope;
    final blend =
        _supportComBlend(source, contact.span, contact.strengthPhase) * scale;
    return (targetDelta - delta) * blend;
  }

  ({JointPose upper, JointPose lower})? _solveLimbTarget(
    LimbIkTarget target,
    IkTargetPose sample,
    Pose pose,
    double weight, {
    ({double x, double y})? worldAnchor,
    double anchorBlend = 0,
  }) {
    final upper = rig.bone(target.upperBoneId);
    final lower = rig.bone(target.lowerBoneId);
    final end = rig.bone(target.endBoneId);
    final anchor = rig.bone(target.anchorBoneId);
    if (upper == null || lower == null || end == null || anchor == null) {
      return null;
    }
    if (lower.parent != upper.id || end.parent != lower.id) return null;

    final world = solver.solve(pose);
    final upperWorld = world[upper.id];
    final lowerWorld = world[lower.id];
    final endWorld = world[end.id];
    final anchorWorld = world[anchor.id];
    if (upperWorld == null ||
        lowerWorld == null ||
        endWorld == null ||
        anchorWorld == null) {
      return null;
    }

    final shoulder = upperWorld.origin;
    final elbow = lowerWorld.origin;
    final wrist = endWorld.origin;
    final authoredTarget = anchorWorld.transformPoint(sample.x, sample.y);
    // A PLANTED support foot blends its IK target toward a fixed [worldAnchor]
    // so the leg bends to absorb the body's groove while the foot stays put
    // (instead of the foot dragging with the hips). [anchorBlend] fades to 0 at
    // the support handoff; it is gentle by design so the natural stance width is
    // preserved (a hard hold narrows the astride into a leg-tangle).
    final targetPoint = worldAnchor == null || anchorBlend <= 0
        ? authoredTarget
        : (
            x:
                authoredTarget.x +
                (worldAnchor.x - authoredTarget.x) * anchorBlend,
            y:
                authoredTarget.y +
                (worldAnchor.y - authoredTarget.y) * anchorBlend,
          );
    final solution = solveTwoBoneIk(
      shoulderX: shoulder.x,
      shoulderY: shoulder.y,
      targetX: targetPoint.x,
      targetY: targetPoint.y,
      upperLength: _pointDistance(shoulder, elbow),
      lowerLength: _pointDistance(elbow, wrist),
      bendDirection: target.bendDirection.toDouble(),
    );
    if (solution == null) return null;
    final upperSegmentAngle = solution.upperAngle;
    final lowerSegmentAngle = solution.lowerAngle;

    final parentRotation = _parentWorldRotation(world, upper, pose);
    final upperTargetRotation =
        upperSegmentAngle -
        parentRotation -
        upper.restRotation -
        _localPivotAngle(lower);
    final upperTransformRotation =
        parentRotation + upper.restRotation + upperTargetRotation;
    final lowerTargetRotation =
        lowerSegmentAngle -
        upperTransformRotation -
        lower.restRotation -
        _localPivotAngle(end);
    final currentUpper = pose.jointOf(upper.id);
    final currentLower = pose.jointOf(lower.id);

    return (
      upper: JointPose(
        rotation: _lerpAngle(
          currentUpper.rotation,
          upperTargetRotation,
          weight,
        ),
        scaleX: currentUpper.scaleX,
        scaleY: currentUpper.scaleY,
      ),
      lower: JointPose(
        rotation: _lerpAngle(
          currentLower.rotation,
          lowerTargetRotation,
          weight,
        ),
        scaleX: currentLower.scaleX,
        scaleY: currentLower.scaleY,
      ),
    );
  }

  double _parentWorldRotation(
    Map<String, Affine2D> world,
    Bone bone,
    Pose pose,
  ) {
    final parentId = bone.parent;
    if (parentId == null) return pose.rootRotation;
    // Bones are solved in topological order, so a non-root bone's parent world
    // transform is always present by the time we read it here.
    return _worldRotation(world[parentId]!);
  }

  double _localPivotAngle(Bone child) => math.atan2(child.pivotY, child.pivotX);

  double _pointDistance(({double x, double y}) a, ({double x, double y}) b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  double _lerpAngle(double from, double to, double weight) =>
      from + _shortestAngle(to - from) * weight;

  /// The body can squash, stretch, and groove; the skull should not. Because
  /// the Phase-1 rig is a parented skeleton, torso scale would otherwise
  /// propagate into the head/ears and make the face look rubbery. Replace the
  /// head subtree's linear transform with a rigid, uniform-scale transform while
  /// preserving the solved neck position. Dance additionally counter-rotates a
  /// little so the face stays controlled while the chest moves underneath it.
  Map<String, Affine2D> _rigidHeadWorld(
    Clip clip,
    Map<String, Affine2D> world, {
    required double timeSeconds,
    required double baseScale,
    required double rootDx,
    required double rootDy,
  }) {
    final headId = rig.face?.anchorBoneId;
    if (headId == null) return world;
    if (!world.containsKey(headId)) return world;

    final headWorld = world[headId]!;
    final headRotation = _worldRotation(headWorld);
    final danceAttitude = _isDanceFamily(clip)
        ? _danceHeadAttitude(_clipPhase(clip, timeSeconds)) *
              clip.danceHeadBobScale
        : 0.0;
    // Let the skull keep a SLICE of the torso's natural bank instead of nailing
    // it bolt-upright: removing 0.92 of the rotation froze the head so rigidly
    // that on the big-sway clips (shaku) the body read as a pendulum swinging
    // under a fixated head. Keeping ~26% of the lean lets the head ride WITH the
    // body — still damped well under the "subtle wobble" bound, but no longer a
    // fixed pivot the torso dangles from.
    //
    // On top of the damped ride, the head FOLLOWS THROUGH: a lagged-difference
    // term (trunk bank a moment ago minus now — pure in time, deterministic)
    // makes the skull trail the trunk into each direction change and catch up
    // after, the whip a dancer's head actually has, instead of arriving welded
    // to the chest.
    final headFollow = _isDanceFamily(clip) && clip.duration > 0
        ? _clampMagnitude(
            (_trunkDriveEstimate(
                      clip,
                      timeSeconds - clip.duration * _headLagFraction,
                    ) -
                    _trunkDriveEstimate(clip, timeSeconds)) *
                0.45 *
                clip.danceHeadBobScale,
            0.06,
          )
        : 0.0;
    final rotationCorrection = _isDanceFamily(clip)
        ? -headRotation * 0.74 + danceAttitude + headFollow
        : 0.0;
    final correction = _rigidLinearCorrection(
      headWorld,
      targetRotation: headRotation + rotationCorrection,
      targetScale: baseScale,
    );
    if (correction == null) {
      return world;
    }
    final anchor = headWorld.origin;
    final stabilizeHead = Affine2D.translation(
      anchor.x,
      anchor.y,
    ).multiply(correction).multiply(Affine2D.translation(-anchor.x, -anchor.y));
    // Lateral follow-through, same lagged-difference model as the rotation:
    // the skull trails the pelvis groove by a few px and catches up, so fast
    // side-to-side pockets read as a head riding a spring, not a bolted mass.
    // Clamped tight — the collar join must never gap.
    final headDxFollow = _isDanceFamily(clip) && clip.duration > 0
        ? _clampMagnitude(
            (evaluator
                        .evaluate(
                          clip,
                          timeSeconds - clip.duration * _headLagFraction,
                        )
                        .rootDx -
                    rootDx) *
                0.22,
            5,
          )
        : 0.0;
    final headCounterTranslate = _isDanceFamily(clip)
        ? Affine2D.translation(
            (_danceHeadHorizontalCounter(rootDx, clip.danceHeadBobScale) +
                    headDxFollow) *
                baseScale,
            _danceHeadVerticalCounter(rootDy, clip.danceHeadBobScale) *
                baseScale,
          )
        : Affine2D.identity;
    final headTransform = headCounterTranslate.multiply(stabilizeHead);
    final shifted = Map<String, Affine2D>.of(world);
    for (final bone in rig.bones) {
      if (bone.id == headId || _hasAncestor(bone.id, headId)) {
        shifted[bone.id] = headTransform.multiply(world[bone.id]!);
      }
    }
    return shifted;
  }

  double _danceHeadVerticalCounter(double rootDy, double headBobScale) {
    // The dance phrase gets its level change from knees/hips/torso. The head
    // must RIDE that level change with the collar, not hold still above it: the
    // old counter reached ~0.82 of the bob for a low-bob clip (shaku at scale
    // 0.2) and ~0.92 near scale 0, so when the body dropped in a knee-bend the
    // skull stayed put and a long orange throat opened under it — the head read
    // as loose / detached / unhealthy. The rigid (non-rubbery) read comes from
    // the uniform-scale + rotation correction, NOT this translate, so the
    // counter is kept light (the head tracks the collar) and CLAMPED so no
    // groove extreme can ever lift the skull off the neck.
    const neutralDanceRootDy = 17.4;
    final fraction = 0.14 + (1 - headBobScale) * 0.1;
    final counter = -(rootDy - neutralDanceRootDy) * fraction;
    // Negative = head rises (the float direction): bound it hard so the join
    // can never gap. Downward (head settling INTO the collar) is harmless, so
    // it is allowed a little more room.
    return counter.clamp(-2.0, 4.0);
  }

  double _danceHeadHorizontalCounter(double rootDx, double headBobScale) {
    // The deck/contact solver shifts the whole body to keep support feet
    // planted. Let the torso take that groove, but give the skull a light
    // inertial counter so it reads as a head riding a neck, not rubber. The
    // stiller-clip term (lower [headBobScale] → lag MORE) used to dominate
    // (0.45), which on shaku held the head back so hard the body swung under it
    // like a pendulum. Trimmed so a stiff clip lags only a little more than a
    // loose one: the head now travels WITH the pelvis, the join never gaps, and
    // the ears no longer fan as the onion "sweep" because the rotation pass —
    // not this translate — does the de-bobbling.
    const neutralDanceRootDx = 0.0;
    final fraction = 0.14 + (1 - headBobScale) * 0.20;
    return -(rootDx - neutralDanceRootDx) * fraction;
  }

  double _danceHeadAttitude(double p) {
    double pulse(double centre, double width) {
      final distance = _cyclicDistance(p, centre);
      if (distance >= width) return 0;
      final t = 1 - distance / width;
      return t * t * (3 - 2 * t);
    }

    // Small, deliberate accents only: enough for the head to answer the body,
    // not enough to return to the rubber bobble that the rigid pass removed.
    return -0.018 * pulse(1 / 8, 1 / 18) +
        0.018 * pulse(3 / 8, 1 / 18) -
        0.016 * pulse(5 / 8, 1 / 18) +
        0.022 * pulse(15 / 16, 1 / 16);
  }

  double _cyclicDistance(double a, double b) {
    final d = (a - b).abs();
    return math.min(d, 1 - d);
  }

  /// The base's VERTICAL axis scale — the head-normalization target.
  ///
  /// The trio's dance view folds a horizontal quarter-turn foreshorten into
  /// the base transform (x column scaled by 0.68 for flankers). Normalizing
  /// the head to the x-column norm shrank upstage heads UNIFORMLY to the
  /// foreshorten factor — small heads on full-height bodies, the "scales in
  /// the back are wrong" read. The y column carries the true plane scale
  /// (camera zoom, member scale) untouched by foreshorten or flip, so heads
  /// keep their plane's size while the body turns.
  static double _verticalScale(Affine2D transform) =>
      math.sqrt(transform.c * transform.c + transform.d * transform.d);

  Affine2D? _rigidLinearCorrection(
    Affine2D current, {
    required double targetRotation,
    required double targetScale,
  }) {
    final det = current.a * current.d - current.b * current.c;
    if (det.abs() < 1e-9 || targetScale <= 0) return null;
    final handedness = det < 0 ? -1.0 : 1.0;
    final cos = math.cos(targetRotation);
    final sin = math.sin(targetRotation);
    final desired = Affine2D(
      cos * targetScale,
      sin * targetScale,
      -sin * targetScale * handedness,
      cos * targetScale * handedness,
      0,
      0,
    );
    final inv = Affine2D(
      current.d / det,
      -current.b / det,
      -current.c / det,
      current.a / det,
      0,
      0,
    );
    final correction = desired.multiply(inv);
    if ((correction.a - 1).abs() < 0.001 &&
        correction.b.abs() < 0.001 &&
        correction.c.abs() < 0.001 &&
        (correction.d - 1).abs() < 0.001) {
      return null;
    }
    return correction;
  }

  double _worldRotation(Affine2D transform) =>
      math.atan2(transform.b, transform.a);

  /// The contact-lock pins the support point, but the shoe can still rotate
  /// through the planted frames as the leg keys keep moving. That reads as
  /// sliding on a deck. During the stable middle of a dance contact, keep the
  /// support foot's world orientation close to its contact-frame orientation,
  /// rotating only the foot subtree around the already-planted contact point.
  Map<String, Affine2D> _danceSupportFootStabilizedWorld(
    Clip clip,
    double timeSeconds,
    Map<String, Affine2D> world,
  ) {
    if (!_isDanceFamily(clip)) return world;
    final contact = _activeContactAt(clip, _clipPhase(clip, timeSeconds));
    if (contact == null) return world;
    final boneId = contact.span.bone;
    final current = world[boneId];
    final contactPoint = _contactPoint(world, boneId);
    if (current == null || contactPoint == null) return world;

    final anchorPose = evaluator.evaluate(
      clip,
      contact.anchorPhase * clip.duration,
    );
    final anchorWorld = solver.solve(anchorPose);
    final anchor = anchorWorld[boneId];
    if (anchor == null) return world;

    final contactStrength = _contactLockStrength(
      clip,
      contact.span,
      contact.strengthPhase,
    ).x;
    final strength = _isDanceFamily(clip)
        ? math.min(1, contactStrength * 1.35)
        : contactStrength;
    if (strength < 0.05) return world;

    final delta = _shortestAngle(
      _worldRotation(anchor) - _worldRotation(current),
    );
    if (delta.abs() < 0.01) return world;

    final correction = Affine2D.translation(contactPoint.x, contactPoint.y)
        .multiply(Affine2D.rotation(delta * strength))
        .multiply(Affine2D.translation(-contactPoint.x, -contactPoint.y));
    final shifted = Map<String, Affine2D>.of(world);
    for (final bone in rig.bones) {
      if (bone.id == boneId || _hasAncestor(bone.id, boneId)) {
        shifted[bone.id] = correction.multiply(world[bone.id]!);
      }
    }
    return shifted;
  }

  double _shortestAngle(double radians) =>
      math.atan2(math.sin(radians), math.cos(radians));

  bool _hasAncestor(String boneId, String ancestorId) {
    var parent = rig.bone(boneId)?.parent;
    while (parent != null) {
      if (parent == ancestorId) return true;
      parent = rig.bone(parent)?.parent;
    }
    return false;
  }

  double _shoulderCorrectiveEngagement(IkTargetPose sample) {
    // Ramp begins just below shoulder height so a hand AT the shoulder line
    // (y ≈ -60, where the motion validator starts expecting girdle response)
    // already carries a slight shrug, reaching the full response overhead.
    final raised = smoothstep((-sample.y - 34) / 56);
    final wideReach = smoothstep((sample.x.abs() - 62) / 34) * 0.55;
    return math.max(raised, wideReach).clamp(0.0, 1.0);
  }

  /// Nudges [pose]'s rotation to at least [signedRotation] in its direction,
  /// leaving any stronger same-direction authored rotation alone.
  JointPose _ensureSignedRotation({
    required JointPose pose,
    required double signedRotation,
  }) {
    var rotation = pose.rotation;
    if (signedRotation != 0 &&
        (rotation * signedRotation < 0 ||
            rotation.abs() < signedRotation.abs())) {
      rotation = signedRotation;
    }
    return JointPose(
      rotation: rotation,
      scaleX: pose.scaleX,
      scaleY: pose.scaleY,
    );
  }

  bool _isHandBone(String boneId) => boneId.toLowerCase().contains('hand');

  int _sideSign(String boneId) {
    if (boneId.endsWith('.L')) return 1;
    if (boneId.endsWith('.R')) return -1;
    return 0;
  }

  /// In-place performance clips do not locomote, but their support foot still
  /// needs to feel planted. [Clip.contactSpans] marks that support foot; this
  /// pass translates the root toward the contact-start anchor. Loops use a
  /// weaker correction than one-shots so dance contacts gain weight without
  /// snapping at support handoffs.
  Pose _contactLockedPose(Clip clip, double timeSeconds, Pose pose) {
    final transition = clip.transitionPlan;
    if (transition != null) {
      return _transitionContactLockedPose(clip, timeSeconds, pose, transition);
    }
    final p = _clipPhase(clip, timeSeconds);
    final contact = _activeContactAt(clip, p);
    if (contact == null) return pose;

    final span = contact.span;
    final anchorPose = evaluator.evaluate(
      clip,
      contact.anchorPhase * clip.duration,
    );
    final currentWorld = solver.solve(pose);
    final anchorWorld = solver.solve(anchorPose);
    final current = _contactPoint(currentWorld, span.bone);
    final anchor = _contactPoint(anchorWorld, span.bone);
    if (current == null || anchor == null) return pose;
    final strength = _contactLockStrength(clip, span, contact.strengthPhase);

    return Pose(
      joints: pose.joints,
      rootDx: pose.rootDx + (anchor.x - current.x) * strength.x,
      rootDy: pose.rootDy + (anchor.y - current.y) * strength.y,
      rootRotation: pose.rootRotation,
    );
  }

  Pose _transitionContactLockedPose(
    Clip clip,
    double timeSeconds,
    Pose pose,
    ClipTransitionPlan transition,
  ) {
    final p = _clipPhase(clip, timeSeconds);
    final weight = _smoothUnit(transition.weight);
    final outgoing = _contactLockRootDelta(
      source: transition.from,
      phase: p,
      pose: pose,
      scale: 1 - weight,
    );
    final incoming = _contactLockRootDelta(
      source: transition.to,
      phase: p,
      pose: pose,
      scale: weight,
    );
    final dx = outgoing.dx + incoming.dx;
    final dy = outgoing.dy + incoming.dy;
    if (dx.abs() < 0.001 && dy.abs() < 0.001) return pose;
    return Pose(
      joints: pose.joints,
      rootDx: pose.rootDx + dx,
      rootDy: pose.rootDy + dy,
      rootRotation: pose.rootRotation,
    );
  }

  ({double dx, double dy}) _contactLockRootDelta({
    required Clip source,
    required double phase,
    required Pose pose,
    required double scale,
  }) {
    if (scale <= 0 || source.contactSpans.isEmpty) {
      return (dx: 0.0, dy: 0.0);
    }
    final contact = _activeContactAt(source, phase);
    if (contact == null) return (dx: 0.0, dy: 0.0);

    final span = contact.span;
    final anchorPose = evaluator.evaluate(
      source,
      contact.anchorPhase * source.duration,
    );
    final currentWorld = solver.solve(pose);
    final anchorWorld = solver.solve(anchorPose);
    final current = _contactPoint(currentWorld, span.bone);
    final anchor = _contactPoint(anchorWorld, span.bone);
    if (current == null || anchor == null) return (dx: 0.0, dy: 0.0);
    final strength = _contactLockStrength(source, span, contact.strengthPhase);

    return (
      dx: (anchor.x - current.x) * strength.x * scale,
      dy: (anchor.y - current.y) * strength.y * scale,
    );
  }

  /// Bends the shoe at the ball of the foot — real soles flex when dancing.
  ///
  /// For each `toe_flex` joint (pivoted at the ball), the solved world pitch
  /// of its foot is measured. When the foot pitches TOE-DOWN (heel lifting)
  /// while the ball is still at floor height, the flex joint counter-rotates
  /// so the toe segment stays flat on the floor — the sole visibly curves
  /// through toe-offs and heel-toe knocks. The bend is weighted by the
  /// ball's proximity to the floor, so an airborne pointed toe keeps a
  /// straight sole, and it is one-sided: soles do not bend backwards on
  /// heel strikes. Pure in pose+rig (rig-space floor from [restFeetOffset]),
  /// so film strips stay deterministic.
  Pose _soleFlexedPose(Pose pose) {
    final flexIds = _toeFlexBoneIds;
    if (flexIds.isEmpty) return pose;

    final world = solver.solve(pose);
    Map<String, JointPose>? joints;

    // The GROUND this frame is wherever the lowest sole point stands — the
    // dance rides far below the rest-pose floor (root drop + contact locks),
    // so a fixed rest-floor reference never triggers on real dig frames.
    var frameFloorY = double.negativeInfinity;
    final tips = <String, ({double x, double y})>{};
    final heels = <String, ({double x, double y})>{};
    for (final flexId in flexIds) {
      final flexBone = rig.bone(flexId)!;
      final footWorld = world[flexBone.parent];
      final flexWorld = world[flexId];
      if (footWorld == null || flexWorld == null) continue;
      final tip = flexWorld.transformPoint(-12, 1);
      final heel = footWorld.transformPoint(8, 10);
      tips[flexId] = tip;
      heels[flexId] = heel;
      frameFloorY = math.max(frameFloorY, math.max(tip.y, heel.y));
    }

    for (final flexId in flexIds) {
      final flexBone = rig.bone(flexId)!;
      final footWorld = world[flexBone.parent];
      final tip = tips[flexId];
      final heel = heels[flexId];
      if (footWorld == null || tip == null || heel == null) continue;

      // Toe-down pitch: the foot's toe points local -x, so a NEGATIVE world
      // rotation drops the toe / raises the heel.
      final pitch = _worldRotation(footWorld);
      if (pitch >= -0.04) continue;

      // The toe must be the WEIGHT-BEARING end: lower than the heel and
      // near the frame's ground. An airborne pointed toe keeps its sole
      // straight; a dig or heel-lift bends it.
      if (tip.y <= heel.y + 2) continue;
      final gap = frameFloorY - tip.y;
      final proximity = (1 - gap / 18).clamp(0.0, 1.0);
      if (proximity <= 0) continue;

      final flex = (-pitch - 0.04) * 1.15 * proximity;
      final delta = flex.clamp(0.0, 0.8);
      if (delta < 0.01) continue;

      joints ??= Map<String, JointPose>.of(pose.joints);
      joints[flexId] = _addJointRotation(pose.jointOf(flexId), delta);
    }

    if (joints == null) return pose;
    return Pose(
      joints: joints,
      rootDx: pose.rootDx,
      rootDy: pose.rootDy,
      rootRotation: pose.rootRotation,
    );
  }

  late final List<String> _toeFlexBoneIds = [
    for (final bone in rig.bones)
      if (bone.id.toLowerCase().contains('toe_flex')) bone.id,
  ];

  /// Clamps every joint carrying a [JointRotationLimit] into its anatomical
  /// range — the last word after clips, IK, and correctives. A pose that
  /// violates a hinge (a backward knee, a wrap-around elbow) degrades to the
  /// nearest legal configuration instead of rendering the impossible.
  Pose _jointLimitedPose(Pose pose) {
    Map<String, JointPose>? joints;
    for (final bone in _limitedBones) {
      final limit = bone.rotationLimit!;
      final joint = pose.jointOf(bone.id);
      final clamped = limit.clampAngle(joint.rotation);
      if (clamped == joint.rotation) continue;
      joints ??= Map<String, JointPose>.of(pose.joints);
      joints[bone.id] = JointPose(
        rotation: clamped,
        scaleX: joint.scaleX,
        scaleY: joint.scaleY,
      );
    }
    if (joints == null) return pose;
    return Pose(
      joints: joints,
      rootDx: pose.rootDx,
      rootDy: pose.rootDy,
      rootRotation: pose.rootRotation,
    );
  }

  late final List<Bone> _limitedBones = [
    for (final bone in rig.bones)
      if (bone.rotationLimit != null) bone,
  ];

  double _clipPhase(Clip clip, double timeSeconds) {
    if (clip.duration <= 0) return 0;
    final raw = timeSeconds / clip.duration;
    return clip.loop ? raw - raw.floorToDouble() : raw.clamp(0.0, 1.0);
  }

  ({GroundSpan span, double anchorPhase, double strengthPhase})?
  _activeContactAt(Clip clip, double p) {
    if (clip.contactSpans.isEmpty) return null;
    final first = clip.contactSpans.first;
    final last = clip.contactSpans.last;
    if (clip.loop && first.bone == last.bone) {
      if (p >= last.start) {
        return (
          span: GroundSpan(last.bone, last.start, first.end + 1),
          anchorPhase: last.start,
          strengthPhase: p,
        );
      }
      if (p < first.end) {
        return (
          span: GroundSpan(first.bone, last.start, first.end + 1),
          anchorPhase: last.start,
          strengthPhase: p + 1,
        );
      }
    }
    for (final span in clip.contactSpans) {
      if (p >= span.start && p < span.end) {
        return (span: span, anchorPhase: span.start, strengthPhase: p);
      }
    }
    return (span: last, anchorPhase: last.start, strengthPhase: p);
  }

  /// The world-space origin of the active SUPPORT foot at the moment it planted
  /// (its contact-span start), plus a `blend` that fades to 0 at the span edges.
  /// Returns null unless the clip opts in via [Clip.supportFootWorldAnchor].
  ({String bone, double x, double y, double blend})? _supportFootWorldAnchor(
    Clip clip,
    double phase,
  ) {
    if (!clip.supportFootWorldAnchor || clip.contactSpans.isEmpty) return null;
    final contact = _activeContactAt(clip, phase);
    if (contact == null) return null;
    final span = contact.span;
    final anchorPose = evaluator.evaluate(
      clip,
      contact.anchorPhase * clip.duration,
    );
    final origin = solver.solve(anchorPose)[span.bone]?.origin;
    if (origin == null) return null;
    final blend = _supportFootAnchorBlend(
      span,
      contact.strengthPhase,
      clip.supportFootWorldAnchorStrength,
    );
    return (bone: span.bone, x: origin.x, y: origin.y, blend: blend);
  }

  /// Edge-faded strength for the world foot anchor. Deliberately GENTLE — a
  /// strong hold pulls the support foot to its plant point and collapses the
  /// astride stance; this damps the lateral skate while leaving most of the
  /// natural foot sweep (and thus the stance width) intact.
  double _supportFootAnchorBlend(
    GroundSpan span,
    double p,
    double strength,
  ) {
    final spanLength = span.end - span.start;
    final fade = (spanLength * 0.24).clamp(0.05, 0.09);
    final fadeIn = _smoothUnit((p - span.start) / fade);
    final fadeOut = _smoothUnit((span.end - p) / fade);
    final edge = fadeIn < fadeOut ? fadeIn : fadeOut;
    return strength * edge;
  }

  double _supportComEnvelope(Clip clip, GroundSpan span) {
    if (clip.name == 'zanku') return 46;
    if (clip.name == 'sekem') return 50;
    if (clip.name == 'buga') return 58;
    if (clip.name == 'azonto') return 58;
    if (clip.name == 'shaku' || clip.name.startsWith('danceBackup')) return 64;
    if (clip.name == 'pouncingCat') return 62;
    final spanLength = span.end - span.start;
    return spanLength <= 0.135 ? 50 : 62;
  }

  double _supportComBlend(Clip clip, GroundSpan span, double p) {
    final spanLength = span.end - span.start;
    final fade = (spanLength * 0.28).clamp(0.05, 0.1);
    final fadeIn = _smoothUnit((p - span.start) / fade);
    final fadeOut = _smoothUnit((span.end - p) / fade);
    final edge = fadeIn < fadeOut ? fadeIn : fadeOut;
    final base = spanLength <= 0.135
        ? 0.72
        : spanLength <= 0.26
        ? 0.58
        : (clip.name == 'shaku' || clip.name.startsWith('danceBackup'))
        ? 0.26
        : 0.42;
    return base * edge * clip.supportFootWorldAnchorStrength;
  }

  ({double x, double y}) _contactLockStrength(
    Clip clip,
    GroundSpan span,
    double p,
  ) {
    final dance = _isDanceFamily(clip);
    final spanLength = span.end - span.start;
    // A world-anchored support foot holds the IK endpoint, but the root still
    // needs enough horizontal correction for the pelvis to visibly load over
    // that planted shoe. Keep this below the non-anchored dance lock so stance
    // width and authored groove survive, but do not leave it at a token nudge:
    // mid-stance catalogue moves otherwise read as side-view toe skates. Short
    // per-beat plants can take a stronger hold than long Shaku/Azonto groove
    // spans, where too much correction whips the head laterally.
    final anchoredDanceBaseX = spanLength <= 0.135
        ? 0.38
        : spanLength <= 0.26
        ? 0.3
        : (clip.name == 'shaku' || clip.name.startsWith('danceBackup'))
        ? 0.16
        : 0.26;
    final baseX = clip.supportFootWorldAnchor
        ? (dance ? anchoredDanceBaseX : 0.18)
        : dance
        ? 0.55
        : (clip.loop ? 0.8 : 0.94);
    final baseY = dance ? 0.94 : (clip.loop ? 0.8 : 0.94);
    final fade = dance
        ? (spanLength * 0.24).clamp(0.044, 0.058)
        : (clip.loop ? (spanLength * 0.2).clamp(0.018, 0.035) : 0.08);
    final fadeIn = _smoothUnit((p - span.start) / fade);
    final fadeOut = _smoothUnit((span.end - p) / fade);
    final edge = fadeIn < fadeOut ? fadeIn : fadeOut;
    return (x: baseX * edge, y: baseY * edge);
  }

  double _smoothUnit(double t) {
    final x = t.clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }

  double _clampMagnitude(double value, double limit) =>
      value.clamp(-limit, limit);

  JointPose _addJointRotation(JointPose pose, double delta) => JointPose(
    rotation: pose.rotation + delta,
    scaleX: pose.scaleX,
    scaleY: pose.scaleY,
  );

  double _jointRotationForAny(Pose pose, List<String> boneIds) {
    for (final boneId in boneIds) {
      final joint = pose.joints[boneId];
      if (joint != null) return joint.rotation;
    }
    return 0;
  }

  List<String> _tailBoneIds() {
    final ids = [
      for (final bone in rig.bones)
        if (bone.id.toLowerCase().startsWith('tail')) bone.id,
    ]..sort((a, b) => _trailingIndex(a).compareTo(_trailingIndex(b)));
    return ids;
  }

  List<String> _outerEarBoneIds() => [
    for (final bone in rig.bones)
      if (_isOuterEarBone(bone.id)) bone.id,
  ];

  bool _isOuterEarBone(String boneId) {
    final id = boneId.toLowerCase();
    // Outer ear BASE and TIP joints both follow the groove (with different
    // gains); inner-ear detail shapes ride their parents.
    return id.contains('ear') && !id.contains('inner');
  }

  int _trailingIndex(String boneId) {
    var start = boneId.length;
    while (start > 0) {
      final unit = boneId.codeUnitAt(start - 1);
      if (unit < 0x30 || unit > 0x39) break;
      start--;
    }
    if (start == boneId.length) return 0;
    return int.tryParse(boneId.substring(start)) ?? 0;
  }

  bool _isDanceFamily(Clip clip) => clip.transitionPlan != null
      ? _isDanceFamily(clip.transitionPlan!.from) ||
            _isDanceFamily(clip.transitionPlan!.to)
      : clip.name == 'shaku' ||
            clip.name == 'zanku' ||
            clip.name == 'azonto' ||
            clip.name == 'buga' ||
            clip.name == 'pouncingCat' ||
            clip.name == 'sekem' ||
            clip.name.startsWith('danceBackup');

  ({double x, double y})? _contactPoint(
    Map<String, Affine2D> world,
    String boneId,
  ) {
    final transform = world[boneId];
    final drawable = rig.bone(boneId)?.drawable;
    if (transform == null || drawable == null) return null;
    return transform.transformPoint(
      drawable.dx,
      drawable.dy + drawable.height / 2,
    );
  }
}

/// A precomputed foot-lock travel curve: [samples] are the cumulative offset at
/// evenly spaced phases `i/(len-1)` across one cycle, [cycleAdvance] the total
/// per-cycle stride. Linear interpolation between samples.
class _LocoTable {
  _LocoTable(this.samples, this.cycleAdvance);

  final List<double> samples;
  final double cycleAdvance;

  double sample(double frac) {
    final n = samples.length - 1;
    final x = frac.clamp(0.0, 1.0) * n;
    final i = x.floor().clamp(0, n - 1);
    return samples[i] + (samples[i + 1] - samples[i]) * (x - i);
  }
}
