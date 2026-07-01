# Native animation runtime lessons for credible motion (2026-07-01)

Follow-up to the Afrobeats and Laban/Effort research notes. This pass looked at
production animation runtimes and 2D rigging tools for ideas we can adapt to the
Flutter vector cat rig without adopting a full external runtime.

## Sources reviewed

| Area | Primary references |
| --- | --- |
| Spine C/C++ runtime | Spine runtime docs, bones, slots, constraints, IK constraints, transform constraints, meshes, weights, keys, JSON format, and runtime source for IK, transform constraints, vertex attachments, curve timelines, draw-order timelines, and deform timelines. |
| ozz-animation | Runtime animation docs plus samples for playback, blend, partial blend, additive animation, motion extraction, foot IK, IK, and key optimization. |
| Cal3D | Skeleton, track/keyframe, mixer, file-format docs, and track/cycle source. |
| Assimp | Official usage docs plus animation, mesh, bone, and weight data structures. |
| Rive C++ runtime | File/artboard model, state machines, rendering loop, external renderer, Flutter state machines/data binding, mesh deformation, and IK source. |
| Godot 2D animation | Skeleton2D, 2D skeleton setup, SkeletonModificationStack2D, TwoBoneIK, FABRIK, CCDIK, and AnimationTree docs. |
| OpenToonz | Cutout IK, Plastic mesh, skeleton onion skin, Function Editor curves, preview/render checks, and onion-skin modes. |
| Synfig | Skeleton layers, skeleton deformation, bone joint preparation, keyframes/onion skin, waypoints/interpolation, TimeTrack, and Graphs Panel. |

Primary entry points:

- Spine: <https://en.esotericsoftware.com/spine-c>,
  <https://esotericsoftware.com/spine-bones>,
  <https://esotericsoftware.com/spine-constraints>,
  <https://esotericsoftware.com/spine-ik-constraints>,
  <https://esotericsoftware.com/spine-meshes>,
  <https://esotericsoftware.com/spine-weights>
- ozz-animation: <https://guillaumeblanc.github.io/ozz-animation/>,
  <https://guillaumeblanc.github.io/ozz-animation/documentation/animation_runtime/>,
  <https://guillaumeblanc.github.io/ozz-animation/samples/blend/>,
  <https://guillaumeblanc.github.io/ozz-animation/samples/foot_ik/>
- Cal3D: <https://mp3butcher.github.io/Cal3D/>,
  <https://mp3butcher.github.io/Cal3D/documentation/guide/x325.html>,
  <https://mp3butcher.github.io/Cal3D/documentation/guide/x337.html>,
  <https://mp3butcher.github.io/Cal3D/documentation/guide/x346.html>
- Assimp: <https://www.assimp.org/>,
  <https://the-asset-importer-lib-documentation.readthedocs.io/en/latest/usage/use_the_lib.html>,
  <https://github.com/assimp/assimp/blob/master/include/assimp/anim.h>
- Rive: <https://rive.app/docs/runtimes/cpp/overview>,
  <https://rive.app/docs/runtimes/cpp/state-machines>,
  <https://rive.app/docs/runtimes/cpp/rendering-loop>,
  <https://rive.app/docs/editor/manipulating-shapes/meshes>,
  <https://rive.app/docs/editor/constraints/ik-constraint>
- Godot: <https://docs.godotengine.org/en/stable/classes/class_skeleton2d.html>,
  <https://docs.godotengine.org/en/stable/classes/class_skeletonmodificationstack2d.html>,
  <https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html>
- OpenToonz: <https://opentoonz.readthedocs.io/en/latest/creating_movements.html>,
  <https://opentoonz.readthedocs.io/en/latest/editing_curves_and_numerical_columns.html>
- Synfig: <https://wiki.synfig.org/Doc:Keyframes>,
  <https://wiki.synfig.org/Doc:Waypoints>,
  <https://wiki.synfig.org/Doc:TimeTrack_Panel>,
  <https://wiki.synfig.org/Doc:Graphs_Panel>

## Converged architecture

The useful common shape is:

1. Sample sparse authored tracks in local space.
2. Blend and mask layers while values are still local.
3. Apply ordered constraints: contact locks, IK, transform constraints, and
   secondary stabilization.
4. Recompute forward kinematics after constraints mutate local pose.
5. Render from the solved pose and measure the solved motion.

This is the opposite of repeatedly nudging finished world-space poses. It gives
us one place to reason about shoulder attachment, support-foot locks, hand
targets, draw order, and motion quality.

## Lessons to adapt

### Asset data vs runtime pose

Spine, Rive, ozz, and Cal3D all separate shared authored data from mutable
runtime pose instances. The repo already mostly follows this with `Clip`,
`RigSpec`, `ClipEvaluator`, and `CharacterScene`; keep new features on that
boundary. Do not store previous-frame hacks inside clip data.

### Ordered constraints, not loose post-passes

The runtimes treat constraints as ordered graph steps with explicit strength.
That maps well to our current problems:

- foot pins/contact locks need to solve before cosmetic balance;
- shoulder sockets and sleeve deformation should follow torso/chest first, then
  arm pose;
- hands should solve toward targets with reach limits, bend continuity, and
  target residual diagnostics;
- head/tail/ears can lag after the primary body solve.

The next engine step should be a small constraint pass object or pipeline, not
another local visual tweak in `cat_in_suit.dart`.

### Meshes and weights for soft body connection

Spine, Rive, Godot, OpenToonz, and Synfig all solve the "detached limb" problem
with weighted deformation around joints. For this repo, the practical version is
not a full mesh editor. It is a small set of weighted vector ribbons/skins:

- shoulder cap and jacket side influenced by torso, clavicle, and upper arm;
- bicep/forearm sleeve influenced by upper arm, lower arm, and wrist;
- pelvis/jacket hem influenced by root, pelvis, and thighs;
- tail base influenced by pelvis and tail bones.

This should replace hard capsule-like limbs where the shoulder or elbow needs to
look continuous. The current skinned sleeve work is the right direction, but the
review target is continuity under motion, not just a better static silhouette.

### Slots and draw order for crossed arms

Spine's slot/draw-order model is directly relevant to Shaku and any arm crossing.
Fixed `z` values are insufficient when hands and forearms cross the torso over a
beat. We should eventually author phase-keyed draw order for forearms, hands,
cuffs, lapels, and torso masks so crossed poses do not look muddy or impossible.

### Mixer/state layer for transitions

Rive state machines, Godot `AnimationTree`, and Cal3D's mixer all point to the
same fix for robotic move changes: add an explicit dance state layer instead of
swapping clips abruptly. A small `DanceMixer` should support:

- base groove layer;
- action/accent layer;
- additive shoulders/head/tail layer;
- per-bone masks;
- fade windows measured in beat fractions;
- transition points constrained by contact spans and musical exits.

The mixer should preserve Afrobeats accents. Smooth every transition enough to
avoid pops, but do not smear sharp moves into generic motion.

### Review tools are part of the rig

OpenToonz and Synfig make onion skins, graph curves, skeleton ghosts, and preview
ranges first-class review tools. We need the same habit in test renders:

- relative and fixed onion modes;
- joint paths and IK target paths;
- support-foot pins and contact spans;
- shoulder/elbow/wrist gap overlays;
- worst-motion markers from temporal metrics;
- focused shoulder/hand/foot crops.

Without these overlays, screenshots can say "looks bad" but not identify whether
the cause is path shape, bad bend side, detached mesh, draw order, foot skate, or
timing.

## Immediate backlog for this repo

1. Add temporal metrics for jerk, curvature/arc ratio, loop closure, foot-plant
   residual velocity, and unmarked pops outside authored accents.
2. Add constraint validation for IK chain shape, reach, bend flips, wrist target
   residual, shoulder gap, elbow foldover, non-finite targets, and draw-order
   crossings.
3. Extend `frame_grid_test.dart` with onion/overlay modes, `GRID_START`,
   `GRID_END`, `GRID_STEP`, support pins, IK target paths, and worst-motion
   markers.
4. Introduce a small ordered constraint pipeline so foot locks, hand IK,
   shoulder skinning, and secondary motion run in predictable order.
5. Add a `DanceMixer` layer for beat-safe clip transitions and sparse additive
   accents.
6. Add phase-keyed draw order for crossed-arm moves once the base constraint and
   mesh pipeline are stable.

## What not to copy wholesale

- Do not port a full Spine/Rive/Godot runtime. Their editor formats, renderers,
  batching, and 3D/mesh assumptions are much larger than this Flutter rig needs.
- Do not add a runtime Assimp dependency; use it only as a possible offline
  importer reference if we later normalize FBX/glTF/mocap into repo-native clips.
- Do not over-anchor feet. Dance needs grounded weight, not every contact solved
  into a frozen foot.
- Do not over-smooth Afrobeats accents. The target is silky and credible motion
  with readable hits, not a low-pass-filtered puppet.
- Do not copy source implementations without a licensing pass. Treat these
  runtimes as design references.
