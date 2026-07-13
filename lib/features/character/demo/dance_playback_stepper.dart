import 'package:dancing_cats/features/character/demo/dance_camera_director.dart';
import 'package:dancing_cats/features/character/demo/dance_camera_rig.dart';
import 'package:dancing_cats/features/character/demo/dance_lip_sync.dart';
import 'package:dancing_cats/features/character/demo/dance_performance.dart';
import 'package:dancing_cats/features/character/model/beat_map.dart';
import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/dance_dynamics.dart';
import 'package:dancing_cats/features/character/model/face.dart';
import 'package:dancing_cats/features/character/runtime/dance_timing.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';

/// The stateful, history-dependent half of one dance frame: the singing mouths
/// (eased) and the virtual camera (smoothed — every move a slow dolly; section
/// arrivals are anticipated in the director's target). The pure half — which
/// move, the warped clock, the beat, the director context — is
/// [DancePerformance].
///
/// Both the live player and every offline renderer own one stepper and call
/// [advance] once per frame, so the per-frame orchestration (voice gating →
/// mouth ease → stage → director → camera glide) is a single code path
/// that cannot drift between them. Because the camera and mouths integrate over `dt`, an
/// offline renderer must **preroll** (advance without rendering) from a lead-in
/// before the first frame it cares about to settle the framing.
class DancePlaybackStepper {
  final DanceCameraRig _cameraRig = DanceCameraRig();

  double _leadMouth = 0;
  double _bgMouth = 0;
  MouthShape _leadShape = MouthShape.singAh;
  MouthShape _bgShape = MouthShape.singAh;
  Shot _shot = (zoom: 1, dx: 0, dy: 0);
  DanceStage? _stage;
  DanceStage? _rawStage;
  _DanceStageTransition? _transition;
  DanceStage? _pendingFrom;
  double _pendingUntil = 0;
  List<DanceDynamics>? _easedDynamics;

  /// Audio position of the most recent dance-to-dance move cut (null before
  /// the first one), for the camera director's move-cut nudge — see
  /// [DanceCameraContext.secondsSinceMoveCut].
  double? _lastMoveCutPos;

  /// How far open the frontman's mouth is (0 = shut), eased toward the cue.
  double get leadMouth => _leadMouth;

  /// How far open the backups' mouths are.
  double get bgMouth => _bgMouth;

  /// The frontman's current viseme.
  MouthShape get leadShape => _leadShape;

  /// The backups' current viseme.
  MouthShape get bgShape => _bgShape;

  /// The framing the camera rig has settled on.
  Shot get shot => _shot;

  /// The stage from the most recent [advance] (null before the first call).
  DanceStage? get stage => _stage;

  /// Advances the mouths and camera by [dt] seconds at audio position [pos].
  ///
  /// [perf] is null before the track loads — the trio then idles and the camera
  /// holds. [cues] is the Rhubarb lip-sync track (empty → mouths rest).
  void advance(
    DancePerformance? perf,
    List<DanceCue> cues,
    double pos,
    double dt,
  ) {
    final cue = mouthForCue(cueShapeAt(cues, pos));
    final words = perf?.words ?? const <DanceWord>[];
    // No lyrics → the frontman lip-syncs every cue; otherwise only on lead words.
    final leadOn =
        words.isEmpty ||
        (perf?.voiceActive(pos, (w) => w.voice == 'lead') ?? false);
    // The backups sing background ad-libs, and join the lead on group hooks.
    final bgOn =
        perf?.voiceActive(
          pos,
          (w) =>
              w.voice == 'background' ||
              (w.voice == 'lead' && kGroupSections.contains(w.section)),
        ) ??
        false;
    if (leadOn) _leadShape = cue.shape;
    if (bgOn) _bgShape = cue.shape;
    _leadMouth = easeDanceMouth(_leadMouth, leadOn ? cue.open : 0.0, dt);
    _bgMouth = easeDanceMouth(_bgMouth, bgOn ? cue.open : 0.0, dt);

    final rawStage = perf?.stageAt(pos) ?? danceIdleStage(pos);
    final transitioned = _stageWithTransition(
      rawStage,
      dt,
      perf: perf,
      pos: pos,
    );
    final stage = _easedDynamicsStage(transitioned, dt);
    final lastCut = _lastMoveCutPos;
    final ctx = perf?.directorContext(
      pos,
      energetic: stage.energetic,
      secondsSinceMoveCut: lastCut == null ? double.infinity : pos - lastCut,
    );
    // The move-cut nudge is measured post-hoc as the delta [cameraShot] adds
    // for [ctx] vs. the same context with no recent cut, rather than reading
    // it straight off [ctx]: this keeps that arithmetic in one place
    // ([_moveCutNudge] inside [cameraShot]) instead of duplicating it here.
    Shot target;
    var postRigNudge = 0.0;
    if (ctx == null) {
      target = _shot;
    } else if (ctx.secondsSinceMoveCut.isInfinite) {
      target = cameraShot(ctx);
    } else {
      final withNudge = cameraShot(ctx);
      target = cameraShot(_withoutMoveCut(ctx));
      postRigNudge = withNudge.zoom - target.zoom;
    }
    _shot = _cameraRig.update(target: target, dt: dt);
    // Applied AFTER the rig's smoothing, not baked into its target: the nudge
    // already carries its own attack/decay envelope (see [_moveCutNudge]), and
    // the rig's `kDanceCameraSmoothTime` (0.5s) — tuned for the director's
    // grand, slow section-level dollies — is comparable to the nudge's own
    // ~0.5s total width. Measured (and confirmed by the panel): running the
    // nudge through that filter cut its peak by ~66% and pushed it a third of
    // a second late, reading as either "no push-in at all" or "a slow creep
    // that keeps growing," never the crisp edit-acknowledgment it was
    // designed to be. Adding it here instead lets it reach the screen exactly
    // as authored while the rig still smooths every other, genuinely
    // continuous camera move.
    if (postRigNudge != 0) {
      _shot = (zoom: _shot.zoom + postRigNudge, dx: _shot.dx, dy: _shot.dy);
    }
    _stage = stage;
  }

  /// Eases `stage.dynamics` toward its per-frame target over
  /// [kDanceDynamicsEaseSeconds]. `_stageWithTransition`'s clip-name-keyed
  /// blend already crossfades dynamics smoothly across a MOVE change, but a
  /// section-level-only step (same clips, new `DanceSection.level`) fires no
  /// clip transition at all — this is the one mechanism that also smooths
  /// that case, so the Effort layer never pops independent of what triggered
  /// the change. Offline exporters already **preroll** the stepper (see the
  /// class doc), so this state settles identically live and offline.
  DanceStage _easedDynamicsStage(DanceStage stage, double dt) {
    final previous = _easedDynamics;
    if (previous == null || previous.length != stage.dynamics.length) {
      _easedDynamics = stage.dynamics;
      return stage;
    }
    final k = (dt / kDanceDynamicsEaseSeconds).clamp(0.0, 1.0);
    final eased = [
      for (var i = 0; i < stage.dynamics.length; i++)
        DanceDynamics.lerp(previous[i], stage.dynamics[i], k),
    ];
    _easedDynamics = eased;
    return (
      lead: stage.lead,
      ensemble: stage.ensemble,
      seconds: stage.seconds,
      section: stage.section,
      energetic: stage.energetic,
      synchronous: stage.synchronous,
      segmentStartSec: stage.segmentStartSec,
      dynamics: eased,
      energyLevel: stage.energyLevel,
    );
  }

  DanceStage _stageWithTransition(
    DanceStage rawGlobal,
    double dt, {
    DancePerformance? perf,
    double pos = 0,
  }) {
    // PHASE ALIGNMENT (transitions panel r2, the dominant remaining
    // ceiling): the incoming move used to enter at whatever bar of its
    // 4-bar phrase the GLOBAL grid dictated, so bar-1-loaded signatures
    // (azonto's kick) could arrive a full bar late — "silhouette-anonymous"
    // entries decided purely by grid luck. Every dance stage is re-anchored
    // here on the first downbeat at/after its own choreo statement's start
    // ([DanceStage.segmentStartSec]), so each entry opens on its own bar 1
    // — the dancer takes the new move on the one.
    final previousRaw = _rawStage;
    // A semantic section boundary may select the exact same trio again. In
    // that case restarting the same clip on the new section's phrase anchor is
    // not a choreographic cut at all; it is an invisible clock reset. Because
    // the name-only signature correctly says "same move", no blend follows and
    // the whole skeleton teleports to the new phase (measured at 74.03s: 36u
    // hands / 52u foot). Carry the existing statement anchor across identical
    // trios so the dancer simply keeps doing the phrase through the boundary.
    final continuedGlobal =
        previousRaw != null &&
            previousRaw.energetic &&
            rawGlobal.energetic &&
            _stageSignature(previousRaw) == _stageSignature(rawGlobal)
        ? _stageWithSegmentStart(rawGlobal, previousRaw.segmentStartSec)
        : rawGlobal;
    final raw = _rebasedStage(perf, continuedGlobal, pos);
    if (previousRaw == null) {
      _rawStage = raw;
      _transition = null;
      return raw;
    }

    if (_stageSignature(previousRaw) != _stageSignature(raw)) {
      final from = _stage ?? previousRaw;
      _rawStage = raw;
      if (!_canBlendStages(from, raw)) {
        _transition = null;
        _pendingFrom = null;
        return raw;
      }
      // BEAT-QUANTIZED CUT (transitions panel r1, all four lenses): the set
      // list switches wherever the section/slot boundary falls, which
      // amputated ballistic limbs mid-flight (azonto's kick at peak,
      // zanku's lifted stomp — "no dancer exits a kick like that"). For
      // dance->dance handoffs, HOLD the outgoing move — its clips keep
      // dancing on their OWN phrase clock — until the next detected beat,
      // so the outgoing phrase resolves onto a count and the blend launches
      // from a landed pose. Rest transitions keep the immediate ease
      // (nothing musical to preserve).
      if (from.energetic && raw.energetic && perf != null) {
        final nextBeat = _nextBeatAfter(perf, pos);
        if (nextBeat != null &&
            nextBeat - pos > dt &&
            nextBeat - pos < kDanceCutQuantizeMaxWaitSeconds) {
          _pendingFrom = from;
          _pendingUntil = nextBeat;
          _transition = null;
          return _heldStage(from, raw, _fromSeconds(perf, from, raw, pos));
        }
      }
      _pendingFrom = null;
      _transition = _DanceStageTransition(from: from, elapsed: 0);
      if (from.energetic && raw.energetic) _lastMoveCutPos = pos;
    } else {
      _rawStage = raw;
    }

    final pending = _pendingFrom;
    if (pending != null) {
      if (pos < _pendingUntil) {
        return _heldStage(pending, raw, _fromSeconds(perf, pending, raw, pos));
      }
      _pendingFrom = null;
      _transition = _DanceStageTransition(from: pending, elapsed: 0);
      _lastMoveCutPos = pos;
    }

    final transition = _transition;
    if (transition == null) return raw;

    final elapsed = transition.elapsed + dt;
    // Dance↔dance keeps the tight window (hits survive); easing into or out
    // of REST takes a longer, calmer settle.
    final danceToDance = transition.from.energetic && raw.energetic;
    final movingFamilyTransition =
        transition.from.lead.belongsToFamily('moving') ||
        raw.lead.belongsToFamily('moving');
    final window = danceToDance
        ? (movingFamilyTransition
              ? _movingTransitionSeconds(transition.from, raw)
              : kDanceMoveTransitionSeconds)
        : kDanceRestTransitionSeconds;
    if (elapsed >= window) {
      _transition = null;
      return raw;
    }
    _transition = transition.withElapsed(elapsed);
    final weight = smoothstep(elapsed / window);
    // The outgoing side keeps its OWN phrase clock through the blend: the
    // blended clip samples the from-channels at seconds + fromTimeShift, so
    // neither side snaps phase at the cut even though their anchors differ.
    final fromSeconds = _fromSeconds(perf, transition.from, raw, pos);
    return _blendStage(
      from: transition.from,
      to: raw,
      weight: weight,
      // A Clip is sampled with normalized LOCAL phase, so its channel mixer no
      // longer knows how many incoming loops elapsed in absolute song time.
      // Compare the outgoing clock with the incoming clip's local seconds;
      // subtracting absolute `raw.seconds` only happened to work when both
      // clips shared a duration. At dance→idle it selected an unrelated source
      // pose and produced the measured one-frame limb teleport at 138.03s.
      fromTimeShiftSeconds:
          fromSeconds - _localClipSeconds(raw.seconds, raw.lead.duration),
      fromPlaybackTimeShiftSeconds: fromSeconds - raw.seconds,
      // Moving's body, support and arms are authored as one whole-body phrase.
      // The catalogue mask deliberately makes feet/body arrive early and hands
      // late, but on these connected arcs that staging compresses each limb's
      // travel into a smaller slice of the already-short handoff and reads as
      // mechanical reassembly. Blend the song phrases coherently over the full
      // one-beat window; keep the hit-preserving staged mask for the catalogue.
      blendMask: danceToDance && movingFamilyTransition
          ? ClipBlendMask.full
          : _danceMoveBlendMask,
    );
  }

  /// [stage] with its warped clock re-anchored on the first downbeat at/after
  /// its own choreo statement start. Idle stages and null [perf] pass through.
  DanceStage _rebasedStage(
    DancePerformance? perf,
    DanceStage stage,
    double pos,
  ) {
    if (perf == null || !stage.energetic) return stage;
    final binding = _segmentBinding(
      perf,
      stage.lead,
      stage.segmentStartSec,
    );
    return (
      lead: stage.lead,
      ensemble: stage.ensemble,
      seconds: perf.map.clipSecondsAt(
        pos,
        clipDuration: stage.lead.duration,
        binding: binding,
      ),
      section: stage.section,
      energetic: stage.energetic,
      synchronous: stage.synchronous,
      segmentStartSec: stage.segmentStartSec,
      dynamics: stage.dynamics,
      energyLevel: stage.energyLevel,
    );
  }

  /// The outgoing side's clock at [pos] during a hold or blend — its own
  /// segment anchor when both sides dance, else the incoming clock (rest
  /// transitions keep the original shared-clock behavior).
  double _fromSeconds(
    DancePerformance? perf,
    DanceStage from,
    DanceStage to,
    double pos,
  ) {
    if (perf == null) return to.seconds;
    // Idle still has a visible breathing/arm clock. Sampling it on the
    // incoming dance's newly rebased phrase clock changes the outgoing pose on
    // the first blend frame even at weight zero (the 10.15s entrance produced
    // the full-song audit's largest hand velocity kink). Keep idle on the
    // continuous playback clock until the incoming dance owns the pose.
    if (!from.energetic) return pos;
    // A dance→rest transition must keep the OUTGOING dance on its own phrase
    // clock too. Reusing idle's raw seconds here jumped the outgoing clip to an
    // unrelated phase on the first blend frame (full-song probe: 138.03s,
    // 62-unit right-hand and 89-unit left-foot teleports). Idle has no musical
    // pose clock worth preserving; the dancing side does.
    return perf.map.clipSecondsAt(
      pos,
      clipDuration: from.lead.duration,
      binding: _segmentBinding(perf, from.lead, from.segmentStartSec),
    );
  }

  final Map<(String, double), BeatLoopBinding> _segmentBindings = {};

  /// The phrase binding anchored on the first downbeat at/after
  /// [segmentStartSec], additionally rotated by [kDanceEntryPhaseOffset]
  /// for moves whose identifying gesture doesn't live at its own phrase's
  /// frame 0. Falls back to the performance's global binding (still offset)
  /// when the segment starts past the last detected downbeat.
  ///
  /// Transitions panel r3 (all four lenses, zoom-crop verified): once entry
  /// became deterministic, azonto's incoming reads converged onto its own
  /// "bar 1" — a quiet wheel-mime/arm-orbit hold — because that's genuinely
  /// what sits at phase 0 of its clip (confirmed reading azonto_data.dart:
  /// the alternating point/jab, its identifying gesture, doesn't start
  /// until frame 16 of the 32-frame loop). Since azonto LOOPS seamlessly
  /// (frame 32 == frame 0 by construction), rotating which phase counts as
  /// "the start" for entry purposes is a pure phase shift of the SAME
  /// content — it changes nothing about the already-9/10 full loop, only
  /// which part of the cycle plays first right after a cut.
  BeatLoopBinding _segmentBinding(
    DancePerformance perf,
    Clip lead,
    double segmentStartSec,
  ) {
    final moveName = lead.name;
    return _segmentBindings.putIfAbsent((moveName, segmentStartSec), () {
      // Moving is authored as an eight-beat/32-frame phrase: its signature
      // calls sit at frames 4/8/12 and therefore belong on consecutive beats.
      // The catalogue-wide four-bar binding stretches those events across 16
      // beats (0.75x authored speed on this track), which the full-song owner
      // review correctly read as slow and low-energy. Keep the older catalogue
      // on its sustainable four-bar calibration, but let the song-specific
      // Moving family run on its natural two-bar clock (1.5x authored speed,
      // four authored frames per detected beat at 120 BPM) — with the family's
      // pocket swing, so the phrase subdivides the beat like the track does
      // instead of like a metronome.
      final songGroove = lead.belongsToFamily('moving');
      final loopLengthBeats = songGroove
          ? kMovingPhraseLoopBeats
          : perf.binding.loopLengthBeats;
      final swing = songGroove ? kMovingSwingBeats : 0.0;
      final offsetBeats =
          ((kDanceEntryPhaseOffset[moveName] ?? 0) * loopLengthBeats).round();
      int rotate(int anchorBeatIndex) {
        if (offsetBeats == 0) return anchorBeatIndex;
        // Subtracting rotates which phase lands on the anchor beat; wrap by
        // full loop lengths (periodic in loopLengthBeats) to stay >= 0 —
        // BeatLoopBinding asserts a non-negative anchor.
        var shifted = anchorBeatIndex - offsetBeats;
        while (shifted < 0) {
          shifted += loopLengthBeats;
        }
        return shifted;
      }

      final beats = perf.map.beatTimesSec;
      for (final db in perf.map.downbeatIndices) {
        if (beats[db] >= segmentStartSec - 0.05) {
          return BeatLoopBinding(
            loopLengthBeats: loopLengthBeats,
            anchorBeatIndex: rotate(db),
            swing: swing,
          );
        }
      }
      return BeatLoopBinding(
        loopLengthBeats: loopLengthBeats,
        anchorBeatIndex: rotate(perf.binding.anchorBeatIndex),
        swing: swing,
      );
    });
  }
}

/// Time constant for easing `DanceStage.dynamics` toward its per-frame target
/// (see `_easedDynamicsStage`). Roughly the move-transition window
/// ([kDanceMoveTransitionSeconds]) — long enough to remove a section-level
/// step, short enough that a real move change (which the clip blend already
/// smooths) doesn't visibly lag its dynamics behind its pose.
const double kDanceDynamicsEaseSeconds = 0.15;

/// Per-move fraction (0..1) of the move's OWN phrase where its identifying
/// gesture lives, for moves whose signature is not at phase 0. Empty/absent
/// entries mean "identity is at bar 1" (the default, correct for most of the
/// catalogue — shaku/zanku/sekem/buga all lead with a recognizable accent).
///
/// azonto 0.65: the alternating point/jab (this move's namesake gesture)
/// starts at frame 16 of its 32-frame loop — exactly HALFWAY (phase 0.5).
/// The value here is 0.65, not 0.5, because this offset rotates the
/// binding's DOWNBEAT anchor, while the beat-quantized cut fires on the
/// nearest BEAT after the raw boundary — a coarser-vs-finer mismatch that
/// empirically leaves the phrase clock running ~0.15 phase (~2-3 beats)
/// behind the intended landing at the actual cut instant (probe-measured
/// across both azonto entries on the sample track: cut-time phase 0.32-0.38
/// at offset 0.5). +0.15 lands the cut consistently at phase ~0.44-0.50 —
/// the jab is already arriving, not still a bar-half away. See
/// [DancePlaybackStepper._segmentBinding] for why rotating the entry phase
/// is safe (a pure phase shift of a seamlessly looping clip, not a content
/// change) and the transitions-panel finding that motivated it.
const Map<String, double> kDanceEntryPhaseOffset = {'azonto': 0.65};

/// Moving's authored 32-frame phrase spans eight musical beats (two 4/4 bars).
const int kMovingPhraseLoopBeats = 8;

/// Pocket swing for the Moving family, in beats (see [BeatLoopBinding.swing]).
///
/// The authored phrases are keyed on a straight even-frame grid, but the
/// track's own accents don't play straight: of the 65 strong onsets the accent
/// envelope fires on, the median sits ~106ms off the detected beat grid. A
/// straight clock therefore subdivides every beat with machine precision that
/// the music itself doesn't have — one of the loudest "robot" tells. 0.06
/// beats ≈ 31ms at this track's ~115 BPM: the downbeat content stays exactly
/// on the detected beats while the offbeat content sits back into the pocket.
/// Applied through the binding so arms, feet, and support changes swing as one
/// body instead of the upper body detaching from its own steps. The swing
/// modulates the clip clock's local rate by ±π·swing inside each beat, so the
/// full-song continuity audit measures motion on the CONTENT clock (see
/// `_contentClockRate` in dance_production_motion_continuity_test.dart) —
/// wall-clock bands would otherwise cap the pocket depth by measurement
/// artefact rather than by musical choice.
const double kMovingSwingBeats = 0.06;

/// The short window used when one catalogue move changes to another.
///
/// It is intentionally less than half a beat at 120 BPM: long enough to remove
/// robotic pose cuts, short enough to preserve Afrobeats hits and foot plants.
const double kDanceMoveTransitionSeconds = 0.18;

/// Song-authored Moving phrases carry broad, multi-beat arm paths. Changing
/// between two of them in the catalogue's 0.18s hit-preserving window forces a
/// hand to traverse an overhead-to-low delta in roughly nine frames, which the
/// production probe measured as 20–30 rig units per 60fps frame even after the
/// seconds/phase teleport bug was fixed. The earlier 0.65s window then became
/// a different failure: with Moving restored to its authored two-bar clock,
/// more than a full beat of whole-body crossfade reads as a slow pose morph.
/// 0.4s keeps a coherent path but lets the new phrase take ownership before
/// its accent has been washed out.
const double kMovingPhraseTransitionSeconds = 0.4;

/// The hook-to-answer exchange has the largest deliberate silhouette change
/// in Moving: lead crown, support leg, ribs and both arm diagonals all trade
/// roles. A generic one-beat crossfade made every part travel fastest on the
/// same frame (112.36s in the production probe), which reads as one residual
/// whole-body teleport even though no individual channel is discontinuous.
/// Give that named exchange a small amount of extra travel time, but no longer
/// the old two-beat/1.0s dissolve that the full-song review found low-energy.
const double kMovingHookAnswerTransitionSeconds = 0.55;

/// Entering the hook call (lead `movingHookLead`), whose flanks answer on
/// displaced clocks — see `_movingTransitionSeconds`.
const double kMovingHookCallTransitionSeconds = 0.44;

/// Body-roll entries/exits trade a high arm-led phrase for the lowest,
/// torso-led silhouette in the score. The generic 0.4s Moving handoff still
/// reverses a rendered hand within one 30fps frame on that full-range change;
/// one extra tenth lets the arm pour through the contrast without changing
/// either phrase's authored tempo.
const double kMovingBodyRollTransitionSeconds = 0.5;

double _movingTransitionSeconds(DanceStage from, DanceStage to) {
  if (from.lead.name == 'movingHookLead' &&
      to.lead.name == 'movingHookSideAnswer') {
    return kMovingHookAnswerTransitionSeconds;
  }
  // Entering the hook CALL statement: its flanks are the phase-shifted
  // call-and-response variants (kMovingEchoPhase/kMovingCanonPhase), whose
  // support timing is deliberately displaced from the outgoing statement's.
  // The generic 0.4s window measured 7.42 units/frame² of flank foot
  // acceleration at the blend's end — inside the historical support-flip
  // signature band the 7-unit gate exists to catch — so this named entry
  // takes a slightly longer pour.
  if (to.lead.name == 'movingHookLead') {
    return kMovingHookCallTransitionSeconds;
  }
  if (from.lead.name == 'movingBodyRoll' || to.lead.name == 'movingBodyRoll') {
    return kMovingBodyRollTransitionSeconds;
  }
  return kMovingPhraseTransitionSeconds;
}

/// The longest a dance->dance handoff may be HELD waiting for the next beat
/// (the cut-quantize above). One beat at 120 BPM is 0.5s; the guard only
/// matters on slow or gap-ridden beat maps, where waiting longer would make
/// the section change read late.
const double kDanceCutQuantizeMaxWaitSeconds = 0.75;

/// The outgoing stage held during a quantized cut: the OLD trio keeps dancing
/// on its OWN phrase clock ([fromSeconds]) while the boundary waits for its
/// beat, so nothing pops and the outgoing phrase finishes honestly.
DanceStage _heldStage(DanceStage from, DanceStage to, double fromSeconds) => (
  lead: from.lead,
  ensemble: from.ensemble,
  seconds: fromSeconds,
  section: to.section,
  energetic: to.energetic,
  synchronous: to.synchronous,
  segmentStartSec: from.segmentStartSec,
  // The outgoing trio keeps its OWN Effort character while it dances out the
  // hold, not the new section's — it hasn't arrived at the new move/section
  // yet, so nothing about it should read as already having changed.
  dynamics: from.dynamics,
  // ...but the effort AMPLITUDE arc follows the song's current energy (the
  // section the playhead is actually in).
  energyLevel: to.energyLevel,
);

/// The first detected beat strictly after [pos], or null past the map's end.
double? _nextBeatAfter(DancePerformance perf, double pos) {
  final beats = perf.map.beatTimesSec;
  var lo = 0;
  var hi = beats.length;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (beats[mid] <= pos) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return lo < beats.length ? beats[lo] : null;
}

/// The longer settle used when the trio eases into or out of REST (idle):
/// nothing musical to preserve there, and a calm body change reads better.
///
/// Raised 0.45 -> 1.3 (owner, live: "the jump right after music start is too
/// harsh"): this window no longer only eases the pose — `CharacterPainter`
/// and `StageLightsOverlay` now also ride it for the whole "stage light
/// comes up" reveal (pre-show dim, gel/rim, floor pools, hero
/// staging/formation), since all of those key off the same blended clip's
/// `ClipTransitionPlan.weight`. 0.45s was tuned for just a body-pose ease
/// and reads as a snap once it's also switching the lighting on; a real
/// stage light cue needs real time to feel like a deliberate reveal rather
/// than a hard cut with a fast fade bolted on.
const double kDanceRestTransitionSeconds = 1.3;

const _bodyBlendWindow = ClipBlendWindow(end: 0.72);
const _shoulderBlendWindow = ClipBlendWindow(start: 0.06, end: 0.88);
const _armBlendWindow = ClipBlendWindow(start: 0.12, end: 0.96);
const _secondaryBlendWindow = ClipBlendWindow(start: 0.24);
const _footBlendWindow = ClipBlendWindow(end: 0.7);
const _handTargetBlendWindow = ClipBlendWindow(start: 0.14);

/// Dance transitions layer the incoming move instead of replacing every track
/// on the same tick. Weight-bearing body/feet settle first, arm targets arrive
/// through the middle, and secondary parts follow last.
const _danceMoveBlendMask = ClipBlendMask(
  root: _bodyBlendWindow,
  joints: {
    CatBones.hips: _bodyBlendWindow,
    CatBones.torso: _bodyBlendWindow,
    CatBones.clavicleL: _shoulderBlendWindow,
    CatBones.clavicleR: _shoulderBlendWindow,
    CatBones.shoulderSocketL: _shoulderBlendWindow,
    CatBones.shoulderSocketR: _shoulderBlendWindow,
    CatBones.armBicepL: _shoulderBlendWindow,
    CatBones.armBicepR: _shoulderBlendWindow,
    CatBones.armUpperL: _armBlendWindow,
    CatBones.armUpperR: _armBlendWindow,
    CatBones.armLowerL: _armBlendWindow,
    CatBones.armLowerR: _armBlendWindow,
    CatBones.armForearmL: _armBlendWindow,
    CatBones.armForearmR: _armBlendWindow,
    CatBones.handL: _armBlendWindow,
    CatBones.handR: _armBlendWindow,
    CatBones.legUpperL: _footBlendWindow,
    CatBones.legUpperR: _footBlendWindow,
    CatBones.legLowerL: _footBlendWindow,
    CatBones.legLowerR: _footBlendWindow,
    CatBones.footL: _footBlendWindow,
    CatBones.footR: _footBlendWindow,
    CatBones.earL: _secondaryBlendWindow,
    CatBones.earR: _secondaryBlendWindow,
    CatBones.tail0: _secondaryBlendWindow,
    CatBones.tail1: _secondaryBlendWindow,
    CatBones.tail2: _secondaryBlendWindow,
    CatBones.tail3: _secondaryBlendWindow,
    CatBones.tail4: _secondaryBlendWindow,
    CatBones.tail5: _secondaryBlendWindow,
    CatBones.tail6: _secondaryBlendWindow,
    CatBones.tie: _secondaryBlendWindow,
    CatBones.tieLower: _secondaryBlendWindow,
  },
  limbTargets: {
    CatBones.handL: _handTargetBlendWindow,
    CatBones.handR: _handTargetBlendWindow,
    CatBones.footL: _footBlendWindow,
    CatBones.footR: _footBlendWindow,
  },
);

class _DanceStageTransition {
  const _DanceStageTransition({required this.from, required this.elapsed});

  final DanceStage from;
  final double elapsed;

  _DanceStageTransition withElapsed(double value) =>
      _DanceStageTransition(from: from, elapsed: value);
}

/// [c] with [DanceCameraContext.secondsSinceMoveCut] reset to infinity — used
/// to measure the move-cut nudge's contribution to [cameraShot] by diffing
/// against the context that includes it (see [DancePlaybackStepper.advance]).
DanceCameraContext _withoutMoveCut(DanceCameraContext c) => DanceCameraContext(
  section: c.section,
  energetic: c.energetic,
  build: c.build,
  phrasePhase: c.phrasePhase,
  sectionPhase: c.sectionPhase,
  occurrence: c.occurrence,
  sectionSeconds: c.sectionSeconds,
  secondsToNext: c.secondsToNext,
  nextSection: c.nextSection,
  nextOccurrence: c.nextOccurrence,
);

String _stageSignature(DanceStage stage) => [
  stage.lead.name,
  for (final clip in stage.ensemble) clip.name,
].join('|');

/// The stage the live app/export must paint for [pos].
///
/// Once [stepper] has advanced, its stage owns held cuts, independent source
/// clocks, and transient blended clips. Falling back to the raw performance is
/// only valid before the first step; bypassing the stepper here reintroduces
/// the hard-cut arm teleports its continuity machinery exists to remove.
DanceStage playbackStageForRender(
  DancePlaybackStepper stepper,
  DancePerformance? performance,
  double pos,
) => stepper.stage ?? performance?.stageAt(pos) ?? danceIdleStage(pos);

DanceStage _stageWithSegmentStart(DanceStage stage, double segmentStartSec) => (
  lead: stage.lead,
  ensemble: stage.ensemble,
  seconds: stage.seconds,
  section: stage.section,
  energetic: stage.energetic,
  synchronous: stage.synchronous,
  segmentStartSec: segmentStartSec,
  dynamics: stage.dynamics,
  energyLevel: stage.energyLevel,
);

double _localClipSeconds(double seconds, double duration) {
  if (duration <= 0) return seconds;
  final local = seconds % duration;
  return local < 0 ? local + duration : local;
}

bool _canBlendStages(DanceStage from, DanceStage to) =>
    // Blending needs matching member counts; everything else crossfades.
    // Idle↔dance and duration-mismatched stages used to HARD-CUT here — the
    // blended clip samples both sources at the shared phase, so a duration
    // mismatch only means the outgoing pose drifts speed slightly during the
    // short window, which reads far better than a pose snap.
    from.ensemble.length == to.ensemble.length;

DanceStage _blendStage({
  required DanceStage from,
  required DanceStage to,
  required double weight,
  double fromTimeShiftSeconds = 0,
  double? fromPlaybackTimeShiftSeconds,
  ClipBlendMask blendMask = _danceMoveBlendMask,
}) => (
  lead: blendedClip(
    from: from.lead,
    to: to.lead,
    weight: weight,
    name: '${from.lead.name}->${to.lead.name}',
    blendMask: blendMask,
    fromTimeShiftSeconds: fromTimeShiftSeconds,
    fromPlaybackTimeShiftSeconds: fromPlaybackTimeShiftSeconds,
  ),
  ensemble: [
    for (var i = 0; i < to.ensemble.length; i++)
      blendedClip(
        from: from.ensemble[i],
        to: to.ensemble[i],
        weight: weight,
        name: '${from.ensemble[i].name}->${to.ensemble[i].name}',
        blendMask: blendMask,
        fromTimeShiftSeconds: fromTimeShiftSeconds,
        fromPlaybackTimeShiftSeconds: fromPlaybackTimeShiftSeconds,
      ),
  ],
  seconds: to.seconds,
  section: to.section,
  energetic: to.energetic,
  synchronous: to.synchronous,
  segmentStartSec: to.segmentStartSec,
  dynamics: [
    for (var i = 0; i < to.dynamics.length; i++)
      DanceDynamics.lerp(from.dynamics[i], to.dynamics[i], weight),
  ],
  // Blend the song-energy arc toward the incoming section too.
  energyLevel: from.energyLevel + (to.energyLevel - from.energyLevel) * weight,
);
