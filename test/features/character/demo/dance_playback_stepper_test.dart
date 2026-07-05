import 'package:dancing_cats/features/character/demo/dance_performance.dart';
import 'package:dancing_cats/features/character/demo/dance_playback_stepper.dart';
import 'package:dancing_cats/features/character/model/beat_map.dart';
import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/face.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';
import 'package:flutter_test/flutter_test.dart';

BeatMap _beatMap() => BeatMap(
  beatTimesSec: [for (var i = 0; i < 13; i++) i * 0.5],
  downbeatIndices: const [0, 4, 8, 12],
);

DancePerformance _perf({
  List<DanceWord> words = const [],
  List<DanceSectionSpan> sectionSpans = const [],
}) {
  final map = _beatMap();
  return DancePerformance(
    map: map,
    binding: BeatLoopBinding.barAligned(map, bars: kDancePhraseBars),
    sections: const [
      (start: 0, end: 6, label: 'A', energetic: true, level: 1),
    ],
    sectionSpans: sectionSpans,
    trackDurationSec: 6,
    words: words,
  );
}

void main() {
  group('DancePlaybackStepper', () {
    test(
      'before the track loads (null perf) the trio idles and shot holds',
      () {
        final stepper = DancePlaybackStepper()
          ..advance(null, const [], 1, 0.016);
        expect(stepper.stage?.lead.name, 'idle');
        expect(stepper.leadMouth, 0);
        expect(stepper.bgMouth, 0);
        // No director context → the camera holds its neutral framing.
        expect(stepper.shot, (zoom: 1.0, dx: 0.0, dy: 0.0));
      },
    );

    test('an active lip-sync cue opens the frontman mouth', () {
      // 'D' is the widest viseme (open 0.6); no lyrics → the frontman lip-syncs.
      const cues = [(start: 0.0, end: 1.0, shape: 'D')];
      final stepper = DancePlaybackStepper()..advance(_perf(), cues, 0.5, 0.06);
      expect(stepper.leadMouth, greaterThan(0.4));
      expect(stepper.leadShape, MouthShape.singAh);
    });

    test('the mouth eases back toward shut once the cue ends', () {
      const cues = [(start: 0.0, end: 0.4, shape: 'D')];
      final perf = _perf();
      final stepper = DancePlaybackStepper()..advance(perf, cues, 0.3, 0.06);
      final opened = stepper.leadMouth;
      stepper.advance(perf, cues, 0.6, 0.06); // past the cue → target 0
      expect(stepper.leadMouth, lessThan(opened));
    });

    test('the stage tracks the performance derivation', () {
      final stepper = DancePlaybackStepper()
        ..advance(_perf(), const [], 2, 0.06);
      // Energetic section at full level → the unison Buga hit.
      expect(stepper.stage?.lead.name, 'buga');
    });

    test('smooths catalogue move changes instead of hard cutting', () {
      final perf = _perf(
        sectionSpans: const [(start: 0, end: 6, section: 'chorus')],
      );
      final stepper = DancePlaybackStepper()
        // Chorus phase 0.54 is before the Buga handoff, so variant 0 uses Zanku.
        ..advance(perf, const [], 3.24, 0.016);
      expect(stepper.stage?.lead.name, 'zanku');

      // Cross the choreography handoff at chorus phase 0.55. The raw derivation
      // is now Buga, but the cut is BEAT-QUANTIZED: the outgoing Zanku keeps
      // dancing (held on the shared clock) until the next detected beat at
      // 3.5s, so ballistic outgoing limbs resolve onto a count instead of
      // being amputated mid-flight (transitions panel r1).
      stepper.advance(perf, const [], 3.36, 0.016);
      expect(stepper.stage?.lead.name, 'zanku');

      // The beat lands — now the stepper exposes the transient blended clip
      // so the renderer does not jump from one full-body pose to another.
      stepper.advance(perf, const [], 3.52, 0.016);
      final mixed = stepper.stage!;
      expect(mixed.lead.name, 'zanku->buga');
      expect(mixed.lead.root, isA<BlendedRootChannel>());
      expect(
        mixed.lead.channels.values,
        everyElement(isA<BlendedJointChannel>()),
      );
      expect(
        mixed.lead.limbTargets.map((target) => target.channel),
        everyElement(isA<BlendedIkTargetChannel>()),
      );
      final root = mixed.lead.root as BlendedRootChannel;
      final rightHand =
          mixed.lead.limbTargets
                  .singleWhere((target) => target.endBoneId == CatBones.handR)
                  .channel
              as BlendedIkTargetChannel;
      final tail = mixed.lead.channels[CatBones.tail6]! as BlendedJointChannel;
      expect(
        root.weight,
        greaterThan(rightHand.weight),
        reason:
            'dance move transitions should settle body/contact before hand IK '
            'targets start chasing the incoming move',
      );
      expect(
        tail.weight,
        0,
        reason:
            'secondary tail/ear/tie motion should follow the transition last, '
            'not reset on the same frame as the primary body',
      );

      for (var i = 0; i < 20; i++) {
        stepper.advance(perf, const [], 3.54 + i * 0.016, 0.016);
      }
      expect(stepper.stage?.lead.name, 'buga');
    });

    test('an incoming move enters on its own bar 1 (segment re-anchor)', () {
      final perf = _perf(
        sectionSpans: const [(start: 0, end: 6, section: 'chorus')],
      );
      final stepper = DancePlaybackStepper();
      // Walk across the 3.3s Zanku->Buga handoff. Buga's choreo statement
      // starts at 3.3; the first downbeat at/after it is 4.0s (beat index
      // 8), so Buga's phrase clock must re-anchor there: its bar 1 lands ON
      // that downbeat instead of whatever phase the global grid dictated.
      for (var t = 3.2; t < 4.0; t += 0.016) {
        stepper.advance(perf, const [], t, 0.016);
      }
      stepper.advance(perf, const [], 4.02, 0.016);
      expect(stepper.stage?.lead.name, 'buga');
      final duration = stepper.stage!.lead.duration;
      expect(
        stepper.stage!.seconds,
        lessThan(duration / 8),
        reason:
            'just past the segment-anchor downbeat the incoming clip should '
            'be at the very start of its own bar 1, not mid-phrase',
      );
    });

    test('in an energetic section the camera moves off its neutral hold', () {
      final perf = _perf();
      final stepper = DancePlaybackStepper();
      for (var i = 0; i < 30; i++) {
        stepper.advance(perf, const [], 0.5 + i * 0.06, 0.06);
      }
      final shot = stepper.shot;
      expect(
        shot.zoom != 1.0 || shot.dx != 0.0 || shot.dy != 0.0,
        isTrue,
        reason: 'the director drives the framing away from the neutral hold',
      );
    });

    test('background-only words leave the frontman silent', () {
      const cues = [(start: 0.0, end: 1.0, shape: 'D')];
      final perf = _perf(
        words: const [
          (start: 0, end: 2, word: 'la', voice: 'background', section: 'verse'),
        ],
      );
      final stepper = DancePlaybackStepper()..advance(perf, cues, 0.5, 0.06);
      // The lead has lyrics but isn't singing now → frontman mouth rests.
      expect(stepper.leadMouth, 0);
      // The backup IS singing → its mouth opens.
      expect(stepper.bgMouth, greaterThan(0.4));
    });

    test(
      'a lead word drives the frontman via voiceActive (not words.isEmpty)',
      () {
        const cues = [(start: 0.0, end: 1.0, shape: 'D')];
        final perf = _perf(
          words: const [
            (start: 0, end: 2, word: 'go', voice: 'lead', section: 'verse'),
          ],
        );
        final stepper = DancePlaybackStepper()..advance(perf, cues, 0.5, 0.06);
        expect(stepper.leadMouth, greaterThan(0.4));
        // A verse (not a group hook) → the backups stay shut.
        expect(stepper.bgMouth, 0);
      },
    );

    test('on a group-hook section the backups join the lead word', () {
      const cues = [(start: 0.0, end: 1.0, shape: 'D')];
      final perf = _perf(
        words: const [
          (start: 0, end: 2, word: 'oh', voice: 'lead', section: 'chorus'),
        ],
      );
      final stepper = DancePlaybackStepper()..advance(perf, cues, 0.5, 0.06);
      expect(stepper.leadMouth, greaterThan(0.4));
      // 'chorus' is a group hook → the backups sing the lead word too.
      expect(stepper.bgMouth, greaterThan(0.4));
    });

    test('the backup viseme getter tracks the active cue on a group hook', () {
      // 'B' is the singEe viseme, distinct from the singAh rest default, so the
      // bgShape getter demonstrably reflects the cue the backups are singing.
      const cues = [(start: 0.0, end: 1.0, shape: 'B')];
      final perf = _perf(
        words: const [
          (start: 0, end: 2, word: 'oh', voice: 'lead', section: 'chorus'),
        ],
      );
      final stepper = DancePlaybackStepper()..advance(perf, cues, 0.5, 0.06);
      expect(stepper.bgShape, MouthShape.singEe);
    });
  });
}
