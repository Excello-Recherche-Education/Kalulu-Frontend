extends Node

## Reports the real texture VRAM a single resource costs, to check import
## settings against what the arithmetic predicts. Run WITHOUT --headless:
##   godot --path <project> --resolution 320x200 res://tools/probe_texture_vram.tscn -- <res://path>

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		print("PROBE usage: -- res://path/to/resource")
		get_tree().quit(1)
		return

	for _i: int in range(10):
		await get_tree().process_frame
	var baseline: float = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)

	var start: int = Time.get_ticks_msec()
	var resource: Resource = load(args[0])
	var load_ms: int = Time.get_ticks_msec() - start
	if not resource:
		print("PROBE FAIL could not load ", args[0])
		get_tree().quit(1)
		return

	# A texture only reaches VRAM once something draws it.
	# Optional second arg: a CanvasItem.TextureFilter to force, so the project
	# default (rendering/textures/canvas_textures/default_texture_filter) can be
	# isolated from the texture's own import settings.
	var filter: int = int(args[1]) if args.size() > 1 else -1

	var holder: Node = null
	if resource is Texture2D:
		var rect: TextureRect = TextureRect.new()
		rect.texture = resource
		holder = rect
	elif resource is SpriteFrames:
		var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
		sprite.sprite_frames = resource
		holder = sprite
	elif resource is PackedScene:
		holder = (resource as PackedScene).instantiate()
	if holder:
		if filter >= 0 and holder is CanvasItem:
			(holder as CanvasItem).texture_filter = filter as CanvasItem.TextureFilter
		add_child(holder)

	for _i: int in range(20):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var after: float = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)

	print("PROBE %s filter=%d -> texture_mem_delta_mb=%.1f load_ms=%d" % [
		args[0], filter, (after - baseline) / 1048576.0, load_ms])
	get_tree().quit()
