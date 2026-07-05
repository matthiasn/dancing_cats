import 'dart:async';
import 'dart:ui' as ui;

import 'package:dancing_cats/features/scenery/model/backdrop_grade.dart';
import 'package:dancing_cats/features/scenery/runtime/backdrop_grade_painter.dart';
import 'package:dancing_cats/features/scenery/runtime/scenery_shaders.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Applies an ASC CDL [grade] to everything its child subtree paints — the
/// widget-level grade node of the ADR 0002 graph. The dance stage uses two:
/// one around the cats' `CustomPaint` (the `cast` node, premultiplied — the
/// trio floats on transparency) and one around the whole stage stack (the
/// `master` node, opaque — the finishing pass; grain and captions composite
/// after it).
///
/// Neutral grade (or an empty size) paints the child directly — the common
/// ungraded frame costs exactly what it did before this widget existed.
/// Non-premultiplied affine grades (Slope/Offset/Saturation/Contrast, no Power)
/// use a composited [ColorFilter] layer so the live player avoids per-frame
/// image readback. Grades that need the shader path (Power/gamma curves or
/// premultiplied-alpha children) capture the child's layer tree into an image
/// at the surface's device pixel ratio and draw it back through the grade
/// shader — the same offscreen-capture technique as the framework's
/// `SnapshotWidget`.
///
/// [repaintTick] must change whenever the child's animated content changes
/// (the stage passes its clock): descendants inside their own repaint
/// boundaries repaint without dirtying this render object, so the tick is
/// what keeps an active grade's capture current.
class GradeFilter extends StatefulWidget {
  const GradeFilter({
    required this.grade,
    required this.child,
    this.premultiplied = false,
    this.repaintTick = 0,
    this.programLoader,
    super.key,
  });

  /// The grade to apply; identity paints the child untouched.
  final BackdropGrade grade;

  /// The subtree being graded.
  final Widget child;

  /// True when the child paints on transparency (the cast): selects the
  /// premultiplied-alpha shader variant so feathered edges cannot halo.
  final bool premultiplied;

  /// Change signal for animated children (see class doc).
  final double repaintTick;

  /// Injectable program loader for tests; defaults to the scenery cache's
  /// composite or per-layer grade program per [premultiplied].
  final SceneryShaderProgramLoader? programLoader;

  @override
  State<GradeFilter> createState() => _GradeFilterState();
}

class _GradeFilterState extends State<GradeFilter> {
  ui.FragmentProgram? _program;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(GradeFilter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.programLoader != widget.programLoader ||
        oldWidget.premultiplied != widget.premultiplied) {
      _load();
    }
  }

  void _load() {
    final loader =
        widget.programLoader ??
        (widget.premultiplied
            ? SceneryShaderProgramCache.loadGradeLayer
            : SceneryShaderProgramCache.loadGrade);
    unawaited(() async {
      try {
        final program = await loader();
        if (mounted) setState(() => _program = program);
      } on Object catch (_) {
        // Shader failed to load/compile: the filter keeps painting the child
        // directly (graceful degrade, same posture as LayeredBackdrop).
      }
    }());
  }

  @override
  Widget build(BuildContext context) {
    return _RawGradeFilter(
      grade: widget.grade,
      program: _program,
      premultiplied: widget.premultiplied,
      allowAffineColorFilter: widget.programLoader == null || _program != null,
      repaintTick: widget.repaintTick,
      // The root View widget always provides a MediaQuery, so this holds in
      // app and test trees alike.
      pixelRatio: MediaQuery.devicePixelRatioOf(context),
      child: widget.child,
    );
  }
}

class _RawGradeFilter extends SingleChildRenderObjectWidget {
  const _RawGradeFilter({
    required this.grade,
    required this.program,
    required this.premultiplied,
    required this.allowAffineColorFilter,
    required this.repaintTick,
    required this.pixelRatio,
    required super.child,
  });

  final BackdropGrade grade;
  final ui.FragmentProgram? program;
  final bool premultiplied;
  final bool allowAffineColorFilter;
  final double repaintTick;
  final double pixelRatio;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderGradeFilter(
    grade: grade,
    program: program,
    premultiplied: premultiplied,
    allowAffineColorFilter: allowAffineColorFilter,
    repaintTick: repaintTick,
    pixelRatio: pixelRatio,
  );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGradeFilter renderObject,
  ) {
    renderObject
      ..grade = grade
      ..program = program
      ..premultiplied = premultiplied
      ..allowAffineColorFilter = allowAffineColorFilter
      ..repaintTick = repaintTick
      ..pixelRatio = pixelRatio;
  }
}

/// The render object behind [GradeFilter]: captures the child's painted layer
/// tree to an image and redraws it through the grade shader.
@visibleForTesting
class RenderGradeFilter extends RenderProxyBox {
  RenderGradeFilter({
    required this._grade,
    required this._program,
    required this._premultiplied,
    required this._allowAffineColorFilter,
    required this._repaintTick,
    required this._pixelRatio,
  });

  BackdropGrade _grade;

  /// The grade this filter applies (identity → direct child paint).
  BackdropGrade get grade => _grade;
  set grade(BackdropGrade value) {
    if (value == _grade) return;
    _grade = value;
    markNeedsPaint();
  }

  ui.FragmentProgram? _program;

  /// The compiled grade shader (null → direct child paint).
  ui.FragmentProgram? get program => _program;
  set program(ui.FragmentProgram? value) {
    if (identical(value, _program)) return;
    _program = value;
    markNeedsPaint();
  }

  double _repaintTick;

  /// The animated-content change signal (see [GradeFilter.repaintTick]).
  double get repaintTick => _repaintTick;
  set repaintTick(double value) {
    if (value == _repaintTick) return;
    _repaintTick = value;
    // Only an ACTIVE grade needs this render object to repaint; the neutral path
    // delegates paint and lets descendants' own repaint boundaries do their job.
    if (!_grade.isNeutral && _program != null) markNeedsPaint();
  }

  double _pixelRatio;

  /// The capture resolution scale (the surface's device pixel ratio).
  double get pixelRatio => _pixelRatio;
  set pixelRatio(double value) {
    if (value == _pixelRatio) return;
    _pixelRatio = value;
    markNeedsPaint();
  }

  bool _premultiplied;

  bool get premultiplied => _premultiplied;
  set premultiplied(bool value) {
    if (value == _premultiplied) return;
    _premultiplied = value;
    markNeedsPaint();
  }

  bool _allowAffineColorFilter;

  bool get allowAffineColorFilter => _allowAffineColorFilter;
  set allowAffineColorFilter(bool value) {
    if (value == _allowAffineColorFilter) return;
    _allowAffineColorFilter = value;
    markNeedsPaint();
  }

  bool get _canUseColorFilter =>
      _allowAffineColorFilter &&
      !_premultiplied &&
      _grade.power == BackdropGrade.identity.power;

  @override
  bool get alwaysNeedsCompositing =>
      child != null && !_grade.isNeutral && _canUseColorFilter;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_grade.isNeutral || size.isEmpty || child == null) {
      super.paint(context, offset);
      return;
    }

    if (_canUseColorFilter) {
      layer = context.pushColorFilter(
        offset,
        ui.ColorFilter.matrix(_colorMatrixFor(_grade)),
        super.paint,
        oldLayer: layer as ColorFilterLayer?,
      );
      return;
    }

    final program = _program;
    if (program == null) {
      super.paint(context, offset);
      return;
    }

    // Paint the child subtree into a detached layer and rasterize it at the
    // surface's pixel ratio — the SnapshotWidget technique, so composited
    // descendants (repaint boundaries, platform-free layers) are included.
    final offsetLayer = OffsetLayer();
    final childContext = PaintingContext(offsetLayer, Offset.zero & size);
    super.paint(childContext, Offset.zero);
    // The context is short-lived and fully painted here, exactly like
    // RenderSnapshotWidget's capture path.
    // ignore: invalid_use_of_protected_member
    childContext.stopRecordingIfNeeded();
    final image = offsetLayer.toImageSync(
      Offset.zero & size,
      pixelRatio: _pixelRatio,
    );
    offsetLayer.dispose();

    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final shader = gradeShaderFor(
      program: program,
      grade: _grade,
      size: imageSize,
      image: image,
    );
    context.canvas
      ..save()
      ..translate(offset.dx, offset.dy)
      ..scale(1 / _pixelRatio)
      ..drawRect(Offset.zero & imageSize, Paint()..shader = shader)
      ..restore();
    image.dispose();
  }

  List<double> _colorMatrixFor(BackdropGrade grade) {
    const luma = [0.2126, 0.7152, 0.0722];
    final slopes = [grade.slope.r, grade.slope.g, grade.slope.b];
    final biases = [
      grade.offset.r * grade.contrast + grade.pivot * (1 - grade.contrast),
      grade.offset.g * grade.contrast + grade.pivot * (1 - grade.contrast),
      grade.offset.b * grade.contrast + grade.pivot * (1 - grade.contrast),
    ];
    final sat = grade.saturation;
    final desat = 1 - sat;

    List<double> row(int channel) {
      final out = <double>[];
      for (var source = 0; source < 3; source++) {
        final channelMix = channel == source ? sat : 0.0;
        out.add(
          (channelMix + desat * luma[source]) * grade.contrast * slopes[source],
        );
      }
      final bias =
          sat * biases[channel] +
          desat *
              (luma[0] * biases[0] + luma[1] * biases[1] + luma[2] * biases[2]);
      return [...out, 0, bias * 255];
    }

    return [
      ...row(0),
      ...row(1),
      ...row(2),
      0,
      0,
      0,
      1,
      0,
    ];
  }
}
