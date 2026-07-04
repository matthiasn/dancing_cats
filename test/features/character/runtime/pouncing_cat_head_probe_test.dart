import 'dart:math' as math;

import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/runtime/character_scene.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Head-level pixel-track probe — resolves the panel round-12 4-vs-1 split.
///
/// R12 left one directly falsifiable disagreement: pouncingCat's premise is a
/// "dead-level head over a gliding base." Anatomy (8.0) called it "genuinely
/// dead-level, professional-grade"; movement/director/afrobeats independently
/// said the head "visibly bobs with the body" — movement even measured "the
/// head's vertical position swings ~54-59px." The digest flagged this as the
/// single most concrete checkable lead and asked for a direct pixel-track of the
/// rendered head position (the same technique that resolved the R10 azonto/sekem
/// "solved rotation doesn't render" mysteries).
///
/// This probes `scene.frameAt(...).world[bone]` — the resolved world-space
/// origin the renderer actually sees, AFTER foot stabilization and the
/// head-level counter (`_rigidHeadWorld`). At the lead's render scale (~0.55)
/// one world unit is ~one rendered pixel, so world-unit swing ≈ the px the panel
/// measured.
///
/// VERDICT (original, pre-fix): the four were right. pouncingCat's rendered head
/// swung ~99 world-units peak-to-peak (37% of body height, ~55px at lead scale —
/// dead on movement's "54-59px"), head/hips coupling 1.34 — the head moved MORE
/// than the hips it rides. Anatomy read a different layer and was self-consistent:
/// the move is *authored* level (`danceHeadBobScale: 0`, flat local neck/head
/// channels), but the head is parented above hips->torso->neck, so the genuine
/// pounce CROUCH propagates up the chain. Flat local channels can't level a head
/// whose parent drops — the same data->render gap the digest hypothesized. It was
/// catalogue-wide: every clip coupled >= 0.98 (buga worst at 44%).
///
/// FIX (shipped): the dance SPINE LEVELER (`_spineLevelShifts`) levels the neck
/// then the head toward their per-clip mean heights, clamped to each joint's
/// NATURAL gap envelope, with a THROAT BRIDGE lifting the collar/tie/shirt so the
/// neck join can't gap, and a deep-crouch EASE that lets the head dip on the
/// pounce bottom (weight, no tubey neck). 3-expert panel (2026-07-04) picked it
/// unanimously. Post-fix: pounce coupling ~1.18 head-swing ~88 (down from
/// 1.34/99.5), head-neck gap held tight (head never crosses below the neck), and
/// hold-frame head-top is near-constant. The asserts below GUARD that fix.
void main() {
  final bones = <String>[
    CatBones.head,
    CatBones.neck,
    CatBones.torso,
    CatBones.hips,
    CatBones.footL,
    CatBones.footR,
    CatBones.earTipL,
  ];
  const samples = 240;

  double rangeOf(List<double> v) => v.reduce(math.max) - v.reduce(math.min);

  ({double headSwing, double hipsSwing, double bodyH, double coupling})
  measure(CharacterScene scene, Clip clip) {
    final headY = <double>[];
    final hipsY = <double>[];
    final earY = <double>[];
    final footLY = <double>[];
    final footRY = <double>[];
    for (var i = 0; i <= samples; i++) {
      final f = scene.frameAt(
        clip: clip,
        timeSeconds: clip.duration * i / samples,
      );
      headY.add(f.world[CatBones.head]!.ty);
      hipsY.add(f.world[CatBones.hips]!.ty);
      earY.add(f.world[CatBones.earTipL]!.ty);
      footLY.add(f.world[CatBones.footL]!.ty);
      footRY.add(f.world[CatBones.footR]!.ty);
    }
    final headSwing = rangeOf(headY);
    final hipsSwing = rangeOf(hipsY);
    return (
      headSwing: headSwing,
      hipsSwing: hipsSwing,
      bodyH: math.max(footLY[0], footRY[0]) - earY[0],
      coupling: headSwing / (hipsSwing == 0 ? 1 : hipsSwing),
    );
  }

  test('catalogue head-level coupling (prints table)', () {
    final scene = CharacterScene(buildCatInSuitRig());
    final clips = <Clip>[
      CatClips.shaku,
      CatClips.zanku,
      CatClips.azonto,
      CatClips.sekem,
      CatClips.buga,
      CatClips.pouncingCat,
    ];
    final table = StringBuffer()
      ..writeln('\n=== catalogue head-level coupling ===')
      ..writeln('clip          headYswing  hipsYswing  coupling  '
          'head%bodyH  px@0.55');
    for (final c in clips) {
      final m = measure(scene, c);
      table.writeln(
        '${c.name.padRight(12)}  '
        '${m.headSwing.toStringAsFixed(1).padLeft(9)}  '
        '${m.hipsSwing.toStringAsFixed(1).padLeft(9)}  '
        '${m.coupling.toStringAsFixed(2).padLeft(7)}  '
        '${(100 * m.headSwing / m.bodyH).toStringAsFixed(1).padLeft(9)}%  '
        '${(m.headSwing * 0.55).toStringAsFixed(0).padLeft(6)}px',
      );
    }
    // ignore: avoid_print
    print(table);
  });

  test('pouncingCat head-level probe (prints trace)', () {
    final scene = CharacterScene(buildCatInSuitRig());
    final clip = CatClips.pouncingCat;

    final tx = <String, List<double>>{for (final b in bones) b: <double>[]};
    final ty = <String, List<double>>{for (final b in bones) b: <double>[]};
    for (var i = 0; i <= samples; i++) {
      final frame = scene.frameAt(
        clip: clip,
        timeSeconds: clip.duration * i / samples,
      );
      for (final b in bones) {
        final w = frame.world[b];
        if (w == null) fail('bone "$b" not resolved for pouncingCat');
        tx[b]!.add(w.tx);
        ty[b]!.add(w.ty);
      }
    }

    double maxAbsStep(List<double> v) {
      var m = 0.0;
      for (var i = 1; i < v.length; i++) {
        m = math.max(m, (v[i] - v[i - 1]).abs());
      }
      return m;
    }

    final m = measure(scene, clip);
    final buf = StringBuffer()
      ..writeln('\n=== pouncingCat head-level probe ===')
      ..writeln('clip.duration=${clip.duration}s  '
          'danceHeadBobScale=${clip.danceHeadBobScale}  '
          'danceHeadLevelClampMin=${clip.danceHeadLevelClampMin}')
      ..writeln('standing height (frame0, ear->foot) = '
          '${m.bodyH.toStringAsFixed(1)} world-units\n')
      ..writeln('bone        Y peak-to-peak   Y max step   X glide (peak-to-peak)');
    for (final b in bones) {
      buf.writeln(
        '${b.padRight(10)}  '
        '${rangeOf(ty[b]!).toStringAsFixed(2).padLeft(10)}   '
        '${maxAbsStep(ty[b]!).toStringAsFixed(3).padLeft(9)}   '
        '${rangeOf(tx[b]!).toStringAsFixed(2).padLeft(10)}',
      );
    }
    // Join integrity (the "orange throat" safety check): the head must not lift
    // off the neck. Track head.ty - neck.ty; its range/max must stay within the
    // natural envelope, or the head-level counter is gapping the join.
    final headNeck = <double>[
      for (var i = 0; i < ty[CatBones.head]!.length; i++)
        ty[CatBones.head]![i] - ty[CatBones.neck]![i],
    ];
    final neckTorso = <double>[
      for (var i = 0; i < ty[CatBones.neck]!.length; i++)
        ty[CatBones.neck]![i] - ty[CatBones.torso]![i],
    ];
    buf
      ..writeln('\n-- join integrity --')
      ..writeln('head-neck gap: min=${headNeck.reduce(math.min).toStringAsFixed(1)} '
          'max=${headNeck.reduce(math.max).toStringAsFixed(1)} '
          'range=${(headNeck.reduce(math.max) - headNeck.reduce(math.min)).toStringAsFixed(1)} '
          '(baseline max=-5.6, range=15.1 pre-fix)')
      ..writeln('neck-torso gap: min=${neckTorso.reduce(math.min).toStringAsFixed(1)} '
          'max=${neckTorso.reduce(math.max).toStringAsFixed(1)} '
          'range=${(neckTorso.reduce(math.max) - neckTorso.reduce(math.min)).toStringAsFixed(1)} '
          '(baseline range=46.7 pre-fix — collar region)')
      ..writeln('neck Y swing: '
          '${(ty[CatBones.neck]!.reduce(math.max) - ty[CatBones.neck]!.reduce(math.min)).toStringAsFixed(1)} '
          '(pre-fix 113.4)')
      ..writeln('\n-- verdict signals --')
      ..writeln('head Y swing         = ${m.headSwing.toStringAsFixed(1)} units '
          '(${(100 * m.headSwing / m.bodyH).toStringAsFixed(1)}% of body height, '
          '~${(m.headSwing * 0.55).toStringAsFixed(0)}px at lead scale 0.55)')
      ..writeln('hips Y swing         = ${m.hipsSwing.toStringAsFixed(1)} units')
      ..writeln('head/hips coupling   = ${m.coupling.toStringAsFixed(2)} '
          '(0=decoupled/level, 1=rides fully with the body)')
      ..writeln('base glide (hips X)  = '
          '${rangeOf(tx[CatBones.hips]!).toStringAsFixed(1)} units')
      ..writeln('feet X travel (L/R)  = '
          '${rangeOf(tx[CatBones.footL]!).toStringAsFixed(1)} / '
          '${rangeOf(tx[CatBones.footR]!).toStringAsFixed(1)} units');
    // ignore: avoid_print
    print(buf);

    // GUARD the shipped spine leveler (pre-fix baselines: coupling 1.34,
    // head-swing 99.5, head-neck gap range 15.1, head-neck max -5.6). If these
    // fail, the leveler regressed or was removed.
    expect(
      m.headSwing,
      lessThan(95),
      reason: 'spine leveler should hold pounce head-swing below the pre-fix '
          '99.5 units',
    );
    expect(
      m.coupling,
      lessThan(1.28),
      reason: 'head should ride at/under the pre-fix 1.34 head/hips coupling',
    );
    final headNeckMax = headNeck.reduce(math.max);
    final headNeckMin = headNeck.reduce(math.min);
    expect(
      headNeckMax,
      lessThan(0),
      reason: 'head must stay ABOVE the neck — the throat never gaps below it',
    );
    expect(
      headNeckMax - headNeckMin,
      lessThan(8),
      reason: 'the leveled head tracks the neck tightly (join stays inside its '
          'natural band, no rubber throat)',
    );
  });
}
