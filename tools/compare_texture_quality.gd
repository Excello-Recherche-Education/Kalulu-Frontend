extends Node

## Renders 1:1 crops of the textures whose import settings are being changed, so
## before/after can be pixel-diffed. 1:1 is the strict case: block compression
## artifacts are most visible when no minification hides them.
##
## Must run WITHOUT --headless.
##   godot --path <project> --resolution 320x200 res://tools/compare_texture_quality.tscn -- before

const CROP_SIZE: Vector2i = Vector2i(1000, 800)
# Subjects: output name, resource, and the region of it to show at 1:1.
# Regions picked for the highest edge density in each sheet, since that is where
# block compression does its damage -- a flat region would pass trivially.
const SUBJECTS: Array = [
	["brain", "res://assets/brain/brain.png", Rect2(2500, 2800, 1000, 800)],
	["brain2", "res://assets/brain/brain.png", Rect2(1000, 0, 1000, 800)],
	# A frame of the reading Kalulu at full detail; frames are 625x1250.
	["kalulu_read", "res://assets/kalulu/kalulu_sheet_read_book.png", Rect2(1875, 5000, 625, 1250)],
]


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var label: String = args[0] if args.size() > 0 else "run"

	for subject: Array in SUBJECTS:
		var name: String = subject[0]
		var texture: Texture2D = load(subject[1])
		var region: Rect2 = subject[2]

		var viewport: SubViewport = SubViewport.new()
		viewport.size = Vector2i(int(region.size.x), int(region.size.y))
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)

		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = texture
		sprite.region_enabled = true
		sprite.region_rect = region
		sprite.centered = false
		# Nearest-neighbour, so what lands in the PNG is the stored texel and not
		# a filtering artefact of our own making.
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		viewport.add_child(sprite)

		for _i: int in range(6):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw

		var image: Image = viewport.get_texture().get_image()
		var path: String = "user://quality_%s_%s.png" % [name, label]
		image.save_png(path)
		print("wrote ", ProjectSettings.globalize_path(path))
		viewport.queue_free()

	get_tree().quit()
