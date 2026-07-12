# Moving choreography handoff

> **Historical snapshot.** This document describes the state of the work at
> commit `46db185`, mid-way through the `feat/moving-musicality-tie` branch.
> Later commits on the branch superseded several claims below: the app-stage
> ownership fix and the "critical unresolved teleport" investigation landed
> (see `ac6d540`/`2fabab1` and `playbackStageForRender`), and a subsequent
> musicality pass added the Moving accent plié
> (`kMovingAccentDropUnits` in `dance_stage_view.dart`) and the beat-binding
> pocket swing (`kMovingSwingBeats` / `BeatLoopBinding.swing`). Known issue
> left for a follow-up: `movingBridgeBounce`'s and `movingBridgeRock`'s
> contact spans contradict their authored feet, so the support anchor crushes
> their heel pops/taps — see the KNOWN ISSUE note on `movingBridgeRock` in
> `cat_in_suit.dart`. Trust the code and current tests over the sections
> below where they disagree.

## Mission

Make the full `Omah Lay - Moving` performance read as a human, organic,
musical dance rather than a procedural animation or spring-driven puppet.
Success is perceptual across the entire song, not merely green tests or one
good nine-second excerpt.

The owner is especially sensitive to:

- shoulders, elbows, forearms, paws, cuffs, and how those parts articulate as
  one believable chain;
- arms snapping back as though pulled by springs;
- mathematically valid but humanly implausible arm configurations;
- whole-body pose morphs that read as teleports;
- identical choreography on all three cats;
- repetitive arm waving, tame exercise-demo gestures, and generic movement;
- motion that is smooth but not clearly phrased to this particular song.

Hands may and should go above the head when the pathway and elbow mechanics
are credible. Do not solve arm problems by keeping everything below shoulder
height or making the limbs look heavy.

## Repository state

- Repository: `dancing_cats`
- Branch: `feat/moving-musicality-tie`
- Current HEAD: `46db185 feat: smooth Moving phrase handoffs and counteraction`
- The current choreography/playback batch is intentionally uncommitted pending
  owner playback review. It spans 13 source/test files plus this handoff and
  includes the real app-stage ownership fix, full-history excerpt preroll,
  loop-seam pose settling, score development, phrase re-authoring, and bridge
  head follow.
- Superseded full-song baseline:
  `build/character_video_exports/moving_full_current_v64_144s_60fps.mp4`
  (640x360, 60fps, 144.066s). Owner playback exposed loose/detaching heads;
  do not use it to approve the current head behavior.
- Exact-current head-fix reviews:
  `build/character_video_exports/moving_attached_heads_v65_104-112_60fps.mp4`
  and
  `build/character_video_exports/moving_attached_heads_broad_v66_68-90_60fps.mp4`.
  Moving now uses its authored head rotation while remaining on the articulated
  neck; independent horizontal/vertical follows and the second vocal bob are
  disabled, and the skull is seated slightly into the collar.
- Final attached-head combined validation: 1,243 passed, 3 expected render
  skips. This includes Moving neck attachment and single-head-clock coverage,
  anatomy, angular motion, adjacent production score ownership, and full 144s
  production continuity.

Before doing anything else in the VM:

```bash
git switch feat/moving-musicality-tie
git status --short
git log -3 --oneline
```

Expected HEAD while this batch remains under review: `46db185` with the
documented modified worktree.

## Non-negotiable render rule

Every clip shown to the owner must come from the same production/export path
as the real output. Do not build a parallel debug renderer and treat it as
evidence.

Use:

```bash
tools/character_video_export/export_dance_video_macos.sh \
  --preset 720p \
  --fps 60 \
  --start 109.5 \
  --duration 9 \
  --out build/character_video_exports/<name>.mp4 \
  --audio build/character_video_exports/.inputs/Omah_Lay-Moving.mp3 \
  --rebuild
```

The exporter consumes the actual beat, word, cue, stage, playback-stepper,
production-clip, scene, painter, and audio paths. `ffmpeg` contact sheets are
useful for diagnosis, but the video itself is the perceptual authority.

## What is implemented

### Song-specific choreography

`lib/features/character/samples/moves/moving_groove_data.dart` contains the
current authored Moving vocabulary. Important public clips are wired through
`lib/features/character/samples/cat_in_suit.dart`:

- `movingHookLead`
- `movingHookLowCounter`
- `movingHookSideAnswer`
- `movingVerseShuffle`
- `movingVerseWindow`
- `movingBridgeBounce`

The full-song setlist is selected in
`lib/features/character/demo/dance_performance.dart`. The three cats are given
different roles instead of cloning the lead exactly.

The current approximate production schedule is:

```text
0.0-9.8     idle
10.2-17.5   hook lead
17.5-25.2   side answer
25.2-30.8   verse shuffle
30.8-36.5   bridge bounce
36.5-42.1   verse shuffle
42.1-49.8   hook lead
49.8-57.5   side answer
57.5-63.0   verse shuffle
63.0-68.5   verse window
68.5-79.4   bridge bounce (continues across the semantic boundary)
79.4-84.8   low counter
84.8-90.1   verse window
90.1-98.0   side answer
98.0-105.9  verse window
105.9-111.7 hook lead
111.7-117.4 side answer
117.4-123.2 verse window
123.2-130.2 verse shuffle
130.2-137.1 hook lead
137.1-138.1 verse shuffle
138.1-end   idle
```

This is a complete schedule, but not yet a proven-good full choreography.
Smoothness, repetition, attitude, and phrase identity still need perceptual
review across the complete export.

### Rig and arm-chain work

The rig now has articulated shoulder controls and continuous ribbon sleeves.
Cuffs inherit the sleeve/forearm axis rather than the independently rotating
paw, which prevents the old spinning-cuff artifact. The relevant code is in:

- `lib/features/character/samples/cat_in_suit_rig.dart`
- `lib/features/character/runtime/character_scene.dart`
- `lib/features/character/runtime/character_painter.dart`

Arm authoring is IK-target based with explicit bend direction and clavicle
tracks. There are tests for sleeve welding, cuff alignment, planar arm range,
shoulder seating, and rendered elbow geometry.

### Transition fixes already worth preserving

`lib/features/character/model/clip.dart` and
`lib/features/character/demo/dance_playback_stepper.dart` contain several
important fixes:

1. Blended joint/IK/root channels track both source and destination duration.
   The outgoing normalized phase is converted through seconds, avoiding phase
   errors when clips have different durations.
2. Playback and local channel time shifts are separate. Absolute scene/contact
   consumers receive an absolute shift; normalized channels receive local
   seconds.
3. Identical trios continue their previous phrase clock across a semantic
   section boundary instead of invisibly restarting the clip. This fixed a
   large teleport around 74.03s.
4. Support-foot world anchors interpolate when both sides share a support foot
   and release/re-engage when support changes. This removed a lower-leg IK
   branch flip around 123.90s.
5. Moving-family transitions use a coherent full-body blend instead of the
   catalogue's heavily staged hand/body mask.

Do not casually revert these while addressing the remaining transition. They
fixed measured 36-100 unit one-frame jumps elsewhere in the song.

### New pose-cell infrastructure

`lib/features/character/model/dance_pose_cell.dart` and its tests provide a
pose-first authoring model. It keeps body, support, limb, and joint intent in a
single cell so separate tracks do not drift into incompatible poses.

## The latest arm fix

The owner correctly observed that the overhead side-answer arm still looked
straight after an initial reduction.

A rendered-geometry probe measured the right elbow at **179.98 degrees** near
frame 14.6 of `movingHookSideAnswer`: technically solvable, visually locked.
The authored crown targets were pulled inside the real two-link reach. The
current measured maximum is **123.04 degrees**, and the paw origin remains
26.2 rig units above the head origin at the apex.

This is now guarded by:

```text
CatClips Moving side-answer crown keeps a visibly bent elbow
```

in `test/features/character/samples/cat_in_suit_test.dart`. It samples the
rendered rig throughout the phrase, requires the maximum right-elbow angle to
remain below 155 degrees, and separately proves the paw still clears the head.

Do not weaken this into a raw-target-distance assertion. The rendered joint
angle is what the owner sees.

## Critical unresolved issue: one remaining teleport

This is the first thing the VM session should fix.

The owner saw one remaining teleport in the 109.5-118.5s excerpt. A full-song
60fps production probe identifies the hook-lead to side-answer transition as
the common spike.

The checkpoint contains a named special case:

```dart
kMovingHookAnswerTransitionSeconds = 1.0
```

in `dance_playback_stepper.dart`. It was intended to give the large silhouette
exchange two beats instead of 0.65s. That did **not** solve the real problem.
The probe after the commit reports a sharp common spike exactly at **112.55s**:

```text
hips       speed 6.90/frame, acceleration 7.72
hand.R     speed 6.39/frame, acceleration 7.73
armLower.R speed 6.64/frame, acceleration 7.76
foot.L     speed 7.31/frame
foot.R     speed 7.52/frame, acceleration 7.88
```

Because hips, arms, and both feet jump together at the end of a longer blend,
this is probably not an authored hand-key discontinuity and not something to
fix by increasing the blend duration again. The likely failure is a state,
phase, or production-decoration mismatch when the temporary blended clip is
replaced by the raw destination clip.

High-value investigation path:

1. Probe frames 112.45-112.60 at 60fps and print:
   - stage lead name;
   - `stage.seconds`;
   - transition elapsed/weight;
   - raw destination clip seconds;
   - world positions before and after `productionDanceClip` decoration.
2. Compare the last temporary clip
   `movingHookLead->movingHookSideAnswer` with the first raw
   `movingHookSideAnswer` frame.
3. Inspect `productionDanceClip` in
   `lib/features/character/demo/dance_stage_view.dart`. The temporary blended
   clip has a synthetic name and may not receive exactly the same
   family/name-driven dynamics or production wrapping as the raw destination.
   Blending raw clips and decorating afterward can create a wrapper boundary
   even when the underlying channels converge.
4. Verify whether `belongsToFamily('moving')`, clip metadata, body warp,
   descriptor lookup, support/contact handling, or dynamic scaling changes on
   the exact frame the blend object disappears.
5. Fix the semantic mismatch so the last blend frame and first raw frame are
   the same pose/velocity. Do not hide it with a global velocity clamp.

The previous 0.65s version peaked earlier around 112.36s but was less severe:
hips 4.74/frame and hand.L 5.79/frame. This supports the hypothesis that a
transition-end wrapper mismatch grows as the source and destination phases
diverge. Reverting the special 1.0s case is acceptable as an interim step, but
the final fix should remove the boundary discontinuity.

## Test status

The focused pre-commit suite passed 154 tests:

```bash
fvm flutter test \
  test/features/character/samples/cat_in_suit_test.dart \
  test/features/character/demo/dance_production_motion_continuity_test.dart \
  test/features/character/demo/dance_performance_test.dart \
  test/features/character/model/clip_test.dart \
  test/features/character/model/dance_pose_cell_test.dart
```

Also run:

```bash
git diff --check
```

Important limitation: the production continuity test currently asserts a
generous per-frame displacement ceiling. It catches true 50-100 unit
teleports, but the owner can perceive the remaining 6-8 unit common-mode snap.
After fixing 112.55s, tighten or extend the test to assert transition-end pose
and velocity continuity, not only position displacement.

Some older `dance_playback_stepper_test.dart` catalogue expectations still
refer to the pre-Moving `buga`/`zanku` schedule and may fail for stale reasons.
Do not claim the entire repository suite is green until those expectations are
reviewed and either updated or separated from the Moving production tests.

## Diagnostic probes

The source machine used temporary files under `/private/tmp`, which will not be
present in a fresh VM:

- `/private/tmp/full_song_motion_probe_test.dart`
- `/private/tmp/full_song_choreo_probe_test.dart`
- `/private/tmp/moving_side_answer_probe_test.dart`
- `/private/tmp/transition_detail_probe_test.dart`
- `/private/tmp/moving_phase_probe_test.dart`

Recreate the important one as a proper repository diagnostic test or tool.
The full-song motion probe should:

1. Load `assets/sample_track/moving.json` and
   `assets/sample_track/moving.words.json`.
2. Build the real `DancePerformance`.
3. Advance a real `DancePlaybackStepper` at 1/60s from 0 to 144.066s.
4. Call the public `productionDanceClip` for the lead using the current stage
   dynamics and energy.
5. Render through a real `CharacterScene`.
6. Record world-space per-frame displacement and velocity delta for hips,
   hands, lower arms, and feet, retaining timestamp and clip name.

This diagnostic is much more useful than sampling a clip in isolation because
the remaining failure only appears through the production schedule and wrapper
handoff.

## Existing video artifacts

These are useful historical comparisons on the source machine but are build
artifacts, not source of truth in a fresh clone:

- `build/character_video_exports/moving_full_organic_v72_144s_60fps.mp4`
  - exact-current full-song review master after v68-v71 were combined;
  - 640x360, 60fps, 144.066s, 8,643 encoded frames, with audio and continuous
    playback history from time zero;
  - contains attached heads, the travelling bridge build, staggered chorus
    lead/catch, shoulder-delayed verse focus, and the single final-chorus
    unison payoff;
  - validated immediately before export by the complete suite: 1,245 passed,
    3 expected skips.
  - encoded-master QA found zero exact consecutive duplicate video frames;
    adjacent-frame difference outliers were inspected at the strongest peaks
    (12.217s, 17.517s, 44.500s) and are continuous character/camera motion under
    deliberately changing stage illumination, not teleports or dropped frames.
  - a four-second-offset SSIM audit of the lead crop found its strongest
    non-outro windows near 24-28s, 42-48s, and 72-76s. Dense frame inspection
    shows distinct dancer silhouettes throughout; the elevated similarity is
    caused by stable framing/background around semantic section boundaries,
    not an accidentally repeated four-second character loop.
- `build/character_video_exports/moving_full_current_v64_144s_60fps.mp4`
  - superseded full-song production export;
  - 640x360, 60fps, 144.066s, with audio and continuous playback history;
  - includes the motion and score refinements but predates the attached-head
    runtime fix.
- `build/character_video_exports/moving_attached_heads_v65_104-112_60fps.mp4`
  - exact-current 60fps reproduction of the owner's 1:48 detachment report.
- `build/character_video_exports/moving_attached_heads_broad_v66_68-90_60fps.mp4`
  - exact-current 60fps multi-phrase audit of head attachment across all lanes.
- `build/character_video_exports/moving_full_attached_heads_v67_144s_60fps.mp4`
  - full-song 60fps attached-head baseline approved as "better" and later
    assessed as fairly decent but still somewhat boring;
  - predates only the subsequent bridge-finale score change.
- `build/character_video_exports/moving_bridge_build_v68_82-94_60fps.mp4`
  - exact-current focused review of the bridge into the late chorus;
  - replaces the bridge's final low-counter phrase with chorus travel, giving
    the section a grounded-roll -> travelling-build -> chorus-lift progression.
- `build/character_video_exports/moving_chorus_lead_catch_v69_44-54_60fps.mp4`
  - exact-current focused second-chorus review after the full-song silhouette
    audit found that `movingChorusOpen` still behaved like mirrored exercise;
  - the planted-side arm now leads, the other shoulder and paw arrive later,
    and the leadership reverses in the second half while foot contacts and loop
    endpoints remain unchanged.
- `build/character_video_exports/moving_verse_focus_v70_57-74_60fps.mp4`
  - exact-current full-verse review after the phrase audit found the window
    arms were organic but the face still followed the generic groove clock;
  - `movingVerseWindow` now uses a small shoulder-delayed rotational focus
    track. Moving head translations remain disabled, and the catalogue-wide
    chin/collar attachment suite stays green.
- `build/character_video_exports/moving_final_chorus_unison_v71_98-108_60fps.mp4`
  - exact-current final-chorus review spanning its varied lead-in, collective
    hook landing, and release into post-chorus;
  - only the final chorus statement assigns `movingHookLead` to all three cats.
    Earlier statements retain complementary roles, so unison reads as an earned
    ensemble event instead of three independent loops or constant mirroring.
- `build/character_video_exports/moving_full_current_v62_144s_60fps.mp4`
  - superseded full-song production baseline;
  - 640x360, 60fps, 144.066s, with audio and continuous playback history;
  - includes the final bridge head-follow refinement;
  - predates only the score-only bridge→chorus repeat removal shown in v63.
- `build/character_video_exports/moving_bridge_to_chorus_v63_84-94_60fps.mp4`
  - exact-current 60fps production excerpt for the corrected section boundary;
  - bridge low-counter now sets up the late-chorus side-answer instead of
    replaying that same lead clip for eight seconds.
- `build/character_video_exports/moving_full_current_v60_144s_60fps.mp4`
  - previous full-song checkpoint; identical choreography except it predates
    the restrained `movingBridgeRock` head counter-focus.

- `build/character_video_exports/moving_full_song_v34_actual.mp4`
  - full 144s production export;
  - predates the latest head-bank, bent-arm, and 1.0s transition work.
- `build/character_video_exports/moving_diagonal_headbank_v36_109.5-118.5_actual.mp4`
  - shows the 179.98-degree locked crown arm.
- `build/character_video_exports/moving_soft_handoff_bent_crown_v37_109.5-118.5_actual.mp4`
  - still predates the final measured 123-degree arm change and the committed
    1.0s special-case handoff.

Do not use v34-v64 to judge current head behavior. Use v65 for the reported
1:48 window, v66 for the broader attachment audit, and v67 for the most recent
full-song head baseline. Use v68 to judge the sole choreography change after
v67. Use v72 for all current full-song judgment; v68-v71 remain useful focused
references for the individual post-v67 changes.

## Suggested immediate sequence in the VM

1. Watch v72 end-to-end at normal speed with audio and note any remaining
   robotic path, weak phrase, or discontinuity; contact sheets and green tests
   are not substitutes for this review.
2. Note timestamps for any remaining teleport, implausible arm chain, dead
   hold, or low-energy phrase.
3. Reproduce each timestamp through the production exporter with full-history
   preroll, then fix the authored path or score rather than relaxing a gate.
4. Recheck these broad ranges with music:
   - 10-25s: first hook and side answer;
   - 42-68s: repeated hook into verse variations;
   - 68-90s: bridge/low-counter/window variety;
   - 90-123s: late chorus and the known transition;
   - 130-144s: final hook and exit to idle.
5. If owner review is positive, run the full suite once more, commit the batch,
   and push. Do not declare completion from motion metrics alone.

## Perceptual standard for the next session

The owner has repeatedly rejected technically smooth movement that still looks
like a puppet, exercise routine, or generic arm waving. Use these checks:

- Does the elbow lead/follow in a credible chain, or does the paw drag the arm?
- Does a high reach preserve flex and a believable shoulder/clavicle pathway?
- Does a return travel through a different arc or sustained release rather
  than springing directly home?
- Can the arms maintain their own rhythmic phrase while torso translation
  displaces them naturally underneath?
- Do weight shifts affect the torso and support leg without forcing every arm
  accent to restart?
- Do the three cats share musical intent without tracing identical paths?
- Is there a recognisable, song-specific payoff, contrast, and evolution over
  the full track?
- When a pose holds, is there contained rhythmic life rather than a freeze?
- Are transitions velocity-continuous in the actual production export?

The work is materially better than the starting point, but the active goal is
not complete until the owner can watch the full export and agree that it reads
as credible, fun dance rather than robotic choreography.
