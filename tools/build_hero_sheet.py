"""Slice the supplied 4x4 character action sheet into an engine-ready sheet.

The source art has transparent gutters, but the rows are not evenly spaced:
long hair and airborne poses cross the naive 1/4-height grid lines.  Each
column is therefore segmented by its own vertical alpha runs, and every frame
is cropped to its real bounding box before being re-aligned on the character's
torso anchor.  This keeps the animation from shimmying or clipping into the
neighbouring frame.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/characters/hero/hero_source.png"
OUTPUT = ROOT / "assets/characters/hero/hero_sheet.png"

# 4 columns x 4 actions: idle, run A, run B, jump arc.
COLUMNS = 4
ROWS = 4
CELL_W, CELL_H = 320, 380
ANCHOR_X, ANCHOR_Y = 160, 200
# The root pixel (between the soles of the idle poses) sits here in every cell.
FOOT_Y = 342
ALPHA_THRESHOLD = 16


def split_column(mask: np.ndarray, x0: int, x1: int) -> list[tuple[int, int]]:
    """Return the four vertical character bands inside one source column."""
    column = mask[:, x0:x1]
    occupied = column.any(axis=1)
    bands: list[tuple[int, int]] = []
    start: int | None = None
    for y, filled in enumerate(occupied):
        if filled and start is None:
            start = y
        elif not filled and start is not None:
            if y - start > 5:
                bands.append((start, y - 1))
            start = None
    if start is not None:
        bands.append((start, len(occupied) - 1))
    if len(bands) != ROWS:
        raise RuntimeError(f"column {x0}-{x1}: expected {ROWS} poses, got {bands}")
    return bands


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    pixels = np.asarray(source)
    alpha = pixels[..., 3]
    luminance = pixels[..., :3].mean(axis=2)
    mask = alpha > ALPHA_THRESHOLD
    height, width = mask.shape

    sheet = Image.new("RGBA", (CELL_W * COLUMNS, CELL_H * ROWS), (0, 0, 0, 0))
    report: list[str] = []

    for column in range(COLUMNS):
        x0 = round(column * width / COLUMNS)
        x1 = round((column + 1) * width / COLUMNS)
        for row, (y0, y1) in enumerate(split_column(mask, x0, x1)):
            cell_mask = mask[y0 : y1 + 1, x0:x1]
            ys, xs = np.where(cell_mask)
            left = x0 + int(xs.min())
            right = x0 + int(xs.max())
            top = y0 + int(ys.min())
            bottom = y1

            # Torso anchor: the dark dress / hair mass is far more stable than
            # the bounding box when the silhouette includes flying hair.
            dark = (luminance[top : bottom + 1, left : right + 1] < 120) & (
                alpha[top : bottom + 1, left : right + 1] > 200
            )
            dark_y, dark_x = np.where(dark)
            if len(dark_x):
                body_x = left + float(np.median(dark_x))
                body_y = top + float(np.median(dark_y))
            else:  # fallback for a hypothetical empty frame
                body_x = (left + right) / 2
                body_y = (top + bottom) / 2

            frame = source.crop((left, top, right + 1, bottom + 1))
            cell_x = column * CELL_W + round(ANCHOR_X - (body_x - left))
            cell_y = row * CELL_H + round(ANCHOR_Y - (body_y - top))
            sheet.alpha_composite(frame, (cell_x, cell_y))
            report.append(
                f"r{row}c{column}: crop=({left},{top},{right},{bottom}) "
                f"body=({body_x:.1f},{body_y:.1f}) -> cell=({cell_x},{cell_y})"
            )

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUTPUT)
    print(f"wrote {OUTPUT} ({sheet.width}x{sheet.height})")
    print("\n".join(report))


if __name__ == "__main__":
    main()
