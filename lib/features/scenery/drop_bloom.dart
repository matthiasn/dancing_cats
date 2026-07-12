import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Warm additive flash centred on the dancers that spikes with the music accent
/// (biggest on the drops) — the punctuating drop "moment" the tempo-synced gel
/// pulse alone can't give, because the rim/pool intensity already saturates on
/// every beat (a drop could never out-punch a bar). Zero between hits, so it
/// only ever reads as a flare on the accent, then decays.
///
/// Single source of truth for BOTH paint paths: the live `DanceStageView` (via
/// [DropBloomPainter]) and the offline `DanceFrameComposer` (direct canvas), so
/// the flare can never drift between the running app and a render.
void paintDropBloom(Canvas canvas, Size size, double accent) {
  final bloom = accent.clamp(0.0, 1.0);
  if (bloom < 0.02) return;
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.radial(
        Offset(size.width / 2, size.height * 0.60),
        size.width * 0.52,
        [
          Color.fromRGBO(255, 216, 158, 0.26 * bloom),
          const Color.fromRGBO(255, 216, 158, 0),
        ],
        const [0.0, 1.0],
      ),
  );
}

/// Paints [paintDropBloom] into the live widget tree; repaints as the accent
/// changes so the flare animates with the music.
class DropBloomPainter extends CustomPainter {
  const DropBloomPainter(this.accent);

  final double accent;

  @override
  void paint(Canvas canvas, Size size) => paintDropBloom(canvas, size, accent);

  @override
  bool shouldRepaint(DropBloomPainter oldDelegate) =>
      oldDelegate.accent != accent;
}
