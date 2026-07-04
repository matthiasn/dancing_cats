part of 'cat_in_suit.dart';

// Signature per-species markings, layered on top of the base rig built by
// `buildCatInSuitRig`. The suit covers the torso and limbs entirely (see
// `CatInSuitPalette`'s doc comment), so every marking here lives on the
// fur-visible real estate: the head/ears, the tail, and the hands. Each
// marking is its own small `Bone`, parented to whichever body part it
// should move with — a stripe on the head rides the head's own sway, a
// tail ring rides that exact tail segment as it curls.
//
// `formRound: false, celShade: false` on every marking keeps them reading
// as flat pigment (paint on fur) rather than extra 3D volumes stacked on
// the silhouette. `outlineWidth: 0` keeps them from reading as appliqué.

Bone _mark({
  required String id,
  required String parent,
  required double pivotX,
  required double pivotY,
  required double width,
  required double height,
  required int z,
  required int color,
  double rotation = 0,
  BoneShapeKind kind = BoneShapeKind.capsule,
}) => Bone(
  id: id,
  parent: parent,
  pivotX: pivotX,
  pivotY: pivotY,
  z: z,
  restRotation: rotation,
  drawable: BoneDrawable(
    kind: kind,
    width: width,
    height: height,
    color: color,
    formRound: false,
    celShade: false,
  ),
);

/// Tiger: a full stripe pattern on the head (crown + cheek sweeps + a
/// muzzle bridge), the classic white spot on the back of each ear, and
/// stripe rings down the tail — NOT on the torso/limbs, which are the
/// suit's jacket and trousers, not fur.
List<Bone> _tigerMarkings() => [
  // Crown: two short stripes angling up from between the eyes.
  _mark(
    id: 'tiger_stripe_crown_l',
    parent: CatBones.head,
    pivotX: -7,
    pivotY: -52,
    width: 5,
    height: 18,
    rotation: -0.35,
    z: 21,
    color: _tigerMark,
  ),
  _mark(
    id: 'tiger_stripe_crown_r',
    parent: CatBones.head,
    pivotX: 7,
    pivotY: -52,
    width: 5,
    height: 18,
    rotation: 0.35,
    z: 21,
    color: _tigerMark,
  ),
  // Temple sweeps: longer, angled back toward the ears.
  _mark(
    id: 'tiger_stripe_temple_l',
    parent: CatBones.head,
    pivotX: -27,
    pivotY: -42,
    width: 6,
    height: 22,
    rotation: -0.6,
    z: 21,
    color: _tigerMark,
  ),
  _mark(
    id: 'tiger_stripe_temple_r',
    parent: CatBones.head,
    pivotX: 27,
    pivotY: -42,
    width: 6,
    height: 22,
    rotation: 0.6,
    z: 21,
    color: _tigerMark,
  ),
  // Cheek stripes: shorter, lower, framing the muzzle.
  _mark(
    id: 'tiger_stripe_cheek_l',
    parent: CatBones.head,
    pivotX: -24,
    pivotY: -20,
    width: 5,
    height: 14,
    rotation: -0.2,
    z: 21,
    color: _tigerMark,
  ),
  _mark(
    id: 'tiger_stripe_cheek_r',
    parent: CatBones.head,
    pivotX: 24,
    pivotY: -20,
    width: 5,
    height: 14,
    rotation: 0.2,
    z: 21,
    color: _tigerMark,
  ),
  // White spot on the back of each ear — the single most tiger-specific
  // detail (real tigers use it as a false "eye" seen from behind).
  _mark(
    id: 'tiger_ear_spot_l',
    parent: CatBones.earL,
    pivotX: 0,
    pivotY: -8,
    width: 11,
    height: 13,
    z: 17,
    color: _tigerEarSpot,
    kind: BoneShapeKind.ellipse,
  ),
  _mark(
    id: 'tiger_ear_spot_r',
    parent: CatBones.earR,
    pivotX: 0,
    pivotY: -8,
    width: 11,
    height: 13,
    z: 17,
    color: _tigerEarSpot,
    kind: BoneShapeKind.ellipse,
  ),
  // Tail: thin bands wrapping each of the last 4 segments, tapering with
  // the ribbon's own width so they read as rings, not blobs.
  _mark(
    id: 'tiger_tail_ring_3',
    parent: CatBones.tail3,
    pivotX: 0,
    pivotY: 8,
    width: 9,
    height: 4,
    z: -3,
    color: _tigerMark,
    kind: BoneShapeKind.ellipse,
  ),
  _mark(
    id: 'tiger_tail_ring_4',
    parent: CatBones.tail4,
    pivotX: 0,
    pivotY: 7,
    width: 7,
    height: 3.5,
    z: -2,
    color: _tigerMark,
    kind: BoneShapeKind.ellipse,
  ),
  _mark(
    id: 'tiger_tail_ring_5',
    parent: CatBones.tail5,
    pivotX: 0,
    pivotY: 6,
    width: 5.5,
    height: 3,
    z: -1,
    color: _tigerMark,
    kind: BoneShapeKind.ellipse,
  ),
  _mark(
    id: 'tiger_tail_ring_6',
    parent: CatBones.tail6,
    pivotX: 0,
    pivotY: 5,
    width: 4,
    height: 2.5,
    z: 0,
    color: _tigerMark,
    kind: BoneShapeKind.ellipse,
  ),
  // Cowlick: one stubborn tuft standing straight up off the crown — the
  // himbo touch that keeps the huge head from reading as merely fierce.
  _mark(
    id: 'tiger_cowlick',
    parent: CatBones.head,
    pivotX: 5,
    pivotY: -66,
    width: 7,
    height: 22,
    rotation: 0.12,
    z: 21,
    color: _tigerFur,
  ),
];

/// Lion: a real layered mane — an inner ring of dense, smaller tufts close
/// to the head plus an outer ring of larger, shaggier ones — framing the
/// head instead of a token fringe, plus small ear tufts.
List<Bone> _lionMarkings() {
  final bones = <Bone>[];

  // Inner ring: denser, smaller tufts close to the head — the mane's
  // "volume" layer. Sits BEHIND the head/ears (z below the head's z:20)
  // but in FRONT of the neck, so it reads as a fluffy collar the head
  // sits inside of.
  const innerCount = 10;
  for (var i = 0; i < innerCount; i++) {
    final angle = (i / innerCount) * 2 * math.pi;
    const rx = 38.0;
    const ry = 34.0;
    bones.add(
      _mark(
        id: 'lion_mane_inner_$i',
        parent: CatBones.head,
        pivotX: math.cos(angle) * rx,
        pivotY: -28 + math.sin(angle) * ry,
        width: 20,
        height: 24,
        rotation: angle,
        z: 15,
        color: _lionManeInner,
        kind: BoneShapeKind.ellipse,
      ),
    );
  }

  // Outer ring: larger, more elongated tufts, offset in angle from the
  // inner ring so the two don't stack exactly — the irregular overlap is
  // what makes the silhouette read as shaggy instead of a perfect disc.
  // Darker colour adds the two-tone depth real manes have.
  const outerCount = 12;
  for (var i = 0; i < outerCount; i++) {
    final angle = (i / outerCount) * 2 * math.pi + (math.pi / outerCount);
    const rx = 52.0;
    const ry = 46.0;
    bones.add(
      _mark(
        id: 'lion_mane_outer_$i',
        parent: CatBones.head,
        pivotX: math.cos(angle) * rx,
        pivotY: -28 + math.sin(angle) * ry,
        width: 24,
        height: 34,
        rotation: angle,
        z: 14,
        color: _lionManeOuter,
        kind: BoneShapeKind.ellipse,
      ),
    );
  }

  // Small dark ear tufts at the tips, plus the diva forelock: one dramatic
  // curl of mane flopping down over the forehead, drawn IN FRONT of the
  // head (z above the head's own z:20) — the "too fabulous" sight gag that
  // turns a regal mane into a hair flip.
  bones.addAll([
    _mark(
      id: 'lion_ear_tuft_l',
      parent: CatBones.earTipL,
      pivotX: 0,
      pivotY: -10,
      width: 7,
      height: 9,
      z: 18,
      color: _lionManeOuter,
      kind: BoneShapeKind.triangle,
    ),
    _mark(
      id: 'lion_ear_tuft_r',
      parent: CatBones.earTipR,
      pivotX: 0,
      pivotY: -10,
      width: 7,
      height: 9,
      z: 18,
      color: _lionManeOuter,
      kind: BoneShapeKind.triangle,
    ),
    _mark(
      id: 'lion_forelock',
      parent: CatBones.head,
      pivotX: -3,
      pivotY: -58,
      width: 12,
      height: 26,
      rotation: -0.3,
      z: 21,
      color: _lionManeOuter,
      kind: BoneShapeKind.triangle,
    ),
  ]);

  return bones;
}

/// Cheetah: the signature black tear-marks from eye to mouth, a
/// head-to-tail spot distribution that thins toward the back, and solid
/// dark rings banding the tail tip (real cheetah tails band solid near
/// the tip rather than staying spotted).
List<Bone> _cheetahMarkings() {
  final bones = <Bone>[
    // Tear-marks: the single most identifying cheetah feature, run
    // dramatically long here — half "big cat," half "just saw a ghost."
    _mark(
      id: 'cheetah_tear_l',
      parent: CatBones.head,
      pivotX: -13,
      pivotY: -20,
      width: 4,
      height: 32,
      rotation: -0.08,
      z: 21,
      color: _cheetahMark,
    ),
    _mark(
      id: 'cheetah_tear_r',
      parent: CatBones.head,
      pivotX: 13,
      pivotY: -20,
      width: 4,
      height: 32,
      rotation: 0.08,
      z: 21,
      color: _cheetahMark,
    ),
    // Shock lines: two short strokes fanning off the outer corner of each
    // eye, the classic "!!" startle mark, so the huge round eyes read as an
    // actual reaction, not just an anatomical quirk.
    _mark(
      id: 'cheetah_shock_l1',
      parent: CatBones.head,
      pivotX: -30,
      pivotY: -42,
      width: 2.5,
      height: 11,
      rotation: -0.5,
      z: 21,
      color: _cheetahMark,
    ),
    _mark(
      id: 'cheetah_shock_l2',
      parent: CatBones.head,
      pivotX: -35,
      pivotY: -34,
      width: 2.5,
      height: 9,
      rotation: -1,
      z: 21,
      color: _cheetahMark,
    ),
    _mark(
      id: 'cheetah_shock_r1',
      parent: CatBones.head,
      pivotX: 30,
      pivotY: -42,
      width: 2.5,
      height: 11,
      rotation: 0.5,
      z: 21,
      color: _cheetahMark,
    ),
    _mark(
      id: 'cheetah_shock_r2',
      parent: CatBones.head,
      pivotX: 35,
      pivotY: -34,
      width: 2.5,
      height: 9,
      rotation: 1,
      z: 21,
      color: _cheetahMark,
    ),
  ];

  // Head spots: small and dense, scattered across the crown/cheeks.
  const headSpots = [
    (-18.0, -50.0, 6.0),
    (18.0, -50.0, 6.0),
    (-6.0, -58.0, 5.0),
    (6.0, -58.0, 5.0),
    (-28.0, -34.0, 5.5),
    (28.0, -34.0, 5.5),
    (0.0, -14.0, 5.0),
  ];
  for (var i = 0; i < headSpots.length; i++) {
    final (dx, dy, size) = headSpots[i];
    bones.add(
      _mark(
        id: 'cheetah_head_spot_$i',
        parent: CatBones.head,
        pivotX: dx,
        pivotY: dy,
        width: size,
        height: size,
        z: 21,
        color: _cheetahMark,
        kind: BoneShapeKind.ellipse,
      ),
    );
  }

  // Tail spots: larger/sparser than the head, thinning toward the tip,
  // which then bands solid.
  const tailSpotSegments = [
    (CatBones.tail0, 6.0),
    (CatBones.tail1, 5.5),
    (CatBones.tail2, 5.0),
  ];
  for (var i = 0; i < tailSpotSegments.length; i++) {
    final (segment, size) = tailSpotSegments[i];
    bones.add(
      _mark(
        id: 'cheetah_tail_spot_$i',
        parent: segment,
        pivotX: 0,
        pivotY: 8,
        width: size,
        height: size,
        z: -3,
        color: _cheetahMark,
        kind: BoneShapeKind.ellipse,
      ),
    );
  }
  const tailBandSegments = [CatBones.tail4, CatBones.tail5, CatBones.tail6];
  for (var i = 0; i < tailBandSegments.length; i++) {
    bones.add(
      _mark(
        id: 'cheetah_tail_band_$i',
        parent: tailBandSegments[i],
        pivotX: 0,
        pivotY: 7,
        width: (6 - i).toDouble(),
        height: 3,
        z: -2,
        color: _cheetahMark,
        kind: BoneShapeKind.ellipse,
      ),
    );
  }

  return bones;
}
