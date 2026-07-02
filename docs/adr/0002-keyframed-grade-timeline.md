# ADR 0002 — Keyframed colour-grade timeline (per-layer looks over the clip)

- **Status:** Accepted (rev 2 — expert-panel feedback folded in; see §Panel review)
- **Date:** 2026-07-02
- **Deciders:** dancing_cats rendering + demo tooling
- **Tags:** grading, timeline, keyframes, DAW-UX, persistence, LLM-authoring

## Context

PR #12 added an in-app ASC CDL grading console — three 3-way wheels
(Lift/Gamma/Gain), white balance, contrast/pivot, saturation, a transfer-curve
scope and an image-derived RGB parade — driving a single `BackdropGrade`
applied as one SOP+S shader pass over the composited backdrop.

That console has four structural limits:

1. **It is static.** One global wheel state for the whole song. A look cannot
   evolve with the music — no "the scene slides toward sunset and dims a touch
   over the clip", no chorus lift, no bridge cool-down.
2. **It is monolithic.** One grade for the entire painted world. A colourist
   cannot warm just the deck glow, pull the drone show down half a stop, or
   desaturate the city lights — there is no per-layer control, even though the
   scene is already an ordered stack of layers.
3. **It grades only the backdrop.** The cats, the stage-light pools and the
   grain overlay are outside the pass, so "dim the scene" leaves the performers
   glowing at full brightness — the exact artefact a scene-wide grade exists to
   avoid.
4. **It is ephemeral and always-on.** Wheel state lives in a `State` object —
   closing the app loses the look; nothing another tool (or an LLM) can read or
   write. And the console row renders permanently below the transport even when
   nobody is grading, costing height and paint.

The demo already has a persistence idiom for exactly this shape of data: the
offline-computed **side files** next to the beat map (`moving.json`,
`moving.words.json`, `moving.cues.json`) — plain JSON, loaded by small pure
parsers, written by tools/humans/LLMs, never by the render loop. The beat map
is the shared clock: everything on the transport timeline is addressed in
`*_sec` seconds.

Constraints carried over from ADRs/PRs past:

- **Live == offline.** The export paths (`DANCE_RENDER_ONLY`, X11 capture, and
  `DANCE_APP_EXPORT`, exact-frame) pump the live widget at audio positions —
  whatever the live stage renders at time *t* is what exports.
- **The scenery feature stays ejectable and camera/demo-agnostic** — it must
  not import the character/demo feature.
- **The baked-twin constraint (ADR 0001):** the painted base plate has the
  skyline, yacht and deck baked in, and the scene re-draws those structures as
  separate layers purely for depth ordering. Anything that treats a re-draw
  differently from its baked twin re-exposes the double.
- **100% line coverage on tested units, generative (glados) tests for pure
  models, zero analyzer warnings.**

## Decision

Introduce a **keyframed grade timeline**: a per-song JSON side file holding
grade **lanes** (master + named targets), each a sparse list of **keyframes**
in wheel-space with an interpolation curve per segment; a runtime that
evaluates the document at the audio position every frame and feeds per-target
CDL passes in a **declared node order**; and a **DAW-style authoring
workspace** sharing one zoomable timeline with the waveform and the true
detected beat grid. The console (wheels + scopes) becomes the *editor of the
selected lane at the playhead* rather than a free-floating global state.

### 1. The document: `<track>.grade.json`, wheel-space, seconds

A new side file next to the beat map (`assets/sample_track/moving.grade.json`;
override with `DANCE_GRADE`). Schema v1:

```json
{
  "version": 1,
  "lanes": [
    {
      "target": "master",
      "enabled": true,
      "keyframes": [
        {
          "t_sec": 0.0,
          "interp": "smooth",
          "look": {
            "lift":  { "x": 0.0, "y": 0.0, "m": 0.0 },
            "gamma": { "x": 0.0, "y": 0.0, "m": 0.0 },
            "gain":  { "x": 0.0, "y": 0.0, "m": 0.0 },
            "saturation": 1.0,
            "temperature": 0.0,
            "tint": 0.0,
            "contrast": 1.0,
            "pivot": 0.435
          }
        }
      ]
    }
  ]
}
```

- **Values are wheel-space (`GradeLook`), not raw CDL.** Wheel-space is the
  console's own vocabulary (puck x/y in −1..1, masters in −1..1, the familiar
  slider ranges), it round-trips pixel-exactly into the UI, it interpolates
  tastefully (the sensitivity mapping in `gradeFromWheels` maps the gamma wheel
  through `2^(−delta)`, so lerping wheel values interpolates the power exponent
  geometrically — the perceptually right gamma path — and every in-between
  frame stays inside the tuned range), and it is the language an LLM prompt
  naturally speaks ("push gain toward orange 0.15, master −0.05"). The true
  Slope/Offset/Power numbers remain visible in the console readouts, derived
  per frame through the existing `gradeFromWheels`.
- **Keyframe times are seconds**, the same `*_sec` vocabulary as every other
  side file. The UI *snaps* to detected beats/half-beats and section
  boundaries on input when the magnet is on, but storage stays in seconds so
  re-running beat detection can never silently move an authored look.
- **Omitted look fields inherit from the previous keyframe in the lane**
  (time order; the first keyframe inherits from neutral). *Panel-revised:*
  the draft's "omitted = neutral" rule meant a minimal LLM edit like
  `{"t_sec": 30, "look": {"saturation": 0.8}}` silently animated every other
  parameter back to neutral — the opposite of author intent. Inheritance keeps
  sparse authoring honest: unmentioned parameters hold their course. The app
  itself always **writes full looks**, so files the UI saves are explicit and
  diff-friendly; sparseness is an input convenience only.
- **Parsed values are clamped to console ranges** (puck radius ≤ 1, masters
  ±1, saturation 0..2, contrast 0.5..1.8, pivot 0.2..0.7, temp/tint ±1), so a
  hand- or LLM-typed `{"gain": {"m": 10}}` cannot blow out the image live
  through the file watcher.
- A lane with a single keyframe is a **static look** for that target (constant
  extrapolation both sides) — how "I dialled something in and keyed it once"
  persists.

Dart model: `lib/features/scenery/model/grade_timeline.dart` — `GradeLook`
(the eight console fields + lerp + JSON + deviation norm), `GradeKeyframe`
(`tSec`, `interp`, `look`), `GradeLane` (`target`, `enabled`, sorted keyframes,
evaluate + edit primitives), `GradeTimelineDoc` (`lanes`,
`evaluate(tSec) → Map<String, GradeLook>`). Pure, immutable, no Flutter
imports beyond `Offset` — glados-testable. The model lives in the scenery
feature; the *file IO* (loader/saver/watcher) lives with the other side-file
loaders in the demo feature, keeping scenery ejectable.

### 2. Interpolation: named curves per segment

Each keyframe carries the curve of the segment **leaving** it:

| `interp`  | meaning                                             |
| --------- | --------------------------------------------------- |
| `hold`    | step — value holds until the next key (beat cuts)   |
| `linear`  | straight lerp                                       |
| `smooth`  | cosine ease-in-out (default; broadcast-safe)        |
| `easeIn`  | accelerating                                        |
| `easeOut` | decelerating                                        |

These reuse the character engine's `Ease` vocabulary where the names overlap.
The overshoot curves (`*Back`) are deliberately excluded: a grade that
overshoots produces a visible colour pump; anticipation is for limbs, not
looks. Components interpolate independently in wheel-space; pucks lerp in x/y
(not polar), so a puck animated through centre crosses neutral instead of
whipping around the hue circle. Outside the keyframed range the edge value
extrapolates as a constant.

*Panel note (colorist):* `smooth` has zero derivative at both ends of every
segment, so a *continuous* multi-key ramp (the sunset use case) stalls and
re-accelerates at each key — a breathing cadence. Authoring guidance (and the
shipped sample): use `linear` on the interior keys of a continuous evolution;
`smooth` is for isolated transitions. A C1 monotone spline (`spline`) is the
named follow-up if breathing shows up in review; cubic-bezier handles stay
rejected (curve-editor UI, not LLM-writable).

### 3. Targets and the grade node graph

A lane's `target` is a stable string id. **v1 exposes only cleanly separable
targets:**

- **`master`** — the whole stage composite: backdrop, haze band, stage-light
  pools **and the cats** — excluding captions *and excluding the grain
  overlay* (grain is finishing texture; grading it would make film grain pump
  with every animated look change, so it composites after the master pass).
  Implemented as a final CDL pass over the stage subtree via an offscreen
  capture (paint the subtree into an `OffsetLayer`, `toImageSync` at the
  surface's device pixel ratio, draw through the grade shader). This *changes
  master's meaning* from "backdrop only" to "the scene": dimming the scene now
  dims the performers, and the RGB parade finally measures what master does.
- **`backdrop`** — the painted-world composite (exactly today's pass), for
  looks that must not touch the cats or the light pools.
- **`cast`** — the trio, graded at the character-painter level (its output
  composited offscreen through the same shader).
- **Separable scenery layers** — ids on the scene's layer wrappers:
  `clouds-far`, `clouds-mid`, `clouds-near`, `jet`, `ocean`, `city-lights`,
  `haze`, `deck-glow`, `police`, `drones-sky`, `drones-launch`, `vignette`.

**Excluded from v1: the baked-twin re-draws** (`base-plate`, `skyline`,
`yacht`, `deck`). *Panel-revised:* ADR 0001 exists because those structures
are baked into the base plate *and* re-drawn on top; grading one copy
independently produces ungraded rim halos at every feathered silhouette edge —
the chromatic analogue of the doubled yacht. Until a de-baked art pass exists,
world-level looks belong on `backdrop`/`master`. The ADD TRACK picker simply
does not offer the twinned ids.

**Blend-aware grade policy.** The overlay layers are premultiplied-alpha; the
light passes (`city-lights`, `deck-glow`, `police`, `drones-*`, `ocean`'s
additive shimmer) are additive, where black = no contribution. A non-zero
Offset on an additive layer lifts black into a full-frame wash. Policy:
per-layer passes un-premultiply → grade → re-premultiply where α > 0, and
**additive targets ignore Offset** (slope/power/saturation only — the controls
that make sense on a light pass). The opaque `backdrop`/`master` composites
keep the existing shader.

**Node order (normative).** CDL passes do not commute, so the composed result
is pinned and covered by a painter test:

```
per-layer passes (inside the stack, each on its own offscreen)
  → backdrop composite pass (background layers as one image)
    → cast pass (the trio's painter output)
      → master pass (whole stage; grain + captions composite after)
```

Master re-grades everything beneath it, by design (it is the finishing node).
The same document therefore renders identically across refactors — the one
property a grade file must have.

Plumbing: `BackdropContext` grows an optional `gradeForTarget(String id)`
callback + the grade program; a layer wrapper consults it for its own id. The
scenery feature only ever sees *ids and grades* — it stays ejectable; the demo
page owns which document supplies them.

### 4. Runtime evaluation and the editing model

Every frame the page evaluates the doc at the audio position (binary search +
one lerp per lane — trivially 60 fps). The console is a **view/editor of the
selected lane at the playhead**, with one rule for the edit target:

- **Clicking a keyframe moves the playhead to it.** Edit target and displayed
  frame always coincide — wheels never show a look the stage isn't rendering.
  When the playhead moves on its own, selection drops back to "lane at
  playhead".
- Not interacting → the wheels *follow* the evaluated values (automation
  readouts).
- Interacting → **absolute-touch**: the baseline freezes at grab (the wheels
  stop following while held) and the dragged state applies live to that
  target. On release with **auto-key** (default ON, visible toggle):
  - *paused* → stamp/update one keyframe at the playhead;
  - *playing* → the gesture wrote a throttled **touch trail**; on release the
    trail **replaces every pre-existing key inside the touched span** and is
    **thinned** (Ramer–Douglas–Peucker in wheel-space, tolerance below visible
    grade difference) so a ridden 8-bar automation stays editable and the JSON
    stays LLM-readable.
  - Every auto-stamp flashes the new diamond + a transient "keyed @ m:ss.mmm"
    note, so accidental writes are noticed while undo is cheap.
- Auto-key OFF → the edit is a **sticky unkeyed preview**: it survives seeks
  and playback (an absolute override on that lane), shows an UNKEYED badge on
  the lane header and console, and is dropped only by Esc/revert or replaced
  by ● KEY. *Panel-revised:* the draft discarded it on seek — a data-loss trap
  in the most reflexive gesture the tool has.
- A lane with no keyframes evaluates to neutral; the first touch under
  auto-key creates its first keyframe — nothing dialled is ever silently lost.
- **Undo/redo** (Ctrl+Z / Ctrl+Shift+Z): one *gesture* (wheel ride, key drag,
  slider scrub, context-menu action, external reload) = one undo transaction.
- Bypass keeps its meaning (feed the stage identity while the panel keeps
  state); each lane has an **enable** toggle (automation-lane mute). Export
  paths force bypass off and resolve/ignore unkeyed previews, logging loudly —
  a forgotten toggle must not silently export the clean plate.

### 5. Persistence and the LLM round-trip

- **Save:** any document mutation schedules a debounced (~600 ms) atomic write
  (temp file + rename). Before the session's first overwrite, the store copies
  the existing file to `<file>.bak` — one known-good checkpoint per session.
- **Watch:** the store polls the file's mtime (~1 s). An external change with
  no pending local edit hot-reloads live — the LLM edits JSON, the app
  reflects it at once; the human drags a wheel, the file updates for the LLM
  to read back. A reload is **announced** (transient "reloaded from disk"
  note) and enters the undo stack as one step (Ctrl+Z restores the pre-LLM
  document — the conflict-resolution affordance).
- **Corrupt input never destroys work.** *Panel-revised:* the draft's "parse
  failure → empty doc" would let one malformed LLM write hot-reload an empty
  document that the next autosave burns over the real file. Now: parse failure
  keeps the last good document in memory, surfaces a visible error badge
  ("grade file unreadable — showing last good"), and **suppresses autosave**
  until the file parses again or the user explicitly re-saves.
- Conflict policy stays last-writer-wins (single-user dev tool), but not
  *silent*: if an external change lands during a pending local edit and gets
  overwritten, the store surfaces an "external change overwritten" note.

### 6. The authoring UI

**Compact (default).** The wheels/scopes row is *gone* — replaced by a GRADE
toggle in the transport's toggle cluster (above the waveform). The transport
waveform drops to half height (112 → 56 px). The grade document still applies
to the stage while the workspace is closed (live == offline demands it) — so
the GRADE toggle **lights up whenever the loaded document is non-neutral**,
the visibility hook for "why does my scene look dim?". Zero *UI* cost when
closed; the grading passes themselves cost the same open or closed.

**Expanded (GRADE on).** The transport's own timeline row is **replaced** by
the workspace's shared timeline (one seek surface, no competing waveforms);
the transport keeps its control/readout row. Layout:

```
┌──────────────────────────── stage (≥ ~45% of window height) ───────────────┐
├──────────────────────────────── transport row ─────────────────────────────┤
│ overview strip: whole track + draggable view-range brush                   │
│ ruler (drag = SCRUB) ─ section pills ────────────── (one shared x-axis)    │
│ waveform (seek)                                                            │
│ BEATS lane: detected beats — ticks; downbeats accented + bar numbers       │
│ ── MASTER   ◆────────◆──────◆──── keyframes + deviation sparkline ──       │
│ ── deck-glow ◆──◆                 (lanes on demand via ADD TRACK;          │
│ ── cast         ◆───────◆          > N lanes scroll internally)            │
├──────────── console: wheels (enlarged, relative drag) + scopes ────────────┤
```

- **One shared x-axis** for everything; zoom zooms all lanes together.
  Bindings follow twenty years of muscle memory: **ruler drag scrubs the
  playhead**; Ctrl+scroll zooms about the cursor; horizontal/Shift+scroll and
  middle-drag pan; the overview brush drags/resizes the visible range; FIT
  resets. Playhead follow is **page-flip**, suspended by any manual pan or
  active drag, re-engaged on play/seek.
- **The beat lane renders the *detected* grid** (`BeatMap.beatTimesSec` +
  downbeats), not a nominal-BPM approximation — at high zoom the ticks sit
  where Beat This! heard them, which is where keyframes snap (beats,
  half-beats via `timeAtBeat(k + ½)`, and section boundaries). The transport's
  BAR n.b readout is driven from the same `BeatMap` so the two never disagree.
- **Lanes on demand:** a fresh document shows MASTER only; ADD TRACK lists the
  remaining v1 targets. Track headers carry name, enable (mute), selection,
  and a context menu (clear keys / remove lane). Lane height is fixed
  (~36 px); beyond ~3 visible lanes the lane area scrolls internally — the
  stage never shrinks below its floor.
- **Keyframe interactions:** click selects **and moves the playhead to the
  key**; drag moves in time (snap magnet; Alt bypasses; dragging past a
  neighbour clamps to it minus epsilon); **Delete/Backspace deletes the
  selection; right-click opens a context menu** — Remove key, the five interp
  curves, Copy look, Paste look — so the destructive action sits behind a
  menu, the way every NLE/DAW does, while "right-click → Remove" stays a
  two-hundred-millisecond gesture. Shift-click multi-selects; a group drag
  moves the set. Double-click on empty lane space adds a key at that time
  with the lane's evaluated look. ←/→ nudge the selection by a beat
  (Shift = fine), Esc drops selection/preview.
- **Wheels enlarge** in the workspace (≈120 px) and gain **relative drag**
  (drag anywhere on the wheel moves the puck by the delta, Shift = fine) —
  the trackball behaviour every grading surface uses — replacing the absolute
  jump-to-cursor mapping that makes small pucks unusable.
- Each lane paints a **deviation sparkline**: a norm over *all* look fields
  (≈1 at full deflection of any single control), not just luma — a
  saturation-only ride must not read dead-flat. *Panel-revised.*

Sizing target: comfortable at the demo's native 1600×900 (stage keeps ≥ ~45%
of window height; the workspace scrolls internally past that) and luxurious on
4K; the stage springs back to full height when the workspace closes.

### 7. Testing & validation

- Model: 100% line coverage; glados generative round-trips (doc → JSON → doc),
  evaluation invariants (constant outside range, exact at keys, bounded
  between keys), **inheritance semantics** (a sparse second key holds
  unmentioned fields) and **clamping** of out-of-range input.
- Store: temp-dir tests for save/load/watch/hot-reload, the corrupt-file
  path (last-good retained, autosave suppressed), `.bak` creation.
- Runtime: painter tests pinning the node order, neutral-skip, the premul and
  additive-policy variants; a widget test for the master pass; a measured
  frame-time check for the master capture at 1600×900 before merge (the
  parade sampler is throttled — it is *not* the proof).
- UI: widget tests keyed like the existing console/transport suites (toggle,
  lanes, add/move/multi-select/delete, context menu, curve set, snap, zoom
  math extracted pure, sticky preview, undo transactions).

## Panel review

A four-expert design panel (senior colorist; video editor/finisher; DAW
automation UX specialist; pro-tool interaction designer) reviewed rev 1
grounded in this repo's code. Scores: **7.5 / 7 / 7 / 7** — architecture
endorsed (wheel-space keyframing, seconds + snap-on-input, x/y puck lerps, no
overshoot curves, lanes-on-demand, compact-by-default), with convergent
majors, all folded into rev 2:

| # | Finding (panel) | Resolution |
|---|---|---|
| 1 | Omitted-field = neutral silently animates looks toward identity (all four flagged it) | Inherit-from-previous-key semantics; app writes full looks (§1) |
| 2 | No clamping of hand-written values | Parse-time clamps to console ranges (§1) |
| 3 | Grade node order unspecified → irreproducible documents | Normative order + painter test (§3) |
| 4 | Additive light passes: Offset lifts black into a wash | Additive targets ignore Offset (§3) |
| 5 | Baked-twin layers as targets re-expose ADR 0001's double, in colour | Twinned ids excluded from v1 (§3) |
| 6 | Bare right-click delete violates muscle memory; single-key-only editing | Context menu + Delete key + shift multi-select + copy/paste look (§6) |
| 7 | Unkeyed preview discarded on seek = data loss | Sticky preview + badge + Esc (§4) |
| 8 | Selected-key vs playhead edit-target ambiguity | Click-key-moves-playhead rule (§4) |
| 9 | Touch trail: overwrite semantics + key spam | Replace-span + RDP thinning + one undo transaction per gesture (§4) |
| 10 | Corrupt external write → empty doc → autosave destroys file | Last-good + error badge + autosave suppression + `.bak` (§5) |
| 11 | Ruler-drag-pans inverts scrub convention; no navigator | Ruler scrubs; overview brush; scroll/middle-drag pans (§6) |
| 12 | Hidden active grade in compact mode | GRADE toggle lights when doc non-neutral (§6) |
| 13 | No vertical budget → viewer starves | Stage floor ≥ ~45%, fixed lane height, internal lane scroll (§6) |
| 14 | Grain graded under master pumps with look changes | Grain composites after the master pass (§3) |
| 15 | Two disagreeing bar-number systems | Transport BAR readout driven from `BeatMap` (§6) |
| 16 | Master-pass cost asserted, not measured | Measured frame-time check gate before merge (§7) |

Deferred, recorded here so they stay visible: `spline` interp for continuous
ramps; marquee selection; typed numeric entry on readouts; scope-selected-
target mode; loop-range audition; CDL (.ccc) export as a derived artifact.

### Screenshot review of the shipped UI

After implementation, the same four disciplines re-reviewed the *running
app* from real captures (compact + expanded, zoomed, menus, auto-key, live
playback frames driven via XTEST on a headless display):

- **Round 1: 7.5 / 7.5 / 7.5 / 7.5.** Converged fixes landed: scopes gained
  graticules and moved to the stage pillarbox at measuring size (RESPONSE
  draws neutral white while channels coincide); additive lanes dim their
  Lift wheel ('offset ignored'); the deviation sparkline became legible at
  subtle grades; every row clips to the shared viewport; beat-lane
  level-of-detail; larger diamonds with a distinct selected state and an
  at-the-diamond auto-key flash; key-state chip on the console; context
  menus reordered (destructive last) with copy/paste look; empty-lane
  hints; M-chip lane mute; true-neutral slider fills; a fixed-height
  workspace layout; compact-bar fixes.
- **Round 2: 8.5 / 8 / 8.5 / 7.5 (avg 8.1).** Residuals fixed: the parade
  histogram now excludes the letterbox matte (bit-exact black) and draws
  log-scaled distributions — it measures the picture; scopes name the lane
  they read; truthful before-first/after-last hold chips; the t=0 INTRO
  chip.
- **Round 3 (focused re-verify, colorist + UX): both signed off ≥ 8.**

The master-pass budget gate (§7): during the capture sessions the release
app sustained real-time playback at 1600×900 with the master + per-layer
passes active (audio-position delta ≈ wall-clock delta across captured
frames, no visible jank in consecutive stills).

## Alternatives considered

- **Store raw CDL per keyframe.** Rejected: interpolating power exponents and
  reconstructing wheel positions from CDL is lossy and unintuitive; the UI and
  LLM both think in wheel-space. CDL stays a derived readout.
- **Per-parameter automation channels** (one sparse key list per look field,
  the classic DAW model). Considered at panel prompting: it is the most
  correct automation representation, but it multiplies the lane UI by eight,
  makes whole-look A/B and copy/paste harder, and the snapshot-keyframe model
  with inheritance semantics covers the real authoring patterns here (looks
  evolve as looks). Revisit only if per-field editing pain shows up in use.
- **Beat-indexed keyframe times.** Rejected: re-running beat detection would
  silently re-time an authored look. Seconds + snap-on-input gives the same
  authoring feel with stable storage.
- **Grade every layer via `ColorFilter.matrix`.** Rejected: CDL's power and
  saturation terms are non-linear; a 4×5 matrix cannot express them, and two
  grade models would drift.
- **A single always-visible wheels+timeline surface.** Rejected: the request
  is explicit that the default view is compact with an opt-in toggle.
- **Cubic-bezier curve handles per segment.** Rejected for v1: named curves
  cover the shipping need, keep the JSON LLM-writable, and avoid a curve-
  editor UI.

## Consequences

- Each *active* (non-neutral at this instant) target costs one offscreen
  composite + one shader pass per frame. Neutral lanes cost nothing. The
  master pass is the expensive one and is gated on a measured frame-time
  check; if it misses at 4K, the fallback is documented (prefer the
  exact-frame export path while a master lane is active).
- Master's meaning changes (backdrop-only → whole stage). The old behaviour
  remains available as the `backdrop` target. Exports pick the grade up for
  free because both export paths render the live widget at audio positions.
- The film-strip/frame-composer test path renders ungraded unless it opts in
  by supplying a document — grading is a demo-page concern; the live/offline
  contract is carried by the widget-pumping exporters.
- A new authoring surface becomes the largest widget in the demo, but ships
  behind the GRADE toggle: the default experience is *lighter* than before
  (the always-on console row disappears, the waveform halves).
