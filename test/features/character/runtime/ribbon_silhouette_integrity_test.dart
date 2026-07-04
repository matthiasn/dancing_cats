import 'package:dancing_cats/features/character/model/affine2d.dart';
import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/face.dart';
import 'package:dancing_cats/features/character/model/rig_spec.dart';
import 'package:dancing_cats/features/character/runtime/character_scene.dart';
import 'package:dancing_cats/features/character/runtime/limb_ribbon.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Silhouette-integrity regression: no arm/leg ribbon may ever spike into a
/// pointed "batwing" flap, in any catalogue pose.
///
/// The batwing was a pointed silhouette spike on shaku's sleeve — but probing
/// showed it was NOT shaku-specific, nor caused by the (since-removed)
/// girdleLeverGain: it is intrinsic to the anti-hinge geometry. Driven
/// unconstrained through the scene, every arm ribbon hairpins somewhere in its
/// loop and mitres its outer edge out to 0.60–0.76x its half-width past the
/// chord (a leg to ~0.37x). limbRibbonPath's outer-spike constraint bounds that;
/// this test proves it holds across the whole catalogue, driven through the SAME
/// pipeline the renderer uses, so the spike cannot silently reappear from a
/// future keyframe edit.
///
/// See also limb_ribbon_test.dart's `outer-spike silhouette constraint` group,
/// which pins the same invariant on the single worst captured spine as a fast,
/// scene-free unit check.
void main() {
  // Constrained residual across the catalogue measures ~0.22 worst (the
  // three-pass relaxation settles onto the ~0.18 target); an unconstrained
  // batwing measures 0.60–0.76 on arms (~0.37 on the worst leg). 0.32 sits in
  // that gap — above any legitimate rounded shoulder, below any spike. Kept in
  // sync with limb_ribbon_test.dart.
  const spikeCeiling = 0.32;

  // Replicates CharacterRenderer._ribbonPath's spine construction: each joint
  // bone's solved world origin. Kept identical so the tested silhouette is the
  // drawn one.
  List<Offset>? ribbonSpine(
    LimbRibbonSpec ribbon,
    Map<String, Affine2D> world,
  ) {
    final spine = <Offset>[];
    for (final boneId in ribbon.jointBoneIds) {
      final t = world[boneId];
      if (t == null) return null;
      spine.add(Offset(t.origin.x, t.origin.y));
    }
    return spine;
  }

  test('no catalogue arm/leg ribbon spikes into a batwing', () {
    final rig = buildCatInSuitRig();
    final scene = CharacterScene(rig);
    // Every catalogue dance move plus the loop's rest/idle, at a dense sub-beat
    // sampling so a spike that lives between beats can't slip through.
    final clips = <Clip>[
      CatClips.shaku,
      CatClips.zanku,
      CatClips.azonto,
      CatClips.sekem,
      CatClips.buga,
      CatClips.pouncingCat,
    ];
    const framesPerClip = 96;
    final base = Affine2D.translation(120, 200);

    var worst = 0.0;
    var worstWhere = '';
    for (final clip in clips) {
      for (var i = 0; i < framesPerClip; i++) {
        final frame = scene.frameAt(
          clip: clip,
          timeSeconds: clip.duration * i / framesPerClip,
          expression: Expression.content,
          base: base,
        );
        for (final ribbon in rig.ribbons) {
          final spine = ribbonSpine(ribbon, frame.world);
          if (spine == null || spine.length < 2) continue;
          final spike = limbRibbonMaxOuterSpike(
            spine,
            ribbon.halfWidths,
            backHalfWidths: ribbon.backHalfWidths,
            jointTensions: ribbon.jointTensions,
            samplesPerSegment: ribbon.samplesPerSegment,
          );
          if (spike > worst) {
            worst = spike;
            worstWhere = '${clip.name} ${ribbon.id} frame $i/$framesPerClip';
          }
        }
      }
    }

    expect(
      worst,
      lessThan(spikeCeiling),
      reason:
          'ribbon silhouette spiked to ${worst.toStringAsFixed(3)}x half-width '
          'at $worstWhere — the batwing constraint is not holding',
    );
  });
}
