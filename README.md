# dancing_cats

A standalone, beat-synced **procedural dancing-cats** engine + **blue-hour waterfront** scenery, ejected from the Lotti app. Pure-Dart skeletal rig, `CustomPainter` runtime, GLSL scenery shaders, lip-sync, a virtual camera director, and an offline MP4/contact-sheet renderer — driven by a track's beat map so the whole scene moves with the music.

No Riverpod, no service locator, no database, no localization. The runtime closure is just `lib/features/character` + `lib/features/scenery`, three scenery shaders, and a handful of assets.

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

`lib/main.dart` is a thin wrapper around the demo's own `main()` in
`lib/features/character/demo/character_dance_to_track_demo.dart`.

## Prepare your own track

Use the Python tooling under `tools/dance_audio/` to turn any song into the
JSON the player consumes (see its README for venv setup):

```sh
python tools/dance_audio/analyze.py track.mp3 -o out/track.json   # beats/tempo/waveform/sections
python tools/dance_audio/transcribe.py track.mp3 -o out/track.words.json   # word timings (optional)
python tools/dance_audio/lipsync.py vocal.wav -o out/track.cues.json       # Rhubarb mouth cues (optional)
```

Point `DANCE_BEATMAP`/`DANCE_WORDS`/`DANCE_CUES` at the results.

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
shaders/                  scenery_sky / scenery_ocean / scenery_city_lights (.frag)
assets/scenery/           backdrop plates + layer art (WebP/PNG)
assets/images/character/  old single-plate waterfront backdrop (togglable)
assets/fonts/Inter/       UI/caption font
assets/sample_track/      sample beat map / words / cues
tools/dance_audio/        beat map + transcription + lip-sync generation (Python)
tools/scenery_art/        scenery layer/cloud extraction pipeline (Python)
tools/character_video_export/  MP4 export shell wrappers
```

See `lib/features/character/README.md` and `lib/features/scenery/README.md` for
the architecture of each module.
