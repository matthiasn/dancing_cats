import 'dart:math' as math;

import 'package:dancing_cats/features/character/demo/dance_cues_store.dart';
import 'package:dancing_cats/features/character/demo/dance_lip_sync.dart';
import 'package:dancing_cats/features/character/demo/dance_lip_sync_doc.dart';
import 'package:flutter/foundation.dart';

/// The editing brain of the lip-sync workspace: owns selection, boundary
/// dragging, split/merge/reshape, beat snapping and gesture-level undo/redo —
/// all as pure [LipSyncDoc] transformations pushed through the
/// [DanceCuesStore]. A structural sibling of `DanceGradeController` adapted
/// to the span-based cue model. Owns no widgets; the workspace renders it and
/// the page feeds it the playhead.
class DanceLipSyncController extends ChangeNotifier {
  DanceLipSyncController({required this.store, this.beatTimesSec = const []})
    : _shadowDoc = store.doc,
      _shadowSerial = store.eventSerial {
    store.addListener(_onStore);
  }

  /// The document's persistence layer (this controller never touches disk).
  final DanceCuesStore store;

  /// Detected beat grid, for snapping dragged/nudged boundaries.
  final List<double> beatTimesSec;

  /// Snap dragged/nudged boundaries to the beat grid.
  bool snapEnabled = true;

  /// The live cue list — what the page feeds `DancePlaybackStepper.advance`
  /// every frame, so edits preview immediately with no extra sync step.
  List<DanceCue> get cues => _doc.cues;

  /// The selected cue's index, or null when nothing is selected.
  int? get selectedIndex => _selectedIndex;
  int? _selectedIndex;

  final List<LipSyncDoc> _undo = [];
  final List<LipSyncDoc> _redo = [];
  LipSyncDoc _shadowDoc;
  int _shadowSerial;

  /// Whether an undo step is available.
  bool get canUndo => _undo.isNotEmpty;

  /// Whether a redo step is available.
  bool get canRedo => _redo.isNotEmpty;

  LipSyncDoc get _doc => store.doc;

  // ── selection ──────────────────────────────────────────────────────────

  /// Click: select the cue at [index] (or clear with null). The page also
  /// moves the playhead to it — edit target and displayed frame coincide.
  void selectCue(int? index) {
    if (_selectedIndex == index) return;
    _selectedIndex = index;
    notifyListeners();
  }

  /// Esc: clear the selection.
  void clearSelection() {
    if (_selectedIndex == null) return;
    _selectedIndex = null;
    notifyListeners();
  }

  // ── boundary dragging ─────────────────────────────────────────────────

  int? _dragIndex;
  double? _dragAnchorTSec;
  LipSyncDoc? _dragBase;

  /// Begins dragging the boundary after `cues[index]` (between `cues[index]`
  /// and `cues[index + 1]`).
  void beginBoundaryDrag(int index) {
    if (index < 0 || index >= cues.length - 1) return;
    _pushUndo();
    _dragIndex = index;
    _dragBase = _doc;
    _dragAnchorTSec = cues[index].end;
    selectCue(index);
  }

  /// Moves the dragged boundary by [deltaSec] from its drag-start position,
  /// snapping when the magnet is on ([snap] false bypasses it — Alt-drag,
  /// fine nudges). Clamped inside [LipSyncDoc.moveBoundary] so neither side
  /// ever drops below [kMinCueDurationSec].
  void updateBoundaryDrag(double deltaSec, {bool snap = true}) {
    final index = _dragIndex;
    final base = _dragBase;
    final anchor = _dragAnchorTSec;
    if (index == null || base == null || anchor == null) return;
    var t = anchor + deltaSec;
    if (snap && snapEnabled) t = snapTime(t);
    store.update(base.moveBoundary(index, t));
  }

  /// Ends the drag transaction.
  void endBoundaryDrag() {
    _dragIndex = null;
    _dragBase = null;
    _dragAnchorTSec = null;
  }

  /// ←/→: nudge the boundary after `cues[index]` by one beat (or [fineSec]
  /// with Shift — fine nudges bypass the magnet, otherwise snap would undo
  /// them).
  void nudgeBoundary(int index, int direction, {double? fineSec}) {
    if (index < 0 || index >= cues.length - 1) return;
    final delta = fineSec != null
        ? direction * fineSec
        : direction * _beatIntervalNear(cues[index].end);
    beginBoundaryDrag(index);
    updateBoundaryDrag(delta, snap: fineSec == null);
    endBoundaryDrag();
  }

  // ── reshape / split / merge ───────────────────────────────────────────

  /// Reassigns `cues[index]`'s viseme letter.
  void setShape(int index, String shape) {
    if (index < 0 || index >= cues.length) return;
    if (cues[index].shape == shape) return;
    _pushUndo();
    store.update(_doc.setShape(index, shape));
  }

  /// Double-click inside a cue: splits it at [tSec] and selects the new
  /// right-hand half. A no-op (no undo step pushed) when the split would
  /// create a span thinner than [kMinCueDurationSec].
  void splitSelectedAt(double tSec) {
    final next = _doc.splitAt(tSec);
    if (identical(next, _doc)) return;
    _pushUndo();
    store.update(next);
    selectCue(next.indexAt(tSec));
  }

  /// Delete/Backspace: merges the selected cue forward into its right
  /// neighbour, or backward into its left neighbour when it is the last cue.
  void mergeSelected() {
    final i = _selectedIndex;
    if (i == null) return;
    final index = i >= cues.length - 1 ? i - 1 : i;
    if (index < 0) return;
    _pushUndo();
    store.update(_doc.mergeBoundaryAfter(index));
    selectCue(index);
  }

  // ── undo/redo ──────────────────────────────────────────────────────────

  /// Ctrl+Z. One gesture = one step; external reloads are steps too.
  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(_doc);
    store.update(_undo.removeLast());
    _selectedIndex = null;
    notifyListeners();
  }

  /// Ctrl+Shift+Z.
  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(_doc);
    store.update(_redo.removeLast());
    _selectedIndex = null;
    notifyListeners();
  }

  void _pushUndo() {
    _undo.add(_doc);
    if (_undo.length > 100) _undo.removeAt(0);
    _redo.clear();
  }

  // ── snapping ───────────────────────────────────────────────────────────

  /// Snaps [tSec] to the nearest detected beat or half-beat within
  /// [toleranceSec]; returns [tSec] unchanged when nothing is close.
  double snapTime(double tSec, {double toleranceSec = 0.12}) {
    if (beatTimesSec.isEmpty) return tSec;
    double? best;
    var bestDist = toleranceSec;
    void consider(double candidate) {
      final d = (candidate - tSec).abs();
      if (d <= bestDist) {
        bestDist = d;
        best = candidate;
      }
    }

    final i = _nearestBeatIndex(tSec);
    if (i != null) {
      for (
        var j = math.max(0, i - 1);
        j <= math.min(beatTimesSec.length - 1, i + 1);
        j++
      ) {
        consider(beatTimesSec[j]);
        if (j + 1 < beatTimesSec.length) {
          consider((beatTimesSec[j] + beatTimesSec[j + 1]) / 2); // the "and"
        }
      }
    }
    return best ?? tSec;
  }

  int? _nearestBeatIndex(double tSec) {
    if (beatTimesSec.isEmpty) return null;
    var lo = 0;
    var hi = beatTimesSec.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (beatTimesSec[mid] <= tSec) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (tSec - beatTimesSec[lo]).abs() <= (beatTimesSec[hi] - tSec).abs()
        ? lo
        : hi;
  }

  double _beatIntervalNear(double tSec) {
    final i = _nearestBeatIndex(tSec);
    if (i == null || beatTimesSec.length < 2) return 0.5;
    final j = math.min(i, beatTimesSec.length - 2);
    return beatTimesSec[j + 1] - beatTimesSec[j];
  }

  // ── plumbing ───────────────────────────────────────────────────────────

  void _onStore() {
    if (store.eventSerial != _shadowSerial) {
      _shadowSerial = store.eventSerial;
      if (store.lastEvent == DanceCuesStoreEvent.externalReload) {
        // A Rhubarb re-run/hand edit landed: one undoable step (Ctrl+Z
        // restores the pre-reload document).
        _undo.add(_shadowDoc);
        _redo.clear();
        _selectedIndex = null;
      }
    }
    _shadowDoc = store.doc;
    notifyListeners();
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    super.dispose();
  }
}
