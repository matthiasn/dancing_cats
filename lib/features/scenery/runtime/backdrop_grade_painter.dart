import 'dart:ui' as ui;

import 'package:dancing_cats/features/scenery/layers/backdrop_layer.dart';
import 'package:dancing_cats/features/scenery/layers/emissive_layer.dart';
import 'package:dancing_cats/features/scenery/model/backdrop_grade.dart';
import 'package:flutter/rendering.dart';

/// Paints [layers] into [canvas] at [size], applying [grade] as an ASC CDL pass
/// via [gradeProgram]. Consecutive normal layers are composited into an offscreen
/// image which the grade shader then samples 1:1 — so the grade lands on the
/// finished painted world (like a colourist grading the final render), and
/// near/far planes stay tonally matched.
///
/// [EmissiveLayer]s break the stack into batches: each one flushes (grades +
/// draws) the batch accumulated so far, then paints its child ungraded OVER the
/// graded result, so practical lights glow warm against the cooled field while
/// still being occluded by any nearer normal layer that follows them.
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
}) {
  if (grade.isNeutral || gradeProgram == null || size.isEmpty) {
    for (final layer in layers) {
      layer.paint(canvas, ctx);
    }
    return;
  }

  final batch = <BackdropLayer>[];

  void flush() {
    if (batch.isEmpty) return;
    final recorder = ui.PictureRecorder();
    final layerCanvas = Canvas(recorder);
    for (final layer in batch) {
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
    batch.clear();
  }

  for (final layer in layers) {
    if (layer is EmissiveLayer) {
      // Grade + draw everything up to here, then add the practical light OVER it
      // (out of the grade). A later normal layer will grade and draw over the
      // light, occluding it correctly.
      flush();
      layer.paint(canvas, ctx);
    } else {
      batch.add(layer);
    }
  }
  flush();
}
