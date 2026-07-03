/// The editable document behind the `<track>.cues.json` side file: a
/// contiguous run of Rhubarb mouth-shape spans (see [DanceCue]), plus the
/// `schema_version`/`audio`/`lipsync` metadata blocks carried through
/// verbatim so a manual edit round-trips losslessly and doesn't fight a
/// future `tools/dance_audio/lipsync.py` re-run.
///
/// Unlike the colour-grade timeline's sparse point keyframes, cues cover the
/// whole track with no gaps (`X` — rest — is itself a cue), so the edit
/// primitives here are span-based: retime a shared boundary, reshape a span,
/// split one span into two, or merge two back into one. Everything is
/// immutable and pure (no IO); file IO lives in `DanceCuesStore`.
library;

import 'package:dancing_cats/features/character/demo/dance_lip_sync.dart';
import 'package:dancing_cats/features/character/demo/dance_loaders.dart';
import 'package:flutter/foundation.dart' show immutable;

/// Floor for any cue span. Drags, splits and merges all clamp to this so no
/// edit can create a cue too thin to ever be grabbed again.
const double kMinCueDurationSec = 0.02;

@immutable
class LipSyncDoc {
  const LipSyncDoc({
    required this.cues,
    this.schemaVersion = '1.0',
    this.audio = const {},
    this.lipsync = const {},
  });

  /// Parses a `<track>.cues.json` document via the existing [parseDanceCues],
  /// keeping the other top-level blocks opaque.
  factory LipSyncDoc.fromJson(Map<String, Object?> json) => LipSyncDoc(
    cues: parseDanceCues(json),
    schemaVersion: (json['schema_version'] as String?) ?? '1.0',
    audio: (json['audio'] as Map<String, Object?>?) ?? const {},
    lipsync: (json['lipsync'] as Map<String, Object?>?) ?? const {},
  );

  /// The cue spans, sorted and contiguous: `cues[i].end == cues[i + 1].start`.
  final List<DanceCue> cues;

  /// Carried through verbatim from the source file.
  final String schemaVersion;

  /// The `audio` metadata block, carried through verbatim.
  final Map<String, Object?> audio;

  /// The `lipsync` metadata block, carried through verbatim.
  final Map<String, Object?> lipsync;

  /// The empty document (no cues yet).
  static const empty = LipSyncDoc(cues: []);

  Map<String, Object?> toJson() => {
    'schema_version': schemaVersion,
    'audio': audio,
    'lipsync': lipsync,
    'cues': [
      for (final c in cues)
        {'start_sec': c.start, 'end_sec': c.end, 'shape': c.shape},
    ],
  };

  /// The index of the cue spanning `[start, end)` at [tSec], or null when
  /// [tSec] is before the first cue or at/after the last cue's end.
  int? indexAt(double tSec) {
    for (var i = 0; i < cues.length; i++) {
      if (tSec >= cues[i].start && tSec < cues[i].end) return i;
    }
    return null;
  }

  /// Retimes the boundary between `cues[index]` and `cues[index + 1]` to
  /// [newTimeSec], clamped so neither side drops below [kMinCueDurationSec].
  /// A no-op when [index] is out of range or both neighbours already sit at
  /// the floor (fully boxed in).
  LipSyncDoc moveBoundary(int index, double newTimeSec) {
    if (index < 0 || index >= cues.length - 1) return this;
    final left = cues[index];
    final right = cues[index + 1];
    final lo = left.start + kMinCueDurationSec;
    final hi = right.end - kMinCueDurationSec;
    if (hi < lo) return this;
    final t = newTimeSec.clamp(lo, hi);
    final next = [...cues];
    next[index] = (start: left.start, end: t, shape: left.shape);
    next[index + 1] = (start: t, end: right.end, shape: right.shape);
    return _withCues(next);
  }

  /// Replaces the viseme letter of `cues[index]`. A no-op when out of range.
  LipSyncDoc setShape(int index, String shape) {
    if (index < 0 || index >= cues.length) return this;
    final c = cues[index];
    final next = [...cues];
    next[index] = (start: c.start, end: c.end, shape: shape);
    return _withCues(next);
  }

  /// Inserts a boundary at [tSec], splitting whichever cue contains it into
  /// two spans that both start with its shape (a no-op split until one half
  /// is reshaped). A no-op when [tSec] falls outside any cue or within
  /// [kMinCueDurationSec] of an existing boundary.
  LipSyncDoc splitAt(double tSec) {
    final i = indexAt(tSec);
    if (i == null) return this;
    final c = cues[i];
    if (tSec - c.start < kMinCueDurationSec ||
        c.end - tSec < kMinCueDurationSec) {
      return this;
    }
    final next = [...cues]
      ..replaceRange(i, i + 1, [
        (start: c.start, end: tSec, shape: c.shape),
        (start: tSec, end: c.end, shape: c.shape),
      ]);
    return _withCues(next);
  }

  /// Drops the boundary after `cues[index]`, extending it to swallow
  /// `cues[index + 1]` (keeps `cues[index]`'s shape). A no-op when [index] is
  /// out of range.
  LipSyncDoc mergeBoundaryAfter(int index) {
    if (index < 0 || index >= cues.length - 1) return this;
    final left = cues[index];
    final right = cues[index + 1];
    final next = [...cues]
      ..replaceRange(index, index + 2, [
        (start: left.start, end: right.end, shape: left.shape),
      ]);
    return _withCues(next);
  }

  LipSyncDoc _withCues(List<DanceCue> next) => LipSyncDoc(
    cues: next,
    schemaVersion: schemaVersion,
    audio: audio,
    lipsync: lipsync,
  );
}
