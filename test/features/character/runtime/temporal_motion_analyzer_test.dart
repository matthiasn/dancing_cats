import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/easing.dart';
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
      expect(report.segments, hasLength(1));
      expect(() => report.worstAcceleration, throwsStateError);
    });
  });
}
