# ADR 0003 — Soft-knee biasing for small parallax moves

- **Status:** Accepted — implemented (PR #21)
- **Date:** 2026-07-02
- **Deciders:** dancing_cats scenery + camera
- **Tags:** parallax, camera, perception, vection

## Context

[ADR 0001](0001-multiplane-parallax.md) established the five-plane depth
ladder: every plane's camera response is `shot` scaled linearly by its
`depth` (`zoom: 1 + (shot.zoom - 1) * depth`, `dx: shot.dx * depth`, `dy:
shot.dy * depth`). That ladder is correct for the deliberate, sustained
camera moves the dance director produces — a chorus push, a bridge
traverse — but it is also applied, unmodified, to the small continuous
motion every "calm" section produces: the establish's lateral drift, the
verse's slow breathe. Those amplitudes are small in absolute terms, but a
background plane's small motion is not perceived the same way a foreground
plane's is.

Motion-parallax / vection literature is specific here: low-disparity
background motion reads as **more** objectionable per pixel than the same
fractional motion on a near plane, because the visual system uses
background optic flow as its primary self-motion cue. A few pixels of jitter
on the `depth = 0.12` backdrop plane during a calm establishing shot reads
as the *scene* swimming; the same absolute jitter on the `depth = 1.0`
foreground cast reads as nothing, because near-plane motion is expected and
readily attributed to the camera, not to the world.

The plain linear ladder has no way to express this: it treats a
1-ref-pixel pan the same as a 500-ref-pixel dolly, differing only by depth,
not by amplitude. Fixing the calm-shot case by simply lowering
`_depthBackground` further would also flatten every plane's response to
*deliberate* moves — the chorus push and the bridge traverse need every
plane at its full ADR 0001 depth to read as a coordinated dolly. The two
requirements (damp small motion, pass big motion) are in tension for a
single linear scalar.

## Decision

Bias each plane's zoom-delta and pan through a **soft knee** before scaling
by depth — a smoothstep ramp that damps amplitudes below a threshold and
passes amplitudes at/above it through at gain 1, so small and large motion
get different treatment without needing two different code paths for "calm"
vs. "deliberate" camera contexts:

```dart
static double _softKnee(double x, double knee) {
  if (knee <= 0) return x;
  final t = (x.abs() / knee).clamp(0.0, 1.0);
  return x * t * t * (3 - 2 * t); // smoothstep: damped near 0, gain 1 at/after the knee
}

static ({double zoom, double dx, double dy}) _parallaxCameraAtDepth(Shot camera, double depth) {
  final farness = (1 - depth).clamp(0.0, 1.0);
  final zoomDelta = _softKnee(camera.zoom - 1, _kParallaxZoomKnee * farness);
  final dx = _softKnee(camera.dx, _kParallaxPanKnee * farness);
  final dy = _softKnee(camera.dy, _kParallaxPanKnee * farness);
  return (zoom: 1 + zoomDelta * depth, dx: dx * depth, dy: dy * depth);
}
```

The knee **widens with farness** (`_kParallaxZoomKnee * (1 - depth)`,
`_kParallaxPanKnee * (1 - depth)`): at `depth = 1` (the foreground cast)
`farness = 0`, so the knee collapses to zero and every move passes through
untouched — this only ever affects background-ward planes, never the
dancers themselves. As depth drops toward `_depthBackground = 0.12`,
`farness` grows toward `~0.88`, widening the damped region.

The two knee constants are sized against the calm-shot amplitudes they
exist to damp, not chosen arbitrarily:

- `_kParallaxZoomKnee = 0.06` (zoom-delta units) — sized to the calm
  establish's baseline push (`zoom 1.06`).
- `_kParallaxPanKnee = 60` (2560-reference px) — sized to the calm drift
  amplitude (`kCalmDriftRef = 35` ref px in the camera director), with
  headroom so ordinary breathing/drift sits inside the soft region.

Any framing that clears these thresholds — `≥1.18` zoom or `≥260px` pan,
comfortably inside "this is a deliberate move" territory — rides the plain
linear ladder at full strength on every plane, exactly as ADR 0001
specifies. Nothing about a chorus push, a bridge traverse, or any other
sustained dolly changes; only the amplitude range below a real dolly's
amplitude gets biased.

## Consequences

- **Monotonicity is preserved.** Because the knee only ever *shrinks* as
  depth increases (`farness` is non-increasing in `depth`), the softened
  output stays depth-monotonic just like the un-softened ladder — a farther
  plane still never out-moves a nearer one, even inside the damped region.
  This is asserted directly by a 300-run property test.
- **One function, two regimes, no branching on "is this a calm shot."** The
  camera director and rig have no notion of "calm vs. deliberate" as a
  discrete mode — sections blend continuously into each other. Soft-knee
  biasing works on raw amplitude, so it needs no section-awareness and
  cannot glitch at a section boundary.
- **The bias is invisible on deliberate moves.** Because the knee is sized
  well below any real dolly's amplitude, this change is not perceptible
  during the piece's showcase moves (the chorus pushes, the bridge
  traverse) — only during the calm sections it targets.
- **A second knob to keep in sync with the camera director.** `kCalmDriftRef`
  (camera director) and `_kParallaxPanKnee` (parallax) are tuned against
  each other by convention, not enforced by a shared constant or a test that
  cross-checks them. If the calm-section drift amplitude is retuned, the pan
  knee should be revisited too.

## Validation

`test/features/character/runtime/character_painter_test.dart`
(`danceParallaxMatrixForShotAtDepth` group) — the soft-knee-specific cases:
for a small zoom delta (`1.04`), the growth ratio (actual ÷ linear) is
strictly lower on a far plane (`depth 0.12`) than a near plane (`depth
0.5`); for a large delta (`0.32`, clear of both knees) the two planes match
pure linear scaling. The same suite's 300-run `glados` property test asserts
the softened output stays depth-monotonic, always finite, `zoom >= 1`, and
never exceeds the foreground shot's own zoom — the same invariants ADR
0001's un-softened ladder guarantees, now re-verified with the bias in
place.

## Related

- [ADR 0001 — Multi-plane parallax](0001-multiplane-parallax.md) — the
  depth ladder this ADR biases.
- [`docs/animation/01-parallax-and-layers.md`](../animation/01-parallax-and-layers.md) —
  concept-first explainer covering both ADRs together, with diagrams.
- Project memory: "Parallax soft-knee for small moves" (PR #21) — grounded
  in vection literature per the user's own framing when this shipped, not a
  guess; user-validated against the running scene.
