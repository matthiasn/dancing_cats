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
      'movingHookLead': CatClips.movingGroove,
      'movingHookLowCounter': CatClips.movingGrooveLowCounter,
      'movingHookSideAnswer': CatClips.movingGrooveSideAnswer,
      'movingChorusTravel': CatClips.movingChorusTravel,
      'movingChorusOpen': CatClips.movingChorusOpen,
      'movingVerseShuffle': CatClips.movingVerseGroove,
      'movingVerseWindow': CatClips.movingVerseWindow,
      'movingBridgeBounce': CatClips.movingBreakdownGroove,
      'movingBridgeRock': CatClips.movingBridgeRock,
      'movingBodyRoll': CatClips.movingBodyRoll,
    };
    const samples = 192;
    for (final entry in clips.entries) {
      final clip = entry.value;
      var lo = double.infinity;
      var hi = double.negativeInfinity;
      var xLo = double.infinity;
      var xHi = double.negativeInfinity;
      for (var i = 0; i < samples; i++) {
        final frame = scene.frameAt(
          clip: clip,
          timeSeconds: clip.duration * i / samples,
        );
        final head = frame.world[CatBones.head]!;
        final shirt = frame.world[CatBones.shirtV]!;
        final gap = shirt.ty - head.ty;
        lo = gap < lo ? gap : lo;
        hi = gap > hi ? gap : hi;
        final offX = head.tx - shirt.tx;
        xLo = offX < xLo ? offX : xLo;
        xHi = offX > xHi ? offX : xHi;
      }
      final moving = clip.belongsToFamily('moving');
      expect(
        hi,
        lessThan(moving ? 14.5 : 24.5),
        reason:
            '${entry.key}: the chin sits ${hi.toStringAsFixed(1)} above the '
            'collar at its widest — the skull is visibly off the body',
      );
      expect(
        hi - lo,
        lessThan(moving ? 4.5 : 13),
        reason:
            '${entry.key}: the chin-to-collar gap swings '
            '${(hi - lo).toStringAsFixed(1)} units over the loop — the neck '
            'is pumping, not articulating',
      );
      // Firmness v2 (owner: "neck often disappears altogether"): the collar
      // may never swallow the chin — the leveler's downward pull is bounded
      // by the same per-clip budget as its lift.
      expect(
        lo,
        greaterThan(moving ? 10.5 : 12.5),
        reason:
            '${entry.key}: the chin dips to ${lo.toStringAsFixed(1)} above '
            'the collar line — the neck visibly disappears (owner, GIF review: '
            '"it often all but disappears")',
      );
      // Firmness v2 (owner: "heads are terribly loose"): the skull stays
      // near the collar's centerline. Bounds leave room for authored lean
      // vocabulary (zanku gbese kick trails to ~10.6) but catch the old
      // lateral-counter parking (up to ~13 off-center, 23-unit swings).
      expect(
        xHi - xLo,
        lessThan(moving ? 16 : 20),
        reason:
            '${entry.key}: the skull wanders ${(xHi - xLo).toStringAsFixed(1)} '
            'units laterally against the collar — a loose head, not a lean',
      );
      expect(
        xHi.abs() > xLo.abs() ? xHi.abs() : xLo.abs(),
        lessThan(moving ? 10 : 13),
        reason:
            '${entry.key}: the skull parks '
            '${(xHi.abs() > xLo.abs() ? xHi : xLo).toStringAsFixed(1)} '
            'off the collar centerline at its extreme',
      );
    }
  });
}
