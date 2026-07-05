import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dancing_cats/features/scenery/layers/backdrop_layer.dart';
import 'package:dancing_cats/features/scenery/layers/drone_text_glyphs.dart';
import 'package:dancing_cats/features/scenery/runtime/scenery_glow.dart';
import 'package:dancing_cats/features/scenery/runtime/scenery_math.dart';

/// First text held by the drone formation.
const String kDroneShowOpeningText = 'Omah Lay';

/// Final text shown by the drone formation.
const String kDroneShowFinalText = 'Moving';

/// Number of light points in the deterministic show.
const int kDroneShowDroneCount = 280;

/// Length of one complete drone-show loop.
///
/// This is intentionally song-scale rather than particle-scale: the aircraft
/// spend tens of seconds climbing from the bridge before they hold readable sky
/// text. That keeps the implied vertical and lateral speeds in the range of a
/// real light-show drone instead of a firework.
const double kDroneShowCycleSeconds = 144;

// Phase boundaries as fractions of the 0..1 loop, in order: the formation
// launches until 0.22, converges into the beam until 0.38, fans out until 0.58,
// then holds text for the remainder. The other fractions stage the text morph
// (opening settle, the staging-hold and the text-transition window) and the
// reduced-motion freeze frame.
const double _launchEnd = 0.22;
const double _beamEnd = 0.38;
const double _fanEnd = 0.58;
const double _launchHoldProgress = 0.14;
const double _openingSettleEnd = 0.16;
const double _textTransitionStart = 0.44;
const double _stagingHoldStart = 0.56;
const double _stagingHoldEnd = 0.62;
const double _textTransitionEnd = 0.74;
const double _reducedMotionCycleProgress = 0.9;
const double _bridgeClearY = 0.36;
const int _ascentSpiralCount = 5;
// The launch is aligned to the police cordon's span on the bridge deck
// (BridgePoliceLayer's roadway, x ≈ 0.555→0.745): the drones stage on exactly
// the stretch of road the police have cleared, so the line of unlit aircraft
// reads as "drones on the closed road" instead of a stray dark bar poking out
// to the left of the cordon. The row sits at road level just behind the
// deck's railing-top edge (railing ≈ y 0.4646 on the 2026-07 plate), level
// with the cordon's light bars.
//
// It splits into TWO bases rather than one continuous line: a single line
// across the full cordon span passed directly under the cable-stayed
// pylon's fanned cables (measured on the shipped plate at x ≈ 0.60–0.705,
// centred almost exactly on the cordon's midpoint) — drones launching
// through rigging that would physically block their ascent. Each base
// occupies one outer end of the cordon, clearing the cable fan with a
// buffer on both sides; the rise→beam transit (already a per-drone lerp
// keyed on the same `u`) then converges the two columns into the single
// beam well above the bridge, with no other change needed to "unite" them.
const double kDroneLaunchStartX = 0.555;
const double kDroneLaunchEndX = 0.745;
const double kDroneLaunchGapStartX = 0.595;
const double kDroneLaunchGapEndX = 0.705;
const double _launchBaseY = 0.4698;
const double _launchSlopeY = 0.002;
const double _ascentSpiralXRadius = 0.014;
const double _ascentSpiralYRadius = 0.011;
const double _ascentSpiralStretchY = 0.024;

/// The cable-stayed pylon's crest, safely above BOTH mast tips
/// (`bridgeTowerTops` y ≈ 0.3542/0.3590 on the 2026-07 plate): the ascent's
/// lateral re-union (see [_launchPhasePoint]) is gated to only begin once a
/// drone's y is already above this line, so the two launch bases never
/// converge while still level with — and so visually crossing behind — the
/// tower or its cables.
const double _pylonCrestY = 0.352;

/// Coarse segment in the repeatable drone-show choreography.
enum DroneShowPhase { launch, beam, fan, formation }

/// One timeline sample for the current loop.
class DroneShowTimeline {
  const DroneShowTimeline({
    required this.phase,
    required this.progress,
    required this.cycleProgress,
  });

  /// Active show segment.
  final DroneShowPhase phase;

  /// Normalized 0..1 progress inside [phase].
  final double progress;

  /// Normalized 0..1 progress inside the full loop.
  final double cycleProgress;
}

/// One sampled drone light in normalized backdrop coordinates.
class DroneShowSample {
  const DroneShowSample({
    required this.position,
    required this.opacity,
    required this.radius,
    required this.phase,
    required this.isLit,
  });

  final ui.Offset position;
  final double opacity;
  final double radius;
  final DroneShowPhase phase;
  final bool isLit;
}

/// Additive drone-show layer for the blue-hour sky.
///
/// Drones launch from a tight, evenly spaced bridge-road line, rise vertically
/// before converging into an ascending beam, fan outward, hold
/// [kDroneShowOpeningText], then morph through a staging row into
/// [kDroneShowFinalText].
/// The layer is stateless and deterministic from [BackdropContext.timeSeconds].
class DroneShowLayer implements BackdropLayer {
  const DroneShowLayer({
    this.droneCount = kDroneShowDroneCount,
    this.cycleSeconds = kDroneShowCycleSeconds,
    this.visiblePhases = const {
      DroneShowPhase.launch,
      DroneShowPhase.beam,
      DroneShowPhase.fan,
      DroneShowPhase.formation,
    },
  });

  const DroneShowLayer.sky({
    this.droneCount = kDroneShowDroneCount,
    this.cycleSeconds = kDroneShowCycleSeconds,
  }) : visiblePhases = const {
         DroneShowPhase.beam,
         DroneShowPhase.fan,
         DroneShowPhase.formation,
       };

  const DroneShowLayer.launchRoad({
    this.droneCount = kDroneShowDroneCount,
    this.cycleSeconds = kDroneShowCycleSeconds,
  }) : visiblePhases = const {DroneShowPhase.launch};

  final int droneCount;
  final double cycleSeconds;
  final Set<DroneShowPhase> visiblePhases;

  @override
  void paint(ui.Canvas canvas, BackdropContext ctx) {
    final samples = sampleDroneShow(
      ctx.reducedMotion
          ? cycleSeconds * _reducedMotionCycleProgress
          : ctx.timeSeconds,
      reducedMotion: ctx.reducedMotion,
      count: droneCount,
      cycleSeconds: cycleSeconds,
    );
    if (samples.isEmpty || !visiblePhases.contains(samples.first.phase)) {
      return;
    }

    final shortestSide = math.min(ctx.size.width, ctx.size.height);
    final haloPaint = ui.Paint()..blendMode = ui.BlendMode.plus;
    final corePaint = ui.Paint()..blendMode = ui.BlendMode.plus;
    // Unlit drones are distant dark bodies seen THROUGH the blue-hour haze, so
    // they must not read as pure-black holes punched in the twilight sky —
    // aerial perspective lifts and cools a far dark object toward the
    // atmosphere. Lift the near-black body most of the way to the shadowed cloud
    // tone and drop the alpha, so they read as faint hazed specks before their
    // lights switch on.
    final offPaint = ui.Paint()
      ..color = ui.Color.lerp(
        const ui.Color(0xFF0A1020),
        ctx.palette.cloudBase,
        0.6,
      )!.withValues(alpha: 0.5);
    final cool = ctx.palette.moonHalo;
    final warm = ctx.palette.windowLed;

    for (final sample in samples) {
      final c = ui.Offset(
        sample.position.dx * ctx.size.width,
        sample.position.dy * ctx.size.height,
      );
      final radius = shortestSide * sample.radius;
      final alpha = sample.opacity.clamp(0.0, 1.0);
      if (!sample.isLit) {
        canvas.drawCircle(c, radius, offPaint);
        continue;
      }

      final color = ui.Color.lerp(cool, warm, hashUnit(c.dx.toInt()))!;
      paintGlowPointLight(
        canvas,
        center: c,
        color: color,
        haloRadius: radius * 4.5,
        haloInnerAlpha: 0.16 * alpha,
        haloMidAlpha: 0.04 * alpha,
        haloMidStop: 0.45,
        coreRadius: radius,
        coreColor: ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.55)!,
        coreAlpha: 0.82 * alpha,
        haloPaint: haloPaint,
        corePaint: corePaint,
      );
    }
  }
}

/// Resolves the repeatable choreography phase for [timeSeconds].
DroneShowTimeline droneShowTimelineAt(
  double timeSeconds, {
  double cycleSeconds = kDroneShowCycleSeconds,
}) {
  final safeCycle = cycleSeconds <= 0 ? kDroneShowCycleSeconds : cycleSeconds;
  final cycleProgress = fract(timeSeconds / safeCycle);
  if (cycleProgress < _launchEnd) {
    return DroneShowTimeline(
      phase: DroneShowPhase.launch,
      progress: cycleProgress / _launchEnd,
      cycleProgress: cycleProgress,
    );
  }
  if (cycleProgress < _beamEnd) {
    return DroneShowTimeline(
      phase: DroneShowPhase.beam,
      progress: (cycleProgress - _launchEnd) / (_beamEnd - _launchEnd),
      cycleProgress: cycleProgress,
    );
  }
  if (cycleProgress < _fanEnd) {
    return DroneShowTimeline(
      phase: DroneShowPhase.fan,
      progress: (cycleProgress - _beamEnd) / (_fanEnd - _beamEnd),
      cycleProgress: cycleProgress,
    );
  }
  return DroneShowTimeline(
    phase: DroneShowPhase.formation,
    progress: (cycleProgress - _fanEnd) / (1 - _fanEnd),
    cycleProgress: cycleProgress,
  );
}

/// Generates normalized destination points for a drone-show text label.
List<ui.Offset> droneShowFormationPoints({
  int count = kDroneShowDroneCount,
  String text = kDroneShowOpeningText,
}) {
  if (count <= 0) return const [];
  final cells = textDotCells(text);
  return List<ui.Offset>.generate(count, (i) {
    final cellIndex = (i * cells.length) ~/ count;
    final cell = cells[math.min(cellIndex, cells.length - 1)];
    final angle = hashUnit(i + 211) * math.pi * 2;
    final radius = math.sqrt(hashUnit(i + 307)) * 0.08;
    return cell.center.translate(
      math.cos(angle) * cell.width * radius,
      math.sin(angle) * cell.height * radius,
    );
  }, growable: false);
}

/// Deterministically samples all drone lights for a frame.
List<DroneShowSample> sampleDroneShow(
  double timeSeconds, {
  bool reducedMotion = false,
  int count = kDroneShowDroneCount,
  double cycleSeconds = kDroneShowCycleSeconds,
}) {
  if (count <= 0) return const [];
  final safeCycle = cycleSeconds <= 0 ? kDroneShowCycleSeconds : cycleSeconds;
  final timeline = droneShowTimelineAt(
    reducedMotion ? safeCycle * _reducedMotionCycleProgress : timeSeconds,
    cycleSeconds: safeCycle,
  );
  final openingFormation = droneShowFormationPoints(count: count);
  final finalFormation = droneShowFormationPoints(
    count: count,
    text: kDroneShowFinalText,
  );
  return List<DroneShowSample>.generate(count, (i) {
    final t = smoothstep(timeline.progress);
    final launch = _launchPoint(i, count);
    final rise = _risePoint(i, count);
    final beam = _beamPoint(i, count);
    final fan = _fanPoint(i, count);
    final position = switch (timeline.phase) {
      DroneShowPhase.launch => _launchPhasePoint(
        i,
        count,
        launch,
        rise,
        timeline.progress,
      ),
      // The rise→beam transit BOWS upward: a straight lerp strung the drones
      // across the middle sky exactly where the lead singer's crown sits in
      // the tight chorus framings (the mid-transit string crossed the ear
      // line right on the chorus-2 drop). The bow keeps the endpoints (and so
      // the phase hand-offs) untouched while the travelling string arcs
      // through open sky above the head band. The transit rides a
      // constant-cruise profile rather than a smoothstep: the beam stands
      // further from the launch pads now, and a smoothstep's mid-phase speed
      // peak would push the drones past the one-second travel budget.
      DroneShowPhase.beam => () {
        final cruise = _easedTravel(timeline.progress);
        return ui.Offset.lerp(rise, beam, cruise)! -
            ui.Offset(0, 0.06 * math.sin(cruise * math.pi));
      }(),
      DroneShowPhase.fan => ui.Offset.lerp(beam, fan, t)!,
      DroneShowPhase.formation => _formationPoint(
        i,
        count,
        fan,
        openingFormation[i],
        finalFormation[i],
        timeline.progress,
      ),
    };
    final twinkle = reducedMotion
        ? 0.0
        : 0.045 * math.sin(timeSeconds * 1.35 + i * 0.42 + hashUnit(i) * 2);
    final coordinated = timeline.phase == DroneShowPhase.launch;
    final formation = timeline.phase == DroneShowPhase.formation;
    final isLit = _isDroneLit(i, position, timeline.phase);
    final litOpacity = (coordinated ? 0.86 : 0.74 + twinkle).clamp(0.0, 1.0);
    final litRadius = coordinated || formation
        ? 0.00255
        : 0.0020 + hashUnit(i + 17) * 0.0009;
    return DroneShowSample(
      position: position,
      opacity: isLit ? litOpacity : 0.64,
      radius: isLit ? litRadius : 0.00185,
      phase: timeline.phase,
      isLit: isLit,
    );
  }, growable: false);
}

bool _isDroneLit(int index, ui.Offset position, DroneShowPhase phase) {
  if (phase != DroneShowPhase.launch) return true;
  final threshold = _bridgeClearY + (hashUnit(index + 131) - 0.5) * 0.016;
  return position.dy <= threshold;
}

/// Maps a drone's global progress [u] (0..1) to its launch-base x: the first
/// half of the population (u < 0.5) stages on the LEFT base, the rest on the
/// RIGHT — the two bases bracket the cable-stayed pylon's fanned cables (see
/// [kDroneLaunchGapStartX]/[kDroneLaunchGapEndX]) instead of one line running under them.
double _launchX(double u) {
  if (u < 0.5) {
    return kDroneLaunchStartX + (u / 0.5) * (kDroneLaunchGapStartX - kDroneLaunchStartX);
  }
  final local = (u - 0.5) / 0.5;
  return kDroneLaunchGapEndX + local * (kDroneLaunchEndX - kDroneLaunchGapEndX);
}

ui.Offset _launchPoint(int index, int count) {
  final u = count <= 1 ? 0.5 : index / (count - 1);
  final x = _launchX(u);
  final y = _launchBaseY + (u - 0.5) * _launchSlopeY;
  return ui.Offset(x, y);
}

ui.Offset _launchPhasePoint(
  int index,
  int count,
  ui.Offset launch,
  ui.Offset rise,
  double progress,
) {
  if (progress < _launchHoldProgress) return launch;
  final rawClimb = (progress - _launchHoldProgress) / (1 - _launchHoldProgress);
  final climb = smoothstep(rawClimb);
  // Y always eases from launch to rise on `climb`, but X is GATED: it holds
  // at the launch base's x (a pure vertical climb, still split left/right)
  // until the drone has actually cleared the pylon's crest height, then
  // eases across to the unified rise x over the remaining climb. Lerping X
  // and Y together on the same `climb` (as before the two-base split) drew a
  // straight diagonal from the split base toward the unified column — at the
  // pylon's own height (still well below the crest) that diagonal cut
  // directly across its shaft/cables, the exact overlap this whole change
  // exists to avoid. Uniting only ABOVE the crest keeps the ascent honest:
  // straight up past the tower, then a clean lateral join in open sky.
  final crestClimb = ((_pylonCrestY - launch.dy) / (rise.dy - launch.dy))
      .clamp(0.0, 1.0);
  // `_easedTravel` (constant-velocity core, ~1.2x average peak) rather than a
  // plain smoothstep (~1.5x average peak): the merge only has a short climb
  // window to cover a real lateral distance, and a peaked profile pushed the
  // instantaneous speed past the "still reads as a dolly, not a particle"
  // budget the whole show is held to.
  final lateralT = climb <= crestClimb
      ? 0.0
      : _easedTravel((climb - crestClimb) / (1 - crestClimb));
  final base = ui.Offset(
    ui.lerpDouble(launch.dx, rise.dx, lateralT)!,
    ui.lerpDouble(launch.dy, rise.dy, climb)!,
  );
  final envelope = math.sin(climb * math.pi).clamp(0.0, 1.0);
  if (envelope == 0) return base;

  final u = count <= 1 ? 0.5 : index / (count - 1);
  // The spiral pods are computed per-BASE (on the drone's local progress
  // within its own launch base) rather than across the full global `u`: a
  // global 5-way split would give one pod straddling u=0.5 — half its
  // drones on each base, spiralling through the cable gap between them.
  final inLeftBase = u < 0.5;
  final baseLocalU = inLeftBase ? u / 0.5 : (u - 0.5) / 0.5;
  final pod = math.min(
    (baseLocalU * _ascentSpiralCount).floor(),
    _ascentSpiralCount - 1,
  );
  final podStart = pod / _ascentSpiralCount;
  final localU = ((baseLocalU - podStart) * _ascentSpiralCount).clamp(
    0.0,
    1.0,
  );
  final baseStartX = inLeftBase ? kDroneLaunchStartX : kDroneLaunchGapEndX;
  final baseEndX = inLeftBase ? kDroneLaunchGapStartX : kDroneLaunchEndX;
  final podCenterX =
      baseStartX + (pod + 0.5) / _ascentSpiralCount * (baseEndX - baseStartX);
  final columned = ui.Offset.lerp(
    base,
    ui.Offset(podCenterX, base.dy),
    envelope * 0.36,
  )!;
  final angle = localU * math.pi * 2 + pod * 0.72 + climb * math.pi * 2.7;
  final stretchY = (localU - 0.5) * _ascentSpiralStretchY * envelope * climb;
  return ui.Offset(
    columned.dx +
        math.cos(angle) *
            _ascentSpiralXRadius *
            envelope *
            (0.72 + climb * 0.28),
    columned.dy + math.sin(angle) * _ascentSpiralYRadius * envelope + stretchY,
  );
}

/// How far the ascent's crest-gated join (see [_launchPhasePoint]) closes the
/// gap between a launch base and the final beam column before handing the
/// rest to the beam phase's own transit. 1.0 (fully joined right at the
/// crest) demands covering the LEFT base's ~0.12 lateral distance inside the
/// short climb window above the crest, which only fits at particle-fast
/// speeds — the "still reads as a dolly" budget the whole show is held to.
/// At 0.72 the two streams are already tight and clearly converging (not two
/// columns either side of a wide gap) by the time they clear the tower,
/// while lighting up; the beam phase — already well above the bridge, no
/// structure left to cross behind — closes the small remaining gap into the
/// single-file beam.
const double _riseJoinFraction = 0.72;

ui.Offset _risePoint(int index, int count) {
  final u = count <= 1 ? 0.5 : index / (count - 1);
  final partial = ui.lerpDouble(_launchX(u), _beamX(u), _riseJoinFraction)!;
  // y sits well above [_pylonCrestY] (both mast tips are 0.354–0.359) rather
  // than just above it, leaving real room for the lateral join.
  return ui.Offset(partial, 0.30 - u * 0.016);
}

/// Position curve 0..1 with smoothstep-eased edges around a constant-velocity
/// core — same distance as a plain smoothstep but with a ~1.2x mid-phase speed
/// peak instead of 1.5x, keeping long transits inside the per-second travel
/// budget that stops drones reading as particles.
double _easedTravel(double p) {
  const edge = 0.2;
  final t = p.clamp(0.0, 1.0);
  double rampArea(double x) => x * x * x - x * x * x * x / 2;
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

/// The narrow "lightsaber" column's x for progress [u] — shared by
/// [_risePoint] (where the two launch bases already reunite, dark, right
/// above the bridge crown) and [_beamPoint] (which only extends it further
/// up). Moved OFF the lead singer's screen axis (was x 0.61 ≈ dead on the
/// lead in the centred and left-leaning framings): the beam's lower half
/// used to cross the lead's ear line through the WHOLE chorus-2 approach (z
/// 1.38–1.47 sweeps the crown up through the band), a bright rod through the
/// star's head on the biggest drop of the piece. At x ~0.70 it stands over
/// the water between the trio and the yacht, reading as a counterweight
/// instead of a crown hazard.
double _beamX(double u) => 0.70 + (u - 0.5) * 0.04;

ui.Offset _beamPoint(int index, int count) {
  final u = count <= 1 ? 0.5 : index / (count - 1);
  return ui.Offset(_beamX(u), 0.255 - u * 0.10);
}

ui.Offset _fanPoint(int index, int count) {
  final u = count <= 1 ? 0.5 : index / (count - 1);
  // Deterministic per-drone "band" in 0..1 (a cheap `(index*7) mod 11` hash) that
  // scatters drones across the fan's depth so it reads as a cloud, not a line.
  final band = ((index * 7) % 11) / 10;
  final crown = -0.032 * math.sin(u * math.pi);
  return ui.Offset(
    0.35 + u * 0.30,
    0.205 + band * 0.085 + crown,
  );
}

ui.Offset _formationPoint(
  int index,
  int count,
  ui.Offset fan,
  ui.Offset opening,
  ui.Offset finalText,
  double progress,
) {
  if (progress < _openingSettleEnd) {
    return ui.Offset.lerp(
      fan,
      opening,
      smoothstep(progress / _openingSettleEnd),
    )!;
  }
  if (progress < _textTransitionStart) return opening;
  final staging = _transitionStagingPoint(index, count);
  if (progress < _stagingHoldStart) {
    final t =
        (progress - _textTransitionStart) /
        (_stagingHoldStart - _textTransitionStart);
    return ui.Offset.lerp(opening, staging, smoothstep(t))!;
  }
  if (progress < _stagingHoldEnd) return staging;
  if (progress < _textTransitionEnd) {
    final t =
        (progress - _stagingHoldEnd) / (_textTransitionEnd - _stagingHoldEnd);
    return ui.Offset.lerp(staging, finalText, smoothstep(t))!;
  }
  return finalText;
}

ui.Offset _transitionStagingPoint(int index, int count) {
  final u = count <= 1 ? 0.5 : index / (count - 1);
  // Deterministic per-drone row offset in roughly ±0.012 (a `(index*5) mod 7`
  // hash centred on 0) so the staging block has a little vertical thickness.
  final row = ((index * 5) % 7 - 3) * 0.004;
  return ui.Offset(0.37 + u * 0.26, 0.245 + row);
}
