import 'package:dancing_cats/features/scenery/layers/backdrop_layer.dart';
import 'package:dancing_cats/features/scenery/model/backdrop_grade.dart';
import 'package:flutter/rendering.dart';

/// Marks its [child] to be graded with its OWN [grade] instead of the scene's
/// global colour grade.
///
/// The grade painter flushes the current global-graded batch when it reaches a
/// [GradedLayer], then grades this child on its own. So one element can hold a
/// different look than the field around it — e.g. a warm dark-wood deck sitting
/// in front of a cool, desaturated blue-hour sky and a near-silhouette city —
/// which a single global grade can't express. Stack order (and therefore
/// occlusion) is preserved: a nearer normal layer that follows still draws over
/// this one.
class GradedLayer implements BackdropLayer {
  const GradedLayer(this.child, {required this.grade});

  final BackdropLayer child;
  final BackdropGrade grade;

  @override
  void paint(Canvas canvas, BackdropContext ctx) => child.paint(canvas, ctx);
}
