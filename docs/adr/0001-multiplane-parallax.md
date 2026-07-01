# ADR 0001 — Multi-plane parallax for the dance stage

- **Status:** Accepted
- **Date:** 2026-07-01
- **Deciders:** dancing_cats rendering
- **Tags:** scenery, camera, cinematography, 2.5D

## Context

The dance-to-track stage is a **2.5D** composition: a Lagos blue-hour lagoon
painted as a back-to-front stack of flat art layers (a master base plate, drifting
clouds, a distant jet, animated ocean, a re-drawn skyline + bridge, a moored
yacht, additive city/cabin night-lights, an aerial-haze band, the foreground
deck with palms and planters, deck glow, police strobes, a drone show) with a
trio of cats performing in front of it. A virtual director dollies the camera
over the piece.

Until now the camera's effect on the scenery was a **single flat plane**: one
`Transform` lagged the *entire* backdrop by a fixed fraction (~28% of the pan)
behind the cats. That is the classic "one distant plate" trick, and it has the
two failure modes a trained eye catches at once: the whole world slides as one
card (no near-vs-far separation), and the cast is a rigid sticker on top of it.

The brief was a **proper multi-plane parallax** — near and far moving at
different rates so the scene reads as real depth, and the cast gaining a shallow
depth of its own.

Three hard constraints shaped the design, and one discovery reshaped it:

- **Live == offline.** The live stage and the offline video composer are two
  independent paint paths that must stay pixel-identical.
- **The scenery feature is reusable and camera-agnostic** (it is ejectable and
  must not depend on the dance camera / character feature).
- **100% test coverage, including generative tests**; the golden numeric windows
  the choreography relies on must not silently regress.
- **The discovery (decisive):** the painted **base plate has the skyline, yacht
  and deck baked into it**, and the scene *re-draws* those same structures as
  separate layers over the animated clouds/ocean purely for correct depth
  ordering. So a re-drawn structure is a **duplicate** of what is already in the
  base. Parallaxing a re-draw independently of the base slides it off its baked
  twin and reveals a **doubled** yacht / skyline. Fine per-layer depth is
  therefore not merely a tuning choice — for the baked structures it is *wrong*.

## Decision

Adopt a **small number of coarse depth PLANES**, grouped so that no element ever
separates from its baked twin, with the camera→transform mapping injected into a
camera-agnostic scenery layer over one shared math source.

### 1. Coarse depth planes, not a per-layer ladder

Because of the baked-twin problem, the **entire backdrop moves as ONE far plane**
— base plate, clouds, ocean, skyline, yacht, all the additive lighting and the
haze together — so re-draws, their light and the atmosphere that veils them stay
locked to the base. Only elements that are **genuinely separable** get their own
plane: the foreground **deck** (the stage the cast dances on), the **cats**, and
the **distant jet** (a *dynamic* layer with no baked twin, so it can safely ride
the farthest plane). Five planes, front to back:

| Plane | depth | why it is separable |
|---|---|---|
| Lead cat ("front cat") | 1.00 | drawn live, the reference plane |
| Backup cats | 0.95 | drawn live |
| Stage / deck (+ deck glow) | 0.35 | a foreground occluder drawn over the scene |
| **Whole painted backdrop** | 0.12 | one plane → no re-draw leaves its baked twin |
| Distant jet | 0.04 | dynamic, no baked twin; the farthest thing in frame |

**Be honest about what this forgoes.** Welding the whole painted world to one
0.12 plane means the yacht no longer out-parallaxes the skyline, the ocean no
longer reads ahead of the shore, the sky no longer sits behind the towers —
*within* the backdrop, near and far move identically. That is, for the painted
world, exactly the "moves as one card" symptom this ADR's own Context indicts. So
this is **not full multi-plane depth**; it is a deliberate **3–4 tier result** —
jet, backdrop, deck and cast separate from one another, but the backdrop does not
separate internally. We accept that because the structures are **baked into a
shared plate**: a doubled yacht is a worse artifact than a flat-but-clean
midground, and clean is the only honest option until the plate is un-baked (see
the durable fix below). Internal-backdrop parallax is *deferred*, not delivered.

What the grouping DOES buy, by construction, is the elimination of a whole class
of artifacts a fine ladder introduced: no yacht-vs-skyline contact shear, the
additive **city and yacht cabin lights cannot detach from their hulls** (same
plane as the structures they light), and the **aerial-haze band cannot drift off
the skyline it veils** (it moves with it). One plane, one motion.

**The durable fix (follow-up).** The baked-twin doubling is a symptom of
un-separated plates — precisely the problem the multiplane technique exists to
solve. The lasting route to true midground depth is to **de-bake the master
plate**: separate the sky, skyline, yacht and ocean into their own alpha plates
(the repo has scenery art-prep / layer-registration tooling for exactly this) so
each *can* parallax past the others without a doubled twin. Only then does the
yacht-vs-skyline separation the brief really wants come back. Coarse grouping is
the correct **interim** until that art pass lands — the same de-bake the palms
split makes for the foreground (below), owed equally to the midground.

Two value notes. The jet at 0.04 sits *farther* than the 0.12 clouds it crosses —
a slight inversion, chosen for near-lock (it should be the least-drifting thing in
frame) rather than literal depth ordering; harmless because it is small, brief and
has no baked twin. And the cloud layers carry their own intrinsic `dxPerSecond`
drift; composed with the 0.12 plane parallax the sum was checked to read as one
calm background motion, not two competing ones.

### 2. Depth is composition, carried by a decorator; the camera is injected

`ParallaxLayer(child, {depth})` wraps one layer and paints it under the scene
camera's parallax at its depth. It does **not** know what a "dance camera" is: it
reads an injected closure `BackdropContext.parallaxForDepth(depth, size) →
Matrix4`, or paints flat if none is supplied (so procedural scenes, other
consumers and unit tests are unaffected). The character feature owns the math and
injects the closure; scenery stays camera-agnostic. Because the **live stage and
the offline composer inject the same closure**, both lag every plane identically.

### 3. One shared, pure math source — with exact edge safety

`CharacterPainter.danceParallaxMatrixForShotAtDepth(shot, size, depth)` is the
single source of truth. A plane at `depth d` receives `d` of the pan/crane and
`1 + (zoom-1)·d` of the *dolly-in* scale, about the same feet-planted pivot as the
foreground camera. Note the vocabulary: the chorus "punch" is a **depth-scaled
dolly-in (a Z-push)**, not an optical zoom — a true zoom scales every plane
equally and yields no parallax; the whole point here is that near planes grow
faster than far, which is dolly behaviour.

Edge safety is **exact, not "usually fine"**. Because every plane only grows about
the pivot (scale ≥ 1 for any depth), it can never reveal its own edge on a push.
The pan clamp then keeps it inside the 16:9 frame. Crucially the vertical clamp is
**asymmetric**: the pivot sits off-centre at the feet line (fraction `f = 0.88`),
and scaling by `z` about `f` exposes `f·span` above the pivot and `(1-f)·span`
below, so the plane may travel **down by `f·span`** before its top edge reveals
and **up by `(1-f)·span`** before its bottom edge does. A symmetric `±span/2`
clamp would let a strong upward lift pop the bottom edge open; the implemented
bound `dy ∈ [-(1-f)·span, +f·span]` closes that. (Horizontally the pivot is
centred, so the side clamp stays symmetric.)

### 4. Inter-cat parallax — lateral only, by design

The centred lead is the `1.0` reference; the flanking backups sit a touch upstage
at `0.90`. Each lane counter-shifts by `(depth-1)·pan/zoom` in local space, so a
lateral truck shears the near lead against the upstage backups. This is applied to
**pan only, never to scale**: a differential *zoom* between lanes would make the
backups appear to shrink away from the lead on a push-in — a change in apparent
size reads as a change in importance, which we do not want for a trio of near-
equals. A uniform pan cancels in the inter-member gaps, so only the differential
moves them: on a rightward truck the left gap widens and the right narrows by the
same shear. Magnitude, so it is not a test-only no-op: at the widest clamped truck
the backup shift is `(1-0.95)·maxDx = 0.05·width·(zoom-1)/2` — a couple of px per
backup at a chorus zoom, deliberately kept **felt, not seen** (immersive, not
obvious). It is a no-op on every non-dance surface.

### 5. Screen-space effects stay unwrapped; plates resample sharp

The vignette (and the film-grain and stage-light overlays) are **not** wrapped —
they are screen-space and must not swim with a world plane. And because per-plane
parallax resamples each plate at a *fractional* zoom every frame, `ImageLayer`
draws at **`FilterQuality.high`** (bicubic) rather than the default low
(bilinear), which crawled on the high-frequency skyline as the camera dollied.
High is the pragmatic ceiling but is *not* mipmapped, so a hair of minification
shimmer can persist on the far skyline during a slow drift; a mipmapped/trilinear
path would fully retire it, and is cheap to add per plate if it ever reads.

## Focus / depth of field

Deliberately **deferred**, and the deferral is principled: the scene already
carries its depth-of-focus cue as *painted aerial perspective* — the
`AtmosphericHazeLayer` and the shader's distance-graded haze lift and desaturate
the far skyline so it recedes behind the sharp near deck and cast. This is the
2D-animation idiom (atmosphere, not lens bokeh) and it is baked to sit correctly
at rest. A real-time, depth-keyed defocus (softness = f(|depth − focusDepth|))
would be the lens-accurate answer and is the natural next ADR; it is out of scope
here because (a) the coarse planes make a per-plane blur cheap to add later, and
(b) with the backdrop unified on one plane there is no *motion* artifact for blur
to hide, only a static poster-vs-lens preference. Critically, softness must be
keyed to the **same depth scalar** as motion if it is added, so it can never
invert the ladder the way an ad-hoc per-layer blur once did.

## Depth ordering vs paint ordering

These are two different orderings and the ADR states so explicitly. **Paint order**
(occlusion) is the layer list; **parallax depth** (drift rate) is the plane. They
mostly agree, but the additive light passes are deliberate exceptions: the police
strobes and drone show are painted *front-of-stack* (so nothing occludes them) yet
sit on the far **background** plane (they belong to the bridge/sky they light).
With the coarse grouping this is trivially consistent — every backdrop element,
whenever it is painted, shares one depth — which is exactly why the doubling
problem cannot recur.

## Readability guardrail

Going multi-plane must not let the background out-shout the dancing cats. The
coarse grouping already helps: the whole backdrop moves as **one calm plane** at
0.12, so there is a single, slow background motion rather than a dozen competing
rates. On top of that the guardrail is: keep the highest local contrast on the
suits (the trio); the vignette seats them; the aerial haze holds the far planes
down in contrast; and the busiest background events (drones, jet) are kept from
peaking on the beats meant for the cast. The camera language is tuned to the same
end (below).

## Consequences

### Positive

- **Tiered depth with zero doubling.** The **backdrop, deck and cast separate**
  from one another on every move (within the backdrop they do not — see §1), and
  nothing ever slides off its baked twin. A clean three-tier read, not the flat
  single-card it replaced.
- **The lighting/atmosphere problems evaporate.** City and cabin lights, water
  reflections and the haze all ride the structure they belong to, because that
  structure and its light share one plane.
- **The cast is no longer a sticker** — a shallow, pan-only inter-cat shear.
- **Decoupled and testable.** Scenery stays camera-agnostic; the parallax math is
  a pure function with unit + generative (property) tests asserting finiteness,
  the `[1, zoom]` bound, and depth-monotonicity.

### Negative / trade-offs

- **Cats slide over the deck on a lateral truck — now the primary artifact, and
  in a worse spot than the shear it replaced** (it sits directly under the hero's
  feet, the contact the eye reads for groundedness, where the old midground shear
  sat between non-focal elements). Magnitude: the plank slips by
  `(depth_cat - depth_deck)·maxDx = 0.65·width·(zoom-1)/2` at the cat plane. Why
  0.35 (down from 0.5): the goal is a depth cue that is **immersive, not obvious**
  — the deck should recede into the gently-moving world behind the cast, not jump
  at the viewer. So the deck was pulled toward the backdrop (0.12), trading a touch
  more theoretical foot-slip for a subtler read; in practice the slip stays bounded
  because the camera pans are deliberately small (see the companion camera work),
  and the feet do not *float* (grounded contact shadows are painted on the **cat
  plane**, welded to the feet). The zero-slip **2-tier fallback** (park the deck on
  the backdrop too, so only the cast peels off a unified world) stays on the shelf
  if the skate ever reads on export; an eventual deck/palms split lets a near
  contact band ride nearer 1.0 while the far rail recedes, retiring the trade.
- **The palms are baked into the deck plate**, so they ride the stage plane and
  swing on a hard push-in (fronds scale up about the feet pivot); worse, at the
  stage depth they read *farther* than the cast they should frame — a mild depth
  inversion,
  since a framing foreground should be the *nearest* plane. The proper fix is an
  art split of `foreground.webp` into `deck` + `palms`, giving the palms their
  **own near-foreground plane** nearer than the cast — the single highest-value
  depth cue still missing (a foreground occluder that looms/overlaps toward camera,
  the strongest "real space through a lens" read). Tracked as follow-up; interim
  mitigation is the wider, slower revised camera, which keeps the swing small.
- **Hand-tuned depths.** Five values, exposed as named constants for live tuning.

## Live == offline

There are two paint paths — the live widget painter (`LayeredBackdrop`) and the
offline composer, which re-implements the layer loop — but they walk the *same*
layer list and inject the *same* parallax closure over the *same* pure math, so
the parallax itself cannot diverge (the surrounding paint code differs; the depth
transform does not). The real pixel-identity risks in this shader-heavy stack are
elsewhere and are managed accordingly: the **frame clock** is deterministic (the
offline composer prerolls the same stepper), **device-pixel-ratio** and **filter
quality** are pinned equal, and **shader/GPU-backend** differences are covered by
the repo's cross-platform pixel-tolerance policy (assertions widen for
rasterisation variance rather than chase exact values). One lens caveat left open:
the fast accents carry no **motion blur / shutter**, so the near deck and cast —
which move most — can judder on the sharpest whip; slowing the accents (companion
camera work) mitigates it, a shutter model would complete it.

## Camera language (companion)

Multi-plane parallax is a *time-and-distance* phenomenon: a plane reads as
separate only when the eye can track it sliding past another, which needs a slow,
wide, **lateral** move — not a fast centred push. The camera was therefore
retuned to exploit the rig: accent moves slowed (~0.14s → ~0.30s, with a longer
bridge whip), the zoom band pulled ~0.1 wider with a lower cap so the far planes
stay in frame to slide, and static-centred sections converted to slow trucks with
deliberate holds after each accent so the cats can perform. Details live with the
director; the parallax rig is the substrate that makes it worth doing.

## Alternatives considered

- **Single flat plane (status quo).** Rejected: the flat-cut-out problem itself.
- **Fine per-layer depth ladder.** Implemented first, then rejected: it slides
  each re-draw off its baked twin (doubled yacht/skyline) and detaches lighting
  and haze from their subjects. Coarse planes are the fix, not a simplification.
- **True 3D / per-layer depth maps.** Over-scoped: the art is hand-painted 2D
  plates; real geometry means re-authoring the scene for little gain at this remove.
- **Split the fused city-lights shader into per-depth passes.** Considered to let
  the yacht cabin glow ride the yacht plane; made moot by the coarse grouping (the
  yacht and its glow share one plane already), and the shader also fuses
  atmosphere it does not own — not worth the surgery.
- **Move the parallax math into scenery.** Rejected: it would couple scenery to
  the dance camera's pivot/reference constants; the injected closure keeps scenery
  a pure "render layers under given transforms" system.
- **Differential zoom between cat lanes.** Rejected: apparent-size change between
  near-equal characters reads as a status change; the inter-cat effect is pan-only.

## Validation

- Unit + generative property tests on the depth-matrix math (finiteness, the
  `[1, zoom]` bound, depth-monotonicity); a `ParallaxLayer` decorator test; a
  scene test asserting the coarse planes (one shared background depth, a nearer
  stage, the farthest jet); a behavioural test that a lateral truck shears the
  trio (left gap widens, right narrows, equally). Full suite green at 100% line
  coverage.
- Artistic sign-off: captured stage frames reviewed by a panel (cinematography,
  2D-animation art direction, motion graphics) against this ADR's intent.
