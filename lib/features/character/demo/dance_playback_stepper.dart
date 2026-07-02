import 'package:dancing_cats/features/character/demo/dance_camera_director.dart';
import 'package:dancing_cats/features/character/demo/dance_camera_rig.dart';
import 'package:dancing_cats/features/character/demo/dance_lip_sync.dart';
import 'package:dancing_cats/features/character/demo/dance_performance.dart';
import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/face.dart';
import 'package:dancing_cats/features/character/runtime/dance_timing.dart';
import 'package:dancing_cats/features/character/samples/cat_in_suit.dart';

/// The stateful, history-dependent half of one dance frame: the singing mouths
/// (eased) and the virtual camera (smoothed — slow dollies with fast accent
/// punches). The pure half — which move, the warped clock, the beat, the
/// director context — is [DancePerformance].
///
/// Both the live player and every offline renderer own one stepper and call
/// [advance] once per frame, so the per-frame orchestration (voice gating →
/// mouth ease → stage → director → camera glide/punch) is a single code path
/// that cannot drift between them. Because the camera and mouths integrate over `dt`, an
/// offline renderer must **preroll** (advance without rendering) from a lead-in
/// before the first frame it cares about to settle the framing.
class DancePlaybackStepper {
  final DanceCameraRig _cameraRig = DanceCameraRig();

  double _leadMouth = 0;
  double _bgMouth = 0;
  MouthShape _leadShape = MouthShape.singAh;
  MouthShape _bgShape = MouthShape.singAh;
  Shot _shot = (zoom: 1, dx: 0, dy: 0);
  DanceStage? _stage;
  DanceStage? _rawStage;
  _DanceStageTransition? _transition;

  /// How far open the frontman's mouth is (0 = shut), eased toward the cue.
  double get leadMouth => _leadMouth;

  /// How far open the backups' mouths are.
  double get bgMouth => _bgMouth;

  /// The frontman's current viseme.
  MouthShape get leadShape => _leadShape;

  /// The backups' current viseme.
  MouthShape get bgShape => _bgShape;

  /// The framing the camera rig has settled on.
  Shot get shot => _shot;

  /// The stage from the most recent [advance] (null before the first call).
  DanceStage? get stage => _stage;

  /// Advances the mouths and camera by [dt] seconds at audio position [pos].
  ///
  /// [perf] is null before the track loads — the trio then idles and the camera
  /// holds. [cues] is the Rhubarb lip-sync track (empty → mouths rest).
  void advance(
    DancePerformance? perf,
    List<DanceCue> cues,
    double pos,
    double dt,
  ) {
    final cue = mouthForCue(cueShapeAt(cues, pos));
    final words = perf?.words ?? const <DanceWord>[];
    // No lyrics → the frontman lip-syncs every cue; otherwise only on lead words.
    final leadOn =
        words.isEmpty ||
        (perf?.voiceActive(pos, (w) => w.voice == 'lead') ?? false);
    // The backups sing background ad-libs, and join the lead on group hooks.
    final bgOn =
        perf?.voiceActive(
          pos,
          (w) =>
              w.voice == 'background' ||
              (w.voice == 'lead' && kGroupSections.contains(w.section)),
        ) ??
        false;
    if (leadOn) _leadShape = cue.shape;
    if (bgOn) _bgShape = cue.shape;
    _leadMouth = easeDanceMouth(_leadMouth, leadOn ? cue.open : 0.0, dt);
    _bgMouth = easeDanceMouth(_bgMouth, bgOn ? cue.open : 0.0, dt);

    final rawStage = perf?.stageAt(pos) ?? danceIdleStage(pos);
    final stage = _stageWithTransition(rawStage, dt);
    final ctx = perf?.directorContext(pos, energetic: stage.energetic);
    final target = ctx == null ? _shot : cameraShot(ctx);
    _shot = _cameraRig.update(
      target: target,
      punch: ctx != null && isCameraPunch(ctx),
      dt: dt,
    );
    _stage = stage;
  }

  DanceStage _stageWithTransition(DanceStage raw, double dt) {
    final previousRaw = _rawStage;
    if (previousRaw == null) {
      _rawStage = raw;
      _transition = null;
      return raw;
    }

    if (_stageSignature(previousRaw) != _stageSignature(raw)) {
      final from = _stage ?? previousRaw;
      _rawStage = raw;
      _transition = _canBlendStages(from, raw)
          ? _DanceStageTransition(from: from, elapsed: 0)
          : null;
      if (_transition == null) return raw;
    } else {
      _rawStage = raw;
    }

    final transition = _transition;
    if (transition == null) return raw;

    final elapsed = transition.elapsed + dt;
    // Dance↔dance keeps the tight window (hits survive); easing into or out
    // of REST takes a longer, calmer settle.
    final window = transition.from.energetic && raw.energetic
        ? kDanceMoveTransitionSeconds
        : kDanceRestTransitionSeconds;
    if (elapsed >= window) {
      _transition = null;
      return raw;
    }
    _transition = transition.withElapsed(elapsed);
    final weight = smoothstep(elapsed / window);
    return _blendStage(from: transition.from, to: raw, weight: weight);
  }
}

/// The short window used when one catalogue move changes to another.
///
/// It is intentionally less than half a beat at 120 BPM: long enough to remove
/// robotic pose cuts, short enough to preserve Afrobeats hits and foot plants.
const double kDanceMoveTransitionSeconds = 0.18;

/// The longer settle used when the trio eases into or out of REST (idle):
/// nothing musical to preserve there, and a calm body change reads better.
const double kDanceRestTransitionSeconds = 0.45;

const _bodyBlendWindow = ClipBlendWindow(end: 0.72);
const _shoulderBlendWindow = ClipBlendWindow(start: 0.06, end: 0.88);
const _armBlendWindow = ClipBlendWindow(start: 0.12, end: 0.96);
const _secondaryBlendWindow = ClipBlendWindow(start: 0.24);
const _footBlendWindow = ClipBlendWindow(end: 0.7);
const _handTargetBlendWindow = ClipBlendWindow(start: 0.14);

/// Dance transitions layer the incoming move instead of replacing every track
/// on the same tick. Weight-bearing body/feet settle first, arm targets arrive
/// through the middle, and secondary parts follow last.
const _danceMoveBlendMask = ClipBlendMask(
  root: _bodyBlendWindow,
  joints: {
    CatBones.hips: _bodyBlendWindow,
    CatBones.torso: _bodyBlendWindow,
    CatBones.clavicleL: _shoulderBlendWindow,
    CatBones.clavicleR: _shoulderBlendWindow,
    CatBones.shoulderSocketL: _shoulderBlendWindow,
    CatBones.shoulderSocketR: _shoulderBlendWindow,
    CatBones.armBicepL: _shoulderBlendWindow,
    CatBones.armBicepR: _shoulderBlendWindow,
    CatBones.armUpperL: _armBlendWindow,
    CatBones.armUpperR: _armBlendWindow,
    CatBones.armLowerL: _armBlendWindow,
    CatBones.armLowerR: _armBlendWindow,
    CatBones.armForearmL: _armBlendWindow,
    CatBones.armForearmR: _armBlendWindow,
    CatBones.handL: _armBlendWindow,
    CatBones.handR: _armBlendWindow,
    CatBones.legUpperL: _footBlendWindow,
    CatBones.legUpperR: _footBlendWindow,
    CatBones.legLowerL: _footBlendWindow,
    CatBones.legLowerR: _footBlendWindow,
    CatBones.footL: _footBlendWindow,
    CatBones.footR: _footBlendWindow,
    CatBones.earL: _secondaryBlendWindow,
    CatBones.earR: _secondaryBlendWindow,
    CatBones.tail0: _secondaryBlendWindow,
    CatBones.tail1: _secondaryBlendWindow,
    CatBones.tail2: _secondaryBlendWindow,
    CatBones.tail3: _secondaryBlendWindow,
    CatBones.tail4: _secondaryBlendWindow,
    CatBones.tail5: _secondaryBlendWindow,
    CatBones.tail6: _secondaryBlendWindow,
    CatBones.tie: _secondaryBlendWindow,
    CatBones.tieLower: _secondaryBlendWindow,
  },
  limbTargets: {
    CatBones.handL: _handTargetBlendWindow,
    CatBones.handR: _handTargetBlendWindow,
    CatBones.footL: _footBlendWindow,
    CatBones.footR: _footBlendWindow,
  },
);

class _DanceStageTransition {
  const _DanceStageTransition({required this.from, required this.elapsed});

  final DanceStage from;
  final double elapsed;

  _DanceStageTransition withElapsed(double value) =>
      _DanceStageTransition(from: from, elapsed: value);
}

String _stageSignature(DanceStage stage) => [
  stage.lead.name,
  for (final clip in stage.ensemble) clip.name,
].join('|');

bool _canBlendStages(DanceStage from, DanceStage to) =>
    // Blending needs matching member counts; everything else crossfades.
    // Idle↔dance and duration-mismatched stages used to HARD-CUT here — the
    // blended clip samples both sources at the shared phase, so a duration
    // mismatch only means the outgoing pose drifts speed slightly during the
    // short window, which reads far better than a pose snap.
    from.ensemble.length == to.ensemble.length;

DanceStage _blendStage({
  required DanceStage from,
  required DanceStage to,
  required double weight,
}) => (
  lead: blendedClip(
    from: from.lead,
    to: to.lead,
    weight: weight,
    name: '${from.lead.name}->${to.lead.name}',
    blendMask: _danceMoveBlendMask,
  ),
  ensemble: [
    for (var i = 0; i < to.ensemble.length; i++)
      blendedClip(
        from: from.ensemble[i],
        to: to.ensemble[i],
        weight: weight,
        name: '${from.ensemble[i].name}->${to.ensemble[i].name}',
        blendMask: _danceMoveBlendMask,
      ),
  ],
  seconds: to.seconds,
  section: to.section,
  energetic: to.energetic,
  synchronous: to.synchronous,
);
