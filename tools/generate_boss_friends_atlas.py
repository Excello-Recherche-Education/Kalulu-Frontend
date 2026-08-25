#!/usr/bin/env python3
"""Generate the slim sprite atlases used by the boss minigame's animal friends.

The boss minigame decorates its scene with eight animal "friends" borrowed from
the other minigames. Instantiating those full character scenes pulled in every
source spritesheet they reference -- roughly 383 MB of imported texture data --
even though each friend is drawn small, and mostly static.

This script extracts only the frames the boss actually plays, downscales them to
the resolution they are displayed at, and packs them into one small atlas per
friend. Run it from the project root:

    python3 tools/generate_boss_friends_atlas.py

Outputs (both are committed):
    assets/minigames/boss/friends/<friend>.png[.import]

The matching SpriteFrames resources are built by tools/build_boss_friends.gd.
"""

from __future__ import annotations

import json
import math
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
from PIL import Image

PROJECT_ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = PROJECT_ROOT / "assets" / "minigames" / "boss" / "friends"
MANIFEST = PROJECT_ROOT / "tools" / "boss_friends_manifest.json"
MEASURED = PROJECT_ROOT / "tools" / "boss_friends_measured.json"

# Godot chokes on very large textures on old GPUs; keep every atlas well under
# the 4096 px limit that the oldest supported Android devices guarantee.
MAX_ATLAS_SIDE = 4096

# The friends are drawn at `display_scale` of their source frame size. Store them
# at 1.2x that, which is exactly what the canvas can stretch to: `canvas_items`
# on a 3840x2160 display scales the 2560x1800 canvas by min(1.5, 1.2) = 1.2,
# limited by height. So the frames are 1:1 at the largest resolution the game can
# reach, and gently minified below it. Never upscale past the source.
RESOLUTION_HEADROOM = 1.2


@dataclass
class Friend:
    """One animal friend of the boss minigame.

    `animations` maps an animation name in the *source* SpriteFrames to the
    number of leading frames to keep. 1 means "this animation is only ever shown
    stopped on its first frame", which is true for every friend's idle pose.
    """

    name: str
    source_tres: str
    animations: dict[str, int]
    sprite_path: str
    note: str = ""
    display_scale: float = 0.0
    frames: list[dict] = field(default_factory=list)


# sprite_path names the node inside the animal scene that the boss actually
# shows, so tools/measure_boss_friends.tscn can report the scale it is drawn at.
FRIENDS: list[Friend] = [
    Friend(
        "monkey",
        "sources/minigames/monkeys/monkey_animations.tres",
        {"idle": 0},
        "AnimatedSprite2D",
        "idle_boss() stops on frame 0; victory_boss() replays idle in full",
    ),
    Friend(
        "turtle",
        "sources/minigames/turtles/purple_turtle_animations.tres",
        {"swim": 0},
        "Body/AnimatedSprite2D",
        "boss picks the purple turtle explicitly; victory replays swim",
    ),
    Friend(
        "penguin",
        "sources/minigames/penguin/penguin_animations.tres",
        {"idle": 1, "happy": 0},
        "AnimatedSprite2D",
    ),
    Friend(
        "frog",
        "sources/minigames/frog/frog_animations.tres",
        {"idle_front": 0},
        "AnimatedSprite2D",
        "victory_boss() replays idle_front, so all frames are needed",
    ),
    Friend(
        "crab",
        "sources/minigames/crabs/crab/crab_animations.tres",
        {"idle": 1, "right": 0},
        "Body/AnimatedSprite2D",
    ),
    Friend(
        "parakeet",
        "sources/minigames/parakeets/green_parakeet_animations.tres",
        {"idle_front": 1, "happy": 0},
        "AnimatedSprite2D",
        "idle_boss() sets color = GREEN, so the green sheet is the one shown",
    ),
    Friend(
        "ant",
        "sources/minigames/ants/ant_animations.tres",
        {"idle": 1, "success": 0},
        "AnimatedSprite2D",
    ),
    Friend(
        "jellyfish",
        "sources/minigames/jellyfish/pink_jellyfish_animations_body.tres",
        {"idle": 1},
        "SpriteControl/AnimatedSprite2D_Body",
        "boss mode hides the arms layer and never plays the body, so 1 frame",
    ),
]

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


def parse_sprite_frames(tres_path: Path) -> tuple[Path, dict[str, dict]]:
    """Return (source png path, {anim_name: {frames, loop, speed}})."""
    text = tres_path.read_text()

    # ext_resource attribute order varies; capture path and id independently.
    ext: dict[str, str] = {}
    for block in re.findall(r"\[ext_resource[^\]]*\]", text):
        if 'type="Texture2D"' not in block:
            continue
        path_m = re.search(r'path="res://([^"]+)"', block)
        # match id="..." but not the uid="..." that precedes it
        id_m = re.search(r'(?:^|\s)id="([^"]+)"', block)
        if path_m and id_m:
            ext[id_m.group(1)] = path_m.group(1)

    regions: dict[str, tuple[str, tuple[float, ...]]] = {}
    for m in re.finditer(
        r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\s*'
        r'atlas = ExtResource\("([^"]+)"\)\s*'
        r"region = Rect2\(([^)]*)\)",
        text,
    ):
        sub_id, atlas_id, rect = m.groups()
        regions[sub_id] = (atlas_id, tuple(float(v) for v in rect.split(",")))

    anims: dict[str, dict] = {}
    for m in re.finditer(
        r'\{\s*"frames": \[(.*?)\],\s*"loop": (\w+),\s*"name": &"([^"]+)",\s*"speed": ([0-9.]+)\s*\}',
        text,
        re.S,
    ):
        blob, loop, name, speed = m.groups()
        ids = re.findall(r'SubResource\("([^"]+)"\)', blob)
        anims[name] = {
            "frames": [regions[i][1] for i in ids],
            "loop": loop == "true",
            "speed": float(speed),
        }

    atlas_ids = {atlas_id for atlas_id, _ in regions.values()}
    if len(atlas_ids) != 1:
        # Every sheet we touch uses a single source texture; bail out loudly
        # rather than silently packing frames from the wrong image.
        raise SystemExit(f"{tres_path}: expected 1 source texture, found {sorted(atlas_ids)}")

    return PROJECT_ROOT / ext[next(iter(atlas_ids))], anims


def resize_premultiplied(img: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Downscale RGBA without letting transparent pixels bleed dark halos in."""
    arr = np.asarray(img, dtype=np.float32) / 255.0
    alpha = arr[..., 3:4]
    arr[..., :3] *= alpha
    premul = Image.fromarray((arr * 255.0 + 0.5).astype("uint8"), "RGBA")
    out = premul.resize(size, Image.LANCZOS)
    arr = np.asarray(out, dtype=np.float32) / 255.0
    alpha = arr[..., 3:4]
    with np.errstate(divide="ignore", invalid="ignore"):
        arr[..., :3] = np.where(alpha > 0.0, arr[..., :3] / np.maximum(alpha, 1e-6), 0.0)
    arr = arr.clip(0.0, 1.0)
    return Image.fromarray((arr * 255.0 + 0.5).astype("uint8"), "RGBA")


def round4(v: float) -> int:
    """Round up to a multiple of 4 so ETC2/ASTC blocks line up with frames."""
    return max(4, int(math.ceil(v / 4.0)) * 4)


def build(friend: Friend) -> dict:
    src_png, anims = parse_sprite_frames(PROJECT_ROOT / friend.source_tres)
    sheet = Image.open(src_png).convert("RGBA")

    selected: list[tuple[str, tuple[float, ...]]] = []
    meta: list[dict] = []
    for anim_name, keep in friend.animations.items():
        if anim_name not in anims:
            raise SystemExit(f"{friend.name}: animation '{anim_name}' missing from {friend.source_tres}")
        rects = anims[anim_name]["frames"]
        rects = rects if keep == 0 else rects[:keep]
        meta.append(
            {
                "name": anim_name,
                "loop": anims[anim_name]["loop"],
                "speed": anims[anim_name]["speed"],
                "first_index": len(selected),
                "count": len(rects),
            }
        )
        selected.extend((anim_name, r) for r in rects)

    src_w = int(selected[0][1][2])
    src_h = int(selected[0][1][3])
    for _, r in selected:
        if int(r[2]) != src_w or int(r[3]) != src_h:
            raise SystemExit(f"{friend.name}: frames are not uniform ({r[2]}x{r[3]} vs {src_w}x{src_h})")

    fw = min(src_w, round4(src_w * friend.display_scale * RESOLUTION_HEADROOM))
    fh = min(src_h, round4(src_h * friend.display_scale * RESOLUTION_HEADROOM))

    n = len(selected)
    # Pick the grid that wastes the fewest slots rather than just filling rows:
    # eight 608 px frames cap at six columns, and 6x2 leaves four empty slots --
    # a third of the atlas -- where 4x2 is exact.
    max_cols = max(1, min(n, MAX_ATLAS_SIDE // fw))
    # Only grids that fit both ways: a prime frame count would otherwise pick a
    # single column, which has the fewest wasted slots and an impossible height.
    candidates = [c for c in range(1, max_cols + 1) if math.ceil(n / c) * fh <= MAX_ATLAS_SIDE]
    if not candidates:
        raise SystemExit(f"{friend.name}: no {fw}x{fh} grid for {n} frames fits {MAX_ATLAS_SIDE}")
    cols = min(
        candidates,
        key=lambda c: (c * math.ceil(n / c), abs(c * fw - math.ceil(n / c) * fh)),
    )
    rows = math.ceil(n / cols)

    atlas = Image.new("RGBA", (cols * fw, rows * fh), (0, 0, 0, 0))
    placements: list[list[int]] = []
    for i, (_, rect) in enumerate(selected):
        x, y, w, h = (int(v) for v in rect)
        frame = sheet.crop((x, y, x + w, y + h))
        if (fw, fh) != (w, h):
            frame = resize_premultiplied(frame, (fw, fh))
        cx, cy = (i % cols) * fw, (i // cols) * fh
        atlas.paste(frame, (cx, cy))
        placements.append([cx, cy, fw, fh])

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    png_path = OUT_DIR / f"{friend.name}.png"
    atlas.save(png_path, optimize=True)

    res_path = png_path.relative_to(PROJECT_ROOT).as_posix()
    (OUT_DIR / f"{friend.name}.png.import").write_text(IMPORT_TEMPLATE.format(res_path=res_path))

    src_px = sum(int(r[2]) * int(r[3]) for _, r in selected)
    return {
        "name": friend.name,
        "texture": f"res://{res_path}",
        "source_tres": friend.source_tres,
        "source_png": src_png.relative_to(PROJECT_ROOT).as_posix(),
        "note": friend.note,
        "frame_size": [fw, fh],
        "source_frame_size": [src_w, src_h],
        "display_scale": friend.display_scale,
        "atlas_size": [cols * fw, rows * fh],
        "regions": placements,
        "animations": meta,
        "kept_pixels": n * fw * fh,
        "source_pixels_full_sheet": sheet.width * sheet.height,
        "source_pixels_kept_frames": src_px,
    }


def load_display_scales() -> None:
    if not MEASURED.exists():
        raise SystemExit(
            f"missing {MEASURED.relative_to(PROJECT_ROOT)} -- run first:\n"
            "  godot --headless --path . res://tools/measure_boss_friends.tscn"
        )
    measured = json.loads(MEASURED.read_text())
    for friend in FRIENDS:
        entries = measured.get(friend.name, [])
        match = next((e for e in entries if e["path"] == friend.sprite_path), None)
        if match is None:
            raise SystemExit(f"{friend.name}: '{friend.sprite_path}' not found in the measurement")
        sx, sy = match["scale"]
        # The atlases keep a single frame size, so size for the larger axis.
        friend.display_scale = max(abs(sx), abs(sy))


def main() -> int:
    load_display_scales()
    manifest = []
    total_new = 0
    total_old = 0
    seen_sheets: set[str] = set()
    for friend in FRIENDS:
        entry = build(friend)
        manifest.append(entry)
        total_new += entry["kept_pixels"]
        if entry["source_png"] not in seen_sheets:
            seen_sheets.add(entry["source_png"])
            total_old += entry["source_pixels_full_sheet"]
        print(
            f"{entry['name']:<10} {entry['frame_size'][0]:>4}x{entry['frame_size'][1]:<4}"
            f" x{sum(a['count'] for a in entry['animations']):<3} frames"
            f" -> atlas {entry['atlas_size'][0]}x{entry['atlas_size'][1]}"
            f"  ({entry['kept_pixels'] / 1e6:5.2f} Mpx"
            f" vs {entry['source_pixels_full_sheet'] / 1e6:6.2f} Mpx full sheet)"
        )

    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n")
    print(
        f"\ntotal {total_new / 1e6:.2f} Mpx across {len(manifest)} atlases"
        f"  (was {total_old / 1e6:.2f} Mpx of source sheets, {total_old / max(total_new, 1):.1f}x)"
    )
    print(f"manifest -> {MANIFEST.relative_to(PROJECT_ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
