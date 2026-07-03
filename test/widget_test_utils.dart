import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal testable-widget wrapper for the standalone dancing-cats repo.
///
/// The character/scenery widgets have no Riverpod, localization, or theme
/// dependencies, so this only provides a [MediaQuery] + [MaterialApp] host —
/// enough to pump a widget and exercise layout, painting and tap callbacks.
Widget makeTestableWidgetNoScroll(
  Widget child, {
  MediaQueryData? mediaQueryData,
  ThemeData? theme,
}) {
  return MediaQuery(
    data: mediaQueryData ?? const MediaQueryData(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: child,
    ),
  );
}

/// Pins the test surface to [size] at a 1:1 device pixel ratio (so painted
/// pixel offsets in assertions match logical coordinates exactly), and
/// registers the matching `addTearDown` resets — the fixed-size-canvas setup
/// several of the demo workspace/panel widget tests otherwise each
/// hand-rolled identically.
void setTestViewSize(WidgetTester tester, Size size) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
