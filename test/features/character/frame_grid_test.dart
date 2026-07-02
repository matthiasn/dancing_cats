import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dancing_cats/features/character/engine/autonomic.dart';
import 'package:dancing_cats/features/character/model/affine2d.dart';
import 'package:dancing_cats/features/character/model/bone.dart';
import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/face.dart';
import 'package:dancing_cats/features/character/model/rig_spec.dart';
import 'package:dancing_cats/features/character/runtime/character_painter.dart';
import 'package:dancing_cats/features/character/runtime/character_renderer.dart';
import 'package:dancing_cats/features/character/runtime/character_scene.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Controllable per-frame **contact-sheet** capture for motion review.
///
/// Where `film_strip_test.dart` lays one cycle in a single wide row, this tool
/// renders *every* sampled frame of a motion into a labelled grid (so timing,
/// spacing and pose-to-pose readability can be eyeballed at detail), plus an
/// **onion-skin** overlay per clip (all frames superimposed) that reveals the
/// arcs of the hands / feet / tail — the single most useful motion-debug view.
///
/// Everything is env-controllable so a reviewer can zoom into one motion:
///
/// | Env var              | Meaning                                  | Default |
/// | -------------------- | ---------------------------------------- | ------- |
/// | `CHARACTER_STRIP_DIR`| output directory                         | `build/character_film_strips` |
/// | `GRID_CLIPS`         | comma list of clips                    | all     |
/// | `GRID_FRAMES`        | frames per clip (override)               | 24 loop / 32 one-shot |
/// | `GRID_COLS`          | columns in the contact sheet             | 6       |
/// | `GRID_SCALE`         | character scale                          | 0.62    |
/// | `GRID_EXPRESSION`    | neutral/content/happy/surprised/sad/angry| content |
/// | `GRID_ONION`         | also write `<clip>_onion.png` (1/0)      | 1       |
/// | `GRID_DANCE_CAMERA`  | enable dance trio camera move (1/0)      | 1       |
/// | `GRID_VIEWS`         | comma list: front,quarter,quarterLeft,quarterRight,side,sideLeft,sideRight | front |
///
/// Run a single motion densely, for example:
/// ```sh
/// GRID_CLIPS=walk GRID_FRAMES=36 GRID_COLS=6 \
///   fvm flutter test test/features/character/frame_grid_test.dart
/// ```
class _ReviewView {
  const _ReviewView({
    required this.name,
    required this.fileSuffix,
    required this.foreshortenX,
    required this.shearX,
    this.depth = 0,
    this.facing = 1,
  });

  final String name;
  final String fileSuffix;
  final double foreshortenX;
  final double shearX;
  final double depth;
  final double facing;

  bool get isFront => fileSuffix.isEmpty;

  Affine2D baseAt({
    required double x,
    required double y,
    required double scale,
  }) {
    return Affine2D.translation(x, y).multiply(
      Affine2D(foreshortenX * scale, 0, shearX * scale, scale, 0, 0),
    );
  }
}

const _frontView = _ReviewView(
  name: 'front',
  fileSuffix: '',
  foreshortenX: 1,
  shearX: 0,
);

const _quarterView = _ReviewView(
  name: 'quarter',
  fileSuffix: 'quarter',
  foreshortenX: 0.74,
  shearX: 0.16,
  depth: 0.48,
);

const _quarterLeftView = _ReviewView(
  name: 'quarterLeft',
  fileSuffix: 'quarter_left',
  foreshortenX: 0.74,
  shearX: -0.16,
  depth: 0.48,
  facing: -1,
);

const _quarterRightView = _ReviewView(
  name: 'quarterRight',
  fileSuffix: 'quarter_right',
  foreshortenX: 0.74,
  shearX: 0.16,
  depth: 0.48,
);

const _sideView = _ReviewView(
  name: 'side',
  fileSuffix: 'side',
  foreshortenX: 0.56,
  shearX: 0.28,
  depth: 1,
);

const _sideLeftView = _ReviewView(
  name: 'sideLeft',
  fileSuffix: 'side_left',
  foreshortenX: 0.56,
  shearX: -0.28,
  depth: 1,
  facing: -1,
);

const _sideRightView = _ReviewView(
  name: 'sideRight',
  fileSuffix: 'side_right',
  foreshortenX: 0.56,
  shearX: 0.28,
  depth: 1,
);

void main() {
  // Cell geometry. Large enough to read a single pose; the body is ~310 units
  // tall at scale 1, so scale 0.62 → ~190px and fits with headroom + ground.
  const cellW = 240.0;
  const cellH = 320.0;
  const bg = Color(0xFFF4F1EA);
  const ground = Color(0xFFD9D2C4);
  const cellLine = Color(0x14000000);
  const labelColor = Color(0xFF555049);

  // Character placement within a cell. Hips sit high enough that the feet land
  // near the ground line; centred slightly left so the tail has room at right.
  const hipsY = cellH * 0.66;
  const groundY = cellH * 0.9;
  const centreX = cellW * 0.46;

  final env = Platform.environment;
  final outputDir = Directory(
    env['CHARACTER_STRIP_DIR'] ?? 'build/character_film_strips',
  );
  final cols = int.tryParse(env['GRID_COLS'] ?? '') ?? 6;
  final scale = double.tryParse(env['GRID_SCALE'] ?? '') ?? 0.62;
  final onion = (env['GRID_ONION'] ?? '1') != '0';
  final labels = (env['GRID_LABELS'] ?? '0') == '1';
  // When set, also write a numbered full-frame PNG sequence per clip into
  // `seq_<clip>/` so ffmpeg can stitch a watchable GIF/APNG of the motion.
  final frameSeq = (env['GRID_FRAMESEQ'] ?? '0') == '1';
  // Also write `<clip>_live.png`: a representative frame through the real
  // CharacterPainter (floor band + contact shadow + grounded framing) so the
  // offline review matches the live demo exactly.
  final live = (env['GRID_LIVE'] ?? '1') == '1';
  final enableDanceCamera = (env['GRID_DANCE_CAMERA'] ?? '1') != '0';
  final expression = _expressionByName(env['GRID_EXPRESSION'] ?? 'content');
  final reviewViews = _reviewViewsByName(
    env['GRID_VIEWS'] ?? env['GRID_VIEW'] ?? 'front',
  );

  final clipsByName = <String, Clip>{
    for (final c in CatClips.all) c.name: c,
  };
  final selected = (env['GRID_CLIPS'] ?? clipsByName.keys.join(','))
      .split(',')
      .map((s) => s.trim())
      .where(clipsByName.containsKey)
      .toList();

  ui.Image? waterfrontBackdropImage;
  ui.Image? waterfrontCloudsImage;
  ui.Image? waterfrontWavesImage;

  setUpAll(() async {
    outputDir.createSync(recursive: true);
    if (live) {
      waterfrontBackdropImage = await _imageFromFile(
        kCharacterWaterfrontBackdropAsset,
      );
      waterfrontCloudsImage = await _optionalImageFromFile(
        kCharacterWaterfrontCloudsAsset,
      );
      waterfrontWavesImage = await _optionalImageFromFile(
        kCharacterWaterfrontWavesAsset,
      );
    }
  });

  tearDownAll(() {
    waterfrontBackdropImage?.dispose();
    waterfrontCloudsImage?.dispose();
    waterfrontWavesImage?.dispose();
  });

  // The phase-sample time for frame [i] of [n], matching the film-strip
  // convention: loops sample [0, span) (the wrap frame == frame 0, omitted),
  // one-shots sample [0, span] inclusive so the terminal pose is shown.
  double sampleTime(Clip clip, int i, int n, double span) {
    if (n <= 1) return 0;
    return clip.loop ? span * i / n : span * i / (n - 1);
  }

  // Places frame [i]'s character at the centre of its grid cell.
  Affine2D cellBase(int i, _ReviewView view) {
    final col = i % cols;
    final row = i ~/ cols;
    return view.baseAt(
      x: col * cellW + centreX,
      y: row * cellH + hipsY,
      scale: scale,
    );
  }

  void drawLabel(Canvas canvas, String text, double x, double y) {
    TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: labelColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )
      ..layout()
      ..paint(canvas, Offset(x, y));
  }

  // Renders the full contact sheet for [clip]: one labelled cell per frame.
  Future<Uint8List> renderGrid(
    CharacterScene scene,
    Clip clip,
    int frames,
    _ReviewView view,
  ) async {
    final rows = (frames / cols).ceil();
    final width = cellW * cols;
    final height = cellH * rows;
    final span = clip.duration;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final renderer = CharacterRenderer();

    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = bg,
    );

    for (var i = 0; i < frames; i++) {
      final col = i % cols;
      final row = i ~/ cols;
      final cx = col * cellW;
      final cy = row * cellH;
      // Per-cell ground strip + separators so each pose reads on its own.
      canvas
        ..drawRect(
          Rect.fromLTWH(cx, cy + groundY, cellW, cellH - groundY),
          Paint()..color = ground,
        )
        ..drawRect(
          Rect.fromLTWH(cx, cy, cellW, 1),
          Paint()..color = cellLine,
        )
        ..drawRect(
          Rect.fromLTWH(cx, cy, 1, cellH),
          Paint()..color = cellLine,
        );

      final t = sampleTime(clip, i, frames, span);
      final p = clip.duration <= 0 ? 0.0 : (t / clip.duration);
      final base = cellBase(i, view);
      final frame = scene.frameAt(
        clip: clip,
        timeSeconds: t,
        expression: expression,
        base: base,
      );
      final reviewWorld = _projectReviewWorld(frame.world, view, scale);
      _paintReviewContactShadows(
        canvas,
        scene.rig,
        clip,
        reviewWorld,
        p,
        scale,
        view,
      );
      renderer.paint(
        canvas,
        scene.rig,
        reviewWorld,
        frame.face,
        memberTransform: base,
      );

      drawLabel(
        canvas,
        '#$i  p=${p.toStringAsFixed(2)}  ${view.name}',
        cx + 6,
        cy + 5,
      );
    }

    return _pngOf(recorder.endRecording(), width.round(), height.round());
  }

  // Onion-skin overlay: every frame superimposed at low opacity so the motion
  // arcs (hand / foot / tail paths) and any foot-skate are visible at a glance.
  // Frames fade from old (faint) to current (stronger); the final pose is solid.
  Future<Uint8List> renderOnion(
    CharacterScene scene,
    Clip clip,
    int frames,
    _ReviewView view,
  ) async {
    final span = clip.duration;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final renderer = CharacterRenderer();

    canvas
      ..drawRect(
        const Rect.fromLTWH(0, 0, cellW, cellH),
        Paint()..color = bg,
      )
      ..drawRect(
        const Rect.fromLTWH(0, groundY, cellW, cellH - groundY),
        Paint()..color = ground,
      );

    final base = view.baseAt(x: centreX, y: hipsY, scale: scale);

    for (var i = 0; i < frames; i++) {
      final t = sampleTime(clip, i, frames, span);
      final frame = scene.frameAt(
        clip: clip,
        timeSeconds: t,
        expression: expression,
        base: base,
      );
      final reviewWorld = _projectReviewWorld(frame.world, view, scale);
      final last = i == frames - 1;
      // Fade ramp: oldest ~10%, newest ~45%, final pose fully solid.
      final alpha = last ? 1.0 : 0.10 + 0.35 * (i / (frames - 1));
      canvas.saveLayer(
        const Rect.fromLTWH(0, 0, cellW, cellH),
        Paint()..color = Color.fromRGBO(0, 0, 0, alpha),
      );
      renderer.paint(
        canvas,
        scene.rig,
        reviewWorld,
        frame.face,
        memberTransform: base,
      );
      canvas.restore();
    }

    drawLabel(canvas, 'onion: ${clip.name} ${view.name} ($frames)', 6, 5);
    return _pngOf(recorder.endRecording(), cellW.round(), cellH.round());
  }

  // A single full-cell frame (no labels/separators) for assembling a GIF/APNG.
  Future<Uint8List> renderFrame(
    CharacterScene scene,
    Clip clip,
    int i,
    int frames,
    _ReviewView view,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final renderer = CharacterRenderer();
    canvas
      ..drawRect(const Rect.fromLTWH(0, 0, cellW, cellH), Paint()..color = bg)
      ..drawRect(
        const Rect.fromLTWH(0, groundY, cellW, cellH - groundY),
        Paint()..color = ground,
      );
    final base = view.baseAt(x: centreX, y: hipsY, scale: scale);
    final frame = scene.frameAt(
      clip: clip,
      timeSeconds: sampleTime(clip, i, frames, clip.duration),
      expression: expression,
      base: base,
    );
    final p = clip.duration <= 0
        ? 0.0
        : sampleTime(clip, i, frames, clip.duration) / clip.duration;
    final reviewWorld = _projectReviewWorld(frame.world, view, scale);
    _paintReviewContactShadows(
      canvas,
      scene.rig,
      clip,
      reviewWorld,
      p,
      scale,
      view,
    );
    renderer.paint(
      canvas,
      scene.rig,
      reviewWorld,
      frame.face,
      memberTransform: base,
    );
    return _pngOf(recorder.endRecording(), cellW.round(), cellH.round());
  }

  // Renders one frame through the real CharacterPainter at a demo-like stage
  // size, so the floor + contact shadow + auto-fit framing match the live view.
  Future<Uint8List> renderLive(
    CharacterScene scene,
    CharacterScene partnerScene,
    CharacterScene thirdScene,
    Clip clip,
  ) async {
    final danceTrio = _isCatalogueDanceClip(clip);
    final w = danceTrio ? 760.0 : 360.0;
    const h = 520.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()..color = const Color(0xFF26303A),
      );
    CharacterPainter(
      scene: scene,
      clip: clip,
      timeSeconds: clip.duration * 0.5,
      expression: expression,
      scale: h * 0.78 / 300.0,
      groundColor: const Color(0xFF374551),
      backdrop: danceTrio
          ? CharacterBackdrop.waterfront
          : CharacterBackdrop.none,
      backdropImage: danceTrio ? waterfrontBackdropImage : null,
      backdropCloudsImage: danceTrio ? waterfrontCloudsImage : null,
      backdropWavesImage: danceTrio ? waterfrontWavesImage : null,
      walkingPair: danceTrio,
      partnerScene: partnerScene,
      ensembleScenes: danceTrio ? [partnerScene, thirdScene] : const [],
      ensembleClips: danceTrio ? [clip, clip, clip] : const [],
      ensembleExpressions: danceTrio
          ? _ensembleExpressionsAt(clip.duration * 0.5, expression)
          : const [],
      synchronousEnsemble: danceTrio,
      enableDanceCamera: enableDanceCamera,
    ).paint(canvas, Size(w, h));
    return _pngOf(recorder.endRecording(), w.round(), h.round());
  }

  // A contact sheet through the real live painter. Unlike `renderGrid`, this
  // shows the actual ensemble staging, expressions, blink/look seeds, floor,
  // contact shadows, and spacing the demo uses.
  Future<Uint8List> renderLiveGrid(
    CharacterScene scene,
    CharacterScene partnerScene,
    CharacterScene thirdScene,
    Clip clip,
    int frames,
  ) async {
    const liveW = 520.0;
    const liveH = 420.0;
    final rows = (frames / cols).ceil();
    final width = liveW * cols;
    final height = liveH * rows;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawRect(
        Rect.fromLTWH(0, 0, width, height),
        Paint()..color = const Color(0xFF26303A),
      );

    for (var i = 0; i < frames; i++) {
      final col = i % cols;
      final row = i ~/ cols;
      final dx = col * liveW;
      final dy = row * liveH;
      final t = sampleTime(clip, i, frames, clip.duration);
      final p = clip.duration <= 0 ? 0.0 : t / clip.duration;

      canvas
        ..save()
        ..translate(dx, dy)
        ..clipRect(const Rect.fromLTWH(0, 0, liveW, liveH))
        ..drawRect(
          const Rect.fromLTWH(0, 0, liveW, liveH),
          Paint()..color = const Color(0xFF26303A),
        );

      CharacterPainter(
        scene: scene,
        clip: clip,
        timeSeconds: t,
        expression: expression,
        scale: liveH * 0.78 / 300.0,
        groundColor: const Color(0xFF374551),
        backdrop: CharacterBackdrop.waterfront,
        backdropImage: waterfrontBackdropImage,
        backdropCloudsImage: waterfrontCloudsImage,
        backdropWavesImage: waterfrontWavesImage,
        walkingPair: true,
        partnerScene: partnerScene,
        ensembleScenes: [partnerScene, thirdScene],
        ensembleClips: [clip, clip, clip],
        ensembleExpressions: _ensembleExpressionsAt(t, expression),
        synchronousEnsemble: true,
        enableDanceCamera: enableDanceCamera,
      ).paint(canvas, const Size(liveW, liveH));

      if (labels) {
        drawLabel(
          canvas,
          '#$i  p=${p.toStringAsFixed(2)}',
          8,
          liveH - 22,
        );
      }
      canvas.restore();
    }

    return _pngOf(recorder.endRecording(), width.round(), height.round());
  }

  // Travel onion: overlays the cat at successive times with locomotion ON, so a
  // PLANTED foot appears as a crisp footprint (it holds world-x through stance)
  // while the body blurs forward. A smeared foot band = residual foot-skate.
  Future<Uint8List> renderTravel(CharacterScene scene, Clip clip) async {
    const w = 360.0;
    const h = 240.0;
    const margin = 64.0;
    const sc = h * 0.62 / 300.0;
    const floorY = h * 0.9;
    const band = w - 2 * margin;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = bg)
      ..drawRect(
        const Rect.fromLTWH(0, floorY, w, h - floorY),
        Paint()..color = ground,
      );
    final renderer = CharacterRenderer();
    const frames = 36;
    final total = clip.duration * 2.4; // a couple of strides
    for (var i = 0; i < frames; i++) {
      final t = total * i / frames;
      final travelPx = scene.locomotionOffset(clip, t).abs() * sc;
      final cyc = travelPx % (2 * band);
      final movingRight = cyc <= band;
      final pos = movingRight ? cyc : 2 * band - cyc;
      // Mirror while moving +x, mirroring the painter's facing so the onion
      // reflects the real runtime (foot should hold still).
      final base = Affine2D.translation(
        margin + pos,
        floorY - scene.restFeetOffset * sc,
      ).multiply(Affine2D.scale(movingRight ? -sc : sc, sc));
      final frame = scene.frameAt(
        clip: clip,
        timeSeconds: t,
        expression: expression,
        base: base,
      );
      final alpha = 0.1 + 0.5 * (i / (frames - 1));
      canvas.saveLayer(
        const Rect.fromLTWH(0, 0, w, h),
        Paint()..color = Color.fromRGBO(0, 0, 0, alpha),
      );
      renderer.paint(
        canvas,
        scene.rig,
        frame.world,
        frame.face,
        memberTransform: base,
      );
      canvas.restore();
    }
    drawLabel(canvas, 'travel: ${clip.name}', 6, 5);
    return _pngOf(recorder.endRecording(), w.round(), h.round());
  }

  test('review view parsing includes stronger quarter and side angles', () {
    final views = _reviewViewsByName(
      'front,quarter,quarter-left,side,side_right,profile,unknown',
    );

    expect(
      views.map((view) => view.name),
      ['front', 'quarter', 'quarterLeft', 'side', 'sideRight'],
    );
    expect(
      _quarterView.foreshortenX,
      lessThan(_frontView.foreshortenX),
      reason:
          'quarter view should visibly narrow the body, not duplicate front',
    );
    expect(
      _sideView.foreshortenX,
      lessThan(_quarterView.foreshortenX),
      reason: 'side/profile review should be more oblique than quarter review',
    );
    expect(_sideLeftView.shearX, lessThan(0));
    expect(_sideRightView.shearX, greaterThan(0));
  });

  test(
    'review view transforms preserve the floor while skewing upper body',
    () {
      const x = 100.0;
      const y = 200.0;
      const scale = 0.5;
      final front = _frontView.baseAt(x: x, y: y, scale: scale);
      final quarter = _quarterView.baseAt(x: x, y: y, scale: scale);
      final side = _sideView.baseAt(x: x, y: y, scale: scale);

      final frontGround = front.transformPoint(0, 120);
      final quarterGround = quarter.transformPoint(0, 120);
      final sideGround = side.transformPoint(0, 120);
      expect(quarterGround.y, frontGround.y);
      expect(sideGround.y, frontGround.y);

      const upperBody = (x: 0.0, y: -120.0);
      final frontUpper = front.transformPoint(upperBody.x, upperBody.y);
      final quarterUpper = quarter.transformPoint(upperBody.x, upperBody.y);
      final sideUpper = side.transformPoint(upperBody.x, upperBody.y);
      expect(
        (quarterUpper.x - frontUpper.x).abs(),
        greaterThan(8),
        reason:
            'quarter view should make upper-body occlusion differences visible',
      );
      expect(
        (sideUpper.x - frontUpper.x).abs(),
        greaterThan((quarterUpper.x - frontUpper.x).abs()),
        reason: 'side/profile view should exaggerate the review angle further',
      );
    },
  );

  test('review depth projection separates near and far contact feet', () {
    final world = {
      CatBones.footL: Affine2D.translation(100, 200),
      CatBones.footR: Affine2D.translation(100, 200),
      CatBones.legUpperL: Affine2D.translation(100, 170),
      CatBones.legUpperR: Affine2D.translation(100, 170),
      CatBones.hips: Affine2D.translation(100, 150),
      CatBones.torso: Affine2D.translation(100, 90),
      CatBones.handL: Affine2D.translation(100, 120),
      CatBones.handR: Affine2D.translation(100, 120),
    };

    expect(_projectReviewWorld(world, _frontView, 1), same(world));

    final side = _projectReviewWorld(world, _sideView, 1);
    expect(
      side[CatBones.footL]!.origin.x - side[CatBones.footR]!.origin.x,
      greaterThan(78),
      reason:
          'side review needs explicit left/right shoe separation, not just '
          'global foreshortening',
    );
    expect(
      side[CatBones.legUpperL]!.origin.x - side[CatBones.legUpperR]!.origin.x,
      greaterThan(54),
      reason:
          'near/far thighs need enough offset to keep side poses from reading '
          'as one dark trouser tube',
    );
    expect(
      side[CatBones.torso]!.origin.x - side[CatBones.hips]!.origin.x,
      greaterThan(16),
      reason:
          'side review should separate chest mass from pelvis mass instead of '
          'stacking the whole body into one column',
    );
    expect(
      side[CatBones.handL]!.origin.x - side[CatBones.handR]!.origin.x,
      greaterThan(88),
      reason: 'hands should pull clear of the torso silhouette in side review',
    );

    final sideLeft = _projectReviewWorld(world, _sideLeftView, 1);
    expect(
      sideLeft[CatBones.footL]!.origin.x - sideLeft[CatBones.footR]!.origin.x,
      lessThan(-78),
      reason: 'left-facing side review should mirror the depth offsets',
    );
    expect(
      sideLeft[CatBones.torso]!.origin.x - sideLeft[CatBones.hips]!.origin.x,
      lessThan(-16),
      reason: 'left-facing side review should mirror torso/pelvis separation',
    );
  });

  test('review contact lookup follows authored support spans', () {
    final buga = CatClips.buga;

    // Buga hands the support foot off ON the hits (f12/f28) so the tall
    // present is never re-planted against a deep-sink span anchor.
    expect(_activeContactBone(buga, 0.10), CatBones.footR);
    expect(_activeContactBone(buga, 0.30), CatBones.footL);
    expect(_activeContactBone(buga, 0.40), CatBones.footR);
    expect(_activeContactBone(buga, 0.625), CatBones.footL);
    expect(_activeContactBone(buga, 0.80), CatBones.footR);
    expect(_activeContactBone(buga, 0.90), CatBones.footL);
  });

  testWidgets('renders per-frame contact-sheet grids', (tester) async {
    await tester.runAsync(() async {
      for (final name in selected) {
        final clip = clipsByName[name]!;
        final catalogueDance = _isCatalogueDanceClip(clip);
        // Mirror the shipped cast: limb thickness follows each lane's staged
        // plane scale (lead = the front reference, flankers upstage).
        final flankThickness = limbThicknessForPlaneScale(
          danceLanePlaneScale(0, 3) / danceLanePlaneScale(1, 3),
        );
        final scene = CharacterScene(
          buildCatInSuitRig(),
          autonomic: _reviewAutonomic(11),
        );
        final partnerScene = CharacterScene(
          buildCatInSuitRig(
            palette: CatInSuitPalette.silverTabby,
            legWidthScale: catalogueDance ? flankThickness : 1,
            armWidthScale: catalogueDance ? flankThickness : 1,
          ),
          autonomic: _reviewAutonomic(29),
        );
        final thirdScene = CharacterScene(
          buildCatInSuitRig(
            palette: CatInSuitPalette.darkBrown,
            legWidthScale: catalogueDance ? flankThickness : 1,
            armWidthScale: catalogueDance ? flankThickness : 1,
          ),
          autonomic: _reviewAutonomic(47),
        );
        final frames =
            int.tryParse(env['GRID_FRAMES'] ?? '') ?? (clip.loop ? 24 : 32);

        for (final view in reviewViews) {
          final grid = await renderGrid(scene, clip, frames, view);
          final gridPath = _viewedPngPath(outputDir, name, view, 'grid');
          File(gridPath).writeAsBytesSync(grid);
          expect(
            await _nonBlankPixels(grid),
            greaterThan(2000),
            reason: '$name ${view.name} grid should paint the character',
          );
          // ignore: avoid_print
          print('wrote $gridPath ($frames frames)');

          if (onion) {
            final onionPng = await renderOnion(scene, clip, frames, view);
            final onionPath = _viewedPngPath(outputDir, name, view, 'onion');
            File(onionPath).writeAsBytesSync(onionPng);
            // ignore: avoid_print
            print('wrote $onionPath');
          }

          if (frameSeq) {
            final seqDir = Directory(
              '${outputDir.path}/seq_$name${_viewDirSuffix(view)}',
            )..createSync(recursive: true);
            for (var i = 0; i < frames; i++) {
              final png = await renderFrame(scene, clip, i, frames, view);
              File(
                '${seqDir.path}/f${i.toString().padLeft(3, '0')}.png',
              ).writeAsBytesSync(png);
            }
            // ignore: avoid_print
            print('wrote ${seqDir.path}/ ($frames frames)');
          }
        }

        if (live) {
          final livePng = await renderLive(
            scene,
            partnerScene,
            thirdScene,
            clip,
          );
          File('${outputDir.path}/${name}_live.png').writeAsBytesSync(livePng);
          // ignore: avoid_print
          print('wrote ${outputDir.path}/${name}_live.png');

          if (_isCatalogueDanceClip(clip)) {
            final liveGridPng = await renderLiveGrid(
              scene,
              partnerScene,
              thirdScene,
              clip,
              frames,
            );
            File(
              '${outputDir.path}/${name}_ensemble_grid.png',
            ).writeAsBytesSync(liveGridPng);
            // ignore: avoid_print
            print('wrote ${outputDir.path}/${name}_ensemble_grid.png');
          }
        }

        if (live && clip.locomotionSpeed != 0) {
          final travelPng = await renderTravel(scene, clip);
          File(
            '${outputDir.path}/${name}_travel.png',
          ).writeAsBytesSync(travelPng);
          // ignore: avoid_print
          print('wrote ${outputDir.path}/${name}_travel.png');
        }
      }
    });
  });
}

bool _isCatalogueDanceClip(Clip clip) =>
    clip.name == CatClips.shaku.name ||
    clip.name == CatClips.zanku.name ||
    clip.name == CatClips.azonto.name ||
    clip.name == CatClips.buga.name ||
    clip.name == CatClips.sekem.name;

Map<String, Affine2D> _projectReviewWorld(
  Map<String, Affine2D> world,
  _ReviewView view,
  double scale,
) {
  if (view.depth <= 0) return world;

  return {
    for (final entry in world.entries)
      entry.key: _translateForReviewDepth(
        entry.value,
        _reviewDepthOffset(entry.key, view, scale),
      ),
  };
}

Affine2D _translateForReviewDepth(
  Affine2D transform,
  ({double x, double y}) offset,
) {
  if (offset.x == 0 && offset.y == 0) return transform;
  return Affine2D.translation(offset.x, offset.y).multiply(transform);
}

({double x, double y}) _reviewDepthOffset(
  String boneId,
  _ReviewView view,
  double scale,
) {
  final depth = view.depth * view.facing * scale;
  final settleY = view.depth * scale;

  double side(double units) => units * depth;

  if (_leftFootBones.contains(boneId)) {
    return (x: side(42), y: settleY * 1.45);
  }
  if (_rightFootBones.contains(boneId)) {
    return (x: -side(42), y: settleY * 1.45);
  }
  if (_leftLegBones.contains(boneId)) {
    return (x: side(30), y: settleY * 0.8);
  }
  if (_rightLegBones.contains(boneId)) {
    return (x: -side(30), y: settleY * 0.8);
  }
  if (_leftHandBones.contains(boneId)) {
    return (x: side(48), y: -settleY * 0.4);
  }
  if (_rightHandBones.contains(boneId)) {
    return (x: -side(48), y: -settleY * 0.4);
  }
  if (_leftArmBones.contains(boneId)) {
    return (x: side(36), y: -settleY * 0.28);
  }
  if (_rightArmBones.contains(boneId)) {
    return (x: -side(36), y: -settleY * 0.28);
  }
  if (_torsoDepthBones.contains(boneId)) {
    return (x: side(10), y: -settleY * 0.5);
  }
  if (_pelvisDepthBones.contains(boneId)) {
    return (x: -side(8), y: settleY * 0.38);
  }
  if (_tailBones.contains(boneId)) {
    return (x: -side(22), y: settleY * 2.0);
  }
  if (_headSideBones.contains(boneId)) {
    final sideSign = boneId.endsWith('.L') ? 1.0 : -1.0;
    return (x: side(6 * sideSign), y: -settleY * 0.4);
  }
  return (x: 0, y: 0);
}

void _paintReviewContactShadows(
  Canvas canvas,
  RigSpec rig,
  Clip clip,
  Map<String, Affine2D> world,
  double phase,
  double scale,
  _ReviewView view,
) {
  if (clip.contactSpans.isEmpty) return;
  final activeBone = _activeContactBone(clip, phase);
  final footBones = {
    for (final span in clip.contactSpans) span.bone,
  };

  for (final boneId in footBones) {
    final transform = world[boneId];
    final drawable = rig.bone(boneId)?.drawable;
    if (transform == null || drawable == null) continue;

    final contact = _drawableFootContact(transform, drawable);
    final active = boneId == activeBone;
    final width = (active ? 72.0 : 38.0) * scale * (1 + 0.08 * view.depth);
    final height = (active ? 9.5 : 5.5) * scale;
    final alpha = active ? 0x56 : 0x22;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(contact.x, contact.y + 2.5 * scale),
        width: width,
        height: height,
      ),
      Paint()..color = Color.fromARGB(alpha, 35, 41, 54),
    );
    if (active) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(contact.x, contact.y + 2.0 * scale),
          width: width * 0.46,
          height: height * 0.56,
        ),
        Paint()..color = const Color.fromARGB(0x5E, 16, 20, 29),
      );
    }
  }
}

String? _activeContactBone(Clip clip, double phase) {
  if (clip.contactSpans.isEmpty || clip.duration < 0) return null;
  final normalized = clip.loop
      ? phase - phase.floorToDouble()
      : phase.clamp(0.0, 1.0 - 1e-9);

  for (final span in clip.contactSpans) {
    if (_spanContainsPhase(span, normalized)) return span.bone;
  }
  return null;
}

bool _spanContainsPhase(GroundSpan span, double phase) {
  if (span.start <= span.end) {
    return phase >= span.start && phase < span.end;
  }
  return phase >= span.start || phase < span.end;
}

({double x, double y}) _drawableFootContact(
  Affine2D transform,
  BoneDrawable drawable,
) => transform.transformPoint(
  drawable.dx,
  drawable.dy + drawable.height / 2,
);

const Set<String> _leftFootBones = {
  CatBones.footL,
  CatBones.shoeHighlightL,
};

const Set<String> _rightFootBones = {
  CatBones.footR,
  CatBones.shoeHighlightR,
};

const Set<String> _leftLegBones = {
  CatBones.legUpperL,
  CatBones.legQuadL,
  CatBones.legLowerL,
  CatBones.legCalfL,
};

const Set<String> _rightLegBones = {
  CatBones.legUpperR,
  CatBones.legQuadR,
  CatBones.legLowerR,
  CatBones.legCalfR,
};

const Set<String> _leftArmBones = {
  CatBones.armUpperL,
  CatBones.armBicepL,
  CatBones.armLowerL,
  CatBones.armForearmL,
  CatBones.armElbowCreaseL,
};

const Set<String> _rightArmBones = {
  CatBones.armUpperR,
  CatBones.armBicepR,
  CatBones.armLowerR,
  CatBones.armForearmR,
  CatBones.armElbowCreaseR,
};

const Set<String> _torsoDepthBones = {
  CatBones.torso,
  CatBones.shirtV,
  CatBones.collarL,
  CatBones.collarR,
  CatBones.lapelL,
  CatBones.lapelR,
  CatBones.button0,
  CatBones.button1,
  CatBones.tie,
  CatBones.tieLower,
  CatBones.neck,
};

const Set<String> _pelvisDepthBones = {
  CatBones.hips,
};

const Set<String> _leftHandBones = {
  CatBones.handL,
  CatBones.wristCuffL,
  CatBones.thumbL,
  CatBones.pawToeL1,
  CatBones.pawToeL2,
};

const Set<String> _rightHandBones = {
  CatBones.handR,
  CatBones.wristCuffR,
  CatBones.thumbR,
  CatBones.pawToeR1,
  CatBones.pawToeR2,
};

const Set<String> _tailBones = {
  CatBones.tail0,
  CatBones.tail1,
  CatBones.tail2,
  CatBones.tail3,
  CatBones.tail4,
  CatBones.tail5,
  CatBones.tail6,
};

const Set<String> _headSideBones = {
  CatBones.earL,
  CatBones.earInnerL,
  CatBones.earR,
  CatBones.earInnerR,
};

List<_ReviewView> _reviewViewsByName(String value) {
  final views = <_ReviewView>[];
  for (final rawName in value.split(',')) {
    final name = rawName.trim().replaceAll('-', '').replaceAll('_', '');
    final view = switch (name.toLowerCase()) {
      'front' => _frontView,
      'quarter' => _quarterView,
      'quarterleft' || 'leftquarter' => _quarterLeftView,
      'quarterright' || 'rightquarter' => _quarterRightView,
      'side' || 'profile' => _sideView,
      'sideleft' ||
      'leftside' ||
      'profileleft' ||
      'leftprofile' => _sideLeftView,
      'sideright' ||
      'rightside' ||
      'profileright' ||
      'rightprofile' => _sideRightView,
      _ => null,
    };
    if (view == null) continue;
    if (!views.any((existing) => existing.fileSuffix == view.fileSuffix)) {
      views.add(view);
    }
  }
  return views.isEmpty ? const [_frontView] : views;
}

String _viewedPngPath(
  Directory outputDir,
  String clipName,
  _ReviewView view,
  String kind,
) {
  final suffix = view.isFront ? '' : '_${view.fileSuffix}';
  return '${outputDir.path}/$clipName${suffix}_$kind.png';
}

String _viewDirSuffix(_ReviewView view) =>
    view.isFront ? '' : '_${view.fileSuffix}';

Expression _expressionByName(String name) => Expression.presets.firstWhere(
  (e) => e.name == name,
  orElse: () => Expression.content,
);

AutonomicLayer _reviewAutonomic(int seed) => AutonomicLayer(
  seed: seed,
  blinkIntervalBase: 1.7,
  blinkIntervalJitter: 1.1,
  eyeDartInterval: 1.05,
  eyeDartAmplitude: 0.75,
);

List<Expression> _ensembleExpressionsAt(double seconds, Expression lead) {
  const seeds = [Expression.neutral, Expression.content, Expression.happy];
  const offsets = [0.0, 0.65, 1.15];
  const period = 1.45;
  return [
    _cycledExpression(lead, seconds + offsets[0], period),
    for (var i = 1; i < seeds.length; i++)
      _cycledExpression(seeds[i], seconds + offsets[i], period),
  ];
}

Expression _cycledExpression(
  Expression seedExpression,
  double seconds,
  double period,
) {
  const presets = [
    Expression.neutral,
    Expression.content,
    Expression.happy,
    Expression.surprised,
  ];
  final base = presets.indexWhere((e) => e.name == seedExpression.name);
  final phase = (seconds / period).floor();
  return presets[((base < 0 ? 0 : base) + phase) % presets.length];
}

Future<Uint8List> _pngOf(ui.Picture picture, int w, int h) async {
  try {
    final image = await picture.toImage(w, h);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes!.buffer.asUint8List();
  } finally {
    picture.dispose();
  }
}

Future<ui.Image> _imageFromFile(String path) async {
  final bytes = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<ui.Image?> _optionalImageFromFile(String path) async {
  if (!File(path).existsSync()) return null;
  return _imageFromFile(path);
}

// Counts pixels that are neither background nor ground (within tolerance) —
// i.e. pixels the character actually painted. Mirrors the film-strip check.
Future<int> _nonBlankPixels(Uint8List png) async {
  const tol = 24;
  const bgRgb = [0xF4, 0xF1, 0xEA];
  const groundRgb = [0xD9, 0xD2, 0xC4];
  bool near(int r, int g, int b, List<int> c) =>
      (r - c[0]).abs() <= tol &&
      (g - c[1]).abs() <= tol &&
      (b - c[2]).abs() <= tol;

  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData();
  frame.image.dispose();
  codec.dispose();
  final bytes = data!.buffer.asUint8List();

  var count = 0;
  for (var i = 0; i + 3 < bytes.length; i += 4) {
    if (near(bytes[i], bytes[i + 1], bytes[i + 2], bgRgb) ||
        near(bytes[i], bytes[i + 1], bytes[i + 2], groundRgb)) {
      continue;
    }
    count++;
  }
  return count;
}
