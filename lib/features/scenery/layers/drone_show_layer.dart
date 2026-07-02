import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dancing_cats/features/scenery/layers/backdrop_layer.dart';
import 'package:dancing_cats/features/scenery/layers/drone_text_glyphs.dart';
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
// The launch line is aligned to the police cordon's span on the bridge deck
// (BridgePoliceLayer's roadway, x ≈ 0.555→0.745): the drones stage on exactly
// the stretch of road the police have cleared, so the line of unlit aircraft
// reads as "drones on the closed road" instead of a stray dark bar poking out
// to the left of the cordon.
const double _launchStartX = 0.555;
const double _launchSpanX = 0.19;
const double _launchBaseY = 0.475;
const double _launchSlopeY = 0.005;
const double _ascentSpiralXRadius = 0.014;
const double _ascentSpiralYRadius = 0.011;
const double _ascentSpiralStretchY = 0.024;

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
      haloPaint.shader = ui.Gradient.radial(
        c,
        radius * 4.5,
        [
          color.withValues(alpha: 0.16 * alpha),
          color.withValues(alpha: 0.04 * alpha),
          color.withValues(alpha: 0),
        ],
        [0, 0.45, 1],
      );
      corePaint.color = ui.Color.lerp(
        color,
        const ui.Color(0xFFFFFFFF),
        0.55,
      )!.withValues(alpha: 0.82 * alpha);
      canvas
        ..drawCircle(c, radius * 4.5, haloPaint)
        ..drawCircle(c, radius, corePaint);
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

ui.Offset _launchPoint(int index, int count) {
  final u = count <= 1 ? 0.5 : index / (count - 1);
  final x = _launchStartX + u * _launchSpanX;
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
  final base = ui.Offset.lerp(launch, rise, climb)!;
  final envelope = math.sin(climb * math.pi).clamp(0.0, 1.0);
  if (envelope == 0) return base;

  final u = count <= 1 ? 0.5 : index / (count - 1);
  final pod = math.min(
    (u * _ascentSpiralCount).floor(),
    _ascentSpiralCount - 1,
  );
  final podStart = pod / _ascentSpiralCount;
  final localU = ((u - podStart) * _ascentSpiralCount).clamp(0.0, 1.0);
  final podCenterX =
      _launchStartX + (pod + 0.5) / _ascentSpiralCount * _launchSpanX;
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

ui.Offset _risePoint(int index, int count) {
  final u = count <= 1 ? 0.5 : index / (count - 1);
  return ui.Offset(
    _launchStartX + u * _launchSpanX,
    0.355 - u * 0.016,
  );
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

ui.Offset _beamPoint(int index, int count) {
  final u = count <= 1 ? 0.5 : index / (count - 1);
  // Moved OFF the lead singer's screen axis (was x 0.61 ≈ dead on the lead in
  // the centred and left-leaning framings) and lifted well into open sky: the
  // beam's lower half used to cross the lead's ear line through the WHOLE
  // chorus-2 approach (z 1.38–1.47 sweeps the crown up through the band), a
  // bright rod through the star's head on the biggest drop of the piece. At
  // x ~0.70 it stands over the water between the trio and the yacht, reading
  // as a counterweight instead of a crown hazard.
  return ui.Offset(
    0.70 + (u - 0.5) * 0.04,
    0.255 - u * 0.10,
  );
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
