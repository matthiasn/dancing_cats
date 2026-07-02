# Prior-artwork motion targets (2026-07-01)

This note converts the latest artwork review into concrete rig and animation
targets. It complements the runtime research note: the runtime tells us how to
solve motion; this note defines what the solved body should look like.

## Silhouette target

- Athletic heroic dancer, not bodybuilder: broad shoulder line, active chest,
  tapered waist, strong upper arms, narrower wrists.
- The jacket reads as cloth over a body: shoulder/chest/pelvis planes should
  shift against each other instead of one hard torso shell.
- Arms need a shoulder-to-bicep-to-forearm hierarchy. A uniform tube reads as
  sausage; a hard polygon reads as broken armor.
- Secondary parts should follow the body. Ears and tail should lag head/hips in
  small waves, not pin to the skull/pelvis and not steal the pose.

## Rig implications

1. Raised arms require shoulder deformation, not just arm rotation.
   The clavicle/shoulder cap should lift and rotate with the arm, while the
   jacket side stretches into the armpit. The torso should not expose a gap or
   stay as a rigid plate under a raised sleeve.

2. Sleeves should be continuous skinned volumes.
   Bicep mass must carry most of the upper-arm width, the elbow should compress
   as a soft inner crease, and the forearm should taper to the cuff. Avoid
   visible elbow "bones" or triangular hinges.

3. Crossed and raised arms need phase-aware layering.
   When arms cross the chest or pass above shoulder height, hands/cuffs/forearms
   may need draw-order changes or torso masks so the silhouette reads as anatomy,
   not overlapping cutouts.

4. Torso motion should be polycentric.
   Pelvis leads, chest follows, shoulders answer, hands arrive last. Good poses
   make the suit bend around the groove; bad poses freeze the suit into a hard
   shell while limbs swing around it.

5. Tail and ears are follow-through, not decoration.
   The tail should build amplitude from base to tip with phase lag. Ears should
   show a small delayed flop plus squash/stretch, bounded so they do not become
   the loudest moving part.

## Immediate engineering targets

- Add validator coverage for locked-straight limbs, over-folded limbs, and
  hand bend-side flips.
- Keep catalogue ears above a minimum motion range and below a dominance range.
- Keep catalogue tails as progressive waves: mid-tail range > root range, tip
  range > mid-tail range.
- Next visible body pass: raised-arm shoulder deformation. Measure and inspect
  Buga/Azonto first because they expose arms above or away from the torso.
- After the shoulder pass, research popular rigging/animation projects again
  with a narrower question: how they implement shoulder/clavicle deformation,
  pose-space corrective shapes, and draw-order/masking for raised or crossed
  arms.

## Rejection signals

- Arm appears detached from the jacket when raised.
- Shoulder stays level while arm reaches high.
- Sleeve width is nearly constant from shoulder to wrist.
- Elbow reads as a hard joint, bone, or triangle.
- Torso looks like a single hard shell while hips and arms move.
- Tail/ears are either frozen or more visually active than the dance phrase.
