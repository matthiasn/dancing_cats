import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dancing_cats/features/character/demo/dance_loaders.dart';
import 'package:dancing_cats/features/character/demo/dance_performance.dart';
import 'package:dancing_cats/features/character/model/beat_map.dart';
import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/dance_dynamics.dart';
import 'package:dancing_cats/features/character/model/dance_dynamics_warp.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;

/// Section tags fed to the generative choreo tests — the real routines plus an
/// untagged/unknown one, so the energy-level fallback is exercised too.
const _choreoSections = [
  'chorus',
  'post-chorus',
  'pre-chorus',
  'verse',
  'bridge',
  'outro',
  'intro',
  '',
];

extension _AnyDance on glados.Any {
  glados.Generator<double> get dancePos =>
      glados.DoubleAnys(this).doubleInRange(0, 8);

  glados.Generator<({String section, double phase, double level, int variant})>
  get choreoArgs => glados.CombinableAny(this).combine4(
    glados.IntAnys(this).intInRange(0, _choreoSections.length - 1),
    glados.DoubleAnys(this).doubleInRange(0, 1),
    glados.DoubleAnys(this).doubleInRange(0, 1),
    glados.IntAnys(this).intInRange(0, 7),
    (s, phase, level, variant) => (
      section: _choreoSections[s],
      phase: phase,
      level: level,
      variant: variant,
    ),
  );

  glados.Generator<({double current, double target, double dt})> get easeArgs =>
      glados.CombinableAny(this).combine3(
        glados.DoubleAnys(this).doubleInRange(0, 1),
        glados.DoubleAnys(this).doubleInRange(0, 1),
        glados.DoubleAnys(this).doubleInRange(0, 0.5),
        (c, t, dt) => (current: c, target: t, dt: dt),
      );
}

/// A synthetic 120 BPM grid: 13 beats 0.5 s apart (0..6 s), downbeats every 4.
BeatMap _beatMap() => BeatMap(
  beatTimesSec: [for (var i = 0; i < 13; i++) i * 0.5],
  downbeatIndices: const [0, 4, 8, 12],
);

DancePerformance _perf({
  List<DanceSection> sections = const [],
  List<DanceSectionSpan> spans = const [],
  List<DanceWord> words = const [],
  double duration = 6,
}) {
  final map = _beatMap();
  return DancePerformance(
    map: map,
    binding: BeatLoopBinding.barAligned(map, bars: kDancePhraseBars),
    sections: sections,
    sectionSpans: spans,
    trackDurationSec: duration,
    words: words,
  );
}

void main() {
  group('DancePerformance.fromBeatMapJson', () {
    test('assembles waveform-classified sections and lyric spans', () {
      final map = _beatMap();
      final perf = DancePerformance.fromBeatMapJson(
        json: const {
          // First half silent, second half loud — drives the energy classify.
          'waveform': [0, 0, 0, 0, 0, 1, 1, 1, 1, 1],
          'sections': [
            {'start_sec': 0, 'end_sec': 5, 'label': 'quiet'},
            {'start_sec': 5, 'end_sec': 10, 'label': 'loud'},
          ],
        },
        map: map,
        trackDurationSec: 10,
        words: const [
          (start: 0, end: 0.5, word: 'a', voice: 'lead', section: 'verse'),
          (start: 2, end: 2.5, word: 'b', voice: 'lead', section: 'chorus'),
        ],
      );

      expect(identical(perf.map, map), isTrue);
      expect(perf.trackDurationSec, 10);
      // The embedded waveform classifies the long quiet head as calm and the
      // loud tail as energetic — exactly as classifyDanceSections would.
      expect(perf.sections.map((s) => s.label), ['quiet', 'loud']);
      expect(perf.sections[0].energetic, isFalse);
      expect(perf.sections[1].energetic, isTrue);
      // The lyrics become the semantic section spans.
      expect(perf.sectionSpans.map((s) => s.section), ['verse', 'chorus']);
      expect(perf.words, hasLength(2));
    });

    test('tolerates a document with no waveform and no sections', () {
      final perf = DancePerformance.fromBeatMapJson(
        json: const {},
        map: _beatMap(),
        trackDurationSec: 6,
      );
      expect(perf.sections, isEmpty);
      expect(perf.sectionSpans, isEmpty);
      expect(perf.words, isEmpty);
    });
  });

  group('classifyDanceSections', () {
    test('without amplitudes every section is energetic at full level', () {
      final out = classifyDanceSections(
        [(start: 0, end: 5, label: 'A'), (start: 5, end: 10, label: 'B')],
        const [],
        10,
      );
      expect(out.map((s) => s.energetic), everyElement(isTrue));
      expect(out.map((s) => s.level), everyElement(1.0));
    });

    test('a long low-energy section is calm; the loud one stays energetic', () {
      final out = classifyDanceSections(
        [
          (start: 0, end: 5, label: 'quiet'),
          (start: 5, end: 10, label: 'loud'),
        ],
        // First half silent, second half loud.
        [0, 0, 0, 0, 0, 1, 1, 1, 1, 1],
        10,
      );
      expect(out[0].energetic, isFalse, reason: 'long + low energy → calm');
      expect(out[1].energetic, isTrue);
      expect(out[0].level, lessThan(out[1].level));
      expect(out[1].level, 1.0);
    });

    test('a short low-energy section stays energetic (no idle flicker)', () {
      final out = classifyDanceSections(
        [(start: 0, end: 2, label: 'dip'), (start: 2, end: 10, label: 'loud')],
        [0, 0, 1, 1, 1, 1, 1, 1, 1, 1],
        10,
      );
      // The dip is below threshold but only 2 s (< kMinCalmSeconds) → energetic.
      expect(out[0].energetic, isTrue);
    });
  });

  group('buildDanceSectionSpans', () {
    test('collapses words into contiguous spans trimmed to the next start', () {
      final spans = buildDanceSectionSpans(
        [
          (start: 0, end: 0.5, word: 'a', voice: 'lead', section: 'verse'),
          (start: 1, end: 1.5, word: 'b', voice: 'lead', section: 'verse'),
          (start: 2, end: 2.5, word: 'c', voice: 'lead', section: 'chorus'),
        ],
        10,
      );
      expect(spans, [
        (start: 0.0, end: 2.0, section: 'verse'),
        (start: 2.0, end: 10.0, section: 'chorus'),
      ]);
    });

    test('no words → no spans', () {
      expect(buildDanceSectionSpans(const [], 10), isEmpty);
    });
  });

  group('danceSectionDisplayName', () {
    test('maps known tags and title-cases the rest', () {
      expect(danceSectionDisplayName('pre-chorus'), 'Pre');
      expect(danceSectionDisplayName('post-chorus'), 'Post');
      expect(danceSectionDisplayName('chorus'), 'Chorus');
      expect(danceSectionDisplayName(''), '—');
      expect(danceSectionDisplayName('hook'), 'Hook');
    });
  });

  group('easeDanceMouth', () {
    test('attack reaches the target faster than release for the same dt', () {
      final opening = easeDanceMouth(0, 1, 0.06);
      final closing = easeDanceMouth(1, 0, 0.06);
      expect(opening, 1.0, reason: 'fast attack fully opens in one 60ms step');
      expect(closing, closeTo(0.5, 1e-9), reason: 'slow release lags');
      expect(opening, greaterThan(1 - closing));
    });

    test('never overshoots the target', () {
      expect(easeDanceMouth(0, 1, 10), 1.0);
      expect(easeDanceMouth(1, 0, 10), 0.0);
    });
  });

  group('danceIdleStage', () {
    test('rests all three cats on the idle clip at raw playback time', () {
      final stage = danceIdleStage(4.2);
      expect(stage.lead.name, 'idle');
      expect(stage.ensemble.map((c) => c.name), everyElement('idle'));
      expect(stage.seconds, 4.2);
      expect(stage.energetic, isFalse);
      expect(stage.synchronous, isTrue);
      expect(stage.dynamics, hasLength(3));
      expect(stage.dynamics, everyElement(DanceDynamics.neutral));
    });
  });

  group('sectionEnergyDynamics', () {
    test('level 0.5 (mid-energy) is neutral', () {
      expect(sectionEnergyDynamics(0.5), DanceDynamics.neutral);
    });

    test('clamps out-of-range levels to the 0..1 endpoints', () {
      expect(sectionEnergyDynamics(-1), sectionEnergyDynamics(0));
      expect(sectionEnergyDynamics(2), sectionEnergyDynamics(1));
    });

    test('the shared gain is a real, nonzero ramp (ADR CHAR-0003 tuning)', () {
      expect(kDanceSectionEnergyGain, isNot(DanceDynamics.neutral));
    });

    test('is monotonic in level on every axis', () {
      final levels = [0.0, 0.25, 0.5, 0.75, 1.0];
      final samples = levels.map(sectionEnergyDynamics).toList();
      for (var i = 1; i < samples.length; i++) {
        expect(samples[i].weight, greaterThanOrEqualTo(samples[i - 1].weight));
        expect(samples[i].time, greaterThanOrEqualTo(samples[i - 1].time));
        expect(samples[i].flow, greaterThanOrEqualTo(samples[i - 1].flow));
      }
    });

    test('the hottest and coldest levels are exact opposites', () {
      final hot = sectionEnergyDynamics(1);
      final cold = sectionEnergyDynamics(0);
      expect(hot.weight, closeTo(-cold.weight, 1e-12));
      expect(hot.time, closeTo(-cold.time, 1e-12));
      expect(hot.flow, closeTo(-cold.flow, 1e-12));
    });

    test(
      'the shipped lane profiles + section gain stay under the modulation '
      'budget, so no in-range composition can invert a defining Effort axis '
      '(ADR CHAR-0003)',
      () {
        for (final lane in kDanceLaneDynamicsProfiles) {
          for (final level in [0.0, 1.0]) {
            final combined = lane + sectionEnergyDynamics(level);
            expect(
              combined.weight.abs(),
              lessThan(kDanceDynamicsModulationBudget),
            );
            expect(
              combined.time.abs(),
              lessThan(kDanceDynamicsModulationBudget),
            );
            expect(
              combined.flow.abs(),
              lessThan(kDanceDynamicsModulationBudget),
            );
          }
        }
      },
    );
  });

  group('DancePerformance.sectionAt', () {
    test('returns the covering section, or the last past the end', () {
      final perf = _perf(
        sections: const [
          (start: 0, end: 3, label: 'A', energetic: true, level: 1),
          (start: 3, end: 6, label: 'B', energetic: true, level: 1),
        ],
      );
      expect(perf.sectionAt(1)?.label, 'A');
      expect(perf.sectionAt(4)?.label, 'B');
      expect(perf.sectionAt(99)?.label, 'B', reason: 'clamps to last');
    });

    test('empty sections → null', () {
      expect(_perf().sectionAt(1), isNull);
    });
  });

  group('DancePerformance.sectionInfoAt / occurrence', () {
    final perf = _perf(
      spans: const [
        (start: 0, end: 2, section: 'verse'),
        (start: 2, end: 4, section: 'chorus'),
        (start: 4, end: 6, section: 'verse'),
      ],
    );

    test('reports the section label and 0..1 phase within the span', () {
      final info = perf.sectionInfoAt(3); // mid chorus span [2,4]
      expect(info.section, 'chorus');
      expect(info.phase, closeTo(0.5, 1e-9));
    });

    test('counts earlier same-label spans as the occurrence index', () {
      expect(perf.sectionOccurrenceAt(1, 'verse'), 0);
      expect(perf.sectionOccurrenceAt(5, 'verse'), 1, reason: '2nd verse');
    });
  });

  group('DancePerformance.choreoTrioForSection', () {
    // The dance-move getters recompile a fresh Clip with no value equality, so
    // assertions compare the stable `name` rather than instance identity.
    final perf = _perf();

    test('the chorus opens on a canon of the hook motif', () {
      final trio = perf.choreoTrioForSection('chorus', 0.6, 0.5, 0);
      expect(trio.lead.name, 'movingHookLead');
      // All three voices QUOTE the lead's hook motif (round-4 panel: a
      // displaced different phrase reads as counterpoint, not an answer) —
      // but on three displaced clocks, so no two state it simultaneously.
      expect(
        trio.ensemble.map((c) => c.name).toSet(),
        {'movingHookLead'},
      );
      final leadRight = trio.ensemble[0].limbTargets
          .singleWhere((t) => t.endBoneId == 'hand.R')
          .channel;
      for (final lane in [1, 2]) {
        final voiceRight = trio.ensemble[lane].limbTargets
            .singleWhere((t) => t.endBoneId == 'hand.R')
            .channel;
        // Sampled at the SAME instants, the displaced voice is elsewhere in
        // the motif — the trio never collapses into unison outside the
        // final chorus's earned hookUnison payoff. (Individual phases can
        // coincide where the motif crosses itself; the voices must be far
        // apart somewhere in every bar.)
        var maxGap = 0.0;
        for (var i = 0; i < 32; i++) {
          final gap =
              (voiceRight.sample(i / 32).y - leadRight.sample(i / 32).y).abs();
          if (gap > maxGap) maxGap = gap;
        }
        expect(
          maxGap,
          greaterThan(25),
          reason: 'lane $lane must not shadow the lead frame-for-frame',
        );
        expect(identical(trio.ensemble[lane], trio.ensemble[0]), isFalse);
      }
    });

    test('the first two choruses establish the same lead signature', () {
      final first = perf.choreoTrioForSection('chorus', 0.2, 0.5, 0);
      final second = perf.choreoTrioForSection('chorus', 0.2, 0.5, 1);

      expect(first.lead.name, 'movingHookLead');
      expect(first.ensemble.every((c) => c.belongsToFamily('moving')), isTrue);
      expect(second.lead.name, 'movingHookLead');
      expect(second.ensemble.every((c) => c.belongsToFamily('moving')), isTrue);
    });

    test('verses rotate body-led song phrases rather than catalogue moves', () {
      final shuffle = perf
          .choreoTrioForSection(
            'verse',
            0,
            0.5,
            0,
            sectionSeconds: 16,
          )
          .lead;
      final window = perf
          .choreoTrioForSection(
            'verse',
            0.3,
            0.5,
            0,
            sectionSeconds: 16,
          )
          .lead;
      final shuffleFoot = shuffle.limbTargets
          .singleWhere((t) => t.endBoneId == 'foot.R')
          .channel;
      final windowFoot = window.limbTargets
          .singleWhere((t) => t.endBoneId == 'foot.R')
          .channel;
      final shuffleLeft = shuffle.limbTargets
          .singleWhere((t) => t.endBoneId == 'hand.L')
          .channel;
      final windowLeft = window.limbTargets
          .singleWhere((t) => t.endBoneId == 'hand.L')
          .channel;
      expect(shuffle.name, 'movingVerseShuffle');
      expect(window.name, 'movingVerseWindow');
      expect(
        windowFoot.sample(4 / 32).x,
        closeTo(shuffleFoot.sample(4 / 32).x, 1e-9),
        reason: 'the arms keep phrasing independently over the heel shuffle',
      );
      expect(
        (windowLeft.sample(24 / 32).y - shuffleLeft.sample(24 / 32).y).abs(),
        greaterThan(40),
        reason: 'repeat verses need a genuinely different upper silhouette',
      );
    });

    test('the bridge drops the trio into the original heel-bounce pocket', () {
      final trio = perf.choreoTrioForSection('bridge', 0.5, 0.5, 0);
      final rightFoot = trio.lead.limbTargets
          .singleWhere((t) => t.endBoneId == 'foot.R')
          .channel;
      expect(trio.lead.name, 'movingBridgeBounce');
      expect(trio.ensemble.every((c) => c.belongsToFamily('moving')), isTrue);
      expect(rightFoot.sample(2 / 32).y, lessThan(85));
    });

    test('untagged sections fall back to the energy-level map', () {
      expect(
        perf.choreoTrioForSection('', 0, 0.95, 0).lead.name,
        'movingHookLead',
      );
      expect(
        perf.choreoTrioForSection('', 0, 0.10, 0).lead.name,
        'sekem',
      );
    });
  });

  group('DancePerformance.choreoTrioByLevel', () {
    final perf = _perf();
    test(
      'builds from the grounded pocket up to the Moving hook by energy',
      () {
        expect(perf.choreoTrioByLevel(0.95).lead.name, 'movingHookLead');
        expect(perf.choreoTrioByLevel(0.80).lead.name, 'zanku');
        expect(perf.choreoTrioByLevel(0.50).lead.name, 'shaku');
        expect(perf.choreoTrioByLevel(0.30).lead.name, 'azonto');
        expect(perf.choreoTrioByLevel(0.05).lead.name, 'sekem');
      },
    );

    test('the two shaku-led bands differ by ensemble at the 0.62 boundary', () {
      expect(
        perf.choreoTrioByLevel(0.62).ensemble.map((c) => c.name).toList(),
        ['shaku', 'zanku', 'sekem'],
      );
      expect(
        perf.choreoTrioByLevel(0.45).ensemble.map((c) => c.name).toList(),
        ['shaku', 'azonto', 'zanku'],
      );
    });
  });

  group('DancePerformance.stageAt', () {
    test('an energetic section dances with a finite warped clock', () {
      final perf = _perf(
        sections: const [
          (start: 0, end: 6, label: 'A', energetic: true, level: 1),
        ],
      );
      final stage = perf.stageAt(2);
      expect(
        stage.lead.name,
        'movingHookLead',
        reason: 'level 1 → the song-specific hook',
      );
      expect(stage.energetic, isTrue);
      expect(stage.synchronous, isTrue);
      expect(stage.seconds.isFinite, isTrue);
      expect(stage.seconds, isNonNegative);
    });

    test('a dead-quiet calm section rests on idle at raw time', () {
      final perf = _perf(
        sections: const [
          (start: 0, end: 6, label: 'A', energetic: false, level: 0.1),
        ],
      );
      final stage = perf.stageAt(2.5);
      expect(stage.lead.name, 'idle');
      expect(stage.seconds, 2.5, reason: 'idle runs on raw playback time');
    });

    test('the bridge Sekem pocket stays in unison', () {
      final perf = _perf(
        spans: const [(start: 0, end: 6, section: 'bridge')],
        sections: const [
          (start: 0, end: 6, label: 'A', energetic: true, level: 0.5),
        ],
      );
      expect(perf.stageAt(2).synchronous, isTrue);
    });

    test(
      "composes each lane's dynamics from its move base, cat profile, and "
      'section energy',
      () {
        final perf = _perf(
          sections: const [
            (start: 0, end: 6, label: 'A', energetic: true, level: 0.5),
          ],
        );
        final stage = perf.stageAt(2);
        final sectionDynamics = sectionEnergyDynamics(0.5);

        expect(stage.dynamics, hasLength(3));
        for (var i = 0; i < stage.dynamics.length; i++) {
          expect(
            stage.dynamics[i],
            effectiveDanceDynamics(
              moveBase: stage.ensemble[i].dynamics,
              catProfile: kDanceLaneDynamicsProfiles[i],
              sectionEnergy: sectionDynamics,
            ),
          );
        }
      },
    );
  });

  group('DancePerformance.beatPulse', () {
    final perf = _perf();
    test('spikes to 1 on a beat and decays to 0 within ~180 ms', () {
      expect(perf.beatPulse(0.5), 1.0, reason: 'exactly on beat 1');
      expect(perf.beatPulse(0.5 + 0.09), closeTo(0.25, 1e-6));
      expect(perf.beatPulse(0.5 + 0.2), 0.0, reason: 'fully decayed');
    });
  });

  group('DancePerformance.voiceActive', () {
    final perf = _perf(
      words: const [
        (start: 1, end: 1.5, word: 'hey', voice: 'lead', section: 'verse'),
      ],
    );
    test('true inside a word window (dilated by the slack), else false', () {
      expect(perf.voiceActive(1.2, (w) => w.voice == 'lead'), isTrue);
      expect(
        perf.voiceActive(1.7, (w) => w.voice == 'lead'),
        isTrue,
        reason: 'within slack past the word end',
      );
      expect(perf.voiceActive(3, (w) => w.voice == 'lead'), isFalse);
      expect(perf.voiceActive(1.2, (w) => w.voice == 'background'), isFalse);
    });
  });

  group('DancePerformance.directorContext', () {
    test('wires the section, energetic flag, phase and normalized build', () {
      final perf = _perf(
        spans: const [(start: 0, end: 6, section: 'chorus')],
        duration: 12,
      );
      final ctx = perf.directorContext(3, energetic: true);
      expect(ctx.section, 'chorus');
      expect(ctx.energetic, isTrue);
      expect(ctx.sectionPhase, closeTo(0.5, 1e-9));
      expect(ctx.build, closeTo(3 / 12, 1e-9));
    });

    test(
      'a non-positive track duration yields build 0 (no divide by zero)',
      () {
        expect(
          _perf(duration: 0).directorContext(2, energetic: false).build,
          0,
        );
      },
    );

    test('wires the occurrence and the NEXT section for the anticipated '
        'dolly', () {
      final perf = _perf(
        spans: const [
          (start: 0, end: 2, section: 'chorus'),
          (start: 2, end: 4, section: 'verse'),
          (start: 4, end: 6, section: 'chorus'),
        ],
      );
      final ctx = perf.directorContext(3, energetic: true);
      expect(ctx.section, 'verse');
      expect(ctx.occurrence, 0);
      expect(ctx.nextSection, 'chorus');
      expect(ctx.secondsToNext, closeTo(1, 1e-9));
      // The upcoming chorus is the SECOND chorus → occurrence 1 (keys the
      // left two-shot home the camera glides into).
      expect(ctx.nextOccurrence, 1);
    });

    test('a gap before the first span still sees the next section coming', () {
      final perf = _perf(
        spans: const [(start: 4, end: 6, section: 'chorus')],
      );
      final ctx = perf.directorContext(2.5, energetic: false);
      expect(ctx.section, '');
      expect(ctx.nextSection, 'chorus');
      expect(ctx.secondsToNext, closeTo(1.5, 1e-9));
      expect(ctx.nextOccurrence, 0);
    });

    test('inside the last span there is no next section (no anticipation)', () {
      final perf = _perf(
        spans: const [(start: 0, end: 6, section: 'outro')],
      );
      final ctx = perf.directorContext(5, energetic: true);
      expect(ctx.nextSection, isNull);
      expect(ctx.secondsToNext, double.infinity);
      expect(ctx.nextOccurrence, 0);
    });
  });

  group('DancePerformance.choreoTrioForSection — remaining routines', () {
    final perf = _perf();
    test('pre-chorus / outro / post-chorus keep the song-specific score', () {
      expect(
        perf.choreoTrioForSection('pre-chorus', 0, 0.5, 0).lead.name,
        'movingVerseShuffle',
      );
      expect(
        perf
            .choreoTrioForSection(
              'outro',
              0.5,
              0.5,
              0,
              sectionSeconds: 16,
            )
            .ensemble
            .map((c) => c.name)
            .toList(),
        [
          'movingBridgeRock',
          'movingBridgeBounce',
          'movingVerseWindow',
        ],
      );
      expect(
        perf
            .choreoTrioForSection(
              'post-chorus',
              0.6,
              0.5,
              0,
              sectionSeconds: 16,
            )
            .lead
            .name,
        'movingBodyRoll',
      );
    });

    test(
      'the third hook advances to the side-answer variation',
      () {
        expect(
          perf
              .choreoTrioForSection('chorus', 0.2, 0.5, 2)
              .ensemble
              .map((c) => c.name)
              .toList(),
          [
            'movingHookSideAnswer',
            'movingHookLead',
            'movingHookLowCounter',
          ],
        );
      },
    );

    test('the final chorus earns one collective hook payoff', () {
      final trio = perf.choreoTrioForSection(
        'chorus',
        0.9,
        0.5,
        2,
        sectionSeconds: 16,
      );

      expect(
        trio.ensemble.map((clip) => clip.name).toSet(),
        {'movingHookLead'},
        reason: 'the preceding chorus slots already own the crew variations',
      );
    });

    test(
      'the 144s score assigns one deliberate statement per two-bar slot',
      () {
        List<String> score(
          String section,
          int occurrence, {
          bool finalOccurrence = false,
        }) => [
          for (final phase in [0.05, 0.3, 0.55, 0.8])
            perf
                .choreoTrioForSection(
                  section,
                  phase,
                  0.5,
                  occurrence,
                  sectionSeconds: 16,
                  finalOccurrence: finalOccurrence,
                )
                .lead
                .name,
        ];

        expect(score('chorus', 0), [
          'movingHookLead',
          'movingHookSideAnswer',
          'movingChorusTravel',
          'movingHookLead',
        ]);
        expect(score('chorus', 1), [
          'movingHookLead',
          'movingChorusOpen',
          'movingHookSideAnswer',
          'movingHookLead',
        ]);
        expect(score('chorus', 2), [
          'movingHookSideAnswer',
          'movingChorusOpen',
          'movingChorusTravel',
          'movingHookLead',
        ]);
        expect(score('post-chorus', 0), [
          'movingHookLowCounter',
          'movingChorusTravel',
          'movingBodyRoll',
          'movingVerseWindow',
        ]);
        // The LAST post-chorus keeps the heat — the track still burns near
        // its peak there, and leading it with the lowest phrase measured as
        // the weakest window of the whole edit (round-3 panel).
        // ...and RESTATES THE CANON in its second statement (round-5: the
        // arc's peak must not abandon the conversation).
        expect(score('post-chorus', 1), [
          'movingChorusTravel',
          'movingHookLead',
          'movingVerseWindow',
          'movingHookLowCounter',
        ]);
        // FINALITY, not occurrence, selects the reprise: this track tags
        // post-chorus exactly once, so its occurrence is 0 — an
        // occurrence-only gate shipped the reprise dead while this test
        // passed the variant by hand (round-7 regression).
        expect(
          score('post-chorus', 0, finalOccurrence: true),
          score('post-chorus', 1),
        );
        // All four verse statements stay in grounded verse vocabulary — the
        // hook-family sideAnswer that used to close the verse put chorus
        // amplitude into the song's breakdown stretch (panel: "the bridge is
        // a third chorus") and erased the dynamic valley.
        expect(score('verse', 0), [
          'movingVerseShuffle',
          'movingVerseWindow',
          'movingBodyRoll',
          'movingHookLowCounter',
        ]);
        expect(score('bridge', 0), [
          'movingBridgeBounce',
          'movingBridgeRock',
          'movingBodyRoll',
          'movingChorusTravel',
        ]);
        expect(score('outro', 0), [
          'movingHookSideAnswer',
          'movingBodyRoll',
          'movingBridgeRock',
          'movingHookLead',
        ]);

        final productionLeadScore = [
          ...score('chorus', 0),
          ...score('pre-chorus', 0),
          ...score('chorus', 1),
          ...score('verse', 0),
          ...score('bridge', 0),
          ...score('chorus', 2),
          ...score('post-chorus', 1),
          ...score('outro', 0),
        ];
        for (var i = 1; i < productionLeadScore.length; i++) {
          expect(
            productionLeadScore[i],
            isNot(productionLeadScore[i - 1]),
            reason:
                'adjacent two-bar statements ${i - 1} and $i must not reuse '
                'the same lead phrase',
          );
        }
      },
    );
  });

  group('DancePerformance.stageAt — the resting gate', () {
    test('a calm section above the idle floor still dances', () {
      final perf = _perf(
        sections: const [
          (start: 0, end: 6, label: 'A', energetic: false, level: 0.3),
        ],
      );
      // resting requires level < 0.15, so level 0.3 dances (energy fallback).
      expect(perf.stageAt(2).lead.name, isNot('idle'));
    });

    test('with no sections at all the trio dances at full energy', () {
      final stage = _perf().stageAt(2);
      expect(stage.lead.name, 'movingHookLead');
      expect(stage.energetic, isTrue);
    });
  });

  group('danceSectionArcTier', () {
    test('the performance builds: early choruses are capped, the last one '
        'owns the ceiling, and the valley sits below the verses', () {
      expect(danceSectionArcTier('chorus', 0), lessThan(1));
      expect(
        danceSectionArcTier('chorus', 1),
        greaterThan(danceSectionArcTier('chorus', 0)),
      );
      expect(
        danceSectionArcTier('chorus', 2),
        greaterThan(danceSectionArcTier('chorus', 1)),
      );
      expect(
        danceSectionArcTier('bridge', 0),
        lessThan(danceSectionArcTier('verse', 0)),
      );
      expect(
        danceSectionArcTier('verse', 0),
        lessThan(danceSectionArcTier('chorus', 0)),
      );
      // The arc rides ON the waveform energy — it must never push the
      // quantized energy outside the effort-cache's 0..1 domain.
      expect(danceSectionArcTier('chorus', 3), lessThan(1.25));
    });

    test('the FINAL post-chorus (the reprise) tops the whole arc', () {
      // Keyed on finality like the reprise setlist itself: this track tags
      // post-chorus exactly once, so an occurrence-gated tier was dead and
      // the reprise measured BELOW the valley (panel: "the trio
      // de-crescendos through the song's actual climax").
      final reprise = danceSectionArcTier(
        'post-chorus',
        0,
        finalOccurrence: true,
      );
      expect(reprise, greaterThan(danceSectionArcTier('chorus', 2)));
      expect(reprise, greaterThan(danceSectionArcTier('post-chorus', 1)));
      expect(danceSectionArcTier('post-chorus', 0), lessThan(1));
      expect(reprise, lessThan(1.25));
    });
  });

  group('call-and-response echo', () {
    test('the hook call is a literal canon of the lead motif', () {
      final perf = _perf(
        sections: const [
          (start: 0, end: 6, label: 'A', energetic: true, level: 1),
        ],
      );
      final call = perf.choreoTrioForSection(
        'chorus',
        0.05,
        0.5,
        0,
        sectionSeconds: 16,
      );
      final lead = CatClips.movingGroove;
      // Both flanks QUOTE the lead's own phrase — whole body, spans included
      // — displaced by their voice's delay (echo one beat + humanization,
      // canon two beats − humanization). A displaced DIFFERENT phrase read
      // as counterpoint, not an answer.
      for (final (lane, shift) in [(1, kMovingCanonPhase), (2, kMovingEchoPhase)]) {
        final voice = call.ensemble[lane];
        expect(voice.name, lead.name);
        for (final bone in [CatBones.handR, CatBones.footL]) {
          final v = voice.limbTargets
              .singleWhere((t) => t.endBoneId == bone)
              .channel;
          final pl = lead.limbTargets
              .singleWhere((t) => t.endBoneId == bone)
              .channel;
          // The grey quote's ARMS carry the extra re-lock delay (see
          // kMovingCanonArmRelock); feet stay on the pure displacement.
          final boneShift = lane == 1 && bone == CatBones.handR
              ? shift + kMovingCanonArmRelock
              : shift;
          expect(
            v.sample(0.4).y,
            closeTo(pl.sample(0.4 + boneShift).y, 1e-9),
            reason: 'lane $lane $bone must quote the lead $boneShift late',
          );
        }
        // The shifted spans keep their feet planted (the crush invariant).
        for (final span in voice.contactSpans) {
          final channel = voice.limbTargets
              .singleWhere((t) => t.endBoneId == span.bone)
              .channel;
          for (var i = 0; i <= 16; i++) {
            final p = span.start + (span.end - span.start) * i / 16;
            expect(channel.sample(p).y, greaterThan(104));
          }
        }
      }
      // The two voices are HUMANIZED off the pure beat grid — their strike
      // times must not coincide with each other or the lead on shared beats.
      expect(kMovingEchoPhase, isNot(closeTo(-1 / 8, 1e-4)));
      expect(kMovingCanonPhase, isNot(closeTo(-2 / 8, 1e-4)));
    });
  });

  group('lane envelopes follow the displaced voice', () {
    test('an echo lane hits one beat after the call', () {
      final perf = DancePerformance.fromBeatMapJson(
        json: const {
          'onsets': [
            {'time_sec': 1.0, 'strength': 1.0},
          ],
        },
        map: _beatMap(),
        trackDurationSec: 6,
      );
      // On the 0.5s grid, one echo beat = 0.5s: the displaced voice's
      // envelope peaks exactly one beat after the plain one.
      expect(perf.laneAccentAt(1, 0), 1);
      expect(perf.laneAccentAt(1, 1), closeTo(0, 1e-9));
      expect(perf.laneAccentAt(1.5, 1), 1);
      expect(perf.laneAccentAt(2, 2), 1);
      // Anticipation displaces identically.
      expect(perf.laneAnticipationAt(1.45, 1), greaterThan(0.4));
      expect(perf.laneAnticipationAt(0.95, 1), closeTo(0, 1e-9));
    });

    test('a blending clip lerps the ENVELOPES, never the displacement', () {
      final perf = DancePerformance.fromBeatMapJson(
        json: const {
          'onsets': [
            {'time_sec': 1.0, 'strength': 1.0},
          ],
        },
        map: _beatMap(),
        trackDurationSec: 6,
      );
      final tutti = CatClips.movingGroove; // echoBeats 0
      final canon = wholeClipPhaseShiftedClip(tutti, -2 / 8); // 2 beats
      final blended = blendedClip(from: canon, to: tutti, weight: 0.5);

      // The blended clip carries the lerped displacement (one beat)...
      expect(blended.echoBeats, closeTo(1, 1e-9));
      // ...and at pos 1.5 the envelope AT that lerped displacement lands
      // exactly on the onset — the phantom replay that shipped as a
      // one-frame stage-light pop at the reprise exit (114.73s): the
      // sweep of a lerping echoBeats crosses onset attacks the voice
      // already played.
      expect(perf.laneAccentAt(1.5, blended.echoBeats), 1);
      // Both REAL sides are quiet there: the tutti side played the onset
      // 0.5s ago (released) and the canon side won't reach it for another
      // half beat. The blend-aware envelope lerps the sides — no replay.
      expect(perf.laneAccentAt(1.5, 0), closeTo(0, 1e-9));
      expect(perf.laneAccentAt(1.5, canon.echoBeats), closeTo(0, 1e-9));
      expect(perf.laneAccentForClip(1.5, blended), closeTo(0, 1e-9));

      // Away from transitions the clip's own displacement is used...
      expect(perf.laneAccentForClip(2, canon), 1);
      // ...and anticipation blends the same way.
      expect(
        perf.laneAnticipationForClip(1.5, blended),
        closeTo(
          (perf.laneAnticipationAt(1.5, canon.echoBeats) +
                  perf.laneAnticipationAt(1.5, 0)) /
              2,
          1e-9,
        ),
      );
    });

    test('the echo voice HOLDS its reprise answers at peak', () {
      final map = _beatMap();
      final perf = DancePerformance(
        map: map,
        binding: BeatLoopBinding.barAligned(map, bars: kDancePhraseBars),
        sections: const [],
        sectionSpans: const [
          (start: 0.0, end: 2.0, section: 'post-chorus'), // first release
          (start: 2.0, end: 4.0, section: 'chorus'),
          (start: 4.0, end: 6.0, section: 'post-chorus'), // the REPRISE
        ],
        trackDurationSec: 6,
        onsets: const [
          (time: 1.0, strength: 1.0), // lands in the first post-chorus
          (time: 4.6, strength: 1.0), // lands in the reprise
        ],
      );
      const echo = kMovingEchoAnswerBeats;
      const hold = DancePerformance.kMovingRepriseAccentHoldSec;
      // On the 0.5s grid the echo voice's envelope peaks `echo` beats after
      // each onset.
      const firstPeak = 1.0 + echo * 0.5;
      const reprisePeak = 4.6 + echo * 0.5;

      // Reprise: the answer SUSTAINS at full depth through the hold, then the
      // unchanged release plays, shifted whole.
      expect(perf.laneAccentAt(reprisePeak, echo), 1);
      expect(perf.laneAccentAt(reprisePeak + hold * 0.9, echo), 1);
      expect(
        perf.laneAccentAt(reprisePeak + hold + 0.42 * 0.4, echo),
        closeTo(0, 1e-9),
        reason: 'the release keeps its shape, delayed by exactly the hold',
      );

      // Everywhere else the hit-and-breathe release stays untouched: the
      // first post-chorus decays immediately past its peak...
      expect(perf.laneAccentAt(firstPeak, echo), 1);
      expect(perf.laneAccentAt(firstPeak + hold * 0.9, echo), lessThan(0.9));
      // ...the lead never holds, even in the reprise...
      expect(perf.laneAccentAt(4.6 + hold * 0.9, 0), lessThan(0.9));
      // ...and the two-beat canon voice's residual hold has already faded to
      // near-nothing (the bump is centred on the one-beat answer).
      const canonBeats = -kMovingCanonPhase * kDanceBeatsPerPhraseLoop;
      const canonPeak = 4.6 + canonBeats * 0.5;
      expect(
        perf.laneAccentAt(canonPeak + hold * 0.9, canonBeats),
        lessThan(0.9),
      );
    });
  });

  group('hand flourish — varied, rare, and continuous', () {
    // A longer 0.5s grid so multi-onset windows and fills fit comfortably.
    final map = BeatMap(
      beatTimesSec: [for (var i = 0; i < 25; i++) i * 0.5],
      downbeatIndices: const [0, 4, 8, 12, 16, 20, 24],
    );
    final perf = DancePerformance(
      map: map,
      binding: BeatLoopBinding.barAligned(map, bars: kDancePhraseBars),
      sections: const [],
      sectionSpans: const [],
      trackDurationSec: 12,
      onsets: const [
        (time: 1.0, strength: 1.0),
        (time: 2.5, strength: 1.0),
        (time: 4.0, strength: 1.0),
        (time: 5.5, strength: 1.0),
        (time: 7.0, strength: 1.0),
        (time: 8.5, strength: 1.0),
        (time: 10.0, strength: 1.0),
      ],
    );
    final groove = CatClips.movingGroove;
    DanceHandFlourish at(double t, {int lane = 0}) =>
        perf.laneHandFlourishFor(t, groove, lane);
    double mag(DanceHandFlourish f) =>
        f.lx.abs() + f.ly.abs() + f.rx.abs() + f.ry.abs();

    test('every hit carries an ornament, and the hits VARY', () {
      final hits = [for (final t in [1.0, 2.5, 4.0, 5.5, 7.0]) at(t)];
      for (final f in hits) {
        expect(mag(f), greaterThan(1), reason: 'hits must reach the hands');
      }
      // The whole point of the layer: consecutive hits do not repeat the
      // same hand accent (deterministic per-onset flavors).
      final directions = {
        for (final f in hits) (f.lx.sign, f.ly.sign, f.rx.sign, f.ry.sign),
      };
      expect(directions.length, greaterThan(1));
      // Lanes decorate the same hit differently.
      final lanes = {
        for (final lane in [0, 1, 2])
          () {
            final f = at(2.5, lane: lane);
            return (f.lx, f.ly);
          }(),
      };
      expect(lanes.length, greaterThan(1));
    });

    test('quiet gaps are exactly still', () {
      // 1.6s: past the 0.42s release of the 1.0 hit, before any fill window
      // of the 2.5 hit (fills start at most 0.75s = 1.5 beats ahead).
      expect(at(1.6), kNoHandFlourish);
      // Before the first onset's fill window opens.
      expect(at(0.1), kNoHandFlourish);
    });

    test('double-time fills are a texture, not a constant', () {
      // Sample each onset's pickup (0.35s ahead: ornament released, coil not
      // yet open) — any motion there is a fill.
      var fills = 0;
      var samples = 0;
      for (final lane in [0, 1, 2]) {
        for (final t in [1.0, 2.5, 4.0, 5.5, 7.0, 8.5, 10.0]) {
          samples++;
          if (mag(at(t - 0.35, lane: lane)) > 0.05) fills++;
        }
      }
      // Owner: "a whole lot more 2x in hands and arms" — a bit over half of
      // each lane's strong onsets roll, but never all of them: each cat
      // still breathes between its own fills.
      expect(fills / samples, greaterThan(0.25));
      expect(fills / samples, lessThan(0.9));
    });

    test('strong hits land in a held one-arm pose that melts back', () {
      // Find, deterministically, an onset that poses for some lane: every
      // onset here is strength 1, so eligibility is purely the hash.
      final posed = <(double, int)>[];
      for (final t in [1.0, 2.5, 4.0, 5.5, 7.0, 8.5, 10.0]) {
        for (final lane in [0, 1, 2]) {
          // A pose reads as a LARGE displacement at the hold plateau
          // (~0.2s past the hit), far beyond ornament scale.
          if (mag(at(t + 0.2, lane: lane)) > 15) posed.add((t, lane));
        }
      }
      expect(posed, isNotEmpty, reason: 'poses must fire on strong hits');
      // The three cats pose on DIFFERENT hits (counterpoint by hash).
      expect(
        posed.map((p) => p.$2).toSet().length,
        greaterThan(1),
        reason: 'poses must not be a unison event',
      );

      final (t0, lane) = posed.first;
      // HOLD: deep into the plateau the reach barely moves...
      final hold1 = at(t0 + 0.18, lane: lane);
      final hold2 = at(t0 + 0.28, lane: lane);
      expect((mag(hold1) - mag(hold2)).abs(), lessThan(3));
      // ...it is ONE-armed: the other hand stays at groove scale...
      final l = hold1.lx.abs() + hold1.ly.abs();
      final r = hold1.rx.abs() + hold1.ry.abs();
      expect(
        math.max(l, r) / math.max(1e-9, math.min(l, r) + 4.5),
        greaterThan(2),
        reason: 'the posing arm must dominate; the other keeps grooving',
      );
      // ...and it has melted back to silence before the next hit's window.
      expect(mag(at(t0 + 0.75, lane: lane)), lessThan(0.6));
    });

    test('the whole trio stamps every section door', () {
      final doorPerf = DancePerformance(
        map: map,
        binding: BeatLoopBinding.barAligned(map, bars: kDancePhraseBars),
        sections: const [],
        sectionSpans: const [
          (start: 0.0, end: 4.0, section: 'verse'),
          (start: 4.0, end: 12.0, section: 'chorus'),
        ],
        trackDurationSec: 12,
        onsets: const [
          (time: 1.0, strength: 1.0),
          (time: 2.5, strength: 1.0),
          // The chorus door: first weighty onset inside the new span.
          (time: 4.4, strength: 0.8),
          (time: 6.0, strength: 1.0),
        ],
      );
      // ALL THREE lanes pose on the door hit — no cat walks through the
      // section turn (each still picks its own flavor/arm by hash).
      for (final lane in [0, 1, 2]) {
        final f = doorPerf.laneHandFlourishFor(4.6, groove, lane);
        expect(
          f.lx.abs() + f.ly.abs() + f.rx.abs() + f.ry.abs(),
          greaterThan(10),
          reason: 'lane $lane must stamp the chorus door',
        );
      }
    });

    test('the paw opens on the posing hand and rolls through fills', () {
      // Reuse the pose finder: a posed hit shows a large one-arm reach.
      (double, int)? posed;
      for (final t in [1.0, 2.5, 4.0, 5.5, 7.0, 8.5, 10.0]) {
        for (final lane in [0, 1, 2]) {
          if (mag(at(t + 0.2, lane: lane)) > 15) {
            posed = (t, lane);
            break;
          }
        }
        if (posed != null) break;
      }
      final (t0, lane) = posed!;
      final paw = perf.lanePawPoseFor(t0 + 0.2, groove, lane);
      final f = at(t0 + 0.2, lane: lane);
      final leftPosing = f.lx.abs() + f.ly.abs() > f.rx.abs() + f.ry.abs();
      // The posing hand is OPEN at the hold; the other stays near closed
      // (only the small per-hit softening).
      final posingSplay = leftPosing ? paw.splayL : paw.splayR;
      final restingSplay = leftPosing ? paw.splayR : paw.splayL;
      expect(posingSplay, greaterThan(0.8));
      expect(restingSplay, lessThan(0.35));
      // The posing wrist aligns with the reach.
      final posingWrist = leftPosing ? paw.wristL : paw.wristR;
      expect(posingWrist.abs(), greaterThan(0.2));

      // Quiet gaps: paws fully at rest.
      expect(perf.lanePawPoseFor(1.6, groove, 0), kClosedPaws);

      // During a fill the wrist ROLLS: it changes sign across the window.
      (double, int)? filled;
      for (final t in [1.0, 2.5, 4.0, 5.5, 7.0, 8.5, 10.0]) {
        for (final l in [0, 1, 2]) {
          if (mag(at(t - 0.35, lane: l)) > 0.05 &&
              mag(at(t + 0.2, lane: l)) < 15) {
            filled = (t, l);
            break;
          }
        }
        if (filled != null) break;
      }
      final (tf, lf) = filled!;
      final wrists = [
        for (var t = tf - 0.7; t < tf; t += 0.03)
          perf.lanePawPoseFor(t, groove, lf).wristL,
      ];
      expect(wrists.any((w) => w > 0.02), isTrue);
      expect(wrists.any((w) => w < -0.02), isTrue);
    });

    test('the hands never teleport — dense continuity sweep', () {
      var prev = at(0.5);
      var worst = 0.0;
      for (var t = 0.502; t <= 10.5; t += 0.002) {
        final f = at(t);
        final step = [
          (f.lx - prev.lx).abs(),
          (f.ly - prev.ly).abs(),
          (f.rx - prev.rx).abs(),
          (f.ry - prev.ry).abs(),
        ].reduce(math.max);
        if (step > worst) worst = step;
        prev = f;
      }
      // Envelope-slope bound: the accent-pose launch covers ~34 units in
      // 0.24s (smoothstep peak ~210 u/s = 0.42 per 2ms step), on top of a
      // dying fill tail (<= 0.19) and the coil (0.09) — but never all three
      // peaks aligned. A shape or window step would land 1-30 units in one
      // sample, far above this band.
      expect(worst, lessThan(0.7));
    });

    test("a blending clip lerps the two sides' flourishes", () {
      final canon = wholeClipPhaseShiftedClip(groove, -2 / 8);
      final blended = blendedClip(from: canon, to: groove, weight: 0.25);
      final f = perf.laneHandFlourishFor(2.5, blended, 1);
      final side0 = perf.laneHandFlourishFor(2.5, canon, 1);
      final side1 = perf.laneHandFlourishFor(2.5, groove, 1);
      expect(f.lx, closeTo(side0.lx + (side1.lx - side0.lx) * 0.25, 1e-9));
      expect(f.ry, closeTo(side0.ry + (side1.ry - side0.ry) * 0.25, 1e-9));
    });
  });

  group('real-track staging (regression)', () {
    test('the final post-chorus stages the canon reprise on the real song', () {
      // Round 6 shipped the reprise gated on `occurrence >= 1`, and the
      // score test passed that variant BY HAND — but the real track tags
      // post-chorus exactly once, so the certified reprise never staged.
      // This test walks the actual song: the score must put the hook call's
      // three-voice canon inside the real final post-chorus span.
      final beatJson =
          jsonDecode(File('assets/sample_track/moving.json').readAsStringSync())
              as Map<String, Object?>;
      final wordsJson =
          jsonDecode(
                File(
                  'assets/sample_track/moving.words.json',
                ).readAsStringSync(),
              )
              as Map<String, Object?>;
      final map = BeatMap.fromJson(beatJson);
      final perf = DancePerformance.fromBeatMapJson(
        json: beatJson,
        map: map,
        trackDurationSec: 144.066,
        words: parseDanceWords(wordsJson),
      );

      final span = perf.sectionSpans.lastWhere(
        (s) => s.section == 'post-chorus',
      );
      // The reprise is the second of the section's four statements.
      final t = span.start + (span.end - span.start) * 3 / 8;
      expect(perf.sectionIsFinalOccurrenceAt(t, 'post-chorus'), isTrue);

      final stage = perf.stageAt(t);
      expect(
        stage.lead.name,
        'movingHookLead',
        reason: "the reprise restates the hook call at the arc's peak",
      );
      // ...as the three-voice canon: both flanks answer displaced.
      expect(
        stage.ensemble[2].echoBeats,
        closeTo(kMovingEchoAnswerBeats, 1e-9),
      );
      expect(
        stage.ensemble[1].echoBeats,
        closeTo(-kMovingCanonPhase * kDanceBeatsPerPhraseLoop, 1e-9),
      );
    });

    test('the flourish never steps on the real track (all voices)', () {
      // The owner's constraint for the hand layer: "it must not teleport."
      // Sweep the full 144s at 2ms for the three real displacement states
      // (tutti, one-beat echo, two-beat canon quote); every irregularity of
      // the real onset list — crowded neighbourhoods, tempo drift, the
      // reprise hold — passes under this gate.
      final beatJson =
          jsonDecode(File('assets/sample_track/moving.json').readAsStringSync())
              as Map<String, Object?>;
      final map = BeatMap.fromJson(beatJson);
      final perf = DancePerformance.fromBeatMapJson(
        json: beatJson,
        map: map,
        trackDurationSec: 144.066,
      );
      final voices = [
        CatClips.movingGroove,
        wholeClipPhaseShiftedClip(CatClips.movingGroove, kMovingEchoPhase),
        wholeClipPhaseShiftedClip(CatClips.movingGroove, kMovingCanonPhase),
      ];
      for (var lane = 0; lane < voices.length; lane++) {
        var prev = perf.laneHandFlourishFor(0, voices[lane], lane);
        var worst = 0.0;
        var worstT = 0.0;
        for (var t = 0.002; t <= 144.0; t += 0.002) {
          final f = perf.laneHandFlourishFor(t, voices[lane], lane);
          final step = [
            (f.lx - prev.lx).abs(),
            (f.ly - prev.ly).abs(),
            (f.rx - prev.rx).abs(),
            (f.ry - prev.ry).abs(),
          ].reduce(math.max);
          if (step > worst) {
            worst = step;
            worstT = t;
          }
          prev = f;
        }
        expect(
          worst,
          lessThan(0.7),
          reason:
              'lane $lane worst flourish step $worst at '
              '${worstT.toStringAsFixed(3)}s — the pose launch slews '
              '~0.42/step at most; a teleport-class step measures 1-30 '
              'units in one 2ms sample',
        );
      }
    });
  });

  group('DancePerformance onset phrasing', () {
    final perf = DancePerformance.fromBeatMapJson(
      json: const {
        'onsets': [
          {'time_sec': 1.0, 'strength': 1.0},
        ],
      },
      map: _beatMap(),
      trackDurationSec: 6,
    );

    test('anticipation and release meet continuously at the hit', () {
      expect(perf.anticipationAt(0.9), closeTo(0, 1e-12));
      expect(perf.anticipationAt(0.95), closeTo(0.5, 1e-9));
      expect(perf.anticipationAt(1 - 1e-6), closeTo(1, 1e-8));
      expect(perf.accentAt(1), 1);
      // Drop: recovers to neutral over the first 40% of the 0.42s window...
      expect(perf.accentAt(1 + 0.42 * 0.2), closeTo(0.5, 1e-9));
      expect(perf.accentAt(1 + 0.42 * 0.4), closeTo(0, 1e-9));
      // ...then BREATHES past neutral (the body lifts slightly above its
      // groove line — hit-and-breathe, not sink-and-return) and settles.
      expect(perf.accentAt(1 + 0.42 * 0.7), closeTo(-0.22, 1e-9));
      expect(perf.accentAt(1.42), closeTo(0, 1e-9));
      expect(perf.accentAt(1.43), 0);
    });

    test('peak picking spaces accents and rescues soft-mix sections', () {
      final crowded = DancePerformance.fromBeatMapJson(
        json: const {
          'onsets': [
            // A strong pair closer than the spacing floor: only the stronger
            // fires...
            {'time_sec': 1.0, 'strength': 0.8},
            {'time_sec': 1.4, 'strength': 0.6},
            // ...a soft-mix section transient below the old 0.5 floor still
            // earns its hit when it owns its neighbourhood...
            {'time_sec': 3.0, 'strength': 0.4},
            // ...and a sub-candidate stays silent.
            {'time_sec': 5.0, 'strength': 0.2},
          ],
        },
        map: _beatMap(),
        trackDurationSec: 6,
      );
      expect(crowded.accentAt(1), closeTo(0.8, 1e-9));
      expect(
        crowded.accentAt(1.4),
        lessThan(0.1),
        reason: 'the weaker neighbour within the spacing floor must not fire '
            'its own full hit',
      );
      expect(crowded.accentAt(3), closeTo(0.4, 1e-9));
      expect(crowded.accentAt(5), 0);
    });
  });

  group('DancePerformance — property invariants (glados)', () {
    final perf = _perf(
      sections: const [
        (start: 0, end: 6, label: 'A', energetic: true, level: 1),
      ],
    );

    glados.Glados(
      glados.any.choreoArgs,
      glados.ExploreConfig(numRuns: 300),
    ).test(
      'every choreo trio is three cats led by ensemble[0]',
      (a) {
        final trio = perf.choreoTrioForSection(
          a.section,
          a.phase,
          a.level,
          a.variant,
        );
        expect(trio.ensemble.length, 3);
        expect(trio.ensemble.first.name, trio.lead.name);
        // ensemble[0] IS the lead instance — the renderer and UI use that as
        // the canonical lead identity, so the invariant test asserts identity.
        expect(identical(trio.ensemble.first, trio.lead), isTrue);
      },
      tags: 'glados',
    );

    glados.Glados(glados.any.dancePos, glados.ExploreConfig(numRuns: 200)).test(
      'beatPulse stays within 0..1 for any position',
      (pos) => expect(perf.beatPulse(pos), inInclusiveRange(0, 1)),
      tags: 'glados',
    );

    glados.Glados(glados.any.dancePos, glados.ExploreConfig(numRuns: 200)).test(
      'stageAt yields a 3-cat trio on a finite, non-negative clock',
      (pos) {
        final stage = perf.stageAt(pos);
        expect(stage.ensemble.length, 3);
        expect(stage.dynamics.length, 3);
        expect(stage.seconds.isFinite, isTrue);
        expect(stage.seconds, greaterThanOrEqualTo(0));
      },
      tags: 'glados',
    );

    glados.Glados(glados.any.easeArgs, glados.ExploreConfig(numRuns: 200)).test(
      'easeDanceMouth never overshoots its target',
      (a) {
        final r = easeDanceMouth(a.current, a.target, a.dt);
        final lo = a.current < a.target ? a.current : a.target;
        final hi = a.current < a.target ? a.target : a.current;
        expect(r, inInclusiveRange(lo, hi));
      },
      tags: 'glados',
    );
  });
}
