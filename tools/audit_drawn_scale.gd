extends Node

## Brings up a scene and reports, for every texture it draws, the resolution
## stored against the size it is actually drawn at. Oversampled textures are pure
## waste: memory paid for detail no screen ever shows.
##
## This is the measurement that has to come before any right-sizing, because
## nesting makes drawn size impossible to read off a scene file -- the crab's
## body sits under a Control at 0.24, and the jellyfish is resized at runtime.
##
##   godot --path <project> --resolution 320x200 res://tools/audit_drawn_scale.tscn -- <res://scene.tscn>

var _rows: Array = []
var _seen: Dictionary = {}


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: -- res://path/to/scene.tscn")
		get_tree().quit(1)
		return

	var scene: PackedScene = load(args[0])
	if not scene:
		print("AUDIT FAIL could not load ", args[0])
		get_tree().quit(1)
		return

	var baseline: float = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	var root: Node = scene.instantiate()
	add_child(root)
	# Long enough for staggered instantiation and any runtime resizing to settle.
	for _i: int in range(40):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var total: float = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) - baseline

	_walk(root, root)
	_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.waste > b.waste)

	print("\n=== %s ===" % args[0])
	print("total texture memory: %.1f MB\n" % (total / 1048576.0))
	print("%9s %11s %11s %7s  %s" % ["stored", "drawn", "wasted", "ratio", "texture / node"])
	var waste_total: float = 0.0
	for row: Dictionary in _rows:
		waste_total += row.waste
		print("%6.2f Mpx %7.2f Mpx %7.2f Mpx %6.2fx  %s" % [
			row.stored / 1e6, row.drawn / 1e6, row.waste / 1e6, row.ratio, row.name])
		print("%42s %s" % ["", row.node])
	print("\noversampling accounts for %.2f Mpx of the %.2f Mpx stored" % [
		waste_total / 1e6, _stored_total() / 1e6])
	get_tree().quit()


func _stored_total() -> float:
	var total: float = 0.0
	for row: Dictionary in _rows:
		total += row.stored
	return total


func _walk(node: Node, root: Node) -> void:
	for child: Node in node.get_children():
		_inspect(child, root)
		_walk(child, root)


func _inspect(node: Node, root: Node) -> void:
	var item: CanvasItem = node as CanvasItem
	if not item or not item.is_visible_in_tree():
		return

	var texture: Texture2D = null
	if node is AnimatedSprite2D:
		var animated: AnimatedSprite2D = node
		if animated.sprite_frames and animated.sprite_frames.has_animation(animated.animation):
			texture = animated.sprite_frames.get_frame_texture(animated.animation, 0)
	elif node is Sprite2D:
		texture = (node as Sprite2D).texture
	elif node is TextureRect:
		texture = (node as TextureRect).texture
	elif node is NinePatchRect:
		texture = (node as NinePatchRect).texture
	if not texture:
		return

	# An AtlasTexture costs its whole sheet, however small the region drawn.
	var source: Texture2D = texture
	var region: Vector2 = texture.get_size()
	if texture is AtlasTexture and (texture as AtlasTexture).atlas:
		source = (texture as AtlasTexture).atlas
	if source.resource_path.is_empty():
		return

	var scale: Vector2 = item.get_global_transform().get_scale()
	var drawn: Vector2 = region * scale.abs()
	# Charge each distinct sheet once, to the node that draws it largest.
	var stored: float = source.get_width() * source.get_height()
	var key: String = source.resource_path
	var drawn_area: float = drawn.x * drawn.y
	var ratio: float = (region.x * region.y) / maxf(drawn_area, 1.0)
	if _seen.has(key) and _rows[_seen[key]].drawn >= drawn_area:
		return
	var row: Dictionary = {
		"name": key.get_file(),
		"node": String(root.get_path_to(node)),
		"stored": stored,
		"drawn": drawn_area,
		"ratio": ratio,
		"waste": stored - stored / maxf(ratio, 1.0),
	}
	if _seen.has(key):
		_rows[_seen[key]] = row
	else:
		_seen[key] = _rows.size()
		_rows.append(row)
