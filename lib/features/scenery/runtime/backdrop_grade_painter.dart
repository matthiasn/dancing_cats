import 'dart:ui' as ui;

import 'package:dancing_cats/features/scenery/layers/backdrop_layer.dart';
import 'package:dancing_cats/features/scenery/model/backdrop_grade.dart';
import 'package:flutter/rendering.dart';

/// Paints [layers] into [canvas] at [size], applying [grade] as a final ASC CDL
/// pass via [gradeProgram]. The layers are composited into an offscreen image
/// which the grade shader then samples 1:1 — so the grade lands on the finished
/// painted world (like a colourist grading the final render), and near/far
/// planes stay tonally matched.
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
  List<BackdropLayer> emissiveLayers = const [],
}) {
  if (grade.isNeutral || gradeProgram == null || size.isEmpty) {
    for (final layer in layers) {
      layer.paint(canvas, ctx);
    }
    for (final layer in emissiveLayers) {
      layer.paint(canvas, ctx);
    }
    return;
  }

  final recorder = ui.PictureRecorder();
  final layerCanvas = Canvas(recorder);
  for (final layer in layers) {
    layer.paint(layerCanvas, ctx);
  }
  final picture = recorder.endRecording();
  final image = picture.toImageSync(size.width.ceil(), size.height.ceil());
  picture.dispose();

  final shader = gradeProgram.fragmentShader()
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
  canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  image.dispose();

  // Practical lights sit OUT of the CDL: painted over the graded backdrop so
  // blue-hour windows / cabin glow warm against the cooled field instead of
  // being cooled and crushed with it.
  for (final layer in emissiveLayers) {
    layer.paint(canvas, ctx);
  }
}
