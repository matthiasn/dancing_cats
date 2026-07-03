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
            'arm.upper.R': DanceJointTrack([
              DanceJointKey(0, rotation: 0.1),
              DanceJointKey(8, rotation: -0.2),
            ], smooth: true),
          },
          bodyMotion: DanceBodyMotion(
            pelvisBoneId: 'pelvis',
            chestBoneId: 'chest',
            tracks: [
              DanceBodyMotionTrack(
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
              DanceBodyMotionTrack(
                keys: [DanceBodyKey(0, pelvisRotation: 0.01)],
              ),
            ],
            extraRootLayers: [SineRootChannel(bobAmplitude: 0.01)],
            extraPelvisLayers: [SineChannel(harmonicAmplitude: 0.006)],
            extraChestLayers: [SineChannel(bias: 0.02)],
          ),
          limbTargetTracks: {
            'hand.R': DanceIkTargetTrack([
              DanceIkTargetKey(0, x: 10, y: 5),
              DanceIkTargetKey(8, x: 12, y: 3),
            ], cyclic: true, microFrames: 1),
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
          rawContactSpans: [GroundSpan('foot.R', 0.4, 0.6)],
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
      final armChannel = clip.channels['arm.upper.R']! as KeyframeChannel;
      expect(armChannel.keys, hasLength(2));
      expect(armChannel.smooth, isTrue);

      // bodyMotion layers every track's pelvis/chest/root channel plus the
      // extra procedural layers, in track order then extra-layer order.
      final rootLayers = (clip.root as LayeredRootChannel).channels;
      expect(rootLayers, hasLength(3)); // 2 tracks + 1 extra root layer
      expect(rootLayers.last, isA<SineRootChannel>());

      final pelvisLayers =
          (clip.channels['pelvis']! as LayeredJointChannel).channels;
      expect(pelvisLayers, hasLength(3)); // 2 tracks + 1 extra pelvis layer
      expect(pelvisLayers.last, isA<SineChannel>());
      expect((pelvisLayers.last as SineChannel).harmonicAmplitude, 0.006);

      final chestLayers =
          (clip.channels['chest']! as LayeredJointChannel).channels;
      expect(chestLayers, hasLength(3)); // 2 tracks + 1 extra chest layer
      // Only the key with chest data survives the first track's damping
      // filter; the second track has no chest data at all.
      final firstChestTrack = chestLayers.first as KeyframeChannel;
      expect(firstChestTrack.keys, hasLength(1));
      expect(firstChestTrack.keys.single.rotation, closeTo(0.1 * 0.88, 1e-9));
      final secondChestTrack = chestLayers[1] as KeyframeChannel;
      expect(secondChestTrack.keys, isEmpty);
      expect(chestLayers.last, isA<SineChannel>());
      expect((chestLayers.last as SineChannel).bias, 0.02);

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
      final handChannel = handTarget.channel as KeyframeIkTargetChannel;
      expect(handChannel.keys, hasLength(2));
      expect(handChannel.cyclic, isTrue);
      // microFrames shifts the whole channel by a fraction of a frame
      // (frame 0 + 1 microFrame, over a 16-frame phrase, phase = 1/16).
      expect(handChannel.keys.first.p, closeTo(1 / 16, 1e-9));
      final footTarget = clip.limbTargets.firstWhere(
        (t) => t.endBoneId == 'foot.L',
      );
      expect(
        (footTarget.channel as KeyframeIkTargetChannel).keys,
        isEmpty, // untouched rig default — no matching track for foot.L
      );

      // supports compiles to phase-mapped contactSpans; rawContactSpans is
      // appended after them verbatim.
      expect(clip.contactSpans, hasLength(2));
      expect(clip.contactSpans[0].bone, 'foot.L');
      expect(clip.contactSpans[0].start, 0);
      expect(clip.contactSpans[0].end, 1);
      expect(clip.contactSpans[1].bone, 'foot.R');
      expect(clip.contactSpans[1].start, 0.4);
      expect(clip.contactSpans[1].end, 0.6);
    });

    test('falls back to baseClip for every unset field/track', () {
      final base = Clip(
        name: _runtime('base'),
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
      );
      final withBase = DanceMoveDescriptor(
        move: _move,
        duration: 2,
        baseClip: base,
        jointTracks: {
          'chest': const DanceJointTrack([
            DanceJointKey(0, rotation: 0.2),
          ], layerOnBase: true),
        },
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
      // layerOnBase: true composes onto the base's existing channel for that
      // bone rather than replacing it.
      final chestChannel = clip.channels['chest']! as LayeredJointChannel;
      expect(chestChannel.channels, hasLength(2));
      expect(chestChannel.channels.first, isA<SineChannel>());
      expect(chestChannel.channels.last, isA<KeyframeChannel>());
      expect(clip.root, isA<SineRootChannel>());
    });

    test('bodyMotion with a single track and no extras stays bit-exact', () {
      const descriptor = DanceMoveDescriptor(
        move: _move,
        duration: 1,
        bodyMotion: DanceBodyMotion(
          pelvisBoneId: 'pelvis',
          chestBoneId: 'chest',
          tracks: [
            DanceBodyMotionTrack(keys: [DanceBodyKey(0, pelvisRotation: 0.05)]),
          ],
        ),
      );

      final clip = assembleMoveClip(_phrase, descriptor);

      // A single contributor still layers (LayeredRootChannel/JointChannel
      // sum starting from 0.0/1.0 neutral, so this samples bit-identically
      // to using the bare channel directly).
      expect((clip.root as LayeredRootChannel).channels, hasLength(1));
      expect(
        (clip.channels['pelvis']! as LayeredJointChannel).channels,
        hasLength(1),
      );
      expect(
        (clip.channels['chest']! as LayeredJointChannel).channels,
        hasLength(1),
      );
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
