/// The shared, pure per-frame *derivation* for the beat-synced dance showcase.
///
/// Both the live audio player (`DanceToTrackPage`) and the offline frame
/// composer (`DanceFrameComposer`, used by the MP4 exporter and the position-
/// window debug harness) turn an **audio position in seconds** into the same
/// on-screen content: which move the trio dances, the warped pose clock it
/// samples, the musical beat pulse, and the virtual director's camera context.
///
/// Keeping that derivation in one place means an offline render matches the
/// running app's *move, pose clock, beat and camera* at a position — there is a
/// single source of truth for those, so they cannot drift. (The paint constants
/// and the stage-light rig are likewise single-sourced in `DanceStageView`; only
/// the ambient stage-light *phase* differs offline, by design — see that file.)
/// Everything here is a pure function of `pos` plus the loaded track data; the
/// stateful parts (the camera rig's smoothing, mouth easing) live in the callers
/// (`DancePlaybackStepper`) and consume these results.
library;

import 'dart:math' as math;

import 'package:dancing_cats/features/character/demo/dance_camera_director.dart';
import 'package:dancing_cats/features/character/demo/dance_lip_sync.dart';
import 'package:dancing_cats/features/character/model/beat_map.dart';
import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/dance_dynamics.dart';
import 'package:dancing_cats/features/character/model/dance_dynamics_warp.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';

/// A structural energy section of the track, tagged energetic/calm with a
/// normalized 0..1 energy `level` across the song's sections.
typedef DanceSection = ({
  double start,
  double end,
  String label,
  bool energetic,
  double level,
});

/// A word from the optional synced-lyrics file. `voice` is `lead` or
/// `background`; `section` is the semantic (lyric) section tag.
typedef DanceWord = ({
  double start,
  double end,
  String word,
  String voice,
  String section,
});

/// A contiguous semantic-section span collapsed from the per-word section tags —
/// each chorus / verse / bridge occurrence is its own span.
typedef DanceSectionSpan = ({double start, double end, String section});

/// The lead move plus the three-cat ensemble (ensemble[0] is the lead's clip).
typedef DanceTrio = ({Clip lead, List<Clip> ensemble});

/// One frame of additive hand-flourish displacement for a Moving lane, in rig
/// units: (lx, ly) offsets the left hand's IK target, (rx, ry) the right.
typedef DanceHandFlourish = ({double lx, double ly, double rx, double ry});

/// The flourish at rest — wrappers treat it as a zero-cost identity.
const DanceHandFlourish kNoHandFlourish = (lx: 0, ly: 0, rx: 0, ry: 0);

/// Per-lane Laban-Effort personality offsets, index-parallel to
/// `DanceTrio.ensemble` (`[0]` lead, `[1]` backup-left, `[2]` backup-right).
/// Composed with each move's base dynamics and the section-energy term via
/// `effectiveDanceDynamics` in [DancePerformance.stageAt]. Perceptual dials
/// (ADR CHAR-0001 D6) — the lead reads a touch harder/snappier/looser than
/// the pack, backup-left is the loosest (most Free) of the three, backup-right
/// the tightest (most Bound); every axis stays well under
/// `kDanceDynamicsModulationBudget` so it never risks inverting a move's
/// authored Effort character (ADR CHAR-0003).
const List<DanceDynamics> kDanceLaneDynamicsProfiles = [
  DanceDynamics(weight: 0.10, time: 0.08, flow: 0.05), // lead
  DanceDynamics(weight: -0.08, time: -0.05, flow: 0.08), // backup-left
  DanceDynamics(weight: -0.03, time: 0.04, flow: -0.06), // backup-right
];

/// The per-axis Effort swing at the hottest section (`level == 1`); the
/// coldest section (`level == 0`) gets the negated offset. A quiet verse
/// pulls the whole trio toward Light/Sustained; the drop pushes toward
/// Strong/Sudden — continuous with the song's energy arc, on top of (not
/// instead of) `choreoTrioByLevel`'s discrete move selection. Perceptual
/// dial (ADR CHAR-0001 D6), sized with the lane profiles above to stay
/// under `kDanceDynamicsModulationBudget`.
const DanceDynamics kDanceSectionEnergyGain = DanceDynamics(
  weight: 0.18,
  time: 0.20,
  flow: 0.05,
);

/// Maps the section's normalized 0..1 energy `level` to a continuous Effort
/// offset: `0.5` (mid-energy) is neutral, `0` and `1` are the full swing in
/// opposite directions. Continuous (not thresholded) so the same catalog move
/// breathes with the song instead of only changing character at the discrete
/// move-selection boundaries `choreoTrioByLevel` already has.
DanceDynamics sectionEnergyDynamics(double level) =>
    kDanceSectionEnergyGain.scale((level.clamp(0, 1) - 0.5) * 2);

/// Multiplier on the waveform-driven dance energy per section occurrence —
/// the PERFORMANCE arc, layered over the track's raw loudness.
///
/// The raw waveform peaks early (first chorus ~0.74, late chorus ~0.78), so
/// an untiered performance visually peaks at chorus one and coasts downhill —
/// the round-2 panel measured window motion energy of chorus 5.28 vs late
/// chorus 4.79 vs finale 4.03 and read the back half as deflating. Real
/// staging holds the first chorus in reserve and spends everything on the
/// last one; this tier caps the early statements and releases the ceiling as
/// occurrences accumulate. Verses/bridge sit low so the valley is an energy
/// valley, not just a vocabulary change.
double danceSectionArcTier(String section, int occurrence) {
  switch (section) {
    case 'chorus':
      return occurrence <= 0 ? 0.90 : (occurrence == 1 ? 0.96 : 1.08);
    case 'post-chorus':
      return occurrence <= 0 ? 0.97 : 1.06;
    case 'pre-chorus':
      return 0.92;
    case 'verse':
      // Lowered 0.85 -> 0.80 with the bridge (round-4 cartoon: the valley
      // measured 1.08x the capped chorus — "a valley that forgot to be a
      // valley"); the quiet-step loading and full lunge vocabulary carry
      // plenty of life at the smaller extent.
      return 0.80;
    case 'bridge':
      return 0.78;
    case 'outro':
      return 1;
    default:
      return 1;
  }
}

/// Everything the painter needs for one frame: the lead clip, the ensemble
/// clips, the warped pose clock `seconds`, the active `section`, whether the
/// section is energetic, whether the trio dances in unison (`synchronous`)
/// or canon (staggered phase, e.g. the Pouncing-Cat glide), and each member's
/// effective Laban-Effort `dynamics` (index-parallel to `ensemble`: `[0]` is
/// the lead's, matching `ensemble[0]`).
typedef DanceStage = ({
  Clip lead,
  List<Clip> ensemble,
  double seconds,
  DanceSection? section,
  bool energetic,
  bool synchronous,
  // When the current choreo STATEMENT began (audio seconds): the section,
  // slot, or intra-section handoff boundary that selected this trio. The
  // stepper re-anchors the phrase clock on the first downbeat at/after this
  // instant so incoming moves open on their own bar 1 ("take the new move
  // on the one") instead of whatever bar the global grid dictates.
  double segmentStartSec,
  List<DanceDynamics> dynamics,
  // Raw 0..1 section energy at this frame (0.5 = neutral). Drives the effort
  // AMPLITUDE arc (how big the hands move) directly, isolated from the moves'
  // own Effort weight and the ±budget that clamps energy out of `dynamics`.
  double energyLevel,
});

/// Number of bars the looping dance phrase spans; the loop stays beat-locked
/// for the whole track once anchored on the first downbeat.
///
/// FOUR bars — the HALF-TIME interpretation (owner decision, 2026-07-05):
/// the 32-frame phrase spans 16 beats — exactly 2 frames per beat — so
/// every authored accent (frames 0/4/8/...) still lands dead ON a real
/// beat, but the counts fall on every OTHER beat: the body's full groove
/// cycle spans two beats, the way dancers actually ride a ~120 BPM track.
/// The previous TWO-bar binding packed a full-body event onto every beat
/// AND played the 6s-authored phrase 1.5x fast (6s squeezed into an 8-beat
/// / 4s window) — reviewed at the slow clock, it shipped as "everyone on
/// uppers... doubtful they would make it through a real show". At 16 beats
/// the phrase spans 8 real seconds: half the previous live speed, and the
/// review-vs-ship gap drops from 1.5x to 0.75x. (The still-earlier 3-bar
/// binding gave 2 2/3 frames per beat — accents BETWEEN beats — and stays
/// wrong for a different reason.)
const int kDancePhraseBars = 4;

/// How much faster the shipped app's beat-warped pose clock runs than the
/// raw, authored clip clock (`_danceBase.duration`) motion-quality tests
/// sample against.
///
/// `BeatMap.clipSecondsAt` re-maps clip-relative time onto the *real* detected
/// beat grid via `BeatLoopBinding.barAligned`, whose loop spans
/// `kDancePhraseBars * timeSignatureNumerator` beats — 16 beats for this
/// track's 4/4 time signature. At the sample track's detected
/// `tempo.global_bpm` (`assets/sample_track/moving.json`, 120.0), 16 beats
/// take `16 * 60 / 120 = 8` real seconds, versus the `_danceBase` clip's
/// authored `duration: 6` seconds — so the live/exported app plays CATALOGUE
/// routines at `6 / 8 = 0.75x` of the raw clip clock the film-strip tests and
/// `TemporalMotionAnalyzer` sample by default (slightly SLOWER than
/// authored, the sustainable half-time read — down from the previous
/// two-bar binding's 1.5x, which shipped frantic). The Moving family does NOT
/// use this factor — see [danceRealTempoSpeedupFor].
///
/// This is *this project's current default track's* factor, not a universal
/// constant — it would need recomputing (from the same formula) if the
/// sample track or `kDancePhraseBars` ever changes. Compressing time by factor
/// `k` scales the n-th time-derivative by `k^n`, so callers multiply speed by
/// `k`, acceleration by `k^2`, and jerk by `k^3` rather than resampling at a
/// different clock.
const double kDanceRealTempoSpeedup = 6 / 8;

/// Real-tempo factor for [clip], honoring per-family bindings.
///
/// [kDanceRealTempoSpeedup] describes only the catalogue's four-bar binding.
/// The Moving family runs on its natural two-bar clock (see
/// `kMovingPhraseLoopBeats` in `dance_playback_stepper.dart`): 8 beats take
/// `8 * 60 / 120 = 4` real seconds against the 6-second authored loop, so its
/// shipped clock is `6 / 4 = 1.5x` — TWICE the catalogue constant. Real-tempo
/// motion gates and inspection panels must use this per-clip factor: scaling
/// Moving by the catalogue constant certifies/displays it at half its shipped
/// speed (velocity 2x off, acceleration 4x, jerk 8x).
double danceRealTempoSpeedupFor(Clip clip) =>
    clip.belongsToFamily('moving') ? 6 / 4 : kDanceRealTempoSpeedup;

/// Fraction of the track's energy range below which a section counts as "calm"
/// (and, if also long enough, eases the trio into idle). See [kMinCalmSeconds].
const double kSectionEnergyThreshold = 0.5;

/// Minimum duration for a low-energy section to be treated as calm — shorter
/// transitions stay energetic so the dance doesn't flicker into idle.
const double kMinCalmSeconds = 4;

/// Sections the whole trio sings (a group hook): the backups' mouths join the
/// frontman on the *lead* words here, not just on the `(...)` ad-libs.
const Set<String> kGroupSections = {'chorus', 'post-chorus', 'outro'};

/// Fast attack for the singing mouth: each sung syllable snaps open quickly…
const double kMouthAttackSeconds = 0.045;

/// …then relaxes shut more slowly, so the mouth doesn't flutter symmetrically.
const double kMouthReleaseSeconds = 0.12;

/// Eases a mouth-open value toward [target] with a fast attack and slower
/// release (frame-rate independent via [dt]). Shared by the live player and the
/// offline composer so both animate the singing mouth identically.
double easeDanceMouth(double current, double target, double dt) {
  final tc = target > current ? kMouthAttackSeconds : kMouthReleaseSeconds;
  var k = dt / tc;
  if (k > 1) k = 1;
  return current + (target - current) * k;
}

/// The trio's resting pose for [pos]: all three cats idle, the clock running on
/// raw playback time. Used before the beat map loads and on genuinely dead-quiet
/// sections.
DanceStage danceIdleStage(double pos, {DanceSection? section}) => (
  lead: CatClips.idle,
  ensemble: [CatClips.idle, CatClips.idle, CatClips.idle],
  seconds: pos,
  section: section,
  energetic: false,
  synchronous: true,
  segmentStartSec: section?.start ?? 0,
  dynamics: const [
    DanceDynamics.neutral,
    DanceDynamics.neutral,
    DanceDynamics.neutral,
  ],
  energyLevel: 0.5,
);

/// Tags each detected section energetic/calm by its mean waveform energy
/// (relative to the track's energy range). Calm only when genuinely low-energy
/// AND long enough — short transition sections stay energetic to avoid flicker.
List<DanceSection> classifyDanceSections(
  List<({double start, double end, String label})> raw,
  List<double> amplitudes,
  double duration,
) {
  if (raw.isEmpty || amplitudes.isEmpty || duration <= 0) {
    return [
      for (final s in raw)
        (
          start: s.start,
          end: s.end,
          label: s.label,
          energetic: true,
          level: 1.0,
        ),
    ];
  }
  final n = amplitudes.length;
  double energyOf(double start, double end) {
    var i0 = (start / duration * n).floor();
    var i1 = (end / duration * n).ceil();
    if (i0 < 0) i0 = 0;
    if (i0 >= n) i0 = n - 1;
    if (i1 > n) i1 = n;
    if (i1 <= i0) i1 = i0 + 1;
    var sum = 0.0;
    for (var i = i0; i < i1; i++) {
      sum += amplitudes[i];
    }
    return sum / (i1 - i0);
  }

  final energies = [for (final s in raw) energyOf(s.start, s.end)];
  var minE = energies.first;
  var maxE = energies.first;
  for (final e in energies) {
    if (e < minE) minE = e;
    if (e > maxE) maxE = e;
  }
  final threshold = minE + kSectionEnergyThreshold * (maxE - minE);
  final range = maxE - minE;
  return [
    for (var i = 0; i < raw.length; i++)
      (
        start: raw[i].start,
        end: raw[i].end,
        label: raw[i].label,
        energetic:
            !(energies[i] < threshold &&
                (raw[i].end - raw[i].start) >= kMinCalmSeconds),
        level: range > 0 ? (energies[i] - minE) / range : 1.0,
      ),
  ];
}

/// Collapses the per-word [DanceWord] `section` tags into contiguous spans — each
/// chorus / verse / bridge occurrence becomes its own span — so the director can
/// report progress WITHIN the current section. The last span runs to [duration];
/// earlier ones are trimmed to the next span's start. Empty without tagged words.
List<DanceSectionSpan> buildDanceSectionSpans(
  List<DanceWord> words,
  double duration,
) {
  final spans = <DanceSectionSpan>[];
  for (final w in words) {
    final section = w.section.toLowerCase();
    if (spans.isEmpty || spans.last.section != section) {
      spans.add((start: w.start, end: duration, section: section));
    }
  }
  for (var i = 0; i < spans.length - 1; i++) {
    spans[i] = (
      start: spans[i].start,
      end: spans[i + 1].start,
      section: spans[i].section,
    );
  }
  return spans;
}

/// A short, human display name for a lyric section tag.
String danceSectionDisplayName(String section) {
  switch (section.toLowerCase()) {
    case 'pre-chorus':
      return 'Pre';
    case 'post-chorus':
      return 'Post';
    case 'chorus':
      return 'Chorus';
    case 'verse':
      return 'Verse';
    case 'bridge':
      return 'Bridge';
    case 'intro':
      return 'Intro';
    case 'outro':
      return 'Outro';
    case '':
      return '—';
    default:
      return section[0].toUpperCase() + section.substring(1);
  }
}

/// The single source of truth for what the dance shows at a given audio position.
///
/// Constructed once after the beat map and optional lyrics load; every method is
/// a pure function of its argument plus the immutable track data, so the same
/// `pos` always yields the same stage, beat and camera context — in the live app
/// and in any offline render alike.
class DancePerformance {
  DancePerformance({
    required this.map,
    required this.binding,
    required this.sections,
    required this.sectionSpans,
    required this.trackDurationSec,
    this.words = const [],
    this.waveform = const [],
    this.onsets = const [],
  });

  /// Builds a performance from a parsed beat-map [json] document (the embedded
  /// waveform + structural sections) and the already-parsed [map] / [words], so
  /// the live player and every offline renderer assemble it the same way.
  factory DancePerformance.fromBeatMapJson({
    required Map<String, Object?> json,
    required BeatMap map,
    required double trackDurationSec,
    List<DanceWord> words = const [],
  }) {
    final amplitudes =
        (json['waveform'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        const <double>[];
    final rawSections = ((json['sections'] as List?) ?? const [])
        .cast<Map<String, Object?>>()
        .map(
          (s) => (
            start: (s['start_sec']! as num).toDouble(),
            end: (s['end_sec']! as num).toDouble(),
            label: (s['label'] as String?) ?? '',
          ),
        )
        .toList();
    return DancePerformance(
      map: map,
      binding: BeatLoopBinding.barAligned(map, bars: kDancePhraseBars),
      sections: classifyDanceSections(
        rawSections,
        amplitudes,
        trackDurationSec,
      ),
      sectionSpans: buildDanceSectionSpans(words, trackDurationSec),
      trackDurationSec: trackDurationSec,
      words: words,
      waveform: amplitudes,
      onsets: ((json['onsets'] as List?) ?? const [])
          .cast<Map<String, Object?>>()
          .map(
            (o) => (
              time: (o['time_sec']! as num).toDouble(),
              strength: (o['strength'] as num?)?.toDouble() ?? 1.0,
            ),
          )
          .toList(),
    );
  }

  /// The beat/downbeat map driving the warped pose clock and the beat pulse.
  final BeatMap map;

  /// Anchors the looping phrase on the first downbeat across whole bars.
  final BeatLoopBinding binding;

  /// Structural energy sections (gate idle vs. dance, drive the level fallback).
  final List<DanceSection> sections;

  /// Semantic (lyric) section spans (drive the lyric-aware choreography).
  final List<DanceSectionSpan> sectionSpans;

  /// Optional synced lyrics (drive the singing mouths in the callers).
  final List<DanceWord> words;

  /// Whole-track duration in seconds (normalizes the director's build progress).
  final double trackDurationSec;

  /// The embedded 0..1 loudness envelope over the whole track (the beat map's
  /// `waveform`), stored so motion can react to the CONTINUOUS song energy
  /// (music-reactive amplitude) instead of the coarse per-section step. Empty
  /// for synthetic/test performances built without a waveform.
  final List<double> waveform;

  late final ({double min, double max}) _waveformRange = (() {
    if (waveform.isEmpty) return (min: 0.0, max: 1.0);
    var lo = waveform.first;
    var hi = waveform.first;
    for (final v in waveform) {
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    return (min: lo, max: hi);
  })();

  /// Smoothed, normalized continuous loudness at [posSec] (0..1) — "how loud is
  /// the track right now." Drives the dance amplitude so movement swells into
  /// the drops and eases through the breakdown, instead of stepping once per
  /// section. Smoothed over ~0.3 s so per-hit spikes don't jitter the size.
  /// Falls back to 0.5 when no waveform is embedded (synthetic performances).
  double intensityAt(double posSec) {
    final n = waveform.length;
    if (n == 0 || trackDurationSec <= 0) return 0.5;
    final binsPerSec = n / trackDurationSec;
    final center = posSec / trackDurationSec * n;
    final half = (0.15 * binsPerSec).clamp(1.0, n.toDouble());
    var i0 = (center - half).floor();
    var i1 = (center + half).ceil();
    if (i0 < 0) i0 = 0;
    if (i1 > n) i1 = n;
    if (i1 <= i0) i1 = (i0 + 1).clamp(1, n);
    var sum = 0.0;
    for (var i = i0; i < i1; i++) {
      sum += waveform[i];
    }
    final mean = sum / (i1 - i0);
    final span = _waveformRange.max - _waveformRange.min;
    return span > 0
        ? ((mean - _waveformRange.min) / span).clamp(0.0, 1.0)
        : 0.5;
  }

  /// Per-transient ACCENT onsets from the beat map's `onsets`
  /// (`{time_sec, strength}`), so the body can HIT on the track's actual
  /// transients. Empty for synthetic/test performances.
  final List<({double time, double strength})> onsets;

  // Accent selection is PEAK-PICKED, not flat-floored. The old 0.5 strength
  // floor kept the chorus honest (~0.5 hits/s) but starved softer-mixed
  // sections: the late chorus (98-118s) has only 4 onsets above 0.5 in 20
  // seconds while 18 sit between 0.35 and 0.5 — the song's peak section
  // danced with almost no hits. Candidates down to 0.35 are admitted, but
  // greedily by strength with a minimum spacing, so the strongest transient
  // in each neighbourhood wins and the accent rate stays at most roughly
  // every other beat — never a bob on every 16th, which reads hectic.
  static const double _kAccentCandidateFloor = 0.35;
  static const double _kAccentMinSpacingSec = 1;
  static const double _kAccentDecaySec = 0.42;

  /// How long the dark flank's reprise answer sustains at peak before its
  /// release plays (see [_laneAccentHoldSec]) — about five 60fps frames, a
  /// readable hold at playback speed without blunting the hit-and-breathe
  /// release the rest of the song keeps.
  static const double kMovingRepriseAccentHoldSec = 0.08;

  /// How far past neutral the accent's release BREATHES back up, as a
  /// fraction of the drop (see [accentAt]'s breathe lobe). A plié that only
  /// sinks and returns reads as a lean; real weight rebounds slightly above
  /// neutral before settling (coach: "hit and breathe"). Deepened 0.15→0.22
  /// and the window extended 0.3→0.42s with a faster recovery share, per the
  /// round-3 MV read: the first chorus "nods where the finale punches" — the
  /// pop after the dip needs to read at roughly a third of the dip over
  /// ~250ms, not vanish inside 130ms.
  static const double _kAccentReboundDepth = 0.22;

  /// Fraction of [_kAccentDecaySec] spent recovering from the drop; the rest
  /// carries the breathe lobe past neutral and settles.
  static const double _kAccentRecoverShare = 0.4;

  /// Window (seconds) BEFORE a strong onset over which the body "coils" in
  /// anticipation of the hit — a short gather that releases into [accentAt]'s
  /// pop on the beat. ~0.1 s is a couple of frames of wind-up at any real fps:
  /// visible as a load, still fast enough to read as one gesture with the hit.
  static const double _kAnticipationWindowSec = 0.1;

  /// Fixed candidate strength for the SECONDARY accent tier: the lead
  /// vocal's word starts. Some stretches carry no strong instrumental
  /// transient at all (the late chorus opens with a 2.2s hole in the onset
  /// data) yet the vocal clearly phrases there — and hitting on the vocal
  /// entry is exactly what a dancer does. Kept below the instrumental
  /// candidates' typical strengths so a real transient always outranks a
  /// word start in the peak picking.
  static const double _kVocalAccentStrength = 0.42;

  /// The onsets that fire a visible body accent: strength-greedy peak picking
  /// with [_kAccentMinSpacingSec] between hits (see the constants above for
  /// why this replaced a flat strength floor). Instrumental onsets are joined
  /// by a secondary tier of lead-vocal word starts (see
  /// [_kVocalAccentStrength]). Pre-computed once, sorted by time.
  late final List<({double time, double strength})> _accentOnsets = () {
    final candidates = [
      for (final o in onsets)
        if (o.strength >= _kAccentCandidateFloor) o,
      for (final w in words)
        if (w.voice == 'lead')
          (time: w.start, strength: _kVocalAccentStrength),
    ]..sort((a, b) => b.strength.compareTo(a.strength));
    final picked = <({double time, double strength})>[];
    for (final o in candidates) {
      final tooClose = picked.any(
        (p) => (p.time - o.time).abs() < _kAccentMinSpacingSec,
      );
      if (!tooClose) picked.add(o);
    }
    picked.sort((a, b) => a.time.compareTo(b.time));
    return picked;
  }();

  /// Music-driven accent envelope at [posSec] (0..1): a quick decay pop on the
  /// most recent STRONG onset, so the body lands WITH the track's hits. 0
  /// between hits; 0 with no onsets (synthetic performances).
  ///
  /// [holdSec] sustains the envelope AT its peak for that long before the
  /// release plays (the whole decay shifts later, the attack stays on the
  /// onset) — the "held accent frame" the reprise answer earns. The value is
  /// continuous in [holdSec], so a hold that ramps with a blend cannot step
  /// the envelope.
  double accentAt(double posSec, {double holdSec = 0}) {
    final o = _accentOnsets;
    if (o.isEmpty) return 0;
    var lo = 0;
    var hi = o.length - 1;
    var idx = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (o[mid].time <= posSec) {
        idx = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    if (idx < 0) return 0;
    final dt = posSec - o[idx].time;
    if (dt < 0 || dt > _kAccentDecaySec + holdSec) return 0;
    final u = ((dt - holdSec) / _kAccentDecaySec).clamp(0.0, 1.0);
    // Drop, then BREATHE. The drop eases out with zero velocity at the onset
    // and reaches neutral at [_kAccentRecoverShare] of the window; the
    // remainder is a C1 negative lobe (zero-derivative at both ends) dipping
    // [_kAccentReboundDepth] past neutral — the body rebounds slightly above
    // its groove line before settling, hit-and-breathe instead of
    // sink-and-return. Consumers that must stay non-negative (lights,
    // formation pop) clamp on their side; the body load deliberately
    // receives the negative tail as a lift.
    final double shape;
    if (u < _kAccentRecoverShare) {
      final r = u / _kAccentRecoverShare;
      shape = 1 - r * r * (3 - 2 * r);
    } else {
      final v = (u - _kAccentRecoverShare) / (1 - _kAccentRecoverShare);
      shape = -_kAccentReboundDepth * 16 * v * v * (1 - v) * (1 - v);
    }
    return (shape * o[idx].strength).clamp(-1.0, 1.0);
  }

  /// The accent envelope a LANE receives: a canon voice answering
  /// [echoBeats] behind the ensemble clock hits — and is lit — on its OWN
  /// displaced beat. With a scalar envelope the whole rig bloomed on the
  /// call while the answers played dark (round-5 MV: "the middle voice of
  /// the canon dances unlit"), and the flank pliés dropped on the lead's
  /// beat under bodies that answer later.
  double laneAccentAt(double posSec, double echoBeats) => echoBeats == 0
      ? accentAt(posSec)
      : accentAt(
          map.timeAtBeat(map.beatAt(posSec) - echoBeats),
          holdSec: _laneAccentHoldSec(posSec, echoBeats),
        );

  /// Peak-hold for the one-beat echo voice's REPRISE answers: in the final
  /// post-chorus the dark flank sustains each hit at full depth for
  /// [kMovingRepriseAccentHoldSec] before the release plays — the held
  /// accent frame that marks the reprise's answer as a statement rather
  /// than a passing hit (round-6 animator), in the one section where the
  /// canon returns as the arc's peak. Shaped as a smooth bump over the
  /// DISPLACEMENT: a blending clip's `echoBeats` lerps through the blend
  /// window, so a boolean gate would step the envelope mid-decay; the bump
  /// ramps the hold in and out with the blend, peaks on the one-beat voice,
  /// and has already faded to ~0.1x at the two-beat canon voice.
  double _laneAccentHoldSec(double posSec, double echoBeats) {
    if (echoBeats <= 0) return 0;
    if (!sectionIsFinalOccurrenceAt(posSec, 'post-chorus')) return 0;
    final bump =
        1 - (echoBeats - kMovingEchoAnswerBeats).abs() / kMovingEchoAnswerBeats;
    return bump <= 0 ? 0 : kMovingRepriseAccentHoldSec * bump;
  }

  /// [anticipationAt] for a displaced voice — see [laneAccentAt].
  double laneAnticipationAt(double posSec, double echoBeats) => echoBeats == 0
      ? anticipationAt(posSec)
      : anticipationAt(map.timeAtBeat(map.beatAt(posSec) - echoBeats));

  /// The accent envelope for a STAGE clip, blend-aware. A transitioning clip
  /// carries a LERPED `echoBeats`, but the envelope is nonlinear in the
  /// displacement: evaluating it at the lerped value sweeps the displaced
  /// lookup across the track at several times real speed (a 2-beat canon
  /// exiting over a 0.44s blend fast-forwards ~1.1s of onsets), and any
  /// onset attack the sweep crosses REPLAYS as a compressed flash — shipped
  /// as a one-frame full-stage light pop at 114.73s, where the reprise exit
  /// swept grey's lookup across the cadence hit. Blend the ENVELOPES of the
  /// plan's two sides instead: endpoints match the pure clips exactly, and
  /// no lookup ever moves faster than the track.
  double laneAccentForClip(double posSec, Clip clip) {
    final plan = clip.transitionPlan;
    if (plan == null) return laneAccentAt(posSec, clip.echoBeats);
    final from = laneAccentAt(posSec, plan.from.echoBeats);
    final to = laneAccentAt(posSec, plan.to.echoBeats);
    return from + (to - from) * plan.weight;
  }

  /// [laneAccentForClip] for the look-ahead coil.
  double laneAnticipationForClip(double posSec, Clip clip) {
    final plan = clip.transitionPlan;
    if (plan == null) return laneAnticipationAt(posSec, clip.echoBeats);
    final from = laneAnticipationAt(posSec, plan.from.echoBeats);
    final to = laneAnticipationAt(posSec, plan.to.echoBeats);
    return from + (to - from) * plan.weight;
  }

  /// Peak hand-flourish displacement, in rig units, at full load. Small next
  /// to the authored hand paths — a shading on the phrase, not a new phrase.
  static const double kMovingFlourishUnits = 4.5;

  /// Peak subdivision-fill radius, in rig units, at full onset strength.
  static const double kMovingFillUnits = 3;

  /// How long a subdivision fill's pickup runs before the hit it leads into.
  static const double kMovingFillBeats = 1.5;

  /// A quad-time roll must be BIGGER and LONGER than a double-time one to
  /// read at all: at 3 units a 4x roll was a sub-pixel shimmer (owner:
  /// "might be too subtle, did not notice it"). The faster the subdivision,
  /// the more amplitude and runway it earns.
  static const double kMovingQuadFillBoost = 2;
  static const double kMovingDoubleFillBoost = 1.25;
  static const double kMovingQuadFillBeats = 2.5;

  /// Per-onset ornament directions, one picked per hit by [_flourishHash]:
  /// outward flick, lift, press, inward pull. The two hands never mirror
  /// exactly (asymmetric magnitudes), matching the authored microtiming
  /// asymmetry. y is rig-down, so a lift is negative.
  static const List<DanceHandFlourish> _kFlourishFlavors = [
    (lx: -1, ly: -0.25, rx: 0.85, ry: -0.2),
    (lx: 0.1, ly: -1.0, rx: -0.1, ry: -0.85),
    (lx: 0.45, ly: 0.8, rx: -0.35, ry: 0.7),
    (lx: 0.8, ly: -0.3, rx: -0.7, ry: -0.25),
  ];

  /// Deterministic 0..1 hash of (onset index, lane, salt) — the flourish's
  /// only source of "randomness", so every render of the same song makes the
  /// same choices and tests can pin them.
  static double _flourishHash(int idx, int lane, int salt) {
    var h = idx * 374761393 + lane * 668265263 + salt * 2246822519;
    h = (h ^ (h >> 13)) * 1274126177;
    h = h ^ (h >> 16);
    return (h & 0xfffff) / 0x100000;
  }

  /// Index of the latest onset at or before [t] (-1 before the first).
  int _lastOnsetIndex(double t) {
    final o = _accentOnsets;
    var lo = 0;
    var hi = o.length - 1;
    var idx = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (o[mid].time <= t) {
        idx = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return idx;
  }

  /// The subdivision (0 = none, 2 = double-time, 4 = quad) onset [idx] earns
  /// as a pickup fill for [lane]. Rare by design (owner: "probably rarely"):
  /// ~16% of strong onsets roll double-time, ~10% quad.
  int _fillSubdivision(int idx, int lane, double strength) {
    if (strength < 0.55) return 0;
    final r = _flourishHash(idx, lane, 2);
    if (r < 0.10) return 4;
    if (r < 0.26) return 2;
    return 0;
  }

  /// The hand-flourish displacement for a Moving lane at [posSec] — the
  /// variation layer that keeps repeated hits from reading identical
  /// (owner: "hand movement is still a bit monotonous"). Two additive terms,
  /// each continuous by construction so the hands can never teleport:
  ///
  /// 1. A per-hit ORNAMENT riding the same joined load envelope as the plié
  ///    (anticipation meets the accent AT the hit, so the ride is continuous),
  ///    with a deterministic per-onset flavor — flick / lift / press / pull.
  ///    Flavors can only switch while the load is zero: decay (0.42s) + the
  ///    reprise hold (0.08s) + the coil window (0.1s) stay under the 1s
  ///    onset spacing floor, so there is always a dead zone between hits.
  /// 2. A RARE beat-locked subdivision fill (double- or quad-time wrist
  ///    roll) that swells through a [kMovingFillBeats] pickup and dies
  ///    exactly at the hit it leads into — sin² bump, zero value AND slope
  ///    at both ends, window clamped clear of the previous onset so the
  ///    owning-onset flip always happens at zero amplitude.
  DanceHandFlourish _handFlourishAt(double posSec, double echoBeats, int lane) {
    final o = _accentOnsets;
    if (o.isEmpty) return kNoHandFlourish;
    final dp = echoBeats == 0
        ? posSec
        : map.timeAtBeat(map.beatAt(posSec) - echoBeats);

    var lx = 0.0;
    var ly = 0.0;
    var rx = 0.0;
    var ry = 0.0;

    final acc = laneAccentAt(posSec, echoBeats).clamp(0.0, 1.0);
    final ant = laneAnticipationAt(posSec, echoBeats);
    final load = acc >= ant ? acc : ant;
    if (load > 0) {
      final owner = acc >= ant ? _lastOnsetIndex(dp) : _lastOnsetIndex(dp) + 1;
      final flavor =
          (_flourishHash(owner, lane, 1) * _kFlourishFlavors.length)
              .floor()
              .clamp(0, _kFlourishFlavors.length - 1);
      final v = _kFlourishFlavors[flavor];
      final amp = kMovingFlourishUnits * load;
      lx += amp * v.lx;
      ly += amp * v.ly;
      rx += amp * v.rx;
      ry += amp * v.ry;
    }

    final next = _lastOnsetIndex(dp) + 1;
    if (next < o.length) {
      final subdivision = _fillSubdivision(next, lane, o[next].strength);
      if (subdivision > 0) {
        final quad = subdivision == 4;
        final tn = o[next].time;
        var windowSec =
            tn -
            map.timeAtBeat(
              map.beatAt(tn) - (quad ? kMovingQuadFillBeats : kMovingFillBeats),
            );
        if (next > 0) {
          windowSec = math.min(windowSec, 0.9 * (tn - o[next - 1].time));
        }
        if (windowSec > 0) {
          final u = 1 - (tn - dp) / windowSec;
          if (u > 0 && u < 1) {
            final bump = math.sin(math.pi * u);
            final swell = bump * bump;
            final phase =
                2 * math.pi * subdivision * map.beatAt(dp) + lane * 0.9;
            final amp =
                kMovingFillUnits *
                (quad ? kMovingQuadFillBoost : kMovingDoubleFillBoost) *
                o[next].strength *
                swell;
            lx += amp * math.sin(phase);
            ly += amp * 0.8 * math.cos(phase);
            rx += amp * math.sin(phase + 2.2);
            ry += amp * 0.8 * math.cos(phase + 2.2);
          }
        }
      }
    }
    return (lx: lx, ly: ly, rx: rx, ry: ry);
  }

  /// [_handFlourishAt] for a STAGE clip, blend-aware the same way
  /// [laneAccentForClip] is: the flourish of a transitioning clip is the
  /// LERP of its two sides' flourishes — never an evaluation at the lerped
  /// displacement, which sweeps onset attacks (the 114.73s one-frame pop).
  DanceHandFlourish laneHandFlourishFor(double posSec, Clip clip, int lane) {
    final plan = clip.transitionPlan;
    if (plan == null) return _handFlourishAt(posSec, clip.echoBeats, lane);
    final from = _handFlourishAt(posSec, plan.from.echoBeats, lane);
    final to = _handFlourishAt(posSec, plan.to.echoBeats, lane);
    final w = plan.weight;
    return (
      lx: from.lx + (to.lx - from.lx) * w,
      ly: from.ly + (to.ly - from.ly) * w,
      rx: from.rx + (to.rx - from.rx) * w,
      ry: from.ry + (to.ry - from.ry) * w,
    );
  }

  /// Look-ahead "coil" envelope at [posSec] (0..1): rises as the NEXT strong
  /// onset approaches (within [_kAnticipationWindowSec]) and returns to 0 AT
  /// the onset, where [accentAt]'s instant attack takes over — so the body
  /// gathers into the hit, then releases on the beat. Scaled by the imminent
  /// onset's strength (a bigger hit earns a bigger wind-up). 0 when no strong
  /// onset is near, and 0 for synthetic performances with no onsets.
  double anticipationAt(double posSec) {
    final o = _accentOnsets;
    if (o.isEmpty) return 0;
    // First strong onset STRICTLY after posSec.
    var lo = 0;
    var hi = o.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (o[mid].time <= posSec) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    if (lo >= o.length) return 0;
    final dt = o[lo].time - posSec; // > 0
    if (dt >= _kAnticipationWindowSec) return 0;
    // Rise 0 -> 1 as the onset nears with zero endpoint velocity. The half-open
    // window leaves the onset itself to [accentAt]; combining the two envelopes
    // for the body load therefore produces a continuous planted compression,
    // not a one-frame downward teleport on every detected hit.
    final u = (1 - dt / _kAnticipationWindowSec).clamp(0.0, 1.0);
    final ramp = u * u * (3 - 2 * u);
    return (o[lo].strength * ramp).clamp(0.0, 1.0);
  }

  static final Clip _shaku = CatClips.shaku;
  static final Clip _zanku = CatClips.zanku;
  static final Clip _azonto = CatClips.azonto;
  static final Clip _buga = CatClips.buga;
  static final Clip _sekem = CatClips.sekem;
  static final Clip _moving = CatClips.movingGroove;
  static final Clip _movingLowCounter = CatClips.movingGrooveLowCounter;
  static final Clip _movingSideAnswer = CatClips.movingGrooveSideAnswer;

  /// The side-answer answering ONE BEAT behind the lead's call — the
  /// WHOLE dancer (steps, weight changes, contacts included, see
  /// [wholeClipPhaseShiftedClip]): an upper-body-only echo measured as lag-0
  /// whole-body correlation because the shared feet dominated. A score-level
  /// variant (not a production-stage wrapper) so transitions blend it as an
  /// ordinary clip on its own clock.
  static final Clip _movingSideAnswerEcho = wholeClipPhaseShiftedClip(
    CatClips.movingGrooveSideAnswer,
    kMovingEchoPhase,
  );

  /// The grey flank's FEATURED canon voice: the low counter two beats
  /// behind the lead in the hook call — a literal QUOTE of the lead's own
  /// hook motif, so the trio reads as call → answer → later answer of the
  /// SAME sentence instead of three simultaneous different ones.
  static final Clip _movingLowCounterCanon = upperBodyPhaseOffsetClip(
    wholeClipPhaseShiftedClip(CatClips.movingGroove, kMovingCanonPhase),
    // Re-lock the quote's arms to its feet: the source phrase's arm accents
    // ride ~50-80ms hot of its footwork — the lead wears that as style, but
    // on the two-beat quote it measured as the second voice RUSHING its
    // answer (round-6 animator: arm median -103ms vs feet -87ms). A small
    // extra upper-body delay aligns the quoted arms with the quoted steps.
    // Safe here because the offset is baked into the score-level variant
    // (pre-blend), exactly like the displacement itself.
    kMovingCanonArmRelock,
    upperBodyBoneIds: kDanceUpperBodyWarpBoneIds,
  );

  /// The right flank's one-beat QUOTE of the lead's hook motif for the CALL
  /// statement. Round-4 coach and animator converged on the same finding: a
  /// displaced *different* phrase reads as counterpoint, not conversation
  /// ("duplicate the lead's call gesture, delay it" / "copy the lead's
  /// gesture curve") — and a one-beat shift of a different beat-periodic
  /// phrase aliased to lag-0 in every measured window. The per-lane
  /// amplitude spread keeps both quotes subordinate to the call.
  static final Clip _movingHookEcho = wholeClipPhaseShiftedClip(
    CatClips.movingGroove,
    kMovingEchoPhase,
  );
  static final Clip _movingVerse = CatClips.movingVerseGroove;
  static final Clip _movingVerseWindow = CatClips.movingVerseWindow;
  static final Clip _movingBreakdown = CatClips.movingBreakdownGroove;
  static final Clip _movingChorusTravel = CatClips.movingChorusTravel;
  static final Clip _movingChorusOpen = CatClips.movingChorusOpen;
  static final Clip _movingBridgeRock = CatClips.movingBridgeRock;
  static final Clip _movingBodyRoll = CatClips.movingBodyRoll;

  /// How far open the lyric-synced mouth slack window is dilated so short gaps
  /// between a phrase's words don't make the mouth flicker shut.
  static const double voiceSlack = 0.3;

  /// The full per-frame stage at [pos]: the clip + warped clock for the current
  /// section. The trio dances the routine chosen for the current semantic (lyric)
  /// section, falling back to the energy level when the song has no lyrics; it
  /// only fully rests on a genuinely dead-quiet section. The lead's duration sets
  /// the beat-lock clock (all dance moves share the phrase length).
  DanceStage stageAt(double pos) {
    final section = sectionAt(pos);
    final level = section?.level ?? 1.0;
    final resting = section != null && !section.energetic && level < 0.15;
    if (!resting) {
      final lyric = sectionInfoAt(pos);
      final occ = sectionOccurrenceAt(pos, lyric.section);
      final trio = choreoTrioForSection(
        lyric.section,
        lyric.phase,
        level,
        occ,
        sectionSeconds: lyric.seconds,
        finalOccurrence: sectionIsFinalOccurrenceAt(pos, lyric.section),
      );
      final sectionDynamics = sectionEnergyDynamics(level);
      // Music-reactive amplitude: the dance size follows the CONTINUOUS track
      // loudness (swells into drops, eases through the breakdown) instead of the
      // coarse per-section step, TIERED by the section arc (see
      // [danceSectionArcTier]) so the performance builds across the song
      // instead of peaking at the first chorus. Quantized to 0.05 to bound the
      // effort-clip cache; falls back to the section level for synthetic
      // (no-waveform) perfs.
      final danceEnergy = waveform.isEmpty
          ? level
          : ((intensityAt(pos) * danceSectionArcTier(lyric.section, occ))
                        .clamp(0.0, 1.0) *
                    20)
                .round() /
            20;
      return (
        lead: trio.lead,
        ensemble: trio.ensemble,
        seconds: map.clipSecondsAt(
          pos,
          clipDuration: trio.lead.duration,
          binding: binding,
        ),
        section: section,
        energetic: section?.energetic ?? true,
        synchronous: true,
        segmentStartSec: segmentStartAt(pos),
        dynamics: [
          for (var i = 0; i < trio.ensemble.length; i++)
            effectiveDanceDynamics(
              moveBase: trio.ensemble[i].dynamics,
              catProfile: kDanceLaneDynamicsProfiles[i],
              sectionEnergy: sectionDynamics,
            ),
        ],
        energyLevel: danceEnergy,
      );
    }
    return danceIdleStage(pos, section: section);
  }

  /// The structural energy section covering [pos] (the last section past the end).
  DanceSection? sectionAt(double pos) {
    for (final s in sections) {
      if (pos >= s.start && pos < s.end) return s;
    }
    return sections.isEmpty ? null : sections.last;
  }

  /// Where [pos] sits inside the current semantic section: its label, progress
  /// 0..1, the section's length in seconds, and its start time. Defaults to
  /// the empty section when no span covers [pos].
  ({String section, double phase, double seconds, double start}) sectionInfoAt(
    double pos,
  ) {
    for (final s in sectionSpans) {
      if (pos >= s.start && pos < s.end) {
        final span = (s.end - s.start) <= 0 ? 1.0 : s.end - s.start;
        return (
          section: s.section,
          phase: ((pos - s.start) / span).clamp(0.0, 1.0),
          seconds: span,
          start: s.start,
        );
      }
    }
    return (section: '', phase: 0, seconds: 0, start: 0);
  }

  /// When the choreo STATEMENT covering [pos] began: the span start, the
  /// slot boundary inside a rotated span, or the mid-hook Buga switch. Must
  /// mirror [choreoTrioForSection]'s branch structure — this is the instant
  /// the trio last changed, which the stepper uses to re-anchor the phrase
  /// so incoming moves enter on their own bar 1.
  double segmentStartAt(double pos) {
    final lyric = sectionInfoAt(pos);
    if (lyric.section.isEmpty) return sectionAt(pos)?.start ?? 0;
    switch (lyric.section) {
      case 'chorus':
      case 'post-chorus':
      case 'pre-chorus':
      case 'verse':
      case 'bridge':
      case 'outro':
        // Same slot arithmetic as _rotateSetlist: slot k spans phase
        // [k/slots, (k+1)/slots).
        final slots = lyric.seconds <= 0
            ? 1
            : (lyric.seconds / kChoreoSlotSeconds).round().clamp(1, 64);
        final slot = (lyric.phase * slots).floor().clamp(0, slots - 1);
        return lyric.start + slot * lyric.seconds / slots;
      default:
        return lyric.start;
    }
  }

  /// Whether the span covering [pos] is the LAST [section]-labelled span of
  /// the song — "the final post-chorus", however many came before. Finality
  /// and occurrence are different questions: this track tags post-chorus
  /// exactly once, so its occurrence is 0 and any `occurrence >= 1` gate on
  /// "the final one" is unreachable — the round-6 canon reprise shipped
  /// panel-certified but DEAD, staged only in tests that passed the variant
  /// by hand. False when no [section] span covers [pos].
  bool sectionIsFinalOccurrenceAt(double pos, String section) {
    var covering = false;
    for (final s in sectionSpans) {
      if (s.section != section) continue;
      covering = pos >= s.start && pos < s.end;
    }
    return covering;
  }

  /// How many earlier spans share [section]'s label — 0 for its first occurrence.
  /// Lets the choreography vary repeated choruses/verses so they don't read
  /// identical.
  int sectionOccurrenceAt(double pos, String section) {
    var occ = 0;
    for (final s in sectionSpans) {
      if (pos >= s.start && pos < s.end) break;
      if (s.section == section) occ++;
    }
    return occ;
  }

  /// How long one authored statement lasts inside the song score.
  ///
  /// Moving's 32-frame vocabulary is an eight-beat/two-bar phrase: four real
  /// seconds at this track's 120 BPM. The old eight-second slot replayed every
  /// selected phrase twice before advancing, so a nominally complete 144s
  /// schedule still read as six loops on rotation. One slot now owns one full
  /// phrase; recurring motifs must be selected deliberately in the section
  /// score below rather than appearing through automatic repetition.
  static const double kChoreoSlotSeconds = 4;

  /// One entry of [setlist], time-sliced across a semantic song section at one
  /// complete two-bar phrase per slot. Section duration is rounded to the
  /// nearest phrase count so pickups/tails do not manufacture a fifth tiny
  /// statement. Production section scores provide an entry for every slot;
  /// wrapping remains only as a defensive fallback for synthetic tests.
  DanceTrio _rotateSetlist(
    List<DanceTrio> setlist,
    double phase,
    double sectionSeconds, {
    int offset = 0,
  }) {
    final slots = sectionSeconds <= 0
        ? 1
        : (sectionSeconds / kChoreoSlotSeconds).round().clamp(1, 64);
    final slot = (phase * slots).floor().clamp(0, slots - 1);
    return setlist[(slot + offset) % setlist.length];
  }

  /// The lyric-driven routine for a semantic [section]: each section of the song
  /// gets its own trio across the named moves, so the dance reads as a designed set
  /// — verses groove, the chorus punches its hook into a unison Buga hit, the
  /// bridge drops to a grounded Sekem pocket, the outro winds down. [phase] is
  /// 0..1 progress through the section; [variant] is the section occurrence (0 =
  /// first) so repeats don't read identical; [sectionSeconds] lets LONG sections
  /// rotate through a mini-setlist instead of parking one trio for the whole
  /// stretch (a full bridge of sekem×3 read as a screensaver). Falls back to
  /// the energy-level map for untagged sections / no lyrics.
  DanceTrio choreoTrioForSection(
    String section,
    double phase,
    double level,
    int variant, {
    double sectionSeconds = 0,
    bool finalOccurrence = false,
  }) {
    final hookCall = (
      lead: _moving,
      ensemble: [_moving, _movingLowCounterCanon, _movingHookEcho],
    );
    final hookAnswer = (
      lead: _movingSideAnswer,
      ensemble: [_movingSideAnswer, _moving, _movingLowCounter],
    );
    final hookReturn = (
      lead: _moving,
      ensemble: [_moving, _movingSideAnswer, _movingVerse],
    );
    final hookUnison = (
      lead: _moving,
      ensemble: [_moving, _moving, _moving],
    );
    final hookTravel = (
      lead: _movingChorusTravel,
      ensemble: [_movingChorusTravel, _movingSideAnswer, _movingLowCounter],
    );
    final hookOpen = (
      lead: _movingChorusOpen,
      ensemble: [_movingChorusOpen, _movingChorusTravel, _movingSideAnswerEcho],
    );
    final verseShuffle = (
      lead: _movingVerse,
      ensemble: [_movingVerse, _movingVerseWindow, _movingLowCounter],
    );
    final verseWindow = (
      lead: _movingVerseWindow,
      ensemble: [_movingVerseWindow, _movingVerse, _movingSideAnswer],
    );
    final breakdown = (
      lead: _movingBreakdown,
      ensemble: [_movingBreakdown, _movingVerse, _movingLowCounter],
    );
    final bridgeRock = (
      lead: _movingBridgeRock,
      ensemble: [_movingBridgeRock, _movingBreakdown, _movingVerseWindow],
    );
    final bodyRoll = (
      lead: _movingBodyRoll,
      ensemble: [_movingBodyRoll, _movingVerse, _movingBridgeRock],
    );
    final lowCounter = (
      lead: _movingLowCounter,
      ensemble: [_movingLowCounter, _movingBreakdown, _movingSideAnswer],
    );
    final sideVerse = (
      lead: _movingSideAnswer,
      ensemble: [_movingSideAnswer, _movingVerse, _movingBreakdown],
    );
    final windowBridge = (
      lead: _movingVerseWindow,
      ensemble: [_movingVerseWindow, _movingBreakdown, _movingLowCounter],
    );

    switch (section) {
      case 'chorus':
        // Four explicitly scored statements per chorus occurrence. The hook
        // returns, but its answer/travel/ensemble ownership develops instead
        // of one selected loop replaying automatically for eight seconds.
        final score = switch (variant) {
          0 => [hookCall, hookAnswer, hookTravel, hookReturn],
          1 => [hookCall, hookOpen, hookAnswer, hookReturn],
          // The last refrain develops through travel before landing the hook.
          // `hookReturn` and `hookCall` share the same lead clip; putting them
          // back-to-back here made the centre cat repeat one raised-fist
          // sentence for roughly eight seconds, then post-chorus repeated it
          // again. Keep the recognisable hook as the final statement, but earn
          // it through a genuinely different whole-body phrase.
          // After three complementary crew statements, let the recognisable
          // hook land once in real unison. Constantly assigning three distinct
          // clips made the cast look like independent loop players and denied
          // the final chorus a collective payoff.
          _ => [hookAnswer, hookOpen, hookTravel, hookUnison],
        };
        return _rotateSetlist(score, phase, sectionSeconds);
      case 'post-chorus':
        // Early post-choruses RELEASE (grounded low vocabulary); the LAST one
        // must not — the track still burns near-peak there (~0.78 intensity at
        // 106s), and leading it with the score's lowest phrase measured as the
        // weakest window of the whole edit (round-3 panel: lead-zone energy
        // 3.16 vs chorus 3.82) exactly where the penultimate peak lands. The
        // final post-chorus keeps the heat with travel/answer vocabulary and
        // releases only in its closing statement.
        return _rotateSetlist(
          // The final post-chorus RESTATES THE CANON at the arc's peak
          // (round-5 animator: the late chorus "abandons the conversation…
          // exactly where the arc should peak" — either restate the canon
          // or commit to a tutti; the canon is the piece's signature now).
          // Keyed on FINALITY, not occurrence: this track tags post-chorus
          // once, so an occurrence-only gate never fired and the reprise
          // shipped dead (see sectionIsFinalOccurrenceAt).
          variant >= 1 || finalOccurrence
              ? [hookTravel, hookCall, windowBridge, lowCounter]
              : [lowCounter, hookTravel, bodyRoll, windowBridge],
          phase,
          sectionSeconds,
        );
      case 'pre-chorus':
        return _rotateSetlist(
          [verseShuffle, bridgeRock, bodyRoll, hookTravel],
          phase,
          sectionSeconds,
        );
      case 'verse':
        // All four verse statements stay in grounded verse vocabulary. The
        // fourth slot used to be sideVerse (a hook-family lead), which put
        // chorus-amplitude fist work into the song's breakdown stretch — the
        // panel read the middle of the song as "a third chorus" with no
        // dynamic valley left to make the real chorus land.
        return _rotateSetlist(
          [verseShuffle, verseWindow, bodyRoll, lowCounter],
          phase,
          sectionSeconds,
        );
      case 'bridge':
        return _rotateSetlist(
          // Keep the first three statements grounded, then travel into the
          // late chorus. The former low-counter ending extended the bridge's
          // low fist vocabulary for eight seconds; sideVerse was rejected too
          // because it repeated the incoming chorus lead across the boundary.
          [breakdown, bridgeRock, bodyRoll, hookTravel],
          phase,
          sectionSeconds,
        );
      case 'outro':
        return _rotateSetlist(
          // Resolve the last sung "moving" with the song's signature rather
          // than repeating bodyRoll and quietly running out of choreography.
          // The following resting gate owns the instrumental release.
          [sideVerse, bodyRoll, bridgeRock, hookCall],
          phase,
          sectionSeconds,
        );
      default:
        return choreoTrioByLevel(level);
    }
  }

  /// Energy-only fallback (no lyrics): map the section's normalized [level] to a
  /// trio, building from the grounded Sekem pocket up to the unison Buga hit.
  DanceTrio choreoTrioByLevel(double level) {
    if (level >= 0.90) {
      return (lead: _moving, ensemble: [_moving, _moving, _moving]);
    }
    if (level >= 0.78) {
      return (lead: _zanku, ensemble: [_zanku, _sekem, _buga]);
    }
    if (level >= 0.62) {
      return (lead: _shaku, ensemble: [_shaku, _zanku, _sekem]);
    }
    if (level >= 0.45) {
      return (lead: _shaku, ensemble: [_shaku, _azonto, _zanku]);
    }
    if (level >= 0.28) {
      return (lead: _azonto, ensemble: [_azonto, _shaku, _sekem]);
    }
    return (lead: _sekem, ensemble: [_sekem, _sekem, _sekem]);
  }

  /// The virtual director's CONTEXT for [pos], from which the target framing
  /// ([cameraShot]) is derived. [energetic] mirrors the acoustic dance gate
  /// (it only steers the unlabelled-section fallback). Besides the current
  /// section it carries the section's occurrence (keys the per-refrain chorus
  /// homes) and the NEXT section with the seconds until it starts, which drive
  /// the director's anticipated dolly into each boundary.
  DanceCameraContext directorContext(
    double pos, {
    required bool energetic,
    double secondsSinceMoveCut = double.infinity,
  }) {
    final info = sectionInfoAt(pos);
    DanceSectionSpan? next;
    for (final s in sectionSpans) {
      if (s.start > pos) {
        next = s;
        break;
      }
    }
    return cameraContext(
      beat: map.beatAt(pos),
      anchorBeat: binding.anchorBeatIndex.toDouble(),
      loopLengthBeats: binding.loopLengthBeats.toDouble(),
      section: info.section,
      energetic: energetic,
      build: trackDurationSec > 0 ? pos / trackDurationSec : 0,
      sectionPhase: info.phase,
      occurrence: sectionOccurrenceAt(pos, info.section),
      sectionSeconds: info.seconds,
      secondsToNext: next == null ? double.infinity : next.start - pos,
      nextSection: next?.section,
      nextOccurrence: next == null
          ? 0
          : sectionOccurrenceAt(next.start, next.section),
      secondsSinceMoveCut: secondsSinceMoveCut,
    );
  }

  /// Whether a voice (selected by [test]) is singing at [pos], dilated by
  /// [voiceSlack] so short gaps between a phrase's words don't make the mouth
  /// flicker shut — it only rests between phrases / when that voice is silent.
  bool voiceActive(double pos, bool Function(DanceWord w) test) {
    for (final w in words) {
      if (test(w) && windowActiveAt(w.start, w.end, pos, voiceSlack)) {
        return true;
      }
      if (w.start - voiceSlack > pos) break;
    }
    return false;
  }

  /// A 0..1 musical pulse that spikes on each detected beat and decays, so the
  /// backdrop lights and foam shimmer with the track. A pure function of [pos]
  /// and the beat times, so it freezes with playback.
  double beatPulse(double pos) {
    final beats = map.beatTimesSec;
    if (beats.isEmpty) return 0;
    var lo = 0;
    var hi = beats.length - 1;
    var idx = 0;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (beats[mid] <= pos) {
        idx = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    final since = pos - beats[idx];
    if (since < 0) return 0;
    final v = 1 - since / 0.18;
    return v <= 0 ? 0 : v * v;
  }
}
