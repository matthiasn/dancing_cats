# ADR CHAR-0003: Laban-Effort dynamics via a split-clock time warp

## Status

**Accepted — plumbing landed (2026-07-05), tuning pending.** The composition
rule, the model-layer warp primitive, and the full wiring from `DanceStage`
through the stepper into the single live/offline paint path
(`danceCharacterPainter`) shipped across three commits on
`feat/effort-dynamics-split-clock`. Every real value in the chain — the six
catalog moves' `AfrobeatsMove.dynamics`, the per-lane personality profiles, the
section-energy gain, and the warp's own live gain — ships **neutral/zero**, so
this PR is provably a no-op: `frameAt`/`painter.clip`/`painter.ensembleClips`
resolve to the exact same `Clip` instances as before, pinned by an
`identical(...)` regression test. A follow-up PR populates the D4 Effort table,
lane personalities, and section-energy gain, adds the kinematic gate tests, and
runs the 60fps GIF motion panel to tune the constants.

## Context

[CHAR-0001](CHAR-0001-dance-choreography-encoding-and-move-library.md)'s D1
built `DanceDynamics` (three signed Weight/Time/Flow dials, `-1..1`) and
`dynamicsCurve()` (the EMOTE-style anticipation/overshoot/snap curve), fully
unit-tested — but **dormant**. Its own "Implementation outcome" section
documents why: the six shipped moves compile their joint tracks with
`smooth: true` (periodic Catmull-Rom), and that path **ignores per-key
`easeFn`** entirely (`clip.dart`'s `KeyframeChannel.sample`, both the linear and
cyclic branches) — the exact mechanism `dynamicsCurve` was built to drive. The
shipped moves get their anticipation/overshoot from a simpler lever instead
(`Ease.easeOutBack` on non-smooth IK-target keyframes), and the render→panel
grind never needed the Effort layer to reach 9/10.

Separately, the trio dances *different* catalog moves per song section
(`choreoTrioForSection`/`choreoTrioByLevel` in `dance_performance.dart`), which
reads as real ensemble variety — but any two cats dancing the **same** move at
the **same** moment are pixel-identical clones: three static `Clip` instances,
sampled at the identical `timeSeconds`, with zero per-member time offset by
deliberate design (`CharacterPainter._ensembleMicroTimingOffset` returns `0` for
a trio specifically because sub-frame lead/trail offsets cross support-foot
handoffs at different moments and pop the flanking dancers' feet).

What changed to make wiring the layer worth it now: motion panels moved from
judging a 32-frame contact-sheet still to **60fps animated GIFs**. The old
constraint — "the panel samples land on the keyframe grid, so sub-frame timing
reshaping is invisible to it" — no longer holds. Timing texture (snap vs.
sustain, an anticipation dip's rhythm, an overshoot's settle) is exactly what a
60fps clip makes legible, which is precisely the register `DanceDynamics`
operates in.

**The owner's ask**, verbatim in shape: give the trio (a) distinct per-cat
Effort *personalities* and (b) a shared Effort response to the song's
section-level *energy*, composed together, so that:

- the same catalog move reads differently on lead vs. backup-left vs.
  backup-right (cheap variety — CHAR-0001 finding 9, PERFORM/Samadani: overlay
  character in Effort space rather than hand-keying variants), and
- the whole ensemble's dynamics breathe with the track's energy arc instead of
  only changing via the existing discrete move-selection thresholds.

## Decision

### The composition rule

```
effective = clamp(moveBase + clampMag(catProfile + sectionEnergy, budget))
```

(`lib/features/character/model/dance_dynamics.dart`, `effectiveDanceDynamics`.)
Cat-profile and section-energy offsets are summed first and capped to
`±kDanceDynamicsModulationBudget` (`0.35`) **per axis** — additive, not
multiplicative, so the trio's personality spread survives quiet sections
instead of every cat scaling toward clone-identical neutral exactly when
clone-ness would be most visible (a quiet-section multiplier would do the
opposite of the ask). The move's authored base is added *after* the cap, and
the sum clamps to the valid `-1..1` range. With the budget sized under every
catalog move's defining-axis magnitude (the D4 table authors moves at
`|axis| >= ~0.4`), **no in-range personality/energy composition can invert a
move's Effort character** — a Bound move can't read Free on any cat at any
energy level. This is pinned by an adversarial test that tries every sign
combination of cat + section against every defining-axis case.

### Mechanism: a beat-local time warp, split by bone group

Two designs were fully specified and compared (see Alternatives below); the
owner chose the **split-clock time warp**. The core idea: derive, per cat per
moment, a *decorated* `Clip` whose **upper-body channels only** are wrapped in
a per-lane phase warp. Support-critical bones — root, hips, legs, feet — are
never wrapped; they keep sampling the shared clock exactly as today. This
directly honors the hard constraint above (`_ensembleMicroTimingOffset`): the
trio's feet stay bit-identical across lanes by construction, because the warp
literally cannot reach the bones a foot-pop would come from.

**The warp is a deviation from neutral, not the raw Effort curve.**
`dynamicsCurve(DanceDynamics.neutral)` returns `easeInOut`, **not the
identity** — using it directly as a time map would reshape every beat even at
neutral dynamics. So the warp is defined as

```
warp(u) = u + gain · (dynamicsCurve(d)(u) − easeInOut(u))
```

for `u` = phase within one beat (`dance_dynamics.dart`, `dynamicsTimeWarp`).
This form has the two properties the mechanism depends on:

- **neutral is the exact identity** (`warp(u) == u` to the bit, verified by
  test) — the layer is opt-in and regression-free by construction, not by
  convention;
- **endpoints are exact** (`warp(0) == 0`, `warp(1) == 1`) — every beat
  boundary maps to itself, so warped dancers **re-sync on every count**
  regardless of their dynamics. The catalog moves author every accent on the
  8-beats-per-32-frame-loop grid (`kDanceBeatsPerPhraseLoop`), so this means
  the warp reshapes *travel between* accents without ever moving an accent
  itself off its authored beat.

Between the endpoints: a Strong `weight` dips the warp *below* the beat start
(a brief retrograde wind-up sampling into the previous beat — the anticipation
read), a Sudden `time` makes the warp lag behind the shared clock through the
approach then catch up steeply (the snap read), and a Free `flow` runs the warp
*past* the beat end before returning (the follow-through/overshoot read). Each
factor is attenuated by its own gain constant before entering the curve
(`kTimeWarpWeightGain`/`kTimeWarpTimeGain`/`kTimeWarpFlowGain`) — Weight-as-
retrograde reads far stronger in the warp domain than Time-as-skew, so it ships
with the lowest multiplier.

**Implementation shape**, all model-layer, zero threading through the painter/
scene/evaluator:

- `PhaseWarpedJointChannel` / `PhaseWarpedIkTargetChannel` (`clip.dart`) — thin
  decorators, the same shape as the existing `SoftenedIkTargetChannel`, that
  sample an inner channel through a warped phase instead of the raw one.
- `Clip.dynamics` — the move's own authored Effort character, lane-invariant,
  stamped on by `assembleMoveClip` from `descriptor.move.dynamics` and lerped
  by `blendedClip` alongside its other scalar fields (`danceHeadBobScale`
  etc.). This has to live on the `Clip`, not a name-keyed lookup table: a
  transition's blended clip is named `'shaku->zanku'`, so a table would miss
  every blend.
- `kDanceUpperBodyWarpBoneIds` (next to `CatBones` in `cat_in_suit_rig.dart`) —
  the explicit allowlist: torso/chest/collar/tie/neck/head/ears/clavicles/
  shoulders/arms/hands/cuffs/tail. Hips, every `leg*`/`foot*`/`shoe*`/
  `toeFlex*` bone, and the root channel are deliberately absent, with a doc
  comment stating the invariant they protect.
- `upperBodyDynamicsWarpedClip` (`dance_dynamics_warp.dart`) — the clip
  decorator: wraps only the allowlisted bones' channels and hand IK targets
  (never foot targets), preserves every other `Clip` field verbatim including
  `name` (deliberately — `CharacterScene`'s `_locoTables`/`_spineLevelPlans`
  memos are name-keyed, so keeping the name intact matters more than a
  cosmetic rename), and wraps the anticipation dip / overshoot across the
  cyclic loop seam. Returns the **same `clip` instance** — `identical`, not
  merely equal — when dynamics are neutral, the gain is zero, or the clip
  isn't a loop; this is what makes the whole mechanism a provable no-op before
  the tuning commit sets a nonzero gain.
- `DanceStage.dynamics` (`dance_performance.dart`) — a `List<DanceDynamics>`
  index-parallel to `ensemble`, composed in `stageAt` from each lane's
  `trio.ensemble[i].dynamics` (move base), `kDanceLaneDynamicsProfiles[i]` (cat
  profile), and `sectionEnergyDynamics(level)` (section energy, a continuous
  function of the existing `DanceSection.level`, replacing nothing — the level
  still drives `choreoTrioByLevel`'s discrete move selection too).
- Stepper smoothing (`dance_playback_stepper.dart`): `_heldStage` carries the
  *outgoing* trio's own dynamics during a beat-quantized hold (it hasn't
  arrived at the new section yet); `_blendStage` lerps per lane by the same
  weight as the pose blend. Neither of those fires on a **section-level-only**
  change with no move swap (`_stageSignature` is clip-name-keyed), so a small
  stateful ease (`_easedDynamicsStage`, `kDanceDynamicsEaseSeconds = 0.15`) sits
  in the stepper — the sanctioned home for history-dependent smoothing (mouths,
  camera) — and catches that one remaining discontinuity. Offline exporters
  inherit its determinism via the stepper's existing preroll convention.
- `danceCharacterPainter` (`dance_stage_view.dart`) is the single call site
  both the live app and every offline renderer go through, so it's the only
  place that needs to build a warped clip at all: each member clip passes
  through `upperBodyDynamicsWarpedClip`, memoized per `(clip instance,
  dynamics value)` via an `Expando` so steady-state playback builds each
  warped clip once. `CharacterPainter`, `CharacterScene`, and `ClipEvaluator`
  are **untouched** — every one of the 13 pose-modifier passes, the rigid-head
  treatment, secondary-follow's finite differences, and hand-IK sampling
  automatically see a consistent warped upper body, because the warp lives
  inside the channels a warped `Clip` carries, not in a parameter threaded
  through the evaluation call chain.

## Alternatives considered

**Pose-space modulation via the existing `PoseModifierStack`.** A full
alternative design was specified in parallel: a new `effort-accent` pass
(velocity-gated deviation-from-baseline emphasis on trunk/hand channels for
Weight, an intra-beat gain envelope + settle-rate scaling for Time, gain hooks
on the already-shipped `overshoot-settle`/`secondary-follow`/`girdle-follow`
passes for Flow). Its strongest property: all three cats stay time-locked by
construction (matches the painter's own stated philosophy — "variance in pose,
arms, faces… not sampled time"), so it carries *zero* foot-pop risk at all,
not just a mitigated one. Its decisive weakness, flagged by its own design as
the mechanism's structural ceiling: pose space cannot retime an arrival, so
Time (snap vs. sustain) would only ever read as "texture around the hit," not
"early/late" — likely the faintest of the three dials, on the dial the
research literature treats as one of the three trustworthy Effort factors.
Rejected as the primary mechanism for that reason; its Flow-gain hooks on
`overshoot-settle`/`secondary-follow` remain a compatible, low-risk future
increment if the split-clock warp's Flow read ever needs a second lever.

**A full-clip time warp (no bone split).** The simplest possible reading of
"warp per cat" — rejected outright: it warps the root/leg/foot channels along
with everything else, which is exactly the per-member sampled-time offset
`_ensembleMicroTimingOffset` was written to forbid, and would reintroduce the
foot-pop the trio's design deliberately engineered away.

**Injecting `dynamicsCurve` as `easeFn` on the existing shipped keys (the D1
plan as originally written).** Verified impossible without re-authoring:
`KeyframeChannel.sample`'s smooth (Catmull-Rom) path ignores `easeFn`
entirely, and every shipped catalog track compiles `smooth: true`. Flipping
tracks to `smooth: false` to unlock this would re-tune every hand-certified
move's interpolation and require a full re-author + panel pass — the opposite
of "opt-in and regression-free."

## Known risks, carried into the tuning PR

- **Polycentric decoupling reading as "drunk."** The upper body warping while
  the pelvis/legs hold the shared clock splits the authored trunk wave; at
  high gain, Strong's retrograde wind-up applied across the whole upper body
  (rather than one joint, as `dynamicsCurve` was originally scoped for) could
  read as a stutter rather than a wind-up. Mitigated by the deviation-form
  warp (small excursions by construction), the modulation budget, exact
  beat-boundary re-sync every count, and the 60fps GIF panel gate in the
  follow-up PR. **Documented fallback** if it fails review: a monotonicized
  warp variant (`du'/du >= 0` everywhere) that sacrifices the retrograde
  wind-up read but keeps the timing skew.
- **Per-beat kinks.** The warp is only C0 at beat boundaries when anticipation
  or overshoot are active (the slope jumps from the overshoot exit rate to the
  next beat's anticipation entry rate), and strongly-Sustained dials give an
  unbounded start slope in principle. Gated by a jerk-band check against the
  existing `dance_smoothness_test.dart` ceiling in the follow-up PR.
- **`CharacterScene`'s name-keyed memos** (`_spineLevelPlans` etc.) compute
  their plan from whichever variant — warped or unwarped — hits the cache
  first for a given clip name, since the warped clip deliberately keeps its
  source clip's name. This is a small, bounded head-leveler phase skew, not a
  correctness bug; monitored on the GIF panel rather than chased with a
  bigger cache key.
- **Z-order swaps stay on the shared clock.** The one shipped swap (shaku,
  phase `0.5`) is beat-aligned, so it's warp-invariant today; a future move
  whose swap boundary lands mid-beat would need checking. The follow-up PR
  adds a test asserting swap boundaries stay on the beat grid.

## Related

- [CHAR-0001](CHAR-0001-dance-choreography-encoding-and-move-library.md) — the
  Laban-Effort research and `DanceDynamics`/`dynamicsCurve` this ADR finally
  wires up; supersedes its "Implementation outcome" note that the layer is
  dormant.
- `../research/2026-06-27-movement-notation-synthesis.md` — finding 9
  (PERFORM/Samadani, personality as an Effort-space overlay on a neutral
  clip) and finding 3 (Weight/Time/Flow as measurable kinematics) are the
  direct sources for this ADR's composition and the follow-up PR's planned
  kinematic gate tests.
