import 'dart:convert';

import 'package:dancing_cats/features/character/demo/dance_lip_sync.dart';
import 'package:dancing_cats/features/character/demo/dance_lip_sync_doc.dart';
import 'package:flutter_test/flutter_test.dart';

DanceCue _cue(double start, double end, String shape) =>
    (start: start, end: end, shape: shape);

/// Three contiguous cues covering 0..3s: X, B, C.
LipSyncDoc _doc() => const LipSyncDoc(
  cues: [
    (start: 0, end: 1, shape: 'X'),
    (start: 1, end: 2, shape: 'B'),
    (start: 2, end: 3, shape: 'C'),
  ],
);

void main() {
  group('LipSyncDoc.fromJson / toJson', () {
    test('round-trips cues and the audio/lipsync metadata verbatim', () {
      final json = {
        'schema_version': '1.0',
        'audio': {'path': '/tmp/track.wav', 'duration_sec': 144.0},
        'lipsync': {'engine': 'rhubarb', 'recognizer': 'phonetic'},
        'cues': [
          {'start_sec': 0.0, 'end_sec': 2.06, 'shape': 'X'},
          {'start_sec': 2.06, 'end_sec': 2.1, 'shape': 'B'},
        ],
      };
      final doc = LipSyncDoc.fromJson(json);
      expect(doc.schemaVersion, '1.0');
      expect(doc.audio, {'path': '/tmp/track.wav', 'duration_sec': 144.0});
      expect(doc.lipsync, {'engine': 'rhubarb', 'recognizer': 'phonetic'});
      expect(doc.cues, [_cue(0, 2.06, 'X'), _cue(2.06, 2.1, 'B')]);

      final back = LipSyncDoc.fromJson(
        jsonDecode(jsonEncode(doc.toJson())) as Map<String, Object?>,
      );
      expect(back.schemaVersion, doc.schemaVersion);
      expect(back.audio, doc.audio);
      expect(back.lipsync, doc.lipsync);
      expect(back.cues, doc.cues);
    });

    test('missing metadata blocks default to empty/1.0', () {
      final doc = LipSyncDoc.fromJson(const {
        'cues': [
          {'start_sec': 0.0, 'end_sec': 1.0, 'shape': 'A'},
        ],
      });
      expect(doc.schemaVersion, '1.0');
      expect(doc.audio, isEmpty);
      expect(doc.lipsync, isEmpty);
    });

    test('the empty document has no cues', () {
      expect(LipSyncDoc.empty.cues, isEmpty);
    });
  });

  group('indexAt', () {
    test('finds the cue spanning a time (half-open)', () {
      final doc = _doc();
      expect(doc.indexAt(0), 0);
      expect(doc.indexAt(0.999), 0);
      expect(doc.indexAt(1), 1); // boundary belongs to the NEXT cue
      expect(doc.indexAt(2.5), 2);
    });

    test('null outside the track', () {
      final doc = _doc();
      expect(doc.indexAt(-1), isNull);
      expect(doc.indexAt(3), isNull); // at/after the last cue's end
    });
  });

  group('moveBoundary', () {
    test('retimes the shared edge between two cues', () {
      final next = _doc().moveBoundary(0, 1.4);
      expect(next.cues[0], _cue(0, 1.4, 'X'));
      expect(next.cues[1], _cue(1.4, 2, 'B'));
      expect(next.cues[2], _cue(2, 3, 'C')); // untouched
    });

    test('clamps so neither side drops below the minimum duration', () {
      final doc = _doc();
      final tooEarly = doc.moveBoundary(0, -5);
      expect(tooEarly.cues[0].end, closeTo(kMinCueDurationSec, 1e-9));
      final tooLate = doc.moveBoundary(0, 5);
      expect(tooLate.cues[1].start, closeTo(2 - kMinCueDurationSec, 1e-9));
    });

    test('is a no-op when boxed in by both neighbours at the floor', () {
      // cues[1] and cues[2] together span less than 2*kMinCueDurationSec, so
      // no position satisfies both floors at once.
      const half = kMinCueDurationSec / 2;
      final boxed = LipSyncDoc(
        cues: [
          _cue(0, 1, 'X'),
          _cue(1, 1 + half, 'B'),
          _cue(1 + half, 1 + kMinCueDurationSec, 'C'),
        ],
      );
      expect(boxed.moveBoundary(1, 1 + half), same(boxed));
    });

    test('is a no-op for an out-of-range index', () {
      final doc = _doc();
      expect(doc.moveBoundary(-1, 1), same(doc));
      expect(doc.moveBoundary(2, 1), same(doc)); // last cue has no successor
    });
  });

  group('setShape', () {
    test("replaces one cue's shape, leaving timing untouched", () {
      final next = _doc().setShape(1, 'D');
      expect(next.cues[1], _cue(1, 2, 'D'));
      expect(next.cues[0], _cue(0, 1, 'X'));
    });

    test('is a no-op for an out-of-range index', () {
      final doc = _doc();
      expect(doc.setShape(-1, 'D'), same(doc));
      expect(doc.setShape(3, 'D'), same(doc));
    });
  });

  group('splitAt', () {
    test('inserts a boundary, both halves keeping the source shape', () {
      final next = _doc().splitAt(1.5);
      expect(next.cues, hasLength(4));
      expect(next.cues[1], _cue(1, 1.5, 'B'));
      expect(next.cues[2], _cue(1.5, 2, 'B'));
    });

    test('is a no-op outside any cue', () {
      final doc = _doc();
      expect(doc.splitAt(-1), same(doc));
      expect(doc.splitAt(3), same(doc));
    });

    test('is a no-op within the minimum duration of an existing boundary', () {
      final doc = _doc();
      expect(doc.splitAt(1 + kMinCueDurationSec / 2), same(doc));
      expect(doc.splitAt(2 - kMinCueDurationSec / 2), same(doc));
    });
  });

  group('mergeBoundaryAfter', () {
    test('swallows the next cue, keeping the left shape', () {
      final next = _doc().mergeBoundaryAfter(0);
      expect(next.cues, [_cue(0, 2, 'X'), _cue(2, 3, 'C')]);
    });

    test('is a no-op for an out-of-range index', () {
      final doc = _doc();
      expect(doc.mergeBoundaryAfter(-1), same(doc));
      expect(doc.mergeBoundaryAfter(2), same(doc));
    });
  });
}
