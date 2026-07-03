import 'dart:convert';
import 'dart:io';

import 'package:dancing_cats/features/character/demo/dance_cues_store.dart';
import 'package:dancing_cats/features/character/demo/dance_lip_sync_controller.dart';
import 'package:dancing_cats/features/character/demo/dance_lip_sync_doc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Four contiguous 1-second cues covering 0..4s: X, B, C, D.
LipSyncDoc _seedDoc() => const LipSyncDoc(
  cues: [
    (start: 0, end: 1, shape: 'X'),
    (start: 1, end: 2, shape: 'B'),
    (start: 2, end: 3, shape: 'C'),
    (start: 3, end: 4, shape: 'D'),
  ],
);

void main() {
  late Directory dir;
  late DanceCuesStore store;
  late DanceLipSyncController c;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('lip_sync_controller_test');
    store = DanceCuesStore(
      path: p.join(dir.path, 't.cues.json'),
      saveDebounce: const Duration(minutes: 1),
      pollInterval: const Duration(minutes: 1),
    );
    await store.load();
    store.update(_seedDoc());
    // Land the seed so later pollOnce() calls (external-reload tests) aren't
    // short-circuited by a pending local edit.
    await store.flush();
    c = DanceLipSyncController(
      store: store,
      // A slightly uneven detected grid: beats every ~0.5s.
      beatTimesSec: [for (var i = 0; i < 40; i++) i * 0.5],
    );
  });

  tearDown(() {
    c.dispose();
    store.dispose();
    dir.deleteSync(recursive: true);
  });

  group('selection', () {
    test('selectCue sets/clears; re-selecting the same index is a no-op', () {
      c.selectCue(1);
      expect(c.selectedIndex, 1);
      c.selectCue(null);
      expect(c.selectedIndex, isNull);
    });

    test('clearSelection clears an existing selection and notifies', () {
      c.selectCue(2);
      var notified = 0;
      c
        ..addListener(() => notified++)
        ..clearSelection();
      expect(c.selectedIndex, isNull);
      expect(notified, 1);
    });

    test('clearSelection is a no-op with nothing selected', () {
      var notified = 0;
      c
        ..addListener(() => notified++)
        ..clearSelection();
      expect(notified, 0);
    });
  });

  group('boundary dragging', () {
    test('retimes the boundary and selects the dragged cue', () {
      c.beginBoundaryDrag(0); // boundary between cues[0] and cues[1], at t=1
      expect(c.selectedIndex, 0);
      c.updateBoundaryDrag(0.4, snap: false);
      expect(c.cues[0].end, closeTo(1.4, 1e-9));
      expect(c.cues[1].start, closeTo(1.4, 1e-9));
      c.endBoundaryDrag();
      // One undo transaction for the whole drag.
      expect(c.canUndo, isTrue);
      c.undo();
      expect(c.cues[0].end, 1);
    });

    test('snaps to the nearest beat when the magnet is on', () {
      // Drags to 1.23s; nearest beat/half-beat sits at 1.25.
      c
        ..beginBoundaryDrag(0)
        ..updateBoundaryDrag(0.23);
      expect(c.cues[0].end, closeTo(1.25, 1e-9));
      c.endBoundaryDrag();
    });

    test('alt-bypass (snap: false) ignores the beat grid', () {
      c
        ..beginBoundaryDrag(0)
        ..updateBoundaryDrag(0.23, snap: false);
      expect(c.cues[0].end, closeTo(1.23, 1e-9));
      c.endBoundaryDrag();
    });

    test('clamps against the minimum cue duration', () {
      c
        ..beginBoundaryDrag(0)
        ..updateBoundaryDrag(-10, snap: false);
      expect(c.cues[0].end, closeTo(kMinCueDurationSec, 1e-9));
      c.endBoundaryDrag();
    });

    test('is a no-op for an out-of-range boundary index', () {
      final before = c.cues;
      // cues[3] is the last cue — no boundary after it.
      c
        ..beginBoundaryDrag(3)
        ..updateBoundaryDrag(1);
      expect(c.cues, before);
      expect(c.canUndo, isFalse);
    });
  });

  group('reshape / split / merge', () {
    test('setShape replaces the shape and pushes one undo step', () {
      c.setShape(1, 'F');
      expect(c.cues[1].shape, 'F');
      expect(c.canUndo, isTrue);
      c.undo();
      expect(c.cues[1].shape, 'B');
    });

    test('setShape to the same value is a no-op (no undo step)', () {
      c.setShape(1, 'B');
      expect(c.canUndo, isFalse);
    });

    test('splitSelectedAt splits and selects the new right half', () {
      c.splitSelectedAt(1.5);
      expect(c.cues, hasLength(5));
      expect(c.selectedIndex, 2); // the half starting at 1.5
      expect(c.cues[1].end, 1.5);
      expect(c.cues[2].start, 1.5);
      expect(c.canUndo, isTrue);
    });

    test('splitSelectedAt near an existing boundary is a no-op', () {
      c.splitSelectedAt(1 + kMinCueDurationSec / 2);
      expect(c.cues, hasLength(4));
      expect(c.canUndo, isFalse);
    });

    test('mergeSelected merges the selection forward into its neighbour', () {
      c
        ..selectCue(1)
        ..mergeSelected();
      expect(c.cues, hasLength(3));
      expect(c.cues[1], (start: 1.0, end: 3.0, shape: 'B'));
      expect(c.selectedIndex, 1);
    });

    test('mergeSelected on the last cue merges backward', () {
      c
        ..selectCue(3)
        ..mergeSelected();
      expect(c.cues, hasLength(3));
      expect(c.cues[2], (start: 2.0, end: 4.0, shape: 'C'));
      expect(c.selectedIndex, 2);
    });

    test('mergeSelected with nothing selected is a no-op', () {
      c.mergeSelected();
      expect(c.cues, hasLength(4));
      expect(c.canUndo, isFalse);
    });
  });

  group('nudgeBoundary', () {
    test('fine nudge moves by the exact fine amount, bypassing snap', () {
      c.nudgeBoundary(0, 1, fineSec: 0.01);
      expect(c.cues[0].end, closeTo(1.01, 1e-9));
    });

    test('coarse nudge moves by one beat interval and snaps', () {
      c.nudgeBoundary(0, 1);
      expect(c.cues[0].end, closeTo(1.5, 1e-9)); // one 0.5s beat forward
    });

    test('is a no-op on the last cue (no trailing boundary)', () {
      final before = c.cues;
      c.nudgeBoundary(3, 1);
      expect(c.cues, before);
    });
  });

  group('undo/redo', () {
    test('redo replays an undone edit', () {
      c
        ..setShape(0, 'H')
        ..undo();
      expect(c.cues[0].shape, 'X');
      c.redo();
      expect(c.cues[0].shape, 'H');
    });

    test('a fresh edit clears the redo stack', () {
      c
        ..setShape(0, 'H')
        ..undo()
        ..setShape(1, 'G');
      expect(c.canRedo, isFalse);
    });

    test('undo/redo with an empty stack is a no-op', () {
      expect(c.canUndo, isFalse);
      c.undo(); // no throw
      expect(c.canRedo, isFalse);
      c.redo(); // no throw
    });
  });

  group('external reload', () {
    test('an external write is pushed as one undoable step', () async {
      File(
        store.path,
      ).writeAsStringSync(jsonEncode(_seedDoc().setShape(0, 'H').toJson()));
      await store.pollOnce();
      expect(store.lastEvent, DanceCuesStoreEvent.externalReload);
      expect(c.cues[0].shape, 'H');
      expect(c.canUndo, isTrue);
      c.undo();
      expect(c.cues[0].shape, 'X');
    });

    test('an external reload clears the current selection', () async {
      c.selectCue(1);
      File(store.path).writeAsStringSync(jsonEncode(_seedDoc().toJson()));
      await store.pollOnce();
      expect(c.selectedIndex, isNull);
    });
  });
}
