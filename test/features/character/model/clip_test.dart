import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/dance_dynamics.dart';
import 'package:dancing_cats/features/character/model/easing.dart';
import 'package:flutter_test/flutter_test.dart';

/// Returns [value] unchanged, but as a *runtime* value the compiler cannot fold
/// into a constant. Used to force a `const` constructor to run at runtime (so
/// its body is counted by coverage) instead of being const-canonicalised away.
T _runtime<T>(T value) => value;

void main() {
  group('SineChannel', () {
    test('amplitude and phase shape the rotation', () {
      const ch = SineChannel(amplitude: 2);
      expect(ch.sample(0).rotation, closeTo(0, 1e-9));
      expect(ch.sample(0.25).rotation, closeTo(2, 1e-9));
      expect(ch.sample(0.5).rotation, closeTo(0, 1e-9));
      expect(ch.sample(0.75).rotation, closeTo(-2, 1e-9));
    });

    test('bias offsets every sample', () {
      const ch = SineChannel(amplitude: 1, bias: 0.5);
      expect(ch.sample(0).rotation, closeTo(0.5, 1e-9));
      expect(ch.sample(0.5).rotation, closeTo(0.5, 1e-9));
    });

    test('second harmonic adds a double-frequency term', () {
      const ch = SineChannel(harmonicAmplitude: 1);
      // sin(4π·0.125) = sin(π/2) = 1.
      expect(ch.sample(0.125).rotation, closeTo(1, 1e-9));
    });

    test('harmonic multiplier controls the secondary pulse frequency', () {
      const ch = SineChannel(harmonicAmplitude: 1, harmonicMultiplier: 4);
      // sin(2π·4·0.0625) = sin(π/2) = 1.
      expect(ch.sample(0.0625).rotation, closeTo(1, 1e-9));
    });

    test('scaleY oscillation defaults to a flat 1', () {
      const ch = SineChannel(amplitude: 1);
      expect(ch.sample(0.3).scaleY, 1);
    });

    test('a runtime-built channel still samples its rotation and scale', () {
      // Built from a non-const argument so the const constructor body runs at
      // runtime; a pure-const call would be folded out of coverage.
      final ch = SineChannel(
        amplitude: _runtime<double>(2),
        scaleYAmplitude: -0.1,
      );
      expect(ch.sample(0).rotation, closeTo(0, 1e-9));
      expect(ch.sample(0.25).rotation, closeTo(2, 1e-9));
      expect(ch.sample(0.75).rotation, closeTo(-2, 1e-9));
      // scaleY = 1 + (-0.1)*sin(2π·0.25) = 0.9.
      expect(ch.sample(0.25).scaleY, closeTo(0.9, 1e-9));
    });
  });

  group('LayeredJointChannel', () {
    test('adds rotations and multiplies scale pulses', () {
      const ch = LayeredJointChannel([
        KeyframeChannel([
          Keyframe(p: 0, rotation: 0.1, scaleX: 1.1, scaleY: 0.9),
          Keyframe(
            p: 1,
            rotation: 0.1,
            scaleX: 1.1,
            scaleY: 0.9,
            ease: Ease.linear,
          ),
        ]),
        SineChannel(
          bias: 0.2,
          scaleXAmplitude: 0.1,
          scaleYAmplitude: -0.1,
        ),
      ]);

      final pose = ch.sample(0.25);
      expect(pose.rotation, closeTo(0.3, 1e-9));
      expect(pose.scaleX, closeTo(1.21, 1e-9));
      expect(pose.scaleY, closeTo(0.81, 1e-9));
    });
  });

  group('BlendedJointChannel', () {
    test('interpolates rotation and scale between two channels', () {
      const from = KeyframeChannel([
        Keyframe(p: 0, rotation: -1, scaleX: 0.8, scaleY: 1.2),
        Keyframe(p: 1, rotation: -1, scaleX: 0.8, scaleY: 1.2),
      ]);
      const to = KeyframeChannel([
        Keyframe(p: 0, rotation: 1, scaleX: 1.2, scaleY: 0.8),
        Keyframe(p: 1, rotation: 1, scaleX: 1.2, scaleY: 0.8),
      ]);

      const blend = BlendedJointChannel(from: from, to: to, weight: 0.25);
      final pose = blend.sample(0.5);

      expect(pose.rotation, closeTo(-0.5, 1e-9));
      expect(pose.scaleX, closeTo(0.9, 1e-9));
      expect(pose.scaleY, closeTo(1.1, 1e-9));
    });

    test('fades missing channels against identity pose', () {
      const to = KeyframeChannel([
        Keyframe(p: 0, rotation: 1, scaleX: 1.2, scaleY: 0.8),
        Keyframe(p: 1, rotation: 1, scaleX: 1.2, scaleY: 0.8),
      ]);

      const blend = BlendedJointChannel(to: to, weight: 0.5);
      final pose = blend.sample(0.5);

      expect(pose.rotation, closeTo(0.5, 1e-9));
      expect(pose.scaleX, closeTo(1.1, 1e-9));
      expect(pose.scaleY, closeTo(0.9, 1e-9));
    });
  });

  group('KeyframeChannel', () {
    const ch = KeyframeChannel([
      Keyframe(p: 0),
      Keyframe(p: 0.5, rotation: 1, ease: Ease.linear),
      Keyframe(p: 1, ease: Ease.linear),
    ]);

    test('hits the keys exactly', () {
      expect(ch.sample(0).rotation, 0);
      expect(ch.sample(0.5).rotation, closeTo(1, 1e-9));
      expect(ch.sample(1).rotation, closeTo(0, 1e-9));
    });

    test('linearly interpolates between keys', () {
      expect(ch.sample(0.25).rotation, closeTo(0.5, 1e-9));
      expect(ch.sample(0.75).rotation, closeTo(0.5, 1e-9));
    });

    test('clamps before the first and after the last key', () {
      expect(ch.sample(-1).rotation, 0);
      expect(ch.sample(2).rotation, closeTo(0, 1e-9));
    });

    test('empty channel is the identity', () {
      const empty = KeyframeChannel(<Keyframe>[]);
      expect(empty.sample(0.5).rotation, 0);
      expect(empty.sample(0.5).scaleY, 1);
    });

    test('a non-zero phase shifts and wraps the sample point', () {
      const shifted = KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.5, rotation: 1, ease: Ease.linear),
        Keyframe(p: 1, ease: Ease.linear),
      ], phase: 0.5);

      // rawP 0 -> p 0.5 (the mid key), rawP 0.5 -> p 0 (wraps past 1),
      // rawP 0.75 -> p 0.25 (halfway up the leading-in linear segment).
      expect(shifted.sample(0).rotation, closeTo(1, 1e-9));
      expect(shifted.sample(0.5).rotation, closeTo(0, 1e-9));
      expect(shifted.sample(0.75).rotation, closeTo(0.5, 1e-9));
    });

    group('smooth (periodic spline)', () {
      // A sine-shaped closed loop: peaks at 0.25/0.75, zero-crossings (but
      // moving) at 0/0.5/1.
      const keys = [
        Keyframe(p: 0),
        Keyframe(p: 0.25, rotation: 1),
        Keyframe(p: 0.5),
        Keyframe(p: 0.75, rotation: -1),
        Keyframe(p: 1),
      ];
      const smooth = KeyframeChannel(keys, smooth: true);
      const eased = KeyframeChannel(keys);

      test('still passes through every key value', () {
        expect(smooth.sample(0).rotation, closeTo(0, 1e-6));
        expect(smooth.sample(0.25).rotation, closeTo(1, 1e-6));
        expect(smooth.sample(0.5).rotation, closeTo(0, 1e-6));
        expect(smooth.sample(0.75).rotation, closeTo(-1, 1e-6));
      });

      double speedAt(KeyframeChannel c, double p) =>
          (c.sample(p + 0.01).rotation - c.sample(p - 0.01).rotation).abs();

      test('flows THROUGH a pass-through key (no stop), unlike eased', () {
        // At p=0.5 the value is 0 but the motion is sweeping +1 -> -1, so a real
        // continuous curve is moving fast there. The smooth spline keeps its
        // speed; the eased channel decelerates to ~0 (stops at the key) — the
        // stutter this mode exists to remove.
        expect(speedAt(smooth, 0.5), greaterThan(0.05));
        expect(speedAt(eased, 0.5), lessThan(0.02));
      });

      test('cyclic mode wraps offset key loops through the seam', () {
        const offsetLoop = KeyframeChannel(
          [
            Keyframe(p: 0.1, rotation: 1),
            Keyframe(p: 0.35),
            Keyframe(p: 0.6, rotation: -1),
            Keyframe(p: 0.85),
          ],
          smooth: true,
          cyclic: true,
        );

        double velocityAt(double p) =>
            (offsetLoop.sample(p + 0.001).rotation -
                offsetLoop.sample(p - 0.001).rotation) /
            0.002;

        expect(
          offsetLoop.sample(1.1).rotation,
          closeTo(offsetLoop.sample(0.1).rotation, 1e-9),
        );
        expect(
          offsetLoop.sample(-0.15).rotation,
          closeTo(offsetLoop.sample(0.85).rotation, 1e-9),
        );
        expect(velocityAt(0), closeTo(velocityAt(1), 1e-9));
      });
    });
  });

  group('SineRootChannel', () {
    test('bob uses the harmonic multiplier', () {
      const root = SineRootChannel(bobAmplitude: 3);
      // Default harmonic 2: dy = 3·sin(2·2π·0.125) = 3·sin(π/2) = 3.
      expect(root.sample(0.125).dy, closeTo(3, 1e-9));
    });

    test('sway and lean track the base frequency', () {
      const root = SineRootChannel(swayAmplitude: 2, leanAmplitude: 0.5);
      final s = root.sample(0.25);
      expect(s.dx, closeTo(2, 1e-9));
      expect(s.rotation, closeTo(0.5, 1e-9));
    });

    test('sway and lean can use harmonic multipliers', () {
      const root = SineRootChannel(
        swayAmplitude: 2,
        swayHarmonic: 2,
        leanAmplitude: 0.5,
        leanHarmonic: 2,
      );
      final s = root.sample(0.125);
      expect(s.dx, closeTo(2, 1e-9));
      expect(s.rotation, closeTo(0.5, 1e-9));
    });
  });

  group('LayeredRootChannel', () {
    test('adds root samples from all child channels', () {
      const root = LayeredRootChannel([
        KeyframeRootChannel([
          RootKeyframe(p: 0),
          RootKeyframe(p: 1, dx: 4, dy: 6, rotation: 0.2, ease: Ease.linear),
        ]),
        SineRootChannel(bobAmplitude: 2, bobHarmonic: 1),
      ]);

      final s = root.sample(0.25);
      expect(s.dx, closeTo(1, 1e-9));
      expect(s.dy, closeTo(3.5, 1e-9));
      expect(s.rotation, closeTo(0.05, 1e-9));
    });
  });

  group('BlendedRootChannel', () {
    test('interpolates body offset and lean', () {
      const from = KeyframeRootChannel([
        RootKeyframe(p: 0, dx: -10, dy: 4, rotation: -0.2),
        RootKeyframe(p: 1, dx: -10, dy: 4, rotation: -0.2),
      ]);
      const to = KeyframeRootChannel([
        RootKeyframe(p: 0, dx: 10, dy: -4, rotation: 0.2),
        RootKeyframe(p: 1, dx: 10, dy: -4, rotation: 0.2),
      ]);

      const blend = BlendedRootChannel(from: from, to: to, weight: 0.75);
      final sample = blend.sample(0.5);

      expect(sample.dx, closeTo(5, 1e-9));
      expect(sample.dy, closeTo(-2, 1e-9));
      expect(sample.rotation, closeTo(0.1, 1e-9));
    });
  });

  group('KeyframeRootChannel', () {
    const root = KeyframeRootChannel([
      RootKeyframe(p: 0),
      RootKeyframe(p: 1, dy: 10, ease: Ease.linear),
    ]);

    test('interpolates the body offset', () {
      expect(root.sample(0).dy, 0);
      expect(root.sample(0.5).dy, closeTo(5, 1e-9));
      expect(root.sample(1).dy, closeTo(10, 1e-9));
    });

    test('smooth cyclic root passes through authored beats', () {
      const smooth = KeyframeRootChannel([
        RootKeyframe(p: 0),
        RootKeyframe(p: 0.25, dx: 10, dy: -2),
        RootKeyframe(p: 0.5),
        RootKeyframe(p: 0.75, dx: -10, dy: -2),
        RootKeyframe(p: 1),
      ], smooth: true);

      expect(smooth.sample(0.25).dx, closeTo(10, 1e-9));
      expect(smooth.sample(0.75).dx, closeTo(-10, 1e-9));
      expect(smooth.sample(0.125).dx, greaterThan(0));
      expect(smooth.sample(0.625).dx, lessThan(0));
    });

    test('cyclic root mode wraps shifted loops through frame zero', () {
      const root = KeyframeRootChannel(
        [
          RootKeyframe(p: 0.125, dx: 10),
          RootKeyframe(p: 0.375),
          RootKeyframe(p: 0.625, dx: -10),
          RootKeyframe(p: 0.875),
        ],
        smooth: true,
        cyclic: true,
      );

      double velocityAt(double p) =>
          (root.sample(p + 0.001).dx - root.sample(p - 0.001).dx) / 0.002;

      expect(root.sample(1.125).dx, closeTo(10, 1e-9));
      expect(root.sample(-0.375).dx, closeTo(-10, 1e-9));
      expect(velocityAt(0), closeTo(velocityAt(1), 1e-9));
    });

    test('empty channel yields no motion', () {
      const empty = KeyframeRootChannel(<RootKeyframe>[]);
      final s = empty.sample(0.4);
      expect(s.dx, 0);
      expect(s.dy, 0);
      expect(s.rotation, 0);
    });
  });

  group('IkTargetChannel', () {
    test('fixed targets hold their semantic point and weight', () {
      const channel = FixedIkTargetChannel(x: 12, y: -8, weight: 0.4);
      final sample = channel.sample(0.72);

      expect(sample.x, 12);
      expect(sample.y, -8);
      expect(sample.weight, 0.4);
    });

    test('a runtime-built fixed target holds its point at any phase', () {
      // Non-const argument forces the const constructor to run at runtime.
      final channel = FixedIkTargetChannel(x: 12, y: -8, weight: _runtime(0.4));
      expect(channel.sample(0).x, 12);
      expect(channel.sample(0).y, -8);
      expect(channel.sample(0.72).weight, 0.4);
    });

    test('layered targets preserve base weight and add weighted offsets', () {
      const channel = LayeredIkTargetChannel([
        FixedIkTargetChannel(x: 12, y: 20, weight: 0.35),
        FixedIkTargetChannel(x: 6, y: -4, weight: 0.5),
        FixedIkTargetChannel(x: -2, y: -8, weight: 0.25),
      ]);
      final sample = channel.sample(0.72);

      expect(sample.x, closeTo(14.5, 1e-9));
      expect(sample.y, closeTo(16, 1e-9));
      expect(sample.weight, closeTo(0.35, 1e-9));
    });

    test('empty layered target contributes no IK weight', () {
      const channel = LayeredIkTargetChannel([]);
      final sample = channel.sample(0.72);

      expect(sample.x, 0);
      expect(sample.y, 0);
      expect(sample.weight, 0);
    });

    test('blended target interpolates position and solve weight', () {
      const from = FixedIkTargetChannel(x: -20, y: 10);
      const to = FixedIkTargetChannel(x: 20, y: -10, weight: 0.5);

      const blend = BlendedIkTargetChannel(from: from, to: to, weight: 0.25);
      final sample = blend.sample(0.5);

      expect(sample.x, closeTo(-10, 1e-9));
      expect(sample.y, closeTo(5, 1e-9));
      expect(sample.weight, closeTo(0.875, 1e-9));
    });

    test('blended target fades single-sided IK weight in or out', () {
      const target = FixedIkTargetChannel(x: 20, y: -10, weight: 0.8);

      final fadeIn = const BlendedIkTargetChannel(
        to: target,
        weight: 0.25,
      ).sample(0.5);
      final fadeOut = const BlendedIkTargetChannel(
        from: target,
        weight: 0.25,
      ).sample(0.5);

      expect(fadeIn.x, 20);
      expect(fadeIn.weight, closeTo(0.2, 1e-9));
      expect(fadeOut.x, 20);
      expect(fadeOut.weight, closeTo(0.6, 1e-9));
    });

    test('softened targets round hard target corners', () {
      const base = KeyframeIkTargetChannel([
        IkTargetKeyframe(p: 0, x: 0, y: 0),
        IkTargetKeyframe(p: 0.5, x: 20, y: 0, ease: Ease.linear),
        IkTargetKeyframe(p: 1, x: 20, y: 20, ease: Ease.linear),
      ]);
      const softened = SoftenedIkTargetChannel(base, radius: 0.1);

      final hardCorner = base.sample(0.5);
      final roundedCorner = softened.sample(0.5);

      expect(hardCorner.x, closeTo(20, 1e-9));
      expect(hardCorner.y, closeTo(0, 1e-9));
      expect(roundedCorner.x, lessThan(20));
      expect(roundedCorner.y, greaterThan(0));
    });

    test('additional softened passes round target corners more gently', () {
      const base = KeyframeIkTargetChannel([
        IkTargetKeyframe(p: 0, x: 0, y: 0),
        IkTargetKeyframe(p: 0.5, x: 20, y: 0, ease: Ease.linear),
        IkTargetKeyframe(p: 1, x: 20, y: 20, ease: Ease.linear),
      ]);
      const singlePass = SoftenedIkTargetChannel(base, radius: 0.1);
      const twoPass = SoftenedIkTargetChannel(base, radius: 0.1, passes: 2);

      final single = singlePass.sample(0.5);
      final doubled = twoPass.sample(0.5);

      expect(doubled.x, lessThan(single.x));
      expect(doubled.y, greaterThan(single.y));
      expect(doubled.weight, closeTo(1, 1e-9));
    });

    test('softened cyclic targets round the loop seam', () {
      const base = KeyframeIkTargetChannel(
        [
          IkTargetKeyframe(p: 0.1, x: 20, y: 0),
          IkTargetKeyframe(p: 0.35, x: 0, y: 20),
          IkTargetKeyframe(p: 0.6, x: -20, y: 0),
          IkTargetKeyframe(p: 0.85, x: 0, y: -20),
        ],
        smooth: true,
        cyclic: true,
      );
      const softened = SoftenedIkTargetChannel(
        base,
        radius: 0.04,
        cyclic: true,
      );

      expect(
        softened.sample(1.02).x,
        closeTo(softened.sample(0.02).x, 1e-9),
      );
      expect(
        softened.sample(-0.02).y,
        closeTo(softened.sample(0.98).y, 1e-9),
      );
      expect(softened.sample(0).y, lessThan(0));
    });

    test('keyframed targets interpolate position and blend weight', () {
      const channel = KeyframeIkTargetChannel([
        IkTargetKeyframe(p: 0, x: 0, y: 10, weight: 0),
        IkTargetKeyframe(p: 1, x: 20, y: -10, ease: Ease.linear),
      ]);
      final sample = channel.sample(0.25);

      expect(sample.x, closeTo(5, 1e-9));
      expect(sample.y, closeTo(5, 1e-9));
      expect(sample.weight, closeTo(0.25, 1e-9));
    });

    test('smooth target paths keep moving through pass-through targets', () {
      const smooth = KeyframeIkTargetChannel([
        IkTargetKeyframe(p: 0, x: 0, y: 0),
        IkTargetKeyframe(p: 0.25, x: 12, y: -6),
        IkTargetKeyframe(p: 0.5, x: 0, y: 0),
        IkTargetKeyframe(p: 0.75, x: -12, y: 6),
        IkTargetKeyframe(p: 1, x: 0, y: 0),
      ], smooth: true);
      const eased = KeyframeIkTargetChannel([
        IkTargetKeyframe(p: 0, x: 0, y: 0),
        IkTargetKeyframe(p: 0.25, x: 12, y: -6),
        IkTargetKeyframe(p: 0.5, x: 0, y: 0),
        IkTargetKeyframe(p: 0.75, x: -12, y: 6),
        IkTargetKeyframe(p: 1, x: 0, y: 0),
      ]);

      double speedAt(IkTargetChannel channel, double p) {
        final before = channel.sample(p - 0.01);
        final after = channel.sample(p + 0.01);
        final dx = after.x - before.x;
        final dy = after.y - before.y;
        return dx * dx + dy * dy;
      }

      expect(speedAt(smooth, 0.5), greaterThan(1));
      expect(speedAt(eased, 0.5), lessThan(0.2));
    });
  });

  test('both channel kinds belong to the sealed JointChannel hierarchy', () {
    expect(const SineChannel(amplitude: 1), isA<JointChannel>());
    expect(const KeyframeChannel(<Keyframe>[]), isA<JointChannel>());
    expect(const LayeredJointChannel([]), isA<JointChannel>());
    expect(const BlendedJointChannel(weight: 0), isA<JointChannel>());
  });

  group('Clip', () {
    test('contact spans do not make an in-place clip locomote', () {
      const clip = Clip(
        name: 'tap',
        duration: 1,
        channels: {},
        contactSpans: [GroundSpan('foot.L', 0, 1)],
      );

      expect(clip.contactSpans.single.bone, 'foot.L');
      expect(clip.groundSpans, isEmpty);
      expect(clip.locomotes, isFalse);
      expect(clip.contactPinning, ContactPinning.activeSpan);
    });

    test('can declare lowest-contact pinning for dance-style clips', () {
      const clip = Clip(
        name: 'dance-role',
        duration: 1,
        channels: {},
        contactSpans: [GroundSpan('foot.L', 0, 1)],
        contactPinning: ContactPinning.lowestContact,
      );

      expect(clip.contactPinning, ContactPinning.lowestContact);
      expect(clip.locomotes, isFalse);
    });

    test('dynamics default to neutral for clips predating the Effort catalog', () {
      const clip = Clip(name: 'plain', duration: 1, channels: {});
      expect(clip.dynamics, DanceDynamics.neutral);
    });

    test('dynamics can be stamped explicitly (as assembleMoveClip does)', () {
      const dynamics = DanceDynamics(weight: 0.7, time: 0.6, flow: -0.4);
      const clip = Clip(
        name: 'zanku',
        duration: 1,
        channels: {},
        dynamics: dynamics,
      );
      expect(clip.dynamics, dynamics);
    });

    test('blendedClip lerps dynamics by the root blend weight', () {
      const from = Clip(
        name: 'from',
        duration: 2,
        channels: {},
        dynamics: DanceDynamics(weight: -0.6, time: -0.4, flow: -0.2),
      );
      const to = Clip(
        name: 'to',
        duration: 2,
        channels: {},
        dynamics: DanceDynamics(weight: 0.6, time: 0.4, flow: 0.2),
      );

      expect(
        blendedClip(from: from, to: to, weight: 0).dynamics,
        from.dynamics,
      );
      expect(blendedClip(from: from, to: to, weight: 1).dynamics, to.dynamics);
      final mid = blendedClip(from: from, to: to, weight: 0.5).dynamics;
      expect(mid.weight, closeTo(0, 1e-9));
      expect(mid.time, closeTo(0, 1e-9));
      expect(mid.flow, closeTo(0, 1e-9));
    });

    test('blendedClip builds a sparse transition clip over both poses', () {
      const from = Clip(
        name: 'from',
        duration: 2,
        channels: {
          'arm': KeyframeChannel([
            Keyframe(p: 0, rotation: -1),
            Keyframe(p: 1, rotation: -1),
          ]),
        },
        root: KeyframeRootChannel([
          RootKeyframe(p: 0, dx: -10),
          RootKeyframe(p: 1, dx: -10),
        ]),
        limbTargets: [
          LimbIkTarget(
            upperBoneId: 'upper',
            lowerBoneId: 'lower',
            endBoneId: 'hand',
            anchorBoneId: 'torso',
            channel: FixedIkTargetChannel(x: -20, y: 0),
          ),
        ],
      );
      const to = Clip(
        name: 'to',
        duration: 2,
        channels: {
          'torso': KeyframeChannel([
            Keyframe(p: 0, rotation: 1),
            Keyframe(p: 1, rotation: 1),
          ]),
        },
        root: KeyframeRootChannel([
          RootKeyframe(p: 0, dx: 10),
          RootKeyframe(p: 1, dx: 10),
        ]),
        limbTargets: [
          LimbIkTarget(
            upperBoneId: 'upper',
            lowerBoneId: 'lower',
            endBoneId: 'hand',
            anchorBoneId: 'torso',
            channel: FixedIkTargetChannel(x: 20, y: 0),
          ),
        ],
      );

      final clip = blendedClip(from: from, to: to, weight: 0.5);

      expect(clip.name, 'from->to');
      expect(clip.channels.keys, containsAll(['arm', 'torso']));
      expect(clip.root.sample(0).dx, closeTo(0, 1e-9));
      expect(clip.channels['arm']!.sample(0).rotation, closeTo(-0.5, 1e-9));
      expect(clip.channels['torso']!.sample(0).rotation, closeTo(0.5, 1e-9));
      expect(clip.limbTargets.single.channel.sample(0).x, closeTo(0, 1e-9));
    });

    test('blendedClip can window body, joint, and IK transition timing', () {
      const from = Clip(
        name: 'from',
        duration: 2,
        channels: {
          'arm': KeyframeChannel([
            Keyframe(p: 0, rotation: -1),
            Keyframe(p: 1, rotation: -1),
          ]),
          'torso': KeyframeChannel([
            Keyframe(p: 0),
            Keyframe(p: 1),
          ]),
        },
        root: KeyframeRootChannel([
          RootKeyframe(p: 0, dx: -10),
          RootKeyframe(p: 1, dx: -10),
        ]),
        limbTargets: [
          LimbIkTarget(
            upperBoneId: 'upper',
            lowerBoneId: 'lower',
            endBoneId: 'hand',
            anchorBoneId: 'torso',
            channel: FixedIkTargetChannel(x: -20, y: 0),
          ),
        ],
      );
      const to = Clip(
        name: 'to',
        duration: 2,
        channels: {
          'arm': KeyframeChannel([
            Keyframe(p: 0, rotation: 1),
            Keyframe(p: 1, rotation: 1),
          ]),
          'torso': KeyframeChannel([
            Keyframe(p: 0, rotation: 1),
            Keyframe(p: 1, rotation: 1),
          ]),
        },
        root: KeyframeRootChannel([
          RootKeyframe(p: 0, dx: 10),
          RootKeyframe(p: 1, dx: 10),
        ]),
        limbTargets: [
          LimbIkTarget(
            upperBoneId: 'upper',
            lowerBoneId: 'lower',
            endBoneId: 'hand',
            anchorBoneId: 'torso',
            channel: FixedIkTargetChannel(x: 20, y: 0),
          ),
        ],
      );

      final clip = blendedClip(
        from: from,
        to: to,
        weight: 0.5,
        blendMask: const ClipBlendMask(
          root: ClipBlendWindow(end: 0.5),
          joints: {'arm': ClipBlendWindow(start: 0.5)},
          limbTargets: {'hand': ClipBlendWindow(start: 0.5)},
        ),
      );

      expect(
        clip.root.sample(0).dx,
        closeTo(10, 1e-9),
        reason: 'the root/body layer can settle before hand action layers',
      );
      expect(
        clip.channels['arm']!.sample(0).rotation,
        closeTo(-1, 1e-9),
        reason: 'a delayed joint window should keep the outgoing arm at first',
      );
      expect(
        clip.channels['torso']!.sample(0).rotation,
        closeTo(0.5, 1e-9),
        reason: 'unmasked joints preserve the historical global blend weight',
      );
      expect(
        clip.limbTargets.single.channel.sample(0).x,
        closeTo(-20, 1e-9),
        reason: 'hand IK targets can lag without creating an end pop',
      );
      expect(clip.transitionPlan!.weight, 0.5);
    });

    test('blendedClip carries contact-aware transition metadata', () {
      const from = Clip(
        name: 'from',
        duration: 1,
        channels: {},
        contactSpans: [GroundSpan('foot.L', 0, 1)],
        supportFootWorldAnchor: true,
        supportFootWorldAnchorStrength: 0.8,
      );
      const to = Clip(
        name: 'to',
        duration: 1,
        channels: {},
        contactSpans: [GroundSpan('foot.R', 0, 1)],
        contactPinning: ContactPinning.lowestContact,
        supportFootWorldAnchor: true,
        supportFootWorldAnchorStrength: 0.4,
      );

      final clip = blendedClip(from: from, to: to, weight: 0.25);

      expect(clip.transitionPlan, isNotNull);
      expect(clip.transitionPlan!.from.name, 'from');
      expect(clip.transitionPlan!.to.name, 'to');
      expect(clip.transitionPlan!.weight, 0.25);
      expect(clip.contactSpans.map((span) => span.bone), [
        'foot.L',
        'foot.R',
      ]);
      expect(clip.contactPinning, ContactPinning.lowestContact);
      expect(clip.supportFootWorldAnchor, isTrue);
      expect(
        clip.supportFootWorldAnchorStrength,
        closeTo(0.7375, 1e-9),
        reason:
            'support anchoring should fade from outgoing to incoming support '
            'instead of flipping at transition midpoint',
      );
    });
  });

  group('Keyframe.easeFn', () {
    test('a non-smooth channel uses easeFn over ease, allowing overshoot', () {
      // easeFn drives 25% faster than linear, so it crosses 1 before the key.
      double overdrive(double t) => t * 1.25;
      const k0 = Keyframe(p: 0);
      final k1 = Keyframe(p: 1, rotation: 1, easeFn: overdrive);
      final ch = KeyframeChannel([k0, k1]);

      // At local 0.5 easeInOut would give 0.5; easeFn gives 0.625.
      expect(ch.sample(0.5).rotation, closeTo(0.625, 1e-9));
      // At local 0.9 it overshoots past the peak value of 1.
      expect(ch.sample(0.9).rotation, closeTo(1.125, 1e-9));
      // Endpoints are still exact.
      expect(ch.sample(0).rotation, closeTo(0, 1e-9));
      expect(ch.sample(1).rotation, closeTo(1, 1e-9));
    });

    test('a smooth channel ignores easeFn (the spline path)', () {
      var calls = 0;
      double spy(double t) {
        calls++;
        return t;
      }

      final keys = [
        Keyframe(p: 0, easeFn: spy),
        Keyframe(p: 0.5, rotation: 1, easeFn: spy),
        Keyframe(p: 1, easeFn: spy),
      ];
      KeyframeChannel(keys, smooth: true).sample(0.25);
      expect(calls, 0, reason: 'the smooth path must not consult easeFn');
    });
  });
  group('smooth tension', () {
    const keys = [
      Keyframe(p: 0),
      Keyframe(p: 0.25, rotation: 1, tension: 1),
      Keyframe(p: 0.5),
      Keyframe(p: 0.75, rotation: -1),
      Keyframe(p: 1),
    ];
    const channel = KeyframeChannel(keys, smooth: true, cyclic: true);

    test('tensioned keys still pass exactly through their values', () {
      expect(channel.sample(0.25).rotation, closeTo(1, 1e-9));
      expect(channel.sample(0.75).rotation, closeTo(-1, 1e-9));
    });

    test('tension 1 means a dead arrival: zero velocity at the key', () {
      const eps = 1e-4;
      final before =
          (channel.sample(0.25).rotation -
              channel.sample(0.25 - eps).rotation) /
          eps;
      final after =
          (channel.sample(0.25 + eps).rotation -
              channel.sample(0.25).rotation) /
          eps;
      expect(
        before.abs(),
        lessThan(0.02),
        reason: 'the motion arrives dead at a tension-1 key',
      );
      expect(
        after.abs(),
        lessThan(0.02),
        reason: 'and accelerates away from rest — no velocity jump',
      );
      // An untensioned PASS-THROUGH key keeps real velocity (0.5 sits
      // between +1 and -1 — its finite-difference tangent is strong).
      final through =
          (channel.sample(0.5 + eps).rotation -
              channel.sample(0.5 - eps).rotation) /
          (2 * eps);
      expect(through.abs(), greaterThan(0.5));
    });

    test('tension 0 reproduces the plain smooth spline', () {
      const plain = KeyframeChannel(
        [
          Keyframe(p: 0),
          Keyframe(p: 0.25, rotation: 1),
          Keyframe(p: 0.5),
          Keyframe(p: 0.75, rotation: -1),
          Keyframe(p: 1),
        ],
        smooth: true,
        cyclic: true,
      );
      const explicit = KeyframeChannel(
        [
          Keyframe(p: 0),
          Keyframe(p: 0.25, rotation: 1),
          Keyframe(p: 0.5),
          Keyframe(p: 0.75, rotation: -1),
          Keyframe(p: 1),
        ],
        smooth: true,
        cyclic: true,
      );
      for (var i = 0; i <= 40; i++) {
        final p = i / 40;
        expect(
          explicit.sample(p).rotation,
          closeTo(plain.sample(p).rotation, 1e-12),
        );
      }
    });
  });
}
