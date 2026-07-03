part of '../cat_in_suit.dart';

// ─────────────────────────────────────────────────────────────────────────
// Pouncing Cat — a compact character hook: compress, push, land, then rebound
// through an Afrobeats shoulder/hip pocket. The cat paw is a rhythmic accent
// layered onto the groove, not a long straight attack pose.
// ─────────────────────────────────────────────────────────────────────────
const _pounceBodyKeys = [
  DanceBodyKey(
    0,
    rootDx: -14,
    rootDy: 46,
    rootRotation: 0.002,
    pelvisRotation: -0.2,
    chestRotation: 0.18,
    chestScaleY: 0.82,
    chestScaleX: 1.14,
  ),
  DanceBodyKey(
    2,
    rootDx: -16,
    rootDy: 62,
    rootRotation: 0.003,
    pelvisRotation: -0.28,
    chestRotation: 0.26,
    chestScaleY: 0.72,
    chestScaleX: 1.22,
  ),
  DanceBodyKey(
    4,
    rootDx: -18,
    rootDy: 80,
    rootRotation: 0.004,
    pelvisRotation: -0.32,
    chestRotation: 0.32,
    chestScaleY: 0.64,
    chestScaleX: 1.26,
  ),
  DanceBodyKey(
    6,
    rootDx: -10,
    rootDy: 34,
    pelvisRotation: -0.08,
    chestRotation: 0.02,
    chestScaleY: 1.06,
    chestScaleX: 0.98,
  ),
  DanceBodyKey(
    8,
    rootDx: 14,
    rootDy: 10,
    pelvisRotation: 0.2,
    chestRotation: -0.34,
    chestScaleY: 1.14,
    chestScaleX: 0.94,
  ),
  DanceBodyKey(
    10,
    rootDx: 16,
    rootDy: 44,
    pelvisRotation: 0.15,
    chestRotation: -0.14,
    chestScaleY: 0.94,
    chestScaleX: 1.04,
  ), // settle into the glide
  DanceBodyKey(
    12,
    rootDx: 14,
    rootDy: 48,
    rootRotation: -0.004,
    pelvisRotation: 0.12,
    chestRotation: -0.12,
    chestScaleY: 0.92,
    chestScaleX: 1.06,
  ), // GLIDE — level head, knees absorb (the Amapiano contrast)
  DanceBodyKey(
    14,
    rootDx: 8,
    rootDy: 46,
    pelvisRotation: 0.12,
    chestRotation: -0.08,
    chestScaleY: 0.94,
    chestScaleX: 1.04,
  ),
  DanceBodyKey(
    16,
    rootDx: 2,
    rootDy: 48,
    pelvisRotation: -0.04,
    chestRotation: 0.06,
    chestScaleY: 0.88,
    chestScaleX: 1.08,
  ),
  // R10: the director called the 2-bar phrase "the same 2-beat cycle
  // looped four times" — bar 2's crouch/push (frames 20/24) were LITERAL
  // copies of bar 1's (frame 4/8), differentiated only by the L/R sign
  // flip. Root-motion samples are inequality/range-tested, not exact-
  // pinned, so there was room to escalate: deepened the second crouch
  // and sharpened the second push beyond bar 1's, so bar 2 reads as a
  // bigger second rep instead of a mirrored copy.
  DanceBodyKey(18, rootDx: 10, rootDy: 54, pelvisRotation: 0.2),
  DanceBodyKey(
    20,
    rootDx: 19,
    rootDy: 88,
    rootRotation: -0.006,
    pelvisRotation: 0.32,
    chestRotation: -0.3,
    chestScaleY: 0.6,
    chestScaleX: 1.3,
  ),
  DanceBodyKey(
    22,
    rootDx: 8,
    rootDy: 34,
    pelvisRotation: 0.08,
    chestRotation: -0.02,
    chestScaleY: 1.06,
    chestScaleX: 0.98,
  ),
  DanceBodyKey(
    24,
    rootDx: -15,
    rootDy: 4,
    pelvisRotation: -0.22,
    chestRotation: 0.36,
    chestScaleY: 1.18,
    chestScaleX: 0.9,
  ),
  DanceBodyKey(
    26,
    rootDx: -16,
    rootDy: 44,
    pelvisRotation: -0.15,
    chestRotation: 0.14,
    chestScaleY: 0.94,
    chestScaleX: 1.04,
  ), // GLIDE
  DanceBodyKey(
    28,
    rootDx: -14,
    rootDy: 48,
    rootRotation: 0.004,
    pelvisRotation: -0.12,
    chestRotation: 0.12,
    chestScaleY: 0.92,
    chestScaleX: 1.06,
  ), // GLIDE
  DanceBodyKey(
    30,
    rootDx: -8,
    rootDy: 46,
    pelvisRotation: -0.12,
    chestRotation: 0.08,
    chestScaleY: 0.94,
    chestScaleX: 1.04,
  ),
  DanceBodyKey(
    32,
    rootDx: -14,
    rootDy: 46,
    rootRotation: 0.003,
    pelvisRotation: -0.2,
    chestRotation: 0.18,
    chestScaleY: 0.82,
    chestScaleX: 1.14,
  ),
];

// A secondary beat pocket over the pounce: small side-weight and torso
// counter accents on the even counts so the phrase keeps dancing between the
// theatrical crouch/reach/land poses.
const _pounceGrooveKeys = [
  DanceBodyKey(0, rootDx: 0, rootDy: 0, pelvisRotation: 0, chestRotation: 0),
  DanceBodyKey(
    2,
    rootDx: -10,
    rootDy: 8,
    pelvisRotation: -0.08,
    chestRotation: 0.08,
  ),
  DanceBodyKey(4, rootDx: -4, rootDy: 0),
  DanceBodyKey(
    6,
    rootDx: 12,
    rootDy: 6,
    pelvisRotation: 0.08,
    chestRotation: -0.08,
  ),
  DanceBodyKey(8, rootDx: 4, rootDy: 0),
  DanceBodyKey(
    10,
    rootDx: 10,
    rootDy: 7,
    pelvisRotation: 0.08,
    chestRotation: -0.09,
  ),
  DanceBodyKey(12, rootDx: 2, rootDy: 0),
  DanceBodyKey(
    14,
    rootDx: -10,
    rootDy: 8,
    pelvisRotation: -0.08,
    chestRotation: 0.09,
  ),
  DanceBodyKey(16, rootDx: 0, rootDy: 0),
  DanceBodyKey(
    18,
    rootDx: 10,
    rootDy: 8,
    pelvisRotation: 0.08,
    chestRotation: -0.08,
  ),
  DanceBodyKey(20, rootDx: 4, rootDy: 0),
  DanceBodyKey(
    22,
    rootDx: -12,
    rootDy: 6,
    pelvisRotation: -0.08,
    chestRotation: 0.08,
  ),
  DanceBodyKey(24, rootDx: -4, rootDy: 0),
  DanceBodyKey(
    26,
    rootDx: -10,
    rootDy: 7,
    pelvisRotation: -0.08,
    chestRotation: 0.09,
  ),
  DanceBodyKey(28, rootDx: -2, rootDy: 0),
  DanceBodyKey(
    30,
    rootDx: 10,
    rootDy: 8,
    pelvisRotation: 0.08,
    chestRotation: -0.09,
  ),
  DanceBodyKey(32, rootDx: 0, rootDy: 0, pelvisRotation: 0, chestRotation: 0),
];

const _pounceContactSpans = [
  GroundSpan(CatBones.footL, 0, 0.25),
  GroundSpan(CatBones.footR, 0.25, 0.5),
  GroundSpan(CatBones.footR, 0.5, 0.75),
  GroundSpan(CatBones.footL, 0.75, 0.9375),
  GroundSpan(CatBones.footR, 0.9375, 1),
];
// Feet show the pounce arc without a long side kick: both feet compress on
// the floor, gather under the hips, lift modestly through the push, then land
// wide and compressed.
const _pounceFootLTargetKeys = [
  DanceIkTargetKey(0, x: -54, y: 100),
  DanceIkTargetKey(4, x: -72, y: 101),
  DanceIkTargetKey(6, x: -62, y: 100),
  DanceIkTargetKey(8, x: -14, y: 80),
  DanceIkTargetKey(10, x: 8, y: 90),
  DanceIkTargetKey(12, x: -18, y: 101),
  DanceIkTargetKey(14, x: -42, y: 100),
  DanceIkTargetKey(16, x: -54, y: 101),
  DanceIkTargetKey(20, x: -72, y: 101),
  DanceIkTargetKey(22, x: -62, y: 100),
  DanceIkTargetKey(24, x: -78, y: 82),
  DanceIkTargetKey(26, x: -90, y: 92),
  DanceIkTargetKey(28, x: -106, y: 101),
  DanceIkTargetKey(30, x: -62, y: 100),
  DanceIkTargetKey(32, x: -54, y: 100),
];
const _pounceFootRTargetKeys = [
  DanceIkTargetKey(0, x: 54, y: 100),
  DanceIkTargetKey(2, x: 62, y: 98),
  DanceIkTargetKey(4, x: 72, y: 101),
  DanceIkTargetKey(8, x: 78, y: 82),
  DanceIkTargetKey(10, x: 90, y: 92),
  DanceIkTargetKey(12, x: 106, y: 101),
  DanceIkTargetKey(14, x: 70, y: 100),
  DanceIkTargetKey(16, x: 54, y: 100),
  DanceIkTargetKey(20, x: 72, y: 101),
  DanceIkTargetKey(22, x: 62, y: 100),
  DanceIkTargetKey(24, x: 14, y: 80),
  DanceIkTargetKey(26, x: -8, y: 90),
  DanceIkTargetKey(28, x: 18, y: 101),
  DanceIkTargetKey(30, x: 42, y: 100),
  DanceIkTargetKey(32, x: 54, y: 100),
];
// Compact paw/fist pulses close to the body. The outer paw leads with elbow
// then wrist; the opposite paw guards near the chest, so the cat flavor rides
// a dance groove instead of becoming a long straight attack pose.
const _pounceHandLTargetKeys = [
  DanceIkTargetKey(0, x: -42, y: -8),
  DanceIkTargetKey(4, x: -52, y: -24),
  DanceIkTargetKey(6, x: -50, y: -60, tension: 1),
  // Mirrored cross-body guide — see the right hand's frame-23 key.
  DanceIkTargetKey(7, x: -12, y: -86),
  DanceIkTargetKey(
    8,
    x: 38,
    y: -92,
    tension: 0.6,
  ), // swipe apex past the far ear
  DanceIkTargetKey(10, x: 44, y: -78), // releasing off the apex
  // R10: the director called the rebound "a closed flinch, not a punch-
  // out" — both hands landed at a similar, fairly tucked height/reach.
  // Opened it wider so the rebound reads as a release, not a guard.
  DanceIkTargetKey(12, x: -60, y: -30),
  DanceIkTargetKey(14, x: -34, y: -38),
  DanceIkTargetKey(16, x: -48, y: -24),
  DanceIkTargetKey(20, x: -18, y: -24),
  DanceIkTargetKey(22, x: 44, y: -54),
  // Same guide as the frame-7 key above (and the mirrored one on hand.R at
  // frame 23): without it the smooth path between 22 and 24 dips close to
  // the shoulder, the two-bone solver's near-degenerate fold zone.
  DanceIkTargetKey(23, x: -12, y: -86),
  // task #39 v2 (post panel-verify): the first attempt pushed BOTH hands
  // further out in the SAME direction, which barely changed the GAP
  // between them (a rigging probe found the rendered cross-arm span was
  // 76px in bar2 vs 79px in bar1 — essentially identical, since the
  // silhouette width is the DISTANCE between the two hands, not either
  // hand's absolute reach). Pushed the outer-lead hand (this one)
  // further out AND pulled hand.R's crossing x back toward center (see
  // its own comment below) so the two moves in opposite directions,
  // genuinely widening the cross instead of translating it sideways.
  DanceIkTargetKey(24, x: -98, y: -58, ease: Ease.easeOutBack),
  DanceIkTargetKey(26, x: -73, y: -33),
  DanceIkTargetKey(28, x: -56, y: -26),
  DanceIkTargetKey(30, x: -62, y: -20),
  DanceIkTargetKey(32, x: -42, y: -8),
];
const _pounceHandRTargetKeys = [
  DanceIkTargetKey(0, x: 42, y: -8),
  DanceIkTargetKey(4, x: 48, y: -20),
  DanceIkTargetKey(6, x: 72, y: -42),
  DanceIkTargetKey(8, x: 92, y: -54, ease: Ease.easeOutBack),
  DanceIkTargetKey(10, x: 76, y: -28),
  // R10: opened to match hand.L's wider, more released rebound (see its
  // comment) — was a tucked flinch, now a real open punch-out.
  DanceIkTargetKey(12, x: 68, y: -18),
  DanceIkTargetKey(14, x: 68, y: -20),
  DanceIkTargetKey(16, x: 48, y: -24),
  DanceIkTargetKey(20, x: 52, y: -24),
  // Mirrors hand.L frame 6's fix: reach dips to ~12% of arm length
  // approaching the guide below (same near-degenerate zone). Full tension
  // damps the tangent through this point; the small widen keeps clear of
  // the zone once damped.
  DanceIkTargetKey(22, x: 54, y: -64, tension: 1),
  // Guide the cross-body sweep OVER the chest: without this key the smooth
  // path between 22 and 24 dips within ~6 units of the shoulder, demanding
  // an impossible fold (the clipping meter flagged it).
  DanceIkTargetKey(23, x: 12, y: -86),
  // task #39 v2 (post panel-verify): pulling this hand's x TOWARD centre
  // (was -39, further from hand.L's frame-24 x than it looks, but not
  // far enough — see hand.L's comment) while keeping/raising the y
  // widens the actual cross-gap between the two hands, which is what a
  // viewer reads as "how deep is the cross," not either hand's absolute
  // reach.
  DanceIkTargetKey(
    24,
    x: -30,
    y: -95,
    tension: 0.6,
  ), // swipe apex past the far ear, deeper than bar 1
  DanceIkTargetKey(26, x: -45, y: -79, tension: 0.85), // releasing off the apex
  DanceIkTargetKey(28, x: 52, y: -34),
  DanceIkTargetKey(30, x: 34, y: -38),
  DanceIkTargetKey(32, x: 42, y: -8),
];
