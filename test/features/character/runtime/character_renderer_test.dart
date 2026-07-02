import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dancing_cats/features/character/model/affine2d.dart';
import 'package:dancing_cats/features/character/model/bone.dart';
import 'package:dancing_cats/features/character/model/face.dart';
import 'package:dancing_cats/features/character/model/rig_spec.dart';
import 'package:dancing_cats/features/character/runtime/character_renderer.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders a single-bone rig of [drawable] centred on a [w]x[h] canvas and
/// returns the RGBA bytes. The bone sits at the canvas centre with identity
/// pose, so the drawable's local geometry maps straight to pixels.
Future<Uint8List> _renderOne(
  BoneDrawable drawable, {
  int w = 120,
  int h = 160,
  CelShadeSpec? celShade,
}) async {
  final rig = RigSpec(
    name: 't',
    bones: [
      Bone(
        id: 'b',
        parent: null,
        pivotX: 0,
        pivotY: 0,
        z: 0,
        drawable: drawable,
      ),
    ],
    celShade: celShade,
  );
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final world = {'b': Affine2D.translation(w / 2, h * 0.2)};
  CharacterRenderer(
    antiAlias: false,
  ).paint(canvas, rig, world, const FaceState());
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  final data = await image.toByteData();
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

/// Counts painted (non-transparent) pixels in row [y] of a [w]-wide RGBA buffer.
int _rowWidth(Uint8List px, int w, int y) {
  var n = 0;
  for (var x = 0; x < w; x++) {
    if (px[(y * w + x) * 4 + 3] != 0) n++;
  }
  return n;
}

const int _faceW = 160;
const int _faceH = 160;

/// Renders just the cat face (the body bones get no world transform, so only the
/// head-anchored face draws) with [face] applied, returning the RGBA bytes. Used
/// to assay the singing-mouth cavity by exact fill colour (anti-aliasing off, so
/// every fill is its exact colour).
Future<Uint8List> _renderFace(FaceState face) async {
  final rig = buildCatInSuitRig();
  final world = {
    rig.face!.anchorBoneId: Affine2D.translation(_faceW / 2, _faceH / 2),
  };
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  CharacterRenderer(antiAlias: false).paint(canvas, rig, world, face);
  final picture = recorder.endRecording();
  final image = await picture.toImage(_faceW, _faceH);
  final data = await image.toByteData();
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

/// Renders an arbitrary [rig] with the supplied [world] transforms onto a
/// [w]x[h] canvas (anti-aliasing off) and returns the RGBA bytes. Used to drive
/// ribbon/mesh draw orders the single-bone [_renderOne] cannot express.
Future<Uint8List> _renderRig(
  RigSpec rig,
  Map<String, Affine2D> world, {
  int w = 120,
  int h = 160,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  CharacterRenderer(
    antiAlias: false,
  ).paint(canvas, rig, world, const FaceState());
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  final data = await image.toByteData();
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

/// Counts pixels that exactly match the opaque 0xAARRGGBB [argb].
int _countColor(Uint8List px, int argb) {
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  var n = 0;
  for (var i = 0; i + 3 < px.length; i += 4) {
    if (px[i] == r && px[i + 1] == g && px[i + 2] == b && px[i + 3] == 255) n++;
  }
  return n;
}

/// Counts exact-[argb] pixels inside the `[x0,x1) × [y0,y1)` window of the
/// [_faceW]-wide face buffer — used to assert a feature lands in a region.
int _countColorInRect(
  Uint8List px,
  int argb,
  int x0,
  int x1,
  int y0,
  int y1,
) {
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  var n = 0;
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      final i = (y * _faceW + x) * 4;
      if (px[i] == r && px[i + 1] == g && px[i + 2] == b && px[i + 3] == 255) {
        n++;
      }
    }
  }
  return n;
}

/// The widest single row (in pixels) of an exact-[argb] fill — a cheap proxy for
/// a shape's maximum width.
int _maxRowOfColor(Uint8List px, int argb) {
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  var best = 0;
  for (var y = 0; y < _faceH; y++) {
    var c = 0;
    for (var x = 0; x < _faceW; x++) {
      final i = (y * _faceW + x) * 4;
      if (px[i] == r && px[i + 1] == g && px[i + 2] == b && px[i + 3] == 255) {
        c++;
      }
    }
    if (c > best) best = c;
  }
  return best;
}

// The crafted singing-mouth interior and the cat's pink nose (== the tongue).
const int _cavity = 0xFF241F2E;
const int _nosePink = 0xFFC8696B;

void main() {
  const w = 120;
  const h = 160;

  testWidgets('celShade lifts the lit side and darkens the shade side', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // A neutral-grey panel so both the lifted highlight and the darkened shade
      // are visible against the flat fill (a near-black fill would hide the
      // shade — exactly the body-crush the highlight tone solves).
      const panel = BoneDrawable(
        kind: BoneShapeKind.roundedRect,
        width: 70,
        height: 110,
        cornerRadius: 16,
        dy: 50,
        color: 0xFF808080,
      );
      final flat = await _renderOne(panel);
      final shaded = await _renderOne(panel, celShade: const CelShadeSpec());
      // Shape centre ≈ (60, 0.2*160 + 50 = 82). Light comes from the upper-left,
      // so the upper-left reads lighter and the lower-right darker than flat.
      int lum(Uint8List px, int x, int y) {
        final o = (y * w + x) * 4;
        return px[o] + px[o + 1] + px[o + 2];
      }

      expect(
        lum(shaded, 42, 56),
        greaterThan(lum(flat, 42, 56) + 24),
        reason: 'lit upper-left is lifted toward the highlight',
      );
      expect(
        lum(shaded, 80, 110),
        lessThan(lum(flat, 80, 110) - 24),
        reason: 'shade lower-right is darkened toward the cool shade',
      );
    });
  });

  testWidgets('celShade:false skips the directional ramp (flat fill)', (
    tester,
  ) async {
    await tester.runAsync(() async {
      const shaded = BoneDrawable(
        kind: BoneShapeKind.roundedRect,
        width: 70,
        height: 110,
        cornerRadius: 16,
        dy: 50,
        color: 0xFF808080,
      );
      const optedOut = BoneDrawable(
        kind: BoneShapeKind.roundedRect,
        width: 70,
        height: 110,
        cornerRadius: 16,
        dy: 50,
        color: 0xFF808080,
        celShade: false,
      );
      // Same directional cel-shade for the shaded shape; only the celShade
      // opt-out differs, so the diff isolates the gate.
      final withRamp = await _renderOne(shaded, celShade: const CelShadeSpec());
      final withoutRamp = await _renderOne(
        optedOut,
        celShade: const CelShadeSpec(),
      );
      final flat = await _renderOne(optedOut); // no celShade supplied at all
      int lum(Uint8List px, int x, int y) {
        final o = (y * w + x) * 4;
        return px[o] + px[o + 1] + px[o + 2];
      }

      // The shaded shape lifts the lit upper-left and darkens the shade
      // lower-right; the opted-out shape does NEITHER — it stays the flat fill,
      // so no sheen can streak the small paw volumes.
      expect(
        lum(withRamp, 42, 56),
        greaterThan(lum(withoutRamp, 42, 56) + 20),
        reason: 'only the shaded shape gets a lit-side sheen',
      );
      expect(
        lum(withRamp, 80, 110),
        lessThan(lum(withoutRamp, 80, 110) - 20),
        reason: 'only the shaded shape gets a shade-side darkening',
      );
      expect(
        lum(withoutRamp, 42, 56),
        closeTo(lum(flat, 42, 56).toDouble(), 1),
        reason: 'celShade:false renders identically to no cel-shade at all',
      );
    });
  });

  testWidgets('celShade form-rounding darkens the contour, not the centre', (
    tester,
  ) async {
    await tester.runAsync(() async {
      const panel = BoneDrawable(
        kind: BoneShapeKind.roundedRect,
        width: 70,
        height: 110,
        cornerRadius: 16,
        dy: 50,
        color: 0xFF808080,
      );
      // Identical directional cel-shade both times; only the form-rounding
      // occlusion differs, so the diff isolates the rounding (a per-shape
      // inner-edge darkening that makes the volume bulge in the middle).
      final noRound = await _renderOne(panel, celShade: const CelShadeSpec());
      final rounded = await _renderOne(
        panel,
        celShade: const CelShadeSpec(roundAmount: 0.6),
      );
      int lum(Uint8List px, int x, int y) {
        final o = (y * w + x) * 4;
        return px[o] + px[o + 1] + px[o + 2];
      }

      // Shape centre ≈ (60, 82); the left contour sits at ≈ x=25 at that height.
      final dropEdge = lum(noRound, 28, 82) - lum(rounded, 28, 82);
      final dropCentre = lum(noRound, 60, 82) - lum(rounded, 60, 82);
      expect(
        dropEdge,
        greaterThan(24),
        reason: 'form-rounding darkens the volume toward its contour',
      );
      expect(
        dropEdge,
        greaterThan(dropCentre + 20),
        reason:
            'the centre stays lit (bulges) while the edge falls to occlusion',
      );
    });
  });

  testWidgets('formRound:false on a shape skips the contour occlusion', (
    tester,
  ) async {
    await tester.runAsync(() async {
      const rounding = CelShadeSpec(roundAmount: 0.6);
      const rounded = BoneDrawable(
        kind: BoneShapeKind.roundedRect,
        width: 70,
        height: 110,
        cornerRadius: 16,
        dy: 50,
        color: 0xFF808080,
      );
      const optedOut = BoneDrawable(
        kind: BoneShapeKind.roundedRect,
        width: 70,
        height: 110,
        cornerRadius: 16,
        dy: 50,
        color: 0xFF808080,
        formRound: false,
      );
      // Same directional cel-shade both times; only the form-round opt-out
      // differs, so the contour diff isolates the gate.
      final withRound = await _renderOne(rounded, celShade: rounding);
      final withoutRound = await _renderOne(optedOut, celShade: rounding);
      int lum(Uint8List px, int x, int y) {
        final o = (y * w + x) * 4;
        return px[o] + px[o + 1] + px[o + 2];
      }

      // At the left contour (≈ x=28, y=82) the opted-out shape stays markedly
      // brighter — no occlusion ring darkens it.
      final edgeLift = lum(withoutRound, 28, 82) - lum(withRound, 28, 82);
      expect(
        edgeLift,
        greaterThan(24),
        reason: 'formRound:false leaves the contour undarkened',
      );
    });
  });

  testWidgets('taperedCapsule is wide at the top and narrows to the tip', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // Wide near end (40) tapering to a narrow tip (10) over 100 units, hung
      // from the bone origin at 0.2*h. So row ~origin is wide, row near the
      // bottom of the shape is narrow.
      final px = await _renderOne(
        const BoneDrawable(
          kind: BoneShapeKind.taperedCapsule,
          width: 40,
          widthTip: 10,
          height: 100,
          dy: 50,
          color: 0xFF2E3A59,
        ),
      );
      final topY = (h * 0.2).round() + 12; // just below the wide cap
      final bottomY = (h * 0.2).round() + 88; // near the narrow tip
      final topWidth = _rowWidth(px, w, topY);
      final bottomWidth = _rowWidth(px, w, bottomY);

      expect(topWidth, greaterThan(0), reason: 'shape should paint near top');
      expect(
        bottomWidth,
        greaterThan(0),
        reason: 'shape should paint near tip',
      );
      expect(
        topWidth,
        greaterThan(bottomWidth + 8),
        reason:
            'tapered: the joint end must be clearly wider than the tip '
            '(top=$topWidth, bottom=$bottomWidth)',
      );
    });
  });

  testWidgets('taperedCapsule with no widthTip falls back to a straight tube', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // widthTip defaults to -1 -> uniform width; top and tip widths match.
      final px = await _renderOne(
        const BoneDrawable(
          kind: BoneShapeKind.taperedCapsule,
          width: 30,
          height: 100,
          dy: 50,
          color: 0xFF2E3A59,
        ),
      );
      final topWidth = _rowWidth(px, w, (h * 0.2).round() + 20);
      final bottomWidth = _rowWidth(px, w, (h * 0.2).round() + 80);
      expect(topWidth, greaterThan(0));
      expect(
        (topWidth - bottomWidth).abs(),
        lessThanOrEqualTo(2),
        reason:
            'no taper -> near-uniform width (top=$topWidth, '
            'bottom=$bottomWidth)',
      );
    });
  });

  testWidgets('every shape kind paints something', (tester) async {
    await tester.runAsync(() async {
      for (final kind in BoneShapeKind.values) {
        final px = await _renderOne(
          BoneDrawable(
            kind: kind,
            width: 40,
            widthTip: 12,
            height: 40,
            cornerRadius: 8,
            color: 0xFFE8A55A,
            outlineColor: 0xFF1B1B2A,
            outlineWidth: 2,
          ),
        );
        var painted = 0;
        for (var i = 3; i < px.length; i += 4) {
          if (px[i] != 0) painted++;
        }
        expect(painted, greaterThan(50), reason: '$kind should paint');
      }
    });
  });

  testWidgets('singing mouth opens wider as mouthOpen grows', (tester) async {
    await tester.runAsync(() async {
      final small = _countColor(
        await _renderFace(
          const FaceState(mouthShape: MouthShape.singAh, mouthOpen: 0.2),
        ),
        _cavity,
      );
      final big = _countColor(
        await _renderFace(
          const FaceState(mouthShape: MouthShape.singAh, mouthOpen: 0.58),
        ),
        _cavity,
      );
      expect(small, greaterThan(0), reason: 'a cracked mouth shows a cavity');
      expect(
        big,
        greaterThan(small * 1.4),
        reason:
            'the cavity grows clearly with mouthOpen (small=$small big=$big)',
      );
    });
  });

  testWidgets('singing mouth is shut below the closed threshold', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final cavity = _countColor(
        await _renderFace(
          const FaceState(mouthShape: MouthShape.singAh, mouthOpen: 0.08),
        ),
        _cavity,
      );
      expect(
        cavity,
        lessThan(4),
        reason:
            'below 0.12 the mouth is a thin lip line, not an open cavity '
            '(got $cavity)',
      );
    });
  });

  testWidgets('tongue appears only when the mouth opens wide', (tester) async {
    await tester.runAsync(() async {
      // The pink nose is constant, so any extra pink when open is the tongue.
      final closed = _countColor(
        await _renderFace(
          const FaceState(mouthShape: MouthShape.singAh, mouthOpen: 0.08),
        ),
        _nosePink,
      );
      final open = _countColor(
        await _renderFace(
          const FaceState(mouthShape: MouthShape.singAh, mouthOpen: 0.85),
        ),
        _nosePink,
      );
      expect(
        open,
        greaterThan(closed + 15),
        reason:
            'a wide mouth adds a pink tongue past the static nose '
            '(closed=$closed open=$open)',
      );
    });
  });

  testWidgets('the ee viseme is wider than the oh viseme', (tester) async {
    await tester.runAsync(() async {
      final ee = _maxRowOfColor(
        await _renderFace(
          const FaceState(mouthShape: MouthShape.singEe, mouthOpen: 0.58),
        ),
        _cavity,
      );
      final oh = _maxRowOfColor(
        await _renderFace(
          const FaceState(mouthShape: MouthShape.singOh, mouthOpen: 0.58),
        ),
        _cavity,
      );
      expect(
        ee,
        greaterThan(oh + 4),
        reason:
            'ee is the wide viseme, oh the narrow/round one (ee=$ee oh=$oh)',
      );
    });
  });

  testWidgets('teethOnLip (F/V) renders a distinct parted mouth', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // The only difference between the two renders is the mouth, so the count
      // of differing pixels is exactly the F/V mouth — proving the cue draws a
      // distinct shape and never silently falls through to the shut mouth.
      final fv = await _renderFace(
        const FaceState(mouthShape: MouthShape.teethOnLip),
      );
      final closed = await _renderFace(
        const FaceState(mouthShape: MouthShape.singAh),
      );
      var diff = 0;
      for (var i = 0; i + 3 < fv.length; i += 4) {
        if (fv[i] != closed[i] ||
            fv[i + 1] != closed[i + 1] ||
            fv[i + 2] != closed[i + 2] ||
            fv[i + 3] != closed[i + 3]) {
          diff++;
        }
      }
      expect(
        diff,
        greaterThan(40),
        reason: 'F/V is a distinct mouth, not a shut one (diff=$diff)',
      );
    });
  });

  testWidgets('each open eye carries a specular catchlight', (tester) async {
    await tester.runAsync(() async {
      // The face anchors at (80, 80); eyes sit at x≈65 / x≈95, y≈46. The
      // catchlight is a unique near-white (0xFFF6F8FF, distinct from the cream
      // sclera) drawn up toward the key light on each iris — the spec highlight
      // that turns a flat button eye into a wet, alive one.
      final open = await _renderFace(const FaceState());
      const catchlight = 0xFFF6F8FF;
      final left = _countColorInRect(open, catchlight, 50, 80, 30, 60);
      final right = _countColorInRect(open, catchlight, 80, 110, 30, 60);
      expect(left, greaterThan(0), reason: 'left eye has a catchlight');
      expect(right, greaterThan(0), reason: 'right eye has a catchlight');

      // Shutting the lids crops the iris and its catchlight away entirely, so a
      // blink loses the highlight rather than leaving it floating on a lid line.
      final shut = await _renderFace(
        const FaceState(eyeOpenLeft: 0, eyeOpenRight: 0),
      );
      expect(
        _countColor(shut, catchlight),
        0,
        reason: 'closed eyes paint no catchlight',
      );
    });
  });

  testWidgets('cel-shading clips its ramp to a capsule volume', (tester) async {
    await tester.runAsync(() async {
      // A capsule fill exercises the capsule arm of the cel-shade clip switch
      // (_clipKind), which the rounded-rect cases above never reach.
      const capsule = BoneDrawable(
        kind: BoneShapeKind.capsule,
        width: 44,
        height: 110,
        dy: 50,
        color: 0xFF808080,
      );
      final flat = await _renderOne(capsule);
      final shaded = await _renderOne(capsule, celShade: const CelShadeSpec());
      int lum(Uint8List px, int x, int y) {
        final o = (y * w + x) * 4;
        return px[o] + px[o + 1] + px[o + 2];
      }

      // Centre ≈ (60, 82); the light comes from the upper-left, so inside the
      // pill the upper-left lifts and the lower-right darkens vs the flat fill.
      expect(
        lum(shaded, 48, 58),
        greaterThan(lum(flat, 48, 58) + 15),
        reason: 'the capsule cel-ramp lifts the lit side',
      );
      expect(
        lum(shaded, 72, 106),
        lessThan(lum(flat, 72, 106) - 15),
        reason: 'the capsule cel-ramp darkens the shade side',
      );
    });
  });

  testWidgets(
    'ribbons and meshes above the last bone z are flushed (and cel-shaded)',
    (tester) async {
      await tester.runAsync(() async {
        // A ribbon (z=50) and mesh (z=60) both sit ABOVE the only bone (z=0), so
        // the main draw loop never consumes them — they fall through to the
        // trailing flush loops at the end of _drawFills. With a CelShadeSpec the
        // flush also runs the ribbon/mesh cel-shade passes.
        RigSpec build({CelShadeSpec? celShade}) => RigSpec(
          name: 'flush',
          celShade: celShade,
          bones: const [
            Bone(
              id: 'root',
              parent: null,
              pivotX: 0,
              pivotY: 0,
              z: 0,
              drawable: BoneDrawable(
                kind: BoneShapeKind.ellipse,
                width: 16,
                height: 16,
                color: 0xFF606060,
              ),
            ),
            Bone(id: 'tip', parent: 'root', pivotX: 0, pivotY: 50, z: 0),
          ],
          ribbons: [
            LimbRibbonSpec(
              id: 'r',
              jointBoneIds: const ['root', 'tip'],
              halfWidths: const [12, 9],
              z: 50,
              color: 0xFF3F6FB0,
            ),
          ],
          meshes: [
            SkinnedMeshSpec(
              id: 'm',
              z: 60,
              color: 0xFFB07A3F,
              vertices: const [
                SkinnedMeshVertex([
                  MeshInfluence(boneId: 'root', x: -22, y: -22, weight: 1),
                ]),
                SkinnedMeshVertex([
                  MeshInfluence(boneId: 'root', x: 22, y: -22, weight: 1),
                ]),
                SkinnedMeshVertex([
                  MeshInfluence(boneId: 'root', x: 0, y: 24, weight: 1),
                ]),
              ],
              boundary: const [0, 1, 2],
            ),
          ],
        );
        final world = {
          'root': Affine2D.translation(60, 70),
          'tip': Affine2D.translation(60, 120),
        };
        final plain = await _renderRig(build(), world);
        final shaded = await _renderRig(
          build(celShade: const CelShadeSpec(roundAmount: 0.6)),
          world,
        );
        var plainPainted = 0;
        var diff = 0;
        for (var i = 0; i + 3 < plain.length; i += 4) {
          if (plain[i + 3] != 0) plainPainted++;
          if (plain[i] != shaded[i] ||
              plain[i + 1] != shaded[i + 1] ||
              plain[i + 2] != shaded[i + 2] ||
              plain[i + 3] != shaded[i + 3]) {
            diff++;
          }
        }
        expect(
          plainPainted,
          greaterThan(200),
          reason: 'the high-z ribbon + mesh are flushed and painted',
        );
        expect(
          diff,
          greaterThan(50),
          reason: 'the cel-shade flush passes re-tint the ribbon + mesh',
        );
      });
    },
  );

  testWidgets(
    'mesh ink seams stroke in z-order and flush above the last bone',
    (tester) async {
      await tester.runAsync(() async {
        const lowFill = 0xFF3A5A2A;
        const lowSeam = 0xFF102040;
        const highFill = 0xFFB07A3F;
        const highSeam = 0xFF601050;
        RigSpec build({required bool smoothLow}) => RigSpec(
          name: 'seams',
          bones: const [
            Bone(id: 'root', parent: null, pivotX: 0, pivotY: 0, z: 0),
          ],
          meshes: [
            // z (and thus inkSeamZ) below the only bone: the seams are
            // consumed INSIDE the draw-order loop, right after the fill.
            SkinnedMeshSpec(
              id: 'low',
              z: -1,
              color: lowFill,
              outlineColor: lowSeam,
              smoothBoundary: smoothLow,
              vertices: const [
                SkinnedMeshVertex([
                  MeshInfluence(boneId: 'root', x: -40, y: -30, weight: 1),
                ]),
                SkinnedMeshVertex([
                  MeshInfluence(boneId: 'root', x: 0, y: -30, weight: 1),
                ]),
                SkinnedMeshVertex([
                  MeshInfluence(boneId: 'root', x: -20, y: 20, weight: 1),
                ]),
              ],
              boundary: const [0, 1, 2],
              inkSeams: const [
                [0, 1, 2],
              ],
              inkSeamWidth: 3,
            ),
            // inkSeamZ above every bone: fill AND seams fall through to the
            // trailing flush loops at the end of _drawFills.
            SkinnedMeshSpec(
              id: 'high',
              z: 60,
              color: highFill,
              outlineColor: highSeam,
              vertices: const [
                SkinnedMeshVertex([
                  MeshInfluence(boneId: 'root', x: 10, y: -30, weight: 1),
                ]),
                SkinnedMeshVertex([
                  MeshInfluence(boneId: 'root', x: 50, y: -30, weight: 1),
                ]),
                SkinnedMeshVertex([
                  MeshInfluence(boneId: 'root', x: 30, y: 20, weight: 1),
                ]),
              ],
              boundary: const [0, 1, 2],
              inkSeams: const [
                [0, 1],
              ],
              inkSeamWidth: 3,
            ),
          ],
        );
        final world = {'root': Affine2D.translation(60, 80)};
        final px = await _renderRig(build(smoothLow: false), world);

        expect(
          _countColor(px, lowSeam),
          greaterThan(4),
          reason: 'the low mesh strokes its tailoring seams inside the loop',
        );
        expect(
          _countColor(px, highSeam),
          greaterThan(4),
          reason: 'seams above the last bone z are flushed after the loop',
        );
        expect(
          _countColor(px, highFill),
          greaterThan(50),
          reason: 'the flushed mesh still paints its fill under the seams',
        );

        // smoothBoundary:false keeps the authored polygon corners: rounding
        // them off (the default) cuts fill area at each corner.
        final hard = _countColor(px, lowFill);
        final soft = _countColor(
          await _renderRig(build(smoothLow: true), world),
          lowFill,
        );
        expect(hard, greaterThan(50), reason: 'the unsmoothed fill paints');
        expect(
          hard,
          greaterThan(soft + 10),
          reason:
              'the unsmoothed contour keeps its sharp corners, so it covers '
              'more area than the corner-smoothed one (hard=$hard soft=$soft)',
        );
      });
    },
  );

  testWidgets('ribbon ink clips its line to a capsule body below it', (
    tester,
  ) async {
    await tester.runAsync(() async {
      const bodyFill = 0xFF808080;
      const ribbonFill = 0xFF3F6FB0;
      const ink = 0xFF14161C;
      RigSpec build({required bool inkOverFill}) => RigSpec(
        name: 'ink-capsule',
        bones: const [
          // A capsule torso below the ribbon's z drives the capsule arm of
          // the body-union path the ink line is clipped to.
          Bone(
            id: 'body',
            parent: null,
            pivotX: 0,
            pivotY: 0,
            z: 0,
            drawable: BoneDrawable(
              kind: BoneShapeKind.capsule,
              width: 30,
              height: 80,
              color: bodyFill,
            ),
          ),
          Bone(id: 'armA', parent: 'body', pivotX: -40, pivotY: 0, z: 5),
          Bone(id: 'armB', parent: 'body', pivotX: 50, pivotY: 0, z: 5),
        ],
        ribbons: [
          LimbRibbonSpec(
            id: 'arm',
            jointBoneIds: const ['armA', 'armB'],
            halfWidths: const [8, 8],
            z: 5,
            color: ribbonFill,
            outlineColor: ink,
            outlineWidth: 3,
            inkOverFill: inkOverFill,
          ),
        ],
      );
      final world = {
        'body': Affine2D.translation(60, 60),
        'armA': Affine2D.translation(20, 60),
        'armB': Affine2D.translation(110, 60),
      };
      final inked = await _renderRig(build(inkOverFill: true), world);
      final plain = await _renderRig(build(inkOverFill: false), world);

      // The ONLY difference between the two renders is the ink-over-fill
      // stroke, and that stroke is clipped to the capsule body behind the
      // ribbon (x in [45, 75]): the line separates the limb exactly where it
      // crosses the body and nowhere else.
      var insideBody = 0;
      var outsideBody = 0;
      for (var i = 0; i + 3 < inked.length; i += 4) {
        if (inked[i] == plain[i] &&
            inked[i + 1] == plain[i + 1] &&
            inked[i + 2] == plain[i + 2] &&
            inked[i + 3] == plain[i + 3]) {
          continue;
        }
        final x = (i ~/ 4) % 120;
        if (x >= 44 && x <= 76) {
          insideBody++;
        } else {
          outsideBody++;
        }
      }
      expect(
        insideBody,
        greaterThan(20),
        reason: 'the ink line draws where the ribbon crosses the capsule',
      );
      expect(
        outsideBody,
        0,
        reason: 'outside the body union the limb keeps no floating outline',
      );
    });
  });
}
