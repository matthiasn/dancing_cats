# dancing_cats

[![CI](https://github.com/matthiasn/dancing_cats/actions/workflows/ci.yml/badge.svg)](https://github.com/matthiasn/dancing_cats/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/matthiasn/dancing_cats/graph/badge.svg)](https://codecov.io/gh/matthiasn/dancing_cats)

A standalone, beat-synced **procedural dancing-cats** engine + **blue-hour waterfront** scenery, ejected from the Lotti app. Pure-Dart skeletal rig, `CustomPainter` runtime, GLSL scenery shaders, lip-sync, a virtual camera director, and an offline MP4/contact-sheet renderer — driven by a track's beat map so the whole scene moves with the music.

No Riverpod, no service locator, no database, no localization. The runtime closure is just `lib/features/character` + `lib/features/scenery`, five scenery shaders, and a handful of assets.

## Run

```sh
fvm flutter run -d linux \
  --dart-define=DANCE_AUDIO=/abs/path/to/track.mp3
```

The beat map, word timings, and lip-sync cues default to the bundled sample under `assets/sample_track/` (`moving.json`, `moving.words.json`, `moving.cues.json`), so the only thing you must supply is the audio file (kept out of the repo for licensing). Override any input with `--dart-define` or the matching `DANCE_*` env var:

| Input | dart-define / env | Default |
|-------|-------------------|---------|
| Audio | `DANCE_AUDIO` | `/home/parallels/Downloads/Omah_Lay-Moving.mp3` |
| Beat map | `DANCE_BEATMAP` | `assets/sample_track/moving.json` |
| Words | `DANCE_WORDS` | `assets/sample_track/moving.words.json` |
| Lip-sync cues | `DANCE_CUES` | `assets/sample_track/moving.cues.json` |

`lib/main.dart` **is** the dance-to-track app (`DanceToTrackApp`): stage view,
transport bar with waveform scrubbing, move inspector, grade console, and
export hooks. The reusable demo panels it composes live under
`lib/features/character/demo/`.

## Prepare your own track

Use the Python tooling under `tools/dance_audio/` to turn any song into the
JSON the player consumes (see its README for venv setup):

```sh
python tools/dance_audio/analyze.py track.mp3 -o out/track.json   # beats/tempo/waveform/sections
python tools/dance_audio/transcribe.py track.mp3 -o out/track.words.json   # word timings (optional)
python tools/dance_audio/lipsync.py vocal.wav -o out/track.cues.json       # Rhubarb mouth cues (optional)
```

Point `DANCE_BEATMAP`/`DANCE_WORDS`/`DANCE_CUES` at the results.

## DIY: point your coding assistant at this repo

This repo is built to be extended *by* a coding agent, not just read by one.
The workflows that produced everything you see — track prep, choreography
authoring, motion review, scenery surgery, video export — are captured as
agent skills under [`.claude/skills/`](.claude/skills/). Claude Code picks
them up automatically; with any other assistant, hand it the relevant
`SKILL.md` as a runbook — each one is a self-contained, human-readable
procedure with the exact commands and acceptance checks.

To build a new choreography for your own song, the skills chain like this:

1. **`dance-track-prep`** — offline beat/downbeat map + word-timestamped
   lyrics for any audio file (wraps `tools/dance_audio/`).
2. **`dance-lipsync`** — real mouth-shape cues from the vocal stem via
   Rhubarb, so the cats sing the words instead of flapping.
3. **`choreo-phrase-authoring`** — author moves as beat-addressed data
   (`Clip`s with IK targets and support spans, see the
   [Afrobeats catalog](lib/features/character/README.md#dance-moves--the-afrobeats-catalog))
   instead of tweaking magic numbers.
4. **`character-motion-review-panel`** / **`temporal-animation-diff`** —
   grounded review loops: render real frame strips, convene dance-coach /
   rigging / physics reviewers, iterate until the move scores.
5. **`character-video-export`** — a verified, audio-synced MP4.

For scenery work there are matching skills (`scenery-art-layer-prep`,
`scenery-layer-registration`, `cinematic-render-panel`,
`flutter-shader-validation`), and the guardrails that make unattended agent
iteration safe are already wired: CI runs a zero-warning analyze gate and the
full suite with coverage tracked on Codecov, and the choreography/pixel tests
pin tight numeric windows that fail loudly when a change drifts.

## Tests

```sh
fvm flutter test                                  # full suite (character + scenery)
fvm flutter analyze                               # very_good_analysis, zero warnings
```

Two harnesses are gated behind env vars and skipped otherwise:

- **Position-window debug grid** — renders a labelled contact sheet of frames
  around an audio position (handy for inspecting a reported misalignment):
  ```sh
  DANCE_POS=40 DANCE_WINDOW=6 fvm flutter test test/features/character/dance_player_window_test.dart
  # → build/dance_window/window.png
  ```
- **MP4 export** — see `tools/character_video_export/` wrappers, which set
  `DANCE_EXPORT=1` and drive `dance_video_export_test.dart`.

## Layout

```
lib/features/character/   skeletal rig, engine, runtime painter, demo player, camera, lip-sync
lib/features/scenery/     layered blue-hour backdrop (shaders + bitmap layers + props/lights)
shaders/                  scenery_sky / scenery_ocean / scenery_city_lights / scenery_grade / scenery_grade_layer (.frag)
assets/scenery/           backdrop plates + layer art (WebP/PNG)
assets/images/character/  old single-plate waterfront backdrop (togglable)
assets/fonts/Inter/       UI/caption font
assets/sample_track/      sample beat map / words / cues
tools/dance_audio/        beat map + transcription + lip-sync generation (Python)
tools/scenery_art/        scenery layer/cloud extraction pipeline (Python)
tools/character_video_export/  MP4 export shell wrappers
```

See `lib/features/character/README.md` and `lib/features/scenery/README.md` for
the architecture of each module, and
[`docs/animation/`](docs/animation/README.md) for concept-first explainers of
the animation techniques themselves (parallax layers, the rig and its
deformable mesh, limb/joint constraints, and the temporal motion constraints
that keep rotation rate and stops readable).
