import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/dance_dynamics.dart';
import 'package:dancing_cats/features/character/model/dance_phrase.dart';
import 'package:flutter_test/flutter_test.dart';

/// Returns [value] unchanged, but as a *runtime* value the compiler cannot fold
/// into a constant. Used to force a `const` constructor to run at runtime (so
/// its body is counted by coverage) instead of being const-canonicalised away.
T _runtime<T>(T value) => value;

void main() {
  group('DancePhrase', () {
    const phrase = DancePhrase(
      frameCount: 32,
      supports: [
        DanceSupportSpan(
          footBoneId: 'foot.L',
          freeFootBoneId: 'foot.R',
          startFrame: 0,
          endFrame: 16,
          loadFrame: 4,
          releaseFrame: 8,
          maxPelvisDistance: 36,
          pocketScaleY: 0.92,
          label: 'left pocket',
        ),
        DanceSupportSpan(
          footBoneId: 'foot.R',
          freeFootBoneId: 'foot.L',
          startFrame: 16,
          endFrame: 32,
          loadFrame: 20,
          releaseFrame: 24,
          maxPelvisDistance: 36,
          pocketScaleY: 0.92,
          label: 'right pocket',
        ),
      ],
      sections: [
        DancePhraseSection(
          name: 'pocket',
          startFrame: 0,
          endFrame: 16,
          intent: 'settle over the left support',
        ),
        DancePhraseSection(
          name: 'answer',
          startFrame: 16,
          endFrame: 32,
          intent: 'answer on the right support',
        ),
      ],
      moves: [
        DanceMoveCue(
          name: 'left pocket hit',
          startFrame: 0,
          endFrame: 8,
          accentFrame: 4,
          featuredDancer: 'lead',
          signature: 'low shoulder pocket over left support',
        ),
        DanceMoveCue(
          name: 'right answer hit',
          startFrame: 16,
          endFrame: 32,
          accentFrame: 20,
          featuredDancer: 'right',
          signature: 'right dancer answers with inside-arm lift',
        ),
      ],
    );

    test('maps authored frames to normalized clip phase', () {
      expect(phrase.phaseOf(0), 0);
      expect(phrase.phaseOf(4), 0.125);
      expect(phrase.phaseOf(16), 0.5);
      expect(phrase.phaseOf(32), 1);
    });

    test('compiles labelled support windows into ground spans', () {
      final spans = phrase.contactSpans();

      expect(spans.map((span) => span.bone), ['foot.L', 'foot.R']);
      expect(spans.map((span) => span.start), [0, 0.5]);
      expect(spans.map((span) => span.end), [0.5, 1]);
      expect(phrase.supports.map((support) => support.label), [
        'left pocket',
        'right pocket',
      ]);
    });

    test('looks up support and weight intent by frame and phase', () {
      expect(phrase.supportAtFrame(0).footBoneId, 'foot.L');
      expect(phrase.supportAtFrame(15).footBoneId, 'foot.L');
      expect(phrase.supportAtFrame(16).footBoneId, 'foot.R');
      expect(phrase.supportAtFrame(32).footBoneId, 'foot.L');
      expect(phrase.supportAtPhase(0.62).footBoneId, 'foot.R');

      final rightPocket = phrase.supportAtFrame(20);
      expect(rightPocket.freeFootBoneId, 'foot.L');
      expect(rightPocket.loadFrame, 20);
      expect(rightPocket.releaseFrame, 24);
      expect(rightPocket.maxPelvisDistance, 36);
      expect(rightPocket.pocketScaleY, 0.92);
      expect(rightPocket.containsFrame(31), isTrue);
      expect(rightPocket.containsFrame(32), isFalse);
    });

    test('looks up named choreographic sections by frame and phase', () {
      expect(phrase.sectionAtFrame(0).name, 'pocket');
      expect(phrase.sectionAtFrame(15).name, 'pocket');
      expect(phrase.sectionAtFrame(16).name, 'answer');
      expect(phrase.sectionAtFrame(32).name, 'pocket');
      expect(phrase.sectionAtPhase(0.75).intent, 'answer on the right support');
    });

    test('looks up concrete move cues by frame and phase', () {
      expect(phrase.moveAtFrame(0).name, 'left pocket hit');
      expect(phrase.moveAtFrame(7).accentFrame, 4);
      expect(phrase.moveAtFrame(16).name, 'right answer hit');
      expect(phrase.moveAtFrame(32).featuredDancer, 'lead');
      expect(phrase.moveAtPhase(0.64).signature, contains('inside-arm lift'));
      expect(phrase.moveNamed('right answer hit').accentFrame, 20);
    });

    test('compiles named move signatures over base choreography keys', () {
      const signatures = [
        DanceMoveSignature(
          moveName: 'left pocket hit',
          bodyAccents: [
            DanceBodyAccent(
              4,
              radiusFrames: 2,
              rootDy: 1.5,
              chestRotation: -0.04,
            ),
          ],
          bodyAccentOffsets: [
            DanceBodyAccentOffset(
              offsetFrames: 1,
              radiusFrames: 2,
              pelvisRotation: 0.03,
              chestScaleX: 1.01,
            ),
          ],
          ikTargetArcs: {
            'hand.R': [
              DanceIkTargetArc(
                name: 'right hand move-level lift',
                startFrame: 4,
                peakFrame: 6,
                endFrame: 8,
                startX: 18,
                startY: 30,
                peakX: 48,
                peakY: -12,
                endX: 28,
                endY: 24,
                controlPoints: [
                  DanceIkTargetArcPoint(5, x: 36, y: 10),
                ],
              ),
            ],
          },
          jointKeys: {
            'foot.R': [
              DanceJointKey(4, rotation: 0.32),
            ],
          },
          ikTargetKeys: {
            'hand.L': [
              DanceIkTargetKey(4, x: -42, y: 6),
            ],
            'hand.R': [
              DanceIkTargetKey(6, x: 42, y: -8),
            ],
          },
        ),
      ];

      final bodyAccents = phrase.moveBodyAccents(signatures);
      final footKeys = phrase.mergeJointKeys(
        baseKeys: const [
          DanceJointKey(0, rotation: -0.1),
          DanceJointKey(4),
          DanceJointKey(32, rotation: -0.1),
        ],
        signatures: signatures,
        boneId: 'foot.R',
      );
      final handKeys = phrase.mergeIkTargetKeys(
        baseKeys: const [
          DanceIkTargetKey(0, x: -12, y: 24),
          DanceIkTargetKey(4, x: -18, y: 30),
          DanceIkTargetKey(32, x: -12, y: 24),
        ],
        signatures: signatures,
        targetBoneId: 'hand.L',
      );
      final rightHandKeys = phrase.mergeIkTargetKeys(
        baseKeys: const [
          DanceIkTargetKey(0, x: 12, y: 24),
          DanceIkTargetKey(4, x: 16, y: 28),
          DanceIkTargetKey(8, x: 20, y: 28),
          DanceIkTargetKey(32, x: 12, y: 24),
        ],
        signatures: signatures,
        targetBoneId: 'hand.R',
      );

      expect(bodyAccents.map((accent) => accent.frame), [4, 5]);
      expect(bodyAccents.first.rootDy, 1.5);
      expect(bodyAccents.first.chestRotation, -0.04);
      expect(bodyAccents.last.pelvisRotation, 0.03);
      expect(bodyAccents.last.chestScaleX, 1.01);
      expect(footKeys.map((key) => key.frame), [0, 4, 32]);
      expect(footKeys[1].rotation, 0.32);
      expect(handKeys.map((key) => key.frame), [0, 4, 32]);
      expect(handKeys[1].x, -42);
      expect(handKeys[1].y, 6);
      expect(rightHandKeys.map((key) => key.frame), [0, 4, 5, 6, 8, 32]);
      expect(rightHandKeys[1].x, 18);
      expect(rightHandKeys[2].x, 36);
      expect(rightHandKeys[3].x, 42);
      expect(rightHandKeys[3].y, -8);
      expect(rightHandKeys[4].x, 28);
    });

    test('builds joint channels from frame-addressed keys', () {
      final channel = phrase.jointChannel(
        const [
          DanceJointKey(0, rotation: -0.2),
          DanceJointKey(8, rotation: 0.4, scaleX: 1.1, scaleY: 0.9),
          DanceJointKey(32, rotation: -0.2),
        ],
      );

      expect(channel.sample(0).rotation, closeTo(-0.2, 1e-9));
      expect(channel.sample(0.25).rotation, closeTo(0.4, 1e-9));
      expect(channel.sample(0.25).scaleX, closeTo(1.1, 1e-9));
      expect(channel.sample(1).rotation, closeTo(-0.2, 1e-9));
    });

    test('builds neutralized joint accent pulses', () {
      final keys = phrase.jointAccentKeys(
        const [
          DanceJointAccent(8, radiusFrames: 2, rotation: 0.12),
          DanceJointAccent(
            20,
            radiusFrames: 4,
            rotation: -0.08,
            scaleX: 1.03,
            scaleY: 0.97,
          ),
        ],
      );

      expect(keys.map((key) => key.frame), [6, 8, 10, 16, 20, 24]);
      expect(keys[0].rotation, 0);
      expect(keys[0].scaleX, 1);
      expect(keys[0].scaleY, 1);
      expect(keys[1].rotation, 0.12);
      expect(keys[1].scaleX, 1);
      expect(keys[1].scaleY, 1);
      expect(keys[4].rotation, -0.08);
      expect(keys[4].scaleX, 1.03);
      expect(keys[4].scaleY, 0.97);
    });

    test('builds root channels from frame-addressed keys', () {
      final channel = phrase.rootChannel(
        const [
          DanceRootKey(0, dx: -8, dy: 18),
          DanceRootKey(16, dx: 8, dy: 12, rotation: 0.02),
          DanceRootKey(32, dx: -8, dy: 18),
        ],
      );

      expect(channel.sample(0).dx, closeTo(-8, 1e-9));
      expect(channel.sample(0.5).dx, closeTo(8, 1e-9));
      expect(channel.sample(0.5).dy, closeTo(12, 1e-9));
      expect(channel.sample(0.5).rotation, closeTo(0.02, 1e-9));
      expect(channel.sample(1).dx, closeTo(-8, 1e-9));
    });

    test('builds synchronized body groove channels from mixed keys', () {
      const keys = [
        DanceBodyKey(
          0,
          rootDx: -8,
          rootDy: 18,
          pelvisRotation: -0.2,
          chestRotation: 0.12,
          chestScaleX: 1.02,
          chestScaleY: 0.94,
        ),
        DanceBodyKey(
          8,
          pelvisRotation: 0.4,
          chestRotation: -0.18,
          chestScaleX: 1.06,
          chestScaleY: 0.91,
        ),
        DanceBodyKey(16, rootDx: 8, rootDy: 12, rootRotation: 0.02),
        DanceBodyKey(
          32,
          rootDx: -8,
          rootDy: 18,
          pelvisRotation: -0.2,
          chestRotation: 0.12,
          chestScaleX: 1.02,
          chestScaleY: 0.94,
        ),
      ];

      final root = phrase.bodyRootChannel(keys);
      final pelvis = phrase.bodyPelvisChannel(keys);
      final chest = phrase.bodyChestChannel(keys);

      expect(root.sample(0).dx, closeTo(-8, 1e-9));
      expect(root.sample(0.5).dx, closeTo(8, 1e-9));
      expect(root.sample(0.5).dy, closeTo(12, 1e-9));
      expect(root.sample(0.5).rotation, closeTo(0.02, 1e-9));
      expect(pelvis.sample(0.25).rotation, closeTo(0.4, 1e-9));
      expect(chest.sample(0.25).rotation, closeTo(-0.18, 1e-9));
      expect(chest.sample(0.25).scaleX, closeTo(1.06, 1e-9));
      expect(chest.sample(0.25).scaleY, closeTo(0.91, 1e-9));
    });

    test('body groove keys can land on fractional frames', () {
      const keys = [
        DanceBodyKey(
          0,
          rootDx: 0,
          pelvisRotation: 0,
          chestRotation: 0,
          chestScaleY: 1,
        ),
        DanceBodyKey(
          8,
          rootDx: 12,
          pelvisRotation: 0.4,
          chestRotation: -0.25,
          chestScaleY: 0.9,
          microFrames: 0.5,
        ),
        DanceBodyKey(
          16,
          rootDx: 0,
          pelvisRotation: 0,
          chestRotation: 0,
          chestScaleY: 1,
        ),
      ];

      final root = phrase.bodyRootChannel(keys);
      final pelvis = phrase.bodyPelvisChannel(keys);
      final chest = phrase.bodyChestChannel(keys);
      const fractionalPhase = 8.5 / 32;

      expect(root.sample(fractionalPhase).dx, closeTo(12, 1e-9));
      expect(pelvis.sample(fractionalPhase).rotation, closeTo(0.4, 1e-9));
      expect(chest.sample(fractionalPhase).rotation, closeTo(-0.25, 1e-9));
      expect(chest.sample(fractionalPhase).scaleY, closeTo(0.9, 1e-9));
      expect(root.sample(8 / 32).dx, lessThan(12));
    });

    test('same body frame can lead with pelvis and follow with chest', () {
      const keys = [
        DanceBodyKey(0, pelvisRotation: 0, chestRotation: 0),
        DanceBodyKey(8, pelvisRotation: 1, microFrames: -0.5),
        DanceBodyKey(8, chestRotation: -1, microFrames: 0.5),
        DanceBodyKey(16, pelvisRotation: 0, chestRotation: 0),
      ];

      final pelvis = phrase.bodyPelvisChannel(keys);
      final chest = phrase.bodyChestChannel(keys);

      expect(pelvis.sample(7.5 / 32).rotation, closeTo(1, 1e-9));
      expect(chest.sample(8.5 / 32).rotation, closeTo(-1, 1e-9));
      expect(pelvis.sample(8.5 / 32).rotation, lessThan(1));
      expect(chest.sample(7.5 / 32).rotation, greaterThan(-1));
    });

    test('builds neutralized body accent pulses', () {
      final keys = phrase.bodyAccentKeys(
        const [
          DanceBodyAccent(
            8,
            radiusFrames: 2,
            rootDy: 3,
            pelvisRotation: 0.08,
            chestRotation: -0.04,
            chestScaleX: 1.02,
            chestScaleY: 0.96,
          ),
          DanceBodyAccent(
            20,
            radiusFrames: 4,
            rootDx: -2,
            chestScaleY: 1.02,
          ),
        ],
      );

      expect(keys.map((key) => key.frame), [6, 8, 10, 16, 20, 24]);
      expect(keys[0].rootDy, 0);
      expect(keys[0].pelvisRotation, 0);
      expect(keys[0].chestScaleY, 1);
      expect(keys[1].rootDy, 3);
      expect(keys[1].pelvisRotation, 0.08);
      expect(keys[1].chestRotation, -0.04);
      expect(keys[1].chestScaleX, 1.02);
      expect(keys[1].chestScaleY, 0.96);
      expect(keys[4].rootDx, -2);
      expect(keys[4].rootDy, 0);
      expect(keys[4].chestRotation, 0);
      expect(keys[4].chestScaleX, 1);
      expect(keys[4].chestScaleY, 1.02);
    });

    test('combines overlapping body accent keys on the same frame', () {
      final keys = phrase.bodyAccentKeys(
        const [
          DanceBodyAccent(
            8,
            radiusFrames: 2,
            rootDy: 2,
            pelvisRotation: 0.04,
            chestScaleX: 1.02,
            chestScaleY: 0.98,
          ),
          DanceBodyAccent(
            8,
            radiusFrames: 2,
            rootDy: -1,
            pelvisRotation: 0.03,
            chestRotation: -0.02,
            chestScaleX: 1.01,
            chestScaleY: 0.99,
          ),
        ],
      );

      expect(keys.map((key) => key.frame), [6, 8, 10]);
      final sharedFrame = keys.singleWhere((key) => key.frame == 8);
      expect(sharedFrame.rootDy, 1);
      expect(sharedFrame.pelvisRotation, closeTo(0.07, 1e-9));
      expect(sharedFrame.chestRotation, -0.02);
      expect(sharedFrame.chestScaleX, closeTo(1.0302, 1e-9));
      expect(sharedFrame.chestScaleY, closeTo(0.9702, 1e-9));
    });

    test('builds IK target channels from frame-addressed keys', () {
      final channel = phrase.ikTargetChannel(
        const [
          DanceIkTargetKey(0, x: -12, y: 24, weight: 0.4),
          DanceIkTargetKey(8, x: 18, y: 12),
          DanceIkTargetKey(32, x: -12, y: 24, weight: 0.4),
        ],
      );

      expect(channel.sample(0).x, closeTo(-12, 1e-9));
      expect(channel.sample(0).y, closeTo(24, 1e-9));
      expect(channel.sample(0).weight, closeTo(0.4, 1e-9));
      expect(channel.sample(0.25).x, closeTo(18, 1e-9));
      expect(channel.sample(0.25).y, closeTo(12, 1e-9));
      expect(channel.sample(0.25).weight, closeTo(1, 1e-9));
      expect(channel.sample(1).x, closeTo(-12, 1e-9));
    });

    test('IK target channels can land on fractional frames', () {
      final channel = phrase.ikTargetChannel(
        const [
          DanceIkTargetKey(0, x: -12, y: 24, weight: 0.4),
          DanceIkTargetKey(8, x: 18, y: 12, microFrames: 0.25),
          DanceIkTargetKey(32, x: -12, y: 24, weight: 0.4),
        ],
        microFrames: 0.5,
      );

      expect(channel.sample(8.75 / 32).x, closeTo(18, 1e-9));
      expect(channel.sample(8.75 / 32).y, closeTo(12, 1e-9));
      expect(channel.sample(8 / 32).x, lessThan(18));
    });

    test('builds named IK target arcs from start peak and settle points', () {
      final keys = phrase.ikTargetArcKeys(
        const [
          DanceIkTargetArc(
            name: 'right hand lift',
            startFrame: 12,
            peakFrame: 16,
            endFrame: 20,
            startX: 32,
            startY: 24,
            peakX: 80,
            peakY: 8,
            endX: 52,
            endY: 28,
            weight: 0.8,
            controlPoints: [
              DanceIkTargetArcPoint(14, x: 58, y: 16),
              DanceIkTargetArcPoint(18, x: 68, y: 14, weight: 0.6),
            ],
          ),
        ],
      );

      expect(keys.map((key) => key.frame), [12, 14, 16, 18, 20]);
      expect(keys[0].x, 32);
      expect(keys[0].y, 24);
      expect(keys[0].weight, 0.8);
      expect(keys[1].x, 58);
      expect(keys[1].y, 16);
      expect(keys[1].weight, 0.8);
      expect(keys[2].x, 80);
      expect(keys[2].y, 8);
      expect(keys[3].x, 68);
      expect(keys[3].y, 14);
      expect(keys[3].weight, 0.6);
      expect(keys[4].x, 52);
      expect(keys[4].y, 28);
    });

    test('builds neutralized IK target accent pulses', () {
      final keys = phrase.ikTargetAccentKeys(
        const [
          DanceIkTargetAccent(8, radiusFrames: 2, x: -6, y: -4),
          DanceIkTargetAccent(
            20,
            radiusFrames: 4,
            x: 5,
            y: -3,
            weight: 0.7,
          ),
        ],
      );

      expect(keys.map((key) => key.frame), [6, 8, 10, 16, 20, 24]);
      expect(keys[0].x, 0);
      expect(keys[0].y, 0);
      expect(keys[0].weight, 0);
      expect(keys[1].x, -6);
      expect(keys[1].y, -4);
      expect(keys[1].weight, 1);
      expect(keys[4].x, 5);
      expect(keys[4].y, -3);
      expect(keys[4].weight, 0.7);
    });

    test('builds move-addressed role IK offset arcs from cue timing', () {
      final keys = phrase.moveTargetOffsetArcKeys(
        const [
          DanceMoveTargetOffsetArc(
            name: 'right answer backup hand',
            moveName: 'right answer hit',
            targetBoneId: 'hand.R',
            startOffsetFrames: -2,
            peakOffsetFrames: 0,
            endOffsetFrames: 3,
            peakX: 9,
            peakY: -6,
            controlPoints: [
              DanceMoveTargetOffsetArcPoint(1, x: 5, y: -3, weight: 0.5),
            ],
          ),
          DanceMoveTargetOffsetArc(
            name: 'filtered other hand',
            moveName: 'right answer hit',
            targetBoneId: 'hand.L',
            startOffsetFrames: -1,
            peakOffsetFrames: 0,
            endOffsetFrames: 1,
            peakX: -4,
            peakY: -2,
          ),
        ],
        'hand.R',
      );

      expect(keys.map((key) => key.frame), [18, 20, 21, 23]);
      expect(keys.first.weight, 0);
      expect(keys[1].x, 9);
      expect(keys[1].y, -6);
      expect(keys[2].x, 5);
      expect(keys[2].weight, 0.5);
      expect(keys.last.weight, 0);
    });

    test('collects role style overlays by body, target, and joint', () {
      const style = DanceRoleStyle(
        bodyAccents: [
          DanceBodyAccent(8, radiusFrames: 2, rootDy: 2),
        ],
        moveBodyAccents: [
          DanceMoveBodyAccent(
            moveName: 'right answer hit',
            offsetFrames: 0,
            radiusFrames: 2,
            pelvisRotation: -0.04,
            chestRotation: 0.05,
          ),
        ],
        ikTargetAccents: {
          'hand.L': [
            DanceIkTargetAccent(12, radiusFrames: 2, x: -4, y: -3),
          ],
        },
        ikTargetOffsetArcs: {
          'hand.L': [
            DanceIkTargetOffsetArc(
              name: 'backup hand scoop offset',
              startFrame: 16,
              peakFrame: 18,
              endFrame: 20,
              peakX: 7,
              peakY: -5,
              controlPoints: [
                DanceIkTargetOffsetArcPoint(17, x: 4, y: -2),
                DanceIkTargetOffsetArcPoint(19, x: 5, y: -3, weight: 0.6),
              ],
            ),
          ],
        },
        jointAccents: {
          'torso': [
            DanceJointAccent(20, radiusFrames: 4, rotation: 0.05),
          ],
        },
        moveJointAccents: [
          DanceMoveJointAccent(
            moveName: 'right answer hit',
            boneId: 'arm.R',
            offsetFrames: 0,
            radiusFrames: 2,
            rotation: 0.18,
          ),
        ],
      );

      final bodyKeys = style.bodyKeys(phrase);
      final handKeys = style.ikTargetKeys(phrase, 'hand.L');
      final missingHandKeys = style.ikTargetKeys(phrase, 'hand.R');
      final torsoKeys = style.jointKeys(phrase, 'torso');
      final armKeys = style.jointKeys(phrase, 'arm.R');
      final missingJointKeys = style.jointKeys(phrase, 'head');

      expect(bodyKeys.map((key) => key.frame), [6, 8, 10, 18, 20, 22]);
      expect(bodyKeys[1].rootDy, 2);
      expect(bodyKeys[4].pelvisRotation, -0.04);
      expect(bodyKeys[4].chestRotation, 0.05);
      expect(handKeys.map((key) => key.frame), [
        10,
        12,
        14,
        16,
        17,
        18,
        19,
        20,
      ]);
      expect(handKeys[1].x, -4);
      expect(handKeys[1].y, -3);
      expect(handKeys[3].weight, 0);
      expect(handKeys[4].x, 4);
      expect(handKeys[5].x, 7);
      expect(handKeys[5].y, -5);
      expect(handKeys[6].weight, 0.6);
      expect(handKeys[7].x, 0);
      expect(handKeys[7].y, 0);
      expect(handKeys[7].weight, 0);
      expect(missingHandKeys, isEmpty);
      expect(torsoKeys.map((key) => key.frame), [16, 20, 24]);
      expect(torsoKeys[1].rotation, 0.05);
      expect(armKeys.map((key) => key.frame), [18, 20, 22]);
      expect(armKeys[1].rotation, 0.18);
      expect(missingJointKeys, isEmpty);
    });

    test('rejects keys outside the authored phrase', () {
      expect(() => phrase.phaseOf(-1), throwsRangeError);
      expect(() => phrase.jointKey(33), throwsRangeError);
      expect(
        () => phrase.jointAccentKeys(
          const [DanceJointAccent(1, radiusFrames: 2, rotation: 0.1)],
        ),
        throwsRangeError,
      );
      expect(
        () => phrase.bodyRootChannel(
          const [DanceBodyKey(33, rootDx: 0)],
        ),
        throwsRangeError,
      );
      expect(
        () => phrase.bodyAccentKeys(
          const [DanceBodyAccent(1, radiusFrames: 2, rootDy: 1)],
        ),
        throwsRangeError,
      );
      expect(
        () => phrase.ikTargetAccentKeys(
          const [DanceIkTargetAccent(31, radiusFrames: 2, x: 1, y: 1)],
        ),
        throwsRangeError,
      );
      expect(
        () => phrase.ikTargetArcKeys(
          const [
            DanceIkTargetArc(
              name: 'bad',
              startFrame: 28,
              peakFrame: 31,
              endFrame: 34,
              startX: 0,
              startY: 0,
              peakX: 1,
              peakY: 1,
              endX: 2,
              endY: 2,
            ),
          ],
        ),
        throwsRangeError,
      );
      expect(
        () => phrase.ikTargetOffsetArcKeys(
          const [
            DanceIkTargetOffsetArc(
              name: 'bad offset',
              startFrame: 28,
              peakFrame: 31,
              endFrame: 34,
              peakX: 2,
              peakY: -2,
            ),
          ],
        ),
        throwsRangeError,
      );
      expect(
        () => phrase.ikTargetKey(33, x: 0, y: 0),
        throwsRangeError,
      );
      expect(() => phrase.moveNamed('missing move'), throwsStateError);
      expect(
        () => phrase.moveRoleBodyAccents(
          const [
            DanceMoveBodyAccent(
              moveName: 'missing move',
              offsetFrames: 0,
              radiusFrames: 2,
              rootDy: 1,
            ),
          ],
        ),
        throwsStateError,
      );
      expect(
        () => phrase.moveRoleJointAccents(
          const [
            DanceMoveJointAccent(
              moveName: 'missing move',
              boneId: 'arm.R',
              offsetFrames: 0,
              radiusFrames: 2,
              rotation: 0.1,
            ),
          ],
          'arm.R',
        ),
        throwsStateError,
      );
      expect(
        () => phrase.moveTargetOffsetArcKeys(
          const [
            DanceMoveTargetOffsetArc(
              name: 'missing move arc',
              moveName: 'missing move',
              targetBoneId: 'hand.R',
              startOffsetFrames: -1,
              peakOffsetFrames: 0,
              endOffsetFrames: 1,
              peakX: 1,
              peakY: -1,
            ),
          ],
          'hand.R',
        ),
        throwsStateError,
      );
      expect(
        () => phrase.mergeIkTargetKeys(
          baseKeys: const [],
          signatures: const [
            DanceMoveSignature(
              moveName: 'missing cue',
              ikTargetKeys: {
                'hand.L': [
                  DanceIkTargetKey(4, x: 1, y: 1),
                ],
              },
            ),
          ],
          targetBoneId: 'hand.L',
        ),
        throwsStateError,
      );
      expect(
        () => phrase.mergeJointKeys(
          baseKeys: const [],
          signatures: const [
            DanceMoveSignature(
              moveName: 'left pocket hit',
              jointKeys: {
                'foot.R': [
                  DanceJointKey(33, rotation: 0.1),
                ],
              },
            ),
          ],
          boneId: 'foot.R',
        ),
        throwsRangeError,
      );
      expect(
        () => const DanceSupportSpan(
          footBoneId: 'foot.L',
          freeFootBoneId: 'foot.R',
          startFrame: 20,
          endFrame: 40,
          loadFrame: 24,
          releaseFrame: 32,
          maxPelvisDistance: 36,
          pocketScaleY: 0.92,
          label: 'bad',
        ).toGroundSpan(phrase),
        throwsRangeError,
      );
    });

    test('constructs at runtime and reports empty lookup windows', () {
      // A bare, runtime-built phrase (non-const so the const constructor body
      // is exercised) with no supports/sections/moves: every "at frame" lookup
      // has nothing to return and must surface a clear StateError.
      final bare = DancePhrase(frameCount: _runtime(16), supports: const []);

      expect(bare.frameCount, 16);
      expect(bare.phaseOf(8), closeTo(0.5, 1e-9));
      expect(() => bare.supportAtFrame(0), throwsStateError);
      expect(() => bare.sectionAtFrame(0), throwsStateError);
      expect(() => bare.moveAtFrame(0), throwsStateError);
    });

    test('throws when a frame falls in a gap between move cues', () {
      // The authored cues cover frames 0..8 and 16..32; frame 10 sits in the
      // gap, so no cue covers it.
      expect(() => phrase.moveAtFrame(10), throwsStateError);
      expect(() => phrase.moveAtPhase(10 / 32), throwsStateError);
    });

    test(
      'enforces phrase, support, section, and move-cue frame invariants',
      () {
        expect(
          () => DancePhrase(frameCount: 0, supports: const []),
          throwsA(isA<AssertionError>()),
          reason: 'frameCount must be positive',
        );

        expect(
          () => DanceSupportSpan(
            footBoneId: 'foot.L',
            freeFootBoneId: 'foot.R',
            startFrame: 8,
            endFrame: 8,
            loadFrame: 8,
            releaseFrame: 8,
            maxPelvisDistance: 1,
            pocketScaleY: 0.5,
            label: 'x',
          ),
          throwsA(isA<AssertionError>()),
          reason: 'support span must move forward',
        );
        expect(
          () => DanceSupportSpan(
            footBoneId: 'foot.L',
            freeFootBoneId: 'foot.R',
            startFrame: 0,
            endFrame: 16,
            loadFrame: 16,
            releaseFrame: 8,
            maxPelvisDistance: 1,
            pocketScaleY: 0.5,
            label: 'x',
          ),
          throwsA(isA<AssertionError>()),
          reason: 'load frame must sit inside the span',
        );
        expect(
          () => DanceSupportSpan(
            footBoneId: 'foot.L',
            freeFootBoneId: 'foot.R',
            startFrame: 0,
            endFrame: 16,
            loadFrame: 4,
            releaseFrame: 20,
            maxPelvisDistance: 1,
            pocketScaleY: 0.5,
            label: 'x',
          ),
          throwsA(isA<AssertionError>()),
          reason: 'release frame must finish inside the span',
        );
        expect(
          () => DanceSupportSpan(
            footBoneId: 'foot.L',
            freeFootBoneId: 'foot.R',
            startFrame: 0,
            endFrame: 16,
            loadFrame: 4,
            releaseFrame: 8,
            maxPelvisDistance: 0,
            pocketScaleY: 0.5,
            label: 'x',
          ),
          throwsA(isA<AssertionError>()),
          reason: 'max pelvis distance must be positive',
        );
        expect(
          () => DanceSupportSpan(
            footBoneId: 'foot.L',
            freeFootBoneId: 'foot.R',
            startFrame: 0,
            endFrame: 16,
            loadFrame: 4,
            releaseFrame: 8,
            maxPelvisDistance: 1,
            pocketScaleY: 1.5,
            label: 'x',
          ),
          throwsA(isA<AssertionError>()),
          reason: 'pocket scale must be a 0..1 compression',
        );

        expect(
          () => DancePhraseSection(
            name: 'x',
            startFrame: 5,
            endFrame: 5,
            intent: 'y',
          ),
          throwsA(isA<AssertionError>()),
          reason: 'section must move forward',
        );

        expect(
          () => DanceMoveCue(
            name: 'x',
            startFrame: 8,
            endFrame: 8,
            accentFrame: 8,
            featuredDancer: 'lead',
            signature: 's',
          ),
          throwsA(isA<AssertionError>()),
          reason: 'move cue must move forward',
        );
        expect(
          () => DanceMoveCue(
            name: 'x',
            startFrame: 0,
            endFrame: 8,
            accentFrame: 8,
            featuredDancer: 'lead',
            signature: 's',
          ),
          throwsA(isA<AssertionError>()),
          reason: 'accent frame must sit inside the cue',
        );
      },
    );

    test('enforces positive radius and ordered arcs on accent data', () {
      expect(
        () => DanceMoveJointAccent(
          moveName: 'x',
          boneId: 'b',
          offsetFrames: 0,
          radiusFrames: 0,
        ),
        throwsA(isA<AssertionError>()),
        reason: 'joint accent radius must be positive',
      );
      expect(
        () => DanceBodyAccentOffset(offsetFrames: 1, radiusFrames: 0),
        throwsA(isA<AssertionError>()),
        reason: 'body accent offset radius must be positive',
      );
      expect(
        () => DanceMoveBodyAccent(
          moveName: 'x',
          offsetFrames: 0,
          radiusFrames: 0,
        ),
        throwsA(isA<AssertionError>()),
        reason: 'move body accent radius must be positive',
      );
      expect(
        () => DanceIkTargetAccent(8, radiusFrames: 0, x: 1, y: 1),
        throwsA(isA<AssertionError>()),
        reason: 'IK target accent radius must be positive',
      );

      expect(
        () => DanceIkTargetArc(
          name: 'x',
          startFrame: 6,
          peakFrame: 6,
          endFrame: 8,
          startX: 0,
          startY: 0,
          peakX: 1,
          peakY: 1,
          endX: 2,
          endY: 2,
        ),
        throwsA(isA<AssertionError>()),
        reason: 'arc peak must follow start',
      );
      expect(
        () => DanceIkTargetArc(
          name: 'x',
          startFrame: 4,
          peakFrame: 8,
          endFrame: 8,
          startX: 0,
          startY: 0,
          peakX: 1,
          peakY: 1,
          endX: 2,
          endY: 2,
        ),
        throwsA(isA<AssertionError>()),
        reason: 'arc end must follow peak',
      );

      expect(
        () => DanceMoveTargetOffsetArc(
          name: 'x',
          moveName: 'm',
          targetBoneId: 't',
          startOffsetFrames: 0,
          peakOffsetFrames: 0,
          endOffsetFrames: 2,
          peakX: 1,
          peakY: 1,
        ),
        throwsA(isA<AssertionError>()),
        reason: 'offset arc peak must follow start',
      );
      expect(
        () => DanceMoveTargetOffsetArc(
          name: 'x',
          moveName: 'm',
          targetBoneId: 't',
          startOffsetFrames: -1,
          peakOffsetFrames: 2,
          endOffsetFrames: 2,
          peakX: 1,
          peakY: 1,
        ),
        throwsA(isA<AssertionError>()),
        reason: 'offset arc end must follow peak',
      );
    });

    test('runtime move signature compiles body accents over its cue', () {
      final signature = DanceMoveSignature(
        moveName: _runtime('left pocket hit'),
        bodyAccents: const [
          DanceBodyAccent(4, radiusFrames: 2, rootDy: 1.5),
        ],
      );

      final accents = phrase.moveBodyAccents([signature]);
      expect(accents.single.frame, 4);
      expect(accents.single.rootDy, 1.5);
    });

    test('runtime root key interpolates inside a compiled root channel', () {
      final key = DanceRootKey(_runtime(16), dx: 8, dy: 12, rotation: 0.02);
      final channel = phrase.rootChannel([
        const DanceRootKey(0),
        key,
        const DanceRootKey(32),
      ]);

      final sample = channel.sample(0.5);
      expect(sample.dx, closeTo(8, 1e-9));
      expect(sample.dy, closeTo(12, 1e-9));
      expect(sample.rotation, closeTo(0.02, 1e-9));
    });

    test('runtime arc control point lands inside the compiled arc keys', () {
      final point = DanceIkTargetArcPoint(
        _runtime(14),
        x: 58,
        y: 16,
        weight: 0.6,
      );
      final keys = phrase.ikTargetArcKeys([
        DanceIkTargetArc(
          name: 'right hand lift',
          startFrame: 12,
          peakFrame: 16,
          endFrame: 20,
          startX: 32,
          startY: 24,
          peakX: 80,
          peakY: 8,
          endX: 52,
          endY: 28,
          controlPoints: [point],
        ),
      ]);

      final mid = keys.firstWhere((k) => k.frame == 14);
      expect(mid.x, 58);
      expect(mid.y, 16);
      expect(mid.weight, 0.6);
    });

    test('runtime move-offset control point follows the cue accent frame', () {
      final point = DanceMoveTargetOffsetArcPoint(
        _runtime(1),
        x: 5,
        y: -3,
        weight: 0.5,
      );
      final keys = phrase.moveTargetOffsetArcKeys([
        DanceMoveTargetOffsetArc(
          name: 'right answer backup hand',
          moveName: 'right answer hit',
          targetBoneId: 'hand.R',
          startOffsetFrames: -2,
          peakOffsetFrames: 0,
          endOffsetFrames: 3,
          peakX: 9,
          peakY: -6,
          controlPoints: [point],
        ),
      ], 'hand.R');

      // 'right answer hit' accents at frame 20; offset +1 -> frame 21.
      final k = keys.firstWhere((key) => key.frame == 21);
      expect(k.x, 5);
      expect(k.weight, 0.5);
    });

    test('runtime role style compiles joint accents over the phrase', () {
      final style = DanceRoleStyle(
        jointAccents: _runtime(<String, List<DanceJointAccent>>{
          'torso': [
            const DanceJointAccent(20, radiusFrames: 4, rotation: 0.05),
          ],
        }),
      );

      final torsoKeys = style.jointKeys(phrase, 'torso');
      expect(torsoKeys.map((k) => k.frame), [16, 20, 24]);
      expect(torsoKeys[1].rotation, 0.05);
    });
  });

  group('DanceJointAccent dynamics', () {
    // A bare phrase is enough: the dynamics channel only needs phaseOf/frame
    // bookkeeping, not support lookups. The accent drives in across frames
    // 4 (neutral 0) -> 8 (peak +1) -> 12 (neutral 0).
    const phrase = DancePhrase(frameCount: 32, supports: []);

    KeyframeChannel channelFor(DanceDynamics? dynamics) =>
        phrase.dynamicsJointChannel([
          DanceJointAccent(8, radiusFrames: 4, rotation: 1, dynamics: dynamics),
        ]);

    // Dense samples of the neutral -> peak (frames 4..8) drive-in segment.
    List<double> driveIn(KeyframeChannel ch) => [
      for (var i = 0; i <= 40; i++) ch.sample((4 + i * 0.1) / 32).rotation,
    ];

    test(
      'a Strong+Sudden+Free accent winds up, overshoots, and lands on peak',
      () {
        final ch = channelFor(
          const DanceDynamics(weight: 0.8, time: 0.8, flow: 0.8),
        );
        final samples = driveIn(ch);
        final lo = samples.reduce((a, b) => a < b ? a : b);
        final hi = samples.reduce((a, b) => a > b ? a : b);

        expect(
          lo,
          lessThan(0),
          reason: 'anticipation: the joint pulls back opposite the peak first',
        );
        expect(
          hi,
          greaterThan(1),
          reason: 'overshoot: the joint swings past the peak before settling',
        );
        expect(
          ch.sample(8 / 32).rotation,
          closeTo(1, 1e-9),
          reason: 'the accent still lands exactly on its authored peak',
        );
      },
    );

    test('neutral dynamics neither winds up nor overshoots', () {
      final samples = driveIn(channelFor(DanceDynamics.neutral));
      expect(samples.reduce((a, b) => a < b ? a : b), greaterThan(-1e-9));
      expect(samples.reduce((a, b) => a > b ? a : b), lessThan(1 + 1e-9));
    });

    test('a null-dynamics accent matches a plain easeInOut accent', () {
      final dyn = channelFor(null);
      final plain = phrase.jointChannel(
        phrase.jointAccentKeys([
          const DanceJointAccent(8, radiusFrames: 4, rotation: 1),
        ]),
      );
      for (var f = 4; f <= 12; f++) {
        expect(
          dyn.sample(f / 32).rotation,
          closeTo(plain.sample(f / 32).rotation, 1e-9),
          reason: 'frame $f should be untouched when dynamics is null',
        );
      }
    });
  });

  group('DanceJointAccent sub-frame swing (microFrames)', () {
    const phrase = DancePhrase(frameCount: 32, supports: []);

    // Peak rotation +1 at frame 8; without swing it lands at phase 8/32.
    KeyframeChannel channel(double micro) => phrase.dynamicsJointChannel([
      DanceJointAccent(8, radiusFrames: 4, rotation: 1, microFrames: micro),
    ]);

    test('zero swing lands the peak exactly on the integer frame', () {
      expect(channel(0).sample(8 / 32).rotation, closeTo(1, 1e-9));
    });

    test(
      'a whole-frame positive swing slides the accent later (laid-back)',
      () {
        final laid = channel(1);
        // The peak now lands at (8+1)/32, not 8/32.
        expect(laid.sample(9 / 32).rotation, closeTo(1, 1e-9));
        expect(laid.sample(8 / 32).rotation, lessThan(1));
      },
    );

    test('a fractional offset shifts the peak by less than one frame', () {
      final swung = channel(0.5);
      expect(swung.sample(8.5 / 32).rotation, closeTo(1, 1e-9));
      // It has not yet reached the peak at the integer frame.
      expect(swung.sample(8 / 32).rotation, lessThan(1));
    });

    test('a negative swing pushes the accent earlier', () {
      final pushed = channel(-1);
      expect(pushed.sample(7 / 32).rotation, closeTo(1, 1e-9));
      expect(pushed.sample(8 / 32).rotation, lessThan(1));
    });
  });
}
