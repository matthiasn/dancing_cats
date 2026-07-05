# ADR CHAR-0003: Laban-Effort dynamics via a split-clock time warp

## Status

**Accepted — plumbing and tuning both landed (2026-07-05).** The composition
rule, the model-layer warp primitive, and the full wiring from `DanceStage`
through the stepper into the single live/offline paint path
(`danceCharacterPainter`) shipped first on `feat/effort-dynamics-split-clock`
as a provable no-op (every real value neutral/zero, pinned by an
`identical(...)` regression test). A follow-up PR (`feat/effort-dynamics-tuning`)
then populated every constant and ran the panel:

- the six catalog moves' `AfrobeatsMove.dynamics` from the D4 Effort table,
  the per-lane personality profiles, and the section-energy gain;
- a new kinematic gate (`dance_dynamics_split_clock_test.dart`) proving the
  headline invariant on the real catalog — every non-upper-body bone stays
  world-transform-identical across all 6 moves x 3 lanes x 3 section levels —
  plus velocity-ordering, jerk-ceiling, determinism, and beat-alignment checks;
- a 4-lens motion-review panel (MoCap/biomechanics, character animator,
  technical animation, cartoon performance) on real rendered frames, which
  converged unanimously: the mechanism is **physically safe** (feet locked,
  no clipping/z-order issues, no "drunk" upper-body reading) but the
  differentiation was **too subtle to read** at the initial `gain = 0.35`
  (lane-to-lane hand-position deltas exceeded 5 units on only ~4% of the
  loop). The panel's own sparse sampling (fixed 25-frame stride) also missed
  the brief windows where the warp's effect concentrates — a capture-quality
  finding as much as a tuning one.
- **Owner-approved fix:** raised `kDanceDynamicsTimeWarpGain` to `0.5` (a
  measured trade-off point: visibility roughly triples to ~13% of the loop,
  while zanku — the catalog's most extreme Strong/Sudden move — is the first
  to feel jerk cost, since higher gain compounds superlinearly with jerk;
  `0.6` and `1.0` were measured and rejected as visibly over the smoothness
  line). Confirmed by a targeted re-render at the known spike windows and the
  loop-seam crossing: legible per-lane pose divergence at the spike frame,
  clean continuity across the loop wrap.

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

## Known risks, resolved or accepted during tuning

- **Polycentric decoupling reading as "drunk."** The upper body warping while
  the pelvis/legs hold the shared clock splits the authored trunk wave.
  **Resolved**: all 4 panel lenses independently confirmed no "drunk" or
  detached reading at the shipped `gain = 0.5`, and a targeted re-render at
  the numerically-identified spike windows showed a legible, physically
  plausible pose divergence, not a glitch. The documented monotonicized-warp
  fallback (`du'/du >= 0` everywhere) was not needed.
- **Per-beat kinks.** The warp is only C0 at beat boundaries when anticipation
  or overshoot are active, and strongly-Sustained dials give a steep start
  slope. **Accepted with a calibrated ceiling**: gated by
  `dance_dynamics_split_clock_test.dart`'s warped-hand-jerk test at `<55`
  (measured worst case 48.5, on zanku — the catalog's most extreme
  Strong/Sudden move, expected to hit this first). Gain was explicitly
  capped at `0.5` rather than pushed higher specifically because jerk grows
  superlinearly with gain (measured: `0.6` -> 64, `1.0` -> 140, clearly
  broken) — this is the real ceiling on how far this mechanism can be pushed
  without a shape change to `dynamicsCurve` itself.
- **`CharacterScene`'s name-keyed memos** (`_spineLevelPlans` etc.) compute
  their plan from whichever variant — warped or unwarped — hits the cache
  first for a given clip name, since the warped clip deliberately keeps its
  source clip's name. Checked on the panel renders: no visible head-level
  artifact at the shipped gain. Still a theoretical small skew, not chased
  with a bigger cache key.
- **Z-order swaps stay on the shared clock.** The one shipped swap (shaku,
  phase `0.5`) is beat-aligned, so it's warp-invariant — pinned by a test
  asserting swap boundaries stay on the beat grid. A future move whose swap
  boundary lands mid-beat would need the same check added.

## Panel-driven tuning process (for future rounds)

The render→panel→fix loop that shipped this tuning, worth repeating verbatim
for future Effort-layer changes:

1. Render real per-lane/per-level frame sequences through the actual
   `upperBodyDynamicsWarpedClip` + shipped constants (not a mocked path).
2. Run a 4-lens panel (MoCap/biomechanics, character animator, technical
   animation, cartoon performance) on the renders.
3. **If the panel says "too subtle" or "can't tell,"** don't just trust the
   verdict — numerically measure where in the loop the effect actually
   concentrates (a deviation-form time warp is bump-shaped near each beat's
   accent, not uniform across it) before concluding the gain is wrong. The
   first-round panel here scored 2-7/10 partly because the capture (fixed
   25-frame stride) missed the brief high-deviation windows entirely — a
   capture-quality problem, not only a tuning one.
4. Sweep the candidate gain against BOTH a visibility metric (e.g. fraction
   of loop with lane-to-lane bone-position delta above a legibility
   threshold) and the jerk ceiling, since they trade off — jerk grows faster
   than the visibility metric as gain increases, so there is a real ceiling,
   not just a dial to turn up freely.
5. Re-render at the *specific* frames the numeric sweep flags (spike windows,
   loop-seam crossing) for a fast, targeted confirmation rather than another
   full broad panel round.

## Related

- [CHAR-0001](CHAR-0001-dance-choreography-encoding-and-move-library.md) — the
  Laban-Effort research and `DanceDynamics`/`dynamicsCurve` this ADR finally
  wires up; supersedes its "Implementation outcome" note that the layer is
  dormant.
- `../research/2026-06-27-movement-notation-synthesis.md` — finding 9
  (PERFORM/Samadani, personality as an Effort-space overlay on a neutral
  clip) and finding 3 (Weight/Time/Flow as measurable kinematics) are the
  direct sources for this ADR's composition and its kinematic gate tests.
