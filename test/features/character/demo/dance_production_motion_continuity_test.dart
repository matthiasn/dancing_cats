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

void main() {
  test('full-song 30fps arms do not reverse within one rendered frame', () {
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
    final scenes = [
      for (var lane = 0; lane < 3; lane++) CharacterScene(buildCatInSuitRig()),
    ];
    const ids = [
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
    final priorPoint = [for (var i = 0; i < 3; i++) <String, _Point>{}];
    final priorVelocity = [for (var i = 0; i < 3; i++) <String, _Point>{}];
    final priorAngle = [for (var i = 0; i < 3; i++) <String, double>{}];
    final priorAngularVelocity = [
      for (var i = 0; i < 3; i++) <String, double>{},
    ];
    final peaks =
        <
          ({
            double value,
            String kind,
            double t,
            int lane,
            String bone,
            String clip,
            double phase,
          })
        >[];
    const dt = 1 / 30;
    for (var t = 0.0; t <= 144.066; t += dt) {
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
          final transform = world[id]!;
          final point = transform.origin;
          final oldPoint = priorPoint[lane][id];
          priorPoint[lane][id] = point;
          if (oldPoint != null) {
            final velocity = (x: point.x - oldPoint.x, y: point.y - oldPoint.y);
            final oldVelocity = priorVelocity[lane][id];
            priorVelocity[lane][id] = velocity;
            if (oldVelocity != null) {
              final ax = velocity.x - oldVelocity.x;
              final ay = velocity.y - oldVelocity.y;
              peaks.add((
                value: math.sqrt(ax * ax + ay * ay),
                kind: 'posA',
                t: t,
                lane: lane,
                bone: id,
                clip: stage.ensemble[lane].name,
                phase: (stage.seconds / clip.duration) % 1,
              ));
            }
          }
          final angle = math.atan2(transform.b, transform.a);
          final oldAngle = priorAngle[lane][id];
          priorAngle[lane][id] = angle;
          if (oldAngle != null) {
            final angularVelocity = math.atan2(
              math.sin(angle - oldAngle),
              math.cos(angle - oldAngle),
            );
            final oldAngularVelocity = priorAngularVelocity[lane][id];
            priorAngularVelocity[lane][id] = angularVelocity;
            if (oldAngularVelocity != null) {
              final angularAcceleration = math
                  .atan2(
                    math.sin(angularVelocity - oldAngularVelocity),
                    math.cos(angularVelocity - oldAngularVelocity),
                  )
                  .abs();
              peaks.add((
                value: angularAcceleration,
                kind: 'angA',
                t: t,
                lane: lane,
                bone: id,
                clip: stage.ensemble[lane].name,
                phase: (stage.seconds / clip.duration) % 1,
              ));
            }
          }
        }
      }
    }
    peaks.sort((a, b) => b.value.compareTo(a.value));
    final peak = peaks.first;
    // The old catastrophic-jump gate sampled at 60fps. It missed sharp
    // V-shaped arm paths that reverse between adjacent 30fps export frames:
    // the rejected later-chorus window peaked at 10.58 units/frame² and read
    // as a visible arm teleport despite passing the 60fps threshold. Enforce
    // the actual export cadence across the complete 144-second choreography.
    expect(
      peak.value,
      lessThan(8.2),
      reason:
          '${peak.kind} ${peak.value.toStringAsFixed(3)} at '
          '${peak.t.toStringAsFixed(3)} lane=${peak.lane} '
          'phase=${peak.phase.toStringAsFixed(4)} ${peak.bone} ${peak.clip}',
    );
  });

  test('full-song production motion has no one-frame teleport', () {
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
    final scenes = [
      for (var lane = 0; lane < 3; lane++) CharacterScene(buildCatInSuitRig()),
    ];
    final previous = [for (var lane = 0; lane < 3; lane++) <String, _Point>{}];
    final previousVelocity = [
      for (var lane = 0; lane < 3; lane++) <String, _Point>{},
    ];
    _MotionSpike maxSpeed = (
      magnitude: 0.0,
      seconds: 0.0,
      lane: 0,
      bone: '',
      clip: '',
      transitionWeight: null,
    );
    var maxAcceleration = maxSpeed;
    const ids = [
      CatBones.hips,
      CatBones.handL,
      CatBones.handR,
      CatBones.armLowerL,
      CatBones.armLowerR,
      CatBones.footL,
      CatBones.footR,
    ];

    const dt = 1 / 60;
    for (var t = 0.0; t <= 144.066; t += dt) {
      stepper.advance(performance, const [], t, dt);
      final stage = stepper.stage!;
      for (var lane = 0; lane < stage.ensemble.length; lane++) {
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
          final prior = previous[lane][id];
          previous[lane][id] = point;
          if (prior == null) continue;
          final velocity = (x: point.x - prior.x, y: point.y - prior.y);
          final speed = math.sqrt(
            velocity.x * velocity.x + velocity.y * velocity.y,
          );
          final plan = stage.ensemble[lane].transitionPlan;
          if (speed > maxSpeed.magnitude) {
            maxSpeed = (
              magnitude: speed,
              seconds: t,
              lane: lane,
              bone: id,
              clip: stage.ensemble[lane].name,
              transitionWeight: plan?.weight,
            );
          }
          final priorVelocity = previousVelocity[lane][id];
          previousVelocity[lane][id] = velocity;
          if (priorVelocity == null) continue;
          final ax = velocity.x - priorVelocity.x;
          final ay = velocity.y - priorVelocity.y;
          final acceleration = math.sqrt(ax * ax + ay * ay);
          if (acceleration > maxAcceleration.magnitude) {
            maxAcceleration = (
              magnitude: acceleration,
              seconds: t,
              lane: lane,
              bone: id,
              clip: stage.ensemble[lane].name,
              transitionWeight: plan?.weight,
            );
          }
        }
      }
    }

    String describe(_MotionSpike spike) =>
        '${spike.seconds.toStringAsFixed(3)} '
        'lane ${spike.lane} '
        '${spike.bone.padRight(12)} ${spike.magnitude.toStringAsFixed(2)} '
        '${spike.clip} w=${spike.transitionWeight?.toStringAsFixed(3) ?? '-'}';
    // The restored two-bar Moving clock intentionally carries faster authored
    // footwork, so speed alone is not a teleport signal. A one-frame velocity
    // reversal is: the rejected production state peaked at 8.10 units/frame²
    // when wrapper/contact ownership switched. Keep room for real accents but
    // fail on that discontinuity class anywhere in the complete 144s export.
    expect(
      maxSpeed.magnitude,
      lessThan(12),
      reason: 'full-song peak speed: ${describe(maxSpeed)}',
    );
    expect(
      maxAcceleration.magnitude,
      lessThan(7),
      reason: 'full-song peak acceleration: ${describe(maxAcceleration)}',
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
