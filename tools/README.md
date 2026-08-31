# tools

Offline tooling for the texture-memory work. None of it is part of the game;
`export_presets.cfg` excludes this folder from builds.

## Regenerating the boss friends

The boss minigame's decorative friends are purpose-built atlases, not the animal
scenes of the other minigames. Three steps, **in this order**:

```bash
godot --headless --path . res://tools/measure_boss_friends.tscn
python3 tools/generate_boss_friends_atlas.py
godot --headless --path . res://tools/build_boss_friends.tscn
```

The order is not optional. `measure_boss_friends` reports the size each friend is
drawn at by instantiating the animal scenes the way the boss used to; the
generator sizes the atlases from that. Skipping the measurement after any change
to an animal scene sizes the atlases from a stale scale -- when the parakeet
sheets went from 800 px frames to 384, a regenerate without re-measuring made the
boss parakeet half the size it should be.

`boss_friends_measured.json` and `boss_friends_manifest.json` are the outputs of
steps one and two, committed so the result is reproducible.

## Reducing a spritesheet

Two shapes, depending on whether the sheet's grid is fully used:

- **`downscale_spritesheet.py`** scales a sheet and every AtlasTexture region that
  slices it by one factor. The slicing is preserved exactly, so no animation
  changes. Right when the grid is full -- the parakeets.
- **`extract_animation_atlas.py`** copies chosen animations into a new atlas and
  repacks them. Right when animations are unreachable, or when slots are empty --
  the turtles' decorative crab used three of six animations, and the crab and
  jellyfish sheets were leaving a third of their grids empty.

Neither touches scenes. Both print the scale and offset compensation the sprites
need, because a smaller frame drawn at the same scale is a smaller sprite. The
exception is anything under `SpriteControl`, which divides by the actual texture
size at runtime and so needs no compensation.

`process/size_limit` in the import options looks like it should do this job. It
does not: it shrinks the image and leaves every hardcoded region pointing at the
wrong pixels, with nothing to complain until the frames are visibly wrong. It is
only safe on a texture nothing slices.

## Measuring

- **`audit_drawn_scale`** — for every texture a scene draws, the resolution stored
  against the size it is drawn at. This is the one that finds waste. Pass `start`
  to call `_start()` on the scene, for minigames that spawn characters there, and
  `name=value` to set a property first, for characters that get their frames from
  a colour assigned at runtime.
- **`probe_texture_vram`** — what one resource costs and how long it takes to load.
- **`compare_texture_quality`** — 1:1 crops before and after an import change, for
  pixel-diffing. Edit `SUBJECTS` for the texture in question. Worth running: it is
  what caught VRAM compression putting visible 4x4 blocking on Kalulu's paws.

Two traps. These need a real renderer -- under `--headless` the dummy one reports
no texture memory at all -- and each variant has to run in its own process, or the
resource cache of one colours the next.

A caution on what measuring tells you: a character that scales itself at random
has no single drawn size. The jellyfish picks `SCALES[colour]` times up to 1.2, so
auditing one instance can report 458 px for something that reaches 720. Derive the
maximum from the code, and use the audit to confirm it.
