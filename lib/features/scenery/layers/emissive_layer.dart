import 'package:dancing_cats/features/scenery/layers/backdrop_layer.dart';
import 'package:flutter/rendering.dart';

/// Marks its [child] as a practical light held OUT of the colour grade.
///
/// The grade painter walks the backdrop stack in order, batching consecutive
/// normal layers into one grade pass; when it reaches an [EmissiveLayer] it
/// flushes (grades + draws) the batch so far, then paints this child ungraded
/// (typically an additive `ImageLayer`) OVER it. So a lit window / cabin / lantern
/// glows warm against the cooled blue-hour field instead of being cooled and
/// crushed with it — yet any nearer normal layer that follows in the stack (e.g.
/// the yacht in front of the city) still grades and draws OVER the light, so it
/// is correctly occluded rather than bleeding through.
class EmissiveLayer implements BackdropLayer {
  const EmissiveLayer(this.child);

  final BackdropLayer child;

  @override
  void paint(Canvas canvas, BackdropContext ctx) => child.paint(canvas, ctx);
}
