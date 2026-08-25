extends Node

## Renders the turtles minigame's decorative crab the way it used to be drawn --
## straight off the full crab spritesheet at scale 0.3 -- against the extracted
## atlas at its compensating scale, and writes both for pixel-diffing.
##
##   godot --path <project> --resolution 320x200 res://tools/compare_crab_decor.tscn

const SHEET_PATH: String = "res://assets/minigames/crabs/graphic/crab_spritesheet.png"
const EXTRACTED_PATH: String = "res://sources/minigames/turtles/crab_decor_animations.tres"

const OLD_SCALE: float = 0.3
const NEW_SCALE: float = 0.8333334
const OLD_FRAME: float = 800.0

## The rows each animation occupied in the original sheet.
const ROWS: Dictionary = {"idle": 800, "idle_claws": 3200, "victory_claws": 4000}
const FRAMES_PER_ANIMATION: int = 8
const CELL: int = 260


func _ready() -> void:
	var extracted: SpriteFrames = load(EXTRACTED_PATH)
	var sheet: Texture2D = load(SHEET_PATH)

	for pass_name: String in ["old", "new"]:
		var viewport: SubViewport = SubViewport.new()
		viewport.size = Vector2i(CELL * FRAMES_PER_ANIMATION, CELL * ROWS.size())
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)

		var row: int = 0
		for animation: String in ROWS:
			for frame: int in FRAMES_PER_ANIMATION:
				var sprite: Sprite2D = Sprite2D.new()
				sprite.centered = false
				sprite.position = Vector2(frame * CELL, row * CELL)
				if pass_name == "old":
					var atlas: AtlasTexture = AtlasTexture.new()
					atlas.atlas = sheet
					atlas.region = Rect2(frame * OLD_FRAME, ROWS[animation], OLD_FRAME, OLD_FRAME)
					sprite.texture = atlas
					sprite.scale = Vector2(OLD_SCALE, OLD_SCALE)
				else:
					sprite.texture = extracted.get_frame_texture(StringName(animation), frame)
					sprite.scale = Vector2(NEW_SCALE, NEW_SCALE)
				viewport.add_child(sprite)
			row += 1

		for _i: int in range(8):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("user://crab_decor_%s.png" % pass_name)
		print("wrote ", ProjectSettings.globalize_path("user://crab_decor_%s.png" % pass_name))
		viewport.queue_free()

	get_tree().quit()
