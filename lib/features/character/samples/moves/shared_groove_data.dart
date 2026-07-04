part of '../cat_in_suit.dart';

const _dancePhrase = DancePhrase(
  frameCount: 32,
  supports: [
    DanceSupportSpan(
      footBoneId: CatBones.footL,
      freeFootBoneId: CatBones.footR,
      startFrame: 0,
      endFrame: 16,
      loadFrame: 4,
      releaseFrame: 8,
      maxPelvisDistance: 40,
      pocketScaleY: 0.918,
      label: 'left-foot Shaku low pocket',
    ),
    DanceSupportSpan(
      footBoneId: CatBones.footR,
      freeFootBoneId: CatBones.footL,
      startFrame: 16,
      endFrame: 30,
      loadFrame: 20,
      releaseFrame: 24,
      maxPelvisDistance: 40,
      pocketScaleY: 0.918,
      label: 'right-foot answer pocket',
    ),
    DanceSupportSpan(
      footBoneId: CatBones.footL,
      freeFootBoneId: CatBones.footR,
      startFrame: 30,
      endFrame: 32,
      loadFrame: 31,
      releaseFrame: 32,
      maxPelvisDistance: 32,
      pocketScaleY: 0.956,
      label: 'left-foot loop pickup',
    ),
  ],
  sections: [
    DancePhraseSection(
      name: 'Shaku pocket',
      startFrame: 0,
      endFrame: 8,
      intent: 'low left support with compact crossed-arm groove',
    ),
    DancePhraseSection(
      name: 'Shaku rebound',
      startFrame: 8,
      endFrame: 16,
      intent: 'rebound through the left support without standing tall',
    ),
    DancePhraseSection(
      name: 'answer pocket',
      startFrame: 16,
      endFrame: 24,
      intent: 'right support komole dip with free-left leg texture',
    ),
    DancePhraseSection(
      name: 'toe-flick release',
      startFrame: 24,
      endFrame: 30,
      intent: 'Gbese-flavoured toe-flick release into the loop',
    ),
    DancePhraseSection(
      name: 'loop pickup',
      startFrame: 30,
      endFrame: 32,
      intent: 'compact pickup that lands back into the first pocket',
    ),
  ],
  moves: [
    DanceMoveCue(
      name: 'lead Shaku pocket hit',
      startFrame: 0,
      endFrame: 8,
      accentFrame: 4,
      featuredDancer: 'lead',
      signature: 'left support step-drag, crossed hands, right toe flick',
    ),
    DanceMoveCue(
      name: 'lead rebound shoulder scoop',
      startFrame: 8,
      endFrame: 12,
      accentFrame: 10,
      featuredDancer: 'lead',
      signature: 'compact chest-level scoop without standing tall',
    ),
    DanceMoveCue(
      name: 'right-side camera answer',
      startFrame: 12,
      endFrame: 16,
      accentFrame: 12,
      featuredDancer: 'right',
      signature: 'right dancer inside-arm lift during the camera pass',
    ),
    DanceMoveCue(
      name: 'right-foot groove pocket',
      startFrame: 16,
      endFrame: 24,
      accentFrame: 20,
      featuredDancer: 'lead',
      signature: 'lead drops into a komole dip with lifted free-left toe',
    ),
    DanceMoveCue(
      name: 'left-side camera answer',
      startFrame: 24,
      endFrame: 28,
      accentFrame: 24,
      featuredDancer: 'left',
      signature: 'left dancer inside-arm answer during the camera pass',
    ),
    DanceMoveCue(
      name: 'toe-flick hook reset',
      startFrame: 28,
      endFrame: 32,
      accentFrame: 28,
      featuredDancer: 'lead',
      signature: 'borrowed dab accent with free-left toe flick into hook reset',
    ),
  ],
);

SineChannel _earFollow({
  required double side,
  double amplitude = 0.032,
  double phase = 0.08,
}) => SineChannel(
  amplitude: amplitude * side,
  phase: phase,
  // The main wave gives the ear delayed mass; the beat-rate harmonic adds the
  // tiny rebound that makes it feel attached to a living skull instead of
  // painted on. Keep both bounded because the dance should still read in the
  // hips, shoulders, and feet.
  harmonicAmplitude: amplitude * 0.72 * side,
  harmonicMultiplier: 8,
  harmonicPhase: phase + 0.018,
  scaleXAmplitude: 0.017,
  scaleXHarmonic: 8,
  scaleXPhase: phase + 0.018,
  scaleYAmplitude: -0.015,
  scaleYHarmonic: 8,
  scaleYPhase: phase + 0.018,
);

Map<String, JointChannel> _tailFollowThrough({
  required double amplitude,
  double bias = -0.34,
  double phase = 0.05,
}) => {
  CatBones.tail0: SineChannel(
    amplitude: amplitude * 0.24,
    phase: phase,
    bias: bias,
    harmonicAmplitude: amplitude * 0.04,
    harmonicMultiplier: 4,
    harmonicPhase: phase + 0.12,
  ),
  CatBones.tail1: SineChannel(
    amplitude: amplitude * 0.42,
    phase: phase + 0.08,
    bias: -0.06,
    harmonicAmplitude: amplitude * 0.06,
    harmonicMultiplier: 4,
    harmonicPhase: phase + 0.16,
  ),
  CatBones.tail2: SineChannel(
    amplitude: amplitude * 0.64,
    phase: phase + 0.16,
    bias: -0.04,
    harmonicAmplitude: amplitude * 0.085,
    harmonicMultiplier: 4,
    harmonicPhase: phase + 0.2,
  ),
  CatBones.tail3: SineChannel(
    amplitude: amplitude * 0.9,
    phase: phase + 0.24,
    harmonicAmplitude: amplitude * 0.12,
    harmonicMultiplier: 4,
    harmonicPhase: phase + 0.24,
  ),
  CatBones.tail4: SineChannel(
    amplitude: amplitude * 1.06,
    phase: phase + 0.32,
    harmonicAmplitude: amplitude * 0.16,
    harmonicMultiplier: 8,
    harmonicPhase: phase + 0.28,
  ),
  CatBones.tail5: SineChannel(
    amplitude: amplitude * 1.14,
    phase: phase + 0.4,
    harmonicAmplitude: amplitude * 0.2,
    harmonicMultiplier: 8,
    harmonicPhase: phase + 0.34,
  ),
  CatBones.tail6: SineChannel(
    amplitude: amplitude * 1.18,
    phase: phase + 0.58,
    harmonicAmplitude: amplitude * 0.25,
    harmonicMultiplier: 8,
    harmonicPhase: phase + 0.38,
  ),
};

const _danceLeadMoveSignatures = [
  DanceMoveSignature(
    moveName: 'lead Shaku pocket hit',
    bodyAccentOffsets: [
      DanceBodyAccentOffset(
        offsetFrames: 1,
        radiusFrames: 2,
        // Foot hits on F4; the shoulder/torso answers on F5. That tiny lag
        // is the difference between a posed mascot hit and a danced pocket.
        // Make it a real Lagos-party pocket: the body sinks after the toe
        // step, the hip keeps loading, and the chest bites back a frame late.
        rootDy: 0.7,
        pelvisRotation: -0.03,
        chestRotation: -0.072,
        chestScaleY: 0.974,
        chestScaleX: 1.02,
      ),
      DanceBodyAccentOffset(
        offsetFrames: 3,
        radiusFrames: 1,
        // A small rebound after the F4 foot mark keeps the first phrase from
        // reading as a held mascot pose: hips release first, then the chest
        // answers as the free toe drags back under the suit.
        rootDx: 0.45,
        rootDy: -0.58,
        pelvisRotation: -0.035,
        chestRotation: 0.08,
        chestScaleY: 1.012,
        chestScaleX: 0.996,
      ),
    ],
    ikTargetKeys: {
      CatBones.handL: [
        // Shaku reads as crossed WRISTS in front, not folded forearms buried
        // into the belly. Keep the left wrist just across the sternum, then
        // open it to its own side so the elbow remains visible.
        DanceIkTargetKey(1, x: 14.5, y: -42.5),
        DanceIkTargetKey(2, x: 11.5, y: -43.6),
        DanceIkTargetKey(3, x: -34.8, y: -33.2),
        DanceIkTargetKey(4, x: -52.6, y: -30.4),
        DanceIkTargetKey(5, x: -30.8, y: -30.8),
        DanceIkTargetKey(6, x: -16.7, y: -34.4),
        // Frame 7 bridges the wrist-cross pocket into the shoulder scoop.
        DanceIkTargetKey(7, x: -40.5, y: -22.8),
      ],
      CatBones.handR: [
        DanceIkTargetKey(1, x: -14.2, y: -36.2),
        DanceIkTargetKey(2, x: -11.8, y: -36.8),
        DanceIkTargetKey(3, x: 36.2, y: -33.2),
        DanceIkTargetKey(4, x: 14.8, y: -36.4),
        DanceIkTargetKey(5, x: 48.2, y: -30.2),
        DanceIkTargetKey(6, x: 38.2, y: -29.6),
        DanceIkTargetKey(7, x: 28.2, y: -30.2),
        DanceIkTargetKey(8, x: -14.5, y: -36.4),
      ],
      CatBones.footL: [
        // Plant the support foot for the Shaku/Gbese pocket. Earlier, the
        // support drifted across the first six frames while the free foot was
        // supposedly tapping; that made the whole body feel like it floated
        // over the floor instead of loading one planted leg.
        DanceIkTargetKey(0, x: 13.6, y: 94.4),
        DanceIkTargetKey(1, x: 13.8, y: 94),
        DanceIkTargetKey(2, x: 14.6, y: 93.8),
        DanceIkTargetKey(3, x: 15.2, y: 94.2),
        DanceIkTargetKey(4, x: 16.4, y: 94.8),
        DanceIkTargetKey(5, x: 16.8, y: 95),
        DanceIkTargetKey(6, x: 15.8, y: 95.3),
      ],
      CatBones.footR: [
        // Keep the free-right foot low enough to read as a toe tap, not a
        // tucked invisible lift under the suit. The outward step is paid off
        // by a low drag back through F6-F8 so the lead pocket has a legwork
        // signature, not only changing hand poses.
        DanceIkTargetKey(1, x: 75.4, y: 88.6),
        DanceIkTargetKey(2, x: 84.6, y: 90.6),
        DanceIkTargetKey(3, x: 95.4, y: 93.2),
        DanceIkTargetKey(4, x: 103.8, y: 95.2),
        DanceIkTargetKey(5, x: 90.8, y: 96.9),
        DanceIkTargetKey(6, x: 69.8, y: 97.4),
        DanceIkTargetKey(7, x: 59.8, y: 96.4),
        DanceIkTargetKey(8, x: 59.6, y: 94.6),
      ],
    },
    jointKeys: {
      CatBones.footL: [
        DanceJointKey(2, rotation: -0.28),
        DanceJointKey(4, rotation: -0.15),
        DanceJointKey(6, rotation: -0.04),
        DanceJointKey(8, rotation: -0.08),
      ],
      CatBones.footR: [
        // Toe-in/toe-out pivots on the free foot: small, low, fast texture
        // that reads as Afrobeats legwork instead of a mascot side shuffle.
        DanceJointKey(1, rotation: 0.3),
        DanceJointKey(2, rotation: 0.66),
        DanceJointKey(3, rotation: 0.22),
        DanceJointKey(4, rotation: 0.84),
        DanceJointKey(5, rotation: 0.18),
        DanceJointKey(6, rotation: 0.58),
        DanceJointKey(7, rotation: 0.16),
        DanceJointKey(8, rotation: 0.2),
      ],
      CatBones.armUpperR: [
        DanceJointKey(3, rotation: 0.2),
        DanceJointKey(4, rotation: 0.34),
        DanceJointKey(5, rotation: 0.43),
        DanceJointKey(6, rotation: 0.18),
        DanceJointKey(7, rotation: 0.02),
      ],
      CatBones.armLowerR: [
        DanceJointKey(3, rotation: 0.08),
        DanceJointKey(4, rotation: -0.12),
        DanceJointKey(5, rotation: -0.22),
        DanceJointKey(6, rotation: 0.02),
        DanceJointKey(7, rotation: 0.24),
      ],
    },
  ),
  DanceMoveSignature(
    moveName: 'lead rebound shoulder scoop',
    bodyAccentOffsets: [
      DanceBodyAccentOffset(
        offsetFrames: 0,
        radiusFrames: 2,
        rootDy: 1.05,
        rootRotation: 0.001,
        pelvisRotation: -0.02,
        chestRotation: 0.045,
        chestScaleY: 0.975,
        chestScaleX: 1.026,
      ),
      DanceBodyAccentOffset(
        offsetFrames: 2,
        radiusFrames: 2,
        rootDx: -0.6,
        rootDy: 0.25,
        rootRotation: -0.001,
        pelvisRotation: 0.018,
        chestRotation: -0.105,
        chestScaleY: 0.992,
        chestScaleX: 1.014,
      ),
    ],
    ikTargetKeys: {
      CatBones.handL: [
        // The lead holds a smaller groove while the flankers answer. The
        // previous shoulder-height scoop made frames 9-16 read like everyone
        // was dancing the same boy-band pose instead of call-and-response.
        DanceIkTargetKey(8, x: -60.8, y: 22.4),
        DanceIkTargetKey(9, x: -58.8, y: 14.2),
        DanceIkTargetKey(10, x: -55.4, y: 8.6),
        DanceIkTargetKey(11, x: -54.2, y: 16.4),
        DanceIkTargetKey(12, x: -52.6, y: 24.2),
      ],
      CatBones.handR: [
        DanceIkTargetKey(8, x: 38.2, y: 28.2),
        DanceIkTargetKey(9, x: 48.6, y: 18.4),
        DanceIkTargetKey(10, x: 58.8, y: 8.4),
        DanceIkTargetKey(11, x: 54.6, y: 16.8),
        DanceIkTargetKey(12, x: 46.4, y: 25.2),
      ],
    },
    jointKeys: {
      CatBones.armUpperL: [
        DanceJointKey(9, rotation: 0.44),
        DanceJointKey(10, rotation: 0.48),
        DanceJointKey(11, rotation: 0.32),
        DanceJointKey(12, rotation: 0.08),
      ],
      CatBones.armLowerL: [
        DanceJointKey(9, rotation: 0.12),
        DanceJointKey(10, rotation: 0.08),
        DanceJointKey(11, rotation: 0.18),
        DanceJointKey(12, rotation: 0.38),
      ],
      CatBones.armUpperR: [
        DanceJointKey(9, rotation: 0.1),
        DanceJointKey(10, rotation: 0.22),
        DanceJointKey(11, rotation: 0.08),
        DanceJointKey(12, rotation: -0.16),
      ],
      CatBones.armLowerR: [
        DanceJointKey(9, rotation: 0.42),
        DanceJointKey(10, rotation: 0.48),
        DanceJointKey(11, rotation: 0.56),
        DanceJointKey(12, rotation: 0.44),
      ],
    },
  ),
  DanceMoveSignature(
    moveName: 'right-side camera answer',
    bodyAccentOffsets: [
      DanceBodyAccentOffset(
        offsetFrames: -1,
        radiusFrames: 2,
        rootDx: 0.4,
        rootDy: 0.2,
        pelvisRotation: 0.035,
        chestRotation: -0.07,
        chestScaleY: 0.988,
        chestScaleX: 1.012,
      ),
      DanceBodyAccentOffset(
        offsetFrames: 2,
        radiusFrames: 2,
        rootDx: -0.6,
        rootDy: 1.1,
        rootRotation: -0.001,
        pelvisRotation: -0.05,
        chestRotation: 0.075,
        chestScaleY: 0.968,
        chestScaleX: 1.024,
      ),
    ],
    ikTargetArcs: {
      CatBones.handR: [
        DanceIkTargetArc(
          name: 'right hand camera-answer lift',
          startFrame: 14,
          peakFrame: 16,
          endFrame: 18,
          startX: 54.4,
          startY: 29.2,
          peakX: 78.2,
          peakY: 15.6,
          endX: 72.8,
          endY: 23.2,
          controlPoints: [
            DanceIkTargetArcPoint(15, x: 66.5, y: 24.2),
            DanceIkTargetArcPoint(17, x: 77, y: 19.2),
          ],
        ),
      ],
    },
    ikTargetKeys: {
      CatBones.handL: [
        DanceIkTargetKey(12, x: -58.8, y: 23.6),
        DanceIkTargetKey(13, x: -59.8, y: 25.6),
        DanceIkTargetKey(14, x: -63.8, y: 28.2),
        DanceIkTargetKey(15, x: -66.4, y: 25.8),
        DanceIkTargetKey(16, x: -61.5, y: 28.8),
      ],
      CatBones.footL: [
        DanceIkTargetKey(13, x: -8.8, y: 99.4),
        DanceIkTargetKey(14, x: -12.6, y: 104.6),
        DanceIkTargetKey(15, x: -34.2, y: 101.8),
        DanceIkTargetKey(16, x: -52.2, y: 102.2),
      ],
      CatBones.footR: [
        DanceIkTargetKey(13, x: 27.2, y: 105.8),
        DanceIkTargetKey(14, x: 13.2, y: 106.2),
        DanceIkTargetKey(15, x: 2.2, y: 103.4),
        DanceIkTargetKey(16, x: -4.2, y: 100.2),
      ],
    },
    jointKeys: {
      CatBones.armUpperL: [
        DanceJointKey(12, rotation: 0.08),
        DanceJointKey(13, rotation: 0.16),
        DanceJointKey(14, rotation: 0.24),
        DanceJointKey(15, rotation: 0.18),
        DanceJointKey(16, rotation: 0.06),
      ],
      CatBones.armLowerL: [
        DanceJointKey(12, rotation: 0.38),
        DanceJointKey(13, rotation: 0.32),
        DanceJointKey(14, rotation: 0.24),
        DanceJointKey(15, rotation: 0.06),
        DanceJointKey(16, rotation: -0.16),
      ],
      CatBones.armUpperR: [
        DanceJointKey(14, rotation: -0.3),
        DanceJointKey(15, rotation: -0.44),
        DanceJointKey(16, rotation: -0.62),
        DanceJointKey(17, rotation: -0.58),
        DanceJointKey(18, rotation: -0.5),
      ],
      CatBones.armLowerR: [
        DanceJointKey(14, rotation: 0.34),
        DanceJointKey(15, rotation: 0.22),
        DanceJointKey(16, rotation: 0.04),
        DanceJointKey(17, rotation: 0.18),
        DanceJointKey(18, rotation: 0.34),
      ],
      CatBones.footL: [
        DanceJointKey(13, rotation: 0.42),
        DanceJointKey(14, rotation: 0.08),
        DanceJointKey(15, rotation: 0.28),
      ],
      CatBones.footR: [
        DanceJointKey(13, rotation: -0.22),
        DanceJointKey(14, rotation: -0.02),
        DanceJointKey(15, rotation: -0.14),
      ],
    },
  ),
  DanceMoveSignature(
    moveName: 'right-foot groove pocket',
    bodyAccentOffsets: [
      DanceBodyAccentOffset(
        offsetFrames: -4,
        radiusFrames: 1,
        rootDy: 0.45,
        pelvisRotation: -0.024,
        chestRotation: 0.07,
        chestScaleY: 0.982,
        chestScaleX: 1.012,
      ),
      DanceBodyAccentOffset(
        offsetFrames: -3,
        radiusFrames: 1,
        rootDy: -0.35,
        pelvisRotation: 0.02,
        chestRotation: -0.05,
        chestScaleY: 1.006,
        chestScaleX: 0.996,
      ),
      DanceBodyAccentOffset(
        offsetFrames: -2,
        radiusFrames: 1,
        rootDy: 0.7,
        pelvisRotation: -0.03,
        chestRotation: 0.08,
        chestScaleY: 0.974,
        chestScaleX: 1.018,
      ),
      DanceBodyAccentOffset(
        offsetFrames: 0,
        radiusFrames: 2,
        rootDy: 0.85,
        rootRotation: -0.001,
        pelvisRotation: -0.05,
        chestRotation: 0.09,
        chestScaleY: 0.952,
        chestScaleX: 1.038,
      ),
      DanceBodyAccentOffset(
        offsetFrames: 1,
        radiusFrames: 1,
        // Hold the komole pocket for one extra count after the F20 load:
        // the planted right foot stays fixed while the torso compresses
        // again, so F21 reads as a low dance dip rather than a pass-through.
        rootDy: 0.54,
        pelvisRotation: -0.028,
        chestRotation: 0.035,
        chestScaleY: 0.976,
        chestScaleX: 1.012,
      ),
      DanceBodyAccentOffset(
        offsetFrames: 2,
        radiusFrames: 1,
        // Center close-up release: after the F20 load, the chest rolls back
        // the other way while the hips stay grounded. This keeps the close-up
        // from reading as one long held lean.
        rootDy: -0.62,
        pelvisRotation: 0.045,
        chestRotation: -0.14,
        chestScaleY: 1.01,
        chestScaleX: 0.992,
      ),
    ],
    ikTargetKeys: {
      CatBones.handL: [
        // Close-up hand phrase: sweep up through the chest, answer the
        // shoulder roll, then prepare the F24 outside hook without crossing
        // the left-arm IK branch. A harder F23 throw made the hand solve flip
        // between dense analyzer samples (a visible one-frame snap).
        DanceIkTargetKey(17, x: -58.4, y: 25.2),
        DanceIkTargetKey(18, x: -67.2, y: 18.6),
        DanceIkTargetKey(19, x: -61, y: 15.8),
        // F20 is the body/foot load; the bigger hand reach answers later so
        // the close-up reads as isolation instead of one simultaneous pose.
        DanceIkTargetKey(20, x: -55.8, y: 21.8),
        DanceIkTargetKey(21, x: -65, y: 18.4),
        DanceIkTargetKey(22, x: -72.4, y: 18.2),
        DanceIkTargetKey(23, x: -76.2, y: 18.8),
      ],
      CatBones.handR: [
        DanceIkTargetKey(18, x: 72.8, y: 23.2),
        DanceIkTargetKey(19, x: 74.8, y: 18.4),
        DanceIkTargetKey(20, x: 72.4, y: 18.8),
        DanceIkTargetKey(21, x: 67.4, y: 20.4),
        DanceIkTargetKey(22, x: 88.4, y: 13.9),
        // Prep the F24 left-side feature by already lowering the hand into a
        // chest-level sweep; the old high F23 reach made the transition drop.
        DanceIkTargetKey(23, x: 96, y: 16.8),
      ],
      CatBones.footL: [
        DanceIkTargetKey(18, x: -58, y: 101.4),
        DanceIkTargetKey(19, x: -71.2, y: 98),
        DanceIkTargetKey(20, x: -82.6, y: 96.6),
        DanceIkTargetKey(21, x: -75.6, y: 99.6),
        DanceIkTargetKey(22, x: -54.2, y: 103.8),
        DanceIkTargetKey(23, x: -34.6, y: 103.4),
      ],
      CatBones.footR: [
        // The right foot is the support here; keep it nearly planted while
        // the free-left foot flicks. Otherwise the groove reads as a body
        // slide with a decorative foot, not a weight transfer.
        // Hold the visible shoe contact under the pelvis. The free-left foot
        // supplies the width; moving this support pivot toward zero pushes
        // the rotated shoe contact away from the body.
        DanceIkTargetKey(16, x: -17, y: 103.8),
        DanceIkTargetKey(17, x: -17.3, y: 104.1),
        DanceIkTargetKey(18, x: -17.5, y: 104.4),
        DanceIkTargetKey(19, x: -18, y: 104.6),
        DanceIkTargetKey(20, x: -20.2, y: 104.2),
        DanceIkTargetKey(21, x: -18.8, y: 105.1),
        DanceIkTargetKey(22, x: -17, y: 105.3),
        DanceIkTargetKey(23, x: -15.5, y: 105.2),
      ],
    },
    jointKeys: {
      CatBones.armUpperL: [
        DanceJointKey(19, rotation: -0.06),
        DanceJointKey(20, rotation: 0.34),
        DanceJointKey(21, rotation: 0.12),
      ],
      CatBones.armLowerL: [
        DanceJointKey(19, rotation: 0.02),
        DanceJointKey(20, rotation: -0.12),
        DanceJointKey(21, rotation: -0.02),
      ],
      CatBones.armUpperR: [
        DanceJointKey(19, rotation: -0.48),
        DanceJointKey(20, rotation: -0.18),
        DanceJointKey(21, rotation: -0.36),
      ],
      CatBones.armLowerR: [
        DanceJointKey(19, rotation: 0.34),
        DanceJointKey(20, rotation: 0.56),
        DanceJointKey(21, rotation: 0.42),
      ],
      CatBones.footL: [
        // Free-left toe pivots against the planted right foot. The small
        // rotation alternation matters more than travel distance here.
        DanceJointKey(18, rotation: 0.24),
        DanceJointKey(19, rotation: 0.68),
        DanceJointKey(20, rotation: 0.34),
        DanceJointKey(21, rotation: 0.6),
        DanceJointKey(22, rotation: 0.28),
      ],
      CatBones.footR: [
        DanceJointKey(16, rotation: -0.12),
        DanceJointKey(17, rotation: 0.02),
        DanceJointKey(18, rotation: -0.02),
        DanceJointKey(19, rotation: -0.14),
        DanceJointKey(20, rotation: -0.08),
        DanceJointKey(21, rotation: -0.02),
        DanceJointKey(22, rotation: -0.08),
      ],
    },
  ),
  DanceMoveSignature(
    moveName: 'left-side camera answer',
    bodyAccentOffsets: [
      DanceBodyAccentOffset(
        offsetFrames: 0,
        radiusFrames: 3,
        rootDy: 1.2,
        rootRotation: 0.001,
        pelvisRotation: -0.055,
        chestRotation: 0.07,
        chestScaleY: 0.972,
        chestScaleX: 1.02,
      ),
      DanceBodyAccentOffset(
        offsetFrames: 2,
        radiusFrames: 2,
        rootDy: -0.45,
        rootRotation: 0.001,
        pelvisRotation: 0.05,
        chestRotation: -0.065,
        chestScaleY: 1.01,
        chestScaleX: 0.996,
      ),
    ],
    ikTargetKeys: {
      CatBones.footL: [
        DanceIkTargetKey(24, x: -31.2, y: 102.9),
        DanceIkTargetKey(25, x: -39.4, y: 104.2),
        DanceIkTargetKey(26, x: -32.4, y: 105.4),
        DanceIkTargetKey(27, x: -20.4, y: 103.8),
      ],
    },
  ),
  DanceMoveSignature(
    moveName: 'toe-flick hook reset',
    bodyAccentOffsets: [
      DanceBodyAccentOffset(
        offsetFrames: 1,
        radiusFrames: 1,
        // First beat of the closing button: compact hip scoop before the
        // hook resets. This gives the phrase a visible finish without making
        // frame 32 a different pose from the loop's frame 0.
        rootDx: 0.35,
        rootDy: 0.45,
        pelvisRotation: 0.035,
        chestRotation: -0.09,
        chestScaleY: 0.972,
        chestScaleX: 1.018,
      ),
      DanceBodyAccentOffset(
        offsetFrames: 2,
        radiusFrames: 2,
        // The blink frame was reading like a facial change on a held body.
        // Make F30 a real pocketed pickup so the phrase keeps dancing into
        // the loop seam instead of freezing after the F29 button.
        rootDx: -0.7,
        rootDy: 0.72,
        rootRotation: -0.001,
        pelvisRotation: 0.03,
        chestRotation: -0.055,
        chestScaleY: 0.978,
        chestScaleX: 1.016,
      ),
      DanceBodyAccentOffset(
        offsetFrames: 3,
        radiusFrames: 1,
        // End as a low asymmetrical freeze, not a neutral reset: hip pickup
        // under a counter-shoulder bite, then frame 32 can loop home.
        rootDy: 0.84,
        pelvisRotation: 0.07,
        chestRotation: -0.252,
        chestScaleY: 0.944,
        chestScaleX: 1.036,
      ),
    ],
    ikTargetKeys: {
      CatBones.handL: [
        DanceIkTargetKey(28, x: -82.4, y: 12.4),
        DanceIkTargetKey(29, x: -90, y: 6.8),
        DanceIkTargetKey(30, x: -83.8, y: 11.8),
        DanceIkTargetKey(31, x: -64.8, y: 22.2),
        DanceIkTargetKey(32, x: -59.2, y: 26.4),
      ],
      CatBones.handR: [
        DanceIkTargetKey(28, x: 58.4, y: 22.4),
        DanceIkTargetKey(29, x: 74.6, y: 12.8),
        DanceIkTargetKey(30, x: 76.6, y: 15.2),
        DanceIkTargetKey(31, x: 55.2, y: 28.4),
        DanceIkTargetKey(32, x: 49.2, y: 33.2),
      ],
      CatBones.footL: [
        DanceIkTargetKey(28, x: -27.4, y: 105),
        DanceIkTargetKey(29, x: -14.2, y: 100.2),
        DanceIkTargetKey(30, x: 4.8, y: 96),
        DanceIkTargetKey(31, x: 12.8, y: 93.6),
        DanceIkTargetKey(32, x: 14.2, y: 94.2),
      ],
    },
    jointKeys: {
      CatBones.armUpperL: [
        DanceJointKey(27, rotation: 0.32),
        DanceJointKey(28, rotation: 0.4),
        DanceJointKey(29, rotation: 0.54),
        DanceJointKey(30, rotation: 0.5),
        DanceJointKey(31, rotation: 0.32),
        DanceJointKey(32, rotation: 0.22),
      ],
      CatBones.armLowerL: [
        DanceJointKey(27, rotation: -0.12),
        DanceJointKey(28, rotation: 0.22),
        DanceJointKey(29, rotation: 0.42),
        DanceJointKey(30, rotation: 0.46),
        DanceJointKey(31, rotation: 0.18),
        DanceJointKey(32, rotation: -0.12),
      ],
      CatBones.armUpperR: [
        DanceJointKey(28, rotation: -0.46),
        DanceJointKey(29, rotation: -0.58),
        DanceJointKey(30, rotation: -0.54),
        DanceJointKey(31, rotation: -0.44),
        DanceJointKey(32, rotation: -0.24),
      ],
      CatBones.armLowerR: [
        DanceJointKey(28, rotation: 0.58),
        DanceJointKey(29, rotation: 0.68),
        DanceJointKey(30, rotation: 0.58),
        DanceJointKey(31, rotation: 0.22),
        DanceJointKey(32, rotation: 0.14),
      ],
      CatBones.footL: [
        DanceJointKey(28, rotation: 0.46),
        DanceJointKey(29, rotation: 0.32),
        DanceJointKey(30, rotation: 0.08),
        DanceJointKey(31, rotation: -0.04),
        DanceJointKey(32, rotation: -0.08),
      ],
    },
  ),
];

// The handoff moved 22 -> 14.5 with the R16/R17 re-authoring: the left
// foot now LIFTS into tap-steps at frame 14 (it used to scuff at sole
// level, which is why the old span could stay on it through 22), the
// right foot plants dead at 15, and the bar-period weight sway commits
// the pelvis rightward from frame 16 — so the support solver must follow
// the right foot for all of bar 2. Keeping the old late handoff pinned
// the airborne left foot to its anchor while the deep right-shifted
// pelvis pulled away, over-rotating the hip past its dancer envelope
// (validator-measured 1.76 rad vs the 1.55 limit).
const _shakuContactSpans = [
  GroundSpan(CatBones.footL, 0, 10 / 32),
  GroundSpan(CatBones.footL, 10 / 32, 14.5 / 32),
  GroundSpan(CatBones.footR, 14.5 / 32, 30.125 / 32),
  GroundSpan(CatBones.footL, 30.125 / 32, 1),
];

// Azonto is an in-place mime/waist groove with a long left-foot base and a
// clear step-touch support map: the planted foot holds while the opposite
// foot does the small Azonto redirect. Long blended support windows made the
// quarter view read as sliding feet under a torso swivel.
const _azontoContactSpans = [
  GroundSpan(CatBones.footL, 0, 4 / 32),
  GroundSpan(CatBones.footR, 4 / 32, 8 / 32),
  GroundSpan(CatBones.footL, 8 / 32, 12 / 32),
  GroundSpan(CatBones.footR, 12 / 32, 16 / 32),
  GroundSpan(CatBones.footL, 16 / 32, 20 / 32),
  GroundSpan(CatBones.footR, 20 / 32, 24 / 32),
  GroundSpan(CatBones.footL, 24 / 32, 28 / 32),
  GroundSpan(CatBones.footR, 28 / 32, 1),
];

// 32-frame / two-bar Afrobeats phrase. The support foot changes only on the
// big count windows; the body keeps moving through compression/rebound so the
// groove reads as pocket instead of pose swapping. The last bar deliberately
// loads into frame 1: a clear prep-and-release sells the loop as choreography
// instead of a reset.
const _danceLegUpperLKeys = [
  DanceJointKey(0, rotation: 0.18),
  DanceJointKey(2, rotation: 0.16),
  DanceJointKey(4, rotation: 0.08),
  DanceJointKey(6, rotation: 0.06),
  DanceJointKey(8, rotation: 0.34),
  DanceJointKey(10, rotation: 0.42),
  DanceJointKey(12, rotation: 0.48),
  DanceJointKey(14, rotation: 0.42),
  DanceJointKey(16, rotation: 0.66),
  DanceJointKey(18, rotation: 0.62),
  DanceJointKey(20, rotation: 0.58),
  DanceJointKey(22, rotation: 0.52),
  DanceJointKey(24, rotation: 0.56),
  DanceJointKey(26, rotation: 0.52),
  DanceJointKey(28, rotation: 0.48),
  DanceJointKey(29, rotation: 0.3),
  DanceJointKey(30, rotation: 0.18),
  DanceJointKey(32, rotation: 0.18),
];
const _danceLegUpperRKeys = [
  DanceJointKey(0, rotation: -0.18),
  DanceJointKey(2, rotation: -0.12),
  DanceJointKey(4, rotation: -0.04),
  DanceJointKey(6, rotation: -0.08),
  DanceJointKey(8, rotation: 0.02),
  DanceJointKey(10, rotation: 0.04),
  DanceJointKey(12, rotation: 0.1),
  DanceJointKey(14, rotation: 0.36),
  DanceJointKey(16, rotation: 0.68),
  DanceJointKey(18, rotation: 0.7),
  DanceJointKey(20, rotation: 0.72),
  DanceJointKey(22, rotation: 0.64),
  DanceJointKey(24, rotation: 0.55),
  DanceJointKey(26, rotation: 0.5),
  DanceJointKey(28, rotation: 0.42),
  DanceJointKey(30, rotation: -0.1),
  DanceJointKey(32, rotation: -0.18),
];
const _danceLegLowerLKeys = [
  DanceJointKey(0, rotation: -1.1),
  DanceJointKey(2, rotation: -1.12),
  DanceJointKey(4, rotation: -1.1),
  DanceJointKey(6, rotation: -1.08),
  DanceJointKey(8, rotation: -1.1),
  DanceJointKey(10, rotation: -1.12),
  DanceJointKey(12, rotation: -1.1),
  DanceJointKey(14, rotation: -1.08),
  DanceJointKey(16, rotation: -0.78),
  DanceJointKey(18, rotation: -0.82),
  DanceJointKey(20, rotation: -0.82),
  DanceJointKey(22, rotation: -0.94),
  DanceJointKey(24, rotation: -0.9),
  DanceJointKey(26, rotation: -0.86),
  DanceJointKey(28, rotation: -0.82),
  DanceJointKey(29, rotation: -1.08),
  DanceJointKey(30, rotation: -1.08),
  DanceJointKey(31, rotation: -1.1),
  DanceJointKey(32, rotation: -1.1),
];
const _danceLegLowerRKeys = [
  DanceJointKey(0, rotation: -0.96),
  DanceJointKey(2, rotation: -1.18),
  DanceJointKey(4, rotation: -1.22),
  DanceJointKey(6, rotation: -1.02),
  DanceJointKey(7, rotation: -0.86),
  DanceJointKey(8, rotation: -1.04),
  DanceJointKey(10, rotation: -0.86),
  DanceJointKey(12, rotation: -0.78),
  DanceJointKey(14, rotation: -0.82),
  DanceJointKey(15, rotation: -0.86),
  DanceJointKey(16, rotation: -0.94),
  DanceJointKey(18, rotation: -0.98),
  DanceJointKey(20, rotation: -0.96),
  DanceJointKey(22, rotation: -0.92),
  DanceJointKey(23, rotation: -0.9),
  DanceJointKey(24, rotation: -0.94),
  DanceJointKey(26, rotation: -0.9),
  DanceJointKey(28, rotation: -0.86),
  DanceJointKey(30, rotation: -0.84),
  DanceJointKey(32, rotation: -0.96),
];
const _danceFootLKeys = [
  DanceJointKey(0, rotation: -0.08),
  DanceJointKey(2, rotation: -0.08),
  DanceJointKey(4, rotation: -0.08),
  DanceJointKey(6, rotation: -0.08),
  DanceJointKey(8, rotation: -0.08),
  DanceJointKey(10, rotation: -0.08),
  DanceJointKey(12, rotation: -0.08),
  DanceJointKey(14, rotation: -0.08),
  DanceJointKey(16, rotation: 0.18),
  DanceJointKey(18, rotation: 0.4),
  DanceJointKey(20, rotation: 0.48),
  DanceJointKey(22, rotation: 0.26),
  DanceJointKey(24, rotation: 0.02),
  DanceJointKey(26, rotation: 0.34),
  DanceJointKey(28, rotation: 0.44),
  DanceJointKey(29, rotation: -0.06),
  DanceJointKey(30, rotation: -0.08),
  DanceJointKey(31, rotation: -0.08),
  DanceJointKey(32, rotation: -0.08),
];
final List<DanceJointKey> _danceFootLLeadKeys = _dancePhrase.mergeJointKeys(
  baseKeys: _danceFootLKeys,
  signatures: _danceLeadMoveSignatures,
  boneId: CatBones.footL,
);
final List<DanceJointKey> _danceFootLAccentKeys = _dancePhrase.jointAccentKeys(
  const [
    DanceJointAccent(28, radiusFrames: 2, rotation: 0.055),
  ],
);
const _danceFootRKeys = [
  DanceJointKey(0, rotation: 0.34),
  DanceJointKey(2, rotation: 0.52),
  DanceJointKey(4, rotation: 0.48),
  DanceJointKey(6, rotation: 0.32),
  DanceJointKey(7, rotation: 0.12),
  DanceJointKey(8, rotation: 0.18),
  DanceJointKey(10, rotation: 0.36),
  DanceJointKey(12, rotation: 0.24),
  DanceJointKey(14, rotation: 0.08),
  DanceJointKey(15, rotation: -0.02),
  DanceJointKey(16, rotation: -0.08),
  DanceJointKey(18, rotation: -0.08),
  DanceJointKey(20, rotation: -0.08),
  DanceJointKey(22, rotation: -0.08),
  DanceJointKey(23, rotation: -0.08),
  DanceJointKey(24, rotation: -0.08),
  DanceJointKey(26, rotation: -0.08),
  DanceJointKey(28, rotation: -0.08),
  DanceJointKey(30, rotation: -0.08),
  DanceJointKey(32, rotation: 0.34),
];
final List<DanceJointKey> _danceFootRLeadKeys = _dancePhrase.mergeJointKeys(
  baseKeys: _danceFootRKeys,
  signatures: _danceLeadMoveSignatures,
  boneId: CatBones.footR,
);

// Hip-space foot targets make lower-body choreography explicit: the thigh and
// shin solve toward where the foot should live relative to the pelvis, while
// the separate foot channels still own shoe roll/toe angle.
final List<DanceIkTargetKey> _danceFootLTargetKeys = _dancePhrase
    .mergeIkTargetKeys(
      baseKeys: [
        ...const [
          DanceIkTargetKey(0, x: 9.6, y: 94.4),
          DanceIkTargetKey(1, x: 10.2, y: 93.9),
          DanceIkTargetKey(2, x: 11.7, y: 93.1),
          DanceIkTargetKey(3, x: 14.7, y: 92.2),
          DanceIkTargetKey(4, x: 17.5, y: 91.4),
          DanceIkTargetKey(5, x: 20.3, y: 90.4),
          DanceIkTargetKey(6, x: 19.4, y: 91.1),
          DanceIkTargetKey(7, x: 8.1, y: 95.2),
          DanceIkTargetKey(8, x: -4.8, y: 97.9),
          DanceIkTargetKey(9, x: -8.9, y: 98),
          DanceIkTargetKey(10, x: -10.4, y: 98),
          DanceIkTargetKey(11, x: -13.9, y: 98.4),
          DanceIkTargetKey(12, x: -16.1, y: 98.8),
          DanceIkTargetKey(13, x: -10.7, y: 98.5),
          DanceIkTargetKey(14, x: -9.5, y: 99.3),
          DanceIkTargetKey(15, x: -24, y: 101.5),
          DanceIkTargetKey(16, x: -38, y: 102.1),
          DanceIkTargetKey(17, x: -42, y: 102.3),
          DanceIkTargetKey(18, x: -48, y: 102.8),
          DanceIkTargetKey(19, x: -47.5, y: 103.3),
          DanceIkTargetKey(20, x: -44.5, y: 103.6),
          DanceIkTargetKey(21, x: -39, y: 103.3),
          DanceIkTargetKey(22, x: -34, y: 102.6),
          DanceIkTargetKey(23, x: -31, y: 102.6),
        ],
        ..._dancePhrase.ikTargetArcKeys(
          const [
            DanceIkTargetArc(
              name: 'left foot toe-flick release',
              startFrame: 24,
              peakFrame: 28,
              endFrame: 32,
              startX: -31.2,
              startY: 102.9,
              peakX: -27.4,
              peakY: 105,
              endX: 9.6,
              endY: 94.4,
              controlPoints: [
                DanceIkTargetArcPoint(25, x: -30.7, y: 103.4),
                DanceIkTargetArcPoint(26, x: -29.3, y: 104),
                DanceIkTargetArcPoint(27, x: -30.7, y: 104.7),
                DanceIkTargetArcPoint(29, x: -0.5, y: 97.7),
                DanceIkTargetArcPoint(30, x: 9.8, y: 94.9),
                DanceIkTargetArcPoint(31, x: 10.8, y: 94),
              ],
            ),
          ],
        ),
      ],
      signatures: _danceLeadMoveSignatures,
      targetBoneId: CatBones.footL,
    );
final KeyframeIkTargetChannel _danceFootLTarget = _dancePhrase.ikTargetChannel(
  _danceFootLTargetKeys,
  smooth: true,
);

final KeyframeIkTargetChannel _danceFootRTarget = _dancePhrase.ikTargetChannel(
  _dancePhrase.mergeIkTargetKeys(
    baseKeys: const [
      DanceIkTargetKey(0, x: 62, y: 89.8),
      DanceIkTargetKey(1, x: 72.1, y: 81.1),
      DanceIkTargetKey(2, x: 70.8, y: 78.4),
      DanceIkTargetKey(3, x: 68.3, y: 78.7),
      DanceIkTargetKey(4, x: 65.9, y: 80.6),
      DanceIkTargetKey(5, x: 66.1, y: 83.2),
      DanceIkTargetKey(6, x: 65.2, y: 87.6),
      DanceIkTargetKey(7, x: 57.3, y: 96),
      DanceIkTargetKey(8, x: 57.8, y: 91.1),
      DanceIkTargetKey(9, x: 54.8, y: 94.5),
      DanceIkTargetKey(10, x: 50.9, y: 98.7),
      DanceIkTargetKey(11, x: 47.7, y: 101),
      DanceIkTargetKey(12, x: 42.7, y: 103),
      DanceIkTargetKey(13, x: 32.5, y: 105),
      DanceIkTargetKey(14, x: 19.9, y: 105.5),
      DanceIkTargetKey(15, x: 5.3, y: 103.8),
      DanceIkTargetKey(16, x: -4.2, y: 100.2),
      DanceIkTargetKey(17, x: -2.8, y: 100.6),
      DanceIkTargetKey(18, x: 1.5, y: 101.8),
      DanceIkTargetKey(19, x: 1.2, y: 102.2),
      DanceIkTargetKey(20, x: -2.2, y: 102.5),
      DanceIkTargetKey(21, x: 1.2, y: 102.9),
      DanceIkTargetKey(22, x: 4.6, y: 103.3),
      DanceIkTargetKey(23, x: 6.4, y: 103.1),
      DanceIkTargetKey(24, x: 2, y: 102.4),
      DanceIkTargetKey(25, x: 2.8, y: 102.9),
      DanceIkTargetKey(26, x: 3.4, y: 103.3),
      DanceIkTargetKey(27, x: 4.4, y: 103.7),
      DanceIkTargetKey(28, x: 7.4, y: 104.2),
      DanceIkTargetKey(29, x: 21.8, y: 101.6),
      DanceIkTargetKey(30, x: 34.8, y: 98),
      DanceIkTargetKey(31, x: 49.8, y: 93.2),
      DanceIkTargetKey(32, x: 62, y: 89.8),
    ],
    signatures: _danceLeadMoveSignatures,
    targetBoneId: CatBones.footR,
  ),
  smooth: true,
);

// One synchronized table owns COM/root travel, pelvis groove, and chest
// counter-motion. Root-only pickup frames keep the COM path shaped without
// injecting fake pelvis/chest keys at those frames.
const _danceBodyGrooveKeys = [
  DanceBodyKey(
    0,
    rootDx: -14,
    rootDy: 17.4,
    rootRotation: -0.007,
    pelvisRotation: 0.32,
    chestRotation: -0.09,
    chestScaleY: 0.962,
    chestScaleX: 1.02,
  ),
  DanceBodyKey(
    1,
    rootDx: -18,
    rootDy: 20.45,
    rootRotation: -0.009,
    pelvisRotation: 0.43,
    chestRotation: -0.18,
    chestScaleY: 0.928,
    chestScaleX: 1.042,
  ),
  DanceBodyKey(
    2,
    rootDx: -20,
    rootDy: 19.05,
    rootRotation: -0.009,
    pelvisRotation: 0.38,
    chestRotation: -0.11,
    chestScaleY: 0.924,
    chestScaleX: 1.044,
  ),
  DanceBodyKey(
    3,
    rootDx: -19,
    rootDy: 20.65,
    rootRotation: -0.008,
    pelvisRotation: 0.51,
    chestRotation: -0.235,
    chestScaleY: 0.91,
    chestScaleX: 1.058,
  ),
  DanceBodyKey(
    4,
    rootDx: -11,
    rootDy: 19.8,
    rootRotation: -0.007,
    pelvisRotation: 0.53,
    chestRotation: -0.25,
    chestScaleY: 0.904,
    chestScaleX: 1.062,
  ),
  DanceBodyKey(
    5,
    rootDx: -13,
    rootDy: 20.05,
    rootRotation: -0.006,
    pelvisRotation: 0.44,
    chestRotation: -0.24,
    chestScaleY: 0.918,
    chestScaleX: 1.05,
  ),
  DanceBodyKey(
    6,
    rootDx: -12,
    rootDy: 20.15,
    rootRotation: -0.005,
    pelvisRotation: 0.38,
    chestRotation: -0.18,
    chestScaleY: 0.928,
    chestScaleX: 1.044,
  ),
  DanceBodyKey(7, rootDx: -1, rootDy: 18.4, rootRotation: 0),
  DanceBodyKey(
    8,
    rootDx: 11,
    rootDy: 16.4,
    rootRotation: 0.005,
    pelvisRotation: 0.16,
    chestRotation: -0.02,
    chestScaleY: 0.982,
    chestScaleX: 1.01,
  ),
  DanceBodyKey(
    9,
    rootDx: 12,
    rootDy: 18.2,
    rootRotation: 0.006,
    pelvisRotation: 0.14,
    chestRotation: 0.02,
    chestScaleY: 0.976,
    chestScaleX: 1.014,
  ),
  DanceBodyKey(
    10,
    rootDx: 17,
    rootDy: 16.4,
    rootRotation: 0.008,
    pelvisRotation: 0.08,
    chestRotation: 0.06,
    chestScaleY: 0.97,
    chestScaleX: 1.018,
  ),
  DanceBodyKey(
    11,
    rootDx: 18,
    rootDy: 18.3,
    rootRotation: 0.008,
    pelvisRotation: 0.01,
    chestRotation: 0.045,
    chestScaleY: 0.964,
    chestScaleX: 1.024,
  ),
  DanceBodyKey(
    12,
    rootDx: 18,
    rootDy: 16.4,
    rootRotation: 0.006,
    pelvisRotation: -0.08,
    chestRotation: 0.1,
    chestScaleY: 0.96,
    chestScaleX: 1.024,
  ),
  DanceBodyKey(
    13,
    rootDx: 12,
    rootDy: 15.9,
    rootRotation: 0.004,
    pelvisRotation: -0.16,
    chestRotation: 0.12,
    chestScaleY: 0.968,
    chestScaleX: 1.018,
  ),
  DanceBodyKey(
    14,
    rootDx: 6,
    rootDy: 18.4,
    rootRotation: -0.001,
    pelvisRotation: -0.24,
    chestRotation: 0.14,
    chestScaleY: 0.956,
    chestScaleX: 1.026,
  ),
  DanceBodyKey(
    15,
    rootDx: -1,
    rootDy: 17.6,
    rootRotation: -0.004,
    pelvisRotation: -0.31,
    chestRotation: 0.16,
    chestScaleY: 0.94,
    chestScaleX: 1.038,
  ),
  DanceBodyKey(
    16,
    rootDx: -7,
    rootDy: 17.4,
    rootRotation: -0.006,
    pelvisRotation: -0.36,
    chestRotation: 0.13,
    chestScaleY: 0.954,
    chestScaleX: 1.028,
  ),
  DanceBodyKey(
    17,
    rootDx: -12,
    rootDy: 16,
    rootRotation: -0.007,
    pelvisRotation: -0.37,
    chestRotation: 0.12,
    chestScaleY: 0.964,
    chestScaleX: 1.022,
  ),
  DanceBodyKey(
    18,
    rootDx: -12.6,
    rootDy: 17.7,
    rootRotation: -0.008,
    pelvisRotation: -0.36,
    chestRotation: 0.13,
    chestScaleY: 0.942,
    chestScaleX: 1.036,
  ),
  DanceBodyKey(
    19,
    rootDx: -12.2,
    rootDy: 18.4,
    rootRotation: -0.008,
    pelvisRotation: -0.42,
    chestRotation: 0.135,
    chestScaleY: 0.928,
    chestScaleX: 1.046,
  ),
  DanceBodyKey(
    20,
    rootDx: -11.4,
    rootDy: 18.1,
    rootRotation: -0.006,
    pelvisRotation: -0.47,
    chestRotation: 0.16,
    chestScaleY: 0.914,
    chestScaleX: 1.06,
  ),
  DanceBodyKey(
    21,
    rootDx: -9.8,
    rootDy: 18.7,
    rootRotation: -0.004,
    pelvisRotation: -0.42,
    chestRotation: 0.2,
    chestScaleY: 0.912,
    chestScaleX: 1.056,
  ),
  DanceBodyKey(
    22,
    rootDx: -5,
    rootDy: 16,
    rootRotation: -0.002,
    pelvisRotation: -0.28,
    chestRotation: -0.03,
    chestScaleY: 1,
    chestScaleX: 0.998,
  ),
  DanceBodyKey(
    23,
    rootDx: 2,
    rootDy: 16.1,
    rootRotation: 0.001,
    pelvisRotation: -0.22,
    chestRotation: -0.055,
    chestScaleY: 0.986,
    chestScaleX: 1.006,
  ),
  DanceBodyKey(
    24,
    rootDx: 12,
    rootDy: 19.6,
    rootRotation: 0.007,
    pelvisRotation: -0.24,
    chestRotation: 0.095,
    chestScaleY: 0.958,
    chestScaleX: 1.032,
  ),
  DanceBodyKey(
    26,
    rootDx: 14,
    rootDy: 15.9,
    rootRotation: 0.008,
    pelvisRotation: -0.08,
    chestRotation: -0.06,
    chestScaleY: 0.97,
    chestScaleX: 1.018,
  ),
  DanceBodyKey(
    27,
    rootDx: 13,
    rootDy: 18.4,
    rootRotation: 0.007,
    pelvisRotation: -0.02,
    chestRotation: -0.08,
    chestScaleY: 0.96,
    chestScaleX: 1.024,
  ),
  DanceBodyKey(
    28,
    rootDx: 12,
    rootDy: 17.2,
    rootRotation: 0.006,
    pelvisRotation: 0.04,
    chestRotation: -0.1,
    chestScaleY: 0.96,
    chestScaleX: 1.024,
  ),
  DanceBodyKey(
    29,
    rootDx: 2,
    rootDy: 19.4,
    rootRotation: 0.001,
    pelvisRotation: 0.12,
    chestRotation: -0.18,
    chestScaleY: 0.934,
    chestScaleX: 1.04,
  ),
  DanceBodyKey(
    30,
    rootDx: -7,
    rootDy: 17.8,
    rootRotation: -0.004,
    pelvisRotation: 0.2,
    chestRotation: -0.15,
    chestScaleY: 0.942,
    chestScaleX: 1.034,
  ),
  DanceBodyKey(
    31,
    rootDx: -12.4,
    rootDy: 17.8,
    rootRotation: -0.006,
    pelvisRotation: 0.27,
    chestRotation: -0.125,
    chestScaleY: 0.952,
    chestScaleX: 1.03,
  ),
  DanceBodyKey(
    32,
    rootDx: -14,
    rootDy: 17.4,
    rootRotation: -0.007,
    pelvisRotation: 0.32,
    chestRotation: -0.09,
    chestScaleY: 0.962,
    chestScaleX: 1.02,
  ),
];

const _danceBodyAccents = [
  DanceBodyAccent(
    4,
    radiusFrames: 2,
    rootDy: 0.65,
    rootRotation: -0.0015,
    pelvisRotation: 0.035,
    chestRotation: -0.02,
    chestScaleY: 0.988,
    chestScaleX: 1.01,
  ),
  DanceBodyAccent(
    12,
    radiusFrames: 2,
    rootDx: 1.2,
    rootDy: -0.8,
    rootRotation: 0.001,
    pelvisRotation: -0.025,
    chestRotation: 0.02,
    chestScaleY: 1.008,
    chestScaleX: 0.996,
  ),
  DanceBodyAccent(
    20,
    radiusFrames: 2,
    rootDy: 0.75,
    rootRotation: 0.0015,
    pelvisRotation: -0.035,
    chestRotation: 0.02,
    chestScaleY: 0.988,
    chestScaleX: 1.01,
  ),
  DanceBodyAccent(
    28,
    radiusFrames: 2,
    rootDx: -1.2,
    rootDy: -0.8,
    rootRotation: -0.001,
    pelvisRotation: 0.025,
    chestRotation: -0.02,
    chestScaleY: 1.008,
    chestScaleX: 0.996,
  ),
  DanceBodyAccent(
    30,
    radiusFrames: 2,
    rootDy: 0.3,
    rootRotation: -0.001,
    pelvisRotation: 0.018,
    chestRotation: -0.025,
    chestScaleY: 0.992,
    chestScaleX: 1.006,
  ),
];

final List<DanceBodyKey> _danceBodyAccentKeys = _dancePhrase.bodyAccentKeys([
  ..._danceBodyAccents,
  ..._dancePhrase.moveBodyAccents(_danceLeadMoveSignatures),
]);

const double _bodyRootLeadFrames = -0.35;
const double _bodyPelvisLeadFrames = -0.55;
const double _bodyChestFollowFrames = 0.55;
const double _bodyChestRotationGain = 0.88;
const double _bodyChestScaleGain = 0.92;

double? _scaleBodyValue(double? value, double gain) =>
    value == null ? null : value * gain;

double? _scaleBodyMultiplier(double? value, double gain) =>
    value == null ? null : 1 + (value - 1) * gain;

List<DanceBodyKey> _scaledBodyKeys(
  List<DanceBodyKey> keys, {
  double rootDxGain = 1,
  double rootDyGain = 1,
  double rootRotationGain = 1,
  double pelvisRotationGain = 1,
  double chestRotationGain = 1,
  double chestScaleGain = 1,
}) => [
  for (final key in keys)
    DanceBodyKey(
      key.frame,
      rootDx: _scaleBodyValue(key.rootDx, rootDxGain),
      rootDy: _scaleBodyValue(key.rootDy, rootDyGain),
      rootRotation: _scaleBodyValue(key.rootRotation, rootRotationGain),
      pelvisRotation: _scaleBodyValue(
        key.pelvisRotation,
        pelvisRotationGain,
      ),
      chestRotation: _scaleBodyValue(key.chestRotation, chestRotationGain),
      chestScaleX: _scaleBodyMultiplier(key.chestScaleX, chestScaleGain),
      chestScaleY: _scaleBodyMultiplier(key.chestScaleY, chestScaleGain),
      ease: key.ease,
      microFrames: key.microFrames,
    ),
];

List<DanceBodyKey> _bodyRootLeadKeys(
  List<DanceBodyKey> keys, {
  double microFrames = _bodyRootLeadFrames,
}) => [
  for (final key in keys)
    if (key.hasRoot)
      DanceBodyKey(
        key.frame,
        rootDx: key.rootDx,
        rootDy: key.rootDy,
        rootRotation: key.rootRotation,
        ease: key.ease,
        microFrames: microFrames,
      ),
];

List<DanceBodyKey> _bodyPelvisLeadKeys(
  List<DanceBodyKey> keys, {
  double microFrames = _bodyPelvisLeadFrames,
}) => [
  for (final key in keys)
    if (key.hasPelvis)
      DanceBodyKey(
        key.frame,
        pelvisRotation: key.pelvisRotation,
        ease: key.ease,
        microFrames: microFrames,
      ),
];

List<DanceBodyKey> _bodyChestFollowKeys(
  List<DanceBodyKey> keys, {
  double microFrames = _bodyChestFollowFrames,
  double rotationGain = _bodyChestRotationGain,
  double scaleGain = _bodyChestScaleGain,
}) => [
  for (final key in keys)
    if (key.hasChest)
      DanceBodyKey(
        key.frame,
        chestRotation: _scaleBodyValue(key.chestRotation, rotationGain),
        chestScaleX: _scaleBodyMultiplier(key.chestScaleX, scaleGain),
        chestScaleY: _scaleBodyMultiplier(key.chestScaleY, scaleGain),
        ease: key.ease,
        microFrames: microFrames,
      ),
];

KeyframeRootChannel _bodyRootLeadChannel(
  List<DanceBodyKey> keys, {
  bool smooth = false,
  double microFrames = _bodyRootLeadFrames,
}) => _dancePhrase.bodyRootChannel(
  _bodyRootLeadKeys(keys, microFrames: microFrames),
  smooth: smooth,
);

KeyframeChannel _bodyPelvisLeadChannel(
  List<DanceBodyKey> keys, {
  bool smooth = false,
  double microFrames = _bodyPelvisLeadFrames,
}) => _dancePhrase.bodyPelvisChannel(
  _bodyPelvisLeadKeys(keys, microFrames: microFrames),
  smooth: smooth,
);

KeyframeChannel _bodyChestFollowChannel(
  List<DanceBodyKey> keys, {
  bool smooth = false,
  double microFrames = _bodyChestFollowFrames,
  double rotationGain = _bodyChestRotationGain,
  double scaleGain = _bodyChestScaleGain,
}) => _dancePhrase.bodyChestChannel(
  _bodyChestFollowKeys(
    keys,
    microFrames: microFrames,
    rotationGain: rotationGain,
    scaleGain: scaleGain,
  ),
  smooth: smooth,
);

// Backup-dancer roles are configured as small additive style overlays below.
// The shared base clip owns support timing and body mechanics.
const _danceNeckKeys = [
  Keyframe(p: 0, rotation: 0.004),
  Keyframe(p: 1 / 16, rotation: 0.003),
  Keyframe(p: 1 / 8, rotation: 0.002),
  Keyframe(p: 3 / 16, rotation: -0.001),
  Keyframe(p: 1 / 4, rotation: -0.004),
  Keyframe(p: 5 / 16, rotation: -0.003),
  Keyframe(p: 3 / 8, rotation: -0.001),
  Keyframe(p: 7 / 16, rotation: -0.002),
  Keyframe(p: 1 / 2, rotation: -0.004),
  Keyframe(p: 9 / 16, rotation: -0.003),
  Keyframe(p: 5 / 8, rotation: -0.002),
  Keyframe(p: 11 / 16, rotation: 0.001),
  Keyframe(p: 3 / 4, rotation: 0.004),
  Keyframe(p: 13 / 16, rotation: 0.003),
  Keyframe(p: 7 / 8, rotation: 0.002),
  Keyframe(p: 15 / 16, rotation: 0.002),
  Keyframe(p: 1, rotation: 0.004),
];
const _danceHeadKeys = [
  Keyframe(p: 0),
  Keyframe(p: 1 / 8, rotation: -0.0015),
  Keyframe(p: 1 / 4),
  Keyframe(p: 3 / 8, rotation: 0.0015),
  Keyframe(p: 1 / 2),
  Keyframe(p: 5 / 8, rotation: 0.0015),
  Keyframe(p: 3 / 4),
  Keyframe(p: 7 / 8, rotation: -0.0015),
  Keyframe(p: 1),
];
const _danceEarLKeys = [
  Keyframe(p: 0, rotation: 0.02, scaleX: 1.01, scaleY: 0.99),
  Keyframe(p: 1 / 16, rotation: -0.08, scaleX: 1.05, scaleY: 0.96),
  Keyframe(p: 1 / 8, rotation: -0.12, scaleX: 1.08, scaleY: 0.94),
  Keyframe(p: 3 / 16, rotation: 0.04, scaleX: 0.98, scaleY: 1.03),
  Keyframe(p: 1 / 4, rotation: 0.11, scaleX: 0.96, scaleY: 1.05),
  Keyframe(p: 3 / 8, rotation: 0.03, scaleX: 1.02, scaleY: 0.98),
  Keyframe(p: 7 / 16, rotation: -0.07, scaleX: 1.05, scaleY: 0.96),
  Keyframe(p: 1 / 2, rotation: -0.1, scaleX: 1.07, scaleY: 0.95),
  Keyframe(p: 5 / 8, rotation: -0.13, scaleX: 1.08, scaleY: 0.94),
  Keyframe(p: 11 / 16, rotation: 0.02),
  Keyframe(p: 3 / 4, rotation: 0.08, scaleX: 0.97, scaleY: 1.04),
  Keyframe(p: 13 / 16, rotation: 0.12, scaleX: 0.96, scaleY: 1.05),
  Keyframe(p: 7 / 8, rotation: 0.1, scaleX: 0.97, scaleY: 1.04),
  Keyframe(p: 15 / 16, rotation: 0.04, scaleX: 1.01, scaleY: 0.99),
  Keyframe(p: 1, rotation: 0.02, scaleX: 1.01, scaleY: 0.99),
];
const _danceEarRKeys = [
  Keyframe(p: 0, rotation: -0.018, scaleX: 0.99, scaleY: 1.01),
  Keyframe(p: 1 / 16, rotation: 0.05, scaleX: 0.97, scaleY: 1.04),
  Keyframe(p: 1 / 8, rotation: 0.115, scaleX: 0.95, scaleY: 1.06),
  Keyframe(p: 3 / 16, rotation: -0.03, scaleX: 1.02, scaleY: 0.98),
  Keyframe(p: 1 / 4, rotation: -0.13, scaleX: 1.08, scaleY: 0.94),
  Keyframe(p: 5 / 16, rotation: -0.06, scaleX: 1.04, scaleY: 0.97),
  Keyframe(p: 3 / 8, rotation: -0.03, scaleX: 1.01, scaleY: 0.99),
  Keyframe(p: 1 / 2, rotation: 0.08, scaleX: 0.97, scaleY: 1.04),
  Keyframe(p: 5 / 8, rotation: 0.12, scaleX: 0.95, scaleY: 1.06),
  Keyframe(p: 11 / 16, rotation: -0.02),
  Keyframe(p: 3 / 4, rotation: -0.075, scaleX: 1.04, scaleY: 0.97),
  Keyframe(p: 13 / 16, rotation: -0.11, scaleX: 1.07, scaleY: 0.95),
  Keyframe(p: 7 / 8, rotation: -0.09, scaleX: 1.04, scaleY: 0.97),
  Keyframe(p: 15 / 16, rotation: -0.035),
  Keyframe(p: 1, rotation: -0.018, scaleX: 0.99, scaleY: 1.01),
];
const _danceArmUpperLKeys = [
  DanceJointKey(0, rotation: 0.22),
  DanceJointKey(2, rotation: -0.12),
  DanceJointKey(4, rotation: -0.46),
  DanceJointKey(6, rotation: -0.08),
  DanceJointKey(7, rotation: 0.22),
  DanceJointKey(8, rotation: 0.52),
  DanceJointKey(9, rotation: 0.56),
  DanceJointKey(10, rotation: 0.46),
  DanceJointKey(11, rotation: 0.22),
  DanceJointKey(12, rotation: 0.02),
  DanceJointKey(13, rotation: 0.26),
  DanceJointKey(14, rotation: 0.38),
  DanceJointKey(15, rotation: 0.24),
  DanceJointKey(16, rotation: 0.06),
  DanceJointKey(17, rotation: -0.08),
  DanceJointKey(18, rotation: -0.18),
  DanceJointKey(20, rotation: 0.22),
  DanceJointKey(22, rotation: 0.26),
  DanceJointKey(23, rotation: 0.42),
  DanceJointKey(24, rotation: 0.58),
  DanceJointKey(25, rotation: 0.52),
  DanceJointKey(26, rotation: 0.32),
  DanceJointKey(28, rotation: 0.42),
  DanceJointKey(29, rotation: 0.64),
  DanceJointKey(30, rotation: 0.58),
  DanceJointKey(31, rotation: 0.32),
  DanceJointKey(32, rotation: 0.22),
];
const _danceArmLowerLKeys = [
  DanceJointKey(0, rotation: -0.12),
  DanceJointKey(2, rotation: 0.02),
  DanceJointKey(4, rotation: 0.38),
  DanceJointKey(6, rotation: -0.36),
  DanceJointKey(7, rotation: -0.02),
  DanceJointKey(8, rotation: 0.24),
  DanceJointKey(9, rotation: 0.22),
  DanceJointKey(10, rotation: 0.12),
  DanceJointKey(12, rotation: 0.38),
  DanceJointKey(14, rotation: 0.2),
  DanceJointKey(15, rotation: -0.04),
  DanceJointKey(16, rotation: -0.16),
  DanceJointKey(17, rotation: -0.08),
  DanceJointKey(18, rotation: 0.04),
  DanceJointKey(20, rotation: -0.22),
  DanceJointKey(22, rotation: -0.46),
  DanceJointKey(23, rotation: -0.52),
  DanceJointKey(24, rotation: -0.46),
  DanceJointKey(25, rotation: -0.52),
  DanceJointKey(26, rotation: -0.58),
  DanceJointKey(28, rotation: 0.42),
  DanceJointKey(29, rotation: 0.56),
  DanceJointKey(30, rotation: 0.54),
  DanceJointKey(31, rotation: 0.18),
  DanceJointKey(32, rotation: -0.12),
];
const _danceArmUpperRKeys = [
  DanceJointKey(0, rotation: -0.24),
  DanceJointKey(2, rotation: 0.05),
  DanceJointKey(4, rotation: 0.44),
  DanceJointKey(6, rotation: -0.02),
  DanceJointKey(7, rotation: 0.08),
  DanceJointKey(8, rotation: -0.08),
  DanceJointKey(10, rotation: -0.02),
  DanceJointKey(12, rotation: -0.24),
  DanceJointKey(14, rotation: -0.34),
  DanceJointKey(15, rotation: -0.46),
  DanceJointKey(16, rotation: -0.68),
  DanceJointKey(18, rotation: -0.54),
  DanceJointKey(20, rotation: -0.38),
  DanceJointKey(22, rotation: -0.5),
  DanceJointKey(23, rotation: -0.62),
  DanceJointKey(24, rotation: -0.56),
  DanceJointKey(25, rotation: -0.54),
  DanceJointKey(26, rotation: -0.58),
  DanceJointKey(28, rotation: -0.48),
  DanceJointKey(29, rotation: -0.68),
  DanceJointKey(30, rotation: -0.62),
  DanceJointKey(31, rotation: -0.48),
  DanceJointKey(32, rotation: -0.24),
];
const _danceArmLowerRKeys = [
  DanceJointKey(0, rotation: 0.14),
  DanceJointKey(2, rotation: 0.36),
  DanceJointKey(4, rotation: -0.26),
  DanceJointKey(6, rotation: 0.26),
  DanceJointKey(7, rotation: 0.32),
  DanceJointKey(8, rotation: 0.46),
  DanceJointKey(10, rotation: 0.42),
  DanceJointKey(12, rotation: 0.44),
  DanceJointKey(14, rotation: 0.36),
  DanceJointKey(15, rotation: 0.18),
  DanceJointKey(16, rotation: -0.02),
  DanceJointKey(17, rotation: 0.14),
  DanceJointKey(18, rotation: 0.36),
  DanceJointKey(20, rotation: 0.36),
  DanceJointKey(22, rotation: 0.24),
  DanceJointKey(23, rotation: 0.1),
  DanceJointKey(24, rotation: 0.34),
  DanceJointKey(26, rotation: 0.3),
  DanceJointKey(28, rotation: 0.78),
  DanceJointKey(29, rotation: 0.84),
  DanceJointKey(30, rotation: 0.72),
  DanceJointKey(31, rotation: 0.22),
  DanceJointKey(32, rotation: 0.14),
];
final List<DanceJointKey> _danceArmUpperLLeadKeys = _dancePhrase.mergeJointKeys(
  baseKeys: _danceArmUpperLKeys,
  signatures: _danceLeadMoveSignatures,
  boneId: CatBones.armUpperL,
);
final List<DanceJointKey> _danceArmLowerLLeadKeys = _dancePhrase.mergeJointKeys(
  baseKeys: _danceArmLowerLKeys,
  signatures: _danceLeadMoveSignatures,
  boneId: CatBones.armLowerL,
);
final List<DanceJointKey> _danceArmUpperRLeadKeys = _dancePhrase.mergeJointKeys(
  baseKeys: _danceArmUpperRKeys,
  signatures: _danceLeadMoveSignatures,
  boneId: CatBones.armUpperR,
);
final List<DanceJointKey> _danceArmLowerRLeadKeys = _dancePhrase.mergeJointKeys(
  baseKeys: _danceArmLowerRKeys,
  signatures: _danceLeadMoveSignatures,
  boneId: CatBones.armLowerR,
);

// Torso-space hand paths seeded from the resolved dance phrase, then evened
// at the abrupt section returns. The IK layer now owns hand placement; the FK
// arm channels remain as elbow shape and fallback motion.
final List<DanceIkTargetKey> _danceHandLTargetKeys = _dancePhrase
    .mergeIkTargetKeys(
      baseKeys: [
        ...const [
          DanceIkTargetKey(0, x: -59.2, y: 26.4),
          DanceIkTargetKey(1, x: -41.1, y: 32.7),
          DanceIkTargetKey(2, x: -29.5, y: 32.8),
          DanceIkTargetKey(3, x: -22.8, y: 31.4),
          DanceIkTargetKey(4, x: -14.2, y: 28.8),
          DanceIkTargetKey(5, x: -12.8, y: 30.2),
          DanceIkTargetKey(6, x: -19.7, y: 30.4),
          DanceIkTargetKey(7, x: -57.2, y: 30.2),
          DanceIkTargetKey(8, x: -92.3, y: 11.3),
          DanceIkTargetKey(9, x: -93.1, y: 10.5),
          DanceIkTargetKey(10, x: -82.5, y: 19.1),
          DanceIkTargetKey(11, x: -70.8, y: 24.6),
          DanceIkTargetKey(12, x: -55.7, y: 28.9),
          DanceIkTargetKey(13, x: -75.2, y: 22.2),
          DanceIkTargetKey(14, x: -80.7, y: 19.7),
          DanceIkTargetKey(15, x: -66, y: 25.8),
          DanceIkTargetKey(16, x: -47, y: 31.5),
          DanceIkTargetKey(17, x: -29.7, y: 32.8),
          DanceIkTargetKey(18, x: -25, y: 32.4),
          DanceIkTargetKey(19, x: -40.7, y: 32.8),
          DanceIkTargetKey(20, x: -49.4, y: 31.3),
          DanceIkTargetKey(21, x: -48.5, y: 30.5),
          DanceIkTargetKey(22, x: -45.3, y: 30.3),
          DanceIkTargetKey(23, x: -53.9, y: 27.8),
        ],
        ..._dancePhrase.ikTargetArcKeys(
          const [
            DanceIkTargetArc(
              name: 'left hand count-8 hook',
              startFrame: 24,
              peakFrame: 29,
              endFrame: 32,
              startX: -78.2,
              startY: 22.2,
              peakX: -98,
              peakY: -3,
              endX: -59.2,
              endY: 26.4,
              controlPoints: [
                DanceIkTargetArcPoint(25, x: -71.2, y: 25.2),
                DanceIkTargetArcPoint(26, x: -64.2, y: 27.6),
                DanceIkTargetArcPoint(27, x: -71.6, y: 26.6),
                DanceIkTargetArcPoint(28, x: -88.2, y: 12.9),
                DanceIkTargetArcPoint(30, x: -94, y: 4),
                DanceIkTargetArcPoint(31, x: -65.4, y: 23.2),
              ],
            ),
          ],
        ),
      ],
      signatures: _danceLeadMoveSignatures,
      targetBoneId: CatBones.handL,
    );
final KeyframeIkTargetChannel _danceHandLTarget = _dancePhrase.ikTargetChannel(
  _danceHandLTargetKeys,
  smooth: true,
);

final List<DanceIkTargetKey> _danceHandRTargetKeys = _dancePhrase
    .mergeIkTargetKeys(
      baseKeys: [
        ...const [
          DanceIkTargetKey(0, x: 49.2, y: 33.2),
          DanceIkTargetKey(1, x: 37.2, y: 31.9),
          DanceIkTargetKey(2, x: 22.3, y: 30.8),
          DanceIkTargetKey(3, x: 11.7, y: 29.9),
          DanceIkTargetKey(4, x: 13.6, y: 29.7),
          DanceIkTargetKey(5, x: 21.4, y: 31.9),
          DanceIkTargetKey(6, x: 30.5, y: 32),
          DanceIkTargetKey(7, x: 22, y: 31),
          DanceIkTargetKey(8, x: 27.5, y: 30.4),
          DanceIkTargetKey(9, x: 26.8, y: 30.2),
          DanceIkTargetKey(10, x: 26.1, y: 30.8),
          DanceIkTargetKey(11, x: 31.7, y: 30.8),
          DanceIkTargetKey(12, x: 44.8, y: 30.3),
          DanceIkTargetKey(13, x: 48.6, y: 30.2),
        ],
        ...const [
          DanceIkTargetKey(19, x: 61.4, y: 27.2),
          DanceIkTargetKey(20, x: 60, y: 27.9),
          DanceIkTargetKey(21, x: 63.5, y: 27.3),
          DanceIkTargetKey(22, x: 72.5, y: 23.9),
          DanceIkTargetKey(23, x: 89, y: 14.6),
          DanceIkTargetKey(24, x: 88.4, y: 18.8),
          DanceIkTargetKey(25, x: 85.2, y: 20.9),
          DanceIkTargetKey(26, x: 83.6, y: 21),
          DanceIkTargetKey(27, x: 62.8, y: 25.6),
          DanceIkTargetKey(28, x: 58.4, y: 24.5),
          DanceIkTargetKey(29, x: 64.2, y: 20.7),
          DanceIkTargetKey(30, x: 62.6, y: 22.3),
          DanceIkTargetKey(31, x: 74.1, y: 23.4),
          DanceIkTargetKey(32, x: 49.2, y: 33.2),
        ],
      ],
      signatures: _danceLeadMoveSignatures,
      targetBoneId: CatBones.handR,
    );
final KeyframeIkTargetChannel _danceHandRTarget = _dancePhrase.ikTargetChannel(
  _danceHandRTargetKeys,
  smooth: true,
);

final KeyframeIkTargetChannel _danceHandLAccentOffset = _dancePhrase
    .ikTargetChannel(
      _dancePhrase.ikTargetAccentKeys(
        const [
          DanceIkTargetAccent(8, radiusFrames: 3, x: -2.5, y: -1.5),
        ],
      ),
      smooth: true,
    );

final KeyframeIkTargetChannel _danceHandRAccentOffset = _dancePhrase
    .ikTargetChannel(
      _dancePhrase.ikTargetAccentKeys(
        const [
          DanceIkTargetAccent(16, radiusFrames: 2, x: 5, y: -3),
          DanceIkTargetAccent(24, radiusFrames: 2, x: 4, y: -2.5),
        ],
      ),
      smooth: true,
    );

final IkTargetChannel _danceLeadHandLTarget = _layerDanceTarget(
  _danceHandLTarget,
  _danceHandLAccentOffset,
);

final IkTargetChannel _danceLeadHandRTarget = _layerDanceTarget(
  _danceHandRTarget,
  _danceHandRAccentOffset,
);

final List<LimbIkTarget> _danceLimbTargets = List<LimbIkTarget>.unmodifiable([
  LimbIkTarget(
    upperBoneId: CatBones.armUpperL,
    lowerBoneId: CatBones.armLowerL,
    endBoneId: CatBones.handL,
    anchorBoneId: CatBones.torso,
    channel: _danceLeadHandLTarget,
    bendDirection: -1,
  ),
  LimbIkTarget(
    upperBoneId: CatBones.armUpperR,
    lowerBoneId: CatBones.armLowerR,
    endBoneId: CatBones.handR,
    anchorBoneId: CatBones.torso,
    channel: _danceLeadHandRTarget,
  ),
  LimbIkTarget(
    upperBoneId: CatBones.legUpperL,
    lowerBoneId: CatBones.legLowerL,
    endBoneId: CatBones.footL,
    anchorBoneId: CatBones.hips,
    channel: _danceFootLTarget,
  ),
  LimbIkTarget(
    upperBoneId: CatBones.legUpperR,
    lowerBoneId: CatBones.legLowerR,
    endBoneId: CatBones.footR,
    anchorBoneId: CatBones.hips,
    channel: _danceFootRTarget,
  ),
]);

const _danceBackupLeftStyle = DanceRoleStyle(
  moveBodyAccents: [
    DanceMoveBodyAccent(
      moveName: 'lead Shaku pocket hit',
      offsetFrames: 0,
      // Silver answers inside the lead's 5-8 window: smaller than the lead
      // call, but visible enough that the opening reads call-response instead
      // of three duplicated mascots.
      radiusFrames: 3,
      rootDy: 0.28,
      pelvisRotation: -0.036,
      chestRotation: 0.046,
      chestScaleY: 0.982,
      chestScaleX: 1.014,
    ),
    DanceMoveBodyAccent(
      moveName: 'lead Shaku pocket hit',
      offsetFrames: 2,
      radiusFrames: 2,
      rootDx: -0.28,
      rootDy: 0.42,
      pelvisRotation: -0.046,
      chestRotation: 0.058,
      chestScaleY: 0.976,
      chestScaleX: 1.018,
    ),
    DanceMoveBodyAccent(
      moveName: 'right-side camera answer',
      offsetFrames: 0,
      radiusFrames: 4,
      // Silver answers first: the foot marks F11, then body + hand answer on
      // F12. Keeping the hand one frame behind the foot avoids pose-swapping
      // and matches the lead's body-led opening pocket.
      // The silhouette opens side/low instead of copying the dark cat's high
      // inside-arm answer.
      rootDx: -1.34,
      rootDy: 2.28,
      pelvisRotation: -0.132,
      chestRotation: 0.155,
      chestScaleY: 0.918,
      chestScaleX: 1.056,
    ),
    DanceMoveBodyAccent(
      moveName: 'left-side camera answer',
      offsetFrames: 0,
      // Left-side feature when the camera pans back across the crew.
      radiusFrames: 7,
      rootDx: -0.85,
      rootDy: 0.78,
      pelvisRotation: -0.105,
      chestRotation: 0.12,
      chestScaleY: 0.964,
      chestScaleX: 1.028,
    ),
    DanceMoveBodyAccent(
      moveName: 'left-side camera answer',
      offsetFrames: 1,
      // One-frame-late echo of the lead's F24 step-tap so the side cats
      // answer the groove without exactly mirroring the lead.
      radiusFrames: 4,
      pelvisRotation: 0.012,
      chestRotation: -0.014,
      chestScaleY: 0.998,
      chestScaleX: 1.004,
    ),
    DanceMoveBodyAccent(
      moveName: 'toe-flick hook reset',
      offsetFrames: 2,
      // Pick up the lead's hook on the second half of the reset and release
      // at frame 32 so the loop closes as crew choreography, not a dead stop.
      radiusFrames: 2,
      rootDx: -0.95,
      rootDy: 0.85,
      pelvisRotation: 0.05,
      chestRotation: -0.07,
      chestScaleY: 0.972,
      chestScaleX: 1.02,
    ),
  ],
  moveTargetOffsetArcs: [
    DanceMoveTargetOffsetArc(
      name: 'left backup early inside-hand answer',
      moveName: 'lead Shaku pocket hit',
      targetBoneId: CatBones.handR,
      startOffsetFrames: 0,
      peakOffsetFrames: 2,
      endOffsetFrames: 4,
      peakX: -17.4,
      peakY: -8.8,
      controlPoints: [
        DanceMoveTargetOffsetArcPoint(1, x: -11.6, y: -5.4, weight: 0.72),
        DanceMoveTargetOffsetArcPoint(3, x: -8.2, y: -3.6, weight: 0.68),
      ],
    ),
    DanceMoveTargetOffsetArc(
      name: 'left backup early right-toe answer',
      moveName: 'lead Shaku pocket hit',
      targetBoneId: CatBones.footR,
      startOffsetFrames: 0,
      peakOffsetFrames: 2,
      endOffsetFrames: 4,
      peakX: -8.8,
      peakY: 2.4,
      controlPoints: [
        DanceMoveTargetOffsetArcPoint(1, x: -6.6, y: 1.7, weight: 0.75),
        DanceMoveTargetOffsetArcPoint(3, x: -4.2, y: 1.1, weight: 0.68),
      ],
    ),
    DanceMoveTargetOffsetArc(
      name: 'left backup mirrored flanker answer',
      moveName: 'right-side camera answer',
      targetBoneId: CatBones.handR,
      startOffsetFrames: -3,
      peakOffsetFrames: 0,
      endOffsetFrames: 5,
      peakX: -31.8,
      peakY: -16.4,
      controlPoints: [
        DanceMoveTargetOffsetArcPoint(-2, x: -21.2, y: -10.8, weight: 0.7),
        DanceMoveTargetOffsetArcPoint(-1, x: -26.4, y: -12.8),
        DanceMoveTargetOffsetArcPoint(1, x: -21.2, y: -10.6),
        DanceMoveTargetOffsetArcPoint(2, x: -13.4, y: -6.8, weight: 0.72),
        DanceMoveTargetOffsetArcPoint(3, x: -8.2, y: -4.1, weight: 0.72),
        DanceMoveTargetOffsetArcPoint(4, x: -3.4, y: -1.7, weight: 0.68),
      ],
    ),
    DanceMoveTargetOffsetArc(
      name: 'left backup outside-hand tuck',
      moveName: 'right-side camera answer',
      targetBoneId: CatBones.handL,
      startOffsetFrames: -3,
      peakOffsetFrames: 0,
      endOffsetFrames: 4,
      peakX: 11,
      peakY: 17.8,
      controlPoints: [
        DanceMoveTargetOffsetArcPoint(-2, x: 6.4, y: 10.8, weight: 0.7),
        DanceMoveTargetOffsetArcPoint(-1, x: 9, y: 14.6),
        DanceMoveTargetOffsetArcPoint(1, x: 7.1, y: 11.4),
        DanceMoveTargetOffsetArcPoint(2, x: 4.5, y: 7.2, weight: 0.72),
        DanceMoveTargetOffsetArcPoint(3, x: 2, y: 3.5, weight: 0.7),
      ],
    ),
    DanceMoveTargetOffsetArc(
      name: 'left backup early right-toe step-plant',
      moveName: 'right-side camera answer',
      targetBoneId: CatBones.footR,
      startOffsetFrames: -3,
      peakOffsetFrames: -1,
      endOffsetFrames: 2,
      peakX: 16.2,
      peakY: 4.1,
      controlPoints: [
        DanceMoveTargetOffsetArcPoint(-2, x: 7.4, y: 1.9, weight: 0.7),
        DanceMoveTargetOffsetArcPoint(0, x: 13.2, y: 3.3),
        DanceMoveTargetOffsetArcPoint(1, x: 6.6, y: 1.7),
      ],
    ),
    DanceMoveTargetOffsetArc(
      name: 'left backup inside-hand feature answer',
      moveName: 'left-side camera answer',
      targetBoneId: CatBones.handR,
      startOffsetFrames: -3,
      peakOffsetFrames: 0,
      endOffsetFrames: 4,
      peakX: -12,
      peakY: -7,
      controlPoints: [
        DanceMoveTargetOffsetArcPoint(
          -2,
          x: -4.4,
          y: -2.2,
          weight: 0.65,
        ),
        DanceMoveTargetOffsetArcPoint(-1, x: -9.2, y: -5.8),
        DanceMoveTargetOffsetArcPoint(1, x: -10.2, y: -5.4),
        DanceMoveTargetOffsetArcPoint(2, x: -5.4, y: -2.4, weight: 0.7),
      ],
    ),
    DanceMoveTargetOffsetArc(
      name: 'left backup low inside-hand tableau',
      moveName: 'toe-flick hook reset',
      targetBoneId: CatBones.handR,
      startOffsetFrames: 0,
      peakOffsetFrames: 3,
      endOffsetFrames: 4,
      peakX: -7.8,
      peakY: 7.6,
      controlPoints: [
        DanceMoveTargetOffsetArcPoint(1, x: -4.8, y: 3.2, weight: 0.7),
        DanceMoveTargetOffsetArcPoint(2, x: -15.2, y: 12.4, weight: 0.78),
      ],
    ),
    DanceMoveTargetOffsetArc(
      name: 'left backup low right-toe answer',
      moveName: 'lead Shaku pocket hit',
      targetBoneId: CatBones.footR,
      startOffsetFrames: -2,
      peakOffsetFrames: 0,
      endOffsetFrames: 3,
      peakX: -9.6,
      peakY: 2.1,
      controlPoints: [
        DanceMoveTargetOffsetArcPoint(-1, x: -5.2, y: 1.2, weight: 0.75),
        DanceMoveTargetOffsetArcPoint(1, x: -7.2, y: 1.7, weight: 0.8),
        DanceMoveTargetOffsetArcPoint(2, x: -3.8, y: 0.9, weight: 0.65),
      ],
    ),
  ],
  moveJointAccents: [
    DanceMoveJointAccent(
      moveName: 'lead Shaku pocket hit',
      boneId: CatBones.armUpperR,
      offsetFrames: 0,
      radiusFrames: 3,
      rotation: -0.04,
    ),
    DanceMoveJointAccent(
      moveName: 'lead Shaku pocket hit',
      boneId: CatBones.armUpperR,
      offsetFrames: 2,
      radiusFrames: 2,
      rotation: -0.06,
    ),
    DanceMoveJointAccent(
      moveName: 'right-side camera answer',
      boneId: CatBones.armUpperR,
      offsetFrames: 0,
      radiusFrames: 4,
      rotation: -0.52,
    ),
    DanceMoveJointAccent(
      moveName: 'left-side camera answer',
      boneId: CatBones.armUpperR,
      offsetFrames: 0,
      radiusFrames: 7,
      rotation: -0.26,
    ),
    DanceMoveJointAccent(
      moveName: 'toe-flick hook reset',
      boneId: CatBones.armUpperR,
      offsetFrames: 2,
      radiusFrames: 2,
      rotation: -0.1,
    ),
    DanceMoveJointAccent(
      moveName: 'lead Shaku pocket hit',
      boneId: CatBones.armLowerR,
      offsetFrames: 0,
      radiusFrames: 3,
      rotation: 0.05,
    ),
    DanceMoveJointAccent(
      moveName: 'lead Shaku pocket hit',
      boneId: CatBones.armLowerR,
      offsetFrames: 2,
      radiusFrames: 2,
      rotation: 0.07,
    ),
    DanceMoveJointAccent(
      moveName: 'right-side camera answer',
      boneId: CatBones.armLowerR,
      offsetFrames: 0,
      radiusFrames: 4,
      rotation: 0.52,
    ),
    DanceMoveJointAccent(
      moveName: 'right-side camera answer',
      boneId: CatBones.footR,
      offsetFrames: -1,
      radiusFrames: 3,
      rotation: 0.22,
    ),
    DanceMoveJointAccent(
      moveName: 'left-side camera answer',
      boneId: CatBones.armLowerR,
      offsetFrames: 0,
      radiusFrames: 7,
      rotation: 0.3,
    ),
    DanceMoveJointAccent(
      moveName: 'toe-flick hook reset',
      boneId: CatBones.armLowerR,
      offsetFrames: 2,
      radiusFrames: 2,
      rotation: 0.13,
    ),
  ],
);

const _danceBackupRightStyle = DanceRoleStyle(
  moveBodyAccents: [
    DanceMoveBodyAccent(
      moveName: 'lead Shaku pocket hit',
      offsetFrames: 1,
      // Dark trails silver by a beatlet in the opening 5-8 answer, so the
      // crew reads as a danced ripple instead of a synchronized copy.
      radiusFrames: 2,
      rootDx: 0.22,
      rootDy: 0.26,
      pelvisRotation: 0.03,
      chestRotation: -0.04,
      chestScaleY: 0.984,
      chestScaleX: 1.012,
    ),
    DanceMoveBodyAccent(
      moveName: 'lead Shaku pocket hit',
      offsetFrames: 3,
      radiusFrames: 2,
      rootDx: 0.34,
      rootDy: 0.42,
      pelvisRotation: 0.044,
      chestRotation: -0.056,
      chestScaleY: 0.976,
      chestScaleX: 1.018,
    ),
    DanceMoveBodyAccent(
      moveName: 'right-side camera answer',
      offsetFrames: 3,
      // Dark answers after silver: foot marks F14, then chest/hips and hand
      // bite on F15. That keeps the response body-led instead of snapping
      // every layer into the same frame.
      radiusFrames: 4,
      rootDx: 1.52,
      rootDy: 2.25,
      pelvisRotation: 0.148,
      chestRotation: -0.168,
      chestScaleY: 0.92,
      chestScaleX: 1.054,
    ),
    DanceMoveBodyAccent(
      moveName: 'right-foot groove pocket',
      offsetFrames: 0,
      // Secondary answer to the lead's right-foot groove: lower than the
      // center, with a chest bite that reads as backup choreography instead
      // of idle marking time.
      radiusFrames: 4,
      rootDx: 0.05,
      rootDy: 1.05,
      pelvisRotation: -0.015,
      chestRotation: 0.08,
      chestScaleY: 0.962,
      chestScaleX: 1.024,
    ),
    DanceMoveBodyAccent(
      moveName: 'left-side camera answer',
      offsetFrames: 0,
      // Camera has moved left by this point; keep the right-side dancer from
      // competing with the featured left-side answer.
      radiusFrames: 6,
      rootDx: 0.45,
      rootDy: 0.62,
      pelvisRotation: 0.025,
      chestRotation: -0.03,
      chestScaleY: 0.982,
      chestScaleX: 1.014,
    ),
    DanceMoveBodyAccent(
      moveName: 'left-side camera answer',
      offsetFrames: 1,
      radiusFrames: 4,
      pelvisRotation: -0.012,
      chestRotation: 0.014,
      chestScaleY: 0.998,
      chestScaleX: 1.004,
    ),
    DanceMoveBodyAccent(
      moveName: 'toe-flick hook reset',
      offsetFrames: 3,
      radiusFrames: 1,
      rootDx: 0.65,
      rootDy: 0.55,
      pelvisRotation: -0.03,
      chestRotation: 0.045,
      chestScaleY: 0.986,
      chestScaleX: 1.012,
    ),
  ],
  ikTargetAccents: {
    CatBones.handL: [
      DanceIkTargetAccent(20, radiusFrames: 3, x: 6.4, y: -4.2),
    ],
    CatBones.footR: [
      DanceIkTargetAccent(20, radiusFrames: 2, x: -1.4, y: 0),
    ],
  },
  moveTargetOffsetArcs: [
    DanceMoveTargetOffsetArc(
      name: 'right backup early inside-hand answer',
      moveName: 'lead Shaku pocket hit',
      targetBoneId: CatBones.handL,
      startOffsetFrames: 1,
      peakOffsetFrames: 3,
      endOffsetFrames: 5,
      peakX: 13.2,
      peakY: -7.2,
      controlPoints: [
        DanceMoveTargetOffsetArcPoint(2, x: 9.2, y: -4.8, weight: 0.72),
        DanceMoveTargetOffsetArcPoint(4, x: 7, y: -3.6, weight: 0.65),
      ],
    ),
    DanceMoveTargetOffsetArc(
      name: 'right backup delayed right-toe answer',
      moveName: 'lead Shaku pocket hit',
      targetBoneId: CatBones.footR,
      startOffsetFrames: 1,
      peakOffsetFrames: 3,
      endOffsetFrames: 5,
      peakX: -5.2,
      peakY: 1.5,
      controlPoints: [
        DanceMoveTargetOffsetArcPoint(2, x: -3.6, y: 0.9, weight: 0.72),
        DanceMoveTargetOffsetArcPoint(4, x: -2.4, y: 0.7, weight: 0.65),
      ],
    ),
    DanceMoveTargetOffsetArc(
      name: 'right backup inside-hand camera answer',
      moveName: 'right-side camera answer',
      targetBoneId: CatBones.handL,
      startOffsetFrames: 0,
      peakOffsetFrames: 3,
      endOffsetFrames: 5,
      peakX: 21.2,
      peakY: -20.8,
      controlPoints: [
        DanceMoveTargetOffsetArcPoint(
          1,
          x: 13.2,
          y: -13.7,
          weight: 0.7,
        ),
        DanceMoveTargetOffsetArcPoint(2, x: 17.4, y: -17.2, weight: 0.75),
        DanceMoveTargetOffsetArcPoint(4, x: 14.2, y: -13.8, weight: 0.72),
      ],
    ),
    DanceMoveTargetOffsetArc(
      name: 'right backup outside-hand tuck',
      moveName: 'right-side camera answer',
      targetBoneId: CatBones.handR,
      startOffsetFrames: 0,
      peakOffsetFrames: 3,
      endOffsetFrames: 4,
      peakX: -5.8,
      peakY: 8.5,
      controlPoints: [
        DanceMoveTargetOffsetArcPoint(1, x: -3.6, y: 5, weight: 0.7),
        DanceMoveTargetOffsetArcPoint(2, x: -4.4, y: 6.4, weight: 0.75),
      ],
    ),
    DanceMoveTargetOffsetArc(
      name: 'right backup late right-toe step-plant',
      moveName: 'right-side camera answer',
      targetBoneId: CatBones.footR,
      startOffsetFrames: 0,
      peakOffsetFrames: 2,
      endOffsetFrames: 4,
      peakX: 18.4,
      peakY: 4.3,
      controlPoints: [
        DanceMoveTargetOffsetArcPoint(1, x: 8, y: 2, weight: 0.7),
        DanceMoveTargetOffsetArcPoint(3, x: 7.4, y: 1.7, weight: 0.7),
      ],
    ),
    DanceMoveTargetOffsetArc(
      name: 'right backup high inside-hand tableau',
      moveName: 'toe-flick hook reset',
      targetBoneId: CatBones.handL,
      startOffsetFrames: 1,
      peakOffsetFrames: 3,
      endOffsetFrames: 4,
      peakX: 5.8,
      peakY: -5.8,
      controlPoints: [
        DanceMoveTargetOffsetArcPoint(2, x: 3.4, y: -3.2, weight: 0.72),
      ],
    ),
    DanceMoveTargetOffsetArc(
      name: 'right backup delayed left-toe pickup',
      moveName: 'right-foot groove pocket',
      targetBoneId: CatBones.footL,
      startOffsetFrames: -1,
      peakOffsetFrames: 1,
      endOffsetFrames: 3,
      peakX: 9.2,
      peakY: -5.2,
      controlPoints: [
        DanceMoveTargetOffsetArcPoint(0, x: 5.4, y: -3.2, weight: 0.75),
        DanceMoveTargetOffsetArcPoint(2, x: 6.2, y: -3.5, weight: 0.75),
      ],
    ),
  ],
  moveJointAccents: [
    DanceMoveJointAccent(
      moveName: 'lead Shaku pocket hit',
      boneId: CatBones.armUpperL,
      offsetFrames: 1,
      radiusFrames: 2,
      rotation: 0.04,
    ),
    DanceMoveJointAccent(
      moveName: 'lead Shaku pocket hit',
      boneId: CatBones.armUpperL,
      offsetFrames: 3,
      radiusFrames: 2,
      rotation: 0.05,
    ),
    DanceMoveJointAccent(
      moveName: 'right-side camera answer',
      boneId: CatBones.armUpperL,
      offsetFrames: 3,
      radiusFrames: 4,
      rotation: 0.6,
    ),
    DanceMoveJointAccent(
      moveName: 'right-foot groove pocket',
      boneId: CatBones.armUpperL,
      offsetFrames: 0,
      radiusFrames: 4,
      rotation: 0.13,
    ),
    DanceMoveJointAccent(
      moveName: 'left-side camera answer',
      boneId: CatBones.armUpperL,
      offsetFrames: 0,
      radiusFrames: 6,
      rotation: 0.07,
    ),
    DanceMoveJointAccent(
      moveName: 'toe-flick hook reset',
      boneId: CatBones.armUpperL,
      offsetFrames: 3,
      radiusFrames: 1,
      rotation: 0.08,
    ),
    DanceMoveJointAccent(
      moveName: 'lead Shaku pocket hit',
      boneId: CatBones.armLowerL,
      offsetFrames: 1,
      radiusFrames: 2,
      rotation: 0.05,
    ),
    DanceMoveJointAccent(
      moveName: 'lead Shaku pocket hit',
      boneId: CatBones.armLowerL,
      offsetFrames: 3,
      radiusFrames: 2,
      rotation: 0.06,
    ),
    DanceMoveJointAccent(
      moveName: 'right-side camera answer',
      boneId: CatBones.armLowerL,
      offsetFrames: 3,
      radiusFrames: 4,
      rotation: 0.66,
    ),
    DanceMoveJointAccent(
      moveName: 'right-side camera answer',
      boneId: CatBones.footR,
      offsetFrames: 2,
      radiusFrames: 3,
      rotation: 0.2,
    ),
    DanceMoveJointAccent(
      moveName: 'right-foot groove pocket',
      boneId: CatBones.armLowerL,
      offsetFrames: 0,
      radiusFrames: 4,
      rotation: 0.18,
    ),
    DanceMoveJointAccent(
      moveName: 'left-side camera answer',
      boneId: CatBones.armLowerL,
      offsetFrames: 0,
      radiusFrames: 6,
      rotation: 0.08,
    ),
    DanceMoveJointAccent(
      moveName: 'toe-flick hook reset',
      boneId: CatBones.armLowerL,
      offsetFrames: 3,
      radiusFrames: 1,
      rotation: 0.1,
    ),
  ],
);

List<LimbIkTarget> _danceRoleLimbTargets(DanceRoleStyle style) =>
    List<LimbIkTarget>.unmodifiable([
      _danceLimbTargets[0].withChannel(
        _layerDanceTarget(
          _danceLeadHandLTarget,
          _danceRoleTargetOffset(style, CatBones.handL),
        ),
      ),
      _danceLimbTargets[1].withChannel(
        _layerDanceTarget(
          _danceLeadHandRTarget,
          _danceRoleTargetOffset(style, CatBones.handR),
        ),
      ),
      _danceLimbTargets[2].withChannel(
        _layerDanceTarget(
          _danceFootLTarget,
          _danceRoleTargetOffset(style, CatBones.footL),
        ),
      ),
      _danceLimbTargets[3].withChannel(
        _layerDanceTarget(
          _danceFootRTarget,
          _danceRoleTargetOffset(style, CatBones.footR),
        ),
      ),
    ]);

KeyframeIkTargetChannel _danceRoleTargetOffset(
  DanceRoleStyle style,
  String targetBoneId,
) => _dancePhrase.ikTargetChannel(
  style.ikTargetKeys(_dancePhrase, targetBoneId),
  smooth: true,
);

IkTargetChannel _layerDanceTarget(
  IkTargetChannel base,
  IkTargetChannel? offset,
) => offset == null ? base : LayeredIkTargetChannel([base, offset]);

const _danceTieKeys = [
  Keyframe(p: 0, rotation: 0.02),
  Keyframe(p: 1 / 12, rotation: 0.05),
  Keyframe(p: 2 / 12, rotation: -0.02),
  Keyframe(p: 3 / 12, rotation: -0.05),
  Keyframe(p: 4 / 12, rotation: 0.02),
  Keyframe(p: 5 / 12, rotation: 0.05),
  Keyframe(p: 6 / 12, rotation: -0.02),
  Keyframe(p: 7 / 12, rotation: -0.05),
  Keyframe(p: 8 / 12, rotation: 0.02),
  Keyframe(p: 9 / 12, rotation: -0.07),
  Keyframe(p: 10 / 12, rotation: 0.03),
  Keyframe(p: 11 / 12, rotation: 0.07),
  Keyframe(p: 1, rotation: 0.02),
];
const _danceTieLowerKeys = [
  Keyframe(p: 0, rotation: 0.04),
  Keyframe(p: 1 / 12, rotation: 0.08),
  Keyframe(p: 2 / 12, rotation: 0.02),
  Keyframe(p: 3 / 12, rotation: -0.08),
  Keyframe(p: 4 / 12, rotation: -0.02),
  Keyframe(p: 5 / 12, rotation: 0.08),
  Keyframe(p: 6 / 12, rotation: 0.02),
  Keyframe(p: 7 / 12, rotation: -0.08),
  Keyframe(p: 8 / 12, rotation: -0.02),
  Keyframe(p: 9 / 12, rotation: -0.13),
  Keyframe(p: 10 / 12, rotation: 0.08),
  Keyframe(p: 11 / 12, rotation: 0.13),
  Keyframe(p: 1, rotation: 0.04),
];
