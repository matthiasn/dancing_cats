import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dancing_cats/features/scenery/layers/backdrop_layer.dart';
import 'package:dancing_cats/features/scenery/layers/drone_show_layer.dart'
    show kDroneShowCycleSeconds;
import 'package:dancing_cats/features/scenery/layers/jet_contrail.dart';
import 'package:dancing_cats/features/scenery/model/scenery_assets.dart';
import 'package:dancing_cats/features/scenery/runtime/scenery_geometry.dart';
import 'package:dancing_cats/features/scenery/runtime/scenery_glow.dart';
import 'package:dancing_cats/features/scenery/runtime/scenery_math.dart';

/// Duration of the distant 747 pass.
///
/// A ~60 second crossing keeps the 747 moving clearly in the opening minute
/// while still reading as a distant approach/departure, not a foreground flyby.
const double kDistantJetPassSeconds = 60;

/// Short blank lead-in so the aircraft is not visible on the first video frame.
const double kDistantJetStartDelaySeconds = 0.18;

/// Extra seconds the contrails remain after the aircraft has left the stage.
/// Shortened from 82: with the steeper climb-out the long-lived streak crossed
/// the frame at the lead singer's ear height for most of the first minute, and
/// the review panel flagged the sustained crown tangent.
const double kDistantJetTrailHoldSeconds = 48;

/// FAA Part 25 anti-collision systems must flash at 40-100 cycles/minute.
/// Use a centered 60 cpm cadence so the distant jet reads as aviation lighting
/// without becoming a music-video strobe.
const double kAircraftAntiCollisionCyclesPerMinute = 60;

/// One pulse per second at [kAircraftAntiCollisionCyclesPerMinute].
const double kAircraftAntiCollisionPeriodSeconds =
    60 / kAircraftAntiCollisionCyclesPerMinute;

const _engineNozzles = [
  ui.Offset(0.36, 0.73),
  ui.Offset(0.43, 0.76),
  ui.Offset(0.54, 0.69),
  ui.Offset(0.61, 0.68),
];

/// Visible exhaust contrails usually begin after the hot plume has mixed and
/// cooled. NASA/LaRC references put typical formation at <=30 m behind the
/// engines; for a 747-sized aircraft that reads as roughly half a body length.
const double _contrailFormationAircraftLengths = 0.45;

/// Extra body lengths over which the first visible ice crystals fade in.
const double _contrailFadeInAircraftLengths = 0.24;

const double _contrailSampleStepSeconds = 0.14;

/// A small, distant Lufthansa 747 crossing the blue-hour sky right-to-left.
///
/// The aircraft itself is a generated transparent bitmap asset; this layer owns
/// only the timing, placement, haze/opacity, FAA-rate anti-collision lights, and
/// four engine-origin contrails. It is drawn behind the drone show as independent
/// background traffic, not as a collision/near-collision gag.
class DistantJetLayer implements BackdropLayer {
  const DistantJetLayer({
    this.passSeconds = kDistantJetPassSeconds,
    this.cycleSeconds = kDroneShowCycleSeconds,
  });

  /// Seconds spent crossing the frame in one loop.
  final double passSeconds;

  /// Scene-loop duration. Matches the drone show by default.
  final double cycleSeconds;

  @override
  void paint(ui.Canvas canvas, BackdropContext ctx) {
    if (ctx.reducedMotion) return;
    final image = ctx.images[SceneryAssets.lufthansa747];
    if (image == null) return;

    final sample = sampleDistantJet(
      ctx.timeSeconds,
      passSeconds: passSeconds,
      cycleSeconds: cycleSeconds,
    );
    if (sample == null) return;

    final stage = distantJetStageRect(ctx.size);
    final center = stage.project(sample.position.dx, sample.position.dy);
    final width = stage.width * sample.widthFraction;
    final height = width * image.height / image.width;

    canvas
      ..save()
      ..clipRect(stage)
      ..saveLayer(stage, ui.Paint());
    _paintTrail(
      canvas,
      ctx,
      stage,
      image,
      passSeconds: passSeconds,
      cycleSeconds: cycleSeconds,
    );
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(sample.headingRadians);
    _paintJetBitmap(canvas, image, sample, width, height);
    _paintLights(canvas, ctx, sample, width, height);
    canvas
      ..restore()
      ..save()
      ..clipRect(stage);
    _cutSkylineOccluder(canvas, ctx);
    canvas
      ..restore()
      ..restore()
      ..restore();
  }
}

void _cutSkylineOccluder(ui.Canvas canvas, BackdropContext ctx) {
  final occluder = ctx.images[SceneryAssets.cityBridge];
  if (occluder == null) return;

  final src = ui.Rect.fromLTWH(
    0,
    0,
    occluder.width.toDouble(),
    occluder.height.toDouble(),
  );
  final dest = coverRect(src.size, ctx.size);
  final paint = ui.Paint()
    ..blendMode = ui.BlendMode.dstOut
    ..filterQuality = ui.FilterQuality.medium;

  // A small pad removes bright aircraft pixels from antialiased skyline edges,
  // which otherwise read as a deregistered ghost mask in close camera crops.
  const offsets = [
    ui.Offset.zero,
    ui.Offset(-1.25, 0),
    ui.Offset(1.25, 0),
    ui.Offset(0, -1.25),
    ui.Offset(0, 1.25),
  ];
  for (final offset in offsets) {
    canvas.drawImageRect(occluder, src, dest.shift(offset), paint);
  }
}

/// Active 16:9 composition rect inside [viewport].
///
/// The dance demo letterboxes the stage to 16:9; this layer uses the same rect
/// so the aircraft never paints into side bars on wider desktop/export surfaces.
ui.Rect distantJetStageRect(ui.Size viewport) {
  if (viewport.isEmpty) return ui.Rect.zero;
  const aspect = 16 / 9;
  final viewportAspect = viewport.width / viewport.height;
  if (viewportAspect > aspect) {
    final width = viewport.height * aspect;
    return ui.Rect.fromLTWH(
      (viewport.width - width) / 2,
      0,
      width,
      viewport.height,
    );
  }
  final height = viewport.width / aspect;
  return ui.Rect.fromLTWH(
    0,
    (viewport.height - height) / 2,
    viewport.width,
    height,
  );
}

/// One normalized sample for the distant jet pass.
class DistantJetSample {
  const DistantJetSample({
    required this.position,
    required this.widthFraction,
    required this.opacity,
    required this.trailOpacity,
    required this.trailLengthScale,
    required this.headingRadians,
    required this.beacon,
    required this.strobe,
  });

  /// Normalized position in the active 16:9 stage coordinate space.
  final ui.Offset position;

  /// Plane width as a fraction of the active 16:9 stage width.
  final double widthFraction;

  /// Haze/edge visibility multiplier.
  final double opacity;

  /// Separate trail visibility multiplier.
  final double trailOpacity;

  /// Contrail length in aircraft-body widths.
  final double trailLengthScale;

  /// Sprite pitch trim. Positive rotates the left-facing airliner's nose
  /// skyward (canvas rotation is clockwise-positive, so a point on the −x nose
  /// axis moves toward −y).
  final double headingRadians;

  /// Red anti-collision beacon intensity.
  final double beacon;

  /// White wingtip strobe intensity.
  final double strobe;
}

/// Samples the pass. Returns null outside the visible pass window.
DistantJetSample? sampleDistantJet(
  double timeSeconds, {
  double passSeconds = kDistantJetPassSeconds,
  double cycleSeconds = kDroneShowCycleSeconds,
}) {
  final safeCycle = cycleSeconds <= 0 ? kDroneShowCycleSeconds : cycleSeconds;
  final safePass = passSeconds <= 0 ? kDistantJetPassSeconds : passSeconds;
  final local = _jetPassLocalSeconds(timeSeconds, safeCycle);
  if (local == null) return null;
  return _sampleDistantJetLocal(local, safePass);
}

double? _jetPassLocalSeconds(double timeSeconds, double safeCycle) {
  final local = fract(timeSeconds / safeCycle) * safeCycle;
  if (local < kDistantJetStartDelaySeconds) return null;
  return local - kDistantJetStartDelaySeconds;
}

DistantJetSample? _sampleDistantJetLocal(double local, double safePass) {
  if (local > safePass + kDistantJetTrailHoldSeconds) return null;

  final progress = (local / safePass).clamp(0.0, 1.0);
  final afterPassSeconds = math.max(0, local - safePass);
  final trailAfterPassFade =
      1 - smoothstep(afterPassSeconds / kDistantJetTrailHoldSeconds);
  // Start at the right edge, but lower in open sky. The earlier high path
  // entered under the foreground palm, making its lights read detached.
  final x = 0.98 - progress * 1.10;
  // Departing on a FRONT-LOADED climb-out (steep initial climb shallowing at
  // altitude — how a heavy jet actually departs). The curve is tuned to the
  // antenna mast on the tall tower at stage (0.209, 0.225): the jet reaches
  // that column at progress ~0.70 (t ≈ 41-42s into the loop) with its engine
  // line JUST above the mast tip — a near-miss flyover, not an overlap. The
  // front-loading also lifts the trail the jet lays across mid-frame early in
  // the pass (an eased-in climb kept that segment low, parking the bright
  // streak at the lead singer's ear height in the tight chorus framings — a
  // sustained crown tangent the review panel flagged twice), while the exit
  // stays below the 0.17 background-traffic floor asserted by the
  // drone-show-peak test.
  final climb = 1 - math.pow(1 - progress, 3).toDouble();
  final y = 0.25 - climb * 0.0415 + math.sin(progress * math.pi) * 0.002;
  final edge = distantJetEdgeVisibility(x);
  if (edge <= 0) return null;

  return DistantJetSample(
    position: ui.Offset(x, y),
    widthFraction: 0.06 - progress * 0.0015,
    opacity: edge * (0.84 - progress * 0.08) * (afterPassSeconds > 0 ? 0 : 1),
    trailOpacity:
        edge *
        trailAfterPassFade *
        (0.68 + math.sin(progress * math.pi) * 0.16),
    trailLengthScale: math.min(7.2, math.max(0.28, local * 0.36)),
    // Nose-up trim (positive rotates the left-facing sprite's nose skyward) so
    // the pitch sells the steeper climb-out; kept under the ~4° flight-path
    // angle so it still reads as a heavy jet, not a fighter.
    headingRadians: 0.045,
    beacon: aircraftBeaconPulse(local),
    strobe: aircraftWingStrobe(local),
  );
}

/// Edge fade for the pass so the jet never pops on/off at the frame boundary.
double distantJetEdgeVisibility(double x) {
  final enter = 1 - smoothstep((x - 1.12) / 0.08);
  final exit = smoothstep((x + 0.18) / 0.12);
  return (enter * exit).clamp(0.0, 1.0);
}

/// Red anti-collision beacon pulse at 60 cycles/minute.
double aircraftBeaconPulse(double timeSeconds, {double phase = 0}) {
  final t = fract(
    (timeSeconds + phase) / kAircraftAntiCollisionPeriodSeconds,
  );
  const flashWidth = 0.11;
  if (t > flashWidth) return 0;
  return 1 - smoothstep(t / flashWidth);
}

/// White anti-collision wingtip pulse, synchronized with the red beacon.
double aircraftWingStrobe(double timeSeconds, {double phase = 0}) {
  return aircraftBeaconPulse(timeSeconds, phase: phase);
}

void _paintJetBitmap(
  ui.Canvas canvas,
  ui.Image image,
  DistantJetSample sample,
  double width,
  double height,
) {
  final dst = ui.Rect.fromCenter(
    center: ui.Offset.zero,
    width: width,
    height: height,
  );
  canvas.drawImageRect(
    image,
    ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    dst,
    ui.Paint()
      ..isAntiAlias = true
      ..filterQuality = ui.FilterQuality.medium
      ..color = const ui.Color(
        0xFFFFFFFF,
      ).withValues(alpha: sample.opacity),
  );
}

void _paintTrail(
  ui.Canvas canvas,
  BackdropContext ctx,
  ui.Rect stage,
  ui.Image image, {
  required double passSeconds,
  required double cycleSeconds,
}) {
  final safeCycle = cycleSeconds <= 0 ? kDroneShowCycleSeconds : cycleSeconds;
  final safePass = passSeconds <= 0 ? kDistantJetPassSeconds : passSeconds;
  final local = _jetPassLocalSeconds(ctx.timeSeconds, safeCycle);
  if (local == null) return;
  final current = _sampleDistantJetLocal(local, safePass);
  if (current == null || current.trailOpacity <= 0) return;

  ui.Offset engineAt(DistantJetSample sample, ui.Offset normalizedNozzle) {
    final center = stage.project(sample.position.dx, sample.position.dy);
    final width = stage.width * sample.widthFraction;
    final height = width * image.height / image.width;
    final localPoint = ui.Offset(
      (normalizedNozzle.dx - 0.5) * width,
      (normalizedNozzle.dy - 0.5) * height,
    );
    return center + _rotate(localPoint, sample.headingRadians);
  }

  ui.Offset windDrift(double ageSeconds) {
    final age = ageSeconds / kDistantJetTrailHoldSeconds;
    return ui.Offset(stage.width * 0.004 * age, -stage.height * 0.002 * age);
  }

  final stageSpeedPerSecond = 1.10 / safePass;
  final formationGapSeconds =
      current.widthFraction *
      _contrailFormationAircraftLengths /
      stageSpeedPerSecond;
  final formationFadeSeconds =
      current.widthFraction *
      _contrailFadeInAircraftLengths /
      stageSpeedPerSecond;
  final maxAge = math.min(local, kDistantJetTrailHoldSeconds);
  if (maxAge <= formationGapSeconds) return;

  for (final normalizedNozzle in _engineNozzles) {
    final points = <TrailPoint>[];
    for (
      var age = formationGapSeconds;
      age <= maxAge;
      age += _contrailSampleStepSeconds
    ) {
      final emitted = _sampleDistantJetLocal(local - age, safePass);
      if (emitted == null || emitted.opacity <= 0) continue;

      points.add(
        TrailPoint(engineAt(emitted, normalizedNozzle) + windDrift(age), age),
      );
    }
    if (points.length < 2) continue;

    paintTrailRibbon(
      canvas,
      points,
      formationGapSeconds: formationGapSeconds,
      formationFadeSeconds: formationFadeSeconds,
      maxAge: maxAge,
      maxWidth: stage.height * 0.0042,
      widthStartFactor: 0.24,
      widthEndFactor: 1.35,
      shader: ui.Gradient.linear(
        points.first.position,
        points.last.position,
        [
          ctx.palette.cloudLit.withValues(alpha: 0),
          ctx.palette.cloudLit.withValues(alpha: current.trailOpacity * 0.11),
          ctx.palette.cloudBase.withValues(alpha: current.trailOpacity * 0.07),
          ctx.palette.cloudBase.withValues(alpha: 0),
        ],
        [0, 0.08, 0.62, 1],
      ),
    );
    paintTrailRibbon(
      canvas,
      points,
      formationGapSeconds: formationGapSeconds,
      formationFadeSeconds: formationFadeSeconds,
      maxAge: maxAge,
      maxWidth: stage.height * 0.0011,
      widthStartFactor: 1,
      widthEndFactor: 0.18,
      shader: ui.Gradient.linear(
        points.first.position,
        points.last.position,
        [
          ctx.palette.cloudLit.withValues(alpha: 0),
          ctx.palette.cloudLit.withValues(alpha: current.trailOpacity * 0.42),
          ctx.palette.cloudBase.withValues(alpha: current.trailOpacity * 0.12),
          ctx.palette.cloudBase.withValues(alpha: 0),
        ],
        [0, 0.045, 0.34, 1],
      ),
    );
  }
}

ui.Offset _rotate(ui.Offset p, double radians) {
  final c = math.cos(radians);
  final s = math.sin(radians);
  return ui.Offset(p.dx * c - p.dy * s, p.dx * s + p.dy * c);
}

void _paintLights(
  ui.Canvas canvas,
  BackdropContext ctx,
  DistantJetSample sample,
  double width,
  double height,
) {
  ui.Offset assetPoint(double x, double y) {
    return ui.Offset((x - 0.5) * width, (y - 0.5) * height);
  }

  void lamp(
    ui.Offset c,
    ui.Color color,
    double intensity,
    double radius, {
    double bloom = 4,
  }) {
    if (intensity <= 0) return;
    final alpha = sample.opacity * intensity;
    paintGlowPointLight(
      canvas,
      center: c,
      color: color,
      haloRadius: radius * bloom,
      haloInnerAlpha: alpha * 0.58,
      haloMidAlpha: alpha * 0.13,
      haloMidStop: 0.42,
      coreRadius: radius,
      coreColor: ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.38)!,
      coreAlpha: alpha,
    );
  }

  final r = math.max(1.1, height * 0.05);
  final visibleWingtip = assetPoint(0.787, 0.322);
  final tailCone = assetPoint(0.982, 0.438);
  final topBeacon = assetPoint(0.438, 0.397);
  final bottomBeacon = assetPoint(0.438, 0.688);

  // Side-on left/profile bitmap: draw only the visible port wing position light
  // plus the rear white position light. The opposite green wingtip is hidden by
  // the fuselage/wing geometry at this angle.
  lamp(
    visibleWingtip,
    ctx.palette.shipPort,
    0.58,
    r * 0.68,
    bloom: 2.2,
  );
  lamp(
    tailCone,
    ctx.palette.shipMast,
    0.56,
    r * 0.7,
    bloom: 2.3,
  );

  // Anti-collision lights: one FAA-rate system pulse, aviation red on the
  // fuselage beacons and aviation white at the visible wingtip strobe.
  lamp(
    visibleWingtip.translate(0, -r * 0.7),
    ctx.palette.aircraftStrobe,
    sample.strobe * 0.55,
    r * 0.82,
    bloom: 3,
  );
  lamp(
    topBeacon,
    ctx.palette.aircraftBeacon,
    sample.beacon * 0.5,
    r * 0.74,
    bloom: 2.7,
  );
  lamp(
    bottomBeacon,
    ctx.palette.aircraftBeacon,
    sample.beacon * 0.28,
    r * 0.62,
    bloom: 2.1,
  );
}

// Shared scenery math (`fract`, `smoothstep`) now lives in scenery_math.dart.
