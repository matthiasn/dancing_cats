/// A keyframed colour-grade timeline for one song — the model behind the
/// `<track>.grade.json` side file (see ADR 0002).
///
/// The document is a set of [GradeLane]s, one per grade *target* (`master`,
/// `backdrop`, `cast`, or a scenery layer id), each holding sparse
/// [GradeKeyframe]s in **wheel-space** ([GradeLook] — the console's own
/// coordinates, not raw CDL). Evaluation interpolates looks between keys with
/// a named curve per segment and hands back per-target looks; callers derive
/// the shader-ready CDL through the existing [gradeFromWheels].
///
/// Everything here is immutable and pure (no IO, no widget imports): mutation
/// helpers return new objects, which is also what makes the editor's
/// undo/redo a trivial snapshot stack. File IO lives with the demo's other
/// side-file loaders, keeping the scenery feature ejectable.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:dancing_cats/features/scenery/model/backdrop_grade.dart';
import 'package:flutter/foundation.dart' show immutable;

/// Stable ids for the two whole-composite grade targets plus the cast. The
/// per-layer ids live on the scene's `ParallaxLayer.gradeTarget` wrappers.
abstract final class GradeTargets {
  /// The whole stage composite (backdrop, lights, grain, cats — not captions).
  static const master = 'master';

  /// The painted-world composite only (the pre-ADR-0002 grade pass).
  static const backdrop = 'backdrop';

  /// The dancing trio, graded at the character-painter level.
  static const cast = 'cast';
}

/// One full console state in wheel-space: the three 3-way wheels plus the
/// balance/tone dials. This is the unit a keyframe stores and the UI edits —
/// raw CDL is always *derived* (see [toGrade]), never persisted.
@immutable
class GradeLook {
  const GradeLook({
    this.lift = const GradeWheel(),
    this.gamma = const GradeWheel(),
    this.gain = const GradeWheel(),
    this.saturation = 1,
    this.temperature = 0,
    this.tint = 0,
    this.contrast = 1,
    this.pivot = kGradePivotDefault,
  });

  /// Parses a look from JSON. Absent fields (and absent wheel axes) inherit
  /// from [base] — the panel-revised sparse semantics: a minimal hand/LLM
  /// keyframe changes only what it mentions, it never silently resets the
  /// rest toward neutral. Pass the previous keyframe's resolved look as
  /// [base]; the first keyframe of a lane inherits from [neutral].
  ///
  /// All parsed values are clamped to the console's control ranges, so a
  /// typo'd `{"gain": {"m": 10}}` in a hand-edited file cannot blow out the
  /// image live through the watcher.
  factory GradeLook.fromJson(
    Map<String, Object?> json, {
    GradeLook base = GradeLook.neutral,
  }) => GradeLook(
    lift: _wheelFromJson(json['lift'], base.lift),
    gamma: _wheelFromJson(json['gamma'], base.gamma),
    gain: _wheelFromJson(json['gain'], base.gain),
    saturation: _numOr(json['saturation'], base.saturation).clamp(0.0, 2.0),
    temperature: _numOr(json['temperature'], base.temperature).clamp(-1.0, 1.0),
    tint: _numOr(json['tint'], base.tint).clamp(-1.0, 1.0),
    contrast: _numOr(json['contrast'], base.contrast).clamp(0.5, 1.8),
    pivot: _numOr(json['pivot'], base.pivot).clamp(0.2, 0.7),
  );

  /// Shadows wheel (CDL Offset).
  final GradeWheel lift;

  /// Midtones wheel (CDL Power).
  final GradeWheel gamma;

  /// Highlights wheel (CDL Slope).
  final GradeWheel gain;

  /// Rec.709 saturation dial (1 = unchanged).
  final double saturation;

  /// White-balance temperature (−1 cool … +1 warm).
  final double temperature;

  /// White-balance tint (−1 green … +1 magenta).
  final double tint;

  /// Contrast about [pivot] (1 = unchanged).
  final double contrast;

  /// Tonal pivot the contrast rotates about (≈ mid grey).
  final double pivot;

  /// The all-neutral look (identity grade).
  static const neutral = GradeLook();

  /// Whether every control sits at its neutral detent. A neutral look renders
  /// through the cheap ungraded paint path.
  bool get isNeutral =>
      lift.isNeutral &&
      gamma.isNeutral &&
      gain.isNeutral &&
      saturation == 1 &&
      temperature == 0 &&
      tint == 0 &&
      contrast == 1;

  /// The shader-ready ASC CDL for this look, via the console's tuned mapping.
  BackdropGrade toGrade() => gradeFromWheels(
    lift: lift,
    gamma: gamma,
    gain: gain,
    saturation: saturation,
    temperature: temperature,
    tint: tint,
    contrast: contrast,
    pivot: pivot,
  );

  /// A copy with individual controls replaced (the console edits one control
  /// per gesture; everything else holds).
  GradeLook copyWith({
    GradeWheel? lift,
    GradeWheel? gamma,
    GradeWheel? gain,
    double? saturation,
    double? temperature,
    double? tint,
    double? contrast,
    double? pivot,
  }) => GradeLook(
    lift: lift ?? this.lift,
    gamma: gamma ?? this.gamma,
    gain: gain ?? this.gain,
    saturation: saturation ?? this.saturation,
    temperature: temperature ?? this.temperature,
    tint: tint ?? this.tint,
    contrast: contrast ?? this.contrast,
    pivot: pivot ?? this.pivot,
  );

  /// Component-wise interpolation toward [other] at progress [t] (0 → this,
  /// 1 → other). Pucks lerp in x/y — a puck animated through centre crosses
  /// neutral rather than whipping around the hue circle.
  GradeLook lerpTo(GradeLook other, double t) {
    double d(double a, double b) => a + (b - a) * t;
    GradeWheel w(GradeWheel a, GradeWheel b) => GradeWheel(
      balance: Offset(
        d(a.balance.dx, b.balance.dx),
        d(a.balance.dy, b.balance.dy),
      ),
      master: d(a.master, b.master),
    );
    return GradeLook(
      lift: w(lift, other.lift),
      gamma: w(gamma, other.gamma),
      gain: w(gain, other.gain),
      saturation: d(saturation, other.saturation),
      temperature: d(temperature, other.temperature),
      tint: d(tint, other.tint),
      contrast: d(contrast, other.contrast),
      pivot: d(pivot, other.pivot),
    );
  }

  /// How far this look sits from neutral, as a 0-ish..1-ish norm over ALL
  /// fields (≈1 when any single control is fully deflected). The lane
  /// sparkline plots this, so a saturation-only or temperature-only ride
  /// never reads dead-flat (panel-revised from a lift/gain-only metric).
  double get deviation {
    double wheel(GradeWheel w) {
      final r = w.balance.distance;
      final radius = r > 1 ? 1.0 : r;
      final master = w.master.abs();
      return radius > master ? radius : master;
    }

    final parts = [
      wheel(lift),
      wheel(gamma),
      wheel(gain),
      (saturation - 1).abs(),
      temperature.abs(),
      tint.abs(),
      (contrast - 1).abs() / 0.8,
    ];
    var out = 0.0;
    for (final p in parts) {
      if (p > out) out = p;
    }
    return out > 1 ? 1 : out;
  }

  /// Explicit JSON: the app always writes FULL looks (every field, every
  /// wheel axis), so saved files are unambiguous and diff-friendly. Sparse
  /// input with inheritance (see [GradeLook.fromJson]) is an authoring
  /// convenience only.
  Map<String, Object?> toJson() => {
    'lift': _wheelToJson(lift),
    'gamma': _wheelToJson(gamma),
    'gain': _wheelToJson(gain),
    'saturation': saturation,
    'temperature': temperature,
    'tint': tint,
    'contrast': contrast,
    'pivot': pivot,
  };

  @override
  bool operator ==(Object other) =>
      other is GradeLook &&
      other.lift == lift &&
      other.gamma == gamma &&
      other.gain == gain &&
      other.saturation == saturation &&
      other.temperature == temperature &&
      other.tint == tint &&
      other.contrast == contrast &&
      other.pivot == pivot;

  @override
  int get hashCode => Object.hash(
    lift,
    gamma,
    gain,
    saturation,
    temperature,
    tint,
    contrast,
    pivot,
  );
}

/// The console's neutral contrast pivot (mid grey for this scene's tonality).
const double kGradePivotDefault = 0.435;

/// The interpolation curve of the segment *leaving* a keyframe. Deliberately
/// excludes overshoot curves — a grade that overshoots reads as a colour pump;
/// anticipation is for limbs, not looks.
enum GradeInterp {
  /// Step: the value holds until the next key (a cut).
  hold,

  /// Straight lerp.
  linear,

  /// Cosine ease-in-out — the broadcast-safe default.
  smooth,

  /// Accelerating.
  easeIn,

  /// Decelerating.
  easeOut;

  /// Parses the JSON name; unknown/absent names fall back to [smooth] so a
  /// typo in a hand-written file degrades to the default rather than a crash.
  static GradeInterp fromName(String? name) => switch (name) {
    'hold' => hold,
    'linear' => linear,
    'easeIn' => easeIn,
    'easeOut' => easeOut,
    _ => smooth,
  };

  /// Maps normalized segment progress [t] (0..1) through the curve. Outputs
  /// stay inside 0..1 (no overshoot by design).
  double apply(double t) {
    final x = t.clamp(0.0, 1.0);
    return switch (this) {
      hold => 0,
      linear => x,
      smooth => 0.5 - 0.5 * math.cos(math.pi * x),
      easeIn => x * x,
      easeOut => 1 - (1 - x) * (1 - x),
    };
  }
}

/// One keyframe: a [look] pinned at [tSec], with the [interp] curve shaping
/// the segment from this key to the next.
@immutable
class GradeKeyframe {
  const GradeKeyframe({
    required this.tSec,
    required this.look,
    this.interp = GradeInterp.smooth,
  });

  /// Parses `{"t_sec": …, "interp": …, "look": {…}}`. Look fields absent from
  /// the JSON inherit from [base] (the previous key's resolved look); a
  /// keyframe with no `look` at all is a pure hold/retime key that carries
  /// [base] forward. A missing/unknown interp is [GradeInterp.smooth].
  factory GradeKeyframe.fromJson(
    Map<String, Object?> json, {
    GradeLook base = GradeLook.neutral,
  }) => GradeKeyframe(
    tSec: _numOr(json['t_sec'], 0),
    interp: GradeInterp.fromName(json['interp'] as String?),
    look: json['look'] is Map<String, Object?>
        ? GradeLook.fromJson(json['look']! as Map<String, Object?>, base: base)
        : base,
  );

  /// Position on the shared transport timeline, in seconds (the same `*_sec`
  /// vocabulary as every other side file; beat snapping is a UI input affair).
  final double tSec;

  /// The console state at this key.
  final GradeLook look;

  /// Curve of the segment leaving this key.
  final GradeInterp interp;

  /// JSON form (interp omitted at its default).
  Map<String, Object?> toJson() => {
    't_sec': tSec,
    if (interp != GradeInterp.smooth) 'interp': interp.name,
    'look': look.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is GradeKeyframe &&
      other.tSec == tSec &&
      other.look == look &&
      other.interp == interp;

  @override
  int get hashCode => Object.hash(tSec, look, interp);
}

/// Two keyframes closer than this (seconds) are the same key — upserts
/// replace instead of stacking, and drags cannot create coincident keys.
const double kGradeKeyEpsilonSec = 1e-3;

/// One automation lane: every keyframe for one grade [target], kept sorted.
@immutable
class GradeLane {
  /// Builds a lane, sorting [keyframes] by time and collapsing keys that
  /// coincide within [kGradeKeyEpsilonSec] (last one wins) so no evaluation
  /// segment can ever be zero-length.
  factory GradeLane({
    required String target,
    List<GradeKeyframe> keyframes = const [],
    bool enabled = true,
  }) {
    // Stable sort (Dart's List.sort is not): tie-break equal times on the
    // original index so "last one wins" in the dedupe is deterministic.
    final indexed = keyframes.indexed.toList()
      ..sort((a, b) {
        final byTime = a.$2.tSec.compareTo(b.$2.tSec);
        return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
      });
    final sorted = [for (final (_, k) in indexed) k];
    final deduped = <GradeKeyframe>[];
    for (final k in sorted) {
      if (deduped.isNotEmpty &&
          (k.tSec - deduped.last.tSec).abs() < kGradeKeyEpsilonSec) {
        deduped[deduped.length - 1] = k;
      } else {
        deduped.add(k);
      }
    }
    return GradeLane._(
      target: target,
      keyframes: List.unmodifiable(deduped),
      enabled: enabled,
    );
  }

  const GradeLane._({
    required this.target,
    required this.keyframes,
    required this.enabled,
  });

  /// Parses `{"target": …, "enabled": …, "keyframes": […]}`. Entries that are
  /// not objects are skipped (tolerant of a hand-edited file), matching the
  /// other side-file parsers' degrade-don't-crash posture. Keys are resolved
  /// in TIME order so sparse looks inherit from their true predecessor even
  /// when the array arrives shuffled.
  factory GradeLane.fromJson(Map<String, Object?> json) {
    final raw = [
      for (final k in (json['keyframes'] as List?) ?? const <Object?>[])
        if (k is Map<String, Object?>) k,
    ];
    final order = raw.indexed.toList()
      ..sort((a, b) {
        final byTime = _numOr(
          a.$2['t_sec'],
          0,
        ).compareTo(_numOr(b.$2['t_sec'], 0));
        return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
      });
    var base = GradeLook.neutral;
    final keys = <GradeKeyframe>[];
    for (final (_, k) in order) {
      final key = GradeKeyframe.fromJson(k, base: base);
      keys.add(key);
      base = key.look;
    }
    return GradeLane(
      target: (json['target'] as String?) ?? GradeTargets.master,
      enabled: json['enabled'] != false,
      keyframes: keys,
    );
  }

  /// The grade target this lane automates (`master`, `backdrop`, `cast`, or a
  /// scenery layer id).
  final String target;

  /// Sorted, deduplicated keyframes.
  final List<GradeKeyframe> keyframes;

  /// A disabled lane evaluates to neutral (the automation-lane mute).
  final bool enabled;

  /// The lane's look at [tSec]: constant beyond the first/last key, the
  /// keyed look exactly at a key, and the segment's [GradeInterp]-eased lerp
  /// between neighbours. Empty or disabled lanes are neutral.
  GradeLook evaluate(double tSec) {
    if (!enabled || keyframes.isEmpty) return GradeLook.neutral;
    if (tSec <= keyframes.first.tSec) return keyframes.first.look;
    if (tSec >= keyframes.last.tSec) return keyframes.last.look;
    // Binary search for the segment [lo, lo+1] containing tSec.
    var lo = 0;
    var hi = keyframes.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (keyframes[mid].tSec <= tSec) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final a = keyframes[lo];
    final b = keyframes[hi];
    final u = (tSec - a.tSec) / (b.tSec - a.tSec);
    return a.look.lerpTo(b.look, a.interp.apply(u));
  }

  /// The index of the key at [tSec] (within [tolerance]), or null.
  int? indexNear(double tSec, {double tolerance = kGradeKeyEpsilonSec}) {
    for (var i = 0; i < keyframes.length; i++) {
      if ((keyframes[i].tSec - tSec).abs() <= tolerance) return i;
    }
    return null;
  }

  /// A copy with [key] stamped: replaces the key at the same time (within the
  /// epsilon) or inserts a new one in order.
  GradeLane upsert(GradeKeyframe key) {
    final i = indexNear(key.tSec);
    final base = i == null ? keyframes : ([...keyframes]..removeAt(i));
    return GradeLane(
      target: target,
      enabled: enabled,
      keyframes: [...base, key],
    );
  }

  /// A copy without the key nearest [tSec] (within [tolerance]); unchanged if
  /// none is close enough.
  GradeLane removeNear(double tSec, {double tolerance = kGradeKeyEpsilonSec}) {
    final i = indexNear(tSec, tolerance: tolerance);
    if (i == null) return this;
    return GradeLane(
      target: target,
      enabled: enabled,
      keyframes: [...keyframes]..removeAt(i),
    );
  }

  /// A copy with the key at index [index] replaced by [key] (the editor's
  /// move/re-curve primitive).
  GradeLane replaceAt(int index, GradeKeyframe key) => GradeLane(
    target: target,
    enabled: enabled,
    keyframes: [
      for (var i = 0; i < keyframes.length; i++)
        if (i == index) key else keyframes[i],
    ],
  );

  /// A copy with the lane muted/unmuted.
  GradeLane withEnabled({required bool enabled}) =>
      GradeLane._(target: target, keyframes: keyframes, enabled: enabled);

  /// JSON form.
  Map<String, Object?> toJson() => {
    'target': target,
    if (!enabled) 'enabled': false,
    'keyframes': [for (final k in keyframes) k.toJson()],
  };
}

/// The whole grade document for one song: every lane, addressable by target.
@immutable
class GradeTimelineDoc {
  /// Builds a document; later duplicate targets replace earlier ones so a
  /// target never has two lanes.
  factory GradeTimelineDoc({List<GradeLane> lanes = const []}) {
    final byTarget = <String, GradeLane>{};
    for (final lane in lanes) {
      byTarget[lane.target] = lane;
    }
    return GradeTimelineDoc._(List.unmodifiable(byTarget.values));
  }

  const GradeTimelineDoc._(this.lanes);

  /// Parses the `<track>.grade.json` document. Throws [FormatException] on a
  /// wrong version so a future-format file fails loudly instead of silently
  /// half-loading; the file loader turns that into an empty doc + a log.
  factory GradeTimelineDoc.fromJson(Map<String, Object?> json) {
    final version = json['version'];
    if (version != null && version != 1) {
      throw FormatException('unsupported grade timeline version: $version');
    }
    return GradeTimelineDoc(
      lanes: [
        for (final l in (json['lanes'] as List?) ?? const <Object?>[])
          if (l is Map<String, Object?>) GradeLane.fromJson(l),
      ],
    );
  }

  /// The lanes, in document order (one per target).
  final List<GradeLane> lanes;

  /// The empty document (no lanes — everything neutral).
  static const GradeTimelineDoc empty = GradeTimelineDoc._([]);

  /// Whether no lane holds any keyframe.
  bool get isEmpty => lanes.every((l) => l.keyframes.isEmpty);

  /// Whether any enabled lane carries a non-neutral key. Drives the
  /// compact-mode GRADE badge: a closed workspace must still reveal that a
  /// loaded document is colouring the stage.
  bool get isActive =>
      lanes.any((l) => l.enabled && l.keyframes.any((k) => !k.look.isNeutral));

  /// The lane for [target], or null.
  GradeLane? lane(String target) {
    for (final l in lanes) {
      if (l.target == target) return l;
    }
    return null;
  }

  /// Every enabled lane's look at [tSec], keyed by target. Neutral results
  /// are skipped so callers can treat map absence as "no grade pass".
  Map<String, GradeLook> evaluate(double tSec) {
    final out = <String, GradeLook>{};
    for (final l in lanes) {
      final look = l.evaluate(tSec);
      if (!look.isNeutral) out[l.target] = look;
    }
    return out;
  }

  /// A copy with [lane] added or replacing its target's existing lane.
  GradeTimelineDoc withLane(GradeLane lane) => GradeTimelineDoc(
    lanes: [...lanes.where((l) => l.target != lane.target), lane],
  );

  /// A copy without [target]'s lane.
  GradeTimelineDoc withoutLane(String target) =>
      GradeTimelineDoc(lanes: [...lanes.where((l) => l.target != target)]);

  /// JSON form (schema v1).
  Map<String, Object?> toJson() => {
    'version': 1,
    'lanes': [for (final l in lanes) l.toJson()],
  };
}

double _numOr(Object? v, double fallback) => v is num ? v.toDouble() : fallback;

/// Parses one wheel, inheriting absent axes from [base] and clamping to the
/// console's ranges: the puck stays inside the unit wheel (direction kept,
/// radius clamped), the master dial inside ±1.
GradeWheel _wheelFromJson(Object? v, GradeWheel base) {
  if (v is! Map<String, Object?>) return base;
  var balance = Offset(
    _numOr(v['x'], base.balance.dx),
    _numOr(v['y'], base.balance.dy),
  );
  if (balance.distance > 1) balance = balance / balance.distance;
  return GradeWheel(
    balance: balance,
    master: _numOr(v['m'], base.master).clamp(-1.0, 1.0),
  );
}

Map<String, Object?> _wheelToJson(GradeWheel w) => {
  'x': w.balance.dx,
  'y': w.balance.dy,
  'm': w.master,
};
