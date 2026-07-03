import 'dart:io';

import 'package:dancing_cats/features/character/demo/dance_cues_store.dart';
import 'package:dancing_cats/features/character/demo/dance_lip_sync_controller.dart';
import 'package:dancing_cats/features/character/demo/dance_lip_sync_doc.dart';
import 'package:dancing_cats/features/character/demo/dance_lip_sync_workspace.dart';
import 'package:dancing_cats/features/character/demo/dance_transport_bar.dart'
    show DanceWaveformSection;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../widget_test_utils.dart';

const double _duration = 40;

const _sections = <DanceWaveformSection>[
  DanceWaveformSection(start: 0, end: 20, label: 'verse'),
  DanceWaveformSection(start: 20, end: 40, label: 'chorus'),
];

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
      double durationSec = _duration,
      bool playing = false,
      List<DanceWaveformSection> sections = _sections,
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
                    durationSec: durationSec,
                    playing: playing,
                    sections: sections,
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

    // The x inside the cue lane for time [t] at FIT zoom (duration _duration).
    Offset laneOffsetFor(WidgetTester tester, double t) {
      final rect = tester.getRect(find.byKey(const Key('lipSyncLane')));
      return Offset(rect.left + t / _duration * rect.width, rect.center.dy);
    }

    // Zoom the shared axis in by one Ctrl+wheel notch (visible 40 → 32s).
    Future<TestPointer> zoomIn(WidgetTester tester) async {
      final lane = tester.getRect(find.byKey(const Key('lipSyncLane')));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      final pointer = TestPointer(3, PointerDeviceKind.mouse)
        ..hover(lane.center);
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -120)));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      return pointer;
    }

    // Where the ruler says the viewport starts: seek at its left edge.
    Future<double> viewStart(WidgetTester tester) async {
      final ruler = tester.getRect(find.byKey(const Key('lipSyncRuler')));
      await tester.tapAt(Offset(ruler.left + 1, ruler.center.dy));
      await tester.pump();
      return seeks.last;
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

    testWidgets(
      'dragging inside a cue (not on a boundary) pans the timeline',
      (tester) async {
        await pump(tester);
        await zoomIn(tester); // narrower window, room to pan
        final before = await viewStart(tester);
        final laneRect = tester.getRect(find.byKey(const Key('lipSyncLane')));
        // Well inside a cue body, away from any boundary's 8px grab radius.
        final dragStart = Offset(
          laneRect.left + laneRect.width * 0.35,
          laneRect.center.dy,
        );
        await tester.dragFrom(dragStart, const Offset(-40, 0));
        await settleTap(tester);
        expect(await viewStart(tester), greaterThan(before));
        await drain(tester);
      },
    );

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

    testWidgets('Backspace merges the selected cue via the keyboard', (
      tester,
    ) async {
      await pump(tester);
      await tester.tapAt(laneOffsetFor(tester, 15)); // selects the B cue
      await settleTap(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(store.doc.cues, hasLength(3));
      expect(store.doc.cues[1], (start: 10.0, end: 30.0, shape: 'B'));
      await drain(tester);
    });

    testWidgets('Escape clears the selection via the keyboard', (
      tester,
    ) async {
      await pump(tester);
      await tester.tapAt(laneOffsetFor(tester, 5)); // selects cue 0
      await settleTap(tester);
      expect(controller.selectedIndex, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(controller.selectedIndex, isNull);
    });

    testWidgets(
      'arrow keys nudge the trailing boundary; Shift is fine; '
      'Ctrl+Z/Y undo and redo',
      (tester) async {
        await pump(tester);
        await tester.tapAt(laneOffsetFor(tester, 5)); // selects cue 0
        await settleTap(tester);
        double boundary() => store.doc.cues[0].end;
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        final nudged = boundary();
        expect(nudged, greaterThan(10)); // snapped one beat step right
        // Shift+arrow is the fine nudge — 10ms, ignoring the snap grid.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        expect(boundary(), closeTo(nudged - 0.01, 1e-6));
        // Ctrl+Z steps back; Ctrl+Shift+Z and Ctrl+Y both step forward.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
        await tester.pump();
        expect(boundary(), closeTo(nudged, 1e-6));
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        expect(boundary(), closeTo(nudged - 0.01, 1e-6));
        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ); // undo again
        await tester.sendKeyEvent(LogicalKeyboardKey.keyY); // Ctrl+Y redoes
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        expect(boundary(), closeTo(nudged - 0.01, 1e-6));
        await drain(tester);
      },
    );

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

    testWidgets(
      'dragging the ruler scrubs the playhead (onHorizontalDragUpdate)',
      (tester) async {
        await pump(tester);
        final ruler = tester.getRect(find.byKey(const Key('lipSyncRuler')));
        final gesture = await tester.createGesture();
        await gesture.down(
          Offset(ruler.left + ruler.width * 0.25, ruler.center.dy),
        );
        // Several small steps (not one big jump) so the horizontal-drag
        // recognizer reliably wins the arena and reports updates — a
        // single large moveBy is arena-order-sensitive against the eager
        // tap recognizer sharing this GestureDetector.
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(Offset(ruler.width * 0.025, 0));
          await tester.pump();
        }
        await gesture.up();
        await tester.pump();
        expect(seeks, isNotEmpty);
        expect(seeks.last, closeTo(_duration / 2, 1.5));
      },
    );

    testWidgets('Ctrl+scroll zooms; FIT resets', (tester) async {
      await pump(tester);
      await zoomIn(tester);
      // Zoomed in around the cursor (lane centre) — no longer starts at 0.
      expect(await viewStart(tester), greaterThan(0));
      await tester.tap(find.byKey(const Key('lipSyncFit')));
      await tester.pump();
      // FIT brings the full track back (viewStart reads out via a 1px tap).
      expect(await viewStart(tester), closeTo(0, 1));
      await drain(tester);
    });

    testWidgets('plain scroll pans the zoomed view on either wheel axis', (
      tester,
    ) async {
      await pump(tester);
      final pointer = await zoomIn(tester);
      final before = await viewStart(tester);
      // A vertical wheel pans; a trackpad's dominant horizontal axis too.
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
      await tester.sendEventToBinding(pointer.scroll(const Offset(200, 10)));
      await tester.pump();
      expect(await viewStart(tester), greaterThan(before + 1));
      await drain(tester);
    });

    testWidgets('play page-flips a zoomed view; a new duration refits', (
      tester,
    ) async {
      await pump(tester);
      await zoomIn(tester); // visible narrows to 32s; follow disarmed
      // Pressing play with the playhead beyond the window re-arms follow and
      // page-flips (clamped to the track's trailing edge at this near-full
      // zoom — 40s track, 32s window leaves only 8s of room to pan).
      await pump(tester, positionSec: 39, playing: true);
      expect(await viewStart(tester), closeTo(8, 2));
      // Loading a longer track refits the viewport to the whole song.
      await pump(tester, durationSec: 200);
      expect(await viewStart(tester), closeTo(0, 2));
      await drain(tester);
    });

    testWidgets(
      'a corrupt cues file on disk shows the error chip; tap force-saves',
      (tester) async {
        await pump(tester);
        // Land the setUp seed so pollOnce() below isn't short-circuited by
        // the still-pending local edit.
        await tester.runAsync(store.flush);
        expect(find.byKey(const Key('lipSyncFileError')), findsNothing);
        File(store.path).writeAsStringSync('not json at all');
        await tester.runAsync(store.pollOnce);
        await tester.pump();
        expect(store.fileUnreadable, isTrue);
        expect(find.byKey(const Key('lipSyncFileError')), findsOneWidget);
        // Tapping it force-saves (real async I/O) and clears the error
        // state. Polls the store directly (ground truth) rather than
        // trusting the widget to have re-rendered within a bounded pump
        // budget — the fire-and-forget saveNow() call's completion timing
        // isn't deterministic under the test binding's fake clock.
        await tester.tap(find.byKey(const Key('lipSyncFileError')));
        for (var i = 0; i < 20 && store.fileUnreadable; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
        }
        expect(store.fileUnreadable, isFalse);
        await drain(tester);
      },
    );
  });
}
