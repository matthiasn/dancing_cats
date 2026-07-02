import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable, listEquals;

/// A per-channel tonal histogram of a rendered frame — the data behind an RGB
/// parade / scope. Each channel is binned into [bins] buckets (dark → bright);
/// [peak] is the largest single bucket across all channels, for normalising the
/// draw. [crush] and [clip] are the fraction of samples pinned at pure black /
/// pure white per channel, so the scope can warn when a grade is losing shadow
/// or highlight detail.
///
/// Built from a downsampled RGBA snapshot of the graded stage (see
/// [buildScopeHistogram]) so a colourist can verify where the *actual* pixels
/// land, not just what the transfer curve does.
@immutable
class ScopeHistogram {
  const ScopeHistogram({
    required this.r,
    required this.g,
    required this.b,
    required this.peak,
    required this.crush,
    required this.clip,
  });

  /// An empty histogram (no samples) — the pre-first-capture placeholder.
  factory ScopeHistogram.empty([int bins = 64]) {
    final z = List<int>.filled(bins, 0);
    return ScopeHistogram(
      r: z,
      g: z,
      b: z,
      peak: 0,
      crush: const (r: 0.0, g: 0.0, b: 0.0),
      clip: const (r: 0.0, g: 0.0, b: 0.0),
    );
  }

  final List<int> r;
  final List<int> g;
  final List<int> b;
  final int peak;

  /// Fraction (0..1) of samples at the darkest bucket, per channel.
  final ({double r, double g, double b}) crush;

  /// Fraction (0..1) of samples at the brightest bucket, per channel.
  final ({double r, double g, double b}) clip;

  int get bins => r.length;

  /// Whether any samples were counted (an empty capture stays a placeholder).
  bool get hasData => peak > 0;

  @override
  bool operator ==(Object other) =>
      other is ScopeHistogram &&
      listEquals(other.r, r) &&
      listEquals(other.g, g) &&
      listEquals(other.b, b) &&
      other.peak == peak &&
      other.crush == crush &&
      other.clip == clip;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(r),
    Object.hashAll(g),
    Object.hashAll(b),
    peak,
    crush,
    clip,
  );
}

/// Builds a [ScopeHistogram] from a packed [rgba] buffer (4 bytes/pixel). Counts
/// every pixel into [bins] buckets per channel and tracks pure-black / pure-white
/// pile-ups. Trailing bytes that don't complete a pixel are ignored.
///
/// Pixels that are EXACTLY (0,0,0) are treated as matte (the stage's
/// letterbox/pillarbox bars, which the snapshot inevitably includes) and
/// skipped — a scope measures the picture, not the frame around it. Real
/// scene shadows are never a bit-exact zero triple across a whole region.
ScopeHistogram buildScopeHistogram(Uint8List rgba, {int bins = 64}) {
  final r = List<int>.filled(bins, 0);
  final g = List<int>.filled(bins, 0);
  final b = List<int>.filled(bins, 0);
  final last = bins - 1;
  var crushR = 0;
  var crushG = 0;
  var crushB = 0;
  var clipR = 0;
  var clipG = 0;
  var clipB = 0;
  var samples = 0;

  final pixels = rgba.length ~/ 4;
  for (var p = 0; p < pixels; p++) {
    final i = p * 4;
    if (rgba[i] == 0 && rgba[i + 1] == 0 && rgba[i + 2] == 0) {
      continue; // matte black (letterbox), not picture
    }
    final rv = (rgba[i] * bins) >> 8;
    final gv = (rgba[i + 1] * bins) >> 8;
    final bv = (rgba[i + 2] * bins) >> 8;
    r[rv]++;
    g[gv]++;
    b[bv]++;
    if (rv == 0) crushR++;
    if (gv == 0) crushG++;
    if (bv == 0) crushB++;
    if (rv == last) clipR++;
    if (gv == last) clipG++;
    if (bv == last) clipB++;
    samples++;
  }

  var peak = 0;
  for (var i = 0; i < bins; i++) {
    if (r[i] > peak) peak = r[i];
    if (g[i] > peak) peak = g[i];
    if (b[i] > peak) peak = b[i];
  }

  final n = samples == 0 ? 1 : samples;
  return ScopeHistogram(
    r: r,
    g: g,
    b: b,
    peak: peak,
    crush: (r: crushR / n, g: crushG / n, b: crushB / n),
    clip: (r: clipR / n, g: clipG / n, b: clipB / n),
  );
}
