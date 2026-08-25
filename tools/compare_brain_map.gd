extends Node

## Renders brain.png through a TextureRect configured exactly as the Brain node in
## brain.tscn is, so a change to its import settings can be judged at the size the
## player actually sees rather than at 1:1.
##
##   godot --path <project> --resolution 320x200 res://tools/compare_brain_map.tscn -- before

const CANVAS: Vector2i = Vector2i(2560, 1800)


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var label: String = args[0] if args.size() > 0 else "run"

	var texture: Texture2D = load("res://assets/brain/brain.png")

	var viewport: SubViewport = SubViewport.new()
	viewport.size = CANVAS
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	# Mirrors brain.tscn: offsets 2560x1800, expand_mode 2, stretch_mode 5.
	var rect: TextureRect = TextureRect.new()
	rect.texture = texture
	rect.offset_right = 2560.0
	rect.offset_bottom = 1800.0
	rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	viewport.add_child(rect)

	for _i: int in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	print("SOURCE texture=%dx%d   drawn rect=%s" % [
		texture.get_width(), texture.get_height(), rect.size])
	var image: Image = viewport.get_texture().get_image()
	var path: String = "user://brainmap_%s.png" % label
	image.save_png(path)
	print("wrote ", ProjectSettings.globalize_path(path))
	get_tree().quit()
