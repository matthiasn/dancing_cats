part of '../cat_in_suit.dart';

// ─────────────────────────────────────────────────────────────────────────
// Zanku / Legwork (Zlatan, NG 2018) — the lead's LEG-dominant hero move. The
// signature is low tap-dig-pop-stomp footwork: the free shoe knocks heel-toe
// under the hips, scrapes back, then stamps. Earlier wide kicks read like
// generic side-leg choreography, so the current version keeps the ankle lanes
// compact and sells the move through shoe rotation, COM drop, and low fists.
// ─────────────────────────────────────────────────────────────────────────
// Rib/chest piston arms in opposition to the legwork. Letting both fists hang
// low made Zanku read as a generic side-to-side groove; the reference shape is
// elbows bent, fists near ribs/chest, with one fist punching down/out on the
// stomp and the other held as a compact guard.
const _zankuHandLTargetKeys = [
  // Round 4: the old wide W (fists at x 60-98, elbows parked above the
  // shoulder line) read as hovering decoration — no rater saw a pump. New
  // contract: COMPACT rib guard between beats (fists near the ribline,
  // elbows low), and on EVERY stamp both fists drive DOWN past the hip
  // line together (tension hit) and recover — arm punctuation synced to
  // the support-foot plant. The gbese fling (f26) throws the fists down
  // hardest while the kick flies.
  // R10: every rater still called the pump "elbows parked at the hip the
  // whole loop." A world-space probe showed the punch (old x:-32,y:-4)
  // and the guard (x:-36,y:-46) actually DO swing ~50-80 world units in
  // Y — the accent itself just wasn't legible as one, because x barely
  // moved (-32 to -36, a 4-unit band) so the elbow's SIDE-TO-SIDE
  // silhouette — the "elbows-OUT" half of "elbows-out arm pump" — never
  // changed at all; only the fist bobbed vertically inside a fixed-width
  // guard. Pulled the punch's x IN (elbow tucks tight on the down-drive)
  // to contrast against the guard's elbow-out width, and pushed y further
  // past the hip (reach-ratio probed clear of the elbow-straightening
  // ceiling found this round) so the strike reads as a driven low punch,
  // not a return to a neutral hang.
  DanceIkTargetKey(0, x: -26, y: 10, tension: 0.6), // PUNCH down w/ stamp
  DanceIkTargetKey(1, x: -34, y: -26), // recovering
  DanceIkTargetKey(2, x: -36, y: -46), // rib guard
  DanceIkTargetKey(3, x: -35, y: -40), // loads
  DanceIkTargetKey(4, x: -26, y: 10, tension: 0.6), // PUNCH
  DanceIkTargetKey(5, x: -34, y: -26),
  DanceIkTargetKey(6, x: -36, y: -46),
  DanceIkTargetKey(7, x: -35, y: -40),
  // Beats 3-4 (stamps 3-4, frames 8-15) get a DOUBLE elbow pump instead of
  // the single-punch-then-guard of beats 1-2 — the round-3 director flagged
  // frames 0-7 and 8-15 as a near-literal repeat ("half the loop is a
  // literal repeat, which reads as a GIF loop"); footwork is untouched
  // (each stamp still lands on its own beat), only the arm accent varies.
  DanceIkTargetKey(8, x: -26, y: 10, tension: 0.6), // PUNCH (stamp 3)
  DanceIkTargetKey(9, x: -33, y: -18), // shallow recover
  DanceIkTargetKey(10, x: -26, y: 10, tension: 0.7), // second pump
  DanceIkTargetKey(11, x: -35, y: -40), // load into stamp 4
  DanceIkTargetKey(12, x: -26, y: 10, tension: 0.6), // PUNCH (stamp 4)
  DanceIkTargetKey(13, x: -33, y: -18), // shallow recover
  DanceIkTargetKey(14, x: -26, y: 10, tension: 0.7), // second pump
  DanceIkTargetKey(15, x: -35, y: -40), // load into bar 2
  // Round 7: every rater called bar 2 a literal mirror of bar 1 — frames
  // 16/20/24 punched to the exact same (x,y) as frames 0/4/8, so nothing
  // escalates across the 2-bar phrase. Widened/deepened bar 2's three
  // punches progressively so they build toward the gbese climax instead
  // of repeating bar 1's pose pixel-for-pixel.
  // R12+ (task #39): the punch depths escalate but the GUARD in between
  // them (17-19, 21-23) was still the exact same rib-guard hold as bar
  // 1's 1-3/5-7 — panel called this "arms static between punches," and
  // it's the other half of why bar 2 still read as a copy. Coiled the
  // guard progressively wider/higher alongside the punch escalation, so
  // the recovery itself visibly builds tension toward the gbese instead
  // of resetting to an identical shape each time.
  DanceIkTargetKey(16, x: -37, y: -10, tension: 0.6), // PUNCH, building
  DanceIkTargetKey(17, x: -35, y: -28), // guard coiling, 1st step
  DanceIkTargetKey(18, x: -37, y: -49),
  DanceIkTargetKey(19, x: -36, y: -42),
  DanceIkTargetKey(20, x: -40, y: -16, tension: 0.6), // PUNCH, deeper
  DanceIkTargetKey(21, x: -35, y: -29), // guard coiling, 2nd step
  DanceIkTargetKey(22, x: -38, y: -51),
  DanceIkTargetKey(23, x: -36, y: -44),
  DanceIkTargetKey(24, x: -43, y: -22, tension: 0.6), // PUNCH, deepest
  DanceIkTargetKey(25, x: -37, y: -50), // high load behind the gbese
  DanceIkTargetKey(26, x: -26, y: 2, tension: 0.5), // FLING — fists slam down
  DanceIkTargetKey(27, x: -33, y: -30),
  DanceIkTargetKey(28, x: -32, y: -2, tension: 0.7), // landing stamp PUNCH
  // Frame 30's rib guard sits at the same (x,y) used at frames 2/6/18/22,
  // but here it lands while the torso is still swinging fast out of the
  // gbese landing recovery — the shoulder sweeps through this exact point,
  // collapsing shoulder-to-hand reach to ~12% of the arm's total length
  // (deep in the two-bone solver's near-degenerate fold zone, same
  // elbow-hypersensitivity class as the earlier azonto/sekem fix). Widened
  // just this key so reach stays well clear of that zone during the fast
  // recovery, instead of changing the shared rib-guard pose everywhere.
  DanceIkTargetKey(29, x: -33, y: -20), // bridges the landing recovery
  DanceIkTargetKey(30, x: -37, y: -46),
  DanceIkTargetKey(31, x: -35, y: -40),
  DanceIkTargetKey(32, x: -26, y: 10, tension: 0.6), // == frame 0
];
const _zankuHandRTargetKeys = [
  DanceIkTargetKey(0, x: 26, y: 10, tension: 0.6), // PUNCH down w/ stamp
  // Frames 1-3 sit in the same near-degenerate two-bone IK zone as zanku
  // hand.L frame 30 (same lesson: see that fix's comment) — but here it's
  // a sustained plateau (reach stayed ~12% of arm length across the whole
  // guard hold, not a single-frame collision) against a shoulder that
  // itself swings a lot during this beat (x 37->38->79 over these 3
  // frames). A held guard well clear of that reach (~40-46%) needs to sit
  // further out and lower than the original hugged-rib pose.
  DanceIkTargetKey(1, x: 55, y: -10),
  DanceIkTargetKey(2, x: 55, y: -10), // rib guard
  DanceIkTargetKey(3, x: 55, y: -10),
  DanceIkTargetKey(4, x: 26, y: 10, tension: 0.6), // PUNCH
  DanceIkTargetKey(5, x: 34, y: -26),
  DanceIkTargetKey(6, x: 36, y: -46),
  DanceIkTargetKey(7, x: 35, y: -40),
  // Beats 3-4 double pump — see the L hand's comment.
  DanceIkTargetKey(8, x: 26, y: 10, tension: 0.6), // PUNCH (stamp 3)
  DanceIkTargetKey(9, x: 33, y: -18), // shallow recover
  DanceIkTargetKey(10, x: 26, y: 10, tension: 0.7), // second pump
  DanceIkTargetKey(11, x: 35, y: -40), // load into stamp 4
  DanceIkTargetKey(12, x: 26, y: 10, tension: 0.6), // PUNCH (stamp 4)
  DanceIkTargetKey(13, x: 33, y: -18), // shallow recover
  DanceIkTargetKey(14, x: 26, y: 10, tension: 0.7), // second pump
  DanceIkTargetKey(15, x: 35, y: -40), // load into bar 2
  // Round 7: mirrors the hand.L bar-2 escalation fix above (see its
  // comment) — same literal-mirror complaint, mirrored keys.
  DanceIkTargetKey(16, x: 37, y: -10, tension: 0.6), // PUNCH, building
  // Same held-guard-vs-swinging-shoulder issue as frames 1-3 — widened the
  // same way (see that fix's comment).
  DanceIkTargetKey(17, x: 55, y: -10),
  DanceIkTargetKey(18, x: 55, y: -10),
  DanceIkTargetKey(19, x: 55, y: -10),
  DanceIkTargetKey(20, x: 40, y: -16, tension: 0.6), // PUNCH, deeper
  DanceIkTargetKey(21, x: 55, y: -10),
  DanceIkTargetKey(22, x: 55, y: -10),
  DanceIkTargetKey(23, x: 55, y: -10),
  DanceIkTargetKey(24, x: 43, y: -22, tension: 0.6), // PUNCH, deepest
  // Same near-degenerate-reach lesson as zanku hand.L frame 30 and hand.R
  // frame 2: the torso sweeps the shoulder through this exact point during
  // the gbese anticipation, collapsing reach to ~12% of arm length. Widened.
  DanceIkTargetKey(25, x: 58, y: -20), // wide load behind the gbese
  DanceIkTargetKey(26, x: 26, y: 2, tension: 0.5), // FLING — fists slam down
  DanceIkTargetKey(27, x: 33, y: -30),
  DanceIkTargetKey(28, x: 32, y: -2, tension: 0.7), // landing stamp PUNCH
  DanceIkTargetKey(30, x: 36, y: -46),
  DanceIkTargetKey(31, x: 35, y: -40),
  DanceIkTargetKey(32, x: 26, y: 10, tension: 0.6), // == frame 0
];
// Low tap-dig-pop-stomp Zanku legwork. The visible story is SHOE ROTATION and
// COM drop, not a lateral leg extension: the foot stays under the hips, knocks
// heel-toe a few pixels outward, scrapes back, then stamps. The panel kept
// reading the old wide leg as a side kick; keeping the ankles near the pelvis
// makes the groove plausible in a front-facing rig.
const _zankuFootLTargetKeys = [
  DanceIkTargetKey(0, x: -62, y: 126, tension: 1), // heavy stamp/support
  DanceIkTargetKey(2, x: -62, y: 125, tension: 0.6), // planted, held
  DanceIkTargetKey(4, x: -62, y: 126, tension: 0.4), // plant end — swap
  DanceIkTargetKey(5, x: -46, y: 110), // compact pickup, not a stride
  DanceIkTargetKey(6, x: -83, y: 122), // heel-toe knock under hip
  DanceIkTargetKey(7, x: -50, y: 124), // drag back under the knee
  DanceIkTargetKey(8, x: -62, y: 126, tension: 1), // stamp
  DanceIkTargetKey(10, x: -62, y: 125, tension: 0.6),
  DanceIkTargetKey(12, x: -62, y: 126, tension: 0.4),
  DanceIkTargetKey(13, x: -46, y: 110),
  DanceIkTargetKey(14, x: -83, y: 122),
  DanceIkTargetKey(15, x: -50, y: 124),
  DanceIkTargetKey(16, x: -62, y: 126, tension: 1), // stamp
  DanceIkTargetKey(18, x: -62, y: 125, tension: 0.6),
  DanceIkTargetKey(20, x: -62, y: 126, tension: 0.4),
  // R12+ (task #39): this pickup/knock/drag was a near-pixel-identical
  // repeat of frames 5/6/7 (and 13/14/15 before it) — panel called the
  // whole loop "one knee-lift shape looped four times." The foot is
  // airborne here (support is on the other foot per the contact span),
  // so there's room to widen the arc without disturbing weight-bearing:
  // pushed the pickup higher and the knock/drag further out, reading as
  // a deeper, more committed step building into the gbese half of the
  // phrase rather than a fourth identical rep.
  DanceIkTargetKey(21, x: -40, y: 100),
  DanceIkTargetKey(22, x: -88, y: 118),
  DanceIkTargetKey(23, x: -54, y: 117),
  DanceIkTargetKey(24, x: -64, y: 126, tension: 1), // stamp/support
  DanceIkTargetKey(
    26,
    x: -64,
    y: 125,
    tension: 0.6,
  ), // support holds while right kicks
  DanceIkTargetKey(28, x: -83, y: 123), // exact-window heel-toe scrape
  DanceIkTargetKey(29, x: -52, y: 123),
  DanceIkTargetKey(30, x: -80, y: 123),
  DanceIkTargetKey(31, x: -52, y: 123),
  DanceIkTargetKey(32, x: -62, y: 126, tension: 1), // == frame 0
];
// RIGHT foot: opposite phase — digs out on 2/10/18/26, stamps on 4/12/20/28.
const _zankuFootRTargetKeys = [
  DanceIkTargetKey(0, x: 50, y: 123), // scrape from previous tap
  DanceIkTargetKey(1, x: 44, y: 110), // compact pickup
  DanceIkTargetKey(2, x: 83, y: 122), // heel-toe knock under hip
  DanceIkTargetKey(3, x: 50, y: 124), // drag back under the knee
  DanceIkTargetKey(4, x: 62, y: 126, tension: 1), // stamp/support
  DanceIkTargetKey(6, x: 62, y: 125, tension: 0.6), // planted, held
  DanceIkTargetKey(8, x: 50, y: 123),
  DanceIkTargetKey(9, x: 44, y: 110),
  DanceIkTargetKey(10, x: 83, y: 122),
  DanceIkTargetKey(11, x: 50, y: 124),
  DanceIkTargetKey(12, x: 62, y: 126, tension: 1), // stamp
  DanceIkTargetKey(14, x: 62, y: 125, tension: 0.6),
  DanceIkTargetKey(16, x: 50, y: 123),
  DanceIkTargetKey(17, x: 44, y: 110),
  DanceIkTargetKey(18, x: 83, y: 122),
  DanceIkTargetKey(19, x: 50, y: 124),
  DanceIkTargetKey(20, x: 62, y: 126, tension: 1), // stamp
  DanceIkTargetKey(22, x: 62, y: 125, tension: 0.6),
  DanceIkTargetKey(24, x: 50, y: 123),
  // Round 7: every rater independently called the gbese "clipped to
  // shin/knee height" — the authored apex (y:52) sat at the shallow end
  // of the tested band (40..52, "hip-to-waist height" per the test's own
  // reason string), not the deep end. Pushed to the tested ceiling.
  // Round 9: even at the tested apex, raters called this "afrobeats-
  // adjacent footwork" rather than a real air-kick — measured world reach
  // from the hip confirmed why: at the exact apex the leg is only ~47% of
  // its max reach (a tucked knee raise), while the untested approach/
  // release frames reach 63-74%. Swept 25/27 further outboard so the leg
  // is already extending OUT before/after the apex, reading as one
  // continuous kicking arc instead of a knee tucking up and back.
  DanceIkTargetKey(25, x: 48, y: 64), // extending out into the kick
  DanceIkTargetKey(
    26,
    x: 32,
    y: 46,
    tension: 0.8,
  ), // GBESE apex — knee/waist height
  DanceIkTargetKey(27, x: 52, y: 76), // whip continues out, still high
  DanceIkTargetKey(28, x: 64, y: 126, tension: 1), // SLAM landing stamp
  DanceIkTargetKey(30, x: 64, y: 125, tension: 0.6), // held support for loop
  DanceIkTargetKey(32, x: 50, y: 123), // == frame 0
];
// Per-beat support map: which foot stamps (and is world-anchored) each beat.
const _zankuContactSpans = [
  GroundSpan(CatBones.footL, 0, 0.125), // beat 1 — left stamps
  GroundSpan(CatBones.footR, 0.125, 0.25), // beat 2 — right stamps
  GroundSpan(CatBones.footL, 0.25, 0.375), // beat 3
  GroundSpan(CatBones.footR, 0.375, 0.5), // beat 4
  GroundSpan(CatBones.footL, 0.5, 0.625), // beat 5
  GroundSpan(CatBones.footR, 0.625, 0.75), // beat 6
  GroundSpan(CatBones.footL, 0.75, 0.875), // beat 7
  GroundSpan(CatBones.footR, 0.875, 1), // beat 8
];
const _zankuFootLKeys = [
  DanceJointKey(0, rotation: 0.1),
  DanceJointKey(4, rotation: -0.28),
  DanceJointKey(5, rotation: 0.34),
  DanceJointKey(6, rotation: 1.02),
  DanceJointKey(7, rotation: -0.42),
  DanceJointKey(8, rotation: 0.1),
  DanceJointKey(12, rotation: -0.28),
  DanceJointKey(13, rotation: 0.34),
  DanceJointKey(14, rotation: 1.04),
  DanceJointKey(15, rotation: -0.42),
  DanceJointKey(16, rotation: 0.1),
  DanceJointKey(20, rotation: -0.28),
  DanceJointKey(21, rotation: 0.34),
  DanceJointKey(22, rotation: 1.02),
  DanceJointKey(23, rotation: -0.42),
  DanceJointKey(24, rotation: 0.1),
  DanceJointKey(28, rotation: -0.28),
  DanceJointKey(29, rotation: 0.34),
  DanceJointKey(30, rotation: 1.04),
  DanceJointKey(32, rotation: 0.1),
];
const _zankuFootRKeys = [
  DanceJointKey(0, rotation: 0.42),
  DanceJointKey(1, rotation: -0.34),
  DanceJointKey(2, rotation: -1.08),
  DanceJointKey(3, rotation: 0.42),
  DanceJointKey(4, rotation: -0.1),
  DanceJointKey(8, rotation: 0.42),
  DanceJointKey(9, rotation: -0.34),
  DanceJointKey(10, rotation: -1.02),
  DanceJointKey(11, rotation: 0.42),
  DanceJointKey(12, rotation: -0.1),
  DanceJointKey(16, rotation: 0.42),
  DanceJointKey(17, rotation: -0.34),
  DanceJointKey(18, rotation: -1.08),
  DanceJointKey(19, rotation: 0.42),
  DanceJointKey(20, rotation: -0.1),
  DanceJointKey(24, rotation: 0.42),
  DanceJointKey(25, rotation: -0.34),
  DanceJointKey(26, rotation: -1.02),
  DanceJointKey(27, rotation: 0.42),
  DanceJointKey(28, rotation: -0.1),
  DanceJointKey(32, rotation: 0.42),
];
// Clavicle rolls behind the stamps (panel: 'elbow-only hinges, clavicles
// frozen'): the shoulder opposite the striking foot dips into each count
// — left foot stamps the odd counts so the RIGHT shoulder dips there, the
// LEFT answers on the right foot's counts.
const _zankuClavicleRKeys = [
  DanceJointKey(0, rotation: 0.12),
  DanceJointKey(2, rotation: -0.1),
  DanceJointKey(4, rotation: -0.03),
  DanceJointKey(6, rotation: 0.02),
  DanceJointKey(8, rotation: 0.12),
  DanceJointKey(10, rotation: -0.1),
  DanceJointKey(12, rotation: -0.03),
  DanceJointKey(14, rotation: 0.02),
  DanceJointKey(16, rotation: 0.12),
  DanceJointKey(18, rotation: -0.1),
  DanceJointKey(20, rotation: -0.03),
  DanceJointKey(22, rotation: 0.02),
  DanceJointKey(24, rotation: 0.12),
  DanceJointKey(26, rotation: -0.1),
  DanceJointKey(28, rotation: -0.03),
  DanceJointKey(30, rotation: 0.02),
  DanceJointKey(32, rotation: 0.12),
];
const _zankuClavicleLKeys = [
  DanceJointKey(0, rotation: 0.03),
  DanceJointKey(2, rotation: -0.12),
  DanceJointKey(4, rotation: 0.1),
  DanceJointKey(6, rotation: -0.02),
  DanceJointKey(8, rotation: 0.03),
  DanceJointKey(10, rotation: -0.12),
  DanceJointKey(12, rotation: 0.1),
  DanceJointKey(14, rotation: -0.02),
  DanceJointKey(16, rotation: 0.03),
  DanceJointKey(18, rotation: -0.12),
  DanceJointKey(20, rotation: 0.1),
  DanceJointKey(22, rotation: -0.02),
  DanceJointKey(24, rotation: 0.03),
  DanceJointKey(26, rotation: -0.12),
  DanceJointKey(28, rotation: 0.1),
  DanceJointKey(30, rotation: -0.02),
  DanceJointKey(32, rotation: 0.03),
];
// Head attitude — ported from the shaku ornament vocabulary (R28) in
// zanku's own idiom: the skull answers each alternating STAMP one frame
// after it lands (tilting toward the striking side), carries a ~40% echo
// nod two frames later, tips INTO the gbese kick and recoils off the
// slam. Before this channel zanku's head was runtime-only ("the body
// dances but the character doesn't").
const _zankuHeadKeys = [
  DanceJointKey(0, rotation: 0.02),
  DanceJointKey(1, rotation: 0.08), // answers the L stamp
  DanceJointKey(3, rotation: 0.032), // echo nod
  DanceJointKey(5, rotation: -0.08), // answers the R stamp
  DanceJointKey(7, rotation: -0.032),
  DanceJointKey(9, rotation: 0.08),
  DanceJointKey(11, rotation: 0.032),
  DanceJointKey(13, rotation: -0.08),
  DanceJointKey(15, rotation: -0.032),
  DanceJointKey(17, rotation: 0.08),
  DanceJointKey(19, rotation: 0.032),
  DanceJointKey(21, rotation: -0.08),
  DanceJointKey(23, rotation: -0.032),
  DanceJointKey(25, rotation: 0.09), // gathers against the kick side
  DanceJointKey(26, rotation: -0.1), // tips INTO the gbese
  DanceJointKey(28, rotation: -0.05), // recoils off the slam
  DanceJointKey(30, rotation: 0.02),
  DanceJointKey(32, rotation: 0.02), // == frame 0
];

const _zankuHandLKeys = [
  DanceJointKey(0, rotation: -0.18),
  DanceJointKey(2, rotation: -0.08),
  DanceJointKey(4, rotation: 0.32),
  DanceJointKey(5, rotation: 0.12),
  DanceJointKey(6, rotation: -0.12),
  DanceJointKey(7, rotation: -0.28), // wrist flick (ornament port)
  DanceJointKey(8, rotation: -0.22),
  DanceJointKey(10, rotation: -0.06),
  DanceJointKey(12, rotation: 0.34),
  DanceJointKey(13, rotation: 0.1),
  DanceJointKey(14, rotation: -0.14),
  DanceJointKey(15, rotation: -0.3), // wrist flick
  DanceJointKey(16, rotation: -0.24),
  DanceJointKey(18, rotation: -0.06),
  DanceJointKey(20, rotation: 0.3),
  DanceJointKey(21, rotation: 0.1),
  DanceJointKey(22, rotation: -0.12),
  DanceJointKey(23, rotation: -0.28), // wrist flick
  DanceJointKey(24, rotation: -0.2),
  DanceJointKey(26, rotation: -0.04),
  DanceJointKey(28, rotation: 0.36),
  DanceJointKey(29, rotation: 0.12),
  DanceJointKey(30, rotation: -0.14),
  DanceJointKey(31, rotation: -0.3), // wrist flick into the loop
  DanceJointKey(32, rotation: -0.18),
];
const _zankuHandRKeys = [
  DanceJointKey(0, rotation: -0.36),
  DanceJointKey(1, rotation: -0.12),
  DanceJointKey(2, rotation: 0.14),
  DanceJointKey(3, rotation: 0.32), // wrist flick (ornament port)
  DanceJointKey(4, rotation: 0.18),
  DanceJointKey(6, rotation: 0.08),
  DanceJointKey(8, rotation: -0.34),
  DanceJointKey(9, rotation: -0.12),
  DanceJointKey(10, rotation: 0.14),
  DanceJointKey(11, rotation: 0.32), // wrist flick
  DanceJointKey(12, rotation: 0.22),
  DanceJointKey(14, rotation: 0.06),
  DanceJointKey(16, rotation: -0.32),
  DanceJointKey(17, rotation: -0.1),
  DanceJointKey(18, rotation: 0.14),
  DanceJointKey(19, rotation: 0.32), // wrist flick
  DanceJointKey(20, rotation: 0.24),
  DanceJointKey(22, rotation: 0.06),
  DanceJointKey(24, rotation: -0.36),
  DanceJointKey(25, rotation: -0.12),
  DanceJointKey(26, rotation: 0.12),
  DanceJointKey(27, rotation: 0.3), // wrist flick off the gbese
  DanceJointKey(28, rotation: 0.2),
  DanceJointKey(30, rotation: 0.06),
  DanceJointKey(32, rotation: -0.36),
];

// Per-beat weight commit that DWELLS over the stamping foot. Stomp frames drop
// the COM deepest, pickup frames rebound only slightly, and the chest bites
// back harder than the pelvis so the shoulders are visibly dancing the beat
// instead of staying upright while the feet move.
const _zankuCommitKeysRaw = [
  DanceBodyKey(
    0,
    rootDx: -22,
    rootDy: 42,
    pelvisRotation: -0.36,
    chestRotation: 0.42,
  ),
  DanceBodyKey(
    1,
    rootDx: -16,
    rootDy: 24,
    pelvisRotation: -0.22,
    chestRotation: 0.28,
  ),
  DanceBodyKey(
    2,
    rootDx: -15,
    rootDy: 24,
    pelvisRotation: -0.2,
    chestRotation: 0.26,
  ),
  DanceBodyKey(
    3,
    rootDx: -10,
    rootDy: 30,
    pelvisRotation: -0.15,
    chestRotation: 0.2,
  ),
  DanceBodyKey(
    4,
    rootDx: 22,
    rootDy: 42,
    pelvisRotation: 0.36,
    chestRotation: -0.42,
  ),
  DanceBodyKey(
    5,
    rootDx: 16,
    rootDy: 24,
    pelvisRotation: 0.22,
    chestRotation: -0.28,
  ),
  DanceBodyKey(
    6,
    rootDx: 15,
    rootDy: 24,
    pelvisRotation: 0.2,
    chestRotation: -0.26,
  ),
  DanceBodyKey(
    7,
    rootDx: 10,
    rootDy: 30,
    pelvisRotation: 0.15,
    chestRotation: -0.2,
  ),
  DanceBodyKey(
    8,
    rootDx: -22,
    rootDy: 42,
    pelvisRotation: -0.37,
    chestRotation: 0.44,
  ),
  DanceBodyKey(
    9,
    rootDx: -16,
    rootDy: 24,
    pelvisRotation: -0.22,
    chestRotation: 0.28,
  ),
  DanceBodyKey(
    10,
    rootDx: -15,
    rootDy: 24,
    pelvisRotation: -0.2,
    chestRotation: 0.26,
  ),
  DanceBodyKey(
    11,
    rootDx: -10,
    rootDy: 30,
    pelvisRotation: -0.15,
    chestRotation: 0.2,
  ),
  DanceBodyKey(
    12,
    rootDx: 22,
    rootDy: 42,
    pelvisRotation: 0.37,
    chestRotation: -0.44,
  ),
  DanceBodyKey(
    13,
    rootDx: 16,
    rootDy: 24,
    pelvisRotation: 0.22,
    chestRotation: -0.28,
  ),
  DanceBodyKey(
    14,
    rootDx: 15,
    rootDy: 24,
    pelvisRotation: 0.2,
    chestRotation: -0.26,
  ),
  DanceBodyKey(
    15,
    rootDx: 10,
    rootDy: 30,
    pelvisRotation: 0.15,
    chestRotation: -0.2,
  ),
  DanceBodyKey(
    16,
    rootDx: -22,
    rootDy: 42,
    pelvisRotation: -0.37,
    chestRotation: 0.44,
  ),
  DanceBodyKey(
    17,
    rootDx: -16,
    rootDy: 24,
    pelvisRotation: -0.22,
    chestRotation: 0.28,
  ),
  DanceBodyKey(
    18,
    rootDx: -15,
    rootDy: 24,
    pelvisRotation: -0.2,
    chestRotation: 0.26,
  ),
  DanceBodyKey(
    19,
    rootDx: -10,
    rootDy: 30,
    pelvisRotation: -0.15,
    chestRotation: 0.2,
  ),
  DanceBodyKey(
    20,
    rootDx: 22,
    rootDy: 42,
    pelvisRotation: 0.37,
    chestRotation: -0.44,
  ),
  DanceBodyKey(
    21,
    rootDx: 16,
    rootDy: 24,
    pelvisRotation: 0.22,
    chestRotation: -0.28,
  ),
  DanceBodyKey(
    22,
    rootDx: 15,
    rootDy: 24,
    pelvisRotation: 0.2,
    chestRotation: -0.26,
  ),
  DanceBodyKey(
    23,
    rootDx: 10,
    rootDy: 30,
    pelvisRotation: 0.15,
    chestRotation: -0.2,
  ),
  DanceBodyKey(
    24,
    rootDx: -24,
    rootDy: 44,
    pelvisRotation: -0.39,
    chestRotation: 0.46,
  ),
  DanceBodyKey(
    25,
    rootDx: -16,
    rootDy: 24,
    pelvisRotation: -0.22,
    chestRotation: 0.28,
  ),
  DanceBodyKey(
    26,
    rootDx: -15,
    rootDy: 24,
    pelvisRotation: -0.2,
    chestRotation: 0.26,
  ),
  DanceBodyKey(
    27,
    rootDx: -10,
    rootDy: 30,
    pelvisRotation: -0.15,
    chestRotation: 0.2,
  ),
  DanceBodyKey(
    28,
    rootDx: 24,
    rootDy: 44,
    pelvisRotation: 0.39,
    chestRotation: -0.46,
  ),
  DanceBodyKey(
    29,
    rootDx: 16,
    rootDy: 24,
    pelvisRotation: 0.22,
    chestRotation: -0.28,
  ),
  DanceBodyKey(
    30,
    rootDx: 15,
    rootDy: 24,
    pelvisRotation: 0.2,
    chestRotation: -0.26,
  ),
  DanceBodyKey(
    31,
    rootDx: 10,
    rootDy: 30,
    pelvisRotation: 0.15,
    chestRotation: -0.2,
  ),
  DanceBodyKey(
    32,
    rootDx: -22,
    rootDy: 42,
    pelvisRotation: -0.36,
    chestRotation: 0.42,
  ),
];

final List<DanceBodyKey> _zankuCommitKeys = _scaledBodyKeys(
  _zankuCommitKeysRaw,
  rootDxGain: 0.82,
  rootDyGain: 0.9,
  pelvisRotationGain: 0.84,
  chestRotationGain: 0.82,
);

// Gbese punctuation (round 3: "no whip, no counter lean-back, no heavy slam
// landing"): the trunk releases its forward fold into a lean-back exactly at
// the kick apex (f26), then the landing stamp (f28) drives a deep slam drop
// that settles over two frames.
// R10: probed the SOLVED torso world angle (not just this layer's own
// authored value) at f26 and found it nets out to only ~3deg — several
// OTHER layers active on the same beat (the commit/pocket-boost keys, the
// constant forward-fold bias) mostly cancel this release before it ever
// reaches the render. Deepened this layer's own contribution so its
// release actually survives being summed with the rest.
const _zankuGbeseAccentKeys = [
  DanceBodyKey(24, rootDy: 0, chestRotation: 0),
  DanceBodyKey(26, rootDy: -5, chestRotation: -0.85, chestScaleY: 1.04),
  DanceBodyKey(28, rootDy: 16, chestRotation: 0.08, chestScaleY: 0.94),
  DanceBodyKey(29, rootDy: 11, chestRotation: 0.05, chestScaleY: 0.97),
  DanceBodyKey(30, rootDy: 0, chestRotation: 0),
];

const _zankuPocketBoostKeys = [
  DanceBodyKey(
    0,
    rootDy: 6,
    pelvisRotation: -0.06,
    chestRotation: 0.08,
    chestScaleY: 0.97,
    chestScaleX: 1.025,
  ),
  DanceBodyKey(2, rootDy: -2, pelvisRotation: -0.02, chestRotation: 0.02),
  DanceBodyKey(
    4,
    rootDy: 7,
    pelvisRotation: 0.07,
    chestRotation: -0.09,
    chestScaleY: 0.965,
    chestScaleX: 1.03,
  ),
  DanceBodyKey(6, rootDy: -2, pelvisRotation: 0.02, chestRotation: -0.02),
  DanceBodyKey(
    8,
    rootDy: 6,
    pelvisRotation: -0.07,
    chestRotation: 0.09,
    chestScaleY: 0.965,
    chestScaleX: 1.03,
  ),
  DanceBodyKey(10, rootDy: -2, pelvisRotation: -0.02, chestRotation: 0.02),
  DanceBodyKey(
    12,
    rootDy: 7,
    pelvisRotation: 0.07,
    chestRotation: -0.09,
    chestScaleY: 0.965,
    chestScaleX: 1.03,
  ),
  DanceBodyKey(14, rootDy: -2, pelvisRotation: 0.02, chestRotation: -0.02),
  DanceBodyKey(
    16,
    rootDy: 6,
    pelvisRotation: -0.07,
    chestRotation: 0.09,
    chestScaleY: 0.965,
    chestScaleX: 1.03,
  ),
  DanceBodyKey(18, rootDy: -2, pelvisRotation: -0.02, chestRotation: 0.02),
  DanceBodyKey(
    20,
    rootDy: 7,
    pelvisRotation: 0.07,
    chestRotation: -0.09,
    chestScaleY: 0.965,
    chestScaleX: 1.03,
  ),
  DanceBodyKey(22, rootDy: -2, pelvisRotation: 0.02, chestRotation: -0.02),
  DanceBodyKey(
    24,
    rootDy: 8,
    pelvisRotation: -0.08,
    chestRotation: 0.1,
    chestScaleY: 0.96,
    chestScaleX: 1.035,
  ),
  DanceBodyKey(26, rootDy: -2, pelvisRotation: -0.02, chestRotation: 0.02),
  DanceBodyKey(
    28,
    rootDy: 8,
    pelvisRotation: 0.08,
    chestRotation: -0.1,
    chestScaleY: 0.96,
    chestScaleX: 1.035,
  ),
  DanceBodyKey(30, rootDy: -2, pelvisRotation: 0.02, chestRotation: -0.02),
  DanceBodyKey(
    32,
    rootDy: 6,
    pelvisRotation: -0.06,
    chestRotation: 0.08,
    chestScaleY: 0.97,
    chestScaleX: 1.025,
  ),
];

// Extra stomp load over the active Zanku support foot. The base commit keys
// carry the step pattern; this layer makes the plant frames read as a brief
// grounded compression instead of a whole-body lean sliding through centre.
const _zankuSupportLoadKeysRaw = [
  DanceBodyKey(
    0,
    rootDx: -6,
    rootDy: 6,
    pelvisRotation: -0.08,
    chestRotation: 0.03,
  ),
  DanceBodyKey(
    1,
    rootDx: -5,
    rootDy: 10,
    pelvisRotation: -0.06,
    chestRotation: 0.02,
  ),
  DanceBodyKey(2, rootDy: -2, pelvisRotation: -0.01, chestRotation: 0.01),
  DanceBodyKey(
    3,
    rootDx: 3,
    rootDy: 2,
    pelvisRotation: 0.045,
    chestRotation: -0.015,
  ),
  DanceBodyKey(
    4,
    rootDx: 6,
    rootDy: 6,
    pelvisRotation: 0.08,
    chestRotation: -0.03,
  ),
  DanceBodyKey(
    5,
    rootDx: 5,
    rootDy: 10,
    pelvisRotation: 0.06,
    chestRotation: -0.02,
  ),
  DanceBodyKey(6, rootDy: -2, pelvisRotation: 0.01, chestRotation: -0.01),
  DanceBodyKey(
    7,
    rootDx: -3,
    rootDy: 2,
    pelvisRotation: -0.045,
    chestRotation: 0.015,
  ),
  DanceBodyKey(
    8,
    rootDx: -6,
    rootDy: 6,
    pelvisRotation: -0.08,
    chestRotation: 0.03,
  ),
  DanceBodyKey(
    9,
    rootDx: -5,
    rootDy: 10,
    pelvisRotation: -0.06,
    chestRotation: 0.02,
  ),
  DanceBodyKey(10, rootDy: -2, pelvisRotation: -0.01, chestRotation: 0.01),
  DanceBodyKey(
    11,
    rootDx: 3,
    rootDy: 2,
    pelvisRotation: 0.045,
    chestRotation: -0.015,
  ),
  DanceBodyKey(
    12,
    rootDx: 6,
    rootDy: 6,
    pelvisRotation: 0.08,
    chestRotation: -0.03,
  ),
  DanceBodyKey(
    13,
    rootDx: 5,
    rootDy: 10,
    pelvisRotation: 0.06,
    chestRotation: -0.02,
  ),
  DanceBodyKey(14, rootDy: -2, pelvisRotation: 0.01, chestRotation: -0.01),
  DanceBodyKey(
    15,
    rootDx: -3,
    rootDy: 2,
    pelvisRotation: -0.045,
    chestRotation: 0.015,
  ),
  DanceBodyKey(
    16,
    rootDx: -6,
    rootDy: 6,
    pelvisRotation: -0.08,
    chestRotation: 0.03,
  ),
  DanceBodyKey(
    17,
    rootDx: -5,
    rootDy: 10,
    pelvisRotation: -0.06,
    chestRotation: 0.02,
  ),
  DanceBodyKey(18, rootDy: -2, pelvisRotation: -0.01, chestRotation: 0.01),
  DanceBodyKey(
    19,
    rootDx: 3,
    rootDy: 2,
    pelvisRotation: 0.045,
    chestRotation: -0.015,
  ),
  DanceBodyKey(
    20,
    rootDx: 6,
    rootDy: 6,
    pelvisRotation: 0.08,
    chestRotation: -0.03,
  ),
  DanceBodyKey(
    21,
    rootDx: 5,
    rootDy: 10,
    pelvisRotation: 0.06,
    chestRotation: -0.02,
  ),
  DanceBodyKey(22, rootDy: -2, pelvisRotation: 0.01, chestRotation: -0.01),
  DanceBodyKey(
    23,
    rootDx: -3.5,
    rootDy: 2.5,
    pelvisRotation: -0.05,
    chestRotation: 0.018,
  ),
  DanceBodyKey(
    24,
    rootDx: -7,
    rootDy: 7,
    pelvisRotation: -0.09,
    chestRotation: 0.035,
  ),
  DanceBodyKey(
    25,
    rootDx: -6,
    rootDy: 11,
    pelvisRotation: -0.07,
    chestRotation: 0.024,
  ),
  DanceBodyKey(26, rootDy: -2, pelvisRotation: -0.01, chestRotation: 0.01),
  DanceBodyKey(
    27,
    rootDx: 3.5,
    rootDy: 2.5,
    pelvisRotation: 0.05,
    chestRotation: -0.018,
  ),
  DanceBodyKey(
    28,
    rootDx: 7,
    rootDy: 7,
    pelvisRotation: 0.09,
    chestRotation: -0.035,
  ),
  DanceBodyKey(
    29,
    rootDx: 6,
    rootDy: 11,
    pelvisRotation: 0.07,
    chestRotation: -0.024,
  ),
  DanceBodyKey(30, rootDy: -2, pelvisRotation: 0.01, chestRotation: -0.01),
  DanceBodyKey(
    31,
    rootDx: -3,
    rootDy: 2,
    pelvisRotation: -0.045,
    chestRotation: 0.015,
  ),
  DanceBodyKey(
    32,
    rootDx: -6,
    rootDy: 6,
    pelvisRotation: -0.08,
    chestRotation: 0.03,
  ),
];

final List<DanceBodyKey> _zankuSupportLoadKeys = _scaledBodyKeys(
  _zankuSupportLoadKeysRaw,
  rootDxGain: 0.78,
  rootDyGain: 0.96,
  pelvisRotationGain: 0.82,
  chestRotationGain: 0.82,
);
