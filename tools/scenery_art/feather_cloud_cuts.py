#!/usr/bin/env python3
"""Feather the hard rectangular erase cuts in the frozen cloud plates.

The clouds_far/mid/near.webp layers are frozen assets from the master-era
de-bake (see Makefile) — the clouded master no longer exists, so they cannot
be regenerated. clouds_far.webp carries a rectangular erase from that era:
everything below row 185 and left of column 760 was cleared, leaving hard
alpha cut lines. Against the old plate's sky the truncated haze slab was
invisible; the 2026-07 blue_hour_cloudless plate has a different sky tone
there, so the slab reads as a light block with a crisp bottom/right edge.

This script feathers those cut lines in place: alpha ramps smoothly to zero
approaching each cut instead of stopping abruptly. Each ramp is tapered at
its ends so no new seam is introduced where feathered pixels meet untouched
organic cloud. Deterministic; safe to re-run (already-feathered edges just
get re-feathered to the same values only if alpha still ends hard, otherwise
the multiplication further softens an already-soft ramp — so treat it as
run-once per asset generation, like the other bake steps).
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image

ASSETS = Path(__file__).resolve().parents[2] / "assets" / "scenery"


def _smoothstep(t: np.ndarray) -> np.ndarray:
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


@dataclass(frozen=True)
class HorizontalCut:
    """Alpha ends hard at `row` (content above, emptiness below)."""

    row: int
    x0: int
    x1: int
    feather: int = 56
    taper: int = 36


@dataclass(frozen=True)
class VerticalCut:
    """Alpha starts hard at `col` (emptiness left, content right)."""

    col: int
    y0: int
    y1: int
    feather: int = 56
    taper: int = 24


# Measured on assets/scenery/clouds_far.webp: the erase rectangle's kept-haze
# bottom edge (last content row 185, x 447..760 — so the ramp ends at 186) and
# the abrupt left boundary of the haze that survives to the right of the
# rectangle (first content col 760, y 186..264).
CLOUDS_FAR_CUTS = (
    HorizontalCut(row=186, x0=436, x1=770),
    VerticalCut(col=760, y0=178, y1=272),
)


def _lateral_weight(n: int, taper: int) -> np.ndarray:
    """1 in the middle of the span, smoothstepping to 0 at both ends."""
    idx = np.arange(n, dtype=np.float64)
    return np.minimum(
        _smoothstep(idx / max(taper, 1)),
        _smoothstep((n - 1 - idx) / max(taper, 1)),
    )


def feather_cuts(alpha: np.ndarray, cuts: tuple) -> np.ndarray:
    a = alpha.astype(np.float64)
    for cut in cuts:
        if isinstance(cut, HorizontalCut):
            rows = np.arange(cut.row - cut.feather, cut.row)
            ramp = _smoothstep((cut.row - rows) / cut.feather)  # 0 at the cut
            lw = _lateral_weight(cut.x1 - cut.x0, cut.taper)
            factor = 1.0 - lw[None, :] * (1.0 - ramp[:, None])
            a[rows[0] : cut.row, cut.x0 : cut.x1] *= factor
        elif isinstance(cut, VerticalCut):
            cols = np.arange(cut.col, cut.col + cut.feather)
            ramp = _smoothstep((cols - cut.col) / cut.feather)  # 0 at the cut
            lw = _lateral_weight(cut.y1 - cut.y0, cut.taper)
            factor = 1.0 - lw[:, None] * (1.0 - ramp[None, :])
            a[cut.y0 : cut.y1, cut.col : cut.col + cut.feather] *= factor
    return np.clip(np.rint(a), 0, 255).astype(np.uint8)


def main() -> None:
    path = ASSETS / "clouds_far.webp"
    image = Image.open(path).convert("RGBA")
    px = np.array(image)
    px[:, :, 3] = feather_cuts(px[:, :, 3], CLOUDS_FAR_CUTS)
    Image.fromarray(px, "RGBA").save(
        path, "WEBP", lossless=True, quality=100, method=6
    )
    print(f"feathered {len(CLOUDS_FAR_CUTS)} cuts in {path}")


if __name__ == "__main__":
    main()
