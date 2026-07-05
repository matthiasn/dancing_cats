/// A small "virtual director" for the dance-to-track demo's camera. Instead of
/// looping one push-in move every phrase, it gives each song section its own
/// treatment, scheduled against the bar grid and the section's own progress:
///
/// - calm intro/outro tails: a wide establish that BREATHES and slowly TRUCKS
///   sideways, so the multi-plane depth is already alive before anyone dances;
/// - pre-chorus: a strictly monotonic crane-push that builds into the drop;
/// - verse: a grounded, centred medium riding ONE long eased lateral truck —
///   the whole section is a single deliberate dolly move that slides the
///   planes past each other, not a parked shot with a decorative wobble;
/// - chorus: each refrain owns a DISTINCT, STABLE home keyed on its OCCURRENCE
///   (first centred and widest, second a committed LEFT two-shot toward the
///   silver backup, later ones a committed RIGHT two-shot toward the dark
///   backup), each held wide enough for the vista and legwork to breathe;
/// - bridge (background-only): the backups trade the vocal, so the camera
///   follows the VOICE with one continuous cross-stage TRAVERSE — it holds a
///   committed silver-side feature, then dollies across the trio through
///   centre (crossing exactly on the mid-bridge hand-off) into the brown-side
///   feature, with a slight zoom relax through the middle so the move reads as
///   an arc around the cast;
/// - post-chorus (closing hook): a grounded centred COIL whose beat-phrased
///   sway fades in and out over the section's edges, with one motivated
///   mid-coil push so the long load breathes;
/// - outro: a long pull-back that lands EXACTLY on the calm establish (breathe,
///   drift and trim included) well before the section ends, so the energy
///   gate's hand-off to the idle wide is a no-op instead of a visible step.
///
/// Section changes are ANTICIPATED, never punched: starting
/// [kCameraAnticipationSeconds] before every section boundary the target
/// glides toward the next section's opening framing and PARKS on it
/// [kCameraArriveLeadSeconds] early, so the stateful rig (which eases the live
/// camera toward this target) settles the arrival ON the downbeat — the accent
/// is a dolly that completes with the music, not a snap-zoom. This replaces
/// the old genre punches (the 0.3s fast zooms on the chorus drop and bridge
/// hand-offs), which flattened the parallax exactly on the accents they were
/// meant to sell: every framing change is now a continuous, motivated move
/// slow enough for the planes to visibly slide against each other.
///
/// The painter pins the dance camera's zoom pivot at the dancers' feet, so a
/// push-in plants the feet on the deck and grows the cast UP into the sky
/// rather than craning the feet off the bottom edge. Because the trio stays
/// centred on the lead, a side cat only reaches frame-centre at an extreme
/// zoom, so feature shots are *leaning two-shots* that weight the frame toward
/// a backup while the lead stays the readable star. Most dance shots ride
/// `dy: 0`; the calm establish carries a small positive `dy` trim.
///
/// Pure and deterministic so it is unit-testable and renders identically
/// offline and live. The output `(zoom, dx, dy)` is the camera's TARGET for
/// the frame; a stateful `DanceCameraRig` eases the live camera toward it
/// every tick, ironing out any residual kink (seeks, the energy gate). The
/// eased shot is what reaches `CharacterPainter.cameraOverride`.
library;

import 'dart:math' as math;

import 'package:dancing_cats/features/character/runtime/dance_timing.dart';

/// One framing: zoom about the frame centre plus a pan/crane offset. `dx` is in
/// 2560-wide reference px and `dy` in 1440-ref px (the painter rescales both to
/// the live stage so they frame the same FRACTION at any size): positive `dy`
/// pushes content down (heads clear the seam), negative lifts it. These are
/// *intent* values — the painter clamps the pan to what the zoom can hide.
typedef Shot = ({double zoom, double dx, double dy});

/// Reference-px horizontal pan (per unit of zoom) that brings a side dancer to
/// frame centre. MEASURED from production renders rather than derived from the
/// trio layout constants: the backup lanes ride the painter's inter-cat
/// parallax, so they partially FOLLOW a pan and need a deeper move than the
/// raw spacing suggests (~483 ref px per unit zoom; the old derived 428
/// under-delivered every lean, which is why the review panel kept reading the
/// "committed two-shots" as centred trio frames). Feature shots use a FRACTION
/// of this so they lean the frame toward a cat without slinging it lopsided.
const double kSideCatCentreRef = 483;

/// Small vertical trim (1440-ref px) for the WIDE/calm framings only. With the
/// dance camera's pivot pinned at the feet, a push-in already plants the feet and
/// grows the cast up into the sky, so `dy` is no longer needed to keep feet in
/// frame — the dance shots ride `dy: 0`. This positive nudge just drops the
/// calm wide a touch so the heads clear the waterline seam at z~1.06.
const double kHorizonDropPx = 8;

/// Seconds before a section boundary at which the director starts gliding the
/// target toward the next section's opening framing — the anticipated dolly
/// that replaces the old accent punches. A bit over two bars at the demo
/// track's tempo: long enough that the move reads as its own calm shot (and
/// the parallax planes visibly slide), short enough that the outgoing section
/// keeps its home for most of its length.
const double kCameraAnticipationSeconds = 3.4;

/// Seconds before the boundary at which the anticipated glide PARKS on the
/// next home. The stateful rig lags its target by roughly its smooth time, so
/// parking the target this early makes the EASED camera stationary on the
/// downbeat itself (velocity ≈ 0 as the beat lands, then the section's own
/// push rises out of the settle) — the review panel read the previous 0.5s
/// lead as the arrival smearing past the accent.
const double kCameraArriveLeadSeconds = 0.9;

/// Reference-px amplitude of the calm establish's slow lateral drift. Kept
/// well inside the pan margin the establish zoom exposes (~51 ref px at the
/// breathe's low point) so the clamp never flattens it mid-phrase.
const double kCalmDriftRef = 35;

/// Reference-px amplitude of the small phrase-locked lateral drift added to
/// the chorus and pre-chorus homes. These sections already carry a committed
/// lean/push, so the drift only needs to be a whisper — enough that the
/// parallax planes are never fully parked, without disturbing the held
/// two-shot identity or the pre-chorus's centred build.
const double kHookDriftRef = 16;

/// Reference-px endpoints of the verse's single cross-section truck: the
/// camera slides from a touch off-centre on the dark side all the way ACROSS
/// to the silver side, one deliberate dolly move deep enough (~270 px of
/// travel, ~20 ref px/s at cruise) that the inter-plane differential reads
/// for the whole verse. The truck deliberately ENDS near the bridge's
/// silver-side feature, so the bridge anticipation continues the same gesture
/// at matched velocity instead of yanking a parked camera sideways (the
/// panel measured the old symmetric truck exiting with a 5x gear change).
const double kVerseTruckStartRef = -50;
const double kVerseTruckEndRef = 320;

/// Zoom-linked headroom trim (1440-ref px): tight framings (z > ~1.38) ride a
/// positive dy that drops the cast enough to keep the drone-show signage and
/// the 747's contrail clear of the lead's ears (the panel flagged crown
/// tangents at every tight zoom, twice). Kept moderate — a deeper tier was
/// tried and it cut the lead's shoes mid-sole at the bottom edge on the drop
/// frames; the crown-clearing work belongs to the sky elements themselves
/// (the drone beam stands off the lead's axis, the 747 flies a higher path).
/// Smoothly zero at and below the grounded register, so wide/medium dance
/// shots still ride dy 0.
const double kTightShotDropRef = 26;

/// The trim for a shot at [zoom] — applied uniformly after section blending in
/// [cameraShot], so it is continuous wherever the zoom is.
double tightShotDrop(double zoom) =>
    kTightShotDropRef * smoothstep(((zoom - 1.38) / 0.08).clamp(0.0, 1.0));

/// Seconds of anticipation for a boundary INTO [next] (at [nextOccurrence]).
/// Big lateral re-stagings need a longer runway to stay at dolly speeds AND
/// slow enough that the drop's own launch-push — not the approach — owns the
/// phrase's peak velocity: the first two choruses arrive from wide/centred
/// framings over a long 6s glide, while the third chorus arrives out of the
/// bridge's nearby tail hold on a short runway that leaves the tail a genuine
/// still DWELL (~1s) after the traverse settles. The verse's far-side start is
/// a big reposition too; bridge/coil arrivals are mid-sized; everything else
/// uses the default.
double cameraAnticipationWindow(String next, int nextOccurrence) {
  switch (next) {
    case 'verse':
      return 5.5;
    case 'chorus':
      return nextOccurrence >= 2 ? 4.5 : 6.0;
    case 'bridge':
      // Long: the silver-side hold is a deep re-staging out of the verse
      // truck, and the run-in must stay under ~2x the truck's cruise speed.
      return 5.5;
    case 'post-chorus':
      return 4.5;
    default:
      return kCameraAnticipationSeconds;
  }
}

/// Seconds before a section boundary at which that section's LAUNCH push
/// begins (see [_launch]): the dolly starts early enough that the EASED
/// camera's velocity — which lags the target by roughly the rig's response
/// time — crests on the downbeat itself instead of half a beat after it (the
/// panel measured a 0.35s lead cresting ~0.5s late through the 0.6s rig).
/// Paired with `kDanceCameraSmoothTime` = 0.5 the measured crest lands within
/// ~0.2s of each drop (asserted by the continuity test).
const double kCameraLaunchLeadSeconds = 0.6;

class DanceCameraContext {
  const DanceCameraContext({
    required this.section,
    required this.energetic,
    required this.build,
    required this.phrasePhase,
    required this.sectionPhase,
    this.occurrence = 0,
    this.sectionSeconds = 0,
    this.secondsToNext = double.infinity,
    this.nextSection,
    this.nextOccurrence = 0,
  });

  /// Section label (lower-case: intro/verse/pre-chorus/chorus/post-chorus/
  /// bridge/outro), or '' if unknown.
  final String section;

  /// Whether the stage is dancing (vs the calm idle). Only gates the UNLABELLED
  /// ('' section) fallback: a labelled section keeps performing its treatment
  /// even while the trio eases in or out of rest, so the camera never steps
  /// when the energy gate and the lyric timeline disagree by a few frames.
  final bool energetic;

  /// Overall progress/intensity 0..1 — grows toward the end of the track.
  final double build;

  /// Phase within the current 3-bar phrase, 0..1 — drives the gentle per-phrase
  /// breathe/drift that keeps a held home alive without parking dead-still.
  final double phrasePhase;

  /// Progress through the CURRENT section, 0..1 — drives the continuous moves
  /// (the pre-chorus push, the bridge traverse, the outro de-escalation) that a
  /// per-phrase value would saw-tooth instead of build.
  final double sectionPhase;

  /// How many earlier sections shared this section's label (0 = first). Keys
  /// the per-refrain chorus homes, so a chorus keeps ONE identity for its whole
  /// length instead of re-staging when a build threshold crosses mid-section.
  final int occurrence;

  /// The current section's length in seconds (0 when unknown). Converts
  /// [sectionPhase] into the absolute seconds the LAUNCH curve runs on, so a
  /// launch lasts the same real time in a short refrain and a long one.
  final double sectionSeconds;

  /// Seconds until the next semantic section begins (infinity when this is the
  /// last). Drives the anticipated dolly into the next section's opening.
  final double secondsToNext;

  /// The next semantic section's label, or null when there is none.
  final String? nextSection;

  /// [occurrence] of the next section.
  final int nextOccurrence;
}

/// Builds the context from the absolute (fractional) beat and the loop binding.
/// [sectionPhase] describes where we are inside the current lyric section and
/// must be supplied by the caller (which knows the section timeline); pass `0`
/// when unknown. The beat + loop length give the per-phrase phase. The optional
/// next-section fields feed the anticipated dolly; omitted they disable it.
DanceCameraContext cameraContext({
  required double beat,
  required double anchorBeat,
  required double loopLengthBeats,
  required String section,
  required bool energetic,
  required double build,
  double sectionPhase = 0,
  int occurrence = 0,
  double sectionSeconds = 0,
  double secondsToNext = double.infinity,
  String? nextSection,
  int nextOccurrence = 0,
}) {
  final rel = beat - anchorBeat;
  var phrase = loopLengthBeats > 0 ? (rel / loopLengthBeats) % 1.0 : 0.0;
  if (phrase < 0) phrase += 1.0;
  return DanceCameraContext(
    section: section,
    energetic: energetic,
    build: build.clamp(0.0, 1.0),
    phrasePhase: phrase,
    sectionPhase: sectionPhase.clamp(0.0, 1.0),
    occurrence: occurrence,
    sectionSeconds: math.max(0, sectionSeconds),
    secondsToNext: math.max(0, secondsToNext),
    nextSection: nextSection,
    nextOccurrence: nextOccurrence,
  );
}

const Shot _establish = (zoom: 1.06, dx: 0, dy: kHorizonDropPx);

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Breathe fade-in envelope for a section's phrase-locked zoom breathe: zero at
/// the section head, easing to full over the first quarter. The phrase grid
/// sits at an arbitrary phase when a section lands, so an un-enveloped breathe
/// puts a small crest-and-sag right on the arrival downbeat — the panel read
/// that as the rig overshooting and rebounding. With the envelope, the target
/// at every section opening is EXACTLY the home value and the breathe grows
/// out of the settle.
double _breatheIn(double sectionPhase) =>
    smoothstep((sectionPhase / 0.25).clamp(0.0, 1.0));

/// Position curve 0..1 with smoothstep-eased edges (width [edge]) around a
/// constant-velocity core — the profile of a real dolly truck: ease up to
/// cruise, hold cruise, ease out. A plain smoothstep spends the whole move
/// accelerating/decelerating, which read as "stall → glide → sprint" once the
/// boundary anticipation grabbed the tail.
double _easedTrapezoid(double p, {double edge = 0.18}) {
  final t = p.clamp(0.0, 1.0);
  // Integral of a velocity profile that smoothsteps 0→1 over [0, edge], holds
  // 1 over [edge, 1-edge], and smoothsteps 1→0 over [1-edge, 1]; normalized so
  // the position ends at exactly 1. ∫smoothstep over one ramp = edge/2.
  double rampArea(double x) => x * x * x - x * x * x * x / 2; // ∫₀ˣ smoothstep
  final double travelled;
  if (t < edge) {
    travelled = edge * rampArea(t / edge);
  } else if (t <= 1 - edge) {
    travelled = edge / 2 + (t - edge);
  } else {
    travelled =
        edge / 2 + (1 - 2 * edge) + edge * (0.5 - rampArea((1 - t) / edge));
  }
  return travelled / (1 - edge);
}

Shot _mix(Shot a, Shot b, double t) => (
  zoom: _lerp(a.zoom, b.zoom, t),
  dx: _lerp(a.dx, b.dx, t),
  dy: _lerp(a.dy, b.dy, t),
);

/// Reference-px pan that leans the frame toward a side cat by [frac] of the way
/// to fully centring it at zoom [z]. Positive favours the LEFT (silver) backup,
/// negative the RIGHT (dark) backup.
double _lean(double z, double frac, {required bool left}) =>
    (left ? 1.0 : -1.0) * frac * z * kSideCatCentreRef;

/// The director's shot for a frame: the current section's treatment, blended
/// toward the NEXT section's opening framing across the anticipation window so
/// every boundary is arrived at by a continuous dolly (see the library doc).
Shot cameraShot(DanceCameraContext c) {
  // The current section's launch clock: seconds since [kCameraLaunchLeadSeconds]
  // before this section began (its launch started during the approach).
  final launchSeconds =
      c.sectionPhase * c.sectionSeconds + kCameraLaunchLeadSeconds;
  var shot = _sectionShot(
    c,
    c.section,
    c.occurrence,
    c.sectionPhase,
    launchSeconds: launchSeconds,
  );
  final next = c.nextSection;
  if (next != null) {
    final window = cameraAnticipationWindow(next, c.nextOccurrence);
    if (c.secondsToNext < window) {
      // Glide begins [window] seconds out and PARKS on the next home
      // kCameraArriveLeadSeconds early, so the rig's settle lands on the beat
      // — then the next section's LAUNCH clock starts running
      // kCameraLaunchLeadSeconds before the boundary, so the eased camera's
      // launch velocity crests ON the downbeat (both formulas meet exactly at
      // the boundary: launchSeconds = kCameraLaunchLeadSeconds).
      final glide = window - kCameraArriveLeadSeconds;
      final t = smoothstep(
        ((window - c.secondsToNext) / glide).clamp(0.0, 1.0),
      );
      final open = _sectionShot(
        c,
        next,
        c.nextOccurrence,
        0,
        launchSeconds: math.max(0, kCameraLaunchLeadSeconds - c.secondsToNext),
      );
      shot = _mix(shot, open, t);
    }
  }
  // Zoom-linked headroom trim for the tight registers (see [tightShotDrop]).
  return (zoom: shot.zoom, dx: shot.dx, dy: shot.dy + tightShotDrop(shot.zoom));
}

/// The treatment for [section] at [sectionPhase], reusable for both the current
/// section and the next section's opening (phase 0) during anticipation.
/// [launchSeconds] is the launch clock (see [cameraShot]).
Shot _sectionShot(
  DanceCameraContext c,
  String section,
  int occurrence,
  double sectionPhase, {
  required double launchSeconds,
}) {
  if (section.isEmpty) {
    // No semantic timeline here: dance in the grounded pocket, rest wide.
    return c.energetic ? _pocketShot(c) : _calmShot(c);
  }
  switch (section) {
    case 'chorus':
      return _chorusShot(c, occurrence, sectionPhase, launchSeconds);
    case 'post-chorus':
      return _postChorusShot(c, sectionPhase);
    case 'bridge':
      return _bridgeShot(c, sectionPhase);
    case 'pre-chorus':
      return _preChorusShot(c, sectionPhase);
    case 'outro':
      return _outroShot(c, sectionPhase);
    default:
      return _verseShot(c, sectionPhase);
  }
}

/// Calm establish: the composed wide with a slow breathe — and a slow lateral
/// DRIFT (a quarter-phrase out of step with the breathe, so one of the two is
/// always moving) that keeps the multi-plane depth alive while everyone rests.
/// The zoom breathe FADES OUT over the track's final seconds so the film ends
/// settled on the establish instead of mid-inhale (the panel measured the old
/// breathe re-zooming +0.02 in the last two seconds — a landing bounce).
Shot _calmShot(DanceCameraContext c) {
  final endFade = 1 - smoothstep(((c.build - 0.92) / 0.06).clamp(0.0, 1.0));
  final breathe = math.sin(c.phrasePhase * 2 * math.pi) * 0.01 * endFade;
  final drift = math.cos(c.phrasePhase * 2 * math.pi) * kCalmDriftRef;
  return (zoom: _establish.zoom + breathe, dx: drift, dy: kHorizonDropPx);
}

/// The unlabelled dance fallback (tracks without lyric sections): a living
/// centred medium — fixed grounded zoom with a breathe and a slow phrase-drift,
/// since without a section timeline there is no arc to author a truck against.
Shot _pocketShot(DanceCameraContext c) {
  final breathe = math.sin(c.phrasePhase * 2 * math.pi) * 0.02;
  final drift = math.sin(c.phrasePhase * 2 * math.pi) * 0.05;
  final z = 1.30 + breathe;
  return (zoom: z, dx: drift * z * kSideCatCentreRef, dy: 0);
}

/// Chorus: the hook. Each refrain owns a DISTINCT, STABLE home keyed on its
/// OCCURRENCE — one identity per refrain for its whole length (the old build
/// thresholds could flip a home mid-section):
///   - first chorus: centred and the widest of the hooks, an eased push with a
///     whisper of lateral arc so the depth keeps sliding;
///   - second (and later odd) choruses: a committed LEFT two-shot favouring the
///     silver backup;
///   - third (and later even) choruses: a committed RIGHT two-shot favouring
///     the dark backup, a touch shallower so the bright yacht hull on that side
///     doesn't pull focus.
/// All hooks are capped well under the grounded ceiling so side cats, feet and
/// shadows stay readable; the anticipated dolly (see [cameraShot]) carries the
/// camera into each home ON the downbeat.
/// Seconds a chorus launch-push takes to complete once it starts. Short
/// enough that the eased camera has visibly SETTLED into its new home within
/// about two beats of the drop (a longer window left near-crest velocity
/// running 0.7s past the beat, blurring the arrival).
const double _kLaunchWindowSeconds = 1.3;

/// A push that LAUNCHES on the downbeat: an ease-out on the launch clock
/// (which starts [kCameraLaunchLeadSeconds] BEFORE the boundary), so the eased
/// camera is already accelerating when the beat lands and its velocity crests
/// exactly on the drop, decaying into the hold. A smoothstep launch starting
/// at the boundary itself got flattened by the rig into a frozen first second
/// right where the song hits hardest.
double _launch(double launchSeconds) {
  final p = (launchSeconds / _kLaunchWindowSeconds).clamp(0.0, 1.0);
  return 1 - (1 - p) * (1 - p);
}

Shot _chorusShot(
  DanceCameraContext c,
  int occurrence,
  double sectionPhase,
  double launchSeconds,
) {
  final breathe =
      math.sin(c.phrasePhase * 2 * math.pi) * 0.015 * _breatheIn(sectionPhase);
  // A quarter-phrase out of step with the breathe (mirrors the calm
  // establish) so the hook is never simultaneously at rest on both axes.
  final drift =
      math.cos(c.phrasePhase * 2 * math.pi) * kHookDriftRef * _breatheIn(sectionPhase);
  final launch = _launch(launchSeconds);
  if (occurrence == 0) {
    // The establishing hook: the one true WIDE. The home sits LOW (1.26) so
    // the drop's launch-push owns the phrase's peak zoom velocity — the panel
    // measured the old approach outrunning the launch, which inverted the
    // emphasis (the biggest camera energy landed two seconds before the beat).
    // A slow drift-up then carries the rest of the refrain. The launch also
    // eases the frame a touch RIGHT (negative dx), giving the drop staging's
    // rightward surge room while keeping the silver backup clear of the edge.
    // The launch itself was toned down from 0.09/18 — the panel read the
    // original push as a jump-cut against the section's otherwise calm hold.
    final z = 1.26 + 0.075 * launch + 0.02 * smoothstep(sectionPhase);
    final arc = math.sin(math.pi * sectionPhase) * 20;
    return (zoom: z + breathe, dx: arc - 10 * launch + drift, dy: 0);
  }
  // Later refrains own a genuinely TIGHTER two-shot register — the piece's
  // second shot size (the panel read the old 1.36–1.41 leans as "one wide trio
  // frame nudged sideways for 144 seconds"). The lean puts the featured backup
  // near the frame's power third (~x 0.38) with the lead on the opposite
  // third; the off-side backup crops partially at the frame edge but never
  // vanishes. The right lean stays a touch shallower so the bright yacht hull
  // doesn't pull focus, and both sit deeper than the bridge's tail hold so
  // chorus 3 still arrives as its own camera event after the traverse. The
  // launch adds a small lateral drift INTO the lean, so the drop reads as a
  // diagonal (zoom + pan) even at this shot size.
  final left = occurrence.isOdd;
  // Home 1.445 with a 0.06 launch (toned down from 0.07 — the panel read the
  // original push as a jump-cut against the section's otherwise calm hold):
  // the drop's push still crests above the approach glide's peak velocity, so
  // the accent — not the runway — owns the phrase.
  final z = 1.445 + 0.06 * launch + 0.015 * smoothstep(sectionPhase);
  final launchDrift = (left ? 1 : -1) * 15 * launch;
  return (
    zoom: z + breathe,
    dx: _lean(z, left ? 0.60 : 0.54, left: left) + launchDrift + drift,
    dy: 0,
  );
}

/// Post-chorus: the closing hook — a grounded centred COIL. The zoom settles
/// onto its band with ONE motivated mid-coil push, and the beat-phrased lateral
/// sway that loads the frame off-centre fades in over the section's opening
/// edge and back out before the finish, so the coil enters and resolves with
/// zero lateral velocity no matter where the phrase grid sits.
Shot _postChorusShot(DanceCameraContext c, double sectionPhase) {
  // ONE breath: the zoom rises out of the chorus, crests mid-coil and
  // RELEASES early, instead of flat-lining for four bars. The crest (1.41)
  // sits BELOW the tight two-shot register, so the wind-down never re-occupies
  // the chorus shot size — the coil reads as its own register, not a fourth
  // build.
  final z =
      1.375 + 0.035 * math.sin(math.pi * (sectionPhase / 0.88).clamp(0.0, 1.0));
  // Sway fades in over the opening edge, DECAYS across the coil (a pendulum
  // that never loses energy read as metronomic), and releases over a longer
  // closing edge so the resolution is calm before the outro's pull-back. A
  // small off-phase second harmonic keeps the swing hand-operated — quicker
  // into the loaded side, slower out — rather than a fixed-period metronome.
  final envelope =
      smoothstep((sectionPhase / 0.12).clamp(0.0, 1.0)) *
      smoothstep(((1 - sectionPhase) / 0.3).clamp(0.0, 1.0)) *
      (1 - 0.5 * sectionPhase);
  final swing =
      (math.sin(c.phrasePhase * 2 * math.pi) +
          0.3 * math.sin(4 * math.pi * c.phrasePhase - 0.9)) /
      1.15;
  final sway = swing * 0.09 * envelope;
  return (zoom: z, dx: sway * z * kSideCatCentreRef, dy: 0);
}

/// Bridge (background-only): the camera follows the VOICE with ONE continuous
/// cross-stage traverse. It holds a committed silver-side (left) feature while
/// she carries the first half, then dollies across the trio — crossing centre
/// exactly on the mid-bridge hand-off — into the brown-side (right) feature
/// for the second half. The zoom relaxes slightly through the middle of the
/// traverse so the move reads as an arc around the cast, and every plane
/// slides past the trio for the full width of the stage: the showcase parallax
/// move, at dolly speed instead of the old whip.
Shot _bridgeShot(DanceCameraContext c, double sectionPhase) {
  final t = smoothstep(((sectionPhase - 0.28) / 0.38).clamp(0.0, 1.0));
  // Asymmetric traverse in the tight feature register: a DEEP committed
  // silver-side feature (0.58 — she owns the frame while she owns the vocal,
  // mirroring the chorus two-shot depth), crossing centre a touch before
  // sectionPhase 0.5 so the EASED camera (which lags the target) crosses
  // exactly on the mid-bridge vocal hand-off, then settling on a brown-side
  // hold DEEP enough that the second singer visibly takes the frame (0.40 —
  // the shallower tail read as the lead keeping the mic) yet still under
  // chorus 3's two-shot (0.54), preserving a real arrival on the last drop
  // after a genuine still DWELL.
  final frac = 0.58 - 0.98 * t;
  final breathe =
      math.sin(c.phrasePhase * 2 * math.pi) * 0.015 * _breatheIn(sectionPhase);
  // The zoom-relax arc TROUGHS exactly at the dx crossing (frac zero at
  // t≈0.592), so the frame is widest at the closest pass — the panel measured
  // the old symmetric dip bottoming ~1.6s before the crossing.
  final z = 1.48 - 0.035 * math.sin(math.pi * (t / 1.184)) + breathe;
  return (zoom: z, dx: frac * z * kSideCatCentreRef, dy: 0);
}

/// Pre-chorus: a strictly monotonic crane-push, dead centre. The crest sits
/// just under the chorus homes so the anticipated dolly continues RISING
/// through the drop into the refrain — one unbroken build, no reset and no
/// backwards accent (the old crest overshot the chorus home, so the "drop
/// punch" visibly zoomed OUT). The zoom itself stays untouched by any
/// breathe (a real oscillation risks a mid-build dip, the exact "backwards
/// accent" this shot exists to avoid) but a whisper of lateral drift keeps
/// the parallax alive through the build instead of parking dead-still.
Shot _preChorusShot(DanceCameraContext c, double sectionPhase) => (
  zoom: 1.18 + 0.14 * smoothstep(sectionPhase),
  dx: math.cos(c.phrasePhase * 2 * math.pi) * kHookDriftRef * _breatheIn(sectionPhase),
  dy: 0,
);

/// Outro: one long pull-back that lands EXACTLY on the calm establish —
/// breathe, drift and dy trim included — by three quarters of the section,
/// then rides it. When the energy gate later hands the stage to the idle wide,
/// the camera is already there: no step, however the gate and the lyric
/// timeline happen to line up.
Shot _outroShot(DanceCameraContext c, double sectionPhase) {
  // The establish's own breathe/drift FEATHER IN only after the pull-back has
  // essentially landed (the panel caught the breathe reversing the zoom while
  // the pull-back was still decelerating — a visible bounce at the landing).
  // [_calmShot]'s end-of-track fade then quiets the breathe again before the
  // final frames, so the landing curve is monotone-then-flat, never V-shaped.
  final est = _calmShot(c);
  final g = smoothstep(((sectionPhase - 0.72) / 0.18).clamp(0.0, 1.0));
  final q = smoothstep((sectionPhase / 0.75).clamp(0.0, 1.0));
  final sway = math.sin(c.phrasePhase * 2 * math.pi) * 45;
  return (
    zoom: _lerp(1.40, _establish.zoom + (est.zoom - _establish.zoom) * g, q),
    dx: _lerp(sway, est.dx * g, q),
    dy: _lerp(0, est.dy, q),
  );
}

/// Verses (and anything else energetic): the grounded pocket between hooks —
/// but a living one: ONE long eased lateral truck across the whole section
/// (slightly left of centre to slightly right) under a slow eased push. A
/// single deliberate dolly move that keeps the planes sliding for the entire
/// verse, instead of a parked medium with a decorative per-phrase wobble.
Shot _verseShot(DanceCameraContext c, double sectionPhase) {
  final z = 1.28 + 0.08 * smoothstep(sectionPhase);
  // The truck rides an eased-trapezoid profile: up to cruise, HOLD cruise,
  // ease out — one move with one speed, readable against the parallax planes
  // for the whole verse (a plain smoothstep never stopped accelerating). Its
  // endpoints run dark-side → silver-side so the bridge approach continues
  // the same gesture (see [kVerseTruckStartRef]/[kVerseTruckEndRef]).
  final p = _easedTrapezoid(sectionPhase);
  return (
    zoom: z,
    dx: _lerp(kVerseTruckStartRef, kVerseTruckEndRef, p),
    dy: 0,
  );
}
