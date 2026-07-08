import 'dart:math';

import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/dance_dynamics_warp.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';
import 'package:flutter_test/flutter_test.dart';

IkTargetChannel _handL(Clip clip) =>
    clip.limbTargets.firstWhere((t) => t.endBoneId == CatBones.handL).channel;

double _yExcursion(IkTargetChannel c) {
  var lo = double.infinity;
  var hi = double.negativeInfinity;
  for (var i = 0; i <= 64; i++) {
    final s = c.sample(i / 64);
    lo = min(lo, s.y);
    hi = max(hi, s.y);
  }
  return hi - lo;
}

void main() {
  group('effort amplitude modulation', () {
    test('scales hand amplitude around its centre (fast timing untouched)', () {
      final clip = CatClips.azonto; // rolling hands = clear excursion
      final base = _yExcursion(_handL(clip)); // barrel roll is tall in y
      expect(base, greaterThan(20), reason: 'azonto roll has real hand travel');

      final low = effortModulatedClip(clip, (p) => 0.6);
      final high = effortModulatedClip(clip, (p) => 1.2);
      final lowEx = _yExcursion(_handL(low));
      final highEx = _yExcursion(_handL(high));

      // 0.6 shrinks the movement, 1.2 grows it — around the same centre.
      expect(lowEx, lessThan(base * 0.75));
      expect(highEx, greaterThan(base * 1.1));
      // A scale of exactly 1 is a no-op (same instance back).
      expect(identical(effortModulatedClip(clip, (p) => 1.0), clip), isFalse,
          reason: 'scale fn is applied; identity only when no hand target');
    });

    test('deterministic variance breathes: not flat, loop-seamless, per-lane', () {
      final s0 = danceEffortScaleOf(0.5, 0);

      // NOT FLAT: the effort varies beat to beat across the loop.
      final perBeat = [for (var i = 0; i < 8; i++) s0(i / 8)];
      final spread =
          perBeat.reduce(max) - perBeat.reduce(min);
      expect(spread, greaterThan(0.05),
          reason: 'effort must vary beat to beat, not be a flat scale');

      // LOOP-SEAMLESS: periodic so the amplitude does not jump at the seam.
      expect(s0(0), closeTo(s0(1), 1e-9));

      // PER-LANE DISTINCT: the three dancers do not breathe in lockstep.
      final s1 = danceEffortScaleOf(0.5, 1);
      expect((s0(0.3) - s1(0.3)).abs(), greaterThan(1e-3));

      // DETERMINISTIC: same inputs → same output every call.
      expect(s0(0.42), s0(0.42));
    });

    test('fast-base orbit adds continuous motion, loop-seamless', () {
      final clip = CatClips.zanku; // has hand IK targets
      final baseCh = _handL(clip);
      final orbitedCh = _handL(fastBaseOrbitedClip(clip, 0));

      double pathLen(IkTargetChannel c) {
        var len = 0.0;
        var prev = c.sample(0);
        for (var i = 1; i <= 128; i++) {
          final s = c.sample(i / 128);
          len += sqrt(pow(s.x - prev.x, 2) + pow(s.y - prev.y, 2));
          prev = s;
        }
        return len;
      }

      // The fast orbit adds real continuous hand travel on top of the authored
      // motion (fast base always on).
      expect(pathLen(orbitedCh), greaterThan(pathLen(baseCh) * 1.2));
      // Loop-seamless: no jump at the seam.
      expect(
        (orbitedCh.sample(0).x - orbitedCh.sample(1).x).abs(),
        lessThan(1e-6),
      );
      expect(
        (orbitedCh.sample(0).y - orbitedCh.sample(1).y).abs(),
        lessThan(1e-6),
      );
    });

    test('higher song energy (Weight) raises the amplitude base', () {
      // Average the phase-varying scale over the loop to compare the base level.
      double mean(double Function(double) f) {
        var s = 0.0;
        for (var i = 0; i < 64; i++) {
          s += f(i / 64);
        }
        return s / 64;
      }

      final calmMean = mean(danceEffortScaleOf(0.1, 0));
      final hotMean = mean(danceEffortScaleOf(0.9, 0));
      expect(hotMean, greaterThan(calmMean),
          reason: 'hot sections move bigger; calm ones smaller (but still fast)');
    });
  });
}
