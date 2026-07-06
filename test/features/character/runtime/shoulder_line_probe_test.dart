import 'dart:math' as math;

import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/runtime/character_scene.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shoulder-LINE pixel-track probe AND regression gate — grounds the
/// "solved-rotation-doesn't-render" shoulder fix in measured world units
/// (the same technique that resolved the R10/R12 render mysteries; one
/// world unit ~ one lead-scale px).
///
/// The panel's unanimous #1 on shaku (three rounds running): "the shoulder
/// LINE stays a level, locked yoke." The authored clavicle see-saw (±0.42)
/// provably solved but rendered ~±1.6 units, because the clavicle pivot
/// sits AT the shoulder corner — rotation can't displace a point at its own
/// pivot. The fix: sternum-pivot `shoulder_line` lever bones (see the rig)
/// mirrored from the clavicles by the scene's `shoulder-line` pass, with
/// the jacket's armhole/yoke vertices riding the lever.
///
/// This test reconstructs the jacket's shoulder-contour vertices with the
/// exact skinning formula the renderer uses and isolates the girdle's
/// contribution from whole-body sway via a girdle-frozen counterfactual.
/// Measured after the fix (2026-07-04): shaku isolated see-saw tilt 20.6
/// (was 3.3), armhole per-side ~9.5 (was 0.0), collar taper ~1.6; buga's
/// symmetric hit lift ~10 per side. The asserts below GUARD that response
/// with ~30% headroom — if a rig/pass edit ever mutes the shoulder line
/// back into a locked yoke, this fails before a panel has to see it.
void main() {
  const samples = 192;

  test('shoulder line probe (prints table)', () {
    final rig = buildCatInSuitRig();
    final scene = CharacterScene(rig);

    // Rest-world origins by accumulating pivots up the parent chain — the
    // same convention buildTrunkSurface uses for skinning locals.
    final byId = {for (final b in rig.bones) b.id: b};
    final restOrigin = <String, ({double x, double y})>{};
    ({double x, double y}) originOf(String id) {
      final cached = restOrigin[id];
      if (cached != null) return cached;
      final bone = byId[id]!;
      final parent = bone.parent == null
          ? (x: 0.0, y: 0.0)
          : originOf(bone.parent!);
      final o = (x: parent.x + bone.pivotX, y: parent.y + bone.pivotY);
      restOrigin[id] = o;
      return o;
    }

    for (final b in rig.bones) {
      originOf(b.id);
    }

    // The jacket's shoulder-contour vertices, exactly as authored in
    // cat_in_suit_rig.dart's buildTrunkSurface call.
    final trackedVertices =
        <String, ({double x, double y, Map<String, double> w})>{
          'armhole.L': (
            x: -32.5,
            y: -60,
            w: {
              CatBones.chest: 0.33,
              CatBones.torso: 0.22,
              CatBones.shoulderLineL: 0.45,
            },
          ),
          'armhole.R': (
            x: 32.5,
            y: -60,
            w: {
              CatBones.chest: 0.33,
              CatBones.torso: 0.22,
              CatBones.shoulderLineR: 0.45,
            },
          ),
          'yoke.L': (
            x: -29,
            y: -75,
            w: {
              CatBones.chest: 0.3,
              CatBones.clavicleL: 0.15,
              CatBones.shoulderLineL: 0.55,
            },
          ),
          'yoke.R': (
            x: 29,
            y: -75,
            w: {
              CatBones.chest: 0.3,
              CatBones.clavicleR: 0.15,
              CatBones.shoulderLineR: 0.55,
            },
          ),
          'collar.L': (
            x: -13,
            y: -81.5,
            w: {
              CatBones.chest: 0.7,
              CatBones.clavicleL: 0.1,
              CatBones.shoulderLineL: 0.2,
            },
          ),
          'collar.R': (
            x: 13,
            y: -81.5,
            w: {
              CatBones.chest: 0.7,
              CatBones.clavicleR: 0.1,
              CatBones.shoulderLineR: 0.2,
            },
          ),
        };

    ({double x, double y}) skin(
      CharacterFrame frame,
      ({double x, double y, Map<String, double> w}) v, {
      bool freezeClavicles = false,
    }) {
      var x = 0.0;
      var y = 0.0;
      v.w.forEach((boneId, weight) {
        // The girdle-frozen counterfactual: ride the chest instead, so the
        // difference vs the actual vertex isolates what the clavicle channel
        // (directly and via the shoulder-line levers) contributes to the
        // rendered contour (as opposed to whole-body sway/lean, which moves
        // both variants identically).
        final effectiveBone =
            freezeClavicles &&
                (boneId == CatBones.clavicleL ||
                    boneId == CatBones.clavicleR ||
                    boneId == CatBones.shoulderLineL ||
                    boneId == CatBones.shoulderLineR)
            ? CatBones.chest
            : boneId;
        final world = frame.world[effectiveBone]!;
        final o = restOrigin[effectiveBone]!;
        final p = world.transformPoint(v.x - o.x, v.y - o.y);
        x += weight * p.x;
        y += weight * p.y;
      });
      return (x: x, y: y);
    }

    final trackedBones = <String>[
      CatBones.clavicleL,
      CatBones.clavicleR,
      CatBones.shoulderSocketL,
      CatBones.shoulderSocketR,
    ];

    final out = StringBuffer('\n=== shoulder line probe ===\n');
    final isolatedTiltRangeByClip = <String, double>{};
    final isolatedYRangeByClip = <String, Map<String, double>>{};
    for (final clip in <Clip>[CatClips.shaku, CatClips.buga]) {
      // Per-sample traces.
      final vertexY = <String, List<double>>{
        for (final k in trackedVertices.keys) k: <double>[],
      };
      final vertexX = <String, List<double>>{
        for (final k in trackedVertices.keys) k: <double>[],
      };
      final boneY = <String, List<double>>{
        for (final b in trackedBones) b: <double>[],
      };
      final boneX = <String, List<double>>{
        for (final b in trackedBones) b: <double>[],
      };
      final tilt = <double>[]; // yoke.L y minus yoke.R y — the see-saw signal
      final armholeTilt = <double>[];
      // Clavicle-isolated contribution per vertex: actual minus frozen.
      final isolatedY = <String, List<double>>{
        for (final k in trackedVertices.keys) k: <double>[],
      };
      final isolatedTilt = <double>[];
      for (var i = 0; i <= samples; i++) {
        final frame = scene.frameAt(
          clip: clip,
          timeSeconds: clip.duration * i / samples,
        );
        for (final entry in trackedVertices.entries) {
          final p = skin(frame, entry.value);
          final frozen = skin(frame, entry.value, freezeClavicles: true);
          vertexX[entry.key]!.add(p.x);
          vertexY[entry.key]!.add(p.y);
          isolatedY[entry.key]!.add(p.y - frozen.y);
        }
        for (final b in trackedBones) {
          boneX[b]!.add(frame.world[b]!.tx);
          boneY[b]!.add(frame.world[b]!.ty);
        }
        tilt.add(vertexY['yoke.L']!.last - vertexY['yoke.R']!.last);
        armholeTilt.add(
          vertexY['armhole.L']!.last - vertexY['armhole.R']!.last,
        );
        isolatedTilt.add(
          isolatedY['yoke.L']!.last - isolatedY['yoke.R']!.last,
        );
      }

      double range(List<double> v) => v.reduce(math.max) - v.reduce(math.min);

      out
        ..writeln('--- ${clip.name} ---')
        ..writeln(
          'shoulder-line TILT (yokeL.y - yokeR.y): '
          'range ${range(tilt).toStringAsFixed(1)}  '
          'min ${tilt.reduce(math.min).toStringAsFixed(1)}  '
          'max ${tilt.reduce(math.max).toStringAsFixed(1)}',
        )
        ..writeln(
          'armhole TILT (L.y - R.y):               '
          'range ${range(armholeTilt).toStringAsFixed(1)}  '
          'min ${armholeTilt.reduce(math.min).toStringAsFixed(1)}  '
          'max ${armholeTilt.reduce(math.max).toStringAsFixed(1)}',
        )
        ..writeln(
          'ISOLATED clavicle tilt (actual - frozen): '
          'range ${range(isolatedTilt).toStringAsFixed(1)}  '
          'min ${isolatedTilt.reduce(math.min).toStringAsFixed(1)}  '
          'max ${isolatedTilt.reduce(math.max).toStringAsFixed(1)}',
        );
      for (final k in trackedVertices.keys) {
        out.writeln(
          '${k.padRight(10)} xRange ${range(vertexX[k]!).toStringAsFixed(1).padLeft(6)}  '
          'yRange ${range(vertexY[k]!).toStringAsFixed(1).padLeft(6)}  '
          'isolatedYRange ${range(isolatedY[k]!).toStringAsFixed(1).padLeft(5)}',
        );
      }
      for (final b in trackedBones) {
        out.writeln(
          '${b.padRight(18)} xRange ${range(boneX[b]!).toStringAsFixed(1).padLeft(6)}  '
          'yRange ${range(boneY[b]!).toStringAsFixed(1).padLeft(6)}',
        );
      }
      isolatedTiltRangeByClip[clip.name] = range(isolatedTilt);
      isolatedYRangeByClip[clip.name] = {
        for (final k in trackedVertices.keys) k: range(isolatedY[k]!),
      };
    }
    // ignore: avoid_print
    print(out);

    // --- Regression gate: the shoulder line must RENDER the girdle. ---
    // Shaku's alternating see-saw must tilt the rendered yoke asymmetrically
    // (measured 20.6 post-fix, 3.3 pre-fix — the "level, locked yoke" bug).
    expect(
      isolatedTiltRangeByClip['shaku'],
      greaterThan(14),
      reason:
          'shaku: the clavicle see-saw must tilt the rendered shoulder line '
          '(isolated from whole-body sway) — a drop back toward ~3 means the '
          'shoulder_line levers went dead and the yoke is a locked bar again',
    );
    for (final corner in const ['armhole.L', 'armhole.R']) {
      expect(
        isolatedYRangeByClip['shaku']![corner],
        greaterThan(6),
        reason:
            'shaku: the $corner shoulder corner must ride the girdle '
            '(measured ~9.5 post-fix, 0.0 pre-fix)',
      );
      expect(
        isolatedYRangeByClip['buga']![corner],
        greaterThan(6),
        reason:
            'buga: the hit shrug must lift the $corner jacket corner '
            '(measured ~10 post-fix)',
      );
    }
    for (final collar in const ['collar.L', 'collar.R']) {
      expect(
        isolatedYRangeByClip['shaku']![collar],
        lessThan(4),
        reason:
            'shaku: the girdle response must TAPER into the neckline — the '
            'pop belongs at the shoulder corner, not the whole collar '
            'rocking (measured ~1.6 post-fix)',
      );
    }
  });
}
