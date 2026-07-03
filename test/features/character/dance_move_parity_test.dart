import 'dart:io';

import 'package:dancing_cats/features/character/engine/autonomic.dart';
import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/runtime/character_scene.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dance_move_parity_support.dart';

/// Proves every shipped catalog move's `<move>DataDrivenPreview`
/// reproduction (assembled through `assembleMoveClip`,
/// `lib/features/character/model/dance_move_compiler.dart`) matches the
/// real, hand-authored move exactly — both field-level (`Clip` levers,
/// contact spans, limb-target rig bindings) and pixel-level (every sampled
/// frame across the cycle). None of these preview getters are part of
/// `CatClips.all` — nothing is wired into the stage.
void main() {
  final moves = <String, ({Clip before, Clip after})>{
    'buga': (before: CatClips.buga, after: CatClips.bugaDataDrivenPreview),
    'shaku': (before: CatClips.shaku, after: CatClips.shakuDataDrivenPreview),
    'zanku': (before: CatClips.zanku, after: CatClips.zankuDataDrivenPreview),
    'azonto': (
      before: CatClips.azonto,
      after: CatClips.azontoDataDrivenPreview,
    ),
    'pouncingCat': (
      before: CatClips.pouncingCat,
      after: CatClips.pouncingCatDataDrivenPreview,
    ),
    'sekem': (before: CatClips.sekem, after: CatClips.sekemDataDrivenPreview),
  };

  for (final entry in moves.entries) {
    final name = entry.key;
    final before = entry.value.before;
    final after = entry.value.after;

    group(name, () {
      test('field-level parity', () {
        checkFieldParity(name, before, after);
      });

      test('not part of the move catalog', () {
        // Both clips share the real move's name (required for
        // CharacterScene._isDanceFamily's runtime parity — see each
        // preview getter's doc comment), so catalog membership can't be
        // told apart by name. Assert the catalog still has exactly the
        // one real entry: if the preview getter were ever added to
        // CatClips.all, this count would become 2.
        expect(CatClips.all.where((c) => c.name == name), hasLength(1));
      });

      test('pixel parity across every sampled frame', () async {
        final scene = CharacterScene(
          buildCatInSuitRig(),
          autonomic: AutonomicLayer(seed: 11),
        );
        await checkPixelParity(name, scene, before, after);
      });

      test('writes before/after grid PNGs for manual review', () async {
        final scene = CharacterScene(
          buildCatInSuitRig(),
          autonomic: AutonomicLayer(seed: 11),
        );
        final outputDir = Directory(
          Platform.environment['CHARACTER_STRIP_DIR'] ??
              'build/character_film_strips',
        )..createSync(recursive: true);
        const frames = 24;
        final beforeGrid = await renderGrid(scene, before, frames);
        final afterGrid = await renderGrid(scene, after, frames);
        File(
          '${outputDir.path}/${name}_before_grid.png',
        ).writeAsBytesSync(beforeGrid);
        File(
          '${outputDir.path}/${name}_after_grid.png',
        ).writeAsBytesSync(afterGrid);
      });
    });
  }
}
