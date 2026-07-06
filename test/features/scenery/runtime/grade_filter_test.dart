import 'dart:ui' as ui;

import 'package:dancing_cats/features/scenery/model/backdrop_grade.dart';
import 'package:dancing_cats/features/scenery/runtime/grade_filter.dart';
import 'package:dancing_cats/features/scenery/runtime/scenery_shaders.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a [GradeFilter] over a red square inside a keyed RepaintBoundary and
/// returns the centre pixel once the shader load has settled.
Future<ui.Color> _centrePixel(
  WidgetTester tester, {
  required BackdropGrade grade,
  bool premultiplied = false,
  bool allowSnapshot = true,
  SceneryShaderProgramLoader? loader,
}) async {
  const boundaryKey = Key('captureBoundary');
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Center(
        child: RepaintBoundary(
          key: boundaryKey,
          child: SizedBox(
            width: 64,
            height: 64,
            child: GradeFilter(
              grade: grade,
              premultiplied: premultiplied,
              allowSnapshot: allowSnapshot,
              programLoader: loader,
              child: const ColoredBox(color: Color(0xFFCC2222)),
            ),
          ),
        ),
      ),
    ),
  );
  // Let the async shader load land, then repaint with the program present.
  await tester.pumpAndSettle();
  final boundary =
      tester.renderObject(find.byKey(boundaryKey)) as RenderRepaintBoundary;
  final image = await boundary.toImage();
  final bytes = await image.toByteData();
  final w = image.width;
  final h = image.height;
  final i = ((h ~/ 2) * w + w ~/ 2) * 4;
  final rgba = bytes!.buffer.asUint8List();
  final color = ui.Color.fromARGB(
    rgba[i + 3],
    rgba[i],
    rgba[i + 1],
    rgba[i + 2],
  );
  image.dispose();
  return color;
}

void main() {
  BackdropGrade desaturated() => gradeFromWheels(saturation: 0);

  testWidgets('a neutral grade paints the child unchanged', (tester) async {
    await tester.runAsync(() async {
      final pixel = await _centrePixel(
        tester,
        grade: BackdropGrade.identity,
      );
      expect(pixel.r, closeTo(0.8, 0.02)); // 0xCC
      expect(pixel.g, closeTo(0.133, 0.02)); // 0x22
    });
  });

  testWidgets('an active grade really changes the pixels (saturation 0)', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final pixel = await _centrePixel(tester, grade: desaturated());
      // Rec.709 luma of (0.8, 0.133, 0.133): ~0.28 — a mid grey. All three
      // channels must collapse together (the definition of desaturation).
      expect((pixel.r - pixel.g).abs(), lessThan(0.02));
      expect((pixel.g - pixel.b).abs(), lessThan(0.02));
      expect(pixel.r, closeTo(0.28, 0.06));
    });
  });

  testWidgets('affine whole-frame grades use the composited fast path', (
    tester,
  ) async {
    Widget build(BackdropGrade grade) => Directionality(
      textDirection: TextDirection.ltr,
      child: GradeFilter(
        grade: grade,
        child: const ColoredBox(color: Color(0xFFCC2222)),
      ),
    );

    await tester.pumpWidget(build(gradeFromWheels(saturation: 0.5)));
    final render = tester.renderObject<RenderGradeFilter>(
      find.byType(GradeFilter),
    );
    expect(render.alwaysNeedsCompositing, isTrue);

    await tester.pumpWidget(
      build(gradeFromWheels(gamma: const GradeWheel(master: 0.2))),
    );
    expect(render.alwaysNeedsCompositing, isFalse);
  });

  testWidgets('the premultiplied variant grades and keeps alpha intact', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final pixel = await _centrePixel(
        tester,
        grade: desaturated(),
        premultiplied: true,
      );
      expect(pixel.a, closeTo(1, 0.01));
      expect((pixel.r - pixel.g).abs(), lessThan(0.02));
    });
  });

  testWidgets('snapshot-only grades are bypassed when snapshots are disabled', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final pixel = await _centrePixel(
        tester,
        grade: desaturated(),
        premultiplied: true,
        allowSnapshot: false,
      );
      expect(pixel.r, closeTo(0.8, 0.02));
      expect(pixel.g, closeTo(0.133, 0.02));
    });
  });

  testWidgets('a failed shader load degrades to painting the child', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final pixel = await _centrePixel(
        tester,
        grade: desaturated(),
        loader: () async => throw StateError('no shader for you'),
      );
      // Still the ungraded red — the filter never blocks the frame.
      expect(pixel.r, closeTo(0.8, 0.02));
      expect(pixel.g, closeTo(0.133, 0.02));
    });
  });

  testWidgets('updating grade/tick/ratio marks the render object dirty', (
    tester,
  ) async {
    await tester.runAsync(() async {
      Widget build(BackdropGrade grade, double tick) => MaterialApp(
        home: GradeFilter(
          grade: grade,
          repaintTick: tick,
          child: const ColoredBox(color: Color(0xFF3355AA)),
        ),
      );
      await tester.pumpWidget(build(BackdropGrade.identity, 0));
      await tester.pumpAndSettle();
      final render = tester.renderObject<RenderGradeFilter>(
        find.byType(GradeFilter).first,
      );
      expect(render.grade, BackdropGrade.identity);
      // Grade change re-paints; tick change on an ACTIVE grade re-captures.
      await tester.pumpWidget(build(gradeFromWheels(saturation: 0.5), 1));
      await tester.pump();
      expect(render.grade.saturation, 0.5);
      expect(render.repaintTick, 1);
      await tester.pumpWidget(build(gradeFromWheels(saturation: 0.5), 2));
      await tester.pump();
      expect(render.repaintTick, 2);
      expect(render.program, isNotNull);
      expect(render.pixelRatio, greaterThan(0));
    });
  });

  testWidgets('re-resolves the program variant and the raw view pixel ratio', (
    tester,
  ) async {
    await tester.runAsync(() async {
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetDevicePixelRatio);
      Widget build({required bool premultiplied}) => Directionality(
        textDirection: TextDirection.ltr,
        child: GradeFilter(
          grade: gradeFromWheels(saturation: 0.5),
          premultiplied: premultiplied,
          child: const ColoredBox(color: Color(0xFF224466)),
        ),
      );
      await tester.pumpWidget(build(premultiplied: false));
      await tester.pumpAndSettle();
      final render = tester.renderObject<RenderGradeFilter>(
        find.byType(GradeFilter),
      );
      expect(render.pixelRatio, 2.0);
      final composite = render.program;
      expect(composite, isNotNull);
      // Flipping premultiplied swaps to the per-layer shader variant…
      await tester.pumpWidget(build(premultiplied: true));
      await tester.pumpAndSettle();
      expect(identical(render.program, composite), isFalse);
      // …and a DPR change re-captures at the new scale.
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(build(premultiplied: true));
      await tester.pump();
      expect(render.pixelRatio, 1.0);
    });
  });
}
