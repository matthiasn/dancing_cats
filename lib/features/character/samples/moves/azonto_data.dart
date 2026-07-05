part of '../cat_in_suit.dart';

// Azonto-only damping of the SHARED `_shakuGrooveCalm` track, applied just to
// bar 2's two jab windows (frames 14-20 and 22-28, one per punch pair — the
// second window shows the exact same drift pattern on re-probe). Root-caused
// via a direct world-space probe (`frame.world[CatBones.torso]`, not just
// authored key values): the jab's IK-target anchor (`torso`) drags ~27 world
// units opposite the jab's own reach direction across each window, because
// torso's world position is driven by its ROOT/PELVIS ancestors' translation
// and lever-arm rotation — a bone's OWN rotation never moves its own origin,
// only an ancestor's does, same mechanism as the clavicle/socket anti-hinge.
// Ablation (temporarily zeroing each `bodyMotion` track in turn and
// re-probing) attributed this track's root+pelvis motion as the single
// largest contributor (disabling it dropped the swing from ~27 to ~16 world
// units, vs. azonto's own `_azontoPocketKeys` contributing only ~5 when
// disabled alone) — and the composition is genuinely NONLINEAR (fully
// zeroing both sources did not monotonically maximize the resulting jab/
// chamber world-x gap at every frame; a partial 0.15 gain measured better
// or equal at 3 of the 4 jab instants). Since this list is shared with
// shaku/zanku's own grooves, damp a LOCAL copy rather than editing the
// shared source — bar 1's wheel-mime and every other move's groove keep the
// original swivel unchanged. Net result, probe-verified (world-x gap
// between the jabbing and chambered hand at frames 16/20/24/28): baseline
// ~1-1.5 world units (read as one merged blob) -> ~4.4/6.2/8.2/13.4 after
// this fix, a real but MODEST improvement — the jab's local target is
// already at its reach-limit ceiling (see `_azontoHandLTargetKeys`'s R10
// note), so there is no further room to widen the local values themselves;
// this is likely close to this lever's practical ceiling.
List<DanceBodyKey> _azontoGrooveCalm = [
  for (final k in _shakuGrooveCalm)
    if (k.frame >= 14 && k.frame <= 30)
      DanceBodyKey(
        k.frame,
        rootDx: k.rootDx == null ? null : k.rootDx! * 0.15,
        rootDy: k.rootDy,
        rootRotation: k.rootRotation == null ? null : k.rootRotation! * 0.15,
        pelvisRotation: k.pelvisRotation == null
            ? null
            : k.pelvisRotation! * 0.15,
        chestRotation: k.chestRotation,
        chestScaleX: k.chestScaleX,
        chestScaleY: k.chestScaleY,
        ease: k.ease,
      )
    else
      k,
];

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
  // 9-path round 2 (coach + animator, twice: the wheel "reads as
  // hands-on-hips... never breaks the torso silhouette"): the whole
  // bars-1-2 orbit rises ~38 units to STERNUM height — elbows lifted,
  // fists rolling in front of the chest, the mime finally legible at
  // strip distance. The x lane is unchanged (the wheel-lane gate holds).
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
  DanceIkTargetKey(0, x: -22, y: -10), // wide reach, held
  DanceIkTargetKey(2, x: -33, y: -20, tension: 0.2), // turning
  DanceIkTargetKey(4, x: -42, y: -31, tension: 0.6), // narrower reach, held
  DanceIkTargetKey(6, x: -33, y: -20, tension: 0.2), // turning back
  DanceIkTargetKey(8, x: -22, y: -10, tension: 0.6), // wide again
  DanceIkTargetKey(10, x: -33, y: -20, tension: 0.2),
  DanceIkTargetKey(12, x: -42, y: -31, tension: 0.6), // narrower again
  DanceIkTargetKey(14, x: -33, y: -20, tension: 0.8), // into bar 2
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
  // R follow-up (panel post-PR#54): the anchor-drift damping fix measurably
  // widened the jab/chamber world-x gap (probe numbers) but a direct render
  // crop showed it still reads as a tight crossed guard — the panel was
  // right that a few world units of anchor compensation doesn't survive
  // down to a legible silhouette. TRIED widening the jab's local reach
  // further (33,-50 -> 48,-60, then scaled attempts) on the theory that an
  // elbow-bend-degrees probe (~90.8deg vs a 178deg ceiling) showed room —
  // that theory was WRONG: the elbow-bend metric was measured against the
  // wrong reference and looked permissive, but re-probing with the actual
  // `MotionConstraintValidator.analyze()` (the same mechanism the "hard arm
  // reach limit" test uses) shows the BASELINE (33,-50) already sits at
  // reachRatio ~0.97 at its worst phase — essentially maxed out, not the
  // ~80-85% every earlier round assumed. There is NO room to widen local
  // reach further; the arm is already at its hard physical limit at
  // baseline. Reverted the widen. The panel's OTHER suggested levers
  // (elbow abduction independent of the wrist target, a forward shoulder
  // roll, a post-strike recoil/rebound) are genuinely different mechanisms
  // from "move the IK target further" and are the real next step — left
  // for a dedicated pass since they need new authored motion, not a value
  // tune. See the panel digest for the specific critiques.
  // R follow-up (panel post-PR#54, task #45 part 1): the movement rater
  // flagged the jab as "arrives and freezes" — no rebound after peak
  // extension. `Ease.easeOutBack` on the recoil key makes the transition
  // INTO it overshoot past (10,-44) then settle back, the same
  // anticipation/overshoot pattern already used on the wheel's OUT-point
  // keys elsewhere in this file — a real spring-back instead of a dead stop.
  DanceIkTargetKey(16, x: 33, y: -50, tension: 1), // JAB past the far line
  DanceIkTargetKey(17, x: 32, y: -48, tension: 1), // hold
  // R1: a y-only lift (-44 -> -58, keeping x on the SAME side as hand.R's
  // simultaneous "loads" key) was tried and panel-rejected (3 reviewers,
  // avg 4.3/10): raising y moved this hand further INTO the torso
  // silhouette rather than out past it, since both hands stayed on the
  // same x-side — a screen-space occlusion problem, not a raw-distance
  // one. Fixed instead by swapping this key to hand.L's OWN (negative)
  // side: x 10 -> -20, back near chamber's -26 rather than mid-crossover.
  // Now this hand and hand.R's "loads" key (x +10, still on R's own side)
  // sit on OPPOSITE sides of the tie at this beat instead of stacked on
  // one side. Magnitude (|x|+|y| basis) stays well under the JAB key's
  // already-validated near-max reachRatio (~0.97 at x33,y-50), so this
  // doesn't reopen the reach-ceiling issue noted above.
  // R2 (task #45): added `Ease.easeOutBack` on top of the opposite-side fix
  // above so the transition into this recoil overshoots past it and
  // settles back, instead of arriving dead — the two fixes are orthogonal
  // (one is WHERE the key sits, the other is HOW the arm arrives there).
  DanceIkTargetKey(
    19,
    x: -20,
    y: -44,
    tension: 0.4,
    ease: Ease.easeOutBack,
  ), // recoil through guard, opposite side + spring-back overshoot
  DanceIkTargetKey(20, x: -26, y: -10, tension: 0.8), // chamber at the hip
  DanceIkTargetKey(22, x: -27, y: -12, tension: 0.5),
  DanceIkTargetKey(23, x: -10, y: -34, tension: 0.4), // loads
  DanceIkTargetKey(24, x: 33, y: -50, tension: 1), // JAB
  DanceIkTargetKey(25, x: 32, y: -48, tension: 1),
  DanceIkTargetKey(
    27,
    x: -20,
    y: -44,
    tension: 0.4,
    ease: Ease.easeOutBack,
  ), // recoil through guard, opposite side + spring-back overshoot
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
  DanceIkTargetKey(0, x: 42, y: -31, tension: 0.6), // narrower reach, held
  DanceIkTargetKey(2, x: 33, y: -20, tension: 0.2),
  DanceIkTargetKey(4, x: 22, y: -10, tension: 0.6), // wide reach, held
  DanceIkTargetKey(6, x: 33, y: -20, tension: 0.2),
  DanceIkTargetKey(8, x: 42, y: -31, tension: 0.6), // narrower again
  DanceIkTargetKey(10, x: 33, y: -20, tension: 0.2),
  DanceIkTargetKey(12, x: 22, y: -10, tension: 0.6), // wide again
  DanceIkTargetKey(14, x: 33, y: -20, tension: 0.2), // into bar 2
  // Bar 2: chambered at the own-side hip while the left jabs, then the
  // answering cross jab.
  DanceIkTargetKey(16, x: 26, y: -10, tension: 0.8), // chamber at the hip
  DanceIkTargetKey(18, x: 27, y: -12, tension: 0.5),
  DanceIkTargetKey(19, x: 10, y: -34, tension: 0.4), // loads
  DanceIkTargetKey(20, x: -33, y: -50, tension: 1), // JAB past the far line
  DanceIkTargetKey(21, x: -32, y: -48, tension: 1), // hold
  // Mirrors hand.L's opposite-side recoil fix above (see that comment):
  // swapped to hand.R's OWN (positive) side so it doesn't stack with
  // hand.L's simultaneous "loads" key (also on L's own, negative side).
  // Also carries the same `Ease.easeOutBack` spring-back overshoot.
  DanceIkTargetKey(
    23,
    x: 20,
    y: -44,
    tension: 0.4,
    ease: Ease.easeOutBack,
  ), // recoil through guard, opposite side + spring-back overshoot
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
// Head attitude — the ornament-port vocabulary in azonto's MIME idiom:
// in the wheel bars the skull leans gently with each grip turn and
// settles with a ~40% echo; behind each JAB it gathers, SNAPS with the
// hit, and carries the echo through the hold — the head sells the mime
// instead of riding level over it. Azonto previously had no authored
// head keys.
const _azontoHeadKeys = [
  DanceJointKey(0, rotation: 0.05), // rides the wide grip
  DanceJointKey(3, rotation: 0.02), // echo settle
  DanceJointKey(4, rotation: -0.05), // answers the narrow grip
  DanceJointKey(7, rotation: -0.02),
  DanceJointKey(8, rotation: 0.05),
  DanceJointKey(11, rotation: 0.02),
  DanceJointKey(12, rotation: -0.05),
  DanceJointKey(15, rotation: -0.06), // gathers behind the jab
  DanceJointKey(16, rotation: 0.1), // SNAPS with the jab
  DanceJointKey(18, rotation: 0.04), // echo through the hold
  DanceJointKey(20, rotation: -0.03), // relaxes through the chamber
  DanceJointKey(23, rotation: -0.06), // loads again
  DanceJointKey(24, rotation: 0.1), // second JAB
  DanceJointKey(26, rotation: 0.04), // echo
  DanceJointKey(28, rotation: -0.03),
  DanceJointKey(30),
  DanceJointKey(32, rotation: 0.05), // == frame 0
];

const _azontoHandLKeys = [
  DanceJointKey(0, rotation: 0.28), // wide grip
  DanceJointKey(1, rotation: 0.36), // flick past the grip (ornament port)
  DanceJointKey(4, rotation: -0.28), // narrow grip — wheel turns
  DanceJointKey(5, rotation: -0.36), // flick
  DanceJointKey(8, rotation: 0.28),
  DanceJointKey(9, rotation: 0.36), // flick
  DanceJointKey(12, rotation: -0.28),
  DanceJointKey(13, rotation: -0.34), // flick, softer into the jab load
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
  DanceJointKey(1, rotation: -0.36), // flick past the grip (ornament port)
  DanceJointKey(4, rotation: 0.28), // wide grip — wheel turns
  DanceJointKey(5, rotation: 0.36), // flick
  DanceJointKey(8, rotation: -0.28),
  DanceJointKey(9, rotation: -0.36), // flick
  DanceJointKey(12, rotation: 0.28),
  DanceJointKey(13, rotation: 0.34), // flick, softer into the jab load
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
// R follow-up (panel post-PR#54, task #45 part 2): the panel wanted the
// punch to read as thrown "from the shoulder," not just a wrist relocating —
// azonto never had a clavicle rotation channel at all (unlike shaku/sekem/
// zanku, which all drive a shoulder roll timed to their own accents), so the
// jab had no shoulder-girdle motion behind it. Added one: the JABBING side's
// clavicle rolls forward through the strike and relaxes back on the chamber
// beat, mirrored for the opposite side. Magnitude matched to zanku's own
// clavicle-roll channel (`_zankuClavicleRKeys`/`LKeys`) — that one already
// reads clearly, per panel feedback, so this channel should read at the same
// magnitude without needing a bigger number.
// Bar 1 (the wheel-mime) is left neutral — not in scope for this pass.
//
// CAVEAT, probe-verified post-merge: the channel genuinely solves (probed
// `frame.world[CatBones.clavicleL/R]`, `atan2(b,a)`) — a real ~13deg swing
// at frame 16, comparable to zanku's own working channel — but a direct
// same-frame before/after render crop is pixel-near-identical; the
// silhouette is dominated by the tightly crossed arms, and a shoulder roll
// this size doesn't read against that. This is NOT the "solved rotation
// doesn't render" mesh bug from PR #51 (the data->render path itself is
// fine, confirmed by probe) — it's that a subtle secondary motion can't
// compete with the crossed-arms silhouette itself. Real fix is the elbow-
// abduction/pole-vector work (task #46), not a bigger shoulder-roll number.
const _azontoClavicleLKeys = [
  DanceJointKey(0),
  DanceJointKey(14), // into bar 2
  DanceJointKey(16, rotation: 0.22), // L JABS — shoulder drives forward
  DanceJointKey(17, rotation: 0.18), // hold
  DanceJointKey(19, rotation: 0.05), // recoil
  DanceJointKey(20, rotation: -0.05), // L chambers while R jabs
  DanceJointKey(23, rotation: 0.02),
  DanceJointKey(24, rotation: 0.22), // L JABS again
  DanceJointKey(25, rotation: 0.18),
  DanceJointKey(27, rotation: 0.05),
  DanceJointKey(28, rotation: -0.05), // L chambers
  DanceJointKey(32), // == frame 0
];
const _azontoClavicleRKeys = [
  DanceJointKey(0),
  DanceJointKey(14),
  DanceJointKey(16, rotation: -0.05), // R chambers while L jabs
  DanceJointKey(19, rotation: 0.02),
  DanceJointKey(20, rotation: 0.22), // R JABS — shoulder drives forward
  DanceJointKey(21, rotation: 0.18), // hold
  DanceJointKey(23, rotation: 0.05), // recoil
  DanceJointKey(24, rotation: -0.05), // R chambers
  DanceJointKey(27, rotation: 0.02),
  DanceJointKey(28, rotation: 0.22), // R JABS again
  DanceJointKey(29, rotation: 0.18),
  DanceJointKey(31, rotation: 0.05),
  DanceJointKey(32), // == frame 0
];
const _azontoFootLTargetKeys = [
  DanceIkTargetKey(0, x: -56, y: 103),
  DanceIkTargetKey(2, x: -56, y: 103), // planted through left support
  DanceIkTargetKey(4, x: -56, y: 103),
  // DOUBLE-TIME LEGS (owner-approved on shaku): each free window is a
  // touch-lift-touch step at ~13-unit clearance — azonto's step-touch
  // idiom at per-beat rate, under the untouched mime/jab upper body.
  DanceIkTargetKey(5, x: -52, y: 83), // high pickup
  DanceIkTargetKey(6, x: -46, y: 101), // TOUCH
  DanceIkTargetKey(7, x: -50, y: 85), // lift
  DanceIkTargetKey(8, x: -48, y: 102), // steps onto the new support
  DanceIkTargetKey(10, x: -48, y: 102), // planted through left support
  DanceIkTargetKey(12, x: -48, y: 102),
  DanceIkTargetKey(13, x: -53, y: 83), // high pickup
  DanceIkTargetKey(14, x: -62, y: 101), // TOUCH out
  DanceIkTargetKey(15, x: -55, y: 85), // lift
  DanceIkTargetKey(16, x: -58, y: 103),
  DanceIkTargetKey(18, x: -58, y: 103), // planted through left support
  DanceIkTargetKey(20, x: -58, y: 103),
  DanceIkTargetKey(21, x: -54, y: 83), // high pickup
  DanceIkTargetKey(22, x: -50, y: 101), // TOUCH
  DanceIkTargetKey(23, x: -58, y: 85), // lift
  DanceIkTargetKey(24, x: -62, y: 103),
  DanceIkTargetKey(26, x: -62, y: 103), // planted through left support
  DanceIkTargetKey(28, x: -62, y: 103),
  DanceIkTargetKey(29, x: -56, y: 83), // high pickup
  DanceIkTargetKey(30, x: -50, y: 101), // TOUCH
  DanceIkTargetKey(31, x: -54, y: 85), // lift home
  DanceIkTargetKey(32, x: -56, y: 103),
];
const _azontoFootRTargetKeys = [
  DanceIkTargetKey(0, x: 54, y: 102),
  DanceIkTargetKey(1, x: 52, y: 83), // high pickup (double-time legs)
  DanceIkTargetKey(2, x: 46, y: 101), // TOUCH
  DanceIkTargetKey(3, x: 52, y: 85), // lift
  DanceIkTargetKey(4, x: 54, y: 103),
  DanceIkTargetKey(6, x: 54, y: 103), // planted through right support
  DanceIkTargetKey(8, x: 54, y: 103),
  DanceIkTargetKey(9, x: 51, y: 83), // high pickup
  DanceIkTargetKey(10, x: 44, y: 101), // TOUCH
  DanceIkTargetKey(11, x: 50, y: 85), // lift
  DanceIkTargetKey(12, x: 48, y: 102),
  DanceIkTargetKey(14, x: 48, y: 102), // planted through right support
  DanceIkTargetKey(16, x: 48, y: 102),
  DanceIkTargetKey(17, x: 54, y: 83), // high pickup
  DanceIkTargetKey(18, x: 64, y: 101), // TOUCH out
  DanceIkTargetKey(19, x: 57, y: 85), // lift
  DanceIkTargetKey(20, x: 60, y: 103),
  DanceIkTargetKey(22, x: 60, y: 103), // planted through right support
  DanceIkTargetKey(24, x: 60, y: 103),
  DanceIkTargetKey(25, x: 56, y: 83), // high pickup
  DanceIkTargetKey(26, x: 48, y: 101), // TOUCH
  DanceIkTargetKey(27, x: 54, y: 85), // lift
  DanceIkTargetKey(28, x: 52, y: 102),
  DanceIkTargetKey(30, x: 52, y: 102), // planted through right support
  DanceIkTargetKey(32, x: 54, y: 102),
];
// Legwork-panel round: the pocket measured range 30 — half of shaku's —
// "the trunk sits too upright for the busy-feet-under-laid-back-trunk
// layering to register". The keys' own step-synced rootDy bounce is
// amplified 1.8x around its mean (an added sine layer measurably
// CANCELLED against this pattern instead of deepening it — the bounce
// is authored to the step timing, so the depth belongs in the keys).
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
    rootDy: 24.4,
    pelvisRotation: -0.1008,
    chestRotation: 0.0864,
    chestScaleY: 0.92,
    chestScaleX: 1.06,
  ),
  DanceBodyKey(
    2,
    rootDx: 0,
    rootDy: 0.5,
    pelvisRotation: 0.0108,
    chestRotation: -0.0108,
    chestScaleY: 0.89,
    chestScaleX: 1.08,
  ),
  DanceBodyKey(
    4,
    rootDx: 7.776,
    rootDy: 43.6,
    pelvisRotation: 0.1224,
    chestRotation: -0.108,
    chestScaleY: 0.86,
    chestScaleX: 1.1,
  ),
  DanceBodyKey(
    6,
    rootDx: -0.432,
    rootDy: 5.3,
    pelvisRotation: 0.0072,
    chestRotation: -0.0072,
    chestScaleY: 0.88,
    chestScaleX: 1.085,
  ),
  DanceBodyKey(
    8,
    rootDx: -8.64,
    rootDy: 29.2,
    pelvisRotation: -0.108,
    chestRotation: 0.0936,
    chestScaleY: 0.9,
    chestScaleX: 1.07,
  ),
  DanceBodyKey(
    10,
    rootDx: 0,
    rootDy: 0.5,
    pelvisRotation: 0.0072,
    chestRotation: -0.0072,
    chestScaleY: 0.88,
    chestScaleX: 1.085,
  ),
  DanceBodyKey(
    12,
    rootDx: 8.64,
    rootDy: 43.6,
    pelvisRotation: 0.1224,
    chestRotation: -0.108,
    chestScaleY: 0.86,
    chestScaleX: 1.1,
  ),
  DanceBodyKey(
    14,
    rootDx: 3.195,
    rootDy: 5.3,
    pelvisRotation: 0.1412,
    chestRotation: -0.124,
    chestScaleY: 0.905,
    chestScaleX: 1.07,
  ),
  // R follow-up (azonto jab root-motion drift): pelvisRotation/rootDx at
  // frames 16/18/20 damped ~60% — see `_azontoGrooveCalm`'s doc comment for
  // the full root-cause probe. This track's own contribution to the torso-
  // anchor drift was smaller than the shared groove's (~5 of ~27 world
  // units, measured by ablation), but every bit matters since the jab's
  // local target is already at its reach-limit ceiling with no room left to
  // widen further. chestRotation/chestScaleX/Y are untouched — a bone's own
  // rotation doesn't move its own world origin, so they don't affect the
  // anchor drift and stay at their full authored value for the chest
  // counter-rotation look.
  DanceBodyKey(
    16,
    rootDx: -0.9,
    rootDy: 29.2,
    pelvisRotation: 0.064,
    chestRotation: -0.14,
    chestScaleY: 0.95,
    chestScaleX: 1.04,
  ),
  DanceBodyKey(
    18,
    rootDx: -0.9,
    rootDy: 0.5,
    pelvisRotation: 0.024,
    chestRotation: -0.05,
    chestScaleY: 1.02,
    chestScaleX: 0.99,
  ),
  DanceBodyKey(
    20,
    rootDx: 0.9,
    rootDy: 43.6,
    pelvisRotation: -0.072,
    chestRotation: 0.16,
    chestScaleY: 0.95,
    chestScaleX: 1.04,
  ),
  DanceBodyKey(
    22,
    rootDx: 2.25,
    rootDy: 5.3,
    pelvisRotation: -0.07,
    chestRotation: 0.06,
    chestScaleY: 1.02,
    chestScaleX: 0.99,
  ),
  // Same jab-window anchor-drift damping as frames 16/18/20 above.
  DanceBodyKey(
    24,
    rootDx: -0.99,
    rootDy: 34,
    pelvisRotation: 0.072,
    chestRotation: -0.16,
    chestScaleY: 0.95,
    chestScaleX: 1.04,
  ),
  DanceBodyKey(
    26,
    rootDx: -2.48,
    rootDy: 0.5,
    pelvisRotation: 0.06,
    chestRotation: -0.05,
    chestScaleY: 1.02,
    chestScaleX: 0.99,
  ),
  DanceBodyKey(
    28,
    rootDx: 0.99,
    rootDy: 48.4,
    pelvisRotation: -0.076,
    chestRotation: 0.17,
    chestScaleY: 0.95,
    chestScaleX: 1.04,
  ),
  DanceBodyKey(
    30,
    rootDx: 2.02,
    rootDy: 5.3,
    pelvisRotation: -0.07,
    chestRotation: 0.06,
    chestScaleY: 1.02,
    chestScaleX: 0.99,
  ),
  DanceBodyKey(
    32,
    rootDx: -2.02,
    rootDy: 24.4,
    pelvisRotation: -0.14,
    chestRotation: 0.12,
    chestScaleY: 0.92,
    chestScaleX: 1.06,
  ),
];
