extends Node

## Renders a parakeet at the size its minigame actually draws it, and reports the
## texture memory a round costs, so downscaling its spritesheets can be judged on
## both counts. Run WITHOUT --headless.
##
##   godot --path <project> --resolution 320x200 res://tools/compare_parakeet.tscn -- before

const PARAKEET_SCENE_PATH: String = "res://sources/minigames/parakeets/parakeet.tscn"
const VIEWPORT: Vector2i = Vector2i(900, 900)

# GREEN, so the round draws a colour other than the one parakeet.tscn defaults to.
const ROUND_COLOUR: int = 1


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var label: String = args[0] if args.size() > 0 else "run"

	for _i: int in range(10):
		await get_tree().process_frame
	var baseline: float = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)

	var viewport: SubViewport = SubViewport.new()
	viewport.size = VIEWPORT
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	# Exactly how parakeets_minigame.gd builds one: add, then set the colour.
	var parakeet: Node = (load(PARAKEET_SCENE_PATH) as PackedScene).instantiate()
	viewport.add_child(parakeet)
	parakeet.color = ROUND_COLOUR
	parakeet.uppercase = true
	parakeet.position = Vector2(450, 500)

	for _i: int in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var after: float = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)

	var sprite: AnimatedSprite2D = parakeet.get_node("AnimatedSprite2D")
	print("PARAKEET %s: round_texture_mem_mb=%.1f  frame=%.0fpx  scale=%.4f  drawn=%.1fpx" % [
		label, (after - baseline) / 1048576.0,
		sprite.sprite_frames.get_frame_texture(sprite.animation, 0).get_size().x,
		sprite.get_global_transform().get_scale().x,
		sprite.sprite_frames.get_frame_texture(sprite.animation, 0).get_size().x
			* sprite.get_global_transform().get_scale().x])

	var image: Image = viewport.get_texture().get_image()
	image.save_png("user://parakeet_%s.png" % label)
	print("wrote ", ProjectSettings.globalize_path("user://parakeet_%s.png" % label))
	get_tree().quit()
