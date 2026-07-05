import 'dart:math' as math;

import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/runtime/character_scene.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';
import 'package:flutter/material.dart';

/// Measured motion traces for a dance clip — the instrument that ended the
/// R14-R18 review plateau.
///
/// Static contact sheets systematically under-convey motion: review panels
/// judging shaku's 48-cell strip reported "the pelvis never dips" about
/// pixels that measurably contained a 30px weight sway and a 32px pocket
/// bounce. The fix was to put the MEASUREMENT next to the pictures: these
/// traces sample the resolved scene (the exact `frameAt` world transforms
/// the renderer draws from) and plot the quantities a groove lives in — the
/// pocket bounce, the weight sway, the head ride, and the sole heights that
/// separate a tap-step from a floor drag.
///
/// One painter serves both consumers: the in-app move inspector's TRACES
/// view, and the offline review harness (`frame_grid_test.dart`), which
/// writes `<clip>_motion_traces.png` beside the contact sheets so review
/// panels can cross-check any absence-of-motion claim before scoring.
class MotionTrace {
  const MotionTrace({
    required this.title,
    required this.values,
    this.secondary,
    this.secondaryLabel,
  });

  final String title;
  final List<double> values;

  /// Optional second series drawn in the same chart (e.g. the other foot).
  final List<double>? secondary;
  final String? secondaryLabel;

  double get range {
    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    return hi - lo;
  }
}

/// Samples the resolved world transforms of [clip] into the standard trace
/// set. World units; +y is down-screen, so DOWN on a chart = the body part
/// sinking, which is the intuitive read for pocket/ride charts.
List<MotionTrace> sampleMotionTraces(
  CharacterScene scene,
  Clip clip, {
  int samples = 96,
}) {
  final hipsY = <double>[];
  final hipsX = <double>[];
  final headY = <double>[];
  final footLY = <double>[];
  final footRY = <double>[];
  for (var i = 0; i <= samples; i++) {
    final frame = scene.frameAt(
      clip: clip,
      timeSeconds: clip.duration * i / samples,
    );
    hipsY.add(frame.world[CatBones.hips]!.ty);
    hipsX.add(frame.world[CatBones.hips]!.tx);
    headY.add(frame.world[CatBones.head]!.ty);
    footLY.add(frame.world[CatBones.footL]!.ty);
    footRY.add(frame.world[CatBones.footR]!.ty);
  }
  return [
    MotionTrace(title: 'POCKET — hips vertical (down = sink)', values: hipsY),
    MotionTrace(title: 'WEIGHT — hips lateral (sway)', values: hipsX),
    MotionTrace(title: 'HEAD RIDE — skull vertical', values: headY),
    MotionTrace(
      title: 'FEET — sole height (taps vs plants)',
      values: footLY,
      secondary: footRY,
      secondaryLabel: 'L solid · R dashed',
    ),
  ];
}

/// Counts local extrema (direction reversals) in [values] with a prominence
/// floor, so a trace's "events" can be expressed as a real-time rate.
int _reversalCount(List<double> values, double prominence) {
  var reversals = 0;
  var lastExtreme = values.first;
  var rising = true;
  for (var i = 1; i < values.length; i++) {
    if (rising && values[i] < values[i - 1]) {
      if ((values[i - 1] - lastExtreme).abs() >= prominence) {
        reversals++;
        lastExtreme = values[i - 1];
      }
      rising = false;
    } else if (!rising && values[i] > values[i - 1]) {
      if ((lastExtreme - values[i - 1]).abs() >= prominence) {
        reversals++;
        lastExtreme = values[i - 1];
      }
      rising = true;
    }
  }
  return reversals;
}

/// Paints [traces] as stacked mini-charts onto any canvas — a plain
/// function so the review harness can drive it through a raw
/// `PictureRecorder` while the app wraps it in [MotionTracePainter].
///
/// The sheet is MUSICALLY legible: [counts] gridlines are real music beats
/// (every [beatsPerBar]-th drawn heavier as a bar line), and with
/// [loopSeconds] — the loop's REAL duration at ship tempo — each chart is
/// annotated with its measured direction-reversal rate in events **per
/// real second live**, so a reviewer can judge tempo and effort
/// sustainability numerically instead of guessing motion speed from
/// stills.
void paintMotionTraces(
  Canvas canvas,
  Size size,
  List<MotionTrace> traces, {
  Color background = const Color(0xFF14161C),
  Color line = const Color(0xFF7FB4FF),
  Color secondaryLine = const Color(0xFFF2B36B),
  Color grid = const Color(0xFF2A2E3A),
  Color barGrid = const Color(0xFF4A5164),
  Color text = const Color(0xFFB9C0CF),
  Color accent = const Color(0xFFE87070),
  int counts = 16,
  int beatsPerBar = 4,
  double? loopSeconds,
}) {
  canvas.drawRect(Offset.zero & size, Paint()..color = background);
  if (traces.isEmpty) return;

  const margin = 14.0;
  const titleH = 30.0;
  const x0 = margin + 4;
  final chartH =
      (size.height - margin) / traces.length - (titleH + margin * 0.6);
  final x1 = size.width - margin;

  void label(String s, double x, double y, Color color, double fontSize,
      {FontWeight weight = FontWeight.w600}) {
    TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
          // The app ships Inter; naming it here also lets the offline
          // review harness render real glyphs after FontLoader'ing it.
          fontFamily: 'Inter',
        ),
      ),
      textDirection: TextDirection.ltr,
    )
      ..layout(maxWidth: size.width - x - margin)
      ..paint(canvas, Offset(x, y));
  }

  var top = margin;
  for (final trace in traces) {
    final all = [...trace.values, ...?trace.secondary];
    var lo = all.reduce(math.min);
    var hi = all.reduce(math.max);
    final pad = math.max(2, (hi - lo) * 0.1);
    lo -= pad;
    hi += pad;

    label(trace.title, x0, top, text, 12.5);
    final rate = loopSeconds == null || loopSeconds <= 0
        ? null
        : _reversalCount(trace.values, trace.range * 0.25) / loopSeconds;
    label(
      'range ${trace.range.toStringAsFixed(1)}'
      '${rate == null ? '' : '   ~${rate.toStringAsFixed(1)} events/s LIVE'}'
      '${trace.secondaryLabel == null ? '' : '   ${trace.secondaryLabel}'}',
      x0 + 4,
      top + 15,
      accent,
      11,
    );

    final cy0 = top + titleH;
    final rect = Rect.fromLTRB(x0, cy0, x1, cy0 + chartH);
    canvas.drawRect(
      rect,
      Paint()
        ..color = grid
        ..style = PaintingStyle.stroke,
    );
    // Beat gridlines; every bar line (each beatsPerBar-th beat) heavier.
    for (var k = 0; k < counts; k++) {
      final gx = x0 + (x1 - x0) * k / counts;
      final isBar = beatsPerBar > 0 && k % beatsPerBar == 0;
      canvas.drawLine(
        Offset(gx, cy0),
        Offset(gx, cy0 + chartH),
        Paint()
          ..color = isBar ? barGrid : grid
          ..strokeWidth = isBar ? 2 : 1,
      );
    }

    void plot(List<double> values, Color color, {bool dashed = false}) {
      final n = values.length;
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      Offset at(int i) {
        final px = x0 + (x1 - x0) * i / (n - 1);
        // Larger world y = lower on screen = lower on the chart: the sink
        // reads as a dip, unmediated.
        final py = cy0 + chartH * (values[i] - lo) / (hi - lo);
        return Offset(px, py);
      }

      if (!dashed) {
        final path = Path()..moveTo(at(0).dx, at(0).dy);
        for (var i = 1; i < n; i++) {
          path.lineTo(at(i).dx, at(i).dy);
        }
        canvas.drawPath(path, paint);
      } else {
        for (var i = 0; i < n - 1; i += 2) {
          canvas.drawLine(at(i), at(math.min(i + 1, n - 1)), paint);
        }
      }
    }

    plot(trace.values, line);
    final secondary = trace.secondary;
    if (secondary != null) plot(secondary, secondaryLine, dashed: true);

    top = cy0 + chartH + margin * 0.6;
  }
}

/// CustomPainter wrapper for the in-app inspector.
class MotionTracePainter extends CustomPainter {
  const MotionTracePainter(this.traces, {this.loopSeconds});

  final List<MotionTrace> traces;

  /// The loop's REAL duration at ship tempo (authored duration divided by
  /// the beat-warp speedup) — enables the events-per-second annotations.
  final double? loopSeconds;

  @override
  void paint(Canvas canvas, Size size) =>
      paintMotionTraces(canvas, size, traces, loopSeconds: loopSeconds);

  @override
  bool shouldRepaint(MotionTracePainter oldDelegate) =>
      !identical(oldDelegate.traces, traces) ||
      oldDelegate.loopSeconds != loopSeconds;
}
