import 'dart:math' as math;

import 'package:dancing_cats/features/character/demo/dance_grade_store.dart';
import 'package:dancing_cats/features/scenery/model/backdrop_grade.dart';
import 'package:dancing_cats/features/scenery/model/grade_timeline.dart';
import 'package:flutter/foundation.dart';

/// Seconds between throttled touch-trail stamps while riding a control during
/// playback.
const double kGradeTrailStampIntervalSec = 0.25;

/// Wheel-space tolerance for post-release trail thinning (below a visible
/// grade difference).
const double kGradeTrailThinTolerance = 0.015;

/// The editing brain of the grade workspace (ADR 0002 §4): owns selection,
/// auto-key, the sticky unkeyed preview, touch-trail recording + thinning,
/// snapping, copy/paste, lane management and gesture-level undo/redo — all as
/// pure document transformations pushed through the [DanceGradeStore]. Owns
/// no widgets; the workspace renders it and the page feeds it the playhead.
class DanceGradeController extends ChangeNotifier {
  DanceGradeController({
    required this.store,
    this.beatTimesSec = const [],
    this.downbeatIndices = const [],
    this.sectionStartsSec = const [],
  }) : _shadowDoc = store.doc,
       _shadowSerial = store.eventSerial {
    store.addListener(_onStore);
  }

  /// The document's persistence layer (this controller never touches disk).
  final DanceGradeStore store;

  /// Detected beat grid (for snapping and the beat lane).
  final List<double> beatTimesSec;

  /// Indices into [beatTimesSec] that are bar downbeats.
  final List<int> downbeatIndices;

  /// Musical section starts (snap targets alongside beats).
  final List<double> sectionStartsSec;

  /// The lane the console edits.
  String get selectedTarget => _selectedTarget;
  String _selectedTarget = GradeTargets.master;

  /// Selected keyframe times on the selected lane (shift-click multi-select).
  Set<double> get selectedKeyTimes => Set.unmodifiable(_selectedKeyTimes);
  final Set<double> _selectedKeyTimes = {};

  /// Auto-key: a released edit stamps a keyframe at the playhead (default ON
  /// — nothing dialled is ever silently lost).
  bool autoKey = true;

  /// Snap dragged/nudged keys to beats, half-beats and section starts.
  bool snapEnabled = true;

  /// The sticky unkeyed preview (auto-key OFF): survives seeks and playback
  /// until Esc or ● KEY (ADR 0002 §4, panel-revised).
  GradeLook? get preview => _preview;
  GradeLook? _preview;

  /// Copied look for paste-across-keys/lanes.
  GradeLook? clipboard;

  final List<GradeTimelineDoc> _undo = [];
  final List<GradeTimelineDoc> _redo = [];
  bool _gestureActive = false;
  final List<GradeKeyframe> _trail = [];
  GradeTimelineDoc _shadowDoc;
  int _shadowSerial;

  /// Whether an undo step is available.
  bool get canUndo => _undo.isNotEmpty;

  /// Whether a redo step is available.
  bool get canRedo => _redo.isNotEmpty;

  GradeTimelineDoc get _doc => store.doc;

  /// The document's lanes for display: MASTER always first (visible even
  /// before it holds keys), then the added lanes in document order.
  List<GradeLane> get displayLanes {
    final master =
        _doc.lane(GradeTargets.master) ??
        GradeLane(target: GradeTargets.master);
    return [
      master,
      ..._doc.lanes.where((l) => l.target != GradeTargets.master),
    ];
  }

  /// What the console shows/edits for [tSec]: the sticky/gesture preview when
  /// one is held for the selected lane, else the lane's evaluated look.
  GradeLook consoleLook(double tSec) =>
      _preview ?? _laneLook(_selectedTarget, tSec);

  GradeLook _laneLook(String target, double tSec) =>
      _doc.lane(target)?.evaluate(tSec) ?? GradeLook.neutral;

  /// Every non-neutral grade at [tSec], keyed by target — the render feed.
  /// The selected lane is overridden by the live preview during a gesture or
  /// a sticky unkeyed edit. [includePreview] false gives the document-only
  /// truth (the export path must never ship an unkeyed experiment).
  Map<String, BackdropGrade> gradesAt(
    double tSec, {
    bool includePreview = true,
  }) {
    final looks = _doc.evaluate(tSec);
    if (includePreview && _preview != null) {
      if (_preview!.isNeutral) {
        looks.remove(_selectedTarget);
      } else {
        looks[_selectedTarget] = _preview!;
      }
    }
    return {for (final e in looks.entries) e.key: e.value.toGrade()};
  }

  // ── console editing ────────────────────────────────────────────────────

  /// A console control changed. First change of a gesture opens an undo
  /// transaction. Auto-key ON: paused → upsert at the playhead now (repeated
  /// changes replace the same key); playing → record a throttled touch trail
  /// committed on [consoleGestureEnded]. Auto-key OFF: hold as the sticky
  /// preview.
  void consoleEdited(
    GradeLook look, {
    required double tSec,
    required bool playing,
  }) {
    if (!_gestureActive) {
      _gestureActive = true;
      _trail.clear();
      // Preview-only edits (auto-key OFF) mutate nothing, so they open no
      // undo transaction; the stamp does.
      if (autoKey) _pushUndo();
    }
    _preview = look;
    if (autoKey) {
      if (playing) {
        if (_trail.isEmpty ||
            tSec - _trail.last.tSec >= kGradeTrailStampIntervalSec) {
          _trail.add(
            GradeKeyframe(tSec: tSec, look: look, interp: GradeInterp.linear),
          );
        }
      } else {
        _mutate(
          _withLane(
            _lane(
              _selectedTarget,
            ).upsert(GradeKeyframe(tSec: tSec, look: look)),
          ),
        );
      }
    }
    notifyListeners();
  }

  /// The gesture (wheel ride / slider scrub) released. Playing + auto-key:
  /// the recorded trail REPLACES every pre-existing key inside the touched
  /// span and is thinned so a ridden 8-bar automation stays editable.
  void consoleGestureEnded({required double tSec, required bool playing}) {
    if (!_gestureActive) return;
    _gestureActive = false;
    if (autoKey) {
      if (playing && _trail.isNotEmpty) {
        final look = _preview;
        if (look != null && tSec > _trail.last.tSec) {
          _trail.add(
            GradeKeyframe(tSec: tSec, look: look, interp: GradeInterp.linear),
          );
        }
        final thinned = thinTrail(_trail);
        var lane = _lane(_selectedTarget);
        final span = (from: _trail.first.tSec, to: _trail.last.tSec);
        lane = GradeLane(
          target: lane.target,
          enabled: lane.enabled,
          keyframes: [
            for (final k in lane.keyframes)
              if (k.tSec < span.from - kGradeKeyEpsilonSec ||
                  k.tSec > span.to + kGradeKeyEpsilonSec)
                k,
            ...thinned,
          ],
        );
        _mutate(_withLane(lane));
      }
      _preview = null;
      _trail.clear();
    }
    // Auto-key OFF: the preview stays sticky (badge lit) until Esc / ● KEY.
    notifyListeners();
  }

  /// ● KEY — stamps the sticky preview (or the current evaluated look) at the
  /// playhead and clears the preview.
  void stampAt(double tSec) {
    final look = _preview ?? _laneLook(_selectedTarget, tSec);
    _pushUndo();
    _mutate(
      _withLane(
        _lane(_selectedTarget).upsert(GradeKeyframe(tSec: tSec, look: look)),
      ),
    );
    _preview = null;
    notifyListeners();
  }

  /// Esc — drops the sticky preview (the document look shows again).
  void discardPreview() {
    if (_preview == null) return;
    _preview = null;
    notifyListeners();
  }

  // ── keyframe editing ───────────────────────────────────────────────────

  /// Click: select this key alone (the page also moves the playhead to it —
  /// edit target and displayed frame always coincide). Shift-click: toggle
  /// membership in the multi-selection.
  void selectKey(String target, double tSec, {bool extend = false}) {
    if (_selectedTarget != target) {
      _selectedTarget = target;
      _selectedKeyTimes.clear();
    }
    if (extend) {
      if (!_selectedKeyTimes.remove(tSec)) _selectedKeyTimes.add(tSec);
    } else {
      _selectedKeyTimes
        ..clear()
        ..add(tSec);
    }
    _preview = null; // the selected key's look is now the console's source
    notifyListeners();
  }

  /// Selects a lane for console editing (clears key selection).
  void selectLane(String target) {
    if (_selectedTarget == target) return;
    _selectedTarget = target;
    _selectedKeyTimes.clear();
    _preview = null;
    notifyListeners();
  }

  /// Esc with a selection: clear it.
  void clearKeySelection() {
    if (_selectedKeyTimes.isEmpty) return;
    _selectedKeyTimes.clear();
    notifyListeners();
  }

  /// Double-click on empty lane space: a key at [tSec] holding the lane's
  /// evaluated look (no visual jump — it pins what is already on screen).
  void addKeyAt(String target, double tSec) {
    final t = snapEnabled ? snapTime(tSec) : tSec;
    _pushUndo();
    final lane = _lane(target);
    _mutate(
      _withLane(lane.upsert(GradeKeyframe(tSec: t, look: lane.evaluate(t)))),
    );
    _selectedTarget = target;
    _selectedKeyTimes
      ..clear()
      ..add(t);
    notifyListeners();
  }

  /// Context menu / Delete key: remove one key.
  void deleteKey(String target, double tSec) {
    _pushUndo();
    _mutate(_withLane(_lane(target).removeNear(tSec)));
    _selectedKeyTimes.remove(tSec);
    notifyListeners();
  }

  /// Delete/Backspace: remove the whole selection on the selected lane.
  void deleteSelected() {
    if (_selectedKeyTimes.isEmpty) return;
    _pushUndo();
    var lane = _lane(_selectedTarget);
    for (final t in _selectedKeyTimes) {
      lane = lane.removeNear(t);
    }
    _mutate(_withLane(lane));
    _selectedKeyTimes.clear();
    notifyListeners();
  }

  // A key drag is one undo transaction: snapshot on start, rebuild from the
  // base on every update (so intermediate states never stack), commit on end.
  GradeLane? _dragBase;
  Set<double>? _dragBaseTimes;

  /// Begins dragging the key at [tSec] (drags the whole selection when the
  /// pressed key is part of it).
  void beginKeyDrag(String target, double tSec) {
    selectKeyForDrag(target, tSec);
    _pushUndo();
    _dragBase = _lane(target);
    _dragBaseTimes = Set.of(_selectedKeyTimes);
  }

  /// Selection rule for a drag press: keep an existing multi-selection when
  /// the pressed key belongs to it, else select just the pressed key.
  void selectKeyForDrag(String target, double tSec) {
    if (_selectedTarget != target || !_selectedKeyTimes.contains(tSec)) {
      selectKey(target, tSec);
    }
  }

  /// Moves the dragged selection by [deltaSec] from its drag-start position,
  /// snapping the pressed key ([anchorTSec]) when the magnet is on ([snap]
  /// false bypasses it — Alt-drag, fine nudges). Keys clamp against their
  /// unselected neighbours (never reorder past them).
  void updateKeyDrag(
    double deltaSec, {
    required double anchorTSec,
    bool snap = true,
  }) {
    final base = _dragBase;
    final times = _dragBaseTimes;
    if (base == null || times == null || times.isEmpty) return;

    var delta = deltaSec;
    if (snap && snapEnabled) {
      final snapped = snapTime(anchorTSec + delta);
      if (snapped != anchorTSec + delta) delta = snapped - anchorTSec;
    }
    // Clamp so every selected key stays inside its unselected neighbourhood.
    final unselected = [
      for (final k in base.keyframes)
        if (!times.contains(k.tSec)) k.tSec,
    ];
    for (final t in times) {
      final prev = unselected
          .where((u) => u < t)
          .fold<double?>(
            null,
            (a, b) => a == null || b > a ? b : a,
          );
      final next = unselected
          .where((u) => u > t)
          .fold<double?>(
            null,
            (a, b) => a == null || b < a ? b : a,
          );
      final lo = math.max(
        (prev == null ? 0.0 : prev + kGradeKeyEpsilonSec * 2) - t,
        -t, // never before the start of the track
      );
      final hi = next == null
          ? double.infinity
          : (next - kGradeKeyEpsilonSec * 2) - t;
      if (hi < lo) {
        delta = 0; // fully boxed in — the drag holds still
      } else {
        delta = delta.clamp(lo, hi);
      }
    }

    final moved = GradeLane(
      target: base.target,
      enabled: base.enabled,
      keyframes: [
        for (final k in base.keyframes)
          if (times.contains(k.tSec))
            GradeKeyframe(
              tSec: k.tSec + delta,
              look: k.look,
              interp: k.interp,
            )
          else
            k,
      ],
    );
    _mutate(_withLane(moved));
    _selectedKeyTimes
      ..clear()
      ..addAll([for (final t in times) t + delta]);
    notifyListeners();
  }

  /// Ends the drag transaction.
  void endKeyDrag() {
    _dragBase = null;
    _dragBaseTimes = null;
  }

  /// ←/→: nudge the selection by one beat (or [fineSec] with Shift — fine
  /// nudges bypass the magnet, otherwise snap would undo them).
  void nudgeSelected(int direction, {double? fineSec}) {
    if (_selectedKeyTimes.isEmpty) return;
    final anchor = _selectedKeyTimes.reduce(math.min);
    final delta = fineSec != null
        ? direction * fineSec
        : direction * _beatIntervalNear(anchor);
    beginKeyDrag(_selectedTarget, anchor);
    updateKeyDrag(delta, anchorTSec: anchor, snap: fineSec == null);
    endKeyDrag();
  }

  /// Sets the outgoing curve of the key at [tSec].
  void setInterp(String target, double tSec, GradeInterp interp) {
    final lane = _lane(target);
    final i = lane.indexNear(tSec);
    if (i == null) return;
    _pushUndo();
    final k = lane.keyframes[i];
    _mutate(
      _withLane(
        lane.replaceAt(
          i,
          GradeKeyframe(tSec: k.tSec, look: k.look, interp: interp),
        ),
      ),
    );
    notifyListeners();
  }

  /// Context menu: copy the look of the key at [tSec].
  void copyLook(String target, double tSec) {
    final lane = _lane(target);
    final i = lane.indexNear(tSec);
    if (i == null) return;
    clipboard = lane.keyframes[i].look;
    notifyListeners();
  }

  /// Context menu: paste the copied look as a key at [tSec] on [target].
  void pasteLook(String target, double tSec) {
    final look = clipboard;
    if (look == null) return;
    _pushUndo();
    _mutate(
      _withLane(_lane(target).upsert(GradeKeyframe(tSec: tSec, look: look))),
    );
    notifyListeners();
  }

  // ── lanes ──────────────────────────────────────────────────────────────

  /// ADD TRACK: creates (and selects) an empty lane for [target].
  void addLane(String target) {
    if (_doc.lane(target) != null) {
      selectLane(target);
      return;
    }
    _pushUndo();
    _mutate(_doc.withLane(GradeLane(target: target)));
    selectLane(target);
  }

  /// Track-header menu: remove the lane (master cannot be removed, only
  /// cleared — it is the workspace's home lane).
  void removeLane(String target) {
    if (target == GradeTargets.master) return;
    _pushUndo();
    _mutate(_doc.withoutLane(target));
    if (_selectedTarget == target) selectLane(GradeTargets.master);
    notifyListeners();
  }

  /// Track-header menu: drop every key but keep the lane.
  void clearLane(String target) {
    _pushUndo();
    _mutate(_withLane(GradeLane(target: target)));
    _selectedKeyTimes.clear();
    notifyListeners();
  }

  /// Lane mute toggle.
  void toggleLaneEnabled(String target) {
    final lane = _doc.lane(target);
    if (lane == null) return;
    _pushUndo();
    _mutate(_withLane(lane.withEnabled(enabled: !lane.enabled)));
    notifyListeners();
  }

  // ── undo/redo ──────────────────────────────────────────────────────────

  /// Ctrl+Z. One gesture = one step; external reloads are steps too.
  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(_doc);
    final doc = _undo.removeLast();
    _mutate(doc);
    _selectedKeyTimes.clear();
    _preview = null;
    notifyListeners();
  }

  /// Ctrl+Shift+Z.
  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(_doc);
    final doc = _redo.removeLast();
    _mutate(doc);
    _selectedKeyTimes.clear();
    notifyListeners();
  }

  // ── snapping ───────────────────────────────────────────────────────────

  /// Snaps [tSec] to the nearest detected beat, half-beat or section start
  /// within [toleranceSec]; returns [tSec] unchanged when nothing is close.
  double snapTime(double tSec, {double toleranceSec = 0.12}) {
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
    sectionStartsSec.forEach(consider);
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

  // ── trail thinning ─────────────────────────────────────────────────────

  /// Ramer–Douglas–Peucker over a touch trail in wheel-space: keeps only the
  /// keys whose look deviates from the linear ramp between kept neighbours by
  /// more than [tolerance], so a played-through ride stays editable and the
  /// JSON stays LLM-readable.
  static List<GradeKeyframe> thinTrail(
    List<GradeKeyframe> trail, {
    double tolerance = kGradeTrailThinTolerance,
  }) {
    if (trail.length <= 2) return List.of(trail);
    final keep = List<bool>.filled(trail.length, false);
    keep[0] = true;
    keep[trail.length - 1] = true;

    void rdp(int from, int to) {
      if (to - from < 2) return;
      final a = trail[from];
      final b = trail[to];
      var worst = 0.0;
      var worstIdx = -1;
      for (var i = from + 1; i < to; i++) {
        final k = trail[i];
        final u = (k.tSec - a.tSec) / (b.tSec - a.tSec);
        final d = lookMaxDiff(k.look, a.look.lerpTo(b.look, u));
        if (d > worst) {
          worst = d;
          worstIdx = i;
        }
      }
      if (worst > tolerance && worstIdx > 0) {
        keep[worstIdx] = true;
        rdp(from, worstIdx);
        rdp(worstIdx, to);
      }
    }

    rdp(0, trail.length - 1);
    return [
      for (var i = 0; i < trail.length; i++)
        if (keep[i]) trail[i],
    ];
  }

  /// The largest per-control difference between two looks, in the same
  /// normalized units as [GradeLook.deviation].
  static double lookMaxDiff(GradeLook a, GradeLook b) {
    double wheel(GradeWheel x, GradeWheel y) => math.max(
      (x.balance - y.balance).distance,
      (x.master - y.master).abs(),
    );
    final parts = [
      wheel(a.lift, b.lift),
      wheel(a.gamma, b.gamma),
      wheel(a.gain, b.gain),
      (a.saturation - b.saturation).abs(),
      (a.temperature - b.temperature).abs(),
      (a.tint - b.tint).abs(),
      (a.contrast - b.contrast).abs() / 0.8,
      (a.pivot - b.pivot).abs(),
    ];
    return parts.reduce(math.max);
  }

  // ── plumbing ───────────────────────────────────────────────────────────

  GradeLane _lane(String target) =>
      _doc.lane(target) ?? GradeLane(target: target);

  GradeTimelineDoc _withLane(GradeLane lane) => _doc.withLane(lane);

  // Every caller opens its own undo transaction (gesture-level, not
  // per-mutation), so this only pushes the document through the store.
  void _mutate(GradeTimelineDoc doc) {
    store.update(doc);
    _shadowDoc = doc;
  }

  void _pushUndo() {
    _undo.add(_doc);
    if (_undo.length > 100) _undo.removeAt(0);
    _redo.clear();
  }

  void _onStore() {
    if (store.eventSerial != _shadowSerial) {
      _shadowSerial = store.eventSerial;
      if (store.lastEvent == DanceGradeStoreEvent.externalReload) {
        // An LLM/human edit landed: one undoable step (Ctrl+Z restores the
        // pre-reload document — the conflict-resolution affordance).
        _undo.add(_shadowDoc);
        _redo.clear();
        _selectedKeyTimes.clear();
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
