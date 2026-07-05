---
name: dance-render-artifacts
description: "Generate the review artifacts for character animation: contact-sheet grids, per-frame sequences, true-speed animated GIFs, motion-trace (movement-curve) sheets, onion skins, transition strips, and before/after comparisons. Use whenever renders, GIFs, curves, or strips are needed for a panel, a PR, or an owner review."
---

# Dance Render Artifacts

How to produce every visual artifact this project reviews animation with.
All renders go through the committed test harnesses so they use the real
scene/painter code — never screenshot the app by hand.

## Ground rules

- Render into the session scratchpad (or `build/`), never into the repo;
  only finished, downscaled PR assets get committed (see the
  `dance-pr-evidence` skill).
- One 32-frame authored phrase = 4 bars = 16 beats = 8 seconds at 120 BPM.
  Everything below is PLAYBACK-TRUE: sampling maps wall-clock through the
  shipped beat warp, so what you render is what the audience sees.
- Verify renders visually before spending a panel on them (crop and look).

## Move-loop artifacts (`frame_grid_test.dart`)

```sh
GRID_CLIPS=shaku,zanku,azonto,sekem,buga \
CHARACTER_STRIP_DIR=$OUT GRID_FRAMES=48 \
fvm flutter test test/features/character/frame_grid_test.dart
```

Per clip this writes:
- `<clip>_grid.png` — 48-cell contact sheet (8x6, one loop), the panel's
  primary instrument;
- `<clip>_live.png` — one production-painter frame;
- `<clip>_motion_traces.png` — the MOVEMENT-CURVE sheet: five channels
  (POCKET hips-vertical, WEIGHT hips-lateral, HEAD RIDE skull, SHOULDERS
  crown L/R, FEET both soles), bar gridlines, live events/s labels with a
  25%-of-range prominence floor. Measure claims here, not by eye;
- `<clip>_onion.png` — onion-skin arc overlay.

Useful extras: `GRID_FRAMESEQ=1` (writes `seq_<clip>/f%03d.png` for GIF
stitching), `GRID_ONION`, `GRID_COLS`, `GRID_SCALE`, `GRID_VIEWS`
(front/quarter/side), `GRID_DANCE_CAMERA`.

## True-speed animated GIFs

The GIF format stores frame delays in integer CENTISECONDS, so exactly
60 fps is not representable: a 1.67 cs delay rounds to 2 cs, and browsers
clamp 1 cs to 10 cs. **50 fps (2 cs per frame) is the highest honest GIF
rate — use it as the standard.** For true 60 fps deliverables use the MP4
exporter (`character-video-export` skill) instead.

1. Render a dense sequence — 50 fps x 8 s loop = 400 frames:

   ```sh
   GRID_CLIPS=<clip> GRID_FRAMESEQ=1 GRID_FRAMES=400 \
   CHARACTER_STRIP_DIR=$OUT \
   fvm flutter test test/features/character/frame_grid_test.dart
   ```

2. Stitch at true speed with a proper palette:

   ```sh
   ffmpeg -framerate 50 -i $OUT/seq_<clip>/f%03d.png \
     -vf "scale=360:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
     <clip>_loop.gif
   ```

Keep GIFs ~360 px wide so a before/after pair stays a few MB. Historical
note: rounds up to 2026-07-05 used 48-frame/6 fps GIFs; the owner upgraded
the standard to high-fps ("realistic") — always render the dense sequence
now unless explicitly asked for a quick preview.

## Transition strips (`transition_strip_test.dart`)

Renders every distinct set-list handoff through the production
stepper/composer (real camera, stage, blend, quantized cuts):

```sh
TRANSITION_STRIPS=1 TRANSITION_STRIP_DIR=$OUT \
fvm flutter test test/features/character/transition_strip_test.dart
```

Writes `seq_<from>__<to>/f%03d.png` per pair + `manifest.json` (boundary
seconds, cut frame, fps, trio signatures). Env: `TRANSITION_FPS` (default
24; use 50 for GIF-bound sequences), `TRANSITION_PRE`/`TRANSITION_POST`
(window around the cut), `TRANSITION_WIDTH`.

Sheets: tile the seq with PIL, marking the set-list boundary (blue), the
beat-quantized cut (red — first beat AFTER the boundary, from the beat
map's `beats[].time_sec`), and the 0.18 s blend window (orange). GIFs: the
ffmpeg recipe above with `-framerate <TRANSITION_FPS>`.

## Movement-curve (trace) comparisons

For a before/after of one channel, crop the 1400x1000 trace sheet — each
of the 5 charts is a 200 px band (POCKET 0-200, WEIGHT 200-400, HEAD RIDE
400-600, SHOULDERS 600-800, FEET 800-1000) — stack the two crops with
one-line labels stating the measured numbers (range and events/s come
printed on the chart), and downscale to ~900 px wide.

## "Before" state renders

Render the before from a git worktree at the merge-base — never stash-juggle
the working tree:

```sh
git worktree add $SCRATCH/wt_before <merge-base-sha>
cd $SCRATCH/wt_before && GRID_CLIPS=... CHARACTER_STRIP_DIR=$OUT_BEFORE ...
git worktree remove $SCRATCH/wt_before --force   # when done
```

## Traps

- Regenerate rather than reuse: cached renders from before a code change
  are the classic stale-panel failure.
- The events/s meter counts BOTH series of paired charts and applies the
  25% prominence floor — sub-floor motion is real but uncounted; say which
  you mean when quoting it.
- Python heredocs with `$` interpolation corrupt Dart probe files — use
  the Write tool for Dart.
- Full-repo `fvm flutter analyze` must be clean before any commit; local
  probe files pollute local analyze but are invisible to CI.
