part of '../cat_in_suit.dart';

// ─────────────────────────────────────────────────────────────────────────
// Buga (Kizz Daniel ft. Tekno, NG 2022) — a UNISON HIT move: "lo-lo-lo-BUGA",
// three prep knee-dips loading at the chest, then on count 4 the body RISES to
// full height, the chest pops open and ONE lead arm thrusts out to present
// (Yoruba "buga" = to show off). Two mirrored cells — RIGHT arm thrusts on the
// frame-12 hit, LEFT arm on the frame-28 hit.
// ─────────────────────────────────────────────────────────────────────────
const _bugaBodyKeys = [
  // "lo-lo-lo-BUGA" as three STEPPED descending floors (panel round 3): the
  // round-2 depths (rootDy 20/38/56) rendered as a knee bob — a probe against
  // rendered hip height showed the whole descent compressed into ~14% of
  // body height, with count 1 indistinguishable from the recoil baseline.
  // Round-3 spec: each count bottoms visibly below the last (~11/23/33% of
  // body height), a small rebound rides IN FRONT of each drop so every 'lo'
  // reads as its own weight commitment, the deepest floor HOLDS through
  // count 3, and the trunk pitches progressively forward with depth so the
  // legs don't carry the sink alone. Bar 2 escalates deeper (A -> A', the
  // director's monotony fix).
  DanceBodyKey(
    0,
    rootDx: -5,
    rootDy: 30,
    pelvisRotation: -0.06,
    chestRotation: -0.12,
    chestScaleY: 0.96,
  ), // lo1 lands ON count 1 — a real drop from the tall recoil
  DanceBodyKey(
    2,
    rootDx: -6,
    rootDy: 30,
    chestRotation: -0.12,
    chestScaleY: 0.96,
  ), // lo1 HOLDS
  DanceBodyKey(
    3,
    rootDx: -5,
    rootDy: 22,
    chestRotation: -0.1,
    chestScaleY: 0.98,
  ), // rebound
  DanceBodyKey(
    4,
    rootDx: 5,
    rootDy: 58,
    pelvisRotation: 0.07,
    chestRotation: -0.18,
    chestScaleY: 0.9,
  ), // lo2 steps down
  DanceBodyKey(
    6,
    rootDx: 6,
    rootDy: 58,
    chestRotation: -0.18,
    chestScaleY: 0.9,
  ), // lo2 HOLDS
  DanceBodyKey(
    7,
    rootDx: 5,
    rootDy: 50,
    chestRotation: -0.16,
    chestScaleY: 0.92,
  ), // rebound
  DanceBodyKey(
    8,
    rootDx: -6,
    rootDy: 88,
    pelvisRotation: -0.11,
    chestRotation: -0.24,
    chestScaleY: 0.84,
  ), // lo3 — deepest floor
  DanceBodyKey(
    10,
    rootDx: -7,
    rootDy: 45,
    chestRotation: -0.19,
    chestScaleY: 0.93,
  ), // rise begins — evenly-paced ramp from here to the hit (see below)
  DanceBodyKey(
    11,
    rootDx: -7,
    rootDy: 24,
    pelvisRotation: 0,
    chestRotation: -0.12,
    chestScaleY: 1.05,
  ), // rise continues at the SAME per-frame rate as 8->10 and 10->11,
  // instead of a shallow hold followed by a steep cliff — spreads the
  // whole ~90-unit rootDy change over three EVEN segments (8->10->11->12)
  DanceBodyKey(
    12,
    rootDx: -6,
    rootDy: 2,
    rootRotation: 0.003,
    pelvisRotation: 0.06,
    chestRotation: -0.1,
    chestScaleY: 1.16,
    chestScaleX: 0.97,
  ), // HIT — explode up, chest pops square
  DanceBodyKey(
    14,
    rootDx: -5,
    rootDy: 3,
    rootRotation: 0.002,
    pelvisRotation: 0.05,
    chestRotation: -0.08,
    chestScaleY: 1.08,
  ), // readable overshoot, already releasing
  DanceBodyKey(
    15,
    rootDx: -4,
    rootDy: 6,
    rootRotation: 0.002,
    pelvisRotation: 0.03,
    chestRotation: -0.05,
    chestScaleY: 0.98,
  ),
  // R10: the director still called the whole 2-bar phrase "a 2-beat unit
  // copy-pasted four times" despite this bar-2 escalation — the old
  // +2/+4/+8 rootDy gap over bar 1 (30->32, 58->62, 88->96, ~7% deeper)
  // was too small to register at render scale, the same "small delta
  // near an existing value reads as unchanged" lesson found repeatedly
  // this session for other moves. Nothing here is test-pinned (only the
  // HIT frames 12/28 and hand-target frames are), so widened the gap
  // (30->33, 58->64, 88->97, ~10-15% deeper). Deepening further hit a
  // real ceiling fast: the overshoot-and-settle pass scales its rebound
  // with incoming velocity, so a deeper bar-2 sink also throws a bigger
  // overshoot into the frame-28 hit — pushed past ~97 on lo3 and the
  // hit's own rootDy briefly went negative (above the planted feet),
  // failing the "second hit stays similarly planted" test. This is the
  // practical ceiling for this specific escalation lever.
  DanceBodyKey(
    16,
    rootDx: 5,
    rootDy: 33,
    pelvisRotation: 0.06,
    chestRotation: 0.12,
    chestScaleY: 0.96,
  ), // bar 2 lo1 — arrives noticeably deeper than bar 1
  DanceBodyKey(
    18,
    rootDx: 6,
    rootDy: 33,
    chestRotation: 0.12,
    chestScaleY: 0.96,
  ), // lo1 HOLDS
  DanceBodyKey(
    19,
    rootDx: 5,
    rootDy: 25,
    chestRotation: 0.1,
    chestScaleY: 0.98,
  ), // rebound
  DanceBodyKey(
    20,
    rootDx: -5,
    rootDy: 64,
    pelvisRotation: -0.07,
    chestRotation: 0.18,
    chestScaleY: 0.9,
  ), // lo2
  DanceBodyKey(
    22,
    rootDx: -6,
    rootDy: 64,
    chestRotation: 0.18,
    chestScaleY: 0.9,
  ), // lo2 HOLDS
  DanceBodyKey(
    23,
    rootDx: -5,
    rootDy: 55,
    chestRotation: 0.16,
    chestScaleY: 0.92,
  ), // rebound
  DanceBodyKey(
    24,
    rootDx: 6,
    rootDy: 97,
    pelvisRotation: 0.11,
    chestRotation: 0.26,
    chestScaleY: 0.83,
  ), // lo3 — the escalated deepest floor of the phrase
  DanceBodyKey(
    26,
    rootDx: 7,
    rootDy: 50,
    chestRotation: 0.2,
    chestScaleY: 0.95,
  ), // rise begins — evenly-paced ramp, mirrors frame 10's fix above
  DanceBodyKey(
    27,
    rootDx: 7,
    rootDy: 26,
    pelvisRotation: 0,
    chestRotation: 0.13,
    chestScaleY: 1.06,
  ), // rise continues at the same per-frame rate — mirrors frame 11
  DanceBodyKey(
    28,
    rootDx: 6,
    rootDy: 2,
    rootRotation: -0.003,
    pelvisRotation: -0.06,
    chestRotation: 0.1,
    chestScaleY: 1.16,
    chestScaleX: 0.97,
  ), // HIT
  DanceBodyKey(
    30,
    rootDx: 5,
    rootDy: 3,
    rootRotation: -0.002,
    pelvisRotation: -0.05,
    chestRotation: 0.08,
    chestScaleY: 1.08,
  ),
  DanceBodyKey(
    31,
    rootDx: 4,
    rootDy: 6,
    rootRotation: -0.002,
    pelvisRotation: -0.03,
    chestRotation: 0.05,
    chestScaleY: 0.98,
  ),
  DanceBodyKey(
    32,
    rootDx: -5,
    rootDy: 30,
    pelvisRotation: -0.06,
    chestRotation: -0.12,
    chestScaleY: 0.96,
  ),
];
// Shins drive the hit: knees flex DEEP through the three dips (loading), then
// EXTEND hard on the BUGA frame so the rise is powered from the ground/legs,
// not just an arm raise. Both legs together (unison move).
const _bugaLegLowerKeys = [
  // Knee flexion tracks the stepped rootDy floors 1:1 — the contact/anchor
  // stack replants the feet, so a rootDy floor only reads if the knees agree.
  DanceJointKey(0, rotation: -1.02), // lo1 flex
  DanceJointKey(2, rotation: -1.02),
  DanceJointKey(3, rotation: -0.94), // rebound
  DanceJointKey(4, rotation: -1.42), // lo2 deeper
  DanceJointKey(6, rotation: -1.42),
  DanceJointKey(7, rotation: -1.34), // rebound
  DanceJointKey(8, rotation: -1.85), // lo3 deepest load
  DanceJointKey(10, rotation: -1.85),
  DanceJointKey(11, rotation: -1.9),
  DanceJointKey(12, rotation: -0.62), // EXTEND — leg drive, not a locked knee
  DanceJointKey(14, rotation: -0.66),
  DanceJointKey(15, rotation: -0.6),
  DanceJointKey(16, rotation: -1.05),
  DanceJointKey(18, rotation: -1.05),
  DanceJointKey(19, rotation: -0.97),
  DanceJointKey(20, rotation: -1.48),
  DanceJointKey(22, rotation: -1.48),
  DanceJointKey(23, rotation: -1.4),
  DanceJointKey(24, rotation: -1.95), // escalated bar-2 floor
  DanceJointKey(26, rotation: -1.95),
  DanceJointKey(27, rotation: -2),
  DanceJointKey(28, rotation: -0.62), // EXTEND
  DanceJointKey(30, rotation: -0.66),
  DanceJointKey(31, rotation: -0.6),
  DanceJointKey(32, rotation: -1.02),
];
// The peacock hit lands with a DOUBLE shoulder shrug — both clavicles rise
// together on every hit (the audit's mirror fix; the old keys shrugged one
// shoulder per alternating present).
// The shrug is a PULSE inside the held present (panel round 3): shoulders
// punch toward the ears exactly ON the hit frame and visibly release two
// frames later while the bowed arms still hold, so the flaunt breathes
// instead of freezing as a mannequin.
// R10: the movement rater measured the arms staying "locked" through the
// 3-count sink (only legs/torso animate the build) — the reach targets
// are already near their anatomical ceiling (~96% reach, documented
// above) so there's no room to push position further. Amplified the
// shoulder's OWN response instead — small deltas per count (0.04 rad
// steps) were too subtle to register, same "small delta near an
// existing value reads as unchanged" lesson as elsewhere this session.
// Kept well under the frame-13/29 hit's own shrug spike so the sink's
// response doesn't compete with the hit's accent.
// R13 (buga re-panel, 2026-07-04): the animator still read the hit's
// shoulders as "flat/dead — no shrug-up toward the ears, the hit lands soft"
// (a persistent R12 finding). The clavicle IS the shoulder-girdle control and
// the peacock hands are IK-pinned, so a bigger clavicle rotation raises the
// shoulder SOCKET toward the head while the hand stays put — the neck
// compresses and the shrug reads. Boosted the hit spike 0.36 -> 0.46 (and its
// release 0.30 -> 0.36). 0.46 not higher: the ease overshoots ~0.07 past the
// key, and the clavicle dancer-envelope caps abs rotation at 0.55, so a 0.55
// key resolved to ~0.61 and tripped the joint-envelope gate. Re-check confirmed
// the shrug now reads clearly, head not swallowed. See reviews/assets/
// buga-shoulder-pop-before-after.png.
// Head attitude — the ornament-port vocabulary in buga's SINK-AND-HIT
// idiom: the chin dips a step deeper with each descending 'lo' (riding
// the stepped floors), coils under the load, SNAPS up-and-back with the
// BUGA hit alongside the shoulder shrug, and settles with a ~40% echo.
// Bar 2 (A') digs and snaps a shade harder. Buga previously had no
// authored head keys.
// R2 (port panel: the hit read as a 2-beat SWELL and the chin dips fell
// under the prominence floor): the coil is twice as deep, the snap
// OVERSHOOTS in one frame and rings an echo, and the post-hit hold gets
// a live settle wobble instead of a 2-beat dead zone.
const _bugaHeadKeys = [
  DanceJointKey(0, rotation: 0.05), // first 'lo' — chin dips
  DanceJointKey(4, rotation: 0.09), // second, deeper
  DanceJointKey(8, rotation: 0.13), // third — coiled over the deep hold
  DanceJointKey(11, rotation: 0.14), // loads hard under the hit
  DanceJointKey(12, rotation: -0.16), // BUGA — one-frame snap, overshoot
  DanceJointKey(13, rotation: -0.02), // recoil
  DanceJointKey(14, rotation: -0.08), // echo ring
  DanceJointKey(15, rotation: -0.03), // settle wobble
  DanceJointKey(16, rotation: 0.05), // bar 2 restarts the descent
  DanceJointKey(20, rotation: 0.1),
  DanceJointKey(24, rotation: 0.14), // A' digs deeper
  DanceJointKey(27, rotation: 0.14),
  DanceJointKey(28, rotation: -0.16), // the bigger BUGA, inside the envelope
  DanceJointKey(29, rotation: -0.03), // recoil
  DanceJointKey(30, rotation: -0.09), // echo ring
  DanceJointKey(31, rotation: -0.04),
  DanceJointKey(32, rotation: 0.05), // == frame 0
];

const _bugaClavicleRKeys = [
  DanceJointKey(0, rotation: -0.04),
  DanceJointKey(4, rotation: -0.09),
  DanceJointKey(8, rotation: -0.16),
  DanceJointKey(11, rotation: -0.12),
  DanceJointKey(12, rotation: -0.46),
  DanceJointKey(13, rotation: -0.36),
  DanceJointKey(14, rotation: -0.1),
  DanceJointKey(16, rotation: 0.02),
  DanceJointKey(20, rotation: -0.1),
  DanceJointKey(24, rotation: -0.18),
  DanceJointKey(27, rotation: -0.14),
  DanceJointKey(28, rotation: -0.46),
  DanceJointKey(29, rotation: -0.36),
  DanceJointKey(30, rotation: -0.1),
  DanceJointKey(32, rotation: -0.04),
];
// 9-path r3 (every rater: "L and R crowns track each other almost
// exactly for the entire loop — the upper body moves as one slab"):
// the L shoulder now ANSWERS the R — every key rides ~1.2 frames later
// (microFrames) at ~3/4 amplitude, so hits roll across the girdle
// R-then-L instead of landing as a yoke.
const _bugaClavicleLKeys = [
  DanceJointKey(0, rotation: 0.034, microFrames: 1.1),
  DanceJointKey(4, rotation: 0.0765, microFrames: 1.1),
  DanceJointKey(8, rotation: 0.136, microFrames: 1.1),
  DanceJointKey(11, rotation: 0.102, microFrames: 1.1),
  DanceJointKey(12, rotation: 0.46, microFrames: 1.1),
  DanceJointKey(13, rotation: 0.36, microFrames: 1.1),
  DanceJointKey(14, rotation: 0.085, microFrames: 1.1),
  DanceJointKey(16, rotation: -0.017, microFrames: 1.1),
  DanceJointKey(20, rotation: 0.085, microFrames: 1.1),
  DanceJointKey(24, rotation: 0.153, microFrames: 1.1),
  DanceJointKey(27, rotation: 0.119, microFrames: 1.1),
  DanceJointKey(28, rotation: 0.46, microFrames: 1.1),
  DanceJointKey(29, rotation: 0.36, microFrames: 1.1),
  DanceJointKey(30, rotation: 0.085, microFrames: 1.1),
  DanceJointKey(32, rotation: 0.034, microFrames: 1.1),
];
const _bugaShoulderSocketRKeys = [
  DanceJointKey(0, rotation: -0.11, scaleX: 1.1, scaleY: 0.955),
  DanceJointKey(8, rotation: -0.11, scaleX: 1.1, scaleY: 0.955),
  DanceJointKey(10, rotation: -0.13, scaleX: 1.11, scaleY: 0.95),
  DanceJointKey(12, rotation: -0.25, scaleX: 1.22, scaleY: 0.9),
  DanceJointKey(13, rotation: -0.21, scaleX: 1.18, scaleY: 0.92),
  DanceJointKey(14, rotation: -0.13, scaleX: 1.1, scaleY: 0.95),
  DanceJointKey(15, rotation: -0.12, scaleX: 1.1, scaleY: 0.955),
  DanceJointKey(16),
  DanceJointKey(24, rotation: -0.11, scaleX: 1.1, scaleY: 0.955),
  DanceJointKey(26, rotation: -0.13, scaleX: 1.11, scaleY: 0.95),
  DanceJointKey(28, rotation: -0.25, scaleX: 1.22, scaleY: 0.9),
  DanceJointKey(29, rotation: -0.21, scaleX: 1.18, scaleY: 0.92),
  DanceJointKey(30, rotation: -0.13, scaleX: 1.1, scaleY: 0.95),
  DanceJointKey(31, rotation: -0.12, scaleX: 1.1, scaleY: 0.955),
  DanceJointKey(32, rotation: -0.11, scaleX: 1.1, scaleY: 0.955),
];
const _bugaShoulderSocketLKeys = [
  DanceJointKey(0, rotation: 0.11, scaleX: 1.1, scaleY: 0.955),
  DanceJointKey(8, rotation: 0.11, scaleX: 1.1, scaleY: 0.955),
  DanceJointKey(10, rotation: 0.13, scaleX: 1.11, scaleY: 0.95),
  DanceJointKey(12, rotation: 0.25, scaleX: 1.22, scaleY: 0.9),
  DanceJointKey(13, rotation: 0.21, scaleX: 1.18, scaleY: 0.92),
  DanceJointKey(14, rotation: 0.13, scaleX: 1.1, scaleY: 0.95),
  DanceJointKey(15, rotation: 0.12, scaleX: 1.1, scaleY: 0.955),
  DanceJointKey(16),
  DanceJointKey(24, rotation: 0.11, scaleX: 1.1, scaleY: 0.955),
  DanceJointKey(26, rotation: 0.13, scaleX: 1.11, scaleY: 0.95),
  DanceJointKey(28, rotation: 0.25, scaleX: 1.22, scaleY: 0.9),
  DanceJointKey(29, rotation: 0.21, scaleX: 1.18, scaleY: 0.92),
  DanceJointKey(30, rotation: 0.13, scaleX: 1.1, scaleY: 0.95),
  DanceJointKey(31, rotation: 0.12, scaleX: 1.1, scaleY: 0.955),
  DanceJointKey(32, rotation: 0.11, scaleX: 1.1, scaleY: 0.955),
];
// The Buga show-off is the PEACOCK BOW (the research audit's top finding —
// the real 2022 signature is BOTH arms opening out-down like a proud
// peacock's wings, never a one-arm overhead present). The paws hang by the
// thighs through the three lo-lo-lo counts, swell outward with the load,
// and snap into a WIDE extended bow on the BUGA hit, held for a beat's
// worth of strut. High-reach targets keep the solve hand-led: a close
// target folds the elbow ABOVE the shoulder and the sleeve renders as a
// fin beside the head, paw dangling at the chest — elbow-led garbage.
const List<DanceIkTargetKey> _bugaHandRTargetKeys = [
  // Two-bone reality: the arm is ~48+37 world units, and flexion grows
  // brutally fast below full reach (83% reach is already a 68-degree
  // elbow). The lo counts hang the paws by the THIGHS (~96% reach, soft
  // elbow) and the hit opens a WIDE extended bow (~90% reach) so the
  // elbow stays slung below the shoulder-hand line through every frame.
  // The paws POP off the hips on each lo count (director round 3), and the
  // retraction from the present spends two frames with the R arm leading L
  // by one frame — the round-3 one-frame teleport read as a glitch.
  DanceIkTargetKey(0, x: 40, y: 16, tension: 0.6), // count pop off the hip
  DanceIkTargetKey(2, x: 44, y: 24, tension: 0.3), // resettle on the thigh
  DanceIkTargetKey(4, x: 52, y: 8, tension: 0.6), // count 2 pop
  DanceIkTargetKey(6, x: 56, y: 18, tension: 0.3),
  DanceIkTargetKey(8, x: 62, y: 6, tension: 0.6), // count 3 pop (deepest)
  DanceIkTargetKey(10, x: 78, y: -16, tension: 0.2), // opening transit
  DanceIkTargetKey(12, x: 106, y: -34, tension: 1), // BUGA — full peacock
  DanceIkTargetKey(14, x: 106, y: -34, tension: 1), // held strut
  DanceIkTargetKey(15, x: 88, y: -4, tension: 0.4), // elbow leads the return
  DanceIkTargetKey(16, x: 58, y: 24, tension: 0.5), // overshoot past the hip
  DanceIkTargetKey(18, x: 48, y: 18, tension: 0.3), // settle
  DanceIkTargetKey(20, x: 46, y: 8, tension: 0.6), // bar-2 count pop
  DanceIkTargetKey(22, x: 50, y: 18, tension: 0.3),
  DanceIkTargetKey(24, x: 62, y: 6, tension: 0.6),
  DanceIkTargetKey(26, x: 78, y: -16, tension: 0.2), // opening transit
  DanceIkTargetKey(28, x: 106, y: -34, tension: 1), // BUGA
  DanceIkTargetKey(30, x: 88, y: -4, tension: 0.4), // R leads the return
  DanceIkTargetKey(31, x: 56, y: 24, tension: 0.5), // overshoot
  DanceIkTargetKey(32, x: 40, y: 16, tension: 0.6),
];
const List<DanceIkTargetKey> _bugaHandLTargetKeys = [
  DanceIkTargetKey(0, x: -40, y: 16, tension: 0.6), // count pop off the hip
  DanceIkTargetKey(2, x: -44, y: 24, tension: 0.3),
  DanceIkTargetKey(4, x: -52, y: 8, tension: 0.6),
  DanceIkTargetKey(6, x: -56, y: 18, tension: 0.3),
  DanceIkTargetKey(8, x: -62, y: 6, tension: 0.6),
  DanceIkTargetKey(10, x: -78, y: -16, tension: 0.2), // opening transit
  DanceIkTargetKey(12, x: -106, y: -34, tension: 1), // BUGA — full peacock
  DanceIkTargetKey(14, x: -106, y: -34, tension: 1), // held strut
  DanceIkTargetKey(15, x: -98, y: -20, tension: 0.4), // trails R by a frame
  DanceIkTargetKey(16, x: -72, y: 8, tension: 0.4),
  DanceIkTargetKey(17, x: -56, y: 26, tension: 0.5), // overshoot past the hip
  DanceIkTargetKey(18, x: -48, y: 18, tension: 0.3), // settle
  DanceIkTargetKey(20, x: -46, y: 8, tension: 0.6),
  DanceIkTargetKey(22, x: -50, y: 18, tension: 0.3),
  DanceIkTargetKey(24, x: -62, y: 6, tension: 0.6),
  DanceIkTargetKey(26, x: -78, y: -16, tension: 0.2), // opening transit
  DanceIkTargetKey(28, x: -106, y: -34, tension: 1), // BUGA
  DanceIkTargetKey(30, x: -98, y: -20, tension: 0.4), // trails the R return
  DanceIkTargetKey(31, x: -68, y: 12, tension: 0.4),
  DanceIkTargetKey(32, x: -40, y: 16, tension: 0.6),
];
// The widening step-out lives in the TRANSIT (f10-f11 / f26-f27) so both
// feet are planted wide with even weight for the whole held present — the
// round-3 panel read the late-arriving step as a balletic lifted leg.
// R11 (owner asked to keep digging on the "hop-and-shrink" glitch):
// root-caused via dense sub-frame sampling of the SOLVED foot position
// (not just integer frames) — the curve is perfectly smooth, there is no
// discontinuity. The "pop" is real motion, not a numeric glitch: footL
// is anchored to `hips` and FREE (not yet the support foot) through
// frames 0-8, so its near-constant authored y (~102, meant to read as
// "on the ground") gets carried through the hip's OWN big vertical
// sink almost 1:1 (hips.y swings ~59 world units by frame 8; footL's
// SOLVED y swings ~63) — the free foot's target never compensates for
// the anchor sinking further away from it. It then gets yanked back
// toward the real ground once footL becomes the support foot at
// exactly frame 8 and the world-anchor blend engages — except the
// blend is MATHEMATICALLY ZERO at the exact instant a span starts
// (`_supportFootAnchorBlend`'s fade-in is 0 at p=span.start), so the
// uncorrected oversink renders fully exposed for one frame before the
// correction ramps up — that's the pop. Fixed at the source: pulled
// frames 4/8's authored y up (less positive = less sink) to roughly
// cancel the hip's own drift at those frames, so the free foot's
// target already sits near true ground BEFORE the anchor has to yank
// it there.
const _bugaFootLTargetKeys = [
  DanceIkTargetKey(0, x: -58, y: 101),
  DanceIkTargetKey(4, x: -72, y: 87),
  DanceIkTargetKey(8, x: -60, y: 66),
  DanceIkTargetKey(10, x: -80, y: 103),
  DanceIkTargetKey(11, x: -94, y: 104),
  DanceIkTargetKey(12, x: -98, y: 104),
  DanceIkTargetKey(13, x: -98, y: 104),
  DanceIkTargetKey(14, x: -98, y: 104),
  // R11: mirrors footR's frame-20/24 anti-sink compensation below — same
  // mechanism, bar-2's own (deeper) hip drift.
  DanceIkTargetKey(16, x: -58, y: 101),
  DanceIkTargetKey(20, x: -72, y: 86),
  DanceIkTargetKey(24, x: -62, y: 62),
  DanceIkTargetKey(26, x: -82, y: 103),
  DanceIkTargetKey(27, x: -96, y: 104),
  DanceIkTargetKey(28, x: -100, y: 104),
  DanceIkTargetKey(29, x: -100, y: 104),
  DanceIkTargetKey(30, x: -100, y: 104),
  DanceIkTargetKey(32, x: -58, y: 101),
];
const _bugaFootRTargetKeys = [
  // R11: same anti-sink compensation as hand.L's frame 4/8 above — footR
  // is the nominal SUPPORT foot through frames 0-8, but the world-anchor
  // blend alone didn't fully protect it either (still measured a ~50
  // unit oversink at f8 before this), so the raw target needs the same
  // fix regardless of support/free role.
  DanceIkTargetKey(0, x: 62, y: 101),
  DanceIkTargetKey(4, x: 76, y: 87),
  DanceIkTargetKey(8, x: 62, y: 66),
  DanceIkTargetKey(10, x: 82, y: 103),
  DanceIkTargetKey(11, x: 96, y: 104),
  DanceIkTargetKey(12, x: 100, y: 104),
  DanceIkTargetKey(13, x: 100, y: 104),
  DanceIkTargetKey(14, x: 100, y: 104),
  // R11: mirrors hand.L's frame-4/8 anti-sink compensation above (see
  // that comment) — same mechanism, bar-2's own (deeper, since this
  // session's escalation fix widened it) hip drift.
  DanceIkTargetKey(16, x: 62, y: 101),
  DanceIkTargetKey(20, x: 76, y: 86),
  DanceIkTargetKey(24, x: 64, y: 62),
  DanceIkTargetKey(26, x: 84, y: 103),
  DanceIkTargetKey(27, x: 98, y: 104),
  DanceIkTargetKey(28, x: 102, y: 104),
  DanceIkTargetKey(29, x: 102, y: 104),
  DanceIkTargetKey(30, x: 102, y: 104),
  DanceIkTargetKey(32, x: 62, y: 101),
];
