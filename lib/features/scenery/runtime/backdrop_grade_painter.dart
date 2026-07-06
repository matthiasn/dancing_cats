import 'dart:ui' as ui;

import 'package:dancing_cats/features/scenery/layers/backdrop_layer.dart';
import 'package:dancing_cats/features/scenery/model/backdrop_grade.dart';
import 'package:flutter/rendering.dart';

/// Wires [grade]'s coefficients + the sampled [image] into a fragment shader
/// built from [program]. Both grade shaders (the opaque whole-composite
/// `scenery_grade.frag` and the premultiplied per-layer
/// `scenery_grade_layer.frag`) share this exact uniform order.
ui.FragmentShader gradeShaderFor({
  required ui.FragmentProgram program,
  required BackdropGrade grade,
  required Size size,
  required ui.Image image,
}) => program.fragmentShader()
  ..setFloat(0, size.width)
  ..setFloat(1, size.height)
  ..setFloat(2, grade.slope.r)
  ..setFloat(3, grade.slope.g)
  ..setFloat(4, grade.slope.b)
  ..setFloat(5, grade.offset.r)
  ..setFloat(6, grade.offset.g)
  ..setFloat(7, grade.offset.b)
  ..setFloat(8, grade.power.r)
  ..setFloat(9, grade.power.g)
  ..setFloat(10, grade.power.b)
  ..setFloat(11, grade.saturation)
  ..setFloat(12, grade.contrast)
  ..setFloat(13, grade.pivot)
  ..setImageSampler(0, image);

/// Composites whatever [paintContent] draws into an offscreen image and draws
/// it back through [grade] via [program] — the one grade-pass primitive every
/// node in the ADR 0002 grade graph uses (per-layer, backdrop composite, and
/// the widget-level cast/master filters go through the same maths in their
/// render object).
void runGradePass({
  required Canvas canvas,
  required Size size,
  required BackdropGrade grade,
  required ui.FragmentProgram program,
  required void Function(Canvas canvas) paintContent,
  bool allowSnapshot = true,
}) {
  if (!allowSnapshot) {
    paintContent(canvas);
    return;
  }

  final recorder = ui.PictureRecorder();
  paintContent(Canvas(recorder));
  final picture = recorder.endRecording();
  final image = picture.toImageSync(size.width.ceil(), size.height.ceil());
  picture.dispose();

  final shader = gradeShaderFor(
    program: program,
    grade: grade,
    size: size,
    image: image,
  );
  canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  image.dispose();
}

/// Paints [layers] into [canvas] at [size], applying [grade] as a final ASC CDL
/// pass via [gradeProgram]. The layers are composited into an offscreen image
/// which the grade shader then samples 1:1 — so the grade lands on the finished
/// painted world (like a colourist grading the final render), and near/far
/// planes stay tonally matched. In the ADR 0002 node order this is the
/// `backdrop` node: it runs AFTER any per-layer passes (which happen inside
/// the layers' own paint) and BEFORE the cast/master widget filters.
///
/// Falls back to a plain direct paint (no offscreen, no shader) whenever the
/// grade is neutral, the program hasn't loaded, or the size is empty — so the
/// common ungraded case keeps the cheaper path. Shared by the live
/// `LayeredBackdrop` painter and the offline composer so export matches live.
void paintGradedBackdrop({
  required Canvas canvas,
  required Size size,
  required List<BackdropLayer> layers,
  required BackdropContext ctx,
  required BackdropGrade grade,
  required ui.FragmentProgram? gradeProgram,
  bool allowSnapshot = true,
}) {
  if (grade.isNeutral || gradeProgram == null || size.isEmpty) {
    for (final layer in layers) {
      layer.paint(canvas, ctx);
    }
    return;
  }

  runGradePass(
    canvas: canvas,
    size: size,
    grade: grade,
    program: gradeProgram,
    allowSnapshot: allowSnapshot,
    paintContent: (layerCanvas) {
      for (final layer in layers) {
        layer.paint(layerCanvas, ctx);
      }
    },
  );
}
