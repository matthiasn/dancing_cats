import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dancing_cats/features/scenery/model/grade_timeline.dart';
import 'package:flutter/foundation.dart';

/// Derives the grade side-file path from the beat-map path, following the
/// side-file naming family (`moving.json` → `moving.grade.json`).
String danceGradePathForBeatMap(String beatMapPath) =>
    beatMapPath.endsWith('.json')
    ? '${beatMapPath.substring(0, beatMapPath.length - 5)}.grade.json'
    : '$beatMapPath.grade.json';

/// What just happened inside the store — the page reads this on notify to
/// drive its toasts ("reloaded from disk", "external change overwritten"),
/// the error badge, and the undo-stack entry for an external reload.
enum DanceGradeStoreEvent {
  /// Nothing yet / a plain local edit.
  none,

  /// Initial [DanceGradeStore.load] finished.
  loaded,

  /// The debounced autosave (or an explicit save) wrote the file.
  saved,

  /// The file changed on disk (LLM/human edit) and was hot-reloaded.
  externalReload,

  /// A local save landed on top of an external change (last-writer-wins is
  /// the policy, but never silently — ADR 0002 §5).
  externalChangeOverwritten,

  /// The on-disk file does not parse; the last good document is retained and
  /// autosave is suppressed until it parses again or `saveNow` overwrites it.
  fileError,
}

/// Load / debounced-atomic-save / poll-watch for the `<track>.grade.json`
/// side file (ADR 0002 §5). Owns no UI: the demo page listens and reacts.
///
/// Safety posture (panel-revised):
/// - A corrupt file NEVER becomes an empty document that autosave then burns
///   over the real data: the last good in-memory doc is kept, an error state
///   is surfaced, and autosave is suppressed until the file parses again or
///   the user explicitly [saveNow]s.
/// - Before the session's first overwrite the existing file is copied to
///   `<path>.bak` — one known-good checkpoint per session.
/// - Writes are atomic (temp file + rename) and always FULL looks (the model
///   serializes explicitly; sparse-with-inheritance is an input convenience).
/// - Change detection is by CONTENT, not mtime, so second-granularity
///   filesystems and self-writes cannot confuse the watcher.
class DanceGradeStore extends ChangeNotifier {
  DanceGradeStore({
    required this.path,
    this.saveDebounce = const Duration(milliseconds: 600),
    this.pollInterval = const Duration(seconds: 1),
  });

  /// Absolute path of the grade document.
  final String path;

  /// How long after the last local mutation the autosave fires.
  final Duration saveDebounce;

  /// How often [startWatching] checks the file for external edits.
  final Duration pollInterval;

  GradeTimelineDoc _doc = GradeTimelineDoc.empty;

  /// The current document (last good on parse errors).
  GradeTimelineDoc get doc => _doc;

  bool _fileUnreadable = false;

  /// True while the on-disk file fails to parse (drives the error badge and
  /// suppresses autosave).
  bool get fileUnreadable => _fileUnreadable;

  DanceGradeStoreEvent _event = DanceGradeStoreEvent.none;

  /// The most recent lifecycle event (see [DanceGradeStoreEvent]).
  DanceGradeStoreEvent get lastEvent => _event;

  int _eventSerial = 0;

  /// Increments with every event so listeners can distinguish repeats of the
  /// same event kind.
  int get eventSerial => _eventSerial;

  Timer? _saveTimer;
  Timer? _pollTimer;
  bool _dirty = false;
  bool _bakWritten = false;
  String? _knownContent;

  void _emit(DanceGradeStoreEvent event) {
    _event = event;
    _eventSerial++;
    notifyListeners();
  }

  /// Reads the document. An absent file is an empty doc (a track simply has
  /// no grade yet); a corrupt file surfaces the error state with an empty doc
  /// (there is no last-good yet) and suppresses autosave.
  Future<void> load() async {
    final file = File(path);
    if (!file.existsSync()) {
      _doc = GradeTimelineDoc.empty;
      _emit(DanceGradeStoreEvent.loaded);
      return;
    }
    String? content;
    try {
      content = await file.readAsString();
      _doc = GradeTimelineDoc.fromJson(
        jsonDecode(content) as Map<String, Object?>,
      );
      _knownContent = content;
      _fileUnreadable = false;
      _emit(DanceGradeStoreEvent.loaded);
    } catch (_) {
      _knownContent = content;
      _fileUnreadable = true;
      _emit(DanceGradeStoreEvent.fileError);
    }
  }

  /// Starts the external-edit watcher (idempotent).
  void startWatching() {
    _pollTimer ??= Timer.periodic(pollInterval, (_) => unawaited(pollOnce()));
  }

  /// Replaces the document after a local mutation and schedules the debounced
  /// autosave. Listeners are notified immediately (the stage re-grades now;
  /// the disk catches up).
  void update(GradeTimelineDoc doc) {
    _doc = doc;
    _dirty = true;
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDebounce, () => unawaited(_save()));
  }

  /// Forces any pending debounced save to land now (page teardown, tests).
  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (_dirty) await _save();
  }

  /// The explicit-overwrite escape hatch for the error state: clears the
  /// unreadable flag and writes the current document unconditionally.
  Future<void> saveNow() async {
    _fileUnreadable = false;
    _saveTimer?.cancel();
    _saveTimer = null;
    _dirty = true;
    await _save();
  }

  Future<void> _save() async {
    if (_fileUnreadable) return; // suppressed until the file parses again
    final file = File(path);
    var overwroteExternal = false;
    if (file.existsSync()) {
      try {
        final current = await file.readAsString();
        overwroteExternal = _knownContent != null && current != _knownContent;
        if (!_bakWritten) {
          await file.copy('$path.bak');
          _bakWritten = true;
        }
      } catch (_) {
        // Unreadable-on-save is fine — the atomic rename below replaces it.
      }
    }
    final content =
        '${const JsonEncoder.withIndent('  ').convert(_doc.toJson())}\n';
    final tmp = File('$path.tmp');
    tmp.parent.createSync(recursive: true);
    await tmp.writeAsString(content, flush: true);
    await tmp.rename(path);
    _knownContent = content;
    _dirty = false;
    _emit(
      overwroteExternal
          ? DanceGradeStoreEvent.externalChangeOverwritten
          : DanceGradeStoreEvent.saved,
    );
  }

  /// One watcher tick (the periodic timer calls this; tests call it
  /// directly). External content change with no pending local edit →
  /// hot-reload (or error state on a corrupt write). With a local edit
  /// pending, the conflict resolves at save time as
  /// [DanceGradeStoreEvent.externalChangeOverwritten].
  Future<void> pollOnce() async {
    final file = File(path);
    if (!file.existsSync()) return;
    String content;
    try {
      content = await file.readAsString();
    } catch (_) {
      return; // transient IO hiccup; try again next tick
    }
    if (content == _knownContent) return;
    if (_dirty || (_saveTimer?.isActive ?? false)) return;
    try {
      _doc = GradeTimelineDoc.fromJson(
        jsonDecode(content) as Map<String, Object?>,
      );
      _knownContent = content;
      _fileUnreadable = false;
      _emit(DanceGradeStoreEvent.externalReload);
    } catch (_) {
      // Keep the last GOOD document on screen; remember the bad content so
      // the same broken write doesn't re-fire every tick.
      _knownContent = content;
      _fileUnreadable = true;
      _emit(DanceGradeStoreEvent.fileError);
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }
}
