#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Export the beat-synced character showcase by capturing a release Linux app.

This is the fast preview/master-candidate path for the current VM: it runs the
release demo inside a temporary rootful Xwayland display, prerolls the app,
captures one extra second to let x11grab/ffmpeg settle, trims that capture
preroll away, and muxes the requested song segment as AAC.

Unlike the frame-exact app exporter, this is still a real-time screen capture.
Use the built-in smoke checks after export when cadence matters.

Usage:
  tools/character_video_export/export_dance_video_realtime.sh [options]

Options:
  --preset 1440p|1080p|720p
                             Output size preset (default: 1080p)
  --width PX                Override output width (must be even)
  --height PX               Override output height (must be even)
  --render-width PX         Temporary app/capture width (default: 1440 for 1080p)
  --render-height PX        Temporary app/capture height (default: 810 for 1080p)
  --fps N                   Output frames per second (default: 60)
  --start SEC               Audio/render start time in seconds (default: 0)
  --duration SEC            Export duration in seconds (default: beatmap duration)
  --out PATH                Output MP4 path
  --audio PATH              Audio file path
  --beatmap PATH            Beat-map JSON path
  --words PATH              Optional synced words JSON path
  --cues PATH               Optional Rhubarb cues JSON path
  --crf N                   x264 CRF, lower is better/larger (default: 18)
  --audio-kbps N            AAC bitrate in kbps (default: 320)
  --x264-preset NAME        x264 preset (default: veryfast)
  --app-preroll SEC         App run time before capture starts (default: 2)
  --capture-preroll SEC     Captured preroll trimmed out of output (default: 1)
  --rebuild                 Rebuild the Linux release bundle first
  --captions                Burn lyric captions into the video
  -h, --help                Show this help

Example:
  tools/character_video_export/export_dance_video_realtime.sh \
    --preset 1080p --fps 60 \
    --out build/character_video_exports/dance_full_1080p60_fast.mp4
EOF
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

preset="1080p"
width=""
height=""
render_width=""
render_height=""
fps="60"
start="0"
duration=""
out=""
audio="${DANCE_AUDIO:-/home/parallels/Downloads/Omah_Lay-Moving.mp3}"
beatmap="${DANCE_BEATMAP:-assets/sample_track/moving.json}"
words="${DANCE_WORDS:-assets/sample_track/moving.words.json}"
cues="${DANCE_CUES:-assets/sample_track/moving.cues.json}"
crf="18"
audio_kbps="320"
x264_preset="veryfast"
app_preroll="2"
# Must exceed ffmpeg's worst-case spin-up (measured up to ~2.5s for x11grab +
# encoder init on this VM under load): the capture has to begin BEFORE the
# app's clock reaches `start`, or the head of the clip is simply never
# captured and no measured trim can recover it. The two-pass measured trim
# cuts the surplus exactly, so a generous preroll costs only capture time.
capture_preroll="6"
skip_sync_check="0"
rebuild="0"
captions="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --preset)
      preset="${2:?missing value for --preset}"
      shift 2
      ;;
    --width)
      width="${2:?missing value for --width}"
      shift 2
      ;;
    --height)
      height="${2:?missing value for --height}"
      shift 2
      ;;
    --render-width)
      render_width="${2:?missing value for --render-width}"
      shift 2
      ;;
    --render-height)
      render_height="${2:?missing value for --render-height}"
      shift 2
      ;;
    --fps)
      fps="${2:?missing value for --fps}"
      shift 2
      ;;
    --start)
      start="${2:?missing value for --start}"
      shift 2
      ;;
    --duration)
      duration="${2:?missing value for --duration}"
      shift 2
      ;;
    --out)
      out="${2:?missing value for --out}"
      shift 2
      ;;
    --audio)
      audio="${2:?missing value for --audio}"
      shift 2
      ;;
    --beatmap)
      beatmap="${2:?missing value for --beatmap}"
      shift 2
      ;;
    --words)
      words="${2:?missing value for --words}"
      shift 2
      ;;
    --cues)
      cues="${2:?missing value for --cues}"
      shift 2
      ;;
    --crf)
      crf="${2:?missing value for --crf}"
      shift 2
      ;;
    --audio-kbps)
      audio_kbps="${2:?missing value for --audio-kbps}"
      shift 2
      ;;
    --x264-preset)
      x264_preset="${2:?missing value for --x264-preset}"
      shift 2
      ;;
    --app-preroll)
      app_preroll="${2:?missing value for --app-preroll}"
      shift 2
      ;;
    --skip-sync-check)
      skip_sync_check="1"
      shift
      ;;
    --capture-preroll)
      capture_preroll="${2:?missing value for --capture-preroll}"
      shift 2
      ;;
    --rebuild)
      rebuild="1"
      shift
      ;;
    --captions)
      captions="1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$preset" in
  1080p)
    width="${width:-1920}"
    height="${height:-1080}"
    render_width="${render_width:-1440}"
    render_height="${render_height:-810}"
    ;;
  1440p)
    width="${width:-2560}"
    height="${height:-1440}"
    render_width="${render_width:-2560}"
    render_height="${render_height:-1440}"
    ;;
  720p)
    width="${width:-1280}"
    height="${height:-720}"
    render_width="${render_width:-1280}"
    render_height="${render_height:-720}"
    ;;
  *)
    if [[ -z "$width" || -z "$height" ]]; then
      echo "Unknown preset '$preset'. Use 1080p, 720p, or pass --width/--height." >&2
      exit 2
    fi
    render_width="${render_width:-$width}"
    render_height="${render_height:-$height}"
    ;;
esac

if [[ -z "$out" ]]; then
  out="build/character_video_exports/dance_realtime_${width}x${height}_${fps}fps.mp4"
fi

for value in "$width" "$height" "$render_width" "$render_height"; do
  if (( value % 2 != 0 )); then
    echo "All output/render dimensions must be even for yuv420p H.264" >&2
    exit 2
  fi
done

for path in "$audio" "$beatmap"; do
  if [[ ! -f "$path" ]]; then
    echo "Required input not found: $path" >&2
    exit 2
  fi
done

if ! command -v ffmpeg >/dev/null; then
  echo "ffmpeg is required" >&2
  exit 2
fi
if ! command -v Xwayland >/dev/null; then
  echo "Xwayland is required for the realtime exporter" >&2
  exit 2
fi

if [[ -z "$duration" ]]; then
  duration="$(
    python3 - "$beatmap" "$start" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)
start = float(sys.argv[2])
duration = data.get("audio", {}).get("duration_sec")
if duration is None:
    last_beat = data["beats"][-1]
    duration = last_beat["time_sec"] if isinstance(last_beat, dict) else last_beat
duration = float(duration)
print(f"{max(0.0, duration - start):.6f}")
PY
  )"
fi

if awk -v d="$duration" 'BEGIN { exit !(d > 0) }'; then
  :
else
  echo "Export duration must be positive" >&2
  exit 2
fi

app="build/linux/arm64/release/bundle/dancing_cats"
if [[ "$rebuild" == "1" || ! -x "$app" ]]; then
  fvm flutter build linux --release -t lib/main.dart
fi

mkdir -p "$(dirname "$out")"
tmpdir="$(mktemp -d -t dancing-cats-dance-realtime.XXXXXX)"
ready_file="$tmpdir/ready"
start_file="$tmpdir/start"
capture_file="$tmpdir/capture"
display=":$((120 + RANDOM % 80))"
xwayland_pid=""
app_pid=""

cleanup() {
  if [[ -n "$app_pid" ]]; then
    kill "$app_pid" 2>/dev/null || true
    wait "$app_pid" 2>/dev/null || true
  fi
  if [[ -n "$xwayland_pid" ]]; then
    kill "$xwayland_pid" 2>/dev/null || true
    wait "$xwayland_pid" 2>/dev/null || true
  fi
  rm -rf "$tmpdir"
}
trap cleanup EXIT

render_start="$(
  awk \
    -v s="$start" \
    -v a="$app_preroll" \
    -v c="$capture_preroll" \
    'BEGIN { printf "%.6f", s - a - c }'
)"

Xwayland "$display" \
  -geometry "${render_width}x${render_height}" \
  -fakescreenfps "$fps" \
  -ac \
  -noreset \
  -nocursor \
  >"$tmpdir/xwayland.log" 2>&1 &
xwayland_pid="$!"
for _ in {1..80}; do
  if xdpyinfo -display "$display" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

DISPLAY="$display" \
GDK_BACKEND=x11 \
DANCE_RENDER_ONLY=1 \
DANCE_RENDER_WIDTH="$render_width" \
DANCE_RENDER_HEIGHT="$render_height" \
DANCE_RENDER_START="$render_start" \
DANCE_RENDER_READY_FILE="$ready_file" \
DANCE_RENDER_START_FILE="$start_file" \
DANCE_RENDER_CAPTURE_FILE="$capture_file" \
DANCE_RENDER_CAPTURE_AT="$(awk -v s="$start" -v c="$capture_preroll" 'BEGIN { printf "%.6f", s - c }')" \
DANCE_RENDER_CAPTIONS="$captions" \
DANCE_AUDIO="$audio" \
DANCE_BEATMAP="$beatmap" \
DANCE_WORDS="$words" \
DANCE_CUES="$cues" \
"$app" >"$tmpdir/app.log" 2>&1 &
app_pid="$!"

for _ in {1..400}; do
  if [[ -f "$ready_file" ]]; then
    break
  fi
  if ! kill -0 "$app_pid" 2>/dev/null; then
    echo "App exited before it became ready:" >&2
    cat "$tmpdir/app.log" >&2 || true
    exit 1
  fi
  sleep 0.1
done
if [[ ! -f "$ready_file" ]]; then
  echo "Timed out waiting for the render window to become ready" >&2
  cat "$tmpdir/app.log" >&2 || true
  exit 1
fi

touch "$start_file"
# Wait for the app to report that its render clock has actually reached the
# capture point (start - capture_preroll), instead of assuming a fixed sleep
# covers the app's warm-up. The first full-stage frame can block the main
# thread for seconds on cold shader caches; a fixed sleep then starts the
# capture against a frozen app and ships video that lags the muxed audio
# (measured at +3.5s and +3.1s before this handshake — the sync gate below
# caught both). The app-preroll budget still bounds the wait.
capture_wait_limit="$(awk -v a="$app_preroll" 'BEGIN { printf "%d", (a + 30) * 50 }')"
for (( i = 0; i < capture_wait_limit; i++ )); do
  if [[ -f "$capture_file" ]]; then
    break
  fi
  if ! kill -0 "$app_pid" 2>/dev/null; then
    echo "App exited before reaching the capture point:" >&2
    cat "$tmpdir/app.log" >&2 || true
    exit 1
  fi
  sleep 0.02
done
if [[ ! -f "$capture_file" ]]; then
  echo "Timed out waiting for the app to reach the capture point" >&2
  cat "$tmpdir/app.log" >&2 || true
  exit 1
fi

# TWO-PASS, MEASURED-TRIM capture. A fixed trim assumed the wall time between
# the app handshake and ffmpeg's first grabbed frame was a known constant; in
# practice ffmpeg's own spin-up ranged from ~10ms to ~2.2s on this VM, and
# every unpredicted millisecond shipped as A/V misalignment. Pass 1 captures
# an UNTRIMMED stream with generous slack; the stage lights flash on the beat
# map's strong onsets, so the captured pixels carry their own sync fiducials —
# the offset is MEASURED on the intermediate and pass 2 cuts exactly there.
capture_tmp="$tmpdir/capture_untrimmed.mp4"
capture_slack="4"
ffmpeg \
  -y \
  -thread_queue_size 1024 \
  -f x11grab \
  -video_size "${render_width}x${render_height}" \
  -framerate "$fps" \
  -draw_mouse 0 \
  -i "${display}.0+0,0" \
  -t "$(awk -v d="$duration" -v c="$capture_preroll" -v s="$capture_slack" 'BEGIN { printf "%.3f", d + c + s }')" \
  -vf "scale=${width}:${height}:flags=lanczos" \
  -c:v libx264 \
  -preset ultrafast \
  -crf 12 \
  -pix_fmt yuv420p \
  -r "$fps" \
  -an \
  "$capture_tmp"

# Measure where audio position `start` actually sits in the captured stream.
video_zero="$(python3 - "$capture_tmp" "$beatmap" "$start" "$duration" "$capture_preroll" <<'PY'
import bisect
import json, subprocess, sys

cap, beatmap, start, duration, head = (
    sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4]),
    float(sys.argv[5]),
)
onsets = [
    (o["time_sec"], o["strength"])
    for o in json.load(open(beatmap)).get("onsets", [])
    if o.get("strength", 0) >= 0.5
]
probe_from = 3.0 if duration > 15 else 0.0
probe_len = min(45.0, max(duration - probe_from, 1.0))
lo = head + probe_from
hi = lo + probe_len
sel = f"movie={cap},select='between(t\\,{lo}\\,{hi})',signalstats"
rows = subprocess.run(
    ["ffprobe", "-v", "error", "-f", "lavfi", "-i", sel,
     "-show_entries", "frame=pts_time:frame_tags=lavfi.signalstats.YAVG",
     "-of", "csv=p=0"],
    capture_output=True, text=True, check=True,
).stdout
vals = []
for line in rows.splitlines():
    parts = line.strip().split(",")
    if len(parts) == 2 and parts[0] and parts[1]:
        vals.append((float(parts[0]), float(parts[1])))
if len(vals) < 60:
    print("ERR too few frames in the capture probe", file=sys.stderr)
    sys.exit(1)
base = sum(y for _, y in vals) / len(vals)
flashes = []
for t, y in vals:
    if y > base + 3:
        if flashes and t - flashes[-1][0] < 0.25:
            if y > flashes[-1][1]:
                flashes[-1] = (t, y)
        else:
            flashes.append((t, y))
window = sorted(
    t - start + head
    for t, _ in onsets
    if lo - head + start <= t <= hi - head + start
)
if len(flashes) < 3 or len(window) < 3:
    print(
        f"ERR too few fiducials (flashes={len(flashes)} onsets={len(window)})",
        file=sys.stderr,
    )
    sys.exit(1)
def matches(delta):
    n = 0
    for ft, _ in flashes:
        target = ft - delta
        i = bisect.bisect_left(window, target)
        best = min(
            (abs(window[j] - target) for j in (i - 1, i) if 0 <= j < len(window)),
            default=99.0,
        )
        if best <= 0.12:
            n += 1
    return n
best_delta, best_n = 0.0, -1
d = -(head + 1.0)
while d <= 8.0:
    n = matches(d)
    if n > best_n or (n == best_n and abs(d) < abs(best_delta)):
        best_delta, best_n = d, n
    d += 0.01
if best_n < 3:
    print("ERR could not lock the fiducial offset", file=sys.stderr)
    sys.exit(1)
# Audio `start` sits at capture time head+best_delta.
print(f"{head + best_delta:.3f}")
print(
    f"measured trim {head + best_delta:+.3f}s ({best_n}/{len(flashes)} flashes)",
    file=sys.stderr,
)
PY
)" || {
  echo "Failed to measure the capture's A/V offset; not producing a master" >&2
  exit 1
}
echo "capture trim at ${video_zero}s (measured from light-flash fiducials)"

ffmpeg \
  -y \
  -ss "$video_zero" \
  -i "$capture_tmp" \
  -ss "$start" \
  -t "$duration" \
  -i "$audio" \
  -map 0:v:0 \
  -map 1:a:0 \
  -t "$duration" \
  -c:v libx264 \
  -preset "$x264_preset" \
  -crf "$crf" \
  -pix_fmt yuv420p \
  -profile:v high \
  -level 4.2 \
  -r "$fps" \
  -colorspace bt709 \
  -color_primaries bt709 \
  -color_trc bt709 \
  -c:a aac \
  -b:a "${audio_kbps}k" \
  -ar 48000 \
  -movflags +faststart \
  -shortest \
  "$out"

# A/V alignment gate: the stage lights flash on the beat map's strong onsets,
# so the encoded video carries its own sync fiducials. Estimate the offset of
# rendered flashes vs onset times (audio timeline) and refuse to bless a
# drifted master — an integrated-clock bug once shipped a full-song export
# whose video lagged its own audio by ~3.5s while every per-file property
# check still passed. Requires python3; skip with --skip-sync-check.
if [[ "$skip_sync_check" != "1" ]]; then
  sync_out="$(python3 - "$out" "$beatmap" "$start" "$duration" <<'PY'
import json, subprocess, sys

out, beatmap, start, duration = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4])
onsets = [
    (o["time_sec"], o["strength"])
    for o in json.load(open(beatmap)).get("onsets", [])
    if o.get("strength", 0) >= 0.5
]
# Probe up to 40s of the clip, starting a little in so encoder warm-up and
# entry transitions don't pollute the fiducials.
probe_from = 5.0 if duration > 15 else 0.0
probe_len = min(40.0, max(duration - probe_from, 1.0))
sel = f"movie={out},select='between(t\\,{probe_from}\\,{probe_from + probe_len})',signalstats"
rows = subprocess.run(
    ["ffprobe", "-v", "error", "-f", "lavfi", "-i", sel,
     "-show_entries", "frame=pts_time:frame_tags=lavfi.signalstats.YAVG",
     "-of", "csv=p=0"],
    capture_output=True, text=True, check=True,
).stdout
vals = []
for line in rows.splitlines():
    parts = line.strip().split(",")
    if len(parts) == 2 and parts[0] and parts[1]:
        vals.append((float(parts[0]), float(parts[1])))
if len(vals) < 60:
    print("SKIP too few frames to check")
    sys.exit(0)
base = sum(y for _, y in vals) / len(vals)
flashes = []
for t, y in vals:
    if y > base + 3:
        if flashes and t - flashes[-1][0] < 0.25:
            if y > flashes[-1][1]:
                flashes[-1] = (t, y)
        else:
            flashes.append((t, y))
window = [t - start for t, _ in onsets if start + probe_from <= t <= start + probe_from + probe_len]
if len(flashes) < 3 or len(window) < 3:
    print(f"SKIP too few fiducials (flashes={len(flashes)} onsets={len(window)})")
    sys.exit(0)
# Cross-correlate the flash train against the onset train over a wide lag
# range. Nearest-onset matching aliases: with onsets ~0.5-1.2s apart, a
# grossly drifted video still finds SOME onset near every flash and can
# report a small median. Scanning lags and maximizing matches finds the true
# shift (the onset train is irregular, so the peak is unambiguous).
win = sorted(window)
def matches(delta):
    n = 0
    for ft, _ in flashes:
        target = ft - delta
        import bisect
        i = bisect.bisect_left(win, target)
        best = min(
            (abs(win[j] - target) for j in (i - 1, i) if 0 <= j < len(win)),
            default=99.0,
        )
        if best <= 0.12:
            n += 1
    return n
best_delta, best_n = 0.0, -1
d = -5.0
while d <= 5.0:
    n = matches(d)
    if n > best_n or (n == best_n and abs(d) < abs(best_delta)):
        best_delta, best_n = d, n
    d += 0.01
print(
    f"OFFSET {best_delta:+.3f}s (matched {best_n}/{len(flashes)} flashes)"
)
sys.exit(0 if abs(best_delta) <= 0.15 and best_n >= 3 else 3)
PY
)" || {
    echo "A/V SYNC CHECK FAILED for $out: $sync_out" >&2
    echo "video content is misaligned with the muxed audio; not a valid master" >&2
    exit 1
  }
  echo "sync check: $sync_out"
fi

echo "wrote $out"
