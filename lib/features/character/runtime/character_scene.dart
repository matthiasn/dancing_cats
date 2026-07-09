import 'dart:math' as math;

import 'package:dancing_cats/features/character/engine/autonomic.dart';
import 'package:dancing_cats/features/character/engine/clip_evaluator.dart';
import 'package:dancing_cats/features/character/engine/face_solver.dart';
import 'package:dancing_cats/features/character/engine/skeleton_solver.dart';
import 'package:dancing_cats/features/character/engine/two_bone_ik.dart';
import 'package:dancing_cats/features/character/model/affine2d.dart';
import 'package:dancing_cats/features/character/model/bone.dart';
import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/dance_dynamics.dart';
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
    this.zOrderSwaps = const [],
    this.occludedShades = const [],
  });

  final Map<String, Affine2D> world;
  final FaceState face;

  /// How far the character has travelled along x for this clip+time, in local
  /// units. Phase 1 deliberately animates in place (each film-strip cell is a
  /// phase sample, and the live widget loops on the spot), so **no caller wires
  /// this yet** — it is the kinematic hook the Phase-2 "walks across the screen"
  /// surface will fold into its placement transform.
  final double locomotionX;

  /// Bone id pairs that should swap paint order for this frame, resolved from
  /// the clip's [Clip.zOrderSwaps] at the current phase. Empty on almost
  /// every clip/frame — passed straight through to `CharacterRenderer.paint`'s
  /// `zOrderSwaps` parameter.
  final List<(String, String)> zOrderSwaps;

  /// Active `shadeBehind` requests for this frame: `(boneA, boneB, opacity)`
  /// for each z-swap window that asked the occluded bone be darkened. The
  /// renderer picks whichever of the pair ends up drawn behind and overlays a
  /// cool shadow at `opacity`. Empty on almost every clip/frame.
  final List<(String, String, double)> occludedShades;
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
        id: 'shoulder-line',
        description:
            'Drive the sternum-pivot shoulder-line levers from the clavicle '
            'drop and the solved humeral elevation. Runs after limb-ik so '
            'the levers respond to the IK-solved arm, and because they are '
            'render-only handles the solve itself is never disturbed.',
        modifier: (context, pose) =>
            _shoulderLinePose(context.clip, context.timeSeconds, pose),
      ),
      PoseModifierPass(
        id: 'overshoot-settle',
        description:
            'Add a decaying rotational settle after a hard authored stop on '
            'arm/torso channels, scaled to how fast the incoming motion was '
            'moving. Runs before joint-limits so the clamp remains the final '
            'safety net.',
        modifier: _overshootSettledPose,
      ),
      PoseModifierPass(
        id: 'wrist-follow',
        description:
            'The paw trails the IK-solved forearm (a lagged share of its recent '
            'rotation), so the hand whips out and settles at the wrist — the '
            'mitt tilting against the sleeve cuff — instead of arriving welded '
            'to the arm.',
        modifier: _wristFollowPose,
      ),
      PoseModifierPass(
        id: 'joint-limits',
        description:
            'Clamp every limited joint into its anatomical range of motion, '
            'including the coupled arm anti-fold rule.',
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

  /// Arm-chain bones whose pivotY (length) the per-clip [Clip.armReachScale]
  /// lengthens: the segments below the shoulder on both sides. armUpper itself
  /// (a tiny offset under the clavicle) is left alone.
  static const List<String> _armChainBoneIds = [
    'arm_bicep.L',
    'arm_lower.L',
    'arm_forearm.L',
    'hand.L',
    'arm_bicep.R',
    'arm_lower.R',
    'arm_forearm.R',
    'hand.R',
  ];

  /// The per-bone pivotY scale for a clip's arm-reach override — const-empty
  /// (a no-op) unless the clip opts in with a non-1.0 [Clip.armReachScale].
  Map<String, double> _armReachScaleMap(Clip clip) {
    final s = clip.armReachScale;
    if (s == 1.0) return const {};
    return {for (final id in _armChainBoneIds) id: s};
  }

  final FaceSolver faceSolver = const FaceSolver();
  final AutonomicLayer autonomic;
  late final PoseModifierStack _poseModifierStack;

  /// Local-space pose modifier passes in solve order.
  List<PoseModifierPass> get poseModifierPasses => _poseModifierStack.passes;

  /// Memoized foot-lock offset tables, keyed by clip name (built once per clip).
  final Map<String, _LocoTable> _locoTables = {};

  /// Memoized per-clip spine-level plan (level lines + natural joint envelopes,
  /// foot-stabilized, before any level counter), keyed by clip name. Drives the
  /// dance head/neck leveler — see [_spineLevelShifts].
  final Map<String, _SpineLevelPlan> _spineLevelPlans = {};

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
    // Per-clip arm-reach override: scale the arm-chain bones' length for this
    // clip only, so its solves (pose passes + IK length derivation + render)
    // are all consistent. Empty for a clip at the 1.0 default (byte-identical).
    solver.limbPivotYScale = _armReachScaleMap(clip);
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
    final headWorld = _rigidHeadWorld(
      clip,
      footStabilizedWorld,
      timeSeconds: timeSeconds,
      base: base,
      baseScale: _verticalScale(base),
      rootDx: posed.rootDx,
      rootDy: posed.rootDy,
    );
    final world = _collarFollowWorld(clip, headWorld);
    var face = faceSolver.applyAutonomic(expression.state, auto);
    if (eyeOpenScale != 1) {
      face = face.copyWith(
        eyeOpenLeft: face.eyeOpenLeft * eyeOpenScale,
        eyeOpenRight: face.eyeOpenRight * eyeOpenScale,
      );
    }
    final locomotion = locomotionOffset(clip, timeSeconds);
    final zOrderSwaps = _activeZOrderSwaps(clip, timeSeconds);
    final occludedShades = _activeOccludedShades(clip, timeSeconds);
    return CharacterFrame(
      world: world,
      face: face,
      locomotionX: locomotion,
      zOrderSwaps: zOrderSwaps,
      occludedShades: occludedShades,
    );
  }

  /// The z-order swaps active at [timeSeconds], honouring a mid-blend
  /// [Clip.transitionPlan].
  ///
  /// A plain (non-blended) clip evaluates its own [Clip.zOrderSwaps] windows
  /// against its own clock directly. A blended clip's `zOrderSwaps` field
  /// only ever holds ONE side's window list (see `blendedClip`'s
  /// mid-transition switch) — evaluating that list against the BLENDED
  /// clip's shared clock (`timeSeconds`, which tracks the INCOMING clip's
  /// own phrase from the first blended frame — see `_blendStage`'s `seconds:
  /// to.seconds`) checks the wrong side's window against the wrong clock:
  /// the outgoing clip's swap window is authored in ITS OWN phase, so a
  /// window active at, say, phase 0.5-1 of shaku's 6s loop reads as
  /// permanently inactive once `timeSeconds` resets to the incoming clip's
  /// near-zero fresh phrase start. Confirmed via transitions-r6 pixel-diff:
  /// shaku's hand.L/hand.R bar-2 swap was active right up to a shaku->buga
  /// cut, then silently vanished on the very next blended frame even though
  /// no bone moved — a paint-order pop, not a pose pop. Fix: evaluate EACH
  /// side's own windows against ITS OWN clock/duration (mirrors the dance
  /// formation cross-blend fix in `character_painter.dart`), then pick
  /// whichever side the pose blend itself is closer to.
  List<(String, String)> _activeZOrderSwaps(Clip clip, double timeSeconds) {
    List<(String, String)> active(Clip source, double sourceSeconds) =>
        source.zOrderSwaps.isEmpty
        ? const <(String, String)>[]
        : [
            for (final window in source.zOrderSwaps)
              if (window.swap &&
                  window.activeAt(evaluator.phaseAt(source, sourceSeconds)))
                (window.boneA, window.boneB),
          ];

    final plan = clip.transitionPlan;
    if (plan == null) return active(clip, timeSeconds);
    return plan.weight < 0.5
        ? active(plan.from, timeSeconds + plan.fromTimeShiftSeconds)
        : active(plan.to, timeSeconds);
  }

  /// The active `shadeBehind` requests at [timeSeconds] — same window resolution
  /// as [_activeZOrderSwaps], but only windows that ask the occluded bone be
  /// darkened, carried as `(boneA, boneB, opacity)`.
  List<(String, String, double)> _activeOccludedShades(
    Clip clip,
    double timeSeconds,
  ) {
    List<(String, String, double)> active(Clip source, double sourceSeconds) =>
        source.zOrderSwaps.isEmpty
        ? const <(String, String, double)>[]
        : [
            for (final window in source.zOrderSwaps)
              if (window.shadeBehind > 0 &&
                  window.activeAt(evaluator.phaseAt(source, sourceSeconds)))
                (window.boneA, window.boneB, window.shadeBehind),
          ];

    final plan = clip.transitionPlan;
    if (plan == null) return active(clip, timeSeconds);
    return plan.weight < 0.5
        ? active(plan.from, timeSeconds + plan.fromTimeShiftSeconds)
        : active(plan.to, timeSeconds);
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
    final tieIds = _tieBoneIds();
    if (tailIds.isEmpty && earIds.isEmpty && tieIds.isEmpty) return pose;

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
      final gain = isTip ? 2.1 : 1.0;
      // Cap the tip sweep: the ear is a long lever, so on the hardest-grooving
      // moves (zanku's ±0.4 pelvis/chest snap) the tip was out-travelling the
      // legwork in the onion — the eye caught the ears, not the feet. A tighter
      // ceiling bites only the saturated (high-rotation) case; gentle moves
      // (shaku) stay well under it, so their ear life is unchanged.
      final clampAt = isTip ? 0.10 : 0.06;
      final delta = _clampMagnitude(
        side * earDrive * gain + flick * gain,
        clampAt,
      );
      if (delta.abs() < 0.0001) continue;
      joints[earId] = _addJointRotation(pose.jointOf(earId), delta);
      changed = true;
    }

    // The TIE is a 2-link cloth pendulum on the sternum, but nothing drove it —
    // it hung dead-straight down the centreline, the single loudest "static
    // chest / detached metronome" tell (mocap). Swing it off the SAME body
    // motion the tail/ears read, weighted toward the CHEST rotation it hangs
    // from: the knot barely moves, the blade lags and swings past it like
    // fabric, then settles. Rig-level — every move's tie now breathes with the
    // groove instead of reading as a painted-on stripe.
    if (tieIds.isNotEmpty) {
      final tieDrive =
          (-lateralVelocity * 0.011) -
          bodyRotation * 0.6 +
          verticalImpulse * 0.004;
      for (var i = 0; i < tieIds.length; i++) {
        final t = tieIds.length == 1 ? 1.0 : i / (tieIds.length - 1);
        // Pendulum gradient: the blade (tip) swings ~3x the knot and lags it.
        final swing = _clampMagnitude(
          tieDrive * (0.3 + 0.9 * t),
          0.04 + 0.05 * t,
        );
        final ripple =
            math.sin(2 * math.pi * (phase * 4 - t * 0.22)) *
            tieDrive.abs() *
            (0.03 + 0.18 * t);
        final delta = swing + ripple;
        if (delta.abs() < 0.0001) continue;
        joints[tieIds[i]] = _addJointRotation(pose.jointOf(tieIds[i]), delta);
        changed = true;
      }
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

    final lag = clip.loop && clip.duration > 0 ? clip.duration / 32 : 0.0;
    final source = lag > 0
        ? evaluator.evaluate(clip, timeSeconds - lag).jointOf(torsoId).rotation
        : authored.rotation;
    final chestDelta = _kThoracicShare * source;
    // R30 hip-shoulder counter-opposition (coach/mocap 8->9): once the pelvis
    // commits laterally over the stance foot (the committed rootDx from the
    // support-balance pass), counter-rotate the trunk the OPPOSITE way so the
    // ribcage and head lean back over the base of support — the pelvis
    // TRANSLATION carries the move (contrapposto) instead of the whole body
    // rocking with it. Shaku-scoped for now; extends to the other moves in the
    // roll-out. Coupled to the committed rootDx so it self-scales with the shift.
    final counterLean = _hipShoulderCounterLean(clip, pose.rootDx);
    // Pelvic LIST coupled to the SAME committed lateral offset (only the moves
    // that get a counter-lean): the loaded-side hip hikes with rootDx so the
    // pelvis tilts and the COM rides over the planted foot — a weight-shifted
    // groove, not a level squat. Self-scales with each move's shift.
    final pelvisId = _pelvisBoneId;
    // azonto is a tight-neck in-place waist groove: even a small pelvic list
    // dips its chin under the 12.5 chin-to-collar floor ("the neck all but
    // disappears"), so it opts out of the list.
    final pelvisList =
        (pelvisId != null &&
            clip.name != 'azonto' &&
            _hipOppositionGain.containsKey(clip.name))
        ? (pose.rootDx * _kPelvisListGain).clamp(
            -_kPelvisListMax,
            _kPelvisListMax,
          )
        : 0.0;
    final torsoRotation =
        authored.rotation * (1 - _kThoracicShare) + counterLean;
    if (chestDelta.abs() < 0.0001 &&
        (authored.rotation - torsoRotation).abs() < 0.0001 &&
        pelvisList.abs() < 0.0001) {
      return pose;
    }

    final joints = Map<String, JointPose>.of(pose.joints);
    joints[torsoId] = JointPose(
      rotation: torsoRotation,
      scaleX: authored.scaleX,
      scaleY: authored.scaleY,
    );
    joints[chestId] = _addJointRotation(pose.jointOf(chestId), chestDelta);
    if (pelvisList.abs() > 0.0001 && pelvisId != null) {
      joints[pelvisId] = _addJointRotation(pose.jointOf(pelvisId), pelvisList);
    }
    return Pose(
      joints: joints,
      rootDx: pose.rootDx,
      rootDy: pose.rootDy,
      rootRotation: pose.rootRotation,
    );
  }

  /// Fraction of the authored trunk rotation carried by the thoracic joint.
  static const double _kThoracicShare = 0.45;

  /// Hip-shoulder counter-opposition: trunk counter-lean per unit of committed
  /// pelvis lateral offset (rootDx). Negative so the trunk leans OPPOSITE the
  /// pelvis commit, keeping the head over the base of support while the hips
  /// drive laterally (contrapposto). Per-move gain (coupled to rootDx so it
  /// self-scales with each move's shift). zanku carries fast arms already near
  /// the warped-jerk ceiling, so it takes a gentler counter (the torso lean
  /// propagates into the arm chain); shaku's 0.005 is the merged, panel-tuned
  /// value. Moves absent from the map (pounce, backups) get none.
  // Strengthened for the weight-shift pass (biomech: the trunk read stacked-
  // vertical, the COM not riding over the planted foot). buga stays under the
  // 0.009 chin-to-collar wander bound noted in the round it was tuned.
  // Raised so the trunk clearly OPPOSES the pelvic list (a contrapposto S-curve,
  // head back over the base of support) instead of both bending the same way
  // into a "banana" C-curve (biomech). buga kept just under its 0.009 chin-to-
  // collar wander bound.
  // Modest increases over the original (0.005/0.0025/0.005/0.006/0.005): a
  // strong counter-lean over-leans the trunk while the head-leveler pins the
  // skull, opening the chin-to-collar gap past its 20-unit plausibility bound.
  // So the OPPOSING S-curve comes mostly from the pelvic list + its tight clamp,
  // and the trunk counter stays gentle enough to keep the head on its collar.
  static const Map<String, double> _hipOppositionGain = {
    'shaku': 0.006,
    'zanku': 0.003,
    'azonto': 0.005,
    'buga': 0.006,
    'sekem': 0.006,
  };
  double _hipShoulderCounterLean(Clip clip, double rootDx) {
    final gain = _hipOppositionGain[clip.name];
    if (gain == null) return 0;
    return -rootDx * gain;
  }

  /// Pelvic LIST (obliquity) per unit committed rootDx: the loaded-side hip
  /// HIKES with the lateral weight-shift so the pelvis tilts and the COM rides
  /// over the planted foot, instead of a level pelvis reading as a stacked-
  /// vertical squat (biomech's top remaining note). The trunk counter-lean above
  /// keeps the ribcage/head back over the base of support (contrapposto).
  static const double _kPelvisListGain = 0.007;

  /// Peak pelvic-list magnitude — caps the tilt at high sway so the combined
  /// list + trunk lean can't push the head past the outer edge of the support
  /// foot at the amplitude extremes (biomech: a "banana" over-lean there).
  static const double _kPelvisListMax = 0.055;

  late final String? _pelvisBoneId = () {
    for (final id in const ['hips', 'pelvis']) {
      if (rig.bone(id) != null) return id;
    }
    return null;
  }();

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

  /// Wrist follow-through gain/cap/lag: the paw trails a share of how much the
  /// SOLVED forearm rotated over the last [_wristLagFraction], so it whips out
  /// and settles at the wrist against the sleeve cuff instead of arriving welded
  /// (animator: the last "action-figure" tell). The joint-limits pass after this
  /// remains the final clamp.
  static const double _kWristFollowGain = 1.15;
  static const double _kWristFollowCap = 0.45;
  static const double _wristLagFraction = 1.6 / 24;

  late final List<(String hand, String forearm)> _handForearmPairs = [
    for (final bone in rig.bones)
      if (bone.id.toLowerCase().contains('hand') && bone.parent != null)
        (bone.id, bone.parent!),
  ];

  Pose _wristFollowPose(PoseModifierContext context, Pose pose) {
    final clip = context.clip;
    if (!_isDanceFamily(clip) || clip.duration <= 0) return pose;
    final pairs = _handForearmPairs;
    if (pairs.isEmpty) return pose;
    // The lagged, IK-solved forearm: re-run the stack up to THIS pass at the
    // lagged instant (pure function of time; the same discipline overshoot-
    // settle uses via _preOvershootPoseAt). stopBefore this pass avoids recursion.
    // Wrap into [0, duration) ourselves (Dart's `%` is non-negative for a
    // positive divisor) so the loop seam closes exactly: at phase 1 the lag is
    // an in-range value, at phase 0 it is that same value reached by +duration —
    // bit-identical, where deferring to the evaluator's internal wrap of a
    // negative time would diverge at FP epsilon and break the seam-close test.
    final lagTime =
        (context.timeSeconds - clip.duration * _wristLagFraction) %
        clip.duration;
    final lagged = _poseModifierStack.apply(
      PoseModifierContext(
        clip: clip,
        timeSeconds: lagTime,
        breath: context.breath,
        earTwitchLeft: context.earTwitchLeft,
        earTwitchRight: context.earTwitchRight,
      ),
      evaluator.evaluate(clip, lagTime),
      stopBefore: 'wrist-follow',
    );
    Map<String, JointPose>? joints;
    for (final (handId, forearmId) in pairs) {
      final v = _shortestAngle(
        lagged.jointOf(forearmId).rotation - pose.jointOf(forearmId).rotation,
      );
      final delta = _clampMagnitude(v * _kWristFollowGain, _kWristFollowCap);
      if (delta.abs() < 0.001) continue;
      joints ??= Map<String, JointPose>.of(pose.joints);
      joints[handId] = _addJointRotation(pose.jointOf(handId), delta);
    }
    if (joints == null) return pose;
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

  /// How much of each clavicle's resolved rotation the matching
  /// shoulder-line lever mirrors. The lever pivots at the sternum (~28
  /// units of horizontal arm to the jacket's shoulder corner), so at 1.0 a
  /// full ±0.42 clavicle see-saw translates the corner ~12 units vertically
  /// before skin weights (0.45–0.55) scale the rendered pop to roughly
  /// half. Tuned against the shoulder-line probe and rendered strips.
  // 1.3 -> 1.15 (2026-07-05, owner: "the shoulder might be too bumpy at
  // the top in many scenes"): the crown probe shows the levers never
  // exceed the collar LINE, so the bumpiness is travel amplitude — a
  // 12% trim keeps the see-saw and the R28 pops legible (probe: pops
  // still 4.4-8.7 crown units) while calming the humps.
  static const double _kShoulderLineGain = 1.15;

  /// Humeral-elevation → girdle coupling (the R14 mocap panel's ask: "~1° of
  /// clavicular elevation per 2° of humerus above ~30°"). When the solved
  /// upper arm swings past [_kShoulderLineAbductionThreshold] from its
  /// hanging rest, the lever on that side lifts the jacket's shoulder corner
  /// with it — a winged elbow now raises its own shoulder line instead of
  /// hinging under a rigid yoke. Applied ONLY to the render levers: the IK
  /// solve, the clavicle channel, and its envelope gate are untouched.
  // Ratcheted twice by panels: 0.6/0.6/0.35 ballooned paired shrug humps
  // to the jaw (R15); at 0.6/0.5/0.25 a churn move whose arms swing every
  // frame kept the caps "permanently shrugged, cresting above the collar"
  // (R16) because the coupling never shut off. The higher threshold means
  // only a genuinely WINGED elbow (upper arm past ~54° from hanging) earns
  // a lift, and the smaller cap keeps the cap below the collar line.
  static const double _kShoulderLineAbductionThreshold = 0.95;
  static const double _kShoulderLineAbductionGain = 0.5;
  static const double _kShoulderLineAbductionCap = 0.15;

  /// Authored-girdle deference for the humeral coupling: as the resolved
  /// clavicle rotation on a side approaches this magnitude, the elevation
  /// coupling on that side fades to zero. Without this, shaku's punch-out
  /// (humerus swung near horizontal) lifts the very shoulder its authored
  /// see-saw is dropping on the same count, and the two cancel back into
  /// the "level yoke" the see-saw fix exists to break. Choreographed
  /// shoulder intent wins; scapulo-humeral rhythm fills in only where the
  /// clavicle channel is quiet (transitions, un-authored moves).
  static const double _kShoulderLineAbductionDeference = 0.25;

  /// Weight-shift bank: how much the shoulder line tilts per unit of the root's
  /// lateral commit ([Pose.rootDx]). The side the body loads onto drops its
  /// shoulder, so the girdle banks WITH the lunge instead of riding level on
  /// top of it — the mocap panel's "the arms read as bolted on, not driven by
  /// the ground" note. Small: a mild counter to the level-yoke read, capped so
  /// it never fights the authored see-saw.
  static const double _kShoulderWeightBankGain = 0.010;
  static const double _kShoulderWeightBankCap = 0.18;

  /// Shoulder-line levers paired with the same-side clavicle, discovered by
  /// id convention like the rest of the girdle plumbing (no lever bones in a
  /// rig ⇒ the pass is a no-op).
  late final List<({String clavicleId, String leverId})> _shoulderLinePairs =
      () {
        final pairs = <({String clavicleId, String leverId})>[];
        for (final bone in rig.bones) {
          final id = bone.id.toLowerCase();
          if (!id.startsWith('shoulder_line')) continue;
          final suffix = id.endsWith('.l')
              ? '.l'
              : id.endsWith('.r')
              ? '.r'
              : null;
          if (suffix == null) continue;
          for (final candidate in rig.bones) {
            final cid = candidate.id.toLowerCase();
            if (cid.contains('clavicle') && cid.endsWith(suffix)) {
              pairs.add((clavicleId: candidate.id, leverId: bone.id));
              break;
            }
          }
        }
        return pairs;
      }();

  /// The `shoulder-line` pipeline stage. Two drivers, both writing only the
  /// transform-only shoulder-line levers (see the rig's shoulder_line bone
  /// comment) — the step that turns SOLVED girdle motion into actual
  /// translation of the jacket's rendered shoulder contour, the
  /// "solved-rotation-doesn't-render" fix:
  ///
  /// 1. Mirrors each clavicle's resolved rotation (authored keys +
  ///    girdle-follow + raised-hand shrug) onto the same-side lever, scaled
  ///    by [_kShoulderLineGain]. A same-sign copy is correct for both
  ///    sides: a +x (right) corner under a positive rotation moves down
  ///    (+y in screen space), and the left clavicle's "drop" is authored
  ///    with the opposite sign, which moves the −x corner down as well.
  /// 2. Adds humeral-elevation coupling: the further the IK-solved upper
  ///    arm swings from its hanging rest past the abduction threshold, the
  ///    more the lever lifts that side's corner (capped) — scapulo-
  ///    clavicular rhythm, reduced to its silhouette effect.
  ///
  /// Runs after `limb-ik` so driver 2 reads the solved humerus; since the
  /// levers have no children and no drawables, nothing downstream is
  /// disturbed.
  Pose _shoulderLinePose(Clip clip, double timeSeconds, Pose pose) {
    if (_shoulderLinePairs.isEmpty) return pose;
    // FOLLOW-THROUGH (R2 panels on buga/zanku/shaku: "the skull and both
    // crowns track the pocket 1:1 — the body pops as one block"): each
    // crown lags HALFWAY toward its clavicle's authored value ~1.5 frames
    // ago (a pure function of time — determinism holds). On a snap the
    // crown arrives late and swings past, the independent overshoot the
    // raters asked for; on smooth grooves the term is near-zero.
    final followLag = _isDanceFamily(clip) && clip.duration > 0
        ? clip.duration * 1.5 / 32
        : 0.0;
    final laggedPose = followLag > 0
        ? evaluator.evaluate(clip, timeSeconds - followLag)
        : null;
    final rawPose = followLag > 0
        ? evaluator.evaluate(clip, timeSeconds)
        : null;
    Map<String, JointPose>? joints;
    void addLever(String leverId, double delta) {
      if (delta == 0) return;
      final map = joints ??= Map<String, JointPose>.of(pose.joints);
      map[leverId] = _addJointRotation(
        map[leverId] ?? pose.jointOf(leverId),
        delta,
      );
    }

    for (final pair in _shoulderLinePairs) {
      final followThrough = laggedPose == null || rawPose == null
          ? 0.0
          : _clampMagnitude(
              (laggedPose.jointOf(pair.clavicleId).rotation -
                      rawPose.jointOf(pair.clavicleId).rotation) *
                  0.5,
              0.18,
            );
      addLever(
        pair.leverId,
        (pose.jointOf(pair.clavicleId).rotation + followThrough) *
            _kShoulderLineGain,
      );
    }

    for (final target in clip.limbTargets) {
      if (!_isHandBone(target.endBoneId)) continue;
      final side = _sideSign(target.endBoneId);
      if (side == 0) continue;
      final pair = _shoulderLineBySuffix[side > 0 ? '.l' : '.r'];
      if (pair == null) continue;
      final swing = _shortestAngle(
        pose.jointOf(target.upperBoneId).rotation,
      ).abs();
      final engagement = swing - _kShoulderLineAbductionThreshold;
      if (engagement <= 0) continue;
      final authored = _shortestAngle(
        pose.jointOf(pair.clavicleId).rotation,
      ).abs();
      final deference = (1 - authored / _kShoulderLineAbductionDeference).clamp(
        0.0,
        1.0,
      );
      if (deference <= 0) continue;
      final lift =
          math.min(
            engagement * _kShoulderLineAbductionGain,
            _kShoulderLineAbductionCap,
          ) *
          deference;
      // side: L=+1, R=−1 — matches the raised-hand shrug's convention where
      // a NEGATIVE right-clavicle rotation is shoulder-up.
      addLever(pair.leverId, side * lift);
    }

    // Weight-shift bank: the loaded side (toward the root's lateral commit)
    // drops its shoulder so the girdle banks with the lunge instead of staying
    // level on top of it. A pure function of the solved root, so determinism
    // holds.
    if (_isDanceFamily(clip) && pose.rootDx != 0) {
      final bank = (pose.rootDx * _kShoulderWeightBankGain).clamp(
        -_kShoulderWeightBankCap,
        _kShoulderWeightBankCap,
      );
      final leftPair = _shoulderLineBySuffix['.l'];
      final rightPair = _shoulderLineBySuffix['.r'];
      if (leftPair != null) addLever(leftPair.leverId, bank);
      if (rightPair != null) addLever(rightPair.leverId, -bank);
    }

    final resolved = joints;
    if (resolved == null) return pose;
    return Pose(
      joints: resolved,
      rootDx: pose.rootDx,
      rootDy: pose.rootDy,
      rootRotation: pose.rootRotation,
    );
  }

  /// Lever/clavicle pair per side suffix, for the humeral coupling above.
  late final Map<String, ({String clavicleId, String leverId})>
  _shoulderLineBySuffix = {
    for (final pair in _shoulderLinePairs)
      if (pair.leverId.toLowerCase().endsWith('.l')) '.l': pair else '.r': pair,
  };

  /// The `limb-ik` pipeline stage: bends each [Clip.limbTargets] two-bone
  /// limb (shoulder→elbow→wrist or hip→knee→ankle) toward its authored
  /// world-space target via [_solveLimbTarget], committing joints one target
  /// at a time so a later target in the same pass sees an already-IK'd pose.
  ///
  /// A target near full authored `weight` (choreographic, not a soft hint)
  /// gets a second corrective solve from the just-committed pose — parent
  /// rotations or a support-foot anchor (below) can have nudged the chain
  /// during the first solve, so re-solving from the updated shoulder/elbow
  /// position lands the end effector closer to its control. The correction
  /// is blended in via `smoothstep((weight - 0.9) / 0.1)` rather than
  /// switched on at a hard `weight >= 0.98` gate, so an interpolated weight
  /// crossing that threshold doesn't step the end effector.
  ///
  /// [Clip.supportFootWorldAnchor] opts a clip's active support foot into a
  /// blended world-space hold (see [_supportFootWorldAnchor]) so the leg
  /// bends to absorb the body's groove while the foot stays planted, instead
  /// of dragging with the hips.
  /// Minimum separation, in anchor-space units, the two hand IK targets are
  /// allowed to close to. Each mitt drawable reads ~10 units across, so
  /// anything under ~19 renders as one merged orange blob.
  static const double _kHandClearance = 30;

  /// Hand-clearance constraint (R15 animator: both mitts "stack directly
  /// over the sternum as a single orange blob... enforce a minimum lateral
  /// separation"). When both authored hand targets sample closer than
  /// [_kHandClearance], each is pushed half the shortfall apart along their
  /// separation axis (falling back to the x axis if they coincide exactly),
  /// so crossed-chest churns always read as two limbs passing. A pure
  /// function of the sampled targets — the clip+time ⇒ pose determinism
  /// guarantee holds — and authored data that already keeps daylight is
  /// returned untouched. Both hands share the same anchor bone in this rig,
  /// so pushing in anchor space is pushing in render space.
  Map<String, IkTargetPose> _handClearanceAdjustedSamples(
    Clip clip,
    double phase,
  ) {
    LimbIkTarget? first;
    LimbIkTarget? second;
    for (final target in clip.limbTargets) {
      if (!_isHandBone(target.endBoneId)) continue;
      if (first == null) {
        first = target;
      } else {
        second = target;
        break;
      }
    }
    if (first == null || second == null) return const {};
    final a = first.channel.sample(phase);
    final b = second.channel.sample(phase);
    if (a.weight <= 0 || b.weight <= 0) return const {};
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance >= _kHandClearance) return const {};
    final push = (_kHandClearance - distance) / 2;
    final ux = distance > 1e-6 ? dx / distance : 1.0;
    final uy = distance > 1e-6 ? dy / distance : 0.0;
    return {
      first.endBoneId: IkTargetPose(
        x: a.x - ux * push,
        y: a.y - uy * push,
        weight: a.weight,
      ),
      second.endBoneId: IkTargetPose(
        x: b.x + ux * push,
        y: b.y + uy * push,
        weight: b.weight,
      ),
    };
  }

  /// Fraction of a 32-frame phrase step over which a hand target's ARRIVAL
  /// velocity into a keyframe is measured (see [_handTargetFollowThrough]).
  static const double _kFollowArrivalWindow = 0.4;

  /// Arrival-window travel (target units) below which a key is treated as a
  /// dead hold and skipped — the spring response is `∝ v0`, so a hold already
  /// yields a near-zero offset; this just avoids amplifying the Catmull-Rom's
  /// micro-wiggle on a held pose into visible jitter.
  static const double _kFollowMinArrivalTravel = 0.5;

  /// Overall amplitude of the hand-target spring: a dimensionless gain on the
  /// velocity-driven closed-form response ([dampedTransitionResponse]).
  /// Perceptual dial, tuned on the crest/elbow metrics.
  static const double _kSpringHandGain = 4;

  /// Cap (target-space units) on the arrival-window travel that scales the
  /// overshoot. An extreme hit into a near-degenerate elbow (zanku's volatile
  /// two-bone reach) would otherwise drive a jerk spike; capping the driving
  /// travel scales the whole response down uniformly, so it bounds the
  /// amplitude without breaking the response shape or touching normal hits.
  static const double _kFollowMaxArrivalTravel = 8;

  /// Damped follow-through in HAND-TARGET space. On every beat the hand target
  /// carries its ARRIVAL velocity past the authored key as a decaying second-
  /// order transient, then settles — so the two-bone IK solver tracks a smooth
  /// overshooting target and the whole arm follows through, instead of
  /// perturbing the post-IK elbow rotation (which fought the joint-limit clamp /
  /// the near-degenerate elbow and injected an amplitude-independent jerk
  /// spike). Driving the pre-IK TARGET is the wall-breaking decision: the hand
  /// gets a fast, punchy crest (it chases an overshooting target) while the
  /// elbow angular velocity stays bounded (the IK of a smooth target is smooth)
  /// — the crest+smooth-elbow combination hand-keyed transitions can't reach.
  ///
  /// The response is `∝ v0` (a dead hold → ~0 automatically, no stop-detection
  /// gate needed), and (ωₙ, ζ) come from the clip's [DanceDynamics] via
  /// [danceSpring]: Flow dials the overshoot (ζ), Time the snap (ωₙ). Zero with
  /// zero slope at BOTH keyframe ends (`Φ(0)=0` + taper), so it perturbs only
  /// the interpolated region and every authored hit still lands on its beat — a
  /// pure function of phase (channel re-sampled, no per-frame state).
  (double, double) _handTargetFollowThrough(
    IkTargetChannel channel,
    double phase,
    double frameDuration,
    DanceSpring spring,
  ) {
    const frameCount = 32;
    final frameLocal = phase * frameCount;
    final frameIndex = frameLocal.floor();
    final u = frameLocal - frameIndex;
    if (u <= 1e-6 || u >= 1 - 1e-6) return (0, 0);
    double wrap(double p) {
      final q = p - p.floorToDouble();
      return q < 0 ? q + 1 : q;
    }

    final t0 = frameIndex / frameCount;
    const arrivalPhase = _kFollowArrivalWindow / frameCount;
    final approach = channel.sample(wrap(t0 - arrivalPhase));
    final at = channel.sample(wrap(t0));
    final adx = at.x - approach.x;
    final ady = at.y - approach.y;
    final travel = math.sqrt(adx * adx + ady * ady);
    if (travel < _kFollowMinArrivalTravel) return (0, 0);
    // Cap the driving travel so an extreme reach can't spike jerk (uniform
    // scale — preserves the response shape).
    final cap = travel > _kFollowMaxArrivalTravel
        ? _kFollowMaxArrivalTravel / travel
        : 1.0;
    // Arrival velocity = travel / arrival-window (in authored-clock seconds);
    // the kernel carries it past the key. `Φ(0)=0` and the taper keep every
    // authored frame untouched, so no exact-frame test is perturbed.
    final arrivalSeconds = _kFollowArrivalWindow * frameDuration;
    final dt = u * frameDuration;
    final kernel = dampedTransitionResponse(
      dt,
      frameDuration,
      spring.omegaN,
      spring.zeta,
    );
    final gain = _kSpringHandGain * cap * kernel / arrivalSeconds;
    return (adx * gain, ady * gain);
  }

  Pose _limbTargetedPose(Clip clip, double timeSeconds, Pose pose) {
    if (clip.limbTargets.isEmpty) return pose;

    final phase = evaluator.phaseAt(clip, timeSeconds);
    final joints = Map<String, JointPose>.of(pose.joints);
    var currentPose = pose;

    // Opt-in (per [Clip.supportFootWorldAnchor]): hold the active support foot
    // toward its planted world position so the body grooves over it. Reads
    // via [_contactSourceFor] so a mid-blend clip's merged contactSpans (see
    // `_transitionSpans`) don't get evaluated against the wrong side's clock
    // — same fix as `_danceSupportFootStabilizedWorld`'s own doc comment.
    final contactSource = _contactSourceFor(clip, timeSeconds);
    final footAnchor = _supportFootWorldAnchor(
      contactSource.clip,
      _clipPhase(contactSource.clip, contactSource.timeSeconds),
    );

    final clearedHands = _handClearanceAdjustedSamples(clip, phase);

    // SOLE FLOOR (R27 mocap hard gate: "floor penetration is the one thing
    // a mocap eye rejects outright"): foot targets are authored in the
    // anchor bone's space, so a deep pocket sink carries the free foot's
    // tap target down with the body — probe-measured up to ~10 units below
    // the planted sole at the seam. The planted support sole IS the floor
    // at every instant; a free foot's target may never sink below it.
    // Same per-side clock fix as [footAnchor] above — the merged clip's
    // contactSpans evaluated at the wrong side's phase can name the wrong
    // bone as the "floor" reference for the free foot's clamp.
    final contactForFloor = clip.enforceSoleFloor && _isDanceFamily(clip)
        ? _activeContactAt(
            contactSource.clip,
            _clipPhase(contactSource.clip, contactSource.timeSeconds),
          )
        : null;
    // The clamp FADES at span edges like every other contact mechanism:
    // at a support handoff the "floor" jumps from one foot to the other,
    // and a hard clamp across that switch ticks the free foot's velocity
    // at the boundary (measured 31 units/frame on zanku's per-beat spans).
    var soleFloorFade = 0.0;
    if (contactForFloor != null) {
      final span = contactForFloor.span;
      final spanLength = span.end - span.start;
      final fade = (spanLength * 0.2).clamp(0.015, 0.04);
      final fadeIn = smoothstep(
        (contactForFloor.strengthPhase - span.start) / fade,
      );
      final fadeOut = smoothstep(
        (span.end - contactForFloor.strengthPhase) / fade,
      );
      soleFloorFade = fadeIn < fadeOut ? fadeIn : fadeOut;
    }

    // Solve the PLANTED foot before free feet: the free feet's sole floor
    // reads the support sole from the evolving pose, which must already
    // carry the support's world-anchored solve (in authored order the free
    // foot could read the support's un-anchored, sink-dragged position).
    final orderedTargets = [...clip.limbTargets]
      ..sort((a, b) {
        int rank(LimbIkTarget t) => !_isFootBone(t.endBoneId)
            ? 0
            : (footAnchor != null && t.endBoneId == footAnchor.bone)
            ? 1
            : 2;
        return rank(a).compareTo(rank(b));
      });
    final handSpring = danceSpring(clip.dynamics);
    final handFrameDuration = clip.duration / 32;
    for (final target in orderedTargets) {
      var sample =
          clearedHands[target.endBoneId] ?? target.channel.sample(phase);
      // Hand-target-space follow-through: a per-beat second-order spring
      // overshoots the smooth target the solver tracks, so the whole arm
      // settles coherently after each hit (ωₙ/ζ from the clip's dynamics).
      // Skipped for an inertialized channel — that channel already IS the
      // spring (Phase 2), so the Phase-1 garnish would double-stack it.
      if (_isHandBone(target.endBoneId) &&
          _isDanceFamily(clip) &&
          handFrameDuration > 0 &&
          target.channel is! InertializedIkTargetChannel) {
        final (fdx, fdy) = _handTargetFollowThrough(
          target.channel,
          phase,
          handFrameDuration,
          handSpring,
        );
        if (fdx != 0 || fdy != 0) {
          sample = IkTargetPose(
            x: sample.x + fdx,
            y: sample.y + fdy,
            weight: sample.weight,
            // Preserve the elbow-solution controls — the follow-through only
            // offsets the wrist target, it must not silently reset which side
            // the elbow breaks ([bendDirection]) or how far it is abducted
            // ([elbowAbduction]). (Dropping these was a latent bug: any hand
            // with an authored bend/abduction lost it whenever the per-beat
            // garnish fired.)
            bendDirection: sample.bendDirection,
            elbowAbduction: sample.elbowAbduction,
          );
        }
      }
      final weight = sample.weight.clamp(0.0, 1.0);
      if (weight <= 0) continue;

      final planted = footAnchor != null && target.endBoneId == footAnchor.bone;
      // The floor for a free foot is the planted sole's position in the
      // CURRENT pre-correction solve — the same space the IK target lives
      // in. (Anchor-space floors mismatch during the seam dive, where the
      // contact-lock's later root correction is large.)
      final soleFloor =
          _isFootBone(target.endBoneId) &&
              !planted &&
              contactForFloor != null &&
              contactForFloor.span.bone != target.endBoneId
          ? _contactPoint(
              solver.solve(currentPose),
              contactForFloor.span.bone,
            )?.y
          : null;
      final soleFloorStrength = soleFloor == null ? 0.0 : soleFloorFade;
      final solved = _solveLimbTarget(
        target,
        sample,
        currentPose,
        weight,
        worldAnchor: planted ? (x: footAnchor.x, y: footAnchor.y) : null,
        anchorBlend: planted ? footAnchor.blend : 0,
        anchorBlendY: planted ? footAnchor.blendY : 0,
        soleFloorY: soleFloorStrength > 0 ? soleFloor : null,
        soleFloorStrength: soleFloorStrength,
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

      // Strong targets are choreographic controls, not soft hints. Run a
      // corrective second solve from the just-updated pose so wrists/feet
      // land closer to their controls when parent rotations and support
      // anchors have moved the chain during the first solve. The correction
      // FADES IN as the authored weight approaches full strength — the old
      // hard weight>=0.98 gate switched the extra solve on discretely as an
      // interpolated weight crossed it, stepping the end effector.
      final refineBlend = smoothstep((weight - 0.9) / 0.1);
      if (refineBlend > 0 && target.anchorBoneId != target.upperBoneId) {
        final refined = _solveLimbTarget(
          target,
          sample,
          currentPose,
          weight,
          worldAnchor: planted ? (x: footAnchor.x, y: footAnchor.y) : null,
          anchorBlend: planted ? footAnchor.blend : 0,
          anchorBlendY: planted ? footAnchor.blendY : 0,
          soleFloorY: soleFloorStrength > 0 ? soleFloor : null,
          soleFloorStrength: soleFloorStrength,
        );
        if (refined != null) {
          final first = (
            upper: joints[target.upperBoneId] ?? JointPose.identity,
            lower: joints[target.lowerBoneId] ?? JointPose.identity,
          );
          commitSolution((
            upper: JointPose(
              rotation: _lerpAngle(
                first.upper.rotation,
                refined.upper.rotation,
                refineBlend,
              ),
              scaleX: refined.upper.scaleX,
              scaleY: refined.upper.scaleY,
            ),
            lower: JointPose(
              rotation: _lerpAngle(
                first.lower.rotation,
                refined.lower.rotation,
                refineBlend,
              ),
              scaleX: refined.lower.scaleX,
              scaleY: refined.lower.scaleY,
            ),
          ));
        }
      }
    }

    return currentPose;
  }

  /// Minimum incoming angular speed (rad/s, raw clip clock) at a keyframe
  /// boundary before a settle is considered at all — well above ordinary
  /// authored motion, so smooth channels (e.g. sekem's) never trigger this.
  static const double _kOvershootMinIncomingSpeed = 6;

  /// A boundary counts as a "hard stop" when the outgoing speed drops to at
  /// most this fraction of the incoming speed.
  static const double _kOvershootMaxOutgoingRatio = 0.4;

  /// Above this speed (rad/s), a finite-difference reading is treated as
  /// two-bone-IK solver noise (a near-degenerate elbow flip snapping the
  /// solved bend angle between frames) rather than genuine authored motion,
  /// and skipped rather than turned into a settle. No authored choreography
  /// swings an arm this fast; a reading past this ceiling means the probe
  /// landed on a solver discontinuity, and amplifying it would manufacture a
  /// far worse snap than the one this pass exists to remove.
  static const double _kOvershootMaxPlausibleSpeed = 25;

  /// Small probe step (seconds) used to finite-difference the pre-overshoot
  /// pose's angular velocity either side of an authored keyframe boundary.
  static const double _kOvershootProbeEpsilon = 1 / 480;

  /// Adds a decaying rotational settle after a hard authored stop on arm and
  /// torso rotation channels.
  ///
  /// The dance phrase is a fixed 32-frame grid (see `_spineDistributedPose`'s
  /// `clip.duration / 32` lag, the same convention), so the most recent
  /// authored keyframe boundary `t0` and the time since it (`dt`) are pure
  /// functions of `timeSeconds` — no search, no per-frame state. The incoming
  /// angular velocity `v0` at `t0` is estimated from the PRE-overshoot pose
  /// (the pose this same pass would see, via `stopBefore: 'overshoot-settle'`)
  /// at `t0` and `t0 - epsilon`; the outgoing velocity `v1` the same way just
  /// after `t0`. A hard stop (`v1` much smaller than `v0`) injects the shared
  /// closed-form damped free response [dampedTransitionResponse], with (ωₙ, ζ)
  /// from the clip's [DanceDynamics] via [danceSpring]. This is the same spring
  /// the hand-target follow-through uses; here it drives TORSO and UPPER-ARM
  /// rotation only — the elbow's (lower-arm) settle comes from the hand-target
  /// spring via IK, and the existing hard-stop gate keeps this pass dormant on
  /// an arm the hand spring already smoothed (so the two never double-count).
  /// The catalogue is authored Bound (ζ ≥ 1 → over-damped, a single rise-and-
  /// decay hump, no ringing); dialing Flow up (ζ < 1) opts into one overshoot
  /// lobe.
  ///
  /// A linear taper forces this term to exactly zero at the NEXT keyframe
  /// boundary regardless of how (ωₙ, ζ) are tuned — the non-regression property
  /// every exact-frame test in `cat_in_suit_test.dart` depends on: the settle
  /// only ever perturbs the INTERPOLATED region between authored keys, never an
  /// authored instant itself. The ωₙ floor (`kSpringOmegaMin` in `danceSpring`)
  /// keeps the hump basically spent by the time the taper engages, so hard
  /// zeroing never introduces a new velocity discontinuity.
  Pose _overshootSettledPose(PoseModifierContext context, Pose pose) {
    final clip = context.clip;
    final timeSeconds = context.timeSeconds;
    if (!_isDanceFamily(clip) || clip.duration <= 0) return pose;

    final targets = _overshootTargetBoneIds(clip);
    if (targets.isEmpty) return pose;

    final spring = danceSpring(clip.dynamics);
    const frameCount = 32;
    final frameDuration = clip.duration / frameCount;
    const epsilon = _kOvershootProbeEpsilon;
    if (frameDuration <= epsilon * 2) return pose;

    final frameIndex = (timeSeconds / frameDuration).floor();
    // Never ring off the LOOP WRAP boundary: the taper zeroes every settle
    // INTO frame 32, so a settle firing OUT of frame 0 makes the loop's
    // boundary velocities asymmetric by construction — measured as a
    // once-per-loop hand tick at the seam (jump ~28 vs the gate's 8) that
    // no authored key could fix. A loop point must depart the way it
    // arrived; accents elsewhere in the phrase keep their follow-through.
    if (clip.loop && frameIndex == 0) return pose;
    final t0 = frameIndex * frameDuration;
    final dt = timeSeconds - t0;
    if (dt <= 1e-9) return pose;
    final taper = 1 - dt / frameDuration;
    if (taper <= 0) return pose;

    final before = _preOvershootPoseAt(context, t0 - epsilon);
    final at = _preOvershootPoseAt(context, t0);
    final after = _preOvershootPoseAt(context, t0 + epsilon);

    Map<String, JointPose>? joints;
    for (final boneId in targets) {
      // Two-bone IK angles come from atan2 internally, so a raw rotation
      // difference can spuriously read as a near-2*pi spike if the true
      // value crosses the +/-pi branch cut between samples. Wrapping through
      // the shortest-angle delta (the same trick `_lerpAngle` uses) keeps the
      // finite difference honest.
      final v0 =
          _shortestAngle(
            at.jointOf(boneId).rotation - before.jointOf(boneId).rotation,
          ) /
          epsilon;
      if (v0.abs() < _kOvershootMinIncomingSpeed ||
          v0.abs() > _kOvershootMaxPlausibleSpeed) {
        continue;
      }
      final v1 =
          _shortestAngle(
            after.jointOf(boneId).rotation - at.jointOf(boneId).rotation,
          ) /
          epsilon;
      if (v1.abs() > v0.abs() * _kOvershootMaxOutgoingRatio) continue;

      final settle =
          v0 *
          dampedTransitionResponse(
            dt,
            frameDuration,
            spring.omegaN,
            spring.zeta,
          );
      if (settle.abs() < 1e-6) continue;

      joints ??= Map<String, JointPose>.of(pose.joints);
      final current = joints[boneId] ?? pose.jointOf(boneId);
      joints[boneId] = JointPose(
        rotation: current.rotation + settle,
        scaleX: current.scaleX,
        scaleY: current.scaleY,
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

  /// Re-evaluates the pose modifier chain up to (not including) the
  /// overshoot-settle pass itself at [timeSeconds], reusing [context]'s
  /// autonomic signals. This is what "pre-overshoot" means: still a pure
  /// function of [timeSeconds], so probing a neighbouring instant costs an
  /// extra evaluation but never breaks the clip+time -> pose determinism
  /// guarantee the rest of this pipeline relies on.
  Pose _preOvershootPoseAt(PoseModifierContext context, double timeSeconds) {
    final rawPose = evaluator.evaluate(context.clip, timeSeconds);
    final subContext = PoseModifierContext(
      clip: context.clip,
      timeSeconds: timeSeconds,
      breath: context.breath,
      earTwitchLeft: context.earTwitchLeft,
      earTwitchRight: context.earTwitchRight,
    );
    return _poseModifierStack.apply(
      subContext,
      rawPose,
      stopBefore: 'overshoot-settle',
    );
  }

  /// Upper-arm and torso rotation channels eligible for the rotational settle,
  /// generically derived from the clip/rig rather than any sample-catalogue
  /// bone-id list: every [LimbIkTarget] whose end effector is NOT a declared
  /// ground/contact bone (i.e. a hand, not a support foot) contributes its
  /// UPPER bone, plus the torso bone (parent of [_chestBoneId]) if the rig
  /// declares one. Feet are excluded explicitly per the coupled arm-fold /
  /// planted-contact lesson: softening a support foot's arrival reads as
  /// sliding into contact rather than landing.
  ///
  /// The lower arm bone (elbow/forearm) is deliberately EXCLUDED: its settle
  /// now comes from the hand-target spring ([_handTargetFollowThrough]) via the
  /// two-bone IK, and adding a second rotation-space settle on top would double-
  /// count. Excluding it also sidesteps the elbow's known volatility — the
  /// two-bone IK solver's most hypersensitive output near a near-degenerate
  /// reach (the same effect this session traced for azonto/sekem), where a
  /// frame-to-frame rotation can carry a solver artifact rather than authored
  /// motion.
  Set<String> _overshootTargetBoneIds(Clip clip) {
    final feet = <String>{
      for (final span in clip.groundSpans) span.bone,
      for (final span in clip.contactSpans) span.bone,
    };
    final targets = <String>{};
    for (final target in clip.limbTargets) {
      if (feet.contains(target.endBoneId)) continue;
      targets.add(target.upperBoneId);
    }
    final chestId = _chestBoneId;
    if (chestId != null) {
      final torsoId = rig.bone(chestId)?.parent;
      if (torsoId != null) targets.add(torsoId);
    }
    return targets;
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
    // Same per-side phase fix as `_transitionContactLockedPose`.
    final weight = smoothstep(transition.weight);
    final dx =
        _supportBalanceRootDelta(
          source: transition.from,
          phase: _clipPhase(
            transition.from,
            timeSeconds + transition.fromTimeShiftSeconds,
          ),
          pose: pose,
          scale: 1 - weight,
        ) +
        _supportBalanceRootDelta(
          source: transition.to,
          phase: _clipPhase(transition.to, timeSeconds),
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

  /// Solves [target]'s two-bone limb toward [sample]'s world-space point
  /// (optionally blended toward [worldAnchor], see [_limbTargetedPose]),
  /// then converts the solved WORLD angles back into LOCAL [JointPose]
  /// rotations — subtracting the parent's current world rotation, the
  /// bone's rest rotation and its local pivot angle, the inverse of how
  /// [SkeletonSolver] composes them going forward — so the result re-enters
  /// the pose exactly as if a clip channel had authored it, and flows
  /// through the same FK path as everything else. `weight` blends the
  /// result toward the pose's current rotation via [_lerpAngle] (an
  /// authored IK-target weight, not a separate easing pass), so a soft
  /// target only nudges the limb rather than fully committing to the IK
  /// solve. Returns null when the rig is missing a bone the target names,
  /// the bone chain isn't the expected upper→lower→end parentage, or the
  /// underlying [solveTwoBoneIk] itself returns null (a degenerate limb).
  ({JointPose upper, JointPose lower})? _solveLimbTarget(
    LimbIkTarget target,
    IkTargetPose sample,
    Pose pose,
    double weight, {
    ({double x, double y})? worldAnchor,
    double anchorBlend = 0,
    double? anchorBlendY,
    double? soleFloorY,
    double soleFloorStrength = 1,
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
    // preserved (a hard hold narrows the astride into a leg-tangle). [anchorBlendY]
    // (defaults to [anchorBlend] when unset) lets the Y pull be strengthened
    // independently of X for a move whose root authors a large SUSTAINED
    // vertical sink — see [Clip.supportFootWorldAnchorVerticalBoost].
    final blendY = anchorBlendY ?? anchorBlend;
    var targetPoint = worldAnchor == null || (anchorBlend <= 0 && blendY <= 0)
        ? authoredTarget
        : (
            x:
                authoredTarget.x +
                (worldAnchor.x - authoredTarget.x) * anchorBlend,
            y: authoredTarget.y + (worldAnchor.y - authoredTarget.y) * blendY,
          );
    // The support sole is the floor: clamp a free foot's target so a deep
    // pocket sink can never press it below the planted shoe (see
    // [_limbTargetedPose]'s sole-floor note). +y is down-screen. The IK
    // targets the foot bone ORIGIN, but a toe-pitched tap hangs its sole
    // several units below the origin — the origin's floor is the sole
    // floor raised by that drop, so the shoe bottom (not the ankle) is
    // what never penetrates.
    if (soleFloorY != null && soleFloorStrength > 0) {
      final sole = _contactPoint(world, end.id);
      final soleDrop = sole == null ? 0.0 : sole.y - endWorld.origin.y;
      final originFloor = soleFloorY - (soleDrop > 0 ? soleDrop : 0);
      if (targetPoint.y > originFloor) {
        targetPoint = (
          x: targetPoint.x,
          y: targetPoint.y + (originFloor - targetPoint.y) * soleFloorStrength,
        );
      }
    }
    final solution = solveTwoBoneIk(
      shoulderX: shoulder.x,
      shoulderY: shoulder.y,
      targetX: targetPoint.x,
      targetY: targetPoint.y,
      upperLength: pointDistance(shoulder, elbow),
      lowerLength: pointDistance(elbow, wrist),
      bendDirection: (sample.bendDirection ?? target.bendDirection).toDouble(),
      abduction: sample.elbowAbduction,
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

  double _lerpAngle(double from, double to, double weight) =>
      from + _shortestAngle(to - from) * weight;

  /// The chin-to-collar gap the collar-follow pulls the tall frames DOWN toward
  /// (never below — the deep-squash frames, where the chin already sits near the
  /// collar, are left alone so the collar can never swallow the chin). Inside
  /// the head_collar_gap band [12.5, 24.5].
  static const double _kCollarFollowTargetGap = 14;
  static const double _kCollarFollowGain = 1;
  static const double _kCollarFollowMaxLift = 8;

  /// Collar surfaces discovered by id convention (the shirt V wedge + the collar
  /// points), like the shoulder-line girdle plumbing — empty ⇒ the pass no-ops.
  late final List<String> _collarFollowIds = [
    for (final b in rig.bones)
      if (b.id == 'shirt_v' || b.id.toLowerCase().startsWith('collar')) b.id,
  ];

  /// Collar-follow: on the tall/stretched frames the shirt collar sits well
  /// below the chin and the exposed neck reads as a "giraffe stalk" (R23/R24
  /// animator #1). A real collar rides up under the chin as the trunk stretches,
  /// so pull the collar surfaces UP toward the head whenever the chin-to-collar
  /// gap grows past [_kCollarFollowTargetGap] — proportionally, capped, and
  /// NEVER past the target, so the deep-squash frames are untouched and `lo`
  /// (the chin-swallow floor) can only improve. A pure function of the solved
  /// world (head vs collar Y), so determinism holds; a no-op on collar-less rigs.
  Map<String, Affine2D> _collarFollowWorld(
    Clip clip,
    Map<String, Affine2D> world,
  ) {
    if (!_isDanceFamily(clip) || _collarFollowIds.isEmpty) return world;
    final headId = rig.face?.anchorBoneId;
    if (headId == null) return world;
    final head = world[headId];
    if (head == null) return world;
    // Gap reference: the shirt V wedge if present (matches head_collar_gap_test's
    // shirt.ty − head.ty), else the first collar bone.
    final refId = _collarFollowIds.contains('shirt_v')
        ? 'shirt_v'
        : _collarFollowIds.first;
    final ref = world[refId];
    if (ref == null) return world;
    final gap = ref.origin.y - head.origin.y;
    if (gap <= _kCollarFollowTargetGap) return world;
    final lift = ((gap - _kCollarFollowTargetGap) * _kCollarFollowGain).clamp(
      0.0,
      _kCollarFollowMaxLift,
    );
    if (lift <= 0) return world;
    final out = Map<String, Affine2D>.from(world);
    final up = Affine2D.translation(0, -lift);
    for (final id in _collarFollowIds) {
      final w = world[id];
      if (w != null) out[id] = up.multiply(w);
    }
    return out;
  }

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
    required Affine2D base,
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
                0.55 *
                clip.danceHeadBobScale,
            0.08,
          )
        : 0.0;
    // R23 panel (animator #1, mocap #3): the head read as a "level bobblehead"
    // — retaining only 26% of the trunk lean nailed it too upright, so it never
    // banked toward the leading stroke. Keep ~37% of the lean (counter-rotate
    // 0.63, was 0.74) so the skull banks WITH the girdle each saw. This is a
    // smooth, phase-locked lean (the retained trunk bank), not a wobble, so the
    // head-stability bound was re-scoped to match the intended bank (0.30 rad,
    // ~17°) while staying under the collar-gap invariant. Held at 0.66 (~34%)
    // rather than lower so the biggest-lean backup clips stay under the bound.
    final rotationCorrection = _isDanceFamily(clip)
        ? -headRotation * 0.66 + danceAttitude + headFollow
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
    // Lateral + vertical follow-through, same lagged-difference model as the
    // rotation: the skull trails the pelvis groove and catches up, so fast
    // pockets read as a head riding a spring, not a bolted mass. Clamped
    // tight — the collar join must never gap.
    final lagged = _isDanceFamily(clip) && clip.duration > 0
        ? evaluator.evaluate(
            clip,
            timeSeconds - clip.duration * _headLagFraction,
          )
        : null;
    // 0.10 → 0.07 (R24): the pelvis lateral commit was amplified so the COM
    // rides over the support foot (mocap#2), which enlarges the head's lateral
    // lag; trim the follow gain so the skull stays inside the collar's
    // lateral-wander band while the body commits harder.
    final headDxFollow = lagged != null
        ? _clampMagnitude((lagged.rootDx - rootDx) * 0.07, 2.5)
        : 0.0;
    // The BOUNCE CASCADE — R20's unanimous finding across all four panel
    // lenses: the skull's vertical trace was "a near pixel-clone" of the
    // hips (measured correlation 0.97 at zero lag), an elevator platform
    // instead of a spine absorbing the bounce. The skull now trails the
    // root bounce by the 2-frame head lag at reduced gain, and the neck by
    // half that — successive breaking: pelvis leads, chest follows, skull
    // arrives last, compressing into each trough and floating off each top.
    // Asymmetric by direction: dropping (negative diff) lets the skull lag
    // UP at full gain — the trough compression every rater asked for — but
    // rising (positive diff) lags the skull DOWN at BELOW the neck's gain,
    // because a neck compresses (chin tuck) far more readily than it
    // extends, and the head-above-neck join invariant must hold at every
    // instant (pouncingCat's big rebound dipped the skull 4.7 units below
    // the throat at the symmetric gain). Scaled by [Clip.danceHeadBobScale]
    // like the rotation follow above, so a clip whose PREMISE is a tight,
    // level skull (pouncingCat, bob scale 0) opts out entirely instead of
    // reading its 75-unit crouch differential as a rubber throat.
    //
    // RE-TUNED 2026-07-05 (owner, with screenshots: "heads bopping around
    // like crazy" — the skull floating a chin-height off the collar): the
    // original gains/clamps (0.44/9, 0.19/4, neck 0.22/5) were tuned before
    // the R21 pocket deepened to a ~55-unit swing, after which the lagged
    // difference SATURATED the clamps on every count — a measured 18-unit
    // chin-to-collar pump per beat (probe: visible gap 10..28, opening on
    // every trough). The artifact is the DIFFERENTIAL between the skull's
    // follow and the collar fabric (which rides the chest at only 0.7 of
    // the NECK's shift), so the compression read survives at half the
    // excursion: the lag TIMING carries the spring, not the amplitude.
    // These values hold the gap pump under ~8 units at full bob scale
    // (measured 2-7 residual with the follows zeroed entirely).
    final cascade = clip.danceHeadBobScale;
    final headDyDiff = lagged != null ? lagged.rootDy - rootDy : 0.0;
    // 9-path round: the skull gets the same halfway-lag the crowns got in
    // the mesh round — every R3 rater measured it phase-locked to the
    // pocket ("the ring is gain-only"). Gains up 0.30/0.13 -> 0.38/0.18,
    // clamps 4/2 -> 5/2.5: still less than half the pre-#73 excursions
    // (0.44/9) that caused the bopping-heads report, and the chin-collar
    // gates (swing < 13, max < 24.5) hold the line — probed after.
    // Owner (GIF review, 2026-07-05): the outward gap is capped but the
    // head "often all but disappears" — the DISAPPEAR side is the rise
    // lag (skull dragged down while the body rises) plus the leveler's
    // downward pull. Rise side cut to 0.10/1.5 (below even the pre-9-path
    // values); the drop side keeps the panel's phase-lag at 0.38/5.
    final headDyFollow = headDyDiff < 0
        ? _clampMagnitude(headDyDiff * 0.38 * cascade, 5)
        : _clampMagnitude(headDyDiff * 0.10 * cascade, 1.5);
    final neckDyFollow = _isDanceFamily(clip) && clip.duration > 0
        ? _clampMagnitude(
            (evaluator
                        .evaluate(
                          clip,
                          timeSeconds - clip.duration * _headLagFraction / 2,
                        )
                        .rootDy -
                    rootDy) *
                0.15 *
                cascade,
            3,
          )
        : 0.0;
    // Per-clip LATERAL NECK-COUNTER: pull the skull back toward the collar
    // centerline by a fraction of its MEASURED lateral offset (whatever the
    // source — pelvic obliquity, spine lean, follow), so a move can drive a
    // deeper hip pop without the skull wandering off the collar. Unlike
    // `_danceHeadHorizontalCounter` (which only cancels the rootDx translation),
    // this cancels the articulated-chain swing that the obliquity produces.
    // Opt-in ([Clip.headLateralStabilize] defaults to 0 -> byte-identical).
    final headWanderAnchor = world[_kThroatBridgeAnchorBone];
    final headWanderCounter =
        (_isDanceFamily(clip) &&
            clip.headLateralStabilize > 0 &&
            headWanderAnchor != null)
        ? -(headWorld.origin.x - headWanderAnchor.origin.x) *
              clip.headLateralStabilize
        : 0.0;
    final headHorizontalCounter = _isDanceFamily(clip)
        ? (_danceHeadHorizontalCounter(rootDx, clip.danceHeadBobScale) +
                      headDxFollow) *
                  baseScale +
              headWanderCounter
        : 0.0;
    // Vertical leveling is a TWO-STAGE spine pass (neck, then head): the head
    // over-travels chiefly through the neck (the torso's crouch arcs it out —
    // neck ~113px vs hips ~74 on pouncingCat), so a head-only counter is glued
    // to that over-travelling neck. Level the neck first, then the head on top.
    final level = _isDanceFamily(clip)
        ? _spineLevelShifts(
            clip,
            headId: headId,
            base: base,
            baseScale: baseScale,
            world: world,
          )
        : const (neckShiftY: 0.0, headExtraShiftY: 0.0, neckId: null);

    // The neck follows 0.65 of the skull's RUNTIME lateral shift (the
    // horizontal counter + dx follow are applied to the head subtree
    // only, which slid the skull off the fixed fur column — the rigging
    // panels' "neck loses ~half its width in deep leans" is the visible
    // overlap sliver narrowing, not the drawable thinning). A fraction,
    // not 1.0, so a hint of flex survives at the join.
    final neckTranslate = Affine2D.translation(
      (headHorizontalCounter + headDxFollow) * 0.65,
      level.neckShiftY + neckDyFollow,
    );
    final headTransform = neckTranslate
        .multiply(
          Affine2D.translation(
            headHorizontalCounter,
            level.headExtraShiftY + headDyFollow,
          ),
        )
        .multiply(stabilizeHead);
    // THROAT BRIDGE: the collar/tie/shirt bones hang off the chest, not the
    // neck, so lifting the neck alone opens an orange gap under the chin. Lift
    // the bridge fabric by a tapering fraction of the neck shift so the collar
    // follows the throat up instead of gapping.
    // The bridge also follows a fraction of the chin's actual LATERAL
    // offset (owner report 2026-07-05, screenshot: "the collar is flying
    // around"): the collar fabric rides the leaning chest top while the
    // firmness-v2 head holds the chin near-still above it — on zanku the
    // fabric sheared ±44-55 units under the face (probe: 87-93 unit
    // swings relative to the chest, double shaku's). Pinning the fabric
    // partway toward the chin's measured x keeps the collar visually
    // seated under the face while still riding the trunk. (The head's
    // COUNTER term alone is useless here — zanku's shear is articulated
    // chain lean, and its counter is only ±2.4 units.)
    final shirtWorld = world[_kThroatBridgeAnchorBone];
    final bridgeLateral = shirtWorld == null
        ? 0.0
        : (headWorld.origin.x - shirtWorld.origin.x) *
              _kThroatBridgeLateralFraction;
    final bridgeTranslate = Affine2D.translation(
      bridgeLateral,
      (level.neckShiftY + neckDyFollow) * _kThroatBridgeFraction,
    );
    final neckId = level.neckId;
    final shifted = Map<String, Affine2D>.of(world);
    for (final bone in rig.bones) {
      if (bone.id == headId || _hasAncestor(bone.id, headId)) {
        shifted[bone.id] = headTransform.multiply(world[bone.id]!);
      } else if (neckId != null &&
          (bone.id == neckId || _hasAncestor(bone.id, neckId))) {
        shifted[bone.id] = neckTranslate.multiply(world[bone.id]!);
      } else if (_kThroatBridgeBones.contains(bone.id)) {
        shifted[bone.id] = bridgeTranslate.multiply(world[bone.id]!);
      }
    }
    return shifted;
  }

  /// Fraction of the neck's level shift applied to the throat-bridge fabric
  /// (collar/tie/shirt) so it follows the lifted neck instead of gapping.
  static const double _kThroatBridgeFraction = 0.7;

  /// The bridge bone whose position stands in for "where the collar sits"
  /// when pinning the fabric toward the chin (rig-specific id, matching
  /// [_kThroatBridgeBones]).
  static const String _kThroatBridgeAnchorBone = 'shirt_v';

  /// Fraction of the chin-to-collar lateral offset the throat-bridge
  /// fabric closes each frame, keeping the collar seated under the face
  /// as the chest leans away beneath it.
  static const double _kThroatBridgeLateralFraction = 0.35;

  /// Collar/tie/shirt bones that bridge the neck to the chest — lifted a
  /// fraction of the neck shift to keep the throat closed under leveling.
  /// (Rig-specific ids; EXPERIMENTAL — promote to a rig/face config if kept.)
  static const Set<String> _kThroatBridgeBones = {
    'collar.L',
    'collar.R',
    'shirt_v',
    'tie',
    'tie_lower',
  };

  /// Fraction of a spine bone's vertical deviation-from-level the leveler pulls
  /// out each frame. Aggressive on purpose: bobbing is capped by each joint's
  /// NATURAL envelope, not by this fraction.
  static const double _kSpineLevelStrength = 1;

  /// How much the leveling EASES OFF at the deepest crouch (0 = hold dead-level
  /// everywhere; 1 = no leveling at the crouch bottom). The panel wanted a small
  /// deliberate head DIP on the two deepest pounce frames so the neck doesn't
  /// stretch tubey and the pounce keeps its weight/anticipation — this lets the
  /// head ride down a fraction of the crouch as it bottoms out, while the holds
  /// stay pinned level.
  static const double _kDeepCrouchEase = 0.5;

  /// The ease is gated on ABSOLUTE crouch depth (local units the torso drops
  /// below its own mean), not a per-clip fraction: a shallow-crouch clip (shaku)
  /// must get ~no dip so its rigid-skull smoothness gate holds, while a deep
  /// pounce dips. Below the deadzone: no ease; at/above full-depth: full ease.
  static const double _kEaseDeadzoneUnits = 20;
  static const double _kEaseFullDepthUnits = 40;

  /// Two-stage spine level shifts (world units): how far to raise/lower the neck
  /// subtree, and the head subtree ON TOP of the neck. Each stage pulls its bone
  /// toward its per-clip mean height, then HARD-CLAMPS its gap-to-parent to that
  /// joint's NATURAL min/max over the loop ([_SpineLevelPlan]) so no joint
  /// separates more than it already does un-leveled. See 2026-07-04-head-level-
  /// probe for why the old rootDy-only counter under-corrected the arc.
  ({double neckShiftY, double headExtraShiftY, String? neckId})
  _spineLevelShifts(
    Clip clip, {
    required String headId,
    required Affine2D base,
    required double baseScale,
    required Map<String, Affine2D> world,
  }) {
    const zero = (neckShiftY: 0.0, headExtraShiftY: 0.0, neckId: null);
    if (clip.duration <= 0 || baseScale == 0) return zero;
    final plan = _spineLevelPlan(clip, headId);
    if (plan == null) return zero;

    final torsoY = world[plan.torsoId]?.ty;
    final neckY = world[plan.neckId]?.ty;
    final headY = world[headId]?.ty;
    if (torsoY == null || neckY == null || headY == null) return zero;

    // Ease the leveling off as the crouch bottoms out, so the head rides a
    // fraction of the deepest dip (weight/anticipation) instead of holding
    // rigidly level and stretching the neck tubey (panel note, 2026-07-04). The
    // ease blends the LEVELED position back toward the un-leveled one AFTER the
    // joint clamps, so it dips the head even where the clamp would otherwise pin
    // the gap (easing strength alone does nothing — the clamp binds; measured).
    final torsoTargetY = base
        .transformPoint(plan.torsoMeanX, plan.torsoMeanY)
        .y;
    // Local units the torso sits below its own mean (negative = above; the
    // clamp below floors it, so a raised torso just gets zero ease).
    final crouchLocal = (torsoY - torsoTargetY) / baseScale;
    final crouchNorm =
        ((crouchLocal - _kEaseDeadzoneUnits) /
                (_kEaseFullDepthUnits - _kEaseDeadzoneUnits))
            .clamp(0.0, 1.0);
    final ease = 1 - _kDeepCrouchEase * crouchNorm; // 1 on holds, <1 deep

    // Per-clip LIFT BUDGET ([Clip.danceHeadLevelClampMin], local units,
    // negative = up): the most the leveling may hold the skull/neck ABOVE
    // where they would ride un-leveled. Honored by the pre-#65 vertical
    // counter and silently dropped in the leveler rewrite; restored so the
    // per-clip taste calls (shaku -5 "rides the crouch", pouncingCat -20
    // "level through the compress") mean what their descriptors say. Only
    // the UPWARD direction is bounded — the downward pull closes the
    // collar, never opens it.
    // Symmetric: the same budget bounds the DOWNWARD pull (2026-07-05,
    // owner: "neck often disappears altogether" — at bounce tops the
    // unbounded down-shift pressed the chin to within ~9 units of the
    // collar line).
    final liftFloor = clip.danceHeadLevelClampMin * baseScale;
    // Down at HALF the lift budget: the downward pull closes the collar
    // over the chin (owner, GIF review: the head "often all but
    // disappears"), so it gets half the headroom the lift does — for
    // every clip, including pouncingCat (whose level-hold probe bound
    // was relaxed 95 -> 98 to absorb the trade; still below the 99.5
    // pre-#65 swing it guards against).
    final dropCeil = -liftFloor * 0.5;

    // Stage 1 — neck level line, clamped to its natural gap-to-torso, then eased
    // back toward the un-leveled neck at the deep crouch.
    final neckTargetY = base.transformPoint(plan.neckMeanX, plan.neckMeanY).y;
    final neckDesiredY = neckY + (neckTargetY - neckY) * _kSpineLevelStrength;
    final neckGap = (neckDesiredY - torsoY).clamp(
      plan.neckTorsoGapMin * baseScale,
      plan.neckTorsoGapMax * baseScale,
    );
    final neckLeveledY = torsoY + neckGap;
    final neckFinalY = neckY + (neckLeveledY - neckY) * ease;
    final neckShiftY = (neckFinalY - neckY).clamp(liftFloor, dropCeil);

    // Stage 2 — head level line, clamped to its natural gap against the fully
    // leveled neck, then eased alongside it (same factor) so the head-neck gap
    // stays inside its natural band at every crouch depth. The head's TOTAL
    // shift shares the neck's lift budget: when both floors bind, the extra
    // shift is zero and the skull rides the crouch together with the neck.
    final headTargetY = base.transformPoint(plan.headMeanX, plan.headMeanY).y;
    final headDesiredY = headY + (headTargetY - headY) * _kSpineLevelStrength;
    final headGap = (headDesiredY - neckLeveledY).clamp(
      plan.headNeckGapMin * baseScale,
      plan.headNeckGapMax * baseScale,
    );
    final headLeveledY = neckLeveledY + headGap;
    final headFinalY = headY + (headLeveledY - headY) * ease;
    final headExtraShiftY =
        (headFinalY - headY).clamp(liftFloor, dropCeil) - neckShiftY;

    return (
      neckShiftY: neckShiftY,
      headExtraShiftY: headExtraShiftY,
      neckId: plan.neckId,
    );
  }

  /// Builds (and memoizes) the per-clip spine-level plan: mean head/neck origins
  /// and each spine joint's natural vertical gap envelope, in local units from
  /// the foot-stabilized solve BEFORE any level counter. No recursion — never
  /// calls [_rigidHeadWorld]. Null if the rig has no head->neck->torso chain.
  _SpineLevelPlan? _spineLevelPlan(Clip clip, String headId) {
    final cached = _spineLevelPlans[clip.name];
    if (cached != null) return cached;
    final neckId = _parentOf(headId);
    final torsoId = neckId == null ? null : _parentOf(neckId);
    if (neckId == null || torsoId == null) return null;

    const samples = 96;
    var neckSx = 0.0;
    var neckSy = 0.0;
    var headSx = 0.0;
    var headSy = 0.0;
    var torsoSx = 0.0;
    var torsoSy = 0.0;
    var neckTorsoMin = double.infinity;
    var neckTorsoMax = double.negativeInfinity;
    var headNeckMin = double.infinity;
    var headNeckMax = double.negativeInfinity;
    for (var i = 0; i < samples; i++) {
      final t = clip.duration * i / samples;
      final posed = _resolvedPose(clip, t, breath: 0);
      final stabilized = _danceSupportFootStabilizedWorld(
        clip,
        t,
        solver.solve(posed),
      );
      final head = stabilized[headId]!.origin;
      final neck = stabilized[neckId]!.origin;
      final torso = stabilized[torsoId]!.origin;
      neckSx += neck.x;
      neckSy += neck.y;
      headSx += head.x;
      headSy += head.y;
      torsoSx += torso.x;
      torsoSy += torso.y;
      final neckTorso = neck.y - torso.y;
      final headNeck = head.y - neck.y;
      neckTorsoMin = math.min(neckTorsoMin, neckTorso);
      neckTorsoMax = math.max(neckTorsoMax, neckTorso);
      headNeckMin = math.min(headNeckMin, headNeck);
      headNeckMax = math.max(headNeckMax, headNeck);
    }
    final plan = _SpineLevelPlan(
      neckId: neckId,
      torsoId: torsoId,
      neckMeanX: neckSx / samples,
      neckMeanY: neckSy / samples,
      headMeanX: headSx / samples,
      headMeanY: headSy / samples,
      torsoMeanX: torsoSx / samples,
      torsoMeanY: torsoSy / samples,
      neckTorsoGapMin: neckTorsoMin,
      neckTorsoGapMax: neckTorsoMax,
      headNeckGapMin: headNeckMin,
      headNeckGapMax: headNeckMax,
    );
    _spineLevelPlans[clip.name] = plan;
    return plan;
  }

  /// The parent bone id of [id], or null if root-parented / unknown.
  String? _parentOf(String id) {
    for (final bone in rig.bones) {
      if (bone.id == id) return bone.parent;
    }
    return null;
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
    //
    // HALVED AGAIN 2026-07-05 (owner, live: "heads are terribly loose"): a
    // probe of the skull's lateral offset from the collar fabric measured
    // 13-23 unit swings across the catalogue — this counter (plus the
    // lagged dx follow) was parking the skull up to ~11 units off-center at
    // every sway extreme. Half the fraction keeps the inertial read; the
    // skull now rides within a few units of the collar line.
    const neutralDanceRootDx = 0.0;
    final fraction = 0.07 + (1 - headBobScale) * 0.10;
    return -(rootDx - neutralDanceRootDx) * fraction;
  }

  double _danceHeadAttitude(double p) {
    double pulse(double centre, double width) {
      final distance = _cyclicDistance(p, centre);
      if (distance >= width) return 0;
      final t = 1 - distance / width;
      return t * t * (3 - 2 * t);
    }

    // Deliberate accents the audience can actually see: panel round 1 read
    // the old ~1-degree pulses as a "gimbal-stabilized" dead head on every
    // move. These stay far from rubber bobble but let the skull answer the
    // beat.
    return -0.034 * pulse(1 / 8, 1 / 18) +
        0.034 * pulse(3 / 8, 1 / 18) -
        0.03 * pulse(5 / 8, 1 / 18) +
        0.042 * pulse(15 / 16, 1 / 16);
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

  /// Resolves which SIDE of a mid-blend [clip] (and its OWN clock) any
  /// contact-span-derived value should read — a blended clip's
  /// `contactSpans` is the UNION of both sides' spans (see
  /// `_transitionSpans`), so evaluating that union against the shared blend
  /// clock (which tracks the INCOMING clip's own phrase from the first
  /// blended frame — see `_blendStage`'s `seconds: to.seconds`) can pick the
  /// wrong span, or the right span at the wrong phase within it. Every
  /// contact-span consumer that isn't ALREADY blend-weighted (unlike e.g.
  /// `_transitionSupportAnchorStrength`, a continuous value) needs this
  /// same per-side resolution — same midpoint-switch pattern as
  /// `enforceSoleFloor`/`zOrderSwaps` in `blendedClip`, matching how
  /// `_transitionContactLockedPose` already handles the ROOT delta.
  ({Clip clip, double timeSeconds}) _contactSourceFor(
    Clip clip,
    double timeSeconds,
  ) {
    final plan = clip.transitionPlan;
    if (plan == null) return (clip: clip, timeSeconds: timeSeconds);
    return plan.weight < 0.5
        ? (
            clip: plan.from,
            timeSeconds: timeSeconds + plan.fromTimeShiftSeconds,
          )
        : (clip: plan.to, timeSeconds: timeSeconds);
  }

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
    // Confirmed via transitions-r6 world-bone probing: shaku's own contact
    // lock (correctly stabilizing its plant every frame right up to a
    // shaku->buga cut) got evaluated one frame later against buga's fresh
    // near-zero clock, and the resulting correction dragged the support
    // leg ~30 world units in a single 60fps frame with no other channel
    // moving at all — see [_contactSourceFor].
    final source = _contactSourceFor(clip, timeSeconds);
    final contactClip = source.clip;
    final contact = _activeContactAt(
      contactClip,
      _clipPhase(contactClip, source.timeSeconds),
    );
    if (contact == null) return world;
    final boneId = contact.span.bone;
    final current = world[boneId];
    final contactPoint = _contactPoint(world, boneId);
    if (current == null || contactPoint == null) return world;

    final anchorPose = evaluator.evaluate(
      contactClip,
      contact.anchorPhase * contactClip.duration,
    );
    final anchorWorld = solver.solve(anchorPose);
    final anchor = anchorWorld[boneId];
    if (anchor == null) return world;

    final contactStrength = _contactLockStrength(
      contactClip,
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
    // Ramp begins at CHEST height (was shoulder height, y≈-34) so a compact
    // chest-carried working arm — shaku's saw fist rides y≈-37, never near the
    // old shoulder-line start — already earns a deltoid hike that rises with the
    // fist, reaching full response by shoulder height and overhead. Rig-level
    // fix for the panel's "shoulder line stays horizontal / forearms pinned to
    // the deltoid" on the COMPACT catalogue (the shrug engaged fine on
    // wide/overhead moves like buga, but was dormant at chest height).
    final raised = smoothstep((-sample.y - 20) / 45);
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

  bool _isFootBone(String boneId) => boneId.toLowerCase().contains('foot');

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
    // Each side gets its OWN phase — sharing one phase derived from the
    // blended clip (whose duration is always `to.duration`) reads `from`'s
    // contact span at the wrong point in ITS OWN phrase, same class of bug
    // as `_contactSourceFor` fixes for the non-blending consumers above.
    final weight = smoothstep(transition.weight);
    final outgoing = _contactLockRootDelta(
      source: transition.from,
      phase: _clipPhase(
        transition.from,
        timeSeconds + transition.fromTimeShiftSeconds,
      ),
      pose: pose,
      scale: 1 - weight,
    );
    final incoming = _contactLockRootDelta(
      source: transition.to,
      phase: _clipPhase(transition.to, timeSeconds),
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
      if (pitch >= -0.02) continue;

      // The toe must be the WEIGHT-BEARING end: lower than the heel and
      // near the frame's ground. An airborne pointed toe keeps its sole
      // straight; a dig or heel-lift bends it. The crease starts almost as
      // soon as the heel peels and bends hard through the roll — the owner
      // read the old late/shallow flex as a rigid slab tilting on its edge.
      if (tip.y <= heel.y + 2) continue;
      final gap = frameFloorY - tip.y;
      final proximity = (1 - gap / 26).clamp(0.0, 1.0);
      if (proximity <= 0) continue;

      final flex = (-pitch - 0.02) * 1.65 * proximity;
      // Cap inside the toe_flex dancer envelope (0.8 rad) — a sole creases
      // hard through the roll but never folds past ~45 degrees.
      final delta = flex.clamp(0.0, 0.78);
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
  ///
  /// Before the per-joint clamps it applies the coupled arm anti-fold rule
  /// ([armFoldCorrections]) — the contralateral elbows-pinched-at-the-sternum
  /// fold that no single-joint range can see.
  Pose _jointLimitedPose(Pose pose) {
    Map<String, JointPose>? joints;
    final folds = armFoldCorrections(pose);
    for (final fold in folds.entries) {
      final joint = pose.jointOf(fold.key);
      joints ??= Map<String, JointPose>.of(pose.joints);
      joints[fold.key] = JointPose(
        rotation: joint.rotation + fold.value,
        scaleX: joint.scaleX,
        scaleY: joint.scaleY,
      );
    }
    for (final bone in _limitedBones) {
      final limit = bone.rotationLimit!;
      final joint = joints?[bone.id] ?? pose.jointOf(bone.id);
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

  /// Shoulder→elbow→hand chains for the coupled arm anti-fold rule, discovered
  /// by the same id convention the other passes use (`toe_flex`, `clavicle`).
  late final List<({Bone upper, Bone lower, Bone end})> _armFoldChains = [
    for (final upper in rig.bones)
      if (upper.id.toLowerCase().contains('arm_upper'))
        for (final lower in rig.bones)
          if (lower.parent == upper.id &&
              lower.id.toLowerCase().contains('arm_lower'))
            for (final end in rig.bones)
              if (end.parent == lower.id &&
                  end.id.toLowerCase().contains('hand'))
                (upper: upper, lower: lower, end: end),
  ];

  /// Lateral-side elbow flexion available when the upper arm is NOT adducted
  /// (hanging or abducted): in this 2D rig the bend side stands in for
  /// humeral rotation, so a free humerus may flex on either side almost to
  /// the hinge stop (the elbow ROM clamp owns the extremes).
  static const double _kArmFoldNeutralLateralFlex = 2.6;

  /// How fast the lateral-flexion allowance collapses as the humerus adducts
  /// across the chest: internal rotation locks the hinge plane, and by
  /// ~0.65 rad of adduction the forearm can no longer break outboard at all.
  static const double _kArmFoldAdductionSlope = 4;

  /// Adduction (medial upper-arm tilt from body-down) beyond which the rule
  /// stops applying: the arm is heading overhead-across, where humeral
  /// rotation freedom returns and outboard forearms are legal again.
  static const double _kArmFoldAdductionCutoff = 1.55;

  /// Elbow local-rotation corrections that remove anatomically impossible
  /// contralateral folds, keyed by forearm bone id.
  ///
  /// Per-joint ROM clamps cannot catch this pose: every joint is individually
  /// inside its range. The impossibility is COUPLED — when the upper arm is
  /// adducted across the chest (elbow swung toward the body midline, below
  /// the shoulder) the humerus is internally rotated, so the forearm can only
  /// continue toward the midline; it cannot break back outboard ("elbows
  /// pinched at the sternum, paws flared out"). The metered quantity is the
  /// RELATIVE elbow bend: lateral-side flexion is unrestricted on a free
  /// humerus and collapses to zero as adduction grows, relaxing again as the
  /// arm raises overhead where humeral rotation freedom returns.
  Map<String, double> armFoldCorrections(Pose pose) {
    if (_armFoldChains.length < 2) return const {};
    Map<String, double>? corrections;
    final world = solver.solve(pose);
    for (final chain in _armFoldChains) {
      final upperWorld = world[chain.upper.id];
      final lowerWorld = world[chain.lower.id];
      final endWorld = world[chain.end.id];
      if (upperWorld == null || lowerWorld == null || endWorld == null) {
        continue;
      }
      final shoulder = upperWorld.origin;
      final elbow = lowerWorld.origin;
      final wrist = endWorld.origin;
      // Medial = toward the OTHER shoulder, in the girdle's own frame — the
      // root's lateral weight commits and trunk banks move the body midline
      // far off world x = 0.
      final other = _armFoldChains.firstWhere(
        (c) => !identical(c, chain),
        orElse: () => chain,
      );
      final otherWorld = world[other.upper.id];
      if (otherWorld == null || identical(other, chain)) continue;
      final otherShoulder = otherWorld.origin;
      final medialX = otherShoulder.x - shoulder.x;
      final medialY = otherShoulder.y - shoulder.y;
      final medialLength = math.sqrt(medialX * medialX + medialY * medialY);
      if (medialLength < 1e-6) continue;
      final mx = medialX / medialLength;
      final my = medialY / medialLength;
      // Body-down = the girdle perpendicular that points toward gravity.
      var dx = -my;
      var dy = mx;
      if (dy < 0) {
        dx = -dx;
        dy = -dy;
      }
      final upperMedial =
          (elbow.x - shoulder.x) * mx + (elbow.y - shoulder.y) * my;
      final upperDown =
          (elbow.x - shoulder.x) * dx + (elbow.y - shoulder.y) * dy;
      // Signed tilt of the upper arm from body-down; + = adducted.
      final adduction = math.atan2(upperMedial, upperDown);
      if (adduction >= _kArmFoldAdductionCutoff) continue;
      final foreMedial = (wrist.x - elbow.x) * mx + (wrist.y - elbow.y) * my;
      final foreDown = (wrist.x - elbow.x) * dx + (wrist.y - elbow.y) * dy;
      // Signed tilt of the forearm from body-down; - = breaking outboard.
      final foldTilt = math.atan2(foreMedial, foreDown);
      // The RELATIVE elbow bend (forearm vs upper arm) is what anatomy
      // limits: lateral-side flexion is fine on a free humerus (a reach, a
      // hammer curl) and impossible on one adducted across the chest.
      final relativeBend = _shortestAngle(foldTilt - adduction);
      final allowance =
          math.max(
            0,
            _kArmFoldNeutralLateralFlex -
                _kArmFoldAdductionSlope * math.max(0, adduction),
          ) +
          math.max(0, (adduction - 1.15) * 2.2);
      if (relativeBend >= -allowance) continue;
      // Illegal arc is (-pi, -allowance); clamp to the nearer boundary that
      // the elbow's own ROM can actually reach — otherwise the ROM clamp
      // that runs after would drag the forearm back into the illegal arc.
      final toCarryBoundary = -allowance - relativeBend;
      final toOverheadBoundary = relativeBend + math.pi;
      // foldTilt grows toward medial; whether that is a positive or negative
      // world rotation depends on which way medial points for this arm.
      final medialSign = mx >= 0 ? 1.0 : -1.0;
      final ordered = toCarryBoundary <= toOverheadBoundary
          ? [toCarryBoundary, -toOverheadBoundary]
          : [-toOverheadBoundary, toCarryBoundary];
      final currentLocal = pose.jointOf(chain.lower.id).rotation;
      final limit = chain.lower.rotationLimit;
      var localDelta = -medialSign * ordered.first;
      for (final tiltDelta in ordered) {
        final candidate = currentLocal + -medialSign * tiltDelta;
        if (limit == null ||
            (limit.clampAngle(candidate) - candidate).abs() < 1e-9) {
          localDelta = -medialSign * tiltDelta;
          break;
        }
      }
      // Emit the branch-normalized equivalent so a large correction lands on
      // a sane (-pi, pi] joint value instead of a +-2pi representation.
      localDelta = _shortestAngle(currentLocal + localDelta) - currentLocal;
      corrections ??= <String, double>{};
      corrections[chain.lower.id] = localDelta;
    }
    return corrections ?? const {};
  }

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
  /// (its contact-span start), plus a `blend` that fades to 0 at the span
  /// edges (shared by X) and a `blendY` that additionally folds in
  /// [Clip.supportFootWorldAnchorVerticalBoost] — see that field's doc
  /// comment for why the vertical pull can be strengthened independently.
  /// Returns null unless the clip opts in via [Clip.supportFootWorldAnchor].
  ({String bone, double x, double y, double blend, double blendY})?
  _supportFootWorldAnchor(Clip clip, double phase) {
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
    final blendY = clip.supportFootWorldAnchorVerticalBoost <= 0
        ? blend
        : _supportFootAnchorBlend(
            span,
            contact.strengthPhase,
            (clip.supportFootWorldAnchorStrength +
                    clip.supportFootWorldAnchorVerticalBoost)
                .clamp(0.0, 1.0),
          );
    return (
      bone: span.bone,
      x: origin.x,
      y: origin.y,
      blend: blend,
      blendY: blendY,
    );
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
    final fadeIn = smoothstep((p - span.start) / fade);
    final fadeOut = smoothstep((span.end - p) / fade);
    final edge = fadeIn < fadeOut ? fadeIn : fadeOut;
    return strength * edge;
  }

  double _supportComEnvelope(Clip clip, GroundSpan span) {
    // Envelope ≈ ~1.1× half the stance width commits the pelvis over the stance
    // ankle (shaku's committed ratio). zanku (46 vs ±88) and buga (58 vs ±102)
    // already sit near that; azonto and sekem were the loose ones (ratio ~1.5-1.8)
    // — tighten them so their pelvis commits like shaku's (R31 roll-out).
    if (clip.name == 'zanku') return 40;
    if (clip.name == 'sekem') return 37;
    // R31 catalogue re-tune (mocap): azonto under-committed at 58 — tighten to
    // bump the commit up, but only to 40: at 28 the harder commit made the head
    // wander 20.8 past the chin-to-collar band (the head-follow lag scales with
    // the pelvis swing), so 40 is the most commit that stays inside it. buga
    // stays at 58 (its wide ±102 stance makes committing over the foot inherently
    // wide travel; loosening pushed the pelvis off the foot and failed the
    // hips-over-shoe bound — buga's polish is the counter strength). zanku/sekem
    // read clean.
    if (clip.name == 'buga') return 58;
    if (clip.name == 'azonto') return 40;
    // R29 mocap #1: shaku's wide 64 envelope let the pelvis sit central (the
    // COM never committed over the stance ankle — weight read as spine-tilt, not
    // translation). Tighten to 24 so the pre-IK balance pass pulls the pelvis
    // ~half the (now compact ~±42) stance width over the planted foot each beat
    // — a real hip weight-shift, the signature Afrobeats pelvis drive. Backups
    // stay wider (background dancers, less scrutinised).
    if (clip.name == 'shaku') return 24;
    if (clip.name.startsWith('danceBackup')) return 64;
    if (clip.name == 'pouncingCat') return 62;
    final spanLength = span.end - span.start;
    return spanLength <= 0.135 ? 50 : 62;
  }

  double _supportComBlend(Clip clip, GroundSpan span, double p) {
    final spanLength = span.end - span.start;
    final fade = (spanLength * 0.28).clamp(0.05, 0.1);
    final fadeIn = smoothstep((p - span.start) / fade);
    final fadeOut = smoothstep((span.end - p) / fade);
    final edge = fadeIn < fadeOut ? fadeIn : fadeOut;
    final base = spanLength <= 0.135
        ? 0.72
        : spanLength <= 0.26
        ? 0.58
        // 0.26 -> 0.45: R16 rigging pixel-diffed both planted shoes sliding
        // ~half a shoe length during the lunge hold — the weak long-span
        // hold let the plants ride the (now much deeper) weight sway. The
        // head-whip concern that motivated 0.26 is re-checked by the
        // rigid-skull gate, which stays green at 0.45.
        : (clip.name == 'shaku' || clip.name.startsWith('danceBackup'))
        ? 0.45
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
        // 0.16 -> 0.24 alongside the deeper weight sway: the planted shoe
        // needs a firmer lateral hold or the committed pelvis drags it.
        : (clip.name == 'shaku' || clip.name.startsWith('danceBackup'))
        ? 0.24
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
    final fadeIn = smoothstep((p - span.start) / fade);
    // Dance spans RELEASE over a longer tail than they engage: a dancer
    // unloads the trailing foot across the last beat of its stance before
    // the peel, so the root hold must let the weight DEPART early. With
    // the symmetric ~1.5-frame fade the lock's x-correction fought the
    // authored weight transfer until the span flipped and then let go all
    // at once — measured as a ~9-unit rightward bump at f31 on shaku and
    // the seam snap-back all four R25 raters flagged (probe: zeroing the
    // x-hold alone turned the crammed 1.5-beat return into a clean
    // 2.5-beat ease). Mid-span strength is unchanged, so the anti-skate
    // hold the drift gates measure still applies through the stance.
    // The early release applies to X ONLY: the weight departs the trailing
    // foot sideways, but the sole stays vertically GROUNDED until the
    // actual peel (R27 rigging measured the plant sagging over its final
    // 1.5 beats when R26 widened the whole edge).
    final fadeOutWidth = dance ? (spanLength * 0.5).clamp(0.044, 0.12) : fade;
    final fadeOutX = smoothstep((span.end - p) / fadeOutWidth);
    final fadeOutY = smoothstep((span.end - p) / fade);
    // Vertical grounding also ENGAGES faster than the lateral hold: a sole
    // that arrives dead (the tension-1 plants) is on the floor at once —
    // the R30 seam verifier measured the wrap-span plant riding ~30px down
    // with the seam dive while its y-lock was still fading in over ~1.4
    // frames, sinking the very floor the free foot is clamped against. The
    // lateral anti-skate keeps the gentler engage (a hard lateral grab at
    // first contact reads as a snap).
    final fadeInY = dance
        ? smoothstep((p - span.start) / (fade * 0.65))
        : fadeIn;
    final edgeX = fadeIn < fadeOutX ? fadeIn : fadeOutX;
    final edgeY = fadeInY < fadeOutY ? fadeInY : fadeOutY;
    return (x: baseX * edgeX, y: baseY * edgeY);
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

  /// The tie's cloth-pendulum links, ordered knot→blade so the secondary-follow
  /// gradient (base barely moves, tip whips) reads as fabric. Root first: the
  /// shorter id (`tie`) is the knot, its child (`tie_lower`) the blade.
  List<String> _tieBoneIds() {
    final ids = [
      for (final bone in rig.bones)
        if (bone.id.toLowerCase() == 'tie' ||
            bone.id.toLowerCase().startsWith('tie_'))
          bone.id,
    ]..sort((a, b) => a.length.compareTo(b.length));
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

/// Per-clip data for the dance spine leveler (see
/// `CharacterScene._spineLevelShifts`): the head/neck "level lines" and each
/// spine joint's natural vertical gap envelope, in local units.
class _SpineLevelPlan {
  const _SpineLevelPlan({
    required this.neckId,
    required this.torsoId,
    required this.neckMeanX,
    required this.neckMeanY,
    required this.headMeanX,
    required this.headMeanY,
    required this.torsoMeanX,
    required this.torsoMeanY,
    required this.neckTorsoGapMin,
    required this.neckTorsoGapMax,
    required this.headNeckGapMin,
    required this.headNeckGapMax,
  });

  final String neckId;
  final String torsoId;
  final double neckMeanX;
  final double neckMeanY;
  final double headMeanX;
  final double headMeanY;
  final double torsoMeanX;
  final double torsoMeanY;
  final double neckTorsoGapMin;
  final double neckTorsoGapMax;
  final double headNeckGapMin;
  final double headNeckGapMax;
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
