part of '../cat_in_suit.dart';

// ─────────────────────────────────────────────────────────────────────────
// Azonto (Ghana, ~2011) — a bent-knee, hip-swivel groove whose signature is
// the expressive miming HAND gestures. Reuses the shaku bent-knee groove for
// the lower body; the Azonto character lives in the hip swivel (with a chest
// counter-rotation) and an alternating point-out arm mime.
// ─────────────────────────────────────────────────────────────────────────
// The signature mime: a near-FULLY-EXTENDED point-out so the sleeved arm shoots
// clear of the torso (a bent hand at the waist just reads as a parked paw, or
// worse, the tail). Arm length from the shoulder is ~89; the points sit at ~84
// so the elbow snaps nearly straight. LEFT arm points out-down-left on beats
// 1/3/5/7, retracts to the chest between; opposite phase to the right arm, so
// one arm is always thrown out — the gesture swings side to side on the beat.
// A 2-gesture phrase for variety: BAR 1 (frames 0-16) ALTERNATES single-arm
// points (L out, R out, L out, R out); BAR 2 (16-32) the arms SYNC into a
// double point-out punch on every beat. Reach pulled back to ~80 (of ~89) so
// the elbow keeps a soft bend instead of locking dead-straight at the limit.
// The point-out rides at lower-chest height (y -10), not down at the thigh
// (y 6, where it read as a dangling arm overlapping the leg): a near-straight
// arm fired OUT to the side (x +-88, ~79% of reach) so it reads as a deliberate
// horizontal "point" clear of both torso and legs. Retracts to the chest (not
// the waist) between beats.
// The OUT-point keys use Ease.easeOutBack so the arm whips PAST the apex and
// settles back onto the point (anticipation→overshoot→settle), instead of
// reaching the extension and freezing — needs the non-smooth channel below.
// Azonto is MIME: the arms act out everyday actions over the leg groove
// (the research audit's top azonto finding — straight-arm point-outs read
// as generic boy-band, not azonto). Bar 1 drives a steering wheel; bar 2
// throws alternating cross-body jabs with the idle paw chambered at the
// hip crest. Panel round 1 lessons baked in: the grips must be SEPARATED
// and counter-rotate in opposing vertical arcs or the wheel reads as one
// blob clutching the tie, and the jabs must reach FULL extension past the
// opposite shoulder line — this rig's upper arm is ~48 world units, so a
// half-reach target folds the elbow across the belly and the sleeve reads
// as a stump (two-bone flexion grows brutally below full reach).
const _azontoHandLTargetKeys = [
  // Round 4, measured in RENDERED space: targets live in the torso anchor
  // whose origin sits ~50 world units BELOW the shoulder line (a probe of
  // the round-3 keys showed the "chest-height" jab at y-44 rendering ON
  // the sternum, and the wheel at belly height with no vertical trade —
  // every rater called both mimes invisible). Mapping: brow ~ -82,
  // shoulder line ~ -60, ribs ~ -38, hip crest ~ -10.
  // Bar 1 wheel: grips at shoulder width counter-rotate around a shared
  // hub — L rises to the brow while R drops to the ribs, swapping over two
  // beats, soft elbows, on the rim all bar.
  // Round 5: the wheel-grip x sat at ~25-28 units from the torso anchor —
  // only 10-35% of the arm's actual reach, deep inside the two-bone
  // solver's near-degenerate fold zone (reach below/near minReach makes the
  // elbow position hypersensitive to tiny target changes, so the elbow
  // jittered wildly between frames while the wrist stayed tucked near the
  // chest the whole time — every rater read that as "arms frozen in one
  // crossed guard"). x is choreographically capped at the -38/-18 lane
  // (round 1: wider grips read as pointing away from the wheel), so pushed
  // to the very edge of that band instead of past it, and traded some of
  // the needed reach for y spread (the tested band there is generous,
  // -90..32) to pull the target further from the near-degenerate zone.
  // Round 6: that fix widened the RANGE but every key kept x within a
  // single unit (-36/-37) — a near-perfectly VERTICAL bob, not a wheel
  // arc. A hand sliding straight up and down close to the body still
  // silhouettes as a tucked guard the whole time (every rater's "frozen
  // hug" read), even though the wrist genuinely moves.
  //
  // Round 9 re-author: the oval-arc fix (round 6) still read as a static
  // crossed guard in the rendered grid — confirmed directly (23 of 24
  // sampled cells were visually near-identical). Root cause, found by
  // measuring WORLD-space hand separation: L rising to the brow while R
  // drops to the ribs (opposing heights, same x-lane throughout) puts
  // both wrists on their OWN side the entire bar, so nothing ever crosses
  // or converges — there is no shared "grip" for the eye to read, just two
  // independent arms doing their own thing. A real wheel-grip needs both
  // hands legible as gripping the SAME object: held at close to the same
  // height, rocking together side to side. Swapped which hand is "outboard"
  // (wide) vs "inboard" (narrow) every 2 beats instead of which hand is
  // "high" vs "low" — L and R now trade x while keeping a small (8-unit,
  // over the test's required >=4) height gap, so the dominant visible
  // motion is a synchronized side-to-side turn, held at each extreme for
  // 2 frames (not a single-frame spike) so it reads as sustained.
  // R10 follow-up: widened the swing itself (not just added rotation) —
  // a reach-ratio probe showed the old wide/narrow pair sat at ~0.75/0.58
  // (span 0.17); pushing toward the lane's actual edges gave more room,
  // but the very edge (ratio ~0.80) straightened the elbow to 180 degrees
  // and broke the elbow-bend validator — backed off to ~0.78/0.55 (span
  // ~0.23), still a real ~35% bigger visible excursion than before while
  // clearing both the near-degenerate zone and the straight-elbow ceiling.
  DanceIkTargetKey(0, x: -20, y: 28), // wide reach, held
  DanceIkTargetKey(2, x: -27, y: 18, tension: 0.2), // turning
  DanceIkTargetKey(4, x: -36, y: 5, tension: 0.6), // narrower reach, held
  DanceIkTargetKey(6, x: -27, y: 18, tension: 0.2), // turning back
  DanceIkTargetKey(8, x: -20, y: 28, tension: 0.6), // wide again
  DanceIkTargetKey(10, x: -27, y: 18, tension: 0.2),
  DanceIkTargetKey(12, x: -36, y: 5, tension: 0.6), // narrower again
  DanceIkTargetKey(14, x: -27, y: 18, tension: 0.8), // into bar 2
  // Bar 2 jabs (beats 5-8, alternating L,R,L,R): fire to near-full
  // extension PAST the opposite shoulder line in one beat-quarter, hold a
  // frame, recoil; the idle paw chambers at the OWN-side hip crest.
  // Round 9: measured world position confirmed the jab and the OTHER
  // hand's chamber were landing within ~1 world unit of each other in x
  // (both authored on the same broad side of the body once the crossing
  // hand reaches over) — the two poses visually merged into one blob
  // instead of contrasting "one hand out, one hand tucked." The chamber
  // is already pinned to its test floor (x magnitude just over 24); the
  // jab has no such ceiling, so pushed it much further across to clear
  // the chamber's landing zone with real daylight between them.
  //
  // R10 follow-up: EVERY rater still calls the jab a static crossed hold
  // that "never extends." Root-caused with a world-space probe (anchor
  // basis vectors at the target's own frame, not just position sampling):
  // the anchor (`torso`) DRIFTS ~24 world units to the left across frames
  // 14-20 as the step-touch weight shifts — exactly opposing the jab's
  // rightward local reach, so a big local-space cross-body reach still
  // lands only slightly right of center in world space (target (33,-50)
  // resolves to world x~25 at frame 16, barely past the chamber hand's
  // own ~24). This is a DIFFERENT bug than the reach-zone/rotation issues
  // fixed elsewhere this round: the target IS being tracked accurately
  // (no fold-clamp, no IK error) and the local values ARE past every
  // tested floor — the anchor itself is moving against the gesture.
  // Tried widening further to compensate (33->38, -50->-55): a follow-up
  // reach-ratio probe against the ACTUAL shoulder position (not just the
  // anchor's linear basis) showed the ORIGINAL values already sit at
  // ratio ~0.81-0.85 — this move's jab was already pushed to near the
  // hard reach ceiling in an earlier round (matches the old "reach-
  // limited" note below), so there is no further room in local-target
  // space to counteract the anchor drift; widening past this breaks the
  // hard reach-limit validator outright. Reverted the widen. The actual
  // fix needs the root-motion side: taming how far the pocket keys'
  // weight-shift drifts the torso specifically during the jab beats
  // (frames 14-20), which touches footwork/weight-commit timing shared
  // with other channels — left for a dedicated pass rather than risking
  // those here.
  DanceIkTargetKey(16, x: 33, y: -50, tension: 1), // JAB past the far line
  DanceIkTargetKey(17, x: 32, y: -48, tension: 1), // hold
  DanceIkTargetKey(19, x: 10, y: -44, tension: 0.4), // recoil through guard
  DanceIkTargetKey(20, x: -26, y: -10, tension: 0.8), // chamber at the hip
  DanceIkTargetKey(22, x: -27, y: -12, tension: 0.5),
  DanceIkTargetKey(23, x: -10, y: -34, tension: 0.4), // loads
  DanceIkTargetKey(24, x: 33, y: -50, tension: 1), // JAB
  DanceIkTargetKey(25, x: 32, y: -48, tension: 1),
  DanceIkTargetKey(27, x: 10, y: -44, tension: 0.4),
  DanceIkTargetKey(28, x: -26, y: -10, tension: 0.8), // chamber
  DanceIkTargetKey(30, x: -24, y: 5, tension: 0.5),
  DanceIkTargetKey(31, x: -22, y: 15, tension: 0.6), // lifts to the wheel
  DanceIkTargetKey(32, x: -20, y: 25), // == frame 0
];
const _azontoHandRTargetKeys = [
  // Round 9 re-author: mirrors the hand.L rock-together wheel redesign
  // and jab-reach fix above (see those comments) — same root causes,
  // mirrored keys.
  // R10 follow-up: widened to match hand.L's bigger reach-ratio swing
  // (see that comment above) — same mirrored values.
  DanceIkTargetKey(0, x: 36, y: 5, tension: 0.6), // narrower reach, held
  DanceIkTargetKey(2, x: 27, y: 18, tension: 0.2),
  DanceIkTargetKey(4, x: 20, y: 28, tension: 0.6), // wide reach, held
  DanceIkTargetKey(6, x: 27, y: 18, tension: 0.2),
  DanceIkTargetKey(8, x: 36, y: 5, tension: 0.6), // narrower again
  DanceIkTargetKey(10, x: 27, y: 18, tension: 0.2),
  DanceIkTargetKey(12, x: 20, y: 28, tension: 0.6), // wide again
  DanceIkTargetKey(14, x: 27, y: 18, tension: 0.2), // into bar 2
  // Bar 2: chambered at the own-side hip while the left jabs, then the
  // answering cross jab.
  DanceIkTargetKey(16, x: 26, y: -10, tension: 0.8), // chamber at the hip
  DanceIkTargetKey(18, x: 27, y: -12, tension: 0.5),
  DanceIkTargetKey(19, x: 10, y: -34, tension: 0.4), // loads
  DanceIkTargetKey(20, x: -33, y: -50, tension: 1), // JAB past the far line
  DanceIkTargetKey(21, x: -32, y: -48, tension: 1), // hold
  DanceIkTargetKey(23, x: -10, y: -44, tension: 0.4), // recoil through guard
  DanceIkTargetKey(24, x: 26, y: -10, tension: 0.8), // chamber
  DanceIkTargetKey(26, x: 27, y: -12, tension: 0.5),
  DanceIkTargetKey(27, x: 10, y: -34, tension: 0.4),
  DanceIkTargetKey(28, x: -33, y: -50, tension: 1), // JAB
  DanceIkTargetKey(29, x: -32, y: -48, tension: 1),
  DanceIkTargetKey(31, x: 29, y: 0, tension: 0.6), // settles to the wheel
  DanceIkTargetKey(32, x: 32, y: 10, tension: 0.6), // == frame 0
];
// R10: every rater independently called the re-positioned wheel-mime and
// jab "legible but frozen holds" — right reach zone, no gesture motion of
// their own. The rigging rater measured the SOLVED arm rotation and found
// real but small swings (10-15deg) that read as static at this compact,
// hip-hugging reach — the same "small delta near the body reads as no
// motion" lesson from the reach-zone investigations, just one layer up.
// Crucially, azonto never had a hand ROTATION channel at all (unlike
// shaku/sekem/zanku's hands, which all key CatBones.handL/R directly) —
// only the IK target's position ever moved, so the paw itself never
// twists. Added an explicit paw-twist channel so the wheel visibly
// "grips and turns" (both hands share the same rotation, since they're
// gripping one shared rim — L and R are exact opposites at every frame
// because the position keys already put them on opposite sides of the
// rim: whichever hand is wide, its twist is positive) and the jab gets a
// real punch-snap (positive rotation on the strike, relaxed negative on
// the chamber) instead of a static crossed hold. Magnitude matched to
// zanku's hand-rotation channel (its punch/pump already reads clearly).
const _azontoHandLKeys = [
  DanceJointKey(0, rotation: 0.28), // wide grip
  DanceJointKey(4, rotation: -0.28), // narrow grip — wheel turns
  DanceJointKey(8, rotation: 0.28),
  DanceJointKey(12, rotation: -0.28),
  DanceJointKey(14, rotation: -0.1), // settle before the jab
  DanceJointKey(16, rotation: 0.4), // JAB snap
  DanceJointKey(17, rotation: 0.32), // hold
  DanceJointKey(19, rotation: 0.05), // recoil
  DanceJointKey(20, rotation: -0.15), // chamber, relaxed
  DanceJointKey(22, rotation: -0.12),
  DanceJointKey(23, rotation: 0.05), // loads
  DanceJointKey(24, rotation: 0.4), // JAB
  DanceJointKey(25, rotation: 0.32),
  DanceJointKey(27, rotation: 0.05),
  DanceJointKey(28, rotation: -0.15), // chamber
  DanceJointKey(30, rotation: -0.05),
  DanceJointKey(31, rotation: 0.1), // lifts back to the wheel
  DanceJointKey(32, rotation: 0.28), // == frame 0
];
const _azontoHandRKeys = [
  DanceJointKey(0, rotation: -0.28), // narrow grip
  DanceJointKey(4, rotation: 0.28), // wide grip — wheel turns
  DanceJointKey(8, rotation: -0.28),
  DanceJointKey(12, rotation: 0.28),
  DanceJointKey(14, rotation: 0.1),
  DanceJointKey(16, rotation: -0.15), // chamber, relaxed
  DanceJointKey(18, rotation: -0.12),
  DanceJointKey(19, rotation: 0.05), // loads
  DanceJointKey(20, rotation: 0.4), // JAB snap
  DanceJointKey(21, rotation: 0.32), // hold
  DanceJointKey(23, rotation: 0.05), // recoil
  DanceJointKey(24, rotation: -0.15), // chamber
  DanceJointKey(26, rotation: -0.12),
  DanceJointKey(27, rotation: 0.05),
  DanceJointKey(28, rotation: 0.4), // JAB
  DanceJointKey(29, rotation: 0.32),
  DanceJointKey(31, rotation: 0.1), // settles toward the wheel
  DanceJointKey(32, rotation: -0.28), // == frame 0
];
const _azontoFootLTargetKeys = [
  DanceIkTargetKey(0, x: -56, y: 103),
  DanceIkTargetKey(2, x: -56, y: 103), // planted through left support
  DanceIkTargetKey(4, x: -56, y: 103),
  DanceIkTargetKey(5, x: -52, y: 96), // pickup — visible passing lift
  DanceIkTargetKey(6, x: -48, y: 102), // free-foot redirect plants
  DanceIkTargetKey(8, x: -48, y: 102),
  DanceIkTargetKey(10, x: -48, y: 102), // planted through left support
  DanceIkTargetKey(12, x: -48, y: 102),
  DanceIkTargetKey(13, x: -53, y: 97), // pickup
  DanceIkTargetKey(14, x: -58, y: 103),
  DanceIkTargetKey(16, x: -58, y: 103),
  DanceIkTargetKey(18, x: -58, y: 103), // planted through left support
  DanceIkTargetKey(20, x: -58, y: 103),
  DanceIkTargetKey(21, x: -54, y: 97), // pickup
  DanceIkTargetKey(22, x: -50, y: 102),
  DanceIkTargetKey(23, x: -56, y: 97), // pickup
  DanceIkTargetKey(24, x: -62, y: 103),
  DanceIkTargetKey(26, x: -62, y: 103), // planted through left support
  DanceIkTargetKey(28, x: -62, y: 103),
  DanceIkTargetKey(29, x: -56, y: 97), // pickup
  DanceIkTargetKey(30, x: -50, y: 102),
  DanceIkTargetKey(31, x: -53, y: 98), // pickup home
  DanceIkTargetKey(32, x: -56, y: 103),
];
const _azontoFootRTargetKeys = [
  DanceIkTargetKey(0, x: 54, y: 102),
  DanceIkTargetKey(1, x: 52, y: 97), // pickup — visible passing lift
  DanceIkTargetKey(2, x: 50, y: 102), // free-foot redirect plants
  DanceIkTargetKey(4, x: 54, y: 103),
  DanceIkTargetKey(6, x: 54, y: 103), // planted through right support
  DanceIkTargetKey(8, x: 54, y: 103),
  DanceIkTargetKey(9, x: 51, y: 97), // pickup
  DanceIkTargetKey(10, x: 48, y: 102),
  DanceIkTargetKey(12, x: 48, y: 102),
  DanceIkTargetKey(14, x: 48, y: 102), // planted through right support
  DanceIkTargetKey(16, x: 48, y: 102),
  DanceIkTargetKey(17, x: 54, y: 97), // pickup
  DanceIkTargetKey(18, x: 60, y: 103),
  DanceIkTargetKey(20, x: 60, y: 103),
  DanceIkTargetKey(22, x: 60, y: 103), // planted through right support
  DanceIkTargetKey(24, x: 60, y: 103),
  DanceIkTargetKey(25, x: 56, y: 97), // pickup
  DanceIkTargetKey(26, x: 52, y: 102),
  DanceIkTargetKey(28, x: 52, y: 102),
  DanceIkTargetKey(30, x: 52, y: 102), // planted through right support
  DanceIkTargetKey(32, x: 54, y: 102),
];
const _azontoPocketKeys = [
  // Bar 1 (frames 0-16, the wheel mime): the rootDx/pelvis/chest fields
  // used to repeat the SAME value at each pair of keys (0&2, 4&6, ...)
  // then jump to the opposite extreme in the very next 2-frame gap — a
  // probe of rendered shoulder-socket world position showed this
  // concentrated the entire weight transfer into one 2-frame window, a
  // ~40-unit one-frame position jump (round-4 rigging critique: "sockets
  // swing 46 units in 3 frames"). Fixed two ways: the intermediate keys
  // now sit at the true midpoint between their neighboring peaks (so the
  // swing paces evenly across the whole beat instead of snapping in half
  // a beat), and the peak rootDx/pelvis/chest values are pulled in ~28%
  // (a 1-beat left-right transfer is still an inherently fast swing —
  // smoothing the curve shape alone left the peak-to-peak rate too high).
  // rootDy keeps its own already-smooth bounce (a real step-touch
  // pattern, not a hold-then-snap), so it is untouched.
  DanceBodyKey(
    0,
    rootDx: -7.776,
    rootDy: 22,
    pelvisRotation: -0.1008,
    chestRotation: 0.0864,
    chestScaleY: 0.92,
    chestScaleX: 1.06,
  ),
  DanceBodyKey(
    2,
    rootDx: 0,
    rootDy: 12,
    pelvisRotation: 0.0108,
    chestRotation: -0.0108,
    chestScaleY: 0.89,
    chestScaleX: 1.08,
  ),
  DanceBodyKey(
    4,
    rootDx: 7.776,
    rootDy: 30,
    pelvisRotation: 0.1224,
    chestRotation: -0.108,
    chestScaleY: 0.86,
    chestScaleX: 1.1,
  ),
  DanceBodyKey(
    6,
    rootDx: -0.432,
    rootDy: 14,
    pelvisRotation: 0.0072,
    chestRotation: -0.0072,
    chestScaleY: 0.88,
    chestScaleX: 1.085,
  ),
  DanceBodyKey(
    8,
    rootDx: -8.64,
    rootDy: 24,
    pelvisRotation: -0.108,
    chestRotation: 0.0936,
    chestScaleY: 0.9,
    chestScaleX: 1.07,
  ),
  DanceBodyKey(
    10,
    rootDx: 0,
    rootDy: 12,
    pelvisRotation: 0.0072,
    chestRotation: -0.0072,
    chestScaleY: 0.88,
    chestScaleX: 1.085,
  ),
  DanceBodyKey(
    12,
    rootDx: 8.64,
    rootDy: 30,
    pelvisRotation: 0.1224,
    chestRotation: -0.108,
    chestScaleY: 0.86,
    chestScaleX: 1.1,
  ),
  DanceBodyKey(
    14,
    rootDx: 3.195,
    rootDy: 14,
    pelvisRotation: 0.1412,
    chestRotation: -0.124,
    chestScaleY: 0.905,
    chestScaleX: 1.07,
  ),
  DanceBodyKey(
    16,
    rootDx: -2.25,
    rootDy: 24,
    pelvisRotation: 0.16,
    chestRotation: -0.14,
    chestScaleY: 0.95,
    chestScaleX: 1.04,
  ),
  DanceBodyKey(
    18,
    rootDx: -2.25,
    rootDy: 12,
    pelvisRotation: 0.06,
    chestRotation: -0.05,
    chestScaleY: 1.02,
    chestScaleX: 0.99,
  ),
  DanceBodyKey(
    20,
    rootDx: 2.25,
    rootDy: 30,
    pelvisRotation: -0.18,
    chestRotation: 0.16,
    chestScaleY: 0.95,
    chestScaleX: 1.04,
  ),
  DanceBodyKey(
    22,
    rootDx: 2.25,
    rootDy: 14,
    pelvisRotation: -0.07,
    chestRotation: 0.06,
    chestScaleY: 1.02,
    chestScaleX: 0.99,
  ),
  DanceBodyKey(
    24,
    rootDx: -2.48,
    rootDy: 26,
    pelvisRotation: 0.18,
    chestRotation: -0.16,
    chestScaleY: 0.95,
    chestScaleX: 1.04,
  ),
  DanceBodyKey(
    26,
    rootDx: -2.48,
    rootDy: 12,
    pelvisRotation: 0.06,
    chestRotation: -0.05,
    chestScaleY: 1.02,
    chestScaleX: 0.99,
  ),
  DanceBodyKey(
    28,
    rootDx: 2.48,
    rootDy: 32,
    pelvisRotation: -0.19,
    chestRotation: 0.17,
    chestScaleY: 0.95,
    chestScaleX: 1.04,
  ),
  DanceBodyKey(
    30,
    rootDx: 2.02,
    rootDy: 14,
    pelvisRotation: -0.07,
    chestRotation: 0.06,
    chestScaleY: 1.02,
    chestScaleX: 0.99,
  ),
  DanceBodyKey(
    32,
    rootDx: -2.02,
    rootDy: 22,
    pelvisRotation: -0.14,
    chestRotation: 0.12,
    chestScaleY: 0.92,
    chestScaleX: 1.06,
  ),
];
