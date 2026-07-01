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
  });

  /// Per-channel multiply (the highlights / "gain" control). 1 = unchanged.
  final GradeRgb slope;

  /// Per-channel add (the shadows / "lift" control). 0 = unchanged.
  final GradeRgb offset;

  /// Per-channel gamma exponent (the midtones / "gamma" control). 1 = unchanged.
  final GradeRgb power;

  /// Rec.709 saturation: 1 = unchanged, 0 = greyscale, >1 = more colourful.
  final double saturation;

  /// The no-op grade.
  static const identity = BackdropGrade();

  /// Whether this grade changes nothing — lets the renderer skip the grade pass
  /// entirely (and keep the cheaper direct paint) when the controls are centred.
  bool get isNeutral =>
      slope == identity.slope &&
      offset == identity.offset &&
      power == identity.power &&
      saturation == 1.0;

  @override
  bool operator ==(Object other) =>
      other is BackdropGrade &&
      other.slope == slope &&
      other.offset == offset &&
      other.power == power &&
      other.saturation == saturation;

  @override
  int get hashCode => Object.hash(slope, offset, power, saturation);
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

/// Builds the ASC CDL [BackdropGrade] from the three wheels plus a global
/// [saturation]. Gain → Slope (highlights), Lift → Offset (shadows), Gamma →
/// Power (midtones). A positive master brightens its range; a positive gamma
/// master lifts the midtones (lower power).
BackdropGrade gradeFromWheels({
  GradeWheel gain = const GradeWheel(),
  GradeWheel lift = const GradeWheel(),
  GradeWheel gamma = const GradeWheel(),
  double saturation = 1,
}) {
  final gainT = wheelTint(gain.balance);
  final liftT = wheelTint(lift.balance);
  final gammaT = wheelTint(gamma.balance);

  double slopeAt(double tint) => 1 + gain.master * _slopeMasterGain + tint * _slopeBalanceGain;
  double offsetAt(double tint) => lift.master * _offsetMasterGain + tint * _offsetBalanceGain;
  // Positive gamma delta → brighter mids → exponent below 1. Clamp so power stays
  // positive and bounded (a colourist never wants a runaway gamma).
  double powerAt(double tint) {
    final delta = (gamma.master + tint) * _gammaGain;
    final p = math.pow(2, -delta).toDouble();
    return p.clamp(0.2, 3.0);
  }

  return BackdropGrade(
    slope: (r: slopeAt(gainT.r), g: slopeAt(gainT.g), b: slopeAt(gainT.b)),
    offset: (r: offsetAt(liftT.r), g: offsetAt(liftT.g), b: offsetAt(liftT.b)),
    power: (r: powerAt(gammaT.r), g: powerAt(gammaT.g), b: powerAt(gammaT.b)),
    saturation: saturation < 0 ? 0 : saturation,
  );
}
