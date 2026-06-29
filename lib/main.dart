import 'package:dancing_cats/features/character/demo/character_dance_to_track_demo.dart'
    as demo;

/// Standalone entry point for the dancing-cats music player.
///
/// Delegates to the demo's own `main()`, which initialises media_kit, sizes the
/// desktop window 16:9, and runs the beat-synced player. Override the track and
/// derived data with `--dart-define` / `DANCE_*` env vars (see the demo header).
Future<void> main() => demo.main();
