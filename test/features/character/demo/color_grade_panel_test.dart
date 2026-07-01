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
  double? temperature;
  double? tint;
  double? contrast;
  bool? bypass;
  int resets = 0;
}

Future<_Rec> _pump(
  WidgetTester tester, {
  GradeWheel lift = const GradeWheel(),
  GradeWheel gamma = const GradeWheel(),
  GradeWheel gain = const GradeWheel(),
  double saturation = 1,
  double temperature = 0,
  double tint = 0,
  double contrast = 1,
  bool bypass = false,
}) async {
  final rec = _Rec();
  // The panel is a full-width transport row sized for the 1600px demo window;
  // give the test surface comparable width so the Row lays out without overflow.
  tester.view.physicalSize = const Size(1500, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Scaffold(
        body: ColorGradePanel(
          lift: lift,
          gamma: gamma,
          gain: gain,
          saturation: saturation,
          temperature: temperature,
          tint: tint,
          contrast: contrast,
          bypass: bypass,
          onLift: (w) => rec.lift = w,
          onGamma: (w) => rec.gamma = w,
          onGain: (w) => rec.gain = w,
          onSaturation: (v) => rec.saturation = v,
          onTemperature: (v) => rec.temperature = v,
          onTint: (v) => rec.tint = v,
          onContrast: (v) => rec.contrast = v,
          onBypass: (v) => rec.bypass = v,
          onReset: () => rec.resets++,
        ),
      ),
    ),
  );
  return rec;
}

Finder _wheel(String label) => find.byKey(Key('gradeWheel-$label'));
Finder _slider(String label) => find.byKey(Key('gradeSlider-$label'));

void main() {
  group('ColorGradePanel', () {
    testWidgets('renders three wheels, the balance/tone sliders and controls', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.byType(GradeWheelControl), findsNWidgets(3));
      expect(find.text('Lift'), findsOneWidget);
      expect(find.text('Gamma'), findsOneWidget);
      expect(find.text('Gain'), findsOneWidget);
      expect(find.text('Temp'), findsOneWidget);
      expect(find.text('Tint'), findsOneWidget);
      expect(find.text('Contrast'), findsOneWidget);
      expect(find.text('Saturation'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
      expect(find.byKey(const Key('gradeBypass')), findsOneWidget);
      expect(find.text('CURVES'), findsOneWidget);
      expect(find.text('R · G · B'), findsOneWidget);
    });

    testWidgets('the curves scope shows a bypassed caption when bypassed', (
      tester,
    ) async {
      await _pump(tester, bypass: true, contrast: 1.3);
      expect(find.text('bypassed'), findsOneWidget);
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
      // The last GestureDetector under the Lift control is its bipolar master.
      final liftControl = find.ancestor(
        of: _wheel('Lift'),
        matching: find.byType(GradeWheelControl),
      );
      final master = find
          .descendant(of: liftControl, matching: find.byType(GestureDetector))
          .last;
      await tester.tapAt(tester.getCenter(master) + const Offset(30, 0));
      await tester.pump();
      expect(rec.lift, isNotNull);
      expect(rec.lift!.master, greaterThan(0));
    });

    testWidgets('per-wheel reset recentres just that wheel', (tester) async {
      final rec = await _pump(
        tester,
        gain: const GradeWheel(balance: Offset(0.3, -0.2), master: 0.4),
      );
      await tester.tap(find.byKey(const Key('gradeWheelReset-Gain')));
      await tester.pump();
      expect(rec.gain, const GradeWheel());
    });

    testWidgets('a neutral wheel reset is inert', (tester) async {
      final rec = await _pump(tester); // all wheels neutral
      await tester.tap(
        find.byKey(const Key('gradeWheelReset-Gain')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(rec.gain, isNull);
    });

    testWidgets('the temperature slider reports a warmer value', (tester) async {
      final rec = await _pump(tester);
      await tester.tapAt(
        tester.getCenter(_slider('Temp')) + const Offset(40, 0),
      );
      await tester.pump();
      expect(rec.temperature, isNotNull);
      expect(rec.temperature, greaterThan(0));
    });

    testWidgets('the tint slider reports a change', (tester) async {
      final rec = await _pump(tester);
      await tester.tapAt(
        tester.getCenter(_slider('Tint')) + const Offset(40, 0),
      );
      await tester.pump();
      expect(rec.tint, isNotNull);
      expect(rec.tint, greaterThan(0));
    });

    testWidgets('the contrast slider reports a change', (tester) async {
      final rec = await _pump(tester);
      await tester.tapAt(
        tester.getCenter(_slider('Contrast')) + const Offset(40, 0),
      );
      await tester.pump();
      expect(rec.contrast, isNotNull);
      expect(rec.contrast, greaterThan(1));
    });

    testWidgets('the saturation slider reports a lower value', (tester) async {
      final rec = await _pump(tester);
      await tester.tapAt(
        tester.getCenter(_slider('Saturation')) + const Offset(-40, 0),
      );
      await tester.pump();
      expect(rec.saturation, isNotNull);
      expect(rec.saturation, lessThan(1));
    });

    testWidgets('dragging a bipolar slider tracks continuously', (
      tester,
    ) async {
      final rec = await _pump(tester);
      // A drag (down + move) exercises the slider's onPanUpdate path.
      await tester.drag(_slider('Contrast'), const Offset(40, 0));
      await tester.pump();
      expect(rec.contrast, isNotNull);
      expect(rec.contrast, greaterThan(1));
    });

    testWidgets('a bipolar slider snaps to centre near the detent', (
      tester,
    ) async {
      final rec = await _pump(tester, temperature: 0.5);
      // Tap the exact centre of the Temp track → snaps to 0.
      await tester.tapAt(tester.getCenter(_slider('Temp')));
      await tester.pump();
      expect(rec.temperature, 0);
    });

    testWidgets('the bypass toggle flips the flag', (tester) async {
      final rec = await _pump(tester);
      await tester.tap(find.byKey(const Key('gradeBypass')));
      await tester.pump();
      expect(rec.bypass, isTrue);
      expect(find.text('A / B'), findsOneWidget);
    });

    testWidgets('a bypassed panel shows the clean-plate state', (tester) async {
      final rec = await _pump(tester, bypass: true);
      expect(find.text('CLEAN'), findsOneWidget);
      await tester.tap(find.byKey(const Key('gradeBypass')));
      await tester.pump();
      expect(rec.bypass, isFalse);
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

    testWidgets('each wheel shows its coefficient letter (S/O/P)', (
      tester,
    ) async {
      await _pump(
        tester,
        gain: const GradeWheel(master: 0.5),
        lift: const GradeWheel(master: 0.3),
        gamma: const GradeWheel(master: 0.2),
      );
      expect(find.textContaining('S '), findsOneWidget); // slope, gain
      expect(find.textContaining('O '), findsOneWidget); // offset, lift
      expect(find.textContaining('P '), findsOneWidget); // power, gamma
    });

    testWidgets('the panel repaints when state changes', (tester) async {
      await _pump(tester, gain: const GradeWheel(balance: Offset(0.2, 0.1)));
      await _pump(
        tester,
        gain: const GradeWheel(balance: Offset(-0.3, 0.2)),
        temperature: 0.3,
        contrast: 1.2,
        bypass: true,
      );
      expect(find.byType(GradeWheelControl), findsNWidgets(3));
    });
  });
}
