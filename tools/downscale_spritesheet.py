#!/usr/bin/env python3
"""Downscale a minigame spritesheet and the AtlasTexture regions that slice it.

Several minigame sheets store far more resolution than they are ever drawn with
-- the parakeets are 800 px frames shown at 320 px. The frames cannot simply be
re-imported smaller, because the SpriteFrames resources address them by hardcoded
pixel regions, and `process/size_limit` would leave every region pointing at the
wrong pixels.

This scales the sheet and every region by the same factor, so the slicing stays
exactly as it was and no animation changes. It refuses to run unless every region
lands on integer pixels at the requested factor.

The sprites that draw the sheet then need their scale multiplied by 1/factor and
their `offset` multiplied by factor, to keep landing on the same screen pixels --
the script prints those values; it does not edit scenes.

    python3 tools/downscale_spritesheet.py 0.48 \\
        assets/minigames/parakeets/graphic/green_parakeet_spritesheet.png
"""

from __future__ import annotations

import re
import sys
from fractions import Fraction
from pathlib import Path

import numpy as np
from PIL import Image

Image.MAX_IMAGE_PIXELS = None
PROJECT_ROOT = Path(__file__).resolve().parent.parent
SEARCH_DIRS = ("sources", "resources")
REGION_RE = re.compile(r"region = Rect2\(([^)]*)\)")


def resources_slicing(sheet: Path) -> list[Path]:
    """Every .tres/.tscn that references this sheet."""
    needle = "res://" + sheet.relative_to(PROJECT_ROOT).as_posix()
    found: list[Path] = []
    for directory in SEARCH_DIRS:
        root = PROJECT_ROOT / directory
        if not root.exists():
            continue
        for path in list(root.rglob("*.tres")) + list(root.rglob("*.tscn")):
            if needle in path.read_text(encoding="utf-8", errors="ignore"):
                found.append(path)
    return sorted(found)


def resize_premultiplied(img: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Downscale RGBA without transparent pixels bleeding dark halos inward."""
    arr = np.asarray(img, dtype=np.float32) / 255.0
    arr[..., :3] *= arr[..., 3:4]
    out = Image.fromarray((arr * 255.0 + 0.5).astype("uint8"), "RGBA").resize(size, Image.LANCZOS)
    arr = np.asarray(out, dtype=np.float32) / 255.0
    alpha = arr[..., 3:4]
    with np.errstate(divide="ignore", invalid="ignore"):
        arr[..., :3] = np.where(alpha > 0.0, arr[..., :3] / np.maximum(alpha, 1e-6), 0.0)
    return Image.fromarray((arr.clip(0.0, 1.0) * 255.0 + 0.5).astype("uint8"), "RGBA")


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    factor = Fraction(sys.argv[1]).limit_denominator(10000)
    sheets = [PROJECT_ROOT / a for a in sys.argv[2:]]

    for sheet in sheets:
        if not sheet.exists():
            raise SystemExit(f"{sheet}: not found")
        resources = resources_slicing(sheet)
        if not resources:
            raise SystemExit(f"{sheet}: nothing references it, refusing to guess")

        regions: list[tuple[Fraction, ...]] = []
        for resource in resources:
            for match in REGION_RE.findall(resource.read_text()):
                regions.append(tuple(Fraction(v.strip()) for v in match.split(",")))
        if not regions:
            raise SystemExit(f"{sheet}: no AtlasTexture regions found in {resources}")

        bad = [r for r in regions if any((v * factor).denominator != 1 for v in r)]
        if bad:
            raise SystemExit(
                f"{sheet}: {len(bad)} region(s) would land on fractional pixels at "
                f"{factor}; pick a factor that divides the frame grid, e.g. {bad[0]}"
            )

        # Only the area the regions actually address is kept; sheets often carry a
        # stray row or column of padding beyond the last frame.
        used_w = max(int(r[0] + r[2]) for r in regions)
        used_h = max(int(r[1] + r[3]) for r in regions)
        image = Image.open(sheet).convert("RGBA")
        if used_w > image.width or used_h > image.height:
            raise SystemExit(f"{sheet}: regions address {used_w}x{used_h}, image is {image.size}")

        new_w = int(used_w * factor)
        new_h = int(used_h * factor)
        cropped = image.crop((0, 0, used_w, used_h))
        resized = resize_premultiplied(cropped, (new_w, new_h))
        resized.save(sheet, optimize=True)

        for resource in resources:
            text = resource.read_text()

            def scale_region(match: re.Match[str]) -> str:
                values = [Fraction(v.strip()) for v in match.group(1).split(",")]
                scaled = [int(v * factor) for v in values]
                return "region = Rect2(%s)" % ", ".join(str(v) for v in scaled)

            resource.write_text(REGION_RE.sub(scale_region, text))

        frame_sizes = sorted({(int(r[2]), int(r[3])) for r in regions})
        print(f"{sheet.relative_to(PROJECT_ROOT)}")
        print(f"   {image.width}x{image.height} -> {new_w}x{new_h}"
              f"   ({image.width * image.height / 1e6:.1f} -> {new_w * new_h / 1e6:.1f} Mpx,"
              f" {(image.width * image.height) / (new_w * new_h):.2f}x less)")
        print(f"   {len(regions)} regions in {len(resources)} resource(s) rescaled;"
              f" frame sizes {frame_sizes} -> {[(int(w * factor), int(h * factor)) for w, h in frame_sizes]}")
        for resource in resources:
            print(f"      {resource.relative_to(PROJECT_ROOT)}")
        print(f"   sprites drawing it need scale x {1 / factor} and offset x {factor}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
