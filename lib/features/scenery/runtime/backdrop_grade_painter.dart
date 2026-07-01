import 'dart:ui' as ui;

import 'package:dancing_cats/features/scenery/layers/backdrop_layer.dart';
import 'package:dancing_cats/features/scenery/layers/emissive_layer.dart';
import 'package:dancing_cats/features/scenery/layers/graded_layer.dart';
import 'package:dancing_cats/features/scenery/model/backdrop_grade.dart';
import 'package:flutter/rendering.dart';

/// Paints [layers] into [canvas] at [size], applying [grade] as an ASC CDL pass
/// via [gradeProgram]. Consecutive normal layers are composited into an offscreen
/// image which the grade shader then samples 1:1 — so the grade lands on the
/// finished painted world (like a colourist grading the final render), and
/// near/far planes stay tonally matched.
///
/// Two markers break the stack into batches, in stack order (so occlusion is
/// preserved — a nearer normal layer that follows still draws over them):
///  * [EmissiveLayer] — its child is painted ungraded (a warm practical light).
///  * [GradedLayer] — its child is graded with its OWN grade instead of [grade],
///    so one element (e.g. a warm dark-wood deck) can hold a different look than
///    the cool field around it.
///
/// Falls back to a plain direct paint (no offscreen, no shader) whenever the
/// program hasn't loaded or the size is empty. Shared by the live
/// `LayeredBackdrop` painter and the offline composer so export matches live.
void paintGradedBackdrop({
  required Canvas canvas,
  required Size size,
  required List<BackdropLayer> layers,
  required BackdropContext ctx,
  required BackdropGrade grade,
  required ui.FragmentProgram? gradeProgram,
}) {
  if (gradeProgram == null || size.isEmpty) {
    for (final layer in layers) {
      layer.paint(canvas, ctx);
    }
    return;
  }

  // Grade [group] with [g] and draw it into [canvas]. A neutral grade skips the
  // offscreen + shader and paints straight through.
  void gradeAndDraw(List<BackdropLayer> group, BackdropGrade g) {
    if (group.isEmpty) return;
    if (g.isNeutral) {
      for (final layer in group) {
        layer.paint(canvas, ctx);
      }
      return;
    }
    final recorder = ui.PictureRecorder();
    final groupCanvas = Canvas(recorder);
    for (final layer in group) {
      layer.paint(groupCanvas, ctx);
    }
    final picture = recorder.endRecording();
    final image = picture.toImageSync(size.width.ceil(), size.height.ceil());
    picture.dispose();

    final shader = gradeProgram.fragmentShader()
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, g.slope.r)
      ..setFloat(3, g.slope.g)
      ..setFloat(4, g.slope.b)
      ..setFloat(5, g.offset.r)
      ..setFloat(6, g.offset.g)
      ..setFloat(7, g.offset.b)
      ..setFloat(8, g.power.r)
      ..setFloat(9, g.power.g)
      ..setFloat(10, g.power.b)
      ..setFloat(11, g.saturation)
      ..setFloat(12, g.contrast)
      ..setFloat(13, g.pivot)
      ..setImageSampler(0, image);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
    image.dispose();
  }

  final batch = <BackdropLayer>[];
  for (final layer in layers) {
    if (layer is EmissiveLayer) {
      // Flush the global-graded batch, then add the practical light OVER it.
      gradeAndDraw(batch, grade);
      batch.clear();
      layer.paint(canvas, ctx);
    } else if (layer is GradedLayer) {
      // Flush the global-graded batch, then grade this element on its OWN curve.
      // (A neutral per-layer grade paints it raw, so an A/B bypass is just every
      // layer set to identity.)
      gradeAndDraw(batch, grade);
      batch.clear();
      gradeAndDraw([layer.child], layer.grade);
    } else {
      batch.add(layer);
    }
  }
  gradeAndDraw(batch, grade);
}
