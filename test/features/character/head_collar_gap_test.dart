import 'package:dancing_cats/features/character/runtime/character_scene.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';
import 'package:flutter_test/flutter_test.dart';

/// The head must stay ATTACHED: catalogue-wide bound on the visible
/// chin-to-collar gap.
///
/// Regression gate for the 2026-07-05 owner report ("heads bopping around
/// like crazy", with screenshots of the skull floating a chin-height off the
/// collar at every crouch bottom). Two mechanisms had compounded:
///
///  1. The spine leveler (#65) dropped the per-clip
///     `Clip.danceHeadLevelClampMin` lift budget, letting leveling hold the
///     skull at each joint's historical-max gap while the trunk sank.
///  2. The R20 bounce-cascade follows saturated their clamps once the R21
///     pocket deepened, adding up to ~10 units of skull-vs-collar
///     differential on every count.
///
/// Together: a measured 18-40 unit chin-to-collar pump per beat. The gap a
/// real neck can open is bounded; these bounds sit just above the healthy
/// post-fix measurements (stretch 8.7-14.3, max gap 23.5) and far below the
/// broken ones (stretch to 40, max gap 29+ with the skull visibly severed).
void main() {
  test('chin-to-collar gap stays in a neck-plausible band on every clip', () {
    final scene = CharacterScene(buildCatInSuitRig());
    final clips = {
      'shaku': CatClips.shaku,
      'zanku': CatClips.zanku,
      'azonto': CatClips.azonto,
      'sekem': CatClips.sekem,
      'buga': CatClips.buga,
      'pouncingCat': CatClips.pouncingCat,
    };
    const samples = 192;
    for (final entry in clips.entries) {
      final clip = entry.value;
      var lo = double.infinity;
      var hi = double.negativeInfinity;
      for (var i = 0; i < samples; i++) {
        final frame = scene.frameAt(
          clip: clip,
          timeSeconds: clip.duration * i / samples,
        );
        final gap = frame.world[CatBones.shirtV]!.ty -
            frame.world[CatBones.head]!.ty;
        lo = gap < lo ? gap : lo;
        hi = gap > hi ? gap : hi;
      }
      expect(
        hi,
        lessThan(26),
        reason:
            '${entry.key}: the chin sits ${hi.toStringAsFixed(1)} above the '
            'collar at its widest — the skull is visibly off the body',
      );
      expect(
        hi - lo,
        lessThan(16),
        reason:
            '${entry.key}: the chin-to-collar gap swings '
            '${(hi - lo).toStringAsFixed(1)} units over the loop — the neck '
            'is pumping, not articulating',
      );
      expect(
        lo,
        greaterThan(0),
        reason:
            '${entry.key}: the chin dips ${lo.toStringAsFixed(1)} — at or '
            'below the collar line',
      );
    }
  });
}
