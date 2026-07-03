part of '../cat_in_suit.dart';

// ─────────────────────────────────────────────────────────────────────────
// Standalone "Shaku Shaku" lead redesign — SEPARATE from the shipped `dance`
// so its (heavily geometry-coupled) tests stay intact while this is iterated
// to a 9/10 panel score. Wired in to replace `dance` only once it lands.
// ─────────────────────────────────────────────────────────────────────────

// Recipe groove: the knee-dip BOTTOMS on every count (rootDy high on 0/4/8…,
// chest squashed on the beat) and rises on the off-beats — an on-beat Shaku
// pocket. Lateral sway (rootDx) + counter-rotation kept from the tuned dance.
const _shakuBodyGrooveKeys = [
  DanceBodyKey(
    0,
    rootDx: -14,
    rootDy: 21.7,
    rootRotation: -0.007,
    pelvisRotation: 0.32,
    chestRotation: -0.09,
    chestScaleY: 0.905,
    chestScaleX: 1.06,
  ),
  DanceBodyKey(
    1,
    rootDx: -18,
    rootDy: 18.5,
    rootRotation: -0.009,
    pelvisRotation: 0.43,
    chestRotation: -0.18,
    chestScaleY: 0.955,
    chestScaleX: 1.025,
  ),
  DanceBodyKey(
    2,
    rootDx: -20,
    rootDy: 15.3,
    rootRotation: -0.009,
    pelvisRotation: 0.38,
    chestRotation: -0.11,
    chestScaleY: 1.005,
    chestScaleX: 0.99,
  ),
  DanceBodyKey(
    3,
    rootDx: -19,
    rootDy: 18.5,
    rootRotation: -0.008,
    pelvisRotation: 0.51,
    chestRotation: -0.235,
    chestScaleY: 0.955,
    chestScaleX: 1.025,
  ),
  DanceBodyKey(
    4,
    rootDx: -11,
    rootDy: 21.7,
    rootRotation: -0.007,
    pelvisRotation: 0.53,
    chestRotation: -0.25,
    chestScaleY: 0.905,
    chestScaleX: 1.06,
  ),
  DanceBodyKey(
    5,
    rootDx: -13,
    rootDy: 18.5,
    rootRotation: -0.006,
    pelvisRotation: 0.44,
    chestRotation: -0.24,
    chestScaleY: 0.955,
    chestScaleX: 1.025,
  ),
  DanceBodyKey(
    6,
    rootDx: -12,
    rootDy: 15.3,
    rootRotation: -0.005,
    pelvisRotation: 0.38,
    chestRotation: -0.18,
    chestScaleY: 1.005,
    chestScaleX: 0.99,
  ),
  DanceBodyKey(
    7,
    rootDx: -1,
    rootDy: 18.5,
    rootRotation: 0,
    chestScaleY: 0.955,
    chestScaleX: 1.025,
  ),
  DanceBodyKey(
    8,
    rootDx: 11,
    rootDy: 21.7,
    rootRotation: 0.005,
    pelvisRotation: 0.16,
    chestRotation: -0.02,
    chestScaleY: 0.905,
    chestScaleX: 1.06,
  ),
  DanceBodyKey(
    9,
    rootDx: 12,
    rootDy: 18.5,
    rootRotation: 0.006,
    pelvisRotation: 0.14,
    chestRotation: 0.02,
    chestScaleY: 0.955,
    chestScaleX: 1.025,
  ),
  DanceBodyKey(
    10,
    rootDx: 17,
    rootDy: 15.3,
    rootRotation: 0.008,
    pelvisRotation: 0.08,
    chestRotation: 0.06,
    chestScaleY: 1.005,
    chestScaleX: 0.99,
  ),
  DanceBodyKey(
    11,
    rootDx: 18,
    rootDy: 18.5,
    rootRotation: 0.008,
    pelvisRotation: 0.01,
    chestRotation: 0.045,
    chestScaleY: 0.955,
    chestScaleX: 1.025,
  ),
  DanceBodyKey(
    12,
    rootDx: 18,
    rootDy: 21.7,
    rootRotation: 0.006,
    pelvisRotation: -0.08,
    chestRotation: 0.1,
    chestScaleY: 0.905,
    chestScaleX: 1.06,
  ),
  DanceBodyKey(
    13,
    rootDx: 12,
    rootDy: 18.5,
    rootRotation: 0.004,
    pelvisRotation: -0.16,
    chestRotation: 0.12,
    chestScaleY: 0.955,
    chestScaleX: 1.025,
  ),
  DanceBodyKey(
    14,
    rootDx: 6,
    rootDy: 15.3,
    rootRotation: -0.001,
    pelvisRotation: -0.24,
    chestRotation: 0.14,
    chestScaleY: 1.005,
    chestScaleX: 0.99,
  ),
  DanceBodyKey(
    15,
    rootDx: -1,
    rootDy: 18.5,
    rootRotation: -0.004,
    pelvisRotation: -0.31,
    chestRotation: 0.16,
    chestScaleY: 0.955,
    chestScaleX: 1.025,
  ),
  DanceBodyKey(
    16,
    rootDx: -7,
    rootDy: 21.7,
    rootRotation: -0.006,
    pelvisRotation: -0.36,
    chestRotation: 0.13,
    chestScaleY: 0.905,
    chestScaleX: 1.06,
  ),
  DanceBodyKey(
    17,
    rootDx: -12,
    rootDy: 18.5,
    rootRotation: -0.007,
    pelvisRotation: -0.37,
    chestRotation: 0.12,
    chestScaleY: 0.955,
    chestScaleX: 1.025,
  ),
  DanceBodyKey(
    18,
    rootDx: -12.6,
    rootDy: 15.3,
    rootRotation: -0.008,
    pelvisRotation: -0.36,
    chestRotation: 0.13,
    chestScaleY: 1.005,
    chestScaleX: 0.99,
  ),
  DanceBodyKey(
    19,
    rootDx: -12.2,
    rootDy: 18.5,
    rootRotation: -0.008,
    pelvisRotation: -0.42,
    chestRotation: 0.135,
    chestScaleY: 0.955,
    chestScaleX: 1.025,
  ),
  DanceBodyKey(
    20,
    rootDx: -11.4,
    rootDy: 21.7,
    rootRotation: -0.006,
    pelvisRotation: -0.47,
    chestRotation: 0.16,
    chestScaleY: 0.905,
    chestScaleX: 1.06,
  ),
  DanceBodyKey(
    21,
    rootDx: -9.8,
    rootDy: 18.5,
    rootRotation: -0.004,
    pelvisRotation: -0.42,
    chestRotation: 0.2,
    chestScaleY: 0.955,
    chestScaleX: 1.025,
  ),
  DanceBodyKey(
    22,
    rootDx: -5,
    rootDy: 15.3,
    rootRotation: -0.002,
    pelvisRotation: -0.28,
    chestRotation: -0.03,
    chestScaleY: 1.005,
    chestScaleX: 0.99,
  ),
  DanceBodyKey(
    23,
    rootDx: 2,
    rootDy: 18.5,
    rootRotation: 0.001,
    pelvisRotation: -0.22,
    chestRotation: -0.055,
    chestScaleY: 0.955,
    chestScaleX: 1.025,
  ),
  DanceBodyKey(
    24,
    rootDx: 12,
    rootDy: 21.7,
    rootRotation: 0.007,
    pelvisRotation: -0.24,
    chestRotation: 0.095,
    chestScaleY: 0.905,
    chestScaleX: 1.06,
  ),
  DanceBodyKey(
    26,
    rootDx: 14,
    rootDy: 15.3,
    rootRotation: 0.008,
    pelvisRotation: -0.08,
    chestRotation: -0.06,
    chestScaleY: 1.005,
    chestScaleX: 0.99,
  ),
  DanceBodyKey(
    27,
    rootDx: 13,
    rootDy: 18.5,
    rootRotation: 0.007,
    pelvisRotation: -0.02,
    chestRotation: -0.08,
    chestScaleY: 0.955,
    chestScaleX: 1.025,
  ),
  DanceBodyKey(
    28,
    rootDx: 12,
    rootDy: 21.7,
    rootRotation: 0.006,
    pelvisRotation: 0.04,
    chestRotation: -0.1,
    chestScaleY: 0.905,
    chestScaleX: 1.06,
  ),
  DanceBodyKey(
    29,
    rootDx: 2,
    rootDy: 18.5,
    rootRotation: 0.001,
    pelvisRotation: 0.12,
    chestRotation: -0.18,
    chestScaleY: 0.955,
    chestScaleX: 1.025,
  ),
  DanceBodyKey(
    30,
    rootDx: -7,
    rootDy: 15.3,
    rootRotation: -0.004,
    pelvisRotation: 0.2,
    chestRotation: -0.15,
    chestScaleY: 1.005,
    chestScaleX: 0.99,
  ),
  DanceBodyKey(
    31,
    rootDx: -12.4,
    rootDy: 18.5,
    rootRotation: -0.006,
    pelvisRotation: 0.27,
    chestRotation: -0.125,
    chestScaleY: 0.955,
    chestScaleX: 1.025,
  ),
  DanceBodyKey(
    32,
    rootDx: -14,
    rootDy: 21.7,
    rootRotation: -0.007,
    pelvisRotation: 0.32,
    chestRotation: -0.09,
    chestScaleY: 0.905,
    chestScaleX: 1.06,
  ),
];

/// How far to scale the shaku-family lateral weight commit (1.0 = the authored
/// [_shakuBodyGrooveKeys] groove). The body commits so far to the side that,
/// under a head deliberately kept facing camera, the torso reads as a pendulum
/// swinging beneath a fixed head; pulling the side-to-side commit in tames that
/// without flattening the move.
const double _shakuLateralGain = 0.6;

/// [_shakuBodyGrooveKeys] with only the LATERAL groove scaled by
/// [_shakuLateralGain] — the side-to-side weight commit (`rootDx` +
/// pelvis/chest rotation). The vertical knee-dip (`rootDy`) and the chest
/// squash are preserved, so the on-beat pocket keeps its full depth. Shared by
/// every clip that grooves on these keys — shaku, zanku, azonto (lead and the
/// ensemble backups alike) — so the whole crew commits less far, not just the
/// lead.
final List<DanceBodyKey> _shakuGrooveCalm = [
  for (final k in _shakuBodyGrooveKeys)
    DanceBodyKey(
      k.frame,
      rootDx: k.rootDx == null ? null : k.rootDx! * _shakuLateralGain,
      rootDy: k.rootDy == null ? null : k.rootDy! + 6,
      rootRotation: k.rootRotation == null
          ? null
          : k.rootRotation! * _shakuLateralGain,
      pelvisRotation: k.pelvisRotation == null
          ? null
          : k.pelvisRotation! * _shakuLateralGain,
      chestRotation: k.chestRotation == null
          ? null
          : k.chestRotation! * _shakuLateralGain,
      chestScaleX: k.chestScaleX,
      chestScaleY: k.chestScaleY,
      ease: k.ease,
    ),
];
// Support knee pumps deepest on each count: LEFT supports bar 1 (deep on
// 0/4/8/12), RIGHT supports bar 2 (deep on 16/20/24/28).
const _shakuLegLowerLKeys = [
  // Wider deep/rebound swing so the per-beat root drop has knee absorption
  // to live in — the gallop loads INTO the floor on the count and gets
  // light between supports.
  DanceJointKey(0, rotation: -1.34),
  DanceJointKey(2, rotation: -0.92),
  DanceJointKey(4, rotation: -1.34),
  DanceJointKey(6, rotation: -0.92),
  DanceJointKey(8, rotation: -1.34),
  DanceJointKey(10, rotation: -0.92),
  DanceJointKey(12, rotation: -1.34),
  DanceJointKey(14, rotation: -0.92),
  DanceJointKey(16, rotation: -0.78),
  DanceJointKey(18, rotation: -0.82),
  DanceJointKey(20, rotation: -0.82),
  DanceJointKey(22, rotation: -0.94),
  DanceJointKey(24, rotation: -0.9),
  DanceJointKey(26, rotation: -0.86),
  DanceJointKey(28, rotation: -0.82),
  DanceJointKey(29, rotation: -1.08),
  DanceJointKey(30, rotation: -1.08),
  DanceJointKey(31, rotation: -1.2),
  DanceJointKey(32, rotation: -1.34),
];
const _shakuLegLowerRKeys = [
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
  DanceJointKey(16, rotation: -1.34),
  DanceJointKey(18, rotation: -0.92),
  DanceJointKey(20, rotation: -1.34),
  DanceJointKey(22, rotation: -0.92),
  DanceJointKey(24, rotation: -1.34),
  DanceJointKey(26, rotation: -0.92),
  DanceJointKey(28, rotation: -1.34),
  DanceJointKey(30, rotation: -0.92),
  DanceJointKey(32, rotation: -0.96),
];

// Shaku arm vocabulary: crossed WRISTS, not folded forearms. Each hit keeps
// the elbow on its own side, crosses only the paw/wrist through the centre,
// then opens into a low scoop. That preserves the Shaku X without asking the
// forearm to rotate out through the same-side sleeve.
// The Shaku Shaku X is the LANDLORD, not the visitor (research audit
// finding 2, panel round 1's unanimous shaku critique): the crossed-wrist
// "handcuffed" pose is the HELD base posture — wrists crossing at the
// sternum, both fists breaking past the far silhouette line at staggered
// heights so the X survives at stage distance — and the open scoop is a
// two-frame flash of punctuation landing on the accented beats, re-crossed
// by the next downbeat. Duty cycle: ~24 of 32 frames crossed.
const _shakuHandLTargetKeys = [
  // Round 4: the round-3 "wide" X put each fist ±30 past the midline — at
  // stage distance that reads as two fists parked on opposite sides with
  // the tie visible between them (a boxer's guard, said every rater). A
  // real handcuffed X STACKS the wrists near the sternum midline: paws
  // overlap slightly (offset so both read), forearms make the X, and the
  // TOP wrist alternates per bar. The open accent is a 3-frame LOW SCOOP
  // arc past the knees (lead hand finishes higher than the trail hand),
  // and bar 2 swaps the copy-paste flash for an asymmetric generator pull.
  // Round 6: bar-1's wrist separation (10 vs -6, an 16-unit gap) was too
  // tight at render scale — the rigging/anatomy raters both saw the two
  // fists collapse into one indistinct blob rather than a legible crossed
  // stack. Widened toward the tested |x|<18 ceiling on both hands so the
  // gap between them reads as two shapes even where they're closest.
  DanceIkTargetKey(0, x: 16, y: -56, tension: 1), // X — L wrist on TOP
  DanceIkTargetKey(2, x: 15, y: -48, tension: 0.5), // gallop ride down
  DanceIkTargetKey(4, x: 16, y: -55, tension: 0.9),
  DanceIkTargetKey(6, x: 15, y: -48, tension: 0.5), // ride
  DanceIkTargetKey(8, x: 16, y: -56, tension: 1),
  // Round 6: the scoop's y (10, -16) barely dipped below the X's own
  // sternum height — at that depth the two-bone solve reads as a static
  // hands-on-hips akimbo plant (every rater's complaint at this exact
  // frame), not a sweep. Pushed the low point down past the hip toward
  // the knee so the silhouette actually opens and drops before the lead
  // hand rises back out.
  // R10: every rater independently called the flash "perfect mirror
  // symmetry, like jazz hands" — at frame 12 itself both hands hit the
  // SAME y (20), only diverging a frame later at 13. Made L (the lead
  // hand) dip deeper than R AT frame 12 itself, not just at the next
  // frame, so the asymmetry reads from the first instant of the flash.
  DanceIkTargetKey(11, x: 6, y: -50, tension: 0.8), // squeeze (anticipation)
  DanceIkTargetKey(12, x: -62, y: 24, tension: 0.7), // lead hand sweeps LOWEST
  DanceIkTargetKey(13, x: -76, y: -10, tension: 0.7), // lead hand rises out
  DanceIkTargetKey(14, x: -10, y: -42, tension: 0.5), // closing transit
  DanceIkTargetKey(15, x: 14, y: -58, tension: 0.8), // overcross lands
  // Same separation widening as bar 1 (see its comment) — note bar 2's
  // "L drops UNDER / R takes TOP" intent is aspirational only: hand.L and
  // hand.R carry fixed z (18 and 17), so L always renders in front
  // regardless of bar. Fixing that needs a per-frame z override, which
  // this rig doesn't have yet — left as a known gap rather than guessed at.
  DanceIkTargetKey(16, x: 8, y: -44, tension: 1), // bar-2 X — L drops UNDER
  DanceIkTargetKey(18, x: 7, y: -36, tension: 0.5), // ride
  DanceIkTargetKey(20, x: 8, y: -43, tension: 0.9),
  DanceIkTargetKey(22, x: 7, y: -36, tension: 0.5),
  DanceIkTargetKey(24, x: 8, y: -44, tension: 1),
  DanceIkTargetKey(27, x: -32, y: 4, tension: 0.8), // parks LOW by the hip
  DanceIkTargetKey(28, x: -38, y: 8, tension: 0.7), // holds through the pull
  DanceIkTargetKey(29, x: -38, y: 6, tension: 0.7),
  DanceIkTargetKey(30, x: -14, y: -34, tension: 0.5), // recovers
  DanceIkTargetKey(31, x: 14, y: -58, tension: 0.8), // overcross
  DanceIkTargetKey(32, x: 16, y: -56, tension: 1), // == frame 0
];
const _shakuHandRTargetKeys = [
  // Round 6: mirrors the hand.L separation widening above (see its
  // comment) — same fused-blob complaint, mirrored keys.
  DanceIkTargetKey(0, x: -16, y: -46, tension: 1), // X — R wrist UNDER
  DanceIkTargetKey(2, x: -15, y: -38, tension: 0.5), // gallop ride down
  DanceIkTargetKey(4, x: -16, y: -45, tension: 0.9),
  DanceIkTargetKey(6, x: -15, y: -38, tension: 0.5), // ride
  DanceIkTargetKey(8, x: -16, y: -46, tension: 1),
  // Round 6: mirrors the hand.L scoop-depth fix above (see its comment).
  DanceIkTargetKey(11, x: -3, y: -40, tension: 0.8), // squeeze
  DanceIkTargetKey(12, x: 66, y: 8, tension: 0.7), // trail hand stays shallow
  DanceIkTargetKey(13, x: 76, y: 14, tension: 0.7), // trail hand stays lower
  DanceIkTargetKey(14, x: 6, y: -34, tension: 0.5), // closing transit
  DanceIkTargetKey(15, x: -12, y: -46, tension: 0.8), // overcross lands
  DanceIkTargetKey(16, x: -17, y: -56, tension: 1), // bar-2 X — R takes TOP
  DanceIkTargetKey(18, x: -16, y: -48, tension: 0.5), // ride
  DanceIkTargetKey(20, x: -17, y: -55, tension: 0.9),
  DanceIkTargetKey(22, x: -16, y: -48, tension: 0.5),
  DanceIkTargetKey(24, x: -17, y: -56, tension: 1),
  DanceIkTargetKey(27, x: 12, y: 8, tension: 0.8), // grabs the cord low
  DanceIkTargetKey(28, x: 62, y: -44, tension: 0.9), // GENERATOR PULL up-back
  DanceIkTargetKey(29, x: 74, y: -56, tension: 0.8), // overshoot high
  DanceIkTargetKey(30, x: 22, y: -18, tension: 0.5), // releases back down
  DanceIkTargetKey(31, x: -12, y: -46, tension: 0.8), // re-crosses
  DanceIkTargetKey(32, x: -16, y: -46, tension: 1), // == frame 0
];
const _shakuFootLTargetKeys = [
  // The support phase is ONE constant plant — the round-3 rigging rater
  // pixel-measured the old ±3-unit authored wander as ice-skating. The
  // handoff to the free phase is a real lift-step (y clears the floor),
  // not a translated sole.
  DanceIkTargetKey(0, x: -69, y: 103), // planted support, visible outside
  DanceIkTargetKey(13, x: -69, y: 103), // still exactly there
  DanceIkTargetKey(14, x: -66, y: 97), // toe-led lift begins
  DanceIkTargetKey(16, x: -52, y: 96), // free foot scuffs, unweighted
  DanceIkTargetKey(17, x: -32, y: 90),
  DanceIkTargetKey(19, x: -60, y: 92),
  DanceIkTargetKey(21, x: -44, y: 94),
  DanceIkTargetKey(24, x: -50, y: 96),
  DanceIkTargetKey(25, x: -30, y: 90),
  DanceIkTargetKey(27, x: -60, y: 92),
  DanceIkTargetKey(29, x: -42, y: 94),
  DanceIkTargetKey(31, x: -62, y: 98), // heel-lead descent into the plant
  DanceIkTargetKey(32, x: -69, y: 103),
];
const _shakuFootRTargetKeys = [
  DanceIkTargetKey(0, x: 52, y: 96), // free foot brushes on own side
  DanceIkTargetKey(1, x: 32, y: 90),
  DanceIkTargetKey(3, x: 60, y: 92),
  DanceIkTargetKey(5, x: 44, y: 94),
  DanceIkTargetKey(8, x: 50, y: 96),
  DanceIkTargetKey(9, x: 30, y: 90),
  DanceIkTargetKey(11, x: 60, y: 92),
  DanceIkTargetKey(13, x: 42, y: 94),
  DanceIkTargetKey(15, x: 62, y: 98), // heel-lead descent into the plant
  DanceIkTargetKey(16, x: 69, y: 103), // planted support, visible outside
  DanceIkTargetKey(29, x: 69, y: 103), // still exactly there
  DanceIkTargetKey(30, x: 58, y: 97), // toe-led lift begins
  DanceIkTargetKey(32, x: 52, y: 96),
];
const _shakuFootLKeys = [
  DanceJointKey(0, rotation: 0.3),
  DanceJointKey(1, rotation: 0.82),
  DanceJointKey(3, rotation: -0.68),
  DanceJointKey(5, rotation: 0.34),
  DanceJointKey(9, rotation: -0.72),
  DanceJointKey(13, rotation: 0.76),
  DanceJointKey(17, rotation: 0.84),
  DanceJointKey(19, rotation: -0.7),
  DanceJointKey(21, rotation: 0.2),
  DanceJointKey(25, rotation: -0.68),
  DanceJointKey(29, rotation: 0.18),
  DanceJointKey(32, rotation: 0.3),
];
const _shakuFootRKeys = [
  DanceJointKey(0, rotation: -0.3),
  DanceJointKey(1, rotation: -0.82),
  DanceJointKey(3, rotation: 0.68),
  DanceJointKey(5, rotation: -0.34),
  DanceJointKey(9, rotation: 0.72),
  DanceJointKey(13, rotation: -0.76),
  DanceJointKey(17, rotation: -0.84),
  DanceJointKey(19, rotation: 0.7),
  DanceJointKey(21, rotation: -0.2),
  DanceJointKey(25, rotation: 0.68),
  DanceJointKey(29, rotation: -0.18),
  DanceJointKey(32, rotation: -0.3),
];
const _shakuHandLKeys = [
  DanceJointKey(0, rotation: -0.12),
  DanceJointKey(1, rotation: 0.58),
  DanceJointKey(2, rotation: 0.62),
  DanceJointKey(3, rotation: 0.3),
  DanceJointKey(6, rotation: -0.42),
  DanceJointKey(7, rotation: 0.32),
  DanceJointKey(9, rotation: -0.46),
  DanceJointKey(10, rotation: -0.42),
  DanceJointKey(11, rotation: 0.3),
  DanceJointKey(14, rotation: -0.44),
  DanceJointKey(15, rotation: 0.24),
  DanceJointKey(17, rotation: 0.54),
  DanceJointKey(18, rotation: -0.42),
  DanceJointKey(19, rotation: 0.2),
  DanceJointKey(22, rotation: -0.44),
  DanceJointKey(23, rotation: 0.24),
  DanceJointKey(27, rotation: 0.18),
  DanceJointKey(29, rotation: -0.44),
  DanceJointKey(31, rotation: 0.22),
  DanceJointKey(32, rotation: -0.12),
];
const _shakuHandRKeys = [
  DanceJointKey(0, rotation: 0.12),
  DanceJointKey(1, rotation: -0.54),
  DanceJointKey(2, rotation: -0.6),
  DanceJointKey(3, rotation: -0.3),
  DanceJointKey(6, rotation: 0.42),
  DanceJointKey(7, rotation: -0.32),
  DanceJointKey(9, rotation: 0.46),
  DanceJointKey(10, rotation: 0.54),
  DanceJointKey(11, rotation: -0.3),
  DanceJointKey(14, rotation: 0.44),
  DanceJointKey(15, rotation: -0.24),
  DanceJointKey(17, rotation: -0.5),
  DanceJointKey(18, rotation: 0.54),
  DanceJointKey(19, rotation: -0.2),
  DanceJointKey(22, rotation: 0.44),
  DanceJointKey(23, rotation: -0.24),
  DanceJointKey(27, rotation: -0.18),
  DanceJointKey(29, rotation: 0.44),
  DanceJointKey(31, rotation: -0.22),
  DanceJointKey(32, rotation: 0.12),
];

// Calmer ears for Shaku: enough delayed flop to avoid a fixed skull silhouette,
// but still much quieter than the generic dance ears so the beat reads in the
// body, not the head.
const _shakuEarLKeys = [
  Keyframe(p: 0, rotation: 0.018, scaleX: 1.008, scaleY: 0.994),
  Keyframe(p: 0.125, rotation: -0.047, scaleX: 1.023, scaleY: 0.982),
  Keyframe(p: 0.25, rotation: -0.031, scaleX: 1.015, scaleY: 0.988),
  Keyframe(p: 0.375, rotation: 0.037, scaleX: 0.99, scaleY: 1.012),
  Keyframe(p: 0.5, rotation: 0.018, scaleX: 1.008, scaleY: 0.994),
  Keyframe(p: 0.625, rotation: -0.05, scaleX: 1.023, scaleY: 0.982),
  Keyframe(p: 0.75, rotation: -0.031, scaleX: 1.015, scaleY: 0.988),
  Keyframe(p: 0.875, rotation: 0.037, scaleX: 0.99, scaleY: 1.012),
  Keyframe(p: 1, rotation: 0.018, scaleX: 1.008, scaleY: 0.994),
];
const _shakuEarRKeys = [
  Keyframe(p: 0, rotation: -0.018, scaleX: 0.994, scaleY: 1.008),
  Keyframe(p: 0.125, rotation: 0.044, scaleX: 0.982, scaleY: 1.023),
  Keyframe(p: 0.25, rotation: 0.031, scaleX: 0.988, scaleY: 1.015),
  Keyframe(p: 0.375, rotation: -0.037, scaleX: 1.012, scaleY: 0.99),
  Keyframe(p: 0.5, rotation: -0.018, scaleX: 0.994, scaleY: 1.008),
  Keyframe(p: 0.625, rotation: 0.047, scaleX: 0.982, scaleY: 1.023),
  Keyframe(p: 0.75, rotation: 0.031, scaleX: 0.988, scaleY: 1.015),
  Keyframe(p: 0.875, rotation: -0.037, scaleX: 1.012, scaleY: 0.99),
  Keyframe(p: 1, rotation: -0.018, scaleX: 0.994, scaleY: 1.008),
];

// Shaku-only body punctuation. It adds shoulder/hip participation around the
// final recovery without altering the base `dance` phrase or the standalone
// Zanku/Azonto variants.
const _shakuDabBodyKeys = [
  DanceBodyKey(
    24,
    rootDx: 0,
    rootDy: 0,
    rootRotation: 0,
    pelvisRotation: 0,
    chestRotation: 0,
    chestScaleY: 1,
    chestScaleX: 1,
  ),
  DanceBodyKey(
    26,
    rootDx: -1.4,
    rootDy: 0.45,
    rootRotation: -0.001,
    pelvisRotation: 0.035,
    chestRotation: -0.06,
    chestScaleY: 0.986,
    chestScaleX: 1.01,
  ),
  DanceBodyKey(
    28,
    rootDx: -4.8,
    rootDy: 1.1,
    rootRotation: -0.002,
    pelvisRotation: 0.075,
    chestRotation: -0.16,
    chestScaleY: 0.958,
    chestScaleX: 1.028,
  ),
  DanceBodyKey(
    30,
    rootDx: -1.6,
    rootDy: 0.35,
    rootRotation: -0.001,
    pelvisRotation: 0.035,
    chestRotation: -0.07,
    chestScaleY: 0.985,
    chestScaleX: 1.008,
  ),
  DanceBodyKey(
    32,
    rootDx: 0,
    rootDy: 0,
    rootRotation: 0,
    pelvisRotation: 0,
    chestRotation: 0,
    chestScaleY: 1,
    chestScaleX: 1,
  ),
];

// Panel pass: make the wrist-crosses sit on a heavier pocket and give the
// open-arm accents a visible downbeat instead of floating over the feet.
const _shakuPanelBodyKeys = [
  DanceBodyKey(0, rootDy: 6, pelvisRotation: -0.06, chestRotation: 0.05),
  DanceBodyKey(1, rootDy: 11, pelvisRotation: -0.14, chestRotation: 0.16),
  DanceBodyKey(2, rootDy: 10, pelvisRotation: -0.16, chestRotation: 0.18),
  DanceBodyKey(3, rootDy: 6, pelvisRotation: -0.06, chestRotation: 0.05),
  DanceBodyKey(5, rootDy: 10, pelvisRotation: -0.1, chestRotation: -0.14),
  DanceBodyKey(6, rootDy: 9, pelvisRotation: -0.1, chestRotation: -0.14),
  DanceBodyKey(7, rootDy: 5),
  DanceBodyKey(8, rootDy: 6, pelvisRotation: 0.06, chestRotation: -0.05),
  DanceBodyKey(9, rootDy: 11, pelvisRotation: 0.14, chestRotation: -0.16),
  DanceBodyKey(10, rootDy: 10, pelvisRotation: 0.16, chestRotation: -0.18),
  DanceBodyKey(11, rootDy: 6, pelvisRotation: 0.06, chestRotation: -0.05),
  DanceBodyKey(13, rootDy: 10, pelvisRotation: 0.1, chestRotation: 0.14),
  DanceBodyKey(14, rootDy: 9, pelvisRotation: 0.1, chestRotation: 0.14),
  DanceBodyKey(15, rootDy: 5),
  DanceBodyKey(16, rootDy: 6, pelvisRotation: -0.06, chestRotation: 0.05),
  DanceBodyKey(17, rootDy: 12, pelvisRotation: -0.15, chestRotation: 0.18),
  DanceBodyKey(18, rootDy: 11, pelvisRotation: -0.17, chestRotation: 0.2),
  DanceBodyKey(19, rootDy: 6, pelvisRotation: -0.06, chestRotation: 0.05),
  DanceBodyKey(21, rootDy: 10, pelvisRotation: -0.1, chestRotation: -0.14),
  DanceBodyKey(22, rootDy: 9, pelvisRotation: -0.1, chestRotation: -0.14),
  DanceBodyKey(23, rootDy: 5),
  DanceBodyKey(24, rootDy: 6, pelvisRotation: 0.06, chestRotation: -0.05),
  DanceBodyKey(25, rootDy: 12, pelvisRotation: 0.15, chestRotation: -0.18),
  DanceBodyKey(26, rootDy: 11, pelvisRotation: 0.17, chestRotation: -0.2),
  DanceBodyKey(27, rootDy: 6, pelvisRotation: 0.06, chestRotation: -0.05),
  DanceBodyKey(29, rootDy: 10, pelvisRotation: 0.1, chestRotation: 0.14),
  DanceBodyKey(30, rootDy: 9, pelvisRotation: 0.1, chestRotation: 0.14),
  DanceBodyKey(31, rootDy: 5),
  DanceBodyKey(32, rootDy: 6, pelvisRotation: -0.06, chestRotation: 0.05),
];
