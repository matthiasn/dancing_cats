part of '../cat_in_suit.dart';

// Azonto-only damping of the SHARED `_shakuGrooveCalm` track, applied just to
// bar 2's two jab windows (frames 14-20 and 22-28, one per punch pair — the
// second window shows the exact same drift pattern on re-probe). Root-caused
// via a direct world-space probe (`frame.world[CatBones.torso]`, not just
// authored key values): the jab's IK-target anchor (`torso`) drags ~27 world
// units opposite the jab's own reach direction across each window, because
// torso's world position is driven by its ROOT/PELVIS ancestors' translation
// and lever-arm rotation — a bone's OWN rotation never moves its own origin,
// only an ancestor's does, same mechanism as the clavicle/socket anti-hinge.
// Ablation (temporarily zeroing each `bodyMotion` track in turn and
// re-probing) attributed this track's root+pelvis motion as the single
// largest contributor (disabling it dropped the swing from ~27 to ~16 world
// units, vs. azonto's own `_azontoPocketKeys` contributing only ~5 when
// disabled alone) — and the composition is genuinely NONLINEAR (fully
// zeroing both sources did not monotonically maximize the resulting jab/
// chamber world-x gap at every frame; a partial 0.15 gain measured better
// or equal at 3 of the 4 jab instants). Since this list is shared with
// shaku/zanku's own grooves, damp a LOCAL copy rather than editing the
// shared source — bar 1's wheel-mime and every other move's groove keep the
// original swivel unchanged. Net result, probe-verified (world-x gap
// between the jabbing and chambered hand at frames 16/20/24/28): baseline
// ~1-1.5 world units (read as one merged blob) -> ~4.4/6.2/8.2/13.4 after
// this fix, a real but MODEST improvement — the jab's local target is
// already at its reach-limit ceiling (see `_azontoHandLTargetKeys`'s R10
// note), so there is no further room to widen the local values themselves;
// this is likely close to this lever's practical ceiling.
List<DanceBodyKey> _azontoGrooveCalm = [
  for (final k in _shakuGrooveCalm)
    if (k.frame >= 14 && k.frame <= 30)
      DanceBodyKey(
        k.frame,
        rootDx: k.rootDx == null ? null : k.rootDx! * 0.15,
        rootDy: k.rootDy,
        rootRotation: k.rootRotation == null ? null : k.rootRotation! * 0.15,
        pelvisRotation: k.pelvisRotation == null
            ? null
            : k.pelvisRotation! * 0.15,
        chestRotation: k.chestRotation,
        chestScaleX: k.chestScaleX,
        chestScaleY: k.chestScaleY,
        ease: k.ease,
      )
    else
      k,
];

// ─────────────────────────────────────────────────────────────────────────
// Azonto (Ghana, ~2011) — a bent-knee, hip-swivel groove whose signature is
// the expressive miming HAND gestures. Reuses the shaku bent-knee groove for
// the lower body; the Azonto character lives in the hip swivel (with a chest
// counter-rotation) and an alternating point-out arm mime.
// ─────────────────────────────────────────────────────────────────────────
// The signature mime: a near-FULLY-EXTENDED point-out so the sleeved arm shoots
// clear of the torso (a bent hand at the waist just reads as a parked paw, or
// worse, the tail). Arm length from the shoulder is ~89; the points sit at ~84
// so the elbow snaps nearly straight. LEFT arm points out-down-left on beats
// 1/3/5/7, retracts to the chest between; opposite phase to the right arm, so
// one arm is always thrown out — the gesture swings side to side on the beat.
// A 2-gesture phrase for variety: BAR 1 (frames 0-16) ALTERNATES single-arm
// points (L out, R out, L out, R out); BAR 2 (16-32) the arms SYNC into a
// double point-out punch on every beat. Reach pulled back to ~80 (of ~89) so
// the elbow keeps a soft bend instead of locking dead-straight at the limit.
// The point-out rides at lower-chest height (y -10), not down at the thigh
// (y 6, where it read as a dangling arm overlapping the leg): a near-straight
// arm fired OUT to the side (x +-88, ~79% of reach) so it reads as a deliberate
// horizontal "point" clear of both torso and legs. Retracts to the chest (not
// the waist) between beats.
// The OUT-point keys use Ease.easeOutBack so the arm whips PAST the apex and
// settles back onto the point (anticipation→overshoot→settle), instead of
// reaching the extension and freezing — needs the non-smooth channel below.
// Azonto is MIME: the arms act out everyday actions over the leg groove
// (the research audit's top azonto finding — straight-arm point-outs read
// as generic boy-band, not azonto). Bar 1 drives a steering wheel; bar 2
// throws alternating cross-body jabs with the idle paw chambered at the
// hip crest. Panel round 1 lessons baked in: the grips must be SEPARATED
// and counter-rotate in opposing vertical arcs or the wheel reads as one
// blob clutching the tie, and the jabs must reach FULL extension past the
// opposite shoulder line — this rig's upper arm is ~48 world units, so a
// half-reach target folds the elbow across the belly and the sleeve reads
// as a stump (two-bone flexion grows brutally below full reach).
const _azontoHandLTargetKeys = [
  // BARREL ROLL v8 (sagittal, occlusion+shadow): each fist holds a small
  // CONSTANT x on its OWN side (no lateral target motion -> elbows do not
  // swing in/out) and only travels vertically, antiphase to the other. The
  // fists stay close enough to OVERLAP (occlusion) but never jam the same
  // point (that degenerate co-location spiked the IK). Depth is sold by the
  // z-order swap + a shadow on the occluded fist — NO size change.
  DanceIkTargetKey(0, x: -6, y: -42),
  DanceIkTargetKey(2, x: -6, y: -28),
  DanceIkTargetKey(4, x: -6, y: -42),
  DanceIkTargetKey(6, x: -6, y: -56),
  DanceIkTargetKey(8, x: -6, y: -42),
  DanceIkTargetKey(10, x: -6, y: -28),
  DanceIkTargetKey(12, x: -6, y: -42),
  DanceIkTargetKey(14, x: -6, y: -56),
  DanceIkTargetKey(16, x: -6, y: -42),
  DanceIkTargetKey(18, x: -6, y: -28),
  DanceIkTargetKey(20, x: -6, y: -42),
  DanceIkTargetKey(22, x: -6, y: -56),
  DanceIkTargetKey(24, x: -6, y: -42),
  DanceIkTargetKey(26, x: -6, y: -28),
  DanceIkTargetKey(28, x: -6, y: -42),
  DanceIkTargetKey(30, x: -6, y: -56),
  DanceIkTargetKey(32, x: -6, y: -42),
];
const _azontoHandRTargetKeys = [
  DanceIkTargetKey(0, x: 6, y: -42),
  DanceIkTargetKey(2, x: 6, y: -56),
  DanceIkTargetKey(4, x: 6, y: -42),
  DanceIkTargetKey(6, x: 6, y: -28),
  DanceIkTargetKey(8, x: 6, y: -42),
  DanceIkTargetKey(10, x: 6, y: -56),
  DanceIkTargetKey(12, x: 6, y: -42),
  DanceIkTargetKey(14, x: 6, y: -28),
  DanceIkTargetKey(16, x: 6, y: -42),
  DanceIkTargetKey(18, x: 6, y: -56),
  DanceIkTargetKey(20, x: 6, y: -42),
  DanceIkTargetKey(22, x: 6, y: -28),
  DanceIkTargetKey(24, x: 6, y: -42),
  DanceIkTargetKey(26, x: 6, y: -56),
  DanceIkTargetKey(28, x: 6, y: -42),
  DanceIkTargetKey(30, x: 6, y: -28),
  DanceIkTargetKey(32, x: 6, y: -42),
];
// R10: every rater independently called the re-positioned wheel-mime and
// jab "legible but frozen holds" — right reach zone, no gesture motion of
// their own. The rigging rater measured the SOLVED arm rotation and found
// real but small swings (10-15deg) that read as static at this compact,
// hip-hugging reach — the same "small delta near the body reads as no
// motion" lesson from the reach-zone investigations, just one layer up.
// Crucially, azonto never had a hand ROTATION channel at all (unlike
// shaku/sekem/zanku's hands, which all key CatBones.handL/R directly) —
// only the IK target's position ever moved, so the paw itself never
// twists. Added an explicit paw-twist channel so the wheel visibly
// "grips and turns" (both hands share the same rotation, since they're
// gripping one shared rim — L and R are exact opposites at every frame
// because the position keys already put them on opposite sides of the
// rim: whichever hand is wide, its twist is positive) and the jab gets a
// real punch-snap (positive rotation on the strike, relaxed negative on
// the chamber) instead of a static crossed hold. Magnitude matched to
// zanku's hand-rotation channel (its punch/pump already reads clearly).
// Head attitude — the ornament-port vocabulary in azonto's MIME idiom:
// in the wheel bars the skull leans gently with each grip turn and
// settles with a ~40% echo; behind each JAB it gathers, SNAPS with the
// hit, and carries the echo through the hold — the head sells the mime
// instead of riding level over it. Azonto previously had no authored
// head keys.
const _azontoHeadKeys = [
  DanceJointKey(0, rotation: 0.05), // rides the wide grip
  DanceJointKey(3, rotation: 0.02), // echo settle
  DanceJointKey(4, rotation: -0.05), // answers the narrow grip
  DanceJointKey(7, rotation: -0.02),
  DanceJointKey(8, rotation: 0.05),
  DanceJointKey(11, rotation: 0.02),
  DanceJointKey(12, rotation: -0.05),
  DanceJointKey(15, rotation: -0.06), // gathers behind the jab
  DanceJointKey(16, rotation: 0.1), // SNAPS with the jab
  DanceJointKey(18, rotation: 0.04), // echo through the hold
  DanceJointKey(20, rotation: -0.03), // relaxes through the chamber
  DanceJointKey(23, rotation: -0.06), // loads again
  DanceJointKey(24, rotation: 0.1), // second JAB
  DanceJointKey(26, rotation: 0.04), // echo
  DanceJointKey(28, rotation: -0.03),
  DanceJointKey(30),
  DanceJointKey(32, rotation: 0.05), // == frame 0
];

const _azontoHandLKeys = [
  // No paw scale or rotation: at this camera distance the near/far hands would
  // not visibly change size, and a rotating round mitt only reads as a fake
  // swell. Depth is sold purely by the z-order occlusion in the descriptor.
  DanceJointKey(0),
  DanceJointKey(2),
  DanceJointKey(4),
  DanceJointKey(6),
  DanceJointKey(8),
  DanceJointKey(10),
  DanceJointKey(12),
  DanceJointKey(14),
  DanceJointKey(16),
  DanceJointKey(18),
  DanceJointKey(20),
  DanceJointKey(22),
  DanceJointKey(24),
  DanceJointKey(26),
  DanceJointKey(28),
  DanceJointKey(30),
  DanceJointKey(32),
];
const _azontoHandRKeys = [
  DanceJointKey(0),
  DanceJointKey(2),
  DanceJointKey(4),
  DanceJointKey(6),
  DanceJointKey(8),
  DanceJointKey(10),
  DanceJointKey(12),
  DanceJointKey(14),
  DanceJointKey(16),
  DanceJointKey(18),
  DanceJointKey(20),
  DanceJointKey(22),
  DanceJointKey(24),
  DanceJointKey(26),
  DanceJointKey(28),
  DanceJointKey(30),
  DanceJointKey(32),
];
// R follow-up (panel post-PR#54, task #45 part 2): the panel wanted the
// punch to read as thrown "from the shoulder," not just a wrist relocating —
// azonto never had a clavicle rotation channel at all (unlike shaku/sekem/
// zanku, which all drive a shoulder roll timed to their own accents), so the
// jab had no shoulder-girdle motion behind it. Added one: the JABBING side's
// clavicle rolls forward through the strike and relaxes back on the chamber
// beat, mirrored for the opposite side. Magnitude matched to zanku's own
// clavicle-roll channel (`_zankuClavicleRKeys`/`LKeys`) — that one already
// reads clearly, per panel feedback, so this channel should read at the same
// magnitude without needing a bigger number.
// Bar 1 (the wheel-mime) is left neutral — not in scope for this pass.
//
// CAVEAT, probe-verified post-merge: the channel genuinely solves (probed
// `frame.world[CatBones.clavicleL/R]`, `atan2(b,a)`) — a real ~13deg swing
// at frame 16, comparable to zanku's own working channel — but a direct
// same-frame before/after render crop is pixel-near-identical; the
// silhouette is dominated by the tightly crossed arms, and a shoulder roll
// this size doesn't read against that. This is NOT the "solved rotation
// doesn't render" mesh bug from PR #51 (the data->render path itself is
// fine, confirmed by probe) — it's that a subtle secondary motion can't
// compete with the crossed-arms silhouette itself. Real fix is the elbow-
// abduction/pole-vector work (task #46), not a bigger shoulder-roll number.
const _azontoClavicleLKeys = [
  // r10 (all four r9 lenses: "shoulder crowns L/R nearly phase-locked for
  // most of the loop — minimal counterpoint for an arm-led routine"): bar 1
  // was authored neutral, so the wheel turned with a dead girdle. The
  // shoulders now trade the lead beat-by-beat through the wheel — L rolls
  // forward into the turn while R eases back, then they swap — the same
  // contrary-motion grammar the bar-2 jab/chamber pairs already use.
  DanceJointKey(0),
  DanceJointKey(2, rotation: 0.13), // L leads the first turn
  DanceJointKey(5, rotation: -0.06), // releases as R takes it
  DanceJointKey(8, rotation: 0.13), // L leads again
  DanceJointKey(11, rotation: -0.06),
  DanceJointKey(14), // into bar 2
  DanceJointKey(16, rotation: 0.22), // L JABS — shoulder drives forward
  DanceJointKey(17, rotation: 0.18), // hold
  DanceJointKey(19, rotation: 0.05), // recoil
  DanceJointKey(20, rotation: -0.05), // L chambers while R jabs
  DanceJointKey(23, rotation: 0.02),
  DanceJointKey(24, rotation: 0.22), // L JABS again
  DanceJointKey(25, rotation: 0.18),
  DanceJointKey(27, rotation: 0.05),
  DanceJointKey(28, rotation: -0.05), // L chambers
  DanceJointKey(32), // == frame 0
];
const _azontoClavicleRKeys = [
  // r10: the answering half of the bar-1 counterpoint above.
  DanceJointKey(0),
  DanceJointKey(2, rotation: -0.09), // R eases back while L leads
  DanceJointKey(5, rotation: 0.11), // R takes the turn
  DanceJointKey(8, rotation: -0.09),
  DanceJointKey(11, rotation: 0.11),
  DanceJointKey(14),
  DanceJointKey(16, rotation: -0.05), // R chambers while L jabs
  DanceJointKey(19, rotation: 0.02),
  DanceJointKey(20, rotation: 0.22), // R JABS — shoulder drives forward
  DanceJointKey(21, rotation: 0.18), // hold
  DanceJointKey(23, rotation: 0.05), // recoil
  DanceJointKey(24, rotation: -0.05), // R chambers
  DanceJointKey(27, rotation: 0.02),
  DanceJointKey(28, rotation: 0.22), // R JABS again
  DanceJointKey(29, rotation: 0.18),
  DanceJointKey(31, rotation: 0.05),
  DanceJointKey(32), // == frame 0
];
const _azontoFootLTargetKeys = [
  DanceIkTargetKey(0, x: -56, y: 103),
  DanceIkTargetKey(2, x: -56, y: 103), // planted through left support
  DanceIkTargetKey(4, x: -56, y: 103),
  // DOUBLE-TIME LEGS (owner-approved on shaku): each free window is a
  // touch-lift-touch step at ~13-unit clearance — azonto's step-touch
  // idiom at per-beat rate, under the untouched mime/jab upper body.
  DanceIkTargetKey(5, x: -52, y: 83), // high pickup
  DanceIkTargetKey(6, x: -46, y: 101), // TOUCH
  DanceIkTargetKey(7, x: -50, y: 85), // lift
  DanceIkTargetKey(8, x: -48, y: 102), // steps onto the new support
  DanceIkTargetKey(10, x: -48, y: 102), // planted through left support
  DanceIkTargetKey(12, x: -48, y: 102),
  DanceIkTargetKey(13, x: -53, y: 83), // high pickup
  DanceIkTargetKey(14, x: -62, y: 101), // TOUCH out
  DanceIkTargetKey(15, x: -55, y: 85), // lift
  DanceIkTargetKey(16, x: -58, y: 103),
  DanceIkTargetKey(18, x: -58, y: 103), // planted through left support
  DanceIkTargetKey(20, x: -58, y: 103),
  DanceIkTargetKey(21, x: -54, y: 83), // high pickup
  DanceIkTargetKey(22, x: -50, y: 101), // TOUCH
  DanceIkTargetKey(23, x: -58, y: 85), // lift
  DanceIkTargetKey(24, x: -62, y: 103),
  DanceIkTargetKey(26, x: -62, y: 103), // planted through left support
  DanceIkTargetKey(28, x: -62, y: 103),
  DanceIkTargetKey(29, x: -56, y: 83), // high pickup
  DanceIkTargetKey(30, x: -50, y: 101), // TOUCH
  DanceIkTargetKey(31, x: -54, y: 85), // lift home
  DanceIkTargetKey(32, x: -56, y: 103),
];
const _azontoFootRTargetKeys = [
  DanceIkTargetKey(0, x: 54, y: 102),
  DanceIkTargetKey(1, x: 52, y: 83), // high pickup (double-time legs)
  DanceIkTargetKey(2, x: 46, y: 101), // TOUCH
  DanceIkTargetKey(3, x: 52, y: 85), // lift
  DanceIkTargetKey(4, x: 54, y: 103),
  DanceIkTargetKey(6, x: 54, y: 103), // planted through right support
  DanceIkTargetKey(8, x: 54, y: 103),
  DanceIkTargetKey(9, x: 51, y: 83), // high pickup
  DanceIkTargetKey(10, x: 44, y: 101), // TOUCH
  DanceIkTargetKey(11, x: 50, y: 85), // lift
  DanceIkTargetKey(12, x: 48, y: 102),
  DanceIkTargetKey(14, x: 48, y: 102), // planted through right support
  DanceIkTargetKey(16, x: 48, y: 102),
  DanceIkTargetKey(17, x: 54, y: 83), // high pickup
  DanceIkTargetKey(18, x: 64, y: 101), // TOUCH out
  DanceIkTargetKey(19, x: 57, y: 85), // lift
  DanceIkTargetKey(20, x: 60, y: 103),
  DanceIkTargetKey(22, x: 60, y: 103), // planted through right support
  DanceIkTargetKey(24, x: 60, y: 103),
  DanceIkTargetKey(25, x: 56, y: 83), // high pickup
  DanceIkTargetKey(26, x: 48, y: 101), // TOUCH
  DanceIkTargetKey(27, x: 54, y: 85), // lift
  DanceIkTargetKey(28, x: 52, y: 102),
  DanceIkTargetKey(30, x: 52, y: 102), // planted through right support
  DanceIkTargetKey(32, x: 54, y: 102),
];
// Legwork-panel round: the pocket measured range 30 — half of shaku's —
// "the trunk sits too upright for the busy-feet-under-laid-back-trunk
// layering to register". The keys' own step-synced rootDy bounce is
// amplified 1.8x around its mean (an added sine layer measurably
// CANCELLED against this pattern instead of deepening it — the bounce
// is authored to the step timing, so the depth belongs in the keys).
const _azontoPocketKeys = [
  // Bar 1 (frames 0-16, the wheel mime): the rootDx/pelvis/chest fields
  // used to repeat the SAME value at each pair of keys (0&2, 4&6, ...)
  // then jump to the opposite extreme in the very next 2-frame gap — a
  // probe of rendered shoulder-socket world position showed this
  // concentrated the entire weight transfer into one 2-frame window, a
  // ~40-unit one-frame position jump (round-4 rigging critique: "sockets
  // swing 46 units in 3 frames"). Fixed two ways: the intermediate keys
  // now sit at the true midpoint between their neighboring peaks (so the
  // swing paces evenly across the whole beat instead of snapping in half
  // a beat), and the peak rootDx/pelvis/chest values are pulled in ~28%
  // (a 1-beat left-right transfer is still an inherently fast swing —
  // smoothing the curve shape alone left the peak-to-peak rate too high).
  // rootDy keeps its own already-smooth bounce (a real step-touch
  // pattern, not a hold-then-snap), so it is untouched.
  DanceBodyKey(
    0,
    rootDx: -7.776,
    rootDy: 24.4,
    pelvisRotation: -0.1008,
    chestRotation: 0.0864,
    chestScaleY: 0.92,
    chestScaleX: 1.06,
  ),
  DanceBodyKey(
    2,
    rootDx: 0,
    rootDy: 0.5,
    pelvisRotation: 0.0108,
    chestRotation: -0.0108,
    chestScaleY: 0.89,
    chestScaleX: 1.08,
  ),
  DanceBodyKey(
    4,
    rootDx: 7.776,
    rootDy: 43.6,
    pelvisRotation: 0.1224,
    chestRotation: -0.108,
    chestScaleY: 0.86,
    chestScaleX: 1.1,
  ),
  DanceBodyKey(
    6,
    rootDx: -0.432,
    rootDy: 5.3,
    pelvisRotation: 0.0072,
    chestRotation: -0.0072,
    chestScaleY: 0.88,
    chestScaleX: 1.085,
  ),
  DanceBodyKey(
    8,
    rootDx: -8.64,
    rootDy: 29.2,
    pelvisRotation: -0.108,
    chestRotation: 0.0936,
    chestScaleY: 0.9,
    chestScaleX: 1.07,
  ),
  DanceBodyKey(
    10,
    rootDx: 0,
    rootDy: 0.5,
    pelvisRotation: 0.0072,
    chestRotation: -0.0072,
    chestScaleY: 0.88,
    chestScaleX: 1.085,
  ),
  DanceBodyKey(
    12,
    rootDx: 8.64,
    rootDy: 43.6,
    pelvisRotation: 0.1224,
    chestRotation: -0.108,
    chestScaleY: 0.86,
    chestScaleX: 1.1,
  ),
  DanceBodyKey(
    14,
    // r11 panel (mocap, the one lens holding azonto at 8.9): "bar 2's
    // exchange reads plateau-then-slide rather than a crisp crest — the
    // energy is smeared across the bar." rootDx 3.195 -> -2: the crest
    // now peaks at f12 and FALLS through f14 into bar 3's trough instead
    // of shelving at +17..20 for the bar's whole second half. (-2 only
    // moved the world value 20 -> 17 — the shelf is mostly support-anchor
    // pull — so the key digs further; -6 lands the fall at ~14.)
    rootDx: -6,
    rootDy: 5.3,
    pelvisRotation: 0.1412,
    chestRotation: -0.124,
    chestScaleY: 0.905,
    chestScaleX: 1.07,
  ),
  // R follow-up (azonto jab root-motion drift): pelvisRotation/rootDx at
  // frames 16/18/20 damped ~60% — see `_azontoGrooveCalm`'s doc comment for
  // the full root-cause probe. This track's own contribution to the torso-
  // anchor drift was smaller than the shared groove's (~5 of ~27 world
  // units, measured by ablation), but every bit matters since the jab's
  // local target is already at its reach-limit ceiling with no room left to
  // widen further. chestRotation/chestScaleX/Y are untouched — a bone's own
  // rotation doesn't move its own world origin, so they don't affect the
  // anchor drift and stay at their full authored value for the chest
  // counter-rotation look.
  DanceBodyKey(
    16,
    rootDx: -0.9,
    rootDy: 29.2,
    pelvisRotation: 0.064,
    chestRotation: -0.14,
    chestScaleY: 0.95,
    // R follow-up (task #46, transitions r4 panel): narrowed from 1.04 at
    // exactly this jab beat — see the render-pipeline probe on
    // `_azontoHandLTargetKeys` above. Reach is confirmed maxed out and
    // bendDirection is confirmed inert at this reach, so the only
    // remaining, non-discontinuous lever is shrinking the jacket
    // silhouette itself right when the mitt needs to clear it, instead of
    // pushing the mitt further out. This is a smooth per-frame scale
    // value (not an IK target), so it can't introduce the kind of
    // discrete pop a bendDirection flip did.
    chestScaleX: 0.88,
  ),
  DanceBodyKey(
    18,
    rootDx: -0.9,
    rootDy: 0.5,
    pelvisRotation: 0.024,
    chestRotation: -0.05,
    chestScaleY: 1.02,
    chestScaleX: 0.99,
  ),
  DanceBodyKey(
    20,
    rootDx: 0.9,
    rootDy: 43.6,
    pelvisRotation: -0.072,
    chestRotation: 0.16,
    chestScaleY: 0.95,
    // R follow-up (task #46, transitions r4 panel): narrowed from 1.04 at
    // exactly this jab beat — see the render-pipeline probe on
    // `_azontoHandLTargetKeys` above. Reach is confirmed maxed out and
    // bendDirection is confirmed inert at this reach, so the only
    // remaining, non-discontinuous lever is shrinking the jacket
    // silhouette itself right when the mitt needs to clear it, instead of
    // pushing the mitt further out. This is a smooth per-frame scale
    // value (not an IK target), so it can't introduce the kind of
    // discrete pop a bendDirection flip did.
    chestScaleX: 0.88,
  ),
  DanceBodyKey(
    22,
    rootDx: 2.25,
    rootDy: 5.3,
    pelvisRotation: -0.07,
    chestRotation: 0.06,
    chestScaleY: 1.02,
    chestScaleX: 0.99,
  ),
  // Same jab-window anchor-drift damping as frames 16/18/20 above.
  DanceBodyKey(
    24,
    rootDx: -0.99,
    rootDy: 34,
    pelvisRotation: 0.072,
    chestRotation: -0.16,
    chestScaleY: 0.95,
    // R follow-up (task #46, transitions r4 panel): narrowed from 1.04 at
    // exactly this jab beat — see the render-pipeline probe on
    // `_azontoHandLTargetKeys` above. Reach is confirmed maxed out and
    // bendDirection is confirmed inert at this reach, so the only
    // remaining, non-discontinuous lever is shrinking the jacket
    // silhouette itself right when the mitt needs to clear it, instead of
    // pushing the mitt further out. This is a smooth per-frame scale
    // value (not an IK target), so it can't introduce the kind of
    // discrete pop a bendDirection flip did.
    chestScaleX: 0.88,
  ),
  DanceBodyKey(
    26,
    rootDx: -2.48,
    rootDy: 0.5,
    pelvisRotation: 0.06,
    chestRotation: -0.05,
    chestScaleY: 1.02,
    chestScaleX: 0.99,
  ),
  DanceBodyKey(
    28,
    rootDx: 0.99,
    rootDy: 48.4,
    pelvisRotation: -0.076,
    chestRotation: 0.17,
    chestScaleY: 0.95,
    // R follow-up (task #46, transitions r4 panel): narrowed from 1.04 at
    // exactly this jab beat — see the render-pipeline probe on
    // `_azontoHandLTargetKeys` above. Reach is confirmed maxed out and
    // bendDirection is confirmed inert at this reach, so the only
    // remaining, non-discontinuous lever is shrinking the jacket
    // silhouette itself right when the mitt needs to clear it, instead of
    // pushing the mitt further out. This is a smooth per-frame scale
    // value (not an IK target), so it can't introduce the kind of
    // discrete pop a bendDirection flip did.
    chestScaleX: 0.88,
  ),
  DanceBodyKey(
    30,
    rootDx: 2.02,
    rootDy: 5.3,
    pelvisRotation: -0.07,
    chestRotation: 0.06,
    chestScaleY: 1.02,
    chestScaleX: 0.99,
  ),
  DanceBodyKey(
    32,
    rootDx: -2.02,
    rootDy: 24.4,
    pelvisRotation: -0.14,
    chestRotation: 0.12,
    chestScaleY: 0.92,
    chestScaleX: 1.06,
  ),
];
