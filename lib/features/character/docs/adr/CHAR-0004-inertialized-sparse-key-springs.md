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
- **Motion:** shaku crest 2.94 → 2.99, elbow angular velocity 0.56 → 0.43
  (smoother), dwell ~flat — equivalent-or-better motion from half the keys. The
  crest is seam-limited (the generator pull straddles the loop point); the
  larger crest win is expected on Free/Sudden moves as the mechanism rolls out.
- **Determinism:** the tables are a pure function of (keys, duration, ωₙ, ζ),
  cached with the clip (mirrors `_LocoTable`), so renders stay reproducible; the
  purity test (`character_scene_test`) covers re-scrub / reverse / seam.

## Follow-ups

Roll the inertializer to the remaining clips (zanku/azonto/buga/sekem — the
C1-smooth channel-type assertion becomes an inertialized-channel or
velocity-continuity check per clip); revisit the seam-vs-snap ωₙ ceiling if a
move needs a sharper accent adjacent to the loop point.
