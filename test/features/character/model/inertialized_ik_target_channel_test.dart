import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit tests for the periodic boundary-value spring that interpolates sparse
/// authored hit-poses ([InertializedIkTargetChannel]) — verified in isolation
/// before it is wired into a move, since it is the Phase-2 mechanism the whole
/// "minimal keyframing" capability rests on.
void main() {
  // Two sparse hits on a loop: 0 → 10 → (back to 0). The interpolator must
  // hold each hit, then snap into the next, landing it exactly on its phase.
  List<IkTargetKeyframe> twoHits() => const [
    IkTargetKeyframe(p: 0, x: 0, y: 0),
    IkTargetKeyframe(p: 0.5, x: 10, y: -4),
  ];

  InertializedIkTargetChannel channel({
    double zeta = 1.2,
    double omegaN = 13,
  }) => InertializedIkTargetChannel(
    twoHits(),
    duration: 6,
    omegaN: omegaN,
    zeta: zeta,
  );

  test('hits every authored key exactly (equality-pinned)', () {
    final c = channel();
    expect(c.sample(0).x, closeTo(0, 1e-9));
    expect(c.sample(0).y, closeTo(0, 1e-9));
    expect(c.sample(0.5).x, closeTo(10, 1e-9));
    expect(c.sample(0.5).y, closeTo(-4, 1e-9));
  });

  test('is periodic: the loop seam closes (phase 0 == phase 1)', () {
    final c = channel();
    expect(c.sample(1).x, closeTo(c.sample(0).x, 1e-9));
    // Continuous across the seam (approach from below ≈ depart from above).
    expect(c.sample(0.999).x, closeTo(c.sample(0.001).x, 0.5));
  });

  test('holds the hit then snaps — not a linear/Catmull swoosh', () {
    final c = channel(zeta: 1.3);
    // Quarter-way through the first segment the hand should still be near the
    // held hit (0), nowhere near the linear midpoint (5) a plain interpolator
    // would give — that is the "park" a swoosh cannot produce.
    final mid = c.sample(0.25).x;
    expect(mid, lessThan(3), reason: 'should still be parked near hit 0');
    // The bulk of the travel happens late (the snap): most of the 0→10 rise is
    // in the last quarter of the segment, not spread evenly like a swoosh.
    final threeQuarter = c.sample(0.375).x;
    expect(
      c.sample(0.5).x - threeQuarter,
      greaterThan(threeQuarter - mid),
      reason: 'more of the rise is packed into the final snap than the hold',
    );
  });

  test('over-damped stays within the hit envelope (no overshoot)', () {
    final c = channel(zeta: 1.4);
    for (var i = 0; i < 256; i++) {
      final x = c.sample(i / 256).x;
      expect(x, greaterThan(-0.6));
      expect(x, lessThan(10.6));
    }
  });

  test('under-damped overshoots the hit envelope (the alive lobe)', () {
    final c = channel(zeta: 0.35);
    var maxX = double.negativeInfinity;
    var minX = double.infinity;
    for (var i = 0; i < 256; i++) {
      final x = c.sample(i / 256).x;
      if (x > maxX) maxX = x;
      if (x < minX) minX = x;
    }
    // A Free/under-damped spring rings past the hit before settling; a Bound
    // one never would.
    expect(
      maxX > 10.3 || minX < -0.3,
      isTrue,
      reason: 'under-damped should overshoot the [0,10] hit envelope',
    );
  });
}
