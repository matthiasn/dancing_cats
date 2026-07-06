import 'dart:math' as math;

import 'package:dancing_cats/features/character/model/dance_dynamics.dart';
import 'package:dancing_cats/features/character/model/easing.dart';
import 'package:dancing_cats/features/character/model/pose.dart';

/// Produces a [JointPose] for one bone given a normalized cycle phase `p`
/// in 0..1. Two flavours exist: [SineChannel] for cyclic motion (walk/run) and
/// [KeyframeChannel] for one-shots (sit/jump). New cycles are just new data —
/// no new code — which is the whole point of the data-driven design.
sealed class JointChannel {
  const JointChannel();

  JointPose sample(double p);
}

/// Adds several joint channels together.
///
/// Rotation is additive. Scale is multiplicative because each child channel is
/// authored as a multiplier around `1`; multiplying preserves that contract and
/// lets small pulse layers sit on top of a larger squash/stretch performance.
class LayeredJointChannel extends JointChannel {
  const LayeredJointChannel(this.channels);

  final List<JointChannel> channels;

  @override
  JointPose sample(double p) {
    var rotation = 0.0;
    var scaleX = 1.0;
    var scaleY = 1.0;
    for (final channel in channels) {
      final pose = channel.sample(p);
      rotation += pose.rotation;
      scaleX *= pose.scaleX;
      scaleY *= pose.scaleY;
    }
    return JointPose(rotation: rotation, scaleX: scaleX, scaleY: scaleY);
  }
}

/// Blends two sampled joint channels.
///
/// This is the small runtime mixer primitive used for dance transitions: the
/// painter and solver still receive a normal [Clip], but its channels can fade
/// from one move into the next instead of hard-cutting between unrelated poses.
class BlendedJointChannel extends JointChannel {
  const BlendedJointChannel({
    required this.weight,
    this.from,
    this.to,
    this.fromTimeShift = 0,
    this.fromDuration = 0,
  }) : assert(weight >= 0 && weight <= 1, 'weight must be in 0..1');

  final JointChannel? from;
  final JointChannel? to;
  final double weight;

  /// Seconds ADDED to the outgoing side's sample time, wrapped into
  /// [fromDuration] — lets a transition keep the outgoing clip on its OWN
  /// phrase clock while the incoming clip enters on a re-anchored one (the
  /// bar-1 entry alignment). Zero = both sides share the clock (the
  /// original behavior).
  final double fromTimeShift;

  /// The outgoing clip's duration, for wrapping [fromTimeShift]; 0 = no wrap.
  final double fromDuration;

  @override
  JointPose sample(double p) {
    final a = from?.sample(_shifted(p, fromTimeShift, fromDuration)) ??
        JointPose.identity;
    final b = to?.sample(p) ?? JointPose.identity;
    return JointPose(
      rotation: _lerp(a.rotation, b.rotation, weight),
      scaleX: _lerp(a.scaleX, b.scaleX, weight),
      scaleY: _lerp(a.scaleY, b.scaleY, weight),
    );
  }
}

/// The outgoing side's shifted-and-wrapped sample time for a blended channel.
double _shifted(double p, double shift, double duration) {
  if (shift == 0) return p;
  if (duration <= 0) return p + shift;
  final t = (p + shift) % duration;
  return t < 0 ? t + duration : t;
}

/// Wraps [inner] so it samples a warped phase instead of the raw one.
///
/// This is the split-clock Effort mechanism's only touch point: [warpPhase]
/// reshapes *when within a beat* the wrapped bone samples its authored
/// channel, while every other bone (in particular the root, legs, and feet)
/// keeps sampling the shared, unwarped clock. See
/// `upperBodyDynamicsWarpedClip` in `dance_dynamics_warp.dart`, the sole
/// place that constructs one of these.
class PhaseWarpedJointChannel extends JointChannel {
  const PhaseWarpedJointChannel(this.inner, this.warpPhase);

  final JointChannel inner;
  final double Function(double p) warpPhase;

  @override
  JointPose sample(double p) => inner.sample(warpPhase(p));
}

/// The [IkTargetChannel] counterpart of [PhaseWarpedJointChannel], used to warp
/// hand IK targets (never foot targets — those must stay on the shared clock).
class PhaseWarpedIkTargetChannel extends IkTargetChannel {
  const PhaseWarpedIkTargetChannel(this.inner, this.warpPhase);

  final IkTargetChannel inner;
  final double Function(double p) warpPhase;

  @override
  IkTargetPose sample(double p) => inner.sample(warpPhase(p));
}

/// Maps the global 0..1 transition progress into a local blend window.
///
/// A plain per-bone mask that never reaches `1` would pop when a temporary
/// transition clip is replaced by the incoming clip. Windows solve that by
/// letting layers start late or finish early while still arriving at the target
/// by the end of the transition.
class ClipBlendWindow {
  const ClipBlendWindow({
    this.start = 0,
    this.end = 1,
  }) : assert(start >= 0 && start <= 1, 'start must be in 0..1'),
       assert(end >= 0 && end <= 1, 'end must be in 0..1'),
       assert(start <= end, 'start must not be after end');

  static const full = ClipBlendWindow();

  final double start;
  final double end;

  double transform(double weight) {
    assert(weight >= 0 && weight <= 1, 'weight must be in 0..1');
    if (start == 0 && end == 1) return weight;
    if (start == end) return weight < start ? 0 : 1;
    final local = ((weight - start) / (end - start)).clamp(0.0, 1.0);
    return _smoothUnit(local);
  }
}

/// Per-layer blend timing for a temporary [blendedClip].
///
/// This is the first small DanceMixer primitive: body/root/support can settle on
/// one timing, hands can lag, and tail/ears/tie can follow last without creating
/// a hard jump when the transition clip expires.
class ClipBlendMask {
  const ClipBlendMask({
    this.root = ClipBlendWindow.full,
    this.defaultJoint = ClipBlendWindow.full,
    this.joints = const <String, ClipBlendWindow>{},
    this.defaultLimbTarget = ClipBlendWindow.full,
    this.limbTargets = const <String, ClipBlendWindow>{},
  });

  static const full = ClipBlendMask();

  final ClipBlendWindow root;
  final ClipBlendWindow defaultJoint;
  final Map<String, ClipBlendWindow> joints;
  final ClipBlendWindow defaultLimbTarget;
  final Map<String, ClipBlendWindow> limbTargets;

  double rootWeight(double weight) => root.transform(weight);

  double jointWeight(String boneId, double weight) =>
      (joints[boneId] ?? defaultJoint).transform(weight);

  double limbTargetWeight(String endBoneId, double weight) =>
      (limbTargets[endBoneId] ?? defaultLimbTarget).transform(weight);
}

/// Cyclic joint motion as a phase-shifted sinusoid plus an optional second
/// harmonic (for the sharper snap of a knee/elbow that a pure sine can't make).
///
/// `rotation = bias + amplitude*sin(2π(p)+phase) + harmonicAmp*sin(2π·H(p)+...)`
class SineChannel extends JointChannel {
  const SineChannel({
    this.amplitude = 0,
    this.phase = 0,
    this.bias = 0,
    this.harmonicAmplitude = 0,
    this.harmonicPhase = 0,
    this.harmonicMultiplier = 2,
    this.scaleYAmplitude = 0,
    this.scaleYPhase = 0,
    this.scaleYHarmonic = 1,
    this.scaleXAmplitude = 0,
    this.scaleXPhase = 0,
    this.scaleXHarmonic = 1,
  });

  /// Primary rotation amplitude in radians.
  final double amplitude;

  /// Phase offset in turns (0..1); shifting legs/arms apart is how a walk is
  /// built. Expressed in turns so authoring reads as "half a cycle later".
  final double phase;

  /// Static rotation offset in radians, added every frame.
  final double bias;

  final double harmonicAmplitude;
  final double harmonicPhase;
  final double harmonicMultiplier;

  /// Squash/stretch oscillation (multiplier delta around 1). The `*Harmonic`
  /// fields set the frequency: a walk takes weight **twice** per cycle, so a
  /// body-squash uses harmonic 2 to compress on each footfall. Pairing a
  /// negative `scaleYAmplitude` with a positive `scaleXAmplitude` (or vice
  /// versa) preserves volume — the classic squash that sells weight.
  final double scaleYAmplitude;
  final double scaleYPhase;
  final double scaleYHarmonic;

  final double scaleXAmplitude;
  final double scaleXPhase;
  final double scaleXHarmonic;

  @override
  JointPose sample(double p) {
    const twoPi = 2 * math.pi;
    final rot =
        bias +
        amplitude * math.sin(twoPi * (p + phase)) +
        harmonicAmplitude *
            math.sin(twoPi * harmonicMultiplier * (p + harmonicPhase));
    final scaleY = scaleYAmplitude == 0
        ? 1.0
        : 1 +
              scaleYAmplitude *
                  math.sin(twoPi * scaleYHarmonic * (p + scaleYPhase));
    final scaleX = scaleXAmplitude == 0
        ? 1.0
        : 1 +
              scaleXAmplitude *
                  math.sin(twoPi * scaleXHarmonic * (p + scaleXPhase));
    return JointPose(rotation: rot, scaleX: scaleX, scaleY: scaleY);
  }
}

/// A single keyframe for a [KeyframeChannel].
class Keyframe {
  const Keyframe({
    required this.p,
    this.rotation = 0,
    this.scaleX = 1,
    this.scaleY = 1,
    this.ease = Ease.easeInOut,
    this.easeFn,
    this.tension = 0,
  }) : assert(
         tension >= -1 && tension <= 1,
         'tension must be in -1..1',
       );

  /// Phase position of the key, 0..1.
  final double p;
  final double rotation;
  final double scaleX;
  final double scaleY;

  /// Easing applied on the segment *leading into* this key.
  final Ease ease;

  /// Optional open-ended easing for the segment leading into this key, used in
  /// preference to [ease] when set (the fixed [ease] is the fallback). Unlike
  /// [ease] it may leave 0..1 to inject anticipation/overshoot — this is how a
  /// `DanceDynamics`-driven accent reshapes its drive-in. Honoured only on the
  /// per-segment (non-`smooth`) interpolation path; the Catmull-Rom `smooth`
  /// path ignores per-key easing entirely — accents on the smooth path are
  /// authored with [tension] instead.
  final EaseCurve? easeFn;

  /// Kochanek–Bartels-style tangent tension for the `smooth` path, applied to
  /// THIS key's tangent in both adjacent segments (so continuity is kept by
  /// construction). `0` = plain Catmull-Rom flow. `1` = zero tangent: the
  /// motion ARRIVES DEAD at this key and accelerates away — a stamp, a hit, a
  /// moving hold. Negative values loosen the tangent for overshoot. This is
  /// what lets flow and beat-attack compose on one channel: flow between
  /// keys, attack exactly at the accent keys.
  final double tension;
}

/// One-shot joint motion as eased keyframes. Keys must be sorted by [Keyframe.p]
/// and span 0..1.
///
/// [phase] shifts the sample point (0..1, wrapping) so a single authored cycle
/// can drive two limbs half a beat apart — e.g. the left and right legs share
/// one step cycle, the right at `phase: 0.5`. It is only meaningful for looping
/// clips whose first and last keys match; one-shots leave it at 0.
class KeyframeChannel extends JointChannel {
  const KeyframeChannel(
    this.keys, {
    this.phase = 0,
    this.smooth = false,
    this.cyclic = false,
  });

  final List<Keyframe> keys;
  final double phase;

  /// When true, interpolate with a **periodic Catmull-Rom spline** (smooth
  /// tangents through every key) instead of per-segment easing. Per-segment
  /// `easeInOut` decelerates the joint to a *stop at every keyframe*, which on a
  /// cyclic clip reads as a frame-to-frame stutter ("it jumps around"). A spline
  /// flows *through* the keys with continuous velocity — limbs only slow at the
  /// real turnarounds (where the value reverses), which is what reads as a
  /// continuous walk. Requires the first and last keys to match (a closed loop);
  /// use it for cyclic clips, leave it off for one-shots (where the per-key
  /// ease, incl. `*Back` settles, is intentional).
  final bool smooth;

  /// When true, key phases are treated as a wrapping cycle instead of a clamped
  /// range. This is for looping dance channels whose authored keys may land a
  /// fraction before frame 0 or after the last frame because of micro-timing.
  final bool cyclic;

  @override
  JointPose sample(double rawP) {
    final shifted = rawP + phase;
    final p = cyclic
        ? _unitPhase(shifted)
        : phase == 0
        ? rawP
        : _unitPhase(shifted);
    if (keys.isEmpty) return JointPose.identity;
    if (cyclic) return _sampleCyclic(p);
    if (p <= keys.first.p) return _poseOf(keys.first);
    if (p >= keys.last.p) return _poseOf(keys.last);

    for (var i = 0; i < keys.length - 1; i++) {
      final k0 = keys[i];
      final k1 = keys[i + 1];
      if (p >= k0.p && p <= k1.p) {
        final span = k1.p - k0.p;
        final local = span == 0 ? 0.0 : (p - k0.p) / span;
        if (smooth) {
          return JointPose(
            rotation: _spline(i, local, span, (k) => k.rotation),
            scaleX: _spline(i, local, span, (k) => k.scaleX),
            scaleY: _spline(i, local, span, (k) => k.scaleY),
          );
        }
        final t = k1.easeFn?.call(local) ?? k1.ease.apply(local);
        return JointPose(
          rotation: k0.rotation + (k1.rotation - k0.rotation) * t,
          scaleX: k0.scaleX + (k1.scaleX - k0.scaleX) * t,
          scaleY: k0.scaleY + (k1.scaleY - k0.scaleY) * t,
        );
      }
    }
    return JointPose.identity;
  }

  JointPose _poseOf(Keyframe k) =>
      JointPose(rotation: k.rotation, scaleX: k.scaleX, scaleY: k.scaleY);

  JointPose _sampleCyclic(double p) {
    final cyclicKeys = _normalizedCyclicKeys(keys, (key) => key.p);
    if (cyclicKeys.isEmpty) return JointPose.identity;
    if (cyclicKeys.length == 1) return _poseOf(cyclicKeys.single.key);

    final segment = _cyclicSegment(cyclicKeys, p);
    final k0 = segment.start.key;
    final k1 = segment.end.key;
    if (smooth) {
      return JointPose(
        rotation: _cyclicCatmullRom(
          cyclicKeys,
          (key) => key.rotation,
          (key) => key.tension,
          segment,
        ),
        scaleX: _cyclicCatmullRom(
          cyclicKeys,
          (key) => key.scaleX,
          (key) => key.tension,
          segment,
        ),
        scaleY: _cyclicCatmullRom(
          cyclicKeys,
          (key) => key.scaleY,
          (key) => key.tension,
          segment,
        ),
      );
    }
    final t = k1.easeFn?.call(segment.local) ?? k1.ease.apply(segment.local);
    return JointPose(
      rotation: k0.rotation + (k1.rotation - k0.rotation) * t,
      scaleX: k0.scaleX + (k1.scaleX - k0.scaleX) * t,
      scaleY: k0.scaleY + (k1.scaleY - k0.scaleY) * t,
    );
  }

  /// Cubic Hermite for the segment [i,i+1] at [local] (0..1, span [dp]), with
  /// finite-difference tangents that wrap around the cycle (period = last-first
  /// key p, assuming the endpoints coincide). This is C1-continuous, so the
  /// joint never stops at an intermediate key.
  double _spline(int i, double local, double dp, double Function(Keyframe) f) =>
      _periodicCatmullRom(keys, (k) => k.p, f, (k) => k.tension, i, local, dp);
}

/// A sampled inverse-kinematics target for a two-bone limb chain.
///
/// Coordinates are expressed in the local space of [LimbIkTarget.anchorBoneId],
/// so choreography can say "put this hand near the chest" instead of solving
/// shoulder and elbow angles by eye.
class IkTargetPose {
  const IkTargetPose({
    required this.x,
    required this.y,
    this.weight = 1,
    this.bendDirection,
  });

  final double x;
  final double y;

  /// Blend amount for the IK solve. `0` leaves authored FK unchanged, `1`
  /// fully hits the target when it is reachable.
  final double weight;

  /// Per-sample override of [LimbIkTarget.bendDirection]. `null` means "no
  /// override, use the limb's own default" — every existing channel keeps
  /// producing `null` and is byte-identical to before this field existed.
  /// A two-bone solve only has two elbow solutions for a given target
  /// (there is no continuous "pole vector" in a planar rig); this lets a
  /// specific keyframe pick the other one — e.g. a cross-body reach whose
  /// default solution folds the elbow across the torso can flip to the
  /// solution that swings it out to the side instead.
  final int? bendDirection;
}

sealed class IkTargetChannel {
  const IkTargetChannel();

  IkTargetPose sample(double p);
}

class FixedIkTargetChannel extends IkTargetChannel {
  const FixedIkTargetChannel({
    required this.x,
    required this.y,
    this.weight = 1,
  });

  final double x;
  final double y;
  final double weight;

  @override
  IkTargetPose sample(double p) => IkTargetPose(x: x, y: y, weight: weight);
}

/// An absolute IK target plus additive offset layers.
///
/// The first channel owns the semantic target ("hand near chest"). Later
/// channels are local offsets whose own [IkTargetPose.weight] scales their
/// contribution. The final solve weight stays with the base channel so a style
/// layer can shade the hand/foot path without accidentally disabling IK.
class LayeredIkTargetChannel extends IkTargetChannel {
  const LayeredIkTargetChannel(this.channels);

  final List<IkTargetChannel> channels;

  @override
  IkTargetPose sample(double p) {
    if (channels.isEmpty) return const IkTargetPose(x: 0, y: 0, weight: 0);
    final base = channels.first.sample(p);
    var x = base.x;
    var y = base.y;
    for (final channel in channels.skip(1)) {
      final offset = channel.sample(p);
      x += offset.x * offset.weight;
      y += offset.y * offset.weight;
    }
    return IkTargetPose(
      x: x,
      y: y,
      weight: base.weight,
      bendDirection: base.bendDirection,
    );
  }
}

/// Blends two IK target channels and their solve weights.
class BlendedIkTargetChannel extends IkTargetChannel {
  const BlendedIkTargetChannel({
    required this.weight,
    this.from,
    this.to,
    this.fromTimeShift = 0,
    this.fromDuration = 0,
  }) : assert(weight >= 0 && weight <= 1, 'weight must be in 0..1');

  final IkTargetChannel? from;
  final IkTargetChannel? to;
  final double weight;

  /// See [BlendedJointChannel.fromTimeShift].
  final double fromTimeShift;
  final double fromDuration;

  @override
  IkTargetPose sample(double p) {
    final a = from?.sample(_shifted(p, fromTimeShift, fromDuration));
    final b = to?.sample(p);
    if (a == null && b == null) {
      return const IkTargetPose(x: 0, y: 0, weight: 0);
    }
    if (a == null) {
      return IkTargetPose(
        x: b!.x,
        y: b.y,
        weight: b.weight * weight,
        bendDirection: b.bendDirection,
      );
    }
    if (b == null) {
      return IkTargetPose(
        x: a.x,
        y: a.y,
        weight: a.weight * (1 - weight),
        bendDirection: a.bendDirection,
      );
    }
    return IkTargetPose(
      x: _lerp(a.x, b.x, weight),
      y: _lerp(a.y, b.y, weight),
      weight: _lerp(a.weight, b.weight, weight).clamp(0.0, 1.0),
      // Bend direction is a discrete either/or, not something to lerp — pick
      // whichever side of the blend currently dominates.
      bendDirection: weight >= 0.5 ? b.bendDirection : a.bendDirection,
    );
  }
}

/// Stateless temporal smoothing for IK target paths.
///
/// This rounds small target-path corners before the two-bone solve runs. It is
/// useful for dance hands, where an exact pose hit should still arrive in time
/// but the wrist path should not read as a hard keyframe step.
class SoftenedIkTargetChannel extends IkTargetChannel {
  const SoftenedIkTargetChannel(
    this.channel, {
    this.radius = 0.01,
    this.passes = 1,
    this.cyclic = false,
  }) : assert(radius >= 0, 'radius must be non-negative'),
       assert(passes > 0, 'passes must be positive');

  final IkTargetChannel channel;

  /// Phase radius for the smoothing window. For a 32-frame phrase, `0.015625`
  /// is half a frame.
  final double radius;

  /// Number of smoothing passes. `1` preserves the original 3-tap behavior;
  /// `2` applies the same kernel again, producing a gentler 5-tap-style curve
  /// for hand paths that should flow through nearby targets without visibly
  /// snapping from count to count.
  final int passes;

  /// Wrap smoothing samples across the loop seam instead of clamping them.
  final bool cyclic;

  @override
  IkTargetPose sample(double p) {
    if (radius == 0) return channel.sample(p);
    return _samplePass(p, passes);
  }

  IkTargetPose _samplePass(double p, int pass) {
    if (pass <= 0) return channel.sample(_samplePhase(p));
    final before = _samplePass(p - radius, pass - 1);
    final centre = _samplePass(p, pass - 1);
    final after = _samplePass(p + radius, pass - 1);
    return IkTargetPose(
      x: before.x * 0.25 + centre.x * 0.5 + after.x * 0.25,
      y: before.y * 0.25 + centre.y * 0.5 + after.y * 0.25,
      weight: (before.weight * 0.25 + centre.weight * 0.5 + after.weight * 0.25)
          .clamp(0.0, 1.0),
      // Discrete, not averaged — the centre sample governs.
      bendDirection: centre.bendDirection,
    );
  }

  double _samplePhase(double p) => cyclic ? _unitPhase(p) : p.clamp(0.0, 1.0);
}

class IkTargetKeyframe {
  const IkTargetKeyframe({
    required this.p,
    required this.x,
    required this.y,
    this.weight = 1,
    this.ease = Ease.easeInOut,
    this.tension = 0,
    this.bendDirection,
  }) : assert(
         tension >= -1 && tension <= 1,
         'tension must be in -1..1',
       ),
       assert(
         bendDirection == null || bendDirection == -1 || bendDirection == 1,
         'bendDirection must be null, -1 or 1',
       );

  final double p;
  final double x;
  final double y;
  final double weight;
  final Ease ease;

  /// Smooth-path tangent tension at this key — see [Keyframe.tension].
  final double tension;

  /// Overrides [LimbIkTarget.bendDirection] from this key until the next key
  /// that also sets it. `null` (the default) leaves the limb's own default
  /// in effect — see [IkTargetPose.bendDirection].
  final int? bendDirection;
}

class KeyframeIkTargetChannel extends IkTargetChannel {
  const KeyframeIkTargetChannel(
    this.keys, {
    this.smooth = false,
    this.cyclic = false,
  });

  final List<IkTargetKeyframe> keys;

  /// Periodic Catmull-Rom interpolation for looping target paths. This matches
  /// [KeyframeChannel.smooth]: the hand/foot travels through authored targets
  /// with continuous velocity instead of stopping on every beat key.
  final bool smooth;

  /// Treats target key phases as a wrapping cycle. This keeps sub-frame dance
  /// target offsets continuous across the frame-0 seam.
  final bool cyclic;

  @override
  IkTargetPose sample(double p) {
    if (keys.isEmpty) return const IkTargetPose(x: 0, y: 0, weight: 0);
    if (cyclic) return _sampleCyclic(_unitPhase(p));
    if (p <= keys.first.p) return _poseOf(keys.first);
    if (p >= keys.last.p) return _poseOf(keys.last);

    for (var i = 0; i < keys.length - 1; i++) {
      final k0 = keys[i];
      final k1 = keys[i + 1];
      if (p >= k0.p && p <= k1.p) {
        final span = k1.p - k0.p;
        final local = span == 0 ? 0.0 : (p - k0.p) / span;
        if (smooth) {
          return IkTargetPose(
            x: _spline(i, local, span, (k) => k.x),
            y: _spline(i, local, span, (k) => k.y),
            weight: _spline(i, local, span, (k) => k.weight).clamp(0.0, 1.0),
            // Held from the segment's start key, not interpolated — see
            // [IkTargetPose.bendDirection].
            bendDirection: k0.bendDirection,
          );
        }
        final t = k1.ease.apply(local);
        return IkTargetPose(
          x: k0.x + (k1.x - k0.x) * t,
          y: k0.y + (k1.y - k0.y) * t,
          weight: k0.weight + (k1.weight - k0.weight) * t,
          bendDirection: k0.bendDirection,
        );
      }
    }
    return const IkTargetPose(x: 0, y: 0, weight: 0);
  }

  IkTargetPose _poseOf(IkTargetKeyframe key) => IkTargetPose(
    x: key.x,
    y: key.y,
    weight: key.weight,
    bendDirection: key.bendDirection,
  );

  IkTargetPose _sampleCyclic(double p) {
    final cyclicKeys = _normalizedCyclicKeys(keys, (key) => key.p);
    if (cyclicKeys.isEmpty) return const IkTargetPose(x: 0, y: 0, weight: 0);
    if (cyclicKeys.length == 1) return _poseOf(cyclicKeys.single.key);

    final segment = _cyclicSegment(cyclicKeys, p);
    final k0 = segment.start.key;
    final k1 = segment.end.key;
    if (smooth) {
      return IkTargetPose(
        x: _cyclicCatmullRom(
          cyclicKeys,
          (key) => key.x,
          (key) => key.tension,
          segment,
        ),
        y: _cyclicCatmullRom(
          cyclicKeys,
          (key) => key.y,
          (key) => key.tension,
          segment,
        ),
        weight: _cyclicCatmullRom(
          cyclicKeys,
          (key) => key.weight,
          (key) => key.tension,
          segment,
        ).clamp(0.0, 1.0),
        bendDirection: k0.bendDirection,
      );
    }
    final t = k1.ease.apply(segment.local);
    return IkTargetPose(
      x: k0.x + (k1.x - k0.x) * t,
      y: k0.y + (k1.y - k0.y) * t,
      weight: k0.weight + (k1.weight - k0.weight) * t,
      bendDirection: k0.bendDirection,
    );
  }

  double _spline(
    int i,
    double local,
    double dp,
    double Function(IkTargetKeyframe) f,
  ) => _periodicCatmullRom(keys, (k) => k.p, f, (k) => k.tension, i, local, dp);
}

/// Binds a two-bone limb chain ([upperBoneId] → [lowerBoneId] → [endBoneId])
/// to a target-based IK channel, so choreography can author "the hand goes
/// here" instead of hand-tuning shoulder/elbow rotations frame by frame.
///
/// [channel] samples an [IkTargetPose] per phase (position + [anchorBoneId]-
/// relative coordinates + weight); `CharacterScene._solveLimbTarget` resolves
/// it against the live rig via the analytic two-bone solver
/// (`solveTwoBoneIk`), then converts the result back into ordinary local
/// joint rotations so it re-enters the pose the same way an authored FK key
/// would. A clip's [Clip.limbTargets] list is also what
/// `CharacterScene._overshootTargetBoneIds` walks to find which arm/torso
/// bones are eligible for the overshoot-settle pass, and what a support-foot
/// target's [endBoneId] is checked against for the world-anchor blend (see
/// [Clip.supportFootWorldAnchor]).
class LimbIkTarget {
  const LimbIkTarget({
    required this.upperBoneId,
    required this.lowerBoneId,
    required this.endBoneId,
    required this.anchorBoneId,
    required this.channel,
    this.bendDirection = 1,
  }) : assert(
         bendDirection == -1 || bendDirection == 1,
         'bendDirection must be -1 or 1',
       );

  final String upperBoneId;
  final String lowerBoneId;
  final String endBoneId;
  final String anchorBoneId;
  final IkTargetChannel channel;

  /// Selects which side of the shoulder->target line the elbow/knee bends
  /// toward. The rig owns the bone ids; the clip owns the choreographic choice.
  final int bendDirection;

  LimbIkTarget withChannel(IkTargetChannel channel) => LimbIkTarget(
    upperBoneId: upperBoneId,
    lowerBoneId: lowerBoneId,
    endBoneId: endBoneId,
    anchorBoneId: anchorBoneId,
    channel: channel,
    bendDirection: bendDirection,
  );
}

/// Root-level body motion layered under forward kinematics: the vertical bob,
/// horizontal sway and torso lean that give a cycle its weight. Sealed so cyclic
/// ([SineRootChannel]) and one-shot ([KeyframeRootChannel]) root motion share a
/// type the evaluator can sample uniformly.
sealed class RootChannel {
  const RootChannel();

  ({double dx, double dy, double rotation}) sample(double p);
}

/// Adds several root channels together. This keeps large authored beats in a
/// keyframed channel while layering tiny cyclic pulses on top.
class LayeredRootChannel extends RootChannel {
  const LayeredRootChannel(this.channels);

  final List<RootChannel> channels;

  @override
  ({double dx, double dy, double rotation}) sample(double p) {
    var dx = 0.0;
    var dy = 0.0;
    var rotation = 0.0;
    for (final channel in channels) {
      final sample = channel.sample(p);
      dx += sample.dx;
      dy += sample.dy;
      rotation += sample.rotation;
    }
    return (dx: dx, dy: dy, rotation: rotation);
  }
}

/// Blends two root channels for short move transitions.
class BlendedRootChannel extends RootChannel {
  const BlendedRootChannel({
    required this.weight,
    this.from,
    this.to,
    this.fromTimeShift = 0,
    this.fromDuration = 0,
  }) : assert(weight >= 0 && weight <= 1, 'weight must be in 0..1');

  final RootChannel? from;
  final RootChannel? to;
  final double weight;

  /// See [BlendedJointChannel.fromTimeShift].
  final double fromTimeShift;
  final double fromDuration;

  @override
  ({double dx, double dy, double rotation}) sample(double p) {
    final a = from?.sample(_shifted(p, fromTimeShift, fromDuration)) ??
        (dx: 0.0, dy: 0.0, rotation: 0.0);
    final b = to?.sample(p) ?? (dx: 0.0, dy: 0.0, rotation: 0.0);
    return (
      dx: _lerp(a.dx, b.dx, weight),
      dy: _lerp(a.dy, b.dy, weight),
      rotation: _lerp(a.rotation, b.rotation, weight),
    );
  }
}

/// Sinusoidal root motion for cyclic clips (walk/run/idle).
class SineRootChannel extends RootChannel {
  const SineRootChannel({
    this.bobAmplitude = 0,
    this.bobPhase = 0,
    this.bobHarmonic = 2,
    this.swayAmplitude = 0,
    this.swayPhase = 0,
    this.swayHarmonic = 1,
    this.leanAmplitude = 0,
    this.leanPhase = 0,
    this.leanHarmonic = 1,
  });

  /// Vertical bob amplitude in local units.
  final double bobAmplitude;
  final double bobPhase;

  /// Bob frequency multiplier. A walk bobs twice per cycle (one per footfall),
  /// so this defaults to 2.
  final double bobHarmonic;

  final double swayAmplitude;
  final double swayPhase;
  final double swayHarmonic;

  final double leanAmplitude;
  final double leanPhase;
  final double leanHarmonic;

  @override
  ({double dx, double dy, double rotation}) sample(double p) {
    const twoPi = 2 * math.pi;
    return (
      dx: swayAmplitude * math.sin(swayHarmonic * twoPi * (p + swayPhase)),
      dy: bobAmplitude * math.sin(bobHarmonic * twoPi * (p + bobPhase)),
      rotation:
          leanAmplitude *
          math.sin(
            leanHarmonic * twoPi * (p + leanPhase),
          ),
    );
  }
}

/// A single root keyframe for one-shot body motion (sit/jump): where the body
/// origin sits and how it leans at phase [p].
class RootKeyframe {
  const RootKeyframe({
    required this.p,
    this.dx = 0,
    this.dy = 0,
    this.rotation = 0,
    this.ease = Ease.easeInOut,
    this.tension = 0,
  }) : assert(
         tension >= -1 && tension <= 1,
         'tension must be in -1..1',
       );

  final double p;
  final double dx;
  final double dy;
  final double rotation;
  final Ease ease;

  /// Smooth-path tangent tension at this key — see [Keyframe.tension].
  final double tension;
}

/// Eased or smooth keyframed root motion. Keys must be sorted by phase.
class KeyframeRootChannel extends RootChannel {
  const KeyframeRootChannel(
    this.keys, {
    this.smooth = false,
    this.cyclic = false,
  });

  final List<RootKeyframe> keys;

  /// When true, interpolate with the same periodic Catmull-Rom spline used by
  /// [KeyframeChannel]. This is meant for cyclic stage movement where the root
  /// should flow through authored beat positions instead of stopping on every
  /// count.
  final bool smooth;

  /// Treats root key phases as a wrapping cycle instead of a clamped one-shot.
  /// Dance body channels use this so micro-timed keys flow through the seam.
  final bool cyclic;

  @override
  ({double dx, double dy, double rotation}) sample(double p) {
    if (keys.isEmpty) return (dx: 0, dy: 0, rotation: 0);
    if (cyclic) return _sampleCyclic(_unitPhase(p));
    if (p <= keys.first.p) {
      final k = keys.first;
      return (dx: k.dx, dy: k.dy, rotation: k.rotation);
    }
    if (p >= keys.last.p) {
      final k = keys.last;
      return (dx: k.dx, dy: k.dy, rotation: k.rotation);
    }
    for (var i = 0; i < keys.length - 1; i++) {
      final k0 = keys[i];
      final k1 = keys[i + 1];
      if (p >= k0.p && p <= k1.p) {
        final span = k1.p - k0.p;
        final local = span == 0 ? 0.0 : (p - k0.p) / span;
        if (smooth) {
          return (
            dx: _spline(i, local, span, (k) => k.dx),
            dy: _spline(i, local, span, (k) => k.dy),
            rotation: _spline(i, local, span, (k) => k.rotation),
          );
        }
        final t = k1.ease.apply(local);
        return (
          dx: k0.dx + (k1.dx - k0.dx) * t,
          dy: k0.dy + (k1.dy - k0.dy) * t,
          rotation: k0.rotation + (k1.rotation - k0.rotation) * t,
        );
      }
    }
    return (dx: 0, dy: 0, rotation: 0);
  }

  double _spline(
    int i,
    double local,
    double dp,
    double Function(RootKeyframe) f,
  ) => _periodicCatmullRom(keys, (k) => k.p, f, (k) => k.tension, i, local, dp);

  ({double dx, double dy, double rotation}) _sampleCyclic(double p) {
    final cyclicKeys = _normalizedCyclicKeys(keys, (key) => key.p);
    if (cyclicKeys.isEmpty) return (dx: 0, dy: 0, rotation: 0);
    if (cyclicKeys.length == 1) {
      final k = cyclicKeys.single.key;
      return (dx: k.dx, dy: k.dy, rotation: k.rotation);
    }

    final segment = _cyclicSegment(cyclicKeys, p);
    final k0 = segment.start.key;
    final k1 = segment.end.key;
    if (smooth) {
      return (
        dx: _cyclicCatmullRom(
          cyclicKeys,
          (key) => key.dx,
          (key) => key.tension,
          segment,
        ),
        dy: _cyclicCatmullRom(
          cyclicKeys,
          (key) => key.dy,
          (key) => key.tension,
          segment,
        ),
        rotation: _cyclicCatmullRom(
          cyclicKeys,
          (key) => key.rotation,
          (key) => key.tension,
          segment,
        ),
      );
    }
    final t = k1.ease.apply(segment.local);
    return (
      dx: k0.dx + (k1.dx - k0.dx) * t,
      dy: k0.dy + (k1.dy - k0.dy) * t,
      rotation: k0.rotation + (k1.rotation - k0.rotation) * t,
    );
  }
}

double _unitPhase(double p) => p - p.floorToDouble();

class _CyclicKey<K> {
  const _CyclicKey({required this.p, required this.key});

  final double p;
  final K key;
}

class _CyclicSegment<K> {
  const _CyclicSegment({
    required this.startIndex,
    required this.start,
    required this.end,
    required this.local,
    required this.span,
  });

  final int startIndex;
  final _CyclicKey<K> start;
  final _CyclicKey<K> end;
  final double local;
  final double span;
}

List<_CyclicKey<K>> _normalizedCyclicKeys<K>(
  List<K> keys,
  double Function(K key) phaseOf,
) {
  const epsilon = 1e-9;
  final normalized = <_CyclicKey<K>>[];
  for (final key in keys) {
    final p = _unitPhase(phaseOf(key));
    final duplicate = normalized.indexWhere(
      (entry) => (entry.p - p).abs() <= epsilon,
    );
    final cyclicKey = _CyclicKey(p: p, key: key);
    if (duplicate == -1) {
      normalized.add(cyclicKey);
    } else {
      normalized[duplicate] = cyclicKey;
    }
  }
  normalized.sort((a, b) => a.p.compareTo(b.p));
  return normalized;
}

_CyclicSegment<K> _cyclicSegment<K>(List<_CyclicKey<K>> keys, double p) {
  assert(keys.length >= 2, 'cyclic segments need at least two keys');
  for (var i = 0; i < keys.length - 1; i++) {
    final start = keys[i];
    final end = keys[i + 1];
    if (p >= start.p && p <= end.p) {
      final span = end.p - start.p;
      return _CyclicSegment(
        startIndex: i,
        start: start,
        end: end,
        local: span == 0 ? 0 : (p - start.p) / span,
        span: span,
      );
    }
  }

  final start = keys.last;
  final end = keys.first;
  final endP = end.p + 1;
  final sampleP = p < start.p ? p + 1 : p;
  final span = endP - start.p;
  return _CyclicSegment(
    startIndex: keys.length - 1,
    start: start,
    end: end,
    local: span == 0 ? 0 : (sampleP - start.p) / span,
    span: span,
  );
}

double _cyclicCatmullRom<K>(
  List<_CyclicKey<K>> keys,
  double Function(K key) valueOf,
  double Function(K key) tensionOf,
  _CyclicSegment<K> segment,
) {
  final n = keys.length;
  final i = segment.startIndex;
  final j = (i + 1) % n;
  final prev = (i - 1 + n) % n;
  final next = (j + 1) % n;

  final p1 = keys[i].p;
  var p2 = keys[j].p;
  if (p2 <= p1) p2 += 1;
  var p0 = keys[prev].p;
  if (p0 >= p1) p0 -= 1;
  var p3 = keys[next].p;
  while (p3 <= p2) {
    p3 += 1;
  }

  final v0 = valueOf(keys[prev].key);
  final v1 = valueOf(keys[i].key);
  final v2 = valueOf(keys[j].key);
  final v3 = valueOf(keys[next].key);
  final denom1 = p2 - p0;
  final denom2 = p3 - p1;
  if (denom1.abs() < 1e-12 || denom2.abs() < 1e-12) {
    return v1 + (v2 - v1) * segment.local;
  }

  final m1 = segment.span * (v2 - v0) / denom1 * (1 - tensionOf(keys[i].key));
  final m2 = segment.span * (v3 - v1) / denom2 * (1 - tensionOf(keys[j].key));
  final t = segment.local;
  final t2 = t * t;
  final t3 = t2 * t;
  return (2 * t3 - 3 * t2 + 1) * v1 +
      (t3 - 2 * t2 + t) * m1 +
      (-2 * t3 + 3 * t2) * v2 +
      (t3 - t2) * m2;
}

/// Periodic Catmull-Rom (Hermite) interpolation of one channel value across the
/// segment that starts at `keys[i]`.
///
/// [phaseOf] reads a key's normalized phase `p` and [valueOf] reads the scalar
/// being interpolated; [local] is the 0..1 progress within the segment and [dp]
/// the segment span used to scale the wrapped finite-difference tangents. The
/// endpoints coincide (`keys.first` == `keys.last`), so neighbours wrap around
/// by one period. Shared by the joint / IK-target / root keyframe channels so
/// the spline math lives in exactly one place.
double _periodicCatmullRom<K>(
  List<K> keys,
  double Function(K) phaseOf,
  double Function(K) valueOf,
  double Function(K) tensionOf,
  int i,
  double local,
  double dp,
) {
  final n = keys.length;
  final period = phaseOf(keys.last) - phaseOf(keys.first);
  final v1 = valueOf(keys[i]);
  final v2 = valueOf(keys[i + 1]);
  // Neighbours, wrapping periodically (keys[0] and keys[n-1] coincide).
  final double v0;
  final double p0;
  final double v3;
  final double p3;
  if (i == 0) {
    v0 = valueOf(keys[n - 2]);
    p0 = phaseOf(keys[n - 2]) - period;
  } else {
    v0 = valueOf(keys[i - 1]);
    p0 = phaseOf(keys[i - 1]);
  }
  if (i + 1 == n - 1) {
    v3 = valueOf(keys[1]);
    p3 = phaseOf(keys[1]) + period;
  } else {
    v3 = valueOf(keys[i + 2]);
    p3 = phaseOf(keys[i + 2]);
  }
  // Per-unit-p tangents (scaled by the segment span for the Hermite basis).
  // Each key's Kochanek–Bartels tension scales ITS tangent — used identically
  // by both segments that share the key, so C1 continuity holds and a
  // tension-1 key becomes a true zero-velocity arrival (a stamp / hold).
  final m1 =
      dp * (v2 - v0) / (phaseOf(keys[i + 1]) - p0) * (1 - tensionOf(keys[i]));
  final m2 =
      dp * (v3 - v1) / (p3 - phaseOf(keys[i])) * (1 - tensionOf(keys[i + 1]));
  final t = local;
  final t2 = t * t;
  final t3 = t2 * t;
  return (2 * t3 - 3 * t2 + 1) * v1 +
      (t3 - 2 * t2 + t) * m1 +
      (-2 * t3 + 3 * t2) * v2 +
      (t3 - t2) * m2;
}

/// Declares which foot [bone] is planted on the ground over the phase span
/// `[start, end)` of a cyclic clip. This drives **foot-locked locomotion**: the
/// body's travel is derived from the planted foot's *actual* body-frame sweep so
/// the foot holds world position (zero skate by construction), instead of a
/// guessed constant [Clip.locomotionSpeed] that a non-constant FK foot sweep can
/// never pin. Spans should tile the cycle `[0,1]` with one grounded foot at a
/// time; the boundaries are the (brief) double-support handoffs.
class GroundSpan {
  const GroundSpan(this.bone, this.start, this.end);

  final String bone;
  final double start;
  final double end;
}

/// Runtime metadata for a clip-to-clip transition.
///
/// The transform channels can blend directly, but contact solving needs to know
/// which support plan came from the outgoing move and which came from the
/// incoming move. Keeping that data explicit lets the scene apply both contact
/// corrections with complementary weights instead of hiding a hard support
/// switch at the midpoint of [blendedClip].
class ClipTransitionPlan {
  const ClipTransitionPlan({
    required this.from,
    required this.to,
    required this.weight,
    this.fromTimeShiftSeconds = 0,
  }) : assert(weight >= 0 && weight <= 1, 'weight must be in 0..1');

  final Clip from;
  final Clip to;

  /// Added to the shared clock to recover [from]'s OWN phrase-clock seconds
  /// during the blend (mirrors the shift already applied when sampling
  /// [from]'s channels — see [blendedClip]'s own parameter of the same
  /// name). Anything that derives a time-varying value from this transition
  /// plan (e.g. a dance formation) needs `from`'s own clock, not the shared
  /// one, or it silently reads `from`'s motion at the wrong phase.
  final double fromTimeShiftSeconds;
  final double weight;
}

/// How an in-place performance clip should be kept on the floor.
///
/// [activeSpan] pins the authored support foot span. It is useful for one-shot
/// moves with a single clear plant, such as a kick.
///
/// [lowestContact] keeps the lowest declared contact foot on the floor. It is
/// safer for cyclic dance phrases where support changes are decorative rather
/// than locomotion anchors: switching the active support foot can otherwise
/// re-anchor the whole body in one frame.
enum ContactPinning {
  activeSpan,
  lowestContact,
}

/// A named animation: a bag of per-bone channels plus root motion, evaluated by
/// the clip evaluator. [loop] distinguishes cyclic clips (walk/run/idle) from
/// one-shots (sit/jump).
class Clip {
  const Clip({
    required this.name,
    required this.duration,
    required this.channels,
    this.loop = true,
    this.root = const SineRootChannel(),
    this.locomotionSpeed = 0,
    this.groundSpans = const [],
    this.contactSpans = const [],
    this.contactPinning = ContactPinning.activeSpan,
    this.limbTargets = const [],
    this.supportFootWorldAnchor = false,
    this.supportFootWorldAnchorStrength = 0.6,
    this.danceHeadBobScale = 1.0,
    this.danceHeadLevelClampMin = -2.0,
    this.enforceSoleFloor = false,
    this.transitionPlan,
    this.zOrderSwaps = const [],
    this.dynamics = DanceDynamics.neutral,
  }) : assert(
         supportFootWorldAnchorStrength >= 0 &&
             supportFootWorldAnchorStrength <= 1,
         'support foot anchor strength must be in 0..1',
       );

  /// Display/lookup name.
  final String name;

  /// Scales the shared dance head treatment for this clip in [0, 1], applied in
  /// `CharacterScene`'s rigid-head pass. At `1.0` (the original behavior, shipped
  /// `dance` untouched) it does nothing; lower values calm the skull so the beat
  /// reads in the body. It scales three things: the rotational head-nod accents,
  /// the vertical head counter, and — the dominant lever — the **lateral** head
  /// counter, so the head lags more of the body's side-to-side sway. That last
  /// one matters because the big-amplitude moves' dominant onion "fan" is the
  /// tall ears being swept *laterally* by the sway, not a vertical bob; lagging
  /// the head laterally tightens it. Near-`0` holds the head almost level (the
  /// Pouncing Cat glide). Opt-in per clip.
  final double danceHeadBobScale;

  /// LIFT BUDGET for the spine leveler (see
  /// `CharacterScene._spineLevelShifts`), in local units, negative = up: the
  /// most the leveling may hold the skull/neck ABOVE where they would ride
  /// un-leveled. The shared default (-2) deliberately caps the lift tiny so a
  /// groove extreme never visibly lifts the skull off the neck — correct for
  /// clips whose intent is "the head rides the bob" but wrong for a clip
  /// whose whole premise is a head that stays level THROUGH a big compress
  /// (e.g. pouncingCat's Amapiano contrast): `danceHeadBobScale: 0` alone
  /// doesn't achieve that, since this budget still caps the lift regardless.
  /// Opt-in per clip; more negative allows a bigger upward correction.
  final double danceHeadLevelClampMin;

  /// When true, free-foot IK targets are clamped so the shoe bottom never
  /// sinks below the planted support sole (the R27 mocap hard gate: deep
  /// pocket sinks carry body-space foot targets through the floor).
  /// OPT-IN PER CLIP, following the re-authoring ratchet: the clamp
  /// visibly changes tuned foot mechanics (zanku's floor scrape
  /// over-rotates its hip when lifted), so each routine enables it in its
  /// own re-author + panel round rather than being silently altered.
  final bool enforceSoleFloor;

  /// When true, the active SUPPORT foot (per [contactSpans]) is held toward its
  /// world position via leg IK during its stance, so an in-place performance
  /// grooves OVER a planted foot instead of dragging it sideways (the skate).
  /// Opt-in per clip — left false for the shipped clips so their tuned contact
  /// geometry (and tests) are unchanged.
  final bool supportFootWorldAnchor;

  /// Strength for [supportFootWorldAnchor]. Lower values leave more of the
  /// authored foot scuff; higher values read as a clearer plant for moves whose
  /// weight transfer depends on a visible support.
  final double supportFootWorldAnchorStrength;

  /// Cycle period (loop) or total length (one-shot), in seconds.
  final double duration;

  /// Whether the clip repeats.
  final bool loop;

  /// Per-bone channels, keyed by bone id. Bones absent here hold their rest
  /// pose (channels are sparse).
  final Map<String, JointChannel> channels;

  final RootChannel root;

  /// World-space horizontal speed in local units/sec, speed-matched to the
  /// cycle to avoid foot-skate. Consumed by the caller for locomotion, not
  /// baked into the pose. Ignored when [groundSpans] is set (foot-lock wins).
  final double locomotionSpeed;

  /// Per-foot ground-contact spans. When non-empty the clip uses **foot-locked**
  /// locomotion (see [GroundSpan]) instead of [locomotionSpeed]. Empty for
  /// in-place clips (idle) and one-shots (sit/jump).
  final List<GroundSpan> groundSpans;

  /// Per-foot support spans for in-place clips. These drive contact shadows and
  /// review overlays only; they do not make a clip travel across the stage.
  final List<GroundSpan> contactSpans;

  /// Floor-pinning policy for in-place clips with [contactSpans].
  final ContactPinning contactPinning;

  /// Optional two-bone IK targets applied after authored FK channels. This is
  /// the choreographic path for hands/feet that must hit semantic positions
  /// without reverse-engineering shoulder/elbow or hip/knee rotations.
  final List<LimbIkTarget> limbTargets;

  /// Source clips and transition weight when this clip is a runtime blend.
  final ClipTransitionPlan? transitionPlan;

  /// Windows where two bones should swap paint order (whichever normally
  /// renders behind now renders in front). A bone's paint depth is fixed at
  /// rig-build time — a clip can't reorder it directly — but a move like a
  /// crossed-wrist hold whose "top" hand alternates per bar needs exactly
  /// that. See [ZOrderSwapWindow].
  final List<ZOrderSwapWindow> zOrderSwaps;

  /// Whether this clip travels across the stage at all (either model).
  bool get locomotes => locomotionSpeed != 0 || groundSpans.isNotEmpty;

  /// This move's authored Laban-Effort character (the "move base" term of
  /// `effectiveDanceDynamics`), stamped on at assembly time from
  /// `AfrobeatsMove.dynamics` by `assembleMoveClip`. Lane-invariant — every cat
  /// dancing this clip shares the same base; per-cat/per-section variation is
  /// composed and carried separately (`DanceStage.dynamics`), never on the
  /// `Clip` itself, so the shared static `Clip` instances stay shareable.
  /// Neutral for `kick`/`idle` and any clip that predates the Effort catalog.
  final DanceDynamics dynamics;
}

/// Declares that [boneA] and [boneB] swap paint order for the phase span
/// `[start, end)`. `start > end` wraps across the cyclic seam (e.g. `0.9` to
/// `0.1` covers the loop boundary). Both bones must exist in the rig and are
/// looked up by id at paint time; missing ids are silently ignored (a typo
/// here should not crash a render).
class ZOrderSwapWindow {
  const ZOrderSwapWindow({
    required this.boneA,
    required this.boneB,
    required this.start,
    required this.end,
  });

  final String boneA;
  final String boneB;
  final double start;
  final double end;

  bool activeAt(double phase) =>
      start <= end ? (phase >= start && phase < end) : (phase >= start || phase < end);
}

Clip blendedClip({
  required Clip from,
  required Clip to,
  required double weight,
  String? name,
  ClipBlendMask blendMask = ClipBlendMask.full,
  double fromTimeShiftSeconds = 0,
}) {
  assert(weight >= 0 && weight <= 1, 'weight must be in 0..1');
  final channelIds = {...from.channels.keys, ...to.channels.keys};
  final fromTargets = {
    for (final target in from.limbTargets) target.endBoneId: target,
  };
  final toTargets = {
    for (final target in to.limbTargets) target.endBoneId: target,
  };
  final targetIds = {...fromTargets.keys, ...toTargets.keys};
  final transitionWeight = _smoothUnit(weight);
  final supportFootAnchorStrength = _transitionSupportAnchorStrength(
    from,
    to,
    transitionWeight,
  );
  final rootWeight = blendMask.rootWeight(weight);

  return Clip(
    name: name ?? '${from.name}->${to.name}',
    duration: to.duration,
    loop: from.loop && to.loop,
    channels: {
      for (final id in channelIds)
        id: BlendedJointChannel(
          from: from.channels[id],
          to: to.channels[id],
          weight: blendMask.jointWeight(id, weight),
          fromTimeShift: fromTimeShiftSeconds,
          fromDuration: from.duration,
        ),
    },
    root: BlendedRootChannel(
      from: from.root,
      to: to.root,
      weight: rootWeight,
      fromTimeShift: fromTimeShiftSeconds,
      fromDuration: from.duration,
    ),
    locomotionSpeed: _lerp(
      from.locomotionSpeed,
      to.locomotionSpeed,
      rootWeight,
    ),
    groundSpans: _transitionSpans(from.groundSpans, to.groundSpans),
    contactSpans: _transitionSpans(from.contactSpans, to.contactSpans),
    contactPinning: _transitionContactPinning(from, to),
    limbTargets: [
      for (final id in targetIds)
        _blendLimbTarget(
          fromTargets[id],
          toTargets[id],
          blendMask.limbTargetWeight(id, weight),
          fromTimeShift: fromTimeShiftSeconds,
          fromDuration: from.duration,
        ),
    ],
    supportFootWorldAnchor: supportFootAnchorStrength > 0,
    supportFootWorldAnchorStrength: supportFootAnchorStrength,
    danceHeadBobScale: _lerp(
      from.danceHeadBobScale,
      to.danceHeadBobScale,
      rootWeight,
    ),
    danceHeadLevelClampMin: _lerp(
      from.danceHeadLevelClampMin,
      to.danceHeadLevelClampMin,
      rootWeight,
    ),
    enforceSoleFloor: rootWeight < 0.5
        ? from.enforceSoleFloor
        : to.enforceSoleFloor,
    // A blended clip used to silently drop BOTH sides' z-order swap windows
    // (this field had no entry above and so fell back to the empty default,
    // popping a hand/limb whose paint order was swapped for the outgoing
    // move's current beat back to the rig's static order the instant a
    // transition began — a real pop confirmed via transitions-r6 pixel-diff,
    // even though nothing about the POSE changed). This value is only a
    // fallback for any caller reading `clip.zOrderSwaps` directly; the
    // render path (`CharacterScene._activeZOrderSwaps`) evaluates `from`/`to`
    // against their OWN clocks via [transitionPlan] instead of trusting this
    // field, since evaluating either side's window against the WRONG clock
    // (the shared blend clock) reads it as permanently inactive — same
    // midpoint-switch pattern as [enforceSoleFloor] above, but see that
    // method's own doc comment for why the clock still has to be per-side.
    zOrderSwaps: rootWeight < 0.5 ? from.zOrderSwaps : to.zOrderSwaps,
    transitionPlan: ClipTransitionPlan(
      from: from,
      to: to,
      weight: weight,
      fromTimeShiftSeconds: fromTimeShiftSeconds,
    ),
    dynamics: DanceDynamics.lerp(from.dynamics, to.dynamics, rootWeight),
  );
}

List<GroundSpan> _transitionSpans(
  List<GroundSpan> from,
  List<GroundSpan> to,
) {
  if (from.isEmpty) return to;
  if (to.isEmpty) return from;
  final spans = [...from, ...to]
    ..sort((a, b) {
      final start = a.start.compareTo(b.start);
      if (start != 0) return start;
      final end = a.end.compareTo(b.end);
      if (end != 0) return end;
      return a.bone.compareTo(b.bone);
    });
  final deduped = <GroundSpan>[];
  for (final span in spans) {
    final duplicate = deduped.any(
      (existing) =>
          existing.bone == span.bone &&
          existing.start == span.start &&
          existing.end == span.end,
    );
    if (!duplicate) deduped.add(span);
  }
  return List<GroundSpan>.unmodifiable(deduped);
}

ContactPinning _transitionContactPinning(Clip from, Clip to) {
  if (from.contactPinning == ContactPinning.lowestContact ||
      to.contactPinning == ContactPinning.lowestContact) {
    return ContactPinning.lowestContact;
  }
  return ContactPinning.activeSpan;
}

double _transitionSupportAnchorStrength(
  Clip from,
  Clip to,
  double weight,
) {
  final outgoing = from.supportFootWorldAnchor
      ? from.supportFootWorldAnchorStrength * (1 - weight)
      : 0.0;
  final incoming = to.supportFootWorldAnchor
      ? to.supportFootWorldAnchorStrength * weight
      : 0.0;
  return (outgoing + incoming).clamp(0.0, 1.0);
}

LimbIkTarget _blendLimbTarget(
  LimbIkTarget? from,
  LimbIkTarget? to,
  double weight, {
  double fromTimeShift = 0,
  double fromDuration = 0,
}) {
  final template = weight < 0.5 ? from ?? to! : to ?? from!;
  return LimbIkTarget(
    upperBoneId: template.upperBoneId,
    lowerBoneId: template.lowerBoneId,
    endBoneId: template.endBoneId,
    anchorBoneId: template.anchorBoneId,
    channel: BlendedIkTargetChannel(
      from: from?.channel,
      to: to?.channel,
      weight: weight,
      fromTimeShift: fromTimeShift,
      fromDuration: fromDuration,
    ),
    bendDirection: template.bendDirection,
  );
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

double _smoothUnit(double t) {
  final x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}
