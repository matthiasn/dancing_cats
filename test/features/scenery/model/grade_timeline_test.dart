import 'package:dancing_cats/features/scenery/model/backdrop_grade.dart';
import 'package:dancing_cats/features/scenery/model/grade_timeline.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;

/// A non-neutral look with every field off its detent, for round-trip tests.
const GradeLook _fullLook = GradeLook(
  lift: GradeWheel(balance: Offset(0.1, -0.2), master: 0.15),
  gamma: GradeWheel(balance: Offset(-0.05, 0.3), master: -0.1),
  gain: GradeWheel(balance: Offset(0.25, 0.05), master: 0.2),
  saturation: 0.8,
  temperature: 0.3,
  tint: -0.15,
  contrast: 1.25,
  pivot: 0.5,
);

GradeKeyframe _key(
  double t, {
  GradeLook look = _fullLook,
  GradeInterp interp = GradeInterp.smooth,
}) => GradeKeyframe(tSec: t, look: look, interp: interp);

/// A look whose only signal is the saturation dial — handy for asserting
/// interpolated positions on a single scalar.
GradeLook _satLook(double saturation) => GradeLook(saturation: saturation);

extension _AnyGradeTimeline on glados.Any {
  /// A generous wheel-space look: pucks and dials off-centre in their real
  /// UI ranges.
  glados.Generator<GradeLook> get gradeLook =>
      glados.CombinableAny(this).combine4(
        glados.DoubleAnys(this).doubleInRange(-1, 1),
        glados.DoubleAnys(this).doubleInRange(-1, 1),
        glados.DoubleAnys(this).doubleInRange(0, 2),
        glados.DoubleAnys(this).doubleInRange(0.5, 1.8),
        // Balances scaled to stay inside the unit wheel (the parse clamp
        // would otherwise make a >1-radius round-trip legitimately lossy).
        (x, y, sat, con) => GradeLook(
          lift: GradeWheel(balance: Offset(x, y) * 0.7, master: y),
          gamma: GradeWheel(balance: Offset(y, x) * 0.7, master: x),
          gain: GradeWheel(balance: Offset(x, x) * 0.7, master: y),
          saturation: sat,
          temperature: x,
          tint: y,
          contrast: con,
          pivot: 0.2 + sat / 10,
        ),
      );

  /// A lane of up to four keyframes at distinct times with mixed curves.
  glados.Generator<GradeLane> get gradeLane =>
      glados.CombinableAny(this).combine3(
        glados.DoubleAnys(this).doubleInRange(0, 30),
        glados.DoubleAnys(this).doubleInRange(0.1, 30),
        gradeLook,
        (t0, dt, look) => GradeLane(
          target: GradeTargets.master,
          keyframes: [
            GradeKeyframe(tSec: t0, look: look),
            GradeKeyframe(
              tSec: t0 + dt,
              look: GradeLook.neutral,
              interp: GradeInterp.linear,
            ),
            GradeKeyframe(
              tSec: t0 + 2 * dt,
              look: look,
              interp: GradeInterp.hold,
            ),
          ],
        ),
      );
}

void main() {
  group('GradeLook', () {
    test('the default look is neutral and maps to the identity grade', () {
      expect(GradeLook.neutral.isNeutral, isTrue);
      expect(GradeLook.neutral.toGrade(), BackdropGrade.identity);
    });

    test('any single moved control makes the look non-neutral', () {
      const w = GradeWheel(master: 0.1);
      expect(const GradeLook(lift: w).isNeutral, isFalse);
      expect(const GradeLook(gamma: w).isNeutral, isFalse);
      expect(const GradeLook(gain: w).isNeutral, isFalse);
      expect(const GradeLook(saturation: 0.9).isNeutral, isFalse);
      expect(const GradeLook(temperature: 0.1).isNeutral, isFalse);
      expect(const GradeLook(tint: -0.1).isNeutral, isFalse);
      expect(const GradeLook(contrast: 1.1).isNeutral, isFalse);
    });

    test('a moved pivot alone stays neutral (contrast 1 ignores it)', () {
      expect(const GradeLook(pivot: 0.6).isNeutral, isTrue);
    });

    test('toGrade routes through the console wheel mapping', () {
      expect(
        _fullLook.toGrade(),
        gradeFromWheels(
          lift: _fullLook.lift,
          gamma: _fullLook.gamma,
          gain: _fullLook.gain,
          saturation: _fullLook.saturation,
          temperature: _fullLook.temperature,
          tint: _fullLook.tint,
          contrast: _fullLook.contrast,
          pivot: _fullLook.pivot,
        ),
      );
    });

    test('lerpTo hits both endpoints exactly', () {
      expect(GradeLook.neutral.lerpTo(_fullLook, 0), GradeLook.neutral);
      expect(GradeLook.neutral.lerpTo(_fullLook, 1), _fullLook);
    });

    test('lerpTo midpoint averages every component', () {
      final mid = GradeLook.neutral.lerpTo(_fullLook, 0.5);
      expect(mid.saturation, closeTo(0.9, 1e-12));
      expect(mid.contrast, closeTo(1.125, 1e-12));
      expect(mid.temperature, closeTo(0.15, 1e-12));
      expect(mid.tint, closeTo(-0.075, 1e-12));
      expect(mid.pivot, closeTo((kGradePivotDefault + 0.5) / 2, 1e-12));
      expect(mid.lift.balance.dx, closeTo(0.05, 1e-12));
      expect(mid.lift.balance.dy, closeTo(-0.1, 1e-12));
      expect(mid.gain.master, closeTo(0.1, 1e-12));
    });

    test(
      'a puck lerp runs straight through centre, not around the hue circle',
      () {
        const left = GradeLook(lift: GradeWheel(balance: Offset(-0.5, 0)));
        const right = GradeLook(lift: GradeWheel(balance: Offset(0.5, 0)));
        final mid = left.lerpTo(right, 0.5);
        expect(mid.lift.balance, Offset.zero);
      },
    );

    test('toJson writes the FULL look — every field, every wheel axis', () {
      final json = GradeLook.neutral.toJson();
      expect(
        json.keys,
        containsAll([
          'lift',
          'gamma',
          'gain',
          'saturation',
          'temperature',
          'tint',
          'contrast',
          'pivot',
        ]),
      );
      final lift = json['lift']! as Map<String, Object?>;
      expect(lift.keys, containsAll(['x', 'y', 'm']));
    });

    test('fromJson of an empty object is neutral', () {
      expect(GradeLook.fromJson(const {}), GradeLook.neutral);
    });

    test('JSON round-trip preserves every field', () {
      expect(GradeLook.fromJson(_fullLook.toJson()), _fullLook);
    });

    test(
      'omitted fields inherit from the base look, never reset to neutral',
      () {
        // The panel's headline schema fix: a minimal LLM keyframe like
        // {"saturation": 0.8} must hold everything else it doesn't mention.
        final sparse = GradeLook.fromJson(const {
          'saturation': 0.6,
        }, base: _fullLook);
        expect(sparse.saturation, 0.6);
        expect(sparse.temperature, _fullLook.temperature);
        expect(sparse.lift, _fullLook.lift);
        expect(sparse.contrast, _fullLook.contrast);
        expect(sparse.pivot, _fullLook.pivot);
      },
    );

    test('omitted wheel axes inherit from the base wheel', () {
      final sparse = GradeLook.fromJson(const {
        'gain': {'m': 0.5},
      }, base: _fullLook);
      expect(sparse.gain.master, 0.5);
      expect(sparse.gain.balance, _fullLook.gain.balance);
    });

    test('parsed values clamp to the console ranges', () {
      final wild = GradeLook.fromJson(const {
        'gain': {'m': 10},
        'lift': {'x': 3.0, 'y': 4.0},
        'saturation': 9,
        'temperature': -5,
        'tint': 5,
        'contrast': 0.1,
        'pivot': 0.9,
      });
      expect(wild.gain.master, 1);
      // Puck direction kept, radius clamped to the unit wheel.
      expect(wild.lift.balance.dx, closeTo(0.6, 1e-12));
      expect(wild.lift.balance.dy, closeTo(0.8, 1e-12));
      expect(wild.saturation, 2);
      expect(wild.temperature, -1);
      expect(wild.tint, 1);
      expect(wild.contrast, 0.5);
      expect(wild.pivot, 0.7);
    });

    test('a non-map wheel value inherits the base wheel', () {
      expect(GradeLook.fromJson(const {'lift': 'oops'}), GradeLook.neutral);
      expect(
        GradeLook.fromJson(const {'lift': 'oops'}, base: _fullLook).lift,
        _fullLook.lift,
      );
    });

    test('deviation is 0 at neutral and ~1 at any full deflection', () {
      expect(GradeLook.neutral.deviation, 0);
      expect(const GradeLook(saturation: 0).deviation, 1);
      expect(const GradeLook(saturation: 2).deviation, 1);
      expect(const GradeLook(temperature: -1).deviation, 1);
      expect(const GradeLook(contrast: 1.8).deviation, closeTo(1, 1e-9));
      expect(
        const GradeLook(gain: GradeWheel(master: -1)).deviation,
        1,
      );
      expect(
        const GradeLook(gamma: GradeWheel(balance: Offset(0, 1))).deviation,
        closeTo(1, 1e-9),
      );
    });

    test(
      'deviation registers a saturation-only ride (panel sparkline fix)',
      () {
        expect(const GradeLook(saturation: 0.7).deviation, closeTo(0.3, 1e-9));
        expect(const GradeLook(tint: 0.2).deviation, closeTo(0.2, 1e-9));
      },
    );

    test('equality and hashCode compare all fields', () {
      expect(GradeLook.fromJson(_fullLook.toJson()), _fullLook);
      expect(
        GradeLook.fromJson(_fullLook.toJson()).hashCode,
        _fullLook.hashCode,
      );
      expect(_fullLook, isNot(const GradeLook(saturation: 0.8)));
    });
  });

  group('GradeInterp', () {
    test('fromName parses every curve and defaults unknowns to smooth', () {
      expect(GradeInterp.fromName('hold'), GradeInterp.hold);
      expect(GradeInterp.fromName('linear'), GradeInterp.linear);
      expect(GradeInterp.fromName('smooth'), GradeInterp.smooth);
      expect(GradeInterp.fromName('easeIn'), GradeInterp.easeIn);
      expect(GradeInterp.fromName('easeOut'), GradeInterp.easeOut);
      expect(GradeInterp.fromName('wobble'), GradeInterp.smooth);
      expect(GradeInterp.fromName(null), GradeInterp.smooth);
    });

    test('every curve starts at 0 and (except hold) ends at 1', () {
      for (final c in GradeInterp.values) {
        expect(c.apply(0), 0, reason: '$c at 0');
        expect(c.apply(1), c == GradeInterp.hold ? 0 : 1, reason: '$c at 1');
      }
    });

    test('curve shapes: hold flat, easeIn slow start, easeOut fast start', () {
      expect(GradeInterp.hold.apply(0.99), 0);
      expect(GradeInterp.linear.apply(0.25), 0.25);
      expect(GradeInterp.smooth.apply(0.5), closeTo(0.5, 1e-12));
      expect(GradeInterp.smooth.apply(0.25), lessThan(0.25));
      expect(GradeInterp.easeIn.apply(0.5), closeTo(0.25, 1e-12));
      expect(GradeInterp.easeOut.apply(0.5), closeTo(0.75, 1e-12));
    });

    test('inputs outside 0..1 clamp instead of extrapolating', () {
      expect(GradeInterp.linear.apply(-1), 0);
      expect(GradeInterp.linear.apply(2), 1);
      expect(GradeInterp.easeOut.apply(2), 1);
    });
  });

  group('GradeKeyframe', () {
    test('JSON round-trip preserves time, look and curve', () {
      final k = _key(12.5, interp: GradeInterp.hold);
      expect(GradeKeyframe.fromJson(k.toJson()), k);
    });

    test('toJson omits the default smooth curve', () {
      expect(_key(1).toJson().containsKey('interp'), isFalse);
      expect(
        _key(1, interp: GradeInterp.linear).toJson()['interp'],
        'linear',
      );
    });

    test('fromJson defaults a missing look/time/curve', () {
      final k = GradeKeyframe.fromJson(const {});
      expect(k.tSec, 0);
      expect(k.look, GradeLook.neutral);
      expect(k.interp, GradeInterp.smooth);
    });

    test('equality compares time, look and curve', () {
      expect(_key(1), _key(1));
      expect(_key(1).hashCode, _key(1).hashCode);
      expect(_key(1), isNot(_key(2)));
      expect(_key(1), isNot(_key(1, interp: GradeInterp.hold)));
    });
  });

  group('GradeLane', () {
    test('the factory sorts keyframes by time', () {
      final lane = GradeLane(
        target: 'deck',
        keyframes: [_key(5), _key(1), _key(3)],
      );
      expect([for (final k in lane.keyframes) k.tSec], [1, 3, 5]);
    });

    test('coincident keys collapse deterministically (last wins)', () {
      final lane = GradeLane(
        target: 'deck',
        keyframes: [
          _key(1, look: _satLook(0.2)),
          _key(1 + kGradeKeyEpsilonSec / 2, look: _satLook(0.9)),
        ],
      );
      expect(lane.keyframes, hasLength(1));
      expect(lane.keyframes.single.look.saturation, 0.9);
    });

    test('an empty lane evaluates neutral everywhere', () {
      final lane = GradeLane(target: 'deck');
      expect(lane.evaluate(0), GradeLook.neutral);
      expect(lane.evaluate(100), GradeLook.neutral);
    });

    test('a disabled lane evaluates neutral despite keyframes', () {
      final lane = GradeLane(
        target: 'deck',
        keyframes: [_key(1)],
      ).withEnabled(enabled: false);
      expect(lane.enabled, isFalse);
      expect(lane.evaluate(1), GradeLook.neutral);
      expect(lane.withEnabled(enabled: true).evaluate(1), _fullLook);
    });

    test('evaluation holds the edge value outside the keyed range', () {
      final lane = GradeLane(
        target: 'deck',
        keyframes: [
          _key(10, look: _satLook(0.5)),
          _key(20, look: _satLook(1.5)),
        ],
      );
      expect(lane.evaluate(0).saturation, 0.5);
      expect(lane.evaluate(10).saturation, 0.5);
      expect(lane.evaluate(20).saturation, 1.5);
      expect(lane.evaluate(99).saturation, 1.5);
    });

    test('a single-key lane is a static look for the whole song', () {
      final lane = GradeLane(target: 'deck', keyframes: [_key(30)]);
      expect(lane.evaluate(0), _fullLook);
      expect(lane.evaluate(30), _fullLook);
      expect(lane.evaluate(300), _fullLook);
    });

    test('linear segments land at the exact fraction', () {
      final lane = GradeLane(
        target: 'deck',
        keyframes: [
          _key(0, look: _satLook(1), interp: GradeInterp.linear),
          _key(10, look: _satLook(2)),
        ],
      );
      expect(lane.evaluate(2.5).saturation, closeTo(1.25, 1e-12));
      expect(lane.evaluate(5).saturation, closeTo(1.5, 1e-12));
    });

    test('hold segments cut at the next key, not before', () {
      final lane = GradeLane(
        target: 'deck',
        keyframes: [
          _key(0, look: _satLook(1), interp: GradeInterp.hold),
          _key(10, look: _satLook(2)),
        ],
      );
      expect(lane.evaluate(9.999).saturation, 1);
      expect(lane.evaluate(10).saturation, 2);
    });

    test('smooth segments ease through the exact midpoint', () {
      final lane = GradeLane(
        target: 'deck',
        keyframes: [
          _key(0, look: _satLook(1)),
          _key(10, look: _satLook(2)),
        ],
      );
      expect(lane.evaluate(5).saturation, closeTo(1.5, 1e-12));
      expect(lane.evaluate(2.5).saturation, lessThan(1.25));
      expect(lane.evaluate(7.5).saturation, greaterThan(1.75));
    });

    test('evaluation binary-searches the right segment among many', () {
      final lane = GradeLane(
        target: 'deck',
        keyframes: [
          for (var i = 0; i <= 10; i++)
            _key(
              i.toDouble(),
              look: _satLook(i / 10),
              interp: GradeInterp.linear,
            ),
        ],
      );
      expect(lane.evaluate(7.5).saturation, closeTo(0.75, 1e-12));
      expect(lane.evaluate(3).saturation, closeTo(0.3, 1e-12));
    });

    test('indexNear finds a key within tolerance and misses outside it', () {
      final lane = GradeLane(target: 'deck', keyframes: [_key(1), _key(2)]);
      expect(lane.indexNear(2), 1);
      expect(lane.indexNear(1.04, tolerance: 0.05), 0);
      expect(lane.indexNear(1.5), isNull);
    });

    test('upsert inserts a new key in time order', () {
      final lane = GradeLane(
        target: 'deck',
        keyframes: [_key(1), _key(5)],
      ).upsert(_key(3));
      expect([for (final k in lane.keyframes) k.tSec], [1, 3, 5]);
    });

    test('upsert replaces the key at the same time', () {
      final lane = GradeLane(
        target: 'deck',
        keyframes: [_key(1, look: _satLook(0.2))],
      ).upsert(_key(1, look: _satLook(1.8)));
      expect(lane.keyframes, hasLength(1));
      expect(lane.keyframes.single.look.saturation, 1.8);
    });

    test('removeNear deletes only a hit and tolerates a miss', () {
      final lane = GradeLane(target: 'deck', keyframes: [_key(1), _key(2)]);
      expect(lane.removeNear(1.5).keyframes, hasLength(2));
      expect(lane.removeNear(2).keyframes.single.tSec, 1);
      expect(
        lane.removeNear(2.2, tolerance: 0.5).keyframes.single.tSec,
        1,
      );
    });

    test('replaceAt swaps one key (the move/re-curve primitive)', () {
      final lane = GradeLane(
        target: 'deck',
        keyframes: [_key(1), _key(5)],
      ).replaceAt(0, _key(2, interp: GradeInterp.hold));
      expect([for (final k in lane.keyframes) k.tSec], [2, 5]);
      expect(lane.keyframes.first.interp, GradeInterp.hold);
    });

    test('JSON round-trip preserves target, mute and keys', () {
      final lane = GradeLane(
        target: 'yacht',
        keyframes: [
          _key(1),
          _key(2, interp: GradeInterp.hold),
        ],
      ).withEnabled(enabled: false);
      final back = GradeLane.fromJson(lane.toJson());
      expect(back.target, 'yacht');
      expect(back.enabled, isFalse);
      expect(back.keyframes, lane.keyframes);
    });

    test('toJson omits enabled when true', () {
      expect(
        GradeLane(target: 'deck').toJson().containsKey('enabled'),
        isFalse,
      );
    });

    test('fromJson skips malformed keyframe entries and defaults target', () {
      final lane = GradeLane.fromJson(const {
        'keyframes': [
          42,
          {'t_sec': 3.0},
          'junk',
        ],
      });
      expect(lane.target, GradeTargets.master);
      expect(lane.enabled, isTrue);
      expect(lane.keyframes.single.tSec, 3);
    });

    test('sparse keys inherit unmentioned fields from their predecessor', () {
      // First key sets temperature; second key only dips saturation. With
      // inheritance the temperature must HOLD at 0.3 across both keys —
      // never ramp back toward neutral (the panel's wrong-pixels scenario).
      final lane = GradeLane.fromJson(const {
        'target': 'master',
        'keyframes': [
          {
            't_sec': 0,
            'look': {'temperature': 0.3},
          },
          {
            't_sec': 30,
            'look': {'saturation': 0.8},
          },
        ],
      });
      expect(lane.keyframes[1].look.temperature, 0.3);
      expect(lane.keyframes[1].look.saturation, 0.8);
      expect(lane.evaluate(15).temperature, closeTo(0.3, 1e-12));
    });

    test(
      'inheritance resolves in TIME order even when the array is shuffled',
      () {
        final lane = GradeLane.fromJson(const {
          'keyframes': [
            {
              't_sec': 30,
              'look': {'saturation': 0.8},
            },
            {
              't_sec': 0,
              'look': {'temperature': 0.3},
            },
          ],
        });
        expect(lane.keyframes.first.tSec, 0);
        expect(lane.keyframes[1].look.temperature, 0.3);
      },
    );

    test('a keyframe without a look is a pure hold/retime key', () {
      final lane = GradeLane.fromJson(const {
        'keyframes': [
          {
            't_sec': 0,
            'look': {'tint': -0.4},
          },
          {'t_sec': 10},
        ],
      });
      expect(lane.keyframes[1].look.tint, -0.4);
      expect(lane.evaluate(5).tint, closeTo(-0.4, 1e-12));
    });
  });

  group('GradeTimelineDoc', () {
    test('the empty doc has no lanes and evaluates to nothing', () {
      expect(GradeTimelineDoc.empty.lanes, isEmpty);
      expect(GradeTimelineDoc.empty.isEmpty, isTrue);
      expect(GradeTimelineDoc.empty.evaluate(1), isEmpty);
    });

    test('duplicate targets collapse (later lane wins)', () {
      final doc = GradeTimelineDoc(
        lanes: [
          GradeLane(
            target: 'deck',
            keyframes: [_key(1, look: _satLook(0.1))],
          ),
          GradeLane(
            target: 'deck',
            keyframes: [_key(1, look: _satLook(1.9))],
          ),
        ],
      );
      expect(doc.lanes, hasLength(1));
      expect(doc.lane('deck')!.evaluate(1).saturation, 1.9);
    });

    test('lane() finds a target and misses an absent one', () {
      final doc = GradeTimelineDoc(lanes: [GradeLane(target: 'cast')]);
      expect(doc.lane('cast'), isNotNull);
      expect(doc.lane('yacht'), isNull);
    });

    test('isEmpty is true with lanes that hold no keys', () {
      expect(
        GradeTimelineDoc(lanes: [GradeLane(target: 'deck')]).isEmpty,
        isTrue,
      );
    });

    test('isActive lights only for an enabled lane with a non-neutral key', () {
      expect(GradeTimelineDoc.empty.isActive, isFalse);
      expect(
        GradeTimelineDoc(lanes: [GradeLane(target: 'deck')]).isActive,
        isFalse,
      );
      final neutralKeys = GradeTimelineDoc(
        lanes: [
          GradeLane(
            target: 'deck',
            keyframes: [_key(0, look: GradeLook.neutral)],
          ),
        ],
      );
      expect(neutralKeys.isActive, isFalse);
      final active = GradeTimelineDoc(
        lanes: [
          GradeLane(target: 'deck', keyframes: [_key(0)]),
        ],
      );
      expect(active.isActive, isTrue);
      final muted = GradeTimelineDoc(
        lanes: [
          GradeLane(
            target: 'deck',
            keyframes: [_key(0)],
          ).withEnabled(enabled: false),
        ],
      );
      expect(muted.isActive, isFalse);
    });

    test('evaluate returns only non-neutral looks', () {
      final doc = GradeTimelineDoc(
        lanes: [
          GradeLane(
            target: 'deck',
            keyframes: [_key(0, look: _satLook(0.5))],
          ),
          GradeLane(
            target: 'cast',
            keyframes: [_key(0, look: GradeLook.neutral)],
          ),
          GradeLane(
            target: 'yacht',
            keyframes: [_key(0)],
          ).withEnabled(enabled: false),
        ],
      );
      final looks = doc.evaluate(10);
      expect(looks.keys, ['deck']);
      expect(looks['deck']!.saturation, 0.5);
    });

    test('withLane adds a new lane and replaces an existing target', () {
      final doc = GradeTimelineDoc()
          .withLane(GradeLane(target: 'deck', keyframes: [_key(1)]))
          .withLane(GradeLane(target: 'cast'))
          .withLane(GradeLane(target: 'deck', keyframes: [_key(2)]));
      expect(doc.lanes, hasLength(2));
      expect(doc.lane('deck')!.keyframes.single.tSec, 2);
    });

    test('withoutLane drops only the named target', () {
      final doc = GradeTimelineDoc(
        lanes: [
          GradeLane(target: 'deck'),
          GradeLane(target: 'cast'),
        ],
      ).withoutLane('deck');
      expect(doc.lane('deck'), isNull);
      expect(doc.lane('cast'), isNotNull);
    });

    test('JSON round-trip preserves the whole document', () {
      final doc = GradeTimelineDoc(
        lanes: [
          GradeLane(
            target: GradeTargets.master,
            keyframes: [
              _key(0),
              _key(30, interp: GradeInterp.linear),
            ],
          ),
          GradeLane(
            target: 'deck',
            keyframes: [_key(4, look: _satLook(0.7))],
          ).withEnabled(enabled: false),
        ],
      );
      final back = GradeTimelineDoc.fromJson(doc.toJson());
      expect(back.toJson(), doc.toJson());
      expect(back.lane('deck')!.enabled, isFalse);
    });

    test('a missing version parses as v1; a future version throws', () {
      expect(GradeTimelineDoc.fromJson(const {}).lanes, isEmpty);
      expect(GradeTimelineDoc.fromJson(const {'version': 1}).lanes, isEmpty);
      expect(
        () => GradeTimelineDoc.fromJson(const {'version': 2}),
        throwsFormatException,
      );
    });

    test('fromJson skips non-object lane entries', () {
      final doc = GradeTimelineDoc.fromJson(const {
        'lanes': [
          7,
          {'target': 'deck'},
        ],
      });
      expect(doc.lanes.single.target, 'deck');
    });
  });

  group('generative invariants', () {
    glados.Glados(
      glados.any.gradeLook,
      glados.ExploreConfig(numRuns: 200),
    ).test('look JSON round-trips exactly', (look) {
      expect(GradeLook.fromJson(look.toJson()), look);
    }, tags: 'glados');

    glados.Glados(
      glados.any.gradeLane,
      glados.ExploreConfig(numRuns: 200),
    ).test('lane evaluation is exact at keys and bounded between them', (lane) {
      for (final k in lane.keyframes) {
        expect(lane.evaluate(k.tSec), k.look);
      }
      final first = lane.keyframes.first;
      final last = lane.keyframes.last;
      // Sample between neighbours: every scalar stays inside the hull of
      // the two endpoint values (no overshoot by design).
      for (var i = 0; i + 1 < lane.keyframes.length; i++) {
        final a = lane.keyframes[i];
        final b = lane.keyframes[i + 1];
        for (final u in [0.25, 0.5, 0.75]) {
          final v = lane.evaluate(a.tSec + (b.tSec - a.tSec) * u).saturation;
          final lo = a.look.saturation < b.look.saturation
              ? a.look.saturation
              : b.look.saturation;
          final hi = a.look.saturation < b.look.saturation
              ? b.look.saturation
              : a.look.saturation;
          expect(v, inInclusiveRange(lo, hi));
        }
      }
      expect(lane.evaluate(first.tSec - 5), first.look);
      expect(lane.evaluate(last.tSec + 5), last.look);
    }, tags: 'glados');

    glados.Glados(
      glados.any.gradeLane,
    ).test('lane JSON round-trips to identical evaluation', (lane) {
      final back = GradeLane.fromJson(lane.toJson());
      expect(back.keyframes, lane.keyframes);
      final mid = (lane.keyframes.first.tSec + lane.keyframes.last.tSec) / 2;
      expect(back.evaluate(mid), lane.evaluate(mid));
    }, tags: 'glados');
  });
}
