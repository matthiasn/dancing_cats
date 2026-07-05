import 'package:dancing_cats/features/character/demo/dance_move_inspector.dart';
import 'package:dancing_cats/features/character/demo/motion_trace_panel.dart';
import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/runtime/character_scene.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../widget_test_utils.dart';

Future<void> _openInspector(
  WidgetTester tester, {
  required CharacterScene scene,
  required Clip clip,
  double clipTimeSeconds = 0.3,
  Size size = const Size(1400, 1000),
}) async {
  setTestViewSize(tester, size);
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showDanceMoveInspector(
                context,
                scene: scene,
                clip: clip,
                clipTimeSeconds: clipTimeSeconds,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      mediaQueryData: MediaQueryData(size: size),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// The grid is a scrollable `GridView.builder`, which only builds cells near
/// the viewport — scroll the last cell into view rather than assuming every
/// cell up to [frameCount] is already built.
Future<void> _expectExactCellCount(WidgetTester tester, int frameCount) async {
  final lastCell = find.byKey(ValueKey('moveFrameCell_${frameCount - 1}'));
  await tester.scrollUntilVisible(
    lastCell,
    300,
    scrollable: find.byType(Scrollable).last,
  );
  expect(lastCell, findsOneWidget);
  expect(
    find.byKey(ValueKey('moveFrameCell_$frameCount')),
    findsNothing,
  );
}

void main() {
  late CharacterScene scene;
  late Clip clip;

  setUp(() {
    scene = CharacterScene(buildCatInSuitRig());
    clip = CatClips.buga;
  });

  group('showDanceMoveInspector', () {
    testWidgets('opens a Dialog showing the clip name', (tester) async {
      await _openInspector(tester, scene: scene, clip: clip);

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text(clip.name), findsOneWidget);
    });

    testWidgets('default frame count renders 16 keyframe cells', (
      tester,
    ) async {
      await _openInspector(tester, scene: scene, clip: clip);
      expect(find.byKey(const ValueKey('moveFrameCell_0')), findsOneWidget);
      await _expectExactCellCount(tester, 16);
    });

    testWidgets('the 24 chip grows the grid to 24 cells', (tester) async {
      await _openInspector(tester, scene: scene, clip: clip);

      await tester.tap(find.byKey(const Key('moveInspectorFrameCount24')));
      await tester.pumpAndSettle();

      await _expectExactCellCount(tester, 24);
    });

    testWidgets('the 12 chip shrinks the grid to 12 cells', (tester) async {
      await _openInspector(tester, scene: scene, clip: clip);

      await tester.tap(find.byKey(const Key('moveInspectorFrameCount12')));
      await tester.pumpAndSettle();

      await _expectExactCellCount(tester, 12);
    });

    testWidgets('the close button pops the route', (tester) async {
      await _openInspector(tester, scene: scene, clip: clip);
      expect(find.byType(Dialog), findsOneWidget);

      await tester.tap(find.byKey(const Key('moveInspectorCloseButton')));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('does not throw for edge-case clip times', (tester) async {
      for (final t in [0.0, clip.duration * 0.5, clip.duration]) {
        await _openInspector(
          tester,
          scene: scene,
          clip: clip,
          clipTimeSeconds: t,
        );
        expect(find.byType(Dialog), findsOneWidget);
        await tester.tap(find.byKey(const Key('moveInspectorCloseButton')));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('the TRACES chip swaps the grid for measured motion charts', (
      tester,
    ) async {
      await _openInspector(tester, scene: scene, clip: clip);

      await tester.tap(find.byKey(const Key('moveInspectorViewTRACES')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('MOTION TRACES'),
        findsOneWidget,
        reason: 'the section header should switch to the traces view',
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is MotionTracePainter,
        ),
        findsOneWidget,
        reason: 'the measured charts replace the keyframe grid',
      );
      expect(find.byKey(const ValueKey('moveFrameCell_0')), findsNothing);

      await tester.tap(find.byKey(const Key('moveInspectorViewFRAMES')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('moveFrameCell_0')), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is MotionTracePainter,
        ),
        findsNothing,
      );
    });
  });

  group('stage playback', () {
    testWidgets('starts paused, showing the play glyph', (tester) async {
      await _openInspector(tester, scene: scene, clip: clip);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
    });

    testWidgets('play toggle starts the stage advancing, pause stops it', (
      tester,
    ) async {
      await _openInspector(tester, scene: scene, clip: clip);
      final phaseText = find.byKey(const Key('moveInspectorStagePhase'));
      final before = tester.widget<Text>(phaseText).data;

      await tester.tap(find.byKey(const Key('moveInspectorStagePlayToggle')));
      await tester.pump();
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      // Bounded pumps, not pumpAndSettle — the stage ticker reschedules
      // itself every frame while playing, so pumpAndSettle would never see
      // "no more frames pending" and hang.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final during = tester.widget<Text>(phaseText).data;
      expect(during, isNot(before));

      await tester.tap(find.byKey(const Key('moveInspectorStagePlayToggle')));
      await tester.pump();
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      final afterPause = tester.widget<Text>(phaseText).data;
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<Text>(phaseText).data, afterPause);

      // Stop the ticker before the dialog closes so pumpAndSettle is safe.
      await tester.tap(find.byKey(const Key('moveInspectorCloseButton')));
      await tester.pumpAndSettle();
    });

    testWidgets('dragging the scrubber seeks the stage and pauses it', (
      tester,
    ) async {
      await _openInspector(tester, scene: scene, clip: clip);
      await tester.tap(find.byKey(const Key('moveInspectorStagePlayToggle')));
      await tester.pump();
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      await tester.drag(
        find.byKey(const Key('moveInspectorStageScrubber')),
        const Offset(200, 0),
      );
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('tapping a keyframe cell seeks the stage', (tester) async {
      await _openInspector(tester, scene: scene, clip: clip);
      final phaseText = find.byKey(const Key('moveInspectorStagePhase'));
      final before = tester.widget<Text>(phaseText).data;

      final cell = find.byKey(const ValueKey('moveFrameCell_8'));
      await tester.scrollUntilVisible(
        cell,
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(cell);
      await tester.pump();

      expect(tester.widget<Text>(phaseText).data, isNot(before));
    });
  });
}
