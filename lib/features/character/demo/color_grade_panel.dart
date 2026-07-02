import 'dart:math' as math;

import 'package:dancing_cats/features/scenery/model/backdrop_grade.dart';
import 'package:dancing_cats/features/scenery/model/scope_histogram.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Which ASC CDL coefficient a wheel drives, so each wheel can show its true
/// Slope / Offset / Power numbers (a colourist has to be able to read, type and
/// match a grade — pucks alone can't be reproduced).
enum GradeRole { lift, gamma, gain }

/// The dance demo's colour-grading console — a new row below the transport
/// waveform. Three ASC-CDL 3-way wheels (Lift / Gamma / Gain), each a balance
/// puck, a bipolar luminance dial and a live Slope/Offset/Power readout; a
/// white-balance Temperature/Tint pair; Contrast and Saturation; a before/after
/// Bypass; and per-wheel plus global reset. Purely presentational: it renders the
/// supplied state and reports intent through callbacks; the page owns the state
/// and builds the [BackdropGrade] (see `gradeFromWheels`). A dev tool for
/// dialling the blue-hour look, not a product surface.
class ColorGradePanel extends StatelessWidget {
  const ColorGradePanel({
    required this.lift,
    required this.gamma,
    required this.gain,
    required this.saturation,
    required this.temperature,
    required this.tint,
    required this.contrast,
    required this.pivot,
    required this.bypass,
    required this.parade,
    required this.onLift,
    required this.onGamma,
    required this.onGain,
    required this.onSaturation,
    required this.onTemperature,
    required this.onTint,
    required this.onContrast,
    required this.onPivot,
    required this.onBypass,
    required this.onReset,
    this.onEditEnd,
    this.wheelDiameter = 90,
    this.title = 'COLOR',
    this.subtitle = 'grade',
    this.additiveTarget = false,
    this.showScopes = true,
    super.key,
  });

  final GradeWheel lift;
  final GradeWheel gamma;
  final GradeWheel gain;
  final double saturation;
  final double temperature;
  final double tint;
  final double contrast;

  /// The tonal pivot the contrast rotates about (mid grey ≈ 0.435).
  final double pivot;
  final bool bypass;

  /// Image-derived RGB parade of the graded stage (empty before first sample).
  final ScopeHistogram parade;
  final ValueChanged<GradeWheel> onLift;
  final ValueChanged<GradeWheel> onGamma;
  final ValueChanged<GradeWheel> onGain;
  final ValueChanged<double> onSaturation;
  final ValueChanged<double> onTemperature;
  final ValueChanged<double> onTint;
  final ValueChanged<double> onContrast;
  final ValueChanged<double> onPivot;
  final ValueChanged<bool> onBypass;
  final VoidCallback onReset;

  /// Fired when an edit gesture releases (wheel ride, slider scrub, tap) —
  /// the grade workspace closes its undo transaction / stamps auto-keys here.
  final VoidCallback? onEditEnd;

  /// Wheel size: 90 in the compact console era, ~116 in the workspace where
  /// there is room to actually grab a puck.
  final double wheelDiameter;

  /// Header label — the workspace shows the selected lane's name here so the
  /// console always says WHAT it is editing.
  final String title;

  /// Header sub-line — the workspace shows the playhead's key state here
  /// ('key @ 00:42.400 · linear' vs 'between keys'), so the on-key state is
  /// readable at the parameter surface, not only up in the lane.
  final String subtitle;

  /// True when the selected lane grades an additive light pass: its CDL
  /// Offset is ignored by design (a lift would wash the frame), so the Lift
  /// wheel dims and stops accepting input instead of masquerading as live.
  final bool additiveTarget;

  /// False when the scopes are mirrored elsewhere (the workspace docks
  /// full-size scopes into the stage's pillarbox) — the console row then
  /// drops its small copies instead of duplicating them.
  final bool showScopes;

  static const _panelTop = Color(0xFF17181C);
  static const _panelBottom = Color(0xFF101114);
  static const _edge = Color(0xFF2A313A);
  static const _textHi = Color(0xFFE7ECF2);
  static const _textLow = Color(0xFF8A94A2);
  static const _accent = Color(0xFF2FB6A8);
  static const _warm = Color(0xFFE6A24A);
  static const _cool = Color(0xFF4A8FE6);

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: 'Inter'),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_panelTop, _panelBottom],
          ),
          border: Border(top: BorderSide(color: _edge)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PanelHeader(
                title: title,
                subtitle: subtitle,
                bypass: bypass,
                onBypass: onBypass,
                onReset: onReset,
              ),
              const SizedBox(width: 22),
              GradeWheelControl(
                role: GradeRole.lift,
                label: 'Lift',
                sublabel: additiveTarget ? 'offset ignored' : 'shadows',
                wheel: lift,
                diameter: wheelDiameter,
                onChanged: onLift,
                onEditEnd: onEditEnd,
                disabled: additiveTarget,
              ),
              const SizedBox(width: 16),
              GradeWheelControl(
                role: GradeRole.gamma,
                label: 'Gamma',
                sublabel: 'midtones',
                wheel: gamma,
                diameter: wheelDiameter,
                onChanged: onGamma,
                onEditEnd: onEditEnd,
              ),
              const SizedBox(width: 16),
              GradeWheelControl(
                role: GradeRole.gain,
                label: 'Gain',
                sublabel: 'highlights',
                wheel: gain,
                diameter: wheelDiameter,
                onChanged: onGain,
                onEditEnd: onEditEnd,
              ),
              const SizedBox(width: 26),
              _SliderStack(
                title: 'BALANCE',
                children: [
                  _LabeledSlider(
                    label: 'Temp',
                    value: temperature,
                    min: -1,
                    max: 1,
                    lowColor: _cool,
                    highColor: _warm,
                    onChanged: onTemperature,
                    onEditEnd: onEditEnd,
                  ),
                  _LabeledSlider(
                    label: 'Tint',
                    value: tint,
                    min: -1,
                    max: 1,
                    lowColor: const Color(0xFF5AC46A),
                    highColor: const Color(0xFFC45AC4),
                    onChanged: onTint,
                    onEditEnd: onEditEnd,
                  ),
                ],
              ),
              const SizedBox(width: 22),
              _SliderStack(
                title: 'TONE',
                children: [
                  _LabeledSlider(
                    label: 'Contrast',
                    value: contrast,
                    min: 0.5,
                    max: 1.8,
                    onChanged: onContrast,
                    onEditEnd: onEditEnd,
                    neutral: 1,
                  ),
                  _LabeledSlider(
                    label: 'Pivot',
                    value: pivot,
                    min: 0.2,
                    max: 0.7,
                    onChanged: onPivot,
                    onEditEnd: onEditEnd,
                    neutral: 0.435,
                  ),
                  _LabeledSlider(
                    label: 'Saturation',
                    value: saturation,
                    min: 0,
                    max: 2,
                    onChanged: onSaturation,
                    onEditEnd: onEditEnd,
                  ),
                ],
              ),
              if (showScopes) ...[
                const SizedBox(width: 24),
                TransferCurveScope(
                  grade: gradeFromWheels(
                    lift: lift,
                    gamma: gamma,
                    gain: gain,
                    saturation: saturation,
                    temperature: temperature,
                    tint: tint,
                    contrast: contrast,
                    pivot: pivot,
                  ),
                  bypass: bypass,
                ),
                const SizedBox(width: 18),
                ParadeScope(histogram: parade, bypass: bypass),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Panel title, the before/after Bypass toggle (a colourist has to see the clean
/// plate to judge how far a look has been pushed) and the global Reset.
class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    required this.subtitle,
    required this.bypass,
    required this.onBypass,
    required this.onReset,
  });

  /// The workspace passes the selected lane's name so the console always
  /// says WHAT it is editing; standalone use keeps the classic 'COLOR'.
  final String title;
  final String subtitle;
  final bool bypass;
  final ValueChanged<bool> onBypass;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: ColorGradePanel._textHi,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(color: ColorGradePanel._textLow, fontSize: 11),
        ),
        const SizedBox(height: 12),
        _BypassButton(bypass: bypass, onBypass: onBypass),
        const SizedBox(height: 8),
        _ResetButton(onReset: onReset),
      ],
    );
  }
}

class _BypassButton extends StatelessWidget {
  const _BypassButton({required this.bypass, required this.onBypass});

  final bool bypass;
  final ValueChanged<bool> onBypass;

  @override
  Widget build(BuildContext context) {
    // Bypassed = showing the clean plate (the "before").
    final active = bypass;
    return Tooltip(
      message: bypass
          ? 'Showing clean plate'
          : 'Show clean plate (bypass grade)',
      child: GestureDetector(
        key: const Key('gradeBypass'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onBypass(!bypass),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active
                ? ColorGradePanel._accent.withValues(alpha: 0.9)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: active ? ColorGradePanel._accent : ColorGradePanel._edge,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                bypass ? Icons.visibility_off_rounded : Icons.compare_rounded,
                size: 14,
                color: active
                    ? const Color(0xFF0F1317)
                    : ColorGradePanel._textLow,
              ),
              const SizedBox(width: 5),
              Text(
                bypass ? 'CLEAN' : 'A / B',
                style: TextStyle(
                  color: active
                      ? const Color(0xFF0F1317)
                      : ColorGradePanel._textLow,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One 3-way grading wheel: a hue balance puck, a bipolar luminance dial and a
/// live Slope/Offset/Power readout. Drag the puck to shift this range's colour
/// balance; the slider is the master luminance; the small ⟲ recentres just this
/// wheel; the panel's Reset recentres everything.
class GradeWheelControl extends StatelessWidget {
  const GradeWheelControl({
    required this.role,
    required this.label,
    required this.sublabel,
    required this.wheel,
    required this.onChanged,
    this.onEditEnd,
    this.diameter = 90,
    this.disabled = false,
    super.key,
  });

  final GradeRole role;
  final String label;
  final String sublabel;
  final GradeWheel wheel;
  final ValueChanged<GradeWheel> onChanged;

  /// Gesture-release hook (undo transactions / auto-key stamping).
  final VoidCallback? onEditEnd;
  final double diameter;

  /// A dead control must LOOK dead: dims and ignores input (the additive
  /// lanes' Lift wheel, whose Offset the render discards by design).
  final bool disabled;

  /// Tap: absolute jump (place the puck where you point).
  void _jumpTo(Offset local) {
    final radius = diameter / 2;
    var v = (local - Offset(radius, radius)) / radius;
    if (v.distance > 1) v = v / v.distance; // clamp to the wheel
    onChanged(GradeWheel(balance: v, master: wheel.master));
  }

  /// Drag: RELATIVE trackball move (Shift = fine) — the behaviour every
  /// grading surface uses; absolute-jump drags make a small puck unusable.
  void _dragBy(Offset delta) {
    final radius = diameter / 2;
    final k = HardwareKeyboard.instance.isShiftPressed ? 0.15 : 0.6;
    var v = wheel.balance + delta / radius * k;
    if (v.distance > 1) v = v / v.distance;
    onChanged(GradeWheel(balance: v, master: wheel.master));
  }

  /// This wheel's coefficient triple, computed through the real grade model so
  /// the readout is the exact CDL the render uses.
  GradeRgb get _coeff {
    switch (role) {
      case GradeRole.lift:
        return gradeFromWheels(lift: wheel).offset;
      case GradeRole.gamma:
        return gradeFromWheels(gamma: wheel).power;
      case GradeRole.gain:
        return gradeFromWheels(gain: wheel).slope;
    }
  }

  String get _coeffLabel => switch (role) {
    GradeRole.lift => 'O',
    GradeRole.gamma => 'P',
    GradeRole.gain => 'S',
  };

  @override
  Widget build(BuildContext context) {
    final c = _coeff;
    final signed = role == GradeRole.lift;
    if (disabled) {
      return Opacity(
        opacity: 0.35,
        child: IgnorePointer(child: _column(c, signed: signed)),
      );
    }
    return _column(c, signed: signed);
  }

  Widget _column(GradeRgb c, {required bool signed}) {
    return Column(
      children: [
        SizedBox(
          width: diameter,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: ColorGradePanel._textHi,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              _WheelReset(
                label: label,
                enabled: !wheel.isNeutral,
                onReset: () => onChanged(const GradeWheel()),
              ),
            ],
          ),
        ),
        Text(
          sublabel,
          style: const TextStyle(color: ColorGradePanel._textLow, fontSize: 10),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          key: Key('gradeWheel-$label'),
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            _jumpTo(d.localPosition);
            onEditEnd?.call();
          },
          onPanUpdate: (d) => _dragBy(d.delta),
          onPanEnd: (_) => onEditEnd?.call(),
          onPanCancel: () => onEditEnd?.call(),
          child: CustomPaint(
            size: Size.square(diameter),
            painter: _WheelPainter(balance: wheel.balance),
          ),
        ),
        const SizedBox(height: 4),
        _BipolarSlider(
          value: wheel.master,
          min: -1,
          max: 1,
          width: diameter,
          accent: ColorGradePanel._accent,
          onChanged: (v) =>
              onChanged(GradeWheel(balance: wheel.balance, master: v)),
          onEditEnd: onEditEnd,
        ),
        Text(
          _lumReadout(wheel.master),
          style: const TextStyle(
            color: ColorGradePanel._textLow,
            fontSize: 10,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          '$_coeffLabel ${_fmt(c.r, signed)} ${_fmt(c.g, signed)} ${_fmt(c.b, signed)}',
          style: const TextStyle(
            color: ColorGradePanel._textLow,
            fontSize: 9,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  static String _lumReadout(double master) {
    final sign = master >= 0 ? '+' : '';
    return 'lum $sign${master.toStringAsFixed(2)}';
  }

  static String _fmt(double v, bool signed) {
    if (signed) {
      final sign = v >= 0 ? '+' : '';
      return '$sign${v.toStringAsFixed(2)}';
    }
    return v.toStringAsFixed(2);
  }
}

/// Small per-wheel reset affordance (⟲) — one wrong nudge shouldn't force nuking
/// the whole grade. Dims to unclickable-looking when the wheel is already home.
class _WheelReset extends StatelessWidget {
  const _WheelReset({
    required this.label,
    required this.enabled,
    required this.onReset,
  });

  final String label;
  final bool enabled;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('gradeWheelReset-$label'),
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onReset : null,
      child: Icon(
        Icons.restart_alt_rounded,
        size: 13,
        color: enabled ? ColorGradePanel._textLow : ColorGradePanel._edge,
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.balance});

  final Offset balance;

  // Primary/secondary hue tick angles (screen space) so the target hue is
  // aimable. Matches `wheelTint`: red at top, green lower-left, blue lower-right.
  static const _tickAngles = <double>[
    -math.pi / 2, // red, top
    -math.pi / 2 - 2 * math.pi / 3, // yellow, upper-left
    math.pi / 2 + 2 * math.pi / 3, // green, lower-left (== -pi/2 - 4pi/3)
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = Offset(radius, radius);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final puck = center + balance * radius;

    canvas
      // Smooth hue ring, aligned to wheelTint (red at top, green lower-left,
      // blue lower-right) so where you drag is the colour you get, with the warm
      // arc given real angular width instead of a crushed seam.
      ..drawCircle(
        center,
        radius,
        Paint()
          ..shader = const SweepGradient(
            startAngle: 0.5235987755982988, // 30°, where blue sits
            endAngle: 0.5235987755982988 + 2 * math.pi,
            colors: [
              Color(0xFF3B6BFF), // blue
              Color(0xFF33C9D6), // cyan
              Color(0xFF3FBF57), // green
              Color(0xFFC9AE3A), // yellow
              Color(0xFFE0483B), // red (top)
              Color(0xFFB44AE0), // magenta
              Color(0xFF3B6BFF), // blue (loop close)
            ],
          ).createShader(rect),
      )
      // Desaturate toward a neutral centre so the middle reads as "no balance"
      // and the puck stays legible against the ring.
      ..drawCircle(
        center,
        radius,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xFF161B21), Color(0x33161B21), Color(0x00161B21)],
            stops: [0.0, 0.45, 0.82],
          ).createShader(rect),
      )
      // Inner-shadow rim for depth.
      ..drawCircle(
        center,
        radius - 0.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..shader = RadialGradient(
            colors: [
              const Color(0x00000000),
              Colors.black.withValues(alpha: 0.5),
            ],
            stops: const [0.86, 1.0],
          ).createShader(rect),
      );

    // Faint primary/secondary tick marks at the rim (R/Y/G and their opposites).
    final tickPaint = Paint()
      ..color = const Color(0x44FFFFFF)
      ..strokeWidth = 1;
    for (final a in _WheelPainter._tickAngles) {
      for (final ang in [a, a + math.pi]) {
        final dir = Offset(math.cos(ang), math.sin(ang));
        canvas.drawLine(
          center + dir * (radius - 6),
          center + dir * (radius - 2),
          tickPaint,
        );
      }
    }

    canvas
      // Crosshair: a neutral reference at the centre.
      ..drawLine(
        Offset(center.dx - 5, center.dy),
        Offset(center.dx + 5, center.dy),
        Paint()
          ..color = const Color(0x55FFFFFF)
          ..strokeWidth = 1,
      )
      ..drawLine(
        Offset(center.dx, center.dy - 5),
        Offset(center.dx, center.dy + 5),
        Paint()
          ..color = const Color(0x55FFFFFF)
          ..strokeWidth = 1,
      )
      // Crisp outer edge.
      ..drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = ColorGradePanel._edge,
      );

    // The balance vector + puck.
    if (balance != Offset.zero) {
      canvas.drawLine(
        center,
        puck,
        Paint()
          ..color = const Color(0xAAFFFFFF)
          ..strokeWidth = 1.5,
      );
    }
    canvas
      ..drawCircle(
        puck,
        7,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      )
      ..drawCircle(puck, 5.5, Paint()..color = Colors.white)
      ..drawCircle(
        puck,
        5.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.black.withValues(alpha: 0.55),
      );
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.balance != balance;
}

/// A titled column of labelled sliders (the Balance and Tone groups), so the
/// controls fill the row instead of leaving dead space to the right.
class _SliderStack extends StatelessWidget {
  const _SliderStack({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: ColorGradePanel._textLow,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}

/// A label + value readout above a bipolar slider (Temp / Tint / Contrast /
/// Saturation).
class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.onEditEnd,
    this.lowColor,
    this.highColor,
    this.neutral,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final VoidCallback? onEditEnd;
  final Color? lowColor;
  final Color? highColor;

  /// The value the fill originates from and the detent snaps to. Defaults to
  /// the track centre; asymmetric dials (Contrast 0.5..1.8, Pivot) pass their
  /// true neutral so the fill reads "how far from unchanged", not "how far
  /// from the middle of an arbitrary range".
  final double? neutral;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 58,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: ColorGradePanel._textHi,
                    fontSize: 11,
                  ),
                ),
              ),
              Text(
                value.toStringAsFixed(2),
                style: const TextStyle(
                  color: ColorGradePanel._textLow,
                  fontSize: 10,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          _BipolarSlider(
            key: Key('gradeSlider-$label'),
            value: value,
            min: min,
            max: max,
            width: 118,
            accent: ColorGradePanel._accent,
            lowColor: lowColor,
            highColor: highColor,
            onChanged: onChanged,
            onEditEnd: onEditEnd,
            neutral: neutral,
          ),
        ],
      ),
    );
  }
}

/// A slider whose fill originates from a centre detent, so polarity and zero are
/// readable at a glance and every dial in the panel speaks one visual language.
/// Snaps to the centre within a small dead-band.
class _BipolarSlider extends StatelessWidget {
  const _BipolarSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.width,
    required this.accent,
    required this.onChanged,
    this.onEditEnd,
    this.lowColor,
    this.highColor,
    this.neutral,
    super.key,
  });

  final double value;
  final double min;
  final double max;
  final double width;
  final Color accent;
  final Color? lowColor;
  final Color? highColor;
  final ValueChanged<double> onChanged;
  final VoidCallback? onEditEnd;

  /// Fill origin + snap detent (defaults to the track centre).
  final double? neutral;

  static const _height = 16.0;

  void _emit(double localX) {
    final t = (localX / width).clamp(0.0, 1.0);
    var v = min + t * (max - min);
    final detent = neutral ?? (min + max) / 2;
    if ((v - detent).abs() < (max - min) * 0.04) v = detent; // snap to neutral
    onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanDown: (d) => _emit(d.localPosition.dx),
      onPanUpdate: (d) => _emit(d.localPosition.dx),
      onPanEnd: (_) => onEditEnd?.call(),
      onPanCancel: () => onEditEnd?.call(),
      child: CustomPaint(
        size: Size(width, _height),
        painter: _BipolarTrackPainter(
          value: value.clamp(min, max),
          min: min,
          max: max,
          accent: accent,
          lowColor: lowColor,
          highColor: highColor,
          neutral: neutral,
        ),
      ),
    );
  }
}

class _BipolarTrackPainter extends CustomPainter {
  _BipolarTrackPainter({
    required this.value,
    required this.min,
    required this.max,
    required this.accent,
    this.lowColor,
    this.highColor,
    this.neutral,
  });

  final double value;
  final double min;
  final double max;
  final Color accent;
  final Color? lowColor;
  final Color? highColor;
  final double? neutral;

  double _x(double v, double width) => (v - min) / (max - min) * width;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final centre = neutral ?? (min + max) / 2;
    final centreX = _x(centre, size.width);
    final valueX = _x(value, size.width);

    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, cy - 1.5, size.width, 3),
      const Radius.circular(1.5),
    );
    // Fill from the centre detent out to the thumb, coloured by polarity.
    final positive = value >= centre;
    final fillColor = positive ? (highColor ?? accent) : (lowColor ?? accent);
    final fillRect = Rect.fromLTRB(
      math.min(centreX, valueX),
      cy - 1.5,
      math.max(centreX, valueX),
      cy + 1.5,
    );

    canvas
      ..drawRRect(track, Paint()..color = const Color(0xFF2A313A))
      ..drawRRect(
        RRect.fromRectAndRadius(fillRect, const Radius.circular(1.5)),
        Paint()..color = fillColor,
      )
      // Centre detent tick.
      ..drawLine(
        Offset(centreX, cy - 4),
        Offset(centreX, cy + 4),
        Paint()
          ..color = const Color(0x66FFFFFF)
          ..strokeWidth = 1,
      )
      // Thumb.
      ..drawCircle(
        Offset(valueX, cy),
        6,
        Paint()..color = Colors.black.withValues(alpha: 0.3),
      )
      ..drawCircle(
        Offset(valueX, cy),
        5,
        Paint()..color = ColorGradePanel._textHi,
      )
      ..drawCircle(
        Offset(valueX, cy),
        5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.black.withValues(alpha: 0.35),
      );
  }

  @override
  bool shouldRepaint(_BipolarTrackPainter old) =>
      old.value != value ||
      old.min != min ||
      old.max != max ||
      old.accent != accent ||
      old.lowColor != lowColor ||
      old.highColor != highColor ||
      old.neutral != neutral;
}

/// A "curves" scope: the grade's per-channel transfer response over a 0..1 input
/// ramp, with an identity diagonal for reference — so the shaping the wheels and
/// contrast apply is measurable, not eyeballed. Fills what would otherwise be
/// dead space on a wide panel; dims when the grade is bypassed.
class TransferCurveScope extends StatelessWidget {
  const TransferCurveScope({
    required this.grade,
    required this.bypass,
    this.width = 220,
    this.height = 118,
    this.caption = 'transfer',
    super.key,
  });

  final BackdropGrade grade;
  final bool bypass;

  /// Graph size — the console row uses the compact default; the pillarbox
  /// dock renders it at 1.5-2x so levels are actually measurable.
  final double width;
  final double height;

  /// Right-side caption: the dock names WHICH lane's transfer this is
  /// (e.g. 'MASTER · transfer') so the scope can never be misread.
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: width,
          child: Row(
            children: [
              const Text(
                'RESPONSE',
                style: TextStyle(
                  color: ColorGradePanel._textLow,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Text(
                bypass ? 'bypassed' : caption,
                style: const TextStyle(
                  color: ColorGradePanel._textLow,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        CustomPaint(
          size: Size(width, height),
          painter: _CurvePainter(grade: grade, bypass: bypass),
        ),
      ],
    );
  }
}

class _CurvePainter extends CustomPainter {
  _CurvePainter({required this.grade, required this.bypass});

  final BackdropGrade grade;
  final bool bypass;

  static const _samples = 48;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFF0C1013));

    // Quarter grid with LABELLED axis levels (a scope is a measuring
    // instrument, not a decoration) + a dotted identity reference.
    final grid = Paint()
      ..color = const Color(0x1AFFFFFF)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final gx = size.width * i / 4;
      final gy = size.height * i / 4;
      canvas
        ..drawLine(Offset(gx, 0), Offset(gx, size.height), grid)
        ..drawLine(Offset(0, gy), Offset(size.width, gy), grid);
    }
    void level(String text, double y, {bool top = false}) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            fontFamily: 'Inter',
            color: Color(0x66FFFFFF),
            fontSize: 7.5,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, top ? y + 1 : y - tp.height - 1));
    }

    level('1.0', 0, top: true);
    level('.5', size.height / 2);
    level('0', size.height);
    // Dotted identity diagonal: the unmistakable "no change" reference.
    final identityPaint = Paint()
      ..color = const Color(0x40FFFFFF)
      ..strokeWidth = 1;
    const dash = 4.0;
    final diagLen = math.sqrt(
      size.width * size.width + size.height * size.height,
    );
    final steps = (diagLen / (dash * 2)).ceil();
    for (var i = 0; i < steps; i++) {
      final t0 = i * 2 * dash / diagLen;
      final t1 = math.min(1, (i * 2 + 1) * dash / diagLen);
      canvas.drawLine(
        Offset(size.width * t0, size.height * (1 - t0)),
        Offset(size.width * t1, size.height * (1 - t1)),
        identityPaint,
      );
    }

    final alpha = bypass ? 0.28 : 1.0;
    void curve(double Function(GradeRgb) select, Color color) {
      final path = Path();
      for (var i = 0; i <= _samples; i++) {
        final x = i / _samples;
        final y = select(grade.responseAt(x));
        final px = x * size.width;
        final py = size.height - y * size.height;
        if (i == 0) {
          path.moveTo(px, py);
        } else {
          path.lineTo(px, py);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round
          ..color = color.withValues(alpha: alpha),
      );
    }

    // Where the three channels coincide the curve must read NEUTRAL (a lone
    // red diagonal says "red has been pushed" on every scope ever built);
    // split into R/G/B strokes only when the grade actually diverges them.
    final coincident =
        grade.slope.r == grade.slope.g &&
        grade.slope.g == grade.slope.b &&
        grade.offset.r == grade.offset.g &&
        grade.offset.g == grade.offset.b &&
        grade.power.r == grade.power.g &&
        grade.power.g == grade.power.b;
    if (coincident) {
      curve((c) => c.r, const Color(0xFFD9E2EA));
    } else {
      curve((c) => c.b, const Color(0xFF4A8FE6));
      curve((c) => c.g, const Color(0xFF3FBF57));
      curve((c) => c.r, const Color(0xFFE0483B));
    }

    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = ColorGradePanel._edge,
    );
  }

  @override
  bool shouldRepaint(_CurvePainter old) =>
      old.grade != grade || old.bypass != bypass;
}

/// An image-derived RGB parade: three per-channel histograms of the *actual*
/// graded stage pixels, so a colourist can verify where tones land — and see
/// crush (pile-up at the dark edge) or clip (pile-up at the bright edge) that the
/// transfer curve can only warn about. Shows a "sampling…" placeholder until the
/// first frame is captured.
class ParadeScope extends StatelessWidget {
  const ParadeScope({
    required this.histogram,
    required this.bypass,
    this.width = 176,
    this.height = 118,
    super.key,
  });

  final ScopeHistogram histogram;
  final bool bypass;

  /// Graph size (see [TransferCurveScope.width]).
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final clipped =
        histogram.clip.r > 0.02 ||
        histogram.clip.g > 0.02 ||
        histogram.clip.b > 0.02;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: width,
          child: Row(
            children: [
              const Text(
                'PARADE',
                style: TextStyle(
                  color: ColorGradePanel._textLow,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Text(
                !histogram.hasData
                    ? 'sampling…'
                    : clipped
                    ? 'clip'
                    : 'signal',
                style: TextStyle(
                  color: clipped
                      ? const Color(0xFFE0483B)
                      : ColorGradePanel._textLow,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        CustomPaint(
          size: Size(width, height),
          painter: _ParadePainter(histogram: histogram, bypass: bypass),
        ),
      ],
    );
  }
}

class _ParadePainter extends CustomPainter {
  _ParadePainter({required this.histogram, required this.bypass});

  final ScopeHistogram histogram;
  final bool bypass;

  static const _channelColors = [
    Color(0xFFE0483B), // R
    Color(0xFF3FBF57), // G
    Color(0xFF4A8FE6), // B
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFF0C1013));

    if (!histogram.hasData) {
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = ColorGradePanel._edge,
      );
      return;
    }

    // Three side-by-side channel cells (R, G, B).
    const gap = 6.0;
    final cellW = (size.width - gap * 2) / 3;
    final channels = [histogram.r, histogram.g, histogram.b];
    final peak = histogram.peak == 0 ? 1 : histogram.peak;
    final alpha = bypass ? 0.3 : 1.0;
    // Log scaling: night material piles most pixels into a few dark bins;
    // linear normalisation pins those to full height and flattens the rest
    // into an unreadable dust line. Log keeps the whole distribution legible.
    final logPeak = math.log(1 + peak.toDouble());

    for (var c = 0; c < 3; c++) {
      final left = c * (cellW + gap);
      final bins = channels[c];
      final barW = cellW / bins.length;
      final fill = _channelColors[c].withValues(alpha: alpha);
      for (var i = 0; i < bins.length; i++) {
        final h = math.log(1 + bins[i].toDouble()) / logPeak * size.height;
        if (h <= 0) continue;
        canvas.drawRect(
          Rect.fromLTWH(left + i * barW, size.height - h, barW + 0.5, h),
          Paint()..color = fill,
        );
      }
      // Level graticule: 25/50/75% marks inside the cell, so "where do the
      // tones sit" is measurable, then crush/clip edge guides.
      final levelPaint = Paint()
        ..color = const Color(0x22FFFFFF)
        ..strokeWidth = 1;
      for (var q = 1; q < 4; q++) {
        final lx = left + cellW * q / 4;
        canvas.drawLine(Offset(lx, 0), Offset(lx, size.height), levelPaint);
      }
      final warn = Paint()
        ..color = const Color(0x66E0483B)
        ..strokeWidth = 1;
      canvas
        ..drawLine(Offset(left, 0), Offset(left, size.height), warn)
        ..drawLine(
          Offset(left + cellW, 0),
          Offset(left + cellW, size.height),
          warn,
        );
    }

    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = ColorGradePanel._edge,
    );
  }

  @override
  bool shouldRepaint(_ParadePainter old) =>
      old.histogram != histogram || old.bypass != bypass;
}

class _ResetButton extends StatelessWidget {
  const _ResetButton({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Reset the whole grade to neutral',
      child: TextButton.icon(
        onPressed: onReset,
        icon: const Icon(Icons.restart_alt_rounded, size: 16),
        label: const Text('Reset'),
        style: TextButton.styleFrom(
          foregroundColor: ColorGradePanel._textLow,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
