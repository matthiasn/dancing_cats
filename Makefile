SHELL := /usr/bin/env bash

.DEFAULT_GOAL := help

OUT_DIR ?= build/character_video_exports
FPS ?= 60
START ?= 0
DURATION ?=
CRF ?= 18
X264_PRESET ?= veryfast
AUDIO_KBPS ?= 128
AUDIO ?=
REBUILD ?= 1
CAPTIONS ?= 0
OUT ?= $(OUT_DIR)/dance_full_1080p$(FPS)_macos_hq.mp4

REALTIME := tools/character_video_export/export_dance_video_realtime.sh
LINUX_EXACT := tools/character_video_export/export_dance_video_app.sh
MACOS_EXACT := tools/character_video_export/export_dance_video_macos.sh
SOFTWARE_EXACT := tools/character_video_export/export_dance_video.sh

REBUILD_FLAG = $(if $(filter 1 true yes,$(REBUILD)),--rebuild,)
CAPTIONS_FLAG = $(if $(filter 1 true yes,$(CAPTIONS)),--captions,)
DURATION_FLAG = $(if $(DURATION),--duration $(DURATION),)
AUDIO_FLAG = $(if $(AUDIO),--audio "$(AUDIO)",)

COMMON_FLAGS = \
	--fps $(FPS) \
	--start $(START) \
	$(DURATION_FLAG) \
	$(AUDIO_FLAG) \
	--crf $(CRF) \
	--audio-kbps $(AUDIO_KBPS) \
	--x264-preset $(X264_PRESET) \
	$(REBUILD_FLAG) \
	$(CAPTIONS_FLAG)

.PHONY: \
	help \
	export \
	export-1080p60-macos-hq \
	export-1080p60-fast \
	export-1080p60-hidden \
	export-1080p60-software \
	export-1080p60-smoke \
	export-1080p60-hook \
	verify-export

help:
	@printf '%s\n' \
	  'Character dance video exports' \
	  '' \
	  'Recommended local export:' \
	  '  make export-1080p60-macos-hq' \
	  '' \
	  'Targets:' \
	  '  make export                    alias for export-1080p60-macos-hq' \
	  '  make export-1080p60-macos-hq   full 1080p60 macOS exact export, CRF 16, AAC 128k' \
	  '  make export-1080p60-fast       full 1080p60 Linux Xwayland realtime export' \
	  '  make export-1080p60-hidden     full 1080p60 Linux frame-exact export via Xvfb' \
	  '  make export-1080p60-software   full 1080p60 flutter_test software export' \
	  '  make export-1080p60-smoke      5s 1080p60 hook smoke clip' \
	  '  make export-1080p60-hook       12s 1080p60 hook clip' \
	  '  make verify-export OUT=...     ffprobe + frame-hash cadence check' \
	  '' \
	  'Useful variables:' \
	  '  REBUILD=1                      rebuild release app first (default)' \
	  '  REBUILD=0                      reuse existing release app' \
	  '  FPS=60                         output fps' \
	  '  CRF=18                         x264 CRF; lower is larger/better' \
	  '  X264_PRESET=veryfast           x264 preset' \
	  '  AUDIO_KBPS=128                 AAC bitrate; 128 matches the source track' \
	  '  AUDIO=/path/to/track.m4a       override audio input path' \
	  '  OUT=build/.../file.mp4         custom output path for the main macOS target' \
	  '  START=80 DURATION=12           custom clip window' \
	  '  CAPTIONS=1                     burn captions'

export: export-1080p60-macos-hq

export-1080p60-macos-hq: CRF = 16
export-1080p60-macos-hq: X264_PRESET = slow
export-1080p60-macos-hq: AUDIO_KBPS = 128
export-1080p60-macos-hq:
	$(MACOS_EXACT) \
		--preset 1080p \
		$(COMMON_FLAGS) \
		--out "$(OUT)"

export-1080p60-fast:
	$(REALTIME) \
		--preset 1080p \
		$(COMMON_FLAGS) \
		--out "$(OUT_DIR)/dance_full_1080p$(FPS)_fast.mp4"

export-1080p60-hidden:
	$(LINUX_EXACT) \
		--preset 1080p \
		$(COMMON_FLAGS) \
		--out "$(OUT_DIR)/dance_full_1080p$(FPS)_hidden_exact.mp4"

export-1080p60-software: X264_PRESET = slow
export-1080p60-software:
	$(SOFTWARE_EXACT) \
		--preset 1080p \
		$(COMMON_FLAGS) \
		--out "$(OUT_DIR)/dance_full_1080p$(FPS)_software_exact.mp4"

export-1080p60-smoke: START = 80
export-1080p60-smoke: DURATION = 5
export-1080p60-smoke: CRF = 23
export-1080p60-smoke: X264_PRESET = ultrafast
export-1080p60-smoke:
	$(MACOS_EXACT) \
		--preset 1080p \
		$(COMMON_FLAGS) \
		--out "$(OUT_DIR)/dance_smoke_1080p$(FPS)_macos.mp4"

export-1080p60-hook: START = 80
export-1080p60-hook: DURATION = 12
export-1080p60-hook:
	$(MACOS_EXACT) \
		--preset 1080p \
		$(COMMON_FLAGS) \
		--out "$(OUT_DIR)/dance_hook_1080p$(FPS)_macos.mp4"

verify-export:
	test -s "$(OUT)"
	ffprobe -v error -select_streams v:0 \
		-show_entries stream=codec_name,width,height,pix_fmt,r_frame_rate,avg_frame_rate,nb_frames,color_space,color_transfer,color_primaries \
		-of default=noprint_wrappers=1 "$(OUT)"
	ffprobe -v error -select_streams a:0 \
		-show_entries stream=codec_name,sample_rate,channels,bit_rate \
		-of default=noprint_wrappers=1 "$(OUT)"
	ffprobe -v error -show_entries format=duration,size \
		-of default=noprint_wrappers=1 "$(OUT)"
	ffmpeg -v error -i "$(OUT)" -map 0:v:0 -an \
		-vf "scale=480:-1,format=rgb24" -f framemd5 - | \
		awk 'BEGIN{prev="";same=0;maxrun=0;run=0;n=0} /^0,/ {hash=$$NF; n++; if(hash==prev){same++; run++} else {if(run>maxrun) maxrun=run; run=0} prev=hash} END{if(run>maxrun) maxrun=run; print "frames=" n, "same=" same, "maxrun=" maxrun}'
