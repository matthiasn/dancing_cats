/// A hand-authored "cat in a suit" rig + cycle library.
///
/// This is the Phase-1 stand-in for the offline AI rigging step: it exercises
/// the engine and the film-strip pipeline with a real, characterful skeleton
/// before any AI rig inference exists. Coordinates use Flutter's y-down space,
/// the hips at the origin, "up" toward negative y. Units are roughly pixels at
/// the authoring scale (~210 tall).
library;

import 'dart:math' as math;

import 'package:dancing_cats/features/character/model/afrobeats_move.dart';
import 'package:dancing_cats/features/character/model/bone.dart';
import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/dance_dynamics.dart';
import 'package:dancing_cats/features/character/model/dance_move_compiler.dart';
import 'package:dancing_cats/features/character/model/dance_move_descriptor.dart';
import 'package:dancing_cats/features/character/model/dance_pose_cell.dart';
import 'package:dancing_cats/features/character/model/dance_phrase.dart';
import 'package:dancing_cats/features/character/model/easing.dart';
import 'package:dancing_cats/features/character/model/face.dart';
import 'package:dancing_cats/features/character/model/rig_spec.dart';
import 'package:dancing_cats/features/character/model/trunk_surface.dart';

part 'cat_in_suit_rig.dart';
part 'moves/buga_data.dart';
part 'moves/moving_groove_data.dart';
part 'moves/shaku_data.dart';
part 'moves/zanku_data.dart';
part 'moves/azonto_data.dart';
part 'moves/pouncing_cat_data.dart';
part 'moves/sekem_data.dart';
part 'moves/shared_groove_data.dart';

/// The Phase-1 clip library: show-focused cat-in-suit performance clips.
class CatClips {
  /// The shared beat-addressed phrase every dance clip's choreography is
  /// authored against (see `dance_phrase.dart`).
  static DancePhrase get dancePhrase => _dancePhrase;

  /// Standalone "Kick" catalog move — a one-shot high side kick, phase-
  /// authored directly (no `DancePhrase` frame addressing, since it's a
  /// single held pose-to-pose beat rather than a looping groove). Assembled
  /// through `assembleMoveClip` via the `rawRoot`/`extraJointChannels`
  /// escape hatches, since none of its channels are frame-keyed.
  static Clip get kick => assembleMoveClip(
    _dancePhrase,
    const DanceMoveDescriptor(
      move: AfrobeatsMove(
        name: 'kick',
        feel: DanceFeel.onBeat,
        featuredRegion: BodyRegion.legs,
      ),
      duration: 1,
      loop: false,
      rawContactSpans: [GroundSpan(CatBones.footL, 0, 1)],
      // Anticipate down, chamber, snap a high side kick, then recoil and
      // settle. No locomotion: this is a stage move in place, so the
      // support foot stays readable while the silhouette carries the
      // action.
      rawRoot: KeyframeRootChannel([
        RootKeyframe(p: 0),
        RootKeyframe(
          p: 0.1,
          dy: 16,
          dx: -7,
          rotation: 0.03,
          ease: Ease.easeOut,
        ),
        RootKeyframe(p: 0.22, dy: 12, dx: -14, rotation: -0.02),
        RootKeyframe(
          p: 0.3,
          dy: -11,
          dx: -19,
          rotation: -0.07,
          ease: Ease.easeOut,
        ),
        RootKeyframe(p: 0.4, dy: -10, dx: -19, rotation: -0.065),
        RootKeyframe(
          p: 0.52,
          dy: 8,
          dx: -12,
          rotation: 0.02,
          ease: Ease.easeIn,
        ),
        RootKeyframe(
          p: 0.68,
          dy: 4,
          dx: -5,
          rotation: 0.01,
          ease: Ease.easeOut,
        ),
        RootKeyframe(p: 0.82, dy: -2, dx: -1, rotation: -0.005),
        RootKeyframe(p: 1),
      ]),
      extraJointChannels: {
        // Support leg loads visibly under the body so the kick has a base.
        CatBones.legUpperL: KeyframeChannel([
          Keyframe(p: 0, rotation: 0.04),
          Keyframe(p: 0.12, rotation: 0.44),
          Keyframe(p: 0.22, rotation: 0.56),
          Keyframe(p: 0.3, rotation: 0.48),
          Keyframe(p: 0.4, rotation: 0.46),
          Keyframe(p: 0.52, rotation: 0.24),
          Keyframe(p: 0.68, rotation: 0.12),
          Keyframe(p: 1, rotation: 0.04, ease: Ease.easeOutBack),
        ]),
        CatBones.legLowerL: KeyframeChannel([
          Keyframe(p: 0, rotation: -0.12),
          Keyframe(p: 0.12, rotation: -0.82),
          Keyframe(p: 0.22, rotation: -0.96),
          Keyframe(p: 0.3, rotation: -0.78),
          Keyframe(p: 0.4, rotation: -0.72),
          Keyframe(p: 0.52, rotation: -0.42),
          Keyframe(p: 0.68, rotation: -0.24),
          Keyframe(p: 1, rotation: -0.12, ease: Ease.easeOutBack),
        ]),
        CatBones.footL: KeyframeChannel([
          Keyframe(p: 0, rotation: -0.08),
          Keyframe(p: 0.12, rotation: -0.46),
          Keyframe(p: 0.22, rotation: -0.52),
          Keyframe(p: 0.3, rotation: -0.5),
          Keyframe(p: 0.4, rotation: -0.46),
          Keyframe(p: 0.52, rotation: -0.24),
          Keyframe(p: 0.68, rotation: -0.12),
          Keyframe(p: 1, rotation: -0.08),
        ]),

        // Far/right leg performs a high side kick: knee chamber, clean extension,
        // brief hold, then a visible recoil. Negative thigh rotation points it out
        // to the cat's right; the shin stays nearly aligned for a clean strike.
        CatBones.legUpperR: KeyframeChannel([
          Keyframe(p: 0, rotation: 0.08),
          Keyframe(p: 0.12, rotation: 0.7, ease: Ease.easeIn),
          Keyframe(p: 0.22, rotation: 1.16),
          Keyframe(p: 0.3, rotation: -1.82, ease: Ease.easeOutBack),
          Keyframe(p: 0.4, rotation: -1.76),
          Keyframe(p: 0.52, rotation: 0.92, ease: Ease.easeIn),
          Keyframe(p: 0.68, rotation: 0.28),
          Keyframe(p: 1, rotation: 0.08, ease: Ease.easeOutBack),
        ]),
        CatBones.legLowerR: KeyframeChannel([
          Keyframe(p: 0, rotation: -0.18),
          Keyframe(p: 0.12, rotation: -1.18, ease: Ease.easeIn),
          Keyframe(p: 0.22, rotation: -1.7),
          Keyframe(p: 0.3, rotation: 0.02, ease: Ease.easeOut),
          Keyframe(p: 0.4),
          Keyframe(p: 0.52, rotation: -1.5, ease: Ease.easeIn),
          Keyframe(p: 0.68, rotation: -0.66),
          Keyframe(p: 1, rotation: -0.18, ease: Ease.easeOutBack),
        ]),
        CatBones.footR: KeyframeChannel([
          Keyframe(p: 0, rotation: -0.08),
          Keyframe(p: 0.22, rotation: 0.28),
          Keyframe(p: 0.3, rotation: 0.9),
          Keyframe(p: 0.4, rotation: 0.82),
          Keyframe(p: 0.52, rotation: 0.16),
          Keyframe(p: 0.68, rotation: -0.02),
          Keyframe(p: 1, rotation: -0.08, ease: Ease.easeOutBack),
        ]),

        CatBones.hips: KeyframeChannel([
          Keyframe(p: 0),
          Keyframe(p: 0.12, rotation: 0.28),
          Keyframe(p: 0.22, rotation: 0.48),
          Keyframe(p: 0.3, rotation: 0.72),
          Keyframe(p: 0.4, rotation: 0.64),
          Keyframe(p: 0.58, rotation: -0.12),
          Keyframe(p: 0.72, rotation: 0.08),
          Keyframe(p: 1, ease: Ease.easeOutBack),
        ]),
        CatBones.torso: KeyframeChannel([
          Keyframe(p: 0),
          Keyframe(p: 0.12, rotation: -0.18, scaleY: 0.92, scaleX: 1.05),
          Keyframe(p: 0.22, rotation: -0.28, scaleY: 0.94, scaleX: 1.04),
          Keyframe(p: 0.3, rotation: -0.54, scaleY: 1.08, scaleX: 0.955),
          Keyframe(p: 0.4, rotation: -0.48, scaleY: 1.055, scaleX: 0.965),
          Keyframe(p: 0.58, rotation: 0.12),
          Keyframe(p: 0.72, rotation: -0.04),
          Keyframe(p: 1, ease: Ease.easeOutBack),
        ]),
        CatBones.neck: KeyframeChannel([
          Keyframe(p: 0),
          Keyframe(p: 0.12, rotation: -0.11),
          Keyframe(p: 0.22, rotation: -0.15),
          Keyframe(p: 0.3, rotation: -0.095),
          Keyframe(p: 0.4, rotation: -0.08),
          Keyframe(p: 0.58, rotation: -0.015),
          Keyframe(p: 0.72, rotation: -0.035),
          Keyframe(p: 1, ease: Ease.easeOut),
        ]),
        CatBones.head: KeyframeChannel([
          Keyframe(p: 0),
          Keyframe(p: 0.12, rotation: -0.02),
          Keyframe(p: 0.22, rotation: -0.03),
          Keyframe(p: 0.3, rotation: -0.015),
          Keyframe(p: 0.4, rotation: -0.015),
          Keyframe(p: 0.58, rotation: -0.004),
          Keyframe(p: 0.72, rotation: -0.01),
          Keyframe(p: 1, ease: Ease.easeOut),
        ]),

        // Counterbalancing arms: one guards high while the other pulls back, so
        // the hands stop merging at the hips and the strike has intent.
        CatBones.armUpperL: KeyframeChannel([
          Keyframe(p: 0, rotation: 0.08),
          Keyframe(p: 0.16, rotation: 0.7),
          Keyframe(p: 0.32, rotation: 0.98),
          Keyframe(p: 0.42, rotation: 0.9),
          Keyframe(p: 0.66, rotation: 0.4),
          Keyframe(p: 1, rotation: 0.08, ease: Ease.easeOutBack),
        ]),
        CatBones.armLowerL: KeyframeChannel([
          Keyframe(p: 0, rotation: 0.08),
          Keyframe(p: 0.16, rotation: -0.45),
          Keyframe(p: 0.32, rotation: -0.72),
          Keyframe(p: 0.42, rotation: -0.62),
          Keyframe(p: 0.66, rotation: -0.24),
          Keyframe(p: 1, rotation: 0.08, ease: Ease.easeOutBack),
        ]),
        CatBones.armUpperR: KeyframeChannel([
          Keyframe(p: 0, rotation: -0.08),
          Keyframe(p: 0.16, rotation: -0.34),
          Keyframe(p: 0.32, rotation: -0.68),
          Keyframe(p: 0.42, rotation: -0.6),
          Keyframe(p: 0.66, rotation: -0.14),
          Keyframe(p: 1, rotation: -0.08, ease: Ease.easeOutBack),
        ]),
        CatBones.armLowerR: KeyframeChannel([
          Keyframe(p: 0, rotation: -0.08),
          Keyframe(p: 0.16, rotation: 0.55),
          Keyframe(p: 0.32, rotation: 0.85),
          Keyframe(p: 0.42, rotation: 0.75),
          Keyframe(p: 0.66, rotation: 0.3),
          Keyframe(p: 1, rotation: -0.08, ease: Ease.easeOutBack),
        ]),

        // Costume and tail follow the snap.
        CatBones.tie: KeyframeChannel([
          Keyframe(p: 0),
          Keyframe(p: 0.3, rotation: 0.16, ease: Ease.easeOut),
          Keyframe(p: 0.42, rotation: 0.09),
          Keyframe(p: 0.6, rotation: -0.08, ease: Ease.easeIn),
          Keyframe(p: 1, ease: Ease.easeOutBack),
        ]),
        CatBones.tieLower: KeyframeChannel([
          Keyframe(p: 0),
          Keyframe(p: 0.3, rotation: 0.08, ease: Ease.easeOut),
          Keyframe(p: 0.42, rotation: 0.035),
          Keyframe(p: 0.6, rotation: -0.045, ease: Ease.easeIn),
          Keyframe(p: 1, ease: Ease.easeOutBack),
        ]),
        CatBones.tail0: KeyframeChannel([
          Keyframe(p: 0),
          Keyframe(p: 0.3, rotation: 0.18),
          Keyframe(p: 0.42, rotation: 0.1),
          Keyframe(p: 0.6, rotation: -0.08),
          Keyframe(p: 1, ease: Ease.easeOutBack),
        ]),
        CatBones.tail1: KeyframeChannel([
          Keyframe(p: 0),
          Keyframe(p: 0.3, rotation: 0.24),
          Keyframe(p: 0.42, rotation: 0.16),
          Keyframe(p: 0.6, rotation: -0.1),
          Keyframe(p: 1, ease: Ease.easeOutBack),
        ]),
        CatBones.tail2: KeyframeChannel([
          Keyframe(p: 0),
          Keyframe(p: 0.3, rotation: 0.3),
          Keyframe(p: 0.42, rotation: 0.2),
          Keyframe(p: 0.6, rotation: -0.12),
          Keyframe(p: 1, ease: Ease.easeOutBack),
        ]),
        CatBones.tail3: KeyframeChannel([
          Keyframe(p: 0),
          Keyframe(p: 0.3, rotation: 0.38),
          Keyframe(p: 0.42, rotation: 0.24),
          Keyframe(p: 0.6, rotation: -0.16),
          Keyframe(p: 1, ease: Ease.easeOutBack),
        ]),
        CatBones.tail4: KeyframeChannel([
          Keyframe(p: 0),
          Keyframe(p: 0.3, rotation: 0.5),
          Keyframe(p: 0.42, rotation: 0.34),
          Keyframe(p: 0.6, rotation: -0.22),
          Keyframe(p: 1, ease: Ease.easeOutBack),
        ]),
        CatBones.tail5: KeyframeChannel([
          Keyframe(p: 0),
          Keyframe(p: 0.3, rotation: 0.62),
          Keyframe(p: 0.42, rotation: 0.42),
          Keyframe(p: 0.6, rotation: -0.28),
          Keyframe(p: 1, ease: Ease.easeOutBack),
        ]),
        CatBones.tail6: KeyframeChannel([
          Keyframe(p: 0),
          Keyframe(p: 0.3, rotation: 0.74),
          Keyframe(p: 0.42, rotation: 0.5),
          Keyframe(p: 0.6, rotation: -0.34),
          Keyframe(p: 1, ease: Ease.easeOutBack),
        ]),
      },
    ),
  );

  /// The shared groove every catalog move builds on (`baseClip:` in each
  /// move's `DanceMoveDescriptor`) — the two-step hip lead / chest counter
  /// / Gbese toe-flick base cycle. Assembled through `assembleMoveClip`
  /// (`dance_move_compiler.dart`) from its authored key data.
  static Clip get _danceBase => assembleMoveClip(
    _dancePhrase,
    DanceMoveDescriptor(
      move: const AfrobeatsMove(
        name: '_danceBase',
        feel: DanceFeel.onBeat,
        featuredRegion: BodyRegion.full,
      ),
      duration: 6,
      contactPinning: ContactPinning.lowestContact,
      supports: _dancePhrase.supports,
      jointTracks: {
        CatBones.legUpperL: const DanceJointTrack(
          _danceLegUpperLKeys,
          smooth: true,
        ),
        CatBones.legUpperR: const DanceJointTrack(
          _danceLegUpperRKeys,
          smooth: true,
        ),
        CatBones.legLowerL: const DanceJointTrack(
          _danceLegLowerLKeys,
          smooth: true,
        ),
        CatBones.legLowerR: const DanceJointTrack(
          _danceLegLowerRKeys,
          smooth: true,
        ),
        CatBones.footR: DanceJointTrack(_danceFootRLeadKeys, smooth: true),
      },
      bodyMotion: DanceBodyMotion(
        pelvisBoneId: CatBones.hips,
        chestBoneId: CatBones.torso,
        tracks: [
          const DanceBodyMotionTrack(keys: _danceBodyGrooveKeys),
          DanceBodyMotionTrack(keys: _danceBodyAccentKeys),
        ],
        extraRootLayers: const [
          SineRootChannel(
            bobAmplitude: -0.055,
            bobPhase: 0.125,
            bobHarmonic: 8,
            leanAmplitude: 0.001,
            leanHarmonic: 8,
          ),
          SineRootChannel(
            bobAmplitude: -0.008,
            bobPhase: 0.02,
            bobHarmonic: 16,
            leanAmplitude: 0.0001,
            leanPhase: 0.03,
            leanHarmonic: 16,
          ),
        ],
        extraPelvisLayers: const [
          SineChannel(
            harmonicAmplitude: 0.004,
            harmonicPhase: 0.015,
            harmonicMultiplier: 24,
            scaleXAmplitude: 0.0015,
            scaleXPhase: 0.015,
            scaleXHarmonic: 24,
            scaleYAmplitude: -0.0015,
            scaleYPhase: 0.015,
            scaleYHarmonic: 24,
          ),
        ],
        extraChestLayers: const [
          SineChannel(
            harmonicAmplitude: 0.003,
            harmonicPhase: 0.04,
            harmonicMultiplier: 24,
            scaleXAmplitude: -0.002,
            scaleXPhase: 0.04,
            scaleXHarmonic: 24,
            scaleYAmplitude: 0.002,
            scaleYPhase: 0.04,
            scaleYHarmonic: 24,
          ),
        ],
      ),
      extraJointChannels: {
        CatBones.footL: LayeredJointChannel([
          _dancePhrase.jointChannel(_danceFootLLeadKeys, smooth: true),
          _dancePhrase.jointChannel(_danceFootLAccentKeys, smooth: true),
        ]),
        CatBones.armUpperL: LayeredJointChannel([
          _dancePhrase.jointChannel(_danceArmUpperLLeadKeys, smooth: true),
          const SineChannel(
            harmonicAmplitude: 0.014,
            harmonicPhase: 0.045,
            harmonicMultiplier: 12,
          ),
        ]),
        CatBones.armUpperR: LayeredJointChannel([
          _dancePhrase.jointChannel(_danceArmUpperRLeadKeys, smooth: true),
          const SineChannel(
            harmonicAmplitude: 0.014,
            harmonicPhase: 0.545,
            harmonicMultiplier: 12,
          ),
        ]),
        CatBones.armLowerL: LayeredJointChannel([
          _dancePhrase.jointChannel(_danceArmLowerLLeadKeys, smooth: true),
          const SineChannel(
            harmonicAmplitude: 0.016,
            harmonicPhase: 0.11,
            harmonicMultiplier: 12,
          ),
        ]),
        CatBones.armLowerR: LayeredJointChannel([
          _dancePhrase.jointChannel(_danceArmLowerRLeadKeys, smooth: true),
          const SineChannel(
            harmonicAmplitude: 0.016,
            harmonicPhase: 0.61,
            harmonicMultiplier: 12,
          ),
        ]),
        CatBones.clavicleL: const SineChannel(
          amplitude: 0.012,
          phase: 0.08,
          harmonicAmplitude: 0.02,
          harmonicPhase: 0.03,
          harmonicMultiplier: 8,
          scaleXAmplitude: 0.004,
          scaleXPhase: 0.09,
          scaleXHarmonic: 8,
          scaleYAmplitude: -0.003,
          scaleYPhase: 0.09,
          scaleYHarmonic: 8,
        ),
        CatBones.clavicleR: const SineChannel(
          amplitude: 0.012,
          phase: 0.58,
          harmonicAmplitude: 0.02,
          harmonicPhase: 0.0925,
          harmonicMultiplier: 8,
          scaleXAmplitude: 0.004,
          scaleXPhase: 0.1525,
          scaleXHarmonic: 8,
          scaleYAmplitude: -0.003,
          scaleYPhase: 0.1525,
          scaleYHarmonic: 8,
        ),
        CatBones.neck: const KeyframeChannel(_danceNeckKeys, smooth: true),
        CatBones.head: const KeyframeChannel(_danceHeadKeys, smooth: true),
        CatBones.tie: const KeyframeChannel(_danceTieKeys, smooth: true),
        CatBones.tieLower: const KeyframeChannel(
          _danceTieLowerKeys,
          smooth: true,
        ),
        CatBones.earL: const KeyframeChannel(_danceEarLKeys, smooth: true),
        CatBones.earR: const KeyframeChannel(_danceEarRKeys, smooth: true),
        ..._tailFollowThrough(amplitude: 0.13, phase: 0.04),
      },
    ),
    rigLimbTargets: _danceLimbTargets,
  );

  /// Song-specific groove for Omah Lay's "Moving".
  ///
  /// The catalogue moves are useful quotations, but cutting between viral
  /// signatures from other records made the routine read as a move sampler.
  /// This is the phrase's connective tissue: a relaxed two-beat step-touch,
  /// pelvis-first weight transfer, delayed rib response, and loose
  /// contralateral arms.  It deliberately carries fewer, broader events than
  /// Zanku/Buga so the singer can sit inside the pocket instead of demonstrating
  /// a new pose on every count.
  static Clip get movingGroove => _movingGroove(
    name: 'movingHookLead',
    handLTargets: _movingHookLeadHandLTargetKeys,
    handRTargets: _movingHookLeadHandRTargetKeys,
    bodyKeys: _movingHookLeadBodyKeys,
    footLTargets: _movingHookLeadFootLTargetKeys,
    footRTargets: _movingHookLeadFootRTargetKeys,
    footLKeys: _movingHookLeadFootLKeys,
    footRKeys: _movingHookLeadFootRKeys,
    handLKeys: _movingHookLeadHandLKeys,
    handRKeys: _movingHookLeadHandRKeys,
    clavicleLKeys: _movingHookLeadClavicleLKeys,
    clavicleRKeys: _movingHookLeadClavicleRKeys,
    contactSpans: _movingHookLeadContactSpans,
  );

  /// Backup 1 keeps the same step-touch pocket as the lead, but supplies the
  /// low, round counter-rhythm underneath the singer's diagonal call.
  static Clip get movingGrooveLowCounter => _movingGroove(
    name: 'movingHookLowCounter',
    handLTargets: _movingGrooveLowCounterHandLTargetKeys,
    handRTargets: _movingGrooveLowCounterHandRTargetKeys,
  );

  /// Backup 2 answers the lead on the off-beats.  This is intentionally a
  /// separate phrase, not the lead shifted in time: the formation has three
  /// roles while still agreeing on the song's downbeats.
  static Clip get movingGrooveSideAnswer => _movingGroove(
    name: 'movingHookSideAnswer',
    handLTargets: _movingGrooveSideAnswerHandLTargetKeys,
    handRTargets: _movingGrooveSideAnswerHandRTargetKeys,
    bodyKeys: _movingGrooveSideAnswerBodyKeys,
    clavicleLKeys: _movingGrooveSideAnswerClavicleLKeys,
    clavicleRKeys: _movingGrooveSideAnswerClavicleRKeys,
    headKeys: _movingGrooveSideAnswerHeadKeys,
  );

  /// Verse phrase: a visible heel-tap shuffle with the hips travelling over
  /// the planted shoe. It is deliberately a different lower-body sentence
  /// from the chorus hook, rather than the same step-touch with new arms.
  static Clip get movingVerseGroove => _movingGroove(
    name: 'movingVerseShuffle',
    handLTargets: _movingVerseHandLTargetKeys,
    handRTargets: _movingVerseHandRTargetKeys,
    bodyKeys: _movingVerseBodyKeys,
    footLTargets: _movingVerseFootLTargetKeys,
    footRTargets: _movingVerseFootRTargetKeys,
    footLKeys: _movingVerseFootLKeys,
    footRKeys: _movingVerseFootRKeys,
  );

  /// Verse variation: the heel shuffle remains independent underneath while
  /// a shoulder-led side window climbs beside the face and pours outward.
  /// This gives repeat verses a new sentence without changing the song's
  /// relaxed weight-transfer vocabulary.
  static Clip get movingVerseWindow => _movingGroove(
    name: 'movingVerseWindow',
    handLTargets: _movingVerseWindowHandLTargetKeys,
    handRTargets: _movingVerseWindowHandRTargetKeys,
    bodyKeys: _movingVerseWindowBodyKeys,
    footLTargets: _movingVerseFootLTargetKeys,
    footRTargets: _movingVerseFootRTargetKeys,
    footLKeys: _movingVerseFootLKeys,
    footRKeys: _movingVerseFootRKeys,
    clavicleLKeys: _movingVerseWindowClavicleLKeys,
    clavicleRKeys: _movingVerseWindowClavicleRKeys,
  );

  /// Breakdown phrase: compact double-time heel lifts under a low centre.
  /// Its smaller travel leaves room for the bridge vocal and makes the next
  /// chorus return feel earned.
  static Clip get movingBreakdownGroove => _movingGroove(
    name: 'movingBridgeBounce',
    handLTargets: _movingBreakdownHandLTargetKeys,
    handRTargets: _movingBreakdownHandRTargetKeys,
    bodyKeys: _movingBreakdownBodyKeys,
    footLTargets: _movingBreakdownFootLTargetKeys,
    footRTargets: _movingBreakdownFootRTargetKeys,
    footLKeys: _movingBreakdownFootLKeys,
    footRKeys: _movingBreakdownFootRKeys,
  );

  static Clip _movingGroove({
    required String name,
    required List<DanceIkTargetKey> handLTargets,
    required List<DanceIkTargetKey> handRTargets,
    List<DanceBodyKey> bodyKeys = _movingGrooveBodyKeys,
    List<DanceIkTargetKey> footLTargets = _movingGrooveFootLTargetKeys,
    List<DanceIkTargetKey> footRTargets = _movingGrooveFootRTargetKeys,
    List<DanceJointKey> footLKeys = _movingGrooveFootLKeys,
    List<DanceJointKey> footRKeys = _movingGrooveFootRKeys,
    List<DanceJointKey> handLKeys = _movingGrooveHandLKeys,
    List<DanceJointKey> handRKeys = _movingGrooveHandRKeys,
    List<DanceJointKey> clavicleLKeys = _movingGrooveClavicleLKeys,
    List<DanceJointKey> clavicleRKeys = _movingGrooveClavicleRKeys,
    List<DanceJointKey> headKeys = _movingGrooveHeadKeys,
    List<GroundSpan> contactSpans = _movingGrooveContactSpans,
  }) {
    final base = _danceBase;
    return assembleMoveClip(
      _dancePhrase,
      DanceMoveDescriptor(
        family: 'moving',
        move: AfrobeatsMove(
          name: name,
          feel: DanceFeel.offBeat,
          featuredRegion: BodyRegion.full,
          // Relaxed/light body with sustained, free transitions. Accents from
          // the track still sharpen this through the live dynamics layer.
          dynamics: DanceDynamics(weight: -0.25, time: -0.3, flow: 0.35),
        ),
        duration: base.duration,
        contactPinning: base.contactPinning,
        supportFootWorldAnchor: true,
        supportFootWorldAnchorStrength: 0.88,
        supportFootWorldAnchorVerticalBoost: 0.08,
        danceHeadBobScale: 0.78,
        danceHeadLevelClampMin: -6,
        enforceSoleFloor: true,
        baseClip: base,
        jointTracks: {
          CatBones.head: DanceJointTrack(
            headKeys,
            smooth: true,
          ),
          CatBones.footL: DanceJointTrack(
            footLKeys,
            smooth: true,
          ),
          CatBones.footR: DanceJointTrack(
            footRKeys,
            smooth: true,
          ),
          CatBones.clavicleL: DanceJointTrack(
            clavicleLKeys,
            smooth: true,
          ),
          CatBones.clavicleR: DanceJointTrack(
            clavicleRKeys,
            smooth: true,
          ),
          CatBones.handL: DanceJointTrack(
            handLKeys,
            smooth: true,
          ),
          CatBones.handR: DanceJointTrack(
            handRKeys,
            smooth: true,
          ),
        },
        bodyMotion: DanceBodyMotion(
          pelvisBoneId: CatBones.hips,
          chestBoneId: CatBones.torso,
          tracks: [
            DanceBodyMotionTrack(
              keys: bodyKeys,
              rootMicroFrames: -0.25,
              chestMicroFrames: 0.85,
              chestRotationGain: 0.82,
              chestScaleGain: 0.86,
            ),
          ],
        ),
        limbTargetTracks: {
          CatBones.handL: DanceIkTargetTrack(
            handLTargets,
            cyclic: true,
            // The arm mass follows the pelvis/ribs, and the two sides never
            // arrive as a mirrored mechanical pair.
            microFrames: 0.55,
          ),
          CatBones.handR: DanceIkTargetTrack(
            handRTargets,
            cyclic: true,
            microFrames: 0.2,
          ),
          CatBones.footL: DanceIkTargetTrack(
            footLTargets,
            cyclic: true,
          ),
          CatBones.footR: DanceIkTargetTrack(
            footRTargets,
            cyclic: true,
          ),
        },
        rawContactSpans: contactSpans,
      ),
      // Both arms stay on their own side of the torso, so their elbows must
      // take the OUTBOARD analytic branch. Reusing the shared lead's opposing
      // bend pair turns the right forearm inside-out even for a safe endpoint.
      rigLimbTargets: [
        const LimbIkTarget(
          upperBoneId: CatBones.armUpperL,
          lowerBoneId: CatBones.armLowerL,
          endBoneId: CatBones.handL,
          anchorBoneId: CatBones.torso,
          channel: KeyframeIkTargetChannel([]),
        ),
        const LimbIkTarget(
          upperBoneId: CatBones.armUpperR,
          lowerBoneId: CatBones.armLowerR,
          endBoneId: CatBones.handR,
          anchorBoneId: CatBones.torso,
          channel: KeyframeIkTargetChannel([]),
          bendDirection: -1,
        ),
        _danceLimbTargets[2],
        _danceLimbTargets[3],
      ],
    );
  }

  /// Standalone "Shaku Shaku" catalog move — separate from the shipped `dance`,
  /// reuses the dance channels and overrides the groove (on-beat dip), the
  /// support-knee pump, and adds a
  /// per-bar upper-body LEAN (chest over the support foot — the weight commit
  /// that does NOT translate the root, so it never drags the free foot into the
  /// planted one). The crossed-X hand IK uses a hit-and-hold square wave with
  /// `easeOutBack` overshoot; the forearm reads via the shared sleeve band.
  ///
  /// Assembled through `assembleMoveClip` (`dance_move_compiler.dart`) from
  /// its authored key data below.
  static Clip get shaku {
    final base = _danceBase;
    return assembleMoveClip(
      _dancePhrase,
      DanceMoveDescriptor(
        move: const AfrobeatsMove(
          name: 'shaku',
          feel: DanceFeel.onBeat,
          featuredRegion: BodyRegion.legs,
          // ADR D4: loose body · Sudden legs · Bound arms.
          dynamics: DanceDynamics(weight: -0.15, time: 0.55, flow: -0.35),
        ),
        duration: base.duration,
        contactPinning: base.contactPinning,
        supportFootWorldAnchor: true,
        // R24 (physicist#1 / mocap#1): the support foot still slid ~14% of the
        // root sway in world-x (the "double-foot skate"), so pin it harder —
        // 0.86 → 0.90 leaves ~10% residual (0.95 tipped foot.R past the 1.5-rad
        // planted-orientation-stability bound; 0.90 stays under it).
        supportFootWorldAnchorStrength: 0.90,
        // Transitions panel: shaku's grooved pocket sink DWELLS (avg ~38px,
        // never near standing height) like zanku's fixed bug, at a lower
        // 0.86 base strength (14% residual) — see
        // Clip.supportFootWorldAnchorVerticalBoost and zanku's own comment
        // for the mechanism. Boosts effective vertical strength to ~0.99.
        supportFootWorldAnchorVerticalBoost: 0.08,
        // Grounded pocket: keep the head COOL and near-level while the hips
        // sink into the knees on each count. The old 0.8 bob let the head
        // travel further than the hips (whole-body pogo, no pocket); calming
        // the bob and letting the level-counter correct the full compress
        // reads as a steady head over a busy lower body.
        // OWNER DECISION (2026-07-04, R16): the head RIDES the crouch for
        // shaku. Three panels read the level-head design as "the strongest
        // keyframed-robotics tell" — the skull sat HIGHEST in the deepest
        // crouch because the leveler counter-extended the neck. Bob back up
        // to 0.8 and the level clamp eased to -5 so the head inherits
        // roughly half of the pelvis drop; the authored tilt channel gives
        // it attitude on top. (pouncingCat and the rest keep the leveler —
        // this is a per-move taste call, not a rig change.)
        danceHeadBobScale: 0.8,
        danceHeadLevelClampMin: -5,
        // R28: the R27 mocap hard gate — free-foot taps may never render
        // below the planted sole (deep sinks dragged them ~10 units
        // through the floor at the seam). Opt-in per the ratchet; other
        // routines enable it in their own re-author rounds.
        enforceSoleFloor: true,
        baseClip: base,
        zOrderSwaps: const [
          ZOrderSwapWindow(
            boneA: CatBones.handL,
            boneB: CatBones.handR,
            start: 0.5,
            end: 1,
          ),
        ],
        jointTracks: {
          CatBones.legLowerL: const DanceJointTrack(
            _shakuLegLowerLKeys,
            smooth: true,
          ),
          CatBones.legLowerR: const DanceJointTrack(
            _shakuLegLowerRKeys,
            smooth: true,
          ),
          CatBones.footL: const DanceJointTrack(_shakuFootLKeys, smooth: true),
          CatBones.footR: const DanceJointTrack(_shakuFootRKeys, smooth: true),
          CatBones.handL: const DanceJointTrack(_shakuHandLKeys, smooth: true),
          CatBones.handR: const DanceJointTrack(_shakuHandRKeys, smooth: true),
          // Shoulder-LED dig: the clavicle drops the socket on each count so
          // the hand can dig low with the elbow bent; the socket bunches for
          // the flesh read. The led variants carry microFrames -1.5 so the
          // girdle initiates each roll ~1.5 frames BEFORE the hand reaches
          // its extreme (R22: "the shoulders drive the arms rather than
          // tilting with them — synchronous reversal reads keyframed").
          CatBones.clavicleL: DanceJointTrack(
            _shakuClavicleLLedKeys,
            smooth: true,
          ),
          CatBones.clavicleR: DanceJointTrack(
            _shakuClavicleRLedKeys,
            smooth: true,
          ),
          CatBones.shoulderSocketL: const DanceJointTrack(
            _shakuShoulderSocketLKeys,
            smooth: true,
          ),
          CatBones.shoulderSocketR: const DanceJointTrack(
            _shakuShoulderSocketRKeys,
            smooth: true,
          ),
          // Head attitude: a lagged counter-tilt answering each open count
          // plus a tip into the generator pull — the R15 animator's "single
          // change that turns this rig from a body that moves into a
          // character that dances".
          CatBones.head: const DanceJointTrack(_shakuHeadKeys, smooth: true),
        },
        bodyMotion: DanceBodyMotion(
          pelvisBoneId: CatBones.hips,
          chestBoneId: CatBones.torso,
          tracks: [
            DanceBodyMotionTrack(
              keys: _shakuGrooveCommitted,
              // R24 sync: the whole authored pocket rides +0.3 frames
              // (~75ms live) so troughs land BEHIND their beats — the
              // panel measured bars 1/2/4 anticipating 27-63ms early —
              // and the seam dive clears the wrap-span contact-lock
              // fade-in instead of being eaten by it. The relative
              // pelvis-leads-root-leads-chest stagger is preserved.
              rootMicroFrames: 0.3,
              pelvisMicroFrames: 0,
              // Groove pocket: let the chest COUNTER-ROTATE harder against the
              // pelvis (panel: "upright torso, no hip/shoulder counter-rotation,
              // timid upper body"). The calmed head bob above frees the shared
              // spine budget the rigid-skull head-step test caps, so the twist
              // can grow without lifting the skull.
              chestRotationGain: 0.95,
            ),
            DanceBodyMotionTrack(
              keys: _danceBodyAccentKeys,
              rootMicroFrames: 0.3,
              pelvisMicroFrames: 0,
            ),
            const DanceBodyMotionTrack(
              keys: _shakuDabBodyKeys,
              rootMicroFrames: 0.3,
              pelvisMicroFrames: 0,
              chestRotationGain: 0.68,
            ),
            const DanceBodyMotionTrack(
              keys: _shakuPanelBodyKeys,
              rootMicroFrames: 0.3,
              pelvisMicroFrames: 0,
              chestRotationGain: 0.68,
            ),
          ],
          extraRootLayers: const [
            // Weight commitment as STEPPED PER-BAR TRANSFERS (R21, all four
            // lenses: "the lateral trace is one smooth 2-bar sinusoid...
            // the centroid glides instead of committing over each support
            // foot — the core keyframed-vs-recorded tell; every other flaw
            // hangs off that"). Three square-wave Fourier terms (h1 + h3/3
            // + h5/5, common phase) turn the old sine into plateau-and-
            // shift: the pelvis PARKS over the left support through bar 1,
            // transitions in ~2-3 frames, and parks over the right through
            // bar 2 — with the crossings phased one frame AFTER the plants
            // (feet step ON the count, weight arrives just behind them).
            // R26: the weight story as EXPLICIT authored keys — all four
            // R25 raters measured the square-wave stack's return transfer
            // crammed into ~1.5 beats at the seam (steepest lateral slope
            // of the loop in its final half-beat) while the outbound
            // transfer breathed over ~2.5. Keys give both transfers the
            // same 5-frame (2.5-beat) ease, parks held genuinely flat,
            // crossings kept just AFTER the plants (R f15 -> ~f16.1,
            // L f30 -> ~f31.2), each transfer landing in its bar-line
            // sink. The lean stays sinusoidal below; the h8 scallops
            // still ripple the parks.
            KeyframeRootChannel(
              [
                // r10: PER-BAR weight commits inside each park (unanimous
                // r9 note: "WEIGHT is one slow phrase-length drift, ~0.8
                // ev/s — hips never exchange laterally on the taps"). The
                // r4 single rock's ~7-unit world wiggle sat under the
                // 25%-of-range prominence floor (~13); each park now digs
                // twice — once per bar, timed with that bar's tap cluster
                // — rising to the park's inner edge between digs (still on
                // the committed side, so the park-and-commit story holds;
                // this is a rock ON the support, not a transfer).
                RootKeyframe(p: 1 / 32, dx: -8, tension: 0.6),
                RootKeyframe(p: 4 / 32, dx: -22, tension: 0.6),
                RootKeyframe(p: 7 / 32, dx: -9, tension: 0.6),
                // r11: bar-2 dig one deeper (coach: "bar 2's dig is the
                // shallowest of the four — mid-phrase the rock nearly
                // flattens back into the old plateau").
                RootKeyframe(p: 10 / 32, dx: -23, tension: 0.6),
                RootKeyframe(p: 13 / 32, dx: -8, tension: 0.6),
                RootKeyframe(p: 15.25 / 32, dx: -1),
                RootKeyframe(p: 17.75 / 32, dx: 9, tension: 0.6),
                RootKeyframe(p: 20 / 32, dx: 25, tension: 0.6),
                // r11: 7 -> 6 (animator: "bars 3-4 digs flatten into the
                // drift") — one more unit of dig depth without moving the
                // park extremes the camera bound tracks.
                RootKeyframe(p: 23 / 32, dx: 6, tension: 0.6),
                RootKeyframe(p: 26 / 32, dx: 24, tension: 0.6),
                // The return starts a beat earlier than symmetry suggests:
                // the support anchor keeps pulling toward the planted R
                // foot until its span ends at f30.125 and follows ~1 frame
                // behind, so the WORLD transfer lands f28.5-f0.5 (2.5
                // beats, crossing ~f30.8 just after the L plant) — probe-
                // matched to the outbound transfer's width.
                RootKeyframe(p: 28.5 / 32, dx: 11, tension: 0.6),
                RootKeyframe(p: 30.75 / 32, dx: -4),
              ],
              smooth: true,
              cyclic: true,
            ),
            SineRootChannel(leanAmplitude: -0.07),
            // Per-tap weight SCALLOPS on the plateaus (R22 mocap verdict:
            // "the pelvis never responds to a single contact... layer a
            // per-tap lateral pulse decaying over the beat, so the trace
            // becomes a plateau with beat-rate scallops instead of a flat
            // line"). The plateau keeps the committed side; this ripple
            // presses into and releases off the support with every tap.
            // r10: -4.5 -> -3.5 — the per-bar dig keys above now carry the
            // press-into-the-support story; at -4.5 the summed lateral
            // slope (dig + scallop) swung the skull 20.4 units against the
            // collar, past the loose-head gate's 20.
            SineRootChannel(swayAmplitude: -3.5, swayHarmonic: 8),
            // (r10: the R27 h4 per-bar rock layer is FOLDED INTO the park
            // keys above — a sine layer under authored per-bar digs risks
            // phase interference, the campaign's thrice-confirmed lesson.)
            // The pocket pulse, SHAPED (R19 mocap verdict: the symmetric
            // triangle wave "never SITS into a beat... one timing change
            // that converts the whole loop from keyframed to danced").
            // Three-harmonic Fourier stack, phases solved numerically:
            //  - h8 primary: trough dead on each count (depth restored by
            //    the accent layer below, so overall swing stays ~55);
            //  - h16 skew at phase 0.05664: steepens the drop INTO each
            //    trough and flattens the exit — measured 2.9x drop/rise
            //    slope asymmetry, trough arriving a hair early (a dancer
            //    hits slightly INTO the beat);
            //  - h2 accent: its two deep moments land ~1.5 frames AFTER
            //    counts 1 and 5 (frames 1.5 / 17.5) — a behind-the-beat
            //    pocket: the foot steps ON the count, the weight arrives
            //    just after, once the landed foot's contact lock is fully
            //    engaged (dead on frame 0 the dive landed inside the wrap
            //    span's lock fade-in and popped the planted sole ~16 units
            //    through its hold).
            SineRootChannel(
              bobAmplitude: -20,
              bobPhase: 0.084375,
              bobHarmonic: 8,
              leanAmplitude: 0.015,
              leanHarmonic: 8,
            ),
            SineRootChannel(
              bobAmplitude: -6,
              bobPhase: 0.047265625,
              bobHarmonic: 16,
              leanAmplitude: 0.006,
              leanPhase: 0.03,
              leanHarmonic: 16,
            ),
            // h2 accent raised -7 -> -9: the R24 panel measured bar 1's
            // hierarchy inverted (the behind-the-bar-line trough was the
            // SHALLOWEST in its bar); the stronger 2-cycle puts the two
            // deepest moments of the loop just behind bars 1 and 3.
            SineRootChannel(bobAmplitude: -11, bobPhase: 0.3421875),
          ],
          extraPelvisLayers: const [
            SineChannel(
              harmonicAmplitude: 0.004,
              harmonicPhase: 0.015,
              harmonicMultiplier: 24,
              scaleXAmplitude: 0.0015,
              scaleXPhase: 0.015,
              scaleXHarmonic: 24,
              scaleYAmplitude: -0.0015,
              scaleYPhase: 0.015,
              scaleYHarmonic: 24,
            ),
          ],
          extraChestLayers: const [
            SineChannel(
              harmonicAmplitude: 0.003,
              harmonicPhase: 0.04,
              harmonicMultiplier: 24,
              scaleXAmplitude: -0.002,
              scaleXPhase: 0.04,
              scaleXHarmonic: 24,
              scaleYAmplitude: 0.002,
              scaleYPhase: 0.04,
              scaleYHarmonic: 24,
            ),
            SineChannel(amplitude: 0.115),
          ],
        ),
        limbTargetTracks: {
          CatBones.handL: const DanceIkTargetTrack(
            _shakuHandLTargetKeys,
            cyclic: true,
            inertialize: true,
          ),
          CatBones.handR: const DanceIkTargetTrack(
            _shakuHandRTargetKeys,
            cyclic: true,
            inertialize: true,
          ),
          CatBones.footL: const DanceIkTargetTrack(_shakuFootLTargetKeys),
          CatBones.footR: const DanceIkTargetTrack(_shakuFootRTargetKeys),
        },
        rawContactSpans: _shakuContactSpans,
        extraJointChannels: const {
          CatBones.earL: KeyframeChannel(_shakuEarLKeys, smooth: true),
          CatBones.earR: KeyframeChannel(_shakuEarRKeys, smooth: true),
        },
      ),
      // Reuse the dance foot targets; the HANDS get the crossed-X channels
      // with elbows on their natural OUTBOARD side. The old flip folded the
      // elbows inboard of the shoulders while the forearms broke
      // outboard-below — the anatomically impossible "broken W" the owner
      // flagged on screen.
      rigLimbTargets: [
        const LimbIkTarget(
          upperBoneId: CatBones.armUpperL,
          lowerBoneId: CatBones.armLowerL,
          endBoneId: CatBones.handL,
          anchorBoneId: CatBones.torso,
          channel: KeyframeIkTargetChannel([]),
        ),
        const LimbIkTarget(
          upperBoneId: CatBones.armUpperR,
          lowerBoneId: CatBones.armLowerR,
          endBoneId: CatBones.handR,
          anchorBoneId: CatBones.torso,
          channel: KeyframeIkTargetChannel([]),
          bendDirection: -1,
        ),
        _danceLimbTargets[2],
        _danceLimbTargets[3],
      ],
    );
  }

  /// Standalone "Zanku / Legwork" catalog move. Reuses the dance channels + the
  /// proven shaku groove, and adds the Zanku signatures: per-BEAT LEGWORK via
  /// the foot IK targets (compact heel-toe scrapes under the hips — see
  /// [_zankuContactSpans]), fists marking low counter-hits, and a compact forward
  /// chest dip on the stomp.
  /// Current review target: legibility is improving, but the kick frames still
  /// need anatomical support and heavier stomp/drop before this reaches 9/10.
  ///
  /// Assembled through `assembleMoveClip` (`dance_move_compiler.dart`) from
  /// its authored key data below.
  static Clip get zanku {
    final base = _danceBase;
    return assembleMoveClip(
      _dancePhrase,
      DanceMoveDescriptor(
        move: const AfrobeatsMove(
          name: 'zanku',
          feel: DanceFeel.offBeat,
          featuredRegion: BodyRegion.legs,
          // ADR D4: Strong · Sudden · Bound (the kick accent runs Free on top).
          dynamics: DanceDynamics(weight: 0.7, time: 0.6, flow: -0.45),
        ),
        duration: base.duration,
        contactPinning: base.contactPinning,
        supportFootWorldAnchor: true,
        supportFootWorldAnchorStrength: 0.9,
        // Transitions panel: zanku's per-beat crouch DWELLS (a sustained
        // root sink, not buga's transient dip-and-release), so the shared
        // 0.9 strength's ~10% residual leaked a persistently lower average
        // foot/screen position than any neighbouring move — read at a hard
        // cut as an accidental ~15-20% camera push. This tightens only the
        // vertical pull (stance width, tuned via the shared strength above,
        // is untouched) — see Clip.supportFootWorldAnchorVerticalBoost.
        supportFootWorldAnchorVerticalBoost: 0.09,
        danceHeadBobScale: 0.75,
        // Ornament-port round: zanku joins the sole-floor ratchet — its
        // heel-toe knocks were re-authored slightly inboard/up so the
        // clamp's lift stays inside the hip envelope.
        enforceSoleFloor: true,
        baseClip: base,
        jointTracks: {
          CatBones.head: const DanceJointTrack(_zankuHeadKeys, smooth: true),
          CatBones.footL: const DanceJointTrack(_zankuFootLKeys, smooth: true),
          CatBones.footR: const DanceJointTrack(_zankuFootRKeys, smooth: true),
          CatBones.handL: const DanceJointTrack(_zankuHandLKeys, smooth: true),
          CatBones.handR: const DanceJointTrack(_zankuHandRKeys, smooth: true),
          CatBones.clavicleR: const DanceJointTrack(
            _zankuClavicleRKeys,
            smooth: true,
            layerOnBase: true,
          ),
          CatBones.clavicleL: const DanceJointTrack(
            _zankuClavicleLKeys,
            smooth: true,
            layerOnBase: true,
          ),
        },
        bodyMotion: DanceBodyMotion(
          pelvisBoneId: CatBones.hips,
          chestBoneId: CatBones.torso,
          tracks: [
            DanceBodyMotionTrack(keys: _danceBodyAccentKeys),
            const DanceBodyMotionTrack(
              keys: _zankuGbeseAccentKeys,
              chestMicroFrames: 0.3,
            ),
            DanceBodyMotionTrack(
              keys: _zankuCommitKeys,
              pelvisMicroFrames: -0.95,
              chestMicroFrames: 0.9,
              chestRotationGain: 0.72,
            ),
            const DanceBodyMotionTrack(
              keys: _zankuPocketBoostKeys,
              rootMicroFrames: -0.3,
              pelvisMicroFrames: -1.05,
              chestMicroFrames: 1.05,
              chestRotationGain: 0.7,
              chestScaleGain: 0.86,
            ),
            DanceBodyMotionTrack(
              keys: _zankuSupportLoadKeys,
              rootMicroFrames: -0.45,
              pelvisMicroFrames: -1.15,
              chestMicroFrames: 1.15,
              chestRotationGain: 0.62,
              chestScaleGain: 0.84,
            ),
          ],
          extraRootLayers: const [
            // Zanku R2: a per-stamp lateral pulse (~35% of the bar sway)
            // commits the pelvis over each stamping foot — the R2 mocap
            // rater measured the mass riding a bar-long lean while the
            // stamps alternated under it ("leg gestures without mass
            // behind them").
            // h4, not h8: stamps alternate every 4 frames, so consecutive
            // stamps sit one full h8 period apart (same pulse sign on both
            // sides — the mirrored dwell gate caught it). h4 flips the
            // lean per stamp: toward L after the L stamp, R after R.
            SineRootChannel(swayAmplitude: -5, swayHarmonic: 4),
            SineRootChannel(
              bobAmplitude: -8,
              bobPhase: 0.09375,
              bobHarmonic: 8,
            ),
          ],
          extraChestLayers: const [
            SineChannel(bias: 0.17),
            SineChannel(
              // NOTE (r6): the back-half-of-bar accent was tried here at
              // 0.078-0.09 and as a root h4 — every variant tripped a
              // stomp-pocket, chest-arrival, velocity, or jerk gate. The
              // channel is saturated; the accent needs authored body keys
              // (queued), not a layered harmonic.
              harmonicAmplitude: 0.055,
              harmonicMultiplier: 4,
              harmonicPhase: 0.0825,
            ),
          ],
        ),
        limbTargetTracks: {
          CatBones.handL: const DanceIkTargetTrack(
            _zankuHandLTargetKeys,
            cyclic: true,
            inertialize: true,
          ),
          CatBones.handR: const DanceIkTargetTrack(
            _zankuHandRTargetKeys,
            cyclic: true,
            inertialize: true,
          ),
          CatBones.footL: const DanceIkTargetTrack(
            _zankuFootLTargetKeys,
            inertialize: true,
          ),
          CatBones.footR: const DanceIkTargetTrack(
            _zankuFootRTargetKeys,
            inertialize: true,
          ),
        },
        rawContactSpans: _zankuContactSpans,
        extraJointChannels: {
          CatBones.earL: _earFollow(side: 1, amplitude: 0.022, phase: 0.1),
          CatBones.earR: _earFollow(side: -1, amplitude: 0.022, phase: 0.57),
          ..._tailFollowThrough(amplitude: 0.095, phase: 0.06),
        },
      ),
      // Zanku's pumping hands live far OUTBOARD all clip, so the elbows must
      // break outboard too (like Shaku's fix): the inherited inboard bends
      // folded the elbow across the ribs on the inward swing while the paw
      // stayed out — the contralateral fold the anti-fold clamp now forbids.
      rigLimbTargets: [
        const LimbIkTarget(
          upperBoneId: CatBones.armUpperL,
          lowerBoneId: CatBones.armLowerL,
          endBoneId: CatBones.handL,
          anchorBoneId: CatBones.torso,
          channel: KeyframeIkTargetChannel([]),
        ),
        const LimbIkTarget(
          upperBoneId: CatBones.armUpperR,
          lowerBoneId: CatBones.armLowerR,
          endBoneId: CatBones.handR,
          anchorBoneId: CatBones.torso,
          channel: KeyframeIkTargetChannel([]),
          bendDirection: -1,
        ),
        _danceLimbTargets[2],
        _danceLimbTargets[3],
      ],
    );
  }

  /// Standalone "Azonto" catalog move — a bent-knee, hip-swivel groove with the
  /// signature miming HAND gestures (here: alternating point-out, de-symmetrized
  /// into a high/low V in bar 2). Reuses the shaku bent-knee groove for the
  /// lower body; the Azonto character is the hip swivel + chest counter-rotation
  /// + the committed lateral weight-drop + the point-out arms (`easeOutBack`
  /// overshoot). Still under panel review: the side/quarter pass needs the
  /// support foot to match where the pelvis actually dwells.
  ///
  /// Assembled through `assembleMoveClip` (`dance_move_compiler.dart`) from
  /// its authored key data below.
  static Clip get azonto {
    final base = _danceBase;
    return assembleMoveClip(
      _dancePhrase,
      DanceMoveDescriptor(
        move: const AfrobeatsMove(
          name: 'azonto',
          feel: DanceFeel.offBeat,
          featuredRegion: BodyRegion.arms,
          // ADR D4: loose body · Sudden·Direct hands.
          dynamics: DanceDynamics(time: 0.6, flow: -0.1),
        ),
        duration: base.duration,
        contactPinning: base.contactPinning,
        supportFootWorldAnchor: true,
        supportFootWorldAnchorStrength: 0.86,
        // Transitions panel: azonto's pocket sink DWELLS (avg ~45px, never
        // near standing height, the largest/worst estimated leak of the
        // catalogue) — same fix as zanku/shaku, see
        // Clip.supportFootWorldAnchorVerticalBoost.
        supportFootWorldAnchorVerticalBoost: 0.13,
        danceHeadBobScale: 0.7,
        // Ornament-port round: azonto joins the sole-floor ratchet (its
        // step-touch redirects are floor-adjacent; the clamp guards the
        // deep-accent frames).
        enforceSoleFloor: true,
        // Sagittal barrel roll: the fists share a screen x and overlap at the
        // mid-line crossings, so one must pass BEHIND the other. handL is the
        // NEAR (front) fist while it's on the toward-you half of the roll
        // (cosθ>0) — draw it on top then; handR on top the rest. 4 rolls/loop →
        // 4 handL-front swap windows, toggling at the vertical extremes (where
        // the fists are separated, hiding the flip). A 5th, full-loop shade-only
        // window (swap:false) darkens whichever fist is currently BEHIND so the
        // far hand reads as sitting in the near hand's shadow — honest depth with
        // NO fake perspective size change (camera meters away, hands cm apart).
        zOrderSwaps: const [
          ZOrderSwapWindow(
            boneA: CatBones.handL,
            boneB: CatBones.handR,
            start: 0.9375,
            end: 0.0625,
          ),
          ZOrderSwapWindow(
            boneA: CatBones.handL,
            boneB: CatBones.handR,
            start: 0.1875,
            end: 0.3125,
          ),
          ZOrderSwapWindow(
            boneA: CatBones.handL,
            boneB: CatBones.handR,
            start: 0.4375,
            end: 0.5625,
          ),
          ZOrderSwapWindow(
            boneA: CatBones.handL,
            boneB: CatBones.handR,
            start: 0.6875,
            end: 0.8125,
          ),
          ZOrderSwapWindow(
            boneA: CatBones.handL,
            boneB: CatBones.handR,
            start: 0,
            end: 1,
            swap: false,
            shadeBehind: 0.22,
          ),
        ],
        baseClip: base,
        jointTracks: {
          CatBones.head: const DanceJointTrack(_azontoHeadKeys, smooth: true),
          CatBones.handL: const DanceJointTrack(
            _azontoHandLKeys,
            smooth: true,
          ),
          CatBones.handR: const DanceJointTrack(
            _azontoHandRKeys,
            smooth: true,
          ),
          CatBones.clavicleL: const DanceJointTrack(
            _azontoClavicleLKeys,
            smooth: true,
          ),
          CatBones.clavicleR: const DanceJointTrack(
            _azontoClavicleRKeys,
            smooth: true,
          ),
        },
        bodyMotion: DanceBodyMotion(
          pelvisBoneId: CatBones.hips,
          chestBoneId: CatBones.torso,
          tracks: [
            DanceBodyMotionTrack(
              keys: _azontoGrooveCalm,
              chestRotationGain: 0.9,
            ),
            DanceBodyMotionTrack(keys: _danceBodyAccentKeys),
            const DanceBodyMotionTrack(
              keys: _azontoPocketKeys,
              rootMicroFrames: -0.1,
              pelvisMicroFrames: -0.15,
              chestMicroFrames: 1.2,
              chestRotationGain: 0.68,
              chestScaleGain: 0.88,
            ),
          ],
          extraRootLayers: const [
            // 9-path r3: per-touch lateral pulse — the lower body read as
            // 'planted while the arms churn' (weight one 0.8/s excursion).
            // r11: -4.5 -> -3.5 — the h4 exchange below now carries the
            // per-bar weight story; at -4.5 the summed lateral slope swung
            // the skull 20.5 against the collar (loose-head gate <20),
            // the same trade shaku made in r10.
            SineRootChannel(swayAmplitude: -3.5, swayHarmonic: 8),
            // r6: lift the base groove under the (now-dominant) wheel —
            // pocket 39.2 was the set's shallowest ('lift the base ~1.3x
            // rather than touching the arms').
            SineRootChannel(
              bobAmplitude: -8.5,
              bobPhase: 0.146875,
              bobHarmonic: 8,
            ),
            SineRootChannel(
              bobAmplitude: -0.04,
              bobPhase: 0.125,
              bobHarmonic: 8,
            ),
            // r10: h2 -> h4 — the 2-cycle sway was the "one long unilateral
            // excursion across bars 1-2 / parked bar 3" every r9 lens
            // measured (0.9 ev/s). One full exchange per bar now steps the
            // pelvis with the step-touch instead of drifting under it.
            // r11: phase 0 -> 0.25, probe-computed — at phase 0 the h4
            // trough landed exactly on bar-2's key crest (keys f8 -8.6 ->
            // f10 0 exchange summed to a flat -8.6 -> -7: the panel's
            // "bars 1-2 one continuous descent"). At 0.25 the sine crests
            // WITH the keys at f0/f4/f8/f12 — the campaign's 4th confirmed
            // phase-interference instance.
            SineRootChannel(
              swayAmplitude: -14,
              swayPhase: 0.25,
              swayHarmonic: 4,
            ),
          ],
          // Azonto baseline panel (coach + mocap #2): the signature hip SWIVEL
          // reads too weak — the groove looks like a bent-knee march, not
          // hip-driven. In a 2D front-facing rig the swivel reads as a deeper
          // pelvis ROLL (hip hike over the loaded leg) under a counter-rolling
          // ribcage; deepened both (pelvis 0.17->0.23, chest -0.11->-0.15) so
          // the hips lead and the chest opposes visibly.
          extraPelvisLayers: const [SineChannel(harmonicAmplitude: 0.23)],
          extraChestLayers: const [
            SineChannel(harmonicAmplitude: -0.15, harmonicPhase: 0.02),
          ],
        ),
        limbTargetTracks: {
          CatBones.handL: const DanceIkTargetTrack(
            _azontoHandLTargetKeys,
            cyclic: true,
          ),
          CatBones.handR: const DanceIkTargetTrack(
            _azontoHandRTargetKeys,
            cyclic: true,
          ),
          // Unlike every other move's feet, azonto's foot IK path is NOT
          // smooth (matches `_azontoFootLTarget`/`RTarget`'s real
          // construction, which omits `smooth: true`).
          CatBones.footL: const DanceIkTargetTrack(
            _azontoFootLTargetKeys,
            smooth: false,
          ),
          CatBones.footR: const DanceIkTargetTrack(
            _azontoFootRTargetKeys,
            smooth: false,
          ),
        },
        rawContactSpans: _azontoContactSpans,
        extraJointChannels: {
          CatBones.earL: _earFollow(side: 1, amplitude: 0.022, phase: 0.12),
          CatBones.earR: _earFollow(side: -1, amplitude: 0.022, phase: 0.59),
          ..._tailFollowThrough(amplitude: 0.09, phase: 0.08),
        },
      ),
      // Outboard elbow bends: the wheel grips sit close in front of the
      // chest and the jabs cross the midline, both of which need the elbow
      // trailing outboard (a crossing jab leads with the fist, elbow behind
      // it) — the inherited inboard bends produced the pinched-elbow fold.
      rigLimbTargets: [
        const LimbIkTarget(
          upperBoneId: CatBones.armUpperL,
          lowerBoneId: CatBones.armLowerL,
          endBoneId: CatBones.handL,
          anchorBoneId: CatBones.torso,
          channel: KeyframeIkTargetChannel([]),
        ),
        const LimbIkTarget(
          upperBoneId: CatBones.armUpperR,
          lowerBoneId: CatBones.armLowerR,
          endBoneId: CatBones.handR,
          anchorBoneId: CatBones.torso,
          channel: KeyframeIkTargetChannel([]),
          bendDirection: -1,
        ),
        _danceLimbTargets[2],
        _danceLimbTargets[3],
      ],
    );
  }

  /// Standalone "Buga" catalog move — the unison-hit show-off move: three prep
  /// knee-dips loading at the chest, then a leg-DRIVEN full-height RISE (knees
  /// flex deep through the dips, extend on the hit) with a chest pop and BOTH
  /// arms snapping open into the peacock bow with a double shoulder shrug on
  /// each hit (frames 12 and 28) — the researched 2022 signature; the old
  /// one-arm overhead present was the audit's top authenticity finding.
  ///
  /// Assembled through `assembleMoveClip` (`dance_move_compiler.dart`) from
  /// its authored key data below.
  static Clip get buga {
    final base = _danceBase;
    return assembleMoveClip(
      _dancePhrase,
      DanceMoveDescriptor(
        // Must be exactly 'buga': CharacterScene._isDanceFamily gates several
        // dance-only runtime passes (support-foot stabilization among them)
        // on a literal clip-name match, not on clip structure. A different
        // name here would silently skip those passes and break the parity
        // this getter exists to prove.
        move: const AfrobeatsMove(
          name: 'buga',
          feel: DanceFeel.onBeat,
          featuredRegion: BodyRegion.arms,
          // ADR D4: Light bounces -> Strong·Direct·Sudden hit, holds.
          dynamics: DanceDynamics(weight: 0.5, time: 0.55, flow: -0.15),
        ),
        duration: base.duration,
        // Lateral neck-counter holds the skull firm over the collar so the
        // deepened pelvic obliquity below (0.05 -> 0.13) reads as a real hip
        // pop without tripping the "heads are terribly loose" wander bound.
        headLateralStabilize: 0.55,
        danceHeadLevelClampMin: -6,
        contactPinning: base.contactPinning,
        supportFootWorldAnchor: true,
        supportFootWorldAnchorStrength: 0.9,
        baseClip: base,
        jointTracks: {
          CatBones.head: const DanceJointTrack(_bugaHeadKeys, smooth: true),
          CatBones.clavicleR: const DanceJointTrack(
            _bugaClavicleRKeys,
            smooth: true,
            layerOnBase: true,
          ),
          CatBones.clavicleL: const DanceJointTrack(
            _bugaClavicleLKeys,
            smooth: true,
            layerOnBase: true,
          ),
          CatBones.shoulderSocketR: const DanceJointTrack(
            _bugaShoulderSocketRKeys,
            smooth: true,
          ),
          CatBones.shoulderSocketL: const DanceJointTrack(
            _bugaShoulderSocketLKeys,
            smooth: true,
          ),
          CatBones.legLowerL: const DanceJointTrack(
            _bugaLegLowerKeys,
            smooth: true,
          ),
          CatBones.legLowerR: const DanceJointTrack(
            _bugaLegLowerKeys,
            smooth: true,
          ),
          CatBones.handL: const DanceJointTrack(_bugaHandLKeys, smooth: true),
          CatBones.handR: const DanceJointTrack(_bugaHandRKeys, smooth: true),
          CatBones.footL: const DanceJointTrack(_bugaFootLKeys, smooth: true),
          CatBones.footR: const DanceJointTrack(_bugaFootRKeys, smooth: true),
        },
        bodyMotion: const DanceBodyMotion(
          pelvisBoneId: CatBones.hips,
          chestBoneId: CatBones.torso,
          tracks: [
            DanceBodyMotionTrack(
              keys: _bugaBodyKeys,
              rootMicroFrames: -0.1,
              pelvisMicroFrames: -0.15,
              // r10: 0.75 -> 1.0 — every r9 lens measured pocket/skull/
              // shoulder as ONE near-identical waveform ("torso rides as a
              // rigid block"). The chest (and everything riding it: crowns,
              // skull) now arrives a frame behind the hips on the lunges.
              // 1.0 is the chin-collar gate's actual headroom: 1.2 read
              // 24.75 and 1.6 read 25.2 against the 24.5 off-the-body
              // ceiling (and a bigger head budget moves it the WRONG way —
              // the budget bounds the leveler's lift, so more budget holds
              // the skull higher). The rest of the decoupling rides the
              // contrary-motion clavicle keys and the authored head snaps.
              chestMicroFrames: 1,
              chestRotationGain: 0.94,
              chestScaleGain: 0.98,
            ),
          ],
          extraRootLayers: [
            // r4/r5 (this time actually on buga — the first attempt's
            // regex overshot into sekem): lateral weight under the strides
            // + a beat-level mini-bounce so mid-bar frames stop floating
            // (pocket was 0.8 ev/s over a 97.8 range).
            // Baseline panel (mocap/physicist/coach): the groove reads as a
            // lateral LEAN, not a vertical hip POP. Rebalanced the lateral sway
            // DOWN (-12 -> -8) and the per-beat vertical bounce UP (-9 -> -13)
            // so the pocket pops vertically on the beat instead of swaying side
            // to side.
            // "Moving" pass: that -8 was tuned for a GENERIC hit move; this song
            // sways (Omah Lay "Moving" — a swaying diminished bassline, pensive,
            // not hectic), so the call reverses for this choreography. Raised to
            // -14 — a SMOOTH, gentle sway (hips-lateral range 44, between the
            // too-subtle -8/range-34 and the too-dramatic -12/-22) — plus a
            // gentle torso body-roll (leanAmplitude, phased with the sway) so the
            // weight-shift reads as a committed lean, not a lateral slide.
            SineRootChannel(
              swayAmplitude: -14,
              swayPhase: 0.125,
              swayHarmonic: 4,
              // Torso commits INTO the weighted side (a gentle body-roll phased
              // with the sway) so the weight-shift reads as a lean, not a slide.
              leanAmplitude: -0.06,
              leanPhase: 0.125,
              leanHarmonic: 4,
            ),
            // Calmed for the chill groove: a lighter per-beat bounce (was -13)
            // so the body vibes rather than pumps.
            SineRootChannel(bobAmplitude: -7, bobPhase: 0.09, bobHarmonic: 8),
          ],
          extraPelvisLayers: [
            SineChannel(
              harmonicAmplitude: 0.006,
              harmonicPhase: 0.02,
              harmonicMultiplier: 24,
              scaleXAmplitude: 0.002,
              scaleXPhase: 0.02,
              scaleXHarmonic: 24,
              scaleYAmplitude: -0.002,
              scaleYPhase: 0.02,
              scaleYHarmonic: 24,
            ),
            // Baseline panel (mocap "the single biggest thing", coach, physicist):
            // the pelvis stays LEVEL, so the groove reads as a knee-scissor squat,
            // not a hip-driven pop. Add pelvic OBLIQUITY — a per-bar hip hike/drop
            // (roll) phased with the lateral weight shift (sway is harmonic 4 at
            // phase 0.125) so the loaded-side hip hikes on the beat and the
            // accent reads as pelvis drive, not knee bend.
            SineChannel(
              harmonicAmplitude: 0.11,
              harmonicPhase: 0.125,
              harmonicMultiplier: 4,
            ),
          ],
        ),
        limbTargetTracks: {
          CatBones.handL: const DanceIkTargetTrack(
            _bugaHandLTargetKeys,
            cyclic: true,
          ),
          CatBones.handR: const DanceIkTargetTrack(
            _bugaHandRTargetKeys,
            cyclic: true,
          ),
          CatBones.footL: const DanceIkTargetTrack(_bugaFootLTargetKeys),
          CatBones.footR: const DanceIkTargetTrack(_bugaFootRTargetKeys),
        },
        // Span boundaries land ON the hits (f12/f28, phase 0.375/0.875): the
        // contact stack re-plants the support foot against the pose at the
        // span START, so the body can never rise far above its span-anchor
        // level — anchoring a fresh span at the tall hit lets the explosion
        // up actually happen, and the following descent is always
        // leg-absorbable. Authored as phase literals routed through the
        // declarative DanceSupportSpan.toGroundSpan path;
        // loadFrame/releaseFrame/maxPelvisDistance/pocketScaleY are all
        // dropped by toGroundSpan, so placeholder values are fine here.
        supports: const [
          DanceSupportSpan(
            footBoneId: CatBones.footR,
            freeFootBoneId: CatBones.footL,
            startFrame: 0,
            endFrame: 8,
            loadFrame: 0,
            releaseFrame: 7,
            maxPelvisDistance: 1,
            pocketScaleY: 1,
            label: 'buga reproduction R1',
          ),
          DanceSupportSpan(
            footBoneId: CatBones.footL,
            freeFootBoneId: CatBones.footR,
            startFrame: 8,
            endFrame: 12,
            loadFrame: 8,
            releaseFrame: 11,
            maxPelvisDistance: 1,
            pocketScaleY: 1,
            label: 'buga reproduction L1',
          ),
          DanceSupportSpan(
            footBoneId: CatBones.footR,
            freeFootBoneId: CatBones.footL,
            startFrame: 12,
            endFrame: 16,
            loadFrame: 12,
            releaseFrame: 15,
            maxPelvisDistance: 1,
            pocketScaleY: 1,
            label: 'buga reproduction R2',
          ),
          DanceSupportSpan(
            footBoneId: CatBones.footL,
            freeFootBoneId: CatBones.footR,
            startFrame: 16,
            endFrame: 24,
            loadFrame: 16,
            releaseFrame: 23,
            maxPelvisDistance: 1,
            pocketScaleY: 1,
            label: 'buga reproduction L2',
          ),
          DanceSupportSpan(
            footBoneId: CatBones.footR,
            freeFootBoneId: CatBones.footL,
            startFrame: 24,
            endFrame: 28,
            loadFrame: 24,
            releaseFrame: 27,
            maxPelvisDistance: 1,
            pocketScaleY: 1,
            label: 'buga reproduction R3',
          ),
          DanceSupportSpan(
            footBoneId: CatBones.footL,
            freeFootBoneId: CatBones.footR,
            startFrame: 28,
            endFrame: 32,
            loadFrame: 28,
            releaseFrame: 31,
            maxPelvisDistance: 1,
            pocketScaleY: 1,
            label: 'buga reproduction L3',
          ),
        ],
        extraJointChannels: {
          CatBones.earL: _earFollow(side: 1, amplitude: 0.026),
          CatBones.earR: _earFollow(side: -1, amplitude: 0.026, phase: 0.55),
          ..._tailFollowThrough(amplitude: 0.13, phase: 0.09),
        },
      ),
      // Outboard elbow bends, and the targets make them safe: on the
      // vertical thigh-hang the elbow bows naturally OUTWARD (inboard
      // tucked it against the belly — a mild contralateral fold the
      // anti-fold clamp caught), and on the wide extended hit the high
      // reach shrinks the elbow offset enough that the wing sits right on
      // the shoulder line instead of finning above it. Bend sign and
      // target reach are buga's own choreographic choice — the inverse of
      // the shared rig's groove defaults — so fresh hand entries are
      // supplied here rather than reusing the shared rig constant. Feet DO
      // reuse the shared rig entries directly.
      rigLimbTargets: [
        const LimbIkTarget(
          upperBoneId: CatBones.armUpperL,
          lowerBoneId: CatBones.armLowerL,
          endBoneId: CatBones.handL,
          anchorBoneId: CatBones.torso,
          channel: KeyframeIkTargetChannel([]),
        ),
        const LimbIkTarget(
          upperBoneId: CatBones.armUpperR,
          lowerBoneId: CatBones.armLowerR,
          endBoneId: CatBones.handR,
          anchorBoneId: CatBones.torso,
          channel: KeyframeIkTargetChannel([]),
          bendDirection: -1,
        ),
        _danceLimbTargets[2],
        _danceLimbTargets[3],
      ],
    );
  }

  /// Standalone "Pouncing Cat" catalog move — a cat-character contrast phrase:
  /// compress, push, land, and rebound through a shoulder/hip pocket. The old
  /// leap/pounce version was legible but not Afrobeats; this version keeps the
  /// pounce readable while making the paws compact and rhythmic.
  ///
  /// Assembled through `assembleMoveClip` (`dance_move_compiler.dart`) from
  /// its authored key data below.
  static Clip get pouncingCat {
    final base = _danceBase;
    return assembleMoveClip(
      _dancePhrase,
      DanceMoveDescriptor(
        move: const AfrobeatsMove(
          name: 'pouncingCat',
          feel: DanceFeel.halfTime,
          featuredRegion: BodyRegion.full,
          // ADR D4: Sustained · Bound · Light glide.
          dynamics: DanceDynamics(weight: -0.55, time: -0.65, flow: -0.35),
        ),
        duration: base.duration,
        contactPinning: base.contactPinning,
        supportFootWorldAnchor: true,
        supportFootWorldAnchorStrength: 0.88,
        // NOT boosted like zanku/shaku/azonto/sekem despite a similar
        // sustained-crouch profile: this move's chin-to-collar gap and
        // head-level probe are already tuned right at their own thresholds
        // (owner, GIF review: the neck "often all but disappears"), and a
        // 0.11 vertical boost measurably tipped both over — see
        // Clip.supportFootWorldAnchorVerticalBoost's doc comment.
        danceHeadBobScale: 0,
        danceHeadLevelClampMin: -20,
        baseClip: base,
        bodyMotion: const DanceBodyMotion(
          pelvisBoneId: CatBones.hips,
          chestBoneId: CatBones.torso,
          tracks: [
            DanceBodyMotionTrack(
              keys: _pounceBodyKeys,
              pelvisSmooth: false,
              chestSmooth: false,
            ),
            DanceBodyMotionTrack(keys: _pounceGrooveKeys),
          ],
          extraChestLayers: [
            SineChannel(harmonicAmplitude: -0.04, harmonicPhase: 0.02),
          ],
        ),
        limbTargetTracks: {
          CatBones.handL: const DanceIkTargetTrack(_pounceHandLTargetKeys),
          CatBones.handR: const DanceIkTargetTrack(_pounceHandRTargetKeys),
          CatBones.footL: const DanceIkTargetTrack(_pounceFootLTargetKeys),
          CatBones.footR: const DanceIkTargetTrack(_pounceFootRTargetKeys),
        },
        rawContactSpans: _pounceContactSpans,
        extraJointChannels: {
          // Neck/head held flat (no inherited dance nod) so the head stays
          // level — see the real getter's comment on danceHeadBobScale.
          CatBones.neck: const SineChannel(),
          CatBones.head: const SineChannel(),
          CatBones.earL: _earFollow(side: 1, amplitude: 0.02, phase: 0.16),
          CatBones.earR: _earFollow(side: -1, amplitude: 0.02, phase: 0.61),
          ..._tailFollowThrough(amplitude: 0.085, phase: 0.14),
        },
      ),
      // Outboard elbow bends: the cross-body swipes lead with the PAW while
      // the elbow trails outboard (a cat swipe, not a chicken wing), and the
      // return to the own-side guard needs the same sign. The inherited
      // inboard bends left the elbow folded across the sternum while the
      // paw exited — the worst contralateral fold in the catalogue (3.0 rad
      // asked).
      rigLimbTargets: [
        const LimbIkTarget(
          upperBoneId: CatBones.armUpperL,
          lowerBoneId: CatBones.armLowerL,
          endBoneId: CatBones.handL,
          anchorBoneId: CatBones.torso,
          channel: KeyframeIkTargetChannel([]),
        ),
        const LimbIkTarget(
          upperBoneId: CatBones.armUpperR,
          lowerBoneId: CatBones.armLowerR,
          endBoneId: CatBones.handR,
          anchorBoneId: CatBones.torso,
          channel: KeyframeIkTargetChannel([]),
          bendDirection: -1,
        ),
        _danceLimbTargets[2],
        _danceLimbTargets[3],
      ],
    );
  }

  /// Standalone "Sekem" catalog move — the grounded-stomp contrast: a free foot
  /// per beat does a pick-up → coil → SLAM (one hard low plant per beat, L,R,L,R)
  /// with a deep on-beat body squash, widened stance, and low hand paddles that
  /// follow the torso with a one-frame elbow/wrist lag.
  ///
  /// Assembled through `assembleMoveClip` (`dance_move_compiler.dart`) from
  /// its authored key data below.
  static Clip get sekem {
    final base = _danceBase;
    return assembleMoveClip(
      _dancePhrase,
      DanceMoveDescriptor(
        move: const AfrobeatsMove(
          name: 'sekem',
          feel: DanceFeel.onBeat,
          featuredRegion: BodyRegion.chest,
          // ADR D4: Strong · Sudden plant · Bound.
          dynamics: DanceDynamics(weight: 0.65, time: 0.55, flow: -0.4),
        ),
        duration: base.duration,
        enforceSoleFloor: true,
        contactPinning: base.contactPinning,
        supportFootWorldAnchor: true,
        supportFootWorldAnchorStrength: 0.9,
        // Transitions panel: sekem is explicitly authored to DWELL over the
        // planting foot (avg ~30px, never near standing height) — same fix
        // as zanku/shaku/azonto/pouncingCat, see
        // Clip.supportFootWorldAnchorVerticalBoost.
        supportFootWorldAnchorVerticalBoost: 0.09,
        danceHeadBobScale: 0.75,
        baseClip: base,
        jointTracks: {
          CatBones.head: const DanceJointTrack(_sekemHeadKeys, smooth: true),
          CatBones.footL: const DanceJointTrack(_sekemFootLKeys, smooth: true),
          CatBones.footR: const DanceJointTrack(_sekemFootRKeys, smooth: true),
          CatBones.handL: const DanceJointTrack(_sekemHandLKeys, smooth: true),
          CatBones.handR: const DanceJointTrack(_sekemHandRKeys, smooth: true),
          CatBones.clavicleR: const DanceJointTrack(
            _sekemClavicleRKeys,
            smooth: true,
            layerOnBase: true,
          ),
          CatBones.clavicleL: const DanceJointTrack(
            _sekemClavicleLKeys,
            smooth: true,
            layerOnBase: true,
          ),
          CatBones.shoulderSocketR: const DanceJointTrack(
            _sekemShoulderSocketRKeys,
            smooth: true,
          ),
          CatBones.shoulderSocketL: const DanceJointTrack(
            _sekemShoulderSocketLKeys,
            smooth: true,
          ),
        },
        bodyMotion: DanceBodyMotion(
          pelvisBoneId: CatBones.hips,
          chestBoneId: CatBones.torso,
          tracks: [
            DanceBodyMotionTrack(
              keys: _sekemBodyKeys,
              pelvisMicroFrames: -0.1,
              chestMicroFrames: 0.9,
              chestRotationGain: 0.74,
              chestScaleGain: 0.86,
              pelvisSmooth: false,
              chestSmooth: false,
            ),
            const DanceBodyMotionTrack(
              keys: _sekemPocketBoostKeys,
              rootMicroFrames: -0.3,
              pelvisMicroFrames: -0.2,
              chestMicroFrames: 1.05,
              chestRotationGain: 0.68,
              chestScaleGain: 0.84,
            ),
            const DanceBodyMotionTrack(
              keys: _sekemSettleKeys,
              rootMicroFrames: -0.15,
              pelvisMicroFrames: -0.1,
              chestMicroFrames: 0.95,
              chestRotationGain: 0.42,
              chestScaleGain: 0.68,
            ),
          ],
          extraRootLayers: const [
            // NOTE: this h4 layer was aimed at buga but a regex ran past
            // buga's (then-nonexistent) extraRootLayers into THIS stack —
            // and the r4 panel scored sekem's sway "best in the set" (8.7)
            // WITH it. Kept deliberately; buga now has its own block.
            SineRootChannel(swayAmplitude: -5, swayHarmonic: 4),
            // 9-path round 2: keep-alive breath — the two ~1s lunge holds
            // read as pose freezes (R3: 'a freeze rather than a settled
            // hold'). A micro h16 bob keeps the mass breathing everywhere.
            SineRootChannel(bobAmplitude: -1.8, bobHarmonic: 16),
            SineRootChannel(
              swayAmplitude: 1.55,
              swayHarmonic: 8,
              swayPhase: -0.035,
              leanAmplitude: 0.0012,
              leanHarmonic: 8,
              leanPhase: -0.02,
            ),
          ],
          extraPelvisLayers: const [
            SineChannel(
              harmonicAmplitude: 0.042,
              harmonicMultiplier: 8,
              harmonicPhase: -0.025,
              scaleXAmplitude: 0.012,
              scaleXHarmonic: 8,
              scaleXPhase: -0.025,
              scaleYAmplitude: -0.01,
              scaleYHarmonic: 8,
              scaleYPhase: -0.025,
            ),
          ],
          extraChestLayers: const [
            SineChannel(
              harmonicAmplitude: -0.026,
              harmonicMultiplier: 8,
              harmonicPhase: 0.03,
              scaleXAmplitude: -0.007,
              scaleXHarmonic: 8,
              scaleXPhase: 0.03,
              scaleYAmplitude: 0.006,
              scaleYHarmonic: 8,
              scaleYPhase: 0.03,
            ),
          ],
        ),
        limbTargetTracks: {
          CatBones.handL: const DanceIkTargetTrack(
            _sekemHandLTargetKeys,
            cyclic: true,
            microFrames: 0.1,
          ),
          CatBones.handR: const DanceIkTargetTrack(
            _sekemHandRTargetKeys,
            cyclic: true,
            microFrames: 0.1,
          ),
          CatBones.footL: const DanceIkTargetTrack(_sekemFootLTargetKeys),
          CatBones.footR: const DanceIkTargetTrack(_sekemFootRTargetKeys),
        },
        rawContactSpans: _sekemContactSpans,
        extraJointChannels: {
          CatBones.earL: _earFollow(side: 1),
          CatBones.earR: _earFollow(side: -1, phase: 0.55),
          ..._tailFollowThrough(amplitude: 0.1, phase: 0.07),
        },
      ),
      // Sekem is own-side paddles, not a crossed-arm pose. Use explicit
      // OUTSIDE elbow bends so the sleeve ribbon stays on the same
      // anatomical side as the paw; inheriting the generic dance bends let
      // the upper arms fold through the chest while the paws stayed low,
      // which produced an impossible X.
      rigLimbTargets: [
        const LimbIkTarget(
          upperBoneId: CatBones.armUpperL,
          lowerBoneId: CatBones.armLowerL,
          endBoneId: CatBones.handL,
          anchorBoneId: CatBones.torso,
          channel: KeyframeIkTargetChannel([]),
        ),
        const LimbIkTarget(
          upperBoneId: CatBones.armUpperR,
          lowerBoneId: CatBones.armLowerR,
          endBoneId: CatBones.handR,
          anchorBoneId: CatBones.torso,
          channel: KeyframeIkTargetChannel([]),
          bendDirection: -1,
        ),
        _danceLimbTargets[2],
        _danceLimbTargets[3],
      ],
    );
  }

  static Clip get danceBackupLeft => _danceStyledRole(
    name: 'danceBackupLeft',
    style: _danceBackupLeftStyle,
  );

  static Clip get danceBackupRight => _danceStyledRole(
    name: 'danceBackupRight',
    style: _danceBackupRightStyle,
  );

  static Clip _danceStyledRole({
    required String name,
    required DanceRoleStyle style,
  }) {
    final base = _danceBase;
    final bodyKeys = style.bodyKeys(_dancePhrase);
    return Clip(
      name: name,
      duration: base.duration,
      contactSpans: base.contactSpans,
      contactPinning: base.contactPinning,
      limbTargets: _danceRoleLimbTargets(style),
      root: LayeredRootChannel([
        base.root,
        _bodyRootLeadChannel(bodyKeys, smooth: true),
      ]),
      channels: {
        ...base.channels,
        CatBones.hips: LayeredJointChannel([
          base.channels[CatBones.hips]!,
          _bodyPelvisLeadChannel(bodyKeys, smooth: true),
          _danceRoleJointChannel(style, CatBones.hips),
        ]),
        CatBones.torso: LayeredJointChannel([
          base.channels[CatBones.torso]!,
          _bodyChestFollowChannel(bodyKeys, smooth: true),
          _danceRoleJointChannel(style, CatBones.torso),
        ]),
        CatBones.armUpperL: LayeredJointChannel([
          base.channels[CatBones.armUpperL]!,
          _danceRoleJointChannel(style, CatBones.armUpperL),
        ]),
        CatBones.armUpperR: LayeredJointChannel([
          base.channels[CatBones.armUpperR]!,
          _danceRoleJointChannel(style, CatBones.armUpperR),
        ]),
        CatBones.armLowerL: LayeredJointChannel([
          base.channels[CatBones.armLowerL]!,
          _danceRoleJointChannel(style, CatBones.armLowerL),
        ]),
        CatBones.armLowerR: LayeredJointChannel([
          base.channels[CatBones.armLowerR]!,
          _danceRoleJointChannel(style, CatBones.armLowerR),
        ]),
      },
    );
  }

  static JointChannel _danceRoleJointChannel(
    DanceRoleStyle style,
    String boneId,
  ) => _dancePhrase.jointChannel(
    style.jointKeys(_dancePhrase, boneId),
    smooth: true,
  );

  /// Standalone "Idle" catalog move — the resting-alive breathing loop.
  /// Every channel is a bare procedural `SineChannel`/`SineRootChannel`
  /// texture (no authored keys at all), so it's assembled entirely through
  /// the `rawRoot`/`extraJointChannels` escape hatches.
  static Clip get idle => assembleMoveClip(
    _dancePhrase,
    const DanceMoveDescriptor(
      move: AfrobeatsMove(
        name: 'idle',
        feel: DanceFeel.onBeat,
        featuredRegion: BodyRegion.full,
      ),
      duration: 3.6,
      // Breathing lives in the CHEST (scaleY), not a whole-body bob — a bob
      // lifts the planted feet off the floor and reads as floating/helium.
      // A whisper of bob (-1) is all that's left so the shoulders just
      // barely rise on the breath.
      rawRoot: SineRootChannel(bobAmplitude: -1, bobHarmonic: 1),
      extraJointChannels: {
        // Breathing: the chest expands (scaleY) and the spine sways a hair,
        // so the character is never a frozen frame even when standing
        // still. The face's autonomic blink + eye-darts layer on top for
        // the rest of the "alive".
        CatBones.torso: SineChannel(amplitude: 0.01, scaleYAmplitude: 0.045),
        CatBones.hips: SineChannel(amplitude: 0.012, phase: 0.5),
        // A tiny, slow head settle — kept very tight so the head sits on
        // the shoulders instead of drifting/floating around.
        CatBones.neck: SineChannel(amplitude: 0.002, phase: 0.2),
        CatBones.head: SineChannel(amplitude: 0.0015, phase: 0.35),
        CatBones.armLowerL: SineChannel(amplitude: 0.03, bias: 0.18),
        CatBones.armLowerR: SineChannel(
          amplitude: 0.03,
          phase: 0.5,
          bias: 0.18,
        ),
        // Ears twitch slowly (listening) and the tail does a lazy
        // travelling sway down all 7 links — the "alive at rest" tell.
        CatBones.tie: SineChannel(amplitude: 0.015, phase: 0.2),
        CatBones.tieLower: SineChannel(
          amplitude: 0.012,
          phase: 0.23,
          bias: 0.025,
        ),
        CatBones.earL: SineChannel(amplitude: 0.03, phase: 0.3),
        CatBones.earR: SineChannel(amplitude: 0.03, phase: 0.8),
        CatBones.tail0: SineChannel(amplitude: 0.04, bias: 0.05),
        CatBones.tail1: SineChannel(amplitude: 0.06, phase: 0.08),
        CatBones.tail2: SineChannel(amplitude: 0.08, phase: 0.16),
        CatBones.tail3: SineChannel(amplitude: 0.11, phase: 0.24),
        CatBones.tail4: SineChannel(amplitude: 0.14, phase: 0.32),
        CatBones.tail5: SineChannel(amplitude: 0.17, phase: 0.4),
        CatBones.tail6: SineChannel(
          amplitude: 0.21,
          phase: 0.48,
          harmonicAmplitude: 0.07,
          harmonicPhase: 0.5,
        ),
      },
    ),
  );

  static List<Clip> get all => [
    kick,
    movingGroove,
    shaku,
    zanku,
    azonto,
    buga,
    pouncingCat,
    sekem,
    idle,
  ];
}
