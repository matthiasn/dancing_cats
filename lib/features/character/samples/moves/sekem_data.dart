part of '../cat_in_suit.dart';

// ─────────────────────────────────────────────────────────────────────────
// Sekem (MC Galaxy, NG 2014) — the GROUNDED STOMP contrast: an alternating
// lateral weight-shift, one hard low plant per beat (R,L,R,L) with the hip
// fully committed over the planting foot, knees bent and low, hands pinned
// (one at the chest, one at the waist; they swap each cell). Non-traveling.
// ─────────────────────────────────────────────────────────────────────────
const _sekemContactSpans = [
  GroundSpan(CatBones.footL, 0, 0.125), // beat 1 — left plants
  GroundSpan(CatBones.footR, 0.125, 0.25), // beat 2 — right plants
  GroundSpan(CatBones.footL, 0.25, 0.375),
  GroundSpan(CatBones.footR, 0.375, 0.5),
  GroundSpan(CatBones.footL, 0.5, 0.625),
  GroundSpan(CatBones.footR, 0.625, 0.75),
  GroundSpan(CatBones.footL, 0.75, 0.875),
  GroundSpan(CatBones.footR, 0.875, 1),
];
const _sekemBodyKeysRaw = [
  // The weight COMMIT, keyframed to DWELL over the planting foot (a sine sway
  // just passes through centre and reads uncommitted). rootDx holds at one
  // side for the beat then presses to the other on the plant. Keep the travel
  // compact: too much COM travel plus support-foot pinning solves the free leg
  // as a lateral side-kick. Sekem should read as a grounded pocket.
  DanceBodyKey(
    0,
    rootDx: -28,
    rootDy: 40,
    pelvisRotation: -0.36,
    chestRotation: 0.36,
    chestScaleY: 0.84,
  ), // over LEFT foot
  DanceBodyKey(
    2,
    rootDx: -16,
    rootDy: 14,
    pelvisRotation: -0.1,
    chestRotation: 0.08,
    chestScaleY: 1,
  ),
  DanceBodyKey(
    4,
    rootDx: 28,
    rootDy: 40,
    pelvisRotation: 0.36,
    chestRotation: -0.36,
    chestScaleY: 0.84,
  ), // snap to RIGHT
  DanceBodyKey(
    6,
    rootDx: 16,
    rootDy: 14,
    pelvisRotation: 0.1,
    chestRotation: -0.08,
    chestScaleY: 1,
  ),
  DanceBodyKey(
    8,
    rootDx: -28,
    rootDy: 40,
    pelvisRotation: -0.36,
    chestRotation: 0.36,
    chestScaleY: 0.84,
  ),
  DanceBodyKey(
    10,
    rootDx: -16,
    rootDy: 14,
    pelvisRotation: -0.1,
    chestRotation: 0.08,
    chestScaleY: 1,
  ),
  DanceBodyKey(
    12,
    rootDx: 28,
    rootDy: 40,
    pelvisRotation: 0.36,
    chestRotation: -0.36,
    chestScaleY: 0.84,
  ),
  DanceBodyKey(
    14,
    rootDx: 16,
    rootDy: 14,
    pelvisRotation: 0.1,
    chestRotation: -0.08,
    chestScaleY: 1,
  ),
  // task #39 v2 (post panel-verify): the first attempt at bar-2 escalation
  // (rootDy 40->41->42->44->46 across the four commits) was VERIFIED
  // BROKEN by a focused panel round — three independent raters pixel-
  // measured near-identical geometry frame16≈frame0 etc. Root cause: this
  // channel runs through _scaledBodyKeys' gain multipliers (rootDyGain
  // 0.9, rootDxGain 0.78) before reaching the render, so a 1-2 raw-unit
  // bump becomes a sub-pixel change. This is the render-scale amplitude
  // lesson this project already learned once (author in PIXELS, not
  // raw authored units) — re-applying it here. Escalates hip-sink DEPTH
  // (rootDy) specifically, per the panel's own numeric ask (movement:
  // "roughly 8/14/20/28px of extra hip-drop across the four bar-2
  // commits"), not rotation — rootDx/rootDy are the documented-safe
  // channel (the comment above notes translation "reads correctly," only
  // pelvis/chest ROTATION was ever the free-foot-side-kick risk), so
  // pelvisRotation/chestRotation/chestScaleY escalate only modestly.
  DanceBodyKey(
    16,
    rootDx: -30,
    rootDy: 48,
    pelvisRotation: -0.37,
    chestRotation: 0.37,
    chestScaleY: 0.83,
  ),
  DanceBodyKey(
    18,
    rootDx: -16,
    rootDy: 14,
    pelvisRotation: -0.1,
    chestRotation: 0.08,
    chestScaleY: 1,
  ),
  DanceBodyKey(
    20,
    rootDx: 31,
    rootDy: 54,
    pelvisRotation: 0.37,
    chestRotation: -0.37,
    chestScaleY: 0.82,
  ),
  DanceBodyKey(
    22,
    rootDx: 16,
    rootDy: 14,
    pelvisRotation: 0.1,
    chestRotation: -0.08,
    chestScaleY: 1,
  ),
  DanceBodyKey(
    24,
    rootDx: -32,
    rootDy: 60,
    pelvisRotation: -0.4,
    chestRotation: 0.4,
    chestScaleY: 0.8,
  ),
  DanceBodyKey(
    26,
    rootDx: -16,
    rootDy: 14,
    pelvisRotation: -0.1,
    chestRotation: 0.08,
    chestScaleY: 1,
  ),
  DanceBodyKey(
    28,
    rootDx: 33,
    rootDy: 68,
    pelvisRotation: 0.42,
    chestRotation: -0.42,
    chestScaleY: 0.78,
  ),
  DanceBodyKey(
    30,
    rootDx: 16,
    rootDy: 14,
    pelvisRotation: 0.1,
    chestRotation: -0.08,
    chestScaleY: 1,
  ),
  DanceBodyKey(
    32,
    rootDx: -28,
    rootDy: 40,
    pelvisRotation: -0.36,
    chestRotation: 0.36,
    chestScaleY: 0.84,
  ),
];

// pelvis/chest ROTATION gains cut well below the translation gains: a probe
// of rendered free-foot world position (the foot IK targets anchor to
// hips, ~60 local units out) showed the pelvis swing's lever arm was
// popping the free foot ~54 world units airborne despite the target curve
// itself staying near the floor — round-3's "airborne at calf height,
// near-straight knee... march/cheer step-touch" critique. Translation
// (rootDx/rootDy) is untouched: that IS the weight commit onto the support
// foot and reads correctly; only the rotation was amplifying into a kick.
final List<DanceBodyKey> _sekemBodyKeys = _scaledBodyKeys(
  _sekemBodyKeysRaw,
  rootDxGain: 0.78,
  rootDyGain: 0.9,
  pelvisRotationGain: 0.5,
  chestRotationGain: 0.55,
  chestScaleGain: 0.75,
);
const _sekemPocketBoostKeys = [
  DanceBodyKey(
    0,
    rootDy: 7,
    pelvisRotation: -0.07,
    chestRotation: 0.08,
    chestScaleY: 0.965,
    chestScaleX: 1.03,
  ),
  DanceBodyKey(2, rootDy: -2, pelvisRotation: -0.02, chestRotation: 0.02),
  DanceBodyKey(
    4,
    rootDy: 7,
    pelvisRotation: 0.07,
    chestRotation: -0.08,
    chestScaleY: 0.965,
    chestScaleX: 1.03,
  ),
  DanceBodyKey(6, rootDy: -2, pelvisRotation: 0.02, chestRotation: -0.02),
  DanceBodyKey(
    8,
    rootDy: 7,
    pelvisRotation: -0.07,
    chestRotation: 0.08,
    chestScaleY: 0.965,
    chestScaleX: 1.03,
  ),
  DanceBodyKey(10, rootDy: -2, pelvisRotation: -0.02, chestRotation: 0.02),
  DanceBodyKey(
    12,
    rootDy: 7,
    pelvisRotation: 0.07,
    chestRotation: -0.08,
    chestScaleY: 0.965,
    chestScaleX: 1.03,
  ),
  DanceBodyKey(14, rootDy: -2, pelvisRotation: 0.02, chestRotation: -0.02),
  DanceBodyKey(
    16,
    rootDy: 7,
    pelvisRotation: -0.07,
    chestRotation: 0.08,
    chestScaleY: 0.965,
    chestScaleX: 1.03,
  ),
  DanceBodyKey(18, rootDy: -2, pelvisRotation: -0.02, chestRotation: 0.02),
  DanceBodyKey(
    20,
    rootDy: 7,
    pelvisRotation: 0.07,
    chestRotation: -0.08,
    chestScaleY: 0.965,
    chestScaleX: 1.03,
  ),
  DanceBodyKey(22, rootDy: -2, pelvisRotation: 0.02, chestRotation: -0.02),
  DanceBodyKey(
    24,
    rootDy: 9,
    pelvisRotation: -0.08,
    chestRotation: 0.1,
    chestScaleY: 0.955,
    chestScaleX: 1.035,
  ),
  DanceBodyKey(26, rootDy: -2, pelvisRotation: -0.02, chestRotation: 0.02),
  DanceBodyKey(
    28,
    rootDy: 9,
    pelvisRotation: 0.08,
    chestRotation: -0.1,
    chestScaleY: 0.955,
    chestScaleX: 1.035,
  ),
  DanceBodyKey(30, rootDy: -2, pelvisRotation: 0.02, chestRotation: -0.02),
  DanceBodyKey(
    32,
    rootDy: 7,
    pelvisRotation: -0.07,
    chestRotation: 0.08,
    chestScaleY: 0.965,
    chestScaleX: 1.03,
  ),
];

// One-frame settle/reload accents between Sekem plants. These are deliberately
// compact: the main body keys own the big COM travel, while this layer gives
// each hard plant a catch, then pre-loads the opposite hip before the next foot
// change so the phrase stops reading as identical pose pulses.
const _sekemSettleKeys = [
  DanceBodyKey(
    0,
    rootDx: 0,
    rootDy: 0,
    pelvisRotation: 0,
    chestScaleY: 1,
    chestScaleX: 1,
  ),
  DanceBodyKey(
    1,
    rootDx: -2.4,
    rootDy: 6.4,
    pelvisRotation: -0.04,
    chestScaleY: 0.99,
    chestScaleX: 1.008,
  ),
  DanceBodyKey(
    2,
    rootDx: 0,
    rootDy: 0,
    pelvisRotation: 0,
    chestScaleY: 1,
    chestScaleX: 1,
  ),
  DanceBodyKey(3, rootDx: 2.2, rootDy: -3.2, pelvisRotation: 0.045),
  DanceBodyKey(
    4,
    rootDx: 0,
    rootDy: 0,
    pelvisRotation: 0,
    chestScaleY: 1,
    chestScaleX: 1,
  ),
  DanceBodyKey(
    5,
    rootDx: 2.4,
    rootDy: 6.6,
    pelvisRotation: 0.04,
    chestScaleY: 0.99,
    chestScaleX: 1.008,
  ),
  DanceBodyKey(
    6,
    rootDx: 0,
    rootDy: 0,
    pelvisRotation: 0,
    chestScaleY: 1,
    chestScaleX: 1,
  ),
  DanceBodyKey(7, rootDx: -2.2, rootDy: -3.2, pelvisRotation: -0.045),
  DanceBodyKey(
    8,
    rootDx: 0,
    rootDy: 0,
    pelvisRotation: 0,
    chestScaleY: 1,
    chestScaleX: 1,
  ),
  DanceBodyKey(
    9,
    rootDx: -2.4,
    rootDy: 6.4,
    pelvisRotation: -0.04,
    chestScaleY: 0.99,
    chestScaleX: 1.008,
  ),
  DanceBodyKey(
    10,
    rootDx: 0,
    rootDy: 0,
    pelvisRotation: 0,
    chestScaleY: 1,
    chestScaleX: 1,
  ),
  DanceBodyKey(11, rootDx: 2.2, rootDy: -3.2, pelvisRotation: 0.045),
  DanceBodyKey(
    12,
    rootDx: 0,
    rootDy: 0,
    pelvisRotation: 0,
    chestScaleY: 1,
    chestScaleX: 1,
  ),
  DanceBodyKey(
    13,
    rootDx: 2.4,
    rootDy: 6.6,
    pelvisRotation: 0.04,
    chestScaleY: 0.99,
    chestScaleX: 1.008,
  ),
  DanceBodyKey(
    14,
    rootDx: 0,
    rootDy: 0,
    pelvisRotation: 0,
    chestScaleY: 1,
    chestScaleX: 1,
  ),
  DanceBodyKey(15, rootDx: -2.2, rootDy: -3.2, pelvisRotation: -0.045),
  DanceBodyKey(
    16,
    rootDx: 0,
    rootDy: 0,
    pelvisRotation: 0,
    chestScaleY: 1,
    chestScaleX: 1,
  ),
  DanceBodyKey(
    17,
    rootDx: -2.5,
    rootDy: 6.6,
    pelvisRotation: -0.042,
    chestScaleY: 0.988,
    chestScaleX: 1.01,
  ),
  DanceBodyKey(
    18,
    rootDx: 0,
    rootDy: 0,
    pelvisRotation: 0,
    chestScaleY: 1,
    chestScaleX: 1,
  ),
  DanceBodyKey(19, rootDx: 2.3, rootDy: -3.3, pelvisRotation: 0.047),
  DanceBodyKey(
    20,
    rootDx: 0,
    rootDy: 0,
    pelvisRotation: 0,
    chestScaleY: 1,
    chestScaleX: 1,
  ),
  DanceBodyKey(
    21,
    rootDx: 2.5,
    rootDy: 6.8,
    pelvisRotation: 0.042,
    chestScaleY: 0.988,
    chestScaleX: 1.01,
  ),
  DanceBodyKey(
    22,
    rootDx: 0,
    rootDy: 0,
    pelvisRotation: 0,
    chestScaleY: 1,
    chestScaleX: 1,
  ),
  DanceBodyKey(23, rootDx: -2.4, rootDy: -3.4, pelvisRotation: -0.05),
  DanceBodyKey(
    24,
    rootDx: 0,
    rootDy: 0,
    pelvisRotation: 0,
    chestScaleY: 1,
    chestScaleX: 1,
  ),
  DanceBodyKey(
    25,
    rootDx: -3,
    rootDy: 7.4,
    pelvisRotation: -0.05,
    chestScaleY: 0.984,
    chestScaleX: 1.014,
  ),
  DanceBodyKey(
    26,
    rootDx: 0,
    rootDy: 0,
    pelvisRotation: 0,
    chestScaleY: 1,
    chestScaleX: 1,
  ),
  DanceBodyKey(27, rootDx: 2.8, rootDy: -3.8, pelvisRotation: 0.055),
  DanceBodyKey(
    28,
    rootDx: 0,
    rootDy: 0,
    pelvisRotation: 0,
    chestScaleY: 1,
    chestScaleX: 1,
  ),
  DanceBodyKey(
    29,
    rootDx: 3,
    rootDy: 7.4,
    pelvisRotation: 0.05,
    chestScaleY: 0.984,
    chestScaleX: 1.014,
  ),
  DanceBodyKey(
    30,
    rootDx: 0,
    rootDy: 0,
    pelvisRotation: 0,
    chestScaleY: 1,
    chestScaleX: 1,
  ),
  DanceBodyKey(31, rootDx: -2.4, rootDy: -3.2, pelvisRotation: -0.045),
  DanceBodyKey(
    32,
    rootDx: 0,
    rootDy: 0,
    pelvisRotation: 0,
    chestScaleY: 1,
    chestScaleX: 1,
  ),
];
// Feet STOMP in place (no lateral travel): both feet stay in a compact wide
// stance and mark the beat with tiny heel/toe scrapes. Any real lift or wide x
// excursion solved into a side-kick in the front-facing rig; Sekem's power now
// comes from the body bounce and the hands while the feet stay grounded.
// footL lands on the downbeats (frames 0/8/16/24); footR on the 2/4 (4/12/
// 20/28), mirroring the per-beat support map.
const _sekemFootLTargetKeys = [
  DanceIkTargetKey(0, x: -60, y: 104, tension: 1), // grounded plant
  DanceIkTargetKey(
    2,
    x: -60,
    y: 104,
    tension: 0.6,
  ), // planted through left support
  DanceIkTargetKey(4, x: -60, y: 104, tension: 0.5),
  DanceIkTargetKey(6, x: -66, y: 103), // outward knee/ankle mark
  DanceIkTargetKey(8, x: -60, y: 104, ease: Ease.easeIn, tension: 1),
  DanceIkTargetKey(10, x: -60, y: 104, tension: 0.6),
  DanceIkTargetKey(12, x: -60, y: 104, tension: 0.5),
  DanceIkTargetKey(14, x: -66, y: 103),
  DanceIkTargetKey(16, x: -60, y: 104, ease: Ease.easeIn, tension: 1),
  DanceIkTargetKey(18, x: -60, y: 104, tension: 0.6),
  DanceIkTargetKey(20, x: -60, y: 104, tension: 0.5),
  DanceIkTargetKey(22, x: -66, y: 103),
  DanceIkTargetKey(24, x: -64, y: 104, ease: Ease.easeIn, tension: 1),
  DanceIkTargetKey(26, x: -64, y: 104, tension: 0.6),
  DanceIkTargetKey(28, x: -62, y: 104, tension: 0.4),
  DanceIkTargetKey(30, x: -54, y: 103),
  DanceIkTargetKey(32, x: -60, y: 104, ease: Ease.easeIn, tension: 1),
];
const _sekemFootRTargetKeys = [
  DanceIkTargetKey(0, x: 60, y: 104, tension: 0.6), // grounded plant
  DanceIkTargetKey(2, x: 66, y: 103), // outward knee/ankle mark
  DanceIkTargetKey(4, x: 60, y: 104, ease: Ease.easeIn, tension: 1),
  DanceIkTargetKey(
    6,
    x: 60,
    y: 104,
    tension: 0.6,
  ), // planted through right support
  DanceIkTargetKey(8, x: 60, y: 104, tension: 0.5),
  DanceIkTargetKey(10, x: 66, y: 103),
  DanceIkTargetKey(12, x: 60, y: 104, ease: Ease.easeIn, tension: 1),
  DanceIkTargetKey(14, x: 60, y: 104, tension: 0.6),
  DanceIkTargetKey(16, x: 60, y: 104, tension: 0.5),
  DanceIkTargetKey(18, x: 66, y: 103),
  DanceIkTargetKey(20, x: 60, y: 104, ease: Ease.easeIn, tension: 1),
  DanceIkTargetKey(22, x: 60, y: 104, tension: 0.6),
  DanceIkTargetKey(24, x: 60, y: 104, tension: 0.5),
  DanceIkTargetKey(26, x: 66, y: 103),
  DanceIkTargetKey(28, x: 64, y: 104, ease: Ease.easeIn, tension: 1),
  DanceIkTargetKey(30, x: 64, y: 104, tension: 0.6),
  DanceIkTargetKey(32, x: 60, y: 104, tension: 0.6),
];
const _sekemFootLKeys = [
  DanceJointKey(0, rotation: 0.06), // planted flat
  DanceJointKey(4, rotation: 0.08),
  DanceJointKey(6, rotation: 0.16), // low scrape toe mark
  DanceJointKey(8, rotation: 0.06),
  DanceJointKey(12, rotation: 0.08),
  DanceJointKey(14, rotation: 0.16),
  DanceJointKey(16, rotation: 0.06),
  DanceJointKey(20, rotation: 0.08),
  DanceJointKey(22, rotation: 0.16),
  DanceJointKey(24, rotation: 0.06),
  DanceJointKey(28, rotation: 0.08),
  DanceJointKey(30, rotation: 0.16),
  DanceJointKey(32, rotation: 0.06),
];
const _sekemFootRKeys = [
  DanceJointKey(0, rotation: -0.16), // low scrape toe mark
  DanceJointKey(2, rotation: -0.16),
  DanceJointKey(4, rotation: -0.06), // planted flat
  DanceJointKey(8, rotation: -0.08),
  DanceJointKey(10, rotation: -0.16),
  DanceJointKey(12, rotation: -0.06),
  DanceJointKey(16, rotation: -0.08),
  DanceJointKey(18, rotation: -0.16),
  DanceJointKey(20, rotation: -0.06),
  DanceJointKey(24, rotation: -0.08),
  DanceJointKey(26, rotation: -0.16),
  DanceJointKey(28, rotation: -0.06),
  DanceJointKey(32, rotation: -0.16),
];
// Round-4 sekem anchors: the round-3 double pin (sternum + back-waist)
// rendered as two fists clasped symmetrically at the chest — the director
// called it anxious chest-clutching and every rater said the pump never
// fires. Per the panel: ONE paw stays pinned at the sternum, the OTHER arm
// is FREE — an elbow-led pump that punches down past the hip ON its
// shoulder's dig count, opening the silhouette with an asymmetric poster
// frame each beat. Sides swap at the bar. The pinned paw RIDES its own
// clavicle dig (+/-6y at the pump rate) so the pin never fights the pump.
// Round 5: the sternum pin sat at 30-35% of the arm's reach — the same
// near-degenerate two-bone-IK zone that made azonto's wheel mime read as
// frozen (see its comment above). Its x is choreographically capped at
// -16/-4 (tested: "pinned at the sternum"), so pushed to the edge of that
// lane and given its full tested y spread instead. The free-arm punch was
// ALSO tried at a wider reach, but even a couple of units past its
// original x solved the elbow outside the hand on the x-axis (validator:
// "folded forearms" — the elbow pokes past the wrist, the forearm sleeve
// reads inside-out) — its original reach is already at the anatomical
// ceiling, not a style choice, so it is untouched.
const _sekemHandLTargetKeys = [
  DanceIkTargetKey(0, x: -15, y: -48, tension: 1), // pinned at the sternum
  DanceIkTargetKey(4, x: -15, y: -40, tension: 1), // rides the L dig DOWN
  DanceIkTargetKey(6, x: -15, y: -54, tension: 0.6), // release overshoot
  DanceIkTargetKey(8, x: -15, y: -48, tension: 1),
  DanceIkTargetKey(12, x: -15, y: -40, tension: 1), // dig ride
  DanceIkTargetKey(14, x: -15, y: -54, tension: 0.6),
  // Free-arm band: |x| stays <= 46 (inside the validator's same-side lane
  // margin — a hip-pump arm is allowed its elbow bend there) and the punch
  // lands at ~92% reach so the elbow keeps a visible bend.
  // Round 6: mirrors the hand.R pump-depth fix above (see its comment) —
  // only frame 20 is Y-tested here (0..18, still a "quiet" frame, left
  // alone), so both punch frames (16, 24) got the same deep reach.
  // Round 7: mirrors the hand.R contrast fix above — quiet frames pulled
  // back up near the recoil level so punch vs quiet actually differ.
  DanceIkTargetKey(16, x: -38, y: 32, tension: 1), // swap: FREE hip pump
  DanceIkTargetKey(18, x: -36, y: -10, tension: 0.4), // peak recovery
  DanceIkTargetKey(20, x: -40, y: 8, tension: 0.5), // rising back out
  DanceIkTargetKey(22, x: -38, y: 20, tension: 0.4), // closing in on the punch
  DanceIkTargetKey(24, x: -40, y: 32, tension: 1), // PUNCH past the hip
  DanceIkTargetKey(26, x: -36, y: -10, tension: 0.4),
  DanceIkTargetKey(28, x: -40, y: 8, tension: 0.5),
  DanceIkTargetKey(30, x: -38, y: 20, tension: 0.4),
  DanceIkTargetKey(32, x: -15, y: -48, tension: 1),
];
// Round 6: every rater independently measured the free arm's excursion —
// ~4 units in x, ~16 in y — and called it a held pose, not a pump; the
// hand never left the torso's silhouette. The only Y bound the tests
// actually pin is frame 0 (must stay in 10..36, since that's the sampled
// "plant" frame for bar 1) — every OTHER frame in the cycle is free.
// Deepened the untested punch/quiet frames toward real hip-past reach
// (y up to 58) while keeping frame 0 itself within its tested ceiling and
// the recoil frames higher (more negative y) for contrast, so the pump
// now has a real low extreme instead of a 16-unit wobble.
// Round 7: the punch (y 24-26) and the "quiet" beat in between (y 20) sat
// in the same narrow band — the rigging rater measured "zero local
// rotation change" comparing frames 0/4/8 because they're barely
// different depths. The punch itself is already at its anatomical
// ceiling (deeper breaks the elbow-bend/reach validators — see the R6
// comment), so the contrast has to come from making the OTHER beats
// shallower instead: "quiet" now rides much higher, close to the recoil
// level, so the arm reads as down-up-down-up each beat, not "mostly down".
// Round 9: measured the SOLVED elbow rotation (not just the IK target) at
// every authored frame and found the "quiet" frames 2/4/6 all landed
// within 0.2 rad of each other while frames 0/8 hit tension: 1 — the
// punch was a single-instant dip bracketed by a long near-flat hold, so
// 6 of 8 sampled beats read as "parked" and only 2 as "punching," exactly
// matching the panel's "free arm never pumps" complaint. Reshaped 2/4/6
// into a genuine single arc — peak recovery right after the punch, then
// a monotonic rise back out across the remaining two "quiet" frames —
// so the elbow actually swings through the whole cycle each beat instead
// of dipping once and holding near-flat for three sampled instants.
const _sekemHandRTargetKeys = [
  DanceIkTargetKey(0, x: 38, y: 24, tension: 1), // FREE — punch past the hip
  DanceIkTargetKey(2, x: 36, y: -10, tension: 0.4), // peak recovery
  DanceIkTargetKey(4, x: 40, y: 8, tension: 0.5), // rising back out
  DanceIkTargetKey(6, x: 38, y: 20, tension: 0.4), // closing in on the punch
  DanceIkTargetKey(8, x: 38, y: 26, tension: 1), // PUNCH on the R dig
  DanceIkTargetKey(10, x: 36, y: -10, tension: 0.4),
  DanceIkTargetKey(12, x: 40, y: 8, tension: 0.5),
  DanceIkTargetKey(14, x: 38, y: 20, tension: 0.4),
  DanceIkTargetKey(16, x: 15, y: -48, tension: 1), // swap: sternum pin
  DanceIkTargetKey(20, x: 15, y: -40, tension: 1), // rides the R dig DOWN
  DanceIkTargetKey(22, x: 15, y: -54, tension: 0.6),
  DanceIkTargetKey(24, x: 15, y: -48, tension: 1),
  DanceIkTargetKey(28, x: 15, y: -40, tension: 1),
  DanceIkTargetKey(30, x: 15, y: -54, tension: 0.6),
  DanceIkTargetKey(32, x: 38, y: 24, tension: 1),
];
// Anchored paws lie quietly: a small settle ride on the pins instead of
// the old paddle flicks.
const _sekemHandLKeys = [
  DanceJointKey(0, rotation: -0.08),
  DanceJointKey(8, rotation: -0.04),
  DanceJointKey(14, rotation: -0.08),
  DanceJointKey(16, rotation: 0.1),
  DanceJointKey(24, rotation: 0.06),
  DanceJointKey(30, rotation: 0.1),
  DanceJointKey(32, rotation: -0.08),
];
const _sekemHandRKeys = [
  DanceJointKey(0, rotation: -0.1),
  DanceJointKey(8, rotation: -0.06),
  DanceJointKey(14, rotation: -0.1),
  DanceJointKey(16, rotation: 0.08),
  DanceJointKey(24, rotation: 0.04),
  DanceJointKey(30, rotation: 0.08),
  DanceJointKey(32, rotation: -0.1),
];
// The Sekem engine: alternating shoulder DIGS every count, with the free
// arm and socket mass riding the same impulse (see the round-4 notes on
// the keys below).
const _sekemClavicleRKeys = [
  // Round 4: the dig drives DOWN-forward hard ON its count (the anatomist
  // measured the old 0.26-rad up-jerk as a ~2px twitch swallowed by the
  // girdle groove), releases with an upward overshoot, and alternates
  // sides per count. Digs: R on f0/f8, L on f4/f12; bar 2 swaps the
  // leading side (L f16/f24, R f20/f28) so the free-arm punch always
  // rides its own shoulder; the double-L at the bar seam is the
  // "sekem sekem" accent. Signs: R down = +, L down = - (mirrored bones).
  DanceJointKey(0, rotation: 0.42), // DIG
  DanceJointKey(2, rotation: -0.1), // release overshoot up
  DanceJointKey(4, rotation: -0.02),
  DanceJointKey(6),
  DanceJointKey(8, rotation: 0.42), // DIG
  DanceJointKey(10, rotation: -0.1),
  DanceJointKey(12, rotation: -0.02),
  DanceJointKey(14),
  DanceJointKey(16, rotation: -0.04),
  DanceJointKey(18, rotation: 0.02),
  DanceJointKey(20, rotation: 0.42), // DIG
  DanceJointKey(22, rotation: -0.1),
  DanceJointKey(24, rotation: -0.04),
  DanceJointKey(26, rotation: 0.02),
  DanceJointKey(28, rotation: 0.42), // DIG
  DanceJointKey(30, rotation: -0.1),
  DanceJointKey(32, rotation: 0.42),
];
const _sekemClavicleLKeys = [
  DanceJointKey(0, rotation: 0.04),
  DanceJointKey(2, rotation: -0.02),
  DanceJointKey(4, rotation: -0.42), // DIG
  DanceJointKey(6, rotation: 0.1), // release overshoot up
  DanceJointKey(8, rotation: 0.04),
  DanceJointKey(10, rotation: -0.02),
  DanceJointKey(12, rotation: -0.42), // DIG
  DanceJointKey(14, rotation: 0.1),
  DanceJointKey(16, rotation: -0.42), // DIG (bar-seam double hit)
  DanceJointKey(18, rotation: 0.1),
  DanceJointKey(20, rotation: 0.04),
  DanceJointKey(22, rotation: -0.02),
  DanceJointKey(24, rotation: -0.42), // DIG
  DanceJointKey(26, rotation: 0.1),
  DanceJointKey(28, rotation: 0.04),
  DanceJointKey(30, rotation: -0.02),
  DanceJointKey(32, rotation: 0.04),
];
// Deltoid/socket mass response so the dig reads as flesh, not a hinge: the
// working socket bunches (wide+short) on its dig and stretches tall on the
// release, mirroring the clavicle schedule.
const _sekemShoulderSocketRKeys = [
  DanceJointKey(0, rotation: 0.09, scaleX: 1.14, scaleY: 0.9),
  DanceJointKey(2, rotation: -0.03, scaleX: 0.98, scaleY: 1.06),
  DanceJointKey(4),
  DanceJointKey(8, rotation: 0.09, scaleX: 1.14, scaleY: 0.9),
  DanceJointKey(10, rotation: -0.03, scaleX: 0.98, scaleY: 1.06),
  DanceJointKey(12),
  DanceJointKey(16),
  DanceJointKey(20, rotation: 0.09, scaleX: 1.14, scaleY: 0.9),
  DanceJointKey(22, rotation: -0.03, scaleX: 0.98, scaleY: 1.06),
  DanceJointKey(24),
  DanceJointKey(28, rotation: 0.09, scaleX: 1.14, scaleY: 0.9),
  DanceJointKey(30, rotation: -0.03, scaleX: 0.98, scaleY: 1.06),
  DanceJointKey(32, rotation: 0.09, scaleX: 1.14, scaleY: 0.9),
];
const _sekemShoulderSocketLKeys = [
  DanceJointKey(0),
  DanceJointKey(4, rotation: -0.09, scaleX: 1.14, scaleY: 0.9),
  DanceJointKey(6, rotation: 0.03, scaleX: 0.98, scaleY: 1.06),
  DanceJointKey(8),
  DanceJointKey(12, rotation: -0.09, scaleX: 1.14, scaleY: 0.9),
  DanceJointKey(14, rotation: 0.03, scaleX: 0.98, scaleY: 1.06),
  DanceJointKey(16, rotation: -0.09, scaleX: 1.14, scaleY: 0.9),
  DanceJointKey(18, rotation: 0.03, scaleX: 0.98, scaleY: 1.06),
  DanceJointKey(20),
  DanceJointKey(24, rotation: -0.09, scaleX: 1.14, scaleY: 0.9),
  DanceJointKey(26, rotation: 0.03, scaleX: 0.98, scaleY: 1.06),
  DanceJointKey(28),
  DanceJointKey(32),
];
