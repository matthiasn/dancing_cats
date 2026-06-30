import 'dart:math' as math;
import 'dart:ui';

import 'package:dancing_cats/features/scenery/model/scenery_assets.dart';

/// Cover-fit (`BoxFit.cover`) [content] into [viewport]: the max-scale, centered
/// rect. Returns [Rect.zero] when either size is empty (an undecoded image or a
/// zero viewport) so callers can no-op safely. Single-sourced here so the layers
/// and the backdrop can't drift apart on the framing math.
Rect coverRect(Size content, Size viewport) {
  if (content.isEmpty || viewport.isEmpty) return Rect.zero;
  final scale = math.max(
    viewport.width / content.width,
    viewport.height / content.height,
  );
  final w = content.width * scale;
  final h = content.height * scale;
  return Rect.fromLTWH(
    (viewport.width - w) / 2,
    (viewport.height - h) / 2,
    w,
    h,
  );
}

/// The rect the fixed [kSceneryCanvasSize] master plate occupies when cover-fit
/// into [viewport] — the mapping normalized art anchors use: `cover.project(x, y)`.
Rect coverFit(Size viewport) => coverRect(kSceneryCanvasSize, viewport);

/// Maps normalized art anchors onto a cover-fit rect.
extension RectProject on Rect {
  /// The screen point for a normalized anchor (`x`, `y` in 0..1) in this rect's
  /// space — i.e. `topLeft + (x, y) * size`.
  Offset project(double x, double y) =>
      Offset(left + x * width, top + y * height);
}
