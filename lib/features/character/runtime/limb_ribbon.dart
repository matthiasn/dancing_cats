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
  List<double>? jointTensions,
  int samplesPerSegment = 10,
  bool roundCaps = true,
}) {
  assert(spine.length == halfWidths.length, 'spine/halfWidths length mismatch');
  assert(
    backHalfWidths == null || backHalfWidths.length == spine.length,
    'spine/backHalfWidths length mismatch',
  );
  assert(
    jointTensions == null || jointTensions.length == spine.length,
    'spine/jointTensions length mismatch',
  );
  if (spine.length < 2) return Path();

  final samples = _sampleCentreline(
    spine,
    halfWidths,
    backHalfWidths ?? halfWidths,
    samplesPerSegment,
    jointTensions: jointTensions,
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

  Offset frontEdge(_Sample s) => s.centre + s.normal * s.halfWidth;
  Offset backEdge(_Sample s) => s.centre - s.normal * s.backHalfWidth;

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
  List<double>? jointTensions,
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
    jointTensions: jointTensions,
  );
  final start = (samples.length * startFraction).round().clamp(
    0,
    samples.length - 2,
  );

  Offset frontEdge(_Sample s) => s.centre + s.normal * s.halfWidth;
  Offset backEdge(_Sample s) => s.centre - s.normal * s.backHalfWidth;

  // Inside a tight fold the clamped edge collapses into the crease; a drawn
  // sleeve would never carry its outline down INTO the crease (it reads as a
  // floating angular scratch inside the cloth mass), so the ink lifts over
  // strongly-creased samples and resumes past them.
  final path = Path();
  var penDown = false;
  void walk(Offset p, {required bool crease}) {
    if (crease) {
      penDown = false;
      return;
    }
    if (penDown) {
      path.lineTo(p.dx, p.dy);
    } else {
      path.moveTo(p.dx, p.dy);
      penDown = true;
    }
  }

  for (var i = start; i < samples.length; i++) {
    walk(frontEdge(samples[i]), crease: samples[i].creaseFront);
  }
  final last = samples.last;
  final capCentre = (frontEdge(last) + backEdge(last)) / 2;
  final capRadius = (last.halfWidth + last.backHalfWidth) / 2;
  final endAngle = math.atan2(last.normal.dy, last.normal.dx);
  if (penDown) {
    path.arcTo(
      Rect.fromCircle(center: capCentre, radius: capRadius),
      endAngle,
      -math.pi,
      false,
    );
  }
  for (var i = samples.length - 2; i >= start; i--) {
    walk(backEdge(samples[i]), crease: samples[i].creaseBack);
  }
  return path;
}

class _Sample {
  _Sample(this.centre, this.normal, this.halfWidth, this.backHalfWidth);
  final Offset centre;
  final Offset normal; // unit, perpendicular to the tangent (points "left")
  double halfWidth;
  double backHalfWidth;

  /// Set where the curvature clamp cut this side deep into a fold — the
  /// sample sits inside a crease, so ink must not trace it.
  bool creaseFront = false;
  bool creaseBack = false;
}

/// How hard the centreline hugs the joint polyline. 0 = classic Catmull-Rom
/// (bends smear along the whole limb — the "boneless noodle" read on a bent
/// elbow); 1 = the raw polyline (a cardboard hinge). 0.45 keeps organic
/// chains (the tail, the shoulder cap) soft; a flat 0.68 defined the elbow
/// but scalloped the shoulder into lobes, so limbs now pass a per-joint
/// tension profile instead: soft where the limb roots into the garment,
/// firm from the mid-limb joint out so flexion resolves at a visible
/// elbow/knee vertex.
const double _kCentrelineTension = 0.45;

/// Resamples [spine] into a tensioned Catmull-Rom curve, carrying the
/// per-sample tangent normal and the interpolated half-widths for both
/// sides. On tight folds the inner-edge offset is clamped to the local
/// radius of curvature so the ribbon pinches to a crease instead of
/// crossing itself into a wire.
List<_Sample> _sampleCentreline(
  List<Offset> spine,
  List<double> halfWidths,
  List<double> backHalfWidths,
  int samplesPerSegment, {
  List<double>? jointTensions,
}) {
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
    // A segment's tension is the mean of its endpoint joints', so a profile
    // like [soft shoulder ... firm elbow ... firm wrist] transitions without
    // a visible kink at the joint where the values change.
    final tension = jointTensions == null
        ? _kCentrelineTension
        : (jointTensions[i] + jointTensions[i + 1]) / 2;
    final last = i == n - 2;
    final steps = last ? samplesPerSegment : samplesPerSegment - 1;
    for (var s = 0; s <= steps; s++) {
      final t = s / samplesPerSegment;
      final pt = _catmullRom(p0, p1, p2, p3, t, tension);
      final tan = _catmullRomTangent(p0, p1, p2, p3, t, tension);
      final len = tan.distance;
      final normal = len < 1e-6
          ? Offset.zero
          : Offset(-tan.dy / len, tan.dx / len);
      out.add(
        _Sample(pt, normal, w1 + (w2 - w1) * t, b1 + (b2 - b1) * t),
      );
    }
  }
  _clampInnerEdgeToCurvature(out);
  return out;
}

/// Below this fraction of a side's AUTHORED half-width, the curvature clamp
/// stops shrinking further. Without a floor, a sharp-enough bend (shaku's
/// held-X elbow measured collapsing to ~3% of its authored width) pinches
/// the fold to a near-zero sliver — geometrically anti-self-intersection-
/// correct, but too thin to read as a bend at render scale ("flat, nearly-
/// straight paddle arm" despite a real ~39deg elbow angle). 0.28 trades a
/// small, usually-imperceptible amount of self-overlap on the tightest
/// folds for a crease that stays visually legible.
const double _kCreaseLegibilityFloor = 0.28;

/// Below this fraction of authored half-width, the fold is severe enough
/// that a drawn ink line would trace a floating scratch inside the cloth
/// mass rather than a real seam, so the ink lifts. Set safely below
/// [_kCreaseLegibilityFloor] so a sample that hit the floor (the common
/// case on any real elbow/knee bend) still gets its defining line — the
/// floor fixed the FILL geometry being too thin to read; without also
/// relaxing this threshold, the line that would actually sell the crease
/// stayed suppressed at the old, much stricter 0.7 cutoff regardless.
const double _kCreaseInkSuppressionThreshold = 0.2;

/// Prevents self-intersection on tight folds: where the centreline's radius
/// of curvature drops below a side's half-width, offsetting the full width
/// on the INSIDE of the bend folds the edge back across itself (the
/// crossed-wrist X read as a wire). Clamp that side's offset to ~90% of the
/// local radius (floored — see [_kCreaseLegibilityFloor] — so the clamp
/// itself doesn't erase the fold it's supposed to render); the outer side
/// is untouched, so the fold keeps its mass and gains a crease.
void _clampInnerEdgeToCurvature(List<_Sample> samples) {
  for (var i = 1; i < samples.length - 1; i++) {
    final prev = samples[i - 1];
    final here = samples[i];
    final next = samples[i + 1];
    // Signed turn between adjacent sample directions; + turns toward the
    // +normal side, so the -normal (back) side is the inside of that bend.
    final inDir = here.centre - prev.centre;
    final outDir = next.centre - here.centre;
    final inLen = inDir.distance;
    final outLen = outDir.distance;
    if (inLen < 1e-6 || outLen < 1e-6) continue;
    final cross =
        (inDir.dx * outDir.dy - inDir.dy * outDir.dx) / (inLen * outLen);
    final dot =
        (inDir.dx * outDir.dx + inDir.dy * outDir.dy) / (inLen * outLen);
    final turn = math.atan2(cross, dot);
    if (turn.abs() < 1e-4) continue;
    final radius = ((inLen + outLen) / 2) / turn.abs();
    final maxInnerOffset = radius * 0.9;
    if (turn > 0) {
      // Curving toward +normal: the +normal (front) side is the inside.
      if (here.halfWidth > maxInnerOffset) {
        final clamped = math.max(
          maxInnerOffset,
          here.halfWidth * _kCreaseLegibilityFloor,
        );
        // A cut below the ink-suppression threshold means this sample sits
        // deep inside a fold even after the legibility floor — flag it so
        // the ink line lifts over the crease.
        here
          ..creaseFront =
              clamped < here.halfWidth * _kCreaseInkSuppressionThreshold
          ..halfWidth = clamped;
      }
    } else {
      if (here.backHalfWidth > maxInnerOffset) {
        final clamped = math.max(
          maxInnerOffset,
          here.backHalfWidth * _kCreaseLegibilityFloor,
        );
        here
          ..creaseBack =
              clamped < here.backHalfWidth * _kCreaseInkSuppressionThreshold
          ..backHalfWidth = clamped;
      }
    }
  }
}

// Hermite form of Catmull-Rom with tension: tangents m1/m2 are the classic
// half-chord tangents scaled by (1 - tension), so tension 0 reproduces the
// historic spline exactly and tension 1 degenerates to the joint polyline.
Offset _catmullRom(
  Offset p0,
  Offset p1,
  Offset p2,
  Offset p3,
  double t,
  double tension,
) {
  final t2 = t * t;
  final t3 = t2 * t;
  final scale = (1 - tension) * 0.5;
  final h00 = 2 * t3 - 3 * t2 + 1;
  final h10 = t3 - 2 * t2 + t;
  final h01 = -2 * t3 + 3 * t2;
  final h11 = t3 - t2;
  double c(double a, double b, double cc, double d) =>
      h00 * b + h10 * scale * (cc - a) + h01 * cc + h11 * scale * (d - b);
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
  double tension,
) {
  final t2 = t * t;
  final scale = (1 - tension) * 0.5;
  final h00 = 6 * t2 - 6 * t;
  final h10 = 3 * t2 - 4 * t + 1;
  final h01 = -6 * t2 + 6 * t;
  final h11 = 3 * t2 - 2 * t;
  double c(double a, double b, double cc, double d) =>
      h00 * b + h10 * scale * (cc - a) + h01 * cc + h11 * scale * (d - b);
  return Offset(
    c(p0.dx, p1.dx, p2.dx, p3.dx),
    c(p0.dy, p1.dy, p2.dy, p3.dy),
  );
}
