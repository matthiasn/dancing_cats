import 'dart:math' as math;
import 'dart:ui';

/// Builds a smooth, tapered **ribbon** that flows through a bone chain's joint
/// positions — the core of mesh-style limb deformation. Where the rigid renderer
/// draws a thigh and a shin as two separate capsules that hinge at a sharp knee
/// (the "cardboard cutout" tell), a ribbon is ONE continuous shape whose
/// centreline is a Catmull-Rom curve through `[hip, knee, ankle]` and whose
/// half-width tapers along it. It bends at the joints instead of folding.
///
/// All points are in the SAME space they will be drawn in (the renderer feeds it
/// canvas-space joint positions from the solved world transforms), so the ribbon
/// is drawn with no per-bone canvas transform.
///
/// [spine] are the joint centres (≥2). [halfWidths] is the half-thickness at
/// each joint on the +normal side (same length as [spine]); the normal is the
/// centreline tangent rotated a quarter turn, so for a limb authored top-down
/// it points toward the character's facing side. [backHalfWidths], when given,
/// sets the -normal side independently — an ASYMMETRIC muscle profile (a quad
/// bulging on the front of the thigh, a calf on the back of the shin) instead
/// of a symmetric tube. Omitted, the ribbon is symmetric about the centreline.
/// [samplesPerSegment] controls smoothness. [roundCaps] keeps anatomical limb
/// tips soft; tailored surfaces such as suit sleeves can disable it for flatter
/// fabric ends at shoulder and cuff.
Path limbRibbonPath(
  List<Offset> spine,
  List<double> halfWidths, {
  List<double>? backHalfWidths,
  int samplesPerSegment = 10,
  bool roundCaps = true,
}) {
  assert(spine.length == halfWidths.length, 'spine/halfWidths length mismatch');
  assert(
    backHalfWidths == null || backHalfWidths.length == spine.length,
    'spine/backHalfWidths length mismatch',
  );
  if (spine.length < 2) return Path();

  final samples = _sampleCentreline(
    spine,
    halfWidths,
    backHalfWidths ?? halfWidths,
    samplesPerSegment,
  );

  // Front (+normal) and back (-normal) edges, offset along the centreline
  // normal by that side's local half-width. Anatomical limbs get round caps
  // (semicircles); tailored sleeves can use flat caps so the ends read like
  // fabric breaks rather than sausages. With an asymmetric profile the cap is
  // centred between the two edge points and spans their average radius, which
  // degenerates to the historic circle when the sides match.
  final path = Path();
  final first = samples.first;
  final last = samples.last;

  Offset frontEdge(_Sample s) =>
      s.centre + s.normal * s.halfWidth;
  Offset backEdge(_Sample s) =>
      s.centre - s.normal * s.backHalfWidth;

  path.moveTo(backEdge(first).dx, backEdge(first).dy);
  if (roundCaps) {
    // Start cap: semicircle from the back edge over the start to the front
    // edge (so the forward front-edge walk continues).
    final capCentre = (frontEdge(first) + backEdge(first)) / 2;
    final capRadius = (first.halfWidth + first.backHalfWidth) / 2;
    final startAngle = math.atan2(-first.normal.dy, -first.normal.dx);
    path.arcTo(
      Rect.fromCircle(center: capCentre, radius: capRadius),
      startAngle,
      -math.pi, // bulge over the BACK of the limb (opposite the tangent)
      false,
    );
  } else {
    path.lineTo(frontEdge(first).dx, frontEdge(first).dy);
  }

  // Forward along the FRONT edge.
  for (var i = 1; i < samples.length; i++) {
    final p = frontEdge(samples[i]);
    path.lineTo(p.dx, p.dy);
  }

  if (roundCaps) {
    // End cap: semicircle from the front edge over the tip to the back edge.
    final capCentre = (frontEdge(last) + backEdge(last)) / 2;
    final capRadius = (last.halfWidth + last.backHalfWidth) / 2;
    final endAngle = math.atan2(last.normal.dy, last.normal.dx);
    path.arcTo(
      Rect.fromCircle(center: capCentre, radius: capRadius),
      endAngle,
      -math.pi,
      false,
    );
  } else {
    path.lineTo(backEdge(last).dx, backEdge(last).dy);
  }

  // Back along the BACK edge.
  for (var i = samples.length - 2; i >= 0; i--) {
    final p = backEdge(samples[i]);
    path.lineTo(p.dx, p.dy);
  }

  path.close();
  return path;
}


/// The hand-drawn INK LINE for a ribbon that overlaps its own body: an OPEN
/// path tracing the limb's edges from [startFraction] of the centreline down
/// to and around the tip — deliberately NOT closed over the root, so the
/// shoulder/hip end of the limb merges into the garment it grows from
/// instead of being enclosed in its own outline like a pinned-on cut-out.
/// Stroke this (round caps) over the ribbon fill; the line fades in exactly
/// where a drawn sleeve's line would leave the armhole.
Path limbRibbonInkPath(
  List<Offset> spine,
  List<double> halfWidths, {
  List<double>? backHalfWidths,
  int samplesPerSegment = 10,
  double startFraction = 0,
}) {
  assert(spine.length == halfWidths.length, 'spine/halfWidths length mismatch');
  if (spine.length < 2) return Path();

  final samples = _sampleCentreline(
    spine,
    halfWidths,
    backHalfWidths ?? halfWidths,
    samplesPerSegment,
  );
  final start = (samples.length * startFraction)
      .round()
      .clamp(0, samples.length - 2);

  Offset frontEdge(_Sample s) => s.centre + s.normal * s.halfWidth;
  Offset backEdge(_Sample s) => s.centre - s.normal * s.backHalfWidth;

  final path = Path()
    ..moveTo(frontEdge(samples[start]).dx, frontEdge(samples[start]).dy);
  for (var i = start + 1; i < samples.length; i++) {
    final p = frontEdge(samples[i]);
    path.lineTo(p.dx, p.dy);
  }
  final last = samples.last;
  final capCentre = (frontEdge(last) + backEdge(last)) / 2;
  final capRadius = (last.halfWidth + last.backHalfWidth) / 2;
  final endAngle = math.atan2(last.normal.dy, last.normal.dx);
  path.arcTo(
    Rect.fromCircle(center: capCentre, radius: capRadius),
    endAngle,
    -math.pi,
    false,
  );
  for (var i = samples.length - 2; i >= start; i--) {
    final p = backEdge(samples[i]);
    path.lineTo(p.dx, p.dy);
  }
  return path;
}

class _Sample {
  _Sample(this.centre, this.normal, this.halfWidth, this.backHalfWidth);
  final Offset centre;
  final Offset normal; // unit, perpendicular to the tangent (points "left")
  final double halfWidth;
  final double backHalfWidth;
}

/// Resamples [spine] into a Catmull-Rom curve, carrying the per-sample tangent
/// normal and the interpolated half-widths for both sides.
List<_Sample> _sampleCentreline(
  List<Offset> spine,
  List<double> halfWidths,
  List<double> backHalfWidths,
  int samplesPerSegment,
) {
  final out = <_Sample>[];
  final n = spine.length;
  for (var i = 0; i < n - 1; i++) {
    // Catmull-Rom control points (clamp at the ends).
    final p0 = spine[i == 0 ? 0 : i - 1];
    final p1 = spine[i];
    final p2 = spine[i + 1];
    final p3 = spine[i + 2 >= n ? n - 1 : i + 2];
    final w1 = halfWidths[i];
    final w2 = halfWidths[i + 1];
    final b1 = backHalfWidths[i];
    final b2 = backHalfWidths[i + 1];
    final last = i == n - 2;
    final steps = last ? samplesPerSegment : samplesPerSegment - 1;
    for (var s = 0; s <= steps; s++) {
      final t = s / samplesPerSegment;
      final pt = _catmullRom(p0, p1, p2, p3, t);
      final tan = _catmullRomTangent(p0, p1, p2, p3, t);
      final len = tan.distance;
      final normal = len < 1e-6
          ? Offset.zero
          : Offset(-tan.dy / len, tan.dx / len);
      out.add(
        _Sample(pt, normal, w1 + (w2 - w1) * t, b1 + (b2 - b1) * t),
      );
    }
  }
  return out;
}

Offset _catmullRom(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
  final t2 = t * t;
  final t3 = t2 * t;
  double c(double a, double b, double cc, double d) =>
      0.5 *
      ((2 * b) +
          (-a + cc) * t +
          (2 * a - 5 * b + 4 * cc - d) * t2 +
          (-a + 3 * b - 3 * cc + d) * t3);
  return Offset(
    c(p0.dx, p1.dx, p2.dx, p3.dx),
    c(p0.dy, p1.dy, p2.dy, p3.dy),
  );
}

Offset _catmullRomTangent(
  Offset p0,
  Offset p1,
  Offset p2,
  Offset p3,
  double t,
) {
  final t2 = t * t;
  double c(double a, double b, double cc, double d) =>
      0.5 *
      ((-a + cc) +
          2 * (2 * a - 5 * b + 4 * cc - d) * t +
          3 * (-a + 3 * b - 3 * cc + d) * t2);
  return Offset(
    c(p0.dx, p1.dx, p2.dx, p3.dx),
    c(p0.dy, p1.dy, p2.dy, p3.dy),
  );
}
