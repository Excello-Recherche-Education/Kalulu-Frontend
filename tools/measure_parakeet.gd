extends Node2D

## Reports the size a parakeet is actually drawn at in its own minigame, which is
## what decides how much resolution its spritesheets need. Instantiated the way
## parakeets_minigame.gd does it: add_child, then set colour -- it never touches
## scale, so the scene's own defaults are what apply.
##
##   godot --headless --path <project> res://tools/measure_parakeet.tscn

const PARAKEET_SCENE_PATH: String = "res://sources/minigames/parakeets/parakeet.tscn"


func _ready() -> void:
	var parakeet: Node = (load(PARAKEET_SCENE_PATH) as PackedScene).instantiate()
	add_child(parakeet)
	parakeet.color = 1  # Colors.GREEN, as a round that does not draw red
	parakeet.uppercase = true

	for _i: int in range(5):
		await get_tree().process_frame

	for node: Node in _descendants(parakeet):
		if not node is AnimatedSprite2D:
			continue
		var sprite: AnimatedSprite2D = node
		if not sprite.sprite_frames:
			continue
		var texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
		if not texture:
			continue
		var transform: Transform2D = sprite.get_global_transform()
		var frame: Vector2 = texture.get_size()
		var atlas_path: String = ""
		if texture is AtlasTexture and (texture as AtlasTexture).atlas:
			atlas_path = (texture as AtlasTexture).atlas.resource_path
		print("SPRITE %-28s visible=%s frame=%.0fx%.0f scale=%.4f drawn=%.1f px offset=%s centered=%s"
			% [parakeet.get_path_to(node), sprite.is_visible_in_tree(), frame.x, frame.y,
			   transform.get_scale().x, frame.x * transform.get_scale().x,
			   sprite.offset, sprite.centered])
		print("       sheet=%s  animation=%s frames=%d" % [
			atlas_path, sprite.animation, sprite.sprite_frames.get_frame_count(sprite.animation)])
	get_tree().quit()


func _descendants(node: Node) -> Array:
	var out: Array = []
	for child: Node in node.get_children():
		out.append(child)
		out.append_array(_descendants(child))
	return out
