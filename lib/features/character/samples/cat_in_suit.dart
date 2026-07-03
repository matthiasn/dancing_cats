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
import 'package:dancing_cats/features/character/model/dance_move_compiler.dart';
import 'package:dancing_cats/features/character/model/dance_move_descriptor.dart';
import 'package:dancing_cats/features/character/model/dance_phrase.dart';
import 'package:dancing_cats/features/character/model/easing.dart';
import 'package:dancing_cats/features/character/model/face.dart';
import 'package:dancing_cats/features/character/model/rig_spec.dart';
import 'package:dancing_cats/features/character/model/trunk_surface.dart';

part 'cat_in_suit_rig.dart';
part 'moves/buga_data.dart';
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

  static Clip get kick => const Clip(
    name: 'kick',
    duration: 1,
    loop: false,
    contactSpans: [
      GroundSpan(CatBones.footL, 0, 1),
    ],
    // Anticipate down, chamber, snap a high side kick, then recoil and settle.
    // No locomotion: this is a stage move in place, so the support foot stays
    // readable while the silhouette carries the action.
    root: KeyframeRootChannel([
      RootKeyframe(p: 0),
      RootKeyframe(p: 0.1, dy: 16, dx: -7, rotation: 0.03, ease: Ease.easeOut),
      RootKeyframe(p: 0.22, dy: 12, dx: -14, rotation: -0.02),
      RootKeyframe(
        p: 0.3,
        dy: -11,
        dx: -19,
        rotation: -0.07,
        ease: Ease.easeOut,
      ),
      RootKeyframe(p: 0.4, dy: -10, dx: -19, rotation: -0.065),
      RootKeyframe(p: 0.52, dy: 8, dx: -12, rotation: 0.02, ease: Ease.easeIn),
      RootKeyframe(p: 0.68, dy: 4, dx: -5, rotation: 0.01, ease: Ease.easeOut),
      RootKeyframe(p: 0.82, dy: -2, dx: -1, rotation: -0.005),
      RootKeyframe(p: 1),
    ]),
    channels: {
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
  );

  static Clip get _danceBase => Clip(
    name: '_danceBase',
    duration: 6,
    contactSpans: _danceContactSpans,
    contactPinning: ContactPinning.lowestContact,
    limbTargets: _danceLimbTargets,
    root: LayeredRootChannel([
      _bodyRootLeadChannel(_danceBodyGrooveKeys, smooth: true),
      _bodyRootLeadChannel(_danceBodyAccentKeys, smooth: true),
      const SineRootChannel(
        bobAmplitude: -0.055,
        bobPhase: 0.125,
        bobHarmonic: 8,
        leanAmplitude: 0.001,
        leanHarmonic: 8,
      ),
      const SineRootChannel(
        // Tiny double-time pulse keeps the torso alive between count hits
        // without lifting both feet off the deck.
        bobAmplitude: -0.008,
        bobPhase: 0.02,
        bobHarmonic: 16,
        leanAmplitude: 0.0001,
        leanPhase: 0.03,
        leanHarmonic: 16,
      ),
    ]),
    channels: {
      // A compact two-step groove: hips lead, chest counters, head stays
      // mostly locked to the viewer so the dance reads as body rhythm instead
      // of a wobbling face.
      CatBones.hips: LayeredJointChannel([
        _bodyPelvisLeadChannel(_danceBodyGrooveKeys, smooth: true),
        _bodyPelvisLeadChannel(_danceBodyAccentKeys, smooth: true),
        const SineChannel(
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
      ]),
      CatBones.torso: LayeredJointChannel([
        _bodyChestFollowChannel(_danceBodyGrooveKeys, smooth: true),
        _bodyChestFollowChannel(_danceBodyAccentKeys, smooth: true),
        const SineChannel(
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
      ]),
      CatBones.clavicleL: const LayeredJointChannel([
        SineChannel(
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
      ]),
      CatBones.clavicleR: const LayeredJointChannel([
        SineChannel(
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
      ]),
      CatBones.neck: const KeyframeChannel(_danceNeckKeys, smooth: true),
      CatBones.head: const KeyframeChannel(_danceHeadKeys, smooth: true),

      // Step-touch legs plus a 4-beat Gbese toe-flick bounce: right flick,
      // rebound, left flick, reset. The support foot stays opposite the flick.
      CatBones.legUpperL: _dancePhrase.jointChannel(
        _danceLegUpperLKeys,
        smooth: true,
      ),
      CatBones.legUpperR: _dancePhrase.jointChannel(
        _danceLegUpperRKeys,
        smooth: true,
      ),
      CatBones.legLowerL: _dancePhrase.jointChannel(
        _danceLegLowerLKeys,
        smooth: true,
      ),
      CatBones.legLowerR: _dancePhrase.jointChannel(
        _danceLegLowerRKeys,
        smooth: true,
      ),
      CatBones.footL: LayeredJointChannel([
        _dancePhrase.jointChannel(_danceFootLLeadKeys, smooth: true),
        _dancePhrase.jointChannel(_danceFootLAccentKeys, smooth: true),
      ]),
      CatBones.footR: _dancePhrase.jointChannel(
        _danceFootRLeadKeys,
        smooth: true,
      ),

      // Alternating groove arms for counts 1-8, then compact elbow pops for the
      // Gbese phrase so hands stay visible outside the belly silhouette.
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

      CatBones.tie: const KeyframeChannel(_danceTieKeys, smooth: true),
      CatBones.tieLower: const KeyframeChannel(
        _danceTieLowerKeys,
        smooth: true,
      ),
      CatBones.earL: const KeyframeChannel(_danceEarLKeys, smooth: true),
      CatBones.earR: const KeyframeChannel(_danceEarRKeys, smooth: true),
      ..._tailFollowThrough(amplitude: 0.13, phase: 0.04),
    },
  );

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
        ),
        duration: base.duration,
        contactPinning: base.contactPinning,
        supportFootWorldAnchor: true,
        supportFootWorldAnchorStrength: 0.86,
        danceHeadBobScale: 0.8,
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
        },
        bodyMotion: DanceBodyMotion(
          pelvisBoneId: CatBones.hips,
          chestBoneId: CatBones.torso,
          tracks: [
            DanceBodyMotionTrack(
              keys: _shakuGrooveCalm,
              rootMicroFrames: 0,
              pelvisMicroFrames: -0.3,
              chestMicroFrames: 0.25,
              chestRotationGain: 0.68,
            ),
            DanceBodyMotionTrack(
              keys: _danceBodyAccentKeys,
              rootMicroFrames: 0,
              pelvisMicroFrames: -0.3,
              chestMicroFrames: 0.25,
            ),
            const DanceBodyMotionTrack(
              keys: _shakuDabBodyKeys,
              rootMicroFrames: 0,
              pelvisMicroFrames: -0.3,
              chestMicroFrames: 0.25,
              chestRotationGain: 0.68,
            ),
            const DanceBodyMotionTrack(
              keys: _shakuPanelBodyKeys,
              rootMicroFrames: 0,
              pelvisMicroFrames: -0.3,
              chestMicroFrames: 0.25,
              chestRotationGain: 0.68,
            ),
          ],
          extraRootLayers: const [
            SineRootChannel(swayAmplitude: -2, leanAmplitude: -0.04),
            SineRootChannel(
              bobAmplitude: -10,
              bobPhase: 0.09375,
              bobHarmonic: 8,
              leanAmplitude: 0.015,
              leanHarmonic: 8,
            ),
            SineRootChannel(
              bobAmplitude: -3.5,
              bobPhase: 0.02,
              bobHarmonic: 16,
              leanAmplitude: 0.006,
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
            SineChannel(amplitude: 0.115),
          ],
        ),
        limbTargetTracks: {
          CatBones.handL: const DanceIkTargetTrack(
            _shakuHandLTargetKeys,
            cyclic: true,
          ),
          CatBones.handR: const DanceIkTargetTrack(
            _shakuHandRTargetKeys,
            cyclic: true,
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
        ),
        duration: base.duration,
        contactPinning: base.contactPinning,
        supportFootWorldAnchor: true,
        supportFootWorldAnchorStrength: 0.9,
        danceHeadBobScale: 0.75,
        baseClip: base,
        jointTracks: {
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
            SineRootChannel(
              bobAmplitude: -8,
              bobPhase: 0.09375,
              bobHarmonic: 8,
            ),
          ],
          extraChestLayers: const [
            SineChannel(bias: 0.17),
            SineChannel(
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
          ),
          CatBones.handR: const DanceIkTargetTrack(
            _zankuHandRTargetKeys,
            cyclic: true,
          ),
          CatBones.footL: const DanceIkTargetTrack(_zankuFootLTargetKeys),
          CatBones.footR: const DanceIkTargetTrack(_zankuFootRTargetKeys),
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
        ),
        duration: base.duration,
        contactPinning: base.contactPinning,
        supportFootWorldAnchor: true,
        supportFootWorldAnchorStrength: 0.86,
        danceHeadBobScale: 0.7,
        baseClip: base,
        jointTracks: {
          CatBones.handL: const DanceJointTrack(
            _azontoHandLKeys,
            smooth: true,
          ),
          CatBones.handR: const DanceJointTrack(
            _azontoHandRKeys,
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
            SineRootChannel(
              bobAmplitude: -0.04,
              bobPhase: 0.125,
              bobHarmonic: 8,
            ),
            SineRootChannel(swayAmplitude: -4, swayHarmonic: 2),
          ],
          extraPelvisLayers: const [SineChannel(harmonicAmplitude: 0.17)],
          extraChestLayers: const [
            SineChannel(harmonicAmplitude: -0.11, harmonicPhase: 0.02),
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
        ),
        duration: base.duration,
        contactPinning: base.contactPinning,
        supportFootWorldAnchor: true,
        supportFootWorldAnchorStrength: 0.9,
        baseClip: base,
        jointTracks: {
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
          CatBones.armBicepR: const DanceJointTrack(
            _bugaBicepKeys,
            smooth: true,
          ),
          CatBones.armBicepL: const DanceJointTrack(
            _bugaBicepKeys,
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
        },
        bodyMotion: const DanceBodyMotion(
          pelvisBoneId: CatBones.hips,
          chestBoneId: CatBones.torso,
          tracks: [
            DanceBodyMotionTrack(
              keys: _bugaBodyKeys,
              rootMicroFrames: -0.1,
              pelvisMicroFrames: -0.15,
              chestMicroFrames: 0.75,
              chestRotationGain: 0.94,
              chestScaleGain: 0.98,
            ),
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
        ),
        duration: base.duration,
        contactPinning: base.contactPinning,
        supportFootWorldAnchor: true,
        supportFootWorldAnchorStrength: 0.88,
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
        ),
        duration: base.duration,
        contactPinning: base.contactPinning,
        supportFootWorldAnchor: true,
        supportFootWorldAnchorStrength: 0.9,
        danceHeadBobScale: 0.75,
        baseClip: base,
        jointTracks: {
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

  static Clip get idle => const Clip(
    name: 'idle',
    duration: 3.6,
    // Breathing lives in the CHEST (scaleY), not a whole-body bob — a bob lifts
    // the planted feet off the floor and reads as floating/helium. A whisper of
    // bob (-1) is all that's left so the shoulders just barely rise on the breath.
    root: SineRootChannel(bobAmplitude: -1, bobHarmonic: 1),
    channels: {
      // Breathing: the chest expands (scaleY) and the spine sways a hair, so the
      // character is never a frozen frame even when standing still. The face's
      // autonomic blink + eye-darts layer on top for the rest of the "alive".
      CatBones.torso: SineChannel(amplitude: 0.01, scaleYAmplitude: 0.045),
      CatBones.hips: SineChannel(amplitude: 0.012, phase: 0.5),
      // A tiny, slow head settle — kept very tight so the head sits on the
      // shoulders instead of drifting/floating around.
      CatBones.neck: SineChannel(amplitude: 0.002, phase: 0.2),
      CatBones.head: SineChannel(amplitude: 0.0015, phase: 0.35),
      CatBones.armLowerL: SineChannel(amplitude: 0.03, bias: 0.18),
      CatBones.armLowerR: SineChannel(amplitude: 0.03, phase: 0.5, bias: 0.18),
      // Ears twitch slowly (listening) and the tail does a lazy travelling sway
      // down all 7 links — the "alive at rest" tell.
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
  );

  static List<Clip> get all => [
    kick,
    shaku,
    zanku,
    azonto,
    buga,
    pouncingCat,
    sekem,
    idle,
  ];
}
