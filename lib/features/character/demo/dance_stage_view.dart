import 'dart:ui' as ui;

import 'package:dancing_cats/features/character/demo/dance_camera_director.dart';
import 'package:dancing_cats/features/character/demo/dance_lip_sync.dart';
import 'package:dancing_cats/features/character/demo/dance_performance.dart';
import 'package:dancing_cats/features/character/engine/autonomic.dart';
import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/dance_dynamics.dart';
import 'package:dancing_cats/features/character/model/dance_dynamics_warp.dart';
import 'package:dancing_cats/features/character/model/face.dart';
import 'package:dancing_cats/features/character/runtime/character_painter.dart';
import 'package:dancing_cats/features/character/runtime/character_renderer.dart';
import 'package:dancing_cats/features/character/runtime/character_scene.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';
import 'package:dancing_cats/features/scenery/layered_backdrop.dart';
import 'package:dancing_cats/features/scenery/model/backdrop_grade.dart';
import 'package:dancing_cats/features/scenery/model/backdrop_scene.dart';
import 'package:dancing_cats/features/scenery/runtime/grade_filter.dart';
import 'package:dancing_cats/features/scenery/runtime/stage_lights.dart';
import 'package:dancing_cats/features/scenery/scene_texture_overlay.dart';
import 'package:dancing_cats/features/scenery/drop_bloom.dart';
import 'package:dancing_cats/features/scenery/stage_lights_overlay.dart';
import 'package:flutter/material.dart';

/// The generalized **live paint path** for the beat-synced dance showcase.
///
/// The live player (`DanceToTrackPage`) renders this widget. It owns the paint
/// constants and the stage-light rig that previously had to be hand-synced
/// across two paint paths (gel cadence via [danceStageRig], backlight weights,
/// body grade, haze band, cast scale, cast, caption), so they cannot diverge.
///
/// The offline renderers (the MP4 exporter and the position-window debug
/// harness) do NOT pump this widget — they go through `DanceFrameComposer`, a
/// fast canvas re-paint that *single-sources those same constants/rig from this
/// file*. So the two paint paths share their constants and the cat compositor
/// (via [danceCharacterPainter]); only the ambient stage-light phase differs
/// offline, by design (see `DanceFrameComposer`).
///
/// The per-frame *derivation* (which move, warped clock, beat, camera) is
/// supplied by the caller from a [DancePerformance]; the stateful camera/mouth
/// integration by a `DancePlaybackStepper`.
class DanceStageView extends StatelessWidget {
  const DanceStageView({
    required this.cast,
    required this.renderer,
    required this.stage,
    required this.shot,
    required this.beat,
    this.bodyAccent = 0,
    this.bodyAnticipation = 0,
    required this.backdropTimeSeconds,
    required this.lightsTimeSeconds,
    required this.bpm,
    required this.leadMouth,
    required this.bgMouth,
    required this.leadShape,
    required this.bgShape,
    required this.dancerAnchors,
    this.onDancerAnchors,
    this.useNewBackdrop = true,
    this.showCaptions = false,
    this.words = const [],
    this.grade = BackdropGrade.identity,
    this.masterGrade = BackdropGrade.identity,
    this.castGrade = BackdropGrade.identity,
    this.gradeForTarget,
    this.allowGradeSnapshots = false,
    this.onBackdropReady,
    this.backdropImage,
    this.cloudsImage,
    this.wavesImage,
    this.boundaryKey,
    super.key,
  });

  /// The three dancers (lead, left, right).
  final DanceCast cast;
  final CharacterRenderer renderer;

  /// The frame's derived stage: lead clip, ensemble clips, warped clock, canon.
  final DanceStage stage;

  /// The virtual director's framing (applied verbatim by the painter).
  final Shot shot;

  /// 0..1 beat pulse (lights/foam brightness; never the cat bodies).
  final double beat;

  /// Music-driven body accent (0..1) — the onset-hit weight-drop applied to the
  /// cat bodies (see `DancePerformance.accentAt`). 0 = no accent.
  final double bodyAccent;

  /// Music-driven anticipation (0..1) — the look-ahead coil before the next hit
  /// (see `DancePerformance.anticipationAt`). 0 = no imminent hit.
  final double bodyAnticipation;

  /// Audio position seconds — drives the scenery (it pauses/seeks with the
  /// track).
  final double backdropTimeSeconds;

  /// Clock for the ambient stage-light gel sweep. The live app passes a
  /// free-running wall clock (decoupled from the looping dance); offline
  /// renderers pass the audio position so a render is deterministic at a
  /// position.
  final double lightsTimeSeconds;

  /// Track tempo, which sets the gel-cycle period (`60 / bpm`).
  final double bpm;

  final double leadMouth;
  final double bgMouth;
  final MouthShape leadShape;
  final MouthShape bgShape;

  /// Last frame's published foot anchors (the lights track them, one frame
  /// lagged).
  final List<Offset> dancerAnchors;
  final ValueChanged<List<Offset>>? onDancerAnchors;

  /// The layered blue-hour scene (true) vs. the old single waterfront plate.
  final bool useNewBackdrop;

  final bool showCaptions;
  final List<DanceWord> words;

  /// Colour grade applied to the painted backdrop (the ADR 0002 `backdrop`
  /// node — the pre-timeline behaviour). Identity by default (no grade).
  final BackdropGrade grade;

  /// Finishing grade over the whole stage — backdrop, haze, light pools AND
  /// the cats (the `master` node). Grain and captions composite after it, so
  /// film texture never pumps with an animated look. Identity by default.
  final BackdropGrade masterGrade;

  /// Grade for the trio alone (the `cast` node, premultiplied). Identity by
  /// default.
  final BackdropGrade castGrade;

  /// Whether grade nodes may use synchronous layer snapshots for exact shader
  /// grading. Kept off for live playback; enabled by export paths.
  final bool allowGradeSnapshots;

  /// Per-layer grades for the scenery's `GradedLayer` targets, forwarded to
  /// [LayeredBackdrop]. Null → no per-layer passes.
  final BackdropGrade? Function(String target)? gradeForTarget;

  final VoidCallback? onBackdropReady;

  /// Old-plate images (only used when [useNewBackdrop] is false).
  final ui.Image? backdropImage;
  final ui.Image? cloudsImage;
  final ui.Image? wavesImage;

  /// Key on the captured [RepaintBoundary] (offline renderers read its image).
  final Key? boundaryKey;

  @override
  Widget build(BuildContext context) {
    // One rig drives BOTH the per-cat rim/halo (memberBacklights) and the floor
    // pools, gel-cycling on the tempo, so a cat's glow always matches its pool.
    final rig = danceStageRig(bpm);
    final samples = useNewBackdrop
        ? rig.sample(time: lightsTimeSeconds, beat: beat, bloom: bodyAccent)
        : const <StageLightSample>[];
    final backlights = danceMemberBacklights(samples);

    return RepaintBoundary(
      key: boundaryKey,
      child: Center(
        // Lock the stage to 16:9 so the painted 2560x1440 art maps 1:1 and never
        // crops/distorts; the resizable window letterboxes around it.
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scale = danceCastScale(constraints.maxHeight);
              // The graded core of the stage, in ADR 0002's node order: any
              // per-layer passes run inside the backdrop's own painter, the
              // backdrop-composite pass wraps the painted world, the cast pass
              // wraps the trio, and the master pass wraps all of it. Grain
              // (SceneTextureOverlay) and captions composite AFTER master so
              // film texture and text never pump with an animated look.
              final gradedStage = GradeFilter(
                grade: masterGrade,
                repaintTick: lightsTimeSeconds,
                allowSnapshot: allowGradeSnapshots,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (useNewBackdrop)
                      // Clip the parallax-driven backdrop to the 16:9 stage so no
                      // plane breathes past the frame as the camera pushes in. The
                      // grain/lights overlays are screen-fixed to this same 16:9
                      // box, so without this a zoomed plane's edges (e.g. the side
                      // planters) could fall outside the grained region. Mirrors the
                      // offline composer's `clipRect(size)` around the backdrop. The
                      // parallax now lives PER LAYER (each plane lags by its depth),
                      // injected into the scene rather than one transform over all.
                      ClipRect(
                        child: LayeredBackdrop(
                          scene: BackdropScene.blueHourWaterfront(),
                          timeSeconds: backdropTimeSeconds,
                          beatPulse: beat,
                          grade: grade,
                          gradeForTarget: gradeForTarget,
                          allowGradeSnapshots: allowGradeSnapshots,
                          onReady: onBackdropReady,
                          parallaxForDepth: (depth, s) =>
                              CharacterPainter.danceParallaxMatrixForShotAtDepth(
                                shot: shot,
                                size: s,
                                depth: depth,
                              ),
                        ),
                      ),
                    // Aerial-perspective haze band at the waterline (frame-fixed,
                    // fades out above the dancers' feet so they stay crisp).
                    if (useNewBackdrop)
                      const DecoratedBox(
                        decoration: BoxDecoration(gradient: kDanceHazeGradient),
                        child: SizedBox.expand(),
                      ),
                    // Floor pools under the feet, grounding each cat in its gel.
                    // `energetic` fades the pools out during calm/idle
                    // sections (owner: "the lights on the floor with the
                    // gel should not be here yet") — see
                    // [StageLightsOverlay.energetic].
                    if (useNewBackdrop)
                      StageLightsOverlay(
                        timeSeconds: lightsTimeSeconds,
                        beat: beat,
                        dancerAnchors: dancerAnchors,
                        rig: rig,
                        energetic: stage.energetic,
                      ),
                    GradeFilter(
                      grade: castGrade,
                      premultiplied: true,
                      repaintTick: lightsTimeSeconds,
                      allowSnapshot: allowGradeSnapshots,
                      child: CustomPaint(
                        painter: danceCharacterPainter(
                          cast: cast,
                          renderer: renderer,
                          stage: stage,
                          shot: shot,
                          bodyAccent: bodyAccent,
                          bodyAnticipation: bodyAnticipation,
                          leadMouth: leadMouth,
                          bgMouth: bgMouth,
                          leadShape: leadShape,
                          bgShape: bgShape,
                          scale: scale,
                          backlights: backlights,
                          onDancerAnchors: onDancerAnchors,
                          useNewBackdrop: useNewBackdrop,
                          backdropImage: backdropImage,
                          cloudsImage: cloudsImage,
                          wavesImage: wavesImage,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    // The drop flash: a warm additive flare centred on the
                    // dancers that spikes on the music accent (biggest on the
                    // drops). Single-sourced with the offline composer via
                    // [paintDropBloom] so the two paint paths can't drift.
                    if (useNewBackdrop && bodyAccent > 0.01)
                      CustomPaint(
                        painter: DropBloomPainter(bodyAccent),
                        child: const SizedBox.expand(),
                      ),
                  ],
                ),
              );
              return Stack(
                fit: StackFit.expand,
                children: [
                  gradedStage,
                  // Film grain rides ABOVE the master pass (and now above the
                  // cats too — one grain pass over the finished frame, the
                  // finishing order a colourist expects).
                  if (useNewBackdrop) const SceneTextureOverlay(),
                  if (showCaptions && words.isNotEmpty)
                    Positioned(
                      left: 24,
                      right: 24,
                      top: 20,
                      child: Center(
                        child: DanceCaption(
                          words: words,
                          positionSeconds: backdropTimeSeconds,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The three dancers, built once. Rebuilding a rig is expensive, so a player or
/// renderer holds one [DanceCast] for its lifetime.
class DanceCast {
  DanceCast({required this.lead, required this.left, required this.right});

  /// The standard trio. Limb thickness is not hand-cast: each lane's rig is
  /// built from its staged PLANE scale (lead downstage at 1, flankers ~0.49)
  /// through [limbThicknessForPlaneScale], so upstage dancers thin out enough
  /// to keep the negative space that makes a small silhouette read.
  factory DanceCast.build() {
    final leadPlane = danceLanePlaneScale(1, 3);
    final flankThickness = limbThicknessForPlaneScale(
      danceLanePlaneScale(0, 3) / leadPlane,
    );
    return DanceCast(
      lead: CharacterScene(
        buildCatInSuitRig(),
        autonomic: danceAutonomic(11),
      ),
      left: CharacterScene(
        buildCatInSuitRig(
          palette: CatInSuitPalette.silverTabby,
          legWidthScale: flankThickness,
          armWidthScale: flankThickness,
        ),
        autonomic: danceAutonomic(29),
      ),
      right: CharacterScene(
        buildCatInSuitRig(
          palette: CatInSuitPalette.darkBrown,
          legWidthScale: flankThickness,
          armWidthScale: flankThickness,
        ),
        autonomic: danceAutonomic(47),
      ),
    );
  }

  final CharacterScene lead;
  final CharacterScene left;
  final CharacterScene right;
}

/// The autonomic (blink / eye-dart) layer used for every dancer — same cadence,
/// per-cat [seed].
AutonomicLayer danceAutonomic(int seed) => AutonomicLayer(
  seed: seed,
  blinkIntervalBase: 1.7,
  blinkIntervalJitter: 1.1,
  eyeDartInterval: 1.05,
  eyeDartAmplitude: 0.75,
);

/// The concert gel rig. The cycle period is the tempo (`60 / bpm`), so the gels
/// rotate one colour per beat; the lead lane is locked to the hero gold.
///
/// `baseIntensity` raised from [StageLightRig]'s class default (0.38 -> 0.75,
/// after an 0.58 first pass still read as "pretty grey when music starts" —
/// live owner feedback): at the default, the gel/rim only read as visible
/// colour near a beat peak — most of a bar sat close to the dark
/// plate-seat's shadow floor with no stage light showing at all (owner:
/// dancing "too dark and grey... there SHOULD be stage light"). Bumped so
/// the coloured key is always clearly present, with `beatBoost` still
/// layering a real punch on top on the beat.
StageLightRig danceStageRig(double bpm) => StageLightRig(
  colorPeriod: bpm > 0 ? 60 / bpm : 0.5,
  leadGoldIndex: 1,
  baseIntensity: 0.75,
);

/// Per-cat rim/halo colours from the rig [samples]: screen order
/// (left→center→right), the centre (lead) hotter so the hero owns the frame.
List<Color> danceMemberBacklights(List<StageLightSample> samples) => [
  for (final (i, s) in samples.indexed)
    s.color.withValues(
      alpha: (s.intensity * kDanceHeroWeight[i % kDanceHeroWeight.length])
          .clamp(0.0, 1.0),
    ),
];

/// Rim-halo weight per screen lane (centre lead hotter, flankers near full).
const List<double> kDanceHeroWeight = [0.9, 1.1, 0.9];

/// Sizes the cast to the stage height (the painter scales uniformly). At the
/// authored ~300-unit body height, 0.78 lands the feet on the painted deck.
double danceCastScale(double stageHeight) => stageHeight * 0.78 / 300.0;

/// The waterline haze gradient (a soft cool veil that separates the foreground
/// cat plane from the distant city/water; fades out above the feet).
const LinearGradient kDanceHazeGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0x005E7088),
    Color(0x005E7088),
    Color(0x2C5E7088),
    Color(0x185E7088),
    Color(0x005E7088),
  ],
  stops: [0.0, 0.40, 0.52, 0.64, 0.76],
);

/// Builds the trio compositor for one frame — the single `CharacterPainter`
/// wiring used by BOTH the live [DanceStageView] and the offline
/// `DanceFrameComposer`, so the ~20-argument painter can't be hand-synced out of
/// step (add a staging param here and both paths pick it up).
///
/// [useNewBackdrop] false selects the legacy single-plate path (the painter
/// draws the waterfront plate + a grey floor band); the offline renderers always
/// use the new layered scene and leave the plate images null.
CharacterPainter danceCharacterPainter({
  required DanceCast cast,
  required CharacterRenderer renderer,
  required DanceStage stage,
  required Shot shot,
  required double leadMouth,
  required double bgMouth,
  required MouthShape leadShape,
  required MouthShape bgShape,
  required double scale,
  required List<Color> backlights,
  ValueChanged<List<Offset>>? onDancerAnchors,
  bool useNewBackdrop = true,
  ui.Image? backdropImage,
  ui.Image? cloudsImage,
  ui.Image? wavesImage,
  double bodyAccent = 0,
  double bodyAnticipation = 0,
}) => CharacterPainter(
  scene: cast.lead,
  partnerScene: cast.left,
  ensembleScenes: [cast.left, cast.right],
  ensembleExpressions: [
    danceSingExpression(leadMouth, Expression.neutral, leadShape),
    danceSingExpression(bgMouth, Expression.content, bgShape),
    danceSingExpression(bgMouth, Expression.happy, bgShape),
  ],
  ensembleClips: [
    for (var i = 0; i < stage.ensemble.length; i++)
      accentDroppedClip(
        productionDanceClip(
          stage.ensemble[i],
          stage.dynamics[i],
          i,
          stage.energyLevel,
        ),
        _bodyLoadEnvelope(
              stage.lead.belongsToFamily('moving') ? 0 : bodyAccent,
              stage.lead.belongsToFamily('moving') ? 0 : bodyAnticipation,
            ) *
            kDanceAccentDropUnits,
      ),
  ],
  synchronousEnsemble: stage.synchronous,
  singingHeadMotion: true,
  walkingPair: true,
  clip: accentDroppedClip(
    productionDanceClip(
      stage.lead,
      stage.dynamics.first,
      0,
      stage.energyLevel,
    ),
    _bodyLoadEnvelope(
          stage.lead.belongsToFamily('moving') ? 0 : bodyAccent,
          stage.lead.belongsToFamily('moving') ? 0 : bodyAnticipation,
        ) *
        kDanceAccentDropUnits,
  ),
  timeSeconds: stage.seconds,
  cameraOverride: shot,
  onDancerAnchors: useNewBackdrop ? onDancerAnchors : null,
  scale: scale,
  // The music accent also reaches the painter itself (not just the plié-drop
  // clip above): it drives the UNISON formation pop — the whole ensemble
  // surging bigger together on the track's strong transients (see
  // `CharacterPainter._kUnisonFormationPop`). Single-sourced here so the live
  // player and every offline renderer pop identically. Its look-ahead partner
  // [bodyAnticipation] drives the coil that precedes the pop.
  // Moving's arm hook has its own lyric clock over an independent lower-body
  // groove. Suppress the generic unison spring/coil so the formation does not
  // appear to tug the phrase around at every music onset.
  bodyAccent: stage.lead.belongsToFamily('moving') ? 0 : bodyAccent,
  bodyAnticipation: stage.lead.belongsToFamily('moving') ? 0 : bodyAnticipation,
  groundColor: useNewBackdrop ? null : const Color(0xFF374551),
  backdrop: useNewBackdrop
      ? CharacterBackdrop.none
      : CharacterBackdrop.waterfront,
  backdropImage: useNewBackdrop ? null : backdropImage,
  backdropCloudsImage: useNewBackdrop ? null : cloudsImage,
  backdropWavesImage: useNewBackdrop ? null : wavesImage,
  memberBacklights: backlights,
  // Surface grade removed (owner: the cats' surfaces read too washed out from
  // the sky/deck wrap tint — "get rid of the grading of the cats' surfaces...
  // I can live with more separation with the background"). bodyGrade defaults
  // to null (no wrap); the rim halo (memberBacklights, above) is separate and
  // stays.
  heroStaging: useNewBackdrop,
  // danceViewProjection intentionally stays at the painter default (false):
  // front-lock the shipped trio while the arm/shoulder mesh is being rebuilt.
  // The projection review path still exists for explicit strips, but the app
  // should not add quarter-turn distortion during limb-attachment review.
  renderer: renderer,
);

/// Joins the look-ahead coil to the post-onset release for the BODY'S vertical
/// load. Both envelopes are smooth at their endpoints and trade ownership at
/// the onset, so the knees compress into the beat continuously. The lights and
/// formation pop still receive [bodyAccent] and [bodyAnticipation] separately:
/// they retain their crisp gather->release contrast while the skeleton carries
/// believable mass instead of teleporting down on the hit frame.
double _bodyLoadEnvelope(double bodyAccent, double bodyAnticipation) =>
    bodyAccent >= bodyAnticipation ? bodyAccent : bodyAnticipation;

/// Per-clip-instance cache of [upperBodyDynamicsWarpedClip] results, keyed by
/// the effective dynamics that produced them. This is the single call site
/// both the live player and every offline renderer go through, so it is the
/// one place that needs to build the warped clip at all — `CharacterPainter`,
/// `CharacterScene`, and `ClipEvaluator` are untouched; the warp travels
/// entirely inside the channels a warped `Clip` carries.
///
/// At steady state (a static catalog clip, a per-section-constant effective
/// dynamics) this builds each warped clip once and reuses it every frame; only
/// transitions — whose blended clip is already a fresh instance per frame —
/// pay the wrapper allocation, on top of the `blendedClip` work they already do.
final Expando<Map<(DanceDynamics, int, double), Clip>> _warpCache = Expando();

/// Moving phrases whose authored loop restart was visually observed as an arm
/// teleport in the production performance. Their position seams are closed,
/// but their opposing end/start tangents need the localized recovery below.
/// Other Moving phrases retain their authored clock: broad application pushed
/// BridgeRock/ChorusTravel catch-up into intentional accents.
const Set<String> _movingUpperBodySeamEasedClips = {
  'movingVerseWindow',
};

/// The exact per-lane clip transformation used by both the live stage and the
/// offline exporter.
///
/// Kept public so production-level motion audits can measure the same clip the
/// painter consumes after effort, energy, and shoulder-wind modulation. Tests
/// that inspect an unwarped catalogue clip are useful rig checks, but cannot
/// prove that the scheduled/exported performance itself stays continuous.
Clip productionDanceClip(
  Clip clip,
  DanceDynamics dynamics,
  int lane,
  double energyLevel,
) {
  final cache = _warpCache[clip] ??= {};
  // energyLevel is per-section-constant, so this stays a small keyed cache.
  return cache[(dynamics, lane, energyLevel)] ??= () {
    final transition = clip.transitionPlan;
    final songGroove = clip.belongsToFamily('moving');
    // 1. Effort TIME warp (unchanged): reshapes the beat timing by dynamics.
    // The Moving phrase already authors long multi-beat arm arcs. Re-syncing
    // their clock independently inside every beat puts tiny hinges into those
    // arcs, so this move keeps its authored clock; its body still reacts to
    // song energy and its shoulders still carry per-lane wind below.
    final warped =
        (songGroove || dynamics.isNeutral || kDanceDynamicsTimeWarpGain == 0)
        ? clip
        : upperBodyDynamicsWarpedClip(
            clip,
            dynamics,
            warpBoneIds: kDanceUpperBodyWarpBoneIds,
          );
    // 2. FAST-BASE orbit: a small continuous per-lane hand roll layered on the
    // authored motion, so every move's hands always carry fast sub-beat motion
    // (not just posed hits), the two hands counter-rotating around each other.
    // "Moving" owns broad sustained arm events. The catalogue-wide fast orbit
    // makes its wrists buzz independently of those events (and swings its
    // hand-parented cuffs), so disable the generic garnish for this move.
    final seamEased =
        songGroove && _movingUpperBodySeamEasedClips.contains(warped.name)
        ? upperBodyLoopSeamEasedClip(
            warped,
            upperBodyBoneIds: kDanceUpperBodyWarpBoneIds,
          )
        : warped;
    final orbited = fastBaseOrbitedClip(
      seamEased,
      lane,
      radius: songGroove ? 0 : kDanceFastBaseOrbitRadius,
    );
    // 3. Effort AMPLITUDE modulation: scales how BIG the hand moves get (base +
    // orbit) by the raw SONG ENERGY arc + a deterministic beat-to-beat breath,
    // leaving the fast timing intact — so a low-energy pass is fast-but-small
    // and never 100%-extreme every beat.
    final effort = songGroove
        ? orbited
        : effortModulatedClip(
            orbited,
            danceEffortScaleOf(energyLevel, lane),
          );
    // 4. WHOLE-BODY groove amplitude: scale the root sway/bob/dips by the song
    // energy too (not just the hands), so the whole body eases through the
    // breakdown and fills into the chorus — mean-preserving so the stance stays.
    final grooved = bodyGrooveScaledClip(
      effort,
      danceBodyGrooveScaleOf(energyLevel),
    );
    // 5. CREW MICROTIMING: the backups anticipate/drag by a few tens of
    // milliseconds in their upper bodies only. Feet, root, and support changes
    // stay on the shared clock, so the formation lands together without the
    // machine-perfect simultaneous arm reversals of a cloned timeline.
    final microTimed = songGroove
        ? upperBodyPhaseOffsetClip(
            grooved,
            kDanceLaneUpperBodyPhaseOffsets[lane] *
                _movingTransitionOwnership(transition),
            upperBodyBoneIds: kDanceUpperBodyWarpBoneIds,
          )
        : grooved;
    // 6. Continuous shoulder/chest WIND: the upper body keeps rolling so it is
    // never a static posed post while the hips bounce (the pocket is upper-
    // body-led — coach).
    final wound = shoulderWoundClip(microTimed, lane);
    if (transition == null) return wound;

    // Scene-level transition consumers (support balance, contact locking,
    // world anchors, z-order) evaluate `transitionPlan.from/to` directly.
    // Decorating only the temporary blended clip left those metadata sources
    // raw, so the last blended frame converged on an undecorated foot/root
    // while the next frame sampled the decorated destination. Full-song
    // production probes measured the resulting wrapper-boundary jumps at
    // 85.47s and 137.87s. Carry the exact same production decoration into the
    // plan's two semantic sources while preserving the already-mixed channels.
    return _clipWithTransitionPlan(
      wound,
      ClipTransitionPlan(
        from: productionDanceClip(
          transition.from,
          dynamics,
          lane,
          energyLevel,
        ),
        to: productionDanceClip(
          transition.to,
          dynamics,
          lane,
          energyLevel,
        ),
        weight: transition.weight,
        fromTimeShiftSeconds: transition.fromTimeShiftSeconds,
      ),
    );
  }();
}

/// Fraction of a transition pose semantically owned by Moving.
///
/// `Clip.belongsToFamily` deliberately returns true when either side belongs to
/// the family, which is right for selecting the production treatment but too
/// coarse for a phase offset: applying the full lane offset to a rest→Moving
/// wrapper shifts the outgoing idle arms even at blend weight zero. Ramp that
/// time offset with the same eased ownership as the pose.
double _movingTransitionOwnership(ClipTransitionPlan? transition) {
  if (transition == null) return 1;
  final fromMoving = transition.from.belongsToFamily('moving');
  final toMoving = transition.to.belongsToFamily('moving');
  if (fromMoving == toMoving) return fromMoving ? 1 : 0;
  final incoming = transition.weight;
  return toMoving ? incoming : 1 - incoming;
}

Clip _clipWithTransitionPlan(Clip clip, ClipTransitionPlan transitionPlan) =>
    Clip(
      name: clip.name,
      family: clip.family,
      duration: clip.duration,
      channels: clip.channels,
      loop: clip.loop,
      root: clip.root,
      locomotionSpeed: clip.locomotionSpeed,
      groundSpans: clip.groundSpans,
      contactSpans: clip.contactSpans,
      contactPinning: clip.contactPinning,
      limbTargets: clip.limbTargets,
      supportFootWorldAnchor: clip.supportFootWorldAnchor,
      supportFootWorldAnchorStrength: clip.supportFootWorldAnchorStrength,
      supportFootWorldAnchorVerticalBoost:
          clip.supportFootWorldAnchorVerticalBoost,
      danceHeadBobScale: clip.danceHeadBobScale,
      danceHeadLevelClampMin: clip.danceHeadLevelClampMin,
      armReachScale: clip.armReachScale,
      headLateralStabilize: clip.headLateralStabilize,
      enforceSoleFloor: clip.enforceSoleFloor,
      transitionPlan: transitionPlan,
      zOrderSwaps: clip.zOrderSwaps,
      dynamics: clip.dynamics,
    );

/// The karaoke caption: a short window of lyric words centred on the current
/// one (highlighted). Empty when no word is active. Shared by the live player
/// and the offline renderers so the caption can't drift.
class DanceCaption extends StatelessWidget {
  const DanceCaption({
    required this.words,
    required this.positionSeconds,
    super.key,
  });

  final List<DanceWord> words;
  final double positionSeconds;

  /// Backdrop alpha, corner radius and text insets for the caption box. Shared
  /// by this widget and the offline canvas caption so the two cannot drift.
  static const double backdropAlpha = 0.45;
  static const double cornerRadius = 10;
  static const double insetH = 16;
  static const double insetV = 8;

  /// Index of the lyric word to caption: the most recent word that has started,
  /// hidden during instrumental gaps (>2 s after the last word ended).
  static int? captionWordIndex(List<DanceWord> words, double pos) {
    int? recent;
    for (var i = 0; i < words.length; i++) {
      if (words[i].start <= pos) {
        recent = i;
      } else {
        break;
      }
    }
    if (recent == null) return null;
    if (pos - words[recent].end > 2.0) return null;
    return recent;
  }

  /// The inclusive-from / exclusive-to window of words shown around the [active]
  /// word in a list of [length] (a few before, a few after).
  static ({int from, int to}) captionWindow(int active, int length) => (
    from: active - 3 < 0 ? 0 : active - 3,
    to: active + 4 > length ? length : active + 4,
  );

  /// The per-word style: the current word is brighter, larger and bolder.
  static TextStyle captionWordStyle({required bool active}) => TextStyle(
    color: active ? Colors.white : Colors.white54,
    fontSize: active ? 26 : 21,
    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
    height: 1.2,
  );

  @override
  Widget build(BuildContext context) {
    final i = captionWordIndex(words, positionSeconds);
    if (i == null) return const SizedBox.shrink();
    final window = captionWindow(i, words.length);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: backdropAlpha),
        borderRadius: BorderRadius.circular(cornerRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: insetH,
          vertical: insetV,
        ),
        child: RichText(
          text: TextSpan(
            children: [
              for (var j = window.from; j < window.to; j++)
                TextSpan(
                  text: '${words[j].word} ',
                  style: captionWordStyle(active: j == i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
