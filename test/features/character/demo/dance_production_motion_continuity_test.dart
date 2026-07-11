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

void main() {
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
