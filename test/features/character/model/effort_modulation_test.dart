import 'dart:math';

import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/dance_dynamics.dart';
import 'package:dancing_cats/features/character/model/dance_dynamics_warp.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';
import 'package:flutter_test/flutter_test.dart';

IkTargetChannel _handL(Clip clip) =>
    clip.limbTargets.firstWhere((t) => t.endBoneId == CatBones.handL).channel;

double _xExcursion(IkTargetChannel c) {
  var lo = double.infinity;
  var hi = double.negativeInfinity;
  for (var i = 0; i <= 64; i++) {
    final s = c.sample(i / 64);
    lo = min(lo, s.x);
    hi = max(hi, s.x);
  }
  return hi - lo;
}

void main() {
  group('effort amplitude modulation', () {
    test('scales hand amplitude around its centre (fast timing untouched)', () {
      final clip = CatClips.azonto; // rolling hands = clear excursion
      final base = _xExcursion(_handL(clip));
      expect(base, greaterThan(20), reason: 'azonto roll has real hand travel');

      final low = effortModulatedClip(clip, (p) => 0.6);
      final high = effortModulatedClip(clip, (p) => 1.2);
      final lowEx = _xExcursion(_handL(low));
      final highEx = _xExcursion(_handL(high));

      // 0.6 shrinks the movement, 1.2 grows it — around the same centre.
      expect(lowEx, lessThan(base * 0.75));
      expect(highEx, greaterThan(base * 1.1));
      // A scale of exactly 1 is a no-op (same instance back).
      expect(identical(effortModulatedClip(clip, (p) => 1.0), clip), isFalse,
          reason: 'scale fn is applied; identity only when no hand target');
    });

    test('deterministic variance breathes: not flat, loop-seamless, per-lane', () {
      final s0 = danceEffortScaleOf(DanceDynamics.neutral, 0);

      // NOT FLAT: the effort varies beat to beat across the loop.
      final perBeat = [for (var i = 0; i < 8; i++) s0(i / 8)];
      final spread =
          perBeat.reduce(max) - perBeat.reduce(min);
      expect(spread, greaterThan(0.1),
          reason: 'effort must vary beat to beat, not be a flat scale');

      // LOOP-SEAMLESS: periodic so the amplitude does not jump at the seam.
      expect(s0(0), closeTo(s0(1), 1e-9));

      // PER-LANE DISTINCT: the three dancers do not breathe in lockstep.
      final s1 = danceEffortScaleOf(DanceDynamics.neutral, 1);
      expect((s0(0.3) - s1(0.3)).abs(), greaterThan(1e-3));

      // DETERMINISTIC: same inputs → same output every call.
      expect(s0(0.42), s0(0.42));
    });

    test('higher song energy (Weight) raises the amplitude base', () {
      const calm = DanceDynamics(weight: -0.2);
      const hot = DanceDynamics(weight: 0.2);
      // Average the phase-varying scale over the loop to compare the base level.
      double mean(double Function(double) f) {
        var s = 0.0;
        for (var i = 0; i < 64; i++) {
          s += f(i / 64);
        }
        return s / 64;
      }

      final calmMean = mean(danceEffortScaleOf(calm, 0));
      final hotMean = mean(danceEffortScaleOf(hot, 0));
      expect(hotMean, greaterThan(calmMean),
          reason: 'hot sections move bigger; calm ones smaller (but still fast)');
    });
  });
}
