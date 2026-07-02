import 'dart:ui' as ui;

import 'package:dancing_cats/features/scenery/layers/backdrop_layer.dart';
import 'package:dancing_cats/features/scenery/layers/graded_layer.dart';
import 'package:dancing_cats/features/scenery/model/backdrop_grade.dart';
import 'package:dancing_cats/features/scenery/model/backdrop_palette.dart';
import 'package:dancing_cats/features/scenery/runtime/scenery_shaders.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records paints (and the canvas painted into) so tests can prove which path
/// ran: the direct path hands the child the caller's canvas, the grade pass
/// hands it an offscreen recorder's canvas.
class _RecordingLayer implements BackdropLayer {
  int paints = 0;
  Canvas? lastCanvas;

  @override
  void paint(Canvas canvas, BackdropContext ctx) {
    paints++;
    lastCanvas = canvas;
  }
}

const _size = Size(64, 36);

BackdropContext _ctx({
  BackdropGrade? Function(String target)? gradeForTarget,
  ui.FragmentProgram? layerGradeProgram,
  Size size = _size,
}) => BackdropContext(
  size: size,
  timeSeconds: 0,
  palette: kBlueHourPalette,
  gradeForTarget: gradeForTarget,
  layerGradeProgram: layerGradeProgram,
);

BackdropGrade _grade() => gradeFromWheels(
  gain: const GradeWheel(master: 0.3),
  saturation: 0.7,
);

void main() {
  test('paints the child directly when nothing supplies grades', () {
    final child = _RecordingLayer();
    GradedLayer(
      child,
      target: 'deck-glow',
    ).paint(Canvas(ui.PictureRecorder()), _ctx());
    expect(child.paints, 1);
  });

  test('paints directly when the supplied grade is null or neutral', () {
    final child = _RecordingLayer();
    GradedLayer(child, target: 'haze')
      ..paint(Canvas(ui.PictureRecorder()), _ctx(gradeForTarget: (_) => null))
      ..paint(
        Canvas(ui.PictureRecorder()),
        _ctx(gradeForTarget: (_) => BackdropGrade.identity),
      );
    expect(child.paints, 2);
  });

  test('paints directly when the layer shader has not loaded', () {
    final child = _RecordingLayer();
    GradedLayer(
      child,
      target: 'haze',
    ).paint(
      Canvas(ui.PictureRecorder()),
      _ctx(gradeForTarget: (_) => _grade()),
    );
    expect(child.paints, 1);
  });

  testWidgets('paints directly at an empty size', (tester) async {
    await tester.runAsync(() async {
      final program = await ui.FragmentProgram.fromAsset(
        SceneryShaderAssets.gradeLayer,
      );
      final child = _RecordingLayer();
      GradedLayer(child, target: 'haze').paint(
        Canvas(ui.PictureRecorder()),
        _ctx(
          gradeForTarget: (_) => _grade(),
          layerGradeProgram: program,
          size: Size.zero,
        ),
      );
      expect(child.paints, 1);
    });
  });

  testWidgets('runs the offscreen grade pass for its own target', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final program = await ui.FragmentProgram.fromAsset(
        SceneryShaderAssets.gradeLayer,
      );
      final child = _RecordingLayer();
      final layer = GradedLayer(child, target: 'clouds-far');
      final asked = <String>[];
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      layer.paint(
        canvas,
        _ctx(
          gradeForTarget: (t) {
            asked.add(t);
            return _grade();
          },
          layerGradeProgram: program,
        ),
      );
      // The child was composited once (into the offscreen — NOT the caller's
      // canvas) and the pass asked for exactly this layer's target id.
      expect(child.paints, 1);
      expect(identical(child.lastCanvas, canvas), isFalse);
      expect(asked, ['clouds-far']);
      final picture = recorder.endRecording();
      final image = await picture.toImage(64, 36);
      expect(image.width, 64);
      image.dispose();
      picture.dispose();
    });
  });

  test('an additive target drops the Offset term but keeps the rest', () {
    final layer = GradedLayer(
      _RecordingLayer(),
      target: 'deck-glow',
      additive: true,
    );
    final graded = layer.effectiveGrade(
      gradeFromWheels(
        lift: const GradeWheel(master: 0.5), // → non-zero offset
        gain: const GradeWheel(master: 0.3),
        saturation: 0.6,
        contrast: 1.2,
      ),
    )!;
    expect(graded.offset, (r: 0.0, g: 0.0, b: 0.0));
    expect(graded.slope.r, greaterThan(1)); // gain survives
    expect(graded.saturation, 0.6);
    expect(graded.contrast, 1.2);
  });

  test('a non-additive target passes the grade through untouched', () {
    final layer = GradedLayer(_RecordingLayer(), target: 'haze');
    final grade = gradeFromWheels(lift: const GradeWheel(master: 0.5));
    expect(layer.effectiveGrade(grade), same(grade));
  });

  testWidgets('an offset-only grade on an additive target skips the pass', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // Stripping Offset leaves the identity — even with the shader loaded,
      // the pass must be skipped entirely (a lift ride on a light pass is a
      // deliberate no-op) and the child painted DIRECTLY.
      final program = await ui.FragmentProgram.fromAsset(
        SceneryShaderAssets.gradeLayer,
      );
      final child = _RecordingLayer();
      final canvas = Canvas(ui.PictureRecorder());
      GradedLayer(child, target: 'police', additive: true).paint(
        canvas,
        _ctx(
          gradeForTarget: (_) =>
              gradeFromWheels(lift: const GradeWheel(master: 0.5)),
          layerGradeProgram: program,
        ),
      );
      expect(child.paints, 1);
      expect(identical(child.lastCanvas, canvas), isTrue);
    });
  });
}
