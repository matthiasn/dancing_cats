import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/dance_dynamics.dart';
import 'package:dancing_cats/features/character/model/dance_dynamics_warp.dart';
import 'package:flutter_test/flutter_test.dart';

const _strong = DanceDynamics(weight: 0.7, time: 0.6, flow: -0.4);

Clip _loopingClip({
  Map<String, JointChannel> channels = const {},
  List<LimbIkTarget> limbTargets = const [],
}) => Clip(
  name: 'test-move',
  duration: 6,
  channels: channels,
  limbTargets: limbTargets,
);

void main() {
  group('upperBodyLoopSeamEasedClip', () {
    test('retains position while reducing velocity at the cyclic seam', () {
      const hand = SineChannel(
        harmonicAmplitude: 1,
        harmonicMultiplier: 1,
        harmonicPhase: 0,
      );
      const foot = KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 1, rotation: 1),
      ]);
      final clip = _loopingClip(channels: {'hand.R': hand, 'foot.R': foot});
      final eased = upperBodyLoopSeamEasedClip(
        clip,
        upperBodyBoneIds: {'hand.R'},
      );

      expect(eased.channels['hand.R'], isA<LoopSeamSettledJointChannel>());
      expect(identical(eased.channels['foot.R'], foot), isTrue);
      expect(eased.channels['hand.R']!.sample(0).rotation, closeTo(0, 1e-12));
      expect(
        eased.channels['hand.R']!
            .sample(kMovingUpperBodySeamEaseWidth)
            .rotation,
        closeTo(hand.sample(kMovingUpperBodySeamEaseWidth).rotation, 1e-12),
      );

      const epsilon = 1e-5;
      final baseDelta = hand.sample(epsilon).rotation - hand.sample(0).rotation;
      final easedDelta =
          eased.channels['hand.R']!.sample(epsilon).rotation -
          eased.channels['hand.R']!.sample(0).rotation;
      expect(easedDelta.abs(), lessThan(baseDelta.abs() * 0.001));
    });

    test('wraps hand targets but never support-foot targets', () {
      const handTarget = LimbIkTarget(
        upperBoneId: 'arm_upper.R',
        lowerBoneId: 'arm_lower.R',
        endBoneId: 'hand.R',
        anchorBoneId: 'chest',
        channel: FixedIkTargetChannel(x: 5, y: 0),
      );
      const footTarget = LimbIkTarget(
        upperBoneId: 'leg_upper.R',
        lowerBoneId: 'leg_lower.R',
        endBoneId: 'foot.R',
        anchorBoneId: 'hips',
        channel: FixedIkTargetChannel(x: 0, y: 10),
      );
      final clip = _loopingClip(limbTargets: [handTarget, footTarget]);
      final eased = upperBodyLoopSeamEasedClip(
        clip,
        upperBodyBoneIds: {'hand.R'},
      );
      final byId = {for (final t in eased.limbTargets) t.endBoneId: t};

      expect(byId['hand.R']!.channel, isA<LoopSeamSettledIkTargetChannel>());
      expect(identical(byId['foot.R']!.channel, footTarget.channel), isTrue);
    });
  });

  group('upperBodyDynamicsWarpedClip — identity no-op cases', () {
    test('neutral dynamics returns the SAME clip instance', () {
      final clip = _loopingClip();
      final warped = upperBodyDynamicsWarpedClip(
        clip,
        DanceDynamics.neutral,
        warpBoneIds: {'torso'},
      );
      expect(identical(warped, clip), isTrue);
    });

    test('zero gain returns the SAME clip instance for any dynamics', () {
      final clip = _loopingClip();
      final warped = upperBodyDynamicsWarpedClip(
        clip,
        _strong,
        warpBoneIds: {'torso'},
        gain: 0,
      );
      expect(identical(warped, clip), isTrue);
    });

    test('a one-shot (non-looping) clip is returned unchanged', () {
      const clip = Clip(
        name: 'kick',
        duration: 1,
        loop: false,
        channels: {},
      );
      final warped = upperBodyDynamicsWarpedClip(
        clip,
        _strong,
        warpBoneIds: {'torso'},
      );
      expect(identical(warped, clip), isTrue);
    });

    test(
      'the default gain constant is live (ADR CHAR-0003 tuning) and the '
      'default-gain call actually warps',
      () {
        final clip = _loopingClip(
          channels: {
            'torso': const KeyframeChannel(
              [
                Keyframe(p: 0),
                Keyframe(p: 0.25, rotation: 1),
                Keyframe(p: 0.5, rotation: -1),
                Keyframe(p: 0.75, rotation: 0.5),
                Keyframe(p: 1),
              ],
              smooth: true,
              cyclic: true,
            ),
          },
        );
        final warped = upperBodyDynamicsWarpedClip(
          clip,
          _strong,
          warpBoneIds: {'torso'},
        );
        expect(kDanceDynamicsTimeWarpGain, isNot(0));
        expect(identical(warped, clip), isFalse);
        expect(warped.channels['torso'], isA<PhaseWarpedJointChannel>());
      },
    );
  });

  group('upperBodyDynamicsWarpedClip — selective wrapping', () {
    test(
      'only bones in warpBoneIds are wrapped; others keep their instance',
      () {
        const torsoChannel = KeyframeChannel([
          Keyframe(p: 0),
          Keyframe(p: 1, rotation: 1),
        ]);
        const footChannel = KeyframeChannel([
          Keyframe(p: 0),
          Keyframe(p: 1, rotation: 1),
        ]);
        final clip = _loopingClip(
          channels: {'torso': torsoChannel, 'foot.L': footChannel},
        );

        final warped = upperBodyDynamicsWarpedClip(
          clip,
          _strong,
          warpBoneIds: {'torso'},
        );

        expect(warped.channels['torso'], isA<PhaseWarpedJointChannel>());
        expect(identical(warped.channels['foot.L'], footChannel), isTrue);
      },
    );

    test('hand IK targets wrap; foot IK targets never do', () {
      const handTarget = LimbIkTarget(
        upperBoneId: 'arm_upper.R',
        lowerBoneId: 'arm_lower.R',
        endBoneId: 'hand.R',
        anchorBoneId: 'chest',
        channel: FixedIkTargetChannel(x: 5, y: 0),
      );
      const footTarget = LimbIkTarget(
        upperBoneId: 'leg_upper.R',
        lowerBoneId: 'leg_lower.R',
        endBoneId: 'foot.R',
        anchorBoneId: 'hips',
        channel: FixedIkTargetChannel(x: 0, y: 10),
      );
      final clip = _loopingClip(limbTargets: [handTarget, footTarget]);

      final warped = upperBodyDynamicsWarpedClip(
        clip,
        _strong,
        warpBoneIds: {'hand.R'},
      );

      final byId = {for (final t in warped.limbTargets) t.endBoneId: t};
      expect(byId['hand.R']!.channel, isA<PhaseWarpedIkTargetChannel>());
      expect(identical(byId['foot.R']!.channel, footTarget.channel), isTrue);
    });

    test('preserves every other Clip field verbatim', () {
      const clip = Clip(
        name: 'sekem',
        duration: 6,
        channels: {
          'torso': KeyframeChannel([Keyframe(p: 0)]),
        },
        locomotionSpeed: 1.5,
        groundSpans: [GroundSpan('foot.L', 0, 0.5)],
        contactSpans: [GroundSpan('foot.R', 0.5, 1)],
        contactPinning: ContactPinning.lowestContact,
        supportFootWorldAnchor: true,
        supportFootWorldAnchorStrength: 0.8,
        danceHeadBobScale: 0.3,
        danceHeadLevelClampMin: -1,
        enforceSoleFloor: true,
        zOrderSwaps: [
          ZOrderSwapWindow(
            boneA: 'hand.L',
            boneB: 'hand.R',
            start: 0.4,
            end: 0.6,
          ),
        ],
        dynamics: _strong,
      );

      final warped = upperBodyDynamicsWarpedClip(
        clip,
        const DanceDynamics(flow: 0.5),
        warpBoneIds: {'torso'},
      );

      expect(warped.name, clip.name);
      expect(warped.duration, clip.duration);
      expect(warped.loop, clip.loop);
      expect(warped.locomotionSpeed, clip.locomotionSpeed);
      expect(warped.groundSpans, clip.groundSpans);
      expect(warped.contactSpans, clip.contactSpans);
      expect(warped.contactPinning, clip.contactPinning);
      expect(warped.supportFootWorldAnchor, clip.supportFootWorldAnchor);
      expect(
        warped.supportFootWorldAnchorStrength,
        clip.supportFootWorldAnchorStrength,
      );
      expect(warped.danceHeadBobScale, clip.danceHeadBobScale);
      expect(warped.danceHeadLevelClampMin, clip.danceHeadLevelClampMin);
      expect(warped.enforceSoleFloor, clip.enforceSoleFloor);
      expect(warped.zOrderSwaps, clip.zOrderSwaps);
      // The move-base dynamics is lane-invariant metadata, carried through
      // unchanged — the warp only reshapes SAMPLING, not this field.
      expect(warped.dynamics, clip.dynamics);
    });
  });

  group('upperBodyDynamicsWarpedClip — beat re-sync and loop-seam safety', () {
    test('pose exactly matches the unwarped clip at every beat boundary', () {
      const channel = KeyframeChannel(
        [
          Keyframe(p: 0),
          Keyframe(p: 0.25, rotation: 1),
          Keyframe(p: 0.5, rotation: -1),
          Keyframe(p: 0.75, rotation: 0.5),
          Keyframe(p: 1),
        ],
        smooth: true,
        cyclic: true,
      );
      final clip = _loopingClip(channels: {'torso': channel});

      final warped = upperBodyDynamicsWarpedClip(
        clip,
        _strong,
        warpBoneIds: {'torso'},
      );

      for (var beat = 0; beat < kDanceBeatsPerPhraseLoop; beat++) {
        final p = beat / kDanceBeatsPerPhraseLoop;
        expect(
          warped.channels['torso']!.sample(p).rotation,
          closeTo(channel.sample(p).rotation, 1e-9),
          reason: 'beat $beat must land on the unwarped pose exactly',
        );
      }
      // The final boundary (p == 1) closes the loop.
      expect(
        warped.channels['torso']!.sample(1).rotation,
        closeTo(channel.sample(1).rotation, 1e-9),
      );
    });

    test('samples just inside/outside the loop seam stay continuous', () {
      const channel = KeyframeChannel(
        [
          Keyframe(p: 0),
          Keyframe(p: 0.5, rotation: 1),
          Keyframe(p: 1),
        ],
        smooth: true,
        cyclic: true,
      );
      final clip = _loopingClip(channels: {'torso': channel});

      // Strong weight dips the warp below 0 near a beat start — the seam
      // beat (0) is the one most likely to wrap out of range.
      final warped = upperBodyDynamicsWarpedClip(
        clip,
        _strong,
        warpBoneIds: {'torso'},
      );

      final justBefore = warped.channels['torso']!.sample(0.999).rotation;
      final justAfter = warped.channels['torso']!.sample(0.001).rotation;
      // Both must be finite, plausible rotation values (the cyclic spline is
      // continuous across the seam by construction) — a wrap bug would
      // instead produce a jump to an out-of-loop or NaN sample.
      expect(justBefore.isFinite, isTrue);
      expect(justAfter.isFinite, isTrue);
      expect((justBefore - justAfter).abs(), lessThan(0.5));
    });
  });
}
