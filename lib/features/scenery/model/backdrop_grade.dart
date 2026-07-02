import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart' show immutable;

/// An RGB triple used for the per-channel grade coefficients.
typedef GradeRgb = ({double r, double g, double b});

/// A primary colour grade in the standardised **ASC CDL** model (Slope, Offset,
/// Power per channel, plus a global Saturation):
///
/// ```text
/// graded = (slope * c + offset) ^ power      // applied Slope → Offset → Power
/// out    = mix(luma(graded), graded, saturation)   // Rec.709 luma
/// ```
///
/// Slope is a multiply (pivots on black → moves highlights most), Offset is an
/// add (moves shadows most), Power is a gamma exponent (moves midtones), so the
/// three map cleanly onto a 3-way colour-wheel UI (gain / lift / gamma). The
/// default is the identity grade (a no-op); see [gradeFromWheels] to build one
/// from wheel state.
@immutable
class BackdropGrade {
  const BackdropGrade({
    this.slope = const (r: 1.0, g: 1.0, b: 1.0),
    this.offset = const (r: 0.0, g: 0.0, b: 0.0),
    this.power = const (r: 1.0, g: 1.0, b: 1.0),
    this.saturation = 1.0,
    this.contrast = 1.0,
    this.pivot = 0.435,
  });

  /// Per-channel multiply (the highlights / "gain" control). 1 = unchanged.
  final GradeRgb slope;

  /// Per-channel add (the shadows / "lift" control). 0 = unchanged.
  final GradeRgb offset;

  /// Per-channel gamma exponent (the midtones / "gamma" control). 1 = unchanged.
  final GradeRgb power;

  /// Rec.709 saturation: 1 = unchanged, 0 = greyscale, >1 = more colourful.
  final double saturation;

  /// Contrast about [pivot] applied after SOP: `(c - pivot) * contrast + pivot`.
  /// 1 = unchanged. Shapes the tone (an S-curve pivot) the offset-only wheels
  /// can't — pulls the subject off a flat, milky plate.
  final double contrast;

  /// The tonal pivot the [contrast] rotates about (≈ mid grey). Irrelevant when
  /// contrast is 1.
  final double pivot;

  /// The no-op grade.
  static const identity = BackdropGrade();

  /// Whether this grade changes nothing — lets the renderer skip the grade pass
  /// entirely (and keep the cheaper direct paint) when the controls are centred.
  bool get isNeutral =>
      slope == identity.slope &&
      offset == identity.offset &&
      power == identity.power &&
      saturation == 1.0 &&
      contrast == 1.0;

  /// The graded response of an input grey [x] (0..1) per channel — the transfer
  /// curve a colourist reads as a "curves" scope. Mirrors the shader's
  /// Slope→Offset→Power→Contrast pipeline (saturation, which mixes channels, is
  /// omitted since a per-channel curve can't express it). Output is clamped to
  /// the displayable 0..1 range.
  GradeRgb responseAt(double x) {
    double channel(double s, double o, double p) {
      var c = s * x + o;
      if (c < 0) c = 0;
      c = math.pow(c, p).toDouble();
      c = (c - pivot) * contrast + pivot;
      return c.clamp(0.0, 1.0);
    }

    return (
      r: channel(slope.r, offset.r, power.r),
      g: channel(slope.g, offset.g, power.g),
      b: channel(slope.b, offset.b, power.b),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BackdropGrade &&
      other.slope == slope &&
      other.offset == offset &&
      other.power == power &&
      other.saturation == saturation &&
      other.contrast == contrast &&
      other.pivot == pivot;

  @override
  int get hashCode =>
      Object.hash(slope, offset, power, saturation, contrast, pivot);
}

/// One 3-way grading wheel's state: a colour [balance] puck (a vector from the
/// wheel centre; each axis roughly -1..1) plus a [master] luminance dial for
/// that tonal range (roughly -1..1). Both zero = neutral.
@immutable
class GradeWheel {
  const GradeWheel({this.balance = Offset.zero, this.master = 0});

  /// Puck offset from centre. `dx` right, `dy` DOWN (screen convention). Hue is
  /// its angle, strength its length.
  final Offset balance;

  /// Luminance dial for this range (gain/lift/gamma master). 0 = neutral.
  final double master;

  bool get isNeutral => balance == Offset.zero && master == 0;

  @override
  bool operator ==(Object other) =>
      other is GradeWheel && other.balance == balance && other.master == master;

  @override
  int get hashCode => Object.hash(balance, master);
}

/// Maps a colour-wheel puck to a small, roughly luma-neutral RGB balance. Hue is
/// the angle, strength the radius; the three primaries sit 120° apart, so pushing
/// toward a hue adds it and pulls its complement (a real colour-balance move,
/// not a tint that lifts overall brightness). Red sits at the top of the wheel.
GradeRgb wheelTint(Offset puck) {
  final radius = puck.distance;
  if (radius == 0) return (r: 0.0, g: 0.0, b: 0.0);
  final r = radius > 1 ? 1.0 : radius;
  // Screen dy points down; flip so "up" is +y (toward red at the top).
  final angle = math.atan2(-puck.dy, puck.dx);
  const top = math.pi / 2; // red at 12 o'clock
  const third = 2 * math.pi / 3;
  double axis(double primary) => r * math.cos(angle - primary);
  return (r: axis(top), g: axis(top + third), b: axis(top - third));
}

/// Sensitivity of each control, so a full puck/dial deflection lands in a
/// tasteful grade range rather than blowing the image out.
const double _slopeBalanceGain = 0.4; // gain wheel colour → slope
const double _slopeMasterGain = 0.6; // gain dial → slope
const double _offsetBalanceGain = 0.2; // lift wheel colour → offset
const double _offsetMasterGain = 0.3; // lift dial → offset
const double _gammaGain = 0.6; // gamma wheel/dial → power exponent
const double _tempGain = 0.25; // temperature → warm/cool slope balance
const double _tintGain = 0.2; // tint → magenta/green slope balance

/// Builds the ASC CDL [BackdropGrade] from the three wheels, a global
/// [saturation] and [contrast], and a global white-balance [temperature]/[tint].
/// Gain → Slope (highlights), Lift → Offset (shadows), Gamma → Power (midtones);
/// a positive master brightens its range, a positive gamma master lifts the
/// midtones (lower power). Temperature warms (+R/-B), tint shifts magenta/green.
BackdropGrade gradeFromWheels({
  GradeWheel gain = const GradeWheel(),
  GradeWheel lift = const GradeWheel(),
  GradeWheel gamma = const GradeWheel(),
  double saturation = 1,
  double contrast = 1,
  double pivot = 0.435,
  double temperature = 0,
  double tint = 0,
}) {
  final gainT = wheelTint(gain.balance);
  final liftT = wheelTint(lift.balance);
  final gammaT = wheelTint(gamma.balance);

  double slopeAt(double t) =>
      1 + gain.master * _slopeMasterGain + t * _slopeBalanceGain;
  double offsetAt(double t) =>
      lift.master * _offsetMasterGain + t * _offsetBalanceGain;
  // Positive gamma delta → brighter mids → exponent below 1. Clamp so power stays
  // positive and bounded (a colourist never wants a runaway gamma).
  double powerAt(double t) {
    final delta = (gamma.master + t) * _gammaGain;
    return math.pow(2, -delta).toDouble().clamp(0.2, 3.0);
  }

  // White balance folds into the slope, kept roughly luma-neutral: temperature
  // pushes red vs blue, tint pushes green vs magenta.
  final wbR = temperature * _tempGain + tint * _tintGain;
  final wbG = -tint * 2 * _tintGain;
  final wbB = -temperature * _tempGain + tint * _tintGain;

  return BackdropGrade(
    slope: (
      r: slopeAt(gainT.r) + wbR,
      g: slopeAt(gainT.g) + wbG,
      b: slopeAt(gainT.b) + wbB,
    ),
    offset: (r: offsetAt(liftT.r), g: offsetAt(liftT.g), b: offsetAt(liftT.b)),
    power: (r: powerAt(gammaT.r), g: powerAt(gammaT.g), b: powerAt(gammaT.b)),
    saturation: saturation < 0 ? 0 : saturation,
    contrast: contrast,
    pivot: pivot,
  );
}
