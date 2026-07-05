import 'dart:math' as math;

import 'package:dancing_cats/features/character/demo/dance_performance.dart'
    show kDanceRealTempoSpeedup;
import 'package:dancing_cats/features/character/demo/motion_trace_panel.dart';
import 'package:dancing_cats/features/character/model/affine2d.dart';
import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/face.dart';
import 'package:dancing_cats/features/character/runtime/character_renderer.dart';
import 'package:dancing_cats/features/character/runtime/character_scene.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Opens a near-full-screen inspector for [clip]'s authored keyframes: a
/// live looping playback stage (with scrub + play/pause), an onion-skin
/// overlay, and a labelled frame grid (contact sheet), so a move can be
/// eyeballed for quality issues (dead hands, insufficient movement) without
/// leaving the running app or running the offline `frame_grid_test.dart`
/// review harness.
///
/// [scene] should be the long-lived `CharacterScene` for the dancer whose
/// move is being inspected — lead, left, or right, whichever name was
/// tapped (rebuilding a rig is expensive — always pass one of the cast's
/// existing scenes, never construct a fresh one just for this dialog).
/// [clipTimeSeconds] is the pose-clock time the stage was paused at; it
/// marks the nearest sampled frame as "you are here".
Future<void> showDanceMoveInspector(
  BuildContext context, {
  required CharacterScene scene,
  required Clip clip,
  required double clipTimeSeconds,
  Expression expression = Expression.neutral,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (context) => _DanceMoveInspectorDialog(
      scene: scene,
      clip: clip,
      clipTimeSeconds: clipTimeSeconds,
      expression: expression,
    ),
  );
}

/// Cell design-space reference, matching `frame_grid_test.dart`'s contact
/// sheet proportions — every painter rescales these to its actual cell size.
const double _cellW = 240;
const double _cellH = 320;
const double _hipsY = _cellH * 0.66;
const double _groundY = _cellH * 0.9;
const double _centreX = _cellW * 0.46;
const double _poseScale = 0.62;

/// Shared aspect ratio for the STAGE and ONION SKIN "monitor" cards — twin
/// instrument panes rendering the same character stage side by side should
/// be frame-matched, not two independently-proportioned crops.
const double _monitorAspect = _cellW / _cellH * 1.1;

/// Shared header-block height for the STAGE and ONION SKIN sections.
const double _panelHeaderH = 34;

/// Shared bottom reservation for STAGE and ONION SKIN — matches the space
/// STAGE's transport row (34px button + 8px gap) actually occupies, so
/// ONION SKIN's monitor computes to the same final size even though it has
/// no transport row of its own.
const double _panelFooterH = 42;

const Color _cellBg = Color(0xFFF4F1EA);
const Color _cellGround = Color(0xFFD9D2C4);
const Color _cellLine = Color(0x14000000);
const Color _cellLabel = Color(0xFF555049);

/// The phase-sample time for frame [i] of [n]: loops sample `[0, span)` (the
/// wrap frame equals frame 0, so it's omitted); one-shots sample `[0, span]`
/// inclusive, so the terminal pose is shown.
double _sampleTime(Clip clip, int i, int n) {
  if (n <= 1) return 0;
  return clip.loop ? clip.duration * i / n : clip.duration * i / (n - 1);
}

double _phaseAt(Clip clip, double t) =>
    clip.duration <= 0 ? 0.0 : t / clip.duration;

/// Places the character within a painted canvas of [size]. [anchorXFrac] is
/// the horizontal anchor as a fraction of the ACTUAL canvas width — grid
/// cells (which enforce the reference `_cellW/_cellH` aspect ratio) pass the
/// default (0.46, matching the offline contact-sheet's tail-clearance
/// convention), but a canvas with a very different aspect ratio (the wide
/// STAGE panel) needs a fraction of its own real width, not a value
/// calibrated to the narrow reference cell — using `_centreX*k` there left
/// the character stranded near the left edge of a much wider box.
/// [scaleBoost] enlarges the pose beyond the standard grid-cell size — used
/// to make the STAGE panel read as the dialog's hero view.
Affine2D _baseTransform(
  Size size, {
  double anchorXFrac = _centreX / _cellW,
  double scaleBoost = 1.0,
}) {
  final heightScale = size.height / _cellH;
  return Affine2D.translation(
    size.width * anchorXFrac,
    _hipsY * heightScale,
  ).multiply(
    Affine2D.scale(
      _poseScale * heightScale * scaleBoost,
      _poseScale * heightScale * scaleBoost,
    ),
  );
}

class _DanceMoveInspectorDialog extends StatefulWidget {
  const _DanceMoveInspectorDialog({
    required this.scene,
    required this.clip,
    required this.clipTimeSeconds,
    required this.expression,
  });

  final CharacterScene scene;
  final Clip clip;
  final double clipTimeSeconds;
  final Expression expression;

  @override
  State<_DanceMoveInspectorDialog> createState() =>
      _DanceMoveInspectorDialogState();
}

class _DanceMoveInspectorDialogState extends State<_DanceMoveInspectorDialog>
    with SingleTickerProviderStateMixin {
  static const _frameCountOptions = [12, 16, 24];
  int _frameCount = 16;

  /// Bottom section view: the keyframe contact grid, or the measured
  /// motion traces (pocket/sway/head/feet) sampled from the same scene.
  bool _showTraces = false;

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  late double _stageSeconds = widget.clipTimeSeconds;
  // Paused on open, not auto-playing: this dialog is reached by clicking a
  // move name while the app itself is paused — starting the stage in motion
  // would be a surprising jump from that "frozen reference" context. The
  // ticker itself is only started/stopped alongside this (see below), not
  // just gated inside its callback — an un-stopped Ticker keeps scheduling
  // frames forever even if the callback no-ops, which would hang any test
  // that waits for the widget tree to settle.
  bool _stagePlaying = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final delta = elapsed - _lastTick;
    _lastTick = elapsed;
    final duration = widget.clip.duration;
    if (duration <= 0) return;
    setState(() {
      _stageSeconds = (_stageSeconds + delta.inMicroseconds / 1e6) % duration;
    });
  }

  void _toggleStagePlaying() {
    setState(() => _stagePlaying = !_stagePlaying);
    if (_stagePlaying) {
      _lastTick = Duration.zero;
      _ticker.start();
    } else {
      _ticker.stop();
    }
  }

  void _seekStage(double seconds) {
    _ticker.stop();
    setState(() {
      _stagePlaying = false;
      _stageSeconds = seconds;
    });
  }

  int get _nearestIndex {
    final p = widget.clip.duration <= 0
        ? 0.0
        : _stageSeconds / widget.clip.duration;
    if (widget.clip.loop) {
      return (p * _frameCount).round() % _frameCount;
    }
    return (p * (_frameCount - 1)).round().clamp(0, _frameCount - 1);
  }

  /// The column count closest to what the available width comfortably fits
  /// that also divides [frameCount] evenly, so the grid's last row is never
  /// a sparse remainder trailing off into empty space. Searches a small
  /// window around the width-driven target rather than only walking
  /// downward from it — e.g. for 16 frames at a target of 7 columns, 8 (one
  /// column tighter than ideal) packs far better than the nearest smaller
  /// divisor, 4 (which would double the cell size and the scroll length).
  int _columnsFor(double maxWidth, int frameCount) {
    final target = (maxWidth / 190).floor().clamp(3, 8);
    int? best;
    var bestDelta = 1 << 30;
    for (var cols = 3; cols <= target + 2; cols++) {
      if (frameCount % cols != 0) continue;
      final delta = (cols - target).abs();
      if (delta < bestDelta || (delta == bestDelta && cols <= target)) {
        bestDelta = delta;
        best = cols;
      }
    }
    return best ?? target;
  }

  @override
  Widget build(BuildContext context) {
    final clip = widget.clip;
    return Dialog(
      insetPadding: const EdgeInsets.all(28),
      backgroundColor: _Chrome.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _Chrome.hairline),
      ),
      // Pinned locally, INSIDE the Dialog: Dialog wraps its child in a
      // Material, which re-derives its own DefaultTextStyle from the theme —
      // an ancestor merge gets clobbered rather than inherited. Placing it
      // here (not inherited from the app theme) keeps this widget self-
      // contained/testable in isolation, mirroring DanceTransportBar's own
      // `DefaultTextStyle.merge` pattern (that file mounts inline, not via a
      // Dialog, so its merge doesn't hit this same reset).
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: 'Inter'),
        child: Column(
          children: [
            _header(clip),
            const ColoredBox(
              color: _Chrome.hairline,
              child: SizedBox(height: 1, width: double.infinity),
            ),
            SizedBox(
              height: 340,
              child: Row(
                children: [
                  Expanded(child: _stageSection()),
                  const ColoredBox(
                    color: _Chrome.hairline,
                    child: SizedBox(width: 1, height: double.infinity),
                  ),
                  Expanded(child: _onionSection()),
                ],
              ),
            ),
            const ColoredBox(
              color: _Chrome.hairline,
              child: SizedBox(height: 1, width: double.infinity),
            ),
            Expanded(child: _gridSection()),
          ],
        ),
      ),
    );
  }

  Widget _header(Clip clip) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            clip.name,
            style: const TextStyle(
              color: _Chrome.textHi,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${clip.loop ? "loop" : "one-shot"} · '
            '${clip.duration.toStringAsFixed(2)}s · '
            // Same #N/phase computation the stage readout and the
            // highlighted grid cell use for themselves — a header summary
            // that tracks the live position, not an independently-rounded
            // figure that could read as disagreeing with them.
            '#$_nearestIndex p=${_phaseAt(clip, _sampleTime(clip, _nearestIndex, _frameCount)).toStringAsFixed(2)}',
            style: const TextStyle(
              color: _Chrome.textMid,
              fontSize: 12,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const Spacer(),
          for (final count in _frameCountOptions) ...[
            _FrameCountChip(
              count: count,
              selected: count == _frameCount,
              onTap: () => setState(() => _frameCount = count),
            ),
            const SizedBox(width: 6),
          ],
          const SizedBox(width: 12),
          // A hairline rule (matching the dividers used throughout this
          // dialog) plus a plain, unbordered ghost icon — deliberately NOT
          // styled like the frame-count chips beside it, so close reads as
          // an unrelated dismiss action rather than a possible 4th option
          // in that segmented control.
          const SizedBox(
            height: 20,
            child: ColoredBox(
              color: _Chrome.hairline,
              child: SizedBox(width: 1),
            ),
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: 'Close',
            child: InkWell(
              key: const Key('moveInspectorCloseButton'),
              onTap: () => Navigator.of(context).pop(),
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: _Chrome.textMid,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stageSection() {
    final duration = widget.clip.duration;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 10, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed height, matching ONION SKIN's header block exactly (that
          // one carries an extra legend row) — twin instrument panes need
          // the same top offset, not just the same aspect ratio, or the
          // Expanded content below starts at different heights and the two
          // monitor cards end up different sizes despite matching ratios.
          const SizedBox(
            height: _panelHeaderH,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'STAGE — live preview',
                style: TextStyle(
                  color: _Chrome.textLow,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          // The monitor image and the transport strip below it share the
          // SAME width — a DAW scrub bar always spans exactly the content it
          // scrubs, never the panel's incidental padding — and the play
          // button sits inline in that strip rather than floating on top of
          // the artwork.
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const transportH = _panelFooterH - 8;
                final rawH = constraints.maxHeight - _panelFooterH;
                final monitorH = rawH < 0 ? 0.0 : rawH;
                final monitorW = math.min(
                  constraints.maxWidth,
                  monitorH * _monitorAspect,
                );
                return Center(
                  child: SizedBox(
                    width: monitorW,
                    child: Column(
                      children: [
                        SizedBox(
                          height: monitorH,
                          width: monitorW,
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: _MoveFramePainter(
                                scene: widget.scene,
                                clip: widget.clip,
                                frameIndex: 0,
                                frameCount: 1,
                                expression: widget.expression,
                                highlighted: false,
                                overrideTimeSeconds: _stageSeconds,
                                showLabel: false,
                                anchorXFrac: 0.5,
                                scaleBoost: 1.1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: transportH,
                          child: Row(
                            children: [
                              _stageTransportButton(),
                              const SizedBox(width: 8),
                              Expanded(child: _stageScrubber(duration)),
                              const SizedBox(width: 8),
                              // Same #N and the SAME phase-of-that-sample
                              // formula the highlighted KEYFRAMES cell uses
                              // for its own label — co-located with the
                              // transport it reports on, and never able to
                              // disagree with the grid, since it IS that
                              // cell's own number, not an independently
                              // rounded live scrub position.
                              Text(
                                '#$_nearestIndex  p=${_phaseAt(widget.clip, _sampleTime(widget.clip, _nearestIndex, _frameCount)).toStringAsFixed(2)}',
                                key: const Key('moveInspectorStagePhase'),
                                style: const TextStyle(
                                  color: _Chrome.textLow,
                                  fontSize: 11,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _stageTransportButton() {
    return GestureDetector(
      key: const Key('moveInspectorStagePlayToggle'),
      onTap: _toggleStagePlaying,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _stagePlaying ? _Chrome.accent : _Chrome.hairline,
          ),
          color: _stagePlaying ? const Color(0x1A4DD6C0) : Colors.transparent,
        ),
        child: Icon(
          _stagePlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 18,
          color: _stagePlaying ? _Chrome.accent : _Chrome.textMid,
        ),
      ),
    );
  }

  Widget _stageScrubber(double duration) {
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 2,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: SliderComponentShape.noOverlay,
        activeTrackColor: _Chrome.accent,
        inactiveTrackColor: _Chrome.hairline,
        thumbColor: _Chrome.accent,
      ),
      child: Slider(
        key: const Key('moveInspectorStageScrubber'),
        value: duration <= 0 ? 0 : _stageSeconds.clamp(0, duration),
        max: duration <= 0 ? 1 : duration,
        onChanged: duration <= 0 ? null : _seekStage,
      ),
    );
  }

  Widget _onionSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _panelHeaderH,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionLabel('ONION SKIN — hands / feet / tail arcs'),
                Row(
                  children: [
                    for (final (color, label) in _traceLegend) ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: const TextStyle(
                          color: _Chrome.textLow,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: _monitorAspect,
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _OnionSkinPainter(
                      scene: widget.scene,
                      clip: widget.clip,
                      frameCount: _frameCount,
                      expression: widget.expression,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Matches the STAGE panel's reserved transport-row height (its
          // play button + scrub bar) so both monitor cards compute to the
          // same final size, not just the same aspect ratio — twin
          // instrument panes should share one centerline. Filled with a
          // static readout (not left blank) so the two "twin monitor"
          // panels carry the same bottom-row information density.
          SizedBox(
            height: _panelFooterH,
            child: Center(
              child: Text(
                '$_frameCount samples · ${widget.clip.duration.toStringAsFixed(2)}s loop',
                style: const TextStyle(
                  color: _Chrome.textLow,
                  fontSize: 11,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gridSection() {
    final clip = widget.clip;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              _sectionLabel(
                _showTraces
                    ? 'MOTION TRACES — measured from the resolved scene'
                    : 'KEYFRAMES ($_frameCount, ${clip.loop ? "loop" : "one-shot"})',
              ),
              const SizedBox(width: 10),
              Text(
                _showTraces
                    ? 'pocket bounce · weight sway · head ride · sole height'
                    : 'tap a frame to preview it on stage',
                style: const TextStyle(
                  color: _Chrome.textLow,
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const Spacer(),
              _ViewToggleChip(
                label: 'FRAMES',
                selected: !_showTraces,
                onTap: () => setState(() => _showTraces = false),
              ),
              const SizedBox(width: 6),
              _ViewToggleChip(
                label: 'TRACES',
                selected: _showTraces,
                onTap: () => setState(() => _showTraces = true),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _showTraces ? _tracesBody(clip) : _framesBody(clip),
          ),
        ],
      ),
    );
  }

  /// Sampled lazily on first TRACES view and cached: 97 resolved frames is
  /// noticeable work, and the traces only change when the clip does.
  List<MotionTrace>? _traceCache;

  Widget _tracesBody(Clip clip) {
    final traces = _traceCache ??= sampleMotionTraces(widget.scene, clip);
    return RepaintBoundary(
      child: CustomPaint(
        painter: MotionTracePainter(
          traces,
          // Ship-tempo seconds, so the events/s annotations describe the
          // live pace the audience sees, not the authored clip clock.
          loopSeconds: clip.duration / kDanceRealTempoSpeedup,
        ),
        size: Size.infinite,
      ),
    );
  }

  Widget _framesBody(Clip clip) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = _columnsFor(constraints.maxWidth, _frameCount);
        return GridView.builder(
          padding: const EdgeInsets.all(4),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: _cellW / _cellH,
          ),
          itemCount: _frameCount,
          itemBuilder: (context, i) => RepaintBoundary(
            key: ValueKey('moveFrameCell_$i'),
            child: GestureDetector(
              onTap: () => _seekStage(_sampleTime(clip, i, _frameCount)),
              child: CustomPaint(
                painter: _MoveFramePainter(
                  scene: widget.scene,
                  clip: clip,
                  frameIndex: i,
                  frameCount: _frameCount,
                  expression: widget.expression,
                  highlighted: i == _nearestIndex,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      color: _Chrome.textLow,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 1,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
  );
}

class _ViewToggleChip extends StatelessWidget {
  const _ViewToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('moveInspectorView$label'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? _Chrome.accent : _Chrome.hairline,
          ),
          color: selected ? const Color(0x1A4DD6C0) : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _Chrome.textHi : _Chrome.textMid,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _FrameCountChip extends StatelessWidget {
  const _FrameCountChip({
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('moveInspectorFrameCount$count'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? _Chrome.accent : _Chrome.hairline,
          ),
          color: selected ? const Color(0x1A4DD6C0) : Colors.transparent,
        ),
        child: Text(
          '$count',
          style: TextStyle(
            color: selected ? _Chrome.textHi : _Chrome.textMid,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// Paints a single labelled keyframe cell: the character posed at one sampled
/// time, on a light "print" card, scaled to whatever size the grid handed it.
/// Doubles as the STAGE panel's live-preview painter when [overrideTimeSeconds]
/// is given (a continuously-varying time from the playback ticker rather than
/// one of the grid's evenly-spaced samples) and [showLabel] is false (the
/// stage shows its own header readout instead of a per-cell caption).
class _MoveFramePainter extends CustomPainter {
  _MoveFramePainter({
    required this.scene,
    required this.clip,
    required this.frameIndex,
    required this.frameCount,
    required this.expression,
    required this.highlighted,
    this.overrideTimeSeconds,
    this.showLabel = true,
    this.anchorXFrac = _centreX / _cellW,
    this.scaleBoost = 1.0,
  });

  final CharacterScene scene;
  final Clip clip;
  final int frameIndex;
  final int frameCount;
  final Expression expression;
  final bool highlighted;
  final double? overrideTimeSeconds;
  final bool showLabel;
  final double anchorXFrac;
  final double scaleBoost;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.height / _cellH;
    canvas
      ..drawRect(Offset.zero & size, Paint()..color = _cellBg)
      ..drawRect(
        Rect.fromLTWH(
          0,
          _groundY * k,
          size.width,
          size.height - _groundY * k,
        ),
        Paint()..color = _cellGround,
      )
      ..drawRect(Rect.fromLTWH(0, 0, size.width, 1), Paint()..color = _cellLine)
      ..drawRect(
        Rect.fromLTWH(0, 0, 1, size.height),
        Paint()..color = _cellLine,
      );

    final base = _baseTransform(
      size,
      anchorXFrac: anchorXFrac,
      scaleBoost: scaleBoost,
    );
    final t = overrideTimeSeconds ?? _sampleTime(clip, frameIndex, frameCount);
    final p = _phaseAt(clip, t);
    final frame = scene.frameAt(
      clip: clip,
      timeSeconds: t,
      expression: expression,
      base: base,
    );
    CharacterRenderer().paint(
      canvas,
      scene.rig,
      frame.world,
      frame.face,
      memberTransform: base,
      zOrderSwaps: frame.zOrderSwaps,
    );

    if (!showLabel) return;
    (TextPainter(
      text: TextSpan(
        text: '#$frameIndex  p=${p.toStringAsFixed(2)}',
        style: const TextStyle(
          fontFamily: 'Inter',
          color: _cellLabel,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout()).paint(canvas, const Offset(6, 5));

    if (highlighted) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = _Chrome.accent,
      );
    }
  }

  @override
  bool shouldRepaint(_MoveFramePainter old) =>
      !identical(old.scene, scene) ||
      old.clip != clip ||
      old.frameIndex != frameIndex ||
      old.frameCount != frameCount ||
      old.expression != expression ||
      old.highlighted != highlighted ||
      old.overrideTimeSeconds != overrideTimeSeconds ||
      old.showLabel != showLabel ||
      old.anchorXFrac != anchorXFrac ||
      old.scaleBoost != scaleBoost;
}

/// Trace colors, picked to sit clear both of the character's OWN costume
/// hues anywhere they might overlap (dusty rose and lavender are far from
/// the cat's tan fur/paws and maroon sneakers) AND of `_Chrome.accent` — the
/// tail deliberately does NOT reuse the app's teal "selected/active" accent,
/// since that made the trace read as a UI-state color rather than a body
/// part. Muted a step below fully-saturated pink/violet/gold so the traces
/// sit in the same restrained register as the rest of the console's chrome
/// instead of reading as candy-bright accents.
const _traceHandColor = Color(0xFFD98CB0);
const _traceFootColor = Color(0xFFA294D6);
const _traceTailColor = Color(0xFFD1AE55);

/// The bones traced as colored motion-arc dots over the onion-skin ghosts —
/// bright, costume-unrelated colors so the trace pops against both the
/// light card and the dark-suited ghosts.
const _traceBones = <(String bone, Color color, String label)>[
  (CatBones.handL, _traceHandColor, 'hand'),
  (CatBones.handR, _traceHandColor, 'hand'),
  (CatBones.footL, _traceFootColor, 'foot'),
  (CatBones.footR, _traceFootColor, 'foot'),
  (CatBones.tail6, _traceTailColor, 'tail'),
];

/// One legend entry per tracked body part (not per bone — hands/feet each
/// have an L/R pair sharing a color).
const _traceLegend = <(Color color, String label)>[
  (_traceHandColor, 'hand'),
  (_traceFootColor, 'foot'),
  (_traceTailColor, 'tail'),
];

/// Paints every sampled frame of [clip] superimposed at the SAME placement
/// (only the pose changes between layers), fading old→new so the motion arcs
/// of hands/feet/tail become visible at a glance, PLUS an explicit colored
/// dot-and-line trace for the hands/feet/tail-tip — the ghost stack alone
/// reads as a blurry pile once a costume color repeats across limbs (the
/// tail is the same navy as the suit), so the trace is what actually
/// delivers "arcs" rather than implying them.
class _OnionSkinPainter extends CustomPainter {
  _OnionSkinPainter({
    required this.scene,
    required this.clip,
    required this.frameCount,
    required this.expression,
  });

  final CharacterScene scene;
  final Clip clip;
  final int frameCount;
  final Expression expression;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.height / _cellH;
    canvas
      ..drawRect(Offset.zero & size, Paint()..color = _cellBg)
      ..drawRect(
        Rect.fromLTWH(
          0,
          _groundY * k,
          size.width,
          size.height - _groundY * k,
        ),
        Paint()..color = _cellGround,
      );

    final base = _baseTransform(size, anchorXFrac: 0.5, scaleBoost: 1.1);
    final rect = Offset.zero & size;
    final trace = {for (final (bone, _, _) in _traceBones) bone: <Offset>[]};

    for (var i = 0; i < frameCount; i++) {
      final t = _sampleTime(clip, i, frameCount);
      final frame = scene.frameAt(
        clip: clip,
        timeSeconds: t,
        expression: expression,
        base: base,
      );
      final last = i == frameCount - 1;
      // Faint ghosts (a light wash, not a dense stack) so the explicit trace
      // below — not the silhouette pile — is what reads as the "arc".
      final alpha = last ? 1.0 : 0.05 + 0.16 * (i / (frameCount - 1));
      canvas.saveLayer(rect, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
      CharacterRenderer().paint(
        canvas,
        scene.rig,
        frame.world,
        frame.face,
        memberTransform: base,
        zOrderSwaps: frame.zOrderSwaps,
      );
      canvas.restore();

      for (final (bone, _, _) in _traceBones) {
        final origin = frame.world[bone]?.origin;
        if (origin != null) trace[bone]!.add(Offset(origin.x, origin.y));
      }
    }

    for (final (bone, color, _) in _traceBones) {
      _drawTrace(canvas, trace[bone]!, color);
    }
  }

  @override
  bool shouldRepaint(_OnionSkinPainter old) =>
      !identical(old.scene, scene) ||
      old.clip != clip ||
      old.frameCount != frameCount ||
      old.expression != expression;
}

/// Draws a smoothed path through [points] in temporal order — the explicit
/// "motion arc" for one tracked joint across the sampled frames. A raw
/// connect-the-dots polyline with a dot at every sample reads as a tangled
/// scribble once a limb doubles back on itself; a quadratic-smoothed curve
/// through midpoints, with only the start/current endpoints marked, reads as
/// one continuous arc instead.
void _drawTrace(Canvas canvas, List<Offset> points, Color color) {
  if (points.isEmpty) return;
  if (points.length == 1) {
    canvas.drawCircle(points.first, 2.5, Paint()..color = color);
    return;
  }

  final path = Path()..moveTo(points[0].dx, points[0].dy);
  for (var i = 1; i < points.length - 1; i++) {
    final next = points[i + 1];
    final mid = Offset(
      (points[i].dx + next.dx) / 2,
      (points[i].dy + next.dy) / 2,
    );
    path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
  }
  path.lineTo(points.last.dx, points.last.dy);

  canvas
    ..drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.75)
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    )
    ..drawCircle(
      points.first,
      2,
      Paint()..color = color.withValues(alpha: 0.5),
    )
    ..drawCircle(points.last, 3.2, Paint()..color = color);
}

/// Self-contained dark palette for the inspector dialog, echoing (not
/// importing) `dance_transport_bar.dart`'s chrome — this feature stays
/// dependency-free/ejectable.
abstract final class _Chrome {
  static const Color accent = Color(0xFF4DD6C0);
  static const Color panel = Color(0xFF121417);
  static const Color hairline = Color(0x1AFFFFFF);
  static const Color textHi = Color(0xFFEDF1F5);
  static const Color textMid = Color(0xFF8A96A3);
  static const Color textLow = Color(0xFF59626D);
}
