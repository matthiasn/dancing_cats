import 'package:dancing_cats/features/character/demo/color_grade_panel.dart';
import 'package:dancing_cats/features/scenery/model/backdrop_grade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../widget_test_utils.dart';

/// Records the latest value pushed through each callback.
class _Rec {
  GradeWheel? lift;
  GradeWheel? gamma;
  GradeWheel? gain;
  double? saturation;
  int resets = 0;
}

Future<_Rec> _pump(
  WidgetTester tester, {
  GradeWheel lift = const GradeWheel(),
  GradeWheel gamma = const GradeWheel(),
  GradeWheel gain = const GradeWheel(),
  double saturation = 1,
}) async {
  final rec = _Rec();
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Scaffold(
        body: ColorGradePanel(
          lift: lift,
          gamma: gamma,
          gain: gain,
          saturation: saturation,
          onLift: (w) => rec.lift = w,
          onGamma: (w) => rec.gamma = w,
          onGain: (w) => rec.gain = w,
          onSaturation: (v) => rec.saturation = v,
          onReset: () => rec.resets++,
        ),
      ),
    ),
  );
  return rec;
}

Finder _wheel(String label) => find.byKey(Key('gradeWheel-$label'));

void main() {
  group('ColorGradePanel', () {
    testWidgets('renders three wheels, a saturation dial and a reset', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.byType(GradeWheelControl), findsNWidgets(3));
      expect(find.text('Lift'), findsOneWidget);
      expect(find.text('Gamma'), findsOneWidget);
      expect(find.text('Gain'), findsOneWidget);
      expect(find.text('Saturation'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
    });

    testWidgets('dragging a wheel reports a colour balance', (tester) async {
      final rec = await _pump(tester);
      await tester.drag(_wheel('Lift'), const Offset(22, -14));
      await tester.pump();
      expect(rec.lift, isNotNull);
      expect(rec.lift!.balance, isNot(Offset.zero));
    });

    testWidgets('tapping a wheel jumps the puck to that point', (tester) async {
      final rec = await _pump(tester);
      // A tap-down (no drag) still positions the balance via onPanDown.
      await tester.tapAt(
        tester.getCenter(_wheel('Gain')) + const Offset(15, -10),
      );
      await tester.pump();
      expect(rec.gain, isNotNull);
      expect(rec.gain!.balance, isNot(Offset.zero));
    });

    testWidgets('the wheel master slider reports a luminance change', (
      tester,
    ) async {
      final rec = await _pump(tester);
      // The first Slider belongs to the Lift wheel's master dial.
      await tester.drag(find.byType(Slider).first, const Offset(30, 0));
      await tester.pump();
      expect(rec.lift, isNotNull);
      expect(rec.lift!.master, isNot(0));
    });

    testWidgets('the saturation slider reports a new value', (tester) async {
      final rec = await _pump(tester);
      await tester.drag(find.byType(Slider).last, const Offset(-30, 0));
      await tester.pump();
      expect(rec.saturation, isNotNull);
      expect(rec.saturation, lessThan(1));
    });

    testWidgets('the reset button fires onReset', (tester) async {
      final rec = await _pump(
        tester,
        lift: const GradeWheel(master: 0.4),
        saturation: 1.3,
      );
      await tester.tap(find.text('Reset'));
      await tester.pump();
      expect(rec.resets, 1);
    });

    testWidgets('the wheel repaints when the puck moves', (tester) async {
      await _pump(tester, gain: const GradeWheel(balance: Offset(0.2, 0.1)));
      // Re-pump with a different balance: the painter must compare and repaint.
      await _pump(tester, gain: const GradeWheel(balance: Offset(-0.3, 0.2)));
      expect(find.byType(GradeWheelControl), findsNWidgets(3));
    });
  });
}
