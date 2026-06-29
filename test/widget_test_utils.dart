import 'package:flutter/material.dart';

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
