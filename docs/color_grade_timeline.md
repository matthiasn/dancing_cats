# The colour-grade timeline file (`<track>.grade.json`)

The dance demo's colour grade is a **keyframed timeline** persisted as a JSON
side file next to the beat map — `moving.json` → `moving.grade.json`
(override with the `DANCE_GRADE` env var). It is designed to be written by
**both** the in-app grading workspace *and* a human or LLM in a text editor:
the app watches the file and hot-reloads external edits live (an in-app toast
announces the reload, and Ctrl+Z reverts it); in-app edits autosave back
within ~600 ms. See ADR 0002 for the architecture.

## Schema (v1)

```json
{
  "version": 1,
  "lanes": [
    {
      "target": "master",
      "enabled": true,
      "keyframes": [
        {
          "t_sec": 42.4,
          "interp": "linear",
          "look": {
            "lift":  { "x": 0.0, "y": 0.0, "m": 0.0 },
            "gamma": { "x": 0.0, "y": 0.0, "m": 0.0 },
            "gain":  { "x": 0.0, "y": 0.0, "m": -0.02 },
            "saturation": 1.0,
            "temperature": 0.06,
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

### Lanes and targets

One lane per grade **target**. Valid targets:

| target | grades |
| --- | --- |
| `master` | the whole stage — backdrop, light pools **and the cats** (grain + captions stay clean) |
| `backdrop` | the painted world only (not the cats, not the light pools) |
| `cast` | the dancing trio only |
| `clouds-far` / `clouds-mid` / `clouds-near` | one drifting cloud plate each |
| `jet` | the distant crossing jet |
| `ocean` † | the animated water shimmer |
| `city-lights` † | the additive window/cabin lights |
| `haze` | the aerial-perspective haze band |
| `deck-glow` † | the warm lantern pool on the deck |
| `police` † | the bridge strobes |
| `drones-sky` † / `drones-launch` † | the two drone-show passes |
| `vignette` | the frame-edge darkening |

† additive light passes: their **Offset (lift) is ignored** — a lift on a
light pass would wash the whole frame. Slope/power/saturation still apply.

The baked-twin re-draws (base plate, skyline, yacht, foreground deck) are
deliberately **not** targets — grading one copy of a structure that is also
baked into the base plate halos its edges. Use `backdrop` or `master` for
world-level looks.

`enabled: false` mutes a lane (the automation-lane mute).

### Keyframes

- `t_sec` — position in **seconds** of the audio track (the same clock as
  every other side file). The in-app editor snaps to detected beats,
  half-beats and section starts; a hand-written time can sit anywhere.
- `interp` — the curve of the segment **leaving** this key:
  `hold` (step/cut), `linear`, `smooth` (cosine ease, the default),
  `easeIn`, `easeOut`. For a *continuous* evolution over many keys prefer
  `linear` on the interior keys — `smooth` stalls at every key and reads as
  breathing. Before the first key and after the last, the edge value holds.
- `look` — the console state in **wheel-space** (the exact coordinates the
  in-app wheels use), not raw CDL:
  - `lift` / `gamma` / `gain`: `x`,`y` = colour-balance puck (−1..1 each,
    radius ≤ 1; `y` is screen-down, red is up), `m` = that range's luminance
    master (−1..1).
  - `saturation` 0..2 (1 neutral) · `temperature` −1..1 (+ warm) ·
    `tint` −1..1 (+ magenta) · `contrast` 0.5..1.8 (1 neutral) ·
    `pivot` 0.2..0.7 (0.435 neutral).
  - Out-of-range values are clamped on load, so a typo cannot blow out the
    image live.

### Sparse authoring: omitted fields INHERIT

Any field you omit from a `look` **inherits from the previous keyframe in
the lane** (the first keyframe inherits neutral). A keyframe with no `look`
at all is a pure hold/retime key. So this:

```json
{ "t_sec": 0,  "look": { "temperature": 0.3 } },
{ "t_sec": 30, "look": { "saturation": 0.8 } }
```

keeps the +0.3 warmth **held** across both keys while saturation dips — the
unmentioned controls never drift back toward neutral. (The app itself always
writes full looks; sparseness is an input convenience for hand/LLM edits.)

## Worked example

`assets/sample_track/moving.grade.json` is the shipped look for the sample
track: a master lane that slides the scene gently toward sunset over the
song — warmth eases in across the first chorus, and by the outro the frame
is +0.18 temperature, −0.07 gain (about a fifth of a stop down), 0.95
saturation with a whisper of magenta. Linear interior keys, timed to the
section boundaries (42.4 / 90.8 / 137.0 are the structural seams in the beat
map). It is deliberately subtle — the reference for "not immediately
noticeable, but the ending feels later in the evening than the start".

## Round-trip etiquette (for LLM co-authors)

- Edit the file in place; the running app reloads it within ~1 s and shows
  a "reloaded from disk" toast. There is no need to restart anything.
- If the app has unsaved local edits at that moment, the app wins
  (last-writer-wins) and surfaces "external change overwritten" — re-read
  the file before editing again.
- Never write a partially-flushed/incomplete file if avoidable; if a broken
  write does land, the app keeps its last good document, pauses autosave and
  shows an error chip until the file parses again.
- The app's first overwrite of a session copies the previous file to
  `<file>.bak`.
