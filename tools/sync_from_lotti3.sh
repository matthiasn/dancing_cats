#!/usr/bin/env bash
#
# Re-sync this standalone repo with the latest dancing-cats source in lotti3.
#
# The eject is more than a copy: it mirrors the character/scenery closure and
# then re-applies a fixed set of transforms (package rename, default-path
# repoint, export-tooling renames, the two build-only alpha overlays). This
# script does all of it idempotently, so syncing after a new lotti3 commit is:
#
#     tools/sync_from_lotti3.sh && fvm flutter analyze && fvm flutter test
#
# Override the source checkout with LOTTI3=/path. Hand-authored, repo-specific
# files (pubspec.yaml, analysis_options.yaml, lib/main.dart, README.md,
# test/widget_test_utils.dart, assets/sample_track, assets/fonts) are never
# touched — only the copied closure is mirrored.
set -euo pipefail

LOTTI3="${LOTTI3:-/home/parallels/github/lotti3}"
DST="$(cd "$(dirname "$0")/.." && pwd)"

[ -d "$LOTTI3" ] || { echo "lotti3 source not found: $LOTTI3" >&2; exit 1; }
echo "Syncing closure  $LOTTI3  ->  $DST"

rs() { rsync -a --delete "$@"; }

# 1. code + tests closure (mirror; --delete drops files removed upstream).
#    Safe for repo-specific files: lib/main.dart and test/widget_test_utils.dart
#    live outside lib/features and test/features.
rs "$LOTTI3/lib/features/character/"  "$DST/lib/features/character/"
rs "$LOTTI3/lib/features/scenery/"    "$DST/lib/features/scenery/"
rs "$LOTTI3/test/features/character/" "$DST/test/features/character/"
rs "$LOTTI3/test/features/scenery/"   "$DST/test/features/scenery/"

# 2. the three scenery shaders.
cp "$LOTTI3"/shaders/scenery_sky.frag \
   "$LOTTI3"/shaders/scenery_ocean.frag \
   "$LOTTI3"/shaders/scenery_city_lights.frag "$DST/shaders/"

# 3. scenery art (mirror).
rs "$LOTTI3/assets/scenery/" "$DST/assets/scenery/"

# 4. character backdrop plate + the two alpha overlays. The alphas are not
#    git-tracked upstream; they live only in lotti3's test build output.
cp "$LOTTI3/assets/images/character/lagos_waterfront.webp" "$DST/assets/images/character/"
alpha_src="$LOTTI3/build/unit_test_assets/assets/images/character"
for a in lagos_clouds_alpha lagos_wave_glints_alpha; do
  if [ -f "$alpha_src/$a.webp" ]; then
    cp "$alpha_src/$a.webp" "$DST/assets/images/character/"
  else
    echo "WARN: $a.webp missing from lotti3 build output — run a lotti3 test" \
         "(e.g. character_painter_test) to regenerate it" >&2
  fi
done

# 5. tooling (skip venvs / generated out). Per-subdir --delete keeps THIS script
#    (tools/sync_from_lotti3.sh) safe from deletion.
for t in dance_audio scenery_art character_video_export; do
  rsync -a --delete \
    --exclude '.venv' --exclude '.venv-asr' --exclude 'out' --exclude '__pycache__' \
    "$LOTTI3/tools/$t/" "$DST/tools/$t/"
done

# 6. dance/scenery Claude skills.
for s in choreo-phrase-authoring character-video-export character-motion-review-panel \
         dance-track-prep dance-lipsync scenery-art-layer-prep scenery-layer-registration \
         cinematic-render-panel flutter-shader-validation temporal-animation-diff; do
  [ -d "$LOTTI3/.claude/skills/$s" ] && \
    rsync -a --delete "$LOTTI3/.claude/skills/$s/" "$DST/.claude/skills/$s/"
done

echo "Re-applying eject transforms"

# 7a. package rename (only rewrites freshly-copied files that still say lotti).
grep -rIl --include='*.dart' 'package:lotti/' "$DST/lib" "$DST/test" 2>/dev/null \
  | xargs -r sed -i 's#package:lotti/#package:dancing_cats/#g'

# 7b. default data paths -> bundled sample.
sed -i 's#/home/parallels/github/lotti/tools/dance_audio/out/moving#assets/sample_track/moving#g' \
  "$DST/lib/features/character/demo/character_dance_to_track_demo.dart" \
  "$DST/test/features/character/dance_player_window_test.dart" \
  "$DST/test/features/character/dance_video_export_test.dart"

# 7c. demo window title.
sed -i 's#Lotti dance export#dancing_cats dance export#g' \
  "$DST/lib/features/character/demo/character_dance_to_track_demo.dart"

# 7d. export tooling: built binary name, default paths, tmp/log names.
sed -i -e 's#release/bundle/lotti#release/bundle/dancing_cats#g' \
       -e 's#/home/parallels/github/lotti/tools/dance_audio/out/moving#assets/sample_track/moving#g' \
       -e 's#lotti-dance-export#dancing-cats-dance-export#g' \
       -e 's#lotti-dance-realtime#dancing-cats-dance-realtime#g' \
  "$DST"/tools/character_video_export/*.sh

# 7e. scenery opencv venv path.
sed -i 's#lotti-scenery-opencv#dancing-cats-scenery-opencv#g' \
  "$DST/lib/features/scenery/README.md" \
  "$DST/tools/scenery_art/README.md" \
  "$DST/tools/scenery_art/isolate_clouds.py"

# 8. normalise import ordering (the rename reshuffles directive sort order) and
#    format. Skip with NO_DARTFIX=1.
if [ "${NO_DARTFIX:-0}" != "1" ]; then
  ( cd "$DST" && fvm dart fix --apply >/dev/null && fvm dart format . >/dev/null )
fi

echo "Done. Verify with: fvm flutter analyze && fvm flutter test"
