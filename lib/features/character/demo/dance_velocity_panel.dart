import 'dart:math' as math;

import 'package:dancing_cats/features/character/demo/dance_performance.dart'
    show danceRealTempoSpeedupFor;
import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/dance_dynamics.dart';
import 'package:dancing_cats/features/character/model/dance_dynamics_warp.dart';
import 'package:dancing_cats/features/character/runtime/character_scene.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';
import 'package:flutter/material.dart';

/// The velocity DERIVATIVE of a dance move's hands — the instrument that turns
/// "the arms feel like they glide" into a number.
///
/// The MotionTrace set plots bone *positions* (pocket, sway, head ride). This
/// plots the first derivative of the hand paths — how FAST each hand travels
/// through the loop — because the "uniform / doesn't jiggle" read lives in the
/// speed curve, not the position curve. Two shape numbers name it:
///
/// - **crest** = peak ÷ mean speed. Low (~2) is a smooth even sweep; a punchy
///   accent-and-hold dance sits around 4–8 (a brief whip over a quiet hold).
/// - **floor** = the slowest tenth of the loop as a % of peak. A high floor
///   means the hand never gets near rest, so nothing reads as a set or a hit.
///
/// Sampled from the resolved scene (`frameAt`, the same world transforms the
/// renderer draws), and optionally through the shipped upper-body Effort warp
/// so the "authored" and "as-danced" curves can be compared in one chart.
class HandVelocityStats {
  const HandVelocityStats({
    required this.crest,
    required this.floorPct,
    required this.dwellPct,
    required this.peak,
    required this.mean,
  });

  /// Peak ÷ mean speed. Higher = punchier; ~2 = uniform glide.
  final double crest;

  /// 10th-percentile speed as a % of peak. Higher = never rests.
  final double floorPct;

  /// % of the loop spent gliding at 30–80% of peak (the "cruising" band).
  final double dwellPct;

  final double peak;
  final double mean;
}

/// Both hands' speed series for one move, plus the shape stats, ready to paint.
class HandVelocityProfile {
  const HandVelocityProfile({
    required this.beatsPerLoop,
    required this.beatAxis,
    required this.shippedL,
    required this.shippedR,
    required this.authoredL,
    required this.authoredR,
    required this.shipped,
    required this.authored,
    required this.dynamics,
    required this.warped,
    required this.peakScale,
  });

  final int beatsPerLoop;

  /// Beat position (0..[beatsPerLoop]) of each sample, the shared x-axis.
  final List<double> beatAxis;

  /// As-danced hand speeds (through the Effort warp), rig units/sec, ship tempo.
  final List<double> shippedL;
  final List<double> shippedR;

  /// Authored hand speeds (raw clip, no warp), same units.
  final List<double> authoredL;
  final List<double> authoredR;

  /// L+R-averaged shape stats for the as-danced and authored curves.
  final HandVelocityStats shipped;
  final HandVelocityStats authored;

  /// The move's authored Effort character.
  final DanceDynamics dynamics;

  /// Whether the Effort warp actually changed anything (false for a neutral
  /// move — then [shipped] == [authored] and only one curve is drawn).
  final bool warped;

  /// Shared vertical scale (rig units/sec) for the chart.
  final double peakScale;
}

List<double> _handSpeeds(
  CharacterScene scene,
  Clip clip,
  String boneId,
  int samples,
  double toPerSecond,
) {
  final xs = <double>[];
  final ys = <double>[];
  for (var i = 0; i < samples; i++) {
    final frame = scene.frameAt(
      clip: clip,
      timeSeconds: clip.duration * i / samples,
    );
    final t = frame.world[boneId]!;
    xs.add(t.tx);
    ys.add(t.ty);
  }
  final speeds = <double>[];
  for (var i = 0; i < samples; i++) {
    final j = (i + 1) % samples; // wrap: the loop closes on itself
    final dx = xs[j] - xs[i];
    final dy = ys[j] - ys[i];
    speeds.add(math.sqrt(dx * dx + dy * dy) * toPerSecond);
  }
  return speeds;
}

HandVelocityStats _statsOf(List<double> a, List<double> b) {
  HandVelocityStats one(List<double> v) {
    final sorted = [...v]..sort();
    final peak = sorted.last;
    final mean = v.reduce((x, y) => x + y) / v.length;
    final p10 = sorted[(v.length * 0.10).floor()];
    final dwell =
        v.where((x) => x > 0.30 * peak && x < 0.80 * peak).length / v.length;
    return HandVelocityStats(
      crest: mean <= 0 ? 0 : peak / mean,
      floorPct: peak <= 0 ? 0 : 100 * p10 / peak,
      dwellPct: 100 * dwell,
      peak: peak,
      mean: mean,
    );
  }

  final sa = one(a);
  final sb = one(b);
  return HandVelocityStats(
    crest: (sa.crest + sb.crest) / 2,
    floorPct: (sa.floorPct + sb.floorPct) / 2,
    dwellPct: (sa.dwellPct + sb.dwellPct) / 2,
    peak: math.max(sa.peak, sb.peak),
    mean: (sa.mean + sb.mean) / 2,
  );
}

/// Samples [clip]'s hand-speed profile. When the clip carries non-neutral
/// [Clip.dynamics] and loops, also samples it through the shipped upper-body
/// Effort warp so the "as-danced" curve can be compared to the authored one.
HandVelocityProfile sampleHandVelocityProfile(
  CharacterScene scene,
  Clip clip, {
  int samples = 144,
  int beatsPerLoop = kDanceBeatsPerPhraseLoop,
}) {
  // per-step world delta -> rig units per REAL second (ship tempo).
  final toPerSecond = clip.duration <= 0
      ? 0.0
      : danceRealTempoSpeedupFor(clip) * samples / clip.duration;

  final authoredL = _handSpeeds(
    scene,
    clip,
    CatBones.handL,
    samples,
    toPerSecond,
  );
  final authoredR = _handSpeeds(
    scene,
    clip,
    CatBones.handR,
    samples,
    toPerSecond,
  );

  final danced = upperBodyDynamicsWarpedClip(
    clip,
    clip.dynamics,
    warpBoneIds: kDanceUpperBodyWarpBoneIds,
  );
  final warped = !identical(danced, clip);
  final shippedL = warped
      ? _handSpeeds(scene, danced, CatBones.handL, samples, toPerSecond)
      : authoredL;
  final shippedR = warped
      ? _handSpeeds(scene, danced, CatBones.handR, samples, toPerSecond)
      : authoredR;

  final beatAxis = [
    for (var i = 0; i < samples; i++) beatsPerLoop * i / samples,
  ];
  final peakScale = <double>[
    ...shippedL,
    ...shippedR,
    ...authoredL,
    ...authoredR,
  ].reduce(math.max);

  return HandVelocityProfile(
    beatsPerLoop: beatsPerLoop,
    beatAxis: beatAxis,
    shippedL: shippedL,
    shippedR: shippedR,
    authoredL: authoredL,
    authoredR: authoredR,
    shipped: _statsOf(shippedL, shippedR),
    authored: _statsOf(authoredL, authoredR),
    dynamics: clip.dynamics,
    warped: warped,
    peakScale: peakScale <= 0 ? 1 : peakScale,
  );
}

/// Palette for [paintVelocityProfile], defaulting to the app's dark chrome +
/// the same L/R hues the MotionTrace view uses (blue = left, warm = right).
class VelocityPanelColors {
  const VelocityPanelColors();
  Color get background => const Color(0xFF14161C);
  Color get grid => const Color(0xFF2A2E3A);
  Color get barGrid => const Color(0xFF4A5164);
  Color get text => const Color(0xFFB9C0CF);
  Color get textLow => const Color(0xFF6C7480);
  Color get accent => const Color(0xFFE87070);
  Color get traceL => const Color(0xFF7FB4FF);
  Color get traceR => const Color(0xFFF2B36B);
  Color get restBand => const Color(0x14F2B36B);
}

String _weightWord(double w) =>
    w > 0.08 ? 'Strong' : (w < -0.08 ? 'Light' : 'neutral');
String _timeWord(double t) =>
    t > 0.08 ? 'Sudden' : (t < -0.08 ? 'Sustained' : 'neutral');
String _flowWord(double f) =>
    f > 0.08 ? 'Free' : (f < -0.08 ? 'Bound' : 'neutral');

/// Paints [profile] as a single hand-speed chart with a stat header — a plain
/// function (like `paintMotionTraces`) so the in-app inspector and any offline
/// harness can both drive it.
void paintVelocityProfile(
  Canvas canvas,
  Size size,
  HandVelocityProfile profile, {
  VelocityPanelColors colors = const VelocityPanelColors(),
  int beatsPerBar = 4,
}) {
  final bg = Paint()..color = colors.background;
  canvas.drawRect(Offset.zero & size, bg);
  if (profile.beatAxis.isEmpty) return;

  void text(
    String s,
    double x,
    double y,
    Color color,
    double fontSize, {
    FontWeight weight = FontWeight.w600,
    double? maxWidth,
  }) {
    TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: weight,
            fontFamily: 'Inter',
          ),
        ),
        textDirection: TextDirection.ltr,
      )
      ..layout(maxWidth: maxWidth ?? (size.width - x - 14))
      ..paint(canvas, Offset(x, y));
  }

  const margin = 16.0;
  const headerH = 70.0;
  final s = profile.shipped;

  // ---- header: crest verdict + labelled stat readout + Effort dials ----
  text(
    'HAND SPEED — velocity of each hand through the loop (rig units / real second)',
    margin,
    margin,
    colors.text,
    12.5,
  );

  // Big crest verdict. Colour by how uniform it is (low crest = uniform = warm).
  final crestColor = s.crest < 3.0
      ? colors.accent
      : (s.crest < 4.0 ? colors.traceR : colors.traceL);
  text(
    'crest ${s.crest.toStringAsFixed(2)}',
    margin,
    margin + 20,
    crestColor,
    22,
    weight: FontWeight.w700,
  );
  text(
    'peak ÷ mean speed',
    margin + 130,
    margin + 31,
    colors.textLow,
    10.5,
    weight: FontWeight.w500,
  );
  text(
    profile.warped
        ? 'as-danced — move base Effort (per-cat & section energy add live) · '
              'authored ${profile.authored.crest.toStringAsFixed(2)} · punchy ≈ 4–8'
        : 'no Effort warp on this move (neutral dynamics) · punchy ≈ 4–8',
    margin,
    margin + 48,
    colors.textLow,
    11,
  );

  // Right column: labelled stats + what they mean + the Effort dials.
  final rx = size.width - margin - 330;
  text(
    'floor ${s.floorPct.toStringAsFixed(0)}%     '
    'dwell ${s.dwellPct.toStringAsFixed(0)}%     '
    'peak ${s.peak.toStringAsFixed(0)}',
    rx,
    margin,
    colors.text,
    12,
    weight: FontWeight.w700,
  );
  text(
    'floor = slowest 10% ÷ peak · dwell = loop at 30–80% peak',
    rx,
    margin + 19,
    colors.textLow,
    9.5,
    weight: FontWeight.w500,
  );
  final d = profile.dynamics;
  text(
    'Effort   Weight ${_weightWord(d.weight)} · Time ${_timeWord(d.time)} · Flow ${_flowWord(d.flow)}',
    rx,
    margin + 40,
    colors.textLow,
    11,
  );

  // ---- chart ----
  const cy0 = margin + headerH;
  const x0 = margin + 4;
  final x1 = size.width - margin;
  final cy1 = size.height - margin;
  final rect = Rect.fromLTRB(x0, cy0, x1, cy1);

  double xAt(double beat) => x0 + (x1 - x0) * beat / profile.beatsPerLoop;
  double yAt(double v) =>
      cy1 - (math.min(v, profile.peakScale) / profile.peakScale) * (cy1 - cy0);

  // rest band: 0..15% of peak — where a hand that actually settles would dip.
  final restTop = yAt(profile.peakScale * 0.15);
  canvas.drawRect(
    Rect.fromLTRB(x0, restTop, x1, cy1),
    Paint()..color = colors.restBand,
  );
  text('rest', x1 - 34, cy1 - 16, colors.textLow, 10, weight: FontWeight.w500);

  canvas.drawRect(
    rect,
    Paint()
      ..color = colors.grid
      ..style = PaintingStyle.stroke,
  );
  // horizontal thirds
  for (final f in [0.25, 0.5, 0.75]) {
    final gy = cy0 + (cy1 - cy0) * f;
    canvas.drawLine(
      Offset(x0, gy),
      Offset(x1, gy),
      Paint()..color = colors.grid,
    );
  }
  // beat verticals; downbeats heavier
  for (var b = 0; b <= profile.beatsPerLoop; b++) {
    final isBar = beatsPerBar > 0 && b % beatsPerBar == 0;
    canvas.drawLine(
      Offset(xAt(b.toDouble()), cy0),
      Offset(xAt(b.toDouble()), cy1),
      Paint()
        ..color = isBar ? colors.barGrid : colors.grid
        ..strokeWidth = isBar ? 2 : 1,
    );
  }

  void plot(
    List<double> v,
    Color color, {
    bool faint = false,
    bool dashed = false,
  }) {
    final paint = Paint()
      ..color = faint ? color.withValues(alpha: 0.32) : color
      ..strokeWidth = faint ? 1.4 : 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    for (var i = 0; i < v.length; i++) {
      final px = xAt(profile.beatAxis[i]);
      final py = yAt(v[i]);
      i == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
    }
    if (!dashed) {
      canvas.drawPath(path, paint);
    } else {
      for (final m in path.computeMetrics()) {
        var dist = 0.0;
        while (dist < m.length) {
          final seg = m.extractPath(dist, math.min(dist + 5, m.length));
          canvas.drawPath(seg, paint);
          dist += 10;
        }
      }
    }
  }

  // authored underlay first (faint), then as-danced on top.
  if (profile.warped) {
    plot(profile.authoredL, colors.traceL, faint: true);
    plot(profile.authoredR, colors.traceR, faint: true);
  }
  plot(profile.shippedL, colors.traceL);
  plot(profile.shippedR, colors.traceR, dashed: true);

  // legend
  text('L hand', x0 + 4, cy0 + 4, colors.traceL, 10);
  text('R hand', x0 + 52, cy0 + 4, colors.traceR, 10);
  if (profile.warped) {
    text(
      '(faint = authored, before Effort warp)',
      x0 + 104,
      cy0 + 4,
      colors.textLow,
      10,
      weight: FontWeight.w500,
    );
  }
}

/// CustomPainter wrapper for the inspector's VELOCITY view.
class VelocityProfilePainter extends CustomPainter {
  const VelocityProfilePainter(this.profile);

  final HandVelocityProfile profile;

  @override
  void paint(Canvas canvas, Size size) =>
      paintVelocityProfile(canvas, size, profile);

  @override
  bool shouldRepaint(VelocityProfilePainter oldDelegate) =>
      !identical(oldDelegate.profile, profile);
}
