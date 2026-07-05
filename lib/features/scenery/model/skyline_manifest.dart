import 'dart:ui' show Offset, Rect;

/// Normalized (0..1) anchor geometry for the structural bitmap layers, used by
/// the runtime light/props layer to pin windows, beacons, police sweeps and
/// vessel lights onto the painted art.
///
/// Coordinates are fractions of the artwork canvas (origin top-left, y down),
/// so they scale to any render size. This is the **contract** between the
/// Codex-authored artwork (`assets/scenery/*.webp`) and the runtime: the
/// generator that draws the bitmap assets emits a matching const so the two cannot
/// drift. The placeholder [kPlaceholderSkylineManifest] below lets the runtime
/// compile and be exercised before the real art lands; Codex replaces it with
/// art-derived values.
class SkylineManifest {
  const SkylineManifest({
    required this.buildingTops,
    required this.windowCells,
    required this.bridgeTowerTops,
    required this.bridgeDeck,
    required this.yachtCabin,
    required this.yachtNavLights,
    required this.waterline,
  });

  /// Apex point of each tall building (aircraft beacons + roof lights).
  final List<Offset> buildingTops;

  /// Rects where lit windows may be drawn (one per building face / grid block).
  final List<Rect> windowCells;

  /// The two bridge-tower tops (aircraft beacons).
  final List<Offset> bridgeTowerTops;

  /// Polyline of the bridge deck, left→right (police-light sweeps travel it).
  final List<Offset> bridgeDeck;

  /// Rect of the yacht's cabin block (warm interior windows).
  final Rect yachtCabin;

  /// Yacht navigation lights — bow (port), bow (starboard), masthead/stern.
  final List<Offset> yachtNavLights;

  /// Normalized y of the horizon / waterline.
  final double waterline;
}

/// A coarse stand-in until the Codex-generated, art-matched manifest replaces
/// it. Values are plausible but not tied to any real artwork.
const SkylineManifest kPlaceholderSkylineManifest = SkylineManifest(
  // Measured against assets/scenery/blue_hour_cloudless.webp (2560x1440,
  // 2026-07 plate) — each anchor sits on the HIGHEST painted point of its
  // tower (antenna/spire tip or roof ridge), left→right: antenna tower,
  // spired tower (needle tip), pyramid-top tower, dark canopy-roof tower,
  // slim antenna tower.
  buildingTops: [
    Offset(0.1652, 0.2800),
    Offset(0.2078, 0.2220),
    Offset(0.2533, 0.3405),
    Offset(0.3457, 0.3240),
    Offset(0.4273, 0.3445),
  ],
  windowCells: [
    Rect.fromLTWH(0.10, 0.47, 0.05, 0.13),
    Rect.fromLTWH(0.20, 0.41, 0.045, 0.18),
    Rect.fromLTWH(0.32, 0.50, 0.05, 0.10),
    Rect.fromLTWH(0.44, 0.37, 0.05, 0.22),
    Rect.fromLTWH(0.56, 0.45, 0.05, 0.14),
    Rect.fromLTWH(0.69, 0.42, 0.05, 0.17),
    Rect.fromLTWH(0.82, 0.48, 0.05, 0.11),
  ],
  // The two mast tips of the cable-stayed bridge A-frame pylon.
  bridgeTowerTops: [
    Offset(0.6438, 0.3542),
    Offset(0.6566, 0.3590),
  ],
  // Railing-top line of the cable-stayed roadway (the visible deck edge from
  // this below-deck camera), essentially level across the span with a slight
  // rise to the right.
  bridgeDeck: [
    Offset(0.43, 0.4660),
    Offset(0.555, 0.4648),
    Offset(0.65, 0.4645),
    Offset(0.745, 0.4640),
    Offset(1, 0.4630),
  ],
  yachtCabin: Rect.fromLTWH(0.55, 0.66, 0.07, 0.03),
  yachtNavLights: [
    Offset(0.535, 0.675),
    Offset(0.625, 0.675),
    Offset(0.58, 0.645),
  ],
  // The painted lagoon meets the far shore here (matches the city-lights
  // shader's kWaterline and the window-bake BAND_BOTTOM). The animated ocean
  // band runs from this line down to the art bottom, so foam covers the whole
  // VISIBLE lagoon between the far shore and the deck — not just a thin strip
  // near the deck that the foreground planks then hide.
  waterline: 0.515,
);
