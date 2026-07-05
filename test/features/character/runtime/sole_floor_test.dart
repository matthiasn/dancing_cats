import 'package:dancing_cats/features/character/model/affine2d.dart';
import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/runtime/character_scene.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';
import 'package:flutter_test/flutter_test.dart';

/// The support sole is the floor: a free foot may never render BELOW the
/// planted shoe.
///
/// Regression gate for the R27 mocap blocker ("floor penetration is the one
/// thing a mocap eye rejects outright"): foot IK targets are authored in the
/// anchor bone's space, so the deep pocket sinks carried free-foot taps down
/// with the body — probe-measured up to ~10 units below the planted sole at
/// shaku's seam. The runtime now clamps free-foot targets to the support
/// sole's height (`_solveLimbTarget`'s sole floor); this test holds the line
/// across every dance clip that declares contact spans.
void main() {
  test('a free foot never sinks below the planted support sole', () {
    final scene = CharacterScene(buildCatInSuitRig());
    // The ratchet list: clips that have opted into Clip.enforceSoleFloor.
    // Each routine joins during its own re-author + panel round (the clamp
    // visibly changes tuned foot mechanics — zanku's floor scrape, for
    // one — so it is never enabled silently).
    final clips = {
      'shaku': CatClips.shaku,
      'zanku': CatClips.zanku,
      'azonto': CatClips.azonto,
      'sekem': CatClips.sekem,
      // buga stays OUT: it is a BOTH-feet-planted move through its wide
      // descents — the clamp's single-support model treats the other
      // planted foot as "free" and hoists it 10-15 units off its plant
      // (probe-verified at f15). Joining needs double-support awareness
      // in the clamp, not a key re-author.
    };
    const samples = 256;
    // The bones compare like-for-like (same rig geometry both sides), so
    // bone-origin heights are directly comparable. Tolerance covers sole
    // roll/flex during the tap itself, not penetration (which measured ~10
    // units before the clamp).
    const tolerance = 3.0;
    for (final entry in clips.entries) {
      final clip = entry.value;
      if (clip.contactSpans.isEmpty) continue;
      expect(clip.enforceSoleFloor, isTrue,
          reason: '${entry.key} is in the ratchet list but not opted in');
      for (var i = 0; i < samples; i++) {
        final phase = i / samples;
        final span = _activeSpan(clip, phase);
        if (span == null) continue;
        // Skip the lock fade-in/out edges where the support itself is
        // mid-handoff and neither foot is unambiguously "the floor".
        final spanLength = span.end - span.start;
        final edge = (spanLength * 0.15).clamp(0.02, 0.05);
        if (phase < span.start + edge || phase > span.end - edge) continue;
        final frame = scene.frameAt(
          clip: clip,
          timeSeconds: clip.duration * phase,
        );
        final freeBone = span.bone == CatBones.footL
            ? CatBones.footR
            : CatBones.footL;
        // Compare SOLE contact points (drawable bottom-centre, the same
        // point the runtime's contact plumbing uses), not bone origins —
        // a toe-flicked free foot pitches its origin low without its sole
        // being anywhere near the floor.
        final supportY = _solePoint(scene, frame.world[span.bone], span.bone);
        final freeY = _solePoint(scene, frame.world[freeBone], freeBone);
        expect(
          freeY,
          lessThan(supportY + tolerance),
          reason:
              '${entry.key} phase ${phase.toStringAsFixed(3)} '
              '(frame ${(phase * 32).toStringAsFixed(1)}): the free foot '
              '($freeBone) renders ${(freeY - supportY).toStringAsFixed(1)} '
              'below the planted ${span.bone} — floor penetration',
        );
      }
    }
  });
}

double _solePoint(CharacterScene scene, Affine2D? transform, String boneId) {
  final drawable = scene.rig.bone(boneId)!.drawable!;
  return transform!.transformPoint(drawable.dx, drawable.dy + drawable.height / 2).y;
}

GroundSpan? _activeSpan(Clip clip, double phase) {
  for (final span in clip.contactSpans) {
    if (phase >= span.start && phase <= span.end) return span;
  }
  return null;
}
