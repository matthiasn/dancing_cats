# Popular rigging project lessons for the dance cat (2026-07-01)

This is a focused follow-up to `2026-07-01-native-animation-runtime-lessons.md`.
The question here is narrower: what do popular character-animation tools keep
doing that maps directly to our current failures: raised shoulders, sausage arms,
robotic transitions, crossed-arm muddiness, and stiff secondary parts?

## Sources reviewed

- Spine: weights, meshes, IK constraints, slots/draw order, graph/dopesheet,
  runtime mix/draw-order timelines.
  - https://esotericsoftware.com/spine-weights
  - https://esotericsoftware.com/spine-meshes
  - https://esotericsoftware.com/spine-ik-constraints
  - https://esotericsoftware.com/spine-slots
  - https://esotericsoftware.com/spine-graph
  - https://esotericsoftware.com/spine-dopesheet
  - https://esotericsoftware.com/spine-api-reference
- Rive: meshes, IK constraints, state machine layers, animation mixing.
  - https://rive.app/docs/editor/manipulating-shapes/meshes
  - https://rive.app/docs/editor/constraints/ik-constraint
  - https://rive.app/docs/editor/state-machine/layers
  - https://rive.app/docs/editor/animate-mode/animation-mixing
- Godot: 2D modification stack, TwoBoneIK, AnimationTree.
  - https://docs.godotengine.org/en/stable/classes/class_skeletonmodificationstack2d.html
  - https://docs.godotengine.org/en/stable/classes/class_skeletonmodification2dtwoboneik.html
  - https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html
- Live2D Cubism: deformers and extended interpolation.
  - https://docs.live2d.com/en/cubism-editor-manual/deformer/
  - https://docs.live2d.com/en/cubism-editor-manual/extended-interpolation/
- DragonBones: mesh/FFD, IK, skinning, curve editor, onion skin.
  - https://dragonbones.github.io/en/animation.html

## Repeated patterns

### 1. Weighted surfaces are the body, not decoration

Spine, Rive, DragonBones, Godot, and Live2D all treat soft attachment as a mesh
or deformer problem. The important part is not "make the sleeve prettier"; it is
"bind vertices to the transforms that actually own that body volume." Spine also
emphasizes testing weights through maximum-range poses and using smoothing/prune
passes; this maps directly to our raised-arm and crossed-arm checks.

For this repo:

- Keep arms as weighted surfaces, not visible capsule chains.
- Add pose-conditioned shoulder correctives when static weights are not enough:
  e.g. if arm elevation passes a threshold, the armpit/shoulder vertices should
  shift through clavicle + upper-arm weights.
- Add a shoulder-gap validator that samples solved mesh vertices, not just bone
  origins. The failure we care about is visible cloth separation or collapse.

### 2. Constraint order is a rig design decision

Rive and Godot make constraint order and strength explicit. Godot's stack docs
call out that full-body setups must solve spine before arms; Rive's IK docs make
strength/order first-class so rigs can blend FK/IK and multiple targets.

For this repo, the constraint order should become explicit:

1. authored local pose;
2. root/pelvis/chest timing offsets;
3. support-foot anchors and balance;
4. shoulder/clavicle correctives;
5. hand/foot IK with reach, bend, residual, and lane validation;
6. pose-conditioned mesh correctives;
7. tail/ear/tie follow-through.

That ordering is the path away from random pose tweaks.

### 3. Robotic motion is a mixer problem, not just a key problem

Spine track entries, Rive state machines/layers, and Godot AnimationTree all put
transitions in a separate runtime layer. They do not rely on one clip instantly
replacing another. They also keep layering explicit: base motion, action/accent,
interaction/override, and runtime response can mix without erasing the whole
pose.

For this repo:

- Add a small `DanceMixer` before trying to polish every catalogue clip.
- Keep a base groove layer always alive.
- Crossfade action clips only at beat-safe windows and only over bones they own.
- Keep shoulders/tail/ears as additive or masked layers, so they do not reset
  when the move changes.
- Validate transitions with temporal metrics: jerk, path corners, and contact
  residual velocity over the crossfade window.

### 4. Curves need semantic control

Spine's graph/dopesheet distinction and Live2D's extended interpolation both
point at the same issue: straight key-to-key interpolation creates wrong arcs,
shrinkage, or robotic motion when the thing being animated should travel on a
curve. Live2D solves this by generating curved interpolation points for
parameters; Spine exposes graph curves so animators can shape timing and value.

For this repo:

- Keep `microFrames`, but add a second primitive for curve intent:
  `snap`, `softEase`, `overshoot`, `settle`, `circularArc`.
- Use generated intermediate keys for known curved paths instead of trusting a
  single smooth flag.
- Add an analyzer that compares joint/end-effector path arc length, chord
  length, and curvature. A "smooth" hand should not make hard corners unless the
  move authored an accent.

### 5. Draw order and masks are part of anatomy

Spine slots/draw-order timelines and clipping attachments exist because fixed
z-order cannot represent arms crossing torsos, hands passing in front of lapels,
or sleeves tucking behind bodies. Our Shaku/raised-arm muddiness is the same
class of problem.

For this repo:

- Add phase-keyed draw order for hand, cuff, forearm, tie, lapel, and shoulder
  fold groups.
- Add tiny torso/arm masks only where crossed or raised arms require them.
- Keep draw-order keys authored per move; do not make one global z-order solve
  every arm pose.

### 6. Review tooling has to expose the rig internals

DragonBones and OpenToonz-style onion workflows, Spine weight overlays, and
Godot/Rive target/constraint controls all make debugging visual. A screenshot
that "looks wrong" is not enough; the review surface should show whether the
cause is target path, solved bend, shoulder gap, mesh weights, draw order, or
support contact.

For this repo:

- Extend `frame_grid_test.dart` with toggles for bones, IK targets, mesh vertex
  handles, support pins, and worst-frame markers.
- Add focused crops for shoulders/hands/feet so panel feedback can point to
  exact failure frames.
- Keep static camera review first; app camera can hide or exaggerate rig bugs.

## Next implementation path

1. Implement a `DanceMixer` with base groove + action layer + additive secondary
   layer. This is the biggest lever for robotic transitions.
2. Add pose-conditioned shoulder corrective offsets to the sleeve/fold mesh for
   high arm elevation. The static shoulder fold committed today is a bridge, not
   the final shoulder solution.
3. Add phase-keyed draw order for Shaku and Buga so arms/cuffs/lapels can swap
   cleanly through crosses and raised presents.
4. Add mesh-vertex diagnostics to the review harness and a shoulder-gap
   validator in `MotionConstraintValidator`.
5. Use curve-intent presets on hand and body channels before doing more manual
   catalogue pose cleanup.

## Do not copy

- Do not port a full editor/runtime.
- Do not add a large dependency to solve one shoulder.
- Do not over-smooth Afrobeats hits. The goal is smoother travel into and out of
  accents, not flattening the accents.
- Do not hide rig bugs with camera angles. The app can stay front-view while the
  review harness keeps diagnostic quarter/side views.
