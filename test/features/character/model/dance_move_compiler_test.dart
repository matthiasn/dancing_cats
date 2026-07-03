import 'package:dancing_cats/features/character/model/afrobeats_move.dart';
import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/dance_move_compiler.dart';
import 'package:dancing_cats/features/character/model/dance_move_descriptor.dart';
import 'package:dancing_cats/features/character/model/dance_phrase.dart';
import 'package:flutter_test/flutter_test.dart';

/// Returns [value] unchanged, but as a *runtime* value the compiler cannot fold
/// into a constant. Used to force a `const` constructor to run at runtime (so
/// its body is counted by coverage) instead of being const-canonicalised away.
T _runtime<T>(T value) => value;

const _phrase = DancePhrase(
  frameCount: 16,
  supports: [
    DanceSupportSpan(
      footBoneId: 'foot.L',
      freeFootBoneId: 'foot.R',
      startFrame: 0,
      endFrame: 16,
      loadFrame: 4,
      releaseFrame: 8,
      maxPelvisDistance: 36,
      pocketScaleY: 0.92,
      label: 'left pocket',
    ),
  ],
);

const _move = AfrobeatsMove(
  name: 'synthetic-move',
  feel: DanceFeel.onBeat,
  featuredRegion: BodyRegion.full,
);

void main() {
  group('assembleMoveClip', () {
    test('compiles every descriptor construct into the matching Clip field', () {
      final descriptor = _runtime(
        const DanceMoveDescriptor(
          move: _move,
          duration: 1.6,
          loop: false,
          locomotionSpeed: 2.5,
          contactPinning: ContactPinning.lowestContact,
          jointTracks: {
            'arm.upper.R': [
              DanceJointKey(0, rotation: 0.1),
              DanceJointKey(8, rotation: -0.2),
            ],
          },
          bodyMotion: DanceBodyMotionTrack(
            pelvisBoneId: 'pelvis',
            chestBoneId: 'chest',
            keys: [
              DanceBodyKey(
                0,
                rootDy: 0.05,
                pelvisRotation: 0.03,
                chestRotation: 0.1,
                chestScaleY: 1.2,
              ),
              DanceBodyKey(8, rootDy: -0.05),
            ],
          ),
          limbTargetTracks: {
            'hand.R': [
              DanceIkTargetKey(0, x: 10, y: 5),
              DanceIkTargetKey(8, x: 12, y: 3),
            ],
          },
          supports: [
            DanceSupportSpan(
              footBoneId: 'foot.L',
              freeFootBoneId: 'foot.R',
              startFrame: 0,
              endFrame: 16,
              loadFrame: 4,
              releaseFrame: 8,
              maxPelvisDistance: 36,
              pocketScaleY: 0.92,
              label: 'left pocket',
            ),
          ],
          extraJointChannels: {'ear.L': SineChannel(amplitude: 0.02)},
          supportFootWorldAnchor: true,
          supportFootWorldAnchorStrength: 0.9,
          danceHeadBobScale: 0.4,
          danceHeadLevelClampMin: -1,
          zOrderSwaps: [
            ZOrderSwapWindow(boneA: 'hand.L', boneB: 'hand.R', start: 0.4, end: 0.6),
          ],
        ),
      );
      const rig = [
        LimbIkTarget(
          upperBoneId: 'arm.upper.R',
          lowerBoneId: 'arm.lower.R',
          endBoneId: 'hand.R',
          anchorBoneId: 'torso',
          channel: KeyframeIkTargetChannel([]),
          bendDirection: -1,
        ),
        LimbIkTarget(
          upperBoneId: 'leg.upper.L',
          lowerBoneId: 'leg.lower.L',
          endBoneId: 'foot.L',
          anchorBoneId: 'hips',
          channel: KeyframeIkTargetChannel([]),
        ),
      ];

      final clip = assembleMoveClip(_phrase, descriptor, rigLimbTargets: rig);

      expect(clip.name, 'synthetic-move');
      expect(clip.duration, 1.6);
      expect(clip.loop, isFalse);
      expect(clip.locomotionSpeed, 2.5);
      expect(clip.contactPinning, ContactPinning.lowestContact);
      expect(clip.supportFootWorldAnchor, isTrue);
      expect(clip.supportFootWorldAnchorStrength, 0.9);
      expect(clip.danceHeadBobScale, 0.4);
      expect(clip.danceHeadLevelClampMin, -1);
      expect(clip.zOrderSwaps, hasLength(1));
      expect(clip.zOrderSwaps.single.boneA, 'hand.L');

      // jointTracks compiles to a real KeyframeChannel via phrase.jointChannel.
      final armChannel = clip.channels['arm.upper.R'];
      expect(armChannel, isA<KeyframeChannel>());
      expect((armChannel! as KeyframeChannel).keys, hasLength(2));

      // bodyMotion writes pelvis/chest channels and layers the root channel.
      expect(clip.channels['pelvis'], isA<KeyframeChannel>());
      final chestChannel = clip.channels['chest']! as KeyframeChannel;
      // Only the key with chest data survives the damping filter.
      expect(chestChannel.keys, hasLength(1));
      expect(chestChannel.keys.single.rotation, closeTo(0.1 * 0.88, 1e-9));
      expect(clip.root, isA<LayeredRootChannel>());

      // extraJointChannels overlays a raw procedural channel verbatim.
      expect(clip.channels['ear.L'], isA<SineChannel>());
      expect((clip.channels['ear.L']! as SineChannel).amplitude, 0.02);

      // limbTargetTracks rebinds the matching rig entry's channel while
      // preserving its bone-chain ids and bend direction; the entry with no
      // matching track keeps the rig's original channel.
      expect(clip.limbTargets, hasLength(2));
      final handTarget = clip.limbTargets.firstWhere(
        (t) => t.endBoneId == 'hand.R',
      );
      expect(handTarget.upperBoneId, 'arm.upper.R');
      expect(handTarget.bendDirection, -1);
      expect(handTarget.channel, isA<KeyframeIkTargetChannel>());
      expect(
        (handTarget.channel as KeyframeIkTargetChannel).keys,
        hasLength(2),
      );
      final footTarget = clip.limbTargets.firstWhere(
        (t) => t.endBoneId == 'foot.L',
      );
      expect(
        (footTarget.channel as KeyframeIkTargetChannel).keys,
        isEmpty, // untouched rig default — no matching track for foot.L
      );

      // supports compiles to phase-mapped contactSpans.
      expect(clip.contactSpans, hasLength(1));
      expect(clip.contactSpans.single.bone, 'foot.L');
      expect(clip.contactSpans.single.start, 0);
      expect(clip.contactSpans.single.end, 1);
    });

    test('falls back to baseClip for every unset field/track', () {
      final base = _runtime(
        Clip(
          name: 'base',
          duration: 2,
          channels: const {'chest': SineChannel(amplitude: 0.01)},
          root: const SineRootChannel(bobAmplitude: 0.02),
          locomotionSpeed: 1.1,
          contactPinning: ContactPinning.lowestContact,
          supportFootWorldAnchor: true,
          supportFootWorldAnchorStrength: 0.7,
          danceHeadBobScale: 0.5,
          danceHeadLevelClampMin: -3,
          zOrderSwaps: const [
            ZOrderSwapWindow(boneA: 'a', boneB: 'b', start: 0, end: 0.5),
          ],
        ),
      );
      final withBase = DanceMoveDescriptor(
        move: _move,
        duration: 2,
        baseClip: base,
      );

      final clip = assembleMoveClip(_phrase, withBase);

      expect(clip.locomotionSpeed, 1.1);
      expect(clip.contactPinning, ContactPinning.lowestContact);
      expect(clip.supportFootWorldAnchor, isTrue);
      expect(clip.supportFootWorldAnchorStrength, 0.7);
      expect(clip.danceHeadBobScale, 0.5);
      expect(clip.danceHeadLevelClampMin, -3);
      expect(clip.zOrderSwaps, base.zOrderSwaps);
      expect(clip.transitionPlan, isNull);
      // Base channel carries through untouched when no jointTracks override it.
      expect(clip.channels['chest'], isA<SineChannel>());
      expect((clip.channels['chest']! as SineChannel).amplitude, 0.01);
      expect(clip.root, isA<SineRootChannel>());
    });

    test('an empty descriptor with no base falls back to Clip defaults', () {
      const descriptor = DanceMoveDescriptor(move: _move, duration: 1);

      final clip = assembleMoveClip(_phrase, descriptor);

      expect(clip.locomotionSpeed, 0);
      expect(clip.contactPinning, ContactPinning.activeSpan);
      expect(clip.supportFootWorldAnchor, isFalse);
      expect(clip.supportFootWorldAnchorStrength, 0.6);
      expect(clip.danceHeadBobScale, 1);
      expect(clip.danceHeadLevelClampMin, -2);
      expect(clip.zOrderSwaps, isEmpty);
      expect(clip.channels, isEmpty);
      expect(clip.contactSpans, isEmpty);
      expect(clip.limbTargets, isEmpty);
      expect(clip.root, isA<SineRootChannel>());
    });
  });
}
