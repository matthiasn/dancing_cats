import 'dart:ui';

import 'package:dancing_cats/features/character/runtime/limb_ribbon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('limbRibbonPath', () {
    test('a straight tapered chain fills its centreline and tapers', () {
      // Vertical spine, wide at the top (half-width 12) tapering to 6.
      final path = limbRibbonPath(
        const [Offset.zero, Offset(0, 60), Offset(0, 120)],
        const [12, 9, 6],
      );

      final b = path.getBounds();
      // Widest at the top cap: spans roughly ±12 in x, and the round caps add the
      // half-width beyond each end in y.
      expect(b.left, closeTo(-12, 1.5));
      expect(b.right, closeTo(12, 1.5));
      expect(b.top, closeTo(-12, 1.5));
      expect(b.bottom, closeTo(126, 1.5));

      // The centreline is inside the filled ribbon.
      expect(path.contains(const Offset(0, 60)), isTrue);
      expect(path.contains(const Offset(0, 5)), isTrue);

      // Taper: x=10 is inside near the WIDE top (half-width ~12) but outside near
      // the NARROW bottom (half-width ~6).
      expect(path.contains(const Offset(10, 6)), isTrue);
      expect(path.contains(const Offset(10, 116)), isFalse);

      // Well outside the limb entirely.
      expect(path.contains(const Offset(60, 60)), isFalse);
    });

    test('a bent chain produces a continuous shape spanning the bend', () {
      // Knee kicks out to +x: hip (0,0) -> knee (30,55) -> ankle (0,110).
      final path = limbRibbonPath(
        const [Offset.zero, Offset(30, 55), Offset(0, 110)],
        const [12, 10, 7],
      );
      final b = path.getBounds();
      // The ribbon must reach out past the knee (x well beyond 30 - its width).
      expect(b.right, greaterThan(34));
      // And it stays a single closed region: a point just inside the knee bend is
      // filled, a point far outside is not.
      expect(path.contains(const Offset(28, 55)), isTrue);
      expect(path.contains(const Offset(80, 55)), isFalse);
    });

    test('flat caps preserve taper without capsule end bulges', () {
      final path = limbRibbonPath(
        const [Offset.zero, Offset(0, 60)],
        const [12, 6],
        roundCaps: false,
      );

      final b = path.getBounds();
      expect(b.left, closeTo(-12, 0.1));
      expect(b.right, closeTo(12, 0.1));
      expect(b.top, closeTo(0, 0.1));
      expect(b.bottom, closeTo(60, 0.1));
      expect(path.contains(Offset.zero), isTrue);
      expect(path.contains(const Offset(0, -6)), isFalse);
      expect(path.contains(const Offset(0, 66)), isFalse);
    });

    test('degenerate input is handled (no crash, empty path)', () {
      expect(
        limbRibbonPath(const [Offset.zero], const [10]).getBounds(),
        Rect.zero,
      );
    });
  });

  group('outer-spike silhouette constraint', () {
    // The batwing regression: where an arm's spine hairpins (the anti-hinge
    // shoulder socket reversing, or a near-degenerate elbow fold), the outer
    // offset edge used to mitre into a pointed "batwing" flap. limbRibbonPath
    // now bounds every outer-edge vertex's bulge past its neighbours' chord to
    // kOuterSpikeMaxChordDeviation of its half-width, so the sleeve rounds
    // instead of spiking — regardless of pose. These tests pin that invariant.

    // Comfortably above the constrained residual the three-pass relaxation
    // leaves (measured worst across the catalogue: ~0.22) and comfortably below
    // an unconstrained batwing (measured: arms 0.60–0.76, legs ~0.37). A value
    // in this gap means the spike is back. See
    // ribbon_silhouette_integrity_test.dart, which holds the same ceiling across
    // every catalogue pose driven through the scene.
    const spikeCeiling = 0.32;

    test('a smooth tapered ribbon has essentially no outer spike', () {
      // A gentle vertical taper — no hairpin anywhere — must read as ~0 spike.
      final spike = limbRibbonMaxOuterSpike(
        const [Offset.zero, Offset(4, 60), Offset(0, 120)],
        const [12, 9, 6],
      );
      expect(spike, lessThan(0.05));
    });

    test("the catalogue's worst batwing pose is tamed to a rounded shoulder",
        () {
      // Captured from the live rig: pouncingCat's arm.L ribbon spine at
      // frame 59/96 — the single hardest hairpin in the catalogue (the wrist
      // reaches across to x≈46 then the chain folds back to x≈97). WITHOUT the
      // constraint this outer edge spikes to ~0.76x its half-width past the
      // chord; with it, the flap must fall well under the ceiling.
      const spine = [
        Offset(101.433, 234.516),
        Offset(101.218, 241.169),
        Offset(76.149, 241.831),
        Offset(46.420, 245.757),
        Offset(73.401, 250.563),
        Offset(96.704, 254.712),
      ];
      const halfWidths = [10.8, 11.0, 11.2, 7.2, 8.5, 5.2];
      const backHalfWidths = [10.4, 10.4, 10.2, 7.4, 7.2, 5.0];
      const jointTensions = [0.42, 0.42, 0.52, 0.74, 0.74, 0.74];

      final spike = limbRibbonMaxOuterSpike(
        spine,
        halfWidths,
        backHalfWidths: backHalfWidths,
        jointTensions: jointTensions,
        samplesPerSegment: 12,
      );
      expect(spike, lessThan(spikeCeiling));
    });
  });
}
