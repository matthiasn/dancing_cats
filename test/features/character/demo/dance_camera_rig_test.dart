import 'package:dancing_cats/features/character/demo/dance_camera_rig.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('smoothDamp', () {
    test('converges onto a held target and settles (velocity → 0)', () {
      var value = 0.0;
      var velocity = 0.0;
      // ~5s at 60fps toward a held target, many smoothTimes past arrival.
      for (var i = 0; i < 300; i++) {
        final r = smoothDamp(
          current: value,
          target: 10,
          velocity: velocity,
          smoothTime: 0.5,
          dt: 1 / 60,
        );
        value = r.value;
        velocity = r.velocity;
      }
      expect(value, moreOrLessEquals(10, epsilon: 1e-2));
      expect(velocity, moreOrLessEquals(0, epsilon: 1e-1));
    });

    test('approaches a step without ever overshooting it', () {
      var value = 0.0;
      var velocity = 0.0;
      var maxSeen = value;
      for (var i = 0; i < 300; i++) {
        final r = smoothDamp(
          current: value,
          target: 5,
          velocity: velocity,
          smoothTime: 0.3,
          dt: 1 / 60,
        );
        value = r.value;
        velocity = r.velocity;
        if (value > maxSeen) maxSeen = value;
        // Monotonic, no bounce past the target — the hallmark of a clean dolly
        // settle rather than a spring.
        expect(value, lessThanOrEqualTo(5 + 1e-9), reason: 'step $i');
      }
      expect(maxSeen, lessThanOrEqualTo(5 + 1e-9));
      expect(value, moreOrLessEquals(5, epsilon: 1e-3));
    });

    test('a larger smoothTime moves slower over the same elapsed time', () {
      double after(double smoothTime, {required int steps}) {
        var value = 0.0;
        var velocity = 0.0;
        for (var i = 0; i < steps; i++) {
          final r = smoothDamp(
            current: value,
            target: 1,
            velocity: velocity,
            smoothTime: smoothTime,
            dt: 1 / 60,
          );
          value = r.value;
          velocity = r.velocity;
        }
        return value;
      }

      // Same elapsed time (0.5s); the slower rig is further from the target.
      final fast = after(0.3, steps: 30);
      final slow = after(0.9, steps: 30);
      expect(slow, lessThan(fast));
      expect(fast, greaterThan(0)); // both are moving, just at different rates
    });

    test('is ~frame-rate independent (same elapsed time → same value)', () {
      double after(double dt, {required int steps}) {
        var value = 0.0;
        var velocity = 0.0;
        for (var i = 0; i < steps; i++) {
          final r = smoothDamp(
            current: value,
            target: 1,
            velocity: velocity,
            smoothTime: 0.5,
            dt: dt,
          );
          value = r.value;
          velocity = r.velocity;
        }
        return value;
      }

      // 0.5s reached at 60fps (30 steps) vs 30fps (15 steps) lands within a
      // small tolerance — the move does not depend on the tick rate.
      final at60 = after(1 / 60, steps: 30);
      final at30 = after(1 / 30, steps: 15);
      expect(at60, moreOrLessEquals(at30, epsilon: 0.02));
    });

    test('a non-positive dt holds the value', () {
      final r = smoothDamp(
        current: 3,
        target: 9,
        velocity: 2,
        smoothTime: 0.5,
        dt: 0,
      );
      expect(r.value, 3);
      expect(r.velocity, 2);
    });
  });

  group('DanceCameraRig', () {
    test('the first update snaps to the target (no easing from nowhere)', () {
      final rig = DanceCameraRig();
      expect(rig.isInitialized, isFalse);
      const target = (zoom: 1.5, dx: 200.0, dy: 0.0);
      final out = rig.update(target: target, punch: false, dt: 1 / 60);
      expect(out, target);
      expect(rig.current, target);
      expect(rig.isInitialized, isTrue);
    });

    test('a non-cut update eases toward the target instead of jumping', () {
      final rig = DanceCameraRig()
        ..update(target: (zoom: 1.5, dx: 0, dy: 0), punch: false, dt: 1 / 60);
      const target = (zoom: 2.1, dx: 400.0, dy: 0.0);
      final out = rig.update(target: target, punch: false, dt: 1 / 60);
      // Moved toward the target on each component, but nowhere near arriving in
      // one frame — a dolly, not a cut.
      expect(out.zoom, greaterThan(1.5));
      expect(out.zoom, lessThan(target.zoom));
      expect(out.dx, greaterThan(0));
      expect(out.dx, lessThan(target.dx));
    });

    test('a punch zooms fast toward the target but never teleports', () {
      // Same one-frame move, played as a punch and as a normal glide.
      final fast =
          (DanceCameraRig()
                ..update(
                  target: (zoom: 1.4, dx: 0, dy: 0),
                  punch: false,
                  dt: 1 / 60,
                ))
              .update(target: (zoom: 2.1, dx: 400, dy: 0), punch: true, dt: 1 / 60);
      final slow =
          (DanceCameraRig()
                ..update(
                  target: (zoom: 1.4, dx: 0, dy: 0),
                  punch: false,
                  dt: 1 / 60,
                ))
              .update(
                target: (zoom: 2.1, dx: 400, dy: 0),
                punch: false,
                dt: 1 / 60,
              );
      // A punch is still continuous — it does NOT snap to the target in one
      // frame (that was the old hard cut)...
      expect(fast.zoom, greaterThan(1.4));
      expect(fast.zoom, lessThan(2.1));
      expect(fast.dx, lessThan(400));
      // ...but it covers much more ground per frame than the slow glide: a fast
      // zoom, not a teleport and not a lazy dolly.
      expect(fast.zoom, greaterThan(slow.zoom));
      expect(fast.dx, greaterThan(slow.dx));
    });

    test('a held punch settles onto its home within about a second', () {
      final rig = DanceCameraRig()
        ..update(target: (zoom: 1.06, dx: 0, dy: 0), punch: false, dt: 1 / 60);
      const home = (zoom: 1.44, dx: 200.0, dy: 0.0);
      // ~1s of punching (60 frames at 60fps) — several punch time-constants at
      // the slowed 0.30s punch, so the fast zoom has essentially arrived. A slow
      // glide is still well short by this point (see the contrast test below).
      for (var i = 0; i < 60; i++) {
        rig.update(target: home, punch: true, dt: 1 / 60);
      }
      expect(rig.current.zoom, moreOrLessEquals(home.zoom, epsilon: 1e-2));
      expect(rig.current.dx, moreOrLessEquals(home.dx, epsilon: 2));
    });

    test('a punch is faster than a glide over the same elapsed time', () {
      double zoomAfter({required bool punch, required int steps}) {
        final rig = DanceCameraRig()
          ..update(target: (zoom: 1.0, dx: 0, dy: 0), punch: false, dt: 1 / 60);
        for (var i = 0; i < steps; i++) {
          rig.update(target: (zoom: 2.0, dx: 0, dy: 0), punch: punch, dt: 1 / 60);
        }
        return rig.current.zoom;
      }

      // After 0.1s the punch has covered far more of the 1.0 -> 2.0 push than the
      // slow glide has.
      expect(zoomAfter(punch: true, steps: 6), greaterThan(zoomAfter(punch: false, steps: 6)));
    });

    test('eventually converges onto a held target', () {
      final rig = DanceCameraRig()
        ..update(target: (zoom: 1.06, dx: 0, dy: 8), punch: false, dt: 1 / 60);
      const home = (zoom: 1.52, dx: 220.0, dy: 0.0);
      for (var i = 0; i < 300; i++) {
        rig.update(target: home, punch: false, dt: 1 / 60);
      }
      expect(rig.current.zoom, moreOrLessEquals(home.zoom, epsilon: 1e-2));
      expect(rig.current.dx, moreOrLessEquals(home.dx, epsilon: 1));
      expect(rig.current.dy, moreOrLessEquals(home.dy, epsilon: 1e-1));
    });

    test('a non-positive dt holds the framing (no snap on a stalled tick)', () {
      final rig = DanceCameraRig()
        ..update(target: (zoom: 1.5, dx: 100, dy: 0), punch: false, dt: 1 / 60);
      final held = rig.current;
      final out = rig.update(
        target: (zoom: 2.0, dx: 0, dy: 0),
        punch: false,
        dt: 0,
      );
      expect(out, held);
    });
  });
}
