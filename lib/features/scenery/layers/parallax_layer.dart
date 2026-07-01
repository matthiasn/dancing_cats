import 'package:dancing_cats/features/scenery/layers/backdrop_layer.dart';
import 'package:flutter/rendering.dart';

/// A depth-assigning decorator: wraps one background [child] layer and paints it
/// under the scene camera's parallax scaled to [depth] — `0` locks the plane at
/// infinity (no drift), `1` moves it fully with the foreground/dancers. Stacking
/// layers at increasing depth (far sky → near deck) makes them drift and grow
/// against one another when the camera dollies, so the scene reads as real
/// depth instead of one flat plate.
///
/// The camera → matrix mapping is INJECTED via [BackdropContext.parallaxForDepth]
/// by whatever drives the camera (the dance stage / the offline video composer),
/// so this stays agnostic to the dance camera and the two paths lag every plane
/// identically. With no camera injected the child paints untransformed (flat),
/// so procedural scenes, other consumers and unit tests are unaffected.
class ParallaxLayer implements BackdropLayer {
  const ParallaxLayer(this.child, {required this.depth});

  /// The layer drawn under this plane's parallax.
  final BackdropLayer child;

  /// Depth 0 (locked at infinity) … 1 (moves with the dancers).
  final double depth;

  @override
  void paint(Canvas canvas, BackdropContext ctx) {
    final matrix = ctx.parallaxForDepth?.call(depth, ctx.size);
    if (matrix == null) {
      // No camera drives the scene: paint flat, exactly as an unwrapped layer.
      child.paint(canvas, ctx);
      return;
    }
    canvas
      ..save()
      ..transform(matrix.storage);
    child.paint(canvas, ctx);
    canvas.restore();
  }
}
