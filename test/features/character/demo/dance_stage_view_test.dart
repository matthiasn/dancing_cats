import 'package:dancing_cats/features/character/demo/dance_performance.dart';
import 'package:dancing_cats/features/character/demo/dance_stage_view.dart';
import 'package:dancing_cats/features/character/model/beat_map.dart';
import 'package:dancing_cats/features/character/model/face.dart';
import 'package:dancing_cats/features/character/model/rig_spec.dart';
import 'package:dancing_cats/features/character/runtime/character_renderer.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';
import 'package:dancing_cats/features/scenery/layered_backdrop.dart';
import 'package:dancing_cats/features/scenery/runtime/stage_lights.dart';
import 'package:dancing_cats/features/scenery/scene_texture_overlay.dart';
import 'package:dancing_cats/features/scenery/stage_lights_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _words = <DanceWord>[
  (start: 0.0, end: 0.5, word: 'one', voice: 'lead', section: 'verse'),
  (start: 1.0, end: 1.5, word: 'two', voice: 'lead', section: 'verse'),
  (start: 2.0, end: 2.5, word: 'three', voice: 'lead', section: 'verse'),
];

/// A synthetic 120 BPM grid with one energetic section, enough for `stageAt` to
/// resolve a dancing (non-resting) stage to feed the live paint path.
DancePerformance _perf({List<DanceWord> words = const []}) {
  final map = BeatMap(
    beatTimesSec: [for (var i = 0; i < 13; i++) i * 0.5],
    downbeatIndices: const [0, 4, 8, 12],
  );
  return DancePerformance(
    map: map,
    binding: BeatLoopBinding.barAligned(map, bars: kDancePhraseBars),
    sections: const [(start: 0, end: 6, label: 'A', energetic: true, level: 1)],
    sectionSpans: const [],
    trackDurationSec: 6,
    words: words,
  );
}

Widget _hostStage(DanceStageView view) =>
    MaterialApp(home: Scaffold(body: view));

DanceStageView _stageView({
  bool useNewBackdrop = true,
  bool showCaptions = true,
  List<DanceWord> words = _words,
  ValueChanged<List<Offset>>? onDancerAnchors,
}) {
  final perf = _perf(words: words);
  return DanceStageView(
    cast: DanceCast.build(),
    renderer: CharacterRenderer(antiAlias: false),
    stage: perf.stageAt(2),
    shot: (zoom: 1.0, dx: 0.0, dy: 0.0),
    beat: 0.5,
    backdropTimeSeconds: 2,
    lightsTimeSeconds: 2,
    bpm: 120,
    leadMouth: 0.4,
    bgMouth: 0.2,
    leadShape: MouthShape.smileOpen,
    bgShape: MouthShape.neutral,
    dancerAnchors: const [Offset(100, 200), Offset(200, 200), Offset(300, 200)],
    onDancerAnchors: onDancerAnchors,
    useNewBackdrop: useNewBackdrop,
    showCaptions: showCaptions,
    words: words,
  );
}

void main() {
  group('DanceCaption.captionWordIndex', () {
    test('no words → null', () {
      expect(DanceCaption.captionWordIndex(const [], 1), isNull);
    });

    test('before the first word → null', () {
      expect(DanceCaption.captionWordIndex(_words, -0.1), isNull);
    });

    test('returns the most recently started word', () {
      expect(DanceCaption.captionWordIndex(_words, 1.2), 1);
      expect(DanceCaption.captionWordIndex(_words, 2.4), 2);
    });

    test('hides during an instrumental gap (>2 s after the last word end)', () {
      // Last word ends at 2.5; 2.5 + 2 = 4.5 is the cutoff.
      expect(DanceCaption.captionWordIndex(_words, 4.4), 2);
      expect(DanceCaption.captionWordIndex(_words, 4.6), isNull);
    });
  });

  group('DanceCaption.captionWindow', () {
    test('clamps a few words either side of the active one', () {
      expect(DanceCaption.captionWindow(0, 10), (from: 0, to: 4));
      expect(DanceCaption.captionWindow(6, 10), (from: 3, to: 10));
      expect(DanceCaption.captionWindow(9, 10), (from: 6, to: 10));
    });
  });

  group('DanceCaption.captionWordStyle', () {
    test('the active word is brighter, larger and bolder', () {
      final active = DanceCaption.captionWordStyle(active: true);
      final inactive = DanceCaption.captionWordStyle(active: false);
      expect(active.color, Colors.white);
      expect(inactive.color, Colors.white54);
      expect(active.fontSize, greaterThan(inactive.fontSize!));
      expect(active.fontWeight, FontWeight.w700);
      expect(inactive.fontWeight, FontWeight.w400);
    });
  });

  group('DanceCaption widget', () {
    testWidgets('renders the active word window, empty when no word is on', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: DanceCaption(words: _words, positionSeconds: 1.2),
        ),
      );
      // The active word and a neighbour are shown.
      expect(find.byType(RichText), findsOneWidget);
      final text = tester
          .widget<RichText>(find.byType(RichText))
          .text
          .toPlainText();
      expect(text, contains('two'));
      expect(text, contains('one'));

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: DanceCaption(words: _words, positionSeconds: 10),
        ),
      );
      // Past the instrumental-gap cutoff → nothing rendered.
      expect(find.byType(RichText), findsNothing);
    });
  });

  group('danceStageRig', () {
    test('the gel cycle period is the beat length (60 / bpm)', () {
      expect(danceStageRig(60).colorPeriod, closeTo(1.0, 1e-9));
      expect(danceStageRig(120).colorPeriod, closeTo(0.5, 1e-9));
    });

    test('a non-positive bpm falls back to a safe period', () {
      expect(danceStageRig(0).colorPeriod, 0.5);
    });

    test('the centre lane is locked to the hero gold gel', () {
      expect(danceStageRig(120).leadGoldIndex, 1);
    });
  });

  group('danceMemberBacklights', () {
    StageLightSample sample(Color c, double intensity) =>
        StageLightSample(color: c, targetX: 0, intensity: intensity);

    test('weights the centre (lead) lane hotter than the flankers', () {
      final out = danceMemberBacklights([
        sample(const Color(0xFFFF0000), 0.5),
        sample(const Color(0xFF00FF00), 0.5),
        sample(const Color(0xFF0000FF), 0.5),
      ]);
      expect(out, hasLength(3));
      // kDanceHeroWeight = [0.9, 1.1, 0.9]: the centre is brighter.
      expect(out[1].a, greaterThan(out[0].a));
      expect(out[1].a, greaterThan(out[2].a));
      expect(out[0].a, closeTo(0.45, 1e-3));
      expect(out[1].a, closeTo(0.55, 1e-3));
    });

    test('clamps the alpha to 1.0 for an over-bright sample', () {
      final out = danceMemberBacklights([sample(const Color(0xFFFFFFFF), 2)]);
      expect(out.single.a, 1.0);
    });

    test('an empty rig sample yields no backlights', () {
      expect(danceMemberBacklights(const []), isEmpty);
    });
  });

  group('danceCastScale', () {
    test('lands the ~300-unit body at 0.78 of the stage height', () {
      expect(danceCastScale(300), closeTo(0.78, 1e-9));
      expect(danceCastScale(600), closeTo(1.56, 1e-9));
    });
  });

  group('DanceCast', () {
    test('uses widened sleeve meshes for the shipped trio', () {
      final baseArm = _leftArmMesh(buildCatInSuitRig());
      final cast = DanceCast.build();

      expect(
        _maxAbsLocalX(_leftArmMesh(cast.lead.rig).vertices[2]),
        closeTo(
          _maxAbsLocalX(baseArm.vertices[2]) * kDanceLeadArmWidthScale,
          0.001,
        ),
      );
      expect(
        _maxAbsLocalX(_leftArmMesh(cast.left.rig).vertices[2]),
        closeTo(
          _maxAbsLocalX(baseArm.vertices[2]) * kDanceBackupArmWidthScale,
          0.001,
        ),
      );
      expect(
        _maxAbsLocalX(_leftArmMesh(cast.right.rig).vertices[2]),
        closeTo(
          _maxAbsLocalX(baseArm.vertices[2]) * kDanceBackupArmWidthScale,
          0.001,
        ),
      );
    });
  });

  group('danceCharacterPainter', () {
    test('front-locks the shipped trio while arm attachment is reviewed', () {
      final painter = danceCharacterPainter(
        cast: DanceCast.build(),
        renderer: CharacterRenderer(antiAlias: false),
        stage: _perf().stageAt(2),
        shot: (zoom: 1.0, dx: 0.0, dy: 0.0),
        leadMouth: 0.4,
        bgMouth: 0.2,
        leadShape: MouthShape.smileOpen,
        bgShape: MouthShape.neutral,
        scale: 1,
        backlights: const [],
      );

      expect(painter.heroStaging, isTrue);
      expect(painter.danceViewProjection, isFalse);
    });
  });

  group('DanceStageView widget', () {
    testWidgets('pumps the live stage (new backdrop + captions) cleanly', (
      tester,
    ) async {
      // A non-null anchor callback exercises the painter foot-anchor wiring.
      await tester.pumpWidget(_hostStage(_stageView(onDancerAnchors: (_) {})));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(LayeredBackdrop), findsOneWidget);
      expect(find.byType(StageLightsOverlay), findsOneWidget);
      expect(find.byType(SceneTextureOverlay), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      // The active lyric word is captioned.
      expect(find.byType(DanceCaption), findsOneWidget);
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('pumps the legacy single-plate path (useNewBackdrop: false)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _hostStage(_stageView(useNewBackdrop: false, showCaptions: false)),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      // The layered scene + its overlays are skipped on the legacy path.
      expect(find.byType(LayeredBackdrop), findsNothing);
      expect(find.byType(StageLightsOverlay), findsNothing);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}

SkinnedMeshSpec _leftArmMesh(RigSpec rig) =>
    rig.meshes.singleWhere((mesh) => mesh.id == 'arm.L.mesh');

double _maxAbsLocalX(SkinnedMeshVertex vertex) => vertex.influences.fold(
  0,
  (maxX, influence) => influence.x.abs() > maxX ? influence.x.abs() : maxX,
);
