import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dancing_cats/features/scenery/layers/backdrop_layer.dart';
import 'package:dancing_cats/features/scenery/layers/drone_show_layer.dart';
import 'package:dancing_cats/features/scenery/model/backdrop_palette.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('droneShowTimelineAt', () {
    test('uses a physically slow cycle for aircraft-scale motion', () {
      expect(kDroneShowCycleSeconds, inInclusiveRange(130, 150));
    });

    test('resolves launch, beam, fan, and formation phases', () {
      expect(droneShowTimelineAt(0).phase, DroneShowPhase.launch);
      expect(
        droneShowTimelineAt(kDroneShowCycleSeconds * 0.26).phase,
        DroneShowPhase.beam,
      );
      expect(
        droneShowTimelineAt(kDroneShowCycleSeconds * 0.46).phase,
        DroneShowPhase.fan,
      );
      expect(
        droneShowTimelineAt(kDroneShowCycleSeconds * 0.86).phase,
        DroneShowPhase.formation,
      );
    });

    test('keeps phase progress in bounds and wraps deterministically', () {
      for (final t in const [-10.0, 0.0, 2.5, 8.2, 15.9, 36.2]) {
        final timeline = droneShowTimelineAt(t);
        expect(timeline.progress, inInclusiveRange(0, 1), reason: '$t');
        expect(timeline.cycleProgress, inInclusiveRange(0, 1), reason: '$t');
      }

      final a = droneShowTimelineAt(3.25);
      final b = droneShowTimelineAt(3.25 + kDroneShowCycleSeconds);
      expect(b.phase, a.phase);
      expect(b.progress, closeTo(a.progress, 1e-12));
      expect(b.cycleProgress, closeTo(a.cycleProgress, 1e-12));
    });
  });

  group('droneShowFormationPoints', () {
    test('uses the exact final label', () {
      expect(kDroneShowOpeningText, 'Omah Lay');
      expect(kDroneShowFinalText, 'Moving');
      expect(kDroneShowDroneCount, greaterThanOrEqualTo(260));
    });

    test('generates the requested number of normalized text points', () {
      final points = droneShowFormationPoints(count: 64);

      expect(points, hasLength(64));
      for (final point in points) {
        expect(point.dx, inInclusiveRange(0, 1));
        expect(point.dy, inInclusiveRange(0, 1));
      }
    });

    test('lays out a modest sky text formation', () {
      final points = droneShowFormationPoints();
      final minX = points.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
      final maxX = points.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
      final minY = points.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
      final maxY = points.map((p) => p.dy).reduce((a, b) => a > b ? a : b);

      expect(minX, greaterThanOrEqualTo(0.34));
      expect(maxX, lessThanOrEqualTo(0.66));
      expect(minY, greaterThanOrEqualTo(0.20));
      expect(maxY, lessThanOrEqualTo(0.30));
      expect(maxX - minX, inInclusiveRange(0.25, 0.33));
    });

    test('can lay out the final Moving message', () {
      final points = droneShowFormationPoints(
        text: kDroneShowFinalText,
      );
      final minX = points.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
      final maxX = points.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
      final minY = points.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
      final maxY = points.map((p) => p.dy).reduce((a, b) => a > b ? a : b);

      expect(points, hasLength(kDroneShowDroneCount));
      expect(minX, greaterThanOrEqualTo(0.34));
      expect(maxX, lessThanOrEqualTo(0.66));
      expect(minY, greaterThanOrEqualTo(0.20));
      expect(maxY, lessThanOrEqualTo(0.30));
    });
  });

  group('sampleDroneShow', () {
    test('is deterministic for the same time', () {
      final a = sampleDroneShow(7.125, count: 48);
      final b = sampleDroneShow(7.125, count: 48);

      expect(a, hasLength(b.length));
      for (var i = 0; i < a.length; i++) {
        expect(a[i].phase, b[i].phase);
        expect(a[i].position.dx, closeTo(b[i].position.dx, 1e-12));
        expect(a[i].position.dy, closeTo(b[i].position.dy, 1e-12));
        expect(a[i].opacity, closeTo(b[i].opacity, 1e-12));
        expect(a[i].radius, closeTo(b[i].radius, 1e-12));
        expect(a[i].isLit, b[i].isLit);
      }
    });

    test('starts as two bases bracketing the cable-stayed pylon', () {
      final samples = sampleDroneShow(0, count: 80);
      final xs = samples.map((s) => s.position.dx).toList();
      final minX = xs.reduce((a, b) => a < b ? a : b);
      final maxX = xs.reduce((a, b) => a > b ? a : b);
      final minY = samples
          .map((s) => s.position.dy)
          .reduce((a, b) => a < b ? a : b);
      final maxY = samples
          .map((s) => s.position.dy)
          .reduce((a, b) => a > b ? a : b);

      // The two bases still bracket the police cordon's outer span (x ≈
      // 0.555→0.745), but no drone starts inside the cable-stayed pylon's
      // fanned cables (measured on the shipped plate at x ≈ 0.595→0.705) —
      // a single line across the full span used to pass directly under them.
      expect(minX, greaterThanOrEqualTo(0.55));
      expect(maxX, lessThanOrEqualTo(0.746));
      for (final x in xs) {
        expect(
          x <= 0.595 || x >= 0.705,
          isTrue,
          reason: 'x=$x lands in the cable gap',
        );
      }

      final left = samples.where((s) => s.position.dx <= 0.595).toList();
      final right = samples.where((s) => s.position.dx >= 0.705).toList();
      expect(left.length, 40);
      expect(right.length, 40);

      void expectUniformStep(List<double> vals) {
        final step = vals[1] - vals[0];
        for (var i = 2; i < vals.length; i++) {
          expect(vals[i] - vals[i - 1], closeTo(step, 1e-9));
        }
      }

      expectUniformStep(left.map((s) => s.position.dx).toList());
      expectUniformStep(right.map((s) => s.position.dx).toList());

      expect(minY, greaterThanOrEqualTo(0.468));
      expect(maxY, lessThanOrEqualTo(0.473));
      for (final sample in samples) {
        expect(sample.isLit, isFalse);
        expect(sample.opacity, closeTo(0.64, 1e-12));
        expect(sample.radius, closeTo(0.00185, 1e-12));
      }
    });

    test(
      'uses dense launch rows without visible spacing gaps within each base',
      () {
        final samples = sampleDroneShow(0);
        final left = samples
            .where((s) => s.position.dx <= 0.595)
            .map((s) => s.position.dx)
            .toList();
        final right = samples
            .where((s) => s.position.dx >= 0.705)
            .map((s) => s.position.dx)
            .toList();

        for (final xs in [left, right]) {
          final step = xs[1] - xs[0];
          expect(step, lessThan(0.001));
          for (var i = 2; i < xs.length; i++) {
            expect(xs[i] - xs[i - 1], closeTo(step, 1e-9));
          }
        }
      },
    );

    test('switches lights on progressively after clearing the bridge', () {
      // Sample points moved earlier (0.18/0.219 -> 0.14/0.16): raising the
      // rise height to give the two launch bases room to reunite above the
      // pylon crest (see [_pylonCrestY]) also means drones reach the
      // bridge-clear height sooner, so the whole light-on transition now
      // happens earlier in the launch phase.
      final dark = sampleDroneShow(0, count: 80);
      final partial = sampleDroneShow(
        kDroneShowCycleSeconds * 0.14,
        count: 80,
      );
      final lateLaunch = sampleDroneShow(
        kDroneShowCycleSeconds * 0.16,
        count: 80,
      );
      final lit = sampleDroneShow(
        kDroneShowCycleSeconds * 0.23,
        count: 80,
      );
      final partialLitCount = partial.where((s) => s.isLit).length;
      final lateLitCount = lateLaunch.where((s) => s.isLit).length;

      expect(dark.map((s) => s.isLit), everyElement(isFalse));
      expect(partial.map((s) => s.phase), everyElement(DroneShowPhase.launch));
      expect(partialLitCount, greaterThan(0));
      expect(partialLitCount, lessThan(partial.length));
      expect(
        lateLaunch.map((s) => s.phase),
        everyElement(DroneShowPhase.launch),
      );
      expect(lateLitCount, greaterThan(partialLitCount));
      expect(lateLitCount, greaterThan((lateLaunch.length * 0.9).floor()));
      expect(lit.map((s) => s.phase), everyElement(DroneShowPhase.beam));
      expect(lit.map((s) => s.isLit), everyElement(isTrue));
      for (final sample in lit) {
        expect(sample.opacity, greaterThan(0.69));
        expect(sample.radius, greaterThanOrEqualTo(0.002));
      }
    });

    test('unites above the cable-stayed bridge crown', () {
      final topOfLaunch = sampleDroneShow(
        kDroneShowCycleSeconds * 0.219,
        count: 80,
      );
      final firstBeam = sampleDroneShow(
        kDroneShowCycleSeconds * 0.23,
        count: 80,
      );

      expect(
        topOfLaunch.map((s) => s.phase),
        everyElement(DroneShowPhase.launch),
      );
      expect(firstBeam.map((s) => s.phase), everyElement(DroneShowPhase.beam));
      expect(
        topOfLaunch.map((s) => s.position.dy),
        everyElement(lessThanOrEqualTo(0.36)),
      );
      expect(
        firstBeam.map((s) => s.position.dy),
        everyElement(lessThanOrEqualTo(0.36)),
      );

      // The two split launch bases must be well into reuniting by the top of
      // the launch phase — clearing most of the original ~0.19 base-to-base
      // spread and closing most of the gap between the nearest members of
      // each stream — rather than still reading as two columns either side
      // of a wide gap. (Full single-file union finishes in the early beam
      // phase, above the bridge, where there is no structure left to cross
      // behind — see [_riseJoinFraction].)
      final topX = topOfLaunch.map((s) => s.position.dx).toList()..sort();
      final topSpread = topX.last - topX.first;
      var maxGap = 0.0;
      for (var i = 1; i < topX.length; i++) {
        final gap = topX[i] - topX[i - 1];
        if (gap > maxGap) maxGap = gap;
      }
      expect(
        topSpread,
        lessThan(0.10),
        reason: 'the two launch bases should be closing together, not still '
            'spanning their original spread',
      );
      expect(
        maxGap,
        lessThan(0.05),
        reason: 'no wide dead gap should remain between the two streams',
      );
    });

    test('rises through five local spiral columns per base before the beam', () {
      // count:80 (not the other tests' 40) keeps 8 drones per pod — the
      // granularity this test's vertical-scatter assertion was tuned
      // against — now that the population also splits 40/40 across the two
      // launch bases before each splits further into 5 pods.
      final start = sampleDroneShow(0, count: 80);
      final rising = sampleDroneShow(
        kDroneShowCycleSeconds * 0.15,
        count: 80,
      );

      // Beam-column x for progress u = i/(count-1): the two launch bases
      // reunite into this same narrow column well before the beam phase
      // (see [_risePoint]), so ascent should already be closing on it. Judge
      // convergence in AGGREGATE (mean distance to the column), not
      // per-drone: a drone that starts almost exactly on the column already
      // (near the base edge closest to the gap) has so little room left to
      // close that the ascent's small decorative spiral jitter can nudge it
      // fractionally further away without contradicting the overall pull
      // toward the column.
      double beamX(int i) => 0.70 + (i / (start.length - 1) - 0.5) * 0.04;
      double meanDistToBeam(List<DroneShowSample> samples) {
        var total = 0.0;
        for (var i = 0; i < samples.length; i++) {
          total += (samples[i].position.dx - beamX(i)).abs();
        }
        return total / samples.length;
      }

      for (var i = 0; i < start.length; i++) {
        expect(rising[i].phase, DroneShowPhase.launch);
        expect(rising[i].position.dy, lessThan(start[i].position.dy));
      }
      expect(
        meanDistToBeam(rising),
        lessThan(meanDistToBeam(start)),
        reason: 'the population should be converging on the beam column',
      );

      // The first half of the population by index is the LEFT base, the
      // rest the RIGHT (see [_launchX]); each base further subdivides its
      // own 40 into 5 local spiral pods of 8.
      final bases = [rising.take(40).toList(), rising.skip(40).take(40).toList()];
      for (final baseSamples in bases) {
        for (var pod = 0; pod < 5; pod++) {
          final podSamples = baseSamples.skip(pod * 8).take(8).toList();
          final minX = podSamples
              .map((s) => s.position.dx)
              .reduce((a, b) => a < b ? a : b);
          final maxX = podSamples
              .map((s) => s.position.dx)
              .reduce((a, b) => a > b ? a : b);
          final minY = podSamples
              .map((s) => s.position.dy)
              .reduce((a, b) => a < b ? a : b);
          final maxY = podSamples
              .map((s) => s.position.dy)
              .reduce((a, b) => a > b ? a : b);

          expect(maxX - minX, lessThan(0.07), reason: 'pod $pod');
          expect(maxY - minY, greaterThan(0.01), reason: 'pod $pod');
        }
      }
    });

    test('shows Omah Lay first, then Moving', () {
      final opening = sampleDroneShow(kDroneShowCycleSeconds * 0.68, count: 80);
      final openingTarget = droneShowFormationPoints(count: 80);
      final finalText = sampleDroneShow(
        kDroneShowCycleSeconds * 0.9,
        count: 80,
      );
      final finalTarget = droneShowFormationPoints(
        count: 80,
        text: kDroneShowFinalText,
      );

      for (var i = 0; i < opening.length; i++) {
        expect(opening[i].position.dx, closeTo(openingTarget[i].dx, 1e-12));
        expect(opening[i].position.dy, closeTo(openingTarget[i].dy, 1e-12));
        expect(finalText[i].position.dx, closeTo(finalTarget[i].dx, 1e-12));
        expect(finalText[i].position.dy, closeTo(finalTarget[i].dy, 1e-12));
      }
    });

    test('uses a coordinated staging line between text messages', () {
      final midTransition = sampleDroneShow(
        kDroneShowCycleSeconds * 0.83,
        count: 80,
      );
      final minY = midTransition
          .map((s) => s.position.dy)
          .reduce((a, b) => a < b ? a : b);
      final maxY = midTransition
          .map((s) => s.position.dy)
          .reduce((a, b) => a > b ? a : b);

      expect(
        midTransition.map((s) => s.phase),
        everyElement(DroneShowPhase.formation),
      );
      expect(maxY - minY, lessThan(0.03));
    });

    test('limits one-second travel so drones do not read as particles', () {
      // Widened from 0.018 when the beam formation moved off the lead
      // singer's screen axis (a deliberately longer rise→beam transit, ridden
      // on a constant-cruise profile with an upward bow): ~0.02/s normalized
      // is still a calm glide on screen, and the bound still catches genuine
      // particle-speed regressions.
      const maxNormalizedStepPerSecond = 0.021;

      for (var t = 0.0; t < kDroneShowCycleSeconds - 1; t += 1) {
        final a = sampleDroneShow(t, count: 80);
        final b = sampleDroneShow(t + 1, count: 80);

        for (var i = 0; i < a.length; i++) {
          final dx = b[i].position.dx - a[i].position.dx;
          final dy = b[i].position.dy - a[i].position.dy;
          final distance = math.sqrt(dx * dx + dy * dy);
          expect(
            distance,
            lessThanOrEqualTo(maxNormalizedStepPerSecond),
            reason: 'drone $i at t=$t',
          );
        }
      }
    });

    test('settles into final text and holds the formation', () {
      final settled = sampleDroneShow(kDroneShowCycleSeconds * 0.9, count: 80);
      final held = sampleDroneShow(kDroneShowCycleSeconds * 0.95, count: 80);

      expect(
        settled.map((s) => s.phase),
        everyElement(DroneShowPhase.formation),
      );
      for (var i = 0; i < settled.length; i++) {
        expect(settled[i].position.dx, closeTo(held[i].position.dx, 1e-12));
        expect(settled[i].position.dy, closeTo(held[i].position.dy, 1e-12));
      }
    });

    test('reduced motion returns a static formation frame', () {
      final a = sampleDroneShow(1, reducedMotion: true, count: 40);
      final b = sampleDroneShow(99, reducedMotion: true, count: 40);

      expect(a.map((s) => s.phase), everyElement(DroneShowPhase.formation));
      final finalTarget = droneShowFormationPoints(
        count: 40,
        text: kDroneShowFinalText,
      );
      for (var i = 0; i < a.length; i++) {
        expect(a[i].position.dx, closeTo(b[i].position.dx, 1e-12));
        expect(a[i].position.dy, closeTo(b[i].position.dy, 1e-12));
        expect(a[i].position.dx, closeTo(finalTarget[i].dx, 1e-12));
        expect(a[i].position.dy, closeTo(finalTarget[i].dy, 1e-12));
        expect(a[i].opacity, closeTo(b[i].opacity, 1e-12));
        expect(a[i].isLit, isTrue);
        expect(b[i].isLit, isTrue);
      }
    });

    test('reduced motion respects custom cycle lengths', () {
      final samples = sampleDroneShow(
        1,
        reducedMotion: true,
        count: 12,
        cycleSeconds: 6,
      );

      expect(
        samples.map((s) => s.phase),
        everyElement(DroneShowPhase.formation),
      );
    });

    test('keeps sampled drones in basic sky bounds', () {
      for (final time in const [0.0, 2.0, 5.5, 9.5, 14.5, 17.5]) {
        final samples = sampleDroneShow(time, count: 80);
        expect(samples, hasLength(80));
        for (final sample in samples) {
          expect(sample.position.dx, inInclusiveRange(0.15, 0.85));
          expect(sample.position.dy, inInclusiveRange(0.10, 0.65));
          expect(sample.opacity, inInclusiveRange(0, 1));
          expect(sample.radius, inInclusiveRange(0.0015, 0.0035));
        }
      }
    });
  });

  group('DroneShowLayer.paint', () {
    test('can split launch-road and sky phases for scene compositing', () {
      const launchLayer = DroneShowLayer.launchRoad();
      const skyLayer = DroneShowLayer.sky();

      expect(launchLayer.visiblePhases, {DroneShowPhase.launch});
      expect(skyLayer.visiblePhases, isNot(contains(DroneShowPhase.launch)));
      expect(skyLayer.visiblePhases, contains(DroneShowPhase.beam));
      expect(skyLayer.visiblePhases, contains(DroneShowPhase.fan));
      expect(skyLayer.visiblePhases, contains(DroneShowPhase.formation));
    });

    test('does not throw and uses the BackdropLayer contract', () {
      const layer = DroneShowLayer(droneCount: 16);
      const asLayer = layer as BackdropLayer;
      final recorder = ui.PictureRecorder();

      expect(
        () => asLayer.paint(
          ui.Canvas(recorder),
          const BackdropContext(
            size: ui.Size(320, 180),
            timeSeconds: 8,
            palette: kBlueHourPalette,
          ),
        ),
        returnsNormally,
      );
      recorder.endRecording().dispose();
    });

    test(
      'paints lit halos and cores for the reduce-motion hold frame',
      () async {
        // A runtime (non-const) construction so the default constructor is
        // exercised, then a reduce-motion paint: that pins the show to its
        // formation hold where every drone is lit, driving the additive
        // halo + core draw path (not just the unlit dark-body dots).
        // ignore: prefer_const_constructors
        final layer = DroneShowLayer(droneCount: 24);
        const w = 320;
        const h = 180;
        final recorder = ui.PictureRecorder();
        layer.paint(
          ui.Canvas(recorder),
          const BackdropContext(
            size: ui.Size(320, 180),
            timeSeconds: 3, // ignored under reduce-motion (pins to the hold)
            palette: kBlueHourPalette,
            reducedMotion: true,
          ),
        );
        final image = await recorder.endRecording().toImage(w, h);
        final data = (await image.toByteData())!.buffer.asUint8List();
        image.dispose();

        var litPixels = 0;
        for (var i = 3; i < data.length; i += 4) {
          if (data[i] != 0) litPixels++;
        }
        expect(
          litPixels,
          greaterThan(0),
          reason: 'lit formation drones add halos + bright cores to the frame',
        );
      },
    );
  });
}
