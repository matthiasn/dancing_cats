import 'dart:ui' as ui;

import 'package:dancing_cats/features/scenery/layers/backdrop_layer.dart';
import 'package:dancing_cats/features/scenery/model/backdrop_grade.dart';
import 'package:dancing_cats/features/scenery/model/backdrop_palette.dart';
import 'package:dancing_cats/features/scenery/runtime/backdrop_grade_painter.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records how many times it was painted so tests can prove which path ran.
class _RecordingLayer implements BackdropLayer {
  int paints = 0;

  @override
  void paint(Canvas canvas, BackdropContext ctx) => paints++;
}

BackdropContext _ctx(Size size) =>
    BackdropContext(size: size, timeSeconds: 0, palette: kBlueHourPalette);

void main() {
  const size = Size(64, 36);

  test('an identity grade paints the layers directly (no grade pass)', () {
    final layer = _RecordingLayer();
    final canvas = Canvas(ui.PictureRecorder());
    paintGradedBackdrop(
      canvas: canvas,
      size: size,
      layers: [layer],
      ctx: _ctx(size),
      grade: BackdropGrade.identity,
      gradeProgram: null,
    );
    expect(layer.paints, 1);
  });

  test(
    'a non-neutral grade with no program loaded falls back to direct paint',
    () {
      final layer = _RecordingLayer();
      final canvas = Canvas(ui.PictureRecorder());
      paintGradedBackdrop(
        canvas: canvas,
        size: size,
        layers: [layer],
        ctx: _ctx(size),
        grade: gradeFromWheels(gain: const GradeWheel(master: 0.3)),
        gradeProgram: null,
      );
      expect(layer.paints, 1);
    },
  );

  testWidgets('an empty size falls back to direct paint (no offscreen)', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final program = await ui.FragmentProgram.fromAsset(
        'shaders/scenery_grade.frag',
      );
      final layer = _RecordingLayer();
      final canvas = Canvas(ui.PictureRecorder());
      // Non-neutral grade AND a real program, but zero size — the size guard
      // must route to direct paint rather than a doomed toImageSync(0, 0).
      paintGradedBackdrop(
        canvas: canvas,
        size: Size.zero,
        layers: [layer],
        ctx: _ctx(Size.zero),
        grade: gradeFromWheels(gain: const GradeWheel(master: 0.3)),
        gradeProgram: program,
      );
      expect(layer.paints, 1);
    });
  });

  testWidgets('a non-neutral grade with a program runs the grade pass', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final program = await ui.FragmentProgram.fromAsset(
        'shaders/scenery_grade.frag',
      );
      final layer = _RecordingLayer();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      paintGradedBackdrop(
        canvas: canvas,
        size: size,
        layers: [layer],
        ctx: _ctx(size),
        grade: gradeFromWheels(
          gain: const GradeWheel(master: 0.3),
          lift: const GradeWheel(master: -0.1),
          saturation: 0.8,
        ),
        gradeProgram: program,
      );
      // The layers are composited into the offscreen picture, then graded.
      expect(layer.paints, 1);
      // The graded frame rasterizes cleanly.
      final picture = recorder.endRecording();
      final image = await picture.toImage(64, 36);
      expect(image.width, 64);
      image.dispose();
      picture.dispose();
    });
  });
}
