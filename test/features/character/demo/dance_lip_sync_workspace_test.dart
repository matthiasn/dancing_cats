import 'dart:io';

import 'package:dancing_cats/features/character/demo/dance_cues_store.dart';
import 'package:dancing_cats/features/character/demo/dance_lip_sync_controller.dart';
import 'package:dancing_cats/features/character/demo/dance_lip_sync_doc.dart';
import 'package:dancing_cats/features/character/demo/dance_lip_sync_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../widget_test_utils.dart';

const double _duration = 40;

/// Four contiguous 10-second cues covering the whole track: X, B, C, D.
LipSyncDoc _seedDoc() => const LipSyncDoc(
  cues: [
    (start: 0, end: 10, shape: 'X'),
    (start: 10, end: 20, shape: 'B'),
    (start: 20, end: 30, shape: 'C'),
    (start: 30, end: 40, shape: 'D'),
  ],
);

void main() {
  group('DanceLipSyncWorkspace', () {
    late Directory dir;
    late DanceCuesStore store;
    late DanceLipSyncController controller;
    final seeks = <double>[];

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('lip_sync_ws_test');
      store = DanceCuesStore(
        path: p.join(dir.path, 't.cues.json'),
        saveDebounce: const Duration(minutes: 1),
        pollInterval: const Duration(minutes: 1),
      );
      await store.load();
      store.update(_seedDoc());
      controller = DanceLipSyncController(
        store: store,
        beatTimesSec: [for (var i = 0; i < 100; i++) i * 0.5],
      );
      seeks.clear();
    });

    tearDown(() {
      controller.dispose();
      store.dispose();
      dir.deleteSync(recursive: true);
    });

    Future<void> pump(
      WidgetTester tester, {
      double positionSec = 5,
      bool playing = false,
    }) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: Column(
              children: [
                const Expanded(child: SizedBox()),
                SizedBox(
                  height: 300,
                  child: DanceLipSyncWorkspace(
                    controller: controller,
                    positionSec: positionSec,
                    durationSec: _duration,
                    playing: playing,
                    onSeek: seeks.add,
                  ),
                ),
              ],
            ),
          ),
          mediaQueryData: const MediaQueryData(size: Size(1600, 900)),
        ),
      );
      await tester.pump();
    }

    // The lane registers onDoubleTap, so a single tap only wins the gesture
    // arena after the double-tap timeout — pump past it.
    Future<void> settleTap(WidgetTester tester) =>
        tester.pump(const Duration(milliseconds: 400));

    // Fire any straggling timers (the store's debounced autosave) so
    // testWidgets' pending-timer check stays green.
    Future<void> drain(WidgetTester tester) =>
        tester.pump(const Duration(minutes: 2));

    // The x inside the cue lane for time [t] at FIT zoom.
    Offset laneOffsetFor(WidgetTester tester, double t) {
      final rect = tester.getRect(find.byKey(const Key('lipSyncLane')));
      return Offset(rect.left + t / _duration * rect.width, rect.center.dy);
    }

    testWidgets('renders the shared timeline, cue lane and shape palette', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byKey(const Key('lipSyncWorkspace')), findsOneWidget);
      expect(find.byKey(const Key('lipSyncRuler')), findsOneWidget);
      expect(find.byKey(const Key('lipSyncLane')), findsOneWidget);
      for (final letter in kVisemeOrder) {
        expect(find.byKey(Key('lipSyncShape-$letter')), findsOneWidget);
      }
    });

    testWidgets('the toolbar toggles snap', (tester) async {
      await pump(tester);
      expect(controller.snapEnabled, isTrue);
      await tester.tap(find.byKey(const Key('lipSyncSnap')));
      await tester.pump();
      expect(controller.snapEnabled, isFalse);
    });

    testWidgets('tapping a cue selects it and moves the playhead', (
      tester,
    ) async {
      await pump(tester);
      await tester.tapAt(laneOffsetFor(tester, 15)); // inside the B cue
      await settleTap(tester);
      expect(controller.selectedIndex, 1);
      expect(seeks, [10]); // click-cue-moves-playhead, to the cue's start
      await drain(tester);
    });

    testWidgets('double-tapping inside a cue splits it', (tester) async {
      await pump(tester);
      final at = laneOffsetFor(tester, 15); // inside the B cue (10..20)
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(at);
      await tester.pumpAndSettle();
      expect(store.doc.cues, hasLength(5));
      expect(store.doc.cues[1].end, closeTo(15, 1e-9));
      expect(store.doc.cues[2].start, closeTo(15, 1e-9));
      expect(store.doc.cues[1].shape, 'B');
      expect(store.doc.cues[2].shape, 'B');
      await drain(tester);
    });

    testWidgets('dragging a boundary retimes it (one undo step)', (
      tester,
    ) async {
      await pump(tester);
      final laneRect = tester.getRect(find.byKey(const Key('lipSyncLane')));
      final pxPerSec = laneRect.width / _duration;
      // Drag the boundary at t=10 (between cues[0] and cues[1]) forward.
      await tester.dragFrom(laneOffsetFor(tester, 10), Offset(3 * pxPerSec, 0));
      await settleTap(tester);
      expect(store.doc.cues[0].end, greaterThan(10));
      expect(store.doc.cues[0].end, closeTo(13, 0.6)); // snapped near +3s
      controller.undo();
      expect(store.doc.cues[0].end, 10);
      await drain(tester);
    });

    testWidgets('Delete merges the selected cue via the keyboard', (
      tester,
    ) async {
      await pump(tester);
      await tester.tapAt(laneOffsetFor(tester, 15)); // selects the B cue
      await settleTap(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();
      expect(store.doc.cues, hasLength(3));
      expect(store.doc.cues[1], (start: 10.0, end: 30.0, shape: 'B'));
      await drain(tester);
    });

    testWidgets('the shape palette reassigns the selected cue', (
      tester,
    ) async {
      await pump(tester);
      await tester.tapAt(laneOffsetFor(tester, 15)); // selects the B cue
      await settleTap(tester);
      await tester.tap(find.byKey(const Key('lipSyncShape-F')));
      await tester.pump();
      expect(store.doc.cues[1].shape, 'F');
      await drain(tester);
    });

    testWidgets('the shape palette is inert with no selection', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('lipSyncShape-F')));
      await tester.pump();
      // Nothing selected → nothing changes.
      expect(store.doc.cues, _seedDoc().cues);
    });

    testWidgets('undo/redo buttons drive the controller', (tester) async {
      await pump(tester);
      controller.setShape(0, 'H');
      await tester.pump();
      await tester.tap(find.byKey(const Key('lipSyncUndo')));
      await tester.pump();
      expect(store.doc.cues[0].shape, 'X');
      await tester.tap(find.byKey(const Key('lipSyncRedo')));
      await tester.pump();
      expect(store.doc.cues[0].shape, 'H');
      await drain(tester);
    });

    testWidgets('the ruler scrubs the playhead on tap', (tester) async {
      await pump(tester);
      final ruler = tester.getRect(find.byKey(const Key('lipSyncRuler')));
      await tester.tapAt(
        Offset(ruler.left + ruler.width / 2, ruler.center.dy),
      );
      await tester.pump();
      expect(seeks, isNotEmpty);
      expect(seeks.last, closeTo(_duration / 2, 1.5));
    });
  });
}
