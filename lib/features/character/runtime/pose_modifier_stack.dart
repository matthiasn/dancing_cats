import 'package:dancing_cats/features/character/model/clip.dart';
import 'package:dancing_cats/features/character/model/pose.dart';

typedef PoseModifier = Pose Function(PoseModifierContext context, Pose pose);

/// Runtime context shared by local-space pose modifier passes.
class PoseModifierContext {
  const PoseModifierContext({
    required this.clip,
    required this.timeSeconds,
    required this.breath,
    this.earTwitchLeft = 0,
    this.earTwitchRight = 0,
  });

  final Clip clip;
  final double timeSeconds;
  final double breath;

  /// Autonomic ear twitch pulses (0 when autonomics are excluded).
  final double earTwitchLeft;
  final double earTwitchRight;
}

/// One named pass in the local-space pose solve.
///
/// The name is deliberately stable: tests, diagnostics, and review tooling can
/// assert constraint order without parsing private `CharacterScene` control
/// flow. `mix` is reserved for future partial-strength passes; current passes
/// preserve their historical full-strength behavior.
class PoseModifierPass {
  const PoseModifierPass({
    required this.id,
    required this.description,
    required this.modifier,
    this.mix = 1,
  }) : assert(mix >= 0 && mix <= 1, 'mix must be in 0..1');

  final String id;
  final String description;
  final PoseModifier modifier;
  final double mix;
}

/// Ordered local-space pose modifier pipeline.
class PoseModifierStack {
  PoseModifierStack(List<PoseModifierPass> passes)
    : passes = List<PoseModifierPass>.unmodifiable(passes);

  final List<PoseModifierPass> passes;

  Pose apply(PoseModifierContext context, Pose initialPose) {
    var pose = initialPose;
    for (final pass in passes) {
      if (pass.mix <= 0) continue;
      pose = pass.modifier(context, pose);
    }
    return pose;
  }
}
