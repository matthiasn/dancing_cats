# ADR 0001 — Multi-plane parallax for the dance stage

- **Status:** Accepted
- **Date:** 2026-07-01
- **Deciders:** dancing_cats rendering
- **Tags:** scenery, camera, cinematography, 2.5D

## Context

The dance-to-track stage is a **2.5D** composition: a Lagos blue-hour lagoon
painted as a back-to-front stack of flat art layers (sky plate, drifting clouds,
skyline + bridge, moored yacht, animated ocean, foreground deck with palms and
planters), with a trio of cats performing in front of it. A "virtual director"
drives a camera over the piece — slow motivated dollies, with fast *punches* on
the choruses and bridge hand-offs.

Until now the camera's effect on the scenery was a **single flat plane**: one
`Transform` lagged the *entire* backdrop by a fixed fraction (~28% of the pan,
~34% of the zoom) behind the foreground cats. This is the classic "one distant
plate" trick. It reads as *some* depth on a push-in, but it has two well-known
failure modes that a trained eye catches immediately:

1. **The backdrop moves as one card.** The near deck/planters, the mid-distance
   yacht, and the far skyline all drift by the same amount. Real depth means the
   near deck should track the cast far more than the distant towers. A single
   plane cannot express that, so on a lateral truck the whole world slides
   rigidly — the tell of a flat cut-out backdrop.

2. **The cast is a flat cut-out too.** All three cats sit on exactly one plane
   and move as a rigid block. A dolly never reveals any relationship *between*
   them; the trio slides as a sticker.

The brief: a **proper multi-plane parallax** system — sky, city, ocean, boat and
foreground deck each moving at their own depth rate, and the cats gaining a
shallow depth of their own so they shift against one another on a truck.

Three hard constraints shaped the design:

- **Live == offline.** The live stage and the offline video composer are two
  independent paint paths that must stay pixel-identical (the export is only
  trustworthy if it matches what the operator saw). Any parallax change has to
  land in *one* place both consume.
- **The scenery feature is reusable and camera-agnostic.** It is ejectable and
  must not depend on the dance camera / character feature.
- **100% test coverage, including generative tests**, and the golden numeric
  windows the choreography relies on must not regress.

## Decision

Adopt a **per-layer depth ladder** for the backdrop and a **per-lane depth
shear** for the trio, sharing one parallax math source.

### 1. Depth is a property of the *scene composition*, carried by a decorator

Introduce `ParallaxLayer(child, {depth})`, a thin decorator wrapping one
background layer. `depth` runs `0` (locked at infinity — no drift) to `1` (moves
fully with the foreground/dancers). The scene wraps each background layer at its
place on the ladder; the screen-space vignette is deliberately left unwrapped.

Depth lives on the scene entry, not the layer class: the same `ImageLayer` art
can sit at different depths in different scenes, so depth is composition, not
identity.

### 2. The camera → transform mapping is *injected*, not imported

`ParallaxLayer` does not know what a "dance camera" is. It reads an injected
closure `BackdropContext.parallaxForDepth(depth, size) -> Matrix4` and paints its
child under that transform (or flat, if none is supplied — so procedural scenes,
other consumers and unit tests are unaffected). The character feature owns the
math and injects the closure; the scenery feature stays camera-agnostic. Because
the **live stage and the offline composer inject the same closure**, the two
paths lag every plane identically — the live == offline constraint is satisfied
structurally, not by discipline.

### 3. One shared, pure math source

`CharacterPainter.danceParallaxMatrixForShotAtDepth(shot, size, depth)` is the
single source of truth. A plane at `depth d` receives `1 + (zoom-1)·d` of the
zoom and `d` of the pan/crane, about the **same feet-planted pivot** as the
foreground camera, with the same off-screen pan clamp. Consequences that fall
out of the formula, by design:

- **Monotonic ladder.** More depth ⇒ at least as much drift and growth. Far
  planes barely move; the deck nearly tracks the cast.
- **`depth = 1` is exactly the foreground camera**, so the ladder is anchored to
  a real reference, not an arbitrary fraction.
- **Every plane only ever grows about the pivot** (zoom ≥ 1 for any depth), so a
  plane can never reveal its own edges; the pan clamp then keeps it inside the
  16:9 frame, where the film-grain and light overlays live.

### 4. The depth ladder (blue-hour waterfront)

| Plane | depth | rationale |
|---|---|---|
| Sky base plate, far clouds, distant jet | 0.06 | near-infinity; a whisper of drift |
| Mid / near clouds | 0.09 / 0.12 | the sky gains internal depth |
| Skyline + bridge, city lights, police strobes | 0.13 | the far structural wall |
| Ocean | 0.16 | the water plane reads just ahead of the shore |
| Yacht | 0.24 | moored *nearer* than the skyline — must out-parallax it |
| Drones | 0.10 | hovering off the bridge, near the sky |
| Waterline aerial haze | 0.30 | the depth-cue veil, between midground and deck |
| Foreground deck, palms, planters, lantern glow | 0.50 | tracks the cast most |
| **Cats (foreground)** | **1.00** | the reference plane |
| Lead cat / flanking backups | 1.00 / 0.92 | the trio's own shallow depth |

The ladder is monotonic front-to-back and the values are exposed as named
constants for live tuning.

### 5. Inter-cat parallax

The centred lead is the `1.0` reference; the flanking backups sit a touch upstage
at `0.92`. Each lane counter-shifts by `(depth-1)·pan/zoom` in local space, so a
lateral truck shears the near lead against the upstage backups. A uniform pan
cancels in the inter-member gaps, so *only* the differential parallax moves them
— on a rightward truck the left gap widens and the right narrows by the same
amount. It is deliberately small: the cast is near-coplanar on the deck, so this
reads as depth, not as a diorama, and it is a no-op on every non-dance surface.

## Consequences

### Positive

- **Real depth.** Near and far now separate on every move; the strongest cue —
  the deck tracking the cast while the skyline holds — is exactly what sells a
  dolly as a move *through* space rather than a zoom *at* a picture.
- **The cast is no longer a sticker.** The trio gains its own shallow volume.
- **Decoupled and testable.** The scenery feature stays camera-agnostic; the
  parallax math is a pure function with unit + generative (property) tests
  asserting finiteness, the `[1, zoom]` bound, and depth-monotonicity.
- **Live == offline by construction.** Both paths inject one closure over one
  math source; there is no second implementation to drift.

### Negative / trade-offs

- **2.5D contact shear.** Giving pre-composited art different depths means
  elements that share a contact line (yacht on water, deck on the shore) shear
  slightly at that line on a large pan. This is inherent to plane-based parallax
  without true geometry. Mitigated by keeping adjacent contacting planes close on
  the ladder (yacht 0.24 vs ocean 0.16) and by the clamped, modest camera pans;
  the deck's big jump to 0.50 is safe because its "contact" is the framed bottom
  edge and the cast, not the hazed midground.
- **Per-layer save/restore.** ~15 `save/transform/restore` pairs per frame.
  Negligible against the shader and image passes.
- **Hand-tuned values.** The ladder is artistic, not physically derived. It is
  named-constant tunable; a future ADR could derive depths from a metric camera.

## Alternatives considered

- **Keep the single flat plane (status quo).** Rejected: it *is* the flat
  cut-out problem the brief exists to fix.
- **True 3D scene (real geometry / a depth map per layer).** Rejected as
  over-scoped: the art is hand-painted 2D plates; full geometry would mean
  re-authoring the scene and buys little over a well-chosen ladder at this remove.
- **Group layers into 3 fixed planes (near/mid/far).** Rejected: too coarse — the
  yacht-vs-skyline and deck-vs-haze separations that most read as depth would
  collapse. Per-layer depth is barely more code and far more expressive.
- **Move the parallax math into the scenery feature.** Rejected: it would couple
  scenery to the dance camera's pivot/reference constants. The injected closure
  keeps scenery a pure "render layers under given transforms" system.
- **Separate zoom vs pan depth factors per layer** (as the old single plane did:
  0.34 vs 0.28). Rejected: a single per-layer depth is simpler and the *ladder*
  already provides the differentiation; the extra knob added tuning surface
  without a visible payoff.
- **Parallax the cast via a full 3D formation.** Rejected: the trio is
  near-coplanar; a shallow per-lane shear delivers the read at a fraction of the
  risk to the golden choreography windows.

## Validation

- Unit + generative property tests on the depth-matrix math; a decorator test for
  `ParallaxLayer`; a scene test asserting the depth ladder is monotonic; a
  behavioural test that a lateral truck shears the trio (left gap widens, right
  narrows, by equal amounts). Full suite green at 100% line coverage.
- Artistic sign-off: captured stage frames reviewed by a panel (cinematography,
  2D-animation art direction, motion graphics) against this ADR's intent.
