import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Screen-order floor anchors (left, centre, right) of the per-voice flares —
/// matched to the StageLightRig pool anchors so each voice's flare rises over
/// its own light pool and its own dancer.
const kDropBloomLaneAnchors = [0.30, 0.50, 0.70];

/// Per-voice flare geometry, sized so a tutti hit (all lanes on the same beat)
/// sums back to the single dome it replaced: with plus blending the three
/// gradients stack to ~0.27 peak alpha at frame centre
/// (0.15 + 2 * 0.15 * (1 - 0.20 / 0.34)) — the old global flare's 0.26 peak.
/// A drop still punches as one warm wash, but a canon hit lifts mostly its own
/// voice's zone: a flanker's flare leaks only ~41% into the centre, where the
/// global flare lifted every zone at full strength and masked the cascade.
const kDropBloomLaneRadiusFrac = 0.34;
const kDropBloomLaneAlpha = 0.15;

/// The global flare's geometry, kept for callers with no per-voice envelopes
/// (a single dancer, or dances without displaced accent lanes).
const kDropBloomGlobalRadiusFrac = 0.52;
const kDropBloomGlobalAlpha = 0.26;

/// Warm additive flash centred on the dancers that spikes with the music accent
/// (biggest on the drops) — the punctuating drop "moment" the tempo-synced gel
/// pulse alone can't give, because the rim/pool intensity already saturates on
/// every beat (a drop could never out-punch a bar). Zero between hits, so it
/// only ever reads as a flare on the accent, then decays.
///
/// With [laneAccents] (per-voice accent envelopes in SCREEN order — each canon
/// voice's accent rides its own displaced beat), the flash is one flare per
/// voice over that voice's pool, so a call-and-response lights as a
/// left-to-right cascade instead of one global lift. Without it, the original
/// single dome.
///
/// Single source of truth for BOTH paint paths: the live `DanceStageView` (via
/// [DropBloomPainter]) and the offline `DanceFrameComposer` (direct canvas), so
/// the flare can never drift between the running app and a render.
void paintDropBloom(
  Canvas canvas,
  Size size,
  double accent, {
  List<double>? laneAccents,
}) {
  if (laneAccents == null) {
    _paintFlare(
      canvas,
      size,
      accent,
      anchorX: 0.5,
      radiusFrac: kDropBloomGlobalRadiusFrac,
      alpha: kDropBloomGlobalAlpha,
    );
    return;
  }
  for (var i = 0; i < laneAccents.length; i++) {
    _paintFlare(
      canvas,
      size,
      laneAccents[i],
      anchorX: kDropBloomLaneAnchors[i % kDropBloomLaneAnchors.length],
      radiusFrac: kDropBloomLaneRadiusFrac,
      alpha: kDropBloomLaneAlpha,
    );
  }
}

void _paintFlare(
  Canvas canvas,
  Size size,
  double accent, {
  required double anchorX,
  required double radiusFrac,
  required double alpha,
}) {
  final bloom = accent.clamp(0.0, 1.0);
  if (bloom < 0.02) return;
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.radial(
        Offset(size.width * anchorX, size.height * 0.60),
        size.width * radiusFrac,
        [
          Color.fromRGBO(255, 216, 158, alpha * bloom),
          const Color.fromRGBO(255, 216, 158, 0),
        ],
        const [0.0, 1.0],
      ),
  );
}

/// Paints [paintDropBloom] into the live widget tree; repaints as the accent
/// changes so the flare animates with the music.
class DropBloomPainter extends CustomPainter {
  const DropBloomPainter(this.accent, {this.laneAccents});

  final double accent;

  /// Per-voice accents in SCREEN order; when set, one flare per voice.
  final List<double>? laneAccents;

  @override
  void paint(Canvas canvas, Size size) =>
      paintDropBloom(canvas, size, accent, laneAccents: laneAccents);

  @override
  bool shouldRepaint(DropBloomPainter oldDelegate) =>
      oldDelegate.accent != accent ||
      !listEquals(oldDelegate.laneAccents, laneAccents);
}
