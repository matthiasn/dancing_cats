import 'dart:convert';
import 'dart:io';

import 'package:dancing_cats/features/character/demo/dance_grade_store.dart';
import 'package:dancing_cats/features/scenery/model/grade_timeline.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../dance_store_test_utils.dart';

GradeTimelineDoc _doc({double saturation = 0.8, double t = 0}) =>
    GradeTimelineDoc(
      lanes: [
        GradeLane(
          target: GradeTargets.master,
          keyframes: [
            GradeKeyframe(
              tSec: t,
              look: GradeLook(saturation: saturation),
            ),
          ],
        ),
      ],
    );

String _docJson({double saturation = 0.8}) =>
    jsonEncode(_doc(saturation: saturation).toJson());

void main() {
  late Directory dir;
  late String path;
  late DanceGradeStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('grade_store_test');
    path = p.join(dir.path, 'moving.grade.json');
    store = DanceGradeStore(
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

  group('danceGradePathForBeatMap', () {
    test('replaces .json with .grade.json', () {
      expect(
        danceGradePathForBeatMap('assets/sample_track/moving.json'),
        'assets/sample_track/moving.grade.json',
      );
    });

    test('appends for a non-.json path', () {
      expect(danceGradePathForBeatMap('/tmp/track'), '/tmp/track.grade.json');
    });
  });

  group('load', () {
    test('an absent file is an empty document (no grade yet)', () async {
      await store.load();
      expect(store.doc.lanes, isEmpty);
      expect(store.fileUnreadable, isFalse);
      expect(store.lastEvent, DanceGradeStoreEvent.loaded);
    });

    test('a valid file parses into the document', () async {
      File(path).writeAsStringSync(_docJson(saturation: 0.7));
      await store.load();
      expect(store.doc.lane(GradeTargets.master), isNotNull);
      expect(store.doc.evaluate(0)[GradeTargets.master]!.saturation, 0.7);
    });

    test(
      'a corrupt file surfaces the error state (no last-good yet)',
      () async {
        File(path).writeAsStringSync('{"version": 1, "lanes": [');
        await store.load();
        expect(store.doc.lanes, isEmpty);
        expect(store.fileUnreadable, isTrue);
        expect(store.lastEvent, DanceGradeStoreEvent.fileError);
      },
    );
  });

  group('save', () {
    test(
      'update schedules; flush writes an atomic, re-parseable file',
      () async {
        await store.load();
        store.update(_doc(saturation: 0.6));
        expect(File(path).existsSync(), isFalse); // debounced, not yet
        await store.flush();
        final json =
            jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
        final back = GradeTimelineDoc.fromJson(json);
        expect(back.evaluate(0)[GradeTargets.master]!.saturation, 0.6);
        expect(store.lastEvent, DanceGradeStoreEvent.saved);
        expect(File('$path.tmp').existsSync(), isFalse); // renamed away
      },
    );

    test('the first overwrite of a session leaves a .bak checkpoint', () async {
      File(path).writeAsStringSync(_docJson(saturation: 0.9));
      await store.load();
      store.update(_doc(saturation: 0.5));
      await store.flush();
      store.update(_doc(saturation: 0.4));
      await store.flush();
      // The .bak holds the ORIGINAL pre-session content, written once.
      final bak =
          jsonDecode(File('$path.bak').readAsStringSync())
              as Map<String, Object?>;
      expect(
        GradeTimelineDoc.fromJson(
          bak,
        ).evaluate(0)[GradeTargets.master]!.saturation,
        0.9,
      );
    });

    test('no .bak when the file did not exist before the first save', () async {
      await store.load();
      store.update(_doc());
      await store.flush();
      expect(File('$path.bak').existsSync(), isFalse);
    });

    test('autosave is suppressed while the file is unreadable', () async {
      const bad = '{"lanes": [broken';
      File(path).writeAsStringSync(bad);
      await store.load();
      store.update(_doc(saturation: 0.3));
      await store.flush();
      // The broken file was NOT overwritten by the suppressed autosave.
      expect(File(path).readAsStringSync(), bad);
      // The explicit overwrite path writes and clears the error state.
      await store.saveNow();
      expect(store.fileUnreadable, isFalse);
      final back = GradeTimelineDoc.fromJson(
        jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>,
      );
      expect(back.evaluate(0)[GradeTargets.master]!.saturation, 0.3);
    });
  });

  group('watch', () {
    test('an external edit hot-reloads the document', () async {
      File(path).writeAsStringSync(_docJson(saturation: 0.9));
      await store.load();
      File(path).writeAsStringSync(_docJson(saturation: 0.2));
      await store.pollOnce();
      expect(store.doc.evaluate(0)[GradeTargets.master]!.saturation, 0.2);
      expect(store.lastEvent, DanceGradeStoreEvent.externalReload);
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
      File(path).writeAsStringSync(_docJson(saturation: 0.9));
      await store.load();
      File(path).writeAsStringSync('not json at all');
      await store.pollOnce();
      // Screen keeps the authored grade; the error badge lights instead.
      expect(store.doc.evaluate(0)[GradeTargets.master]!.saturation, 0.9);
      expect(store.fileUnreadable, isTrue);
      expect(store.lastEvent, DanceGradeStoreEvent.fileError);
      // The same broken content does not spam a fresh event every tick.
      final serial = store.eventSerial;
      await store.pollOnce();
      expect(store.eventSerial, serial);
      // A fixed file recovers: reload + autosave re-enabled.
      File(path).writeAsStringSync(_docJson(saturation: 0.4));
      await store.pollOnce();
      expect(store.fileUnreadable, isFalse);
      expect(store.doc.evaluate(0)[GradeTargets.master]!.saturation, 0.4);
    });

    test(
      'a reload never fires mid-edit; the save reports the overwrite',
      () async {
        File(path).writeAsStringSync(_docJson(saturation: 0.9));
        await store.load();
        store.update(_doc(saturation: 0.5)); // local edit pending
        File(path).writeAsStringSync(_docJson(saturation: 0.1)); // LLM writes
        await store.pollOnce();
        // The external content must not clobber the in-flight local edit…
        expect(store.doc.evaluate(0)[GradeTargets.master]!.saturation, 0.5);
        await store.flush();
        // …and the landing save declares last-writer-wins out loud.
        expect(store.lastEvent, DanceGradeStoreEvent.externalChangeOverwritten);
        final back = GradeTimelineDoc.fromJson(
          jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>,
        );
        expect(back.evaluate(0)[GradeTargets.master]!.saturation, 0.5);
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
      expect(store.doc.isEmpty, isFalse); // keeps the loaded doc
    });

    test('startWatching polls on the timer and dispose stops it', () async {
      final fast = DanceGradeStore(
        path: path,
        saveDebounce: const Duration(milliseconds: 10),
        pollInterval: const Duration(milliseconds: 20),
      );
      File(path).writeAsStringSync(_docJson(saturation: 0.9));
      await fast.load();
      fast
        ..startWatching()
        ..startWatching(); // idempotent
      File(path).writeAsStringSync(_docJson(saturation: 0.25));
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(fast.doc.evaluate(0)[GradeTargets.master]!.saturation, 0.25);
      fast.dispose();
    });

    test('the debounced autosave fires on its own timer', () async {
      final fast = DanceGradeStore(
        path: path,
        saveDebounce: const Duration(milliseconds: 10),
        pollInterval: kTestStorePollInterval,
      );
      await fast.load();
      fast.update(_doc(saturation: 0.65));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(File(path).existsSync(), isTrue);
      final back = GradeTimelineDoc.fromJson(
        jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>,
      );
      expect(back.evaluate(0)[GradeTargets.master]!.saturation, 0.65);
      fast.dispose();
    });
  });
}
