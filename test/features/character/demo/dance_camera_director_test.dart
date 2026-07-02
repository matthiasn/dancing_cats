import 'package:dancing_cats/features/character/demo/dance_camera_director.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;

/// Every section label the director branches on, plus a couple it treats as the
/// default "verse" pocket — so the generator exercises the whole switch. The
/// empty label is the unlabelled fallback (calm establish / dance pocket).
const _sections = <String>[
  '',
  'intro',
  'verse',
  'pre-chorus',
  'chorus',
  'post-chorus',
  'bridge',
  'outro',
];

/// Direct context builder with defaults so the example tests state only the
/// fields that matter to the shot under test.
DanceCameraContext _ctx({
  String section = 'chorus',
  bool energetic = true,
  double build = 0.5,
  double phrasePhase = 0,
  double sectionPhase = 0,
  int occurrence = 0,
  double sectionSeconds = 15,
  double secondsToNext = double.infinity,
  String? nextSection,
  int nextOccurrence = 0,
}) => DanceCameraContext(
  section: section,
  energetic: energetic,
  build: build,
  phrasePhase: phrasePhase,
  sectionPhase: sectionPhase,
  occurrence: occurrence,
  sectionSeconds: sectionSeconds,
  secondsToNext: secondsToNext,
  nextSection: nextSection,
  nextOccurrence: nextOccurrence,
);

extension _AnyDanceCtx on glados.Any {
  /// A random director context spanning every section, both energy states, the
  /// full build/phase ranges, chorus occurrences, and anticipation states
  /// (including no-next and an imminent next) — the input space for the
  /// invariants.
  glados.Generator<DanceCameraContext> get danceCtx =>
      glados.CombinableAny(this).combine7(
        glados.IntAnys(this).intInRange(0, _sections.length - 1),
        glados.IntAnys(this).intInRange(0, 7),
        glados.DoubleAnys(this).doubleInRange(0, 1),
        glados.DoubleAnys(this).doubleInRange(0, 1),
        glados.DoubleAnys(this).doubleInRange(0, 1),
        glados.IntAnys(this).intInRange(0, _sections.length),
        glados.DoubleAnys(this).doubleInRange(0, 6),
        (sIdx, flags, build, phrase, secPhase, nIdx, toNext) => _ctx(
          section: _sections[sIdx],
          energetic: flags.isOdd,
          build: build,
          phrasePhase: phrase,
          sectionPhase: secPhase,
          occurrence: flags >> 1,
          nextSection: nIdx == _sections.length ? null : _sections[nIdx],
          secondsToNext: nIdx == _sections.length ? double.infinity : toNext,
          nextOccurrence: flags >> 1,
        ),
      );
}

void main() {
  group('cameraContext', () {
    test('derives the per-phrase phase from the beat grid and wraps it', () {
      final whole = cameraContext(
        beat: 13,
        anchorBeat: 1,
        loopLengthBeats: 12,
        section: 'chorus',
        energetic: true,
        build: 0.5,
      );
      // rel = 12 = exactly one phrase → phase wraps to 0.
      expect(whole.phrasePhase, closeTo(0, 1e-9));
      final half = cameraContext(
        beat: 7,
        anchorBeat: 1,
        loopLengthBeats: 12,
        section: 'chorus',
        energetic: true,
        build: 0.5,
      );
      // rel = 6 = half a phrase.
      expect(half.phrasePhase, closeTo(0.5, 1e-9));
    });

    test('clamps build, sectionPhase and secondsToNext into range', () {
      final c = cameraContext(
        beat: 5,
        anchorBeat: 0,
        loopLengthBeats: 12,
        section: 'verse',
        energetic: true,
        build: 1.5,
        sectionPhase: -0.3,
        secondsToNext: -2,
        nextSection: 'chorus',
      );
      expect(c.build, 1.0);
      expect(c.sectionPhase, 0.0);
      expect(c.secondsToNext, 0.0);
      expect(c.nextSection, 'chorus');
    });

    test('without next-section info the anticipation stays disabled', () {
      final c = cameraContext(
        beat: 5,
        anchorBeat: 0,
        loopLengthBeats: 12,
        section: 'outro',
        energetic: true,
        build: 0.9,
      );
      expect(c.nextSection, isNull);
      expect(c.secondsToNext, double.infinity);
      expect(c.occurrence, 0);
      expect(c.nextOccurrence, 0);
    });
  });

  group('cameraShot — anticipated section arrivals (no punches)', () {
    test('far from the boundary the next section does not bleed in', () {
      final away = cameraShot(
        _ctx(
          section: 'verse',
          sectionPhase: 0.5,
          nextSection: 'bridge',
          secondsToNext: cameraAnticipationWindow('bridge', 0) + 1,
        ),
      );
      final noNext = cameraShot(_ctx(section: 'verse', sectionPhase: 0.5));
      expect(away, noNext);
    });

    test('big lateral re-stagings get a longer anticipation runway', () {
      // The committed chorus two-shots and the verse's far-side start are
      // 300–400 ref px repositions; the window scales so they stay at dolly
      // speeds instead of compressing into the default runway.
      expect(
        cameraAnticipationWindow('chorus', 0),
        greaterThan(kCameraAnticipationSeconds),
      );
      expect(
        cameraAnticipationWindow('verse', 0),
        greaterThan(kCameraAnticipationSeconds),
      );
      expect(
        cameraAnticipationWindow('bridge', 0),
        greaterThan(kCameraAnticipationSeconds),
      );
      expect(cameraAnticipationWindow('outro', 0), kCameraAnticipationSeconds);
      expect(cameraAnticipationWindow('', 0), kCameraAnticipationSeconds);
    });

    test('the glide toward the next home is continuous and monotonic', () {
      // Sweep the last seconds of a verse before a bridge: the target must walk
      // from the verse shot to the bridge's opening silver-side feature without
      // a jump, parking on it kCameraArriveLeadSeconds early.
      final bridgeOpen = cameraShot(
        _ctx(section: 'bridge', phrasePhase: 0.3),
      );
      final window = cameraAnticipationWindow('bridge', 0);
      var prev = cameraShot(
        _ctx(
          section: 'verse',
          sectionPhase: 0.8,
          phrasePhase: 0.3,
          nextSection: 'bridge',
          secondsToNext: window,
        ),
      );
      for (var s = window; s >= 0; s -= 0.05) {
        final shot = cameraShot(
          _ctx(
            section: 'verse',
            sectionPhase: 0.8,
            phrasePhase: 0.3,
            nextSection: 'bridge',
            secondsToNext: s,
          ),
        );
        expect((shot.zoom - prev.zoom).abs(), lessThan(0.01), reason: 's=$s');
        expect((shot.dx - prev.dx).abs(), lessThan(12), reason: 's=$s');
        prev = shot;
      }
      // Parked exactly on the next home before the boundary (the rig's settle
      // lands the eased camera on the downbeat).
      final parked = cameraShot(
        _ctx(
          section: 'verse',
          sectionPhase: 0.8,
          phrasePhase: 0.3,
          nextSection: 'bridge',
          secondsToNext: kCameraArriveLeadSeconds,
        ),
      );
      expect(parked.zoom, closeTo(bridgeOpen.zoom, 1e-9));
      expect(parked.dx, closeTo(bridgeOpen.dx, 1e-9));
      expect(parked.dy, closeTo(bridgeOpen.dy, 1e-9));
    });

    test('the target is continuous ACROSS every section boundary', () {
      // At the boundary itself, [outgoing section fully blended to next(0)]
      // must equal [next section at phase 0] — for every ordered pair.
      for (final from in _sections) {
        for (final to in _sections) {
          final end = cameraShot(
            _ctx(
              section: from,
              sectionPhase: 1,
              phrasePhase: 0.7,
              nextSection: to,
              secondsToNext: 0,
            ),
          );
          final open = cameraShot(
            _ctx(section: to, phrasePhase: 0.7),
          );
          expect(end.zoom, closeTo(open.zoom, 1e-9), reason: '$from->$to');
          expect(end.dx, closeTo(open.dx, 1e-9), reason: '$from->$to');
          expect(end.dy, closeTo(open.dy, 1e-9), reason: '$from->$to');
        }
      }
    });

    test('the approach PARKS on the exact home, then the launch clock starts '
        'kCameraLaunchLeadSeconds before the beat', () {
      // In the park zone (between the arrive lead and the launch lead) the
      // blended target is EXACTLY the next section's home — independent of the
      // phrase grid (the breathe fades in later) and of time (parked still).
      Shot approach(double stn, double pp) => cameraShot(
        _ctx(
          section: 'pre-chorus',
          sectionPhase: 0.9,
          phrasePhase: pp,
          nextSection: 'chorus',
          nextOccurrence: 1,
          secondsToNext: stn,
        ),
      );
      final parked = approach(kCameraLaunchLeadSeconds, 0.25);
      for (final pp in [0.0, 0.6, 0.9]) {
        final again = approach(kCameraLaunchLeadSeconds + 0.2, pp);
        expect(again.zoom, closeTo(parked.zoom, 1e-9), reason: 'pp=$pp');
        expect(again.dx, closeTo(parked.dx, 1e-9), reason: 'pp=$pp');
      }
      // Inside the launch lead the target is ALREADY moving (the launch-push
      // has begun), so the eased camera's velocity crests on the downbeat.
      final launching = approach(0.05, 0.25);
      expect(launching.zoom, greaterThan(parked.zoom + 0.005));
      // …and the launch clock is CONTINUOUS across the boundary: the shot at
      // secondsToNext=0 equals the chorus's own opening frame.
      final atBoundary = approach(0, 0.25);
      final open = cameraShot(
        _ctx(occurrence: 1, phrasePhase: 0.25),
      );
      expect(atBoundary.zoom, closeTo(open.zoom, 1e-9));
      expect(atBoundary.dx, closeTo(open.dx, 1e-9));
    });

    test('the calm intro glides into the first chorus home before the drop', () {
      // The pre-song establish ('' section, calm) anticipates the first chorus:
      // approaching the boundary the zoom rises from the wide toward 1.30.
      final wide = cameraShot(
        _ctx(
          section: '',
          energetic: false,
          nextSection: 'chorus',
          secondsToNext: cameraAnticipationWindow('chorus', 0) + 0.5,
        ),
      );
      final arriving = cameraShot(
        _ctx(
          section: '',
          energetic: false,
          nextSection: 'chorus',
          secondsToNext: kCameraArriveLeadSeconds,
        ),
      );
      expect(wide.zoom, closeTo(1.06, 0.03));
      expect(arriving.zoom, closeTo(1.26, 1e-9));
      expect(arriving.dx, 0);
      expect(arriving.dy, 0);
    });
  });

  group('cameraShot — section treatments', () {
    test('the calm establish breathes AND drifts (the planes never park)', () {
      final s = cameraShot(
        _ctx(section: '', energetic: false, phrasePhase: 0.3),
      );
      expect(s.zoom, closeTo(1.06, 0.03)); // establish + a small breathe
      expect(s.dy, kHorizonDropPx);
      // The slow lateral drift keeps the parallax alive on the wide…
      expect(
        cameraShot(_ctx(section: '', energetic: false)).dx,
        closeTo(kCalmDriftRef, 1e-9),
      );
      expect(
        cameraShot(_ctx(section: '', energetic: false, phrasePhase: 0.5)).dx,
        closeTo(-kCalmDriftRef, 1e-9),
      );
      // …and stays inside the pan margin the establish zoom exposes.
      expect(kCalmDriftRef, lessThan(1280 * (1.06 - 0.01 - 1)));
    });

    test('the unlabelled dance fallback is a living centred medium', () {
      final s = cameraShot(_ctx(section: '', phrasePhase: 0.25));
      expect(s.zoom, closeTo(1.32, 1e-9)); // 1.30 + breathe peak
      expect(s.dx, greaterThan(0)); // phrase drift
      expect(s.dy, 0);
      expect(
        cameraShot(_ctx(section: '', phrasePhase: 0.75)).dx,
        lessThan(0),
      );
    });

    test('pre-chorus is a strictly monotonic crane-push, dead centre', () {
      var prev = -1.0;
      for (final p in [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]) {
        final s = cameraShot(_ctx(section: 'pre-chorus', sectionPhase: p));
        expect(s.dx, 0, reason: 'p=$p');
        expect(s.dy, 0, reason: 'p=$p');
        expect(s.zoom, greaterThan(prev), reason: 'p=$p');
        prev = s.zoom;
      }
      expect(cameraShot(_ctx(section: 'pre-chorus')).zoom, closeTo(1.18, 1e-9));
      // The crest sits UNDER the chorus homes, so the anticipated dolly keeps
      // RISING through the drop — the old crest overshot the home and made the
      // arrival zoom out exactly on the accent.
      expect(
        cameraShot(_ctx(section: 'pre-chorus', sectionPhase: 1)).zoom,
        closeTo(1.32, 1e-9),
      );
      expect(1.32, lessThan(1.46)); // under the two-shot chorus register
    });

    test('each chorus owns a distinct home keyed on its OCCURRENCE', () {
      // First chorus: centred (up to the launch's small rightward ease).
      expect(cameraShot(_ctx()).dx.abs(), lessThan(15));
      // Second chorus: leans LEFT toward the silver backup (+dx).
      expect(cameraShot(_ctx(occurrence: 1)).dx, greaterThan(0));
      // Third chorus: leans RIGHT toward the dark backup (-dx).
      expect(cameraShot(_ctx(occurrence: 2)).dx, lessThan(0));
      // The identity holds for the WHOLE section (the old build thresholds
      // could re-stage a chorus mid-phrase).
      for (final sp in [0.0, 0.3, 0.6, 1.0]) {
        expect(
          cameraShot(_ctx(occurrence: 1, sectionPhase: sp)).dx,
          greaterThan(0),
          reason: 'sp=$sp',
        );
        expect(
          cameraShot(_ctx(occurrence: 2, sectionPhase: sp)).dx,
          lessThan(0),
          reason: 'sp=$sp',
        );
      }
    });

    test('the first chorus LAUNCHES on the drop, then drifts up with an arc', () {
      final start = cameraShot(_ctx());
      final launched = cameraShot(_ctx(sectionPhase: 0.12));
      final mid = cameraShot(_ctx(sectionPhase: 0.5));
      final end = cameraShot(_ctx(sectionPhase: 1));
      // The launch clock starts kCameraLaunchLeadSeconds before the boundary,
      // so the section opens already a touch into its launch-push…
      expect(start.zoom, inInclusiveRange(1.26, 1.33));
      // …and the camera has visibly moved a couple of bars in.
      expect(launched.zoom - start.zoom, greaterThan(0.02));
      // The slow drift-up carries the rest of the refrain.
      expect(end.zoom, closeTo(1.37, 1e-9));
      // The arc drifts out mid-section and returns, riding the launch's small
      // rightward ease — the depth keeps sliding through the held hook.
      expect(mid.dx, closeTo(20 - 18, 1e-9));
      expect(end.dx, closeTo(-18, 1e-9));
    });

    test('a chorus home holds its lean and pushes gently across the section', () {
      final start = cameraShot(_ctx(occurrence: 1));
      final end = cameraShot(_ctx(occurrence: 1, sectionPhase: 1));
      expect(start.dx, greaterThan(0));
      expect(end.dx, greaterThan(0)); // same committed side throughout
      expect(end.zoom, greaterThan(start.zoom)); // slow push, never a snap
      expect(end.zoom - start.zoom, lessThan(0.1)); // gentle, not a jump
    });

    test('bridge is ONE continuous cross-stage traverse following the voice', () {
      // DEEP committed silver-side feature held while she carries the first
      // half — she is the shot's subject, not just the pan direction…
      final earlyA = cameraShot(_ctx(section: 'bridge', sectionPhase: 0.1));
      final earlyB = cameraShot(_ctx(section: 'bridge', sectionPhase: 0.25));
      expect(earlyA.dx, greaterThan(300));
      expect(earlyA.dx, closeTo(earlyB.dx, 1e-9)); // a committed hold
      // …the TARGET crosses centre a touch BEFORE sectionPhase 0.5, so the
      // eased camera (which lags the target) crosses on the vocal hand-off…
      expect(
        cameraShot(_ctx(section: 'bridge', sectionPhase: 0.44)).dx,
        greaterThan(0),
      );
      final atHandOff = cameraShot(_ctx(section: 'bridge', sectionPhase: 0.5));
      expect(atHandOff.dx, lessThan(0));
      expect(atHandOff.dx.abs(), lessThan(80));
      // …and a SHALLOWER brown-side hold takes the second half, leaving the
      // deeper chorus-3 right two-shot somewhere to go on the last drop.
      final lateA = cameraShot(_ctx(section: 'bridge', sectionPhase: 0.7));
      final lateB = cameraShot(_ctx(section: 'bridge', sectionPhase: 0.9));
      expect(lateA.dx, lessThan(-100));
      expect(lateA.dx, closeTo(lateB.dx, 1e-9));
      expect(lateA.dx.abs(), lessThan(earlyA.dx.abs())); // asymmetric on purpose
      final chorus3Home = cameraShot(_ctx(occurrence: 2));
      expect(chorus3Home.dx, lessThan(lateA.dx)); // deeper than the tail hold
      // The zoom relaxes slightly through the crossing — an arc, not a slide.
      final mid = cameraShot(_ctx(section: 'bridge', sectionPhase: 0.5));
      expect(mid.zoom, lessThan(earlyA.zoom));
      expect(earlyA.zoom, closeTo(1.48, 0.02));
      // The traverse is a DOLLY: finely swept, the pan never jumps (the old
      // hand-off flipped the target by ~335 ref px for the rig to whip across).
      var prev = cameraShot(_ctx(section: 'bridge', sectionPhase: 0.26));
      for (var sp = 0.26; sp <= 0.66; sp += 0.002) {
        final s = cameraShot(_ctx(section: 'bridge', sectionPhase: sp));
        expect((s.dx - prev.dx).abs(), lessThan(6), reason: 'sp=$sp');
        prev = s;
      }
    });

    test('verse is ONE long truck with a constant-velocity cruise', () {
      final a = cameraShot(_ctx(section: 'verse'));
      final mid = cameraShot(_ctx(section: 'verse', sectionPhase: 0.5));
      final b = cameraShot(_ctx(section: 'verse', sectionPhase: 1));
      expect(a.zoom, closeTo(1.28, 1e-9));
      expect(b.zoom, closeTo(1.36, 1e-9));
      expect(a.dy, 0);
      // The truck starts a touch off-centre on the dark side and travels all
      // the way ACROSS to the silver side (where the bridge feature waits):
      // a single deliberate move, monotonic throughout.
      expect(a.dx, closeTo(kVerseTruckStartRef, 1e-9));
      expect(mid.dx, greaterThan(a.dx));
      expect(b.dx, closeTo(kVerseTruckEndRef, 1e-9));
      var prev = a.dx;
      for (var sp = 0.02; sp <= 1; sp += 0.02) {
        final dx = cameraShot(_ctx(section: 'verse', sectionPhase: sp)).dx;
        expect(dx, greaterThanOrEqualTo(prev), reason: 'sp=$sp');
        prev = dx;
      }
      // The middle rides at CRUISE (an eased trapezoid, not a smoothstep whose
      // velocity never stops changing): equal phase steps across the core move
      // equal distances.
      double at(double sp) =>
          cameraShot(_ctx(section: 'verse', sectionPhase: sp)).dx;
      final step1 = at(0.4) - at(0.3);
      final step2 = at(0.6) - at(0.5);
      expect(step1, closeTo(step2, 1e-9));
      // …and the cruise is genuinely faster than the eased edges.
      expect(step1, greaterThan(at(0.09) - at(0)));
    });

    test('outro lands EXACTLY on the calm establish well before its end', () {
      final a = cameraShot(_ctx(section: 'outro'));
      expect(a.zoom, closeTo(1.40, 1e-9));
      // The zoom-linked trim's ramp starts under the outro's opening zoom, so
      // a small residual trim rides the first pull-back frames.
      expect(a.dy, lessThan(5));
      // From three quarters in, the outro IS the establish — breathe, drift
      // and trim included — so the energy gate's later hand-off to the idle
      // wide cannot step, wherever it lands.
      for (final sp in [0.9, 0.95, 1.0]) {
        for (final pp in [0.0, 0.3, 0.8]) {
          final out = cameraShot(
            _ctx(section: 'outro', sectionPhase: sp, phrasePhase: pp),
          );
          final calm = cameraShot(
            _ctx(section: '', energetic: false, phrasePhase: pp),
          );
          expect(out.zoom, closeTo(calm.zoom, 1e-9), reason: 'sp=$sp pp=$pp');
          expect(out.dx, closeTo(calm.dx, 1e-9), reason: 'sp=$sp pp=$pp');
          expect(out.dy, closeTo(calm.dy, 1e-9), reason: 'sp=$sp pp=$pp');
        }
      }
      // Before the landing, the establish's breathe/drift stay FEATHERED OUT
      // so they cannot bounce the still-decelerating pull-back (at the 3/4
      // landing mark the establish terms are still nearly silent).
      final landing = cameraShot(
        _ctx(section: 'outro', sectionPhase: 0.75, phrasePhase: 0.25),
      );
      expect(landing.zoom, closeTo(1.06, 0.005));
      expect(landing.dx.abs(), lessThan(8));
    });
  });

  group('cameraShot — continuous (dolly) within every section', () {
    // The director's TARGET moves continuously within every section — there are
    // no punches anywhere any more, INCLUDING the bridge (its old dx sign-flip
    // is now the mid-traverse crossing). Sweeping sectionPhase finely
    // (phrasePhase fixed so the breathe term is constant), the target never
    // jumps: a real cut (the old homes jumped dx by ~300 / zoom by ~0.15)
    // would blow these bounds.
    const cases = <({String section, int occurrence})>[
      (section: 'chorus', occurrence: 0),
      (section: 'chorus', occurrence: 1),
      (section: 'chorus', occurrence: 2),
      (section: 'verse', occurrence: 0),
      (section: 'pre-chorus', occurrence: 0),
      (section: 'bridge', occurrence: 0),
      (section: 'outro', occurrence: 0),
      (section: 'post-chorus', occurrence: 0),
    ];
    for (final cse in cases) {
      test('${cse.section} (occurrence ${cse.occurrence}) never jumps', () {
        var prev = cameraShot(
          _ctx(section: cse.section, occurrence: cse.occurrence),
        );
        for (var sp = 0.005; sp <= 1.0 + 1e-9; sp += 0.005) {
          final s = cameraShot(
            _ctx(
              section: cse.section,
              occurrence: cse.occurrence,
              sectionPhase: sp,
            ),
          );
          expect(
            (s.zoom - prev.zoom).abs(),
            lessThan(0.01),
            reason: '${cse.section} zoom jumped at sp=$sp',
          );
          expect(
            (s.dx - prev.dx).abs(),
            lessThan(16),
            reason: '${cse.section} pan jumped at sp=$sp',
          );
          prev = s;
        }
      });
    }
  });

  group('cameraShot — final post-chorus hook', () {
    test('holds a grounded band and its sway fades in and out', () {
      // The coil stays in its grounded band with ONE motivated mid-coil push,
      // capped at 1.45 so headroom clears the drone signage and the deck keeps
      // toe-room under the legwork.
      for (final sp in [0.5, 0.62, 0.74, 0.86, 0.90, 0.96, 1.0]) {
        final s = cameraShot(_ctx(section: 'post-chorus', sectionPhase: sp));
        expect(s.zoom, inInclusiveRange(1.37, 1.42), reason: 'sp=$sp');
        // Tight frames ride the zoom-linked headroom trim (signage clearance).
        expect(
          s.dy,
          inInclusiveRange(0, kTightShotDropRef),
          reason: 'sp=$sp',
        );
      }
      // The beat-phrased sway loads the frame well off-centre mid-coil…
      expect(
        cameraShot(
          _ctx(section: 'post-chorus', sectionPhase: 0.3, phrasePhase: 0.25),
        ).dx.abs(),
        greaterThan(40),
      );
      // …DECAYS across the coil (a pendulum that never loses energy read as
      // metronomic)…
      expect(
        cameraShot(
          _ctx(section: 'post-chorus', sectionPhase: 0.85, phrasePhase: 0.25),
        ).dx.abs(),
        lessThan(
          cameraShot(
            _ctx(section: 'post-chorus', sectionPhase: 0.3, phrasePhase: 0.25),
          ).dx.abs(),
        ),
      );
      // …but ENTERS and RESOLVES at zero, wherever the phrase grid sits, so
      // the coil cannot start or end with a lateral step.
      for (final pp in [0.0, 0.25, 0.6]) {
        expect(
          cameraShot(
            _ctx(section: 'post-chorus', phrasePhase: pp),
          ).dx,
          closeTo(0, 1e-9),
          reason: 'pp=$pp',
        );
        expect(
          cameraShot(
            _ctx(section: 'post-chorus', sectionPhase: 1, phrasePhase: pp),
          ).dx,
          closeTo(0, 1e-9),
          reason: 'pp=$pp',
        );
      }
    });

    test('the whole final hook stays continuous and capped', () {
      var prev = cameraShot(_ctx(section: 'post-chorus'));
      for (var i = 0; i <= 400; i++) {
        final s = cameraShot(
          _ctx(section: 'post-chorus', sectionPhase: i / 400),
        );
        expect(s.zoom, lessThanOrEqualTo(1.42), reason: 'sp=${i / 400}');
        expect(
          (s.zoom - prev.zoom).abs(),
          lessThan(0.01),
          reason: 'sp=${i / 400}',
        );
        prev = s;
      }
    });

    test('no section exceeds the grounded dance ceiling', () {
      var maxShot = 0.0;
      for (final section in _sections) {
        for (var occ = 0; occ <= 3; occ++) {
          for (var ph = 0; ph <= 4; ph++) {
            for (var sp = 0; sp <= 10; sp++) {
              final c = _ctx(
                section: section,
                occurrence: occ,
                phrasePhase: ph / 4,
                sectionPhase: sp / 10,
              );
              final z = cameraShot(c).zoom;
              if (z > maxShot) maxShot = z;
            }
          }
        }
      }
      expect(maxShot, lessThanOrEqualTo(1.55));
    });
  });

  group('cameraShot — invariants (glados)', () {
    glados.Glados(glados.any.danceCtx, glados.ExploreConfig(numRuns: 300)).test(
      'no shot ever exceeds the grounded dance ceiling, and all output is finite',
      (c) {
        final s = cameraShot(c);
        expect(s.zoom, lessThanOrEqualTo(1.55), reason: '$c');
        expect(s.zoom, greaterThan(1.0), reason: '$c');
        expect(s.zoom.isFinite, isTrue, reason: '$c');
        expect(s.dx.isFinite, isTrue, reason: '$c');
        expect(s.dy.isFinite, isTrue, reason: '$c');
      },
      tags: 'glados',
    );

    glados.Glados(glados.any.danceCtx, glados.ExploreConfig(numRuns: 300)).test(
      'never pans further than centring a side cat at the current zoom',
      (c) {
        final s = cameraShot(c);
        expect(
          s.dx.abs(),
          lessThanOrEqualTo(s.zoom * kSideCatCentreRef + 1e-6),
          reason: '$c',
        );
      },
      tags: 'glados',
    );

    glados.Glados(glados.any.danceCtx, glados.ExploreConfig(numRuns: 300)).test(
      'dy stays inside the calm trim + tight-shot drop band (blends included)',
      (c) {
        final dy = cameraShot(c).dy;
        expect(
          dy,
          inInclusiveRange(
            0,
            kHorizonDropPx + kTightShotDropRef,
          ),
          reason: '$c',
        );
      },
      tags: 'glados',
    );
  });
}
