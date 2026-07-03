import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dancing_cats/features/character/model/affine2d.dart';
import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/runtime/character_renderer.dart';
import 'package:dancing_cats/features/character/runtime/character_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared rendering/assertion helpers for the `<move>DataDrivenPreview`
/// parity tests (`dance_move_parity_test.dart`): each shipped move's
/// hand-authored `Clip` compared against its reproduction assembled through
/// `assembleMoveClip`. Grid-cell geometry matches `frame_grid_test.dart`'s
/// conventions so the artifacts these tests write are directly comparable to
/// that tool's output.
const cellW = 240.0;
const cellH = 320.0;
const double hipsY = cellH * 0.66;
const double groundY = cellH * 0.9;
const double centreX = cellW * 0.46;
const gridScale = 0.62;
const gridCols = 8;
const _bg = Color(0xFFF4F1EA);
const _ground = Color(0xFFD9D2C4);

double sampleTime(Clip clip, int i, int n) {
  final span = clip.duration;
  return clip.loop ? span * i / n : span * i / (n - 1);
}

Future<ByteData> rawFrame(
  CharacterScene scene,
  Clip clip,
  double timeSeconds,
) async {
  final frame = scene.frameAt(
    clip: clip,
    timeSeconds: timeSeconds,
    base: Affine2D.translation(
      centreX,
      hipsY,
    ).multiply(Affine2D.scale(gridScale, gridScale)),
  );
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(const Rect.fromLTWH(0, 0, cellW, cellH), Paint()..color = _bg)
    ..drawRect(
      const Rect.fromLTWH(0, groundY, cellW, cellH - groundY),
      Paint()..color = _ground,
    );
  CharacterRenderer().paint(
    canvas,
    scene.rig,
    frame.world,
    frame.face,
    zOrderSwaps: frame.zOrderSwaps,
  );
  final image = await recorder.endRecording().toImage(
    cellW.round(),
    cellH.round(),
  );
  try {
    return (await image.toByteData())!;
  } finally {
    image.dispose();
  }
}

Future<Uint8List> renderGrid(
  CharacterScene scene,
  Clip clip,
  int frames,
) async {
  final rows = (frames / gridCols).ceil();
  final width = (cellW * gridCols).round();
  final height = (cellH * rows).round();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = _bg,
    );

  for (var i = 0; i < frames; i++) {
    final col = i % gridCols;
    final row = i ~/ gridCols;
    final cx = col * cellW;
    final cy = row * cellH;
    final t = sampleTime(clip, i, frames);
    final frame = scene.frameAt(
      clip: clip,
      timeSeconds: t,
      base: Affine2D.translation(
        cx + centreX,
        cy + hipsY,
      ).multiply(Affine2D.scale(gridScale, gridScale)),
    );
    canvas.drawRect(
      Rect.fromLTWH(cx, cy + groundY, cellW, cellH - groundY),
      Paint()..color = _ground,
    );
    CharacterRenderer().paint(
      canvas,
      scene.rig,
      frame.world,
      frame.face,
      zOrderSwaps: frame.zOrderSwaps,
    );
  }

  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(width, height);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}

/// Asserts every `Clip`-level construct not captured by channel sampling
/// (engine levers, contact spans, limb-target rig bindings) matches between
/// [before] (the shipped hand-authored clip) and [after] (its
/// `assembleMoveClip` reproduction).
void checkFieldParity(String label, Clip before, Clip after) {
  expect(after.duration, before.duration, reason: '$label duration');
  expect(
    after.contactPinning,
    before.contactPinning,
    reason: '$label contactPinning',
  );
  expect(
    after.supportFootWorldAnchor,
    before.supportFootWorldAnchor,
    reason: '$label supportFootWorldAnchor',
  );
  expect(
    after.supportFootWorldAnchorStrength,
    before.supportFootWorldAnchorStrength,
    reason: '$label supportFootWorldAnchorStrength',
  );
  expect(
    after.danceHeadBobScale,
    before.danceHeadBobScale,
    reason: '$label danceHeadBobScale',
  );
  expect(
    after.danceHeadLevelClampMin,
    before.danceHeadLevelClampMin,
    reason: '$label danceHeadLevelClampMin',
  );
  expect(after.zOrderSwaps, before.zOrderSwaps, reason: '$label zOrderSwaps');
  expect(
    after.locomotionSpeed,
    before.locomotionSpeed,
    reason: '$label locomotionSpeed',
  );

  expect(
    after.contactSpans,
    hasLength(before.contactSpans.length),
    reason: '$label contactSpans length',
  );
  for (var i = 0; i < before.contactSpans.length; i++) {
    expect(
      after.contactSpans[i].bone,
      before.contactSpans[i].bone,
      reason: '$label contactSpans[$i].bone',
    );
    expect(
      after.contactSpans[i].start,
      before.contactSpans[i].start,
      reason: '$label contactSpans[$i].start',
    );
    expect(
      after.contactSpans[i].end,
      before.contactSpans[i].end,
      reason: '$label contactSpans[$i].end',
    );
  }

  expect(
    after.limbTargets,
    hasLength(before.limbTargets.length),
    reason: '$label limbTargets length',
  );
  for (final beforeTarget in before.limbTargets) {
    final afterTarget = after.limbTargets.firstWhere(
      (t) => t.endBoneId == beforeTarget.endBoneId,
    );
    expect(
      afterTarget.upperBoneId,
      beforeTarget.upperBoneId,
      reason: '$label ${beforeTarget.endBoneId} upperBoneId',
    );
    expect(
      afterTarget.lowerBoneId,
      beforeTarget.lowerBoneId,
      reason: '$label ${beforeTarget.endBoneId} lowerBoneId',
    );
    expect(
      afterTarget.anchorBoneId,
      beforeTarget.anchorBoneId,
      reason: '$label ${beforeTarget.endBoneId} anchorBoneId',
    );
    expect(
      afterTarget.bendDirection,
      beforeTarget.bendDirection,
      reason: '$label ${beforeTarget.endBoneId} bendDirection',
    );
  }
}

/// Asserts every sampled frame across the cycle renders pixel-identically
/// between [before] and [after].
Future<void> checkPixelParity(
  String label,
  CharacterScene scene,
  Clip before,
  Clip after, {
  int frames = 32,
}) async {
  for (var i = 0; i < frames; i++) {
    final t = sampleTime(before, i, frames);
    final beforeBytes = await rawFrame(scene, before, t);
    final afterBytes = await rawFrame(scene, after, t);
    expect(
      afterBytes.buffer.asUint8List(),
      beforeBytes.buffer.asUint8List(),
      reason: '$label frame $i (t=$t) differs from its data-driven '
          'reproduction',
    );
  }
}
