PYTHON ?= python3

.PHONY: blue-hour inspect

# blue_hour_cloudless.webp is now the immutable full-frame base plate directly
# (already cloudless, palms-in-foreground removed) — there is no separate master
# plate to derive it from anymore, so isolate_clouds.py is not part of this
# target. clouds_far/mid/near.webp are frozen assets from the earlier master-era
# extraction and remain valid unmodified layers over the new base.
blue-hour:
	$(PYTHON) layer_from_masks.py \
		--master ../../assets/scenery/blue_hour_cloudless.webp \
		--out-dir ../../assets/scenery \
		--preview-dir ../../tmp/scenery_work \
		--layer city_bridge=scenes/blue_hour_waterfront/masks/city_bridge.png \
		--layer yacht=scenes/blue_hour_waterfront/masks/yacht.png \
		--layer foreground=scenes/blue_hour_waterfront/masks/foreground.png
	$(PYTHON) bake_city_windows.py

inspect:
	$(PYTHON) inspect_layers.py
