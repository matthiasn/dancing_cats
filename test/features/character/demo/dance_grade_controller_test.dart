import 'dart:io';

import 'package:dancing_cats/features/character/demo/dance_grade_controller.dart';
import 'package:dancing_cats/features/character/demo/dance_grade_store.dart';
import 'package:dancing_cats/features/scenery/model/grade_timeline.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../dance_store_test_utils.dart';

GradeLook _sat(double saturation) => GradeLook(saturation: saturation);

void main() {
  late Directory dir;
  late DanceGradeStore store;
  late DanceGradeController c;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('grade_controller_test');
    store = DanceGradeStore(
      path: p.join(dir.path, 't.grade.json'),
      saveDebounce: kTestStoreSaveDebounce,
      pollInterval: kTestStorePollInterval,
    );
    await store.load();
    c = DanceGradeController(
      store: store,
      // A slightly uneven detected grid: beats every ~0.5s.
      beatTimesSec: [for (var i = 0; i < 40; i++) i * 0.5],
      downbeatIndices: [for (var i = 0; i < 10; i++) i * 4],
      sectionStartsSec: const [0, 8.3, 16.6],
    );
  });

  tearDown(() {
    c.dispose();
    store.dispose();
    dir.deleteSync(recursive: true);
  });

  group('console editing', () {
    test('paused auto-key stamps and re-stamps one key at the playhead', () {
      c
        ..consoleEdited(_sat(0.9), tSec: 4, playing: false)
        ..consoleEdited(_sat(0.7), tSec: 4, playing: false)
        ..consoleGestureEnded(tSec: 4, playing: false);
      final lane = store.doc.lane(GradeTargets.master)!;
      expect(lane.keyframes, hasLength(1));
      expect(lane.keyframes.single.look.saturation, 0.7);
      // One gesture = one undo step, back to the empty document.
      expect(c.canUndo, isTrue);
      c.undo();
      expect(store.doc.lane(GradeTargets.master)?.keyframes ?? [], isEmpty);
    });

    test('playing auto-key records a thinned trail replacing the span', () {
      // Pre-existing keys inside and outside the ridden span.
      store.update(
        GradeTimelineDoc(
          lanes: [
            GradeLane(
              target: GradeTargets.master,
              keyframes: [
                GradeKeyframe(tSec: 1, look: _sat(0.2)),
                GradeKeyframe(tSec: 5, look: _sat(0.4)), // inside the ride
                GradeKeyframe(tSec: 20, look: _sat(1.8)),
              ],
            ),
          ],
        ),
      );
      // Ride saturation linearly 4s → 8s (a perfectly linear ramp thins to
      // its endpoints).
      for (var t = 4.0; t <= 8.0; t += 0.1) {
        c.consoleEdited(_sat(1 + (t - 4) * 0.1), tSec: t, playing: true);
      }
      c.consoleGestureEnded(tSec: 8.2, playing: true);
      final lane = store.doc.lane(GradeTargets.master)!;
      final times = [for (final k in lane.keyframes) k.tSec];
      // Outside keys survive; the 5s key inside the span was replaced.
      expect(times.first, 1);
      expect(times.last, 20);
      expect(times.where((t) => t >= 4 && t <= 8.2).length, lessThan(6));
      expect(times.contains(5), isFalse);
      // Trail keys interpolate linearly (touch segments must not breathe).
      final inSpan = lane.keyframes.where((k) => k.tSec >= 4 && k.tSec < 8.2);
      expect(inSpan.every((k) => k.interp == GradeInterp.linear), isTrue);
      // The preview cleared on release: the doc is the source again.
      expect(c.preview, isNull);
    });

    test('auto-key OFF holds a sticky preview until stamp or discard', () {
      c
        ..autoKey = false
        ..consoleEdited(_sat(0.5), tSec: 3, playing: false)
        ..consoleGestureEnded(tSec: 3, playing: false);
      // Nothing written…
      expect(store.doc.isEmpty, isTrue);
      // …but the preview survives (a seek elsewhere keeps it — sticky).
      expect(c.preview!.saturation, 0.5);
      expect(c.consoleLook(60).saturation, 0.5);
      expect(
        c.gradesAt(60)[GradeTargets.master]!.saturation,
        0.5,
      );
      // The export feed must NOT ship the experiment.
      expect(c.gradesAt(60, includePreview: false), isEmpty);
      // ● KEY commits it at the playhead.
      c.stampAt(7);
      expect(c.preview, isNull);
      expect(
        store.doc.lane(GradeTargets.master)!.keyframes.single.tSec,
        7,
      );
    });

    test('Esc discards the sticky preview without touching the doc', () {
      c
        ..autoKey = false
        ..consoleEdited(_sat(0.5), tSec: 3, playing: false)
        ..consoleGestureEnded(tSec: 3, playing: false)
        ..discardPreview();
      expect(c.preview, isNull);
      expect(store.doc.isEmpty, isTrue);
    });

    test('a neutral preview suppresses the lane grade for the render feed', () {
      store.update(
        GradeTimelineDoc(
          lanes: [
            GradeLane(
              target: GradeTargets.master,
              keyframes: [GradeKeyframe(tSec: 0, look: _sat(0.4))],
            ),
          ],
        ),
      );
      c
        ..autoKey = false
        ..consoleEdited(GradeLook.neutral, tSec: 0, playing: false);
      expect(c.gradesAt(0), isEmpty);
    });
  });

  group('keyframe editing', () {
    setUp(() {
      store.update(
        GradeTimelineDoc(
          lanes: [
            GradeLane(
              target: GradeTargets.master,
              keyframes: [
                GradeKeyframe(tSec: 2, look: _sat(0.5)),
                GradeKeyframe(tSec: 6, look: _sat(1.5)),
                GradeKeyframe(tSec: 10, look: _sat(0.9)),
              ],
            ),
          ],
        ),
      );
    });

    test('click selects one key; shift-click extends; Esc clears', () {
      // Selecting a key on ANOTHER lane re-homes selection to that lane.
      c
        ..addLane('cast')
        ..selectKey(GradeTargets.master, 2);
      expect(c.selectedTarget, GradeTargets.master);
      expect(c.selectedKeyTimes, {2});
      c.selectKey(GradeTargets.master, 6, extend: true);
      expect(c.selectedKeyTimes, {2, 6});
      c.selectKey(GradeTargets.master, 6, extend: true); // toggle off
      expect(c.selectedKeyTimes, {2});
      c.clearKeySelection();
      expect(c.selectedKeyTimes, isEmpty);
    });

    test('double-click adds a key pinning the evaluated look (snapped)', () {
      c.addKeyAt(GradeTargets.master, 4.02); // snaps to the 4.0 beat
      final lane = store.doc.lane(GradeTargets.master)!;
      expect(lane.keyframes, hasLength(4));
      final added = lane.keyframes[1];
      expect(added.tSec, 4.0);
      // The pinned look equals what was on screen at that time.
      expect(added.look.saturation, closeTo(1.0, 1e-9));
    });

    test('delete removes one key; deleteSelected removes the set', () {
      c.deleteKey(GradeTargets.master, 6);
      expect(store.doc.lane(GradeTargets.master)!.keyframes, hasLength(2));
      c
        ..selectKey(GradeTargets.master, 2)
        ..selectKey(GradeTargets.master, 10, extend: true)
        ..deleteSelected();
      expect(store.doc.lane(GradeTargets.master)!.keyframes, isEmpty);
    });

    test('a key drag moves in time, snaps, and clamps at its neighbours', () {
      c
        ..beginKeyDrag(GradeTargets.master, 6)
        ..updateKeyDrag(1.02, anchorTSec: 6); // 7.02 snaps to beat 7.0
      var times = [
        for (final k in store.doc.lane(GradeTargets.master)!.keyframes) k.tSec,
      ];
      expect(times, [2, 7, 10]);
      // Dragging far right clamps just before the 10s neighbour.
      c.updateKeyDrag(30, anchorTSec: 6);
      times = [
        for (final k in store.doc.lane(GradeTargets.master)!.keyframes) k.tSec,
      ];
      expect(times[1], lessThan(10));
      expect(times[1], greaterThan(9.9));
      c
        ..endKeyDrag()
        // The whole drag is ONE undo step.
        ..undo();
      expect(
        [
          for (final k in store.doc.lane(GradeTargets.master)!.keyframes)
            k.tSec,
        ],
        [2, 6, 10],
      );
    });

    test('a group drag moves the multi-selection rigidly', () {
      c
        ..selectKey(GradeTargets.master, 2)
        ..selectKey(GradeTargets.master, 6, extend: true)
        ..beginKeyDrag(GradeTargets.master, 2)
        ..updateKeyDrag(0.5, anchorTSec: 2)
        ..endKeyDrag();
      final times = [
        for (final k in store.doc.lane(GradeTargets.master)!.keyframes) k.tSec,
      ];
      expect(times, [2.5, 6.5, 10]);
      expect(c.selectedKeyTimes, {2.5, 6.5});
    });

    test('nudge moves the selection by one detected beat, or fine', () {
      c
        ..selectKey(GradeTargets.master, 6)
        ..nudgeSelected(1);
      expect(
        store.doc.lane(GradeTargets.master)!.keyframes[1].tSec,
        closeTo(6.5, 1e-9),
      );
      c.nudgeSelected(-1, fineSec: 0.01);
      expect(
        store.doc.lane(GradeTargets.master)!.keyframes[1].tSec,
        closeTo(6.49, 1e-9),
      );
    });

    test('setInterp re-curves one segment', () {
      c.setInterp(GradeTargets.master, 6, GradeInterp.hold);
      expect(
        store.doc.lane(GradeTargets.master)!.keyframes[1].interp,
        GradeInterp.hold,
      );
      // A miss is a no-op.
      c.setInterp(GradeTargets.master, 99, GradeInterp.hold);
      expect(store.doc.lane(GradeTargets.master)!.keyframes, hasLength(3));
    });

    test('copy/paste carries a look across lanes', () {
      c
        ..copyLook(GradeTargets.master, 6)
        ..addLane(GradeTargets.cast)
        ..pasteLook(GradeTargets.cast, 3);
      final cast = store.doc.lane(GradeTargets.cast)!;
      expect(cast.keyframes.single.tSec, 3);
      expect(cast.keyframes.single.look.saturation, 1.5);
      // Copy of a missing key is a no-op.
      c.copyLook(GradeTargets.master, 99);
      expect(c.clipboard!.saturation, 1.5);
    });
  });

  group('lanes', () {
    test('displayLanes always leads with MASTER, even when absent', () {
      expect(c.displayLanes.first.target, GradeTargets.master);
      expect(c.displayLanes, hasLength(1));
      c.addLane('deck-glow');
      expect(c.displayLanes, hasLength(2));
      expect(c.selectedTarget, 'deck-glow');
    });

    test('addLane of an existing target just selects it', () {
      c
        ..addLane('deck-glow')
        ..selectLane(GradeTargets.master)
        ..addLane('deck-glow');
      expect(c.selectedTarget, 'deck-glow');
      expect(
        store.doc.lanes.where((l) => l.target == 'deck-glow'),
        hasLength(1),
      );
    });

    test('removeLane drops a lane and re-homes selection to master', () {
      c
        ..addLane('cast')
        ..removeLane('cast');
      expect(store.doc.lane('cast'), isNull);
      expect(c.selectedTarget, GradeTargets.master);
      // Master is the home lane: it can be cleared, never removed.
      c
        ..stampAt(2)
        ..removeLane(GradeTargets.master);
      expect(store.doc.lane(GradeTargets.master), isNotNull);
      c.clearLane(GradeTargets.master);
      expect(store.doc.lane(GradeTargets.master)!.keyframes, isEmpty);
    });

    test('toggleLaneEnabled mutes and unmutes', () {
      c
        ..addLane('haze')
        ..toggleLaneEnabled('haze');
      expect(store.doc.lane('haze')!.enabled, isFalse);
      c.toggleLaneEnabled('haze');
      expect(store.doc.lane('haze')!.enabled, isTrue);
      // Unknown target is a no-op.
      c.toggleLaneEnabled('nope');
    });
  });

  group('undo/redo', () {
    test('undo/redo walk the document history', () {
      c
        ..stampAt(1)
        ..stampAt(2);
      expect(store.doc.lane(GradeTargets.master)!.keyframes, hasLength(2));
      c.undo();
      expect(store.doc.lane(GradeTargets.master)!.keyframes, hasLength(1));
      c.redo();
      expect(store.doc.lane(GradeTargets.master)!.keyframes, hasLength(2));
      c
        ..undo()
        ..undo();
      expect(c.canUndo, isFalse);
      expect(c.canRedo, isTrue);
      // A fresh edit clears the redo branch.
      c.stampAt(5);
      expect(c.canRedo, isFalse);
    });

    test('an external reload is one undoable step', () async {
      c.stampAt(1);
      await store.flush(); // no pending local edit — reloads may fire
      final before = store.doc;
      // Simulate the LLM writing a different document.
      File(store.path).writeAsStringSync(
        '{"version":1,"lanes":[{"target":"cast","keyframes":'
        '[{"t_sec":9,"look":{"saturation":0.5}}]}]}',
      );
      await store.pollOnce();
      expect(store.doc.lane('cast'), isNotNull);
      c.undo();
      expect(store.doc.lane('cast'), isNull);
      expect(store.doc.toJson(), before.toJson());
    });
  });

  group('snapping', () {
    test('snaps to beats, half-beats and section starts within tolerance', () {
      expect(c.snapTime(4.03), 4.0); // beat
      expect(c.snapTime(4.26), 4.25); // the "and" between beats
      expect(c.snapTime(8.35), 8.3); // section start beats the 8.5 half-beat
      expect(c.snapTime(4.4, toleranceSec: 0.05), 4.4); // nothing close
    });

    test('degrades gracefully with no beat grid', () {
      final bare = DanceGradeController(store: store);
      expect(bare.snapTime(3.3), 3.3);
      bare.dispose();
    });
  });

  group('thinTrail', () {
    GradeKeyframe key(double t, double sat) => GradeKeyframe(
      tSec: t,
      look: _sat(sat),
      interp: GradeInterp.linear,
    );

    test('a linear ramp collapses to its endpoints', () {
      final trail = [for (var i = 0; i <= 20; i++) key(i * 0.25, 1 + i * 0.01)];
      final thin = DanceGradeController.thinTrail(trail);
      expect(thin, hasLength(2));
      expect(thin.first.tSec, 0);
      expect(thin.last.tSec, 5);
    });

    test('a corner survives thinning', () {
      final trail = [
        for (var i = 0; i <= 10; i++) key(i * 0.25, 1),
        for (var i = 1; i <= 10; i++) key(2.5 + i * 0.25, 1 + i * 0.05),
      ];
      final thin = DanceGradeController.thinTrail(trail);
      expect(thin.length, lessThan(6));
      // The corner at t=2.5 is preserved (within a stamp of it).
      expect(
        thin.any((k) => (k.tSec - 2.5).abs() < 0.3),
        isTrue,
      );
    });

    test('short trails pass through untouched', () {
      final trail = [key(0, 1), key(1, 2)];
      expect(DanceGradeController.thinTrail(trail), hasLength(2));
    });
  });

  test('lookMaxDiff reports the largest normalized control difference', () {
    expect(
      DanceGradeController.lookMaxDiff(_sat(1), _sat(1.4)),
      closeTo(0.4, 1e-9),
    );
    expect(
      DanceGradeController.lookMaxDiff(
        GradeLook.neutral,
        const GradeLook(contrast: 1.4),
      ),
      closeTo(0.5, 1e-9),
    );
    expect(DanceGradeController.lookMaxDiff(_sat(1), _sat(1)), 0);
  });
}
