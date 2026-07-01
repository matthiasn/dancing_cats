import 'package:dancing_cats/features/scenery/model/backdrop_grade.dart';
import 'package:flutter/material.dart';

/// The dance demo's colour-grading console — a new row below the transport
/// waveform with three ASC-CDL-style colour wheels (Lift / Gamma / Gain), each a
/// balance puck plus a luminance dial, and a master saturation slider. Purely
/// presentational: it renders the supplied [GradeWheel] state and reports intent
/// through callbacks; the page owns the state and builds the [BackdropGrade]
/// (see `gradeFromWheels`). A dev tool for dialling the blue-hour look, not a
/// product surface.
class ColorGradePanel extends StatelessWidget {
  const ColorGradePanel({
    required this.lift,
    required this.gamma,
    required this.gain,
    required this.saturation,
    required this.onLift,
    required this.onGamma,
    required this.onGain,
    required this.onSaturation,
    required this.onReset,
    super.key,
  });

  final GradeWheel lift;
  final GradeWheel gamma;
  final GradeWheel gain;
  final double saturation;
  final ValueChanged<GradeWheel> onLift;
  final ValueChanged<GradeWheel> onGamma;
  final ValueChanged<GradeWheel> onGain;
  final ValueChanged<double> onSaturation;
  final VoidCallback onReset;

  static const _bg = Color(0xFF14181D);
  static const _edge = Color(0xFF2A313A);
  static const _textHi = Color(0xFFE7ECF2);
  static const _textLow = Color(0xFF8A94A2);

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: 'Inter'),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: _bg,
          border: Border(top: BorderSide(color: _edge)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PanelTitle(),
              const SizedBox(width: 20),
              GradeWheelControl(
                label: 'Lift',
                sublabel: 'shadows',
                wheel: lift,
                onChanged: onLift,
              ),
              const SizedBox(width: 16),
              GradeWheelControl(
                label: 'Gamma',
                sublabel: 'midtones',
                wheel: gamma,
                onChanged: onGamma,
              ),
              const SizedBox(width: 16),
              GradeWheelControl(
                label: 'Gain',
                sublabel: 'highlights',
                wheel: gain,
                onChanged: onGain,
              ),
              const SizedBox(width: 24),
              _SaturationDial(value: saturation, onChanged: onSaturation),
              const Spacer(),
              _ResetButton(onReset: onReset),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COLOR',
          style: TextStyle(
            color: ColorGradePanel._textHi,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        Text(
          'grade',
          style: TextStyle(color: ColorGradePanel._textLow, fontSize: 11),
        ),
      ],
    );
  }
}

/// One 3-way grading wheel: a hue balance puck plus a luminance dial. Drag the
/// puck to shift this range's colour balance; the slider is the master
/// luminance; the panel's Reset recentres everything.
class GradeWheelControl extends StatelessWidget {
  const GradeWheelControl({
    required this.label,
    required this.sublabel,
    required this.wheel,
    required this.onChanged,
    this.diameter = 84,
    super.key,
  });

  final String label;
  final String sublabel;
  final GradeWheel wheel;
  final ValueChanged<GradeWheel> onChanged;
  final double diameter;

  void _dragTo(Offset local) {
    final radius = diameter / 2;
    var v = (local - Offset(radius, radius)) / radius;
    if (v.distance > 1) v = v / v.distance; // clamp to the wheel
    onChanged(GradeWheel(balance: v, master: wheel.master));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: ColorGradePanel._textHi,
            fontSize: 12,
            fontWeight: FontWeight.w600,
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
          onPanDown: (d) => _dragTo(d.localPosition),
          onPanUpdate: (d) => _dragTo(d.localPosition),
          child: CustomPaint(
            size: Size.square(diameter),
            painter: _WheelPainter(balance: wheel.balance),
          ),
        ),
        SizedBox(
          width: diameter + 8,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: wheel.master.clamp(-1.0, 1.0),
              min: -1,
              onChanged: (v) =>
                  onChanged(GradeWheel(balance: wheel.balance, master: v)),
            ),
          ),
        ),
      ],
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.balance});

  final Offset balance;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = Offset(radius, radius);
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Hue ring: a full sweep of the spectrum (red at the top, matching
    // wheelTint's convention), faded to a neutral grey centre so the middle
    // reads as "no balance", then a thin edge and the draggable puck.
    final puck = center + balance * radius;
    canvas
      ..drawCircle(
        center,
        radius,
        Paint()
          ..shader = const SweepGradient(
            startAngle: -1.5708, // -90°, so red sits at the top
            colors: [
              Color(0xFFFF4040),
              Color(0xFFFFFF40),
              Color(0xFF40FF40),
              Color(0xFF40FFFF),
              Color(0xFF4040FF),
              Color(0xFFFF40FF),
              Color(0xFFFF4040),
            ],
          ).createShader(rect),
      )
      ..drawCircle(
        center,
        radius,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xFF20262E), Color(0x0020262E)],
            stops: [0.0, 0.62],
          ).createShader(rect),
      )
      ..drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = ColorGradePanel._edge,
      )
      ..drawCircle(puck, 6, Paint()..color = Colors.white)
      ..drawCircle(
        puck,
        6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.black87,
      );
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.balance != balance;
}

class _SaturationDial extends StatelessWidget {
  const _SaturationDial({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Saturation',
          style: TextStyle(
            color: ColorGradePanel._textHi,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value.toStringAsFixed(2),
          style: const TextStyle(color: ColorGradePanel._textLow, fontSize: 10),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 150,
          child: Slider(
            value: value.clamp(0.0, 2.0),
            max: 2,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _ResetButton extends StatelessWidget {
  const _ResetButton({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Reset the grade to neutral',
      child: TextButton.icon(
        onPressed: onReset,
        icon: const Icon(Icons.restart_alt_rounded, size: 18),
        label: const Text('Reset'),
        style: TextButton.styleFrom(foregroundColor: ColorGradePanel._textLow),
      ),
    );
  }
}
