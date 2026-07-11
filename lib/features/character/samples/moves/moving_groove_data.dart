part of '../cat_in_suit.dart';

// Pose-first lead hook. Each cell describes one complete silhouette: where the
// weight is, how the ribs oppose it, where both hands and feet are, and how the
// elbows/paws/shoulders support that intention. The runtime tracks below are
// derived from this list; there is no independently tuned hand/body version of
// the lead phrase to drift out of agreement.
const _movingHookLeadPoseCellsLegacy = <DancePoseCell>[
  DancePoseCell(
    frame: 0,
    intent: 'first moving gathers in a flexed right elbow',
    supportFootIds: [CatBones.footL],
    body: DancePoseBody(
      rootDx: -16,
      rootDy: 31,
      pelvisRotation: -0.18,
      chestRotation: 0.14,
      chestScaleY: 0.96,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -78,
        y: -18,
        bendDirection: -1,
        elbowAbduction: 0.05,
      ),
      CatBones.handR: DancePoseLimb(
        x: 78,
        y: -25,
        bendDirection: 1,
        elbowAbduction: 0.08,
      ),
      CatBones.footL: DancePoseLimb(x: -58, y: 110),
      CatBones.footR: DancePoseLimb(x: 58, y: 110),
    },
    joints: {
      CatBones.handL: DancePoseJoint(rotation: -0.07),
      CatBones.handR: DancePoseJoint(rotation: 0.11),
      CatBones.footL: DancePoseJoint(),
      CatBones.footR: DancePoseJoint(),
      CatBones.clavicleL: DancePoseJoint(rotation: -0.01),
      CatBones.clavicleR: DancePoseJoint(rotation: 0.012),
    },
  ),
  DancePoseCell(
    frame: 2,
    intent: 'first moving unfurls diagonally from elbow to paw',
    supportFootIds: [CatBones.footL],
    body: DancePoseBody(
      rootDx: -19,
      rootDy: 18,
      pelvisRotation: -0.22,
      chestRotation: 0.1,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -82,
        y: -12,
        bendDirection: -1,
        elbowAbduction: 0.04,
      ),
      CatBones.handR: DancePoseLimb(
        x: 105,
        y: -82,
        bendDirection: 1,
        elbowAbduction: 0.13,
        tension: 0.3,
      ),
      CatBones.footL: DancePoseLimb(x: -58, y: 110, tension: 0.5),
      CatBones.footR: DancePoseLimb(x: 48, y: 93),
    },
    joints: {
      CatBones.handR: DancePoseJoint(rotation: 0.15),
      CatBones.footR: DancePoseJoint(rotation: -0.08),
      CatBones.clavicleR: DancePoseJoint(rotation: 0.022),
    },
  ),
  DancePoseCell(
    frame: 4,
    intent: 'the reached paw exits around the outside edge, not backward',
    supportFootIds: [CatBones.footL],
    body: DancePoseBody(
      rootDx: -16,
      rootDy: 27,
      pelvisRotation: -0.16,
      chestRotation: 0.18,
      chestScaleX: 1.025,
      chestScaleY: 0.95,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -88,
        y: -18,
        bendDirection: -1,
        elbowAbduction: 0.04,
      ),
      CatBones.handR: DancePoseLimb(
        x: 112,
        y: -58,
        bendDirection: 1,
        elbowAbduction: 0.15,
        tension: 0.12,
      ),
      CatBones.footL: DancePoseLimb(x: -58, y: 110, tension: 0.6),
      CatBones.footR: DancePoseLimb(x: 34, y: 107, tension: 0.35),
    },
    joints: {
      CatBones.handR: DancePoseJoint(rotation: 0.18, tension: 0.1),
      CatBones.footR: DancePoseJoint(rotation: -0.14),
      CatBones.clavicleR: DancePoseJoint(rotation: 0.028),
    },
  ),
  DancePoseCell(
    frame: 6,
    intent: 'the elbow folds through a low circular preparation',
    supportFootIds: [CatBones.footL],
    body: DancePoseBody(
      rootDx: -5,
      rootDy: 16,
      pelvisRotation: -0.05,
      chestRotation: 0.04,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -82,
        y: -30,
        bendDirection: -1,
        elbowAbduction: 0.04,
      ),
      CatBones.handR: DancePoseLimb(
        x: 92,
        y: -22,
        bendDirection: 1,
        elbowAbduction: 0.14,
      ),
      CatBones.footL: DancePoseLimb(x: -58, y: 110, tension: 0.5),
      CatBones.footR: DancePoseLimb(x: 48, y: 94),
    },
    joints: {
      CatBones.handR: DancePoseJoint(rotation: 0.15),
      CatBones.footR: DancePoseJoint(rotation: -0.05),
      CatBones.clavicleR: DancePoseJoint(rotation: 0.012),
    },
  ),
  DancePoseCell(
    frame: 8,
    intent: 'second moving slices outward from the prepared elbow',
    supportFootIds: [CatBones.footR],
    body: DancePoseBody(
      rootDx: 17,
      rootDy: 52,
      pelvisRotation: 0.26,
      chestRotation: -0.22,
      chestScaleX: 1.05,
      chestScaleY: 0.87,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -76,
        y: -46,
        bendDirection: -1,
        elbowAbduction: 0.05,
      ),
      CatBones.handR: DancePoseLimb(
        x: 108,
        y: -42,
        bendDirection: 1,
        elbowAbduction: 0.12,
      ),
      CatBones.footL: DancePoseLimb(x: -58, y: 110),
      CatBones.footR: DancePoseLimb(x: 58, y: 110, tension: 0.6),
    },
    joints: {
      CatBones.handR: DancePoseJoint(rotation: 0.14),
      CatBones.footR: DancePoseJoint(),
      CatBones.clavicleL: DancePoseJoint(rotation: -0.012),
      CatBones.clavicleR: DancePoseJoint(rotation: 0.018),
    },
  ),
  DancePoseCell(
    frame: 9,
    intent: 'offbeat rib rebound with both elbows alive',
    supportFootIds: [CatBones.footR],
    body: DancePoseBody(
      rootDx: 22,
      rootDy: 16,
      pelvisRotation: 0.28,
      chestRotation: 0.14,
      chestScaleX: 1.02,
      chestScaleY: 1.0,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -90,
        y: -70,
        bendDirection: -1,
        elbowAbduction: 0.11,
      ),
      CatBones.handR: DancePoseLimb(
        x: 109,
        y: -36,
        bendDirection: 1,
        elbowAbduction: 0.11,
      ),
      CatBones.footL: DancePoseLimb(x: -48, y: 98),
      CatBones.footR: DancePoseLimb(x: 58, y: 110, tension: 0.55),
    },
    joints: {
      CatBones.handL: DancePoseJoint(rotation: -0.13),
      CatBones.handR: DancePoseJoint(rotation: 0.15),
      CatBones.footL: DancePoseJoint(rotation: 0.05),
      CatBones.clavicleL: DancePoseJoint(rotation: -0.02),
      CatBones.clavicleR: DancePoseJoint(rotation: 0.022),
    },
  ),
  DancePoseCell(
    frame: 10,
    intent: 'third moving changes level while the left paw joins',
    supportFootIds: [CatBones.footR],
    body: DancePoseBody(
      rootDx: 19,
      rootDy: 46,
      pelvisRotation: 0.27,
      chestRotation: 0.08,
      chestScaleX: 1.04,
      chestScaleY: 0.9,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -100,
        y: -60,
        bendDirection: -1,
        elbowAbduction: 0.07,
      ),
      CatBones.handR: DancePoseLimb(
        x: 110,
        y: -30,
        bendDirection: 1,
        elbowAbduction: 0.11,
      ),
      CatBones.footL: DancePoseLimb(x: -40, y: 92),
      CatBones.footR: DancePoseLimb(x: 58, y: 110, tension: 0.5),
    },
    joints: {
      CatBones.handR: DancePoseJoint(rotation: 0.13),
      CatBones.footL: DancePoseJoint(rotation: 0.08),
      CatBones.clavicleL: DancePoseJoint(rotation: -0.018),
    },
  ),
  DancePoseCell(
    frame: 11,
    intent: 'second offbeat tick reverses the ribs over the crossing toe',
    supportFootIds: [CatBones.footR],
    body: DancePoseBody(
      rootDx: 18,
      rootDy: 14,
      pelvisRotation: 0.2,
      chestRotation: -0.28,
      chestScaleX: 1.03,
      chestScaleY: 1.0,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -104,
        y: -44,
        bendDirection: -1,
        elbowAbduction: 0.1,
      ),
      CatBones.handR: DancePoseLimb(
        x: 100,
        y: -24,
        bendDirection: 1,
        elbowAbduction: 0.1,
      ),
      CatBones.footL: DancePoseLimb(x: -22, y: 98),
      CatBones.footR: DancePoseLimb(x: 58, y: 110, tension: 0.55),
    },
    joints: {
      CatBones.handL: DancePoseJoint(rotation: -0.11),
      CatBones.handR: DancePoseJoint(rotation: 0.12),
      CatBones.footL: DancePoseJoint(rotation: 0.11),
      CatBones.clavicleL: DancePoseJoint(rotation: 0.06),
      CatBones.clavicleR: DancePoseJoint(rotation: 0.024),
    },
  ),
  DancePoseCell(
    frame: 12,
    intent: 'both paws finish through a low outside curve',
    supportFootIds: [CatBones.footR],
    body: DancePoseBody(
      rootDx: 16,
      rootDy: 40,
      pelvisRotation: 0.16,
      chestRotation: -0.24,
      chestScaleX: 1.04,
      chestScaleY: 0.92,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -108,
        y: -28,
        bendDirection: -1,
        elbowAbduction: 0.06,
      ),
      CatBones.handR: DancePoseLimb(
        x: 96,
        y: -4,
        bendDirection: 1,
        elbowAbduction: 0.1,
        tension: 0.12,
      ),
      CatBones.footL: DancePoseLimb(x: -8, y: 106, tension: 0.35),
      CatBones.footR: DancePoseLimb(x: 58, y: 110, tension: 0.6),
    },
    joints: {
      CatBones.handR: DancePoseJoint(rotation: 0.12, tension: 0.1),
      CatBones.footL: DancePoseJoint(rotation: 0.14),
      CatBones.clavicleL: DancePoseJoint(rotation: -0.016),
      CatBones.clavicleR: DancePoseJoint(rotation: 0.02),
    },
  ),
  DancePoseCell(
    frame: 14,
    intent: 'ive been gathers the left elbow as the right arm settles',
    supportFootIds: [CatBones.footR],
    body: DancePoseBody(
      rootDx: 5,
      rootDy: 17,
      pelvisRotation: 0.05,
      chestRotation: -0.04,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -88,
        y: -42,
        bendDirection: -1,
        elbowAbduction: 0.05,
      ),
      CatBones.handR: DancePoseLimb(
        x: 84,
        y: -20,
        bendDirection: 1,
        elbowAbduction: 0.08,
      ),
      CatBones.footL: DancePoseLimb(x: -32, y: 94),
      CatBones.footR: DancePoseLimb(x: 58, y: 110, tension: 0.5),
    },
    joints: {
      CatBones.handL: DancePoseJoint(rotation: -0.09),
      CatBones.handR: DancePoseJoint(rotation: 0.1),
      CatBones.footL: DancePoseJoint(rotation: 0.05),
    },
  ),
  DancePoseCell(
    frame: 16,
    intent: 'second phrase moving unfurls the left diagonal',
    supportFootIds: [CatBones.footL],
    body: DancePoseBody(
      rootDx: -18,
      rootDy: 50,
      pelvisRotation: -0.21,
      chestRotation: 0.22,
      chestScaleY: 0.84,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -105,
        y: -82,
        bendDirection: -1,
        elbowAbduction: 0.12,
        tension: 0.3,
      ),
      CatBones.handR: DancePoseLimb(
        x: 78,
        y: -18,
        bendDirection: 1,
        elbowAbduction: 0.07,
      ),
      CatBones.footL: DancePoseLimb(x: -58, y: 110, tension: 0.6),
      CatBones.footR: DancePoseLimb(x: 58, y: 110),
    },
    joints: {
      CatBones.handL: DancePoseJoint(rotation: -0.13),
      CatBones.handR: DancePoseJoint(rotation: 0.08),
      CatBones.footL: DancePoseJoint(),
      CatBones.clavicleL: DancePoseJoint(rotation: -0.018),
      CatBones.clavicleR: DancePoseJoint(rotation: 0.01),
    },
  ),
  DancePoseCell(
    frame: 18,
    intent: 'ooh lifts the left elbow toward an overhead pathway',
    supportFootIds: [CatBones.footL],
    body: DancePoseBody(
      rootDx: -20,
      rootDy: 40,
      pelvisRotation: -0.24,
      chestRotation: 0.08,
      chestScaleX: 1.02,
      chestScaleY: 0.88,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -82,
        y: -98,
        bendDirection: -1,
        elbowAbduction: 0.14,
      ),
      CatBones.handR: DancePoseLimb(
        x: 98,
        y: -50,
        bendDirection: 1,
        elbowAbduction: 0.11,
      ),
      CatBones.footL: DancePoseLimb(x: -58, y: 110, tension: 0.5),
      CatBones.footR: DancePoseLimb(x: 48, y: 93),
    },
    joints: {
      CatBones.handL: DancePoseJoint(rotation: -0.16),
      CatBones.handR: DancePoseJoint(rotation: 0.13),
      CatBones.footR: DancePoseJoint(rotation: -0.08),
      CatBones.clavicleL: DancePoseJoint(rotation: -0.022),
    },
  ),
  DancePoseCell(
    frame: 19,
    intent: 'left elbow leads the offbeat climb beside the head',
    supportFootIds: [CatBones.footL],
    body: DancePoseBody(
      rootDx: -18,
      rootDy: 28,
      pelvisRotation: -0.2,
      chestRotation: -0.02,
      chestScaleX: 1.05,
      chestScaleY: 0.95,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -64,
        y: -125,
        bendDirection: -1,
        elbowAbduction: 0.08,
      ),
      CatBones.handR: DancePoseLimb(
        x: 104,
        y: -56,
        bendDirection: 1,
        elbowAbduction: 0.13,
      ),
      CatBones.footL: DancePoseLimb(x: -58, y: 110, tension: 0.55),
      CatBones.footR: DancePoseLimb(x: 42, y: 98),
    },
    joints: {
      CatBones.handL: DancePoseJoint(rotation: -0.18),
      CatBones.handR: DancePoseJoint(rotation: 0.15),
      CatBones.footR: DancePoseJoint(rotation: -0.11),
      CatBones.clavicleL: DancePoseJoint(rotation: 0.2),
    },
  ),
  DancePoseCell(
    frame: 20,
    intent: 'ooh payoff: left paw above the head as the ribs roll under it',
    supportFootIds: [CatBones.footL],
    body: DancePoseBody(
      rootDx: -14,
      rootDy: 12,
      pelvisRotation: -0.12,
      chestRotation: -0.12,
      chestScaleX: 1.08,
      chestScaleY: 1.03,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -62,
        y: -147,
        bendDirection: -1,
        elbowAbduction: 0.03,
        tension: 0.2,
      ),
      CatBones.handR: DancePoseLimb(
        x: 108,
        y: -62,
        bendDirection: 1,
        elbowAbduction: 0.14,
      ),
      CatBones.footL: DancePoseLimb(x: -58, y: 110, tension: 0.6),
      CatBones.footR: DancePoseLimb(x: 34, y: 107, tension: 0.35),
    },
    joints: {
      CatBones.handL: DancePoseJoint(rotation: -0.18, tension: 0.08),
      CatBones.handR: DancePoseJoint(rotation: 0.16),
      CatBones.footR: DancePoseJoint(rotation: -0.14),
      CatBones.clavicleL: DancePoseJoint(rotation: 0.35),
    },
  ),
  DancePoseCell(
    frame: 21,
    intent: 'suspend the overhead line while the ribs finish underneath',
    supportFootIds: [CatBones.footL],
    body: DancePoseBody(
      rootDx: -8,
      rootDy: 16,
      pelvisRotation: -0.04,
      chestRotation: -0.18,
      chestScaleX: 1.08,
      chestScaleY: 0.98,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -58,
        y: -143,
        bendDirection: -1,
        elbowAbduction: 0.05,
        tension: 0.18,
      ),
      CatBones.handR: DancePoseLimb(
        x: 110,
        y: -58,
        bendDirection: 1,
        elbowAbduction: 0.14,
      ),
      CatBones.footL: DancePoseLimb(x: -58, y: 110, tension: 0.55),
      CatBones.footR: DancePoseLimb(x: 40, y: 98),
    },
    joints: {
      CatBones.handL: DancePoseJoint(rotation: -0.19, tension: 0.1),
      CatBones.handR: DancePoseJoint(rotation: 0.16),
      CatBones.footR: DancePoseJoint(rotation: -0.1),
      CatBones.clavicleL: DancePoseJoint(rotation: 0.3),
    },
  ),
  DancePoseCell(
    frame: 22,
    intent: 'the overhead paw exits diagonally as the body roll travels right',
    supportFootIds: [CatBones.footL],
    body: DancePoseBody(
      rootDx: 0,
      rootDy: 28,
      pelvisRotation: 0.03,
      chestRotation: -0.2,
      chestScaleX: 1.05,
      chestScaleY: 0.99,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -72,
        y: -112,
        bendDirection: -1,
        elbowAbduction: 0.14,
      ),
      CatBones.handR: DancePoseLimb(
        x: 104,
        y: -48,
        bendDirection: 1,
        elbowAbduction: 0.13,
      ),
      CatBones.footL: DancePoseLimb(x: -58, y: 110, tension: 0.5),
      CatBones.footR: DancePoseLimb(x: 48, y: 94),
    },
    joints: {
      CatBones.handL: DancePoseJoint(rotation: -0.17),
      CatBones.handR: DancePoseJoint(rotation: 0.15),
      CatBones.footR: DancePoseJoint(rotation: -0.05),
      CatBones.clavicleL: DancePoseJoint(rotation: 0.16),
    },
  ),
  DancePoseCell(
    frame: 23,
    intent: 'drop the overhead line into the final moving preparation',
    supportFootIds: [CatBones.footL],
    body: DancePoseBody(
      rootDx: 10,
      rootDy: 40,
      pelvisRotation: 0.12,
      chestRotation: -0.24,
      chestScaleX: 1.06,
      chestScaleY: 0.96,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -92,
        y: -92,
        bendDirection: -1,
        elbowAbduction: 0.13,
      ),
      CatBones.handR: DancePoseLimb(
        x: 100,
        y: -40,
        bendDirection: 1,
        elbowAbduction: 0.12,
      ),
      CatBones.footL: DancePoseLimb(x: -58, y: 110, tension: 0.5),
      CatBones.footR: DancePoseLimb(x: 50, y: 100),
    },
    joints: {
      CatBones.handL: DancePoseJoint(rotation: -0.17),
      CatBones.handR: DancePoseJoint(rotation: 0.14),
      CatBones.footR: DancePoseJoint(rotation: -0.06),
      CatBones.clavicleL: DancePoseJoint(rotation: 0.02),
    },
  ),
  DancePoseCell(
    frame: 24,
    intent: 'final moving sends the left paw outward and slightly high',
    supportFootIds: [CatBones.footR],
    body: DancePoseBody(
      rootDx: 18,
      rootDy: 50,
      pelvisRotation: 0.22,
      chestRotation: -0.12,
      chestScaleX: 1.04,
      chestScaleY: 0.93,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -112,
        y: -72,
        bendDirection: -1,
        elbowAbduction: 0.12,
        tension: 0.12,
      ),
      CatBones.handR: DancePoseLimb(
        x: 90,
        y: -28,
        bendDirection: 1,
        elbowAbduction: 0.12,
        tension: 0.1,
      ),
      CatBones.footL: DancePoseLimb(x: -58, y: 110),
      CatBones.footR: DancePoseLimb(x: 58, y: 110, tension: 0.6),
    },
    joints: {
      CatBones.handL: DancePoseJoint(rotation: -0.15),
      CatBones.handR: DancePoseJoint(rotation: 0.14),
      CatBones.footR: DancePoseJoint(),
      CatBones.clavicleL: DancePoseJoint(rotation: -0.02),
      CatBones.clavicleR: DancePoseJoint(rotation: 0.02),
    },
  ),
  DancePoseCell(
    frame: 25,
    intent: 'offbeat rebound keeps the final reach from parking',
    supportFootIds: [CatBones.footR],
    body: DancePoseBody(
      rootDx: 23,
      rootDy: 12,
      pelvisRotation: 0.28,
      chestRotation: 0.04,
      chestScaleX: 1.02,
      chestScaleY: 1.0,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -116,
        y: -48,
        bendDirection: -1,
        elbowAbduction: 0.11,
      ),
      CatBones.handR: DancePoseLimb(
        x: 86,
        y: -18,
        bendDirection: 1,
        elbowAbduction: 0.1,
      ),
      CatBones.footL: DancePoseLimb(x: -48, y: 98),
      CatBones.footR: DancePoseLimb(x: 58, y: 110, tension: 0.55),
    },
    joints: {
      CatBones.handL: DancePoseJoint(rotation: -0.14),
      CatBones.handR: DancePoseJoint(rotation: 0.12),
      CatBones.footL: DancePoseJoint(rotation: 0.04),
      CatBones.clavicleL: DancePoseJoint(rotation: -0.018),
    },
  ),
  DancePoseCell(
    frame: 26,
    intent: 'the reached left paw exits downward around the outside',
    supportFootIds: [CatBones.footR],
    body: DancePoseBody(
      rootDx: 20,
      rootDy: 28,
      pelvisRotation: 0.24,
      chestRotation: -0.12,
      chestScaleX: 1.02,
      chestScaleY: 0.98,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -110,
        y: -42,
        bendDirection: -1,
        elbowAbduction: 0.1,
        tension: 0.08,
      ),
      CatBones.handR: DancePoseLimb(
        x: 84,
        y: -18,
        bendDirection: 1,
        elbowAbduction: 0.1,
      ),
      CatBones.footL: DancePoseLimb(x: -50, y: 96),
      CatBones.footR: DancePoseLimb(x: 58, y: 110, tension: 0.5),
    },
    joints: {
      CatBones.handL: DancePoseJoint(rotation: -0.13),
      CatBones.handR: DancePoseJoint(rotation: 0.12),
      CatBones.footL: DancePoseJoint(rotation: 0.05),
    },
  ),
  DancePoseCell(
    frame: 27,
    intent: 'low cross-step drop gives the phrase a grounded tail',
    supportFootIds: [CatBones.footR],
    body: DancePoseBody(
      rootDx: 20,
      rootDy: 50,
      pelvisRotation: 0.24,
      chestRotation: -0.22,
      chestScaleX: 1.04,
      chestScaleY: 0.9,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -104,
        y: -8,
        bendDirection: -1,
        elbowAbduction: 0.09,
      ),
      CatBones.handR: DancePoseLimb(
        x: 82,
        y: -14,
        bendDirection: 1,
        elbowAbduction: 0.09,
      ),
      CatBones.footL: DancePoseLimb(x: -28, y: 104, tension: 0.2),
      CatBones.footR: DancePoseLimb(x: 58, y: 110, tension: 0.55),
    },
    joints: {
      CatBones.handL: DancePoseJoint(rotation: -0.1),
      CatBones.handR: DancePoseJoint(rotation: 0.1),
      CatBones.footL: DancePoseJoint(rotation: 0.1),
      CatBones.clavicleL: DancePoseJoint(rotation: -0.02),
    },
  ),
  DancePoseCell(
    frame: 28,
    intent: 'the phrase exhales over two beats, not one elastic return',
    supportFootIds: [CatBones.footR],
    body: DancePoseBody(
      rootDx: 16,
      rootDy: 24,
      pelvisRotation: 0.18,
      chestRotation: -0.15,
      chestScaleY: 0.95,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -98,
        y: -18,
        bendDirection: -1,
        elbowAbduction: 0.08,
      ),
      CatBones.handR: DancePoseLimb(
        x: 78,
        y: -12,
        bendDirection: 1,
        elbowAbduction: 0.08,
      ),
      CatBones.footL: DancePoseLimb(x: -36, y: 107, tension: 0.3),
      CatBones.footR: DancePoseLimb(x: 58, y: 110, tension: 0.6),
    },
    joints: {
      CatBones.handL: DancePoseJoint(rotation: -0.1),
      CatBones.handR: DancePoseJoint(rotation: 0.1),
      CatBones.footL: DancePoseJoint(rotation: 0.12),
      CatBones.clavicleL: DancePoseJoint(rotation: -0.024),
    },
  ),
  DancePoseCell(
    frame: 30,
    intent: 'continue the exhale into the loop seam',
    supportFootIds: [CatBones.footR],
    body: DancePoseBody(
      rootDx: 5,
      rootDy: 20,
      pelvisRotation: 0.04,
      chestRotation: -0.04,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -84,
        y: -8,
        bendDirection: -1,
        elbowAbduction: 0.08,
      ),
      CatBones.handR: DancePoseLimb(
        x: 76,
        y: -18,
        bendDirection: 1,
        elbowAbduction: 0.05,
      ),
      CatBones.footL: DancePoseLimb(x: -50, y: 97),
      CatBones.footR: DancePoseLimb(x: 58, y: 110, tension: 0.5),
    },
    joints: {
      CatBones.handL: DancePoseJoint(rotation: -0.08),
      CatBones.handR: DancePoseJoint(rotation: 0.09),
      CatBones.footL: DancePoseJoint(rotation: 0.04),
      CatBones.clavicleL: DancePoseJoint(rotation: -0.01),
    },
  ),
  DancePoseCell(
    frame: 32,
    intent: 'loop seam returns to the already travelling opening carve',
    supportFootIds: [CatBones.footL],
    body: DancePoseBody(
      rootDx: -16,
      rootDy: 31,
      pelvisRotation: -0.18,
      chestRotation: 0.14,
      chestScaleY: 0.96,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -78,
        y: -18,
        bendDirection: -1,
        elbowAbduction: 0.05,
      ),
      CatBones.handR: DancePoseLimb(
        x: 78,
        y: -25,
        bendDirection: 1,
        elbowAbduction: 0.08,
      ),
      CatBones.footL: DancePoseLimb(x: -58, y: 110),
      CatBones.footR: DancePoseLimb(x: 58, y: 110),
    },
    joints: {
      CatBones.handL: DancePoseJoint(rotation: -0.07),
      CatBones.handR: DancePoseJoint(rotation: 0.11),
      CatBones.footL: DancePoseJoint(),
      CatBones.footR: DancePoseJoint(),
      CatBones.clavicleL: DancePoseJoint(rotation: -0.01),
      CatBones.clavicleR: DancePoseJoint(rotation: 0.012),
    },
  ),
];

// Production hook phrase, rebuilt around readable dance intentions instead of
// a pose on nearly every subdivision.  Arms travel through a path and sustain
// the payoff; the planted foot remains continuous while the free foot taps in,
// so the pelvis can visibly ride the knee compression without puppet recoil.
const _movingHookLeadPoseCells = <DancePoseCell>[
  DancePoseCell(
    frame: 0,
    intent: 'coil low over the left plant',
    supportFootIds: [CatBones.footL],
    body: DancePoseBody(
      rootDx: -18,
      rootDy: 28,
      pelvisRotation: -0.2,
      chestRotation: 0.16,
      chestScaleY: 0.96,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(x: -76, y: -10, bendDirection: -1),
      CatBones.handR: DancePoseLimb(
        x: 65,
        y: -48,
        bendDirection: 1,
        elbowAbduction: 0.08,
      ),
      CatBones.footL: DancePoseLimb(x: -58, y: 110, tension: 0.6),
      CatBones.footR: DancePoseLimb(x: 30, y: 106),
    },
    joints: {
      CatBones.handL: DancePoseJoint(rotation: -0.08),
      CatBones.handR: DancePoseJoint(rotation: 0.08),
      CatBones.footR: DancePoseJoint(rotation: -0.08),
      CatBones.clavicleL: DancePoseJoint(rotation: -0.02),
      CatBones.clavicleR: DancePoseJoint(rotation: 0.04),
    },
  ),
  DancePoseCell(
    frame: 2,
    intent: 'right elbow leads the lyric out of the coil',
    supportFootIds: [CatBones.footL],
    body: DancePoseBody(
      rootDx: -21,
      rootDy: 20,
      pelvisRotation: -0.24,
      chestRotation: 0.08,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(x: -82, y: -18, bendDirection: -1),
      CatBones.handR: DancePoseLimb(
        x: 75,
        y: -75,
        bendDirection: 1,
        elbowAbduction: 0.12,
      ),
      CatBones.footL: DancePoseLimb(x: -58, y: 110, tension: 0.6),
      CatBones.footR: DancePoseLimb(x: 18, y: 104),
    },
    joints: {
      CatBones.handR: DancePoseJoint(rotation: 0.14),
      CatBones.footR: DancePoseJoint(rotation: -0.12),
      CatBones.clavicleR: DancePoseJoint(rotation: 0.09),
    },
  ),
  DancePoseCell(
    frame: 4,
    intent: 'send the right diagonal and touch the free toe in',
    supportFootIds: [CatBones.footL],
    body: DancePoseBody(
      rootDx: -16,
      rootDy: 16,
      pelvisRotation: -0.16,
      chestRotation: 0.2,
      chestScaleX: 1.035,
      chestScaleY: 0.96,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(x: -88, y: -10, bendDirection: -1),
      CatBones.handR: DancePoseLimb(
        x: 105,
        y: -90,
        bendDirection: 1,
        elbowAbduction: 0.13,
        tension: 0.25,
      ),
      CatBones.footL: DancePoseLimb(x: -58, y: 110, tension: 0.6),
      CatBones.footR: DancePoseLimb(x: 8, y: 110, tension: 0.25),
    },
    joints: {
      CatBones.handR: DancePoseJoint(rotation: 0.18),
      CatBones.footR: DancePoseJoint(rotation: -0.16),
      CatBones.clavicleR: DancePoseJoint(rotation: 0.13),
    },
  ),
  DancePoseCell(
    frame: 6,
    intent: 'keep the sent arm alive while it rounds down outside',
    supportFootIds: [CatBones.footL],
    body: DancePoseBody(
      rootDx: -5,
      rootDy: 22,
      pelvisRotation: -0.06,
      chestRotation: 0.06,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(x: -82, y: -24, bendDirection: -1),
      CatBones.handR: DancePoseLimb(
        x: 112,
        y: -65,
        bendDirection: 1,
        elbowAbduction: 0.14,
      ),
      CatBones.footL: DancePoseLimb(x: -58, y: 110, tension: 0.6),
      CatBones.footR: DancePoseLimb(x: 28, y: 96),
    },
    joints: {
      CatBones.handR: DancePoseJoint(rotation: 0.16),
      CatBones.footR: DancePoseJoint(rotation: -0.08),
      CatBones.clavicleR: DancePoseJoint(rotation: 0.1),
    },
  ),
  DancePoseCell(
    frame: 8,
    intent: 'land right and receive the arm through the ribs',
    supportFootIds: [CatBones.footR],
    body: DancePoseBody(
      rootDx: 18,
      rootDy: 34,
      pelvisRotation: 0.24,
      chestRotation: -0.2,
      chestScaleX: 1.04,
      chestScaleY: 0.9,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(x: -74, y: -34, bendDirection: -1),
      CatBones.handR: DancePoseLimb(
        x: 100,
        y: -50,
        bendDirection: 1,
        elbowAbduction: 0.12,
      ),
      CatBones.footL: DancePoseLimb(x: -30, y: 106),
      CatBones.footR: DancePoseLimb(x: 58, y: 110, tension: 0.6),
    },
    joints: {
      CatBones.handL: DancePoseJoint(rotation: -0.1),
      CatBones.handR: DancePoseJoint(rotation: 0.14),
      CatBones.footL: DancePoseJoint(rotation: 0.08),
      CatBones.clavicleL: DancePoseJoint(rotation: 0.02),
      CatBones.clavicleR: DancePoseJoint(rotation: 0.07),
    },
  ),
  DancePoseCell(
    frame: 10,
    intent: 'sit into the right knee as both elbows breathe',
    supportFootIds: [CatBones.footR],
    body: DancePoseBody(
      rootDx: 22,
      rootDy: 40,
      pelvisRotation: 0.28,
      chestRotation: 0.08,
      chestScaleY: 0.88,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -72,
        y: -42,
        bendDirection: -1,
        elbowAbduction: 0.08,
      ),
      CatBones.handR: DancePoseLimb(
        x: 82,
        y: -28,
        bendDirection: 1,
        elbowAbduction: 0.1,
      ),
      CatBones.footL: DancePoseLimb(x: -16, y: 104),
      CatBones.footR: DancePoseLimb(x: 58, y: 110, tension: 0.6),
    },
    joints: {
      CatBones.handL: DancePoseJoint(rotation: -0.12),
      CatBones.handR: DancePoseJoint(rotation: 0.11),
      CatBones.footL: DancePoseJoint(rotation: 0.12),
    },
  ),
  DancePoseCell(
    frame: 12,
    intent: 'compact low answer on the third moving',
    supportFootIds: [CatBones.footR],
    body: DancePoseBody(
      rootDx: 16,
      rootDy: 31,
      pelvisRotation: 0.18,
      chestRotation: -0.24,
      chestScaleY: 0.94,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -70,
        y: -50,
        bendDirection: -1,
        elbowAbduction: 0.1,
      ),
      CatBones.handR: DancePoseLimb(
        x: 70,
        y: -46,
        bendDirection: 1,
        elbowAbduction: 0.1,
      ),
      CatBones.footL: DancePoseLimb(x: -6, y: 110, tension: 0.25),
      CatBones.footR: DancePoseLimb(x: 58, y: 110, tension: 0.6),
    },
    joints: {
      CatBones.handL: DancePoseJoint(rotation: -0.12),
      CatBones.handR: DancePoseJoint(rotation: 0.12),
      CatBones.footL: DancePoseJoint(rotation: 0.15),
      CatBones.clavicleL: DancePoseJoint(rotation: 0.05),
      CatBones.clavicleR: DancePoseJoint(rotation: -0.04),
    },
  ),
  DancePoseCell(
    frame: 14,
    intent: 'rebound through the left elbow before the crown',
    supportFootIds: [CatBones.footR],
    body: DancePoseBody(
      rootDx: 5,
      rootDy: 18,
      pelvisRotation: 0.05,
      chestRotation: -0.06,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -75,
        y: -75,
        bendDirection: -1,
        elbowAbduction: 0.1,
      ),
      CatBones.handR: DancePoseLimb(x: 72, y: -20, bendDirection: 1),
      CatBones.footL: DancePoseLimb(x: -28, y: 96),
      CatBones.footR: DancePoseLimb(x: 58, y: 110, tension: 0.6),
    },
    joints: {
      CatBones.handL: DancePoseJoint(rotation: -0.14),
      CatBones.handR: DancePoseJoint(rotation: 0.09),
      CatBones.footL: DancePoseJoint(rotation: 0.06),
      CatBones.clavicleL: DancePoseJoint(rotation: 0.1),
    },
  ),
  DancePoseCell(
    frame: 16,
    intent: 'land left and launch the crown from the shoulder',
    supportFootIds: [CatBones.footL],
    body: DancePoseBody(
      rootDx: -18,
      rootDy: 28,
      pelvisRotation: -0.2,
      chestRotation: 0.22,
      chestScaleY: 0.94,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -70,
        y: -96,
        bendDirection: -1,
        elbowAbduction: 0.12,
      ),
      CatBones.handR: DancePoseLimb(x: 74, y: -14, bendDirection: 1),
      CatBones.footL: DancePoseLimb(x: -58, y: 110, tension: 0.6),
      CatBones.footR: DancePoseLimb(x: 34, y: 106),
    },
    joints: {
      CatBones.handL: DancePoseJoint(rotation: -0.16),
      CatBones.handR: DancePoseJoint(rotation: 0.08),
      CatBones.footR: DancePoseJoint(rotation: -0.08),
      CatBones.clavicleL: DancePoseJoint(rotation: 0.16),
    },
  ),
  DancePoseCell(
    frame: 18,
    intent: 'left paw travels beside the face, not across it',
    supportFootIds: [CatBones.footL],
    body: DancePoseBody(
      rootDx: -22,
      rootDy: 20,
      pelvisRotation: -0.25,
      chestRotation: 0.12,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -64,
        y: -126,
        bendDirection: -1,
        elbowAbduction: 0.09,
      ),
      CatBones.handR: DancePoseLimb(x: 78, y: -22, bendDirection: 1),
      CatBones.footL: DancePoseLimb(x: -58, y: 110, tension: 0.6),
      CatBones.footR: DancePoseLimb(x: 18, y: 104),
    },
    joints: {
      CatBones.handL: DancePoseJoint(rotation: -0.16),
      CatBones.handR: DancePoseJoint(rotation: 0.09),
      CatBones.footR: DancePoseJoint(rotation: -0.12),
      CatBones.clavicleL: DancePoseJoint(rotation: 0.22),
    },
  ),
  DancePoseCell(
    frame: 20,
    intent: 'overhead crown lands on ooh',
    supportFootIds: [CatBones.footL],
    body: DancePoseBody(
      rootDx: -16,
      rootDy: 14,
      pelvisRotation: -0.16,
      chestRotation: 0.2,
      chestScaleX: 1.03,
      chestScaleY: 0.98,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -58,
        y: -150,
        bendDirection: -1,
        elbowAbduction: 0.06,
        tension: 0.3,
      ),
      CatBones.handR: DancePoseLimb(
        x: 98,
        y: -42,
        bendDirection: 1,
        elbowAbduction: 0.08,
      ),
      CatBones.footL: DancePoseLimb(x: -58, y: 110, tension: 0.6),
      CatBones.footR: DancePoseLimb(x: 8, y: 110, tension: 0.25),
    },
    joints: {
      CatBones.handL: DancePoseJoint(rotation: -0.1),
      CatBones.handR: DancePoseJoint(rotation: 0.1),
      CatBones.footR: DancePoseJoint(rotation: -0.16),
      CatBones.clavicleL: DancePoseJoint(rotation: 0.28),
    },
  ),
  DancePoseCell(
    frame: 22,
    intent: 'sustain the crown while the ribs answer underneath',
    supportFootIds: [CatBones.footL],
    body: DancePoseBody(
      rootDx: -7,
      rootDy: 20,
      pelvisRotation: -0.06,
      chestRotation: -0.08,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -62,
        y: -146,
        bendDirection: -1,
        elbowAbduction: 0.07,
      ),
      CatBones.handR: DancePoseLimb(
        x: 92,
        y: -54,
        bendDirection: 1,
        elbowAbduction: 0.1,
      ),
      CatBones.footL: DancePoseLimb(x: -58, y: 110, tension: 0.6),
      CatBones.footR: DancePoseLimb(x: 28, y: 108),
    },
    joints: {
      CatBones.handL: DancePoseJoint(rotation: -0.08),
      CatBones.handR: DancePoseJoint(rotation: 0.12),
      CatBones.footR: DancePoseJoint(rotation: -0.08),
      CatBones.clavicleL: DancePoseJoint(rotation: 0.26),
    },
  ),
  DancePoseCell(
    frame: 24,
    intent: 'land right as the crown pours down the outside',
    supportFootIds: [CatBones.footR],
    body: DancePoseBody(
      rootDx: 19,
      rootDy: 36,
      pelvisRotation: 0.24,
      chestRotation: -0.22,
      chestScaleY: 0.9,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -90,
        y: -105,
        bendDirection: -1,
        elbowAbduction: 0.04,
      ),
      CatBones.handR: DancePoseLimb(x: 76, y: -18, bendDirection: 1),
      CatBones.footL: DancePoseLimb(x: -34, y: 106),
      CatBones.footR: DancePoseLimb(x: 58, y: 110, tension: 0.6),
    },
    joints: {
      CatBones.handL: DancePoseJoint(rotation: -0.12),
      CatBones.handR: DancePoseJoint(rotation: 0.08),
      CatBones.footL: DancePoseJoint(rotation: 0.08),
      CatBones.clavicleL: DancePoseJoint(rotation: 0.18),
    },
  ),
  DancePoseCell(
    frame: 26,
    intent: 'release the crown into a wide left answer',
    supportFootIds: [CatBones.footR],
    body: DancePoseBody(
      rootDx: 22,
      rootDy: 28,
      pelvisRotation: 0.27,
      chestRotation: 0.1,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -102,
        y: -72,
        bendDirection: -1,
        elbowAbduction: 0.13,
      ),
      CatBones.handR: DancePoseLimb(
        x: 78,
        y: -34,
        bendDirection: 1,
        elbowAbduction: 0.08,
      ),
      CatBones.footL: DancePoseLimb(x: -18, y: 104),
      CatBones.footR: DancePoseLimb(x: 58, y: 110, tension: 0.6),
    },
    joints: {
      CatBones.handL: DancePoseJoint(rotation: -0.17),
      CatBones.handR: DancePoseJoint(rotation: 0.1),
      CatBones.footL: DancePoseJoint(rotation: 0.12),
      CatBones.clavicleL: DancePoseJoint(rotation: 0.1),
    },
  ),
  DancePoseCell(
    frame: 28,
    intent: 'open both diagonals for the final moving',
    supportFootIds: [CatBones.footR],
    body: DancePoseBody(
      rootDx: 16,
      rootDy: 18,
      pelvisRotation: 0.16,
      chestRotation: -0.16,
      chestScaleX: 1.04,
      chestScaleY: 0.97,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(
        x: -96,
        y: -80,
        bendDirection: -1,
        elbowAbduction: 0.12,
      ),
      CatBones.handR: DancePoseLimb(
        x: 98,
        y: -74,
        bendDirection: 1,
        elbowAbduction: 0.12,
      ),
      CatBones.footL: DancePoseLimb(x: -8, y: 110, tension: 0.25),
      CatBones.footR: DancePoseLimb(x: 58, y: 110, tension: 0.6),
    },
    joints: {
      CatBones.handL: DancePoseJoint(rotation: -0.16),
      CatBones.handR: DancePoseJoint(rotation: 0.16),
      CatBones.footL: DancePoseJoint(rotation: 0.16),
      CatBones.clavicleL: DancePoseJoint(rotation: 0.1),
      CatBones.clavicleR: DancePoseJoint(rotation: -0.1),
    },
  ),
  DancePoseCell(
    frame: 30,
    intent: 'let the open shape settle forward without recoiling',
    supportFootIds: [CatBones.footR],
    body: DancePoseBody(
      rootDx: 4,
      rootDy: 24,
      pelvisRotation: 0.05,
      chestRotation: -0.04,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(x: -82, y: -32, bendDirection: -1),
      CatBones.handR: DancePoseLimb(x: 84, y: -38, bendDirection: 1),
      CatBones.footL: DancePoseLimb(x: -28, y: 108),
      CatBones.footR: DancePoseLimb(x: 58, y: 110, tension: 0.6),
    },
    joints: {
      CatBones.handL: DancePoseJoint(rotation: -0.1),
      CatBones.handR: DancePoseJoint(rotation: 0.11),
      CatBones.footL: DancePoseJoint(rotation: 0.06),
      CatBones.clavicleL: DancePoseJoint(rotation: 0.02),
      CatBones.clavicleR: DancePoseJoint(rotation: -0.02),
    },
  ),
  DancePoseCell(
    frame: 32,
    intent: 'loop into the same low left coil',
    supportFootIds: [CatBones.footL],
    body: DancePoseBody(
      rootDx: -18,
      rootDy: 28,
      pelvisRotation: -0.2,
      chestRotation: 0.16,
      chestScaleY: 0.96,
    ),
    limbs: {
      CatBones.handL: DancePoseLimb(x: -76, y: -10, bendDirection: -1),
      CatBones.handR: DancePoseLimb(
        x: 65,
        y: -48,
        bendDirection: 1,
        elbowAbduction: 0.08,
      ),
      CatBones.footL: DancePoseLimb(x: -58, y: 110, tension: 0.6),
      CatBones.footR: DancePoseLimb(x: 30, y: 106),
    },
    joints: {
      CatBones.handL: DancePoseJoint(rotation: -0.08),
      CatBones.handR: DancePoseJoint(rotation: 0.08),
      CatBones.footR: DancePoseJoint(rotation: -0.08),
      CatBones.clavicleL: DancePoseJoint(rotation: -0.02),
      CatBones.clavicleR: DancePoseJoint(rotation: 0.04),
    },
  ),
];

final _movingHookLeadBodyKeys = bodyKeysFromPoseCells(
  _movingHookLeadPoseCells,
);
final _movingHookLeadHandLTargetKeys = limbKeysFromPoseCells(
  _movingHookLeadPoseCells,
  CatBones.handL,
);
final _movingHookLeadHandRTargetKeys = limbKeysFromPoseCells(
  _movingHookLeadPoseCells,
  CatBones.handR,
);
final _movingHookLeadFootLTargetKeys = limbKeysFromPoseCells(
  _movingHookLeadPoseCells,
  CatBones.footL,
);
final _movingHookLeadFootRTargetKeys = limbKeysFromPoseCells(
  _movingHookLeadPoseCells,
  CatBones.footR,
);
final _movingHookLeadFootLKeys = jointKeysFromPoseCells(
  _movingHookLeadPoseCells,
  CatBones.footL,
);
final _movingHookLeadFootRKeys = jointKeysFromPoseCells(
  _movingHookLeadPoseCells,
  CatBones.footR,
);
final _movingHookLeadHandLKeys = jointKeysFromPoseCells(
  _movingHookLeadPoseCells,
  CatBones.handL,
);
final _movingHookLeadHandRKeys = jointKeysFromPoseCells(
  _movingHookLeadPoseCells,
  CatBones.handR,
);
final _movingHookLeadClavicleLKeys = jointKeysFromPoseCells(
  _movingHookLeadPoseCells,
  CatBones.clavicleL,
);
final _movingHookLeadClavicleRKeys = jointKeysFromPoseCells(
  _movingHookLeadPoseCells,
  CatBones.clavicleR,
);
final _movingHookLeadContactSpans = contactSpansFromPoseCells(
  _movingHookLeadPoseCells,
  32,
);

// ─────────────────────────────────────────────────────────────────────────
// "Moving" groove — song-specific connective phrase.
//
// Four two-beat weight transfers replace the catalogue's one-new-pose-per-beat
// cadence.  Each side accepts weight, rebounds without losing the support,
// then releases through a brief double-support transfer.  The second bar is a
// variation, not a clone: slightly deeper pockets and a wider final arm answer.
// ─────────────────────────────────────────────────────────────────────────

const _movingGrooveContactSpans = [
  GroundSpan(CatBones.footL, 0, 0.25),
  GroundSpan(CatBones.footR, 0.25, 0.5),
  GroundSpan(CatBones.footL, 0.5, 0.75),
  GroundSpan(CatBones.footR, 0.75, 1),
];

const _movingGrooveBodyKeys = [
  // Bar 1: load left, float inside the pocket, transfer; mirror right.
  DanceBodyKey(
    0,
    rootDx: -16,
    rootDy: 31,
    pelvisRotation: -0.18,
    chestRotation: 0.15,
    chestScaleX: 1.025,
    chestScaleY: 0.965,
  ),
  DanceBodyKey(
    2,
    rootDx: -18,
    rootDy: 17,
    pelvisRotation: -0.22,
    chestRotation: 0.11,
    chestScaleX: 1.01,
    chestScaleY: 0.99,
  ),
  DanceBodyKey(
    4,
    rootDx: -15,
    rootDy: 25,
    pelvisRotation: -0.15,
    chestRotation: 0.12,
    chestScaleX: 1.02,
    chestScaleY: 0.975,
  ),
  DanceBodyKey(
    6,
    rootDx: -6,
    rootDy: 20,
    pelvisRotation: -0.05,
    chestRotation: 0.05,
  ),
  DanceBodyKey(
    8,
    rootDx: 16,
    rootDy: 33,
    pelvisRotation: 0.19,
    chestRotation: -0.16,
    chestScaleX: 1.03,
    chestScaleY: 0.96,
  ),
  DanceBodyKey(
    10,
    rootDx: 18,
    rootDy: 18,
    pelvisRotation: 0.23,
    chestRotation: -0.11,
    chestScaleX: 1.01,
    chestScaleY: 0.99,
  ),
  DanceBodyKey(
    12,
    rootDx: 15,
    rootDy: 26,
    pelvisRotation: 0.16,
    chestRotation: -0.13,
    chestScaleX: 1.02,
    chestScaleY: 0.975,
  ),
  DanceBodyKey(
    14,
    rootDx: 6,
    rootDy: 20,
    pelvisRotation: 0.05,
    chestRotation: -0.05,
  ),

  // Bar 2: same motor pattern with a touch more weight and a softer release.
  DanceBodyKey(
    16,
    rootDx: -18,
    rootDy: 35,
    pelvisRotation: -0.21,
    chestRotation: 0.17,
    chestScaleX: 1.035,
    chestScaleY: 0.955,
  ),
  DanceBodyKey(
    18,
    rootDx: -20,
    rootDy: 19,
    pelvisRotation: -0.25,
    chestRotation: 0.12,
    chestScaleX: 1.015,
    chestScaleY: 0.99,
  ),
  DanceBodyKey(
    20,
    rootDx: -17,
    rootDy: 28,
    pelvisRotation: -0.18,
    chestRotation: 0.14,
    chestScaleX: 1.025,
    chestScaleY: 0.97,
  ),
  DanceBodyKey(
    22,
    rootDx: -7,
    rootDy: 21,
    pelvisRotation: -0.055,
    chestRotation: 0.055,
  ),
  DanceBodyKey(
    24,
    rootDx: 18,
    rootDy: 36,
    pelvisRotation: 0.22,
    chestRotation: -0.18,
    chestScaleX: 1.04,
    chestScaleY: 0.95,
  ),
  DanceBodyKey(
    26,
    rootDx: 20,
    rootDy: 20,
    pelvisRotation: 0.26,
    chestRotation: -0.13,
    chestScaleX: 1.015,
    chestScaleY: 0.985,
  ),
  DanceBodyKey(
    28,
    rootDx: 17,
    rootDy: 29,
    pelvisRotation: 0.19,
    chestRotation: -0.15,
    chestScaleX: 1.03,
    chestScaleY: 0.965,
  ),
  DanceBodyKey(
    30,
    rootDx: 5,
    rootDy: 21,
    pelvisRotation: 0.045,
    chestRotation: -0.045,
  ),
  DanceBodyKey(
    32,
    rootDx: -16,
    rootDy: 31,
    pelvisRotation: -0.18,
    chestRotation: 0.15,
    chestScaleX: 1.025,
    chestScaleY: 0.965,
  ),
];

// Song-specific signature: "I've been" preloads the working arm, then the
// three sung "moving" pulses get three diagonal call/point throws at frames
// 4/8/12. Bar 2 answers on the left; its middle throw sustains one extra frame
// for the sung "ooh" before the final "moving". Every throw recoils, so the
// motif has preparation → accent → release rather than three parked poses.
//
// These targets stay fully on their own side of the ribcage and outside the
// arm's acute-fold zone. The planar elbow cannot honestly solve a hand pulled
// close to the sternum: although the endpoint is mathematically reachable, the
// only two solutions point the elbow through the chest or turn the forearm
// inside-out. The "draw" therefore travels low-out -> high-out as a
// shoulder-led diagonal, never through the tie. No spring interpolation here:
// the sustained spline is the point of contrast with the catalogue hit moves.
const _movingGrooveHandLTargetKeys = [
  // Bar 1: tucked, asymmetrical counterweight while the right paw calls out.
  DanceIkTargetKey(0, x: -80, y: -10, bendDirection: -1),
  DanceIkTargetKey(4, x: -86, y: -18, bendDirection: -1),
  DanceIkTargetKey(8, x: -78, y: -14, bendDirection: -1),
  DanceIkTargetKey(12, x: -88, y: -12, bendDirection: -1),
  DanceIkTargetKey(16, x: -80, y: -10, bendDirection: -1),
  // Bar 2: wind → call/point → recoil → higher answer → second point. Short
  // spans create a light throw-and-return, while all targets remain in the
  // relaxed own-side reach envelope of the corrected elbow branch.
  DanceIkTargetKey(18, x: -75, y: -25, bendDirection: -1),
  DanceIkTargetKey(20, x: -100, y: -85, bendDirection: -1),
  DanceIkTargetKey(21, x: -104, y: -88, bendDirection: -1, tension: 0.35),
  DanceIkTargetKey(22, x: -72, y: -45, bendDirection: -1),
  DanceIkTargetKey(24, x: -96, y: -75, bendDirection: -1),
  DanceIkTargetKey(25, x: -100, y: -72, bendDirection: -1, tension: 0.25),
  DanceIkTargetKey(26, x: -82, y: -20, bendDirection: -1),
  DanceIkTargetKey(28, x: -102, y: -70, bendDirection: -1),
  DanceIkTargetKey(30, x: -72, y: -42, bendDirection: -1),
  DanceIkTargetKey(32, x: -80, y: -10, bendDirection: -1),
];

const _movingGrooveHandRTargetKeys = [
  // Bar 1: right-paw call-and-point hook.
  DanceIkTargetKey(0, x: 80, y: -38, bendDirection: 1),
  DanceIkTargetKey(2, x: 75, y: -25, bendDirection: 1),
  DanceIkTargetKey(4, x: 100, y: -85, bendDirection: 1),
  DanceIkTargetKey(5, x: 104, y: -88, bendDirection: 1, tension: 0.35),
  DanceIkTargetKey(6, x: 72, y: -45, bendDirection: 1),
  DanceIkTargetKey(8, x: 96, y: -75, bendDirection: 1),
  DanceIkTargetKey(10, x: 82, y: -20, bendDirection: 1),
  DanceIkTargetKey(12, x: 102, y: -70, bendDirection: 1),
  DanceIkTargetKey(14, x: 80, y: -38, bendDirection: 1),
  DanceIkTargetKey(16, x: 80, y: -38, bendDirection: 1),
  // Bar 2: tucked counterweight until the loop returns to the right call.
  DanceIkTargetKey(20, x: 86, y: -18, bendDirection: 1),
  DanceIkTargetKey(24, x: 78, y: -14, bendDirection: 1),
  DanceIkTargetKey(28, x: 88, y: -12, bendDirection: 1),
  DanceIkTargetKey(30, x: 80, y: -18, bendDirection: 1),
  DanceIkTargetKey(32, x: 80, y: -38, bendDirection: 1),
];

// Later-chorus travel. Each eight-frame unit is one complete weight decision:
// load, send the free shoe outside the stance, collect, and change support.
// Bar two develops the idea with a deeper landing instead of mirroring bar one.
const _movingChorusTravelContactSpans = [
  GroundSpan(CatBones.footL, 0, 0.25),
  GroundSpan(CatBones.footR, 0.25, 0.5),
  GroundSpan(CatBones.footL, 0.5, 0.75),
  GroundSpan(CatBones.footR, 0.75, 1),
];

const _movingChorusTravelBodyKeys = [
  DanceBodyKey(
    0,
    rootDx: -24,
    rootDy: 35,
    pelvisRotation: -0.28,
    chestRotation: 0.20,
    chestScaleY: 0.94,
  ),
  DanceBodyKey(
    1,
    rootDx: -28,
    rootDy: 30,
    pelvisRotation: -0.3,
    chestRotation: 0.16,
  ),
  DanceBodyKey(
    3,
    rootDx: -29,
    rootDy: 18,
    pelvisRotation: -0.31,
    chestRotation: 0.08,
  ),
  DanceBodyKey(
    6,
    rootDx: -10,
    rootDy: 12,
    pelvisRotation: -0.08,
    chestRotation: -0.06,
    chestScaleY: 1.02,
  ),
  DanceBodyKey(
    8,
    rootDx: 22,
    rootDy: 32,
    pelvisRotation: 0.26,
    chestRotation: -0.19,
    chestScaleY: 0.95,
  ),
  DanceBodyKey(
    11,
    rootDx: 30,
    rootDy: 17,
    pelvisRotation: 0.32,
    chestRotation: -0.07,
  ),
  DanceBodyKey(
    14,
    rootDx: 8,
    rootDy: 11,
    pelvisRotation: 0.07,
    chestRotation: 0.07,
    chestScaleY: 1.025,
  ),
  DanceBodyKey(
    16,
    rootDx: -23,
    rootDy: 35,
    pelvisRotation: -0.28,
    chestRotation: 0.21,
    chestScaleX: 1.035,
    chestScaleY: 0.93,
  ),
  DanceBodyKey(
    19,
    rootDx: -27,
    rootDy: 21,
    pelvisRotation: -0.30,
    chestRotation: 0.09,
  ),
  DanceBodyKey(
    22,
    rootDx: -7,
    rootDy: 10,
    pelvisRotation: -0.05,
    chestRotation: -0.09,
    chestScaleY: 1.03,
  ),
  DanceBodyKey(
    24,
    rootDx: 23,
    rootDy: 36,
    pelvisRotation: 0.29,
    chestRotation: -0.22,
    chestScaleX: 1.04,
    chestScaleY: 0.92,
  ),
  DanceBodyKey(
    27,
    rootDx: 27,
    rootDy: 22,
    pelvisRotation: 0.31,
    chestRotation: -0.09,
  ),
  DanceBodyKey(
    30,
    rootDx: 6,
    rootDy: 11,
    pelvisRotation: 0.04,
    chestRotation: 0.09,
    chestScaleY: 1.03,
  ),
  DanceBodyKey(
    31,
    rootDx: -14,
    rootDy: 28,
    pelvisRotation: -0.14,
    chestRotation: 0.14,
    chestScaleY: 0.98,
  ),
  DanceBodyKey(
    32,
    rootDx: -24,
    rootDy: 35,
    pelvisRotation: -0.28,
    chestRotation: 0.20,
    chestScaleY: 0.94,
  ),
];

const _movingChorusTravelHandLTargetKeys = [
  DanceIkTargetKey(0, x: -78, y: -2, bendDirection: -1),
  DanceIkTargetKey(1, x: -78, y: -2, bendDirection: -1),
  DanceIkTargetKey(2, x: -82, y: -30, bendDirection: -1),
  DanceIkTargetKey(3, x: -88, y: -70, bendDirection: -1),
  DanceIkTargetKey(5, x: -80, y: -96, bendDirection: -1),
  DanceIkTargetKey(6, x: -72, y: -106, bendDirection: -1, elbowAbduction: 0.12),
  DanceIkTargetKey(7, x: -76, y: -100, bendDirection: -1),
  DanceIkTargetKey(8, x: -82, y: -76, bendDirection: -1),
  DanceIkTargetKey(10, x: -88, y: -20, bendDirection: -1),
  DanceIkTargetKey(12, x: -90, y: 12, bendDirection: -1),
  DanceIkTargetKey(16, x: -78, y: 5, bendDirection: -1),
  DanceIkTargetKey(18, x: -84, y: 8, bendDirection: -1),
  DanceIkTargetKey(20, x: -86, y: 10, bendDirection: -1),
  DanceIkTargetKey(22, x: -86, y: -18, bendDirection: -1),
  DanceIkTargetKey(24, x: -84, y: -58, bendDirection: -1),
  DanceIkTargetKey(
    27,
    x: -76,
    y: -108,
    bendDirection: -1,
    elbowAbduction: 0.13,
  ),
  DanceIkTargetKey(29, x: -84, y: -78, bendDirection: -1),
  DanceIkTargetKey(30, x: -86, y: -52, bendDirection: -1),
  DanceIkTargetKey(31, x: -82, y: -24, bendDirection: -1),
  DanceIkTargetKey(32, x: -78, y: -2, bendDirection: -1),
];

const _movingChorusTravelHandRTargetKeys = [
  DanceIkTargetKey(0, x: 86, y: -56, bendDirection: 1),
  DanceIkTargetKey(3, x: 91, y: 6, bendDirection: 1),
  DanceIkTargetKey(4, x: 92, y: 12, bendDirection: 1),
  DanceIkTargetKey(5, x: 90, y: 12, bendDirection: 1),
  DanceIkTargetKey(6, x: 86, y: 10, bendDirection: 1),
  DanceIkTargetKey(8, x: 78, y: 5, bendDirection: 1),
  DanceIkTargetKey(11, x: 88, y: -72, bendDirection: 1),
  DanceIkTargetKey(14, x: 72, y: -106, bendDirection: 1, elbowAbduction: 0.12),
  DanceIkTargetKey(16, x: 84, y: -54, bendDirection: 1),
  DanceIkTargetKey(18, x: 86, y: -12, bendDirection: 1),
  DanceIkTargetKey(20, x: 86, y: 8, bendDirection: 1),
  DanceIkTargetKey(22, x: 84, y: 4, bendDirection: 1),
  DanceIkTargetKey(24, x: 80, y: 5, bendDirection: 1),
  DanceIkTargetKey(28, x: 90, y: 12, bendDirection: 1),
  DanceIkTargetKey(30, x: 88, y: -22, bendDirection: 1),
  DanceIkTargetKey(32, x: 86, y: -56, bendDirection: 1),
];

const _movingChorusTravelFootLTargetKeys = [
  DanceIkTargetKey(0, x: -58, y: 110),
  DanceIkTargetKey(8, x: -58, y: 110),
  DanceIkTargetKey(10, x: -72, y: 88),
  DanceIkTargetKey(12, x: -85, y: 101),
  DanceIkTargetKey(13, x: -79, y: 93),
  DanceIkTargetKey(14, x: -70, y: 89),
  DanceIkTargetKey(15, x: -63, y: 97),
  DanceIkTargetKey(16, x: -58, y: 110),
  DanceIkTargetKey(24, x: -58, y: 110),
  DanceIkTargetKey(26, x: -76, y: 85),
  DanceIkTargetKey(28, x: -88, y: 100),
  DanceIkTargetKey(29, x: -81, y: 92),
  DanceIkTargetKey(30, x: -71, y: 89),
  DanceIkTargetKey(31, x: -64, y: 97),
  DanceIkTargetKey(32, x: -58, y: 110),
];

const _movingChorusTravelFootRTargetKeys = [
  DanceIkTargetKey(0, x: 58, y: 110),
  DanceIkTargetKey(2, x: 74, y: 87),
  DanceIkTargetKey(4, x: 85, y: 101),
  DanceIkTargetKey(5, x: 79, y: 93),
  DanceIkTargetKey(6, x: 70, y: 89),
  DanceIkTargetKey(7, x: 63, y: 97),
  DanceIkTargetKey(8, x: 58, y: 110),
  DanceIkTargetKey(16, x: 58, y: 110),
  DanceIkTargetKey(18, x: 77, y: 84),
  DanceIkTargetKey(20, x: 88, y: 100),
  DanceIkTargetKey(21, x: 81, y: 92),
  DanceIkTargetKey(22, x: 71, y: 89),
  DanceIkTargetKey(23, x: 64, y: 97),
  DanceIkTargetKey(24, x: 58, y: 110),
  DanceIkTargetKey(32, x: 58, y: 110),
];

const _movingChorusTravelFootLKeys = [
  DanceJointKey(0),
  DanceJointKey(8),
  DanceJointKey(10, rotation: 0.16),
  DanceJointKey(12, rotation: 0.34),
  DanceJointKey(14, rotation: 0.12),
  DanceJointKey(16),
  DanceJointKey(24),
  DanceJointKey(26, rotation: 0.18),
  DanceJointKey(28, rotation: 0.38),
  DanceJointKey(30, rotation: 0.13),
  DanceJointKey(32),
];

const _movingChorusTravelFootRKeys = [
  DanceJointKey(0),
  DanceJointKey(2, rotation: -0.16),
  DanceJointKey(4, rotation: -0.34),
  DanceJointKey(6, rotation: -0.12),
  DanceJointKey(8),
  DanceJointKey(16),
  DanceJointKey(18, rotation: -0.18),
  DanceJointKey(20, rotation: -0.38),
  DanceJointKey(22, rotation: -0.13),
  DanceJointKey(24),
  DanceJointKey(32),
];

// Small authored paw pronation/supination rides on top of the runtime's delayed
// forearm-follow. The keys crest after the clavicle but around the hand apex;
// they articulate the paw without the catalogue moves' large wrist flicks.
const _movingChorusTravelHandLKeys = [
  DanceJointKey(0, rotation: 0.06),
  DanceJointKey(4, rotation: -0.10),
  DanceJointKey(7, rotation: -0.24),
  DanceJointKey(10, rotation: -0.04),
  DanceJointKey(14, rotation: 0.12),
  DanceJointKey(18, rotation: 0.02),
  DanceJointKey(24, rotation: -0.08),
  DanceJointKey(28, rotation: -0.26),
  DanceJointKey(31, rotation: 0.02),
  DanceJointKey(32, rotation: 0.06),
];

const _movingChorusTravelHandRKeys = [
  DanceJointKey(0, rotation: 0.08),
  DanceJointKey(5, rotation: -0.10),
  DanceJointKey(10, rotation: 0.04),
  DanceJointKey(15, rotation: 0.24),
  DanceJointKey(18, rotation: 0.06),
  DanceJointKey(22, rotation: -0.10),
  DanceJointKey(26, rotation: 0.08),
  DanceJointKey(30, rotation: -0.06),
  DanceJointKey(32, rotation: 0.08),
];

// The shoulder initiates each overhead pour before the corresponding paw.
const _movingChorusTravelClavicleLKeys = [
  DanceJointKey(0),
  DanceJointKey(3, rotation: 0.008),
  DanceJointKey(5, rotation: 0.024),
  DanceJointKey(9, rotation: -0.006),
  DanceJointKey(16),
  // Preserve the already-smooth inherited hook timing for the second rise.
  DanceJointKey(20, rotation: -0.01),
  DanceJointKey(24, rotation: 0.018),
  DanceJointKey(28, rotation: -0.008),
  DanceJointKey(32),
];

const _movingChorusTravelClavicleRKeys = [
  DanceJointKey(0),
  DanceJointKey(9, rotation: 0.005),
  DanceJointKey(12, rotation: -0.024),
  DanceJointKey(16, rotation: 0.006),
  DanceJointKey(24),
  DanceJointKey(32),
];

// Later-chorus escalation. The shoes press outward but remain near the deck;
// the body's energy comes from a larger lunge and two arms opening together,
// not from repeating the hook's single lifted fist.
const _movingChorusOpenContactSpans = [
  GroundSpan(CatBones.footL, 0, 0.25),
  GroundSpan(CatBones.footR, 0.25, 0.5),
  GroundSpan(CatBones.footL, 0.5, 0.75),
  GroundSpan(CatBones.footR, 0.75, 1),
];

const _movingChorusOpenBodyKeys = [
  DanceBodyKey(
    0,
    rootDx: -28,
    rootDy: 30,
    rootRotation: -0.035,
    pelvisRotation: -0.34,
    chestRotation: 0.27,
    chestScaleX: 1.05,
    chestScaleY: 0.88,
  ),
  DanceBodyKey(
    1,
    rootDx: -29,
    rootDy: 29,
    rootRotation: -0.03,
    pelvisRotation: -0.32,
    chestRotation: 0.24,
    chestScaleX: 1.04,
    chestScaleY: 0.91,
  ),
  DanceBodyKey(
    2,
    rootDx: -27,
    rootDy: 26,
    rootRotation: -0.018,
    pelvisRotation: -0.28,
    chestRotation: 0.2,
    chestScaleX: 1.03,
    chestScaleY: 0.95,
  ),
  DanceBodyKey(
    4,
    rootDx: -20,
    rootDy: 18,
    rootRotation: 0.01,
    pelvisRotation: -0.20,
    chestRotation: 0.08,
    chestScaleY: 1.02,
  ),
  DanceBodyKey(
    8,
    rootDx: 29,
    rootDy: 30,
    rootRotation: 0.04,
    pelvisRotation: 0.35,
    chestRotation: -0.28,
    chestScaleX: 1.05,
    chestScaleY: 0.88,
  ),
  DanceBodyKey(
    12,
    rootDx: 20,
    rootDy: 17,
    rootRotation: -0.01,
    pelvisRotation: 0.20,
    chestRotation: -0.08,
    chestScaleY: 1.025,
  ),
  DanceBodyKey(
    16,
    rootDx: -28,
    rootDy: 30,
    rootRotation: -0.038,
    pelvisRotation: -0.34,
    chestRotation: 0.28,
    chestScaleX: 1.05,
    chestScaleY: 0.88,
  ),
  DanceBodyKey(
    20,
    rootDx: -21,
    rootDy: 17,
    rootRotation: 0.012,
    pelvisRotation: -0.21,
    chestRotation: 0.08,
    chestScaleY: 1.03,
  ),
  DanceBodyKey(
    24,
    rootDx: 29,
    rootDy: 30,
    rootRotation: 0.04,
    pelvisRotation: 0.35,
    chestRotation: -0.29,
    chestScaleX: 1.05,
    chestScaleY: 0.88,
  ),
  DanceBodyKey(
    28,
    rootDx: 20,
    rootDy: 17,
    rootRotation: -0.012,
    pelvisRotation: 0.20,
    chestRotation: -0.08,
    chestScaleY: 1.03,
  ),
  DanceBodyKey(
    30,
    rootDx: -8,
    rootDy: 25,
    rootRotation: -0.02,
    pelvisRotation: -0.1,
    chestRotation: 0.12,
    chestScaleX: 1.02,
    chestScaleY: 0.97,
  ),
  DanceBodyKey(
    31,
    rootDx: -20,
    rootDy: 29,
    rootRotation: -0.03,
    pelvisRotation: -0.24,
    chestRotation: 0.21,
    chestScaleX: 1.04,
    chestScaleY: 0.92,
  ),
  DanceBodyKey(
    32,
    rootDx: -28,
    rootDy: 30,
    rootRotation: -0.035,
    pelvisRotation: -0.34,
    chestRotation: 0.27,
    chestScaleX: 1.05,
    chestScaleY: 0.88,
  ),
];

const _movingChorusOpenHandLTargetKeys = [
  DanceIkTargetKey(0, x: -74, y: 4, bendDirection: -1),
  DanceIkTargetKey(1, x: -74, y: 4, bendDirection: -1),
  DanceIkTargetKey(2, x: -82, y: -10, bendDirection: -1),
  DanceIkTargetKey(3, x: -94, y: -30, bendDirection: -1),
  DanceIkTargetKey(4, x: -104, y: -46, bendDirection: -1),
  DanceIkTargetKey(8, x: -112, y: -78, bendDirection: -1),
  DanceIkTargetKey(12, x: -98, y: -34, bendDirection: -1),
  DanceIkTargetKey(16, x: -72, y: 6, bendDirection: -1),
  DanceIkTargetKey(20, x: -98, y: -38, bendDirection: -1),
  DanceIkTargetKey(24, x: -112, y: -54, bendDirection: -1),
  DanceIkTargetKey(28, x: -92, y: -22, bendDirection: -1),
  DanceIkTargetKey(30, x: -82, y: -4, bendDirection: -1),
  DanceIkTargetKey(31, x: -76, y: 2, bendDirection: -1),
  DanceIkTargetKey(32, x: -74, y: 4, bendDirection: -1),
];

const _movingChorusOpenHandRTargetKeys = [
  DanceIkTargetKey(0, x: 74, y: 6, bendDirection: 1),
  DanceIkTargetKey(1, x: 74, y: 6, bendDirection: 1),
  DanceIkTargetKey(2, x: 84, y: -8, bendDirection: 1),
  DanceIkTargetKey(4, x: 96, y: -28, bendDirection: 1),
  DanceIkTargetKey(8, x: 112, y: -46, bendDirection: 1),
  DanceIkTargetKey(12, x: 106, y: -76, bendDirection: 1),
  DanceIkTargetKey(16, x: 72, y: 4, bendDirection: 1),
  DanceIkTargetKey(20, x: 106, y: -56, bendDirection: 1),
  DanceIkTargetKey(24, x: 112, y: -82, bendDirection: 1),
  DanceIkTargetKey(28, x: 94, y: -26, bendDirection: 1),
  DanceIkTargetKey(30, x: 82, y: -4, bendDirection: 1),
  DanceIkTargetKey(31, x: 76, y: 4, bendDirection: 1),
  DanceIkTargetKey(32, x: 74, y: 6, bendDirection: 1),
];

const _movingChorusOpenFootLTargetKeys = [
  DanceIkTargetKey(0, x: -60, y: 110),
  DanceIkTargetKey(8, x: -60, y: 110),
  DanceIkTargetKey(10, x: -80, y: 88),
  DanceIkTargetKey(12, x: -94, y: 101),
  DanceIkTargetKey(13, x: -88, y: 93),
  DanceIkTargetKey(14, x: -80, y: 89),
  DanceIkTargetKey(15, x: -66, y: 97),
  DanceIkTargetKey(16, x: -60, y: 110),
  DanceIkTargetKey(24, x: -60, y: 110),
  DanceIkTargetKey(26, x: -82, y: 85),
  DanceIkTargetKey(28, x: -98, y: 100),
  DanceIkTargetKey(29, x: -90, y: 92),
  DanceIkTargetKey(30, x: -81, y: 89),
  DanceIkTargetKey(31, x: -66, y: 97),
  DanceIkTargetKey(32, x: -60, y: 110),
];

const _movingChorusOpenFootRTargetKeys = [
  DanceIkTargetKey(0, x: 60, y: 110),
  DanceIkTargetKey(2, x: 80, y: 87),
  DanceIkTargetKey(4, x: 94, y: 101),
  DanceIkTargetKey(5, x: 88, y: 93),
  DanceIkTargetKey(6, x: 80, y: 89),
  DanceIkTargetKey(7, x: 66, y: 97),
  DanceIkTargetKey(8, x: 60, y: 110),
  DanceIkTargetKey(16, x: 60, y: 110),
  DanceIkTargetKey(18, x: 82, y: 84),
  DanceIkTargetKey(20, x: 98, y: 100),
  DanceIkTargetKey(21, x: 90, y: 92),
  DanceIkTargetKey(22, x: 81, y: 89),
  DanceIkTargetKey(23, x: 66, y: 97),
  DanceIkTargetKey(24, x: 60, y: 110),
  DanceIkTargetKey(32, x: 60, y: 110),
];

const _movingChorusOpenFootLKeys = [
  DanceJointKey(0),
  DanceJointKey(8),
  DanceJointKey(10, rotation: 0.06),
  DanceJointKey(12, rotation: 0.14),
  DanceJointKey(14, rotation: 0.05),
  DanceJointKey(15),
  DanceJointKey(16),
  DanceJointKey(24),
  DanceJointKey(26, rotation: 0.07),
  DanceJointKey(28, rotation: 0.15),
  DanceJointKey(30, rotation: 0.05),
  DanceJointKey(31),
  DanceJointKey(32),
];

const _movingChorusOpenFootRKeys = [
  DanceJointKey(0),
  DanceJointKey(2, rotation: -0.06),
  DanceJointKey(4, rotation: -0.14),
  DanceJointKey(6, rotation: -0.05),
  DanceJointKey(7),
  DanceJointKey(8),
  DanceJointKey(16),
  DanceJointKey(18, rotation: -0.07),
  DanceJointKey(20, rotation: -0.15),
  DanceJointKey(22, rotation: -0.05),
  DanceJointKey(23),
  DanceJointKey(24),
  DanceJointKey(32),
];

const _movingChorusOpenHandLKeys = [
  DanceJointKey(0, rotation: 0.08),
  DanceJointKey(5, rotation: -0.08),
  DanceJointKey(9, rotation: -0.20),
  DanceJointKey(13, rotation: -0.04),
  DanceJointKey(16, rotation: 0.08),
  DanceJointKey(21, rotation: -0.08),
  DanceJointKey(25, rotation: -0.18),
  DanceJointKey(29, rotation: -0.02),
  DanceJointKey(32, rotation: 0.08),
];

const _movingChorusOpenHandRKeys = [
  DanceJointKey(0, rotation: -0.08),
  DanceJointKey(5, rotation: 0.08),
  DanceJointKey(9, rotation: 0.16),
  DanceJointKey(13, rotation: 0.21),
  DanceJointKey(16, rotation: -0.08),
  DanceJointKey(21, rotation: 0.12),
  DanceJointKey(25, rotation: 0.22),
  DanceJointKey(29, rotation: 0.02),
  DanceJointKey(32, rotation: -0.08),
];

const _movingChorusOpenClavicleLKeys = [
  DanceJointKey(0),
  DanceJointKey(3, rotation: 0.012),
  DanceJointKey(7, rotation: 0.035),
  DanceJointKey(11, rotation: 0.012),
  DanceJointKey(16),
  DanceJointKey(19, rotation: 0.012),
  DanceJointKey(23, rotation: 0.032),
  DanceJointKey(28, rotation: 0.008),
  DanceJointKey(32),
];

const _movingChorusOpenClavicleRKeys = [
  DanceJointKey(0),
  DanceJointKey(3, rotation: -0.010),
  DanceJointKey(7, rotation: -0.026),
  DanceJointKey(11, rotation: -0.036),
  DanceJointKey(16),
  DanceJointKey(19, rotation: -0.012),
  DanceJointKey(23, rotation: -0.038),
  DanceJointKey(28, rotation: -0.008),
  DanceJointKey(32),
];

// Bridge rock: the target paths visibly pass through double support, but the
// contact metadata names one stabilisation owner at a time. CharacterScene's
// support anchor is singular; overlapping ownership would make two planted
// shoes fight over the root at a phrase handoff. The long diagonal pour
// intentionally has fewer reversals than the chorus.
const _movingBridgeRockContactSpans = [
  GroundSpan(CatBones.footL, 0, 0.25),
  GroundSpan(CatBones.footR, 0.25, 0.5),
  GroundSpan(CatBones.footL, 0.5, 0.75),
  GroundSpan(CatBones.footR, 0.75, 1),
];

const _movingBridgeRockBodyKeys = [
  DanceBodyKey(
    0,
    rootDx: -25,
    rootDy: 42,
    pelvisRotation: -0.30,
    chestRotation: 0.25,
    chestScaleY: 0.89,
  ),
  DanceBodyKey(
    1,
    rootDx: -29,
    rootDy: 39,
    pelvisRotation: -0.32,
    chestRotation: 0.22,
    chestScaleY: 0.92,
  ),
  DanceBodyKey(
    2,
    rootDx: -31,
    rootDy: 35,
    pelvisRotation: -0.34,
    chestRotation: 0.19,
    chestScaleY: 0.95,
  ),
  DanceBodyKey(
    4,
    rootDx: -31,
    rootDy: 29,
    pelvisRotation: -0.34,
    chestRotation: 0.13,
  ),
  DanceBodyKey(
    8,
    rootDx: -8,
    rootDy: 17,
    pelvisRotation: -0.10,
    chestRotation: -0.04,
    chestScaleY: 1.0,
  ),
  DanceBodyKey(
    12,
    rootDx: 25,
    rootDy: 38,
    pelvisRotation: 0.29,
    chestRotation: -0.23,
    chestScaleY: 0.91,
  ),
  DanceBodyKey(
    16,
    rootDx: 10,
    rootDy: 20,
    pelvisRotation: 0.12,
    chestRotation: 0.02,
  ),
  DanceBodyKey(
    20,
    rootDx: -27,
    rootDy: 45,
    pelvisRotation: -0.32,
    chestRotation: 0.27,
    chestScaleY: 0.87,
  ),
  DanceBodyKey(
    24,
    rootDx: -5,
    rootDy: 18,
    pelvisRotation: -0.06,
    chestRotation: -0.05,
    chestScaleY: 1.01,
  ),
  DanceBodyKey(
    28,
    rootDx: 27,
    rootDy: 40,
    pelvisRotation: 0.31,
    chestRotation: -0.25,
    chestScaleY: 0.90,
  ),
  DanceBodyKey(
    30,
    rootDx: -8,
    rootDy: 38,
    pelvisRotation: -0.08,
    chestRotation: 0.08,
    chestScaleY: 0.94,
  ),
  DanceBodyKey(
    31,
    rootDx: -20,
    rootDy: 42,
    pelvisRotation: -0.23,
    chestRotation: 0.2,
    chestScaleY: 0.9,
  ),
  DanceBodyKey(
    32,
    rootDx: -25,
    rootDy: 42,
    pelvisRotation: -0.30,
    chestRotation: 0.25,
    chestScaleY: 0.89,
  ),
];

const _movingBridgeRockHandLTargetKeys = [
  DanceIkTargetKey(0, x: -90, y: 10, bendDirection: -1),
  DanceIkTargetKey(1, x: -90, y: 8, bendDirection: -1),
  DanceIkTargetKey(2, x: -90, y: -8, bendDirection: -1),
  DanceIkTargetKey(4, x: -90, y: -48, bendDirection: -1),
  DanceIkTargetKey(8, x: -72, y: -82, bendDirection: -1),
  DanceIkTargetKey(12, x: -80, y: -42, bendDirection: -1),
  DanceIkTargetKey(16, x: -92, y: 12, bendDirection: -1),
  DanceIkTargetKey(20, x: -86, y: -52, bendDirection: -1),
  DanceIkTargetKey(24, x: -70, y: -86, bendDirection: -1),
  DanceIkTargetKey(28, x: -84, y: -40, bendDirection: -1),
  DanceIkTargetKey(30, x: -88, y: -2, bendDirection: -1),
  DanceIkTargetKey(31, x: -90, y: 8, bendDirection: -1),
  DanceIkTargetKey(32, x: -90, y: 10, bendDirection: -1),
];

const _movingBridgeRockHandRTargetKeys = [
  DanceIkTargetKey(0, x: 76, y: -78, bendDirection: 1),
  DanceIkTargetKey(1, x: 78, y: -76, bendDirection: 1),
  DanceIkTargetKey(2, x: 82, y: -66, bendDirection: 1),
  DanceIkTargetKey(4, x: 86, y: -42, bendDirection: 1),
  DanceIkTargetKey(8, x: 92, y: 4, bendDirection: 1),
  DanceIkTargetKey(12, x: 88, y: -50, bendDirection: 1),
  DanceIkTargetKey(16, x: 72, y: -88, bendDirection: 1),
  DanceIkTargetKey(20, x: 84, y: -44, bendDirection: 1),
  DanceIkTargetKey(24, x: 90, y: 4, bendDirection: 1),
  DanceIkTargetKey(28, x: 88, y: -48, bendDirection: 1),
  DanceIkTargetKey(30, x: 82, y: -68, bendDirection: 1),
  DanceIkTargetKey(31, x: 78, y: -76, bendDirection: 1),
  DanceIkTargetKey(32, x: 76, y: -78, bendDirection: 1),
];

const _movingBridgeRockFootLTargetKeys = [
  DanceIkTargetKey(0, x: -63, y: 110),
  DanceIkTargetKey(12, x: -63, y: 110),
  DanceIkTargetKey(14, x: -48, y: 90),
  DanceIkTargetKey(16, x: -35, y: 104),
  DanceIkTargetKey(18, x: -49, y: 91),
  DanceIkTargetKey(20, x: -63, y: 110),
  DanceIkTargetKey(28, x: -63, y: 110),
  DanceIkTargetKey(30, x: -51, y: 94),
  DanceIkTargetKey(32, x: -63, y: 110),
];

const _movingBridgeRockFootRTargetKeys = [
  DanceIkTargetKey(0, x: 63, y: 110),
  DanceIkTargetKey(4, x: 63, y: 110),
  DanceIkTargetKey(6, x: 48, y: 90),
  DanceIkTargetKey(8, x: 35, y: 104),
  DanceIkTargetKey(10, x: 49, y: 91),
  DanceIkTargetKey(12, x: 63, y: 110),
  DanceIkTargetKey(20, x: 63, y: 110),
  DanceIkTargetKey(22, x: 49, y: 89),
  DanceIkTargetKey(24, x: 34, y: 103),
  DanceIkTargetKey(26, x: 50, y: 91),
  DanceIkTargetKey(28, x: 63, y: 110),
  DanceIkTargetKey(32, x: 63, y: 110),
];

const _movingBridgeRockFootLKeys = [
  DanceJointKey(0),
  DanceJointKey(12),
  DanceJointKey(14, rotation: 0.10),
  DanceJointKey(16, rotation: 0.22),
  DanceJointKey(18, rotation: 0.08),
  DanceJointKey(20),
  DanceJointKey(28),
  DanceJointKey(30, rotation: 0.08),
  DanceJointKey(32),
];

const _movingBridgeRockFootRKeys = [
  DanceJointKey(0),
  DanceJointKey(4),
  DanceJointKey(6, rotation: -0.10),
  DanceJointKey(8, rotation: -0.22),
  DanceJointKey(10, rotation: -0.08),
  DanceJointKey(12),
  DanceJointKey(20),
  DanceJointKey(22, rotation: -0.10),
  DanceJointKey(24, rotation: -0.23),
  DanceJointKey(26, rotation: -0.08),
  DanceJointKey(28),
  DanceJointKey(32),
];

// The bridge has a slower wrist pour than the travelling chorus: one change of
// facing per diagonal rock, delayed behind the shoulder and elbow pathway.
const _movingBridgeRockHandLKeys = [
  DanceJointKey(0, rotation: 0.08),
  DanceJointKey(5, rotation: -0.04),
  DanceJointKey(9, rotation: -0.18),
  DanceJointKey(13, rotation: -0.02),
  DanceJointKey(16, rotation: 0.10),
  DanceJointKey(21, rotation: -0.04),
  DanceJointKey(25, rotation: -0.20),
  DanceJointKey(29, rotation: -0.02),
  DanceJointKey(32, rotation: 0.08),
];

const _movingBridgeRockHandRKeys = [
  DanceJointKey(0, rotation: 0.18),
  DanceJointKey(4, rotation: 0.02),
  DanceJointKey(8, rotation: -0.08),
  DanceJointKey(13, rotation: 0.04),
  DanceJointKey(17, rotation: 0.20),
  DanceJointKey(21, rotation: 0.02),
  DanceJointKey(24, rotation: -0.08),
  DanceJointKey(29, rotation: 0.04),
  DanceJointKey(32, rotation: 0.18),
];

// Body-led pocket: two four-beat plants instead of four two-beat step-touches.
// The free shoe brushes inward and returns along the floor arc while the ribs
// complete one slow roll. Hands remain low enough that the torso—not a fist—
// owns the phrase silhouette.
const _movingBodyRollContactSpans = [
  GroundSpan(CatBones.footL, 0, 0.5),
  GroundSpan(CatBones.footR, 0.5, 1),
];

const _movingBodyRollBodyKeys = [
  DanceBodyKey(
    0,
    rootDx: -20,
    rootDy: 35,
    rootRotation: -0.025,
    pelvisRotation: -0.27,
    chestRotation: 0.23,
    chestScaleY: 0.92,
  ),
  DanceBodyKey(
    1,
    rootDx: -22,
    rootDy: 32,
    rootRotation: -0.032,
    pelvisRotation: -0.29,
    chestRotation: 0.2,
    chestScaleY: 0.94,
  ),
  DanceBodyKey(
    2,
    rootDx: -24,
    rootDy: 28,
    rootRotation: -0.038,
    pelvisRotation: -0.3,
    chestRotation: 0.17,
    chestScaleY: 0.96,
  ),
  DanceBodyKey(
    4,
    rootDx: -24,
    rootDy: 22,
    rootRotation: -0.04,
    pelvisRotation: -0.30,
    chestRotation: 0.12,
    chestScaleY: 0.98,
  ),
  DanceBodyKey(
    8,
    rootDx: -18,
    rootDy: 13,
    rootRotation: -0.015,
    pelvisRotation: -0.18,
    chestRotation: -0.04,
    chestScaleY: 1.03,
  ),
  DanceBodyKey(
    12,
    rootDx: -7,
    rootDy: 20,
    rootRotation: 0.025,
    pelvisRotation: -0.05,
    chestRotation: -0.16,
  ),
  DanceBodyKey(
    16,
    rootDx: 21,
    rootDy: 36,
    rootRotation: 0.03,
    pelvisRotation: 0.28,
    chestRotation: -0.24,
    chestScaleY: 0.91,
  ),
  DanceBodyKey(
    20,
    rootDx: 25,
    rootDy: 23,
    rootRotation: 0.04,
    pelvisRotation: 0.31,
    chestRotation: -0.12,
    chestScaleY: 0.98,
  ),
  DanceBodyKey(
    24,
    rootDx: 18,
    rootDy: 13,
    rootRotation: 0.015,
    pelvisRotation: 0.18,
    chestRotation: 0.05,
    chestScaleY: 1.03,
  ),
  DanceBodyKey(
    28,
    rootDx: 6,
    rootDy: 20,
    rootRotation: -0.025,
    pelvisRotation: 0.04,
    chestRotation: 0.17,
  ),
  DanceBodyKey(
    30,
    rootDx: -8,
    rootDy: 28,
    rootRotation: -0.03,
    pelvisRotation: -0.1,
    chestRotation: 0.2,
    chestScaleY: 0.96,
  ),
  DanceBodyKey(
    31,
    rootDx: -16,
    rootDy: 34,
    rootRotation: -0.027,
    pelvisRotation: -0.22,
    chestRotation: 0.22,
    chestScaleY: 0.93,
  ),
  DanceBodyKey(
    32,
    rootDx: -20,
    rootDy: 35,
    rootRotation: -0.025,
    pelvisRotation: -0.27,
    chestRotation: 0.23,
    chestScaleY: 0.92,
  ),
];

const _movingBodyRollHandLTargetKeys = [
  DanceIkTargetKey(0, x: -76, y: 8, bendDirection: -1),
  DanceIkTargetKey(4, x: -70, y: -8, bendDirection: -1),
  DanceIkTargetKey(8, x: -68, y: -32, bendDirection: -1),
  DanceIkTargetKey(12, x: -72, y: -16, bendDirection: -1),
  DanceIkTargetKey(16, x: -94, y: -16, bendDirection: -1),
  DanceIkTargetKey(20, x: -108, y: -28, bendDirection: -1),
  DanceIkTargetKey(24, x: -112, y: -16, bendDirection: -1),
  DanceIkTargetKey(28, x: -100, y: -8, bendDirection: -1),
  DanceIkTargetKey(32, x: -76, y: 8, bendDirection: -1),
];

const _movingBodyRollHandRTargetKeys = [
  DanceIkTargetKey(0, x: 94, y: -16, bendDirection: 1),
  DanceIkTargetKey(4, x: 108, y: -28, bendDirection: 1),
  DanceIkTargetKey(8, x: 112, y: -16, bendDirection: 1),
  DanceIkTargetKey(12, x: 100, y: -8, bendDirection: 1),
  DanceIkTargetKey(16, x: 76, y: 8, bendDirection: 1),
  DanceIkTargetKey(20, x: 70, y: -8, bendDirection: 1),
  DanceIkTargetKey(24, x: 68, y: -32, bendDirection: 1),
  DanceIkTargetKey(28, x: 72, y: -16, bendDirection: 1),
  DanceIkTargetKey(32, x: 94, y: -16, bendDirection: 1),
];

const _movingBodyRollFootLTargetKeys = [
  DanceIkTargetKey(0, x: -62, y: 110),
  DanceIkTargetKey(16, x: -62, y: 110),
  DanceIkTargetKey(19, x: -55, y: 94),
  DanceIkTargetKey(22, x: -36, y: 104),
  DanceIkTargetKey(25, x: -44, y: 91),
  DanceIkTargetKey(28, x: -56, y: 101),
  DanceIkTargetKey(32, x: -62, y: 110),
];

const _movingBodyRollFootRTargetKeys = [
  DanceIkTargetKey(0, x: 62, y: 110),
  DanceIkTargetKey(3, x: 55, y: 94),
  DanceIkTargetKey(6, x: 36, y: 104),
  DanceIkTargetKey(9, x: 44, y: 91),
  DanceIkTargetKey(12, x: 56, y: 101),
  DanceIkTargetKey(16, x: 62, y: 110),
  DanceIkTargetKey(32, x: 62, y: 110),
];

const _movingBodyRollFootLKeys = [
  DanceJointKey(0),
  DanceJointKey(16),
  DanceJointKey(19, rotation: 0.08),
  DanceJointKey(22, rotation: 0.16),
  DanceJointKey(25, rotation: 0.07),
  DanceJointKey(28, rotation: 0.03),
  DanceJointKey(32),
];

const _movingBodyRollFootRKeys = [
  DanceJointKey(0),
  DanceJointKey(3, rotation: -0.08),
  DanceJointKey(6, rotation: -0.16),
  DanceJointKey(9, rotation: -0.07),
  DanceJointKey(12, rotation: -0.03),
  DanceJointKey(16),
  DanceJointKey(32),
];

const _movingBodyRollHandLKeys = [
  DanceJointKey(0, rotation: 0.10),
  DanceJointKey(8, rotation: -0.22),
  DanceJointKey(16, rotation: 0.14),
  DanceJointKey(24, rotation: -0.16),
  DanceJointKey(32, rotation: 0.10),
];

const _movingBodyRollHandRKeys = [
  DanceJointKey(0, rotation: -0.14),
  DanceJointKey(8, rotation: 0.16),
  DanceJointKey(16, rotation: -0.10),
  DanceJointKey(24, rotation: 0.22),
  DanceJointKey(32, rotation: -0.14),
];

const _movingBodyRollClavicleLKeys = [
  DanceJointKey(0, rotation: 0.024),
  DanceJointKey(8, rotation: -0.036),
  DanceJointKey(16, rotation: 0.022),
  DanceJointKey(24, rotation: -0.032),
  DanceJointKey(32, rotation: 0.024),
];

const _movingBodyRollClavicleRKeys = [
  DanceJointKey(0, rotation: -0.028),
  DanceJointKey(8, rotation: 0.032),
  DanceJointKey(16, rotation: -0.024),
  DanceJointKey(24, rotation: 0.038),
  DanceJointKey(32, rotation: -0.028),
];

// Backup 1: one low scoop per bar. It deliberately HOLDS its counter-pose
// around the lead's three lyric calls: the previous every-few-frames travel
// turned the whole formation into an arm wave.
const _movingGrooveLowCounterHandLTargetKeys = [
  DanceIkTargetKey(0, x: -76, y: -28, bendDirection: -1),
  DanceIkTargetKey(4, x: -84, y: -38, bendDirection: -1),
  DanceIkTargetKey(6, x: -102, y: -56, bendDirection: -1),
  DanceIkTargetKey(8, x: -112, y: -70, bendDirection: -1),
  DanceIkTargetKey(10, x: -104, y: -62, bendDirection: -1),
  DanceIkTargetKey(12, x: -86, y: -38, bendDirection: -1),
  DanceIkTargetKey(16, x: -76, y: -28, bendDirection: -1),
  DanceIkTargetKey(20, x: -72, y: -24, bendDirection: -1),
  DanceIkTargetKey(24, x: -78, y: -30, bendDirection: -1),
  DanceIkTargetKey(28, x: -82, y: -34, bendDirection: -1),
  DanceIkTargetKey(32, x: -76, y: -28, bendDirection: -1),
];

const _movingGrooveLowCounterHandRTargetKeys = [
  DanceIkTargetKey(0, x: 76, y: -22, bendDirection: 1),
  DanceIkTargetKey(4, x: 72, y: -24, bendDirection: 1),
  DanceIkTargetKey(8, x: 78, y: -28, bendDirection: 1),
  DanceIkTargetKey(12, x: 82, y: -32, bendDirection: 1),
  DanceIkTargetKey(16, x: 76, y: -22, bendDirection: 1),
  DanceIkTargetKey(20, x: 84, y: -36, bendDirection: 1),
  DanceIkTargetKey(22, x: 102, y: -54, bendDirection: 1),
  DanceIkTargetKey(24, x: 112, y: -68, bendDirection: 1),
  DanceIkTargetKey(26, x: 104, y: -60, bendDirection: 1),
  DanceIkTargetKey(28, x: 86, y: -36, bendDirection: 1),
  DanceIkTargetKey(32, x: 76, y: -22, bendDirection: 1),
];

// Side answer / post-chorus payoff. The first bar presents outward with the
// right arm instead of copying the hook. Mid-phrase both elbows gather low,
// then the right paw climbs over the head while the left knee floats and the
// left arm carves low/outward on "time is to have fun". That contralateral
// diagonal replaces the earlier two-fists-up cheer (smooth, but too much like
// an exercise cue). The high side sustains through the word, then pours open
// instead of being pulled back to neutral by a one-frame recoil.
const _movingGrooveSideAnswerHandLTargetKeys = [
  DanceIkTargetKey(0, x: -78, y: -24, bendDirection: -1),
  DanceIkTargetKey(4, x: -88, y: -36, bendDirection: -1),
  DanceIkTargetKey(6, x: -84, y: -44, bendDirection: -1),
  DanceIkTargetKey(8, x: -70, y: -58, bendDirection: -1),
  DanceIkTargetKey(10, x: -86, y: -62, bendDirection: -1),
  DanceIkTargetKey(12, x: -100, y: -72, bendDirection: -1),
  DanceIkTargetKey(14, x: -112, y: -84, bendDirection: -1, tension: 0.2),
  DanceIkTargetKey(16, x: -108, y: -80, bendDirection: -1, tension: 0.2),
  DanceIkTargetKey(18, x: -100, y: -68, bendDirection: -1),
  DanceIkTargetKey(20, x: -104, y: -76, bendDirection: -1),
  // Do not send both fists back to the same rib-height home pose after the
  // crown. The left arm keeps pouring around the outside, then hangs low as
  // the right side finishes its larger arc. This recovery is deliberately a
  // different path from the rise, so it reads as released weight rather than
  // a spring retracting the paw.
  DanceIkTargetKey(24, x: -104, y: -58, bendDirection: -1),
  DanceIkTargetKey(26, x: -100, y: -30, bendDirection: -1),
  DanceIkTargetKey(28, x: -92, y: -12, bendDirection: -1),
  DanceIkTargetKey(30, x: -84, y: -6, bendDirection: -1),
  DanceIkTargetKey(32, x: -78, y: -24, bendDirection: -1),
];

const _movingGrooveSideAnswerHandRTargetKeys = [
  DanceIkTargetKey(0, x: 78, y: -26, bendDirection: 1),
  DanceIkTargetKey(4, x: 92, y: -58, bendDirection: 1),
  DanceIkTargetKey(6, x: 106, y: -82, bendDirection: 1),
  DanceIkTargetKey(7, x: 96, y: -74, bendDirection: 1),
  DanceIkTargetKey(8, x: 82, y: -70, bendDirection: 1),
  DanceIkTargetKey(10, x: 66, y: -90, bendDirection: 1),
  DanceIkTargetKey(12, x: 54, y: -108, bendDirection: 1),
  // Keep the crown unmistakably overhead without asking the two-link arm to
  // reach its mathematical limit. The old -152 target clamped the solver at
  // near-full extension, visibly locking the elbow at the payoff.
  DanceIkTargetKey(14, x: 48, y: -120, bendDirection: 1, tension: 0.3),
  DanceIkTargetKey(16, x: 52, y: -118, bendDirection: 1, tension: 0.2),
  DanceIkTargetKey(18, x: 78, y: -96, bendDirection: 1),
  DanceIkTargetKey(20, x: 108, y: -74, bendDirection: 1),
  // The crown exits through a long outside waterfall into a loose low hand.
  // Previously frames 24-32 drove straight back to the same shoulder-height
  // guard as the left paw, producing the repeated aerobics-demo silhouette
  // visible throughout the 90-123s full-song audit.
  DanceIkTargetKey(24, x: 100, y: -42, bendDirection: 1),
  DanceIkTargetKey(26, x: 98, y: -14, bendDirection: 1),
  DanceIkTargetKey(28, x: 88, y: 4, bendDirection: 1),
  DanceIkTargetKey(30, x: 80, y: -8, bendDirection: 1),
  DanceIkTargetKey(32, x: 78, y: -26, bendDirection: 1),
];

const _movingGrooveSideAnswerBodyKeys = [
  DanceBodyKey(
    0,
    rootDx: -16,
    rootDy: 31,
    pelvisRotation: -0.18,
    chestRotation: 0.15,
    chestScaleX: 1.025,
    chestScaleY: 0.965,
  ),
  DanceBodyKey(
    4,
    rootDx: -14,
    rootDy: 23,
    pelvisRotation: -0.16,
    chestRotation: 0.1,
  ),
  DanceBodyKey(
    8,
    rootDx: 16,
    rootDy: 36,
    pelvisRotation: 0.2,
    chestRotation: -0.18,
    chestScaleY: 0.94,
  ),
  DanceBodyKey(
    10,
    rootDx: 18,
    rootDy: 24,
    pelvisRotation: 0.22,
    chestRotation: -0.17,
    chestScaleY: 0.98,
  ),
  DanceBodyKey(
    12,
    rootDx: 18,
    rootDy: 14,
    pelvisRotation: 0.2,
    chestRotation: -0.16,
    chestScaleY: 1.01,
  ),
  DanceBodyKey(
    14,
    rootDx: 10,
    rootDy: 9,
    pelvisRotation: 0.16,
    chestRotation: -0.15,
    chestScaleX: 1.03,
    chestScaleY: 1.025,
  ),
  DanceBodyKey(
    16,
    rootDx: -8,
    rootDy: 12,
    pelvisRotation: -0.08,
    chestRotation: 0.08,
    chestScaleX: 1.03,
    chestScaleY: 1.015,
  ),
  DanceBodyKey(
    18,
    rootDx: -20,
    rootDy: 18,
    pelvisRotation: -0.24,
    chestRotation: 0.16,
    chestScaleY: 1.0,
  ),
  DanceBodyKey(
    20,
    rootDx: -18,
    rootDy: 26,
    pelvisRotation: -0.2,
    chestRotation: 0.14,
    chestScaleY: 0.98,
  ),
  DanceBodyKey(
    24,
    rootDx: 18,
    rootDy: 34,
    pelvisRotation: 0.22,
    chestRotation: -0.18,
    chestScaleY: 0.95,
  ),
  DanceBodyKey(
    28,
    rootDx: 18,
    rootDy: 24,
    pelvisRotation: 0.22,
    chestRotation: -0.14,
    chestScaleY: 0.98,
  ),
  DanceBodyKey(
    30,
    rootDx: 7,
    rootDy: 22,
    pelvisRotation: 0.07,
    chestRotation: -0.05,
  ),
  DanceBodyKey(
    32,
    rootDx: -16,
    rootDy: 31,
    pelvisRotation: -0.18,
    chestRotation: 0.15,
    chestScaleX: 1.025,
    chestScaleY: 0.965,
  ),
];

const _movingGrooveSideAnswerClavicleLKeys = [
  DanceJointKey(0),
  DanceJointKey(8, rotation: 0.04),
  DanceJointKey(10, rotation: 0.05),
  DanceJointKey(12, rotation: 0.07),
  DanceJointKey(14, rotation: 0.09),
  DanceJointKey(16, rotation: 0.08),
  DanceJointKey(18, rotation: 0.06),
  DanceJointKey(20, rotation: 0.05),
  DanceJointKey(24, rotation: 0.04),
  DanceJointKey(32),
];

const _movingGrooveSideAnswerClavicleRKeys = [
  DanceJointKey(0),
  DanceJointKey(4, rotation: 0.08),
  DanceJointKey(6, rotation: 0.13),
  DanceJointKey(8, rotation: 0.05),
  DanceJointKey(10, rotation: 0.16),
  DanceJointKey(12, rotation: 0.24),
  DanceJointKey(14, rotation: 0.3),
  DanceJointKey(16, rotation: 0.28),
  DanceJointKey(18, rotation: 0.18),
  DanceJointKey(20, rotation: 0.09),
  DanceJointKey(24, rotation: 0.03),
  DanceJointKey(32),
];

// The focus follows the rising diagonal but arrives after the shoulder. This
// is deliberately visible (the shared groove head motion is subtler): a fixed
// upright skull was preserving the "exercise demo" feeling even after the
// limbs became asymmetrical.
const _movingGrooveSideAnswerHeadKeys = [
  DanceJointKey(0, rotation: 0.035),
  DanceJointKey(4, rotation: -0.015),
  DanceJointKey(8, rotation: -0.045),
  DanceJointKey(10, rotation: -0.07),
  DanceJointKey(12, rotation: -0.1),
  DanceJointKey(14, rotation: -0.13),
  DanceJointKey(16, rotation: -0.11),
  DanceJointKey(18, rotation: -0.055),
  DanceJointKey(20, rotation: 0.015),
  DanceJointKey(24, rotation: 0.055),
  DanceJointKey(28, rotation: 0.025),
  DanceJointKey(32, rotation: 0.035),
];

// Second verse sentence: a loose side-window carve over the heel shuffle.
// Unlike the first verse's alternating waist-level scoops, this phrase keeps
// one arm as a low counterweight while the other travels beside the face and
// opens into the upper corner. The elbow leads the rise, the shoulder follows,
// and the paw arrives last; the return pours down the outside rather than
// reversing the same path like a spring. Bar 2 changes leader instead of
// mirroring bar 1 exactly, which gives repeat verses a recognisable variation.
const _movingVerseWindowHandLTargetKeys = [
  DanceIkTargetKey(0, x: -72, y: -30, bendDirection: -1),
  DanceIkTargetKey(4, x: -94, y: -54, bendDirection: -1),
  DanceIkTargetKey(8, x: -108, y: -78, bendDirection: -1, tension: 0.2),
  DanceIkTargetKey(12, x: -90, y: -52, bendDirection: -1),
  DanceIkTargetKey(16, x: -70, y: -54, bendDirection: -1),
  DanceIkTargetKey(18, x: -64, y: -72, bendDirection: -1),
  DanceIkTargetKey(20, x: -58, y: -102, bendDirection: -1),
  DanceIkTargetKey(22, x: -56, y: -124, bendDirection: -1),
  DanceIkTargetKey(24, x: -68, y: -132, bendDirection: -1, tension: 0.25),
  DanceIkTargetKey(26, x: -92, y: -112, bendDirection: -1),
  DanceIkTargetKey(28, x: -108, y: -78, bendDirection: -1),
  DanceIkTargetKey(32, x: -72, y: -30, bendDirection: -1),
];

const _movingVerseWindowHandRTargetKeys = [
  DanceIkTargetKey(0, x: 68, y: -56, bendDirection: 1),
  DanceIkTargetKey(4, x: 76, y: -38, bendDirection: 1),
  DanceIkTargetKey(8, x: 92, y: -50, bendDirection: 1),
  DanceIkTargetKey(10, x: 106, y: -76, bendDirection: 1),
  DanceIkTargetKey(12, x: 112, y: -92, bendDirection: 1, tension: 0.2),
  DanceIkTargetKey(14, x: 96, y: -70, bendDirection: 1),
  DanceIkTargetKey(16, x: 76, y: -42, bendDirection: 1),
  // Bar 2 belongs to the left arm's face-window climb. Let the right paw
  // counterbalance it below the belt in one pendular outside arc instead of
  // continuing the same shoulder-height fist wave underneath.
  DanceIkTargetKey(18, x: 76, y: -28, bendDirection: 1),
  DanceIkTargetKey(20, x: 80, y: -16, bendDirection: 1),
  DanceIkTargetKey(22, x: 82, y: -6, bendDirection: 1),
  DanceIkTargetKey(24, x: 82, y: -2, bendDirection: 1, tension: 0.2),
  DanceIkTargetKey(26, x: 80, y: -6, bendDirection: 1),
  DanceIkTargetKey(28, x: 76, y: -14, bendDirection: 1),
  DanceIkTargetKey(30, x: 72, y: -24, bendDirection: 1),
  DanceIkTargetKey(32, x: 68, y: -56, bendDirection: 1),
];

const _movingVerseWindowBodyKeys = [
  DanceBodyKey(
    0,
    rootDx: -24,
    rootDy: 34,
    pelvisRotation: -0.27,
    chestRotation: 0.2,
    chestScaleY: 0.94,
  ),
  DanceBodyKey(
    4,
    rootDx: -16,
    rootDy: 21,
    pelvisRotation: -0.16,
    chestRotation: 0.11,
  ),
  DanceBodyKey(
    8,
    rootDx: 20,
    rootDy: 30,
    pelvisRotation: 0.23,
    chestRotation: -0.18,
    chestScaleY: 0.96,
  ),
  DanceBodyKey(
    12,
    rootDx: 25,
    rootDy: 17,
    pelvisRotation: 0.26,
    chestRotation: -0.19,
    chestScaleX: 1.025,
  ),
  DanceBodyKey(
    16,
    rootDx: -18,
    rootDy: 38,
    pelvisRotation: -0.22,
    chestRotation: 0.17,
    chestScaleY: 0.92,
  ),
  DanceBodyKey(
    20,
    rootDx: -25,
    rootDy: 22,
    pelvisRotation: -0.27,
    chestRotation: 0.2,
    chestScaleY: 0.99,
  ),
  DanceBodyKey(
    24,
    rootDx: 16,
    rootDy: 25,
    pelvisRotation: 0.18,
    chestRotation: -0.14,
    chestScaleX: 1.03,
    chestScaleY: 1.0,
  ),
  DanceBodyKey(
    28,
    rootDx: 12,
    rootDy: 19,
    pelvisRotation: 0.1,
    chestRotation: -0.07,
  ),
  DanceBodyKey(
    32,
    rootDx: -24,
    rootDy: 34,
    pelvisRotation: -0.27,
    chestRotation: 0.2,
    chestScaleY: 0.94,
  ),
];

const _movingVerseWindowClavicleLKeys = [
  DanceJointKey(0, rotation: 0.02),
  DanceJointKey(8, rotation: 0.1),
  DanceJointKey(12, rotation: 0.04),
  DanceJointKey(16, rotation: 0.06),
  DanceJointKey(18, rotation: 0.11),
  DanceJointKey(20, rotation: 0.18),
  DanceJointKey(22, rotation: 0.23),
  DanceJointKey(24, rotation: 0.21),
  DanceJointKey(26, rotation: 0.15),
  DanceJointKey(28, rotation: 0.08),
  DanceJointKey(32, rotation: 0.02),
];

const _movingVerseWindowClavicleRKeys = [
  DanceJointKey(0, rotation: 0.04),
  DanceJointKey(4, rotation: 0.02),
  DanceJointKey(8, rotation: 0.07),
  DanceJointKey(10, rotation: 0.12),
  DanceJointKey(12, rotation: 0.16),
  DanceJointKey(14, rotation: 0.1),
  DanceJointKey(16, rotation: 0.03),
  DanceJointKey(32, rotation: 0.04),
];

// Verse arms: broad, sustained scoops that counter the heel brush.  Each hand
// owns half a bar and passes the focus through the sternum; nothing fires for a
// single frame and snaps home.  The silhouette stays below the hook's crown so
// the chorus still has somewhere to grow.
const _movingVerseHandLTargetKeys = [
  DanceIkTargetKey(0, x: -78, y: -26, bendDirection: -1),
  DanceIkTargetKey(4, x: -98, y: -52, bendDirection: -1),
  DanceIkTargetKey(8, x: -106, y: -66, bendDirection: -1),
  DanceIkTargetKey(12, x: -86, y: -38, bendDirection: -1),
  DanceIkTargetKey(16, x: -74, y: -24, bendDirection: -1),
  DanceIkTargetKey(20, x: -82, y: -50, bendDirection: -1),
  DanceIkTargetKey(24, x: -94, y: -68, bendDirection: -1),
  DanceIkTargetKey(28, x: -104, y: -54, bendDirection: -1),
  DanceIkTargetKey(32, x: -78, y: -26, bendDirection: -1),
];

const _movingVerseHandRTargetKeys = [
  DanceIkTargetKey(0, x: 66, y: -48, bendDirection: 1),
  DanceIkTargetKey(4, x: 76, y: -30, bendDirection: 1),
  DanceIkTargetKey(8, x: 96, y: -58, bendDirection: 1),
  DanceIkTargetKey(12, x: 106, y: -66, bendDirection: 1),
  DanceIkTargetKey(16, x: 84, y: -36, bendDirection: 1),
  DanceIkTargetKey(20, x: 104, y: -62, bendDirection: 1),
  DanceIkTargetKey(24, x: 92, y: -68, bendDirection: 1),
  DanceIkTargetKey(28, x: 68, y: -34, bendDirection: 1),
  DanceIkTargetKey(32, x: 66, y: -48, bendDirection: 1),
];

// Bridge arms: one side reaches beyond the ribcage while the other stays loose
// and low, then the roles trade in bar two.  The broad endpoint follows the
// weighted heel rather than arriving with it; the return passes through an
// outside recovery instead of snapping both fists back beside the waist.
const _movingBreakdownHandLTargetKeys = [
  DanceIkTargetKey(0, x: -72, y: -24, bendDirection: -1),
  DanceIkTargetKey(4, x: -90, y: -52, bendDirection: -1),
  DanceIkTargetKey(8, x: -122, y: -72, bendDirection: -1, tension: 0.18),
  DanceIkTargetKey(12, x: -112, y: -60, bendDirection: -1),
  DanceIkTargetKey(16, x: -78, y: -30, bendDirection: -1),
  DanceIkTargetKey(20, x: -82, y: -42, bendDirection: -1),
  DanceIkTargetKey(24, x: -90, y: -54, bendDirection: -1),
  DanceIkTargetKey(28, x: -116, y: -68, bendDirection: -1, tension: 0.15),
  DanceIkTargetKey(30, x: -94, y: -48, bendDirection: -1),
  DanceIkTargetKey(32, x: -72, y: -24, bendDirection: -1),
];

const _movingBreakdownHandRTargetKeys = [
  DanceIkTargetKey(0, x: 72, y: -24, bendDirection: 1),
  DanceIkTargetKey(4, x: 76, y: -32, bendDirection: 1),
  DanceIkTargetKey(8, x: 80, y: -18, bendDirection: 1),
  DanceIkTargetKey(12, x: 90, y: -52, bendDirection: 1),
  DanceIkTargetKey(16, x: 120, y: -70, bendDirection: 1, tension: 0.18),
  DanceIkTargetKey(20, x: 110, y: -58, bendDirection: 1),
  DanceIkTargetKey(24, x: 74, y: -22, bendDirection: 1),
  DanceIkTargetKey(28, x: 90, y: -40, bendDirection: 1),
  DanceIkTargetKey(32, x: 72, y: -24, bendDirection: 1),
];

// Phrase-specific paw facing. These are intentionally smaller and more
// sustained than the catalogue's hit flicks: the paw turns through an arm arc,
// settles after the endpoint, and never stays welded to the forearm.
const _movingGrooveLowCounterHandLKeys = [
  DanceJointKey(0, rotation: 0.05),
  DanceJointKey(5, rotation: -0.04),
  DanceJointKey(9, rotation: -0.16),
  DanceJointKey(13, rotation: -0.03),
  DanceJointKey(16, rotation: 0.04),
  DanceJointKey(24, rotation: -0.02),
  DanceJointKey(32, rotation: 0.05),
];

const _movingGrooveLowCounterHandRKeys = [
  DanceJointKey(0, rotation: -0.03),
  DanceJointKey(16, rotation: 0.04),
  DanceJointKey(21, rotation: 0.06),
  DanceJointKey(25, rotation: 0.17),
  DanceJointKey(29, rotation: 0.03),
  DanceJointKey(32, rotation: -0.03),
];

const _movingGrooveSideAnswerHandLKeys = [
  DanceJointKey(0, rotation: 0.05),
  DanceJointKey(7, rotation: -0.03),
  DanceJointKey(15, rotation: -0.14),
  DanceJointKey(19, rotation: -0.06),
  DanceJointKey(25, rotation: 0.05),
  DanceJointKey(30, rotation: 0.10),
  DanceJointKey(32, rotation: 0.05),
];

const _movingGrooveSideAnswerHandRKeys = [
  DanceJointKey(0, rotation: -0.04),
  DanceJointKey(7, rotation: 0.08),
  DanceJointKey(15, rotation: 0.19),
  DanceJointKey(18, rotation: 0.10),
  DanceJointKey(23, rotation: -0.04),
  DanceJointKey(28, rotation: -0.12),
  DanceJointKey(32, rotation: -0.04),
];

const _movingVerseHandLKeys = [
  DanceJointKey(0, rotation: 0.04),
  DanceJointKey(5, rotation: -0.04),
  DanceJointKey(9, rotation: -0.13),
  DanceJointKey(13, rotation: 0.02),
  DanceJointKey(17, rotation: 0.06),
  DanceJointKey(25, rotation: -0.14),
  DanceJointKey(29, rotation: -0.02),
  DanceJointKey(32, rotation: 0.04),
];

const _movingVerseHandRKeys = [
  DanceJointKey(0, rotation: -0.06),
  DanceJointKey(5, rotation: 0.04),
  DanceJointKey(13, rotation: 0.14),
  DanceJointKey(17, rotation: -0.02),
  DanceJointKey(21, rotation: 0.13),
  DanceJointKey(25, rotation: 0.05),
  DanceJointKey(29, rotation: -0.05),
  DanceJointKey(32, rotation: -0.06),
];

const _movingVerseWindowHandLKeys = [
  DanceJointKey(0, rotation: 0.06),
  DanceJointKey(9, rotation: -0.12),
  DanceJointKey(14, rotation: -0.02),
  DanceJointKey(19, rotation: -0.08),
  DanceJointKey(25, rotation: -0.19),
  DanceJointKey(29, rotation: -0.05),
  DanceJointKey(32, rotation: 0.06),
];

const _movingVerseWindowHandRKeys = [
  DanceJointKey(0, rotation: -0.05),
  DanceJointKey(7, rotation: 0.04),
  DanceJointKey(13, rotation: 0.17),
  DanceJointKey(17, rotation: 0.04),
  DanceJointKey(24, rotation: -0.10),
  DanceJointKey(29, rotation: -0.03),
  DanceJointKey(32, rotation: -0.05),
];

const _movingBreakdownHandLKeys = [
  DanceJointKey(0, rotation: 0.05),
  DanceJointKey(5, rotation: -0.04),
  DanceJointKey(9, rotation: -0.15),
  DanceJointKey(13, rotation: -0.02),
  DanceJointKey(17, rotation: 0.05),
  DanceJointKey(25, rotation: -0.10),
  DanceJointKey(29, rotation: -0.15),
  DanceJointKey(32, rotation: 0.05),
];

const _movingBreakdownHandRKeys = [
  DanceJointKey(0, rotation: -0.05),
  DanceJointKey(8, rotation: -0.02),
  DanceJointKey(13, rotation: 0.08),
  DanceJointKey(17, rotation: 0.16),
  DanceJointKey(21, rotation: 0.04),
  DanceJointKey(25, rotation: -0.04),
  DanceJointKey(29, rotation: 0.15),
  DanceJointKey(32, rotation: -0.05),
];

// Step-touch feet. The support shoe stays broad and quiet for two beats. The
// free shoe peels, taps inward on the ball, REBOUNDS into the air, and only then
// travels back out to become the next support. The old touch->plant segment
// stayed at floor height for four frames, visibly scraping the shoe sideways.
// This touch-lift-land arc is the small but crucial human weight transfer.
const _movingGrooveFootLTargetKeys = [
  DanceIkTargetKey(0, x: -58, y: 110),
  DanceIkTargetKey(8, x: -58, y: 110),
  DanceIkTargetKey(10, x: -46, y: 84),
  DanceIkTargetKey(12, x: -28, y: 106, tension: 0.25),
  DanceIkTargetKey(13, x: -34, y: 91, microFrames: 0.5),
  DanceIkTargetKey(14, x: -46, y: 82),
  DanceIkTargetKey(15, x: -55, y: 95),
  DanceIkTargetKey(16, x: -58, y: 110),
  DanceIkTargetKey(24, x: -58, y: 110),
  DanceIkTargetKey(26, x: -45, y: 82),
  DanceIkTargetKey(28, x: -25, y: 105, tension: 0.3),
  DanceIkTargetKey(29, x: -32, y: 90, microFrames: 0.35),
  DanceIkTargetKey(30, x: -46, y: 83),
  DanceIkTargetKey(31, x: -55, y: 96),
  DanceIkTargetKey(32, x: -58, y: 110),
];

const _movingGrooveFootRTargetKeys = [
  DanceIkTargetKey(0, x: 58, y: 110),
  DanceIkTargetKey(2, x: 46, y: 84),
  DanceIkTargetKey(4, x: 28, y: 106, tension: 0.25),
  DanceIkTargetKey(5, x: 34, y: 91, microFrames: 0.5),
  DanceIkTargetKey(6, x: 46, y: 82),
  DanceIkTargetKey(7, x: 55, y: 95),
  DanceIkTargetKey(8, x: 58, y: 110),
  DanceIkTargetKey(16, x: 58, y: 110),
  DanceIkTargetKey(18, x: 45, y: 82),
  DanceIkTargetKey(20, x: 25, y: 105, tension: 0.3),
  DanceIkTargetKey(21, x: 32, y: 90, microFrames: 0.35),
  DanceIkTargetKey(22, x: 46, y: 83),
  DanceIkTargetKey(23, x: 55, y: 96),
  DanceIkTargetKey(24, x: 58, y: 110),
  DanceIkTargetKey(32, x: 58, y: 110),
];

// Verse — heel-tap shuffle. The free shoe opens wide, brushes back under the
// body and re-plants; the body commits over the other shoe before the next
// release. This gives the verse its own visible footwork rather than merely
// changing the chorus arms.
const _movingVerseBodyKeys = [
  DanceBodyKey(
    0,
    rootDx: -22,
    rootDy: 30,
    pelvisRotation: -0.24,
    chestRotation: 0.16,
    chestScaleY: 0.95,
  ),
  DanceBodyKey(
    2,
    rootDx: -20,
    rootDy: 18,
    pelvisRotation: -0.17,
    chestRotation: 0.10,
  ),
  DanceBodyKey(
    4,
    rootDx: -12,
    rootDy: 24,
    pelvisRotation: -0.10,
    chestRotation: 0.06,
  ),
  DanceBodyKey(
    6,
    rootDx: 2,
    rootDy: 16,
    pelvisRotation: 0.02,
    chestRotation: -0.02,
  ),
  DanceBodyKey(
    8,
    rootDx: 22,
    rootDy: 31,
    pelvisRotation: 0.25,
    chestRotation: -0.17,
    chestScaleY: 0.95,
  ),
  DanceBodyKey(
    10,
    rootDx: 20,
    rootDy: 18,
    pelvisRotation: 0.17,
    chestRotation: -0.10,
  ),
  DanceBodyKey(
    12,
    rootDx: 12,
    rootDy: 24,
    pelvisRotation: 0.10,
    chestRotation: -0.06,
  ),
  DanceBodyKey(
    14,
    rootDx: -2,
    rootDy: 16,
    pelvisRotation: -0.02,
    chestRotation: 0.02,
  ),
  DanceBodyKey(
    16,
    rootDx: -24,
    rootDy: 33,
    pelvisRotation: -0.27,
    chestRotation: 0.18,
    chestScaleY: 0.94,
  ),
  DanceBodyKey(
    18,
    rootDx: -21,
    rootDy: 18,
    pelvisRotation: -0.18,
    chestRotation: 0.11,
  ),
  DanceBodyKey(
    20,
    rootDx: -10,
    rootDy: 25,
    pelvisRotation: -0.08,
    chestRotation: 0.05,
  ),
  DanceBodyKey(
    22,
    rootDx: 4,
    rootDy: 16,
    pelvisRotation: 0.04,
    chestRotation: -0.03,
  ),
  DanceBodyKey(
    24,
    rootDx: 24,
    rootDy: 34,
    pelvisRotation: 0.28,
    chestRotation: -0.19,
    chestScaleY: 0.94,
  ),
  DanceBodyKey(
    26,
    rootDx: 21,
    rootDy: 18,
    pelvisRotation: 0.18,
    chestRotation: -0.11,
  ),
  DanceBodyKey(
    28,
    rootDx: 10,
    rootDy: 25,
    pelvisRotation: 0.08,
    chestRotation: -0.05,
  ),
  DanceBodyKey(
    30,
    rootDx: -4,
    rootDy: 16,
    pelvisRotation: -0.04,
    chestRotation: 0.03,
  ),
  DanceBodyKey(
    32,
    rootDx: -22,
    rootDy: 30,
    pelvisRotation: -0.24,
    chestRotation: 0.16,
    chestScaleY: 0.95,
  ),
];

const _movingVerseFootLTargetKeys = [
  DanceIkTargetKey(0, x: -58, y: 110),
  DanceIkTargetKey(8, x: -58, y: 110),
  DanceIkTargetKey(10, x: -68, y: 94),
  DanceIkTargetKey(12, x: -78, y: 108, tension: 0.2),
  DanceIkTargetKey(13, x: -72, y: 99),
  DanceIkTargetKey(14, x: -65, y: 95),
  DanceIkTargetKey(15, x: -60, y: 103),
  DanceIkTargetKey(16, x: -58, y: 110),
  DanceIkTargetKey(24, x: -58, y: 110),
  DanceIkTargetKey(26, x: -70, y: 93),
  DanceIkTargetKey(28, x: -80, y: 108, tension: 0.2),
  DanceIkTargetKey(29, x: -74, y: 99),
  DanceIkTargetKey(30, x: -65, y: 95),
  DanceIkTargetKey(31, x: -60, y: 103),
  DanceIkTargetKey(32, x: -58, y: 110),
];

const _movingVerseFootRTargetKeys = [
  DanceIkTargetKey(0, x: 58, y: 110),
  DanceIkTargetKey(2, x: 68, y: 94),
  DanceIkTargetKey(4, x: 78, y: 108, tension: 0.2),
  DanceIkTargetKey(5, x: 72, y: 99),
  DanceIkTargetKey(6, x: 65, y: 95),
  DanceIkTargetKey(7, x: 60, y: 103),
  DanceIkTargetKey(8, x: 58, y: 110),
  DanceIkTargetKey(16, x: 58, y: 110),
  DanceIkTargetKey(18, x: 70, y: 93),
  DanceIkTargetKey(20, x: 80, y: 108, tension: 0.2),
  DanceIkTargetKey(21, x: 74, y: 99),
  DanceIkTargetKey(22, x: 65, y: 95),
  DanceIkTargetKey(23, x: 60, y: 103),
  DanceIkTargetKey(24, x: 58, y: 110),
  DanceIkTargetKey(32, x: 58, y: 110),
];

// A heel brush is ankle-led, not a knee-high kick: the shoe rotates only a
// little as it skims out and in. Keeping this separate from the chorus foot
// rotation is what lets the verse read as a shuffle rather than a flick.
const _movingVerseFootLKeys = [
  DanceJointKey(0),
  DanceJointKey(8),
  DanceJointKey(10, rotation: 0.08),
  DanceJointKey(12, rotation: 0.18),
  DanceJointKey(13, rotation: 0.06),
  DanceJointKey(14, rotation: 0.03),
  DanceJointKey(15, rotation: 0.05),
  DanceJointKey(16),
  DanceJointKey(24),
  DanceJointKey(26, rotation: 0.08),
  DanceJointKey(28, rotation: 0.18),
  DanceJointKey(29, rotation: 0.06),
  DanceJointKey(30, rotation: 0.03),
  DanceJointKey(31, rotation: 0.05),
  DanceJointKey(32),
];

const _movingVerseFootRKeys = [
  DanceJointKey(0),
  DanceJointKey(2, rotation: -0.08),
  DanceJointKey(4, rotation: -0.18),
  DanceJointKey(5, rotation: -0.06),
  DanceJointKey(6, rotation: -0.03),
  DanceJointKey(7, rotation: -0.05),
  DanceJointKey(8),
  DanceJointKey(16),
  DanceJointKey(18, rotation: -0.08),
  DanceJointKey(20, rotation: -0.18),
  DanceJointKey(21, rotation: -0.06),
  DanceJointKey(22, rotation: -0.03),
  DanceJointKey(23, rotation: -0.05),
  DanceJointKey(24),
  DanceJointKey(32),
];

// Bridge — a low two-pulse heel bounce: both knees stay springy while each
// free heel pops cleanly off the floor. It contrasts with the verse shuffle
// without changing into a borrowed catalogue dance.
const _movingBreakdownBodyKeys = [
  DanceBodyKey(
    0,
    rootDx: -14,
    rootDy: 44,
    pelvisRotation: -0.18,
    chestRotation: 0.12,
    chestScaleY: 0.86,
  ),
  DanceBodyKey(
    2,
    rootDx: -9,
    rootDy: 26,
    pelvisRotation: -0.10,
    chestRotation: 0.07,
    chestScaleY: 0.96,
  ),
  DanceBodyKey(
    4,
    rootDx: 14,
    rootDy: 44,
    pelvisRotation: 0.18,
    chestRotation: -0.12,
    chestScaleY: 0.86,
  ),
  DanceBodyKey(
    6,
    rootDx: 9,
    rootDy: 26,
    pelvisRotation: 0.10,
    chestRotation: -0.07,
    chestScaleY: 0.96,
  ),
  DanceBodyKey(
    8,
    rootDx: -14,
    rootDy: 44,
    pelvisRotation: -0.18,
    chestRotation: 0.12,
    chestScaleY: 0.86,
  ),
  DanceBodyKey(
    10,
    rootDx: -9,
    rootDy: 26,
    pelvisRotation: -0.10,
    chestRotation: 0.07,
    chestScaleY: 0.96,
  ),
  DanceBodyKey(
    12,
    rootDx: 14,
    rootDy: 44,
    pelvisRotation: 0.18,
    chestRotation: -0.12,
    chestScaleY: 0.86,
  ),
  DanceBodyKey(
    14,
    rootDx: 9,
    rootDy: 26,
    pelvisRotation: 0.10,
    chestRotation: -0.07,
    chestScaleY: 0.96,
  ),
  DanceBodyKey(
    16,
    rootDx: -18,
    rootDy: 46,
    pelvisRotation: -0.22,
    chestRotation: 0.14,
    chestScaleY: 0.84,
  ),
  DanceBodyKey(
    18,
    rootDx: -10,
    rootDy: 26,
    pelvisRotation: -0.10,
    chestRotation: 0.07,
    chestScaleY: 0.96,
  ),
  DanceBodyKey(
    20,
    rootDx: 18,
    rootDy: 46,
    pelvisRotation: 0.22,
    chestRotation: -0.14,
    chestScaleY: 0.84,
  ),
  DanceBodyKey(
    22,
    rootDx: 10,
    rootDy: 26,
    pelvisRotation: 0.10,
    chestRotation: -0.07,
    chestScaleY: 0.96,
  ),
  DanceBodyKey(
    24,
    rootDx: -18,
    rootDy: 46,
    pelvisRotation: -0.22,
    chestRotation: 0.14,
    chestScaleY: 0.84,
  ),
  DanceBodyKey(
    26,
    rootDx: -10,
    rootDy: 26,
    pelvisRotation: -0.10,
    chestRotation: 0.07,
    chestScaleY: 0.96,
  ),
  DanceBodyKey(
    28,
    rootDx: 18,
    rootDy: 46,
    pelvisRotation: 0.22,
    chestRotation: -0.14,
    chestScaleY: 0.84,
  ),
  DanceBodyKey(
    30,
    rootDx: 10,
    rootDy: 26,
    pelvisRotation: 0.10,
    chestRotation: -0.07,
    chestScaleY: 0.96,
  ),
  DanceBodyKey(
    32,
    rootDx: -14,
    rootDy: 44,
    pelvisRotation: -0.18,
    chestRotation: 0.12,
    chestScaleY: 0.86,
  ),
];

const _movingBreakdownFootLTargetKeys = [
  DanceIkTargetKey(0, x: -58, y: 110),
  DanceIkTargetKey(4, x: -58, y: 110),
  DanceIkTargetKey(6, x: -54, y: 78),
  DanceIkTargetKey(8, x: -58, y: 110),
  DanceIkTargetKey(12, x: -58, y: 110),
  DanceIkTargetKey(14, x: -54, y: 76),
  DanceIkTargetKey(16, x: -58, y: 110),
  DanceIkTargetKey(20, x: -58, y: 110),
  DanceIkTargetKey(22, x: -54, y: 74),
  DanceIkTargetKey(24, x: -58, y: 110),
  DanceIkTargetKey(28, x: -58, y: 110),
  DanceIkTargetKey(30, x: -54, y: 76),
  DanceIkTargetKey(32, x: -58, y: 110),
];

const _movingBreakdownFootRTargetKeys = [
  DanceIkTargetKey(0, x: 58, y: 110),
  DanceIkTargetKey(2, x: 54, y: 78),
  DanceIkTargetKey(4, x: 58, y: 110),
  DanceIkTargetKey(8, x: 58, y: 110),
  DanceIkTargetKey(10, x: 54, y: 76),
  DanceIkTargetKey(12, x: 58, y: 110),
  DanceIkTargetKey(16, x: 58, y: 110),
  DanceIkTargetKey(18, x: 54, y: 74),
  DanceIkTargetKey(20, x: 58, y: 110),
  DanceIkTargetKey(24, x: 58, y: 110),
  DanceIkTargetKey(26, x: 54, y: 76),
  DanceIkTargetKey(28, x: 58, y: 110),
  DanceIkTargetKey(32, x: 58, y: 110),
];

const _movingBreakdownFootLKeys = [
  DanceJointKey(0),
  DanceJointKey(4),
  DanceJointKey(6, rotation: 0.12),
  DanceJointKey(8),
  DanceJointKey(12),
  DanceJointKey(14, rotation: 0.12),
  DanceJointKey(16),
  DanceJointKey(20),
  DanceJointKey(22, rotation: 0.14),
  DanceJointKey(24),
  DanceJointKey(28),
  DanceJointKey(30, rotation: 0.12),
  DanceJointKey(32),
];

const _movingBreakdownFootRKeys = [
  DanceJointKey(0),
  DanceJointKey(2, rotation: -0.12),
  DanceJointKey(4),
  DanceJointKey(8),
  DanceJointKey(10, rotation: -0.12),
  DanceJointKey(12),
  DanceJointKey(16),
  DanceJointKey(18, rotation: -0.14),
  DanceJointKey(20),
  DanceJointKey(24),
  DanceJointKey(26, rotation: -0.12),
  DanceJointKey(28),
  DanceJointKey(32),
];

const _movingGrooveFootLKeys = [
  DanceJointKey(0),
  DanceJointKey(8),
  DanceJointKey(10, rotation: 0.22),
  DanceJointKey(12, rotation: 0.5),
  DanceJointKey(13, rotation: 0.18, microFrames: 0.5),
  DanceJointKey(14, rotation: 0.08),
  DanceJointKey(15, rotation: 0.16),
  DanceJointKey(16),
  DanceJointKey(24),
  DanceJointKey(26, rotation: 0.24),
  DanceJointKey(28, rotation: 0.56),
  DanceJointKey(29, rotation: 0.2, microFrames: 0.35),
  DanceJointKey(30, rotation: 0.08),
  DanceJointKey(31, rotation: 0.16),
  DanceJointKey(32),
];

const _movingGrooveFootRKeys = [
  DanceJointKey(0),
  DanceJointKey(2, rotation: -0.22),
  DanceJointKey(4, rotation: -0.5),
  DanceJointKey(5, rotation: -0.18, microFrames: 0.5),
  DanceJointKey(6, rotation: -0.08),
  DanceJointKey(7, rotation: -0.16),
  DanceJointKey(8),
  DanceJointKey(16),
  DanceJointKey(18, rotation: -0.24),
  DanceJointKey(20, rotation: -0.56),
  DanceJointKey(21, rotation: -0.2, microFrames: 0.35),
  DanceJointKey(22, rotation: -0.08),
  DanceJointKey(23, rotation: -0.16),
  DanceJointKey(24),
  DanceJointKey(32),
];

// Keep the paw neutral in the solved forearm frame. The cuff is sleeve-parented
// and the runtime wrist-follow pass supplies only a small delayed paw response.
const _movingGrooveHandLKeys = [
  DanceJointKey(0),
  DanceJointKey(32),
];

const _movingGrooveHandRKeys = [
  DanceJointKey(0),
  DanceJointKey(32),
];

// Fully authored shoulder lead for this song-specific phrase. The active
// clavicle starts rising before its hand, crests just ahead of the hand apex,
// then releases; the opposite side remains quiet enough to preserve the torso
// bank. CharacterScene deliberately skips its generic reach-driven shrug for
// this clip so these keys have a single owner.
const _movingGrooveClavicleLKeys = [
  DanceJointKey(0),
  DanceJointKey(8, rotation: 0.005),
  DanceJointKey(16),
  DanceJointKey(20, rotation: -0.01),
  DanceJointKey(24, rotation: 0.018),
  DanceJointKey(28, rotation: -0.008),
  DanceJointKey(32),
];

const _movingGrooveClavicleRKeys = [
  DanceJointKey(0),
  DanceJointKey(4, rotation: 0.01),
  DanceJointKey(8, rotation: -0.018),
  DanceJointKey(12, rotation: 0.008),
  DanceJointKey(16),
  DanceJointKey(32),
];

// The skull acknowledges the loaded side and arrives last; the angles are
// intentionally smaller than the body bank so this reads as focus, not a wobble.
const _movingGrooveHeadKeys = [
  DanceJointKey(0, rotation: 0.045),
  DanceJointKey(3, rotation: 0.015),
  DanceJointKey(8, rotation: -0.045),
  DanceJointKey(11, rotation: -0.012),
  DanceJointKey(16, rotation: 0.052),
  DanceJointKey(19, rotation: 0.016),
  DanceJointKey(24, rotation: -0.052),
  DanceJointKey(28, rotation: -0.075),
  DanceJointKey(31, rotation: 0.018),
  DanceJointKey(32, rotation: 0.045),
];
