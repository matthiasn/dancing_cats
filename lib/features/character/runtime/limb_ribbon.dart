import 'dart:math' as math;
import 'dart:ui';

import 'package:meta/meta.dart';

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

  // The two offset edges, de-spiked so a spine hairpin can't mitre the
  // silhouette into a batwing (see [_ribbonEdges]).
  final (:front, :back) = _ribbonEdges(samples);

  final first = samples.first;
  final last = samples.last;
  final firstFront = front.first;
  final firstBack = back.first;
  final lastFront = front.last;
  final lastBack = back.last;

  path.moveTo(firstBack.dx, firstBack.dy);
  if (roundCaps) {
    // Start cap: semicircle from the back edge over the start to the front
    // edge (so the forward front-edge walk continues).
    final capCentre = (firstFront + firstBack) / 2;
    final capRadius = (first.halfWidth + first.backHalfWidth) / 2;
    final startAngle = math.atan2(-first.normal.dy, -first.normal.dx);
    path.arcTo(
      Rect.fromCircle(center: capCentre, radius: capRadius),
      startAngle,
      -math.pi, // bulge over the BACK of the limb (opposite the tangent)
      false,
    );
  } else {
    path.lineTo(firstFront.dx, firstFront.dy);
  }

  // Forward along the FRONT edge.
  for (var i = 1; i < front.length; i++) {
    path.lineTo(front[i].dx, front[i].dy);
  }

  if (roundCaps) {
    // End cap: semicircle from the front edge over the tip to the back edge.
    final capCentre = (lastFront + lastBack) / 2;
    final capRadius = (last.halfWidth + last.backHalfWidth) / 2;
    final endAngle = math.atan2(last.normal.dy, last.normal.dx);
    path.arcTo(
      Rect.fromCircle(center: capCentre, radius: capRadius),
      endAngle,
      -math.pi,
      false,
    );
  } else {
    path.lineTo(lastBack.dx, lastBack.dy);
  }

  // Back along the BACK edge.
  for (var i = back.length - 2; i >= 0; i--) {
    path.lineTo(back[i].dx, back[i].dy);
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

/// The most an outer-edge vertex may bulge past the straight chord between
/// its neighbours, as a fraction of that sample's authored half-width. A
/// smooth curve's vertices sit almost exactly on their neighbours' chord
/// (sagitta << width), so this never touches ordinary bends; only a spine
/// HAIRPIN — a >~90-degree reversal where the outer offset mitres into a
/// spike — produces a deviation this large. Measured across the catalogue: an
/// arm's anti-hinge shoulder-socket reversal throws its outer vertex ~0.6–0.76x
/// half-width past the chord; 0.18 pulls that pointed flap back to a rounded
/// shoulder while leaving every legitimate elbow/knee crease (whose outer side
/// is a gentle convex curve, deviation < a few % of width) untouched — tuned by
/// render, like the inner clamp's constants.
///
/// Public + [visibleForTesting] so the silhouette-integrity regression can
/// assert the invariant against this exact bound rather than a copied number.
@visibleForTesting
const double kOuterSpikeMaxChordDeviation = 0.18;

/// Builds a ribbon's two offset edges from its sampled centreline and runs the
/// silhouette-spike constraint on both. Shared by [limbRibbonPath] (which walks
/// these into the fill) and [limbRibbonMaxOuterSpike] (which measures the
/// residual spike a regression test gates on), so the rendered silhouette and
/// the tested invariant can never drift apart.
///
/// Where the spine hairpins (a >~90-degree reversal, e.g. the anti-hinge
/// shoulder socket or a near-degenerate elbow fold), the OUTER offset point
/// juts past its neighbours into a "batwing" flap. The inner side is already
/// protected by [_clampInnerEdgeToCurvature]; [_limitOuterSpikes] bounds the
/// outer side symmetrically, so the sleeve can never spike regardless of pose.
({List<Offset> front, List<Offset> back}) _ribbonEdges(List<_Sample> samples) {
  final front = [for (final s in samples) s.centre + s.normal * s.halfWidth];
  final back = [for (final s in samples) s.centre - s.normal * s.backHalfWidth];
  _limitOuterSpikes(front, samples, (s) => s.halfWidth);
  _limitOuterSpikes(back, samples, (s) => s.backHalfWidth);
  return (front: front, back: back);
}

/// Signed OUTWARD distance of edge vertex [i] past the straight chord between
/// its neighbours, measured along the outward direction (sample centre → edge
/// point). Positive = the vertex bulges out past where a smooth edge would sit
/// — the batwing-spike metric. Endpoints (no chord) and degenerate cases
/// return 0. Shared by the clamp ([_limitOuterSpikes]) and the diagnostic
/// ([limbRibbonMaxOuterSpike]) so both read the spike the same way.
double _outwardChordDeviation(List<Offset> edge, int i, Offset centre) {
  if (i <= 0 || i >= edge.length - 1) return 0;
  final here = edge[i];
  final outward = here - centre;
  final outLen = outward.distance;
  if (outLen < 1e-6) return 0;
  final outUnit = outward / outLen;
  final chord = edge[i + 1] - edge[i - 1];
  final chordLen = chord.distance;
  final Offset onChord;
  if (chordLen < 1e-6) {
    onChord = edge[i - 1];
  } else {
    final u = chord / chordLen;
    final proj =
        (here - edge[i - 1]).dx * u.dx + (here - edge[i - 1]).dy * u.dy;
    onChord = edge[i - 1] + u * proj;
  }
  return (here.dx - onChord.dx) * outUnit.dx +
      (here.dy - onChord.dy) * outUnit.dy;
}

/// Bounds each outer-edge vertex's OUTWARD bulge past the chord of its
/// neighbours (see [kOuterSpikeMaxChordDeviation]). The mirror of
/// [_clampInnerEdgeToCurvature]: that one stops the INNER edge crossing
/// itself on a tight fold; this stops the OUTER edge spiking into a
/// "batwing" at the same fold. Purely subtractive — a vertex is only ever
/// pulled IN toward the centreline, never pushed out — so it can add no new
/// material and cannot deform a pose, only remove a rendering spike. Three
/// passes, since pulling one vertex in shifts its neighbours' chords; measured
/// across the whole catalogue, three iterations settle the worst residual from
/// ~0.25 (one relaxation short) down onto the ~0.18 target.
void _limitOuterSpikes(
  List<Offset> edge,
  List<_Sample> samples,
  double Function(_Sample) sideWidth,
) {
  for (var pass = 0; pass < 3; pass++) {
    for (var i = 1; i < edge.length - 1; i++) {
      final centre = samples[i].centre;
      final deviation = _outwardChordDeviation(edge, i, centre);
      final limit = sideWidth(samples[i]) * kOuterSpikeMaxChordDeviation;
      if (deviation <= limit) continue;
      final outward = edge[i] - centre;
      final outLen = outward.distance;
      if (outLen < 1e-6) continue;
      edge[i] = edge[i] - (outward / outLen) * (deviation - limit);
    }
  }
}

/// The worst OUTWARD silhouette spike [limbRibbonPath] produces for [spine]:
/// the largest amount any edge vertex bulges past its neighbours' chord, as a
/// fraction of that vertex's half-width, AFTER the spike constraint has run.
/// Takes the same inputs [limbRibbonPath] takes and reuses its exact edge
/// construction ([_ribbonEdges]), so this measures precisely what gets drawn.
///
/// The constraint holds this at or (within its three-pass convergence) barely
/// above [kOuterSpikeMaxChordDeviation]; a value well past that means the
/// batwing is back. Exposed so the silhouette-integrity regression can assert
/// the invariant across every catalogue pose without reproducing the private
/// centreline sampling.
@visibleForTesting
double limbRibbonMaxOuterSpike(
  List<Offset> spine,
  List<double> halfWidths, {
  List<double>? backHalfWidths,
  List<double>? jointTensions,
  int samplesPerSegment = 10,
}) {
  if (spine.length < 2) return 0;
  final samples = _sampleCentreline(
    spine,
    halfWidths,
    backHalfWidths ?? halfWidths,
    samplesPerSegment,
    jointTensions: jointTensions,
  );
  final (:front, :back) = _ribbonEdges(samples);
  var worst = 0.0;
  for (var i = 1; i < samples.length - 1; i++) {
    final centre = samples[i].centre;
    final w = samples[i].halfWidth;
    if (w > 1e-6) {
      worst = math.max(worst, _outwardChordDeviation(front, i, centre) / w);
    }
    final bw = samples[i].backHalfWidth;
    if (bw > 1e-6) {
      worst = math.max(worst, _outwardChordDeviation(back, i, centre) / bw);
    }
  }
  return worst;
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
