import 'dart:math' as math;

import 'package:dancing_cats/features/character/runtime/character_scene.dart';
import 'package:dancing_cats/features/character/runtime/temporal_motion_analyzer.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the smooth-interpolation migration: catalogue hand paths flow
/// through their keys instead of dead-stopping at each one.
///
/// Before the migration the zanku/azonto hand channels were per-segment
/// eased (velocity pinned to zero at EVERY key) with a corner blur stacked
/// on top. The current round-4 authored hits keep smooth spline channels, but
/// deliberately add sharper zanku punch accents; these bounds hold the ceiling
/// above those accents so a regression back to stop-go easing still fails
/// loudly instead of reading as "robotic" in review.
void main() {
  test('catalogue hand motion keeps rendered jerk below the stop-go band', () {
    final scene = CharacterScene(buildCatInSuitRig());
    final analyzer = TemporalMotionAnalyzer(scene);

    for (final clip in [CatClips.zanku, CatClips.azonto]) {
      final report = analyzer.analyze(
        clip: clip,
        samples: 192,
        boneIds: const [CatBones.handL, CatBones.handR],
      );
      for (final hand in const [CatBones.handL, CatBones.handR]) {
        final worstJerk = report.jerks
            .where((jerk) => jerk.boneId == hand)
            .map((jerk) => jerk.magnitude)
            .reduce(math.max);
        expect(
          worstJerk,
          lessThan(28),
          reason:
              '${clip.name} $hand worst jerk should stay bounded even with '
              'the authored round-4 punch accents',
        );
      }
    }
  });
}
