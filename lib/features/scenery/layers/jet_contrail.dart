import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dancing_cats/features/scenery/runtime/scenery_math.dart';

/// One sampled point on a contrail: its stage-space [position] and the
/// [ageSeconds] since the engine emitted it (drives the width / fade ramps).
class TrailPoint {
  const TrailPoint(this.position, this.ageSeconds);

  final ui.Offset position;
  final double ageSeconds;
}

/// Meshes the contrail [points] polyline into a tapered, age-faded filled ribbon
/// and paints it with [shader] — the most involved geometry in the scenery, kept
/// separate from the aircraft placement so it can be read and tested alone.
///
/// Each point's half-width ramps in over [formationFadeSeconds] after
/// [formationGapSeconds], matures over ~5 s, and scales from [widthStartFactor]
/// to [widthEndFactor] across the trail's age up to [maxAge], peaking at
/// [maxWidth]. The ribbon is built by extruding a perpendicular at each point
/// and closing the left edge against the reversed right edge.
void paintTrailRibbon(
  ui.Canvas canvas,
  List<TrailPoint> points, {
  required double formationGapSeconds,
  required double formationFadeSeconds,
  required double maxAge,
  required double maxWidth,
  required double widthStartFactor,
  required double widthEndFactor,
  required ui.Shader shader,
}) {
  final left = <ui.Offset>[];
  final right = <ui.Offset>[];
  for (var i = 0; i < points.length; i++) {
    final point = points[i];
    final tangent =
        points[math.min(i + 1, points.length - 1)].position -
        points[math.max(i - 1, 0)].position;
    final length = tangent.distance;
    if (length == 0) continue;

    final normal = ui.Offset(-tangent.dy / length, tangent.dx / length);
    final fadeIn = smoothstep(
      (point.ageSeconds - formationGapSeconds) / formationFadeSeconds,
    );
    final mature = smoothstep(
      (point.ageSeconds - formationGapSeconds) / 5,
    );
    final age01 =
        ((point.ageSeconds - formationGapSeconds) /
                math.max(0.001, maxAge - formationGapSeconds))
            .clamp(0.0, 1.0);
    final ageWidth = ui.lerpDouble(
      widthStartFactor,
      widthEndFactor,
      smoothstep(age01),
    )!;
    final halfWidth = maxWidth * fadeIn * (0.82 + 0.18 * mature) * ageWidth / 2;
    left.add(point.position + normal * halfWidth);
    right.add(point.position - normal * halfWidth);
  }
  if (left.length < 2 || right.length < 2) return;

  final path = ui.Path()..moveTo(left.first.dx, left.first.dy);
  for (final p in left.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  for (final p in right.reversed) {
    path.lineTo(p.dx, p.dy);
  }
  path.close();

  canvas.drawPath(
    path,
    ui.Paint()
      ..isAntiAlias = true
      ..style = ui.PaintingStyle.fill
      ..shader = shader,
  );
}
