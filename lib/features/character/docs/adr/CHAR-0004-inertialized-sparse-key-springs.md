# ADR CHAR-0004: Inertialized sparse-key arm springs

## Status

**Accepted — shaku pilot landed.** Phase 2 of the physics-driven arm-transition
plan. Phase 1 (`feat/arm-spring-damper`, #119) generalized the dormant
overshoot-settle / follow-through seeds into one closed-form second-order spring
(`danceSpring`, `dampedTransitionResponse`) firing as a per-beat *garnish* on
top of the existing dense hand-keys. This ADR covers the mechanism that makes
the spring the *interpolator itself*, so the arms can be authored from sparse
hit-poses.

## Context

The graded goal is a system that models realistic dance "without too much
hand-crafting keyframes." The dense hit-and-park authoring shaku used (17 hand
keys per side: a hit, a dead-hold duplicate, and a `tension:1` snap-hint every
beat) was the animator hand-crafting the *transition shape* the Catmull-Rom
interpolator wouldn't give — exactly the hand-keying the goal wants gone. A
plain smooth spline can't hold, snap late, or overshoot; the dead-holds and
tension hints existed only to fake those.

## Decision

Add `InertializedIkTargetChannel` (`clip.dart`): the interpolation between
sparse authored hit-poses IS a periodic second-order spring. Its constructor
solves, once, a **periodic boundary-value least-squares** (Kass–Anderson
"wiggly splines"): discretize `q̈ + 2ζωₙq̇ + ωₙ²(q − a) = 0` on an N-sample loop,
hold the drive `a` at the most-recent hit, and pin `q` to the authored value at
each key sample. The solution holds each hit (the drive's equilibrium), then
snaps into the next landing exactly on its beat — hit-and-park by construction,
C¹-smooth (Catmull-Rom table read, so the two-bone IK elbow stays smooth), and
periodic so the loop seam closes.

- **Why least-squares, not an exact ODE BVP:** solving the ODE exactly at free
  nodes is ill-posed — a held drive over a long span can't reach a far pin
  without a divergent transient (observed as a ~3e7 blow-up). Least-squares
  fits it instead and never blows up.
- **(ωₙ, ζ) from `DanceDynamics`** via `danceSpring` (Time → snap, Flow →
  overshoot), softened by `_kInertializerOmegaScale = 0.9`: the inertializer's
  snap is inherently sharper than the Phase-1 garnish, and an extreme hit next
  to the loop seam (shaku's generator pull) recovers fast enough to tick the
  seam at full ωₙ.
- **Opt-in per track** (`DanceIkTargetTrack.inertialize`), compiled in
  `assembleMoveClip`, which already has the move's duration and dynamics.
- **No double-stacking:** the Phase-1 hand follow-through
  (`_handTargetFollowThrough`) and the Effort time-warp (`dance_dynamics_warp`)
  both skip an inertialized channel — it already owns the hand's transition
  timing.

## Consequences

- **shaku hands: 17 keys → 8** (one hit-pose per beat; no dead-holds, no
  tension hints). The hold → snap → settle is generated.
- **Exact-frame safe:** authored hits are equality-pinned and read back exactly
  at their frames, so the category-A/B `cat_in_suit_test` bounds hold with no
  test edits; the elbow gate, smoothness, and loop-seam gates stay green.
- **Motion (pilot, pre-tuning):** shaku crest 2.94 → 2.99, elbow angular
  velocity 0.56 → 0.43 (smoother), from half the keys — but see the tuning pass
  below: at the pilot's default ζ the motion read as an over-damped GLIDE.
- **Determinism:** the tables are a pure function of (keys, duration, ωₙ, ζ),
  cached with the clip (mirrors `_LocoTable`), so renders stay reproducible; the
  purity test (`character_scene_test`) covers re-scrub / reverse / seam.

## Panel tuning pass (punch)

A 5-lens expert panel (Afrobeats coach, character animator, mocap/biomechanics,
**physicist**, technical) read the merged pilot as an **over-damped glide**
(unanimous, avg 5.4/10): crest 2.99, floor 12%, dwell 40% — the hand never
rested. The physicist diagnosed it precisely: ζ≈1.2's slow over-damped root has
a settle time near a whole beat, so the transient never completes before the
next hit.

**Fix (in `dance_move_compiler.dart`):** the inertializer runs STIFFER and
nearer-critical than the raw [danceSpring] garnish tuning — `ωₙ × 1.4`
(`_kInertializerOmegaScale`) and ζ capped at `1.02` (`_kInertializerMaxZeta`,
removing the slow creep; Flow can still dial a *Free* move under-damped for
overshoot, it just can't push the inertializer over-damped into a glide). Result:
shaku **crest 2.99 → 4.41** (into the punchy 4–8 band), floor 12% → 6%, dwell
40% → 19%, elbow angular velocity still ~0.4 (the target-space spring keeps the
whip decoupled from the elbow). ωₙ is held just under the acceleration gate
(`velocitySpikes` minAcceleration 32) — that gate uses AND logic (accel *and*
ratio), so it already tolerates a high speed-RATIO hit-and-park as long as the
acceleration stays bounded; no need to relax it.

**Loop-seam gate re-scope.** The stiff spring lands the downbeat accent — and
the generator-pull recovery — right on the loop seam (frame 0). That is a large
but **C1-continuous** velocity change (verified by resolution-doubling: the
finite-difference seam jump SHRINKS 2371 → 1537 → 957 as the sample interval
halves; a true discontinuity's would stay constant), not a tick. The pure-
magnitude seam gate couldn't tell the two apart, so `loopSeamVelocityJumps`
gained an optional `maxInLoopJumpRatio` (bounds the seam to 2.5× the worst
in-loop adjacent jump — a real tick runs 3–9× and is anomalous; a climax accent
~1.5–2×), backed by an explicit **C1-continuity test** (the jump must shrink
with finer sampling). Smooth clips keep the legacy magnitude behaviour.

## The ceiling to 8/10 is now RIG/MESH, not the spring

With the glide fixed the panel rose to ~6.3, and every remaining blocker is
rig/mesh or amplitude, not the transition physics: the upper-arm ribbon balloons
into a deltoid blob at deep flexion; the paw hides behind the tie/jacket at the
tucked poses; the open-hits don't clear the torso far enough (IK-anchor reach
ceiling); the round mitt can't show a wrist/forearm roll; the shoulder girdle
doesn't couple to the leg weight-shift. These are the same ceilings prior panels
identified (the shoulder-mesh gap) — the inertializer proved the *capability*
(punchy hit-and-park from sparse keys), and the path to 8 is now rig work.

## Rig pass (in progress)

The first rig lever landed: a **raise-dependent deltoid clamp**
(`LimbRibbonSpec.clampProximalOnRaise`, resolved in `CharacterRenderer`). The
arm ribbon's proximal (deltoid) half-widths narrow in proportion to how far the
upper arm is from hanging straight down — full at rest (the armhole gap-proofing
dome is preserved for idle/walk), narrowed when raised/across-chest where the
wide dome was exposed as a bulbous "shoulder blob". The technical lens's #1
blocker (blob in ~⅓ of frames) is cleared; arm-rig cleanliness scored 6 → 8.

## Follow-ups

Roll the inertializer to the remaining clips (zanku/azonto/buga/sekem — the
C1-smooth channel-type assertion becomes an inertialized-channel or
velocity-continuity check per clip); remaining rig levers (open-paw drawable,
shoulder-girdle → weight-shift coupling, arm reach for a wider silhouette
beyond the reach cap).
