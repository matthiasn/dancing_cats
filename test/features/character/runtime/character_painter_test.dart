import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dancing_cats/features/character/demo/dance_camera_director.dart';
import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/face.dart';
import 'package:dancing_cats/features/character/runtime/character_painter.dart';
import 'package:dancing_cats/features/character/runtime/character_renderer.dart';
import 'package:dancing_cats/features/character/runtime/character_scene.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;

/// A random parallax case: a director shot plus a plane depth in [0, 1], for the
/// generative invariants over [CharacterPainter.danceParallaxMatrixForShotAtDepth].
extension _AnyParallax on glados.Any {
  glados.Generator<({double zoom, double dx, double dy, double depth})>
  get parallaxCase => glados.CombinableAny(this).combine4(
    glados.DoubleAnys(this).doubleInRange(1, 2.4),
    glados.DoubleAnys(this).doubleInRange(-500, 500),
    glados.DoubleAnys(this).doubleInRange(-60, 60),
    glados.DoubleAnys(this).doubleInRange(0, 1),
    (z, dx, dy, d) => (zoom: z, dx: dx, dy: dy, depth: d),
  );
}

void main() {
  late CharacterScene scene;
  late CharacterRenderer renderer;
  late ui.Image waterfrontBackdropImage;
  late ui.Image waterfrontCloudsImage;
  late ui.Image waterfrontWavesImage;

  setUpAll(() async {
    waterfrontBackdropImage = await _imageFromFile(
      kCharacterWaterfrontBackdropAsset,
    );
    waterfrontCloudsImage = await _imageFromFile(
      kCharacterWaterfrontCloudsAsset,
    );
    waterfrontWavesImage = await _imageFromFile(
      kCharacterWaterfrontWavesAsset,
    );
  });

  tearDownAll(() {
    waterfrontBackdropImage.dispose();
    waterfrontCloudsImage.dispose();
    waterfrontWavesImage.dispose();
  });

  setUp(() {
    scene = CharacterScene(buildCatInSuitRig());
    renderer = CharacterRenderer();
  });

  CharacterPainter painterAt(double t, {Expression e = Expression.neutral}) =>
      CharacterPainter(
        scene: scene,
        clip: CatClips.shaku,
        timeSeconds: t,
        expression: e,
        renderer: renderer,
      );

  group('CharacterPainter.shouldRepaint', () {
    test('repaints when time advances', () {
      expect(painterAt(0.1).shouldRepaint(painterAt(0)), isTrue);
    });

    test('repaints when the expression changes', () {
      expect(
        painterAt(0, e: Expression.happy).shouldRepaint(painterAt(0)),
        isTrue,
      );
    });

    test('repaints when the renderer instance changes', () {
      final other = CharacterPainter(
        scene: scene,
        clip: CatClips.shaku,
        timeSeconds: 0.5,
        renderer: CharacterRenderer(antiAlias: false),
      );
      expect(other.shouldRepaint(painterAt(0.5)), isTrue);
    });

    test('repaints when walking pair mode changes', () {
      final pair = CharacterPainter(
        scene: scene,
        clip: CatClips.shaku,
        timeSeconds: 0.5,
        walkingPair: true,
        renderer: renderer,
      );
      expect(pair.shouldRepaint(painterAt(0.5)), isTrue);
    });

    test('repaints when ensemble clips change', () {
      final lead = CharacterPainter(
        scene: scene,
        clip: CatClips.shaku,
        timeSeconds: 0.5,
        walkingPair: true,
        ensembleClips: [CatClips.shaku],
        renderer: renderer,
      );
      final backup = CharacterPainter(
        scene: scene,
        clip: CatClips.shaku,
        timeSeconds: 0.5,
        walkingPair: true,
        ensembleClips: [CatClips.danceBackupLeft],
        renderer: renderer,
      );
      expect(backup.shouldRepaint(lead), isTrue);
    });

    test('repaints when the backdrop changes', () {
      final waterfront = CharacterPainter(
        scene: scene,
        clip: CatClips.shaku,
        timeSeconds: 0.5,
        backdrop: CharacterBackdrop.waterfront,
        renderer: renderer,
      );
      expect(waterfront.shouldRepaint(painterAt(0.5)), isTrue);
    });

    test('repaints when the dance camera review mode changes', () {
      final locked = CharacterPainter(
        scene: scene,
        clip: CatClips.shaku,
        timeSeconds: 0.5,
        enableDanceCamera: false,
        renderer: renderer,
      );
      expect(locked.shouldRepaint(painterAt(0.5)), isTrue);
    });

    test('repaints when the dance view projection changes', () {
      final projected = CharacterPainter(
        scene: scene,
        clip: CatClips.shaku,
        timeSeconds: 0.5,
        danceViewProjection: true,
        renderer: renderer,
      );
      expect(projected.shouldRepaint(painterAt(0.5)), isTrue);
    });

    test('does not repaint for identical inputs', () {
      final clip = CatClips.shaku;
      final previous = CharacterPainter(
        scene: scene,
        clip: clip,
        timeSeconds: 0.5,
        renderer: renderer,
      );
      final current = CharacterPainter(
        scene: scene,
        clip: clip,
        timeSeconds: 0.5,
        renderer: renderer,
      );
      expect(current.shouldRepaint(previous), isFalse);
    });
  });

  testWidgets('dance-only clips ignore the locomotion flag', (
    tester,
  ) async {
    await tester.runAsync(() async {
      Future<Uint8List> render({required bool locomote}) async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        CharacterPainter(
          scene: scene,
          clip: CatClips.shaku,
          // A time where the walk has travelled a good fraction of a stride.
          timeSeconds: 0.6,
          locomote: locomote,
          renderer: renderer,
        ).paint(canvas, const Size(360, 280));
        final picture = recorder.endRecording();
        final image = await picture.toImage(360, 280);
        final data = await image.toByteData();
        image.dispose();
        picture.dispose();
        return data!.buffer.asUint8List();
      }

      final travelling = await render(locomote: true);
      final inPlace = await render(locomote: false);
      expect(
        travelling,
        equals(inPlace),
        reason:
            'the public character showcase is dance-only now; clips without '
            'locomotionSpeed should ignore the legacy locomotion flag',
      );
    });
  });

  testWidgets('paint actually draws the character (non-blank output)', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      painterAt(0.3).paint(canvas, const Size(200, 280));
      final picture = recorder.endRecording();
      try {
        final image = await picture.toImage(200, 280);
        try {
          final data = await image.toByteData();
          final pixels = data!.buffer.asUint8List();
          // The painter draws on a transparent canvas, so any non-zero alpha
          // byte means the rig was actually rendered (not an empty frame).
          var opaque = 0;
          for (var i = 3; i < pixels.length; i += 4) {
            if (pixels[i] != 0) opaque++;
          }
          expect(opaque, greaterThan(0), reason: 'expected painted pixels');
        } finally {
          image.dispose();
        }
      } finally {
        picture.dispose();
      }
    });
  });

  testWidgets('dance contact foot is visually pinned to the floor', (
    tester,
  ) async {
    await tester.runAsync(() async {
      const width = 320;
      const height = 360;
      const canvasSize = Size(320, 360);
      const feetFraction = 0.78;
      const expectedFloorY = height * feetFraction;

      for (final t in const [0.0, 0.75, 1.5, 2.25, 3.0, 3.75, 4.5]) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        CharacterPainter(
          scene: scene,
          clip: CatClips.shaku,
          timeSeconds: t,
          feetFraction: feetFraction,
          shadowColor: const Color(0x00000000),
          renderer: renderer,
        ).paint(canvas, canvasSize);
        final picture = recorder.endRecording();
        try {
          final image = await picture.toImage(width, height);
          try {
            final data = await image.toByteData();
            final pixels = data!.buffer.asUint8List();
            final floorPixels = _opaquePixelsInBox(
              pixels,
              width,
              0,
              width - 1,
              (expectedFloorY - 4).floor(),
              (expectedFloorY + 5).ceil(),
            );
            expect(
              floorPixels,
              greaterThan(0),
              reason:
                  'dance lowest declared contact foot should reach the floor '
                  'at t=$t',
            );
          } finally {
            image.dispose();
          }
        } finally {
          picture.dispose();
        }
      }
    });
  });

  testWidgets(
    'dance support handoff does not horizontally re-anchor the body',
    (
      tester,
    ) async {
      await tester.runAsync(() async {
        const width = 760;
        const height = 520;
        const canvasSize = Size(760, 520);

        Future<({double x, double y})> visibleCenter(
          Clip clip,
          double p,
        ) async {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          CharacterPainter(
            scene: scene,
            clip: clip,
            timeSeconds: clip.duration * p,
            shadowColor: const Color(0x00000000),
            renderer: renderer,
          ).paint(canvas, canvasSize);
          final picture = recorder.endRecording();
          try {
            final image = await picture.toImage(width, height);
            try {
              final data = await image.toByteData();
              return _visibleCenter(data!.buffer.asUint8List(), width, height);
            } finally {
              image.dispose();
            }
          } finally {
            picture.dispose();
          }
        }

        for (final clip in [
          CatClips.shaku,
          CatClips.danceBackupLeft,
          CatClips.danceBackupRight,
        ]) {
          for (final frame in [60, 120, 225]) {
            final before = await visibleCenter(clip, (frame - 1) / 240);
            final after = await visibleCenter(clip, frame / 240);

            expect(
              (after.x - before.x).abs(),
              lessThan(18),
              reason:
                  '${clip.name} should not snap sideways at support handoff '
                  '$frame',
            );
            expect(
              (after.y - before.y).abs(),
              lessThan(18),
              reason:
                  '${clip.name} should not snap vertically at support handoff '
                  '$frame',
            );
          }
        }
      });
    },
  );

  testWidgets('waterfront backdrop paints distinct stage bands', (
    tester,
  ) async {
    await tester.runAsync(() async {
      const width = 360;
      const height = 420;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      CharacterPainter(
        scene: scene,
        clip: CatClips.shaku,
        timeSeconds: 0.3,
        backdrop: CharacterBackdrop.waterfront,
        backdropImage: waterfrontBackdropImage,
        backdropCloudsImage: waterfrontCloudsImage,
        backdropWavesImage: waterfrontWavesImage,
        shadowColor: const Color(0x00000000),
        renderer: renderer,
      ).paint(canvas, Size(width.toDouble(), height.toDouble()));
      final picture = recorder.endRecording();
      try {
        final image = await picture.toImage(width, height);
        try {
          final data = await image.toByteData();
          final pixels = data!.buffer.asUint8List();
          final sky = _rgbaAt(pixels, width, width ~/ 2, 40);
          final water = _rgbaAt(pixels, width, 60, 230);
          final deck = _rgbaAt(pixels, width, width ~/ 2, 400);

          expect(sky.a, 255);
          expect(sky.b, greaterThan(sky.r), reason: 'sky should read blue');
          expect(
            water.b,
            greaterThan(water.r),
            reason: 'water should read blue',
          );
          expect(
            deck.r,
            greaterThan(water.r),
            reason: 'deck should separate from lagoon water',
          );
          expect(deck.r, greaterThan(deck.b), reason: 'deck should read warm');
        } finally {
          image.dispose();
        }
      } finally {
        picture.dispose();
      }
    });
  });

  testWidgets('walking pair paints two separated characters', (tester) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      CharacterPainter(
        scene: scene,
        clip: CatClips.shaku,
        timeSeconds: 0.3,
        walkingPair: true,
        shadowColor: const Color(0x00000000),
        renderer: renderer,
      ).paint(canvas, const Size(520, 320));
      final picture = recorder.endRecording();
      try {
        final image = await picture.toImage(520, 320);
        try {
          final data = await image.toByteData();
          final pixels = data!.buffer.asUint8List();
          var leftOpaque = 0;
          var rightOpaque = 0;
          for (var y = 0; y < 320; y++) {
            for (var x = 0; x < 520; x++) {
              final alpha = pixels[(y * 520 + x) * 4 + 3];
              if (alpha == 0) continue;
              if (x < 220) {
                leftOpaque++;
              } else if (x > 300) {
                rightOpaque++;
              }
            }
          }
          expect(
            leftOpaque,
            greaterThan(1500),
            reason: 'left cat should occupy its own lane',
          );
          expect(
            rightOpaque,
            greaterThan(1500),
            reason: 'right cat should occupy its own lane',
          );
        } finally {
          image.dispose();
        }
      } finally {
        picture.dispose();
      }
    });
  });

  testWidgets('dance trio stages the orange lead in the centre lane', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      CharacterPainter(
        scene: scene,
        partnerScene: CharacterScene(
          buildCatInSuitRig(palette: CatInSuitPalette.silverTabby),
        ),
        ensembleScenes: [
          CharacterScene(
            buildCatInSuitRig(palette: CatInSuitPalette.silverTabby),
          ),
          CharacterScene(
            buildCatInSuitRig(palette: CatInSuitPalette.darkBrown),
          ),
        ],
        ensembleClips: [
          CatClips.shaku,
          CatClips.danceBackupLeft,
          CatClips.danceBackupRight,
        ],
        ensembleExpressions: const [
          Expression.neutral,
          Expression.content,
          Expression.happy,
        ],
        synchronousEnsemble: true,
        clip: CatClips.shaku,
        timeSeconds: 0.25,
        walkingPair: true,
        shadowColor: const Color(0x00000000),
        renderer: renderer,
      ).paint(canvas, const Size(760, 420));
      final picture = recorder.endRecording();
      try {
        final image = await picture.toImage(760, 420);
        try {
          final data = await image.toByteData();
          final pixels = data!.buffer.asUint8List();
          var leftOrange = 0;
          var centerOrange = 0;
          var rightOrange = 0;
          var leftOpaque = 0;
          var rightOpaque = 0;
          for (var y = 0; y < 420; y++) {
            for (var x = 0; x < 760; x++) {
              final offset = (y * 760 + x) * 4;
              final red = pixels[offset];
              final green = pixels[offset + 1];
              final blue = pixels[offset + 2];
              final alpha = pixels[offset + 3];
              if (alpha == 0) continue;
              if (x < 260) leftOpaque++;
              if (x > 500) rightOpaque++;
              final orangeFur =
                  red > 200 && green > 120 && green < 190 && blue < 120;
              if (!orangeFur) continue;
              if (x < 260) {
                leftOrange++;
              } else if (x > 500) {
                rightOrange++;
              } else {
                centerOrange++;
              }
            }
          }

          expect(leftOpaque, greaterThan(1000));
          expect(rightOpaque, greaterThan(1000));
          expect(
            centerOrange,
            greaterThan(leftOrange * 4),
            reason: 'the orange lead should be staged in the centre lane',
          );
          expect(
            centerOrange,
            greaterThan(rightOrange * 4),
            reason: 'the orange lead should be staged in the centre lane',
          );
        } finally {
          image.dispose();
        }
      } finally {
        picture.dispose();
      }
    });
  });

  testWidgets('a music accent pops the trio bigger (and coils it smaller '
      'first) IN UNISON', (tester) async {
    await tester.runAsync(() async {
      // Opaque-pixel area per screen lane (the trio stages left / centre /
      // right), for a given accent. The unison pop scales every member about
      // its own foot anchor, so a stronger accent = strictly more silhouette
      // area in EVERY lane.
      Future<({int left, int centre, int right})> laneAreas(
        double bodyAccent, {
        double bodyAnticipation = 0,
      }) async {
        const w = 760;
        const h = 420;
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        CharacterPainter(
          scene: scene,
          partnerScene: CharacterScene(
            buildCatInSuitRig(palette: CatInSuitPalette.silverTabby),
          ),
          ensembleScenes: [
            CharacterScene(
              buildCatInSuitRig(palette: CatInSuitPalette.silverTabby),
            ),
            CharacterScene(
              buildCatInSuitRig(palette: CatInSuitPalette.darkBrown),
            ),
          ],
          ensembleClips: [
            CatClips.shaku,
            CatClips.danceBackupLeft,
            CatClips.danceBackupRight,
          ],
          ensembleExpressions: const [
            Expression.neutral,
            Expression.content,
            Expression.happy,
          ],
          synchronousEnsemble: true,
          clip: CatClips.shaku,
          timeSeconds: 0.25,
          walkingPair: true,
          shadowColor: const Color(0x00000000),
          bodyAccent: bodyAccent,
          bodyAnticipation: bodyAnticipation,
          renderer: renderer,
        ).paint(canvas, Size(w.toDouble(), h.toDouble()));
        final picture = recorder.endRecording();
        try {
          final image = await picture.toImage(w, h);
          try {
            final data = await image.toByteData();
            final pixels = data!.buffer.asUint8List();
            var left = 0;
            var centre = 0;
            var right = 0;
            for (var y = 0; y < h; y++) {
              for (var x = 0; x < w; x++) {
                if (pixels[(y * w + x) * 4 + 3] == 0) continue;
                if (x < 260) {
                  left++;
                } else if (x > 500) {
                  right++;
                } else {
                  centre++;
                }
              }
            }
            return (left: left, centre: centre, right: right);
          } finally {
            image.dispose();
          }
        } finally {
          picture.dispose();
        }
      }

      final rest = await laneAreas(0);
      final hit = await laneAreas(1);
      // Every lane grows — the surge is UNISON, not just the lead.
      expect(
        hit.left,
        greaterThan(rest.left),
        reason: 'left backup should surge on the accent',
      );
      expect(
        hit.centre,
        greaterThan(rest.centre),
        reason: 'centre lead should surge on the accent',
      );
      expect(
        hit.right,
        greaterThan(rest.right),
        reason: 'right backup should surge on the accent',
      );
      // And the total surge is real (a ~5% scale is ~10% more area), not a
      // one-pixel rounding wobble.
      final restTotal = rest.left + rest.centre + rest.right;
      final hitTotal = hit.left + hit.centre + hit.right;
      expect(
        hitTotal,
        greaterThan((restTotal * 1.04).round()),
        reason: 'the accent should visibly enlarge the ensemble silhouette',
      );

      // The COIL is the inverse: just before the hit (bodyAnticipation, no
      // accent yet) the ensemble gathers strictly SMALLER in every lane, so it
      // reads as a load that releases into the pop above.
      final coil = await laneAreas(0, bodyAnticipation: 1);
      expect(
        coil.left,
        lessThan(rest.left),
        reason: 'left backup should gather smaller in the coil',
      );
      expect(
        coil.centre,
        lessThan(rest.centre),
        reason: 'centre lead should gather smaller in the coil',
      );
      expect(
        coil.right,
        lessThan(rest.right),
        reason: 'right backup should gather smaller in the coil',
      );
    });
  });

  group('CharacterPainter.memberBacklights / bodyGrade', () {
    // Distinct pure-colour gels per lane so rim pixels are unambiguous.
    const gels = [Color(0xFFFF0000), Color(0xFF00FF00), Color(0xFF0000FF)];
    const w = 760;
    const h = 420;
    // Cat lane centres (≈ 0.3/0.5/0.7 of width); assign a pixel to its nearest.
    int laneOf(int x) =>
        (x - 228).abs() <= (x - 380).abs() && x < 304 ? 0 : (x < 456 ? 1 : 2);

    CharacterPainter trio({
      List<Color> backlights = const [],
      ({Color skyWrap, Color deckWrap})? bodyGrade,
      Clip? lead,
    }) => CharacterPainter(
      scene: scene,
      partnerScene: CharacterScene(
        buildCatInSuitRig(palette: CatInSuitPalette.silverTabby),
      ),
      ensembleScenes: [
        CharacterScene(
          buildCatInSuitRig(palette: CatInSuitPalette.silverTabby),
        ),
        CharacterScene(buildCatInSuitRig(palette: CatInSuitPalette.darkBrown)),
      ],
      ensembleClips: [
        lead ?? CatClips.shaku,
        CatClips.danceBackupLeft,
        CatClips.danceBackupRight,
      ],
      synchronousEnsemble: true,
      walkingPair: true,
      clip: lead ?? CatClips.shaku,
      timeSeconds: 0.25,
      shadowColor: const Color(0x00000000),
      memberBacklights: backlights,
      bodyGrade: bodyGrade,
      renderer: renderer,
    );

    Future<Uint8List> pixels(CharacterPainter p) async {
      final recorder = ui.PictureRecorder();
      p.paint(Canvas(recorder), const Size(760, 420));
      final pic = recorder.endRecording();
      final img = await pic.toImage(w, h);
      final data = (await img.toByteData())!.buffer.asUint8List();
      img.dispose();
      pic.dispose();
      return data;
    }

    testWidgets('rings each member in its own gel beyond the silhouette', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final plain = await pixels(trio());
        final lit = await pixels(trio(backlights: gels));
        var litTotal = 0;
        var plainTotal = 0;
        final hits = [0, 0, 0]; // NEW rim pixels matching this lane's gel
        final wrong = [0, 0, 0];
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            final o = (y * w + x) * 4;
            if (plain[o + 3] != 0) plainTotal++;
            if (lit[o + 3] == 0) continue;
            litTotal++;
            if (plain[o + 3] != 0) continue; // only NEW (rim) pixels
            final r = lit[o];
            final g = lit[o + 1];
            final b = lit[o + 2];
            final dom = r > g && r > b ? 0 : (g > r && g > b ? 1 : 2);
            if (dom == laneOf(x)) {
              hits[laneOf(x)]++;
            } else {
              wrong[laneOf(x)]++;
            }
          }
        }
        // The rim adds coloured coverage OUTSIDE the bodies, and each lane's new
        // pixels are dominated by THAT lane's gel.
        expect(
          litTotal,
          greaterThan(plainTotal),
          reason: 'rim adds coverage beyond the bodies',
        );
        for (var i = 0; i < 3; i++) {
          expect(
            hits[i],
            greaterThan(100),
            reason: 'lane $i ringed in its gel',
          );
          expect(
            hits[i],
            greaterThan(wrong[i]),
            reason: 'lane $i rim is mostly its own gel',
          );
        }
      });
    });

    // Regression guard: the concert stage act (rim/halo, grade, formation, foot
    // anchors) must light up for the catalogue phrases the audio player cuts
    // between. Gating the whole system on one representative phrase once left
    // later sections flat/frontal in the running player.
    testWidgets(
      'rings the trio for catalogue dance phrases, not just one lead move',
      (
        tester,
      ) async {
        await tester.runAsync(() async {
          for (final lead in [CatClips.shaku, CatClips.zanku, CatClips.sekem]) {
            final plain = await pixels(trio(lead: lead));
            final lit = await pixels(trio(lead: lead, backlights: gels));
            var newRimPixels = 0;
            for (var y = 0; y < h; y++) {
              for (var x = 0; x < w; x++) {
                final o = (y * w + x) * 4;
                if (lit[o + 3] != 0 && plain[o + 3] == 0) newRimPixels++;
              }
            }
            expect(
              newRimPixels,
              greaterThan(300),
              reason:
                  'memberBacklights must ring ${lead.name}; otherwise the live '
                  'stage loses trio depth during that catalogue phrase',
            );
          }
        });
      },
    );

    testWidgets('bodyGrade seats both the body and the face into the plate', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final plain = await pixels(trio(backlights: gels));
        // Strong, opaque-ish wrap so the body tint is unambiguous in the diff.
        final graded = await pixels(
          trio(
            backlights: gels,
            bodyGrade: const (
              skyWrap: Color(0xAA1F3354),
              deckWrap: Color(0xAA3A2616),
            ),
          ),
        );
        // The figure's vertical extent, from the (ungraded) silhouette.
        var minY = h;
        var maxY = 0;
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            if (plain[(y * w + x) * 4 + 3] != 0) {
              if (y < minY) minY = y;
              if (y > maxY) maxY = y;
              break;
            }
          }
        }
        final span = maxY - minY;
        final headCut = minY + (span * 0.32).round(); // head ≈ the top third
        final bodyCut = minY + (span * 0.55).round(); // torso/legs below
        var headChange = 0;
        var bodyChange = 0;
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            final o = (y * w + x) * 4;
            if (plain[o + 3] == 0 && graded[o + 3] == 0) continue;
            final d =
                (graded[o] - plain[o]).abs() +
                (graded[o + 1] - plain[o + 1]).abs() +
                (graded[o + 2] - plain[o + 2]).abs();
            if (y < headCut) headChange += d;
            if (y >= bodyCut) bodyChange += d;
          }
        }
        // The grade seats the whole figure into the plate. The BODY (seat +
        // twilight wrap + gel terminator, below the collar) carries the heaviest
        // re-tint…
        expect(
          bodyChange,
          greaterThan(5000),
          reason: 'bodyGrade re-tints the torso/legs',
        );
        // …and the FACE is seated too — a gentle warm-key→cool-fill split above
        // the collar so the bright warm muzzle stops floating as the scene's
        // hottest sticker. (It used to be clipped out entirely; the integration
        // grade now treats it, just more softly than the body.)
        expect(
          headChange,
          greaterThan(1000),
          reason: 'bodyGrade seats the face with its warm-key/cool-fill split',
        );
        // …but the face split should stay in the same order of magnitude as the
        // body grade, not blow out as a separate sticker pass. The bound is a
        // loose sanity check (a real "sticker" blowout is multiples larger).
        // Quarter-view projection narrows the visible torso/limb area relative
        // to the face, so the face/body total can sit a little higher while
        // still reading as one integrated grade.
        // Bound recalibrated when the renderer began scaling ribbon widths
        // with the member transform: the correctly-slimmer limbs at this
        // scale shrink the body area, lifting the head/body ratio.
        expect(
          headChange,
          lessThan(bodyChange * 2.2),
          reason: 'the face grade should stay balanced against the body grade',
        );
      });
    });

    // Regression guard for the idle body-grade fix: bodyGrade used to be
    // gated on the same clip-name check as the energetic-only staging
    // (hero pose, formation, rim glow), so it silently dropped out during
    // the idle clip. It must now apply regardless of clip name.
    testWidgets('bodyGrade seats the idle (non-dance) clip too', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final plain = await pixels(trio(lead: CatClips.idle));
        final graded = await pixels(
          trio(
            lead: CatClips.idle,
            bodyGrade: const (
              skyWrap: Color(0xAA1F3354),
              deckWrap: Color(0xAA3A2616),
            ),
          ),
        );
        var change = 0;
        for (var i = 0; i < plain.length; i += 4) {
          if (plain[i + 3] == 0 && graded[i + 3] == 0) continue;
          change +=
              (graded[i] - plain[i]).abs() +
              (graded[i + 1] - plain[i + 1]).abs() +
              (graded[i + 2] - plain[i + 2]).abs();
        }
        expect(
          change,
          greaterThan(1000),
          reason:
              'the idle clip must be seated into the plate too, not just '
              'the named dance moves',
        );
      });
    });

    // Regression guard for the pre-show dim: the idle clip should read
    // visibly DARKER than a danced clip under the identical grade, since
    // the stage light hasn't "come up" yet at danceWeight 0.
    testWidgets('the pre-show dim darkens the idle clip vs. a danced one', (
      tester,
    ) async {
      await tester.runAsync(() async {
        const grade = (
          skyWrap: Color(0xAA1F3354),
          deckWrap: Color(0xAA3A2616),
        );
        final idle = await pixels(
          trio(lead: CatClips.idle, bodyGrade: grade),
        );
        final dancing = await pixels(
          trio(lead: CatClips.shaku, bodyGrade: grade),
        );
        var idleLuma = 0;
        var idlePixels = 0;
        var danceLuma = 0;
        var dancePixels = 0;
        for (var i = 0; i < idle.length; i += 4) {
          if (idle[i + 3] != 0) {
            idleLuma += idle[i] + idle[i + 1] + idle[i + 2];
            idlePixels++;
          }
          if (dancing[i + 3] != 0) {
            danceLuma += dancing[i] + dancing[i + 1] + dancing[i + 2];
            dancePixels++;
          }
        }
        expect(idlePixels, greaterThan(0));
        expect(dancePixels, greaterThan(0));
        expect(
          idleLuma / idlePixels,
          lessThan(danceLuma / dancePixels),
          reason:
              'the pre-show dim should make the idle figure read darker than '
              'the same grade applied to a danced clip',
        );
      });
    });

    // Regression guard for the harsh idle<->dance transition fix: the
    // energetic-only staging (backlight glow here) must fade CONTINUOUSLY
    // with the blend weight, not snap on the instant a blended clip appears.
    testWidgets(
      'backlight glow is a fraction of full strength mid-blend, not snapped on',
      (tester) async {
        await tester.runAsync(() async {
          Future<int> newRimPixelCount(Clip lead) async {
            final plain = await pixels(trio(lead: lead));
            final lit = await pixels(trio(lead: lead, backlights: gels));
            var count = 0;
            for (var i = 0; i < plain.length; i += 4) {
              if (lit[i + 3] != 0 && plain[i + 3] == 0) count++;
            }
            return count;
          }

          final idleRim = await newRimPixelCount(CatClips.idle);
          final danceRim = await newRimPixelCount(CatClips.shaku);
          final blended = blendedClip(
            from: CatClips.idle,
            to: CatClips.shaku,
            weight: 0.5,
          );
          final midRim = await newRimPixelCount(blended);

          expect(
            idleRim,
            0,
            reason: 'the idle clip alone must show no rim glow at all',
          );
          expect(
            danceRim,
            greaterThan(0),
            reason: 'a steady dance clip shows full rim glow',
          );
          expect(
            midRim,
            greaterThan(0),
            reason:
                'a half-blended idle<->dance clip must show SOME glow — if '
                'this is 0 the fade snapped to off instead of lerping',
          );
          expect(
            midRim,
            lessThan(danceRim),
            reason:
                'a half-blended clip must show LESS glow than the fully '
                'danced clip — if this is >= danceRim the fade snapped to '
                'full strength instead of lerping',
          );
        });
      },
    );
  });

  testWidgets('dance trio clears the dark backup during the finish', (
    tester,
  ) async {
    await tester.runAsync(() async {
      Future<({double darkCenterX, double leadCenterX, int darkPixels})>
      boundsAt(double p) async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        CharacterPainter(
          scene: scene,
          partnerScene: CharacterScene(
            buildCatInSuitRig(palette: CatInSuitPalette.silverTabby),
          ),
          ensembleScenes: [
            CharacterScene(
              buildCatInSuitRig(palette: CatInSuitPalette.silverTabby),
            ),
            CharacterScene(
              buildCatInSuitRig(palette: CatInSuitPalette.darkBrown),
            ),
          ],
          ensembleClips: [
            CatClips.shaku,
            CatClips.danceBackupLeft,
            CatClips.danceBackupRight,
          ],
          synchronousEnsemble: true,
          clip: CatClips.shaku,
          timeSeconds: CatClips.shaku.duration * p,
          walkingPair: true,
          shadowColor: const Color(0x00000000),
          renderer: renderer,
        ).paint(canvas, const Size(760, 420));
        final picture = recorder.endRecording();
        try {
          final image = await picture.toImage(760, 420);
          try {
            final data = await image.toByteData();
            final pixels = data!.buffer.asUint8List();
            final lead = _boundsForPixels(
              pixels,
              760,
              420,
              // The orange-tabby lead's warm fur, widened to follow the baked
              // form-rounding which deepens and cools the face/fur edges (lower
              // red, more blue) out of the original tight bright-orange band —
              // still warm, red-dominant, and distinct from the grey/navy backups.
              (red, green, blue, alpha, x, y) =>
                  alpha > 180 &&
                  red > 150 &&
                  green > 90 &&
                  green < 200 &&
                  blue < 130,
            );
            final dark = _boundsForPixels(
              pixels,
              760,
              420,
              // The dark-brown backup's low-value range, widened to follow the
              // baked form-rounding occlusion which deepens and COOLS the edge
              // pixels (more blue, less red) so they no longer sit in the original
              // tight warm-brown band — still a dark, distinct-from-the-bright-cats
              // range, and still gated to the right of the lead.
              (red, green, blue, alpha, x, y) =>
                  x > lead.centerX + 20 &&
                  alpha > 180 &&
                  red >= 16 &&
                  red <= 90 &&
                  green >= 16 &&
                  green <= 74 &&
                  blue <= 82,
            );

            expect(dark.count, greaterThan(250));
            expect(lead.count, greaterThan(250));
            return (
              darkCenterX: dark.centerX,
              leadCenterX: lead.centerX,
              darkPixels: dark.count,
            );
          } finally {
            image.dispose();
          }
        } finally {
          picture.dispose();
        }
      }

      final preFinish = await boundsAt(3 / 4);
      final finish = await boundsAt(29 / 32);

      expect(
        finish.darkCenterX,
        lessThan(preFinish.darkCenterX - 8),
        reason:
            'the final hook-reset triangle should pull the dark backup inward '
            'instead of leaving it parked in the right-side clutter lane',
      );
      expect(
        finish.darkCenterX,
        greaterThan(finish.leadCenterX + 34),
        reason:
            'the dark backup should still read as the right-side dancer, not '
            'cross into the lead lane during the finish',
      );
    });
  });

  test('dance trio keeps backup depth stable while focus moves laterally', () {
    ({double dx, double dy, double scale}) formationAt(int index, double p) =>
        CharacterPainter.debugDanceFormation(
          index,
          3,
          CatClips.shaku.duration * p,
          CatClips.shaku.duration,
        );

    final silverFrames = [
      for (var frame = 0; frame <= 32; frame++) formationAt(0, frame / 32),
    ];
    final darkFrames = [
      for (var frame = 0; frame <= 32; frame++) formationAt(2, frame / 32),
    ];
    final allFrames = [
      ...silverFrames,
      for (var frame = 0; frame <= 32; frame++) formationAt(1, frame / 32),
      ...darkFrames,
    ];

    double range(Iterable<double> values) {
      final list = values.toList();
      return list.reduce(math.max) - list.reduce(math.min);
    }

    double largestFrameStep(
      List<({double dx, double dy, double scale})> frames,
    ) {
      var largest = 0.0;
      for (var i = 1; i < frames.length; i++) {
        largest = math.max(largest, (frames[i].dy - frames[i - 1].dy).abs());
      }
      return largest;
    }

    expect(
      range(silverFrames.map((frame) => frame.dx)),
      greaterThan(28),
      reason:
          'the silver backup should still trade focus through lateral '
          'formation changes instead of standing in a static chorus lane',
    );
    expect(
      range(darkFrames.map((frame) => frame.dx)),
      greaterThan(34),
      reason:
          'the dark backup should still trade focus through lateral formation '
          'changes instead of standing in a static chorus lane',
    );
    expect(
      range(silverFrames.map((frame) => frame.dy)),
      lessThanOrEqualTo(0.001),
      reason:
          'the silver backup floor row should stay locked when its feet are '
          'dancing in place',
    );
    expect(
      range(darkFrames.map((frame) => frame.dy)),
      lessThanOrEqualTo(0.001),
      reason:
          'the dark backup floor row should stay locked when its feet are '
          'dancing in place',
    );
    expect(
      largestFrameStep(silverFrames),
      lessThanOrEqualTo(0.001),
      reason: 'backup depth should not animate without matching footwork',
    );
    expect(
      largestFrameStep(darkFrames),
      lessThanOrEqualTo(0.001),
      reason: 'backup depth should not animate without matching footwork',
    );
    for (final frame in allFrames) {
      expect(
        frame.scale,
        closeTo(1, 0.001),
        reason:
            'dance focus should not come from perspective scale pulses that '
            'are disconnected from the legwork',
      );
    }
  });

  test('dance trio view projection quarter-turns flankers inward', () {
    final leftView = CharacterPainter.debugDanceMemberView(0, 3);
    final leadView = CharacterPainter.debugDanceMemberView(1, 3);
    final rightView = CharacterPainter.debugDanceMemberView(2, 3);

    expect(leftView.shearX, greaterThan(0));
    expect(rightView.shearX, lessThan(0));
    expect(leadView.shearX, greaterThan(0.08));
    expect(leftView.foreshortenX, lessThan(leadView.foreshortenX));
    expect(rightView.foreshortenX, lessThan(leadView.foreshortenX));
    expect(
      leadView.foreshortenX,
      lessThan(0.88),
      reason:
          'the app lead needs a visible quarter turn, not the old near-front '
          'projection that looked frontal in screenshots',
    );
    expect(leadView.depth, greaterThan(0.25));

    final frame = scene.frameAt(clip: CatClips.shaku, timeSeconds: 0.25);
    final leftWorld = CharacterPainter.debugProjectDanceViewWorld(
      frame.world,
      index: 0,
      memberCount: 3,
      scale: 1,
    );
    final rightWorld = CharacterPainter.debugProjectDanceViewWorld(
      frame.world,
      index: 2,
      memberCount: 3,
      scale: 1,
    );
    final leadWorld = CharacterPainter.debugProjectDanceViewWorld(
      frame.world,
      index: 1,
      memberCount: 3,
      scale: 1,
    );

    expect(
      leftWorld[CatBones.footL]!.origin.x -
          frame.world[CatBones.footL]!.origin.x,
      greaterThan(7),
      reason: 'left flanker near shoe should move into its depth lane',
    );
    expect(
      leftWorld[CatBones.footR]!.origin.x -
          frame.world[CatBones.footR]!.origin.x,
      lessThan(-7),
      reason: 'left flanker far shoe should move into the opposite depth lane',
    );
    expect(
      rightWorld[CatBones.footL]!.origin.x -
          frame.world[CatBones.footL]!.origin.x,
      lessThan(-7),
      reason: 'right flanker should mirror the near/far shoe lanes',
    );
    expect(
      leftWorld[CatBones.handL]!.origin.x -
          frame.world[CatBones.handL]!.origin.x,
      greaterThan(9),
      reason: 'quarter-turn hands should pull clear of the jacket',
    );
    expect(
      leftWorld[CatBones.torso]!.origin.x - leftWorld[CatBones.hips]!.origin.x,
      greaterThan(
        frame.world[CatBones.torso]!.origin.x -
            frame.world[CatBones.hips]!.origin.x,
      ),
      reason: 'quarter turn should separate chest mass from pelvis mass',
    );
    expect(
      (leadWorld[CatBones.torso]!.origin.x - leadWorld[CatBones.hips]!.origin.x)
          .abs(),
      greaterThan(1.5),
      reason:
          'lead projection should also separate chest from pelvis so the shipped '
          'app shows a real quarter turn',
    );
  });

  testWidgets('dance trio camera pushes into torso close-up then pulls out', (
    tester,
  ) async {
    await tester.runAsync(() async {
      Future<
        ({
          int orangeWidth,
          int orangeHeight,
          double orangeCenterX,
          double orangeCenterY,
          int contentMinX,
          int contentMaxX,
          int contentMinY,
          int contentMaxY,
        })
      >
      boundsAt(double p, {bool enableDanceCamera = true}) async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        CharacterPainter(
          scene: scene,
          partnerScene: CharacterScene(
            buildCatInSuitRig(palette: CatInSuitPalette.silverTabby),
          ),
          ensembleScenes: [
            CharacterScene(
              buildCatInSuitRig(palette: CatInSuitPalette.silverTabby),
            ),
            CharacterScene(
              buildCatInSuitRig(palette: CatInSuitPalette.darkBrown),
            ),
          ],
          ensembleClips: [
            CatClips.shaku,
            CatClips.danceBackupLeft,
            CatClips.danceBackupRight,
          ],
          synchronousEnsemble: true,
          clip: CatClips.shaku,
          timeSeconds: CatClips.shaku.duration * p,
          walkingPair: true,
          enableDanceCamera: enableDanceCamera,
          shadowColor: const Color(0x00000000),
          renderer: renderer,
        ).paint(canvas, const Size(760, 420));
        final picture = recorder.endRecording();
        try {
          final image = await picture.toImage(760, 420);
          try {
            final data = await image.toByteData();
            final pixels = data!.buffer.asUint8List();
            var minX = 760;
            var maxX = -1;
            var minY = 420;
            var maxY = -1;
            var minOpaqueX = 760;
            var maxOpaqueX = -1;
            var minOpaqueY = 420;
            var maxOpaqueY = -1;
            for (var y = 0; y < 420; y++) {
              for (var x = 0; x < 760; x++) {
                final offset = (y * 760 + x) * 4;
                if (pixels[offset + 3] != 0) {
                  minOpaqueX = math.min(minOpaqueX, x);
                  maxOpaqueX = math.max(maxOpaqueX, x);
                  minOpaqueY = math.min(minOpaqueY, y);
                  maxOpaqueY = math.max(maxOpaqueY, y);
                }
                final red = pixels[offset];
                final green = pixels[offset + 1];
                final blue = pixels[offset + 2];
                final orangeFur =
                    red > 200 && green > 120 && green < 190 && blue < 120;
                if (!orangeFur) continue;
                minX = math.min(minX, x);
                maxX = math.max(maxX, x);
                minY = math.min(minY, y);
                maxY = math.max(maxY, y);
              }
            }

            expect(maxX, greaterThanOrEqualTo(minX));
            expect(maxY, greaterThanOrEqualTo(minY));
            expect(maxOpaqueX, greaterThanOrEqualTo(minOpaqueX));
            expect(maxOpaqueY, greaterThanOrEqualTo(minOpaqueY));
            return (
              orangeWidth: maxX - minX + 1,
              orangeHeight: maxY - minY + 1,
              orangeCenterX: (minX + maxX) / 2,
              orangeCenterY: (minY + maxY) / 2,
              contentMinX: minOpaqueX,
              contentMaxX: maxOpaqueX,
              contentMinY: minOpaqueY,
              contentMaxY: maxOpaqueY,
            );
          } finally {
            image.dispose();
          }
        } finally {
          picture.dispose();
        }
      }

      final wide = await boundsAt(0);
      final centerPush = await boundsAt(1 / 8);
      final rightPan = await boundsAt(1 / 4);
      final rightClose = await boundsAt(3 / 8);
      final rightHold = await boundsAt(7 / 16);
      final leadLevel = await boundsAt(1 / 2);
      final postRightRecovery = await boundsAt(17 / 32);
      final leftPan = await boundsAt(5 / 8);
      final leftClose = await boundsAt(3 / 4);
      final leftHold = await boundsAt(13 / 16);
      final reset = await boundsAt(1);
      final lockedWide = await boundsAt(0, enableDanceCamera: false);
      final lockedMid = await boundsAt(1 / 2, enableDanceCamera: false);

      expect(
        centerPush.orangeCenterX,
        closeTo(wide.orangeCenterX, 28),
        reason:
            'the first push should stay centred on the trio before travelling',
      );
      // Upper bound recalibrated for member-scaled ribbon rendering: the
      // tail/limb ribbons now render thinner at the wide shot's small scale,
      // shrinking the wide bbox and lifting this ratio. A true jump-cut to a
      // close-up is still multiples larger.
      expect(
        centerPush.orangeHeight,
        // Lower bound 0.95 -> 0.93: the bounce cascade lags the skull
        // behind the pelvis, shifting the framed bbox ~1% at this sampled
        // beat. A zoom jump still measures far outside this band.
        inInclusiveRange(wide.orangeHeight * 0.93, wide.orangeHeight * 1.55),
        reason:
            'the first beat should begin a visible dolly-in without jumping '
            'straight to a close-up',
      );
      expect(
        centerPush.orangeCenterX - rightPan.orangeCenterX,
        // 48 -> 56: shaku's owner-approved weight sway (bar-period, ±20
        // units) legitimately moves the trio's rendered centre a little
        // further between these two sampled camera beats. A true snap
        // still measures multiples of this band.
        // 56 -> 60 (9-path r5): shaku's per-bar weight rock re-armed into the
        // sway parks shifts the lead ~4px right at this beat — the bound
        // tracks the character's shot range; the easing guard is the
        // adjacent delta assertions, which are untouched.
        inInclusiveRange(-8, 60),
        reason:
            'the second beat now starts with the push-in; any right truck '
            'should ease in without snapping the lead left',
      );
      expect(
        centerPush.orangeCenterX - rightClose.orangeCenterX,
        inInclusiveRange(12, 72),
        reason:
            'the right-side pass should still truck far enough to feature the '
            'right lane after the initial push-in',
      );
      // Upper bound recalibrated for member-scaled ribbon rendering (see the
      // dolly-in note above): the wide-shot denominator shrank.
      expect(
        rightClose.orangeHeight,
        inInclusiveRange(
          wide.orangeHeight * 1.55,
          wide.orangeHeight * 2.6,
        ),
        reason:
            'the right-side pass should commit to a face/torso close-up, not '
            'another mostly full-body medium-wide shot',
      );
      expect(
        rightClose.orangeCenterY,
        lessThan(wide.orangeCenterY - 15),
        reason:
            'the pushed-in camera should lift the dancers toward a face/torso '
            'composition instead of keeping the enlarged lead low in frame',
      );
      expect(
        rightClose.contentMinY,
        greaterThan(2),
        reason:
            'lifting the close-up should not crop ears or heads through the top '
            'of the desktop viewport',
      );
      expect(
        rightClose.contentMinX,
        greaterThanOrEqualTo(0),
        reason:
            'the close-up may crop feet, but it must stay within the desktop '
            'viewport horizontally',
      );
      expect(
        rightClose.contentMaxX,
        lessThanOrEqualTo(759),
        reason:
            'the close-up must not move the visible trio out of the desktop '
            'viewport horizontally',
      );
      expect(
        rightClose.contentMaxY,
        lessThanOrEqualTo(419),
        reason:
            'the torso close-up can crop feet, but it should not move the shot '
            'outside the desktop canvas',
      );
      expect(
        rightHold.orangeCenterX,
        closeTo(rightClose.orangeCenterX, 24),
        reason:
            'the right feature should settle for a short held shot instead of '
            'drifting immediately back to centre',
      );
      // The bounds guard against a full zoom *jump* (which would be many tens of
      // percent taller/shorter); the exact height is a per-pixel readback that
      // drifts ~1-2% across rasterization backends (local arm64 vs CI x86_64),
      // so they carry margin around the observed push-in. The floor was 0.80
      // until the dance spine leveler (2026-07-04-head-level-probe) held the
      // head level over the crouch: the face now reads a touch smaller in the
      // settled hold relative to the push-in (ratio ~0.77), so the floor is
      // 0.72 with backend margin. Still well clear of an actual zoom jump, and
      // the viewport/centre assertions above confirm the shot stays framed.
      expect(
        rightHold.orangeHeight,
        inInclusiveRange(
          rightClose.orangeHeight * 0.72,
          rightClose.orangeHeight * 1.40,
        ),
        reason:
            'the right feature can begin the center push-in, but it should '
            'still read as a settled held shot rather than a zoom jump',
      );
      expect(
        leadLevel.orangeCenterX,
        closeTo(rightHold.orangeCenterX, 72),
        reason:
            'the right pass should ease through the lunge recovery instead of '
            'snapping straight back to the trio centre',
      );
      expect(
        leadLevel.orangeHeight,
        inInclusiveRange(
          rightClose.orangeHeight * 0.80,
          rightClose.orangeHeight * 1.34,
        ),
        reason:
            'the mid-phrase should stay in the close-shot band instead of '
            'dropping back to a full-body wide',
      );
      expect(
        leadLevel.contentMinY,
        greaterThan(2),
        reason: 'the tighter center close-up should not crop ears or heads',
      );
      expect(
        leadLevel.contentMaxY,
        lessThanOrEqualTo(419),
        reason:
            'the tighter center close-up should stay inside the desktop '
            'viewport',
      );
      expect(
        postRightRecovery.orangeCenterX,
        closeTo(leadLevel.orangeCenterX, 72),
        reason:
            'the truck/arc should glide through the centre instead of resetting '
            'to the original wide composition',
      );
      expect(
        postRightRecovery.orangeHeight,
        greaterThan(wide.orangeHeight * 1.5),
        reason:
            'the camera should still be in face/torso territory at the middle '
            'of the shot phrase',
      );
      expect(
        leftPan.orangeCenterX - postRightRecovery.orangeCenterX,
        inInclusiveRange(20, 116),
        reason:
            'the next beat should truck toward the left-side dancer, moving '
            'the lead right on screen',
      );
      // Upper bound recalibrated for member-scaled ribbon rendering (see the
      // dolly-in note above): the wide-shot denominator shrank.
      expect(
        leftClose.orangeHeight,
        inInclusiveRange(wide.orangeHeight * 1.34, wide.orangeHeight * 2.05),
        reason:
            'the left-side pass should stay visibly pushed in before the final '
            'pull-out',
      );
      expect(
        leftHold.orangeCenterX,
        closeTo(leftClose.orangeCenterX, 36),
        reason:
            'the left feature should also hold briefly before the wide reset',
      );
      expect(
        leftHold.orangeHeight,
        inInclusiveRange(
          wide.orangeHeight * 1.06,
          leftClose.orangeHeight * 1.25,
        ),
        reason:
            'the left-side hold should begin the pull-out without snapping '
            'straight back to the wide frame',
      );
      expect(
        reset.orangeHeight,
        closeTo(wide.orangeHeight, wide.orangeHeight * 0.14),
        reason: 'the final beat should return to the wide stage frame',
      );
      expect(
        lockedMid.orangeHeight,
        closeTo(lockedWide.orangeHeight, lockedWide.orangeHeight * 0.2),
        reason:
            'locked-camera review should preserve the choreo formation without '
            'the music-video zoom changing dancer size',
      );
      expect(
        lockedMid.orangeHeight,
        lessThan(leadLevel.orangeHeight * 0.68),
        reason:
            'turning off the dance camera should disable the close-up push-in',
      );
    });
  });

  testWidgets(
    'capped dance-camera strength keeps the left backup off the stage edge '
    'during the push-in (the "left cat cut off" fix)',
    (tester) async {
      await tester.runAsync(() async {
        // At FULL strength the push-in (zoom ~2.08 about centre) shoves the left
        // silver-tabby backup off the 16:9 stage box at the demo's scale — the
        // "left cat cut off well within the window" bug. The demo caps the
        // energetic ramp (kEnergeticCameraStrength) so the whole trio stays on
        // the locked stage. This renders both strengths at the demo's stage and
        // asserts the cap pulls the left backup clear of the edge it hit at full.
        Future<({int count, double centerX, int minX})> silverAt(
          double p,
          double strength,
        ) async {
          const size = Size(1333, 750); // demo-representative locked 16:9 stage
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          CharacterPainter(
            scene: scene,
            partnerScene: CharacterScene(
              buildCatInSuitRig(palette: CatInSuitPalette.silverTabby),
            ),
            ensembleScenes: [
              CharacterScene(
                buildCatInSuitRig(palette: CatInSuitPalette.silverTabby),
              ),
              CharacterScene(
                buildCatInSuitRig(palette: CatInSuitPalette.darkBrown),
              ),
            ],
            ensembleClips: [
              CatClips.shaku,
              CatClips.danceBackupLeft,
              CatClips.danceBackupRight,
            ],
            synchronousEnsemble: true,
            clip: CatClips.shaku,
            timeSeconds: CatClips.shaku.duration * p,
            walkingPair: true,
            danceCameraStrength: strength,
            scale: size.height * 0.78 / 300.0,
            shadowColor: const Color(0x00000000),
            renderer: renderer,
          ).paint(canvas, size);
          final picture = recorder.endRecording();
          try {
            final image = await picture.toImage(
              size.width.toInt(),
              size.height.toInt(),
            );
            try {
              final data = await image.toByteData();
              final pixels = data!.buffer.asUint8List();
              // Silver-tabby fur: light grey (channels close, mid-bright) — the
              // navy suit is blue-dominant and white eyes are >205, both excluded.
              final silver = _boundsForPixels(
                pixels,
                size.width.toInt(),
                size.height.toInt(),
                (red, green, blue, alpha, x, y) =>
                    alpha > 180 &&
                    red > 120 &&
                    red < 205 &&
                    (red - green).abs() < 24 &&
                    (green - blue).abs() < 24,
              );
              return (
                count: silver.count,
                centerX: silver.centerX,
                minX: silver.minX,
              );
            } finally {
              image.dispose();
            }
          } finally {
            picture.dispose();
          }
        }

        // Worst push-in phase (p=7/16: rising zoom into the right-feature hold).
        const worstPhase = 7 / 16;
        final full = await silverAt(worstPhase, 1);
        final capped = await silverAt(worstPhase, 0.5);

        // Full strength clips the left backup hard against the left edge...
        expect(
          full.minX,
          lessThan(8),
          reason:
              'at full strength the push-in should reach the stage edge (this is '
              'the bug the demo cap exists to prevent)',
        );
        // ...the capped strength pulls it clear, fully on the stage.
        expect(
          capped.minX,
          greaterThan(40),
          reason:
              'the capped energetic strength must hold the left backup clear of '
              'the stage edge so it is not cut off',
        );
        expect(
          capped.centerX,
          lessThan(1333 / 2),
          reason:
              'it must still read as the LEFT dancer (centre left of stage)',
        );
      });
    },
  );

  testWidgets(
    'director close shots keep hero-staged backup cats clear of the side edges',
    (tester) async {
      await tester.runAsync(() async {
        const size = Size(1333, 750); // demo-representative locked 16:9 stage
        const width = 1333;
        const height = 750;
        const edgeMargin = 12;
        const grade = (
          skyWrap: Color(0x2E1F3354),
          deckWrap: Color(0x2E3A2616),
        );

        Future<
          ({
            ({int minX, int maxX, int count}) silver,
            ({int minX, int maxX, int count}) dark,
          })
        >
        backupBounds(Shot shot, double phase) async {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          CharacterPainter(
            scene: scene,
            ensembleScenes: [
              CharacterScene(
                buildCatInSuitRig(palette: CatInSuitPalette.silverTabby),
              ),
              CharacterScene(
                buildCatInSuitRig(palette: CatInSuitPalette.darkBrown),
              ),
            ],
            ensembleClips: [
              CatClips.shaku,
              CatClips.danceBackupLeft,
              CatClips.danceBackupRight,
            ],
            synchronousEnsemble: true,
            walkingPair: true,
            clip: CatClips.shaku,
            timeSeconds: CatClips.shaku.duration * phase,
            cameraOverride: shot,
            heroStaging: true,
            bodyGrade: grade,
            scale: size.height * 0.78 / 300.0,
            shadowColor: const Color(0x00000000),
            renderer: renderer,
          ).paint(canvas, size);
          final picture = recorder.endRecording();
          try {
            final image = await picture.toImage(width, height);
            try {
              final data = await image.toByteData();
              final pixels = data!.buffer.asUint8List();
              final silver = _boundsForPixels(
                pixels,
                width,
                height,
                (red, green, blue, alpha, x, y) =>
                    x < width ~/ 2 &&
                    alpha > 150 &&
                    red > 110 &&
                    red < 220 &&
                    (red - green).abs() < 30 &&
                    (green - blue).abs() < 30,
              );
              final dark = _boundsForPixels(
                pixels,
                width,
                height,
                (red, green, blue, alpha, x, y) =>
                    x > width ~/ 2 &&
                    alpha > 150 &&
                    red < 95 &&
                    green < 90 &&
                    blue < 90,
              );
              return (
                silver: (
                  minX: silver.minX,
                  maxX: silver.maxX,
                  count: silver.count,
                ),
                dark: (minX: dark.minX, maxX: dark.maxX, count: dark.count),
              );
            } finally {
              image.dispose();
            }
          } finally {
            picture.dispose();
          }
        }

        // The centred coil keeps BOTH backups clear of the edges; a committed
        // feature hold (the bridge's singer features, per the review panel)
        // deliberately lets the OFF-side backup crop partially at the frame
        // edge — but every backup must always remain clearly VISIBLE (a cat
        // leaving frame entirely reads as a glitch), and the featured side
        // must be well inside the frame.
        final cases = [
          (
            label: 'post-chorus sway left',
            featured: null,
            shot: cameraShot(
              const DanceCameraContext(
                section: 'post-chorus',
                energetic: true,
                build: 0.9,
                phrasePhase: 0.75,
                sectionPhase: 0.45,
              ),
            ),
          ),
          (
            label: 'post-chorus sway right',
            featured: null,
            shot: cameraShot(
              const DanceCameraContext(
                section: 'post-chorus',
                energetic: true,
                build: 0.9,
                phrasePhase: 0.25,
                sectionPhase: 0.45,
              ),
            ),
          ),
          (
            label: 'bridge favours silver',
            featured: 'silver',
            shot: cameraShot(
              const DanceCameraContext(
                section: 'bridge',
                energetic: true,
                build: 0.9,
                phrasePhase: 0,
                sectionPhase: 0.25,
              ),
            ),
          ),
          (
            label: 'bridge favours dark',
            featured: 'dark',
            shot: cameraShot(
              const DanceCameraContext(
                section: 'bridge',
                energetic: true,
                build: 0.9,
                phrasePhase: 0,
                sectionPhase: 0.75,
              ),
            ),
          ),
        ];

        for (final phase in const [0.0, 0.25, 0.5, 0.75, 31 / 32]) {
          for (final c in cases) {
            final b = await backupBounds(c.shot, phase);
            expect(
              b.silver.count,
              greaterThan(250),
              reason: '${c.label} phase=$phase should find the silver backup',
            );
            expect(
              b.dark.count,
              greaterThan(250),
              reason: '${c.label} phase=$phase should find the dark backup',
            );
            if (c.featured != 'dark') {
              expect(
                b.silver.minX,
                greaterThan(edgeMargin),
                reason:
                    '${c.label} phase=$phase clipped silver at '
                    'x=${b.silver.minX}',
              );
            }
            if (c.featured != 'silver') {
              expect(
                b.dark.maxX,
                lessThan(width - edgeMargin),
                reason:
                    '${c.label} phase=$phase clipped dark at x=${b.dark.maxX}',
              );
            }
            if (c.featured == 'silver') {
              expect(
                b.silver.minX,
                greaterThan(edgeMargin),
                reason:
                    '${c.label} phase=$phase: the FEATURED silver backup must '
                    'sit well inside the frame (x=${b.silver.minX})',
              );
            }
            if (c.featured == 'dark') {
              expect(
                b.dark.maxX,
                lessThan(width - edgeMargin),
                reason:
                    '${c.label} phase=$phase: the FEATURED dark backup must '
                    'sit well inside the frame (x=${b.dark.maxX})',
              );
            }
          }
        }
      });
    },
  );

  group('danceParallaxMatrixForShotAtDepth', () {
    const size = Size(800, 450);
    // The director plants its pivot at the dancers' feet (0.90 of the height —
    // matching CharacterPainter.feetFraction's default, the actual floor line;
    // see _directorPivotFraction's doc comment) so a zoom grows the cast
    // upward; every plane scales about the SAME pivot or the scenery would
    // slide off the planted feet.
    const directorPivot = Offset(400, 450 * 0.90); // (400, 405)

    Matrix4 at(
      ({double zoom, double dx, double dy}) shot,
      double depth, {
      bool active = true,
      Size sz = size,
    }) => CharacterPainter.danceParallaxMatrixForShotAtDepth(
      shot: shot,
      size: sz,
      depth: depth,
      active: active,
    );

    test(
      'is identity when inactive, empty, or the plane is locked (depth<=0)',
      () {
        const shot = (zoom: 2.10, dx: 120.0, dy: 0.0);
        expect(at(shot, 0.3, active: false), Matrix4.identity());
        expect(at(shot, 0.3, sz: Size.zero), Matrix4.identity());
        expect(at(shot, 0), Matrix4.identity()); // locked at infinity
        expect(at(shot, -0.5), Matrix4.identity());
      },
    );

    test('a neutral shot leaves the plane untouched at any depth', () {
      expect(at((zoom: 1.0, dx: 0.0, dy: 0.0), 0.5), Matrix4.identity());
      expect(at((zoom: 1.0, dx: 0.0, dy: 0.0), 1), Matrix4.identity());
    });

    test(
      'depth scales the zoom linearly toward the full foreground push, '
      'for a deliberate push well clear of the small-move soft knee',
      () {
        // zoom entry = 1 + (shot.zoom - 1) * depth: a far plane (0.1) barely
        // grows; depth 1 matches the foreground camera exactly. The 1.10 zoom
        // delta clears _kParallaxZoomKnee at every depth here, so the soft
        // knee is a no-op and this is exactly the un-softened linear ladder.
        const shot = (zoom: 2.10, dx: 0.0, dy: 0.0);
        expect(
          at(shot, 0.1).entry(0, 0),
          moreOrLessEquals(1.11, epsilon: 1e-9),
        );
        expect(
          at(shot, 0.5).entry(0, 0),
          moreOrLessEquals(1.55, epsilon: 1e-9),
        );
        expect(at(shot, 1).entry(0, 0), moreOrLessEquals(2.10, epsilon: 1e-9));
      },
    );

    test(
      'a small move is damped harder on a far plane than on a near one '
      '(the soft knee)',
      () {
        // A 0.04 zoom delta sits BETWEEN the two planes' knees (far plane
        // knee at depth 0.12 is 0.06*0.88=0.0528; near plane knee at depth
        // 0.5 is 0.06*0.5=0.03), so the near plane already clears its knee
        // (full linear pass) while the far plane is still inside its softened
        // region: the ratio of actual growth to what pure linear scaling
        // would give is lower far than near.
        const shot = (zoom: 1.04, dx: 0.0, dy: 0.0);
        final far = at(shot, 0.12).entry(0, 0) - 1;
        final near = at(shot, 0.5).entry(0, 0) - 1;
        const farLinear = 0.04 * 0.12;
        const nearLinear = 0.04 * 0.5;
        expect(far / farLinear, lessThan(near / nearLinear));
        expect(near / nearLinear, moreOrLessEquals(1, epsilon: 1e-9));

        // A deliberate push (chorus-scale, 0.32 delta) clears the knee at
        // both depths and rides the plain linear ladder.
        const bigShot = (zoom: 1.32, dx: 0.0, dy: 0.0);
        expect(
          at(bigShot, 0.12).entry(0, 0) - 1,
          moreOrLessEquals(0.32 * 0.12, epsilon: 1e-9),
        );
        expect(
          at(bigShot, 0.5).entry(0, 0) - 1,
          moreOrLessEquals(0.32 * 0.5, epsilon: 1e-9),
        );
      },
    );

    test('scales about the feet-planted director pivot at any depth', () {
      // Under a pure zoom the pivot is the one point that maps to itself; the
      // head-height point (0.56h) is pulled up, so it is NOT the pivot.
      final m = at((zoom: 2.10, dx: 0.0, dy: 0.0), 0.5);
      final fixed = MatrixUtils.transformPoint(m, directorPivot);
      expect(fixed.dx, moreOrLessEquals(directorPivot.dx, epsilon: 1e-6));
      expect(fixed.dy, moreOrLessEquals(directorPivot.dy, epsilon: 1e-6));
      const headPivot = Offset(400, 450 * 0.56); // (400, 252)
      final movedHead = MatrixUtils.transformPoint(m, headPivot);
      expect(movedHead.dy, lessThan(headPivot.dy));
    });

    test('pans a plane by depth * the 2560-ref-rescaled dx', () {
      // dx authored in 2560-ref px; a plane at depth d drifts by dx*d rescaled to
      // the stage width (clamped to the margin the depth-zoom exposes).
      const shot = (zoom: 1.5, dx: 300.0, dy: 0.0);
      final panned = MatrixUtils.transformPoint(at(shot, 0.5), directorPivot);
      const expectedDx = 300.0 * 0.5 * 800 / 2560; // 46.875, within the clamp
      expect(
        panned.dx - directorPivot.dx,
        moreOrLessEquals(expectedDx, epsilon: 1e-6),
      );
      expect(panned.dx, greaterThan(directorPivot.dx));
    });

    test('a flat-zoom vertical nudge is clamped away (no headroom)', () {
      expect(at((zoom: 1.0, dx: 0.0, dy: 30.0), 0.5), Matrix4.identity());
    });

    test('a positive dy lowers a zoomed plane by depth * the rescaled dy', () {
      // dy scaled by depth then rescaled to the height: 40*0.5*450/1440 = 6.25.
      final nudged = MatrixUtils.transformPoint(
        at((zoom: 2.10, dx: 0.0, dy: 40.0), 0.5),
        directorPivot,
      );
      expect(
        nudged.dy - directorPivot.dy,
        moreOrLessEquals(6.25, epsilon: 1e-6),
      );
      expect(nudged.dy, greaterThan(directorPivot.dy));
    });

    test(
      'a nearer plane always parallaxes at least as much as a farther one',
      () {
        // Monotonic depth ladder: more depth -> more zoom growth and more pan.
        const shot = (zoom: 1.8, dx: 260.0, dy: 0.0);
        var prevZoom = 1.0;
        var prevPan = 0.0;
        for (final d in [0.1, 0.2, 0.3, 0.5, 0.8, 1.0]) {
          final m = at(shot, d);
          final zoom = m.entry(0, 0);
          final pan =
              MatrixUtils.transformPoint(m, directorPivot).dx -
              directorPivot.dx;
          expect(
            zoom,
            greaterThanOrEqualTo(prevZoom - 1e-9),
            reason: 'depth $d',
          );
          expect(pan, greaterThanOrEqualTo(prevPan - 1e-9), reason: 'depth $d');
          prevZoom = zoom;
          prevPan = pan;
        }
      },
    );

    glados.Glados(
      glados.any.parallaxCase,
      glados.ExploreConfig(numRuns: 300),
    ).test(
      'a plane stays finite, never zooms past the foreground, and grows with depth',
      (
        c,
      ) {
        final shot = (zoom: c.zoom, dx: c.dx, dy: c.dy);
        final m = CharacterPainter.danceParallaxMatrixForShotAtDepth(
          shot: shot,
          size: size,
          depth: c.depth,
        );
        final z = m.entry(0, 0);
        expect(z.isFinite, isTrue, reason: '$c');
        // A plane only ever grows about the pivot (never < 1) and never out-
        // zooms the foreground camera (depth 1).
        expect(z, greaterThanOrEqualTo(1 - 1e-9), reason: '$c');
        expect(z, lessThanOrEqualTo(c.zoom + 1e-9), reason: '$c');
        // Half the depth parallaxes no more than the full depth.
        final shallower = CharacterPainter.danceParallaxMatrixForShotAtDepth(
          shot: shot,
          size: size,
          depth: c.depth * 0.5,
        );
        expect(
          z,
          greaterThanOrEqualTo(shallower.entry(0, 0) - 1e-9),
          reason: '$c',
        );
      },
      tags: 'glados',
    );
  });

  testWidgets('a locomoting clip travels the cat across the stage', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // A clip with a non-zero locomotionSpeed enables the locomotion branch in
      // paint(): the centre walks (ping-pongs) instead of staying pinned.
      const walk = Clip(
        name: 'walk-test',
        duration: 1,
        channels: {},
        locomotionSpeed: 140,
      );
      Future<Uint8List> render(double t, {bool walkingPair = false}) async {
        final recorder = ui.PictureRecorder();
        CharacterPainter(
          scene: scene,
          partnerScene: walkingPair
              ? CharacterScene(
                  buildCatInSuitRig(palette: CatInSuitPalette.silverTabby),
                )
              : null,
          walkingPair: walkingPair,
          clip: walk,
          timeSeconds: t,
          locomote: true,
          shadowColor: const Color(0x00000000),
          renderer: renderer,
        ).paint(Canvas(recorder), const Size(360, 280));
        final picture = recorder.endRecording();
        final image = await picture.toImage(360, 280);
        final data = (await image.toByteData())!.buffer.asUint8List();
        image.dispose();
        picture.dispose();
        return data;
      }

      double centreX(Uint8List data) {
        var minX = 360;
        var maxX = -1;
        for (var y = 0; y < 280; y++) {
          for (var x = 0; x < 360; x++) {
            if (data[(y * 360 + x) * 4 + 3] != 0) {
              if (x < minX) minX = x;
              if (x > maxX) maxX = x;
            }
          }
        }
        return (minX + maxX) / 2;
      }

      final early = centreX(await render(0.15));
      final late = centreX(await render(0.75));
      expect(
        late,
        greaterThan(early + 20),
        reason:
            'locomote=true should travel the walking cat rightward over time',
      );

      // A walking PAIR exercises the group-half-width spacing branch, and a
      // phase past the band edge exercises the ping-pong return leg of the
      // travel triangle (movingRight == false).
      var pairPainted = 0;
      final pairFrame = await render(2, walkingPair: true);
      for (var i = 3; i < pairFrame.length; i += 4) {
        if (pairFrame[i] != 0) pairPainted++;
      }
      expect(
        pairPainted,
        greaterThan(0),
        reason: 'a locomoting walking pair still paints on the return leg',
      );
    });
  });

  testWidgets('reports per-dancer foot anchors in catalogue trio dance mode', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final lead in [CatClips.shaku, CatClips.zanku, CatClips.sekem]) {
        List<Offset>? reported;
        final recorder = ui.PictureRecorder();
        CharacterPainter(
          scene: scene,
          partnerScene: CharacterScene(
            buildCatInSuitRig(palette: CatInSuitPalette.silverTabby),
          ),
          ensembleScenes: [
            CharacterScene(
              buildCatInSuitRig(palette: CatInSuitPalette.silverTabby),
            ),
            CharacterScene(
              buildCatInSuitRig(palette: CatInSuitPalette.darkBrown),
            ),
          ],
          ensembleClips: [lead, lead, lead],
          synchronousEnsemble: true,
          walkingPair: true,
          clip: lead,
          timeSeconds: 0.25,
          // Locked camera so the reported anchors stay inside the canvas (the
          // dance camera's deep zoom can push feet past the frame edge).
          enableDanceCamera: false,
          shadowColor: const Color(0x00000000),
          onDancerAnchors: (anchors) => reported = anchors,
          renderer: renderer,
        ).paint(Canvas(recorder), const Size(760, 420));
        recorder.endRecording().dispose();

        expect(
          reported,
          isNotNull,
          reason: '${lead.name} should use trio mode',
        );
        expect(reported!.length, 3);
        for (final anchor in reported!) {
          expect(anchor.dx, inInclusiveRange(0.0, 1.0));
          expect(anchor.dy, inInclusiveRange(0.0, 1.0));
        }
        // Reported left→right by lane.
        expect(reported![0].dx, lessThan(reported![1].dx));
        expect(reported![1].dx, lessThan(reported![2].dx));
      }
    });
  });

  testWidgets('inter-cat parallax shears the trio under a lateral truck', (
    tester,
  ) async {
    await tester.runAsync(() async {
      List<Offset> anchorsFor(({double zoom, double dx, double dy}) shot) {
        List<Offset>? reported;
        final recorder = ui.PictureRecorder();
        CharacterPainter(
          scene: scene,
          partnerScene: CharacterScene(
            buildCatInSuitRig(palette: CatInSuitPalette.silverTabby),
          ),
          ensembleScenes: [
            CharacterScene(
              buildCatInSuitRig(palette: CatInSuitPalette.silverTabby),
            ),
            CharacterScene(
              buildCatInSuitRig(palette: CatInSuitPalette.darkBrown),
            ),
          ],
          ensembleClips: [
            CatClips.shaku,
            CatClips.danceBackupLeft,
            CatClips.danceBackupRight,
          ],
          synchronousEnsemble: true,
          walkingPair: true,
          clip: CatClips.shaku,
          timeSeconds: 0.25,
          cameraOverride: shot,
          shadowColor: const Color(0x00000000),
          onDancerAnchors: (anchors) => reported = anchors,
          renderer: renderer,
        ).paint(Canvas(recorder), const Size(760, 420));
        recorder.endRecording().dispose();
        return reported!;
      }

      // The inter-member gaps depend ONLY on the per-lane parallax (a uniform
      // camera pan shifts all three equally and cancels in the gaps), so any
      // change between a centred shot and a lateral truck is the shear itself.
      final centred = anchorsFor((zoom: 1.4, dx: 0, dy: 0));
      final trucked = anchorsFor((zoom: 1.4, dx: 380, dy: 0));

      final leftGapDelta =
          (trucked[1].dx - trucked[0].dx) - (centred[1].dx - centred[0].dx);
      final rightGapDelta =
          (trucked[2].dx - trucked[1].dx) - (centred[2].dx - centred[1].dx);

      // The upstage backups (depth < 1) lag the near lead on the rightward truck,
      // so the left gap widens and the right gap narrows by the same shear —
      // opposite signs, so the trio leans instead of sliding as one flat cut-out.
      expect(leftGapDelta, greaterThan(0.004));
      expect(rightGapDelta, lessThan(-0.004));
      expect(
        leftGapDelta,
        moreOrLessEquals(-rightGapDelta, epsilon: 1e-3),
        reason: 'both backups lag by the same amount',
      );
    });
  });

  testWidgets('a synchronous pair applies per-lane micro-timing offsets', (
    tester,
  ) async {
    await tester.runAsync(() async {
      Future<Uint8List> render({required bool synchronous}) async {
        final recorder = ui.PictureRecorder();
        CharacterPainter(
          scene: scene,
          partnerScene: CharacterScene(
            buildCatInSuitRig(palette: CatInSuitPalette.silverTabby),
          ),
          synchronousEnsemble: synchronous,
          walkingPair: true,
          clip: CatClips.shaku,
          timeSeconds: 0.3,
          shadowColor: const Color(0x00000000),
          renderer: renderer,
        ).paint(Canvas(recorder), const Size(420, 300));
        final picture = recorder.endRecording();
        final image = await picture.toImage(420, 300);
        final data = (await image.toByteData())!.buffer.asUint8List();
        image.dispose();
        picture.dispose();
        return data;
      }

      final synced = await render(synchronous: true);
      final staggered = await render(synchronous: false);
      var painted = 0;
      for (var i = 3; i < synced.length; i += 4) {
        if (synced[i] != 0) painted++;
      }
      expect(painted, greaterThan(0), reason: 'the synchronous pair paints');
      // Synchronous sampling uses the small per-lane micro-timing offsets
      // instead of the half-cycle stagger, so the two frames differ.
      expect(
        synced,
        isNot(equals(staggered)),
        reason: 'micro-timed phase differs from the half-cycle stagger',
      );
    });
  });

  testWidgets('singing head motion nods the head subtree on a dance clip', (
    tester,
  ) async {
    await tester.runAsync(() async {
      const singing = Expression(
        'sing',
        FaceState(mouthShape: MouthShape.singAh, mouthOpen: 0.7),
      );
      Future<Uint8List> render({required bool singHead}) async {
        final recorder = ui.PictureRecorder();
        CharacterPainter(
          scene: scene,
          clip: CatClips.shaku,
          // A phase where the continuous sway is clearly off-zero, so the head
          // transform actually moves (no early-out at tilt==0 && dip==0).
          timeSeconds: CatClips.shaku.duration * 0.45,
          expression: singing,
          singingHeadMotion: singHead,
          shadowColor: const Color(0x00000000),
          renderer: renderer,
        ).paint(Canvas(recorder), const Size(220, 300));
        final picture = recorder.endRecording();
        final image = await picture.toImage(220, 300);
        final data = (await image.toByteData())!.buffer.asUint8List();
        image.dispose();
        picture.dispose();
        return data;
      }

      final still = await render(singHead: false);
      final nodding = await render(singHead: true);
      // The face state is identical in both; only the head subtree transform
      // differs, so any pixel change is the nod/dip.
      expect(
        nodding,
        isNot(equals(still)),
        reason: 'singingHeadMotion bobs and dips the head subtree',
      );
    });
  });

  testWidgets('Moving uses one authored head clock, not a second vocal bob', (
    tester,
  ) async {
    await tester.runAsync(() async {
      const singing = Expression(
        'sing',
        FaceState(mouthShape: MouthShape.singAh, mouthOpen: 0.7),
      );
      Future<Uint8List> render({required bool singHead}) async {
        final recorder = ui.PictureRecorder();
        CharacterPainter(
          scene: scene,
          clip: CatClips.movingGrooveLowCounter,
          timeSeconds: CatClips.movingGrooveLowCounter.duration * 0.45,
          expression: singing,
          singingHeadMotion: singHead,
          shadowColor: const Color(0x00000000),
          renderer: renderer,
        ).paint(Canvas(recorder), const Size(220, 300));
        final picture = recorder.endRecording();
        final image = await picture.toImage(220, 300);
        final data = (await image.toByteData())!.buffer.asUint8List();
        image.dispose();
        picture.dispose();
        return data;
      }

      expect(
        await render(singHead: true),
        equals(await render(singHead: false)),
        reason:
            'Moving already authors head rotation and must stay seated on the '
            'neck instead of receiving another painter-level nod',
      );
    });
  });

  testWidgets(
    'a looping activeSpan contact clip floor-pins via the loop span',
    (
      tester,
    ) async {
      await tester.runAsync(() async {
        // loop + activeSpan pinning + contactSpans (and NOT a locomoting clip)
        // reaches the looping branch of _spanStartTime.
        const pinClip = Clip(
          name: 'loop-pin',
          duration: 2,
          channels: {},
          contactSpans: [
            GroundSpan(CatBones.footL, 0, 0.5),
            GroundSpan(CatBones.footR, 0.5, 1),
          ],
        );
        final recorder = ui.PictureRecorder();
        CharacterPainter(
          scene: scene,
          clip: pinClip,
          // Past one whole loop (raw=1.3 -> phase 0.3 -> footL span).
          timeSeconds: 2.6,
          feetFraction: 0.8,
          shadowColor: const Color(0x00000000),
          renderer: renderer,
        ).paint(Canvas(recorder), const Size(220, 300));
        final picture = recorder.endRecording();
        final image = await picture.toImage(220, 300);
        final data = (await image.toByteData())!.buffer.asUint8List();
        image.dispose();
        picture.dispose();
        // The figure renders with its support foot held on the floor line.
        final floorBand = _opaquePixelsInBox(data, 220, 0, 219, 232, 248);
        expect(
          floorBand,
          greaterThan(0),
          reason: 'the looping support foot stays pinned to the floor line',
        );
      });
    },
  );

  testWidgets('a groundSpans clip casts per-foot deck shadows', (tester) async {
    await tester.runAsync(() async {
      // groundSpans (no contactSpans) with a double-support GAP: at t=0.5 the
      // phase falls in the 0.4..0.6 gap, so _activeGroundSpan falls back to its
      // last span and _shadowBones reads the groundSpans path.
      const groundClip = Clip(
        name: 'ground-shadow',
        duration: 1,
        channels: {},
        groundSpans: [
          GroundSpan(CatBones.footL, 0, 0.4),
          GroundSpan(CatBones.footR, 0.6, 1),
        ],
      );
      final recorder = ui.PictureRecorder();
      CharacterPainter(
        scene: scene,
        clip: groundClip,
        timeSeconds: 0.5,
        feetFraction: 0.8,
        shadowColor: const Color(0xAA000000),
        renderer: renderer,
      ).paint(Canvas(recorder), const Size(220, 300));
      final picture = recorder.endRecording();
      final image = await picture.toImage(220, 300);
      final data = (await image.toByteData())!.buffer.asUint8List();
      image.dispose();
      picture.dispose();
      final floorShadow = _opaquePixelsInBox(data, 220, 0, 219, 236, 250);
      expect(
        floorShadow,
        greaterThan(0),
        reason:
            'groundSpans feed _shadowBones so the contact feet cast shadows',
      );
    });
  });

  testWidgets('danceViewProjection turns the trio into a three-quarter view', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // The opt-in dance view projection foreshortens each member (0.68 for
      // the flanking backups, 0.84 for the lead), shears them toward the
      // camera, and depth-offsets the solved frame — the trio stops reading
      // as flat frontal cutouts. The camera is locked so the only difference
      // between the two renders is the projection itself.
      const size = Size(1333, 750);
      Future<Uint8List> render({required bool projected}) async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        CharacterPainter(
          scene: scene,
          ensembleScenes: [
            CharacterScene(
              buildCatInSuitRig(palette: CatInSuitPalette.silverTabby),
            ),
            CharacterScene(
              buildCatInSuitRig(palette: CatInSuitPalette.darkBrown),
            ),
          ],
          ensembleClips: [
            CatClips.shaku,
            CatClips.danceBackupLeft,
            CatClips.danceBackupRight,
          ],
          synchronousEnsemble: true,
          walkingPair: true,
          clip: CatClips.shaku,
          timeSeconds: CatClips.shaku.duration * 0.3,
          enableDanceCamera: false,
          danceViewProjection: projected,
          scale: size.height * 0.78 / 300.0,
          shadowColor: const Color(0x00000000),
          renderer: renderer,
        ).paint(canvas, size);
        final picture = recorder.endRecording();
        try {
          final image = await picture.toImage(
            size.width.toInt(),
            size.height.toInt(),
          );
          try {
            final data = await image.toByteData();
            return data!.buffer.asUint8List();
          } finally {
            image.dispose();
          }
        } finally {
          picture.dispose();
        }
      }

      final flat = await render(projected: false);
      final turned = await render(projected: true);
      expect(
        turned,
        isNot(equals(flat)),
        reason: 'the quarter-turn projection must change the staged render',
      );

      var flatPainted = 0;
      var turnedPainted = 0;
      for (var i = 3; i < flat.length; i += 4) {
        if (flat[i] != 0) flatPainted++;
        if (turned[i] != 0) turnedPainted++;
      }
      expect(
        turnedPainted,
        lessThan(flatPainted - 2000),
        reason:
            'foreshortening every dancer toward the lead must shrink the '
            'painted silhouette area (flat=$flatPainted '
            'turned=$turnedPainted)',
      );
    });
  });
}

int _opaquePixelsInBox(
  Uint8List pixels,
  int width,
  int minX,
  int maxX,
  int minY,
  int maxY,
) {
  final left = minX.clamp(0, width - 1);
  final right = maxX.clamp(0, width - 1);
  var opaque = 0;
  for (var y = minY; y <= maxY; y++) {
    for (var x = left; x <= right; x++) {
      if (pixels[(y * width + x) * 4 + 3] != 0) opaque++;
    }
  }
  return opaque;
}

({double x, double y}) _visibleCenter(Uint8List pixels, int width, int height) {
  var minX = width;
  var maxX = 0;
  var minY = height;
  var maxY = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (pixels[(y * width + x) * 4 + 3] == 0) continue;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }
  return (x: (minX + maxX) / 2, y: (minY + maxY) / 2);
}

({
  int minX,
  int maxX,
  int minY,
  int maxY,
  int count,
  double centerX,
})
_boundsForPixels(
  Uint8List pixels,
  int width,
  int height,
  bool Function(int red, int green, int blue, int alpha, int x, int y)
  predicate,
) {
  var minX = width;
  var maxX = -1;
  var minY = height;
  var maxY = -1;
  var count = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final offset = (y * width + x) * 4;
      if (!predicate(
        pixels[offset],
        pixels[offset + 1],
        pixels[offset + 2],
        pixels[offset + 3],
        x,
        y,
      )) {
        continue;
      }
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
      count++;
    }
  }
  expect(maxX, greaterThanOrEqualTo(minX));
  expect(maxY, greaterThanOrEqualTo(minY));
  return (
    minX: minX,
    maxX: maxX,
    minY: minY,
    maxY: maxY,
    count: count,
    centerX: (minX + maxX) / 2,
  );
}

({int r, int g, int b, int a}) _rgbaAt(
  Uint8List pixels,
  int width,
  int x,
  int y,
) {
  final offset = (y * width + x) * 4;
  return (
    r: pixels[offset],
    g: pixels[offset + 1],
    b: pixels[offset + 2],
    a: pixels[offset + 3],
  );
}

Future<ui.Image> _imageFromFile(String path) async {
  final bytes = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}
