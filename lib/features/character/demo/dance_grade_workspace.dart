import 'dart:async';
import 'dart:math' as math;

import 'package:dancing_cats/features/character/demo/color_grade_panel.dart';
import 'package:dancing_cats/features/character/demo/dance_grade_controller.dart';
import 'package:dancing_cats/features/character/demo/dance_grade_store.dart';
import 'package:dancing_cats/features/character/demo/dance_transport_bar.dart';
import 'package:dancing_cats/features/scenery/model/backdrop_scene.dart';
import 'package:dancing_cats/features/scenery/model/grade_timeline.dart';
import 'package:dancing_cats/features/scenery/model/scope_histogram.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The zoom/pan state of the workspace's one shared x-axis: every row (ruler,
/// waveform, beats, grade lanes, overview brush) maps time↔pixels through the
/// same instance, so zooming zooms everything together. Pure math — unit
/// tested without widgets.
@immutable
class GradeTimelineViewport {
  const GradeTimelineViewport({
    required this.durationSec,
    required this.startSec,
    required this.visibleSec,
  });

  /// The whole track fits the width (the FIT state).
  factory GradeTimelineViewport.fit(double durationSec) =>
      GradeTimelineViewport(
        durationSec: durationSec,
        startSec: 0,
        visibleSec: durationSec,
      );

  /// Track length in seconds.
  final double durationSec;

  /// Left edge of the visible window.
  final double startSec;

  /// Width of the visible window in seconds.
  final double visibleSec;

  /// Narrowest allowed window (a keyframe stays grabbable at extreme zoom).
  static const double minVisibleSec = 1.5;

  /// Time → x for a row of [width] pixels.
  double xFor(double tSec, double width) =>
      (tSec - startSec) / visibleSec * width;

  /// x → time for a row of [width] pixels.
  double tFor(double x, double width) => startSec + x / width * visibleSec;

  /// Whether [tSec] is inside the window.
  bool contains(double tSec) =>
      tSec >= startSec && tSec <= startSec + visibleSec;

  /// Zooms by [factor] (>1 zooms in) keeping [focusTSec] pinned under the
  /// cursor — the only zoom behaviour that doesn't make the timeline swim.
  GradeTimelineViewport zoomAt(double focusTSec, double factor) {
    final newVisible = (visibleSec / factor).clamp(minVisibleSec, durationSec);
    final u = ((focusTSec - startSec) / visibleSec).clamp(0.0, 1.0);
    return GradeTimelineViewport(
      durationSec: durationSec,
      startSec: focusTSec - u * newVisible,
      visibleSec: newVisible,
    ).clamped();
  }

  /// Pans by [deltaSec] (positive → later).
  GradeTimelineViewport panBy(double deltaSec) => GradeTimelineViewport(
    durationSec: durationSec,
    startSec: startSec + deltaSec,
    visibleSec: visibleSec,
  ).clamped();

  /// Centres the window on [tSec] (the overview brush drag).
  GradeTimelineViewport centreOn(double tSec) => GradeTimelineViewport(
    durationSec: durationSec,
    startSec: tSec - visibleSec / 2,
    visibleSec: visibleSec,
  ).clamped();

  /// Page-flip follow: when the playhead runs past the right margin the view
  /// jumps so the playhead re-enters near the left edge (never a continuous
  /// scroll that yanks the surface mid-drag).
  GradeTimelineViewport followPlayhead(double tSec) {
    if (tSec >= startSec && tSec <= startSec + visibleSec * 0.95) return this;
    return GradeTimelineViewport(
      durationSec: durationSec,
      startSec: tSec - visibleSec * 0.05,
      visibleSec: visibleSec,
    ).clamped();
  }

  /// Clamps the window inside the track.
  GradeTimelineViewport clamped() {
    final v = math.min(
      math.max(visibleSec, minVisibleSec),
      math.max(minVisibleSec, durationSec),
    );
    final maxStart = math.max(0, durationSec - v).toDouble();
    return GradeTimelineViewport(
      durationSec: durationSec,
      startSec: math.min(math.max(startSec, 0), maxStart),
      visibleSec: v,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GradeTimelineViewport &&
      other.durationSec == durationSec &&
      other.startSec == startSec &&
      other.visibleSec == visibleSec;

  @override
  int get hashCode => Object.hash(durationSec, startSec, visibleSec);
}

/// The expanded colour-grading workspace (ADR 0002 §6): one shared zoomable
/// timeline — overview brush, scrubbing ruler + section pills, waveform,
/// detected-beat lane, grade lanes with keyframe diamonds + deviation
/// sparklines — above the enlarged console. Purely presentational over a
/// [DanceGradeController] + playback state from the page.
class DanceGradeWorkspace extends StatefulWidget {
  const DanceGradeWorkspace({
    required this.controller,
    required this.positionSec,
    required this.durationSec,
    required this.playing,
    required this.amplitudes,
    required this.sections,
    required this.parade,
    required this.bypass,
    required this.onBypass,
    required this.onSeek,
    this.showScopes = true,
    super.key,
  });

  /// The editing brain (selection, auto-key, undo, the document).
  final DanceGradeController controller;

  /// Audio playhead in seconds.
  final double positionSec;

  /// Track length in seconds.
  final double durationSec;

  /// Whether the transport is playing (drives touch-trail recording and
  /// page-flip follow).
  final bool playing;

  /// Full-track waveform, normalized 0..1.
  final List<double> amplitudes;

  /// Musical sections for the pills row (shared hues with the transport).
  final List<DanceWaveformSection> sections;

  /// The image-derived RGB parade for the console scopes.
  final ScopeHistogram parade;

  /// Whether the stage shows the clean plate (grade bypassed).
  final bool bypass;

  /// Bypass toggle intent.
  final ValueChanged<bool> onBypass;

  /// Seek intent (ruler scrub, waveform tap, click-key-moves-playhead).
  final ValueChanged<double> onSeek;

  /// False when the page docks full-size scopes into the stage pillarbox —
  /// the console then drops its small duplicates.
  final bool showScopes;

  @override
  State<DanceGradeWorkspace> createState() => _DanceGradeWorkspaceState();
}

class _DanceGradeWorkspaceState extends State<DanceGradeWorkspace> {
  late GradeTimelineViewport _view = GradeTimelineViewport.fit(
    math.max(1, widget.durationSec),
  );
  bool _follow = true;

  // Key-drag session state (lane canvas gestures).
  String? _dragTarget;
  double? _dragAnchorT;
  double _dragDx = 0;

  // Transient note ("keyed @ …", "reloaded from disk").
  String? _note;
  Timer? _noteTimer;
  int _seenEditNoteSerial = 0;
  int _seenStoreSerial = 0;

  final FocusNode _focus = FocusNode(debugLabel: 'gradeWorkspace');

  DanceGradeController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _seenEditNoteSerial = _c.editNoteSerial;
    _seenStoreSerial = _c.store.eventSerial;
    _c.addListener(_onController);
  }

  @override
  void didUpdateWidget(DanceGradeWorkspace old) {
    super.didUpdateWidget(old);
    if (old.durationSec != widget.durationSec) {
      _view = GradeTimelineViewport.fit(math.max(1, widget.durationSec));
    }
    // Pressing play re-arms follow; page-flip only outside active drags.
    if (!old.playing && widget.playing) _follow = true;
    if (widget.playing && _follow && _dragTarget == null) {
      final next = _view.followPlayhead(widget.positionSec);
      if (next != _view) setState(() => _view = next);
    }
  }

  void _onController() {
    if (!mounted) return;
    if (_c.editNoteSerial != _seenEditNoteSerial) {
      _seenEditNoteSerial = _c.editNoteSerial;
      final t = _c.lastStampTSec;
      final n = _c.lastTrailCount;
      _showNote(
        t != null
            ? 'keyed @ ${formatDancePlaybackTimestamp(t)}'
            : 'automation trail: $n keys',
      );
    }
    if (_c.store.eventSerial != _seenStoreSerial) {
      _seenStoreSerial = _c.store.eventSerial;
      switch (_c.store.lastEvent) {
        case DanceGradeStoreEvent.externalReload:
          _showNote('reloaded from disk (Ctrl+Z reverts)');
        case DanceGradeStoreEvent.externalChangeOverwritten:
          _showNote('external change overwritten (last writer wins)');
        case DanceGradeStoreEvent.none:
        case DanceGradeStoreEvent.loaded:
        case DanceGradeStoreEvent.saved:
        case DanceGradeStoreEvent.fileError:
          break; // fileError shows as a persistent chip, not a note
      }
    }
    setState(() {});
  }

  void _showNote(String note) {
    _noteTimer?.cancel();
    _note = note;
    _noteTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _note = null);
    });
  }

  @override
  void dispose() {
    _noteTimer?.cancel();
    _c.removeListener(_onController);
    _focus.dispose();
    super.dispose();
  }

  // ── input plumbing ───────────────────────────────────────────────────────

  bool get _shift => HardwareKeyboard.instance.isShiftPressed;
  bool get _alt => HardwareKeyboard.instance.isAltPressed;
  bool get _ctrl => HardwareKeyboard.instance.isControlPressed;

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
      _c.deleteSelected();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _c
        ..discardPreview()
        ..clearKeySelection();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      final dir = key == LogicalKeyboardKey.arrowRight ? 1 : -1;
      _c.nudgeSelected(dir, fineSec: _shift ? 0.01 : null);
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

  double? _hitKey(GradeLane lane, double x, double width) {
    const grabPx = 8.0;
    double? best;
    var bestDist = grabPx;
    for (final k in lane.keyframes) {
      final d = (_view.xFor(k.tSec, width) - x).abs();
      if (d <= bestDist) {
        bestDist = d;
        best = k.tSec;
      }
    }
    return best;
  }

  void _laneTap(GradeLane lane, double x, double width) {
    _focus.requestFocus();
    final hit = _hitKey(lane, x, width);
    if (hit != null) {
      _c.selectKey(lane.target, hit, extend: _shift);
      // Edit target and displayed frame always coincide (ADR 0002 §4).
      if (!_shift) widget.onSeek(hit);
    } else {
      _c
        ..selectLane(lane.target)
        ..clearKeySelection();
    }
  }

  Future<void> _laneContextMenu(
    GradeLane lane,
    double x,
    double width,
    Offset globalPos,
  ) async {
    _focus.requestFocus();
    final hit = _hitKey(lane, x, width);
    final t = hit ?? _view.tFor(x, width);
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      globalPos & const Size(1, 1),
      Offset.zero & overlay.size,
    );
    final lanei = _c.doc(lane.target);
    final interp = lanei == null || hit == null
        ? null
        : lanei.keyframes[lanei.indexNear(hit)!].interp;
    final action = await showMenu<String>(
      context: context,
      position: position,
      color: _Ws.menu,
      items: [
        if (hit != null) ...[
          const PopupMenuItem(value: 'copy', child: Text('Copy look')),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            enabled: false,
            height: 26,
            child: Text(
              'CURVE',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: _Ws.textLow,
              ),
            ),
          ),
          for (final i in GradeInterp.values)
            PopupMenuItem(
              value: 'interp:${i.name}',
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    child: i == interp
                        ? const Icon(Icons.check, size: 14)
                        : null,
                  ),
                  Text(_interpLabel(i)),
                ],
              ),
            ),
        ] else ...[
          const PopupMenuItem(value: 'add', child: Text('Add key here')),
        ],
        // Always present so the copy→paste workflow is discoverable; armed
        // only once a look has been copied, with the recovery path named.
        PopupMenuItem(
          value: 'paste',
          enabled: _c.clipboard != null,
          child: Text(
            _c.clipboard == null
                ? 'Paste look (copy a look first)'
                : hit != null
                ? 'Paste look onto key'
                : 'Paste look as new key here',
          ),
        ),
        // Destructive action LAST, never the item under the cursor.
        if (hit != null) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'remove', child: Text('Remove key')),
        ],
      ],
    );
    switch (action) {
      case 'remove':
        _c.deleteKey(lane.target, t);
      case 'copy':
        _c.copyLook(lane.target, t);
      case 'add':
        _c.addKeyAt(lane.target, t);
      case 'paste':
        _c.pasteLook(lane.target, t);
      case final String a when a.startsWith('interp:'):
        _c.setInterp(
          lane.target,
          t,
          GradeInterp.fromName(a.substring('interp:'.length)),
        );
      case _:
        break;
    }
  }

  static String _interpLabel(GradeInterp i) => switch (i) {
    GradeInterp.hold => 'Hold (cut)',
    GradeInterp.linear => 'Linear',
    GradeInterp.smooth => 'Smooth',
    GradeInterp.easeIn => 'Ease in',
    GradeInterp.easeOut => 'Ease out',
  };

  void _laneDragStart(GradeLane lane, double x, double width) {
    final hit = _hitKey(lane, x, width);
    if (hit != null) {
      _dragTarget = lane.target;
      _dragAnchorT = hit;
      _dragDx = 0;
      _c.beginKeyDrag(lane.target, hit);
    } else {
      _dragTarget = null; // empty-lane drag pans the shared axis
      _follow = false;
    }
  }

  void _laneDragUpdate(DragUpdateDetails d, double width) {
    if (_dragTarget != null) {
      _dragDx += d.delta.dx;
      _c.updateKeyDrag(
        _dragDx / width * _view.visibleSec,
        anchorTSec: _dragAnchorT!,
        snap: !_alt,
      );
    } else {
      _pan(-d.delta.dx / width * _view.visibleSec);
    }
  }

  void _laneDragEnd() {
    if (_dragTarget != null) _c.endKeyDrag();
    _dragTarget = null;
    _dragAnchorT = null;
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
          key: const Key('gradeWorkspace'),
          decoration: const BoxDecoration(
            color: _Ws.panel,
            border: Border(top: BorderSide(color: _Ws.edge)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = math
                  .max(1, constraints.maxWidth - _Ws.headerW)
                  .toDouble();
              return Listener(
                onPointerSignal: (e) {
                  if (e is PointerScrollEvent) {
                    _onScroll(e, width);
                  }
                },
                child: Column(
                  children: [
                    _toolbar(),
                    ..._timelineRows(width),
                    // The lane stack takes whatever height remains and
                    // scrolls internally — the console can NEVER be pushed
                    // off the bottom by adding lanes.
                    Expanded(child: _lanesArea(width)),
                    const Divider(height: 1, color: _Ws.edge),
                    _console(compact: constraints.maxHeight < 470),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // The stacked, shared-axis rows. Every row is [header | canvas(width)].
  List<Widget> _timelineRows(double width) => [
    _row(height: 14, header: const SizedBox.shrink(), child: _overview(width)),
    _row(height: 24, header: _headerLabel('TIME'), child: _ruler(width)),
    _row(height: 36, header: _headerLabel('WAVE'), child: _waveform(width)),
    _row(height: 16, header: _headerLabel('BEATS'), child: _beats(width)),
  ];

  Widget _lanesArea(double width) {
    final lanes = _c.displayLanes;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final lane in lanes)
            _row(
              height: _Ws.laneH,
              header: _laneHeader(lane),
              child: _laneCanvas(lane, width),
            ),
        ],
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
          SizedBox(width: _Ws.headerW, child: header),
          // Every row clips to the shared content viewport — zoomed/panned
          // ruler labels and beat ticks must never bleed into the header
          // gutter (the one discipline a shared axis cannot break).
          Expanded(child: ClipRect(child: child)),
        ],
      ),
    );
  }

  Widget _headerLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 12),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          color: _Ws.textLow,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    ),
  );

  // ── toolbar ──────────────────────────────────────────────────────────────

  Widget _toolbar() {
    final hasPreview = _c.preview != null;
    return SizedBox(
      height: 32,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            _toolToggle(
              key: const Key('gradeAutoKey'),
              label: 'AUTO KEY',
              icon: Icons.fiber_manual_record_rounded,
              active: _c.autoKey,
              tooltip: _c.autoKey
                  ? 'Releasing a control writes a keyframe at the playhead'
                  : 'Edits preview only — ● KEY commits, Esc discards',
              onTap: () => setState(() => _c.autoKey = !_c.autoKey),
            ),
            const SizedBox(width: 6),
            _toolToggle(
              key: const Key('gradeSnap'),
              label: 'SNAP',
              icon: Icons.straighten_rounded,
              active: _c.snapEnabled,
              tooltip:
                  'Snap keys to beats, half-beats and sections '
                  '(Alt bypasses while dragging)',
              onTap: () => setState(() => _c.snapEnabled = !_c.snapEnabled),
            ),
            const SizedBox(width: 6),
            _toolButton(
              key: const Key('gradeFit'),
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
              key: const Key('gradeUndo'),
              label: 'UNDO',
              icon: Icons.undo_rounded,
              enabled: _c.canUndo,
              tooltip: 'Undo (Ctrl+Z)',
              onTap: _c.undo,
            ),
            const SizedBox(width: 6),
            _toolButton(
              key: const Key('gradeRedo'),
              label: 'REDO',
              icon: Icons.redo_rounded,
              enabled: _c.canRedo,
              tooltip: 'Redo (Ctrl+Shift+Z)',
              onTap: _c.redo,
            ),
            const SizedBox(width: 14),
            if (hasPreview && !_c.autoKey) ...[
              Container(
                key: const Key('gradeUnkeyedChip'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: _Ws.warn.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _Ws.warn),
                ),
                child: const Text(
                  'UNKEYED',
                  style: TextStyle(
                    color: _Ws.warn,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _toolButton(
                key: const Key('gradeStampKey'),
                label: '● KEY',
                icon: null,
                tooltip: 'Commit the preview at the playhead (Esc discards)',
                onTap: () => _c.stampAt(widget.positionSec),
              ),
            ],
            if (_c.store.fileUnreadable) ...[
              const SizedBox(width: 6),
              Tooltip(
                message:
                    'The grade file on disk does not parse — showing the last '
                    'good document. Autosave is paused; fix the file or '
                    'force-save.',
                child: InkWell(
                  key: const Key('gradeFileError'),
                  onTap: () => unawaited(_c.store.saveNow()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _Ws.error.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _Ws.error),
                    ),
                    child: const Text(
                      'FILE UNREADABLE — TAP TO FORCE-SAVE',
                      style: TextStyle(
                        color: _Ws.error,
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
            if (_note != null)
              Text(
                _note!,
                key: const Key('gradeNote'),
                style: const TextStyle(color: _Ws.accent, fontSize: 11),
              ),
            const SizedBox(width: 12),
            _addTrackButton(),
          ],
        ),
      ),
    );
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
            color: active ? _Ws.accent.withValues(alpha: 0.16) : null,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: active ? _Ws.accent : _Ws.edge),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 11,
                color: active ? _Ws.accent : _Ws.textLow,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: active ? _Ws.textHi : _Ws.textLow,
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
            border: Border.all(color: _Ws.edge),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 11, color: enabled ? _Ws.textMid : _Ws.edge),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  color: enabled ? _Ws.textMid : _Ws.edge,
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

  Widget _addTrackButton() {
    final existing = {for (final l in _c.displayLanes) l.target};
    final available = [
      (id: GradeTargets.backdrop, label: 'Backdrop (painted world)'),
      (id: GradeTargets.cast, label: 'Cast (the trio)'),
      for (final t in kBlueHourGradeTargets)
        (
          id: t.id,
          // Mirror the format doc's dagger: light passes ignore Offset.
          label: t.additive ? '${t.label} · no offset' : t.label,
        ),
    ].where((t) => !existing.contains(t.id)).toList();
    return PopupMenuButton<String>(
      key: const Key('gradeAddTrack'),
      tooltip: 'Add a grade lane for a scene target',
      color: _Ws.menu,
      onSelected: _c.addLane,
      enabled: available.isNotEmpty,
      itemBuilder: (context) => [
        for (final t in available)
          PopupMenuItem(value: t.id, child: Text(t.label)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _Ws.edge),
        ),
        child: const Row(
          children: [
            Icon(Icons.add_rounded, size: 12, color: _Ws.textMid),
            SizedBox(width: 3),
            Text(
              'ADD TRACK',
              style: TextStyle(
                color: _Ws.textMid,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── timeline rows ────────────────────────────────────────────────────────

  Widget _overview(double width) {
    return GestureDetector(
      key: const Key('gradeOverview'),
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
          amplitudes: widget.amplitudes,
          durationSec: widget.durationSec,
          view: _view,
          positionSec: widget.positionSec,
        ),
      ),
    );
  }

  Widget _ruler(double width) {
    return GestureDetector(
      key: const Key('gradeRuler'),
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

  Widget _waveform(double width) {
    return GestureDetector(
      key: const Key('gradeWaveform'),
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => widget.onSeek(_view.tFor(d.localPosition.dx, width)),
      onHorizontalDragUpdate: (d) =>
          widget.onSeek(_view.tFor(d.localPosition.dx, width)),
      child: CustomPaint(
        size: Size(width, 36),
        painter: _WaveformPainter(
          amplitudes: widget.amplitudes,
          durationSec: widget.durationSec,
          view: _view,
          positionSec: widget.positionSec,
        ),
      ),
    );
  }

  Widget _beats(double width) {
    return CustomPaint(
      key: const Key('gradeBeatsLane'),
      size: Size(width, 16),
      painter: _BeatsPainter(
        view: _view,
        beatTimesSec: _c.beatTimesSec,
        downbeatIndices: _c.downbeatIndices,
        positionSec: widget.positionSec,
      ),
    );
  }

  Widget _laneHeader(GradeLane lane) {
    final selected = _c.selectedTarget == lane.target;
    final label = _targetLabel(lane.target);
    return InkWell(
      key: Key('gradeLaneHeader-${lane.target}'),
      onTap: () => _c.selectLane(lane.target),
      child: Container(
        padding: const EdgeInsets.only(left: 12, right: 4),
        decoration: BoxDecoration(
          color: selected ? _Ws.accent.withValues(alpha: 0.10) : null,
          border: Border(
            left: BorderSide(
              color: selected ? _Ws.accent : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? _Ws.textHi : _Ws.textMid,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            InkWell(
              key: Key('gradeLaneMute-${lane.target}'),
              onTap: () => _c.toggleLaneEnabled(lane.target),
              child: Tooltip(
                // The DAW mute convention — an eye reads as "hide the row".
                message: lane.enabled ? 'Mute lane (bypass)' : 'Lane muted',
                child: Container(
                  width: 15,
                  height: 15,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: lane.enabled
                        ? Colors.transparent
                        : _Ws.warn.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: lane.enabled ? _Ws.edge : _Ws.warn,
                    ),
                  ),
                  child: Text(
                    'M',
                    style: TextStyle(
                      color: lane.enabled ? _Ws.textLow : _Ws.warn,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
            PopupMenuButton<String>(
              key: Key('gradeLaneMenu-${lane.target}'),
              tooltip: 'Lane options',
              color: _Ws.menu,
              iconSize: 13,
              icon: const Icon(Icons.more_vert_rounded, color: _Ws.textLow),
              onSelected: (a) => switch (a) {
                'clear' => _c.clearLane(lane.target),
                'remove' => _c.removeLane(lane.target),
                _ => null,
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'clear',
                  child: Text('Clear keyframes'),
                ),
                if (lane.target != GradeTargets.master)
                  const PopupMenuItem(
                    value: 'remove',
                    child: Text('Remove lane'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _targetLabel(String target) {
    if (target == GradeTargets.master) return 'Master';
    if (target == GradeTargets.backdrop) return 'Backdrop';
    if (target == GradeTargets.cast) return 'Cast';
    for (final t in kBlueHourGradeTargets) {
      if (t.id == target) return t.label;
    }
    return target;
  }

  Widget _laneCanvas(GradeLane lane, double width) {
    return GestureDetector(
      key: Key('gradeLane-${lane.target}'),
      behavior: HitTestBehavior.opaque,
      // Hit-test keys at the PRESS position, not the post-slop drag-accept
      // position — otherwise every key grab misses by the touch slop.
      dragStartBehavior: DragStartBehavior.down,
      onTapUp: (d) => _laneTap(lane, d.localPosition.dx, width),
      onDoubleTapDown: (d) => _c.addKeyAt(
        lane.target,
        _view.tFor(d.localPosition.dx, width),
      ),
      onSecondaryTapUp: (d) => unawaited(
        _laneContextMenu(lane, d.localPosition.dx, width, d.globalPosition),
      ),
      onHorizontalDragStart: (d) =>
          _laneDragStart(lane, d.localPosition.dx, width),
      onHorizontalDragUpdate: (d) => _laneDragUpdate(d, width),
      onHorizontalDragEnd: (_) => _laneDragEnd(),
      onHorizontalDragCancel: _laneDragEnd,
      child: CustomPaint(
        size: Size(width, _Ws.laneH),
        painter: _LanePainter(
          lane: lane,
          view: _view,
          positionSec: widget.positionSec,
          selected: _c.selectedTarget == lane.target,
          selectedKeyTimes: _c.selectedKeyTimes,
          flashKeyTSec: _note != null && _c.selectedTarget == lane.target
              ? _c.lastStampTSec
              : null,
        ),
      ),
    );
  }

  // ── console ──────────────────────────────────────────────────────────────

  Widget _console({bool compact = false}) {
    final look = _c.consoleLook(widget.positionSec);
    void edit(GradeLook next) => _c.consoleEdited(
      next,
      tSec: widget.positionSec,
      playing: widget.playing,
    );
    final lane = _c.store.doc.lane(_c.selectedTarget);
    final keys = lane?.keyframes ?? const <GradeKeyframe>[];
    final onKey = lane?.indexNear(widget.positionSec, tolerance: 0.02);
    // The chip narrates the playhead's exact relationship to the lane:
    // 'between keys' is reserved for true two-neighbour interpolation;
    // outside the keyed range the edge value HOLDS and the chip says so.
    final String subtitle;
    if (_c.preview != null && !_c.autoKey) {
      subtitle = 'UNKEYED preview';
    } else if (onKey != null) {
      subtitle =
          'key @ ${formatDancePlaybackTimestamp(widget.positionSec)} · '
          '${keys[onKey].interp.name}';
    } else if (keys.isEmpty) {
      subtitle = 'no keys yet';
    } else if (widget.positionSec < keys.first.tSec) {
      subtitle = 'before first key · holding';
    } else if (widget.positionSec > keys.last.tSec) {
      subtitle = 'after last key · holding';
    } else {
      subtitle = 'between keys';
    }
    final additive = kBlueHourGradeTargets.any(
      (t) => t.id == _c.selectedTarget && t.additive,
    );
    return ColorGradePanel(
      lift: look.lift,
      gamma: look.gamma,
      gain: look.gain,
      saturation: look.saturation,
      temperature: look.temperature,
      tint: look.tint,
      contrast: look.contrast,
      pivot: look.pivot,
      bypass: widget.bypass,
      parade: widget.parade,
      wheelDiameter: compact ? 104 : 116,
      title: _targetLabel(_c.selectedTarget).toUpperCase(),
      subtitle: subtitle,
      additiveTarget: additive,
      showScopes: widget.showScopes,
      onLift: (w) => edit(look.copyWith(lift: w)),
      onGamma: (w) => edit(look.copyWith(gamma: w)),
      onGain: (w) => edit(look.copyWith(gain: w)),
      onSaturation: (v) => edit(look.copyWith(saturation: v)),
      onTemperature: (v) => edit(look.copyWith(temperature: v)),
      onTint: (v) => edit(look.copyWith(tint: v)),
      onContrast: (v) => edit(look.copyWith(contrast: v)),
      onPivot: (v) => edit(look.copyWith(pivot: v)),
      onBypass: widget.onBypass,
      onReset: () => edit(GradeLook.neutral),
      onEditEnd: () => _c.consoleGestureEnded(
        tSec: widget.positionSec,
        playing: widget.playing,
      ),
    );
  }
}

/// Extension hook used by the context menu to reach the current lane state.
extension on DanceGradeController {
  GradeLane? doc(String target) => store.doc.lane(target);
}

// ── painters ───────────────────────────────────────────────────────────────

/// Whole-track mini strip with the visible-window brush.
class _OverviewPainter extends CustomPainter {
  _OverviewPainter({
    required this.amplitudes,
    required this.durationSec,
    required this.view,
    required this.positionSec,
  });

  final List<double> amplitudes;
  final double durationSec;
  final GradeTimelineViewport view;
  final double positionSec;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0B0E12),
    );
    if (amplitudes.isNotEmpty) {
      final n = amplitudes.length;
      final paint = Paint()..color = _Ws.waveAhead;
      for (var i = 0; i < n; i++) {
        final x = i / (n - 1) * size.width;
        final h = (amplitudes[i] * (size.height - 4)).clamp(1.0, size.height);
        canvas.drawRect(
          Rect.fromLTWH(x, (size.height - h) / 2, 1, h),
          paint,
        );
      }
    }
    if (durationSec > 0) {
      // The brush: the visible window.
      final left = view.startSec / durationSec * size.width;
      final w = view.visibleSec / durationSec * size.width;
      canvas
        ..drawRect(
          Rect.fromLTWH(left, 0, w, size.height),
          Paint()..color = _Ws.accent.withValues(alpha: 0.16),
        )
        ..drawRect(
          Rect.fromLTWH(left, 0, w, size.height),
          Paint()
            ..style = PaintingStyle.stroke
            ..color = _Ws.accent.withValues(alpha: 0.7),
        )
        // Playhead tick.
        ..drawRect(
          Rect.fromLTWH(
            positionSec / durationSec * size.width,
            0,
            1.5,
            size.height,
          ),
          Paint()..color = _Ws.accent,
        );
    }
  }

  @override
  bool shouldRepaint(_OverviewPainter old) =>
      old.view != view ||
      old.positionSec != positionSec ||
      !identical(old.amplitudes, amplitudes);
}

/// Time labels + section pills, in viewport space.
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
              color: _Ws.textMid,
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
    // Section pills along the bottom of the ruler.
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
            color: active ? hue : _Ws.textLow,
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
    // Sub-second labels only when zoomed far enough for them to differ.
    return frac > 0.01 ? '$m:$ss.${(frac * 10).round()}' : '$m:$ss';
  }

  @override
  bool shouldRepaint(_RulerPainter old) =>
      old.view != view ||
      old.positionSec != positionSec ||
      !identical(old.sections, sections);
}

/// Played/ahead waveform in viewport space (same two-tone language as the
/// compact transport strip).
class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.amplitudes,
    required this.durationSec,
    required this.view,
    required this.positionSec,
  });

  final List<double> amplitudes;
  final double durationSec;
  final GradeTimelineViewport view;
  final double positionSec;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0D1116),
    );
    if (amplitudes.length < 2 || durationSec <= 0) return;
    final mid = size.height / 2;
    final px = view.xFor(positionSec, size.width);

    Path envelope() {
      final p = Path()..moveTo(0, mid);
      final n = amplitudes.length;
      for (var x = 0.0; x <= size.width; x += 2) {
        final t = view.tFor(x, size.width);
        final i = (t / durationSec * (n - 1)).round().clamp(0, n - 1);
        final h = (amplitudes[i] * (size.height - 6)).clamp(1.0, size.height);
        p.lineTo(x, mid - h / 2);
      }
      for (var x = size.width; x >= 0; x -= 2) {
        final t = view.tFor(x, size.width);
        final i = (t / durationSec * (n - 1)).round().clamp(0, n - 1);
        final h = (amplitudes[i] * (size.height - 6)).clamp(1.0, size.height);
        p.lineTo(x, mid + h / 2);
      }
      return p..close();
    }

    final env = envelope();
    void fill(double from, double to, Color color) {
      if (to <= from) return;
      canvas
        ..save()
        ..clipRect(Rect.fromLTWH(from, 0, to - from, size.height))
        ..drawPath(env, Paint()..color = color)
        ..restore();
    }

    fill(0, px, _Ws.wavePlayed);
    fill(px, size.width, _Ws.waveAhead);
    _paintPlayhead(canvas, size, view, positionSec);
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.view != view ||
      old.positionSec != positionSec ||
      !identical(old.amplitudes, amplitudes);
}

/// The DETECTED beat grid: ticks where Beat This! heard beats, downbeats
/// accented and numbered by bar — the truth keyframes snap to, not a
/// nominal-BPM approximation.
class _BeatsPainter extends CustomPainter {
  _BeatsPainter({
    required this.view,
    required this.beatTimesSec,
    required this.downbeatIndices,
    required this.positionSec,
  });

  final GradeTimelineViewport view;
  final List<double> beatTimesSec;
  final List<int> downbeatIndices;
  final double positionSec;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0B0E12),
    );
    if (beatTimesSec.isEmpty) return;
    final downbeats = Set.of(downbeatIndices);
    final beat = Paint()..color = const Color(0x40FFFFFF);
    final down = Paint()..color = const Color(0x9AFFFFFF);
    // Level-of-detail: below ~8px/beat a full grid is an undifferentiated
    // picket fence, so draw downbeats only and label every Nth bar such that
    // labels keep ~40px of air.
    final avgBeat =
        (beatTimesSec.last - beatTimesSec.first) /
        math.max(1, beatTimesSec.length - 1);
    final pxPerBeat = avgBeat / view.visibleSec * size.width;
    final drawBeats = pxPerBeat >= 8;
    final pxPerBar = pxPerBeat * 4;
    final labelEveryBars = pxPerBar >= 40
        ? 1
        : pxPerBar >= 10
        ? 4
        : 8;
    var bar = 0;
    for (var i = 0; i < beatTimesSec.length; i++) {
      final t = beatTimesSec[i];
      final isDown = downbeats.contains(i);
      if (isDown) bar++;
      final x = view.xFor(t, size.width);
      if (x < -20 || x > size.width + 20) continue;
      if (isDown) {
        canvas.drawRect(Rect.fromLTWH(x, 2, 1.5, size.height - 2), down);
        if (bar % labelEveryBars == 0) {
          TextPainter(
              text: TextSpan(
                text: '$bar',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: _Ws.textMid,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              textDirection: TextDirection.ltr,
            )
            ..layout()
            ..paint(canvas, Offset(x + 3, 1));
        }
      } else if (drawBeats) {
        canvas.drawRect(
          Rect.fromLTWH(x, size.height * 0.45, 1, size.height * 0.55),
          beat,
        );
      }
    }
    _paintPlayhead(canvas, size, view, positionSec);
  }

  @override
  bool shouldRepaint(_BeatsPainter old) =>
      old.view != view ||
      old.positionSec != positionSec ||
      !identical(old.beatTimesSec, beatTimesSec);
}

/// One grade lane: deviation sparkline + keyframe diamonds (+ selection).
class _LanePainter extends CustomPainter {
  _LanePainter({
    required this.lane,
    required this.view,
    required this.positionSec,
    required this.selected,
    required this.selectedKeyTimes,
    this.flashKeyTSec,
  });

  final GradeLane lane;
  final GradeTimelineViewport view;
  final double positionSec;
  final bool selected;
  final Set<double> selectedKeyTimes;

  /// A just-stamped key to ring (the toolbar note's in-lane counterpart).
  final double? flashKeyTSec;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      // Lane bodies stay one neutral surface — selection is encoded in the
      // header edge only, so it can never collide with the deviation band.
      ..drawRect(Offset.zero & size, Paint()..color = const Color(0xFF101317))
      ..drawRect(
        Rect.fromLTWH(0, size.height - 1, size.width, 1),
        Paint()..color = _Ws.edge,
      );
    final muted = !lane.enabled;
    final alpha = muted ? 0.35 : 1.0;

    // Deviation sparkline: a filled band + bright top stroke, one sample per
    // ~4px. Square-root scaling with a minimum visible amplitude — a SUBTLE
    // document (the whole point of a tasteful grade) must still draw a
    // legible ramp, or the lane hides the very automation it exists to show.
    if (lane.keyframes.isNotEmpty) {
      double yFor(double d) {
        if (d <= 0) return size.height - 1;
        final scaled = math.sqrt(d.clamp(0.0, 1.0));
        final h = (3.0 + scaled * (size.height - 10)).clamp(
          3.0,
          size.height - 6.0,
        );
        return size.height - 1 - h;
      }

      final fill = Path()..moveTo(0, size.height - 1);
      final stroke = Path();
      var started = false;
      for (var x = 0.0; x <= size.width; x += 4) {
        final t = view.tFor(x, size.width);
        final y = yFor(lane.evaluate(t).deviation);
        fill.lineTo(x, y);
        if (started) {
          stroke.lineTo(x, y);
        } else {
          stroke.moveTo(x, y);
          started = true;
        }
      }
      fill
        ..lineTo(size.width, size.height - 1)
        ..close();
      const sparkColor = Color(0xFFAFC3D4);
      canvas
        ..drawPath(
          fill,
          Paint()..color = sparkColor.withValues(alpha: 0.22 * alpha),
        )
        ..drawPath(
          stroke,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = sparkColor.withValues(alpha: 0.9 * alpha),
        );
    }

    // Keyframe diamonds; hold segments draw a step hint to the next key.
    for (var i = 0; i < lane.keyframes.length; i++) {
      final k = lane.keyframes[i];
      final x = view.xFor(k.tSec, size.width);
      if (x < -10 || x > size.width + 10) continue;
      final cy = size.height / 2;
      final isSel = selectedKeyTimes.any(
        (t) => (t - k.tSec).abs() < kGradeKeyEpsilonSec,
      );
      final isFlash =
          flashKeyTSec != null &&
          (flashKeyTSec! - k.tSec).abs() < kGradeKeyEpsilonSec;
      final r = isSel ? 7.5 : 6.0;
      final diamond = Path()
        ..moveTo(x, cy - r)
        ..lineTo(x + r, cy)
        ..lineTo(x, cy + r)
        ..lineTo(x - r, cy)
        ..close();
      canvas
        ..drawPath(
          diamond,
          Paint()
            // Selected = white core + teal ring, so selection, playhead and
            // overview brush stop sharing one identical teal.
            ..color = (isSel ? Colors.white : const Color(0xFFE2E9F0))
                .withValues(alpha: alpha),
        )
        ..drawPath(
          diamond,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSel ? 2 : 1.2
            ..color = (isSel ? _Ws.accent : Colors.black.withValues(alpha: 0.6))
                .withValues(alpha: alpha),
        );
      if (isFlash) {
        // Auto-stamp receipt anchored AT the artifact, not only in the
        // toolbar note across the screen.
        canvas.drawCircle(
          Offset(x, cy),
          r + 5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = _Ws.accent.withValues(alpha: 0.9),
        );
      }
      if (k.interp == GradeInterp.hold && i + 1 < lane.keyframes.length) {
        final nx = view.xFor(lane.keyframes[i + 1].tSec, size.width);
        canvas.drawRect(
          Rect.fromLTWH(x + r + 1, cy - 0.5, math.max(0, nx - x - 2 * r), 1),
          Paint()..color = const Color(0x55FFFFFF),
        );
      }
    }

    if (lane.keyframes.isEmpty) {
      // An empty lane advertises its path to the first key instead of
      // reading as a dead black strip.
      final hint = TextPainter(
        text: const TextSpan(
          text: 'double-click to add a key · console edits write here',
          style: TextStyle(
            fontFamily: 'Inter',
            color: Color(0x4DFFFFFF),
            fontSize: 9,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      hint.paint(
        canvas,
        Offset(12, (size.height - hint.height) / 2),
      );
    }

    if (muted) {
      final tp = TextPainter(
        text: const TextSpan(
          text: 'MUTED',
          style: TextStyle(
            fontFamily: 'Inter',
            color: _Ws.warn,
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width - tp.width - 6, 3));
    }

    _paintPlayhead(canvas, size, view, positionSec);
  }

  @override
  bool shouldRepaint(_LanePainter old) =>
      old.view != view ||
      old.positionSec != positionSec ||
      old.selected != selected ||
      old.lane != lane ||
      old.flashKeyTSec != flashKeyTSec ||
      !setEquals(old.selectedKeyTimes, selectedKeyTimes);
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
    Paint()..color = _Ws.accent,
  );
  if (flag) {
    final path = Path()
      ..moveTo(x - 5, 0)
      ..lineTo(x + 5, 0)
      ..lineTo(x + 5, 5)
      ..lineTo(x, 8)
      ..lineTo(x - 5, 5)
      ..close();
    canvas.drawPath(path, Paint()..color = _Ws.accent);
  }
}

/// Self-contained dark palette for the workspace chrome (demo-only values,
/// matching the transport's console language).
abstract final class _Ws {
  static const Color panel = Color(0xFF121417);
  static const Color menu = Color(0xFF1B2127);
  static const Color edge = Color(0x1FFFFFFF);
  static const Color accent = Color(0xFF4DD6C0);
  static const Color warn = Color(0xFFE6A24A);
  static const Color error = Color(0xFFE0483B);
  static const Color textHi = Color(0xFFEDF1F5);
  static const Color textMid = Color(0xFF8A96A3);
  static const Color textLow = Color(0xFF59626D);
  static const Color wavePlayed = Color(0xFFB8C6D2);
  static const Color waveAhead = Color(0xFF3A4550);
  static const double headerW = 148;
  static const double laneH = 34;
}
