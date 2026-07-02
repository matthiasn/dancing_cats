import 'dart:io';

import 'package:dancing_cats/features/character/demo/color_grade_panel.dart';
import 'package:dancing_cats/features/character/demo/dance_grade_controller.dart';
import 'package:dancing_cats/features/character/demo/dance_grade_store.dart';
import 'package:dancing_cats/features/character/demo/dance_grade_workspace.dart';
import 'package:dancing_cats/features/character/demo/dance_transport_bar.dart';
import 'package:dancing_cats/features/scenery/model/grade_timeline.dart';
import 'package:dancing_cats/features/scenery/model/scope_histogram.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../widget_test_utils.dart';

const double _duration = 100;

GradeLook _sat(double s) => GradeLook(saturation: s);

void main() {
  group('GradeTimelineViewport', () {
    const fit = GradeTimelineViewport(
      durationSec: 100,
      startSec: 0,
      visibleSec: 100,
    );

    test('fit maps the whole track across the width', () {
      final v = GradeTimelineViewport.fit(100);
      expect(v.xFor(0, 500), 0);
      expect(v.xFor(100, 500), 500);
      expect(v.tFor(250, 500), 50);
    });

    test('xFor and tFor are inverses at any zoom', () {
      final v = fit.zoomAt(30, 4);
      for (final t in [20.0, 30.0, 42.5]) {
        expect(v.tFor(v.xFor(t, 640), 640), closeTo(t, 1e-9));
      }
    });

    test('zoomAt keeps the focus time pinned under the cursor', () {
      final v = fit.zoomAt(30, 4);
      expect(v.visibleSec, 25);
      // Focus at u=0.3 of the old window stays at u=0.3 of the new one.
      expect(v.xFor(30, 100), closeTo(30, 1e-9));
      expect(v.contains(30), isTrue);
    });

    test('zoom clamps to the minimum window and the track length', () {
      expect(
        fit.zoomAt(50, 1000000000).visibleSec,
        GradeTimelineViewport.minVisibleSec,
      );
      expect(fit.zoomAt(50, 1e-9).visibleSec, 100);
      expect(fit.zoomAt(50, 0.5).startSec, 0);
    });

    test('panBy moves and clamps at both edges', () {
      final zoomed = fit.zoomAt(50, 4); // visible 25
      expect(zoomed.panBy(10).startSec, closeTo(zoomed.startSec + 10, 1e-9));
      expect(zoomed.panBy(-1000).startSec, 0);
      expect(zoomed.panBy(1000).startSec, closeTo(75, 1e-9));
    });

    test('centreOn centres (clamped)', () {
      final zoomed = fit.zoomAt(50, 4);
      expect(zoomed.centreOn(50).startSec, closeTo(37.5, 1e-9));
      expect(zoomed.centreOn(0).startSec, 0);
    });

    test('followPlayhead page-flips only past the right margin', () {
      final zoomed = fit.zoomAt(0, 4); // 0..25 visible
      expect(zoomed.followPlayhead(10), zoomed); // inside → unchanged
      final flipped = zoomed.followPlayhead(26);
      expect(flipped.startSec, closeTo(26 - 25 * 0.05, 1e-9));
      expect(flipped.visibleSec, 25);
    });

    test('value equality', () {
      expect(GradeTimelineViewport.fit(100), GradeTimelineViewport.fit(100));
      expect(
        GradeTimelineViewport.fit(100).hashCode,
        GradeTimelineViewport.fit(100).hashCode,
      );
      expect(GradeTimelineViewport.fit(100), isNot(fit.zoomAt(1, 2)));
    });
  });

  group('DanceGradeWorkspace', () {
    late Directory dir;
    late DanceGradeStore store;
    late DanceGradeController controller;
    final seeks = <double>[];
    var bypasses = <bool>[];

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('grade_ws_test');
      store = DanceGradeStore(
        path: p.join(dir.path, 't.grade.json'),
        saveDebounce: const Duration(minutes: 1),
        pollInterval: const Duration(minutes: 1),
      );
      await store.load();
      controller = DanceGradeController(
        store: store,
        beatTimesSec: [for (var i = 0; i < 200; i++) i * 0.5],
        downbeatIndices: [for (var i = 0; i < 50; i++) i * 4],
        sectionStartsSec: const [0, 20, 60],
      );
      seeks.clear();
      bypasses = [];
    });

    tearDown(() {
      controller.dispose();
      store.dispose();
      dir.deleteSync(recursive: true);
    });

    Future<void> pump(
      WidgetTester tester, {
      double positionSec = 10,
      bool playing = false,
      double durationSec = _duration,
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
                  height: 470,
                  child: DanceGradeWorkspace(
                    controller: controller,
                    positionSec: positionSec,
                    durationSec: durationSec,
                    playing: playing,
                    amplitudes: const [0.2, 0.9, 0.5, 0.7, 0.3, 0.8],
                    sections: const [
                      DanceWaveformSection(start: 0, end: 20, label: 'verse'),
                      DanceWaveformSection(
                        start: 20,
                        end: 100,
                        label: 'chorus',
                      ),
                    ],
                    parade: ScopeHistogram.empty(),
                    bypass: false,
                    onBypass: bypasses.add,
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

    // Lane canvases register onDoubleTap, so a single tap only wins the
    // gesture arena after the double-tap timeout — pump past it.
    Future<void> settleTap(WidgetTester tester) =>
        tester.pump(const Duration(milliseconds: 400));

    // Fire any straggling timers (the store's debounced autosave, the 4s
    // toolbar note) so testWidgets' pending-timer check stays green.
    Future<void> drain(WidgetTester tester) =>
        tester.pump(const Duration(minutes: 2));

    // The x inside the master lane canvas for time [t] at FIT zoom.
    Offset laneOffsetFor(WidgetTester tester, double t, {String? target}) {
      final rect = tester.getRect(
        find.byKey(Key('gradeLane-${target ?? 'master'}')),
      );
      return Offset(
        rect.left + t / _duration * rect.width,
        rect.center.dy,
      );
    }

    testWidgets('renders the shared timeline rows, master lane and console', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byKey(const Key('gradeWorkspace')), findsOneWidget);
      expect(find.byKey(const Key('gradeOverview')), findsOneWidget);
      expect(find.byKey(const Key('gradeRuler')), findsOneWidget);
      expect(find.byKey(const Key('gradeWaveform')), findsOneWidget);
      expect(find.byKey(const Key('gradeBeatsLane')), findsOneWidget);
      expect(find.byKey(const Key('gradeLane-master')), findsOneWidget);
      expect(find.byType(ColorGradePanel), findsOneWidget);
      // The console header names the lane it edits.
      expect(find.text('MASTER'), findsWidgets);
    });

    testWidgets('the toolbar toggles auto-key and snap', (tester) async {
      await pump(tester);
      expect(controller.autoKey, isTrue);
      await tester.tap(find.byKey(const Key('gradeAutoKey')));
      await tester.pump();
      expect(controller.autoKey, isFalse);
      await tester.tap(find.byKey(const Key('gradeSnap')));
      await tester.pump();
      expect(controller.snapEnabled, isFalse);
    });

    testWidgets('ADD TRACK lists targets and adds a lane', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('gradeAddTrack')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Deck glow')); // '· no offset'
      await tester.pumpAndSettle();
      expect(store.doc.lane('deck-glow'), isNotNull);
      expect(controller.selectedTarget, 'deck-glow');
      expect(
        find.byKey(const Key('gradeLaneHeader-deck-glow')),
        findsOneWidget,
      );
      await drain(tester);
    });

    testWidgets('tapping a keyframe selects it and moves the playhead', (
      tester,
    ) async {
      store.update(
        GradeTimelineDoc(
          lanes: [
            GradeLane(
              target: GradeTargets.master,
              keyframes: [GradeKeyframe(tSec: 40, look: _sat(0.5))],
            ),
          ],
        ),
      );
      await pump(tester);
      await tester.tapAt(laneOffsetFor(tester, 40));
      await settleTap(tester);
      expect(controller.selectedKeyTimes, {40});
      expect(seeks, [40]); // click-key-moves-playhead (ADR 0002 §4)
      await drain(tester);
    });

    testWidgets('double-tapping empty lane space adds a key there', (
      tester,
    ) async {
      await pump(tester);
      final at = laneOffsetFor(tester, 30);
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(at);
      await tester.pumpAndSettle();
      final lane = store.doc.lane(GradeTargets.master)!;
      expect(lane.keyframes, hasLength(1));
      // Snapped to the detected half-second grid around t=30.
      expect(lane.keyframes.single.tSec, closeTo(30, 0.3));
      await drain(tester);
    });

    testWidgets('right-click on a key opens the context menu; Remove deletes', (
      tester,
    ) async {
      store.update(
        GradeTimelineDoc(
          lanes: [
            GradeLane(
              target: GradeTargets.master,
              keyframes: [GradeKeyframe(tSec: 40, look: _sat(0.5))],
            ),
          ],
        ),
      );
      await pump(tester);
      await tester.tapAt(
        laneOffsetFor(tester, 40),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      expect(find.text('Remove key'), findsOneWidget);
      expect(find.text('Copy look'), findsOneWidget);
      expect(find.text('Hold (cut)'), findsOneWidget);
      await tester.tap(find.text('Remove key'));
      await tester.pumpAndSettle();
      expect(store.doc.lane(GradeTargets.master)!.keyframes, isEmpty);
      await drain(tester);
    });

    testWidgets('the context menu re-curves a segment', (tester) async {
      store.update(
        GradeTimelineDoc(
          lanes: [
            GradeLane(
              target: GradeTargets.master,
              keyframes: [GradeKeyframe(tSec: 40, look: _sat(0.5))],
            ),
          ],
        ),
      );
      await pump(tester);
      await tester.tapAt(
        laneOffsetFor(tester, 40),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hold (cut)'));
      await tester.pumpAndSettle();
      expect(
        store.doc.lane(GradeTargets.master)!.keyframes.single.interp,
        GradeInterp.hold,
      );
      await drain(tester);
    });

    testWidgets('right-click on empty space offers Add key here', (
      tester,
    ) async {
      await pump(tester);
      await tester.tapAt(
        laneOffsetFor(tester, 60),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add key here'));
      await tester.pumpAndSettle();
      expect(store.doc.lane(GradeTargets.master)!.keyframes, hasLength(1));
      await drain(tester);
    });

    testWidgets('Delete removes the selected key via the keyboard', (
      tester,
    ) async {
      store.update(
        GradeTimelineDoc(
          lanes: [
            GradeLane(
              target: GradeTargets.master,
              keyframes: [GradeKeyframe(tSec: 40, look: _sat(0.5))],
            ),
          ],
        ),
      );
      await pump(tester);
      await tester.tapAt(laneOffsetFor(tester, 40));
      await settleTap(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();
      expect(store.doc.lane(GradeTargets.master)!.keyframes, isEmpty);
      await drain(tester);
    });

    testWidgets('dragging a key moves it in time (one undo step)', (
      tester,
    ) async {
      store.update(
        GradeTimelineDoc(
          lanes: [
            GradeLane(
              target: GradeTargets.master,
              keyframes: [GradeKeyframe(tSec: 40, look: _sat(0.5))],
            ),
          ],
        ),
      );
      await pump(tester);
      final laneRect = tester.getRect(
        find.byKey(const Key('gradeLane-master')),
      );
      final pxPerSec = laneRect.width / _duration;
      await tester.dragFrom(
        laneOffsetFor(tester, 40),
        Offset(10 * pxPerSec, 0),
      );
      await settleTap(tester);
      final t = store.doc.lane(GradeTargets.master)!.keyframes.single.tSec;
      expect(t, closeTo(50, 0.6)); // snapped near the target beat
      controller.undo();
      expect(store.doc.lane(GradeTargets.master)!.keyframes.single.tSec, 40);
      await drain(tester);
    });

    testWidgets('the ruler scrubs the playhead (drag = seek)', (tester) async {
      await pump(tester);
      final ruler = tester.getRect(find.byKey(const Key('gradeRuler')));
      await tester.tapAt(Offset(ruler.left + ruler.width / 2, ruler.center.dy));
      await tester.pump();
      expect(seeks, isNotEmpty);
      expect(seeks.last, closeTo(50, 1.5));
    });

    testWidgets('the waveform seeks on tap', (tester) async {
      await pump(tester);
      final wave = tester.getRect(find.byKey(const Key('gradeWaveform')));
      await tester.tapAt(Offset(wave.left + wave.width / 4, wave.center.dy));
      await tester.pump();
      expect(seeks.last, closeTo(25, 1.5));
    });

    testWidgets('lane mute and lane menu clear work from the header', (
      tester,
    ) async {
      store.update(
        GradeTimelineDoc(
          lanes: [
            GradeLane(
              target: GradeTargets.master,
              keyframes: [GradeKeyframe(tSec: 40, look: _sat(0.5))],
            ),
          ],
        ),
      );
      await pump(tester);
      await tester.tap(find.byKey(const Key('gradeLaneMute-master')));
      await tester.pump();
      expect(store.doc.lane(GradeTargets.master)!.enabled, isFalse);
      await tester.tap(find.byKey(const Key('gradeLaneMenu-master')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear keyframes'));
      await tester.pumpAndSettle();
      expect(store.doc.lane(GradeTargets.master)!.keyframes, isEmpty);
      await drain(tester);
    });

    testWidgets('auto-key OFF shows UNKEYED and ● KEY commits at playhead', (
      tester,
    ) async {
      controller.autoKey = false;
      await pump(tester, positionSec: 25);
      // Dial saturation on the console (a slider drag).
      await tester.drag(
        find.byKey(const Key('gradeSlider-Saturation')),
        const Offset(-30, 0),
      );
      await tester.pump();
      expect(controller.preview, isNotNull);
      expect(find.byKey(const Key('gradeUnkeyedChip')), findsOneWidget);
      await tester.tap(find.byKey(const Key('gradeStampKey')));
      await tester.pump();
      final lane = store.doc.lane(GradeTargets.master)!;
      expect(lane.keyframes.single.tSec, 25);
      expect(lane.keyframes.single.look.saturation, lessThan(1));
      expect(find.byKey(const Key('gradeUnkeyedChip')), findsNothing);
      await drain(tester);
    });

    testWidgets('a paused console edit auto-keys and flashes the note', (
      tester,
    ) async {
      await pump(tester, positionSec: 12);
      await tester.drag(
        find.byKey(const Key('gradeSlider-Saturation')),
        const Offset(-30, 0),
      );
      await tester.pump();
      final lane = store.doc.lane(GradeTargets.master)!;
      expect(lane.keyframes.single.tSec, 12);
      expect(find.byKey(const Key('gradeNote')), findsOneWidget);
      expect(find.textContaining('keyed @'), findsOneWidget);
      await drain(tester);
    });

    testWidgets('undo/redo buttons drive the controller', (tester) async {
      await pump(tester, positionSec: 5);
      controller.stampAt(5);
      await tester.pump();
      await tester.tap(find.byKey(const Key('gradeUndo')));
      await tester.pump();
      expect(store.doc.isEmpty, isTrue);
      await tester.tap(find.byKey(const Key('gradeRedo')));
      await tester.pump();
      expect(store.doc.lane(GradeTargets.master)!.keyframes, hasLength(1));
      await drain(tester);
    });

    testWidgets('a corrupt file on disk lights the error chip', (
      tester,
    ) async {
      File(store.path).writeAsStringSync('not json');
      await tester.runAsync(store.pollOnce);
      await pump(tester);
      expect(find.byKey(const Key('gradeFileError')), findsOneWidget);
      // Tapping it force-saves and clears the state.
      await tester.tap(find.byKey(const Key('gradeFileError')));
      await tester.pumpAndSettle();
      expect(store.fileUnreadable, isFalse);
      await drain(tester);
    });

    testWidgets('an external reload flashes the reload note', (tester) async {
      await pump(tester);
      File(store.path).writeAsStringSync(
        '{"version":1,"lanes":[{"target":"cast","keyframes":'
        '[{"t_sec":9,"look":{"saturation":0.5}}]}]}',
      );
      await tester.runAsync(store.pollOnce);
      await tester.pump();
      expect(find.textContaining('reloaded from disk'), findsOneWidget);
      await drain(tester);
    });

    testWidgets('Ctrl+scroll zooms; FIT resets', (tester) async {
      store.update(
        GradeTimelineDoc(
          lanes: [
            GradeLane(
              target: GradeTargets.master,
              keyframes: [GradeKeyframe(tSec: 40, look: _sat(0.5))],
            ),
          ],
        ),
      );
      await pump(tester);
      final wave = tester.getRect(find.byKey(const Key('gradeWaveform')));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      final pointer = TestPointer(1, PointerDeviceKind.mouse)
        ..hover(wave.center);
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -120)));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      // Zoomed in: the key at t=40 has shifted position (viewport changed) —
      // FIT brings the full track back.
      await tester.tap(find.byKey(const Key('gradeFit')));
      await tester.pump();
      expect(find.byKey(const Key('gradeWorkspace')), findsOneWidget);
      await drain(tester);
    });

    testWidgets('Esc discards the sticky preview from the keyboard', (
      tester,
    ) async {
      controller.autoKey = false;
      await pump(tester);
      await tester.drag(
        find.byKey(const Key('gradeSlider-Saturation')),
        const Offset(-30, 0),
      );
      await tester.pump();
      expect(controller.preview, isNotNull);
      await tester.tapAt(laneOffsetFor(tester, 70)); // focus the timeline
      await settleTap(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(controller.preview, isNull);
      await drain(tester);
    });

    // Zoom the shared axis in by one Ctrl+wheel notch (visible 100 → 80s).
    Future<TestPointer> zoomIn(WidgetTester tester) async {
      final wave = tester.getRect(find.byKey(const Key('gradeWaveform')));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      final pointer = TestPointer(3, PointerDeviceKind.mouse)
        ..hover(wave.center);
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -120)));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      return pointer;
    }

    // Where the ruler says the viewport starts: seek at its left edge.
    Future<double> viewStart(WidgetTester tester) async {
      final ruler = tester.getRect(find.byKey(const Key('gradeRuler')));
      await tester.tapAt(Offset(ruler.left + 1, ruler.center.dy));
      await tester.pump();
      return seeks.last;
    }

    testWidgets('play page-flips a zoomed view; a new duration refits', (
      tester,
    ) async {
      await pump(tester);
      await zoomIn(tester); // visible 80s starting at 10s; follow disarmed
      // Pressing play with the playhead beyond the window re-arms follow and
      // page-flips so the playhead sits near the left edge (5% margin).
      await pump(tester, positionSec: 95, playing: true);
      expect(await viewStart(tester), closeTo(95 - 80 * 0.95, 2));
      // Loading a longer track refits the viewport to the whole song.
      await pump(tester, durationSec: 200);
      expect(await viewStart(tester), closeTo(0, 2));
    });

    testWidgets('plain scroll pans the zoomed view on either wheel axis', (
      tester,
    ) async {
      await pump(tester);
      final pointer = await zoomIn(tester); // window [10, 90]
      final before = await viewStart(tester);
      // A vertical wheel pans; a trackpad's dominant horizontal axis too.
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
      await tester.sendEventToBinding(pointer.scroll(const Offset(200, 10)));
      await tester.pump();
      expect(await viewStart(tester), greaterThan(before + 1));
    });

    testWidgets('arrow keys nudge the selected key; Ctrl+Z/Y undo and redo', (
      tester,
    ) async {
      store.update(
        GradeTimelineDoc(
          lanes: [
            GradeLane(
              target: GradeTargets.master,
              keyframes: [GradeKeyframe(tSec: 40, look: _sat(0.5))],
            ),
          ],
        ),
      );
      await pump(tester);
      await tester.tapAt(laneOffsetFor(tester, 40));
      await settleTap(tester);
      double keyT() =>
          store.doc.lane(GradeTargets.master)!.keyframes.single.tSec;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      final nudged = keyT();
      expect(nudged, greaterThan(40)); // snapped one grid step right
      // Shift+arrow is the fine nudge — 10ms, ignoring the snap grid.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(keyT(), closeTo(nudged - 0.01, 1e-6));
      // Ctrl+Z steps back; Ctrl+Shift+Z and Ctrl+Y both step forward.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.pump();
      expect(keyT(), closeTo(nudged, 1e-6));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(keyT(), closeTo(nudged - 0.01, 1e-6));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ); // undo again
      await tester.sendKeyEvent(LogicalKeyboardKey.keyY); // Ctrl+Y redoes
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(keyT(), closeTo(nudged - 0.01, 1e-6));
      await drain(tester);
    });

    testWidgets('the context menu copies a look and pastes it as a new key', (
      tester,
    ) async {
      store.update(
        GradeTimelineDoc(
          lanes: [
            GradeLane(
              target: GradeTargets.master,
              keyframes: [GradeKeyframe(tSec: 40, look: _sat(0.5))],
            ),
          ],
        ),
      );
      await pump(tester);
      await tester.tapAt(
        laneOffsetFor(tester, 40),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy look'));
      await tester.pumpAndSettle();
      expect(controller.clipboard, isNotNull);
      await tester.tapAt(
        laneOffsetFor(tester, 80),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paste look as new key here'));
      await tester.pumpAndSettle();
      final lane = store.doc.lane(GradeTargets.master)!;
      expect(lane.keyframes, hasLength(2));
      expect(lane.keyframes.last.look.saturation, 0.5);
      await drain(tester);
    });

    testWidgets('dragging empty lane space pans the axis, never a key', (
      tester,
    ) async {
      store.update(
        GradeTimelineDoc(
          lanes: [
            GradeLane(
              target: GradeTargets.master,
              keyframes: [GradeKeyframe(tSec: 40, look: _sat(0.5))],
            ),
          ],
        ),
      );
      await pump(tester);
      await tester.dragFrom(laneOffsetFor(tester, 70), const Offset(-60, 0));
      await settleTap(tester);
      expect(store.doc.lane(GradeTargets.master)!.keyframes.single.tSec, 40);
      await drain(tester);
    });

    testWidgets('the overview strip jumps and drags the view window', (
      tester,
    ) async {
      await pump(tester);
      await zoomIn(tester); // window [10, 90]
      final ov = tester.getRect(find.byKey(const Key('gradeOverview')));
      // A tap re-centres the window on the tapped song position…
      await tester.tapAt(Offset(ov.left + ov.width * 0.1, ov.center.dy));
      await tester.pump();
      expect(await viewStart(tester), closeTo(0, 2)); // centreOn(10) clamps
      // …and dragging the brush slides it continuously.
      await tester.dragFrom(
        Offset(ov.left + ov.width * 0.5, ov.center.dy),
        Offset(ov.width * 0.3, 0),
      );
      await tester.pump();
      expect(await viewStart(tester), closeTo(20, 2)); // clamped right edge
    });

    testWidgets('dragging the ruler and the waveform scrubs continuously', (
      tester,
    ) async {
      await pump(tester);
      final ruler = tester.getRect(find.byKey(const Key('gradeRuler')));
      await tester.dragFrom(
        Offset(ruler.left + ruler.width * 0.2, ruler.center.dy),
        Offset(ruler.width * 0.2, 0),
      );
      await tester.pump();
      expect(seeks.last, closeTo(40, 3));
      final wave = tester.getRect(find.byKey(const Key('gradeWaveform')));
      await tester.dragFrom(
        Offset(wave.left + wave.width * 0.5, wave.center.dy),
        Offset(-wave.width * 0.2, 0),
      );
      await tester.pump();
      expect(seeks.last, closeTo(30, 3));
    });

    testWidgets('a lane header selects its lane; the menu removes it', (
      tester,
    ) async {
      store.update(
        GradeTimelineDoc(
          lanes: [
            GradeLane(
              target: GradeTargets.master,
              keyframes: [GradeKeyframe(tSec: 40, look: _sat(0.5))],
            ),
            GradeLane(
              target: GradeTargets.cast,
              keyframes: [GradeKeyframe(tSec: 10, look: _sat(0.8))],
            ),
          ],
        ),
      );
      await pump(tester);
      await tester.tap(find.byKey(const Key('gradeLaneHeader-cast')));
      await tester.pump();
      expect(controller.selectedTarget, GradeTargets.cast);
      await tester.tap(find.byKey(const Key('gradeLaneMenu-cast')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove lane'));
      await tester.pumpAndSettle();
      expect(store.doc.lane(GradeTargets.cast), isNull);
      await drain(tester);
    });

    testWidgets('the console chip narrates holding after the last key', (
      tester,
    ) async {
      store.update(
        GradeTimelineDoc(
          lanes: [
            GradeLane(
              target: GradeTargets.master,
              keyframes: [GradeKeyframe(tSec: 5, look: _sat(0.5))],
            ),
          ],
        ),
      );
      await pump(tester, positionSec: 50);
      expect(find.text('after last key · holding'), findsOneWidget);
      await drain(tester);
    });

    testWidgets('every console control writes its field through auto-key', (
      tester,
    ) async {
      await pump(tester, positionSec: 20);
      Future<void> dial(String key) async {
        await tester.drag(find.byKey(Key(key)), const Offset(25, 0));
        await tester.pump();
      }

      await dial('gradeWheel-Lift');
      await dial('gradeWheel-Gamma');
      await dial('gradeWheel-Gain');
      await dial('gradeSlider-Temp');
      await dial('gradeSlider-Tint');
      await dial('gradeSlider-Contrast');
      await dial('gradeSlider-Pivot');
      final look = store.doc.lane(GradeTargets.master)!.evaluate(20);
      expect(look.lift.balance.dx, greaterThan(0));
      expect(look.gamma.balance.dx, greaterThan(0));
      expect(look.gain.balance.dx, greaterThan(0));
      expect(look.temperature, greaterThan(0));
      expect(look.tint, greaterThan(0));
      expect(look.contrast, greaterThan(1));
      expect(look.pivot, greaterThan(kGradePivotDefault));
      // Reset restores neutral in one stroke — and keys it, like any edit.
      await tester.tap(find.text('Reset'));
      await tester.pump();
      expect(
        store.doc.lane(GradeTargets.master)!.evaluate(20).isNeutral,
        isTrue,
      );
      await drain(tester);
    });

    testWidgets('save-time store events surface as toolbar notes', (
      tester,
    ) async {
      await pump(tester);
      // The first save pins the store's known-content baseline.
      controller.stampAt(10);
      await tester.runAsync(store.flush);
      await tester.pump();
      // An external writer lands while a local edit is pending — the save
      // that follows declares last-writer-wins out loud.
      controller.stampAt(20);
      File(store.path).writeAsStringSync('{"version":1,"lanes":[]}');
      await tester.runAsync(store.flush);
      await tester.pump();
      expect(
        find.textContaining('external change overwritten'),
        findsOneWidget,
      );
      await drain(tester);
    });

    testWidgets('a corrupt write while open lights the chip, not a note', (
      tester,
    ) async {
      await pump(tester);
      File(store.path).writeAsStringSync('not json');
      await tester.runAsync(store.pollOnce);
      await tester.pump();
      expect(find.byKey(const Key('gradeFileError')), findsOneWidget);
      expect(find.byKey(const Key('gradeNote')), findsNothing);
      await drain(tester);
    });

    testWidgets('a hold segment draws its flat tail to the next key', (
      tester,
    ) async {
      store.update(
        GradeTimelineDoc(
          lanes: [
            GradeLane(
              target: GradeTargets.master,
              keyframes: [
                GradeKeyframe(
                  tSec: 20,
                  look: _sat(0.5),
                  interp: GradeInterp.hold,
                ),
                GradeKeyframe(tSec: 60, look: _sat(0.8)),
              ],
            ),
          ],
        ),
      );
      await pump(tester);
      expect(find.byKey(const Key('gradeLane-master')), findsOneWidget);
      await drain(tester);
    });
  });
}
