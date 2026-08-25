extends Node2D

## Fireworks only exist after a win, so a static audit never sees them. This
## plays them and reports the resolution stored against the size drawn.
##   godot --path <project> --resolution 320x200 res://tools/measure_fireworks.tscn

func _ready() -> void:
	var fireworks: Node = (load("res://sources/utils/fx/fireworks.tscn") as PackedScene).instantiate()
	add_child(fireworks)
	fireworks.play()
	for _i: int in range(40):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var reported: Dictionary = {}
	for node: Node in _all(fireworks):
		var item: CanvasItem = node as CanvasItem
		if not item or not item.is_visible_in_tree():
			continue
		var texture: Texture2D = null
		if node is Sprite2D: texture = (node as Sprite2D).texture
		elif node is AnimatedSprite2D:
			var a: AnimatedSprite2D = node
			if a.sprite_frames and a.sprite_frames.has_animation(a.animation):
				texture = a.sprite_frames.get_frame_texture(a.animation, 0)
		if not texture: continue
		var source: Texture2D = texture
		var region: Vector2 = texture.get_size()
		if texture is AtlasTexture and (texture as AtlasTexture).atlas:
			source = (texture as AtlasTexture).atlas
		if reported.has(source.resource_path): continue
		reported[source.resource_path] = true
		var scale: Vector2 = item.get_global_transform().get_scale().abs()
		print("FIREWORK %-24s sheet %.0fx%.0f (%.2f Mpx)  frame %.0fx%.0f  scale %.3f -> drawn %.0fx%.0f" % [
			source.resource_path.get_file(), source.get_width(), source.get_height(),
			source.get_width() * source.get_height() / 1e6,
			region.x, region.y, scale.x, region.x * scale.x, region.y * scale.y])
	print("FIREWORK sprites alive: %d" % _all(fireworks).size())
	get_tree().quit()


func _all(node: Node) -> Array:
	var out: Array = []
	for c: Node in node.get_children():
		out.append(c); out.append_array(_all(c))
	return out
