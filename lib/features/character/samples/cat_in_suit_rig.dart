part of 'cat_in_suit.dart';

// Palette (ARGB). Kept local to the sample; real characters carry their own
// colours in the rig art (plan decision D6 — no design-system colour tokens).

/// The ONE suit cloth. Every navy surface of the garment derives from [base]
/// by a uniform value scale — same hue, different plane value — so the jacket,
/// sleeves, trousers, and lapels always read as a single fabric. Before this,
/// each surface had its own hand-picked constant and the hues drifted apart,
/// which showed up as a "different material" patch where the near sleeve's
/// deltoid overlaps the jacket yoke.
class SuitFabric {
  const SuitFabric(this.base);

  final int base;

  /// The fabric at [value] brightness (1 = the jacket reference plane). RGB is
  /// scaled uniformly and hue is untouched: brighter planes face the key or
  /// sit downstage, darker planes fall upstage.
  int plane(double value) {
    int chan(int shift) =>
        (((base >> shift) & 0xFF) * value).round().clamp(0, 255);
    return 0xFF000000 | (chan(16) << 16) | (chan(8) << 8) | chan(0);
  }
}

const SuitFabric kSuitFabric = SuitFabric(0xFF2E3A59);

/// Shared-lighting group ids, one per GARMENT: each garment is lit by ONE
/// cel ramp spanning its union bounds (see LimbRibbonSpec.shadeGroup), so a
/// junction inside a garment (a sleeve on the jacket yoke, a thigh out of the
/// pelvis) carries the same tone on both sides. The jacket and the trousers
/// are separate pieces of clothing and keep separate ramps; the shirt, tie,
/// and cuffs are small flat-shaded pieces and need no group.
// NOTE: both garments currently share one ramp REGION: the key light falls
// continuously down the figure, so the jacket hem's shade side must not butt
// against a lit trouser top (that opposing-ramp flip read as a hard block
// break at the hem). Garment separation reads through the fill values and
// the hem line; the ids stay separate so fabrics can split again if needed.
const String kJacketShadeGroup = 'suit-cloth';
const String kTrouserShadeGroup = 'suit-cloth';
final int _suit = kSuitFabric.plane(1); // navy jacket (torso)
// Sleeves are the SAME cloth as the jacket — no near/far value step. A
// crossing arm separates from the chest by its drawn INK LINE (the ribbons'
// inkOverFill), like hand-drawn animation, so no pose can expose a lighter
// "patch of different fabric" where the sleeve root sits on the yoke.
final int _sleeve = kSuitFabric.plane(1); // far sleeve
final int _sleeveNear = kSuitFabric.plane(1); // near sleeve
const int _button = 0xFFAE955C; // muted brass placket button — a dark horn
// button vanished on the navy front; a metal tone reads as a button line.
final int _trouser = kSuitFabric.plane(0.83); // darker navy
// Both trouser legs are the SAME cloth — like the sleeves, the far leg no
// longer fakes depth with a darker value (that read as a different fabric);
// the overlap-clipped ink line separates the legs where they cross.
final int _trouserRear = kSuitFabric.plane(0.83);
const int _fur = 0xFFE8A55A; // orange tabby
const int _furDark = 0xFFD08A3C; // tail tip / shading
const int _shirt = 0xFFF3EFE6; // collar
const int _tie = 0xFF7A2233; // maroon
const int _shoe = 0xFFF6F3EC; // 90s basketball-boot WHITE leather upper
// — pops against the navy trousers and the dark deck, echoes the shirt
// cuffs/collar, and reads instantly as the era.
const int _shoeToe = 0xFF7E2536; // toe box — the 90s colour-blocked
// accent (maroon, rhyming with the tie): a generic high-top panel scheme,
// deliberately WITHOUT any brand marks.
const int _shoeSole = 0xFFCFC9BB; // sneaker midsole — the full-length rubber
// band along the bottom, a half-step grey under the white upper so the two
// planes split by ink AND value, like a real AF1 wall.
const int _outline = 0xFF1B1B2A;
const int _innerEar = 0xFFE7A39B; // soft pink ear
const int _muzzle = 0xFFF3DCB8; // lighter snout patch
const int _nose = 0xFFC8696B; // pink nose
const int _whisker = 0xFF8A765C; // muted whisker

/// Limb thickness as a pure function of a dancer's PLANE scale, relative to
/// the front (lead) reference plane at 1.0.
///
/// Perceptual, not projective: uniform scaling already keeps proportions, but
/// a HALF-scale upstage dancer whose limbs keep the front dancer's relative
/// thickness fuses into a balloon blob — the negative space between arm and
/// torso is what makes a small silhouette read, and it vanishes first. So
/// thickness follows the plane with a gentle quarter-power curve: the front
/// dancer carries full anatomical mass, a 0.49-plane backup thins to ~0.84 of
/// it. Replaces the old hand-tuned per-cast width constants entirely.
double limbThicknessForPlaneScale(double relativePlaneScale) {
  // Gentle: the renderer now scales limb geometry with each member's plane
  // (see CharacterRenderer.paint memberTransform), so proportions are already
  // correct at any scale — this curve only trims small upstage silhouettes
  // enough to keep their limb/torso negative space readable.
  final curved = math.pow(relativePlaneScale.clamp(0.1, 4.0), 0.12).toDouble();
  return curved.clamp(0.85, 1.1);
}

/// Fur/face colours for a cat-in-suit rig variant.
///
/// The suit stays fixed so paired cats still read as the same act; the palette
/// only swaps the character fur and face markings.
class CatInSuitPalette {
  const CatInSuitPalette({
    required this.fur,
    required this.furDark,
    required this.innerEar,
    required this.muzzle,
    required this.nose,
    required this.whisker,
    required this.brow,
  });

  final int fur;
  final int furDark;
  final int innerEar;
  final int muzzle;
  final int nose;
  final int whisker;
  final int brow;

  static const orangeTabby = CatInSuitPalette(
    fur: _fur,
    furDark: _furDark,
    innerEar: _innerEar,
    muzzle: _muzzle,
    nose: _nose,
    whisker: _whisker,
    brow: _outline,
  );

  static const silverTabby = CatInSuitPalette(
    fur: 0xFFB8BBC8,
    furDark: 0xFF80869B,
    innerEar: 0xFFD8A7B4,
    muzzle: 0xFFEDE8DC,
    nose: 0xFFB56B7C,
    whisker: 0xFF6F7180,
    brow: _outline,
  );

  static const darkBrown = CatInSuitPalette(
    fur: 0xFF302820,
    furDark: 0xFF17110D,
    innerEar: 0xFF8E6A61,
    muzzle: 0xFFC9A77F,
    nose: 0xFF8F555C,
    whisker: 0xFFE7D7C0,
    brow: 0xFFF1E2C9,
  );
}

/// Stable bone ids, also the keys clips animate.
class CatBones {
  static const hips = 'hips';
  static const torso = 'torso';
  static const chest = 'chest';
  static const clavicleL = 'clavicle.L';
  static const clavicleR = 'clavicle.R';
  static const shirtV = 'shirt_v';
  static const collarL = 'collar.L';
  static const collarR = 'collar.R';
  static const button0 = 'button_0';
  static const button1 = 'button_1';
  static const tie = 'tie';
  static const tieLower = 'tie_lower';
  static const neck = 'neck';
  static const head = 'head';
  static const earL = 'ear.L';
  static const earR = 'ear.R';
  static const earInnerL = 'ear_inner.L';
  static const earTipL = 'ear_tip.L';
  static const earInnerR = 'ear_inner.R';
  static const earTipR = 'ear_tip.R';
  static const armUpperL = 'arm_upper.L';
  static const shoulderSocketL = 'shoulder_socket.L';
  static const armBicepL = 'arm_bicep.L';
  static const armLowerL = 'arm_lower.L';
  static const armForearmL = 'arm_forearm.L';
  static const armElbowCreaseL = 'arm_elbow_crease.L';
  static const handL = 'hand.L';
  static const wristCuffL = 'wrist_cuff.L';
  static const thumbL = 'thumb.L';
  static const pawToeL1 = 'paw_toe1.L';
  static const pawToeL2 = 'paw_toe2.L';
  static const armUpperR = 'arm_upper.R';
  static const shoulderSocketR = 'shoulder_socket.R';
  static const armBicepR = 'arm_bicep.R';
  static const armLowerR = 'arm_lower.R';
  static const armForearmR = 'arm_forearm.R';
  static const armElbowCreaseR = 'arm_elbow_crease.R';
  static const handR = 'hand.R';
  static const wristCuffR = 'wrist_cuff.R';
  static const thumbR = 'thumb.R';
  static const pawToeR1 = 'paw_toe1.R';
  static const pawToeR2 = 'paw_toe2.R';
  static const hipBlendL = 'hip_blend.L';
  static const legUpperL = 'leg_upper.L';
  static const legQuadL = 'leg_quad.L';
  static const legLowerL = 'leg_lower.L';
  static const legCalfL = 'leg_calf.L';
  static const footL = 'foot.L';
  static const shoeHighlightL = 'shoe_highlight.L';
  static const shoeToeL = 'shoe_toe.L';
  static const shoeCounterL = 'shoe_counter.L';
  static const shoeTabL = 'shoe_tab.L';
  static const toeFlexL = 'toe_flex.L';
  static const shoeSoleFrontL = 'shoe_sole_front.L';
  static const hipBlendR = 'hip_blend.R';
  static const legUpperR = 'leg_upper.R';
  static const legQuadR = 'leg_quad.R';
  static const legLowerR = 'leg_lower.R';
  static const legCalfR = 'leg_calf.R';
  static const footR = 'foot.R';
  static const shoeHighlightR = 'shoe_highlight.R';
  static const shoeToeR = 'shoe_toe.R';
  static const shoeCounterR = 'shoe_counter.R';
  static const shoeTabR = 'shoe_tab.R';
  static const toeFlexR = 'toe_flex.R';
  static const shoeSoleFrontR = 'shoe_sole_front.R';
  static const tail0 = 'tail_0';
  static const tail1 = 'tail_1';
  static const tail2 = 'tail_2';
  static const tail3 = 'tail_3';
  static const tail4 = 'tail_4';
  static const tail5 = 'tail_5';
  static const tail6 = 'tail_6';
}

/// A tapered limb segment: [w] wide at the joint (pivot) end, [wTip] at the far
/// end, so limbs read as wedged arms/legs with defined wrists/ankles instead of
/// constant-width sausages.
BoneDrawable _tapered(
  double w,
  double wTip,
  double h,
  int color, {
  double dy = 0,
  double outlineWidth = 2,
  bool formRound = true,
  bool celShade = true,
}) => BoneDrawable(
  kind: BoneShapeKind.taperedCapsule,
  width: w,
  widthTip: wTip,
  height: h,
  dy: dy,
  color: color,
  outlineColor: _outline,
  outlineWidth: outlineWidth,
  formRound: formRound,
  celShade: celShade,
);

/// A tail link — a short tapered segment in the drag chain. Kept as a helper so
/// the whole tail (length, taper, lift) is trivial to retune.
Bone _tailSeg(
  String id,
  String parent, {
  required double pivotY,
  required int z,
  required double restRotation,
  required double w,
  required double wTip,
  required double h,
  required double dy,
  double pivotX = 0,
  int color = _fur,
}) => Bone(
  id: id,
  parent: parent,
  pivotX: pivotX,
  pivotY: pivotY,
  z: z,
  restRotation: restRotation,
  drawable: BoneDrawable(
    kind: BoneShapeKind.taperedCapsule,
    width: w,
    widthTip: wTip,
    height: h,
    dy: dy,
    color: color,
    outlineColor: _outline,
    outlineWidth: 2,
  ),
);

/// Builds the cat-in-a-suit [RigSpec].
RigSpec buildCatInSuitRig({
  CatInSuitPalette palette = CatInSuitPalette.orangeTabby,
  double legWidthScale = 1,
  double armWidthScale = 1,
}) {
  final bones = <Bone>[
    // Tail controls: the visible tail is drawn as one soft ribbon below. These
    // short bones only provide the bending spine, so the tail can attach behind
    // the rump and sweep as one flexible shape instead of a stack of hinges.
    _tailSeg(
      CatBones.tail0,
      CatBones.hips,
      pivotX: 28,
      pivotY: 2,
      z: -7,
      restRotation: -1.58, // high rear-rump attachment, not a waist/hand spike

      w: 8,
      wTip: 7,
      h: 21,
      dy: 6.5,
      color: palette.fur,
    ),
    _tailSeg(
      CatBones.tail1,
      CatBones.tail0,
      pivotY: 12,
      z: -6,
      restRotation: -0.18,
      w: 10,
      wTip: 9,
      h: 20,
      dy: 6,
      color: palette.fur,
    ),
    _tailSeg(
      CatBones.tail2,
      CatBones.tail1,
      pivotY: 11,
      z: -5,
      restRotation: -0.16,
      w: 9,
      wTip: 8,
      h: 19,
      dy: 5.5,
      color: palette.fur,
    ),
    _tailSeg(
      CatBones.tail3,
      CatBones.tail2,
      pivotY: 10,
      z: -4,
      restRotation: -0.14,
      w: 8,
      wTip: 6,
      h: 18,
      dy: 5,
      color: palette.fur,
    ),
    _tailSeg(
      CatBones.tail4,
      CatBones.tail3,
      pivotY: 9,
      z: -3,
      restRotation: -0.12,
      w: 6,
      wTip: 5,
      h: 17,
      dy: 4.5,
      color: palette.fur,
    ),
    _tailSeg(
      CatBones.tail5,
      CatBones.tail4,
      pivotY: 8,
      z: -2,
      restRotation: -0.1,
      w: 5,
      wTip: 3,
      h: 16,
      dy: 4,
      color: palette.furDark,
    ),
    _tailSeg(
      CatBones.tail6,
      CatBones.tail5,
      pivotY: 7,
      z: -1,
      restRotation: -0.06,
      w: 4,
      wTip: 2,
      h: 14,
      dy: 3,
      color: palette.furDark,
    ),

    // Far (right) leg controls, drawn behind. Their rigid drawables are hidden
    // by the leg ribbon below; keeping the drawables on the bones makes the
    // fallback path and bbox utilities still work.
    // Pelvis-blend root for the leg ribbon: a fixed point INSIDE the hip
    // mass, so the thigh's centreline sweeps out of the pelvis with a
    // flowing tangent instead of the leg reading as a tube bolted to a
    // joint on the pelvis rim.
    const Bone(
      id: CatBones.hipBlendR,
      parent: CatBones.hips,
      pivotX: 9,
      pivotY: 2,
      z: 3,
    ),
    Bone(
      id: CatBones.legUpperR,
      parent: CatBones.hips,
      pivotX: 18,
      pivotY: 11,
      z: 3,
      drawable: _tapered(28, 22, 58, _trouserRear, dy: 24),
    ),
    const Bone(
      id: CatBones.legQuadR,
      parent: CatBones.legUpperR,
      pivotX: 2,
      pivotY: 31,
      z: 3,
    ),
    Bone(
      id: CatBones.legLowerR,
      parent: CatBones.legUpperR,
      pivotX: 0,
      pivotY: 55,
      z: 4,
      // The knee is a one-way hinge: deep flexion, never a backward bend
      // (catalogue measures [-1.70, +0.02]; the runtime clamp makes reversed
      // knees impossible rather than merely untested).
      rotationLimit: const JointRotationLimit(-2.7, 0.1),
      drawable: _tapered(24, 16, 56, _trouserRear, dy: 23),
    ),
    const Bone(
      id: CatBones.legCalfR,
      parent: CatBones.legLowerR,
      pivotX: 1.5,
      pivotY: 27,
      z: 4,
    ),
    const Bone(
      id: CatBones.footR,
      parent: CatBones.legLowerR,
      pivotX: 0,
      pivotY: 48,
      z: 5,
      rotationLimit: JointRotationLimit(-1.25, 1.25),
      drawable: BoneDrawable(
        kind: BoneShapeKind.roundedRect,
        // The vamp. Toe points -x (local), which — through the locomotion
        // mirror — makes the shoe LEAD the direction of travel instead of
        // trailing it. The sole plane stays at local y=10: the contact
        // solvers key off this drawable's bottom. FLAT white, no interior
        // ink: the boot is ONE union silhouette, and cel gradients made the
        // white leather look dingy.
        width: 33,
        height: 12,
        dx: -7,
        dy: 4,
        cornerRadius: 5,
        color: _shoe,
        outlineColor: _outline,
        outlineWidth: 2,
        celShade: false,
      ),
    ),
    // High-top collar: the 90s basketball-boot ankle wrap — rises well
    // above the vamp and hugs the ankle so the trouser breaks ON the boot.
    // Accent-blocked (with the toe box) against the white body; still NO
    // interior ink — colour panels separate themselves.
    const Bone(
      id: CatBones.shoeCounterR,
      parent: CatBones.footR,
      pivotX: 0,
      pivotY: 0,
      z: 6,
      drawable: BoneDrawable(
        kind: BoneShapeKind.roundedRect,
        width: 15,
        height: 19,
        dx: 2.5,
        dy: -1.5,
        cornerRadius: 6,
        color: _shoeToe,
        outlineColor: _outline,
        outlineWidth: 2,
        celShade: false,
      ),
    ),
    // Ball-of-foot flex joint: the sneaker BENDS here. The sole-flex pass
    // counter-rotates this bone when the heel lifts while the ball still
    // bears on the floor, so the sole curves through toe-offs and heel-toe
    // knocks instead of tilting as a rigid plank.
    const Bone(
      id: CatBones.toeFlexR,
      parent: CatBones.footR,
      pivotX: -16,
      pivotY: 8,
      z: 6,
    ),
    // Toe box: rounds the front of the boot as part of the ONE silhouette —
    // same white, no interior circle line. Rides the flex joint.
    const Bone(
      id: CatBones.shoeToeR,
      parent: CatBones.toeFlexR,
      pivotX: 0,
      pivotY: 0,
      z: 6,
      drawable: BoneDrawable(
        kind: BoneShapeKind.ellipse,
        width: 14,
        height: 11,
        dx: -7,
        dy: -3.7,
        color: _shoeToe,
        outlineColor: _outline,
        outlineWidth: 2,
        celShade: false,
      ),
    ),
    // Lace bar: one thin diagonal stroke across the instep — the single
    // detail (besides the sole line) that says sneaker without clutter.
    const Bone(
      id: CatBones.shoeTabR,
      parent: CatBones.footR,
      pivotX: -6,
      pivotY: 1,
      z: 7,
      restRotation: -0.55,
      drawable: BoneDrawable(
        kind: BoneShapeKind.roundedRect,
        width: 2,
        height: 9,
        cornerRadius: 1,
        color: _outline,
        celShade: false,
      ),
    ),
    // Midsole: the full-length cream rubber band along the bottom — THE
    // sneaker cue. Stays a hair above the sole plane so grounding cannot
    // shift; inked so the sole reads drawn.
    const Bone(
      id: CatBones.shoeHighlightR,
      parent: CatBones.footR,
      pivotX: 0,
      pivotY: 0,
      z: 7,
      drawable: BoneDrawable(
        kind: BoneShapeKind.roundedRect,
        width: 27,
        height: 6,
        dx: -2.5,
        dy: 6.9,
        cornerRadius: 3,
        color: _shoeSole,
        outlineColor: _outline,
        outlineWidth: 2,
        celShade: false,
        inkOverFill: true,
      ),
    ),
    // Front midsole: the toe half of the sole, riding the flex joint so the
    // rubber visibly bends at the ball (overlaps the rear half at the crease
    // so the union stays closed while bending).
    const Bone(
      id: CatBones.shoeSoleFrontR,
      parent: CatBones.toeFlexR,
      pivotX: 0,
      pivotY: 0,
      z: 7,
      drawable: BoneDrawable(
        kind: BoneShapeKind.roundedRect,
        width: 15,
        height: 6,
        dx: -5.5,
        dy: -1.1,
        cornerRadius: 3,
        color: _shoeSole,
        outlineColor: _outline,
        outlineWidth: 2,
        celShade: false,
        inkOverFill: true,
      ),
    ),
    // Near (left) leg controls. The visible leg is a continuous ribbon that
    // starts inside the hip volume; the hip is drawn over the top so the leg
    // reads as part of the body, not a capsule bolted underneath.
    // Pelvis-blend root for the leg ribbon: a fixed point INSIDE the hip
    // mass, so the thigh's centreline sweeps out of the pelvis with a
    // flowing tangent instead of the leg reading as a tube bolted to a
    // joint on the pelvis rim.
    const Bone(
      id: CatBones.hipBlendL,
      parent: CatBones.hips,
      pivotX: -9,
      pivotY: 2,
      z: 6,
    ),
    Bone(
      id: CatBones.legUpperL,
      parent: CatBones.hips,
      pivotX: -18,
      pivotY: 11,
      z: 6,
      drawable: _tapered(28, 22, 58, _trouser, dy: 24),
    ),
    const Bone(
      id: CatBones.legQuadL,
      parent: CatBones.legUpperL,
      pivotX: -2,
      pivotY: 31,
      z: 6,
    ),
    Bone(
      id: CatBones.legLowerL,
      parent: CatBones.legUpperL,
      pivotX: 0,
      pivotY: 55,
      z: 7,
      // The knee is a one-way hinge: deep flexion, never a backward bend
      // (catalogue measures [-1.70, +0.02]; the runtime clamp makes reversed
      // knees impossible rather than merely untested).
      rotationLimit: const JointRotationLimit(-2.7, 0.1),
      drawable: _tapered(24, 16, 56, _trouser, dy: 23),
    ),
    const Bone(
      id: CatBones.legCalfL,
      parent: CatBones.legLowerL,
      pivotX: -1.5,
      pivotY: 27,
      z: 7,
    ),
    const Bone(
      id: CatBones.footL,
      parent: CatBones.legLowerL,
      pivotX: 0,
      pivotY: 48,
      z: 8,
      rotationLimit: JointRotationLimit(-1.25, 1.25),
      drawable: BoneDrawable(
        kind: BoneShapeKind.roundedRect,
        // The vamp. Toe points -x (local), which — through the locomotion
        // mirror — makes the shoe LEAD the direction of travel instead of
        // trailing it. The sole plane stays at local y=10: the contact
        // solvers key off this drawable's bottom. FLAT white, no interior
        // ink: the boot is ONE union silhouette, and cel gradients made the
        // white leather look dingy.
        width: 33,
        height: 12,
        dx: -7,
        dy: 4,
        cornerRadius: 5,
        color: _shoe,
        outlineColor: _outline,
        outlineWidth: 2,
        celShade: false,
      ),
    ),
    // High-top collar: the 90s basketball-boot ankle wrap — rises well
    // above the vamp and hugs the ankle so the trouser breaks ON the boot.
    // Accent-blocked (with the toe box) against the white body; still NO
    // interior ink — colour panels separate themselves.
    const Bone(
      id: CatBones.shoeCounterL,
      parent: CatBones.footL,
      pivotX: 0,
      pivotY: 0,
      z: 9,
      drawable: BoneDrawable(
        kind: BoneShapeKind.roundedRect,
        width: 15,
        height: 19,
        dx: 2.5,
        dy: -1.5,
        cornerRadius: 6,
        color: _shoeToe,
        outlineColor: _outline,
        outlineWidth: 2,
        celShade: false,
      ),
    ),
    // Ball-of-foot flex joint: the sneaker BENDS here. The sole-flex pass
    // counter-rotates this bone when the heel lifts while the ball still
    // bears on the floor, so the sole curves through toe-offs and heel-toe
    // knocks instead of tilting as a rigid plank.
    const Bone(
      id: CatBones.toeFlexL,
      parent: CatBones.footL,
      pivotX: -16,
      pivotY: 8,
      z: 9,
    ),
    // Toe box: rounds the front of the boot as part of the ONE silhouette —
    // same white, no interior circle line. Rides the flex joint.
    const Bone(
      id: CatBones.shoeToeL,
      parent: CatBones.toeFlexL,
      pivotX: 0,
      pivotY: 0,
      z: 9,
      drawable: BoneDrawable(
        kind: BoneShapeKind.ellipse,
        width: 14,
        height: 11,
        dx: -7,
        dy: -3.7,
        color: _shoeToe,
        outlineColor: _outline,
        outlineWidth: 2,
        celShade: false,
      ),
    ),
    // Lace bar: one thin diagonal stroke across the instep — the single
    // detail (besides the sole line) that says sneaker without clutter.
    const Bone(
      id: CatBones.shoeTabL,
      parent: CatBones.footL,
      pivotX: -6,
      pivotY: 1,
      z: 10,
      restRotation: -0.55,
      drawable: BoneDrawable(
        kind: BoneShapeKind.roundedRect,
        width: 2,
        height: 9,
        cornerRadius: 1,
        color: _outline,
        celShade: false,
      ),
    ),
    // Midsole: the full-length cream rubber band along the bottom — THE
    // sneaker cue. Stays a hair above the sole plane so grounding cannot
    // shift; inked so the sole reads drawn.
    const Bone(
      id: CatBones.shoeHighlightL,
      parent: CatBones.footL,
      pivotX: 0,
      pivotY: 0,
      z: 10,
      drawable: BoneDrawable(
        kind: BoneShapeKind.roundedRect,
        width: 27,
        height: 6,
        dx: -2.5,
        dy: 6.9,
        cornerRadius: 3,
        color: _shoeSole,
        outlineColor: _outline,
        outlineWidth: 2,
        celShade: false,
        inkOverFill: true,
      ),
    ),
    // Front midsole: the toe half of the sole, riding the flex joint so the
    // rubber visibly bends at the ball (overlaps the rear half at the crease
    // so the union stays closed while bending).
    const Bone(
      id: CatBones.shoeSoleFrontL,
      parent: CatBones.toeFlexL,
      pivotX: 0,
      pivotY: 0,
      z: 10,
      drawable: BoneDrawable(
        kind: BoneShapeKind.roundedRect,
        width: 15,
        height: 6,
        dx: -5.5,
        dy: -1.1,
        cornerRadius: 3,
        color: _shoeSole,
        outlineColor: _outline,
        outlineWidth: 2,
        celShade: false,
        inkOverFill: true,
      ),
    ),

    // Pelvis / seat (root). A single low trouser volume sits behind the jacket
    // and over the thigh roots: enough glute/hip mass that the legs feel
    // attached to a body, but not the two rounded thigh caps that read as
    // separate butt cheeks.
    Bone(
      id: CatBones.hips,
      parent: null,
      pivotX: 0,
      pivotY: 0,
      z: 9,
      drawable: BoneDrawable(
        kind: BoneShapeKind.ellipse,
        width: 54,
        height: 30,
        dy: 9,
        color: _trouser,
        outlineColor: _outline,
        outlineWidth: 2,
      ),
    ),
    // Far (right) arm controls. The skinned sleeve mesh hides these rigid
    // controls and draws one bendy surface through shoulder→elbow→wrist.
    Bone(
      id: CatBones.shoulderSocketR,
      parent: CatBones.clavicleR,
      pivotX: 0,
      pivotY: 10,
      z: 14,
      restRotation: -0.14,
      drawable: _tapered(
        26,
        19,
        24,
        _sleeve,
        dy: 2,
        outlineWidth: 0,
        formRound: false,
        celShade: false,
      ),
    ),
    Bone(
      id: CatBones.armUpperR,
      parent: CatBones.clavicleR,
      pivotX: 0,
      pivotY: 6,
      // Starts under the clavicle shoulder plane instead of on top of it, so the
      // arm reads as a sleeve hanging from a moving jacket shoulder.
      z: 15,
      restRotation: -0.06,
      drawable: _tapered(27, 21, 56, _sleeve, dy: 23),
    ),
    const Bone(
      id: CatBones.armBicepR,
      parent: CatBones.armUpperR,
      pivotX: 0,
      pivotY: 22,
      z: 15,
    ),
    Bone(
      id: CatBones.armLowerR,
      parent: CatBones.armUpperR,
      pivotX: 0,
      pivotY: 48,
      z: 16,
      // Either bend side is a legal 2D stand-in for humeral rotation; the
      // WRAPPED fold caps at ~166° (limits are applied on the circle — see
      // JointRotationLimit.clampAngle — so an IK solution that lands on the
      // +2π representation of a legal pose is never corrupted).
      rotationLimit: const JointRotationLimit(-2.9, 2.9),
      drawable: _tapered(23, 17, 50, _sleeve, dy: 20),
    ),
    const Bone(
      id: CatBones.armForearmR,
      parent: CatBones.armLowerR,
      pivotX: 0,
      pivotY: 22,
      z: 16,
    ),
    const Bone(
      id: CatBones.armElbowCreaseR,
      parent: CatBones.armLowerR,
      pivotX: 0,
      pivotY: 0,
      z: 17,
      restRotation: 1.57,
    ),
    // CAT PAW: a soft rounded pad with two toe beans bumping past its front edge
    // and a short side thumb — it's a cat, so the hand reads as a paw, not a
    // fist. The old build (taller fist + a light "knuckle" bar + a splayed thumb)
    // chromed into a lumpy metallic mitt. The whole paw opts OUT of the cel
    // form-rounding (formRound:false) so the gentle key sheen can't carve a
    // specular streak across the small round volumes — the head/neck dodge it the
    // same way.
    Bone(
      id: CatBones.handR,
      parent: CatBones.armLowerR,
      pivotX: 0,
      pivotY: 41,
      z: 17,
      rotationLimit: const JointRotationLimit(-1, 1),
      drawable: BoneDrawable(
        kind: BoneShapeKind.ellipse,
        width: 22.5 * armWidthScale,
        height: 21 * armWidthScale,
        dy: 1,
        color: palette.fur,
        outlineColor: _outline,
        outlineWidth: 2.5,
        celShade: false,
      ),
    ),
    // Hand-parented cuff: it rotates with the paw, so it stays on the wrist
    // side instead of sliding out from the forearm as a white blob in the palm.
    Bone(
      id: CatBones.wristCuffR,
      parent: CatBones.handR,
      pivotX: 0,
      pivotY: -12 * armWidthScale,
      z: 16,
      restRotation: -0.08,
      drawable: BoneDrawable(
        kind: BoneShapeKind.roundedRect,
        width: 18 * armWidthScale,
        height: 7 * armWidthScale,
        dy: -1,
        cornerRadius: 3,
        color: _shirt,
        outlineColor: _outline,
        outlineWidth: 1.5,
        celShade: false,
      ),
    ),
    // Two toe beans drawn BEHIND the pad (z 16 < pad z 17): only the arcs peeking
    // past the pad's front edge show, so they scallop the silhouette into toes
    // with no internal outline seams.
    Bone(
      id: CatBones.pawToeR1,
      parent: CatBones.handR,
      pivotX: -6 * armWidthScale,
      pivotY: 0,
      z: 16,
      drawable: BoneDrawable(
        kind: BoneShapeKind.ellipse,
        width: 9.2 * armWidthScale,
        height: 9.2 * armWidthScale,
        dy: 8 * armWidthScale,
        color: palette.fur,
        outlineColor: _outline,
        outlineWidth: 2.5,
        celShade: false,
      ),
    ),
    Bone(
      id: CatBones.pawToeR2,
      parent: CatBones.handR,
      pivotX: 5 * armWidthScale,
      pivotY: 0,
      z: 16,
      drawable: BoneDrawable(
        kind: BoneShapeKind.ellipse,
        width: 9.2 * armWidthScale,
        height: 9.2 * armWidthScale,
        dy: 8 * armWidthScale,
        color: palette.fur,
        outlineColor: _outline,
        outlineWidth: 2.5,
        celShade: false,
      ),
    ),
    // Thumb: a short side toe on the inner (centreline) side of the paw, less
    // splayed than before so it tucks against the pad as a digit rather than
    // jutting out as a spur. Drawn over the pad (z 18) so it reads as the near
    // toe.
    Bone(
      id: CatBones.thumbR,
      parent: CatBones.handR,
      pivotX: -9 * armWidthScale,
      pivotY: 2,
      z: 18,
      restRotation: 0.8,
      drawable: _tapered(
        9.4 * armWidthScale,
        5.8 * armWidthScale,
        13.5 * armWidthScale,
        palette.fur,
        dy: 1,
        outlineWidth: 2.5,
        celShade: false,
      ),
    ),
    // Torso (suit jacket): a tapered wedge — wide at the shoulders (top),
    // narrowing to the waist (bottom) — so it reads as a tailored jacket with a
    // shoulder line, not a barrel/box. The pelvis flares back out below it.
    Bone(
      id: CatBones.torso,
      parent: CatBones.hips,
      pivotX: 0,
      pivotY: -2,
      z: 13,
      drawable: BoneDrawable(
        kind: BoneShapeKind.taperedCapsule,
        width: 64, // broad shoulder line for the suited athletic silhouette
        widthTip: 51, // jacket hem covers the pelvis and thigh roots
        height: 98,
        dy: -38,
        color: _suit,
        outlineColor: _outline,
        outlineWidth: 2,
      ),
    ),
    // Thoracic joint: a transform-only spine link at sternum height. The clip
    // channels keep driving `torso` (the lumbar joint, local space unchanged),
    // and the scene's spine-distribute pass hands a share of that rotation to
    // this bone with a slight lag — so the body bends through TWO centres (an
    // S-curve: pelvis, waist, ribcage) instead of tilting as one plate.
    const Bone(
      id: CatBones.chest,
      parent: CatBones.torso,
      pivotX: 0,
      pivotY: -56,
      z: 13,
    ),
    // Transform-only shoulder girdle controls. The arms, lapels, collar points,
    // and the upper jacket surface hang from the chest through these, so dance
    // accents ripple through the shoulders and the shoulder mass answers the
    // thoracic bend instead of riding a rigid shell. Raised slightly above the
    // chest joint so the shoulder line sits square like a dancer's, not sloped
    // off a low armhole.
    const Bone(
      id: CatBones.clavicleR,
      parent: CatBones.chest,
      pivotX: 35,
      pivotY: -6,
      z: 14,
    ),
    const Bone(
      id: CatBones.clavicleL,
      parent: CatBones.chest,
      pivotX: -35,
      pivotY: -6,
      z: 14,
    ),

    // Jacket front tailoring: a pale shirt wedge at the collar opening with two
    // navy lapels folded back over it, framing a V down to the tie knot — the
    // single biggest "this is a tailored suit" cue the flat navy front lacked.
    // All sit on the jacket mesh (z13) under the tie (z14) and under the crossing
    // arms (z15/16), so the dance's crossed-X still reads over the chest.
    // Pale shirt V: a downward wedge (restScaleY -1 flips the apex-up triangle to
    // apex-down) showing the collar opening behind the tie.
    const Bone(
      id: CatBones.shirtV,
      parent: CatBones.chest,
      pivotX: 0,
      pivotY: -20,
      z: 13,
      restScaleY: -1,
      drawable: BoneDrawable(
        kind: BoneShapeKind.triangle,
        // Wider, taller wedge raised under the chin so a clear white collar
        // opening reads (was a thin sliver that the head swallowed), making the
        // face rise out of a shirt collar rather than sit on the jacket.
        width: 38,
        height: 36,
        dy: -16,
        color: _shirt,
        outlineColor: _outline,
        outlineWidth: 2,
        celShade: false,
      ),
    ),
    // Shirt collar: two white points standing at the base of the neck, framing
    // the tie knot dropping between them — so the head rises OUT of a collar
    // instead of sitting straight on the jacket. Flat-shaded (celShade:false)
    // like the other small bright shapes so the key can't streak them; drawn
    // under the tie knot (z14). A separate LAPEL bone (a tapered panel from
    // the collar point to the sternum) lived here through several rounds of
    // the shoulder-seam investigation: it kept reading as either an
    // independently-lit ball (a shading bug, fixed) or a stray outline seam
    // at the collar/shoulder junction (a geometry issue, also fixed) for
    // marginal payoff — the shirt V + collar + tie already sell "tailored
    // suit" on their own, so it was removed rather than tuned further.
    Bone(
      id: CatBones.collarL,
      parent: CatBones.clavicleL,
      pivotX: 24,
      pivotY: -18,
      z: 13,
      restRotation: 0.5,
      drawable: _tapered(15, 4, 26, _shirt, dy: 11, celShade: false),
    ),
    Bone(
      id: CatBones.collarR,
      parent: CatBones.clavicleR,
      pivotX: -24,
      pivotY: -18,
      z: 13,
      restRotation: -0.5,
      drawable: _tapered(15, 4, 26, _shirt, dy: 11, celShade: false),
    ),

    // Tie: a 2-link cloth pendulum over the jacket. The knot is short and nearly
    // rigid at the collar; the blade hangs off it, lags, and tapers to a point
    // — so it reads as a tie and trails like fabric, not a rigid stick.
    const Bone(
      id: CatBones.tie,
      parent: CatBones.chest,
      pivotX: 0,
      pivotY: -20,
      z: 14,
      drawable: BoneDrawable(
        kind: BoneShapeKind.taperedCapsule,
        // A distinct knot: clearly WIDER than the blade below it and short, so it
        // reads as a four-in-hand knot the blade hangs from — not a uniform red
        // stripe emerging straight from the throat.
        // A trapezoid knot: clearly wide at the collar (18) tapering to the
        // blade's width (11) at its base, so the knot reads as a four-in-hand the
        // blade flows straight out of — wide top, no gap, no bell.
        width: 18,
        widthTip: 11,
        height: 15,
        dy: 6,
        color: _tie,
        outlineColor: _outline,
        outlineWidth: 2,
        // Flat tie: the form-rounding bulged the blade into a fat red tube
        // ballooning over the jacket front; keep it a flat knotted tie.
        formRound: false,
      ),
    ),
    const Bone(
      id: CatBones.tieLower,
      parent: CatBones.tie,
      pivotX: 0,
      pivotY: 20,
      z: 14,
      // A whisper of lean so the blade hangs on a slight diagonal like real
      // cloth, not a ruler-straight stripe.
      restRotation: 0.05,
      drawable: BoneDrawable(
        kind: BoneShapeKind.taperedCapsule,
        // Slimmer than the knot and tapering to a near-POINT (widthTip 2) so the
        // blade comes to a tip down the shirt, not a rounded sticker stub.
        width: 11,
        widthTip: 2,
        height: 54,
        dy: 17, // tucks up under the knot base so there is no shirt gap
        color: _tie,
        outlineColor: _outline,
        outlineWidth: 2,
        formRound: false, // flat blade — see the knot
      ),
    ),

    // Placket buttons down the centreline below the tie. The jacket→trouser
    // transition is formed by the jacket.mesh and hips.mesh overlapping, so the
    // old dark hem BAND that used to sit here is gone — it read as an ugly dark
    // "U" stamped across the pelvis on top of the mesh.
    const Bone(
      id: CatBones.button0,
      parent: CatBones.torso,
      pivotX: 0,
      pivotY: -16,
      z: 14,
      drawable: BoneDrawable(
        kind: BoneShapeKind.ellipse,
        width: 7,
        height: 7,
        color: _button,
        outlineColor: _outline,
        outlineWidth: 1.5,
      ),
    ),
    const Bone(
      id: CatBones.button1,
      parent: CatBones.torso,
      pivotX: 0,
      pivotY: -3,
      z: 14,
      drawable: BoneDrawable(
        kind: BoneShapeKind.ellipse,
        width: 7,
        height: 7,
        color: _button,
        outlineColor: _outline,
        outlineWidth: 1.5,
      ),
    ),
    // Near (left) arm.
    Bone(
      id: CatBones.shoulderSocketL,
      parent: CatBones.clavicleL,
      pivotX: 0,
      pivotY: 10,
      z: 15,
      restRotation: 0.14,
      drawable: _tapered(
        26,
        19,
        24,
        _sleeveNear,
        dy: 2,
        outlineWidth: 0,
        formRound: false,
        celShade: false,
      ),
    ),
    Bone(
      id: CatBones.armUpperL,
      parent: CatBones.clavicleL,
      pivotX: 0,
      pivotY: 6,
      z: 16,
      restRotation: 0.06,
      drawable: _tapered(27, 21, 56, _sleeveNear, dy: 23),
    ),
    const Bone(
      id: CatBones.armBicepL,
      parent: CatBones.armUpperL,
      pivotX: 0,
      pivotY: 22,
      z: 16,
    ),
    Bone(
      id: CatBones.armLowerL,
      parent: CatBones.armUpperL,
      pivotX: 0,
      pivotY: 48,
      z: 17,
      // Either bend side is a legal 2D stand-in for humeral rotation; the
      // WRAPPED fold caps at ~166° (limits are applied on the circle — see
      // JointRotationLimit.clampAngle — so an IK solution that lands on the
      // +2π representation of a legal pose is never corrupted).
      rotationLimit: const JointRotationLimit(-2.9, 2.9),
      drawable: _tapered(23, 17, 50, _sleeveNear, dy: 20),
    ),
    const Bone(
      id: CatBones.armForearmL,
      parent: CatBones.armLowerL,
      pivotX: 0,
      pivotY: 22,
      z: 17,
    ),
    const Bone(
      id: CatBones.armElbowCreaseL,
      parent: CatBones.armLowerL,
      pivotX: 0,
      pivotY: 0,
      z: 18,
      restRotation: 1.57,
    ),
    // CAT PAW (near side) — mirror of the right paw: rounded pad, two toe beans
    // bumping past the front edge from behind, a tucked side thumb, all opted out
    // of cel form-rounding so the small round volumes don't chrome.
    Bone(
      id: CatBones.handL,
      parent: CatBones.armLowerL,
      pivotX: 0,
      pivotY: 41,
      z: 18,
      rotationLimit: const JointRotationLimit(-1, 1),
      drawable: BoneDrawable(
        kind: BoneShapeKind.ellipse,
        width: 22.5 * armWidthScale,
        height: 21 * armWidthScale,
        dy: 1,
        color: palette.fur,
        outlineColor: _outline,
        outlineWidth: 2.5,
        celShade: false,
      ),
    ),
    Bone(
      id: CatBones.wristCuffL,
      parent: CatBones.handL,
      pivotX: 0,
      pivotY: -12 * armWidthScale,
      z: 17,
      restRotation: 0.08,
      drawable: BoneDrawable(
        kind: BoneShapeKind.roundedRect,
        width: 18 * armWidthScale,
        height: 7 * armWidthScale,
        dy: -1,
        cornerRadius: 3,
        color: _shirt,
        outlineColor: _outline,
        outlineWidth: 1.5,
        celShade: false,
      ),
    ),
    Bone(
      id: CatBones.pawToeL1,
      parent: CatBones.handL,
      pivotX: 6 * armWidthScale,
      pivotY: 0,
      z: 17,
      drawable: BoneDrawable(
        kind: BoneShapeKind.ellipse,
        width: 9.2 * armWidthScale,
        height: 9.2 * armWidthScale,
        dy: 8 * armWidthScale,
        color: palette.fur,
        outlineColor: _outline,
        outlineWidth: 2.5,
        celShade: false,
      ),
    ),
    Bone(
      id: CatBones.pawToeL2,
      parent: CatBones.handL,
      pivotX: -5 * armWidthScale,
      pivotY: 0,
      z: 17,
      drawable: BoneDrawable(
        kind: BoneShapeKind.ellipse,
        width: 9.2 * armWidthScale,
        height: 9.2 * armWidthScale,
        dy: 8 * armWidthScale,
        color: palette.fur,
        outlineColor: _outline,
        outlineWidth: 2.5,
        celShade: false,
      ),
    ),
    Bone(
      id: CatBones.thumbL,
      parent: CatBones.handL,
      pivotX: 9 * armWidthScale,
      pivotY: 2,
      z: 20,
      restRotation: -0.8,
      drawable: _tapered(
        9.4 * armWidthScale,
        5.8 * armWidthScale,
        13.5 * armWidthScale,
        palette.fur,
        dy: 1,
        outlineWidth: 2.5,
        celShade: false,
      ),
    ),
    // Pointed ears (behind the head crown so only the tips show above it),
    // each with a smaller inner ear nested on top.
    Bone(
      id: CatBones.earL,
      parent: CatBones.head,
      pivotX: -24,
      pivotY: -52,
      z: 18,
      restRotation: -0.22,
      // Ear BASE: a shorter wedge with the same deep root behind the crown
      // (z18 < head z20) so rotation never exposes a background gap. The
      // upper part of the ear lives on the TIP joint below and bends.
      drawable: BoneDrawable(
        kind: BoneShapeKind.triangle,
        width: 32,
        height: 44,
        dy: -6,
        color: palette.fur,
        outlineColor: _outline,
        outlineWidth: 2,
      ),
    ),
    // Ear TIP: the bendy upper half — lags the groove harder than the base
    // (a miniature of the tail gradient) and carries the autonomic flicks,
    // so the ears read as live cartilage instead of stiff felt.
    Bone(
      id: CatBones.earTipL,
      parent: CatBones.earL,
      pivotX: 0,
      pivotY: -18,
      z: 18,
      // Sized to CONTINUE the base's taper at the hinge (the base is ~8
      // wide where the tip takes over) — a wider tip reads as a kinked
      // arrowhead stuck on a stalk, even at rest.
      drawable: BoneDrawable(
        kind: BoneShapeKind.triangle,
        width: 9,
        height: 24,
        dy: -11,
        color: palette.fur,
        outlineColor: _outline,
        outlineWidth: 2,
      ),
    ),
    Bone(
      id: CatBones.earInnerL,
      parent: CatBones.earL,
      pivotX: 0,
      pivotY: 0,
      z: 19,
      drawable: BoneDrawable(
        kind: BoneShapeKind.triangle,
        width: 14,
        height: 17,
        dy: -13,
        color: palette.innerEar,
      ),
    ),
    Bone(
      id: CatBones.earR,
      parent: CatBones.head,
      pivotX: 24,
      pivotY: -52,
      z: 18,
      restRotation: 0.22,
      // Ear BASE: a shorter wedge with the same deep root behind the crown
      // (z18 < head z20) so rotation never exposes a background gap. The
      // upper part of the ear lives on the TIP joint below and bends.
      drawable: BoneDrawable(
        kind: BoneShapeKind.triangle,
        width: 32,
        height: 44,
        dy: -6,
        color: palette.fur,
        outlineColor: _outline,
        outlineWidth: 2,
      ),
    ),
    // Ear TIP: the bendy upper half — lags the groove harder than the base
    // (a miniature of the tail gradient) and carries the autonomic flicks,
    // so the ears read as live cartilage instead of stiff felt.
    Bone(
      id: CatBones.earTipR,
      parent: CatBones.earR,
      pivotX: 0,
      pivotY: -18,
      z: 18,
      // Sized to CONTINUE the base's taper at the hinge (the base is ~8
      // wide where the tip takes over) — a wider tip reads as a kinked
      // arrowhead stuck on a stalk, even at rest.
      drawable: BoneDrawable(
        kind: BoneShapeKind.triangle,
        width: 9,
        height: 24,
        dy: -11,
        color: palette.fur,
        outlineColor: _outline,
        outlineWidth: 2,
      ),
    ),
    Bone(
      id: CatBones.earInnerR,
      parent: CatBones.earR,
      pivotX: 0,
      pivotY: 0,
      z: 19,
      drawable: BoneDrawable(
        kind: BoneShapeKind.triangle,
        width: 14,
        height: 17,
        dy: -13,
        color: palette.innerEar,
      ),
    ),

    // Neck: visible bridge tucked behind the head and collar. Without this the
    // head reads pasted directly onto the jacket, especially when the torso
    // mesh jiggles under it.
    Bone(
      id: CatBones.neck,
      parent: CatBones.chest,
      pivotX: 0,
      pivotY: -31,
      z: 12,
      drawable: BoneDrawable(
        kind: BoneShapeKind.roundedRect,
        // A real (if mostly collar-hidden) fur link: wide and tall enough
        // that the head's follow-through lag reads as a neck flexing, not as
        // the skull separating from the collar.
        // Spans from behind the skull DOWN past the jacket crown: the fur
        // column must bridge chin → collar with overlap at both ends, or the
        // head reads as detached the moment it follows through laterally.
        width: 18,
        height: 24,
        dy: -3,
        cornerRadius: 9,
        color: palette.fur,
        outlineColor: _outline,
        outlineWidth: 1.4,
        formRound: false, // keep the head/neck join clean — see celShade note
      ),
    ),
    Bone(
      id: CatBones.head,
      parent: CatBones.neck,
      pivotX: 0,
      pivotY: -7, // a touch of neck shows below the chin, no balloon-on-blob
      z: 20,
      drawable: BoneDrawable(
        kind: BoneShapeKind.ellipse,
        width: 72,
        height: 66,
        dy: -28,
        color: palette.fur,
        outlineColor: _outline,
        outlineWidth: 2,
        formRound: false, // head keeps the flat terminator — see celShade note
      ),
    ),
  ];

  final face = FaceRig(
    anchorBoneId: CatBones.head,
    eyeOffsetX: 15,
    eyeOffsetY: -34,
    eyeRadiusX: 9,
    eyeRadiusY: 11,
    pupilRadius: 7,
    browOffsetY: -48,
    browWidth: 16,
    mouthOffsetY: -12,
    mouthWidth: 22,
    mouthHeight: 11,
    eyeColor: _shirt,
    pupilColor: _outline,
    browColor: palette.brow,
    mouthColor: _outline,
    muzzleWidth: 34,
    muzzleHeight: 24,
    muzzleColor: palette.muzzle,
    noseWidth: 10,
    noseHeight: 7,
    noseColor: palette.nose,
    whiskerColor: palette.whisker,
    whiskerLength: 22,
  );

  List<double> scaledLegWidths(List<double> widths) => [
    for (final width in widths) width * legWidthScale,
  ];
  List<double> scaledArmWidths(List<double> widths) => [
    for (final width in widths) width * armWidthScale,
  ];
  final ribbons = <LimbRibbonSpec>[
    LimbRibbonSpec(
      id: 'tail.ribbon',
      jointBoneIds: const [
        CatBones.tail0,
        CatBones.tail1,
        CatBones.tail2,
        CatBones.tail3,
        CatBones.tail4,
        CatBones.tail5,
        CatBones.tail6,
      ],
      hiddenBoneIds: const [
        CatBones.tail0,
        CatBones.tail1,
        CatBones.tail2,
        CatBones.tail3,
        CatBones.tail4,
        CatBones.tail5,
        CatBones.tail6,
      ],
      halfWidths: const [3.8, 3.7, 3.4, 3.0, 2.5, 1.9, 1.2],
      z: -7,
      color: palette.fur,
      outlineColor: _outline,
      outlineWidth: 2,
    ),
    LimbRibbonSpec(
      id: 'leg.R.ribbon',
      jointBoneIds: const [
        CatBones.hipBlendR,
        CatBones.legUpperR,
        CatBones.legQuadR,
        CatBones.legLowerR,
        CatBones.legCalfR,
        CatBones.footR,
      ],
      hiddenBoneIds: const [CatBones.legUpperR, CatBones.legLowerR],
      // Tailored athletic trouser profile: enough thigh mass to feel strong,
      // a decisive knee pinch, a fitted calf, then a narrow ankle. Keep it lean
      // rather than bodybuilder-wide so the dance reads agile in quarter view.
      // FRONT profile: the quad carries the thigh mass and holds it almost
      // to the knee; the shin's front is near-straight (bone, not muscle).
      halfWidths: scaledLegWidths(const [15.0, 14.2, 15.6, 8.6, 9.2, 5.5]),
      // BACK profile: hamstring eases off the seat, then the CALF bulge —
      // the S-curve that reads athletic where a symmetric tube reads stuffed.
      backHalfWidths: scaledLegWidths(const [15.0, 13.0, 11.2, 8.2, 12.2, 5.3]),
      // Tension profile: soft through the hip/seat so the trouser root stays
      // one smooth mass, firm from the knee down so flexion resolves at a
      // visible knee vertex instead of a crescent shin.
      jointTensions: const [0.42, 0.45, 0.55, 0.74, 0.74, 0.74],
      z: 3,
      color: _trouserRear,
      outlineColor: _outline,
      outlineWidth: 2,
      samplesPerSegment: 12,
      shadeGroup: kTrouserShadeGroup,
      inkOverFill: true,
      inkStartFraction: 0.16,
    ),
    LimbRibbonSpec(
      id: 'leg.L.ribbon',
      jointBoneIds: const [
        CatBones.hipBlendL,
        CatBones.legUpperL,
        CatBones.legQuadL,
        CatBones.legLowerL,
        CatBones.legCalfL,
        CatBones.footL,
      ],
      hiddenBoneIds: const [CatBones.legUpperL, CatBones.legLowerL],
      // FRONT profile: the quad carries the thigh mass and holds it almost
      // to the knee; the shin's front is near-straight (bone, not muscle).
      halfWidths: scaledLegWidths(const [15.0, 14.2, 15.6, 8.6, 9.2, 5.5]),
      // BACK profile: hamstring eases off the seat, then the CALF bulge —
      // the S-curve that reads athletic where a symmetric tube reads stuffed.
      backHalfWidths: scaledLegWidths(const [15.0, 13.0, 11.2, 8.2, 12.2, 5.3]),
      // Tension profile: soft through the hip/seat so the trouser root stays
      // one smooth mass, firm from the knee down so flexion resolves at a
      // visible knee vertex instead of a crescent shin.
      jointTensions: const [0.42, 0.45, 0.55, 0.74, 0.74, 0.74],
      z: 6,
      color: _trouser,
      outlineColor: _outline,
      outlineWidth: 2,
      samplesPerSegment: 12,
      shadeGroup: kTrouserShadeGroup,
      inkOverFill: true,
      // The trouser leg's line starts below the pelvis panel.
      inkStartFraction: 0.16,
    ),
    // Arms: the same continuous-ribbon treatment that already makes the legs
    // read as one bending limb. The centreline flows clavicle→shoulder→elbow→
    // wrist with an anatomical half-width profile — widest at the DELTOID (the
    // round start cap doubles as the shoulder muscle), tapering through bicep
    // and elbow to a slim wrist with a slight forearm swell. This inverts the
    // old "sausage" tell (thinnest at the attachment point).
    //
    // ANTI-HINGE: the first TWO joints (clavicle, socket) are both rigidly
    // clavicle-anchored, so the ribbon's root section cannot rotate with the
    // arm. When the arm swings, the curve bends over the socket→bicep span —
    // a fabric crease BELOW the anchored deltoid dome — instead of the whole
    // shoulder cap sweeping around a pin like a paper-doll rivet.
    LimbRibbonSpec(
      id: 'arm.R.ribbon',
      jointBoneIds: const [
        CatBones.clavicleR,
        CatBones.shoulderSocketR,
        CatBones.armBicepR,
        CatBones.armLowerR,
        CatBones.armForearmR,
        CatBones.handR,
      ],
      hiddenBoneIds: const [
        CatBones.shoulderSocketR,
        CatBones.armUpperR,
        CatBones.armLowerR,
      ],
      // FRONT profile [clavicle, deltoid, bicep, elbow, forearm, wrist]:
      // the BICEP carries the upper-arm mass and the forearm swells with the
      // brachioradialis before tapering into the wrist. The clavicle root
      // stays close to the deltoid width so the round start cap (the armhole
      // gap-proofing dome) reads as one continuous mass with the shoulder,
      // not a pinched neck-then-bulge.
      // Terminal width raised 5.2 -> 6.7 (~60% of the bicep): with the cuff
      // termination below, the sleeve ENDS as a fabric opening at the cuff
      // band instead of deflating into the palm ("forearm pinches to a
      // third of the bicep just above the cuff" — R21 rigging).
      halfWidths: scaledArmWidths(const [10.8, 11.0, 11.2, 7.2, 8.5, 6.7]),
      // BACK profile: fuller triceps up high, a tight bony elbow point, and
      // a lean forearm underside — the same put-the-mass-where-the-muscle-is
      // asymmetry that makes the legs read athletic.
      backHalfWidths: scaledArmWidths(const [10.4, 10.4, 10.2, 7.4, 7.2, 6.4]),
      // Tension profile: soft over the clavicle/deltoid cap (a flat firm
      // tension scalloped the shoulder into per-joint lobes), firm from the
      // bicep out so the elbow keeps a defined vertex at any flexion.
      jointTensions: const [0.42, 0.42, 0.52, 0.74, 0.74, 0.74],
      z: 15,
      color: _sleeve,
      outlineColor: _outline,
      outlineWidth: 2,
      samplesPerSegment: 12,
      formRound: false,
      shadeGroup: kJacketShadeGroup,
      inkOverFill: true,
      // Below the deltoid: the root must merge with the jacket. The ink is
      // clipped to actual body overlap at render time, so its ends land ON
      // the silhouette rather than floating mid-cloth.
      inkStartFraction: 0.2,
      // Sleeve terminates at the CUFF, not the palm: the last spine joint
      // is the hand origin (the mitten's centre) and the wrist cuff sits
      // ~12 units back up the forearm — without this inset the sleeve
      // painted across the paw and, via its end cap, PAST it ("continues
      // past the cuff to an empty squared end" — three panel rounds).
      // 14 back + the ~6.7 cap radius lands the fabric edge under the
      // cuff band.
      distalInset: 14 * armWidthScale,
    ),
    LimbRibbonSpec(
      id: 'arm.L.ribbon',
      jointBoneIds: const [
        CatBones.clavicleL,
        CatBones.shoulderSocketL,
        CatBones.armBicepL,
        CatBones.armLowerL,
        CatBones.armForearmL,
        CatBones.handL,
      ],
      hiddenBoneIds: const [
        CatBones.shoulderSocketL,
        CatBones.armUpperL,
        CatBones.armLowerL,
      ],
      // FRONT profile [clavicle, deltoid, bicep, elbow, forearm, wrist]:
      // the BICEP carries the upper-arm mass and the forearm swells with the
      // brachioradialis before tapering into the wrist. The clavicle root
      // stays close to the deltoid width so the round start cap (the armhole
      // gap-proofing dome) reads as one continuous mass with the shoulder,
      // not a pinched neck-then-bulge.
      // Terminal width raised 5.2 -> 6.7 (~60% of the bicep): with the cuff
      // termination below, the sleeve ENDS as a fabric opening at the cuff
      // band instead of deflating into the palm ("forearm pinches to a
      // third of the bicep just above the cuff" — R21 rigging).
      halfWidths: scaledArmWidths(const [10.8, 11.0, 11.2, 7.2, 8.5, 6.7]),
      // BACK profile: fuller triceps up high, a tight bony elbow point, and
      // a lean forearm underside — the same put-the-mass-where-the-muscle-is
      // asymmetry that makes the legs read athletic.
      backHalfWidths: scaledArmWidths(const [10.4, 10.4, 10.2, 7.4, 7.2, 6.4]),
      // Tension profile: soft over the clavicle/deltoid cap (a flat firm
      // tension scalloped the shoulder into per-joint lobes), firm from the
      // bicep out so the elbow keeps a defined vertex at any flexion.
      jointTensions: const [0.42, 0.42, 0.52, 0.74, 0.74, 0.74],
      z: 16,
      color: _sleeveNear,
      outlineColor: _outline,
      outlineWidth: 2,
      samplesPerSegment: 12,
      formRound: false,
      shadeGroup: kJacketShadeGroup,
      inkOverFill: true,
      // Below the deltoid: the root must merge with the jacket. The ink is
      // clipped to actual body overlap at render time, so its ends land ON
      // the silhouette rather than floating mid-cloth.
      inkStartFraction: 0.2,
      // Sleeve terminates at the CUFF, not the palm: the last spine joint
      // is the hand origin (the mitten's centre) and the wrist cuff sits
      // ~12 units back up the forearm — without this inset the sleeve
      // painted across the paw and, via its end cap, PAST it ("continues
      // past the cuff to an empty squared end" — three panel rounds).
      // 14 back + the ~6.7 cap radius lands the fabric edge under the
      // cuff band.
      distalInset: 14 * armWidthScale,
    ),
  ];

  final meshes = <SkinnedMeshSpec>[
    SkinnedMeshSpec(
      id: 'hips.mesh',
      vertices: const [
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.torso, x: -22, y: 7, weight: 0.3),
          MeshInfluence(boneId: CatBones.hips, x: -22, y: 2, weight: 0.7),
        ]),
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.torso, x: -8, y: 11, weight: 0.24),
          MeshInfluence(boneId: CatBones.hips, x: -10, y: 6, weight: 0.76),
        ]),
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.torso, x: 8, y: 11, weight: 0.24),
          MeshInfluence(boneId: CatBones.hips, x: 10, y: 6, weight: 0.76),
        ]),
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.torso, x: 22, y: 7, weight: 0.3),
          MeshInfluence(boneId: CatBones.hips, x: 22, y: 2, weight: 0.7),
        ]),
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.hips, x: 27.5, y: 10, weight: 1),
        ]),
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.hips, x: 26, y: 19, weight: 1),
        ]),
        // Bottom edge is an M, not a U: two thigh-tops with a CROTCH NOTCH
        // between them, so the legs emerge from hips with a V-crotch instead of
        // hanging off a filled rounded "disk" that reads as no real body part.
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.hips, x: 19, y: 26, weight: 1),
        ]),
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.hips, x: 0, y: 13, weight: 1),
        ]),
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.hips, x: -19, y: 26, weight: 1),
        ]),
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.hips, x: -26, y: 19, weight: 1),
        ]),
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.hips, x: -27.5, y: 10, weight: 1),
        ]),
      ],
      boundary: const [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      hiddenBoneIds: const [CatBones.hips],
      z: 9,
      color: _trouser,
      shadeGroup: kTrouserShadeGroup,
      // NO outline and NO form-rounding: an outlined / contour-darkened pelvis
      // read as a separate "plate" stamped between the jacket and the legs. The
      // jacket caps its top and the same-tone leg ribbons flow out of its bottom,
      // so the lower body reads as one continuous trouser form, not a panel.
      formRound: false,
    ),
    // Jacket: ONE generated trunk surface. The silhouette is a width table
    // (hem → waist pinch → ribs → armhole) plus a neckline crown, and the skin
    // weights blend down the hips→torso→chest spine automatically — see
    // buildTrunkSurface. The spine-distribute pass bends this surface through
    // the waist and sternum, so the jacket flexes like a torso instead of
    // riding the dance as one rigid shell. Replaces the hand-weighted
    // jacket.mesh + two side panels that only deformed well in tuned poses.
    buildTrunkSurface(
      id: 'jacket.mesh',
      bones: bones,
      stations: const [
        TrunkStation(boneId: CatBones.hips, y: 14, halfWidth: 22.5),
        TrunkStation(boneId: CatBones.torso, y: -8, halfWidth: 19.5),
        TrunkStation(boneId: CatBones.torso, y: -34, halfWidth: 24.5),
        TrunkStation(boneId: CatBones.chest, y: -60, halfWidth: 32.5),
      ],
      // The yoke: a near-vertical armhole side seam up to the shoulder corner,
      // then a ~25° trapezius line into the collar — NOT a steep straight
      // ramp from deltoid to head. The arm ribbon's deltoid dome crowns just
      // above the corner and reads as the shoulder point. The OUTER corners
      // ride the clavicles half-weighted, so a girdle shrug lifts the
      // trapezius with the raised deltoid instead of leaving a valley
      // between shoulder and collar.
      crown: const [(x: -29.0, y: -75.0), (x: -13.0, y: -81.5)],
      crownWeights: const [
        {CatBones.chest: 0.5, CatBones.clavicleL: 0.5},
        {CatBones.chest: 0.85, CatBones.clavicleL: 0.15},
      ],
      crownWeightsMirrored: const [
        {CatBones.chest: 0.85, CatBones.clavicleR: 0.15},
        {CatBones.chest: 0.5, CatBones.clavicleR: 0.5},
      ],
      z: 13,
      color: _suit,
      outlineColor: _outline,
      outlineWidth: 1,
      hiddenBoneIds: const [CatBones.torso],
      shadeGroup: kJacketShadeGroup,
      // NO drawn shoulder seam: the outline is the outer border of the
      // fabric, nothing else. Every attempt to run a decorative seam near
      // the shoulder produced stray pencil-stroke reads in some pose; the
      // limb ink below is clipped to actual overlap, so the shoulder always
      // carries exactly ONE line — the silhouette.
    ),
  ];

  return RigSpec(
    name: 'cat_in_suit',
    bones: bones,
    ribbons: ribbons,
    meshes: meshes,
    face: face,
    // Cel-shade the cat: a baked per-shape form shadow so the flat fills read as
    // dimensional cartoon volumes (each limb/torso/head lit from upper-left into
    // a cool blue-hour shade), not stickers on the painted plate. The core shadow
    // does the modelling (deep, cool, broad coverage with a soft terminator); the
    // warm key highlight is kept GENTLE and narrow — just enough to lift the lit
    // side of the near-black navy suit so the form reads, but not so hot/hard that
    // small round shapes (arms, hands, tail) chrome out into metallic streaks.
    // This is the structural form-light a film panel said flat fills could never
    // fake with screen-space gradients; baking it per-shape means it tracks the
    // geometry through every pose instead of sliding over it.
    celShade: const CelShadeSpec(
      // Round-4-plus: a tall shape (a leg, lit from above) puts a large
      // fraction of its own length past the shadow terminator by design —
      // at hero scale on the lead dancer this crushed the trousers toward
      // near-black ("harsh line... definitely mistuned"). Backed off both
      // knobs: less of the shape falls into full shadow (coverage), and the
      // shadow floor itself sits higher (shadowFactor), while keeping the
      // shade cool/broad enough that limbs still read as dimensional, not
      // flat stickers.
      shadowFactor: 0.62,
      coolAmount: 0.26,
      coverage: 0.4,
      softness: 0.16,
      // A modest lit-side SHEEN so the fabric/fur reads as catching the key,
      // without going so bright that the thin limbs/cuffs chrome out.
      highlightAmount: 0.24,
      highlightCoverage: 0.24,
      // Painterly form-rounding rounds each volume's contour into a cool
      // occlusion so limbs/torso read as TUBES, not flat sticks (the panel's
      // flat-bodies note). The head + neck opt OUT (BoneDrawable.formRound:false):
      // their rounded bottoms darkened against the torso top into a detached
      // "about to fall off" head. So the body gets volume; the head/neck keep the
      // flat cel terminator only.
      roundAmount: 0.42,
      roundCoverage: 0.6,
    ),
  );
}
