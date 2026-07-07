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
///
/// The hand-target follow-through (`_handTargetFollowThrough` in
/// `character_scene.dart`) adds a deliberate C1 settle-overshoot after each
/// hit — real dance hands whip fast and settle, and the owner explicitly
/// relaxed this "hands can't move fast" ceiling for it. It raises the ceiling
/// only on `zanku`, whose most extreme near-degenerate-reach hit clamps against
/// max reach and reads worst (~39); `azonto` stays tightly guarded, so a
/// genuine regression to stop-go easing (which spikes far higher, e.g. the
/// pre-migration values, or the reverted rotation-space settle at ~67) still
/// fails loudly. The follow-through amplitude is capped so this does not run
/// away with gain.
void main() {
  test('catalogue hand motion keeps rendered jerk below the stop-go band', () {
    final scene = CharacterScene(buildCatInSuitRig());
    final analyzer = TemporalMotionAnalyzer(scene);

    // Per-clip ceiling: zanku's near-degenerate reach + the follow-through
    // settle earns headroom; azonto stays at the original stop-go bound.
    const jerkCeiling = {'zanku': 58.0, 'azonto': 28.0};

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
          lessThan(jerkCeiling[clip.name]!),
          reason:
              '${clip.name} $hand worst jerk should stay bounded even with '
              'the authored punch accents + hand-target follow-through settle',
        );
      }
    }
  });
}
