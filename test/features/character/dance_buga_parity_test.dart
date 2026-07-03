import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dancing_cats/features/character/engine/autonomic.dart';
import 'package:dancing_cats/features/character/model/affine2d.dart';
import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/runtime/character_renderer.dart';
import 'package:dancing_cats/features/character/runtime/character_scene.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Grid-cell geometry, matching `frame_grid_test.dart`'s conventions so the
/// artifacts this test writes are directly comparable to that tool's output.
const _cellW = 240.0;
const _cellH = 320.0;
const double _hipsY = _cellH * 0.66;
const double _groundY = _cellH * 0.9;
const double _centreX = _cellW * 0.46;
const _scale = 0.62;
const _cols = 8;
const _bg = Color(0xFFF4F1EA);
const _ground = Color(0xFFD9D2C4);

double _sampleTime(Clip clip, int i, int n) {
  final span = clip.duration;
  return clip.loop ? span * i / n : span * i / (n - 1);
}

Future<ByteData> _rawFrame(
  CharacterScene scene,
  Clip clip,
  double timeSeconds,
) async {
  final frame = scene.frameAt(
    clip: clip,
    timeSeconds: timeSeconds,
    base: Affine2D.translation(
      _centreX,
      _hipsY,
    ).multiply(Affine2D.scale(_scale, _scale)),
  );
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(const Rect.fromLTWH(0, 0, _cellW, _cellH), Paint()..color = _bg)
    ..drawRect(
      const Rect.fromLTWH(0, _groundY, _cellW, _cellH - _groundY),
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
    _cellW.round(),
    _cellH.round(),
  );
  try {
    return (await image.toByteData())!;
  } finally {
    image.dispose();
  }
}

Future<Uint8List> _renderGrid(
  CharacterScene scene,
  Clip clip,
  int frames,
) async {
  final rows = (frames / _cols).ceil();
  final width = (_cellW * _cols).round();
  final height = (_cellH * rows).round();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = _bg,
    );

  for (var i = 0; i < frames; i++) {
    final col = i % _cols;
    final row = i ~/ _cols;
    final cx = col * _cellW;
    final cy = row * _cellH;
    final t = _sampleTime(clip, i, frames);
    final frame = scene.frameAt(
      clip: clip,
      timeSeconds: t,
      base: Affine2D.translation(
        cx + _centreX,
        cy + _hipsY,
      ).multiply(Affine2D.scale(_scale, _scale)),
    );
    canvas.drawRect(
      Rect.fromLTWH(cx, cy + _groundY, _cellW, _cellH - _groundY),
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

void main() {
  final before = CatClips.buga;
  final after = CatClips.bugaDataDrivenPreview;

  group('field-level parity', () {
    test('engine levers match', () {
      expect(after.duration, before.duration);
      expect(after.contactPinning, before.contactPinning);
      expect(after.supportFootWorldAnchor, before.supportFootWorldAnchor);
      expect(
        after.supportFootWorldAnchorStrength,
        before.supportFootWorldAnchorStrength,
      );
      expect(after.danceHeadBobScale, before.danceHeadBobScale);
      expect(after.danceHeadLevelClampMin, before.danceHeadLevelClampMin);
      expect(after.zOrderSwaps, before.zOrderSwaps);
      expect(after.locomotionSpeed, before.locomotionSpeed);
    });

    test('contactSpans match exactly (phase-mapped from frame data)', () {
      expect(after.contactSpans, hasLength(before.contactSpans.length));
      for (var i = 0; i < before.contactSpans.length; i++) {
        expect(after.contactSpans[i].bone, before.contactSpans[i].bone);
        expect(after.contactSpans[i].start, before.contactSpans[i].start);
        expect(after.contactSpans[i].end, before.contactSpans[i].end);
      }
    });

    test('limbTargets match by endBoneId (bone chain + bend direction)', () {
      expect(after.limbTargets, hasLength(before.limbTargets.length));
      for (final beforeTarget in before.limbTargets) {
        final afterTarget = after.limbTargets.firstWhere(
          (t) => t.endBoneId == beforeTarget.endBoneId,
        );
        expect(afterTarget.upperBoneId, beforeTarget.upperBoneId);
        expect(afterTarget.lowerBoneId, beforeTarget.lowerBoneId);
        expect(afterTarget.anchorBoneId, beforeTarget.anchorBoneId);
        expect(afterTarget.bendDirection, beforeTarget.bendDirection);
      }
    });

    test('bugaDataDrivenPreview is not part of the move catalog', () {
      // Both clips share the name 'buga' (required for runtime parity — see
      // the getter's doc comment), so catalog membership can't be told apart
      // by name. Assert the catalog still has exactly the one real entry:
      // if bugaDataDrivenPreview were ever added to CatClips.all, this count
      // would become 2.
      expect(CatClips.all.where((c) => c.name == 'buga'), hasLength(1));
    });
  });

  group('pixel parity', () {
    test('every sampled frame renders identically', () async {
      final scene = CharacterScene(
        buildCatInSuitRig(),
        autonomic: AutonomicLayer(seed: 11),
      );
      const frames = 32;
      for (var i = 0; i < frames; i++) {
        final t = _sampleTime(before, i, frames);
        final beforeBytes = await _rawFrame(scene, before, t);
        final afterBytes = await _rawFrame(scene, after, t);
        expect(
          afterBytes.buffer.asUint8List(),
          beforeBytes.buffer.asUint8List(),
          reason: 'frame $i (t=$t) differs between buga and its '
              'data-driven reproduction',
        );
      }
    });

    test('writes before/after grid PNGs for manual review', () async {
      final scene = CharacterScene(
        buildCatInSuitRig(),
        autonomic: AutonomicLayer(seed: 11),
      );
      final outputDir = Directory(
        Platform.environment['CHARACTER_STRIP_DIR'] ??
            'build/character_film_strips',
      )..createSync(recursive: true);
      const frames = 24;
      final beforeGrid = await _renderGrid(scene, before, frames);
      final afterGrid = await _renderGrid(scene, after, frames);
      File(
        '${outputDir.path}/buga_before_grid.png',
      ).writeAsBytesSync(beforeGrid);
      File(
        '${outputDir.path}/buga_after_grid.png',
      ).writeAsBytesSync(afterGrid);
    });
  });
}
