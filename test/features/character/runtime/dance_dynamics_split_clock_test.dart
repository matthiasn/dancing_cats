import 'dart:math' as math;

import 'package:dancing_cats/features/character/demo/dance_performance.dart';
import 'package:dancing_cats/features/character/model/dance_dynamics.dart';
import 'package:dancing_cats/features/character/model/dance_dynamics_warp.dart';
import 'package:dancing_cats/features/character/runtime/character_scene.dart';
import 'package:dancing_cats/features/character/runtime/temporal_motion_analyzer.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';
import 'package:flutter_test/flutter_test.dart';

/// The kinematic gate for ADR CHAR-0003's split-clock Effort warp: real,
/// non-neutral dynamics composed from the shipped move table, lane profiles,
/// and section-energy gain, exercised against the actual catalogue clips via
/// [upperBodyDynamicsWarpedClip] and the real [CharacterScene]/
/// [TemporalMotionAnalyzer] pipeline (no engine code changed to support the
/// warp — it lives entirely inside the `Clip` the scene is handed).
void main() {
  final catalogClips = [
    CatClips.shaku,
    CatClips.zanku,
    CatClips.azonto,
    CatClips.buga,
    CatClips.pouncingCat,
    CatClips.sekem,
  ];

  DanceDynamics laneDynamics(int lane, double level) => effectiveDanceDynamics(
    moveBase: catalogClips[0].dynamics, // any move: only used for its shape
    catProfile: kDanceLaneDynamicsProfiles[lane],
    sectionEnergy: sectionEnergyDynamics(level),
  );

  group(
    'upperBodyDynamicsWarpedClip — support-bone exact invariant (the '
    'headline guarantee)',
    () {
      test(
        'every non-upper-body bone is world-transform-identical between '
        'warped and unwarped catalogue clips, on every move at every lane',
        () {
          final scene = CharacterScene(buildCatInSuitRig());
          final rig = buildCatInSuitRig();
          final supportBoneIds = [
            for (final bone in rig.bones)
              if (!kDanceUpperBodyWarpBoneIds.contains(bone.id)) bone.id,
          ];
          expect(
            supportBoneIds,
            containsAll([
              CatBones.hips,
              CatBones.footL,
              CatBones.footR,
              CatBones.legUpperL,
              CatBones.legLowerL,
            ]),
          );

          for (final clip in catalogClips) {
            for (var lane = 0; lane < 3; lane++) {
              for (final level in [0.0, 0.5, 1.0]) {
                final dynamics = effectiveDanceDynamics(
                  moveBase: clip.dynamics,
                  catProfile: kDanceLaneDynamicsProfiles[lane],
                  sectionEnergy: sectionEnergyDynamics(level),
                );
                final warped = upperBodyDynamicsWarpedClip(
                  clip,
                  dynamics,
                  warpBoneIds: kDanceUpperBodyWarpBoneIds,
                );
                expect(
                  identical(warped, clip),
                  isFalse,
                  reason:
                      '${clip.name} lane $lane level $level should compose '
                      'to a non-neutral, warped clip',
                );

                for (var i = 0; i <= 16; i++) {
                  final t = clip.duration * i / 16;
                  final rawFrame = scene.frameAt(clip: clip, timeSeconds: t);
                  final warpedFrame = scene.frameAt(
                    clip: warped,
                    timeSeconds: t,
                  );
                  for (final boneId in supportBoneIds) {
                    final raw = rawFrame.world[boneId];
                    final warpedTransform = warpedFrame.world[boneId];
                    if (raw == null || warpedTransform == null) continue;
                    expect(
                      warpedTransform,
                      raw,
                      reason:
                          '${clip.name}/$boneId at t=$t (lane $lane, level '
                          '$level) must stay bit-identical — this bone is '
                          'support-critical and must never see the warp',
                    );
                  }
                }
              }
            }
          }
        },
      );
    },
  );

  group('upperBodyPhaseOffsetClip — crew microtiming', () {
    test('lead is an identity no-op', () {
      final clip = CatClips.movingChorusTravel;
      expect(
        identical(
          upperBodyPhaseOffsetClip(
            clip,
            kDanceLaneUpperBodyPhaseOffsets[0],
            upperBodyBoneIds: kDanceUpperBodyWarpBoneIds,
          ),
          clip,
        ),
        isTrue,
      );
    });

    test('backup hands separate while every support bone stays exact', () {
      final scene = CharacterScene(buildCatInSuitRig());
      final clip = CatClips.movingChorusTravel;
      final shifted = upperBodyPhaseOffsetClip(
        clip,
        kDanceLaneUpperBodyPhaseOffsets[2],
        upperBodyBoneIds: kDanceUpperBodyWarpBoneIds,
      );
      final supportBoneIds = [
        for (final bone in buildCatInSuitRig().bones)
          if (!kDanceUpperBodyWarpBoneIds.contains(bone.id)) bone.id,
      ];
      var maxHandDelta = 0.0;

      for (var i = 0; i < 64; i++) {
        final t = clip.duration * i / 64;
        final raw = scene.frameAt(clip: clip, timeSeconds: t).world;
        final offset = scene.frameAt(clip: shifted, timeSeconds: t).world;
        for (final boneId in supportBoneIds) {
          expect(
            offset[boneId],
            raw[boneId],
            reason: '$boneId at t=$t must remain on the shared beat clock',
          );
        }
        for (final handId in [CatBones.handL, CatBones.handR]) {
          final a = raw[handId]!.origin;
          final b = offset[handId]!.origin;
          maxHandDelta = math.max(
            maxHandDelta,
            math.sqrt(
              math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2),
            ),
          );
        }
      }

      expect(
        maxHandDelta,
        greaterThan(1.0),
        reason: 'the backup upper body should visibly anticipate/drag',
      );
    });
  });

  group('upperBodyDynamicsWarpedClip — velocity ordering', () {
    // pouncingCat's move base (weight -0.55, time -0.65) has no positive
    // weight/flow at all, so it never enters dynamicsCurve's anticipation/
    // overshoot "bump" terms (those only trigger for positive dial values) —
    // its warp is pure inflection-skew. Going COLDER pushes both dials
    // further negative, which can skew the inflection point earlier and
    // locally steepen the curve MORE than the hot direction does (which
    // pulls the dials back toward neutral, i.e. less skew). Measured:
    // cold=28.9 vs hot=15.7 peak hand velocity — an inverted-but-explained
    // result of dynamicsCurve's asymmetric bump design (CHAR-0001 D1), not a
    // wiring bug. Every other catalogue move has a positive weight and/or
    // flow component and orders correctly (measured cold/hot: shaku
    // 20.5/33.4, zanku 20.2/24.0, azonto 12.7/20.5, buga 17.6/22.2, sekem
    // 16.8/22.0).
    // azonto joined 2026-07 with the dance-dynamics organic-hands re-author: its
    // paws now trace a continuous, constant-frequency roll (hands rotating
    // around each other) instead of discrete hit-poses, so the warp has no
    // hit to accentuate in a hot section — hand travel is energy-uniform and no
    // longer orders hot>cold. This is an accepted trade for the continuous
    // organic look (owner: "look and feel like actual afrobeats... loosen
    // constraints if needed"); its accents now come from the body/legs, not the
    // rolling hands.
    const levelOrderingExclusions = {'pouncingCat', 'azonto'};

    test(
      'higher section level composes to higher peak upper-body velocity, '
      'same move',
      () {
        final scene = CharacterScene(buildCatInSuitRig());
        final analyzer = TemporalMotionAnalyzer(scene);

        for (final clip in catalogClips) {
          if (levelOrderingExclusions.contains(clip.name)) continue;

          double peakHandVelocity(double level) {
            final dynamics = effectiveDanceDynamics(
              moveBase: clip.dynamics,
              catProfile: DanceDynamics.neutral,
              sectionEnergy: sectionEnergyDynamics(level),
            );
            final warped = upperBodyDynamicsWarpedClip(
              clip,
              dynamics,
              warpBoneIds: kDanceUpperBodyWarpBoneIds,
            );
            final report = analyzer.analyze(
              clip: warped,
              samples: 192,
              boneIds: const [CatBones.handL, CatBones.handR],
            );
            return report.segments.map((s) => s.distance).reduce(math.max);
          }

          expect(
            peakHandVelocity(1),
            greaterThan(peakHandVelocity(0)),
            reason:
                '${clip.name}: a hot section should read faster hand travel '
                'than a cold one',
          );
        }
      },
    );

    test(
      'lead lane reads a stronger accent than backup-left, same move+level',
      () {
        final scene = CharacterScene(buildCatInSuitRig());
        final analyzer = TemporalMotionAnalyzer(scene);

        double peakHandVelocity(int lane) {
          final clip = CatClips.zanku;
          final dynamics = effectiveDanceDynamics(
            moveBase: clip.dynamics,
            catProfile: kDanceLaneDynamicsProfiles[lane],
            sectionEnergy: sectionEnergyDynamics(1),
          );
          final warped = upperBodyDynamicsWarpedClip(
            clip,
            dynamics,
            warpBoneIds: kDanceUpperBodyWarpBoneIds,
          );
          final report = analyzer.analyze(
            clip: warped,
            samples: 192,
            boneIds: const [CatBones.handL, CatBones.handR],
          );
          return report.segments.map((s) => s.distance).reduce(math.max);
        }

        expect(
          peakHandVelocity(0),
          greaterThan(peakHandVelocity(1)),
          reason:
              "the lead's profile (+weight/+time) should read a harder, "
              "snappier accent than backup-left's (-weight/-time) on the same "
              'move and energy',
        );
      },
    );
  });

  group('upperBodyDynamicsWarpedClip — warped hand jerk stays bounded', () {
    // `dance_smoothness_test.dart` gates the UNWARPED zanku/azonto hand jerk
    // at <28 (rendered clip.clock jerk, no lane/level composition). Warping
    // adds a second source of jerk on top of the authored motion, so this is
    // a fresh calibration, not a re-check of that gate.
    //
    // The warp gain was raised from 0.35 to 0.5 after a 4-lens motion-review
    // panel found the lane/level differentiation real but too subtle to read
    // at 0.35 (lane-to-lane hand-position deltas exceeded 5 units on only
    // ~4% of the loop). At 0.5, worst measured jerk across all 6 catalogue
    // moves x 3 lanes at the hottest level is zanku's lead lane:
    // hand.L=48.5, hand.R=48.4 (lane2 hand.R=41.3 is the next-worst; every
    // azonto combination stayed under 34). zanku hits the ceiling hardest
    // because its OWN move-base dial (Strong/Sudden, ADR D4) is already the
    // catalog's most extreme, so its curve has the least headroom left
    // before the warp's linear gain starts compounding superlinearly with
    // jerk (owner-approved trade-off — a higher gain read better but grew
    // jerk far faster: gain 0.6 -> 64, gain 1.0 -> 140, clearly broken). 55
    // keeps real headroom above the 48.5 worst case while still catching a
    // regression back toward "stop-go" territory.
    test('the worst-case lane+level combination stays under the ceiling', () {
      final scene = CharacterScene(buildCatInSuitRig());
      final analyzer = TemporalMotionAnalyzer(scene);

      for (final clip in [CatClips.zanku, CatClips.azonto]) {
        for (var lane = 0; lane < 3; lane++) {
          final dynamics = effectiveDanceDynamics(
            moveBase: clip.dynamics,
            catProfile: kDanceLaneDynamicsProfiles[lane],
            sectionEnergy: sectionEnergyDynamics(1), // the hottest section
          );
          final warped = upperBodyDynamicsWarpedClip(
            clip,
            dynamics,
            warpBoneIds: kDanceUpperBodyWarpBoneIds,
          );
          final report = analyzer.analyze(
            clip: warped,
            samples: 192,
            boneIds: const [CatBones.handL, CatBones.handR],
          );
          for (final hand in const [CatBones.handL, CatBones.handR]) {
            final worstJerk = report.jerks
                .where((jerk) => jerk.boneId == hand)
                .map((jerk) => jerk.magnitude)
                .reduce(math.max);
            expect(
              worstJerk,
              lessThan(55),
              reason:
                  '${clip.name} lane $lane $hand warped jerk should stay '
                  'well clear of stop-go territory even at full energy',
            );
          }
        }
      }
    });
  });

  group('upperBodyDynamicsWarpedClip — determinism', () {
    test('shuffled-order frame sampling matches sequential sampling', () {
      final scene = CharacterScene(buildCatInSuitRig());
      final clip = CatClips.sekem;
      final dynamics = laneDynamics(0, 1);
      final warped = upperBodyDynamicsWarpedClip(
        clip,
        dynamics,
        warpBoneIds: kDanceUpperBodyWarpBoneIds,
      );

      final times = [for (var i = 0; i <= 20; i++) clip.duration * i / 20];
      final sequential = {
        for (final t in times) t: scene.frameAt(clip: warped, timeSeconds: t),
      };
      final shuffledTimes = times.reversed.toList()
        ..sort((a, b) => (a * 7919).round().compareTo((b * 7919).round()));
      for (final t in shuffledTimes) {
        final frame = scene.frameAt(clip: warped, timeSeconds: t);
        final expected = sequential[t]!;
        for (final boneId in expected.world.keys) {
          expect(frame.world[boneId], expected.world[boneId]);
        }
      }
    });
  });

  group('upperBodyDynamicsWarpedClip — z-order swap beat alignment', () {
    test(
      "shaku's hand z-order swap window stays on the beat grid, so it is "
      'warp-invariant',
      () {
        final clip = CatClips.shaku;
        expect(clip.zOrderSwaps, isNotEmpty);
        for (final window in clip.zOrderSwaps) {
          final startBeats = window.start * kDanceBeatsPerPhraseLoop;
          final endBeats = window.end * kDanceBeatsPerPhraseLoop;
          expect(
            startBeats,
            closeTo(startBeats.roundToDouble(), 1e-9),
            reason: 'swap start should land on a beat boundary',
          );
          expect(
            endBeats,
            closeTo(endBeats.roundToDouble(), 1e-9),
            reason: 'swap end should land on a beat boundary',
          );
        }
      },
    );
  });
}
