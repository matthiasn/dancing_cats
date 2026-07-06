import 'package:dancing_cats/features/scenery/layers/backdrop_layer.dart';
import 'package:dancing_cats/features/scenery/model/backdrop_grade.dart';
import 'package:dancing_cats/features/scenery/runtime/backdrop_grade_painter.dart';
import 'package:flutter/rendering.dart';

/// A grade-target decorator (ADR 0002 §3): wraps one [child] layer under a
/// stable [target] id. When the injected [BackdropContext.gradeForTarget]
/// supplies a non-neutral grade for that id (and the premultiplied layer
/// shader is loaded), the child is composited to its own offscreen and drawn
/// back through the ASC CDL pass; otherwise it paints exactly as unwrapped.
/// This is the `per-layer` node of the grade graph — it runs before the
/// backdrop-composite pass by construction (it happens inside the stack).
///
/// [additive] marks light passes (city lights, deck glow, strobes, drones,
/// ocean shimmer) whose blend treats black as "no contribution": a non-zero
/// CDL Offset would lift their black into a full-frame wash, so additive
/// targets ignore Offset (slope/power/saturation still apply — the controls
/// that make sense on a light pass).
class GradedLayer implements BackdropLayer {
  const GradedLayer(this.child, {required this.target, this.additive = false});

  /// The wrapped layer.
  final BackdropLayer child;

  /// Stable grade-target id (what a grade-timeline lane's `target` names).
  final String target;

  /// Whether the child is an additive light pass (Offset is ignored).
  final bool additive;

  /// The grade to actually run for this layer given the injected [grade]:
  /// additive targets drop the Offset term (ADR 0002 §3 blend policy).
  BackdropGrade? effectiveGrade(BackdropGrade? grade) {
    if (grade == null || !additive) return grade;
    return BackdropGrade(
      slope: grade.slope,
      power: grade.power,
      saturation: grade.saturation,
      contrast: grade.contrast,
      pivot: grade.pivot,
    );
  }

  @override
  void paint(Canvas canvas, BackdropContext ctx) {
    final grade = effectiveGrade(ctx.gradeForTarget?.call(target));
    final program = ctx.layerGradeProgram;
    if (grade == null ||
        grade.isNeutral ||
        program == null ||
        ctx.size.isEmpty ||
        !ctx.allowGradeSnapshots) {
      child.paint(canvas, ctx);
      return;
    }
    runGradePass(
      canvas: canvas,
      size: ctx.size,
      grade: grade,
      program: program,
      allowSnapshot: ctx.allowGradeSnapshots,
      paintContent: (layerCanvas) => child.paint(layerCanvas, ctx),
    );
  }
}
