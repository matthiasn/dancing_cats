import 'package:dancing_cats/features/character/engine/autonomic.dart';
import 'package:dancing_cats/features/character/model/bone.dart';
import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/easing.dart';
import 'package:dancing_cats/features/character/model/rig_spec.dart';
import 'package:dancing_cats/features/character/runtime/character_scene.dart';
import 'package:dancing_cats/features/character/runtime/temporal_motion_analyzer.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TemporalMotionAnalyzer', () {
    test('reports exact worst-frame displacement for the dance clip', () {
      final analyzer = TemporalMotionAnalyzer(
        CharacterScene(buildCatInSuitRig()),
      );
      const watchedBones = [
        CatBones.hips,
        CatBones.torso,
        CatBones.head,
        CatBones.handL,
        CatBones.handR,
        CatBones.footL,
        CatBones.footR,
        CatBones.tail6,
      ];

      final report = analyzer.analyze(
        clip: CatClips.shaku,
        samples: 96,
        boneIds: watchedBones,
      );
      final worst = report.worstDisplacement;

      expect(report.clipName, CatClips.shaku.name);
      expect(report.segments, hasLength(96 * watchedBones.length));
      expect(worst.boneId, isIn(watchedBones));
      expect(worst.fromFrame + 1, worst.toFrame);
      expect(worst.fromPhase, closeTo(worst.fromFrame / 96, 1e-9));
      expect(worst.toPhase, closeTo(worst.toFrame / 96, 1e-9));
      expect(
        worst.distance,
        lessThan(75),
        reason:
            'Shaku now uses bigger crossed-arm travel than the old generic '
            'dance clip, but the resolved hands should stay below the visible '
            'one-frame snap budget',
      );
    });

    test('separates acceleration spikes from large but steady travel', () {
      final analyzer = TemporalMotionAnalyzer(
        CharacterScene(buildCatInSuitRig()),
      );
      const clip = Clip(
        name: 'synthetic-root-snap',
        duration: 1,
        loop: false,
        root: KeyframeRootChannel([
          RootKeyframe(p: 0),
          RootKeyframe(p: 0.5, dx: 120, ease: Ease.linear),
          RootKeyframe(p: 1, dx: 120, ease: Ease.linear),
        ]),
        channels: {},
      );

      final report = analyzer.analyze(
        clip: clip,
        samples: 4,
        boneIds: const [CatBones.hips],
      );

      expect(report.topDisplacements(2), hasLength(2));
      expect(report.worstDisplacement.dx.abs(), closeTo(60, 1e-9));
      expect(report.worstDisplacement.distance, closeTo(60, 0.01));
      expect(report.worstAcceleration.throughFrame, 2);
      expect(report.worstAcceleration.dx.abs(), closeTo(60, 1e-9));
      expect(report.worstAcceleration.magnitude, closeTo(60, 0.01));
    });

    test('rejects a non-positive sample count', () {
      final analyzer = TemporalMotionAnalyzer(
        CharacterScene(buildCatInSuitRig()),
      );
      expect(
        () => analyzer.analyze(
          clip: CatClips.shaku,
          samples: 0,
          boneIds: const [CatBones.hips],
        ),
        throwsArgumentError,
      );
    });

    test('rejects an empty bone list', () {
      final analyzer = TemporalMotionAnalyzer(
        CharacterScene(buildCatInSuitRig()),
      );
      expect(
        () => analyzer.analyze(
          clip: CatClips.shaku,
          samples: 4,
          boneIds: const [],
        ),
        throwsArgumentError,
      );
    });

    test('throws when a watched bone is not resolved in the rig', () {
      final analyzer = TemporalMotionAnalyzer(
        CharacterScene(buildCatInSuitRig()),
      );
      expect(
        () => analyzer.analyze(
          clip: CatClips.shaku,
          samples: 4,
          boneIds: const ['no-such-bone'],
        ),
        throwsStateError,
      );
    });

    test(
      'topAccelerations returns the n biggest spikes, sorted descending',
      () {
        final analyzer = TemporalMotionAnalyzer(
          CharacterScene(buildCatInSuitRig()),
        );
        const clip = Clip(
          name: 'synthetic-root-snap',
          duration: 1,
          loop: false,
          root: KeyframeRootChannel([
            RootKeyframe(p: 0),
            RootKeyframe(p: 0.5, dx: 120, ease: Ease.linear),
            RootKeyframe(p: 1, dx: 120, ease: Ease.linear),
          ]),
          channels: {},
        );
        final report = analyzer.analyze(
          clip: clip,
          samples: 4,
          boneIds: const [CatBones.hips],
        );
        final top = report.topAccelerations(2);
        expect(top, hasLength(2));
        expect(
          top.first.magnitude,
          greaterThanOrEqualTo(top.last.magnitude),
          reason: 'sorted by magnitude, biggest first',
        );
        expect(
          top.first.magnitude,
          closeTo(report.worstAcceleration.magnitude, 1e-9),
        );
      },
    );

    test('topJerks returns acceleration-change spikes sorted descending', () {
      final analyzer = TemporalMotionAnalyzer(
        CharacterScene(buildCatInSuitRig()),
      );
      const clip = Clip(
        name: 'synthetic-root-snap',
        duration: 1,
        loop: false,
        root: KeyframeRootChannel([
          RootKeyframe(p: 0),
          RootKeyframe(p: 0.5, dx: 120, ease: Ease.linear),
          RootKeyframe(p: 1, dx: 120, ease: Ease.linear),
        ]),
        channels: {},
      );
      final report = analyzer.analyze(
        clip: clip,
        samples: 4,
        boneIds: const [CatBones.hips],
      );

      final top = report.topJerks(2);
      expect(top, hasLength(2));
      expect(report.jerks, hasLength(2));
      expect(top.first.magnitude, greaterThanOrEqualTo(top.last.magnitude));
      expect(top.first.magnitude, closeTo(report.worstJerk.magnitude, 1e-9));
      expect(report.worstJerk.magnitude, closeTo(60, 0.01));
    });

    test('velocitySpikes finds an abrupt speed pulse without a full hold', () {
      final analyzer = TemporalMotionAnalyzer(
        _oneBoneScene(),
      );
      const clip = Clip(
        name: 'synthetic-speed-pulse',
        duration: 1,
        loop: false,
        root: KeyframeRootChannel([
          RootKeyframe(p: 0),
          RootKeyframe(p: 0.4, dx: 20, ease: Ease.linear),
          RootKeyframe(p: 0.6, dx: 100, ease: Ease.linear),
          RootKeyframe(p: 1, dx: 120, ease: Ease.linear),
        ]),
        channels: {},
      );

      final report = analyzer.analyze(
        clip: clip,
        samples: 5,
        boneIds: const [CatBones.hips],
      );
      final spikes = report.velocitySpikes(
        minAcceleration: 40,
        minSpeedDelta: 40,
        minSpeedRatio: 3,
      );

      expect(spikes, hasLength(2));
      expect(spikes.first.boneId, CatBones.hips);
      expect(spikes.first.accelerationMagnitude, closeTo(70, 0.01));
      expect(spikes.first.speedDelta, closeTo(70, 0.01));
      expect(spikes.first.speedRatio, closeTo(8, 0.01));
    });

    test('velocitySpikes ignores steady continuous travel', () {
      final analyzer = TemporalMotionAnalyzer(
        _oneBoneScene(),
      );
      const clip = Clip(
        name: 'synthetic-steady-speed',
        duration: 1,
        loop: false,
        root: KeyframeRootChannel([
          RootKeyframe(p: 0),
          RootKeyframe(p: 1, dx: 120, ease: Ease.linear),
        ]),
        channels: {},
      );

      final report = analyzer.analyze(
        clip: clip,
        samples: 5,
        boneIds: const [CatBones.hips],
      );

      expect(
        report.velocitySpikes(
          minAcceleration: 40,
          minSpeedDelta: 40,
          minSpeedRatio: 3,
        ),
        isEmpty,
      );
    });

    test('pathCorners finds a hard direction change without a speed pulse', () {
      final analyzer = TemporalMotionAnalyzer(
        _oneBoneScene(),
      );
      const clip = Clip(
        name: 'synthetic-hard-corner',
        duration: 1,
        loop: false,
        root: KeyframeRootChannel([
          RootKeyframe(p: 0),
          RootKeyframe(p: 0.5, dx: 40, ease: Ease.linear),
          RootKeyframe(p: 1, dx: 40, dy: 40, ease: Ease.linear),
        ]),
        channels: {},
      );

      final report = analyzer.analyze(
        clip: clip,
        samples: 2,
        boneIds: const [CatBones.hips],
      );
      final corners = report.pathCorners(
        minTurnDegrees: 80,
        minAcceleration: 40,
      );

      expect(corners, hasLength(1));
      expect(corners.single.boneId, CatBones.hips);
      expect(corners.single.turnDegrees, closeTo(90, 0.01));
      expect(corners.single.arcRatio, closeTo(1.414, 0.01));
      expect(corners.single.accelerationMagnitude, closeTo(56.57, 0.01));
    });

    test('pathCorners ignores straight continuous travel', () {
      final analyzer = TemporalMotionAnalyzer(
        _oneBoneScene(),
      );
      const clip = Clip(
        name: 'synthetic-straight-path',
        duration: 1,
        loop: false,
        root: KeyframeRootChannel([
          RootKeyframe(p: 0),
          RootKeyframe(p: 1, dx: 80, ease: Ease.linear),
        ]),
        channels: {},
      );

      final report = analyzer.analyze(
        clip: clip,
        samples: 4,
        boneIds: const [CatBones.hips],
      );

      expect(
        report.pathCorners(
          minTurnDegrees: 80,
          minAcceleration: 40,
        ),
        isEmpty,
      );
    });

    test('stutterTransitions finds a held pose followed by a snap', () {
      final analyzer = TemporalMotionAnalyzer(
        _oneBoneScene(),
      );
      const clip = Clip(
        name: 'synthetic-hold-then-snap',
        duration: 1,
        loop: false,
        root: KeyframeRootChannel([
          RootKeyframe(p: 0),
          RootKeyframe(p: 0.75, ease: Ease.linear),
          RootKeyframe(p: 1, dx: 120, ease: Ease.linear),
        ]),
        channels: {},
      );

      final report = analyzer.analyze(
        clip: clip,
        samples: 4,
        boneIds: const [CatBones.hips],
      );
      final stutters = report.stutterTransitions(
        holdDistance: 0.01,
        releaseDistance: 40,
      );

      expect(stutters, hasLength(1));
      expect(stutters.single.boneId, CatBones.hips);
      expect(stutters.single.holdSegments, 3);
      expect(stutters.single.holdFromFrame, 0);
      expect(stutters.single.holdToFrame, 3);
      expect(stutters.single.exitDistance, closeTo(120, 0.01));
      expect(stutters.single.adjacentTravel, closeTo(120, 0.01));
    });

    test('stutterTransitions ignores steady continuous travel', () {
      final analyzer = TemporalMotionAnalyzer(
        _oneBoneScene(),
      );
      const clip = Clip(
        name: 'synthetic-steady-travel',
        duration: 1,
        loop: false,
        root: KeyframeRootChannel([
          RootKeyframe(p: 0),
          RootKeyframe(p: 1, dx: 120, ease: Ease.linear),
        ]),
        channels: {},
      );

      final report = analyzer.analyze(
        clip: clip,
        samples: 4,
        boneIds: const [CatBones.hips],
      );

      expect(
        report.stutterTransitions(
          holdDistance: 0.01,
          releaseDistance: 40,
        ),
        isEmpty,
      );
    });

    test('dance hands and torso avoid egregious hold-then-teleport pops', () {
      final analyzer = TemporalMotionAnalyzer(
        CharacterScene(buildCatInSuitRig()),
      );
      const watchedBones = [
        CatBones.torso,
        CatBones.handL,
        CatBones.handR,
      ];

      for (final clip in [
        CatClips.shaku,
        CatClips.zanku,
        CatClips.azonto,
        CatClips.buga,
        CatClips.sekem,
      ]) {
        final report = analyzer.analyze(
          clip: clip,
          samples: 128,
          boneIds: watchedBones,
        );
        final stutters = report.stutterTransitions(
          holdDistance: 0.05,
          releaseDistance: 36,
        );

        expect(
          stutters,
          isEmpty,
          reason:
              '${clip.name} should not freeze a watched upper-body bone and '
              'then teleport it; worst ${stutters.isEmpty ? 'none' : stutters.first.boneId} '
              'hold=${stutters.isEmpty ? 'n/a' : '${stutters.first.holdFromFrame}-${stutters.first.holdToFrame}'} '
              'travel=${stutters.isEmpty ? 'n/a' : stutters.first.adjacentTravel.toStringAsFixed(1)}',
        );
      }
    });

    test('dance hands and torso avoid egregious speed-pulse pops', () {
      final analyzer = TemporalMotionAnalyzer(
        CharacterScene(buildCatInSuitRig()),
      );
      const watchedBones = [
        CatBones.torso,
        CatBones.handL,
        CatBones.handR,
      ];

      for (final clip in [
        CatClips.shaku,
        CatClips.zanku,
        CatClips.azonto,
        CatClips.buga,
        CatClips.sekem,
      ]) {
        final report = analyzer.analyze(
          clip: clip,
          samples: 128,
          boneIds: watchedBones,
        );
        final spikes = report.velocitySpikes(
          minAcceleration: 24,
          minSpeedDelta: 14,
          minSpeedRatio: 2.5,
          minSegmentDistance: 3,
        );

        expect(
          spikes,
          isEmpty,
          reason:
              '${clip.name} should not hit a robotic upper-body speed pulse; '
              'worst ${spikes.isEmpty ? 'none' : spikes.first.boneId} '
              'frames=${spikes.isEmpty ? 'n/a' : '${spikes.first.fromFrame}-${spikes.first.toFrame}'} '
              'accel=${spikes.isEmpty ? 'n/a' : spikes.first.accelerationMagnitude.toStringAsFixed(1)} '
              'ratio=${spikes.isEmpty ? 'n/a' : spikes.first.speedRatio.toStringAsFixed(1)}',
        );
      }
    });

    test('dance hands and torso avoid egregious hard path corners', () {
      final analyzer = TemporalMotionAnalyzer(
        CharacterScene(buildCatInSuitRig()),
      );
      const watchedBones = [
        CatBones.torso,
        CatBones.handL,
        CatBones.handR,
      ];

      for (final clip in [
        CatClips.shaku,
        CatClips.zanku,
        CatClips.azonto,
        CatClips.buga,
        CatClips.sekem,
      ]) {
        final report = analyzer.analyze(
          clip: clip,
          samples: 128,
          boneIds: watchedBones,
        );
        final corners = report.pathCorners(
          minTurnDegrees: 165,
          minAcceleration: 34,
          minArcRatio: 2.2,
          minSegmentDistance: 3,
        );

        expect(
          corners,
          isEmpty,
          reason:
              '${clip.name} should not cut a high-travel hand/torso path into '
              'a hard corner; worst ${corners.isEmpty ? 'none' : corners.first.boneId} '
              'frames=${corners.isEmpty ? 'n/a' : '${corners.first.fromFrame}-${corners.first.toFrame}'} '
              'turn=${corners.isEmpty ? 'n/a' : corners.first.turnDegrees.toStringAsFixed(1)} '
              'arc=${corners.isEmpty ? 'n/a' : corners.first.arcRatio.toStringAsFixed(2)} '
              'accel=${corners.isEmpty ? 'n/a' : corners.first.accelerationMagnitude.toStringAsFixed(1)}',
        );
      }
    });

    test('worstAcceleration throws when no acceleration was recorded', () {
      final analyzer = TemporalMotionAnalyzer(
        CharacterScene(buildCatInSuitRig()),
      );
      // A single sample yields one displacement segment but no consecutive
      // pair to derive an acceleration from.
      final report = analyzer.analyze(
        clip: CatClips.shaku,
        samples: 1,
        boneIds: const [CatBones.hips],
      );
      expect(report.accelerations, isEmpty);
      expect(report.jerks, isEmpty);
      expect(report.segments, hasLength(1));
      expect(() => report.worstAcceleration, throwsStateError);
      expect(() => report.worstJerk, throwsStateError);
    });
  });
}

RigSpec _oneBoneRig() => RigSpec(
  name: 'one-bone-motion-probe',
  bones: const [
    Bone(id: CatBones.hips, parent: null, pivotX: 0, pivotY: 0, z: 0),
  ],
);

CharacterScene _oneBoneScene() => CharacterScene(
  _oneBoneRig(),
  autonomic: AutonomicLayer(breathAmplitude: 0),
);
