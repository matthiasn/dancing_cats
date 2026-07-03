# ADR CHAR-0002: Angular motion diagnostics + overshoot-settle

## Status

**Accepted — implemented (2026-07-03).** Shipped in
`feat(character): angular motion diagnostics + overshoot-settle` (PR #22).
Ships as two independent mechanisms: a CI
test-time gate on rotation rate (no runtime enforcement), and an always-on
runtime pose-modifier pass that adds a decaying rotational settle after a
hard authored stop. All six catalogue clips pass the gate cleanly — the
`known`-exclusion escape hatch the test defines is empty at ship time.

## Context

[Doc CHAR-0001](CHAR-0001-dance-choreography-encoding-and-move-library.md)
and the runtime's existing `TemporalMotionAnalyzer` cover *positional*
smoothness (displacement → acceleration → jerk on world-space bone `dx`/
`dy`) and *anatomical range* (`JointRotationLimit`, applied every frame as
the pipeline's final safety net). Neither covers a third failure mode: a
joint can stay entirely inside its legal range, and its *position* can even
read as smooth, while its **rotation** still snaps — an elbow or the torso
whipping through an angle fast enough, or stopping abruptly enough, to read
as a glitch rather than a dance move. Nothing in the engine measured
rotation rate, and nothing shaped what a hard authored stop looked like the
instant after it landed.

Two-bone IK compounds the problem in a specific way: near a
**near-degenerate reach** (the target close enough to the shoulder that the
solved elbow bend angle is barely constrained), a small change in target
position can flip the solved bend angle by a large amount between adjacent
samples — a genuine solver artifact, not authored motion, but one that reads
identically to a real snap in any diagnostic that only looks at the
resolved pose.

## Decision

Ship two independent, differently-scoped mechanisms rather than one:

### 1. Angular motion diagnostics (measurement, test-time gate only)

Extend `TemporalMotionAnalyzer` with the same three-stage
displacement→acceleration→jerk chain already used for position, applied to
**world-space bone angle** instead: `TemporalMotionAngularSegment` →
`TemporalMotionAngularAcceleration` → `TemporalMotionAngularJerk`, exposed
on `TemporalMotionReport` as `worstAngularVelocity` /
`worstAngularAcceleration` / `worstAngularJerk` and matching `topN`
accessors.

Angle is read from the fully resolved `Affine2D`
(`math.atan2(transform.b, transform.a)`) — **world space, not local
`JointPose.rotation`** — because a forearm's visual rotation compounds its
parent's rotation too, and world angle is what a viewer actually perceives
as a snap. Readings are accumulated **unwrapped** across the `atan2` branch
cut so a rotation crossing ±π doesn't register a false ~2π spike.

The analyzer itself carries no built-in threshold, matching its existing
positional queries — it is a measurement object. The one caller,
`test/features/character/runtime/dance_angular_motion_test.dart`, is the
actual gate: for every catalogue clip and bones `handL`/`handR`/`torso`, it
asserts

```dart
expect(worstVelocity * kDanceRealTempoSpeedup, lessThan(2.5));       // rad/sample
expect(worstAcceleration * (kDanceRealTempoSpeedup * kDanceRealTempoSpeedup), lessThan(1.5)); // rad/sample²
```

`kDanceRealTempoSpeedup = 6 / 4 = 1.5` corrects for a real calibration gap:
clips are authored on a fixed 6-second clock, but the live app re-maps clip
time onto the track's real beat grid (`BeatLoopBinding.barAligned`), which
at the sample track's 120 BPM plays every routine 1.5× faster than the raw
clip clock — a factor every *earlier* smoothness test silently ignored.
Since compressing time by `k` scales the n-th derivative by `k^n`, velocity
readings are scaled by `1.5` and acceleration readings by `1.5² = 2.25`
before comparing to the ceiling, so the gate reflects what a viewer actually
sees in the running app. This is explicitly documented as *this track's*
current factor, not a universal constant.

Thresholds were calibrated against `sekem` — the clip nobody had flagged as
snappy — with roughly 3–4× headroom over its own worst readings.

**This is a CI gate, not a runtime clamp.** No code path in `SkeletonSolver`,
`ClipEvaluator`, or `CharacterScene`'s pose-modifier pipeline enforces a
velocity or acceleration ceiling at render time; an out-of-bounds clip
simply fails to merge.

### 2. Overshoot-settle (runtime, always-on)

A new `PoseModifierPass` (`id: 'overshoot-settle'`), wired between
`limb-ik` and `joint-limits`, injects the closed-form response of a
**critically-damped** spring-damper to an initial velocity impulse — one
rise-and-decay hump, deliberately not the lightly-damped oscillating form
(a ring would itself read as a second, higher-frequency snap):

```dart
final settle = v0 * dt * math.exp(-_kOvershootOmegaN * dt) * taper;
```

`v0`/`v1` (incoming/outgoing angular velocity around a keyframe boundary)
are estimated by a ±ε finite-difference probe against the *pre-overshoot*
pose (the chain evaluated with `stopBefore: 'overshoot-settle'`), gated so a
settle only triggers on a genuine hard stop:

| Constant | Value | Purpose |
| --- | --- | --- |
| `_kOvershootOmegaN` | `11` rad/s | settle rise/decay rate, tuned by feel |
| `_kOvershootMinIncomingSpeed` | `6` rad/s | floor below which nothing triggers (ordinary motion never fires this) |
| `_kOvershootMaxOutgoingRatio` | `0.4` | only a "hard stop" if outgoing speed drops to ≤40% of incoming |
| `_kOvershootMaxPlausibleSpeed` | `25` rad/s | ceiling above which a reading is discarded as IK solver noise |
| `_kOvershootProbeEpsilon` | `1/480` s | finite-difference probe step |

A **linear taper** (`1 - dt / frameDuration`, on the fixed 32-frame
choreography grid) forces the injected term to exactly zero at the *next*
authored keyframe boundary, regardless of spring tuning — the guarantee
every exact-frame pose assertion elsewhere in the suite depends on: the
settle only ever perturbs the interpolated region between authored keys,
never an authored instant.

Target bones are derived generically from the clip's own data (every
`LimbIkTarget` end effector that is *not* a declared ground/contact bone
contributes its upper+lower segment bones, plus the torso if the rig
declares a chest) — **feet are explicitly excluded**, since softening a
support foot's arrival would read as sliding into contact rather than
landing, directly fighting the contact-anchoring work `CHAR-0001` and the
runtime already do. The pass is stateless (a pure function of
`timeSeconds`), preserving the `frameAt(clip, time)` determinism the
film-strip renderer's byte-identical-output guarantee depends on. It runs
*before* `joint-limits` so any injected overshoot can still never push a
joint past its anatomical range.

### What tripped the gate, and how it was fixed

The gate's first run flagged `zanku`, `azonto`, and `pouncingCat`. In every
case the root cause was the two-bone IK near-degenerate-reach artifact
described in Context, not genuinely fast choreography. The fix was in the
choreography data, not the engine: widening the IK-target reach at the
offending keyframes in `samples/cat_in_suit.dart` so the solver never
entered the near-degenerate zone. One case (`azonto`'s frame 30→31)
needed a different fix — a shoulder-corrective ramp
(`_shoulderCorrectiveEngagement`) was crossing its engagement threshold in a
single frame; spreading it across two frames removed the spike.

## Consequences

- **Two mechanisms, not causally coupled.** Overshoot-settle's net effect on
  the shipped catalogue is small — the gate's actual worst-case readings
  lived in the lower-arm/elbow channel (the IK solver's most volatile
  output), which the settle pass measurably helps for *position* jerk but
  does not move for these specific *rotation* readings. The gate was made to
  pass by fixing choreography data (reach), not by this pass. Both are worth
  having; neither should be credited for the other's effect.
- **A new, generically-scoped runtime pass.** Because target bones derive
  from clip data rather than a hardcoded list, overshoot-settle applies to
  any future clip with `LimbIkTarget`s and a chest bone without further
  wiring — but also means a newly authored clip could trigger settles the
  author didn't anticipate; the min-incoming-speed floor is the main guard
  against that being visible on ordinary motion.
- **The plausible-speed ceiling is a load-bearing guard, not a nicety.**
  Without `_kOvershootMaxPlausibleSpeed`, a near-degenerate IK reading (seen
  as high as ~72 rad/s during development) would have been amplified into a
  settle, manufacturing a worse snap than the one this pass exists to
  remove. Any future change to the IK solver's degenerate-reach behavior
  should re-check this ceiling still discriminates real motion from solver
  noise.
- **`kDanceRealTempoSpeedup` is a single-track constant.** It is derived
  from the sample track's BPM and `kDancePhraseBars`; adding a second track
  at a materially different tempo, or changing the loop length, requires
  recomputing it — the gate would otherwise silently under- or
  over-tolerate real snaps.
- **No runtime enforcement of rate/acceleration.** Unlike anatomical range
  (`JointRotationLimit`, enforced every frame), rotation rate is enforced
  only at CI time. A future clip that regresses rate smoothness will fail
  the test suite, not degrade gracefully at runtime.

## Related

- Concept-first explainer with diagrams:
  [`docs/animation/04-temporal-motion-constraints.md`](../../../../../docs/animation/04-temporal-motion-constraints.md).
- [CHAR-0001](CHAR-0001-dance-choreography-encoding-and-move-library.md) —
  the choreography/IK-target model this ADR's diagnostics and settle pass
  both operate over.
- Code: `runtime/temporal_motion_analyzer.dart` (angular diagnostics),
  `runtime/character_scene.dart` (`_overshootSettledPose`,
  `_preOvershootPoseAt`, `_overshootTargetBoneIds`), `demo/dance_performance.dart`
  (`kDanceRealTempoSpeedup`).
- Tests: `test/features/character/runtime/dance_angular_motion_test.dart`
  (the gate), `test/features/character/runtime/temporal_motion_analyzer_test.dart`,
  `test/features/character/runtime/character_scene_test.dart` (pipeline
  stage order).
- Panel notes proposing further extensions (torso roll on support-foot
  swaps, a chin-dip, arm-spread arrivals): `../reviews/2026-07-03-panel-round9.txt`.
