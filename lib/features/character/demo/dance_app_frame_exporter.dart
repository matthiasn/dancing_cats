import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dancing_cats/features/character/demo/dance_ffmpeg_encoder.dart';

/// Drives the live app's exact-frame MP4 export: the deterministic
/// render → capture → encode loop, lifted out of the player widget's `State` so
/// the loop is testable on its own (the widget keeps only the Flutter-bound
/// callbacks and the process-level success/exit handling).
///
/// All the work that touches the widget is injected:
/// - [waitReady] resolves once the scene's async resources (the layered
///   backdrop's images/shaders) have settled, so the export never captures the
///   empty warm-up state;
/// - [prerollClock] advances the animation clock silently from a couple of
///   seconds before the start, so motion that depends on prior frames (trails,
///   smoothed cameras) is warmed in;
/// - [renderFrame] steps the clock to `pos` and pumps one frame;
/// - [captureFrame] reads the stage's raw RGBA;
/// - [startEncoder] starts the ffmpeg encoder for this export.
class DanceAppFrameExporter {
  DanceAppFrameExporter({
    required this.waitReady,
    required this.prerollClock,
    required this.renderFrame,
    required this.captureFrame,
    required this.startEncoder,
    this.log,
  });

  /// Resolves once the scene's async resources are loaded.
  final Future<void> Function() waitReady;

  /// Silently advances the clock from before `start` (warm-up), at step `dt`.
  final void Function(double start, double dt) prerollClock;

  /// Steps the clock to `pos` (step `dt`) and pumps one frame to the boundary.
  final Future<void> Function(double pos, double dt) renderFrame;

  /// Reads the just-rendered stage frame as raw RGBA.
  final Future<Uint8List> Function() captureFrame;

  /// Starts the ffmpeg encoder for this export.
  final Future<DanceFfmpegEncoder> Function() startEncoder;

  /// Optional progress sink (e.g. `stdout.writeln`).
  final void Function(String message)? log;

  /// Renders the `[start, start + durationSec]` window at [fps], piping every
  /// frame into the encoder, then [DanceFfmpegEncoder.finish]es it — or
  /// [DanceFfmpegEncoder.kill]s it if anything throws mid-export.
  ///
  /// [progressEvery] frames a progress line is emitted (default: once per
  /// second of output, i.e. every [fps] frames); the final frame always logs.
  Future<void> run({
    required double start,
    required double durationSec,
    required int fps,
    int progressEvery = 0,
  }) async {
    final frameCount = math.max(1, (durationSec * fps).ceil());
    final dt = 1 / fps;
    final every = progressEvery > 0 ? progressEvery : math.max(1, fps);

    await waitReady();
    final encoder = await startEncoder();
    var finished = false;
    try {
      prerollClock(start, dt);
      for (var frame = 0; frame < frameCount; frame++) {
        final pos = start + frame * dt;
        await renderFrame(pos, dt);
        await encoder.writeFrame(await captureFrame());
        if (frame % every == 0 || frame == frameCount - 1) {
          log?.call('rendered ${frame + 1}/$frameCount frames');
        }
      }
      await encoder.finish();
      finished = true;
    } finally {
      if (!finished) encoder.kill();
    }
  }
}
