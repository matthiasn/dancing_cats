import 'package:dancing_cats/features/character/model/bone.dart';
import 'package:dancing_cats/features/character/model/rig_spec.dart';

/// One cross-section of a trunk surface: a horizontal slice of the body at
/// [y] (rest-world), [halfWidth] wide, ridden by [boneId].
///
/// A trunk surface is authored as a short list of these stations (hem → waist
/// → ribs → armhole for a jacket) instead of a cloud of hand-placed weighted
/// vertices. [buildTrunkSurface] turns the list into a [SkinnedMeshSpec],
/// deriving every vertex position and every skin weight from the stations and
/// the rig's rest pose — so the silhouette is retuned by editing a width
/// table, and ANY pose deforms it consistently (the failure mode this replaces
/// was hand-tuned weights that only looked right in the poses they were tuned
/// against).
class TrunkStation {
  const TrunkStation({
    required this.boneId,
    required this.y,
    required this.halfWidth,
    this.x = 0,
  });

  /// The spine bone this slice primarily follows.
  final String boneId;

  /// Rest-world centre of the slice.
  final double x;
  final double y;

  final double halfWidth;
}

/// Builds a skinned trunk surface from cross-section [stations] (ordered
/// bottom → top).
///
/// Geometry: each station contributes a left and a right boundary vertex at
/// `x ∓ halfWidth`. The boundary walks the left edge bottom→top, crosses the
/// top through the mirrored [crown] polyline (an optional neckline/yoke arch,
/// given as rest-world points for the LEFT side from outer to centre), and
/// returns down the right edge — one closed loop the renderer smooths.
///
/// Skinning: a station's vertices weight [neighborShare] of themselves onto
/// the adjacent stations' bones (half up, half down; edge stations give the
/// whole share to their one neighbour). Same-bone influences merge, so
/// consecutive stations on one bone simply ride it harder. Every influence's
/// local coordinates are derived from the bone's rest-world origin, computed
/// by walking the parent chain — nothing is hand-placed.
SkinnedMeshSpec buildTrunkSurface({
  required String id,
  required List<Bone> bones,
  required List<TrunkStation> stations,
  required int z,
  required int color,
  List<({double x, double y})> crown = const [],
  List<Map<String, double>>? crownWeights,
  List<Map<String, double>>? crownWeightsMirrored,
  double neighborShare = 0.4,
  int? outlineColor,
  double outlineWidth = 0,
  bool formRound = false,
  double boundaryCornerSmoothing = 0.22,
  List<String> hiddenBoneIds = const [],
  String? shadeGroup,
  double crownSeamWidth = 0,
  int? crownSeamZ,
  ({double x, double y})? crownSeamTip,
  Map<String, double>? crownSeamTipWeights,
  Map<String, double>? crownSeamTipWeightsMirrored,
}) {
  assert(stations.length >= 2, 'a trunk surface needs at least two stations');
  final origins = _restWorldOrigins(bones);

  SkinnedMeshVertex vertexAt(
    double worldX,
    double worldY,
    Map<String, double> weightsByBone,
  ) {
    final influences = <MeshInfluence>[];
    weightsByBone.forEach((boneId, weight) {
      final origin = origins[boneId];
      if (origin == null) {
        throw ArgumentError(
          'Trunk surface "$id" references missing bone "$boneId"',
        );
      }
      influences.add(
        MeshInfluence(
          boneId: boneId,
          x: worldX - origin.x,
          y: worldY - origin.y,
          weight: weight,
        ),
      );
    });
    return SkinnedMeshVertex(influences);
  }

  Map<String, double> stationWeights(int i) {
    final weights = <String, double>{};
    void add(String boneId, double weight) {
      if (weight <= 0) return;
      weights.update(boneId, (w) => w + weight, ifAbsent: () => weight);
    }

    final below = i > 0 ? stations[i - 1].boneId : null;
    final above = i < stations.length - 1 ? stations[i + 1].boneId : null;
    final neighbours = [?below, ?above];
    add(stations[i].boneId, 1 - neighborShare);
    for (final neighbour in neighbours) {
      add(neighbour, neighborShare / neighbours.length);
    }
    return weights;
  }

  final vertices = <SkinnedMeshVertex>[];
  final boundary = <int>[];

  // Left edge, bottom → top.
  for (var i = 0; i < stations.length; i++) {
    final s = stations[i];
    boundary.add(vertices.length);
    vertices.add(vertexAt(s.x - s.halfWidth, s.y, stationWeights(i)));
  }
  // Crown arch across the top: out→centre on the left, mirrored centre→out on
  // the right. By default crown points ride the top station's bone; passing
  // [crownWeights] (left side, same order as [crown]) and
  // [crownWeightsMirrored] (right side, in the REVERSED traversal order)
  // lets a yoke's outer corners ride the shoulder girdle too — so a shrug
  // lifts the trapezius line with the deltoid instead of opening a valley
  // between the raised shoulder and the collar.
  assert(
    crownWeights == null || crownWeights.length == crown.length,
    'crownWeights must match crown length',
  );
  assert(
    crownWeightsMirrored == null || crownWeightsMirrored.length == crown.length,
    'crownWeightsMirrored must match crown length',
  );
  final topWeights = stationWeights(stations.length - 1);
  for (var i = 0; i < crown.length; i++) {
    final point = crown[i];
    boundary.add(vertices.length);
    vertices.add(vertexAt(point.x, point.y, crownWeights?[i] ?? topWeights));
  }
  for (var i = 0; i < crown.length; i++) {
    final point = crown[crown.length - 1 - i];
    boundary.add(vertices.length);
    vertices.add(
      vertexAt(-point.x, point.y, crownWeightsMirrored?[i] ?? topWeights),
    );
  }
  // Right edge, top → bottom.
  for (var i = stations.length - 1; i >= 0; i--) {
    final s = stations[i];
    boundary.add(vertices.length);
    vertices.add(vertexAt(s.x + s.halfWidth, s.y, stationWeights(i)));
  }

  // The crown as DRAWN SHOULDER SEAMS (when [crownSeamWidth] > 0): the
  // tailoring line over the yoke to the collar point. With a [crownSeamTip]
  // the seam STARTS at that extra skinned vertex — authored to sit on the
  // shoulder's outer silhouette edge and weighted to the girdle so it stays
  // welded there through a shrug — making the seam ONE stroke that leaves
  // the body outline, instead of a floating line ending mid-cloth. Without a
  // tip it starts at the top station vertex (the armhole edge).
  final rightCrownStart = stations.length + crown.length;
  int? tipLeftIndex;
  int? tipRightIndex;
  if (crownSeamTip != null) {
    tipLeftIndex = vertices.length;
    vertices.add(
      vertexAt(
        crownSeamTip.x,
        crownSeamTip.y,
        crownSeamTipWeights ?? stationWeights(stations.length - 1),
      ),
    );
    tipRightIndex = vertices.length;
    vertices.add(
      vertexAt(
        -crownSeamTip.x,
        crownSeamTip.y,
        crownSeamTipWeightsMirrored ??
            crownSeamTipWeights ??
            stationWeights(stations.length - 1),
      ),
    );
  }
  final leftSeam = [
    tipLeftIndex ?? stations.length - 1,
    for (var i = 0; i < crown.length; i++) stations.length + i,
  ];
  // Right-side crown vertices were emitted centre-first (the mirrored
  // reversed walk), so the chain runs tip/armhole first, then crown indices
  // from LAST (outer corner) down to FIRST (collar point).
  final rightSeam = [
    tipRightIndex ?? rightCrownStart + crown.length,
    for (var i = crown.length - 1; i >= 0; i--) rightCrownStart + i,
  ];

  return SkinnedMeshSpec(
    id: id,
    vertices: vertices,
    boundary: boundary,
    hiddenBoneIds: hiddenBoneIds,
    z: z,
    color: color,
    outlineColor: outlineColor,
    outlineWidth: outlineWidth,
    formRound: formRound,
    boundaryCornerSmoothing: boundaryCornerSmoothing,
    shadeGroup: shadeGroup,
    inkSeams: crownSeamWidth > 0 && crown.isNotEmpty
        ? [leftSeam, rightSeam]
        : const [],
    inkSeamWidth: crownSeamWidth,
    inkSeamZ: crownSeamZ,
  );
}

/// Rest-world origin of every bone, by accumulating pivots up the parent
/// chain. Trunk chains must be rest-neutral (no rest rotation/scale) for the
/// accumulation to hold; bones that are not (tail links, ears) simply must not
/// be referenced by a [TrunkStation].
Map<String, ({double x, double y})> _restWorldOrigins(List<Bone> bones) {
  final byId = {for (final bone in bones) bone.id: bone};
  final cache = <String, ({double x, double y})>{};

  ({double x, double y}) originOf(Bone bone) {
    final cached = cache[bone.id];
    if (cached != null) return cached;
    final parent = bone.parent == null ? null : byId[bone.parent];
    final parentOrigin = parent == null ? (x: 0.0, y: 0.0) : originOf(parent);
    final origin = (
      x: parentOrigin.x + bone.pivotX,
      y: parentOrigin.y + bone.pivotY,
    );
    cache[bone.id] = origin;
    return origin;
  }

  bones.forEach(originOf);
  return cache;
}
