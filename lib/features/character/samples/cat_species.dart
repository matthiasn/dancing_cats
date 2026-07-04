part of 'cat_in_suit.dart';

// Big-cat species colours. The suit (jacket/trousers/sleeves) stays the
// fixed navy `_suit`/`_trouser` fabric regardless of species (see
// `CatInSuitPalette`'s own doc comment) — only the FUR-visible areas
// (head/ears, tail, hands) carry species colour, so the markings built in
// `cat_species_markings.dart` are placed to live there too.
const int _tigerFur = 0xFFF07C1E; // bright tiger orange
const int _tigerFurDark = 0xFFCF6712;
const int _tigerInnerEar = 0xFFF6E4CE;
const int _tigerMuzzle = 0xFFFBF3E4; // near-white muzzle patch
const int _tigerNose = 0xFF7A3B3E;
const int _tigerWhisker = 0xFF2A2018;
const int _tigerMark = 0xFF201007; // stripe ink — warm near-black
const int _tigerEarSpot = 0xFFF7F1E4; // the white spot on the back of each ear

const int _lionFur = 0xFFCE9A46; // tawny gold
const int _lionFurDark = 0xFFAE7B32;
const int _lionInnerEar = 0xFFE9C79A;
const int _lionMuzzle = 0xFFEFDCB2;
const int _lionNose = 0xFF4A2B22; // lions have dark noses, not pink
const int _lionWhisker = 0xFF3C2A18;
const int _lionManeInner = 0xFF9C5A22; // warm brown — dense inner ring
const int _lionManeOuter = 0xFF5C3418; // darker — the shaggy outer tips

const int _cheetahFur = 0xFFEBD59E; // pale gold/cream
const int _cheetahFurDark = 0xFFD8BD82;
const int _cheetahInnerEar = 0xFFF3E6CE;
const int _cheetahMuzzle = 0xFFF7EFDD;
const int _cheetahNose = 0xFF2A1E18; // dark nose
const int _cheetahWhisker = 0xFF3A2E20;
const int _cheetahMark = 0xFF241A12; // spots/tear-marks — warm near-black

const kTigerPalette = CatInSuitPalette(
  fur: _tigerFur,
  furDark: _tigerFurDark,
  innerEar: _tigerInnerEar,
  muzzle: _tigerMuzzle,
  nose: _tigerNose,
  whisker: _tigerWhisker,
  brow: _tigerMark,
);

const kLionPalette = CatInSuitPalette(
  fur: _lionFur,
  furDark: _lionFurDark,
  innerEar: _lionInnerEar,
  muzzle: _lionMuzzle,
  nose: _lionNose,
  whisker: _lionWhisker,
  brow: _lionManeOuter,
);

const kCheetahPalette = CatInSuitPalette(
  fur: _cheetahFur,
  furDark: _cheetahFurDark,
  innerEar: _cheetahInnerEar,
  muzzle: _cheetahMuzzle,
  nose: _cheetahNose,
  whisker: _cheetahWhisker,
  brow: _cheetahMark,
);

/// Everything that varies by SPECIES, as opposed to [CatInSuitPalette] (which
/// only ever varied flat fur colour on the one house-cat skull): head/ear
/// silhouette, face proportions, overall body size, base limb leanness, and
/// a signature marking set (stripes/mane/spots). The suit stays the fixed
/// navy fabric regardless of species (see [CatInSuitPalette]'s own doc
/// comment) — only the fur-visible areas (head/ears, tail, hands) carry
/// species geometry and colour, since the jacket/trousers/sleeves cover
/// everything else.
class CatSpeciesSpec {
  const CatSpeciesSpec({
    required this.name,
    required this.palette,
    this.headWidth = 72,
    this.headHeight = 66,
    this.earBaseWidth = 32,
    this.earBaseHeight = 44,
    this.earTipWidth = 9,
    this.earTipHeight = 24,
    this.earInnerWidth = 14,
    this.earInnerHeight = 17,
    this.eyeOffsetX = 15,
    this.eyeOffsetY = -34,
    this.eyeRadiusX = 9,
    this.eyeRadiusY = 11,
    this.pupilRadius = 7,
    this.browOffsetY = -48,
    this.browWidth = 16,
    this.muzzleWidth = 34,
    this.muzzleHeight = 24,
    this.noseWidth = 10,
    this.noseHeight = 7,
    this.whiskerLength = 22,
    this.displayScale = 1,
    this.armWidthScale = 1,
    this.legWidthScale = 1,
    this.markings,
  });

  final String name;
  final CatInSuitPalette palette;

  // Head ellipse (BoneShapeKind.ellipse on CatBones.head).
  final double headWidth;
  final double headHeight;

  // Ear triangles (CatBones.earL/R base, earTipL/R, earInnerL/R).
  final double earBaseWidth;
  final double earBaseHeight;
  final double earTipWidth;
  final double earTipHeight;
  final double earInnerWidth;
  final double earInnerHeight;

  // Passed straight into FaceRig.
  final double eyeOffsetX;
  final double eyeOffsetY;
  final double eyeRadiusX;
  final double eyeRadiusY;
  final double pupilRadius;
  final double browOffsetY;
  final double browWidth;
  final double muzzleWidth;
  final double muzzleHeight;
  final double noseWidth;
  final double noseHeight;
  final double whiskerLength;

  /// Overall body-size multiplier (see `RigSpec.displayScale`).
  final double displayScale;

  /// Base leanness, composed multiplicatively with `buildCatInSuitRig`'s own
  /// `armWidthScale`/`legWidthScale` params (today used for ensemble-depth
  /// thinning) — a species sets its OWN build, staging can still thin it
  /// further for an upstage flanker.
  final double armWidthScale;
  final double legWidthScale;

  /// Extra decorative bones (stripes/mane/spots) layered onto the base rig.
  /// Null for the plain house cat.
  final List<Bone> Function()? markings;

  static const houseCat = CatSpeciesSpec(
    name: 'house cat',
    palette: CatInSuitPalette.orangeTabby,
  );

  /// Same house-cat geometry, palette-only variants — used to give the
  /// default trio's flanking dancers a distinct coat without changing their
  /// head/ear shape.
  static const silverTabby = CatSpeciesSpec(
    name: 'house cat (silver)',
    palette: CatInSuitPalette.silverTabby,
  );

  static const darkBrown = CatSpeciesSpec(
    name: 'house cat (dark brown)',
    palette: CatInSuitPalette.darkBrown,
  );

  /// The himbo bruiser: a huge head on a buff frame, ears shrunk down to
  /// comically small next to it, big wide-set googly eyes with tiny pupils
  /// (a dopey, not-the-brightest look), and a fat, slightly underslung
  /// muzzle for a permanent goofy grin.
  static const tiger = CatSpeciesSpec(
    name: 'tiger',
    palette: kTigerPalette,
    headWidth: 92,
    headHeight: 80,
    earBaseWidth: 18,
    earBaseHeight: 22,
    earTipWidth: 5,
    earTipHeight: 10,
    earInnerWidth: 8,
    earInnerHeight: 9,
    eyeOffsetX: 20,
    eyeRadiusX: 13,
    eyeRadiusY: 15,
    pupilRadius: 5,
    browOffsetY: -44,
    browWidth: 22,
    muzzleWidth: 46,
    muzzleHeight: 30,
    displayScale: 1.35,
    armWidthScale: 1.15,
    legWidthScale: 1.1,
    markings: _tigerMarkings,
  );

  /// The fabulous show-off: the biggest of the three, wrapped in a mane so
  /// big it borders on absurd, with a dainty little muzzle peeking out and
  /// dramatically arched, permanently imperious brows.
  static const lion = CatSpeciesSpec(
    name: 'lion',
    palette: kLionPalette,
    headWidth: 84,
    headHeight: 76,
    earBaseWidth: 14,
    earBaseHeight: 18,
    earTipWidth: 5,
    earTipHeight: 9,
    earInnerWidth: 7,
    earInnerHeight: 8,
    eyeRadiusX: 10,
    eyeRadiusY: 13,
    browOffsetY: -54,
    browWidth: 20,
    muzzleWidth: 32,
    muzzleHeight: 20,
    displayScale: 1.45,
    armWidthScale: 1.1,
    legWidthScale: 1.1,
    markings: _lionMarkings,
  );

  /// The perpetually startled speedster: small head, lean build, and eyes
  /// blown up to saucer size around pinprick pupils with eyebrows shot
  /// halfway up its forehead — a permanent "did I just see a bus?" face.
  static const cheetah = CatSpeciesSpec(
    name: 'cheetah',
    palette: kCheetahPalette,
    headWidth: 60,
    headHeight: 58,
    earBaseWidth: 22,
    earBaseHeight: 28,
    earTipWidth: 6,
    earTipHeight: 14,
    earInnerWidth: 10,
    earInnerHeight: 12,
    eyeOffsetX: 17,
    eyeRadiusX: 15,
    eyeRadiusY: 17,
    pupilRadius: 4,
    browOffsetY: -58,
    browWidth: 12,
    muzzleWidth: 30,
    muzzleHeight: 22,
    displayScale: 1.05,
    armWidthScale: 0.8,
    legWidthScale: 0.8,
    markings: _cheetahMarkings,
  );
}
