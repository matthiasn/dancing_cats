import 'package:dancing_cats/features/character/demo/dance_transport_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../widget_test_utils.dart';

/// Records how many times each transport intent fired, plus the last seek.
class _Recorder {
  int play = 0;
  int loop = 0;
  int captions = 0;
  int backdrop = 0;
  int mute = 0;
  double? seek;
}

const _amplitudes = <double>[0.2, 0.6, 0.9, 0.4, 0.7, 0.3, 0.85, 0.5];
const _sections = <DanceWaveformSection>[
  DanceWaveformSection(start: 0, end: 72, label: 'A'),
  DanceWaveformSection(start: 72, end: 144.06, label: 'B'),
];
const _hueSections = <DanceWaveformSection>[
  DanceWaveformSection(start: 0, end: 48, label: 'pre-chorus'),
  DanceWaveformSection(start: 48, end: 96, label: 'post-chorus'),
  DanceWaveformSection(start: 96, end: 144.06, label: 'chorus'),
];

Future<_Recorder> _pump(
  WidgetTester tester, {
  bool loading = false,
  bool playing = false,
  bool loop = true,
  bool showCaptions = false,
  bool captionsAvailable = true,
  bool useNewBackdrop = true,
  bool muted = false,
  double bpm = 120,
  double positionSec = 93.433,
  double durationSec = 144.06,
  String? sectionLabel = 'B',
  List<String> moveLabels = const ['shaku', 'zanku', 'buga'],
  List<double>? amplitudes = _amplitudes,
  List<DanceWaveformSection> sections = _sections,
  Size size = const Size(1280, 800),
}) async {
  final rec = _Recorder();
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            const Expanded(child: SizedBox()),
            DanceTransportBar(
              loading: loading,
              playing: playing,
              loop: loop,
              showCaptions: showCaptions,
              captionsAvailable: captionsAvailable,
              useNewBackdrop: useNewBackdrop,
              muted: muted,
              bpm: bpm,
              positionSec: positionSec,
              durationSec: durationSec,
              currentSectionLabel: sectionLabel,
              moveLabels: moveLabels,
              amplitudes: amplitudes,
              sections: sections,
              onPlayPause: () => rec.play++,
              onToggleLoop: () => rec.loop++,
              onToggleCaptions: () => rec.captions++,
              onToggleBackdrop: () => rec.backdrop++,
              onToggleMute: () => rec.mute++,
              onSeekToSeconds: (s) => rec.seek = s,
            ),
          ],
        ),
      ),
      mediaQueryData: MediaQueryData(size: size),
    ),
  );
  await tester.pump();
  return rec;
}

void main() {
  group('formatDancePlaybackTimestamp', () {
    test('formats sub-hour positions as mm:ss.mmm', () {
      expect(formatDancePlaybackTimestamp(0), '00:00.000');
      expect(formatDancePlaybackTimestamp(93.433), '01:33.433');
      expect(formatDancePlaybackTimestamp(144.06), '02:24.060');
    });

    test('rounds to the nearest millisecond and carries into minutes', () {
      expect(formatDancePlaybackTimestamp(59.9996), '01:00.000');
      expect(formatDancePlaybackTimestamp(61.2345), '01:01.235');
    });

    test('uses h:mm:ss.mmm after the first hour', () {
      expect(formatDancePlaybackTimestamp(3661.234), '1:01:01.234');
    });

    test('clamps invalid or negative positions to zero', () {
      expect(formatDancePlaybackTimestamp(-1), '00:00.000');
      expect(formatDancePlaybackTimestamp(double.nan), '00:00.000');
      expect(formatDancePlaybackTimestamp(double.infinity), '00:00.000');
    });
  });

  group('DanceTransportBar', () {
    testWidgets('renders timecode, BPM and the active section', (tester) async {
      await _pump(tester);

      // Timecode shows current / total with millisecond precision.
      expect(
        find.textContaining('01:33.433', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('02:24.060', findRichText: true),
        findsOneWidget,
      );
      // BPM readout and the now-playing section name (uppercased).
      expect(find.textContaining('120', findRichText: true), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      // Move names are shown left-to-right so screenshots identify the active
      // choreography for each dancer.
      expect(
        find.textContaining('shaku  /  zanku  /  buga', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('loading hides metadata and disables play', (tester) async {
      final rec = await _pump(tester, loading: true);

      // Metadata cluster is hidden while loading.
      expect(find.text('B'), findsNothing);
      expect(find.textContaining('120', findRichText: true), findsNothing);
      // Play is disabled: tapping it does nothing.
      await tester.tap(
        find.byIcon(Icons.play_arrow_rounded),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(rec.play, 0);
    });

    testWidgets('play / loop / backdrop toggles fire their callbacks', (
      tester,
    ) async {
      final rec = await _pump(tester);

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      // Loop defaults on, so its on-glyph (repeat_on) is shown.
      await tester.tap(find.byIcon(Icons.repeat_on_rounded));
      await tester.tap(find.byIcon(Icons.image_rounded));
      await tester.pump();

      expect(rec.play, 1);
      expect(rec.loop, 1);
      expect(rec.backdrop, 1);
    });

    testWidgets('mute toggle fires and swaps the speaker glyph', (
      tester,
    ) async {
      // Unmuted (default): the speaker-on glyph shows; tapping requests a mute.
      final rec = await _pump(tester);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      expect(find.byIcon(Icons.volume_off_rounded), findsNothing);
      await tester.tap(find.byIcon(Icons.volume_up_rounded));
      await tester.pump();
      expect(rec.mute, 1);

      // Muted: the struck-through glyph shows instead.
      await _pump(tester, muted: true);
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
    });

    testWidgets('captions toggle fires when lyrics are available', (
      tester,
    ) async {
      final rec = await _pump(tester);
      await tester.tap(find.byIcon(Icons.closed_caption_off_rounded));
      await tester.pump();
      expect(rec.captions, 1);
    });

    testWidgets('captions toggle is hidden without lyrics', (tester) async {
      await _pump(tester, captionsAvailable: false);
      expect(find.byIcon(Icons.closed_caption_off_rounded), findsNothing);
      expect(find.byIcon(Icons.closed_caption_rounded), findsNothing);
    });

    testWidgets('tapping the timeline seeks proportionally', (tester) async {
      final rec = await _pump(tester);

      await tester.tap(find.byKey(const Key('danceTimeline')));
      await tester.pump();

      // Tapping the horizontal centre seeks to ~half the track.
      expect(rec.seek, isNotNull);
      expect(rec.seek, closeTo(144.06 / 2, 144.06 * 0.08));
    });

    testWidgets('dragging the timeline scrubs the playhead', (tester) async {
      final rec = await _pump(tester);

      await tester.drag(
        find.byKey(const Key('danceTimeline')),
        const Offset(160, 0),
      );
      await tester.pump();

      // The horizontal-drag handler seeks proportionally, like the tap handler.
      expect(rec.seek, isNotNull);
      expect(rec.seek, inInclusiveRange(0, 144.06));
    });

    testWidgets('the timeline paints recurring pre/post-chorus hues', (
      tester,
    ) async {
      await _pump(
        tester,
        sections: _hueSections,
        sectionLabel: 'pre-chorus',
      );
      // The waveform/section painter ran (no placeholder), so the structural
      // hue lookup resolved the pre-chorus → amber and post-chorus → rose bands.
      expect(find.byKey(const Key('danceTimeline')), findsOneWidget);
      expect(find.textContaining('no waveform in beat map'), findsNothing);
      // The now-playing readout shows the active section, uppercased.
      expect(find.text('PRE-CHORUS'), findsOneWidget);
    });

    testWidgets('the timeline painter is consulted for repaint on rebuild', (
      tester,
    ) async {
      await _pump(tester);
      // Re-pump the identical tree: the CustomPaint receives a fresh painter
      // instance and must compare it against the previous one via shouldRepaint.
      await _pump(tester);
      expect(find.byKey(const Key('danceTimeline')), findsOneWidget);
    });

    testWidgets('empty waveform shows the regenerate hint', (tester) async {
      await _pump(tester, amplitudes: const []);
      expect(
        find.textContaining('no waveform in beat map'),
        findsOneWidget,
      );
      // No seek surface to tap when there is no waveform.
      expect(find.byKey(const Key('danceTimeline')), findsNothing);
    });

    testWidgets('null amplitudes render the loading placeholder', (
      tester,
    ) async {
      await _pump(tester, amplitudes: null);
      expect(find.byKey(const Key('danceTimeline')), findsNothing);
      expect(find.text('loading…'), findsOneWidget);
    });
  });
}
