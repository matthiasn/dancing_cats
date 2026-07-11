import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dancing_cats/features/character/demo/dance_loaders.dart';
import 'package:dancing_cats/features/character/demo/dance_performance.dart';
import 'package:dancing_cats/features/character/demo/dance_playback_stepper.dart';
import 'package:dancing_cats/features/character/demo/dance_stage_view.dart';
import 'package:dancing_cats/features/character/model/beat_map.dart';
import 'package:dancing_cats/features/character/runtime/character_scene.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Point = ({double x, double y});
typedef _MotionSpike = ({
  double magnitude,
  double seconds,
  int lane,
  String bone,
  String clip,
  double? transitionWeight,
});

typedef _ArmSpike = ({
  double value,
  String kind,
  double t,
  int lane,
  String bone,
  String clip,
  double phase,
});

typedef _FullSongAudit = ({
  _ArmSpike arm30Peak,
  _MotionSpike speed60Peak,
  _MotionSpike acceleration60Peak,
});

_FullSongAudit _auditFullSong() {
  final beatJson =
      jsonDecode(File('assets/sample_track/moving.json').readAsStringSync())
          as Map<String, Object?>;
  final wordsJson =
      jsonDecode(
            File('assets/sample_track/moving.words.json').readAsStringSync(),
          )
          as Map<String, Object?>;
  final map = BeatMap.fromJson(beatJson);
  final performance = DancePerformance.fromBeatMapJson(
    json: beatJson,
    map: map,
    trackDurationSec: 144.066,
    words: parseDanceWords(wordsJson),
  );
  final stepper = DancePlaybackStepper();
  final scenes = [
    for (var lane = 0; lane < 3; lane++) CharacterScene(buildCatInSuitRig()),
  ];
  const armIds = [
    CatBones.clavicleL,
    CatBones.armUpperL,
    CatBones.armBicepL,
    CatBones.armLowerL,
    CatBones.armForearmL,
    CatBones.handL,
    CatBones.clavicleR,
    CatBones.armUpperR,
    CatBones.armBicepR,
    CatBones.armLowerR,
    CatBones.armForearmR,
    CatBones.handR,
  ];
  const motion60Ids = {
    CatBones.hips,
    CatBones.handL,
    CatBones.handR,
    CatBones.armLowerL,
    CatBones.armLowerR,
    CatBones.footL,
    CatBones.footR,
  };
  final points30 = [for (var lane = 0; lane < 3; lane++) <String, _Point>{}];
  final velocities30 = [
    for (var lane = 0; lane < 3; lane++) <String, _Point>{},
  ];
  final angles30 = [for (var lane = 0; lane < 3; lane++) <String, double>{}];
  final angularVelocities30 = [
    for (var lane = 0; lane < 3; lane++) <String, double>{},
  ];
  final points60 = [for (var lane = 0; lane < 3; lane++) <String, _Point>{}];
  final velocities60 = [
    for (var lane = 0; lane < 3; lane++) <String, _Point>{},
  ];
  _ArmSpike arm30Peak = (
    value: 0,
    kind: '',
    t: 0,
    lane: 0,
    bone: '',
    clip: '',
    phase: 0,
  );
  _MotionSpike speed60Peak = (
    magnitude: 0,
    seconds: 0,
    lane: 0,
    bone: '',
    clip: '',
    transitionWeight: null,
  );
  var acceleration60Peak = speed60Peak;

  const dt = 1 / 60;
  final frames = (144.066 * 60).floor();
  for (var frame = 0; frame <= frames; frame++) {
    final t = frame * dt;
    stepper.advance(performance, const [], t, dt);
    final stage = stepper.stage!;
    for (var lane = 0; lane < 3; lane++) {
      final clip = productionDanceClip(
        stage.ensemble[lane],
        stage.dynamics[lane],
        lane,
        stage.energyLevel,
      );
      final world = scenes[lane]
          .frameAt(clip: clip, timeSeconds: stage.seconds)
          .world;

      for (final id in motion60Ids) {
        final origin = world[id]!.origin;
        final point = (x: origin.x, y: origin.y);
        final prior = points60[lane][id];
        points60[lane][id] = point;
        if (prior == null) continue;
        final velocity = (x: point.x - prior.x, y: point.y - prior.y);
        final speed = math.sqrt(
          velocity.x * velocity.x + velocity.y * velocity.y,
        );
        final plan = stage.ensemble[lane].transitionPlan;
        if (speed > speed60Peak.magnitude) {
          speed60Peak = (
            magnitude: speed,
            seconds: t,
            lane: lane,
            bone: id,
            clip: stage.ensemble[lane].name,
            transitionWeight: plan?.weight,
          );
        }
        final priorVelocity = velocities60[lane][id];
        velocities60[lane][id] = velocity;
        if (priorVelocity == null) continue;
        final ax = velocity.x - priorVelocity.x;
        final ay = velocity.y - priorVelocity.y;
        final acceleration = math.sqrt(ax * ax + ay * ay);
        if (acceleration > acceleration60Peak.magnitude) {
          acceleration60Peak = (
            magnitude: acceleration,
            seconds: t,
            lane: lane,
            bone: id,
            clip: stage.ensemble[lane].name,
            transitionWeight: plan?.weight,
          );
        }
      }

      if (frame.isOdd) continue;
      for (final id in armIds) {
        final transform = world[id]!;
        final point = transform.origin;
        final oldPoint = points30[lane][id];
        points30[lane][id] = point;
        if (oldPoint != null) {
          final velocity = (x: point.x - oldPoint.x, y: point.y - oldPoint.y);
          final oldVelocity = velocities30[lane][id];
          velocities30[lane][id] = velocity;
          if (oldVelocity != null) {
            final ax = velocity.x - oldVelocity.x;
            final ay = velocity.y - oldVelocity.y;
            final value = math.sqrt(ax * ax + ay * ay);
            if (value > arm30Peak.value) {
              arm30Peak = (
                value: value,
                kind: 'posA',
                t: t,
                lane: lane,
                bone: id,
                clip: stage.ensemble[lane].name,
                phase: (stage.seconds / clip.duration) % 1,
              );
            }
          }
        }
        final angle = math.atan2(transform.b, transform.a);
        final oldAngle = angles30[lane][id];
        angles30[lane][id] = angle;
        if (oldAngle == null) continue;
        final angularVelocity = math.atan2(
          math.sin(angle - oldAngle),
          math.cos(angle - oldAngle),
        );
        final oldAngularVelocity = angularVelocities30[lane][id];
        angularVelocities30[lane][id] = angularVelocity;
        if (oldAngularVelocity == null) continue;
        final value = math
            .atan2(
              math.sin(angularVelocity - oldAngularVelocity),
              math.cos(angularVelocity - oldAngularVelocity),
            )
            .abs();
        if (value > arm30Peak.value) {
          arm30Peak = (
            value: value,
            kind: 'angA',
            t: t,
            lane: lane,
            bone: id,
            clip: stage.ensemble[lane].name,
            phase: (stage.seconds / clip.duration) % 1,
          );
        }
      }
    }
  }
  return (
    arm30Peak: arm30Peak,
    speed60Peak: speed60Peak,
    acceleration60Peak: acceleration60Peak,
  );
}

void main() {
  late _FullSongAudit fullSongAudit;

  setUpAll(() {
    fullSongAudit = _auditFullSong();
  });

  test("full-song 30fps arms do not reverse within one rendered frame", () {
    final peak = fullSongAudit.arm30Peak;
    expect(
      peak.value,
      lessThan(8.2),
      reason:
          peak.kind +
          " " +
          peak.value.toStringAsFixed(3) +
          " at " +
          peak.t.toStringAsFixed(3) +
          " lane=" +
          peak.lane.toString() +
          " phase=" +
          peak.phase.toStringAsFixed(4) +
          " " +
          peak.bone +
          " " +
          peak.clip,
    );
  });

  test("full-song production motion has no one-frame teleport", () {
    String describe(_MotionSpike spike) =>
        spike.seconds.toStringAsFixed(3) +
        " lane " +
        spike.lane.toString() +
        " " +
        spike.bone.padRight(12) +
        " " +
        spike.magnitude.toStringAsFixed(2) +
        " " +
        spike.clip +
        " w=" +
        (spike.transitionWeight?.toStringAsFixed(3) ?? "-");
    expect(
      fullSongAudit.speed60Peak.magnitude,
      lessThan(12),
      reason: "full-song peak speed: " + describe(fullSongAudit.speed60Peak),
    );
    expect(
      fullSongAudit.acceleration60Peak.magnitude,
      lessThan(7),
      reason:
          "full-song peak acceleration: " +
          describe(fullSongAudit.acceleration60Peak),
    );
  });

  test('Moving score cuts keep shoulder wind on the outgoing clock', () {
    final beatJson =
        jsonDecode(File('assets/sample_track/moving.json').readAsStringSync())
            as Map<String, Object?>;
    final wordsJson =
        jsonDecode(
              File('assets/sample_track/moving.words.json').readAsStringSync(),
            )
            as Map<String, Object?>;
    final map = BeatMap.fromJson(beatJson);
    final performance = DancePerformance.fromBeatMapJson(
      json: beatJson,
      map: map,
      trackDurationSec: 144.066,
      words: parseDanceWords(wordsJson),
    );
    final stepper = DancePlaybackStepper();
    final scenes = [
      for (var lane = 0; lane < 3; lane++) CharacterScene(buildCatInSuitRig()),
    ];
    final points = [for (var lane = 0; lane < 3; lane++) <String, _Point>{}];
    final velocities = [
      for (var lane = 0; lane < 3; lane++) <String, _Point>{},
    ];
    var peak = 0.0;
    const ids = [
      CatBones.clavicleL,
      CatBones.clavicleR,
      CatBones.armUpperL,
      CatBones.armUpperR,
      CatBones.armLowerL,
      CatBones.armLowerR,
      CatBones.handL,
      CatBones.handR,
    ];
    const dt = 1 / 60;
    var peakTime = 0.0;
    var peakLane = 0;
    var peakBone = '';
    var peakClip = '';
    var peakFromPhase = 0.0;
    var peakToPhase = 0.0;
    var peakWeight = 0.0;
    for (var t = 126.5; t <= 129.0; t += dt) {
      stepper.advance(performance, const [], t, dt);
      final stage = stepper.stage!;
      for (var lane = 0; lane < 3; lane++) {
        final clip = productionDanceClip(
          stage.ensemble[lane],
          stage.dynamics[lane],
          lane,
          stage.energyLevel,
        );
        final world = scenes[lane]
            .frameAt(clip: clip, timeSeconds: stage.seconds)
            .world;
        for (final id in ids) {
          final origin = world[id]!.origin;
          final point = (x: origin.x, y: origin.y);
          final prior = points[lane][id];
          points[lane][id] = point;
          if (prior == null) continue;
          final velocity = (x: point.x - prior.x, y: point.y - prior.y);
          final oldVelocity = velocities[lane][id];
          velocities[lane][id] = velocity;
          if (oldVelocity == null ||
              stage.ensemble[lane].transitionPlan == null) {
            continue;
          }
          final ax = velocity.x - oldVelocity.x;
          final ay = velocity.y - oldVelocity.y;
          final acceleration = math.sqrt(ax * ax + ay * ay);
          if (acceleration > peak) {
            peak = acceleration;
            peakTime = t;
            peakLane = lane;
            peakBone = id;
            peakClip = stage.ensemble[lane].name;
            final transition = clip.transitionPlan;
            if (transition != null) {
              peakFromPhase =
                  ((stage.seconds + transition.fromTimeShiftSeconds) /
                      transition.from.duration) %
                  1;
              peakToPhase = (stage.seconds / transition.to.duration) % 1;
              peakWeight = transition.weight;
            }
          }
        }
      }
    }
    // Sampling the shoulder wind on the incoming clock at transition weight 0
    // produced 5.72 units/frame² here and read as a hand teleport. The
    // transition-aware wind stays below 3 while retaining the 0.4s handoff.
    expect(
      peak,
      lessThan(3.1),
      reason:
          '${peak.toStringAsFixed(3)} at ${peakTime.toStringAsFixed(3)}s '
          'lane=$peakLane $peakBone $peakClip '
          'fromPhase=${peakFromPhase.toStringAsFixed(3)} '
          'toPhase=${peakToPhase.toStringAsFixed(3)} '
          'w=${peakWeight.toStringAsFixed(3)}',
    );
  });

  test('Moving hook-to-answer support transfer stays velocity-continuous', () {
    final beatJson =
        jsonDecode(
              File('assets/sample_track/moving.json').readAsStringSync(),
            )
            as Map<String, Object?>;
    final wordsJson =
        jsonDecode(
              File('assets/sample_track/moving.words.json').readAsStringSync(),
            )
            as Map<String, Object?>;
    final map = BeatMap.fromJson(beatJson);
    final performance = DancePerformance.fromBeatMapJson(
      json: beatJson,
      map: map,
      trackDurationSec: 144.066,
      words: parseDanceWords(wordsJson),
    );
    final stepper = DancePlaybackStepper();
    final scene = CharacterScene(buildCatInSuitRig());
    final previous = <String, _Point>{};
    final previousVelocity = <String, _Point>{};
    const ids = [
      CatBones.hips,
      CatBones.handL,
      CatBones.handR,
      CatBones.armLowerR,
      CatBones.footL,
      CatBones.footR,
    ];

    const dt = 1 / 60;
    for (var t = 109.5; t <= 112.75; t += dt) {
      stepper.advance(performance, const [], t, dt);
      final stage = stepper.stage!;
      final clip = productionDanceClip(
        stage.lead,
        stage.dynamics.first,
        0,
        stage.energyLevel,
      );
      final world = scene.frameAt(clip: clip, timeSeconds: stage.seconds).world;
      for (final id in ids) {
        final origin = world[id]!.origin;
        final point = (x: origin.x, y: origin.y);
        final prior = previous[id];
        previous[id] = point;
        if (prior == null) continue;
        final velocity = (x: point.x - prior.x, y: point.y - prior.y);
        final priorVelocity = previousVelocity[id];
        previousVelocity[id] = velocity;
        if (t < 112.2 || priorVelocity == null) continue;

        final travel = math.sqrt(
          velocity.x * velocity.x + velocity.y * velocity.y,
        );
        final ax = velocity.x - priorVelocity.x;
        final ay = velocity.y - priorVelocity.y;
        final acceleration = math.sqrt(ax * ax + ay * ay);
        expect(
          travel,
          lessThan(6.0),
          reason: '$id moved $travel units at ${t.toStringAsFixed(3)}s',
        );
        expect(
          acceleration,
          lessThan(5.0),
          reason:
              '$id changed velocity by $acceleration units/frame at '
              '${t.toStringAsFixed(3)}s',
        );
      }
    }
  });

  test('production phrase handoffs do not teleport limbs', () {
    final beatJson =
        jsonDecode(
              File('assets/sample_track/moving.json').readAsStringSync(),
            )
            as Map<String, Object?>;
    final wordsJson =
        jsonDecode(
              File('assets/sample_track/moving.words.json').readAsStringSync(),
            )
            as Map<String, Object?>;
    final map = BeatMap.fromJson(beatJson);
    final performance = DancePerformance.fromBeatMapJson(
      json: beatJson,
      map: map,
      trackDurationSec: 144.066,
      words: parseDanceWords(wordsJson),
    );

    // 74s keeps the same move across a semantic section boundary; resetting
    // its phrase anchor used to teleport the unchanged clip. 112s is the
    // former ~100-unit dance→dance arm teleport. 138s also
    // exercises unequal clip durations at dance→idle, where local channel
    // phase and absolute contact time require distinct offsets.
    for (final window in [
      (73.7, 74.4),
      (111.8, 112.6),
      (123.6, 124.3),
      (137.8, 138.5),
    ]) {
      final stepper = DancePlaybackStepper();
      final scene = CharacterScene(buildCatInSuitRig());
      final previous = <String, _Point>{};
      const ids = [
        CatBones.handL,
        CatBones.handR,
        CatBones.armLowerL,
        CatBones.armLowerR,
        CatBones.footL,
        CatBones.footR,
      ];

      const dt = 1 / 60;
      for (var t = window.$1; t <= window.$2; t += dt) {
        stepper.advance(performance, const [], t, dt);
        final stage = stepper.stage!;
        final clip = productionDanceClip(
          stage.lead,
          stage.dynamics.first,
          0,
          stage.energyLevel,
        );
        final world = scene
            .frameAt(clip: clip, timeSeconds: stage.seconds)
            .world;

        for (final id in ids) {
          final origin = world[id]!.origin;
          final point = (x: origin.x, y: origin.y);
          final prior = previous[id];
          if (prior != null) {
            final dx = point.x - prior.x;
            final dy = point.y - prior.y;
            final travel = math.sqrt(dx * dx + dy * dy);
            // The full production audit currently peaks below 8.2 units for
            // every sampled limb. Leave modest headroom for authored accents,
            // but keep this tight enough to catch a support-anchor ownership
            // flip or phase reset rather than merely proving "below 40".
            const limit = 12.0;
            expect(
              travel,
              lessThan(limit),
              reason:
                  '$id jumped $travel units at ${t.toStringAsFixed(3)}s '
                  'in ${stage.lead.name}',
            );
          }
          previous[id] = point;
        }
      }
    }
  });
}
