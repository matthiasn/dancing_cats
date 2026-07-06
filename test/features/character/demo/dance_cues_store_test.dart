import 'dart:convert';
import 'dart:io';

import 'package:dancing_cats/features/character/demo/dance_cues_store.dart';
import 'package:dancing_cats/features/character/demo/dance_lip_sync_doc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../dance_store_test_utils.dart';

LipSyncDoc _doc({String shape = 'B'}) => LipSyncDoc(
  cues: [
    (start: 0.0, end: 1.0, shape: 'X'),
    (start: 1.0, end: 2.0, shape: shape),
  ],
  audio: const {'path': '/tmp/t.wav', 'duration_sec': 2.0},
  lipsync: const {'engine': 'rhubarb'},
);

String _docJson({String shape = 'B'}) =>
    jsonEncode(_doc(shape: shape).toJson());

void main() {
  late Directory dir;
  late String path;
  late DanceCuesStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('cues_store_test');
    path = p.join(dir.path, 'moving.cues.json');
    store = DanceCuesStore(
      path: path,
      // Long timers: tests drive flush()/pollOnce() directly.
      saveDebounce: kTestStoreSaveDebounce,
      pollInterval: kTestStorePollInterval,
    );
  });

  tearDown(() {
    store.dispose();
    dir.deleteSync(recursive: true);
  });

  group('load', () {
    test('an absent file is an empty document (no cues yet)', () async {
      await store.load();
      expect(store.doc.cues, isEmpty);
      expect(store.fileUnreadable, isFalse);
      expect(store.lastEvent, DanceCuesStoreEvent.loaded);
    });

    test('a valid file parses into the document', () async {
      File(path).writeAsStringSync(_docJson(shape: 'C'));
      await store.load();
      expect(store.doc.cues.last.shape, 'C');
      expect(store.doc.audio, {'path': '/tmp/t.wav', 'duration_sec': 2.0});
      expect(store.doc.lipsync, {'engine': 'rhubarb'});
    });

    test(
      'a corrupt file surfaces the error state (no last-good yet)',
      () async {
        File(path).writeAsStringSync('{"cues": [');
        await store.load();
        expect(store.doc.cues, isEmpty);
        expect(store.fileUnreadable, isTrue);
        expect(store.lastEvent, DanceCuesStoreEvent.fileError);
      },
    );
  });

  group('save', () {
    test(
      'update schedules; flush writes an atomic, re-parseable file',
      () async {
        await store.load();
        store.update(_doc(shape: 'D'));
        expect(File(path).existsSync(), isFalse); // debounced, not yet
        await store.flush();
        final json =
            jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
        final back = LipSyncDoc.fromJson(json);
        expect(back.cues.last.shape, 'D');
        expect(store.lastEvent, DanceCuesStoreEvent.saved);
        expect(File('$path.tmp').existsSync(), isFalse); // renamed away
      },
    );

    test('the first overwrite of a session leaves a .bak checkpoint', () async {
      File(path).writeAsStringSync(_docJson(shape: 'E'));
      await store.load();
      store.update(_doc(shape: 'F'));
      await store.flush();
      store.update(_doc(shape: 'G'));
      await store.flush();
      // The .bak holds the ORIGINAL pre-session content, written once.
      final bak =
          jsonDecode(File('$path.bak').readAsStringSync())
              as Map<String, Object?>;
      expect(LipSyncDoc.fromJson(bak).cues.last.shape, 'E');
    });

    test('no .bak when the file did not exist before the first save', () async {
      await store.load();
      store.update(_doc());
      await store.flush();
      expect(File('$path.bak').existsSync(), isFalse);
    });

    test('autosave is suppressed while the file is unreadable', () async {
      const bad = '{"cues": [broken';
      File(path).writeAsStringSync(bad);
      await store.load();
      store.update(_doc(shape: 'H'));
      await store.flush();
      // The broken file was NOT overwritten by the suppressed autosave.
      expect(File(path).readAsStringSync(), bad);
      // The explicit overwrite path writes and clears the error state.
      await store.saveNow();
      expect(store.fileUnreadable, isFalse);
      final back = LipSyncDoc.fromJson(
        jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>,
      );
      expect(back.cues.last.shape, 'H');
    });
  });

  group('watch', () {
    test('an external edit hot-reloads the document', () async {
      File(path).writeAsStringSync(_docJson());
      await store.load();
      File(path).writeAsStringSync(_docJson(shape: 'C'));
      await store.pollOnce();
      expect(store.doc.cues.last.shape, 'C');
      expect(store.lastEvent, DanceCuesStoreEvent.externalReload);
    });

    test('an unchanged file does not re-fire events', () async {
      File(path).writeAsStringSync(_docJson());
      await store.load();
      final serial = store.eventSerial;
      await store.pollOnce();
      await store.pollOnce();
      expect(store.eventSerial, serial);
    });

    test('a corrupt external write keeps the last GOOD document', () async {
      File(path).writeAsStringSync(_docJson());
      await store.load();
      File(path).writeAsStringSync('not json at all');
      await store.pollOnce();
      // Screen keeps the authored cues; the error badge lights instead.
      expect(store.doc.cues.last.shape, 'B');
      expect(store.fileUnreadable, isTrue);
      expect(store.lastEvent, DanceCuesStoreEvent.fileError);
      // The same broken content does not spam a fresh event every tick.
      final serial = store.eventSerial;
      await store.pollOnce();
      expect(store.eventSerial, serial);
      // A fixed file recovers: reload + autosave re-enabled.
      File(path).writeAsStringSync(_docJson(shape: 'D'));
      await store.pollOnce();
      expect(store.fileUnreadable, isFalse);
      expect(store.doc.cues.last.shape, 'D');
    });

    test(
      'a reload never fires mid-edit; the save reports the overwrite',
      () async {
        File(path).writeAsStringSync(_docJson());
        await store.load();
        store.update(_doc(shape: 'C')); // local edit pending
        File(path).writeAsStringSync(_docJson(shape: 'D')); // Rhubarb writes
        await store.pollOnce();
        // The external content must not clobber the in-flight local edit…
        expect(store.doc.cues.last.shape, 'C');
        await store.flush();
        // …and the landing save declares last-writer-wins out loud.
        expect(store.lastEvent, DanceCuesStoreEvent.externalChangeOverwritten);
        final back = LipSyncDoc.fromJson(
          jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>,
        );
        expect(back.cues.last.shape, 'C');
      },
    );

    test('the store ignores its own writes', () async {
      await store.load();
      store.update(_doc());
      await store.flush();
      final serial = store.eventSerial;
      await store.pollOnce(); // sees exactly what it wrote
      expect(store.eventSerial, serial);
    });

    test('a deleted file is tolerated (nothing to poll)', () async {
      File(path).writeAsStringSync(_docJson());
      await store.load();
      File(path).deleteSync();
      await store.pollOnce();
      expect(store.doc.cues, isNotEmpty); // keeps the loaded doc
    });

    test('startWatching polls on the timer and dispose stops it', () async {
      final fast = DanceCuesStore(
        path: path,
        saveDebounce: const Duration(milliseconds: 10),
        pollInterval: const Duration(milliseconds: 20),
      );
      File(path).writeAsStringSync(_docJson());
      await fast.load();
      fast
        ..startWatching()
        ..startWatching(); // idempotent
      File(path).writeAsStringSync(_docJson(shape: 'E'));
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(fast.doc.cues.last.shape, 'E');
      fast.dispose();
    });

    test('the debounced autosave fires on its own timer', () async {
      final fast = DanceCuesStore(
        path: path,
        saveDebounce: const Duration(milliseconds: 10),
        pollInterval: kTestStorePollInterval,
      );
      await fast.load();
      fast.update(_doc(shape: 'F'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(File(path).existsSync(), isTrue);
      final back = LipSyncDoc.fromJson(
        jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>,
      );
      expect(back.cues.last.shape, 'F');
      fast.dispose();
    });
  });
}
