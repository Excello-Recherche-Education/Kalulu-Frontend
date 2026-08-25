#!/usr/bin/env python3
"""Extract chosen animations from a spritesheet into a small dedicated atlas.

For a character borrowed as decoration: the scene that borrows it plays a couple
of animations, but referencing the sheet costs the whole thing. This copies out
only the animations named, at the resolution they are actually drawn, and writes
a standalone SpriteFrames beside them.

    python3 tools/extract_animation_atlas.py \\
        --source sources/minigames/turtles/turtles_minigame.tscn \\
        --animations idle idle_claws victory_claws \\
        --frame-size 288 \\
        --out-png assets/minigames/turtles/graphic/crab_decor.png \\
        --out-tres sources/minigames/turtles/crab_decor_animations.tres

The sprite that draws it then needs its scale multiplied by
source_frame_size / frame_size; the script prints that factor.
"""

from __future__ import annotations

import argparse
import math
import re
from pathlib import Path

import numpy as np
from PIL import Image

Image.MAX_IMAGE_PIXELS = None
PROJECT_ROOT = Path(__file__).resolve().parent.parent
MAX_ATLAS_SIDE = 4096

IMPORT_TEMPLATE = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://{res_path}"

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""


def parse(source: Path) -> tuple[Path, dict[str, dict]]:
    """Return (sheet png, {animation: {frames: [rect], loop, speed}})."""
    text = source.read_text()

    textures: dict[str, str] = {}
    for block in re.findall(r"\[ext_resource[^\]]*\]", text):
        if 'type="Texture2D"' not in block:
            continue
        path = re.search(r'path="res://([^"]+)"', block)
        # id="..." but not the uid="..." that precedes it
        ident = re.search(r'(?:^|\s)id="([^"]+)"', block)
        if path and ident:
            textures[ident.group(1)] = path.group(1)

    regions: dict[str, tuple[str, tuple[float, ...]]] = {}
    for match in re.finditer(
        r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\s*'
        r'atlas = ExtResource\("([^"]+)"\)\s*region = Rect2\(([^)]*)\)',
        text,
    ):
        sub, atlas, rect = match.groups()
        regions[sub] = (atlas, tuple(float(v) for v in rect.split(",")))

    animations: dict[str, dict] = {}
    for match in re.finditer(
        r'\{\s*"frames": \[(.*?)\],\s*"loop": (\w+),\s*"name": &"([^"]+)",\s*"speed": ([0-9.]+)\s*\}',
        text,
        re.S,
    ):
        blob, loop, name, speed = match.groups()
        ids = [i for i in re.findall(r'SubResource\("([^"]+)"\)', blob) if i in regions]
        if ids:
            animations[name] = {
                "frames": [regions[i][1] for i in ids],
                "loop": loop == "true",
                "speed": float(speed),
                "atlas": regions[ids[0]][0],
            }

    if not animations:
        raise SystemExit(f"{source}: found no SpriteFrames animations")
    sheets = {a["atlas"] for a in animations.values()}
    if len(sheets) != 1:
        raise SystemExit(f"{source}: animations span several sheets, {sheets}")
    return PROJECT_ROOT / textures[sheets.pop()], animations


def resize_premultiplied(img: Image.Image, size: tuple[int, int]) -> Image.Image:
    arr = np.asarray(img, dtype=np.float32) / 255.0
    arr[..., :3] *= arr[..., 3:4]
    out = Image.fromarray((arr * 255.0 + 0.5).astype("uint8"), "RGBA").resize(size, Image.LANCZOS)
    arr = np.asarray(out, dtype=np.float32) / 255.0
    alpha = arr[..., 3:4]
    with np.errstate(divide="ignore", invalid="ignore"):
        arr[..., :3] = np.where(alpha > 0.0, arr[..., :3] / np.maximum(alpha, 1e-6), 0.0)
    return Image.fromarray((arr.clip(0.0, 1.0) * 255.0 + 0.5).astype("uint8"), "RGBA")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--animations", required=True, nargs="+")
    parser.add_argument("--frame-size", required=True, type=int)
    parser.add_argument("--out-png", required=True)
    parser.add_argument("--out-tres", required=True)
    args = parser.parse_args()

    sheet_path, animations = parse(PROJECT_ROOT / args.source)
    for name in args.animations:
        if name not in animations:
            raise SystemExit(f"no animation '{name}'; source has {sorted(animations)}")

    selected: list[tuple[float, ...]] = []
    meta: list[dict] = []
    for name in args.animations:
        rects = animations[name]["frames"]
        meta.append({
            "name": name,
            "loop": animations[name]["loop"],
            "speed": animations[name]["speed"],
            "first": len(selected),
            "count": len(rects),
        })
        selected.extend(rects)

    src_w, src_h = int(selected[0][2]), int(selected[0][3])
    for rect in selected:
        if (int(rect[2]), int(rect[3])) != (src_w, src_h):
            raise SystemExit(f"frames are not uniform: {rect[2]}x{rect[3]} vs {src_w}x{src_h}")

    fw = args.frame_size
    fh = max(4, int(round(src_h * fw / src_w / 4)) * 4)

    n = len(selected)
    max_cols = max(1, min(n, MAX_ATLAS_SIDE // fw))
    cols = min(range(1, max_cols + 1),
               key=lambda c: (c * math.ceil(n / c), abs(c * fw - math.ceil(n / c) * fh)))
    rows = math.ceil(n / cols)
    if rows * fh > MAX_ATLAS_SIDE:
        raise SystemExit(f"atlas would be {cols * fw}x{rows * fh}, over {MAX_ATLAS_SIDE}")

    sheet = Image.open(sheet_path).convert("RGBA")
    atlas = Image.new("RGBA", (cols * fw, rows * fh), (0, 0, 0, 0))
    placements: list[tuple[int, int]] = []
    for index, rect in enumerate(selected):
        x, y, w, h = (int(v) for v in rect)
        frame = sheet.crop((x, y, x + w, y + h))
        if (fw, fh) != (w, h):
            frame = resize_premultiplied(frame, (fw, fh))
        cx, cy = (index % cols) * fw, (index // cols) * fh
        atlas.paste(frame, (cx, cy))
        placements.append((cx, cy))

    out_png = PROJECT_ROOT / args.out_png
    out_png.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(out_png, optimize=True)
    res_path = out_png.relative_to(PROJECT_ROOT).as_posix()
    Path(str(out_png) + ".import").write_text(IMPORT_TEMPLATE.format(res_path=res_path))

    # SpriteFrames, written with a path-only ext_resource; Godot fills in the uid.
    lines = [f'[gd_resource type="SpriteFrames" load_steps={n + 2} format=3]', ""]
    lines.append(f'[ext_resource type="Texture2D" path="res://{res_path}" id="1_sheet"]')
    lines.append("")
    for index, (cx, cy) in enumerate(placements):
        lines += [f'[sub_resource type="AtlasTexture" id="AtlasTexture_{index:03d}"]',
                  'atlas = ExtResource("1_sheet")',
                  f"region = Rect2({cx}, {cy}, {fw}, {fh})", ""]
    lines.append("[resource]")
    lines.append("animations = [")
    blocks = []
    for entry in meta:
        frames = ",\n".join(
            '{\n"duration": 1.0,\n"texture": SubResource("AtlasTexture_%03d")\n}' % (entry["first"] + i)
            for i in range(entry["count"]))
        blocks.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}'
                      % (frames, str(entry["loop"]).lower(), entry["name"], entry["speed"]))
    lines.append(", ".join(blocks) + "]")
    (PROJECT_ROOT / args.out_tres).write_text("\n".join(lines) + "\n")

    src_area = sheet.width * sheet.height
    print(f"{sheet_path.relative_to(PROJECT_ROOT)}  {sheet.width}x{sheet.height} ({src_area / 1e6:.2f} Mpx)")
    print(f"   kept {len(args.animations)} of {len(animations)} animations, {n} frames"
          f" at {fw}x{fh} (was {src_w}x{src_h})")
    print(f"   -> {res_path}  {cols * fw}x{rows * fh}"
          f" ({cols * fw * rows * fh / 1e6:.2f} Mpx, {src_area / (cols * fw * rows * fh):.1f}x less)")
    print(f"   -> {args.out_tres}")
    print(f"   the sprite drawing it needs scale x {src_w / fw:.6f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
