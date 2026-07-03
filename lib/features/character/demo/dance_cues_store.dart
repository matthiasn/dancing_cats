import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dancing_cats/features/character/demo/dance_lip_sync_doc.dart';
import 'package:flutter/foundation.dart';

/// What just happened inside the store — the page reads this on notify to
/// drive its toasts/error badge (the same event shape as the colour-grade
/// store's, for the lip-sync cue track).
enum DanceCuesStoreEvent {
  /// Nothing yet / a plain local edit.
  none,

  /// Initial [DanceCuesStore.load] finished.
  loaded,

  /// The debounced autosave (or an explicit save) wrote the file.
  saved,

  /// The file changed on disk (Rhubarb re-run / hand edit) and was
  /// hot-reloaded.
  externalReload,

  /// A local save landed on top of an external change (last-writer-wins,
  /// but never silently).
  externalChangeOverwritten,

  /// The on-disk file does not parse; the last good document is retained and
  /// autosave is suppressed until it parses again or `saveNow` overwrites it.
  fileError,
}

/// Load / debounced-atomic-save / poll-watch for the `<track>.cues.json`
/// side file — a structural copy of the colour-grade store's safety posture
/// (`dance_grade_store.dart`), applied to [LipSyncDoc] instead of the grade
/// timeline. Owns no UI: the demo page listens and reacts.
///
/// - A corrupt file never becomes an empty document that autosave then burns
///   over the real data: the last good in-memory doc is kept, an error state
///   is surfaced, and autosave is suppressed until the file parses again or
///   the user explicitly [saveNow]s.
/// - Before the session's first overwrite the existing file is copied to
///   `<path>.bak` — one known-good checkpoint per session.
/// - Writes are atomic (temp file + rename).
/// - Change detection is by CONTENT, not mtime, so second-granularity
///   filesystems and self-writes cannot confuse the watcher.
class DanceCuesStore extends ChangeNotifier {
  DanceCuesStore({
    required this.path,
    this.saveDebounce = const Duration(milliseconds: 600),
    this.pollInterval = const Duration(seconds: 1),
  });

  /// Absolute path of the cue document.
  final String path;

  /// How long after the last local mutation the autosave fires.
  final Duration saveDebounce;

  /// How often [startWatching] checks the file for external edits.
  final Duration pollInterval;

  LipSyncDoc _doc = LipSyncDoc.empty;

  /// The current document (last good on parse errors).
  LipSyncDoc get doc => _doc;

  bool _fileUnreadable = false;

  /// True while the on-disk file fails to parse (drives the error badge and
  /// suppresses autosave).
  bool get fileUnreadable => _fileUnreadable;

  DanceCuesStoreEvent _event = DanceCuesStoreEvent.none;

  /// The most recent lifecycle event (see [DanceCuesStoreEvent]).
  DanceCuesStoreEvent get lastEvent => _event;

  int _eventSerial = 0;

  /// Increments with every event so listeners can distinguish repeats of the
  /// same event kind.
  int get eventSerial => _eventSerial;

  Timer? _saveTimer;
  Timer? _pollTimer;
  bool _dirty = false;
  bool _bakWritten = false;
  String? _knownContent;

  void _emit(DanceCuesStoreEvent event) {
    _event = event;
    _eventSerial++;
    notifyListeners();
  }

  /// Reads the document. An absent file is an empty doc (a track simply has
  /// no cues yet); a corrupt file surfaces the error state with an empty doc
  /// (there is no last-good yet) and suppresses autosave.
  Future<void> load() async {
    final file = File(path);
    if (!file.existsSync()) {
      _doc = LipSyncDoc.empty;
      _emit(DanceCuesStoreEvent.loaded);
      return;
    }
    String? content;
    try {
      content = await file.readAsString();
      _doc = LipSyncDoc.fromJson(jsonDecode(content) as Map<String, Object?>);
      _knownContent = content;
      _fileUnreadable = false;
      _emit(DanceCuesStoreEvent.loaded);
    } catch (_) {
      _knownContent = content;
      _fileUnreadable = true;
      _emit(DanceCuesStoreEvent.fileError);
    }
  }

  /// Starts the external-edit watcher (idempotent).
  void startWatching() {
    _pollTimer ??= Timer.periodic(pollInterval, (_) => unawaited(pollOnce()));
  }

  /// Replaces the document after a local mutation and schedules the debounced
  /// autosave. Listeners are notified immediately (playback reads the new
  /// cues next frame; the disk catches up).
  void update(LipSyncDoc doc) {
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
          ? DanceCuesStoreEvent.externalChangeOverwritten
          : DanceCuesStoreEvent.saved,
    );
  }

  /// One watcher tick (the periodic timer calls this; tests call it
  /// directly). External content change with no pending local edit →
  /// hot-reload (or error state on a corrupt write). With a local edit
  /// pending, the conflict resolves at save time as
  /// [DanceCuesStoreEvent.externalChangeOverwritten].
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
      _doc = LipSyncDoc.fromJson(jsonDecode(content) as Map<String, Object?>);
      _knownContent = content;
      _fileUnreadable = false;
      _emit(DanceCuesStoreEvent.externalReload);
    } catch (_) {
      // Keep the last GOOD document on screen; remember the bad content so
      // the same broken write doesn't re-fire every tick.
      _knownContent = content;
      _fileUnreadable = true;
      _emit(DanceCuesStoreEvent.fileError);
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }
}
