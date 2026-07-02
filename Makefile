SHELL := /usr/bin/env bash

.DEFAULT_GOAL := export-1080p60-fast

.PHONY: \
	help \
	export-1080p60-fast \
	export-1080p60-smoke \
	export-1080p60-hook \
	verify-export

help:
	@$(MAKE) -C tools/character_video_export help
	@printf '\n%s\n' \
	  'Root shortcuts:' \
	  '  make export-1080p60-fast   rebuild release app, then export full 1080p60 fast MP4' \
	  '  make export-1080p60-smoke  rebuild release app, then export 5s 1080p60 smoke MP4' \
	  '  make export-1080p60-hook   rebuild release app, then export 12s 1080p60 hook MP4' \
	  '  make verify-export OUT=... verify an exported MP4'

export-1080p60-fast:
	$(MAKE) -C tools/character_video_export full-1080p-fast FPS=60 REBUILD=1

export-1080p60-smoke:
	$(MAKE) -C tools/character_video_export smoke-1080p FPS=60 REBUILD=1

export-1080p60-hook:
	$(MAKE) -C tools/character_video_export hook-1080p FPS=60 REBUILD=1

verify-export:
	$(MAKE) -C tools/character_video_export verify OUT="$(OUT)"
