import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dancing_cats/features/character/demo/color_grade_panel.dart';
import 'package:dancing_cats/features/character/demo/dance_app_frame_exporter.dart';
import 'package:dancing_cats/features/character/demo/dance_cues_store.dart';
import 'package:dancing_cats/features/character/demo/dance_ffmpeg_encoder.dart';
import 'package:dancing_cats/features/character/demo/dance_grade_controller.dart';
import 'package:dancing_cats/features/character/demo/dance_grade_store.dart';
import 'package:dancing_cats/features/character/demo/dance_grade_workspace.dart';
import 'package:dancing_cats/features/character/demo/dance_lip_sync_controller.dart';
import 'package:dancing_cats/features/character/demo/dance_lip_sync_workspace.dart';
import 'package:dancing_cats/features/character/demo/dance_loaders.dart';
import 'package:dancing_cats/features/character/demo/dance_move_inspector.dart';
import 'package:dancing_cats/features/character/demo/dance_performance.dart';
import 'package:dancing_cats/features/character/demo/dance_playback_stepper.dart';
import 'package:dancing_cats/features/character/demo/dance_stage_view.dart';
import 'package:dancing_cats/features/character/demo/dance_transport_bar.dart';
import 'package:dancing_cats/features/character/model/beat_map.dart';
import 'package:dancing_cats/features/character/runtime/character_painter.dart';
import 'package:dancing_cats/features/character/runtime/character_renderer.dart';
import 'package:dancing_cats/features/scenery/model/backdrop_grade.dart';
import 'package:dancing_cats/features/scenery/model/grade_timeline.dart';
import 'package:dancing_cats/features/scenery/model/scope_histogram.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

/// Beat-synced dance demo — the first wiring of the offline beat map into live
/// playback (design plan `2026-06-27_dance_audio_analysis.md` §15, kept in the
/// Lotti mother repo). A dev tool, not a product surface.
///
/// It plays a track (looped) and locks the looping dance phrase to the detected
/// beats/downbeats: each frame the dance time is the audio playback position
/// warped through [BeatMap.clipSecondsAt], so the 32-frame phrase (8 beats =
/// 2 bars, 4 frames per beat) lands on-beat and follows tempo drift for the
/// whole track instead of free-running at a guessed BPM. The waveform below is a
/// seek bar — tap or drag to scrub.
///
/// Beat detection is the **offline** `tools/dance_audio` tool (Beat This!); it
/// cannot run in-app. This demo loads a **pre-generated full-track beat-map JSON**
/// (no detection at runtime), including the offline-computed waveform.
///
/// Deliberately **self-contained**: depends only on the `media_kit` package +
/// this character feature — no journal/speech code — so it travels cleanly when
/// the feature is ejected into its own repo.
///
/// Run it (defaults to local dev files; override with --dart-define):
/// ```sh
/// fvm flutter run -d linux \
///   --dart-define=DANCE_AUDIO=/abs/track.mp3 \
///   --dart-define=DANCE_BEATMAP=/abs/full_track_beatmap.json
/// ```
/// Generate the full-track map first:
/// `python tools/dance_audio/analyze.py track.mp3 -o out/track.json`.
///
/// The audio is original artwork — kept local, never committed; only its derived
/// beat-map JSON is read here (also kept out of VCS).
const String kDefaultDanceAudioPath = String.fromEnvironment(
  'DANCE_AUDIO',
  defaultValue: '~/Downloads/Omah_Lay-Moving.mp3',
);
const String kDefaultDanceBeatMapPath = String.fromEnvironment(
  'DANCE_BEATMAP',
  defaultValue: 'assets/sample_track/moving.json',
);

/// Optional word-level lyrics (from `tools/dance_audio/transcribe.py`). Absent →
/// no captions. Original artwork derivative — kept local, never committed.
const String kDefaultDanceWordsPath = String.fromEnvironment(
  'DANCE_WORDS',
  defaultValue: 'assets/sample_track/moving.words.json',
);

/// Optional lip-sync cue track (from `tools/dance_audio/lipsync.py` — Rhubarb).
/// Absent → no mouth movement. Drives the singers' mouths from the actual vocal
/// phonemes; the lyric voice tags only gate *which* cat shows the cues.
const String kDefaultDanceCuesPath = String.fromEnvironment(
  'DANCE_CUES',
  defaultValue: 'assets/sample_track/moving.cues.json',
);

/// Optional keyframed colour-grade timeline (ADR 0002) — written by the
/// in-app workspace and/or by hand/LLM; hot-reloaded while the app runs.
/// Defaults to the beat map's side-file sibling (`moving.grade.json`).
String get kDanceGradePath =>
    Platform.environment['DANCE_GRADE'] ??
    danceGradePathForBeatMap(kDanceBeatMapPath);

String get kDanceAudioPath => _expandUserPath(
  Platform.environment['DANCE_AUDIO'] ?? kDefaultDanceAudioPath,
);
String get kDanceBeatMapPath => _expandUserPath(
  Platform.environment['DANCE_BEATMAP'] ?? kDefaultDanceBeatMapPath,
);
String get kDanceWordsPath => _expandUserPath(
  Platform.environment['DANCE_WORDS'] ?? kDefaultDanceWordsPath,
);
String get kDanceCuesPath => _expandUserPath(
  Platform.environment['DANCE_CUES'] ?? kDefaultDanceCuesPath,
);

String _expandUserPath(String path) {
  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (home == null || home.isEmpty) return path;
  if (path == '~') return home;
  if (path.startsWith('~/') || path.startsWith(r'~\')) {
    return '$home${path.substring(1)}';
  }
  if (path == r'$HOME') return home;
  if (path.startsWith(r'$HOME/') || path.startsWith(r'$HOME\')) {
    return '$home${path.substring(5)}';
  }
  return path;
}

void _logDanceError(String message, [Object? error, StackTrace? stackTrace]) {
  final detail = error == null ? message : '$message\n$error';
  debugPrint(detail);
  if (stackTrace != null) debugPrint('$stackTrace');
  stderr.writeln(detail);
  if (stackTrace != null) stderr.writeln(stackTrace);
}

Future<String> _readRequiredTextInput(String path, String label) async {
  final file = File(path);
  if (file.existsSync()) return file.readAsString();
  if (file.isAbsolute) {
    throw StateError('$label not found: $path');
  }
  try {
    return await rootBundle.loadString(path);
  } on Object catch (e) {
    throw StateError('$label not found as file or bundled asset: $path ($e)');
  }
}

/// Runtime-only capture mode for command-line video export. This avoids the
/// slow test-engine `toImage()` path: the release Linux app renders normally
/// into an X display, and ffmpeg captures that display in real time.
bool get kDanceRenderOnly =>
    Platform.environment['DANCE_RENDER_ONLY'] == '1' ||
    const bool.fromEnvironment('DANCE_RENDER_ONLY');
bool get kDanceRenderCaptions =>
    Platform.environment['DANCE_RENDER_CAPTIONS'] != '0';
int get kDanceRenderWidth =>
    int.tryParse(Platform.environment['DANCE_RENDER_WIDTH'] ?? '') ?? 1920;
int get kDanceRenderHeight =>
    int.tryParse(Platform.environment['DANCE_RENDER_HEIGHT'] ?? '') ?? 1080;
double get kDanceRenderStartSec =>
    double.tryParse(Platform.environment['DANCE_RENDER_START'] ?? '') ?? 0;
String get kDanceRenderReadyFile =>
    Platform.environment['DANCE_RENDER_READY_FILE'] ?? '';
String get kDanceRenderStartFile =>
    Platform.environment['DANCE_RENDER_START_FILE'] ?? '';

/// Marker the app writes when its UNCLAMPED render clock first reaches
/// [kDanceRenderCaptureAtSec] — the realtime exporter waits for this before
/// launching its capture instead of sleeping a fixed preroll. Wall-clock
/// sleeps assumed the app started advancing the instant the start file was
/// touched; in reality the first full-stage frame can block the main thread
/// for seconds (cold shader warm-up), and every second of that jank shipped
/// as video content lagging the muxed audio.
String get kDanceRenderCaptureFile =>
    Platform.environment['DANCE_RENDER_CAPTURE_FILE'] ?? '';
double get kDanceRenderCaptureAtSec =>
    double.tryParse(Platform.environment['DANCE_RENDER_CAPTURE_AT'] ?? '') ??
    double.negativeInfinity;

/// Exact-frame export mode for the release desktop app. Unlike X11 capture, the
/// app steps a fixed frame clock, captures the stage [RepaintBoundary], and
/// pipes raw RGBA frames to one ffmpeg process. This keeps the live app's render
/// path while avoiding wall-clock duplicated/dropped capture frames.
bool get kDanceAppExport => Platform.environment['DANCE_APP_EXPORT'] == '1';
int get kDanceAppExportFps =>
    int.tryParse(Platform.environment['DANCE_APP_EXPORT_FPS'] ?? '') ?? 60;
double get kDanceAppExportDurationSec =>
    double.tryParse(Platform.environment['DANCE_APP_EXPORT_DURATION'] ?? '') ??
    0;
String get kDanceAppExportOut =>
    Platform.environment['DANCE_APP_EXPORT_OUT'] ??
    'build/character_video_exports/dance_app_export.mp4';
int get kDanceAppExportCrf =>
    int.tryParse(Platform.environment['DANCE_APP_EXPORT_CRF'] ?? '') ?? 18;
int get kDanceAppExportAudioKbps =>
    int.tryParse(Platform.environment['DANCE_APP_EXPORT_AUDIO_KBPS'] ?? '') ??
    320;
String get kDanceAppExportX264Preset =>
    Platform.environment['DANCE_APP_EXPORT_X264_PRESET'] ?? 'veryfast';
double get kDanceAppExportWarmupSec =>
    double.tryParse(Platform.environment['DANCE_APP_EXPORT_WARMUP'] ?? '') ?? 2;

/// Opt-in profiling hooks for measuring the live playback path. Kept behind
/// env flags so normal interactive/export runs are unchanged.
bool get kDanceAutoplay => Platform.environment['DANCE_AUTOPLAY'] == '1';
bool get kDancePerfLog => Platform.environment['DANCE_PERF_LOG'] == '1';
double get kDancePerfStartDelaySec =>
    double.tryParse(Platform.environment['DANCE_PERF_START_DELAY'] ?? '') ?? 0;
double get kDancePerfExitAfterSec =>
    double.tryParse(Platform.environment['DANCE_PERF_EXIT_AFTER'] ?? '') ?? 0;

/// Native review window for the audio demo. The content being judged is the
/// stage image, so keep the desktop window itself 16:9 during choreography and
/// scenery review. If the WM still letterboxes, those bars are intentionally
/// plain black.
const Size kDanceDemoWindowSize = Size(1600, 900);
const double kDanceDemoAspectRatio = 16 / 9;

// The beat-synced choreography derivation (which move, warped clock, beat,
// camera context), its data types, the track-config constants and the side-file
// loaders all live in the shared dance-core modules so the live player and the
// offline frame composer derive identical content from one source of truth.

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await _configureDanceDemoWindow();
  runApp(const DanceToTrackApp());
}

Future<void> _configureDanceDemoWindow() async {
  if (!Platform.isLinux && !Platform.isMacOS && !Platform.isWindows) return;
  await windowManager.ensureInitialized();
  await windowManager.setAspectRatio(kDanceDemoAspectRatio);
  await windowManager.setTitle(
    kDanceRenderOnly ? 'dancing_cats dance export' : 'Dance to track',
  );
  final size = kDanceRenderOnly
      ? Size(kDanceRenderWidth.toDouble(), kDanceRenderHeight.toDouble())
      : kDanceDemoWindowSize;
  await windowManager.setMinimumSize(
    kDanceRenderOnly ? size : const Size(960, 540),
  );
  await windowManager.setSize(size);
  await windowManager.center();
}

class DanceToTrackApp extends StatelessWidget {
  const DanceToTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Inter (a bundled family) across the transport chrome for a crisp,
    // consistent console look; falls back to the platform font if absent.
    final base = ThemeData.dark(useMaterial3: true);
    return MaterialApp(
      title: kDanceRenderOnly ? 'dancing_cats dance export' : 'Dance to track',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: base.textTheme.apply(fontFamily: 'Inter'),
        primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Inter'),
      ),
      home: const DanceToTrackPage(),
    );
  }
}

class DanceToTrackPage extends StatefulWidget {
  const DanceToTrackPage({super.key});

  @override
  State<DanceToTrackPage> createState() => _DanceToTrackPageState();
}

class _FramePulse extends ChangeNotifier {
  void pulse() => notifyListeners();
}

class _DanceToTrackPageState extends State<DanceToTrackPage>
    with SingleTickerProviderStateMixin {
  // The trio: lead plus two backing cats, built once. The clock is the audio
  // position warped through the beat map, not a free-running scalar.
  late final DanceCast _cast = DanceCast.build();

  final CharacterRenderer _renderer = CharacterRenderer();
  final Player _player = Player();
  // Surfaces libmpv playback errors instead of letting them fail silently — the
  // symptom that hid a missing macOS `network.client` entitlement (libmpv's
  // stream/protocol init fails under App Sandbox without it, killing audio).
  StreamSubscription<String>? _playerErrorSub;
  final GlobalKey _stageBoundaryKey = GlobalKey();

  late final Ticker _ticker; // 60 fps repaint pump; time comes from the player.
  final _FramePulse _framePulse = _FramePulse();

  BeatMap? _map;
  // The shared per-frame derivation (which move, warped clock, beat, camera
  // context). Null until the beat map loads; the player then delegates every
  // frame to it so the offline composer renders identically. It also holds the
  // beat-loop binding and structural sections, so the State keeps no copies.
  DancePerformance? _perf;
  List<double>? _amplitudes; // full-track waveform, normalized 0..1
  // Section bands for the transport timeline, mapped from the structural
  // sections once on load so the bar doesn't re-allocate the list every frame.
  List<DanceWaveformSection> _waveformSections = const [];
  List<DanceWord> _words = const []; // synced lyrics (optional)
  // Contiguous semantic-section spans (chorus/verse/bridge/...) collapsed from the
  // per-word section tags; the virtual director reads the section label, progress
  // within it, and bar-from-its-downbeat here. Empty without a lyrics file.
  List<DanceSectionSpan> _sectionSpans = const [];
  double _trackDurationSec = 0;
  double _bpm = 0;
  bool _loop = true;
  late bool _showCaptions = kDanceRenderOnly && kDanceRenderCaptions;
  // Dev A/B switch: the new layered blue-hour scene vs. the old single-plate
  // waterfront backdrop.
  bool _useNewBackdrop = true;
  // Mute forces the player volume to zero; the video keeps playing. The app has
  // no volume slider, so unmuting restores full (100) volume.
  bool _muted = false;
  // The keyframed colour-grade timeline (ADR 0002): the store persists and
  // watches <track>.grade.json, the controller owns editing state, and the
  // workspace below the transport renders both when the GRADE toggle is on.
  // [_bypass] feeds the stage identity grades (the clean plate) while the
  // console keeps its state; export paths ignore it by construction.
  DanceGradeStore? _gradeStore;
  DanceGradeController? _gradeController;
  bool _gradeOpen = false;
  bool _bypass = false;

  // The lip-sync cue editor: the store persists and watches
  // <track>.cues.json, the controller owns editing state, and the workspace
  // below the transport renders both when the mic toggle is on. A sibling of
  // the grade timeline above, adapted to span-based cues instead of point
  // keyframes.
  DanceCuesStore? _cuesStore;
  DanceLipSyncController? _lipSyncController;
  bool _lipSyncOpen = false;

  // Image-derived RGB parade: a tiny snapshot of the graded stage, sampled a few
  // times a second, so the grade panel can show where the actual pixels land
  // (clip/crush) rather than only what the transfer curve does.
  ScopeHistogram _scope = ScopeHistogram.empty();
  double _sinceScopeSample = 0;
  bool _scopeSampling = false;
  static const double _scopeInterval = 0.25; // seconds between samples
  static const double _scopePixelRatio = 0.16; // tiny snapshot, cheap to read
  ui.Image? _backdrop;
  ui.Image? _clouds;
  ui.Image? _waves;
  double _wallSeconds = 0; // steady clock for ambient backdrop animation
  // Live dancer screen anchors (normalized, left→right), published by the
  // CharacterPainter each frame so the stage lights can follow the cats.
  List<Offset> _dancerAnchors = const [];
  Duration _lastTick = Duration.zero;
  // The stateful half of each frame: the eased singing mouths + the smoothed
  // virtual camera (with cuts). One code path, shared with the offline renderers
  // so the per-frame orchestration can't drift.
  final DancePlaybackStepper _stepper = DancePlaybackStepper();
  String? _error;
  bool _renderReadySignaled = false;
  bool _renderStarted = false;
  bool _renderCaptureSignaled = false;
  DateTime? _renderWallStart;
  DateTime? _renderPrevTick;
  double _renderClockSeconds = 0;
  bool _appExportStarted = false;
  _DanceFrameTimingProbe? _perfProbe;
  bool _backdropReadyForExport = false;

  double get _positionSec {
    if (!kDanceRenderOnly) {
      return _player.state.position.inMicroseconds / 1e6;
    }
    final max = _trackDurationSec <= 0 ? double.infinity : _trackDurationSec;
    return (kDanceRenderStartSec + _renderClockSeconds).clamp(0.0, max);
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
    _ticker = createTicker(_onTick);
    if (!kDanceAppExport) _ticker.start();
    unawaited(_load());
    // Old-backdrop plate, loaded so the A/B toggle can switch to it instantly.
    unawaited(_loadBackdrop());
  }

  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (kDanceRenderOnly || kDanceAppExport) return false;
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.space) return false;
    if (_map != null) unawaited(_togglePlay());
    return true;
  }

  bool _advanceRenderClock(double dt) {
    if (!kDanceRenderOnly) return true;
    _signalRenderReadyIfNeeded();
    if (_map == null) return false;
    if (!_renderStarted) {
      final startFile = kDanceRenderStartFile;
      if (startFile.isNotEmpty && !File(startFile).existsSync()) {
        return false;
      }
      _renderStarted = true;
      _renderWallStart = DateTime.now();
      return true;
    }
    // WALL-CLOCK position, not integrated ticker deltas. The realtime
    // exporter's whole A/V contract is that app position tracks wall time:
    // x11grab captures wall-clock frames and the audio is muxed on the wall
    // timeline. _onTick's 0.1s stall clamp — correct for the interactive app,
    // where the audio player owns the position — silently stole
    // (stall - 0.1s) from an integrated clock on every cold-cache warmup
    // jank, which shipped a full-song export whose video lagged its own
    // audio by ~3.5s (v73, measured via light-flash vs onset fiducials).
    // Anchoring to wall time makes jank cost duplicated captured frames
    // (the exporter's cadence check catches those) instead of A/V drift.
    var wallStart = _renderWallStart;
    if (wallStart != null) {
      final now = DateTime.now();
      final prev = _renderPrevTick ?? now;
      _renderPrevTick = now;
      final gap = now.difference(prev).inMicroseconds / 1e6;
      // PREROLL stalls are ABSORBED: shift the anchor so the clock only
      // advances by a nominal frame across the stall. The first full-stage
      // paints can block for seconds on cold caches; letting the wall clock
      // leap over that puts the capture point in the past and the exporter
      // captures content ahead of (or behind) its audio. Once the capture
      // marker is written the clock is hard wall-locked — from there jank
      // must cost duplicated frames, never A/V drift.
      if (!_renderCaptureSignaled && gap > 0.25) {
        wallStart = wallStart.add(
          Duration(microseconds: ((gap - 1 / 60) * 1e6).round()),
        );
        _renderWallStart = wallStart;
      }
      _renderClockSeconds = now.difference(wallStart).inMicroseconds / 1e6;
    } else {
      _renderClockSeconds += dt;
    }
    // Tell the exporter when the (unclamped) clock actually reaches the
    // capture point, so x11grab starts against a live, warm pipeline. See
    // [kDanceRenderCaptureFile] — a fixed sleep here cost ~3s of A/V drift
    // whenever the first full-stage frame blocked on shader warm-up.
    if (!_renderCaptureSignaled) {
      final path = kDanceRenderCaptureFile;
      if (path.isNotEmpty &&
          kDanceRenderStartSec + _renderClockSeconds >=
              kDanceRenderCaptureAtSec) {
        File(path).writeAsStringSync('capture\n');
        _renderCaptureSignaled = true;
      }
    }
    return true;
  }

  void _signalRenderReadyIfNeeded() {
    if (!kDanceRenderOnly || _renderReadySignaled || _map == null) return;
    if (!_renderBackdropReady) return;
    final path = kDanceRenderReadyFile;
    if (path.isNotEmpty) {
      final file = File(path);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('ready\n');
    }
    _renderReadySignaled = true;
  }

  bool get _renderBackdropReady => !_useNewBackdrop || _backdropReadyForExport;

  void _markBackdropReadyForExport() {
    if (_backdropReadyForExport) return;
    _backdropReadyForExport = true;
    _signalRenderReadyIfNeeded();
  }

  // Per-frame: repaint and ease the singing mouths. The dance camera is no longer
  // a single eased strength — the virtual director ([_directorContext]) computes the
  // whole shot (zoom/pan, with cuts) from the audio position in [build]. Frame-
  // rate independent: uses the real frame dt and a time constant for the mouths.
  void _onTick(Duration elapsed) {
    var dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt < 0) dt = 0;
    if (dt > 0.1) dt = 0.1; // ignore long stalls (tab switch, etc.)
    _maybeSampleScope(dt);
    final clockRunning = _advanceRenderClock(dt);
    if (!clockRunning) {
      if (mounted) _framePulse.pulse();
      return;
    }
    // Steady wall clock for ambient backdrop animation + the stage-light gel
    // cycle/sweep (independent of the looping dance clock).
    _wallSeconds += dt;
    final pos = _positionSec;
    _advancePerformance(pos: pos, dt: dt);
    if (mounted) _framePulse.pulse();
  }

  void _advancePerformance({required double pos, required double dt}) {
    _stepper.advance(_perf, _lipSyncController?.cues ?? const [], pos, dt);
  }

  Future<void> _load() async {
    try {
      debugPrint(
        'Dance demo startup:\n'
        '  cwd: ${Directory.current.path}\n'
        '  audio: $kDanceAudioPath\n'
        '  beat map: $kDanceBeatMapPath\n'
        '  words: $kDanceWordsPath\n'
        '  cues: $kDanceCuesPath',
      );
      final json =
          jsonDecode(
                await _readRequiredTextInput(kDanceBeatMapPath, 'beat map'),
              )
              as Map<String, Object?>;
      final map = BeatMap.fromJson(json);
      final audio = json['audio'] as Map<String, Object?>?;
      final tempo = json['tempo'] as Map<String, Object?>?;
      final duration =
          (audio?['duration_sec'] as num?)?.toDouble() ?? map.beatTimesSec.last;

      if (!kDanceRenderOnly) {
        final audioFile = File(kDanceAudioPath);
        if (!audioFile.existsSync()) {
          throw StateError('audio file not found: $kDanceAudioPath');
        }
        _playerErrorSub ??= _player.stream.error.listen(
          (error) => _logDanceError('Audio playback error: $error'),
        );
        await _player.open(Media(audioFile.path), play: false);
        await _player.setPlaylistMode(
          _loop ? PlaylistMode.loop : PlaylistMode.none,
        );
      }

      // The waveform is computed offline by tools/dance_audio and embedded in the
      // beat map — no in-app audio decoding (just_waveform has no Linux plugin).
      final amplitudes =
          (json['waveform'] as List?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const <double>[];
      final words = await loadDanceWords(kDanceWordsPath);
      // The single source of truth for the per-frame derivation, assembled
      // through the same factory the offline composer uses so its renders match
      // this player.
      final perf = DancePerformance.fromBeatMapJson(
        json: json,
        map: map,
        trackDurationSec: duration,
        words: words,
      );

      // The grade timeline document (ADR 0002): load before first build so
      // exports and the live stage grade identically from frame zero. The
      // watcher (LLM round-trip) only runs in the interactive app.
      final gradeStore = DanceGradeStore(path: kDanceGradePath);
      await gradeStore.load();
      final sections = _buildWaveformSections(
        perf.sectionSpans,
        perf.sections,
        duration,
      );
      final gradeController = DanceGradeController(
        store: gradeStore,
        beatTimesSec: map.beatTimesSec,
        downbeatIndices: map.downbeatIndices,
        sectionStartsSec: [for (final s in sections) s.start],
      );
      if (!kDanceRenderOnly && !kDanceAppExport) gradeStore.startWatching();

      // The lip-sync cue track (Rhubarb, via tools/dance_audio/lipsync.py):
      // loaded the same way as the grade timeline, so a track without a cue
      // file simply loads an empty document (no mouth motion), and the
      // watcher lets the in-app editor and a re-run of Rhubarb coexist.
      final cuesStore = DanceCuesStore(path: kDanceCuesPath);
      await cuesStore.load();
      final lipSyncController = DanceLipSyncController(
        store: cuesStore,
        beatTimesSec: map.beatTimesSec,
      );
      if (!kDanceRenderOnly && !kDanceAppExport) cuesStore.startWatching();

      if (!mounted) {
        gradeController.dispose();
        gradeStore.dispose();
        lipSyncController.dispose();
        cuesStore.dispose();
        return;
      }
      setState(() {
        _map = map;
        _trackDurationSec = duration;
        _bpm = (tempo?['global_bpm'] as num?)?.toDouble() ?? 0;
        _perf = perf;
        _amplitudes = amplitudes;
        _waveformSections = sections;
        _words = words;
        _sectionSpans = perf.sectionSpans;
        _gradeStore = gradeStore;
        _gradeController = gradeController;
        _cuesStore = cuesStore;
        _lipSyncController = lipSyncController;
      });
      if (!kDanceRenderOnly && kDanceAutoplay) {
        if (kDanceRenderStartSec > 0) {
          await _player.seek(
            Duration(microseconds: (kDanceRenderStartSec * 1e6).round()),
          );
        }
        await _player.play();
        if (mounted) setState(() {});
      }
      _startPerfProbeIfRequested(
        kDanceRenderOnly
            ? 'render-only'
            : kDanceAutoplay
            ? 'live-autoplay'
            : 'live-open',
      );
      if (kDanceAppExport) unawaited(_exportFramesFromApp());
    } on Object catch (e, st) {
      _logDanceError('Could not start beat-synced demo.', e, st);
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _startPerfProbeIfRequested(String label) {
    if (!kDancePerfLog || _perfProbe != null) return;
    final probe = _DanceFrameTimingProbe(label);
    _perfProbe = probe;
    final delay = kDancePerfStartDelaySec;
    void start() {
      probe.start();
      final exitAfter = kDancePerfExitAfterSec;
      if (exitAfter > 0) {
        Timer(Duration(milliseconds: (exitAfter * 1000).round()), () {
          probe.printSummary('final');
          exit(0);
        });
      }
    }

    if (delay <= 0) {
      start();
    } else {
      Timer(Duration(milliseconds: (delay * 1000).round()), start);
    }
  }

  Future<void> _exportFramesFromApp() async {
    if (_appExportStarted) return;
    _appExportStarted = true;
    try {
      if (kDanceAppExportFps <= 0) {
        throw StateError('DANCE_APP_EXPORT_FPS must be positive');
      }
      final start = kDanceRenderStartSec.clamp(0.0, _trackDurationSec);
      final duration = kDanceAppExportDurationSec > 0
          ? math.min(kDanceAppExportDurationSec, _trackDurationSec - start)
          : _trackDurationSec - start;
      if (duration <= 0) throw StateError('export duration is empty');

      final exporter = DanceAppFrameExporter(
        waitReady: _waitForExportReadiness,
        prerollClock: (clockStart, dt) =>
            _prerollExportClock(start: clockStart, dt: dt),
        renderFrame: (pos, dt) => _renderExportFrame(pos: pos, dt: dt),
        captureFrame: _captureStageRgba,
        startEncoder: () => DanceFfmpegEncoder.start(
          width: kDanceRenderWidth,
          height: kDanceRenderHeight,
          fps: kDanceAppExportFps,
          startSec: start,
          durationSec: duration,
          outputPath: kDanceAppExportOut,
          audioPath: kDanceAudioPath,
          crf: kDanceAppExportCrf,
          audioKbps: kDanceAppExportAudioKbps,
          x264Preset: kDanceAppExportX264Preset,
        ),
        log: stdout.writeln,
      );
      await exporter.run(
        start: start,
        durationSec: duration,
        fps: kDanceAppExportFps,
      );
      stdout.writeln('wrote $kDanceAppExportOut');
      exit(0);
    } on Object catch (e, st) {
      stderr
        ..writeln('dance app export failed: $e')
        ..writeln(st);
      exit(1);
    }
  }

  Future<void> _waitForExportReadiness() async {
    // Let the first frame build, then give LayeredBackdrop's async image/shader
    // loads time to settle. This avoids exporting the CPU fallback / empty image
    // state that can exist immediately after the widget tree is mounted.
    await SchedulerBinding.instance.endOfFrame;
    final timeout = math.max(kDanceAppExportWarmupSec, 30);
    final deadline = Stopwatch()..start();
    while (!_renderBackdropReady &&
        deadline.elapsed < Duration(milliseconds: (timeout * 1000).round())) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await SchedulerBinding.instance.endOfFrame;
    }
    if (!_renderBackdropReady) {
      throw StateError('timed out waiting for layered backdrop resources');
    }
    await SchedulerBinding.instance.endOfFrame;
  }

  void _prerollExportClock({required double start, required double dt}) {
    // The playback stepper owns state across four-second phrase slots, held
    // cuts, and eased camera changes. A two-second warm start produced excerpt
    // frames that did NOT match full-song playback at the same timestamp
    // (notably the reported 123s arm jump). Fast-forward the lightweight
    // orchestration from song start; no images are rendered during this loop,
    // so excerpt accuracy does not inherit full-song rendering cost.
    for (var t = 0.0; t < start; t += dt) {
      _renderClockSeconds = t - kDanceRenderStartSec;
      _wallSeconds = t;
      _advancePerformance(pos: t, dt: dt);
    }
  }

  Future<void> _renderExportFrame({
    required double pos,
    required double dt,
  }) async {
    if (!mounted) throw StateError('export widget unmounted');
    setState(() {
      _renderClockSeconds = pos - kDanceRenderStartSec;
      _wallSeconds = pos;
      _advancePerformance(pos: pos, dt: dt);
    });
    await SchedulerBinding.instance.endOfFrame;
  }

  Future<Uint8List> _captureStageRgba() async {
    final context = _stageBoundaryKey.currentContext;
    if (context == null) throw StateError('stage boundary is not mounted');
    final boundary = context.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      throw StateError('stage boundary is not a RenderRepaintBoundary');
    }
    final image = await boundary.toImage();
    try {
      // The encoder is told -s:v renderW×renderH; a capture of any other size
      // would desync the raw-frame stride and roll the picture. Fail loudly
      // rather than emit rolling video (see the export FittedBox in build).
      if (image.width != kDanceRenderWidth ||
          image.height != kDanceRenderHeight) {
        throw StateError(
          'captured ${image.width}x${image.height}, expected '
          '${kDanceRenderWidth}x$kDanceRenderHeight — stage not pinned to the '
          'render size',
        );
      }
      final data = await image.toByteData();
      if (data == null) throw StateError('failed to read raw RGBA frame');
      return Uint8List.fromList(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } finally {
      image.dispose();
    }
  }

  /// Throttled trigger for the grade-panel RGB parade — off in headless export,
  /// and skipped while a sample is still in flight.
  void _maybeSampleScope(double dt) {
    if (kDanceRenderOnly) return;
    _sinceScopeSample += dt;
    if (_scopeSampling || _sinceScopeSample < _scopeInterval) return;
    _sinceScopeSample = 0;
    _scopeSampling = true;
    unawaited(_sampleScope());
  }

  /// Snapshots the graded stage at a tiny resolution and rebuilds the parade
  /// histogram. Best-effort: any capture hiccup just skips this sample.
  Future<void> _sampleScope() async {
    try {
      final boundary = _stageBoundaryKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) return;
      final image = await boundary.toImage(pixelRatio: _scopePixelRatio);
      final bytes = (await image.toByteData())?.buffer.asUint8List();
      image.dispose();
      if (bytes != null && mounted) {
        setState(() => _scope = buildScopeHistogram(bytes));
      }
    } finally {
      _scopeSampling = false;
    }
  }

  /// The transport timeline's section bands: the musical (lyric) sections when
  /// available — labelled Verse/Chorus/Bridge/… with a leading Intro for any
  /// pre-vocal gap — else the structural energy sections (A/B/C/D). Musical
  /// names give the markers real information scent instead of recycled letters.
  static List<DanceWaveformSection> _buildWaveformSections(
    List<DanceSectionSpan> spans,
    List<DanceSection> structural,
    double duration,
  ) {
    if (spans.isEmpty) {
      return [
        for (final s in structural)
          DanceWaveformSection(start: s.start, end: s.end, label: s.label),
      ];
    }
    final out = <DanceWaveformSection>[];
    final first = spans.first.start;
    if (first > 0.5) {
      out.add(DanceWaveformSection(start: 0, end: first, label: 'Intro'));
    }
    for (final s in spans) {
      out.add(
        DanceWaveformSection(
          start: s.start,
          end: s.end,
          label: danceSectionDisplayName(s.section),
        ),
      );
    }
    return out;
  }

  Future<void> _togglePlay() async {
    if (_player.state.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleLoop() async {
    _loop = !_loop;
    await _player.setPlaylistMode(
      _loop ? PlaylistMode.loop : PlaylistMode.none,
    );
    if (mounted) setState(() {});
  }

  Future<void> _toggleMute() async {
    _muted = !_muted;
    await _player.setVolume(_muted ? 0 : 100);
    if (mounted) setState(() {});
  }

  void _seekToTime(double tSec) {
    if (_trackDurationSec <= 0) return;
    final t = tSec < 0
        ? 0.0
        : (tSec > _trackDurationSec ? _trackDurationSec : tSec);
    unawaited(_player.seek(Duration(microseconds: (t * 1e6).round())));
    if (mounted) setState(() {});
  }

  /// Opens the keyframe/onion-skin inspector for one dancer's current move,
  /// picked by tapping that dancer's name in the transport bar. Only
  /// reachable while paused (see the `onInspectMove` wiring below); [stage]
  /// is captured from that paused build, so it's exactly the frozen
  /// move/pose the user is looking at. [index] mirrors `moveLabels`' order
  /// (`stage.ensemble`: index 0 is the lead, matching `DanceStageView`'s
  /// `scene: cast.lead` / `ensembleScenes: [cast.left, cast.right]` mapping.
  void _openMoveInspector(DanceStage stage, int index) {
    final scene = switch (index) {
      1 => _cast.left,
      2 => _cast.right,
      _ => _cast.lead,
    };
    final clip = index < stage.ensemble.length
        ? stage.ensemble[index]
        : stage.lead;
    unawaited(
      showDanceMoveInspector(
        context,
        scene: scene,
        clip: clip,
        clipTimeSeconds: stage.seconds,
      ),
    );
  }

  Future<void> _loadBackdrop() async {
    final images = await Future.wait([
      _loadUiImage(kCharacterWaterfrontBackdropAsset),
      _loadUiImage(kCharacterWaterfrontCloudsAsset),
      _loadUiImage(kCharacterWaterfrontWavesAsset),
    ]);
    if (!mounted) {
      for (final image in images) {
        image.dispose();
      }
      return;
    }
    setState(() {
      _backdrop = images[0];
      _clouds = images[1];
      _waves = images[2];
    });
  }

  Future<ui.Image> _loadUiImage(String asset) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  @override
  void dispose() {
    _perfProbe?.dispose();
    _framePulse.dispose();
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    _ticker.dispose();
    unawaited(_playerErrorSub?.cancel());
    unawaited(_player.dispose());
    final store = _gradeStore;
    _gradeController?.dispose();
    if (store != null) {
      // Land any pending debounced save before tearing the store down.
      unawaited(store.flush().whenComplete(store.dispose));
    }
    final cuesStore = _cuesStore;
    _lipSyncController?.dispose();
    if (cuesStore != null) {
      unawaited(cuesStore.flush().whenComplete(cuesStore.dispose));
    }
    _backdrop?.dispose();
    _clouds?.dispose();
    _waves?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not start beat-synced demo:\n\n$_error\n\n'
              'Point DANCE_AUDIO / DANCE_BEATMAP at local files '
              '(see the file header).',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _framePulse,
        builder: (context, _) => _buildDanceBody(context),
      ),
    );
  }

  Widget _buildDanceBody(BuildContext context) {
    final posSec = _positionSec;
    // Render the SAME stateful stage that owns quantized cuts, outgoing/incoming
    // clocks, and momentum-preserving blends. The old direct `stageAt` call
    // bypassed DancePlaybackStepper after `_advancePerformance` had computed
    // it, so tests audited smooth handoffs while the actual app/export hard-cut
    // the raw score (the repeated arm teleports reported around 123s).
    final stage = playbackStageForRender(_stepper, _perf, posSec);
    final beat = _perf?.beatPulse(posSec) ?? 0;
    // Music-driven body accent — the onset-hit weight-drop, softened by the
    // section energy (single-sourced with the offline render path).
    final bodyAccent = danceBodyAccentEnvelope(
      _perf?.accentAt(posSec) ?? 0,
      stage.energyLevel,
    );
    // Look-ahead partner: the coil that gathers the ensemble just before the
    // next hit, released by the accent above on the beat (same energy scaling).
    final bodyAnticipation = danceBodyAccentEnvelope(
      _perf?.anticipationAt(posSec) ?? 0,
      stage.energyLevel,
    );
    // The director owns the camera; the stepper holds the eased framing and the
    // singing mouths. The whole composite is the generalized DanceStageView,
    // rendered identically by the live app and every offline renderer — there is
    // no second paint path to drift.
    // Evaluate the grade timeline at the playhead — the per-frame feed for
    // every node of the ADR 0002 grade graph. Export paths render the
    // DOCUMENT only (no bypass, no unkeyed previews — a forgotten toggle
    // must never ship); the interactive app honours both, and Bypass shows
    // the clean plate while the console keeps the dialled look.
    final exporting = kDanceRenderOnly || kDanceAppExport;
    final controller = _gradeController;
    final lipSyncController = _lipSyncController;
    final grades = controller == null
        ? const <String, BackdropGrade>{}
        : exporting
        ? controller.gradesAt(posSec, includePreview: false)
        : _bypass
        ? const <String, BackdropGrade>{}
        : controller.gradesAt(posSec);
    final stageView = DanceStageView(
      boundaryKey: _stageBoundaryKey,
      grade: grades[GradeTargets.backdrop] ?? BackdropGrade.identity,
      masterGrade: grades[GradeTargets.master] ?? BackdropGrade.identity,
      castGrade: grades[GradeTargets.cast] ?? BackdropGrade.identity,
      gradeForTarget: grades.isEmpty ? null : (t) => grades[t],
      allowGradeSnapshots: exporting || _gradeOpen || !_player.state.playing,
      cast: _cast,
      renderer: _renderer,
      stage: stage,
      shot: _stepper.shot,
      beat: beat,
      bodyAccent: bodyAccent,
      bodyAnticipation: bodyAnticipation,
      backdropTimeSeconds: posSec,
      // Ambient stage lights run on a steady wall clock (decoupled from the
      // looping dance); offline renderers pass the audio position instead so a
      // render is deterministic at a position.
      lightsTimeSeconds: _wallSeconds,
      bpm: _bpm,
      leadMouth: _stepper.leadMouth,
      bgMouth: _stepper.bgMouth,
      leadShape: _stepper.leadShape,
      bgShape: _stepper.bgShape,
      dancerAnchors: _dancerAnchors,
      onDancerAnchors: (a) => _dancerAnchors = a,
      useNewBackdrop: _useNewBackdrop,
      showCaptions: _showCaptions,
      words: _words,
      onBackdropReady: kDanceRenderOnly ? _markBackdropReadyForExport : null,
      backdropImage: _backdrop,
      cloudsImage: _clouds,
      wavesImage: _waves,
    );
    final section = _perf?.sectionAt(posSec);
    // Prefer the musical section name (Verse/Chorus/…) for the now-playing chip
    // when lyrics are loaded; fall back to the structural label otherwise, and
    // to the timeline's own band (Intro/Outro) where the lyric spans have no
    // name yet — the chip and the timeline must never disagree.
    String? bandLabel;
    for (final b in _waveformSections) {
      if (posSec >= b.start && posSec < b.end) {
        bandLabel = b.label;
        break;
      }
    }
    var musicalLabel = _sectionSpans.isNotEmpty
        ? danceSectionDisplayName(_perf?.sectionInfoAt(posSec).section ?? '')
        : section?.label;
    if (musicalLabel == null ||
        musicalLabel.isEmpty ||
        musicalLabel == '–' ||
        musicalLabel == '—') {
      musicalLabel = bandLabel ?? section?.label;
    }
    // Exact-frame app export captures the stage RepaintBoundary via toImage,
    // so its pixel size must be exactly the requested render size. A desktop
    // window can't always BE that size (macOS clamps the window to the
    // screen), which would make toImage return the clamped size and desync the
    // raw-frame stride against ffmpeg's -s:v (the frame "rolls"). Pin the
    // captured stage to renderW×renderH regardless of the window; FittedBox
    // just scales the on-screen preview to fit.
    return kDanceAppExport
        ? FittedBox(
            child: SizedBox(
              width: kDanceRenderWidth.toDouble(),
              height: kDanceRenderHeight.toDouble(),
              child: stageView,
            ),
          )
        : kDanceRenderOnly
        ? stageView
        : Column(
            children: [
              // While grading, the stage's pillarbox columns stop being
              // dead black: full-size scopes dock beside the viewer (the
              // finishing-suite layout), and the console drops its small
              // duplicates.
              Expanded(
                child: _gradeOpen && controller != null
                    ? LayoutBuilder(
                        builder: (context, box) {
                          final pillar =
                              (box.maxWidth -
                                  box.maxHeight * kDanceDemoAspectRatio) /
                              2;
                          if (pillar < 240) return stageView;
                          final dockW = math.min(pillar - 32, 380).toDouble();
                          return Stack(
                            children: [
                              stageView,
                              Positioned(
                                right: 12,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: _SideScopes(
                                    width: dockW,
                                    laneLabel: controller.selectedTarget
                                        .toUpperCase(),
                                    grade: controller
                                        .consoleLook(posSec)
                                        .toGrade(),
                                    parade: _scope,
                                    bypass: _bypass,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      )
                    : stageView,
              ),
              DanceTransportBar(
                loading: _map == null,
                playing: _player.state.playing,
                loop: _loop,
                showCaptions: _showCaptions,
                captionsAvailable: _words.isNotEmpty,
                useNewBackdrop: _useNewBackdrop,
                muted: _muted,
                bpm: _bpm,
                positionSec: posSec,
                durationSec: _trackDurationSec,
                currentSectionLabel: musicalLabel,
                barsBeats: _barBeatFromMap(posSec),
                moveLabels: [
                  for (final clip in stage.ensemble) clip.name,
                ],
                amplitudes: _amplitudes,
                sections: _waveformSections,
                onPlayPause: () => unawaited(_togglePlay()),
                onToggleLoop: () => unawaited(_toggleLoop()),
                onToggleCaptions: () =>
                    setState(() => _showCaptions = !_showCaptions),
                onToggleBackdrop: () =>
                    setState(() => _useNewBackdrop = !_useNewBackdrop),
                onToggleMute: () => unawaited(_toggleMute()),
                onSeekToSeconds: _seekToTime,
                gradeOpen: _gradeOpen,
                gradeActive: _gradeStore?.doc.isActive ?? false,
                onToggleGrade: controller == null
                    ? null
                    : () => setState(() {
                        _gradeOpen = !_gradeOpen;
                        if (_gradeOpen) _lipSyncOpen = false;
                      }),
                lipSyncOpen: _lipSyncOpen,
                onToggleLipSync: lipSyncController == null
                    ? null
                    : () => setState(() {
                        _lipSyncOpen = !_lipSyncOpen;
                        if (_lipSyncOpen) _gradeOpen = false;
                      }),
                onInspectMove: _player.state.playing
                    ? null
                    : (i) => _openMoveInspector(stage, i),
                showTimeline: !_gradeOpen && !_lipSyncOpen,
              ),
              if (_gradeOpen && controller != null)
                SizedBox(
                  // The stage keeps its floor (~45% of the window). The
                  // workspace lays out inside this fixed height — lanes
                  // scroll internally, the console never clips.
                  height: math.min(
                    470,
                    MediaQuery.sizeOf(context).height * 0.46,
                  ),
                  child: DanceGradeWorkspace(
                    controller: controller,
                    positionSec: posSec,
                    durationSec: _trackDurationSec,
                    playing: _player.state.playing,
                    amplitudes: _amplitudes ?? const [],
                    sections: _waveformSections,
                    parade: _scope,
                    bypass: _bypass,
                    onBypass: (v) => setState(() => _bypass = v),
                    onSeek: _seekToTime,
                    // The pillarbox dock mirrors the scopes at full size.
                    showScopes: false,
                  ),
                ),
              if (_lipSyncOpen && lipSyncController != null)
                SizedBox(
                  // Unlike the grade console (whose height the wheel/scope
                  // panel drives), lip-sync is one cue lane over a shape
                  // palette — a fraction of the grade workspace's footprint
                  // covers it with room to spare.
                  height: math.min(
                    200,
                    MediaQuery.sizeOf(context).height * 0.22,
                  ),
                  child: DanceLipSyncWorkspace(
                    controller: lipSyncController,
                    positionSec: posSec,
                    durationSec: _trackDurationSec,
                    playing: _player.state.playing,
                    sections: _waveformSections,
                    onSeek: _seekToTime,
                  ),
                ),
            ],
          );
  }

  /// The BAR n.b.s readout from the DETECTED beat grid (bars counted from
  /// real downbeats), so the transport and the workspace's beat lane can
  /// never show two disagreeing bar numbers. Null (no map / before the first
  /// downbeat) falls back to the transport's nominal-BPM derivation.
  String? _barBeatFromMap(double pos) {
    final map = _map;
    if (map == null || map.downbeatIndices.isEmpty) return null;
    final beat = map.beatAt(pos);
    final idx = beat.floor();
    var bar = 0;
    var lastDown = -1;
    for (final db in map.downbeatIndices) {
      if (db > idx) break;
      bar++;
      lastDown = db;
    }
    if (lastDown < 0) return null;
    final beatInBar = idx - lastDown + 1;
    final sixteenth = (((beat - idx) * 4).floor() + 1).clamp(1, 4);
    return '$bar.$beatInBar.$sixteenth';
  }
}

class _DanceFrameTimingProbe {
  _DanceFrameTimingProbe(this.label);

  final String label;
  final List<int> _buildUs = [];
  final List<int> _rasterUs = [];
  final List<int> _totalUs = [];
  late final TimingsCallback _callback = _record;
  Timer? _periodic;

  void start() {
    SchedulerBinding.instance.addTimingsCallback(_callback);
    stdout.writeln('dance perf: started label=$label');
    _periodic = Timer.periodic(const Duration(seconds: 5), (_) {
      printSummary('sample');
    });
  }

  void dispose() {
    _periodic?.cancel();
    SchedulerBinding.instance.removeTimingsCallback(_callback);
  }

  void _record(List<ui.FrameTiming> timings) {
    for (final timing in timings) {
      _buildUs.add(timing.buildDuration.inMicroseconds);
      _rasterUs.add(timing.rasterDuration.inMicroseconds);
      _totalUs.add(timing.totalSpan.inMicroseconds);
    }
  }

  void printSummary(String kind) {
    final count = _totalUs.length;
    if (count == 0) {
      stdout.writeln('dance perf: $kind label=$label frames=0');
      return;
    }
    final budgetUs = (1000000 / 60).round();
    stdout.writeln(
      'dance perf: $kind label=$label '
      'frames=$count '
      'build=${_summary(_buildUs)} '
      'raster=${_summary(_rasterUs)} '
      'total=${_summary(_totalUs)} '
      'over16_build=${_overBudget(_buildUs, budgetUs)} '
      'over16_raster=${_overBudget(_rasterUs, budgetUs)} '
      'over16_total=${_overBudget(_totalUs, budgetUs)}',
    );
  }

  String _summary(List<int> values) {
    final sorted = [...values]..sort();
    final avg = values.fold<int>(0, (a, b) => a + b) / values.length / 1000;
    final p50 = _percentile(sorted, 0.50) / 1000;
    final p95 = _percentile(sorted, 0.95) / 1000;
    final max = sorted.last / 1000;
    return 'avg=${avg.toStringAsFixed(2)}ms,'
        'p50=${p50.toStringAsFixed(2)}ms,'
        'p95=${p95.toStringAsFixed(2)}ms,'
        'max=${max.toStringAsFixed(2)}ms';
  }

  int _percentile(List<int> sorted, double p) {
    final index = ((sorted.length - 1) * p).round();
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  int _overBudget(List<int> values, int budgetUs) =>
      values.where((v) => v > budgetUs).length;
}

/// The pillarbox scope dock: RESPONSE + PARADE mirrored at measuring size
/// beside the stage while the grade workspace is open (the classic finishing
/// layout — viewer centre, scopes flanking — instead of dead black columns).
class _SideScopes extends StatelessWidget {
  const _SideScopes({
    required this.width,
    required this.laneLabel,
    required this.grade,
    required this.parade,
    required this.bypass,
  });

  final double width;

  /// Which lane the transfer curve reads (the parade always reads the
  /// program out — the composited stage).
  final String laneLabel;
  final BackdropGrade grade;
  final ScopeHistogram parade;
  final bool bypass;

  @override
  Widget build(BuildContext context) {
    final graphH = width * 0.52;
    return DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: 'Inter'),
      child: Container(
        width: width + 24,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xEE111316),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x22FFFFFF)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TransferCurveScope(
              grade: grade,
              bypass: bypass,
              width: width,
              height: graphH,
              caption: '$laneLabel · transfer',
            ),
            const SizedBox(height: 14),
            ParadeScope(
              histogram: parade,
              bypass: bypass,
              width: width,
              height: graphH,
            ),
          ],
        ),
      ),
    );
  }
}
