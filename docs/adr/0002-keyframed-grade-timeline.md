# ADR 0002 — Keyframed colour-grade timeline (per-layer looks over the clip)

- **Status:** Proposed (panel review pending)
- **Date:** 2026-07-02
- **Deciders:** dancing_cats rendering + demo tooling
- **Tags:** grading, timeline, keyframes, DAW-UX, persistence, LLM-authoring

## Context

ADR-adjacent history: PR #12 added an in-app ASC CDL grading console — three
3-way wheels (Lift/Gamma/Gain), white balance, contrast/pivot, saturation, a
transfer-curve scope and an image-derived RGB parade — driving a single
`BackdropGrade` applied as one SOP+S shader pass over the composited backdrop.

That console has four structural limits:

1. **It is static.** One global wheel state for the whole song. A look cannot
   evolve with the music — no "the scene slides toward sunset and dims a touch
   over the clip", no chorus lift, no bridge cool-down.
2. **It is monolithic.** One grade for the entire painted world. A colourist
   cannot warm just the deck, pull the yacht down half a stop, or desaturate
   the drone show — there is no per-layer control, even though the scene is
   already an ordered stack of named-in-code layers.
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
- **100% line coverage on tested units, generative (glados) tests for pure
  models, zero analyzer warnings.**

## Decision

Introduce a **keyframed grade timeline**: a per-song JSON side file holding
grade **lanes** (master + named layer targets), each a sparse list of
**keyframes** in wheel-space with an interpolation curve per segment; a runtime
that evaluates the document at the audio position every frame and feeds
per-target CDL passes; and a **DAW-style authoring workspace** that shares one
zoomable timeline with the waveform and the true detected beat grid. The
console (wheels + scopes) becomes the *editor of the selected lane at the
playhead* rather than a free-floating global state.

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
  tastefully (the sensitivity mapping in `gradeFromWheels` keeps every
  in-between frame inside the tuned range — interpolating raw power exponents
  can't drift out of bounds because raw power is never stored), and it is the
  same language an LLM prompt naturally speaks ("push gain toward orange 0.15,
  master −0.05"). The true Slope/Offset/Power numbers remain visible in the
  console readouts, derived per frame through the existing `gradeFromWheels`.
- **Keyframe times are seconds**, the same `*_sec` vocabulary as every other
  side file. The UI *snaps* to detected beats/bars on input when the magnet
  toggle is on, but storage stays in seconds so re-running beat detection can
  never silently move an authored look.
- **Sparse-friendly:** any omitted `look` field defaults to its neutral value,
  so a hand- or LLM-written file stays minimal.
- A lane with a single keyframe is a **static look** for that target (constant
  extrapolation on both sides), which is exactly how "I dialled something in
  and pressed key once" persists.

Dart model: `lib/features/scenery/model/grade_timeline.dart` — `GradeLook`
(the eight console fields + `lerp` + JSON), `GradeKeyframe` (`tSec`, `interp`,
`look`), `GradeLane` (`target`, `enabled`, sorted keyframes), and
`GradeTimelineDoc` (`lanes`, `evaluate(tSec) → Map<String, GradeLook>`).
Pure, immutable, no Flutter imports beyond `Offset` — glados-testable. The
model lives in the scenery feature (it is a grading concept); the *file IO*
(loader/saver/watcher) lives with the other side-file loaders in the demo
feature, keeping scenery ejectable.

### 2. Interpolation: named curves per segment

Each keyframe carries the curve of the segment **leaving** it:

| `interp`  | meaning                                             |
| --------- | --------------------------------------------------- |
| `hold`    | step — value holds until the next key (cuts)        |
| `linear`  | straight lerp                                       |
| `smooth`  | cosine ease-in-out (the default; broadcast-safe)    |
| `easeIn`  | accelerating                                        |
| `easeOut` | decelerating                                        |

These reuse the character engine's `Ease` vocabulary (`easing.dart`) where the
names overlap — one easing language across the repo. The overshoot curves
(`*Back`) are deliberately excluded: a grade that overshoots produces a visible
colour pump; anticipation is for limbs, not for looks. Components interpolate
independently in wheel-space; pucks lerp in x/y (not polar), so a puck animated
through centre crosses neutral instead of whipping around the hue circle.
Outside the keyframed range the edge value extrapolates as a constant. Cubic
bezier handles are deferred — five named curves cover the current need and stay
trivially LLM-writable.

### 3. Targets: master, the named layers, the cast

A lane's `target` is a stable string id:

- **`master`** — the whole stage composite: backdrop, haze band, stage-light
  pools, grain overlay **and the cats**, excluding captions. Implemented as a
  final CDL pass over the stage subtree via an offscreen capture (the
  `SnapshotWidget` technique: paint the subtree into an `OffsetLayer`,
  `toImageSync`, draw through the grade shader). This *changes master's
  meaning* from "backdrop only" to "the scene", fixing limit (3): dimming the
  scene now dims the performers. The RGB parade already samples the whole
  stage, so the scope finally measures what master actually does.
- **`backdrop`** — the painted world composite (exactly today's pass), kept as
  its own target for looks that must not touch the cats or the light pools.
- **Per-layer ids** — every layer in `BackdropScene.blueHourWaterfront()` gets
  a stable id on its `ParallaxLayer` wrapper: `base-plate`, `clouds-far`,
  `clouds-mid`, `clouds-near`, `jet`, `ocean`, `skyline`, `yacht`,
  `city-lights`, `haze`, `deck`, `deck-glow`, `police`, `drones-sky`,
  `drones-launch`, and `vignette` (foreground). A per-layer pass composites
  that one layer offscreen and grades it before it lands in the stack; only
  targets whose *evaluated grade at this instant* is non-neutral pay the cost.
- **`cast`** — the trio, graded at the painter level (the character painter's
  output composited offscreen and passed through the same shader), so a
  colourist can hold the cats while the world shifts — or vice versa.

Plumbing: `BackdropContext` grows an optional `gradeForTarget(String id)`
callback + the grade program; `ParallaxLayer` consults it for its own id.
The scenery feature only ever sees *ids and grades* — it stays ejectable; the
demo page owns which document supplies them.

**Premultiplied-alpha caveat (correctness):** the overlay layers are
premultiplied-alpha images. Grading premultiplied RGB with a non-zero Offset
would tint fully-transparent pixels (haloing). The per-layer pass therefore
uses a shader variant that un-premultiplies (where α > 0), grades, and
re-premultiplies. The backdrop/master composites are opaque and keep the
existing shader.

### 4. Runtime evaluation and the editing model

Every frame the page evaluates the doc at the audio position (`evaluate` is a
binary search + one lerp per lane — trivially 60 fps). The console becomes a
**view/editor of the selected lane at the playhead**:

- Not interacting → the wheels *follow* the evaluated values (they animate
  with playback, like automation readouts in a DAW).
- Interacting → the dragged state applies live to that target (instant visual
  feedback), and on release **auto-key** (default ON, with a visible toggle)
  stamps/updates a keyframe at the playhead; while *playing*, a continuous
  drag stamps a throttled trail (touch-automation style). Auto-key OFF → the
  edit is a live preview flagged "unkeyed"; the ● KEY button stamps it
  explicitly, seeking away discards it.
- A lane with no keyframes evaluates to neutral; the first touch under
  auto-key creates its first keyframe — nothing a user dials is ever silently
  lost.
- **Undo/redo** (Ctrl+Z / Ctrl+Shift+Z) over document mutations — table stakes
  for an authoring surface; the docs are tiny, so an immutable-snapshot stack
  is enough.
- Bypass keeps its meaning (feed the stage identity while the panel keeps
  state); each lane also has an **enable** toggle (mute one lane like muting
  an automation lane).

### 5. Persistence and the LLM round-trip

- **Save:** any document mutation schedules a debounced (~600 ms) atomic write
  (temp file + rename) to the grade path. No explicit save button to forget.
- **Watch:** the store polls the file's mtime (~1 s). An external change with
  no pending local edit hot-reloads the document live — so a human and an LLM
  can genuinely alternate: the LLM edits JSON, the app reflects it at once;
  the human drags a wheel, the file updates for the LLM to read back.
  Conflict policy is last-writer-wins (single-user dev tool; no merge).

### 6. The authoring UI

**Compact (default).** The wheels/scopes row is *gone* — replaced by a GRADE
toggle in the transport's toggle cluster (above the waveform, as requested).
The transport waveform drops to half height (112 → 56 px). Zero grading cost
when the workspace is closed.

**Expanded (GRADE on).** A workspace opens between the transport bar and the
console:

```
┌────────────────────────────── stage (shrinks) ─────────────────────────────┐
├─────────────────────────────── transport row ──────────────────────────────┤
│ ruler ─ section pills ─────────────────────────────── (one shared x-axis) │
│ waveform (seek)                                                            │
│ BEATS lane: true detected beats — ticks; downbeats accented + bar numbers  │
│ ── MASTER   ◆────────◆──────◆───────── keyframes + value sparkline ──      │
│ ── deck     ◆──◆                        (lanes added via ADD TRACK)        │
│ ── cast         ◆───────◆                                                  │
├───────────── console: wheels (enlarged) + sliders + scopes ────────────────┤
```

- **One shared x-axis** for ruler, markers, waveform, beats and every grade
  lane — zooming zooms all of them together. Ctrl+scroll zooms about the
  cursor; drag on the ruler pans; a FIT button resets; the view auto-follows
  the playhead during playback.
- **The beat lane renders the *detected* grid** (`BeatMap.beatTimesSec` +
  downbeats), not the nominal-BPM approximation the old bar grid drew — at
  high zoom the ticks sit exactly where Beat This! heard them, which is where
  keyframes snap. Downbeats get taller accents and bar numbers.
- **Lanes on demand** (the DAW automation-lane pattern): a fresh document
  shows MASTER only; an ADD TRACK picker lists the remaining targets. Track
  headers carry name, enable, and selection; the selected lane is what the
  console edits.
- **Keyframe interactions:** click selects (console loads that key's look);
  drag moves in time (beat-snap magnet toggle; Alt bypasses); **right-click
  deletes**; double-click on empty lane space adds a key at that time with the
  lane's evaluated look; the selected key shows a curve chip cycling
  HOLD / LINEAR / SMOOTH / EASE IN / EASE OUT.
- **Wheels enlarge** in the workspace (≈120 px) and gain **relative drag**
  (drag anywhere on the wheel moves the puck by the delta, Shift = fine),
  replacing the absolute jump-to-cursor mapping that makes small pucks
  unusable — the trackball behaviour every grading surface uses.
- Each lane paints a **sparkline of its value over time** (luma-ish summary:
  the look's overall lift/gain deviation) so "something changes here" is
  visible without selecting the lane.

Sizing target: comfortable on a 16-inch MacBook window (~1600×900, the demo's
native size) and luxurious on 4K; the stage shrinks while the workspace is
open (the grading posture — Resolve does the same) and springs back when
closed.

### 7. Testing

- Model (`grade_timeline.dart`): 100% line coverage; glados generative
  round-trip (doc → JSON → doc), evaluation invariants (constant outside the
  range, exact at keys, bounded between keys for monotone curves).
- Store: temp-dir tests for save/load/watch/hot-reload and corrupt-file
  degradation (parse failure → empty doc, never a crash).
- Runtime: painter tests for per-target passes (neutral skips, non-neutral
  grades, premul variant), master-pass widget test.
- UI: widget tests keyed like the existing console/transport suites (toggle,
  lanes, keyframe add/move/delete via right-click, curve cycling, zoom math
  extracted pure).

## Alternatives considered

- **Store raw CDL per keyframe.** Rejected: interpolating power exponents and
  reconstructing wheel positions from CDL is lossy and unintuitive; the UI
  and LLM both think in wheel-space. CDL stays a *derived* readout.
- **Beat-indexed keyframe times.** Rejected: re-running beat detection would
  silently re-time an authored look. Seconds + snap-on-input gives the same
  authoring feel with stable storage.
- **Grade every layer via `ColorFilter.matrix`.** Rejected: CDL's power and
  saturation terms are non-linear; a 4×5 matrix cannot express them, and two
  grade models (matrix vs shader) would drift.
- **A single "wheels + timeline always visible" surface.** Rejected: the
  console is heavy; the request is explicit that the default view is compact
  with an opt-in toggle.
- **Cubic-bezier curve handles per segment.** Deferred: five named curves
  cover the shipping need, keep the JSON LLM-writable, and avoid a whole
  curve-editor UI in v1.

## Consequences

- Each *active* (non-neutral at this instant) target costs one offscreen
  composite + one shader pass per frame. Neutral lanes cost nothing; the
  common closed-workspace state costs exactly today's price. This is a desktop
  dev tool; the budget is acceptable and measured, not guessed — the parade
  sampler already exercises the same capture path.
- Master's meaning changes (backdrop-only → whole stage). The old behaviour
  remains available as the `backdrop` target. Exports pick the grade up for
  free because both export paths render the live widget at audio positions.
- The film-strip/frame-composer test path renders ungraded unless it opts into
  supplying a document — acceptable: grading is a demo-page concern, and the
  live/offline contract is carried by the widget-pumping exporters.
- A new authoring surface (workspace) becomes the largest widget in the demo;
  it ships behind the GRADE toggle, so the default experience is *lighter*
  than before (the always-on console row disappears).
