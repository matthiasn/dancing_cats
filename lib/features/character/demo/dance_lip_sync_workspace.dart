/// The lip-sync cue editor (a span-based sibling of the colour-grade
/// workspace): one shared zoomable timeline — ruler with section pills, a
/// cue lane whose blocks you drag to retime and click to reshape — above a
/// shape palette. Purely presentational over a [DanceLipSyncController] +
/// playback state from the page.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:dancing_cats/features/character/demo/dance_grade_workspace.dart'
    show GradeTimelineViewport;
import 'package:dancing_cats/features/character/demo/dance_lip_sync.dart';
import 'package:dancing_cats/features/character/demo/dance_lip_sync_controller.dart';
import 'package:dancing_cats/features/character/demo/dance_transport_bar.dart'
    show DanceWaveformSection, danceSectionHue, formatDancePlaybackTimestamp;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The Rhubarb viseme letters in display order (rest last, as the "off"
/// state).
const List<String> kVisemeOrder = [
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'X',
];

/// A short human label for each viseme, describing the mouth pose (mirrors
/// the commentary in `mouthForCue`, `dance_lip_sync.dart`).
const Map<String, String> kVisemeLabel = {
  'A': 'closed',
  'B': 'slightly open',
  'C': 'open (EH/AE)',
  'D': 'wide open (AA)',
  'E': 'rounded (AO/ER)',
  'F': 'puckered (UW/OW)',
  'G': 'F/V (tight)',
  'H': 'L (tongue up)',
  'X': 'rest',
};

/// A sober, low-chroma colour per viseme (kept out of the workspace's teal
/// accent band so a selected cue's accent outline always reads distinctly).
const Map<String, Color> kVisemeColor = {
  'A': Color(0xFF8893A0), // slate — closed
  'B': Color(0xFF7E97B2), // steel-blue
  'C': Color(0xFFCB8B77), // terracotta
  'D': Color(0xFFC7A86A), // amber
  'E': Color(0xFF9A86BE), // violet
  'F': Color(0xFF7FB293), // sage
  'G': Color(0xFFC089A0), // rose
  'H': Color(0xFF6FA8A0), // muted cyan
  'X': Color(0xFF59626D), // dim grey — rest
};

class DanceLipSyncWorkspace extends StatefulWidget {
  const DanceLipSyncWorkspace({
    required this.controller,
    required this.positionSec,
    required this.durationSec,
    required this.playing,
    required this.onSeek,
    this.sections = const [],
    super.key,
  });

  /// The editing brain (selection, drag, split/merge, undo, the document).
  final DanceLipSyncController controller;

  /// Audio playhead in seconds.
  final double positionSec;

  /// Track length in seconds.
  final double durationSec;

  /// Whether the transport is playing (drives page-flip follow).
  final bool playing;

  /// Seek intent (ruler scrub, click-cue-moves-playhead).
  final ValueChanged<double> onSeek;

  /// Musical sections for the ruler's pills row (shared hues with the
  /// transport and the grade workspace).
  final List<DanceWaveformSection> sections;

  @override
  State<DanceLipSyncWorkspace> createState() => _DanceLipSyncWorkspaceState();
}

class _DanceLipSyncWorkspaceState extends State<DanceLipSyncWorkspace> {
  late GradeTimelineViewport _view = GradeTimelineViewport.fit(
    math.max(1, widget.durationSec),
  );
  bool _follow = true;

  // Boundary-drag session state (lane canvas gestures).
  int? _dragIndex;
  double _dragDx = 0;

  final FocusNode _focus = FocusNode(debugLabel: 'lipSyncWorkspace');

  DanceLipSyncController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onController);
  }

  @override
  void didUpdateWidget(DanceLipSyncWorkspace old) {
    super.didUpdateWidget(old);
    if (old.durationSec != widget.durationSec) {
      _view = GradeTimelineViewport.fit(math.max(1, widget.durationSec));
    }
    // Pressing play re-arms follow; page-flip only outside active drags.
    if (!old.playing && widget.playing) _follow = true;
    if (widget.playing && _follow && _dragIndex == null) {
      final next = _view.followPlayhead(widget.positionSec);
      if (next != _view) setState(() => _view = next);
    }
  }

  void _onController() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _c.removeListener(_onController);
    _focus.dispose();
    super.dispose();
  }

  // ── input plumbing ───────────────────────────────────────────────────────

  bool get _alt => HardwareKeyboard.instance.isAltPressed;
  bool get _ctrl => HardwareKeyboard.instance.isControlPressed;
  bool get _shift => HardwareKeyboard.instance.isShiftPressed;

  void _zoom(double focusT, double factor) {
    setState(() {
      _view = _view.zoomAt(focusT, factor);
      _follow = false;
    });
  }

  void _pan(double deltaSec) {
    setState(() {
      _view = _view.panBy(deltaSec);
      _follow = false;
    });
  }

  void _onScroll(PointerScrollEvent event, double width) {
    final t = _view.tFor(event.localPosition.dx, width);
    if (_ctrl) {
      _zoom(t, event.scrollDelta.dy < 0 ? 1.25 : 1 / 1.25);
    } else {
      // Plain/shift scroll pans; trackpads pan via their horizontal axis.
      final raw = event.scrollDelta.dx.abs() > event.scrollDelta.dy.abs()
          ? event.scrollDelta.dx
          : event.scrollDelta.dy;
      _pan(raw / width * _view.visibleSec);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      _c.mergeSelected();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _c.clearSelection();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      // Nudges the boundary trailing the selected cue (shrinks/grows it);
      // a no-op on the last cue, which has no trailing boundary.
      final sel = _c.selectedIndex;
      if (sel != null) {
        final dir = key == LogicalKeyboardKey.arrowRight ? 1 : -1;
        _c.nudgeBoundary(sel, dir, fineSec: _shift ? 0.01 : null);
      }
      return KeyEventResult.handled;
    }
    if (_ctrl && key == LogicalKeyboardKey.keyZ) {
      _shift ? _c.redo() : _c.undo();
      return KeyEventResult.handled;
    }
    if (_ctrl && key == LogicalKeyboardKey.keyY) {
      _c.redo();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored; // Space etc. bubble to the page
  }

  // ── lane gestures ────────────────────────────────────────────────────────

  int? _hitBoundary(List<DanceCue> cues, double x, double width) {
    const grabPx = 8.0;
    int? best;
    var bestDist = grabPx;
    for (var i = 0; i < cues.length - 1; i++) {
      final d = (_view.xFor(cues[i].end, width) - x).abs();
      if (d <= bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  int? _cueAt(List<DanceCue> cues, double x, double width) {
    final t = _view.tFor(x, width);
    for (var i = 0; i < cues.length; i++) {
      if (t >= cues[i].start && t < cues[i].end) return i;
    }
    return null;
  }

  void _laneTapUp(TapUpDetails d, double width) {
    _focus.requestFocus();
    final cues = _c.cues;
    if (_hitBoundary(cues, d.localPosition.dx, width) != null) {
      return; // boundary taps are handled by the drag gesture
    }
    final i = _cueAt(cues, d.localPosition.dx, width);
    _c.selectCue(i);
    // Edit target and displayed frame always coincide.
    if (i != null) widget.onSeek(cues[i].start);
  }

  void _laneDoubleTapDown(TapDownDetails d, double width) {
    _c.splitSelectedAt(_view.tFor(d.localPosition.dx, width));
  }

  void _laneDragStart(DragStartDetails d, double width) {
    // Hit-test at the PRESS position, not the post-slop drag-accept position
    // — otherwise every boundary grab misses by the touch slop.
    final hit = _hitBoundary(_c.cues, d.localPosition.dx, width);
    if (hit != null) {
      _dragIndex = hit;
      _dragDx = 0;
      _c.beginBoundaryDrag(hit);
    } else {
      _dragIndex = null; // empty-lane drag pans the shared axis
      _follow = false;
    }
  }

  void _laneDragUpdate(DragUpdateDetails d, double width) {
    if (_dragIndex != null) {
      _dragDx += d.delta.dx;
      _c.updateBoundaryDrag(_dragDx / width * _view.visibleSec, snap: !_alt);
    } else {
      _pan(-d.delta.dx / width * _view.visibleSec);
    }
  }

  void _laneDragEnd() {
    if (_dragIndex != null) _c.endBoundaryDrag();
    _dragIndex = null;
  }

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: 'Inter'),
        child: DecoratedBox(
          key: const Key('lipSyncWorkspace'),
          decoration: const BoxDecoration(
            color: _Ls.panel,
            border: Border(top: BorderSide(color: _Ls.edge)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = math
                  .max(1, constraints.maxWidth - _Ls.headerW)
                  .toDouble();
              return Listener(
                onPointerSignal: (e) {
                  if (e is PointerScrollEvent) _onScroll(e, width);
                },
                child: Column(
                  children: [
                    _toolbar(),
                    _row(
                      height: 14,
                      header: const SizedBox.shrink(),
                      child: _overview(width),
                    ),
                    _row(
                      height: 24,
                      header: _headerLabel('TIME'),
                      child: _ruler(width),
                    ),
                    Expanded(
                      child: _filledRow(
                        header: _headerLabel('CUES'),
                        child: _laneCanvas(width),
                      ),
                    ),
                    const Divider(height: 1, color: _Ls.edge),
                    _shapePalette(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _row({
    required double height,
    required Widget header,
    required Widget child,
  }) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          SizedBox(width: _Ls.headerW, child: header),
          Expanded(child: ClipRect(child: child)),
        ],
      ),
    );
  }

  Widget _filledRow({required Widget header, required Widget child}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: _Ls.headerW, child: header),
        Expanded(child: ClipRect(child: child)),
      ],
    );
  }

  Widget _headerLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 12),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          color: _Ls.textLow,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    ),
  );

  // ── toolbar ──────────────────────────────────────────────────────────────

  Widget _toolbar() {
    return SizedBox(
      height: 32,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            _toolToggle(
              key: const Key('lipSyncSnap'),
              label: 'SNAP',
              icon: Icons.straighten_rounded,
              active: _c.snapEnabled,
              tooltip:
                  'Snap boundaries to beats and half-beats '
                  '(Alt bypasses while dragging)',
              onTap: () => setState(() => _c.snapEnabled = !_c.snapEnabled),
            ),
            const SizedBox(width: 6),
            _toolButton(
              key: const Key('lipSyncFit'),
              label: 'FIT',
              icon: Icons.fit_screen_rounded,
              tooltip: 'Fit the whole track (Ctrl+scroll zooms)',
              onTap: () => setState(() {
                _view = GradeTimelineViewport.fit(
                  math.max(1, widget.durationSec),
                );
                _follow = true;
              }),
            ),
            const SizedBox(width: 14),
            _toolButton(
              key: const Key('lipSyncUndo'),
              label: 'UNDO',
              icon: Icons.undo_rounded,
              enabled: _c.canUndo,
              tooltip: 'Undo (Ctrl+Z)',
              onTap: _c.undo,
            ),
            const SizedBox(width: 6),
            _toolButton(
              key: const Key('lipSyncRedo'),
              label: 'REDO',
              icon: Icons.redo_rounded,
              enabled: _c.canRedo,
              tooltip: 'Redo (Ctrl+Shift+Z)',
              onTap: _c.redo,
            ),
            if (_c.store.fileUnreadable) ...[
              const SizedBox(width: 14),
              Tooltip(
                message:
                    'The cues file on disk does not parse — showing the last '
                    'good document. Autosave is paused; fix the file or '
                    'force-save.',
                child: InkWell(
                  key: const Key('lipSyncFileError'),
                  onTap: () => unawaited(_c.store.saveNow()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _Ls.error.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _Ls.error),
                    ),
                    child: const Text(
                      'FILE UNREADABLE — TAP TO FORCE-SAVE',
                      style: TextStyle(
                        color: _Ls.error,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const Spacer(),
            if (_c.selectedIndex != null)
              Text(
                _selectionLabel(),
                key: const Key('lipSyncSelectionLabel'),
                style: const TextStyle(color: _Ls.accent, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }

  String _selectionLabel() {
    final i = _c.selectedIndex;
    final cues = _c.cues;
    if (i == null || i < 0 || i >= cues.length) return '';
    final c = cues[i];
    return '${kVisemeLabel[c.shape] ?? c.shape} · '
        '${formatDancePlaybackTimestamp(c.start)} – '
        '${formatDancePlaybackTimestamp(c.end)}';
  }

  Widget _toolToggle({
    required String label,
    required IconData icon,
    required bool active,
    required String tooltip,
    required VoidCallback onTap,
    Key? key,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: active ? _Ls.accent.withValues(alpha: 0.16) : null,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: active ? _Ls.accent : _Ls.edge),
          ),
          child: Row(
            children: [
              Icon(icon, size: 11, color: active ? _Ls.accent : _Ls.textLow),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: active ? _Ls.textHi : _Ls.textLow,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolButton({
    required String label,
    required IconData? icon,
    required String tooltip,
    required VoidCallback onTap,
    bool enabled = true,
    Key? key,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: key,
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _Ls.edge),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 11, color: enabled ? _Ls.textMid : _Ls.edge),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  color: enabled ? _Ls.textMid : _Ls.edge,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── ruler / lane / palette ───────────────────────────────────────────────

  Widget _overview(double width) {
    return GestureDetector(
      key: const Key('lipSyncOverview'),
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => setState(() {
        _view = _view.centreOn(
          d.localPosition.dx / width * widget.durationSec,
        );
        _follow = false;
      }),
      onHorizontalDragUpdate: (d) => setState(() {
        _view = _view.centreOn(
          d.localPosition.dx / width * widget.durationSec,
        );
        _follow = false;
      }),
      child: CustomPaint(
        size: Size(width, 14),
        painter: _OverviewPainter(
          cues: _c.cues,
          durationSec: widget.durationSec,
          view: _view,
          positionSec: widget.positionSec,
        ),
      ),
    );
  }

  Widget _ruler(double width) {
    return GestureDetector(
      key: const Key('lipSyncRuler'),
      behavior: HitTestBehavior.opaque,
      // Ruler drag SCRUBS the playhead — twenty years of muscle memory.
      onTapDown: (d) => widget.onSeek(_view.tFor(d.localPosition.dx, width)),
      onHorizontalDragUpdate: (d) =>
          widget.onSeek(_view.tFor(d.localPosition.dx, width)),
      child: CustomPaint(
        size: Size(width, 24),
        painter: _RulerPainter(
          view: _view,
          sections: widget.sections,
          positionSec: widget.positionSec,
        ),
      ),
    );
  }

  Widget _laneCanvas(double width) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        return GestureDetector(
          key: const Key('lipSyncLane'),
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onTapUp: (d) => _laneTapUp(d, width),
          onDoubleTapDown: (d) => _laneDoubleTapDown(d, width),
          onHorizontalDragStart: (d) => _laneDragStart(d, width),
          onHorizontalDragUpdate: (d) => _laneDragUpdate(d, width),
          onHorizontalDragEnd: (_) => _laneDragEnd(),
          onHorizontalDragCancel: _laneDragEnd,
          child: CustomPaint(
            size: Size(width, height),
            painter: _CueLanePainter(
              cues: _c.cues,
              view: _view,
              positionSec: widget.positionSec,
              selectedIndex: _c.selectedIndex,
            ),
          ),
        );
      },
    );
  }

  Widget _shapePalette() {
    final sel = _c.selectedIndex;
    final cues = _c.cues;
    final activeShape = sel != null && sel < cues.length
        ? cues[sel].shape
        : null;
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            const Text(
              'SHAPE',
              style: TextStyle(
                color: _Ls.textLow,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 10),
            for (final letter in kVisemeOrder) ...[
              _shapeSwatch(
                letter,
                enabled: sel != null,
                active: letter == activeShape,
              ),
              const SizedBox(width: 4),
            ],
          ],
        ),
      ),
    );
  }

  Widget _shapeSwatch(
    String letter, {
    required bool enabled,
    required bool active,
  }) {
    final color = kVisemeColor[letter] ?? _Ls.textLow;
    return Tooltip(
      message: kVisemeLabel[letter] ?? letter,
      child: InkWell(
        key: Key('lipSyncShape-$letter'),
        onTap: enabled ? () => _c.setShape(_c.selectedIndex!, letter) : null,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(
              alpha: enabled ? (active ? 0.9 : 0.35) : 0.12,
            ),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: active ? _Ls.accent : _Ls.edge,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Text(
            letter,
            style: TextStyle(
              color: enabled ? const Color(0xFF0B0E12) : _Ls.edge,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

// ── painters ─────────────────────────────────────────────────────────────

/// Time labels + section pills, in viewport space. A small local duplicate of
/// the grade workspace's ruler painter (that one is file-private); the
/// tick-drawing logic is short enough that duplicating it is lower risk than
/// refactoring the shipped grade console to share it.
class _RulerPainter extends CustomPainter {
  _RulerPainter({
    required this.view,
    required this.sections,
    required this.positionSec,
  });

  final GradeTimelineViewport view;
  final List<DanceWaveformSection> sections;
  final double positionSec;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF11151A),
    );
    final interval = _niceInterval(view.visibleSec);
    final first = (view.startSec / interval).floor() * interval;
    final tick = Paint()..color = const Color(0x33FFFFFF);
    for (var t = first; t <= view.startSec + view.visibleSec; t += interval) {
      if (t < 0) continue;
      final x = view.xFor(t, size.width);
      canvas.drawRect(Rect.fromLTWH(x, size.height - 5, 1, 5), tick);
      TextPainter(
          text: TextSpan(
            text: _mmss(t),
            style: const TextStyle(
              fontFamily: 'Inter',
              color: _Ls.textMid,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          textDirection: TextDirection.ltr,
        )
        ..layout()
        ..paint(canvas, Offset(x + 3, 1));
    }
    for (final s in sections) {
      final x0 = view.xFor(s.start, size.width);
      if (x0 > size.width || view.xFor(s.end, size.width) < 0) continue;
      final active = positionSec >= s.start && positionSec < s.end;
      final hue = danceSectionHue(s.label);
      canvas.drawRect(
        Rect.fromLTWH(x0, size.height - 3, 3, 3),
        Paint()..color = hue,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: s.label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Inter',
            color: active ? hue : _Ls.textLow,
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x0 + 5, size.height - tp.height - 1));
    }
    _paintPlayhead(canvas, size, view, positionSec, flag: true);
  }

  static double _niceInterval(double visible) {
    const candidates = <double>[0.5, 1, 2, 5, 10, 15, 20, 30, 60, 120, 300];
    for (final c in candidates) {
      if (visible / c <= 9) return c;
    }
    return 300;
  }

  static String _mmss(double s) {
    final t = s.floor();
    final m = t ~/ 60;
    final ss = (t % 60).toString().padLeft(2, '0');
    final frac = s - t;
    return frac > 0.01 ? '$m:$ss.${(frac * 10).round()}' : '$m:$ss';
  }

  @override
  bool shouldRepaint(_RulerPainter old) =>
      old.view != view ||
      old.positionSec != positionSec ||
      !identical(old.sections, sections);
}

/// Whole-track minimap: every cue condensed into its viseme colour, with the
/// visible-window brush on top — a DAW-style "you are here" so zooming into
/// a readable segment never loses the rest of the track.
class _OverviewPainter extends CustomPainter {
  _OverviewPainter({
    required this.cues,
    required this.durationSec,
    required this.view,
    required this.positionSec,
  });

  final List<DanceCue> cues;
  final double durationSec;
  final GradeTimelineViewport view;
  final double positionSec;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0B0E12),
    );
    if (durationSec > 0) {
      for (final c in cues) {
        final x0 = (c.start / durationSec * size.width).clamp(0, size.width);
        final x1 = (c.end / durationSec * size.width).clamp(0, size.width);
        if (x1 <= x0) continue;
        canvas.drawRect(
          Rect.fromLTWH(x0.toDouble(), 0, (x1 - x0).toDouble(), size.height),
          Paint()
            ..color = (kVisemeColor[c.shape] ?? _Ls.textLow).withValues(
              alpha: 0.55,
            ),
        );
      }
      // The brush: the visible window — a bold "you are here" box, not a
      // faint tint, since this is glanced at while watching the stage.
      final left = view.startSec / durationSec * size.width;
      final w = view.visibleSec / durationSec * size.width;
      canvas
        ..drawRect(
          Rect.fromLTWH(left, 0, w, size.height),
          Paint()..color = _Ls.accent.withValues(alpha: 0.32),
        )
        ..drawRect(
          Rect.fromLTWH(left, 0, w, size.height),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = _Ls.accent.withValues(alpha: 0.95),
        )
        // Grab handles at both edges of the brush — solid regardless of how
        // wide the window is, so it always reads as a draggable scrubber,
        // not just a border that vanishes when the window spans the strip.
        ..drawRect(
          Rect.fromLTWH(left - 1, 0, 2.5, size.height),
          Paint()..color = _Ls.accent,
        )
        ..drawRect(
          Rect.fromLTWH(left + w - 1.5, 0, 2.5, size.height),
          Paint()..color = _Ls.accent,
        )
        ..drawRect(
          Rect.fromLTWH(
            positionSec / durationSec * size.width,
            0,
            1.5,
            size.height,
          ),
          Paint()..color = _Ls.accent,
        );
    }
  }

  @override
  bool shouldRepaint(_OverviewPainter old) =>
      old.view != view ||
      old.positionSec != positionSec ||
      !identical(old.cues, cues);
}

/// One block per cue, coloured by viseme, with a seam at every boundary and
/// an accent outline on the selected cue.
class _CueLanePainter extends CustomPainter {
  _CueLanePainter({
    required this.cues,
    required this.view,
    required this.positionSec,
    required this.selectedIndex,
  });

  final List<DanceCue> cues;
  final GradeTimelineViewport view;
  final double positionSec;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0B0E12),
    );
    for (var i = 0; i < cues.length; i++) {
      final c = cues[i];
      final x0 = view.xFor(c.start, size.width);
      final x1 = view.xFor(c.end, size.width);
      if (x1 < 0 || x0 > size.width) continue;
      final left = math.max(0, x0).toDouble();
      final right = math.min(size.width, x1);
      if (right <= left) continue;
      final selected = i == selectedIndex;
      final color = kVisemeColor[c.shape] ?? _Ls.textLow;
      // Below ~6px the 1px inset + 4px vertical margin would swallow the
      // whole block (negative width) — a song's-worth of Rhubarb cues at
      // FIT zoom are routinely sub-pixel, so fill edge-to-edge with no
      // inset there instead of vanishing into the background.
      final raw = right - left;
      final rect = raw > 6
          ? Rect.fromLTWH(left + 1, 4, raw - 2, size.height - 8)
          : Rect.fromLTWH(left, 0, math.max(0.6, raw), size.height);
      final rrect = RRect.fromRectAndRadius(
        rect,
        raw > 6 ? const Radius.circular(3) : Radius.zero,
      );
      canvas.drawRRect(
        rrect,
        Paint()..color = color.withValues(alpha: selected ? 0.92 : 0.85),
      );
      if (selected) {
        canvas.drawRRect(
          rrect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = _Ls.accent,
        );
      }
      if (rect.width > 14) {
        final tp = TextPainter(
          text: TextSpan(
            text: c.shape,
            style: const TextStyle(
              fontFamily: 'Inter',
              color: Color(0xFF0B0E12),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(
            rect.left + (rect.width - tp.width) / 2,
            rect.top + (rect.height - tp.height) / 2,
          ),
        );
      }
      // At high density a seam every couple of pixels reads as a grid
      // lattice that drowns out the fill colour entirely — only draw it
      // once cues are wide enough for a seam to read as a boundary rather
      // than as the dominant texture.
      if (i > 0 && raw > 6) {
        canvas.drawRect(
          Rect.fromLTWH(x0 - 0.75, 0, 1.5, size.height),
          Paint()..color = const Color(0x33000000),
        );
      }
    }
    _paintPlayhead(canvas, size, view, positionSec);
  }

  @override
  bool shouldRepaint(_CueLanePainter old) =>
      old.view != view ||
      old.positionSec != positionSec ||
      old.selectedIndex != selectedIndex ||
      !identical(old.cues, cues);
}

void _paintPlayhead(
  Canvas canvas,
  Size size,
  GradeTimelineViewport view,
  double positionSec, {
  bool flag = false,
}) {
  final x = view.xFor(positionSec, size.width);
  if (x < -2 || x > size.width + 2) return;
  canvas.drawRect(
    Rect.fromLTWH(x - 0.75, 0, 1.5, size.height),
    Paint()..color = _Ls.accent,
  );
  if (flag) {
    final path = Path()
      ..moveTo(x - 5, 0)
      ..lineTo(x + 5, 0)
      ..lineTo(x + 5, 5)
      ..lineTo(x, 8)
      ..lineTo(x - 5, 5)
      ..close();
    canvas.drawPath(path, Paint()..color = _Ls.accent);
  }
}

/// Self-contained dark palette for the workspace chrome (demo-only values,
/// matching the transport's/grade workspace's console language).
abstract final class _Ls {
  static const Color panel = Color(0xFF121417);
  static const Color edge = Color(0x1FFFFFFF);
  static const Color accent = Color(0xFF4DD6C0);
  static const Color error = Color(0xFFE0483B);
  static const Color textHi = Color(0xFFEDF1F5);
  static const Color textMid = Color(0xFF8A96A3);
  static const Color textLow = Color(0xFF59626D);
  static const double headerW = 60;
}
