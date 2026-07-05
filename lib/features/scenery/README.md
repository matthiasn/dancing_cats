# Scenery

Reusable animated backdrops for character/demo surfaces. The current production
scene is the Lagos-inspired blue-hour waterfront used by the dance-to-track app
(`DanceToTrackApp` in `lib/main.dart`): a generated bitmap plate split into
full-frame WebP layers, with shader and canvas effects composited between those
layers.

The module is deliberately independent from `features/character`. Consumers pass
a clock and optional child into `LayeredBackdrop`; scenery code owns image/shader
loading, reduced-motion handling, and layer composition.

The multi-plane depth rig this README's layer stack implements is explained
concept-first, with diagrams, in
[`docs/animation/01-parallax-and-layers.md`](../../../docs/animation/01-parallax-and-layers.md)
(design record: [ADR 0001](../../../docs/adr/0001-multiplane-parallax.md)).

## Runtime Architecture

```mermaid
flowchart TD
  demo[DanceToTrackApp] -->|audio position seconds| lb[LayeredBackdrop]
  demo -->|screen-fixed final pass| texture[SceneTextureOverlay]
  self[Standalone use] -->|null timeSeconds| lb
  lb --> loader[async loaders]
  loader --> imgs[decoded ui.Image assets]
  loader --> shaders[FragmentProgram cache]
  lb --> painter[_BackdropPainter]
  painter --> ctx[BackdropContext]
  ctx --> layers[BackdropLayer stack]
  imgs --> ctx
  shaders --> ctx
  layers --> canvas[Canvas]
  texture --> canvas
```

`LayeredBackdrop` has two clock modes:

- External clock: pass `timeSeconds`, used by the audio dance player so scenery
  seeks, pauses, and resumes with playback.
- Self clock: leave `timeSeconds` and `timeOverride` null; the widget starts its
  own `Ticker`.

`MediaQuery.disableAnimationsOf(context)` freezes the scene at
`kSceneryCalmFrameSeconds`. Tests can pin `timeOverride`.

## Layer Stack

`BackdropScene.blueHourWaterfront()` defines the current stack. Every bitmap is
authored at `kSceneryCanvasSize` (`2560x1440`) and cover-fit into the viewport.
The same cover-fit mapping is used by bitmap layers, cloud drift, ocean band
placement, and city/yacht light sampling.

```mermaid
flowchart BT
  child[Dancers / caller child]
  vignette[VignetteLayer foreground]
  glow[DeckGlowLayer]
  fg[foreground.webp deck - stage plane]
  yachtGroup[YachtGroupLayer: hull + YachtLightsLayer - stage plane]
  haze[AtmosphericHazeLayer]
  lights[CityLightsLayer city-only]
  police[BridgePoliceLayer cordon]
  launchDrones[DroneShowLayer launch/ascent pass]
  skyDrones[DroneShowLayer sky pass]
  ocean[OceanLayer shader/fallback]
  jet[DistantJetLayer]
  near[clouds_near.webp parallax]
  mid[clouds_mid.webp parallax]
  far[clouds_far.webp parallax]
  base[blue_hour_cloudless.webp]

  base --> far --> mid --> near --> jet --> ocean --> lights --> haze --> yachtGroup --> fg --> glow --> police --> skyDrones --> launchDrones --> child --> vignette
```

The ordering is the important contract:

- The base is `blue_hour_cloudless.webp`, not the original master plate.
- Clouds are reintroduced as transparent full-frame WebPs and drift with
  `CloudParallaxLayer`.
- `DistantJetLayer` draws the generated transparent `lufthansa_747.png` asset
  as a small right-to-left opening pass. The pass is clipped to the active 16:9
  stage rect so it never crosses desktop/export side bars, and adds four
  engine-origin contrails that diffuse and fade behind the aircraft. Its lights
  model the visible side only: steady red port wingtip, steady aft white, plus
  FAA-rate red/white anti-collision pulses.
- `OceanLayer` adds animated foam/glint over the painted lagoon.
- The moored yacht is a `YachtGroupLayer` — the hull bitmap plus its own
  `YachtLightsLayer` (cabin windows, hull rim/fill, nav/deck lamps) — drawn as
  ONE group on the nearer, docked (foreground/stage) plane, so it parallaxes with
  the pier it is tied to rather than the far skyline. It is drawn AFTER the city
  lights + haze (a near, docked vessel is not veiled by the distance haze) and
  behind the deck; its hull still occludes the foam. The de-baked base plate has
  no yacht twin to slide off.
- The skyline is NOT redrawn — the city and sky share one plane and the clean
  base plate already carries a sharp skyline, so `city_bridge.webp` is decoded
  only as the distant jet's `dstOut` occluder mask (the opaque plate has no
  transparent sky to cut the aircraft against).
- `CityLightsLayer` draws additive CITY windows + tower/pylon beacon glows only
  (shader in city mode, `uYachtOnly = 0`). The yacht's own cabin/nav lights are a
  separate pass in the yacht group (shader in yacht mode, `uYachtOnly = 1`).
- `foreground.webp` and `DeckGlowLayer` sit over the animated water/deck area.
- `BridgePoliceLayer` strobes a blue (plus sparse red) emergency cordon along the
  bridge roadway. It is timed to the drone-show loop: the lights roll in before
  launch, hold while the drones stage on the cleared road, then clear out as the
  formation climbs — so the road is dark again once the show is in the sky. Drawn
  with the drones as a post-haze active light pass; suppressed under reduce-motion.
- `DroneShowLayer.sky()` and `DroneShowLayer.launchRoad()` are the highest
  background art passes. The ascent starts as small unlit aircraft dots, then
  switches on above the cable-stayed bridge; drawing both passes here keeps
  bridge cables, palms, and deck masks from cutting artificial gaps through the
  show.
- Foreground layers, currently the vignette, paint over the caller child.

The dance-to-track app additionally paints `SceneTextureOverlay` in screen
space, outside the backdrop camera transform and below the dancers. That pass is
not an authored art layer: it is a final tiny grain/edge-sink treatment that
keeps the whole viewport, including parallax side bands, from reading cleaner
than the centre.

## Bitmap Assets

`SceneryAssets` names the runtime assets:

- `blue_hour_cloudless.webp`: immutable full-frame base plate — already
  cloudless, with the foreground palms baked out so they never duplicate
  against the independently animated `foreground.webp` parallax layer.
- `clouds_far.webp`, `clouds_mid.webp`, `clouds_near.webp`: exact-size transparent
  cloud plates. They are not cropped.
- `yacht.webp`, `foreground.webp`: structure/occluder layers cut from same-size
  masks, redrawn over the animated water.
- `city_bridge.webp`: alpha-cut skyline silhouette; no longer painted as a
  redraw layer — decoded only as the distant jet's `dstOut` occluder mask.
- `city_windows.webp` / `yacht_windows.webp`: sampled window fields (the two
  halves of the old combined field — skyline windows in `city_windows`'s red
  channel, yacht cabin windows in `yacht_windows`'s blue channel). `CityLightsLayer`
  samples the first, `YachtLightsLayer` the second, so the yacht's glow can be lit
  on the yacht group's own plane.

Full-frame assets are intentional. Cropping would require independent alignment
metadata and creates visible drift errors when layers are cover-fit at different
viewport ratios.

## Cloud Parallax

`CloudParallaxLayer` shifts one full-frame transparent cloud plate horizontally
and wraps it with three draws (`-1`, `0`, `+1` art widths). The movement is
one-way and cyclic. `dxPerSecond` is a fraction of the cover-fitted art width per
second; `0.001` equals 12% of the art width over a two-minute track.

Vertical motion is a very small sine "breathing" offset. Cloud bands use
different phases and speeds:

- Far/dark upper clouds: subtle but now visible motion.
- Mid clouds: slightly faster.
- Near/bright cloud details: most visible motion.

The current asset extraction keeps the left skyline-adjacent cloud band mostly
baked into the base. That is a deliberate quality tradeoff: those clouds overlap
tall tower silhouettes in the source art, and moving them independently makes
building-shaped artifacts read as drifting architecture.

## Shader And Canvas Layers

`SceneryShaderProgramCache` loads:

- `scenery_sky.frag`: procedural fallback scene for
  `BackdropScene.proceduralBlueHour()`.
- `scenery_ocean.frag`: additive lagoon foam and glint.
- `scenery_city_lights.frag`: additive window and yacht-cabin lighting.

Shader load failure is non-fatal. Layers either use CPU fallback rendering or
no-op until their programs/assets load.

`CityLightsLayer` also paints canvas beacons and yacht lamps. It maps normalized
art anchors through `coverFit`, so lights stay attached to the painted structures
on desktop and phone aspect ratios.

## Drone Show

`layers/drone_show_layer.dart` is a deterministic background performance layer,
not a bitmap asset. It samples normalized drone positions from the scene clock
and paints additive glows in the sky. The current show is aircraft-paced rather
than particle-paced: 280 drones hold a dense, evenly spaced cable-stayed
bridge-road launch line as dark aircraft dots, rise through five local spiral
columns, switch lights on progressively above the bridge cables, converge into a
controlled beam, fan out, hold compact dot-matrix `Omah Lay`, collapse through a
coordinated staging row, then form `Moving` over a 144-second cycle.

```mermaid
stateDiagram-v2
  [*] --> Launch
  Launch --> Beam: dark road hold + five spiral ascents
  Beam --> Fan: controlled convergence
  Fan --> Formation: spread into text points
  Formation --> Launch: loop wraps
```

The pure functions are the contract:

- `droneShowTimelineAt(timeSeconds)` resolves the current phase and local
  progress inside the repeatable loop.
- `droneShowFormationPoints()` generates destination points for either
  dot-matrix message (`Omah Lay` by default, or `Moving` for the final hold).
- `sampleDroneShow(timeSeconds)` returns per-drone normalized positions,
  opacity, radius, and phase; reduced-motion samples a static formation frame.
  During formation, drones settle into `Omah Lay`, hold, transition into
  `Moving` through a thin staging row, then hold again so lettering remains
  readable. The tests also bound one-second normalized travel so retunes do not
  accidentally make the aircraft move like fireworks.

The runtime scene uses two configured layer instances:
`DroneShowLayer.sky()` for beam/fan/text phases and
`DroneShowLayer.launchRoad()` for launch/ascent only. Both draw above the fixed
structure redraw, but the launch samples stay visually dark until they clear the
cable-stayed bridge. That keeps the aircraft readable as physical objects on the
bridge while preventing the bridge-cable alpha mask from slicing holes through
the show.

## Stage Lighting

The dance-to-track demo lights the trio like a stage act with a **graphic
rim/backlight** look (chosen because the cats are flat cartoon shapes — front-lit
colored cones read as glowing capsules, but a colored edge hugging the silhouette
reads as real backlight). One scheduler drives two halves so the body glow and
its floor pool always share a gel:

- **`runtime/stage_lights.dart` — `StageLightRig` (pure).** A deterministic,
  canvas-free scheduler: feed it the scene time + the 0..1 beat envelope and it
  returns each light's gel `color`, pool `targetX` and `intensity`. The gel cycle
  (`kStageGelCycle`: warm gold / dusk fuchsia / electric violet, pulled back from
  neon toward the plate's lantern-amber / dusk-magenta so the gels read as light in
  the blue-hour world rather than arcade decals; the gold is deepened toward amber
  so the additive rim/pool stays gold when hot instead of blowing to white on the
  beat) **snaps** (never lerps) on a `colorPeriod` wired to the track tempo
  (`60 / bpm`), offset per lane so the row rotates rather than flashing in unison;
  brightness is `baseIntensity + beatBoost * beat` (a lifted base so the calm intro
  is never underlit, a tempered boost so the beat punches without blowing out).
  `leadGoldIndex` pins one lane (the centre/lead) to the hero gold every frame
  while the flankers keep cycling, so the lead reads as a consistent star colour.
- **The directional rim/halo + body grade are drawn by `CharacterPainter`**
  (`memberBacklights` + `bodyGrade` + `heroStaging`, not in this module): each cat
  is rendered as a blurred, solid-gel silhouette behind itself (a soft bloom + a
  tight rim pass), each pass **offset toward that lane's light source** so the rim
  is directional with a real shadow side. `bodyGrade` then grades the body into the
  twilight plate (a cool→warm ambient wrap + a directional gel terminator), clipped
  below the neckline so the face stays natural, and `heroStaging` pushes the lead
  bigger/downstage. It reuses the member transform, so the rim tracks the dancer
  through any camera move. The whole act activates for the centred-trio concert
  dance phrase — both `dance` and the shipping `shaku` (what the player dances).
- **`stage_lights_overlay.dart` — `StageLightsOverlay` / `StageLightsPainter`.**
  The grounding half: an additive (`BlendMode.plus`) screen-space pass over the
  dancers drawing a gel pool that is anchored at the foot and **rakes forward**
  (downstage) with a horizontal shear (`_kPoolLean`) so off-centre pools lie along
  the deck's plank perspective, plus a hot core at the foot contact. A small cool
  near-black **contact occlusion** is then punched back into the pool centre
  (normal alpha-over, on top of the additive gel) hugging the sole — the dancer
  occluding the floor light where they stand — so the cat is anchored by a real
  dark contact with the gel spilling *around* it, not floating on a bright puddle;
  the occlusion is beat-independent (grounding must not pulse). It eases its pool
  toward the live dancer foot (lazy on small moves, fast catch-up on a camera
  cut), tracking the anchors the painter publishes via `onDancerAnchors`.

The demo samples the rig once per frame and feeds the gels to both halves, so the
whole rig pulses with the music. The cat **bodies never flash with the beat** (a
full-figure luminance flash would be a photosensitivity risk): the figure's value
and form stay static, and only a single motivated gel-key term on the fabric (plus
the rim halo and floor pools around the cats) breathes gently — see the seizure
note in `character/README.md`. Reduce-motion freezes the rig to a calm static
frame.

## Asset Preparation

The generated WebP stack lives under `assets/scenery/`; the tooling lives under
`tools/scenery_art/`.

```mermaid
flowchart LR
  base[blue_hour_cloudless.webp] --> masks[layer masks]
  masks --> layerer[layer_from_masks.py]
  layerer --> city[city_bridge.webp]
  layerer --> yacht[yacht.webp]
  layerer --> fg[foreground.webp]
  base --> bake[bake_city_windows.py]
  city --> bake
  yacht --> bake
  fg --> bake
  bake --> windows[city_windows.webp]
```

`blue_hour_cloudless.webp` is the immutable base plate — already cloudless,
with the foreground palms baked out so they never duplicate against the
independently animated `foreground.webp` layer. `clouds_far/mid/near.webp` are
frozen assets from an earlier master-era cloud extraction and are not part of
this regeneration path (see `tools/scenery_art/README.md`).

Regenerate with:

```bash
make -C tools/scenery_art blue-hour
```

Preview/debug outputs go to `tmp/scenery_work/` and are not runtime assets. See
`tools/scenery_art/README.md` for the mask-generation details and visual QA
checks.

## Tests

Focused checks for this feature:

```bash
fvm flutter analyze lib/features/scenery lib/main.dart test/features/scenery/layers/cloud_parallax_layer_test.dart test/features/scenery/model/backdrop_scene_test.dart test/features/scenery/scenery_assets_test.dart
fvm flutter test test/features/scenery/runtime/scenery_shaders_test.dart test/features/scenery/layers/cloud_parallax_layer_test.dart test/features/scenery/layers/drone_show_layer_test.dart test/features/scenery/model/backdrop_scene_test.dart test/features/scenery/scenery_assets_test.dart
```

Coverage responsibilities:

- `backdrop_scene_test.dart`: layer order and declared assets.
- `scenery_assets_test.dart`: full-frame asset geometry and alpha sanity.
- `cloud_parallax_layer_test.dart`: deterministic offset/wrap math.
- `scenery_shaders_test.dart`: registered shader assets compile through Flutter's
  runtime-effect compiler.
- `runtime/stage_lights_test.dart`: the `StageLightRig` gel-cycle / sweep /
  beat-intensity maths.
- `stage_lights_overlay_test.dart`: the floor pools land their gel, track the
  dancer foot (lazy follow) and pulse on the beat.
- `drone_show_layer_test.dart`: drone timeline phases, `Omah Lay` → `Moving`
  formation bounds, deterministic sampling, and paint contract.
- `scene_texture_overlay_test.dart`: screen-fixed finishing grain covers both
  vertical side strips and preserves a gentle edge sink.
