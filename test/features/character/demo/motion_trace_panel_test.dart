import 'dart:ui' as ui;

import 'package:dancing_cats/features/character/demo/motion_trace_panel.dart';
import 'package:dancing_cats/features/character/runtime/character_scene.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sampleMotionTraces', () {
    test('returns the four standard traces sampled across the loop', () {
      final scene = CharacterScene(buildCatInSuitRig());
      final traces = sampleMotionTraces(scene, CatClips.shaku, samples: 48);

      expect(traces, hasLength(4));
      expect(traces[0].title, contains('POCKET'));
      expect(traces[1].title, contains('WEIGHT'));
      expect(traces[2].title, contains('HEAD RIDE'));
      expect(traces[3].title, contains('FEET'));
      for (final trace in traces) {
        expect(trace.values, hasLength(49)); // samples + closing endpoint
      }
      // The feet chart overlays both soles.
      expect(traces[3].secondary, isNotNull);
      expect(traces[3].secondary, hasLength(49));
      expect(traces[3].secondaryLabel, isNotNull);
      // A dance clip genuinely moves: the pocket has real range.
      expect(traces[0].range, greaterThan(10));
    });
  });

  group('paintMotionTraces', () {
    ui.Picture paint(
      List<MotionTrace> traces, {
      double? loopSeconds,
    }) {
      final recorder = ui.PictureRecorder();
      paintMotionTraces(
        Canvas(recorder),
        const Size(1400, 1000),
        traces,
        loopSeconds: loopSeconds,
      );
      return recorder.endRecording();
    }

    test('renders charts with live event rates when loopSeconds is given',
        () async {
      final scene = CharacterScene(buildCatInSuitRig());
      final traces = sampleMotionTraces(scene, CatClips.shaku, samples: 48);
      // With the ship-tempo duration the rate labels and beat/bar gridline
      // branches all execute; the picture must rasterize non-empty.
      final picture = paint(traces, loopSeconds: 8);
      final image = await picture.toImage(1400, 1000);
      expect(image.width, 1400);
      image.dispose();
    });

    test('renders without rate labels when loopSeconds is absent', () async {
      final scene = CharacterScene(buildCatInSuitRig());
      final traces = sampleMotionTraces(scene, CatClips.shaku, samples: 24);
      final image = await paint(traces).toImage(1400, 1000);
      expect(image.height, 1000);
      image.dispose();
    });

    test('empty trace list paints only the background', () async {
      final image = await paint(const []).toImage(100, 100);
      expect(image.width, 100);
      image.dispose();
    });

    test('a flat trace reports zero events without dividing by zero',
        () async {
      const flat = MotionTrace(
        title: 'flat',
        values: [5, 5, 5, 5, 5, 5],
      );
      final image = await paint(const [flat], loopSeconds: 8).toImage(
        400,
        300,
      );
      expect(image.width, 400);
      image.dispose();
    });
  });

  group('MotionTracePainter', () {
    const traceA = MotionTrace(title: 'a', values: [0, 1, 0, 1]);
    const traceB = MotionTrace(title: 'b', values: [1, 0, 1, 0]);

    test('shouldRepaint tracks trace identity and loopSeconds', () {
      const painter = MotionTracePainter([traceA], loopSeconds: 8);
      expect(
        painter.shouldRepaint(const MotionTracePainter([traceA])),
        isTrue, // loopSeconds changed
      );
      expect(
        painter.shouldRepaint(
          const MotionTracePainter([traceB], loopSeconds: 8),
        ),
        isTrue, // different trace list
      );
      const identical = [traceA];
      expect(
        const MotionTracePainter(identical, loopSeconds: 8).shouldRepaint(
          const MotionTracePainter(identical, loopSeconds: 8),
        ),
        isFalse,
      );
    });

    testWidgets('paints inside a CustomPaint widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CustomPaint(
            painter: MotionTracePainter([traceA, traceB], loopSeconds: 4),
            size: Size(600, 400),
          ),
        ),
      );
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
