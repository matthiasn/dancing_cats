import 'dart:typed_data';
import 'dart:ui';

import 'package:dancing_cats/features/scenery/layers/backdrop_layer.dart';
import 'package:dancing_cats/features/scenery/layers/parallax_layer.dart';
import 'package:dancing_cats/features/scenery/model/backdrop_palette.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the canvas transform in force (and the call count) each time painted,
/// so a test can prove what the [ParallaxLayer] wrapped its child in.
class _CapturingLayer implements BackdropLayer {
  int calls = 0;
  Float64List? transform;

  @override
  void paint(Canvas canvas, BackdropContext ctx) {
    calls++;
    transform = canvas.getTransform();
  }
}

BackdropContext _ctx({
  Matrix4 Function(double depth, Size size)? parallaxForDepth,
}) => BackdropContext(
  size: const Size(200, 100),
  timeSeconds: 0,
  palette: kBlueHourPalette,
  parallaxForDepth: parallaxForDepth,
);

void main() {
  group('ParallaxLayer', () {
    test('paints the child flat when no camera is injected', () {
      final child = _CapturingLayer();
      final canvas = Canvas(PictureRecorder());

      ParallaxLayer(child, depth: 0.5).paint(canvas, _ctx());

      expect(child.calls, 1);
      // No wrap: the child paints under the bare (identity) canvas transform.
      expect(child.transform, Matrix4.identity().storage);
    });

    test('paints the child under the injected depth transform', () {
      final child = _CapturingLayer();
      final canvas = Canvas(PictureRecorder());
      // A pure translation by (11, 22), column-major (tx, ty in the last column).
      final matrix = Matrix4(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 11, 22, 0, 1);

      double? seenDepth;
      Size? seenSize;
      ParallaxLayer(child, depth: 0.42).paint(
        canvas,
        _ctx(
          parallaxForDepth: (depth, size) {
            seenDepth = depth;
            seenSize = size;
            return matrix;
          },
        ),
      );

      // The plane's own depth and the paint size are forwarded to the mapping...
      expect(seenDepth, 0.42);
      expect(seenSize, const Size(200, 100));
      // ...and the child paints under exactly that transform.
      expect(child.calls, 1);
      expect(child.transform, matrix.storage);
    });

    test('restores the canvas so later siblings are not left transformed', () {
      final child = _CapturingLayer();
      final sibling = _CapturingLayer();
      final canvas = Canvas(PictureRecorder());
      final matrix = Matrix4(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 33, 0, 0, 1);

      ParallaxLayer(child, depth: 0.3).paint(
        canvas,
        _ctx(parallaxForDepth: (_, _) => matrix),
      );
      // A plain sibling painted afterwards sees the bare canvas again.
      sibling.paint(canvas, _ctx());

      expect(child.transform, matrix.storage);
      expect(sibling.transform, Matrix4.identity().storage);
    });
  });
}
