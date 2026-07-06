import 'dart:io';
import 'dart:ui' as ui;

import 'package:dancing_cats/features/character/demo/dance_velocity_panel.dart';
import 'package:dancing_cats/features/character/runtime/character_scene.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the in-app VELOCITY panel for every catalogue move into one PNG so
/// the hand-speed diagnostic can be eyeballed offline the way the trace sheets
/// are. Also a smoke test that the profile computes for each move.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final outputDir = Directory('build/character_film_strips');

  setUpAll(() async {
    outputDir.createSync(recursive: true);
    await (FontLoader('Inter')..addFont(
          rootBundle.load('assets/fonts/Inter/Inter-VariableFont_opsz,wght.ttf'),
        ))
        .load();
  });

  test('render velocity panels for the catalogue', () async {
    final scene = CharacterScene(buildCatInSuitRig());
    final moves = <String, dynamic>{
      'shaku': CatClips.shaku,
      'zanku': CatClips.zanku,
      'azonto': CatClips.azonto,
      'sekem': CatClips.sekem,
      'buga': CatClips.buga,
      'pouncingCat': CatClips.pouncingCat,
    };

    const w = 980.0;
    const h = 270.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    var row = 0;
    for (final entry in moves.entries) {
      final profile = sampleHandVelocityProfile(scene, entry.value);
      expect(profile.shipped.crest, greaterThan(0));
      canvas.save();
      canvas.translate(0, row * h);
      paintVelocityProfile(canvas, const Size(w, h), profile);
      // move-name watermark, centred faintly in the chart so it never
      // collides with the header readout (this sheet only — the app shows
      // the move name in the dialog header).
      TextPainter(
          text: TextSpan(
            text: entry.key.toUpperCase(),
            style: const TextStyle(
              color: Color(0x22FFFFFF),
              fontSize: 46,
              fontWeight: FontWeight.w800,
              fontFamily: 'Inter',
              letterSpacing: 4,
            ),
          ),
          textDirection: TextDirection.ltr,
        )
        ..layout()
        ..paint(canvas, Offset(w / 2 - 130, h * 0.5));
      canvas.restore();
      // ignore: avoid_print
      print('${entry.key.padRight(12)} crest ${profile.shipped.crest.toStringAsFixed(2)}'
          ' (authored ${profile.authored.crest.toStringAsFixed(2)})'
          '  floor ${profile.shipped.floorPct.toStringAsFixed(0)}%'
          '  dwell ${profile.shipped.dwellPct.toStringAsFixed(0)}%');
      row++;
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(w.toInt(), (h * moves.length).toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${outputDir.path}/velocity_panels.png');
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('wrote ${file.path}');
  });
}
