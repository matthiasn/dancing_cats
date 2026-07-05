part of '../cat_in_suit.dart';

// ─────────────────────────────────────────────────────────────────────────
// Standalone "Shaku Shaku" lead redesign — SEPARATE from the shipped `dance`
// so its (heavily geometry-coupled) tests stay intact while this is iterated
// to a 9/10 panel score. Wired in to replace `dance` only once it lands.
// ─────────────────────────────────────────────────────────────────────────

// Recipe groove: the knee-dip BOTTOMS on every count (rootDy high on 0/4/8…,
// chest squashed on the beat) and rises on the off-beats — an on-beat Shaku
// pocket. Lateral sway (rootDx) + counter-rotation kept from the tuned dance.
const _shakuBodyGrooveKeys = [
  DanceBodyKey(
    0,
    rootDx: -14,
    rootDy: 21.7,
    rootRotation: -0.007,
    pelvisRotation: 0.32,
    chestRotation: -0.09,
    chestScaleY: 0.905,
    chestScaleX: 1.06,
  ),
  DanceBodyKey(
    1,
    rootDx: -18,
    rootDy: 18.5,
    rootRotation: -0.009,
    pelvisRotation: 0.43,
    chestRotation: -0.18,
    chestScaleY: 0.955,
    chestScaleX: 1.025,
  ),
  DanceBodyKey(
    2,
    rootDx: -20,
    rootDy: 15.3,
    rootRotation: -0.009,
    pelvisRotation: 0.38,
    chestRotation: -0.11,
    chestScaleY: 1.005,
    chestScaleX: 0.99,
  ),
  DanceBodyKey(
    3,
    rootDx: -19,
    rootDy: 18.5,
    rootRotation: -0.008,
    pelvisRotation: 0.51,
    chestRotation: -0.235,
    chestScaleY: 0.955,
    chestScaleX: 1.025,
  ),
  DanceBodyKey(
    4,
    rootDx: -11,
    rootDy: 21.7,
    rootRotation: -0.007,
    pelvisRotation: 0.53,
    chestRotation: -0.25,
    chestScaleY: 0.905,
    chestScaleX: 1.06,
  ),
  DanceBodyKey(
    5,
    rootDx: -13,
    rootDy: 18.5,
    rootRotation: -0.006,
    pelvisRotation: 0.44,
    chestRotation: -0.24,
    chestScaleY: 0.955,
    chestScaleX: 1.025,
  ),
  DanceBodyKey(
    6,
    rootDx: -12,
    rootDy: 15.3,
    rootRotation: -0.005,
    pelvisRotation: 0.38,
    chestRotation: -0.18,
    chestScaleY: 1.005,
    chestScaleX: 0.99,
  ),
  DanceBodyKey(
    7,
    rootDx: -1,
    rootDy: 18.5,
    rootRotation: 0,
    chestScaleY: 0.955,
    chestScaleX: 1.025,
  ),
  DanceBodyKey(
    8,
    rootDx: 11,
    rootDy: 21.7,
    rootRotation: 0.005,
    pelvisRotation: 0.16,
    chestRotation: -0.02,
    chestScaleY: 0.905,
    chestScaleX: 1.06,
  ),
  DanceBodyKey(
    9,
    rootDx: 12,
    rootDy: 18.5,
    rootRotation: 0.006,
    pelvisRotation: 0.14,
    chestRotation: 0.02,
    chestScaleY: 0.955,
    chestScaleX: 1.025,
  ),
  DanceBodyKey(
    10,
    rootDx: 17,
    rootDy: 15.3,
    rootRotation: 0.008,
    pelvisRotation: 0.08,
    chestRotation: 0.06,
    chestScaleY: 1.005,
    chestScaleX: 0.99,
  ),
  DanceBodyKey(
    11,
    rootDx: 18,
    rootDy: 18.5,
    rootRotation: 0.008,
    pelvisRotation: 0.01,
    chestRotation: 0.045,
    chestScaleY: 0.955,
    chestScaleX: 1.025,
  ),
  DanceBodyKey(
    12,
    rootDx: 18,
    rootDy: 21.7,
    rootRotation: 0.006,
    pelvisRotation: -0.08,
    chestRotation: 0.1,
    chestScaleY: 0.905,
    chestScaleX: 1.06,
  ),
  DanceBodyKey(
    13,
    rootDx: 12,
    rootDy: 18.5,
    rootRotation: 0.004,
    pelvisRotation: -0.16,
    chestRotation: 0.12,
    chestScaleY: 0.955,
    chestScaleX: 1.025,
  ),
  DanceBodyKey(
    14,
    rootDx: 6,
    rootDy: 15.3,
    rootRotation: -0.001,
    pelvisRotation: -0.24,
    chestRotation: 0.14,
    chestScaleY: 1.005,
    chestScaleX: 0.99,
  ),
  DanceBodyKey(
    15,
    rootDx: -1,
    rootDy: 18.5,
    rootRotation: -0.004,
    pelvisRotation: -0.31,
    chestRotation: 0.16,
    chestScaleY: 0.955,
    chestScaleX: 1.025,
  ),
  DanceBodyKey(
    16,
    rootDx: -7,
    rootDy: 21.7,
    rootRotation: -0.006,
    pelvisRotation: -0.36,
    chestRotation: 0.13,
    chestScaleY: 0.905,
    chestScaleX: 1.06,
  ),
  DanceBodyKey(
    17,
    rootDx: -12,
    rootDy: 18.5,
    rootRotation: -0.007,
    pelvisRotation: -0.37,
    chestRotation: 0.12,
    chestScaleY: 0.955,
    chestScaleX: 1.025,
  ),
  DanceBodyKey(
    18,
    rootDx: -12.6,
    rootDy: 15.3,
    rootRotation: -0.008,
    pelvisRotation: -0.36,
    chestRotation: 0.13,
    chestScaleY: 1.005,
    chestScaleX: 0.99,
  ),
  DanceBodyKey(
    19,
    rootDx: -12.2,
    rootDy: 18.5,
    rootRotation: -0.008,
    pelvisRotation: -0.42,
    chestRotation: 0.135,
    chestScaleY: 0.955,
    chestScaleX: 1.025,
  ),
  DanceBodyKey(
    20,
    rootDx: -11.4,
    rootDy: 21.7,
    rootRotation: -0.006,
    pelvisRotation: -0.47,
    chestRotation: 0.16,
    chestScaleY: 0.905,
    chestScaleX: 1.06,
  ),
  DanceBodyKey(
    21,
    rootDx: -9.8,
    rootDy: 18.5,
    rootRotation: -0.004,
    pelvisRotation: -0.42,
    chestRotation: 0.2,
    chestScaleY: 0.955,
    chestScaleX: 1.025,
  ),
  DanceBodyKey(
    22,
    rootDx: -5,
    rootDy: 15.3,
    rootRotation: -0.002,
    pelvisRotation: -0.28,
    chestRotation: -0.03,
    chestScaleY: 1.005,
    chestScaleX: 0.99,
  ),
  DanceBodyKey(
    23,
    rootDx: 2,
    rootDy: 18.5,
    rootRotation: 0.001,
    pelvisRotation: -0.22,
    chestRotation: -0.055,
    chestScaleY: 0.955,
    chestScaleX: 1.025,
  ),
  DanceBodyKey(
    24,
    rootDx: 12,
    rootDy: 21.7,
    rootRotation: 0.007,
    pelvisRotation: -0.24,
    chestRotation: 0.095,
    chestScaleY: 0.905,
    chestScaleX: 1.06,
  ),
  DanceBodyKey(
    26,
    rootDx: 14,
    rootDy: 15.3,
    rootRotation: 0.008,
    pelvisRotation: -0.08,
    chestRotation: -0.06,
    chestScaleY: 1.005,
    chestScaleX: 0.99,
  ),
  DanceBodyKey(
    27,
    rootDx: 13,
    rootDy: 18.5,
    rootRotation: 0.007,
    pelvisRotation: -0.02,
    chestRotation: -0.08,
    chestScaleY: 0.955,
    chestScaleX: 1.025,
  ),
  DanceBodyKey(
    28,
    rootDx: 12,
    rootDy: 21.7,
    rootRotation: 0.006,
    pelvisRotation: 0.04,
    chestRotation: -0.1,
    chestScaleY: 0.905,
    chestScaleX: 1.06,
  ),
  DanceBodyKey(
    29,
    rootDx: 2,
    rootDy: 18.5,
    rootRotation: 0.001,
    pelvisRotation: 0.12,
    chestRotation: -0.18,
    chestScaleY: 0.955,
    chestScaleX: 1.025,
  ),
  DanceBodyKey(
    30,
    rootDx: -7,
    rootDy: 15.3,
    rootRotation: -0.004,
    pelvisRotation: 0.2,
    chestRotation: -0.15,
    chestScaleY: 1.005,
    chestScaleX: 0.99,
  ),
  DanceBodyKey(
    31,
    rootDx: -12.4,
    rootDy: 18.5,
    rootRotation: -0.006,
    pelvisRotation: 0.27,
    chestRotation: -0.125,
    chestScaleY: 0.955,
    chestScaleX: 1.025,
  ),
  DanceBodyKey(
    32,
    rootDx: -14,
    rootDy: 21.7,
    rootRotation: -0.007,
    pelvisRotation: 0.32,
    chestRotation: -0.09,
    chestScaleY: 0.905,
    chestScaleX: 1.06,
  ),
];

/// How far to scale the shaku-family lateral weight commit (1.0 = the authored
/// [_shakuBodyGrooveKeys] groove). The body commits so far to the side that,
/// under a head deliberately kept facing camera, the torso reads as a pendulum
/// swinging beneath a fixed head; pulling the side-to-side commit in tames that
/// without flattening the move.
const double _shakuLateralGain = 0.6;

/// [_shakuBodyGrooveKeys] with only the LATERAL groove scaled by
/// [_shakuLateralGain] — the side-to-side weight commit (`rootDx` +
/// pelvis/chest rotation). The vertical knee-dip (`rootDy`) and the chest
/// squash are preserved, so the on-beat pocket keeps its full depth. Shared by
/// every clip that grooves on these keys — shaku, zanku, azonto (lead and the
/// ensemble backups alike) — so the whole crew commits less far, not just the
/// lead.
final List<DanceBodyKey> _shakuGrooveCalm = _calmedGroove(_shakuLateralGain);


/// Shaku's own groove variant for the R21 stepped weight transfer: the
/// lateral commit story moved to the square-wave sway layers in the shaku
/// descriptor (park over the support foot, shift in 2-3 frames after each
/// plant), so the groove's own rootDx wander drops to per-beat texture —
/// at the shared 0.6 it smeared the plateaus back into the "one smooth
/// 2-bar sinusoid" all four R21 raters flagged. Zanku/azonto keep riding
/// [_shakuGrooveCalm] at the shared gain; only shaku steps.
///
/// The deeper sink (+11 vs the shared +6) is the R21 pocket CEILING: at
/// the top of each bounce the knees reached near-full extension ("the
/// character stands up out of the pocket mid-loop" — all four raters), so
/// the whole pulse now rides ~5 units lower and the highest hip position
/// keeps a visible knee bend.
final List<DanceBodyKey> _shakuGrooveCommitted = _calmedGroove(0.25, sink: 11);

List<DanceBodyKey> _calmedGroove(double lateralGain, {double sink = 6}) => [
  for (final k in _shakuBodyGrooveKeys)
    DanceBodyKey(
      k.frame,
      rootDx: k.rootDx == null ? null : k.rootDx! * lateralGain,
      rootDy: k.rootDy == null ? null : k.rootDy! + sink,
      rootRotation: k.rootRotation == null
          ? null
          : k.rootRotation! * lateralGain,
      pelvisRotation: k.pelvisRotation == null
          ? null
          : k.pelvisRotation! * lateralGain,
      chestRotation: k.chestRotation == null
          ? null
          : k.chestRotation! * lateralGain,
      chestScaleX: k.chestScaleX,
      chestScaleY: k.chestScaleY,
      ease: k.ease,
    ),
];
// Support knee pumps deepest on each count: LEFT supports bar 1 (deep on
// 0/4/8/12), RIGHT supports bar 2 (deep on 16/20/24/28).
const _shakuLegLowerLKeys = [
  // Wider deep/rebound swing so the per-beat root drop has knee absorption
  // to live in — the gallop loads INTO the floor on the count and gets
  // light between supports.
  DanceJointKey(0, rotation: -1.34),
  DanceJointKey(2, rotation: -0.92),
  DanceJointKey(4, rotation: -1.34),
  DanceJointKey(6, rotation: -0.92),
  DanceJointKey(8, rotation: -1.34),
  DanceJointKey(10, rotation: -0.92),
  DanceJointKey(12, rotation: -1.34),
  DanceJointKey(14, rotation: -0.92),
  DanceJointKey(16, rotation: -0.78),
  DanceJointKey(18, rotation: -0.82),
  DanceJointKey(20, rotation: -0.82),
  DanceJointKey(22, rotation: -0.94),
  DanceJointKey(24, rotation: -0.9),
  DanceJointKey(26, rotation: -0.86),
  DanceJointKey(28, rotation: -0.82),
  DanceJointKey(29, rotation: -1.08),
  DanceJointKey(30, rotation: -1.08),
  DanceJointKey(31, rotation: -1.2),
  DanceJointKey(32, rotation: -1.34),
];
const _shakuLegLowerRKeys = [
  DanceJointKey(0, rotation: -0.96),
  DanceJointKey(2, rotation: -1.18),
  DanceJointKey(4, rotation: -1.22),
  DanceJointKey(6, rotation: -1.02),
  DanceJointKey(7, rotation: -0.86),
  DanceJointKey(8, rotation: -1.04),
  DanceJointKey(10, rotation: -0.86),
  DanceJointKey(12, rotation: -0.78),
  DanceJointKey(14, rotation: -0.82),
  DanceJointKey(15, rotation: -0.86),
  DanceJointKey(16, rotation: -1.34),
  DanceJointKey(18, rotation: -0.92),
  DanceJointKey(20, rotation: -1.34),
  DanceJointKey(22, rotation: -0.92),
  DanceJointKey(24, rotation: -1.34),
  DanceJointKey(26, rotation: -0.92),
  DanceJointKey(28, rotation: -1.34),
  DanceJointKey(30, rotation: -0.92),
  DanceJointKey(32, rotation: -0.96),
];

// Shaku arm vocabulary — R13 re-author: an ALTERNATING shoulder-led DIG, not a
// held crossed-X. Every count one hand digs DOWN-and-ACROSS toward the opposite
// hip while the other RECOVERS HIGH to the chest; the roles swap each count, so
// the arms trade a continuous down/up diagonal instead of clasping at the
// sternum. The crossed-wrist X survives as a FLEETING pass-through on the
// off-beat transitions (the hands swap sides through the centre), keeping the
// shaku read without the "welded/pops-between-two-poses" duty cycle the panel
// flagged. Bar 2 deepens the dig and climaxes on the generator-pull (R sweeps
// up-and-back on the count-8 accent) so it escalates bar 1 rather than copying
// it. L digs on counts 0/8/16/24; R digs on 4/12/20/28.
// NOTE: dig depth is bounded by the arm-reach envelope. From a HIGH, static
// shoulder the hand cannot reach far down-and-across without the two-bone solver
// straightening the elbow (ratio>1 / bend~180) — the exact ceiling documented
// across shaku's earlier scoop rounds. These digs sit at the deepest point that
// still clears the reach + elbow-bend validators; a DEEPER shoulder-led dig
// needs a clavicle-drop channel (bring the socket down so the hand follows with
// the elbow bent), which is the next lever, not authored here yet.
const _shakuHandLTargetKeys = [
  // bar 1 — L OPENS out-left on its downbeats (the silhouette breaks to the
  // left), gathering IN across the chest between so the two arms TRADE the
  // opening each beat instead of clasping at the sternum (R13 panel: the
  // clamped centre blob was the load-bearing miss).
  // R19 arm re-author — cross-body ROWING at hip height (animator: "the
  // legs already dance shaku, the arms don't"; coach: "drop hands to
  // waist/hip height... alternating loose cross-body sweeps"). Each cycle:
  // OPEN low-out at the waist on the count, sweep UP across the chest,
  // land at the OPPOSITE hip, swing back out. The two arms' high-passes
  // alternate (L crosses high on 2/10/18, R on 6/14/22) — a structural
  // half-beat offset — and the runtime hand-clearance constraint keeps
  // the crossings from ever stacking.
  DanceIkTargetKey(0, x: -66, y: -14, tension: 1), // OPEN low-out (count)
  DanceIkTargetKey(2, x: 0, y: -44, tension: 0.5), // sweep up-across, high
  DanceIkTargetKey(4, x: 23, y: -2, tension: 0.9), // land wide at the right hip
  DanceIkTargetKey(6, x: -18, y: -28, tension: 0.5), // swing back out
  DanceIkTargetKey(8, x: -66, y: -14, tension: 1),
  DanceIkTargetKey(10, x: 0, y: -44, tension: 0.5),
  DanceIkTargetKey(12, x: 23, y: -2, tension: 0.9),
  DanceIkTargetKey(14, x: -18, y: -28, tension: 0.5),
  // bar 2 — open wider; the generator-pull count (28) keeps L rowing low
  // while R yanks the cord up-and-out.
  DanceIkTargetKey(16, x: -70, y: -16, tension: 1),
  DanceIkTargetKey(18, x: 0, y: -44, tension: 0.5),
  DanceIkTargetKey(20, x: 23, y: -2, tension: 0.9),
  DanceIkTargetKey(22, x: -18, y: -28, tension: 0.5),
  DanceIkTargetKey(24, x: -70, y: -16, tension: 1),
  DanceIkTargetKey(26, x: -2, y: -40, tension: 0.5),
  DanceIkTargetKey(28, x: 24, y: -6, tension: 0.9), // rows low under the pull
  DanceIkTargetKey(30, x: -18, y: -30, tension: 0.5),
  DanceIkTargetKey(32, x: -66, y: -14, tension: 1), // == frame 0
];
const _shakuHandRTargetKeys = [
  // bar 1 — R recovers IN at the left-chest on L's open counts, then OPENS
  // out-right on its own counts, so the silhouette breaks alternately L / R.
  // Mirror rowing, phase-shifted: R lands at the LEFT hip on L's open
  // counts, opens low-out on its own, and crosses high on the alternate
  // off-beats (6/14/22) so the two arms never peak together.
  DanceIkTargetKey(0, x: -18, y: -8, tension: 0.75), // lands settled on the seam
  DanceIkTargetKey(1, x: -24, y: -2, tension: 0.3), // follow-through loop past the land
  DanceIkTargetKey(3, x: 4, y: -22, tension: 0.4), // swing back out on an arc
  DanceIkTargetKey(4, x: 66, y: -14, tension: 1), // OPEN low-out (count)
  DanceIkTargetKey(6, x: 0, y: -44, tension: 0.5), // sweep up-across, high
  DanceIkTargetKey(8, x: -23, y: -2, tension: 0.9),
  DanceIkTargetKey(10, x: 18, y: -28, tension: 0.5),
  DanceIkTargetKey(12, x: 66, y: -14, tension: 1),
  DanceIkTargetKey(14, x: 0, y: -44, tension: 0.5),
  // bar 2 — open wider, then the GENERATOR PULL up-and-out on count 8.
  DanceIkTargetKey(16, x: -23, y: -2, tension: 0.9),
  DanceIkTargetKey(18, x: 18, y: -28, tension: 0.5),
  DanceIkTargetKey(20, x: 70, y: -16, tension: 1),
  DanceIkTargetKey(22, x: 0, y: -44, tension: 0.5),
  DanceIkTargetKey(24, x: -23, y: -2, tension: 0.9),
  DanceIkTargetKey(26, x: 30, y: -22, tension: 0.6), // gathers for the pull
  DanceIkTargetKey(28, x: 56, y: -46, tension: 1), // GENERATOR PULL up-out
  DanceIkTargetKey(29, x: 64, y: -54, tension: 0.8), // overshoot high
  DanceIkTargetKey(30, x: 24, y: -16, tension: 0.5), // release back down
  DanceIkTargetKey(32, x: -18, y: -8, tension: 0.75), // == frame 0
];
const _shakuFootLTargetKeys = [
  // The support phase is ONE constant plant — the round-3 rigging rater
  // pixel-measured the old ±3-unit authored wander as ice-skating. The
  // handoff to the free phase is a real lift-step (y clears the floor),
  // not a translated sole.
  DanceIkTargetKey(0, x: -69, y: 103), // planted support, visible outside
  DanceIkTargetKey(13, x: -69, y: 103), // still exactly there
  DanceIkTargetKey(14, x: -66, y: 97), // toe-led lift begins
  // Free phase re-authored as LIFTED tap-steps (R16 mocap: stance-width
  // changes "all while both feet render flat and weighted... replaced by
  // feet sliding on the floor"; coach: "the signature quick in-out
  // cross-step vocabulary is absent"). The foot now alternates clear
  // airborne travel (y 86-88, visible daylight) with quick toe TAPS at
  // the floor (y 95-96) — in, out, in — instead of gliding at sole level.
  // Inboard taps stay closer under the hip than the R foot's: bar 2's
  // pocket is deep AND right-shifted, and a far cross-body tap from a
  // low pelvis over-rotates the hip past its 1.55 rad dancer envelope
  // (the validator caught 1.76 at the -34 tap).
  DanceIkTargetKey(16, x: -54, y: 88), // lifted, travelling in
  DanceIkTargetKey(17, x: -42, y: 96), // TAP inboard
  DanceIkTargetKey(19, x: -50, y: 86), // lifted, travelling out
  DanceIkTargetKey(21, x: -58, y: 95), // TAP outboard
  DanceIkTargetKey(23, x: -48, y: 87), // lifted
  DanceIkTargetKey(24, x: -52, y: 96), // down-and-OUT on the count (base)
  DanceIkTargetKey(26, x: -32, y: 96), // TAP inboard on the "and"
  DanceIkTargetKey(28, x: -54, y: 86), // lifted, swinging home
  // The R14 rigging rater pixel-tracked the old 29→32 travel (y 94→98→103)
  // as a ~28px flat-contact DRAG across the loop seam — the sole never
  // visibly left the floor. Re-shaped as a real recovery step: the flick
  // LIFTS clear of the floor at 29 (16 units of daylight), travels home
  // while airborne, and PLANTS dead at 30 — before the footL contact span
  // takes over at 30.125 — holding flat through the loop wrap. tension: 1
  // is the planted-contact stamp: it zeroes the spline tangent so the sole
  // arrives dead instead of overshooting through the floor.
  DanceIkTargetKey(29, x: -46, y: 87), // lift peak, sole clears the floor
  DanceIkTargetKey(30, x: -69, y: 103, tension: 1), // airborne flick lands
  DanceIkTargetKey(31, x: -69, y: 103, tension: 1), // held plant
  DanceIkTargetKey(32, x: -69, y: 103, tension: 1), // == frame 0, planted
];
const _shakuFootRTargetKeys = [
  // Mirror of the L foot's tap-step vocabulary: lifted travel between
  // quick floor taps, never a sole-level glide.
  DanceIkTargetKey(0, x: 52, y: 96), // TAP on its own side on the downbeat
  DanceIkTargetKey(1, x: 36, y: 87), // lifted, travelling in
  DanceIkTargetKey(3, x: 58, y: 95), // TAP outboard
  DanceIkTargetKey(5, x: 44, y: 86), // lifted
  DanceIkTargetKey(6, x: 32, y: 96), // TAP inboard on the "and"
  DanceIkTargetKey(8, x: 50, y: 96), // back OUT and down on the count (base)
  DanceIkTargetKey(9, x: 36, y: 87), // lifted, travelling in
  DanceIkTargetKey(11, x: 60, y: 95), // TAP outboard
  DanceIkTargetKey(13, x: 44, y: 87), // lifted toward the descent
  // Plants on the "and" BEFORE bar 2 (15, tension:1 = dead arrival), so
  // the foot is genuinely down when the contact span takes over at 14.5
  // and the committed weight sway arrives onto a planted shoe.
  DanceIkTargetKey(14, x: 58, y: 90), // airborne swing toward the plant
  DanceIkTargetKey(15, x: 69, y: 103, tension: 1), // plant on the "and"
  DanceIkTargetKey(16, x: 69, y: 103, tension: 1), // planted support, held
  // Hold the plant while the L foot makes its airborne recovery (frames
  // 30-31) — the old data peeled R at 30, leaving the seam with NO support
  // at all, which is exactly why the L foot used to slide in at floor
  // level instead of stepping.
  DanceIkTargetKey(31, x: 69, y: 103), // still planted under the L recovery
  DanceIkTargetKey(32, x: 52, y: 96), // peel into the loop-start brush
];
const _shakuFootLKeys = [
  DanceJointKey(0, rotation: 0.3),
  DanceJointKey(1, rotation: 0.82),
  DanceJointKey(3, rotation: -0.68),
  DanceJointKey(5, rotation: 0.34),
  DanceJointKey(9, rotation: -0.72),
  DanceJointKey(13, rotation: 0.76),
  DanceJointKey(17, rotation: 0.84),
  DanceJointKey(19, rotation: -0.7),
  DanceJointKey(21, rotation: 0.2),
  DanceJointKey(25, rotation: -0.68),
  DanceJointKey(29, rotation: 0.18),
  DanceJointKey(32, rotation: 0.3),
];
const _shakuFootRKeys = [
  DanceJointKey(0, rotation: -0.3),
  DanceJointKey(1, rotation: -0.82),
  DanceJointKey(3, rotation: 0.68),
  DanceJointKey(5, rotation: -0.34),
  DanceJointKey(9, rotation: 0.72),
  DanceJointKey(13, rotation: -0.76),
  DanceJointKey(17, rotation: -0.84),
  DanceJointKey(19, rotation: 0.7),
  DanceJointKey(21, rotation: -0.2),
  DanceJointKey(25, rotation: 0.68),
  DanceJointKey(29, rotation: -0.18),
  DanceJointKey(32, rotation: -0.3),
];
const _shakuHandLKeys = [
  DanceJointKey(0, rotation: -0.12),
  DanceJointKey(1, rotation: 0.58),
  DanceJointKey(2, rotation: 0.62),
  DanceJointKey(3, rotation: 0.3),
  DanceJointKey(6, rotation: -0.42),
  DanceJointKey(7, rotation: 0.32),
  DanceJointKey(9, rotation: -0.46),
  DanceJointKey(10, rotation: -0.42),
  DanceJointKey(11, rotation: 0.3),
  DanceJointKey(14, rotation: -0.44),
  DanceJointKey(15, rotation: 0.24),
  DanceJointKey(17, rotation: 0.54),
  DanceJointKey(18, rotation: -0.42),
  DanceJointKey(19, rotation: 0.2),
  DanceJointKey(22, rotation: -0.44),
  DanceJointKey(23, rotation: 0.24),
  DanceJointKey(27, rotation: 0.18),
  DanceJointKey(29, rotation: -0.44),
  DanceJointKey(31, rotation: 0.22),
  DanceJointKey(32, rotation: -0.12),
];
const _shakuHandRKeys = [
  DanceJointKey(0, rotation: 0.12),
  DanceJointKey(1, rotation: -0.54),
  DanceJointKey(2, rotation: -0.6),
  DanceJointKey(3, rotation: -0.3),
  DanceJointKey(6, rotation: 0.42),
  DanceJointKey(7, rotation: -0.32),
  DanceJointKey(9, rotation: 0.46),
  DanceJointKey(10, rotation: 0.54),
  DanceJointKey(11, rotation: -0.3),
  DanceJointKey(14, rotation: 0.44),
  DanceJointKey(15, rotation: -0.24),
  DanceJointKey(17, rotation: -0.42),
  DanceJointKey(18, rotation: 0.54),
  DanceJointKey(19, rotation: -0.2),
  DanceJointKey(22, rotation: 0.44),
  DanceJointKey(23, rotation: -0.24),
  DanceJointKey(27, rotation: -0.18),
  DanceJointKey(29, rotation: 0.44),
  DanceJointKey(31, rotation: -0.22),
  DanceJointKey(32, rotation: 0.12),
];

// Shoulder-LED SEE-SAW: on each count the OPENING arm's clavicle drops the
// socket DOWN while the other clavicle rises — an alternating shoulder roll,
// not a rigid level yoke (R13 rigging: the shoulders must isolate). Same
// mechanism/sign as sekem's dig: R down = +, L down = − (mirrored bones). The
// drop snaps on the count and releases with a small overshoot; the off shoulder
// pops up for the see-saw. L opens on 0/8/16/24, R on 4/12/20/28 — matching the
// hand schedule so each arm rolls off its OWN shoulder.
//
// PHASE LEAD (R22, mocap + rigging): "offset the shoulder-line keys 1-2
// frames AHEAD of the arm-row keys... so the shoulders drive the arms
// rather than tilting with them — synchronous reversal reads keyframed,
// not recorded." Every key carries microFrames -1.5: the girdle initiates
// each roll ~1.5 frames before the hand arrives at its extreme.
const _shakuClavicleLead = -1.5;

List<DanceJointKey> _shoulderLed(List<DanceJointKey> keys) => [
  for (final k in keys)
    DanceJointKey(
      k.frame,
      rotation: k.rotation,
      scaleX: k.scaleX,
      scaleY: k.scaleY,
      ease: k.ease,
      tension: k.tension,
      microFrames: _shakuClavicleLead,
    ),
];

final List<DanceJointKey> _shakuClavicleLLedKeys = _shoulderLed(
  _shakuClavicleLKeys,
);
final List<DanceJointKey> _shakuClavicleRLedKeys = _shoulderLed(
  _shakuClavicleRKeys,
);

const _shakuClavicleLKeys = [
  DanceJointKey(0, rotation: -0.42), // L DROP (L opens)
  DanceJointKey(2, rotation: 0.08), // release overshoot up
  DanceJointKey(4, rotation: 0.15), // POP up (see-saw) while R drops
  DanceJointKey(6, rotation: -0.05), // anticipates the next drop
  DanceJointKey(8, rotation: -0.42),
  DanceJointKey(10, rotation: 0.08),
  DanceJointKey(12, rotation: 0.15),
  DanceJointKey(14, rotation: -0.05),
  DanceJointKey(16, rotation: -0.42),
  DanceJointKey(18, rotation: 0.08),
  DanceJointKey(20, rotation: 0.15),
  DanceJointKey(22, rotation: -0.05),
  DanceJointKey(24, rotation: -0.42),
  DanceJointKey(26, rotation: 0.08),
  DanceJointKey(28, rotation: 0.15),
  DanceJointKey(30, rotation: -0.05),
  DanceJointKey(32, rotation: -0.42),
];
const _shakuClavicleRKeys = [
  DanceJointKey(0, rotation: -0.15), // POP up (see-saw) while L drops
  DanceJointKey(2, rotation: -0.05), // anticipates the next drop
  DanceJointKey(4, rotation: 0.42), // R DROP (R opens)
  DanceJointKey(6, rotation: -0.08), // release overshoot up
  DanceJointKey(8, rotation: -0.15),
  DanceJointKey(10, rotation: -0.05),
  DanceJointKey(12, rotation: 0.42),
  DanceJointKey(14, rotation: -0.08),
  DanceJointKey(16, rotation: -0.15),
  DanceJointKey(18, rotation: -0.05),
  DanceJointKey(20, rotation: 0.42),
  DanceJointKey(22, rotation: -0.08),
  DanceJointKey(24, rotation: -0.15),
  DanceJointKey(26, rotation: -0.05),
  DanceJointKey(28, rotation: 0.42),
  DanceJointKey(30, rotation: -0.08),
  DanceJointKey(32, rotation: -0.15),
];
// Deltoid/socket mass response so the dig reads as flesh, not a hinge: the
// working socket bunches (wide + short) on its dig and stretches on release,
// mirroring the clavicle schedule (same as sekem's).
const _shakuShoulderSocketLKeys = [
  DanceJointKey(0, rotation: -0.08, scaleX: 1.12, scaleY: 0.92),
  DanceJointKey(2, rotation: 0.03, scaleX: 0.98, scaleY: 1.05),
  DanceJointKey(4),
  DanceJointKey(8, rotation: -0.08, scaleX: 1.12, scaleY: 0.92),
  DanceJointKey(10, rotation: 0.03, scaleX: 0.98, scaleY: 1.05),
  DanceJointKey(12),
  DanceJointKey(16, rotation: -0.08, scaleX: 1.12, scaleY: 0.92),
  DanceJointKey(18, rotation: 0.03, scaleX: 0.98, scaleY: 1.05),
  DanceJointKey(20),
  DanceJointKey(24, rotation: -0.08, scaleX: 1.12, scaleY: 0.92),
  DanceJointKey(26, rotation: 0.03, scaleX: 0.98, scaleY: 1.05),
  DanceJointKey(28),
  DanceJointKey(32, rotation: -0.08, scaleX: 1.12, scaleY: 0.92),
];
const _shakuShoulderSocketRKeys = [
  DanceJointKey(0),
  DanceJointKey(4, rotation: 0.08, scaleX: 1.12, scaleY: 0.92),
  DanceJointKey(6, rotation: -0.03, scaleX: 0.98, scaleY: 1.05),
  DanceJointKey(8),
  DanceJointKey(12, rotation: 0.08, scaleX: 1.12, scaleY: 0.92),
  DanceJointKey(14, rotation: -0.03, scaleX: 0.98, scaleY: 1.05),
  DanceJointKey(16),
  DanceJointKey(20, rotation: 0.08, scaleX: 1.12, scaleY: 0.92),
  DanceJointKey(22, rotation: -0.03, scaleX: 0.98, scaleY: 1.05),
  DanceJointKey(24),
  DanceJointKey(28, rotation: 0.08, scaleX: 1.12, scaleY: 0.92),
  DanceJointKey(30, rotation: -0.03, scaleX: 0.98, scaleY: 1.05),
  DanceJointKey(32),
];

// Head attitude channel — the R15 animator's single highest-leverage note:
// "the head is bolt-vertical with identical orientation in all 48 frames...
// the body dances but the character doesn't." A ±0.11-0.14 rad counter-tilt
// keyed ONE FRAME AFTER each open count (the lag is what makes it read as
// the head answering the body instead of being welded to it), tipping INTO
// the generator pull at 29. Stays inside the head's 0.18 joint envelope.
const _shakuHeadKeys = [
  // Count-anchored keys ONLY (R22 de-jitter, three raters: the skull-top
  // trace carried "high-frequency double-bumps between beats absent from
  // the hips" — those were this channel's old intermediate half-way keys
  // swinging the skull top every two frames). One smooth arc per count.
  DanceJointKey(0, rotation: 0.03),
  DanceJointKey(1, rotation: 0.09), // answers L's open, tilts toward it
  DanceJointKey(5, rotation: -0.09), // answers R's open
  DanceJointKey(9, rotation: 0.09),
  DanceJointKey(13, rotation: -0.09),
  DanceJointKey(17, rotation: 0.1),
  DanceJointKey(21, rotation: -0.1),
  DanceJointKey(25, rotation: 0.1),
  DanceJointKey(29, rotation: -0.12), // tips INTO the generator pull
  DanceJointKey(32, rotation: 0.03), // == frame 0
];

// Calmer ears for Shaku: enough delayed flop to avoid a fixed skull silhouette,
// but still much quieter than the generic dance ears so the beat reads in the
// body, not the head.
const _shakuEarLKeys = [
  Keyframe(p: 0, rotation: 0.018, scaleX: 1.008, scaleY: 0.994),
  Keyframe(p: 0.125, rotation: -0.047, scaleX: 1.023, scaleY: 0.982),
  Keyframe(p: 0.25, rotation: -0.031, scaleX: 1.015, scaleY: 0.988),
  Keyframe(p: 0.375, rotation: 0.037, scaleX: 0.99, scaleY: 1.012),
  Keyframe(p: 0.5, rotation: 0.018, scaleX: 1.008, scaleY: 0.994),
  Keyframe(p: 0.625, rotation: -0.05, scaleX: 1.023, scaleY: 0.982),
  Keyframe(p: 0.75, rotation: -0.031, scaleX: 1.015, scaleY: 0.988),
  Keyframe(p: 0.875, rotation: 0.037, scaleX: 0.99, scaleY: 1.012),
  Keyframe(p: 1, rotation: 0.018, scaleX: 1.008, scaleY: 0.994),
];
const _shakuEarRKeys = [
  Keyframe(p: 0, rotation: -0.018, scaleX: 0.994, scaleY: 1.008),
  Keyframe(p: 0.125, rotation: 0.044, scaleX: 0.982, scaleY: 1.023),
  Keyframe(p: 0.25, rotation: 0.031, scaleX: 0.988, scaleY: 1.015),
  Keyframe(p: 0.375, rotation: -0.037, scaleX: 1.012, scaleY: 0.99),
  Keyframe(p: 0.5, rotation: -0.018, scaleX: 0.994, scaleY: 1.008),
  Keyframe(p: 0.625, rotation: 0.047, scaleX: 0.982, scaleY: 1.023),
  Keyframe(p: 0.75, rotation: 0.031, scaleX: 0.988, scaleY: 1.015),
  Keyframe(p: 0.875, rotation: -0.037, scaleX: 1.012, scaleY: 0.99),
  Keyframe(p: 1, rotation: -0.018, scaleX: 0.994, scaleY: 1.008),
];

// Shaku-only body punctuation. It adds shoulder/hip participation around the
// final recovery without altering the base `dance` phrase or the standalone
// Zanku/Azonto variants.
const _shakuDabBodyKeys = [
  DanceBodyKey(
    24,
    rootDx: 0,
    rootDy: 0,
    rootRotation: 0,
    pelvisRotation: 0,
    chestRotation: 0,
    chestScaleY: 1,
    chestScaleX: 1,
  ),
  DanceBodyKey(
    26,
    rootDx: -1.4,
    rootDy: 0.45,
    rootRotation: -0.001,
    pelvisRotation: 0.035,
    chestRotation: -0.06,
    chestScaleY: 0.986,
    chestScaleX: 1.01,
  ),
  DanceBodyKey(
    28,
    rootDx: -4.8,
    rootDy: 1.1,
    rootRotation: -0.002,
    pelvisRotation: 0.075,
    chestRotation: -0.16,
    chestScaleY: 0.958,
    chestScaleX: 1.028,
  ),
  DanceBodyKey(
    30,
    rootDx: -1.6,
    rootDy: 0.35,
    rootRotation: -0.001,
    pelvisRotation: 0.035,
    chestRotation: -0.07,
    chestScaleY: 0.985,
    chestScaleX: 1.008,
  ),
  DanceBodyKey(
    32,
    rootDx: 0,
    rootDy: 0,
    rootRotation: 0,
    pelvisRotation: 0,
    chestRotation: 0,
    chestScaleY: 1,
    chestScaleX: 1,
  ),
];

// Panel pass: make the wrist-crosses sit on a heavier pocket and give the
// open-arm accents a visible downbeat instead of floating over the feet.
const _shakuPanelBodyKeys = [
  DanceBodyKey(0, rootDy: 6, pelvisRotation: -0.06, chestRotation: 0.05),
  DanceBodyKey(1, rootDy: 11, pelvisRotation: -0.14, chestRotation: 0.16),
  DanceBodyKey(2, rootDy: 10, pelvisRotation: -0.16, chestRotation: 0.18),
  DanceBodyKey(3, rootDy: 6, pelvisRotation: -0.06, chestRotation: 0.05),
  DanceBodyKey(5, rootDy: 10, pelvisRotation: -0.1, chestRotation: -0.14),
  DanceBodyKey(6, rootDy: 9, pelvisRotation: -0.1, chestRotation: -0.14),
  DanceBodyKey(7, rootDy: 5),
  DanceBodyKey(8, rootDy: 6, pelvisRotation: 0.06, chestRotation: -0.05),
  DanceBodyKey(9, rootDy: 11, pelvisRotation: 0.14, chestRotation: -0.16),
  DanceBodyKey(10, rootDy: 10, pelvisRotation: 0.16, chestRotation: -0.18),
  DanceBodyKey(11, rootDy: 6, pelvisRotation: 0.06, chestRotation: -0.05),
  DanceBodyKey(13, rootDy: 10, pelvisRotation: 0.1, chestRotation: 0.14),
  DanceBodyKey(14, rootDy: 9, pelvisRotation: 0.1, chestRotation: 0.14),
  DanceBodyKey(15, rootDy: 5),
  DanceBodyKey(16, rootDy: 6, pelvisRotation: -0.06, chestRotation: 0.05),
  DanceBodyKey(17, rootDy: 12, pelvisRotation: -0.15, chestRotation: 0.18),
  DanceBodyKey(18, rootDy: 11, pelvisRotation: -0.17, chestRotation: 0.2),
  DanceBodyKey(19, rootDy: 6, pelvisRotation: -0.06, chestRotation: 0.05),
  DanceBodyKey(21, rootDy: 10, pelvisRotation: -0.1, chestRotation: -0.14),
  DanceBodyKey(22, rootDy: 9, pelvisRotation: -0.1, chestRotation: -0.14),
  DanceBodyKey(23, rootDy: 5),
  DanceBodyKey(24, rootDy: 6, pelvisRotation: 0.06, chestRotation: -0.05),
  DanceBodyKey(25, rootDy: 12, pelvisRotation: 0.15, chestRotation: -0.18),
  DanceBodyKey(26, rootDy: 11, pelvisRotation: 0.17, chestRotation: -0.2),
  DanceBodyKey(27, rootDy: 6, pelvisRotation: 0.06, chestRotation: -0.05),
  DanceBodyKey(29, rootDy: 10, pelvisRotation: 0.1, chestRotation: 0.14),
  DanceBodyKey(30, rootDy: 9, pelvisRotation: 0.1, chestRotation: 0.14),
  DanceBodyKey(31, rootDy: 5),
  DanceBodyKey(32, rootDy: 6, pelvisRotation: -0.06, chestRotation: 0.05),
];
