extends Node

## Brings up the parakeets minigame far enough to confirm its parakeets still get
## their frames now that the colour is set before they enter the tree, and that
## nothing loads a sheet for a colour the round is not using.

func _ready() -> void:
	var scene: PackedScene = load("res://sources/minigames/parakeets/parakeets_minigame.tscn")
	if not scene:
		print("SMOKE FAIL: parakeets_minigame.tscn did not load")
		get_tree().quit(1)
		return
	var minigame: Node = scene.instantiate()
	add_child(minigame)
	for _i: int in range(30):
		await get_tree().process_frame

	var parakeets: Array = minigame.parakeets if "parakeets" in minigame else []
	print("SMOKE parakeets=%d" % parakeets.size())
	var sheets: Dictionary = {}
	var without_frames: int = 0
	for parakeet: Node in parakeets:
		var sprite: AnimatedSprite2D = parakeet.get_node("AnimatedSprite2D")
		if not sprite.sprite_frames:
			without_frames += 1
			continue
		var texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
		if texture is AtlasTexture and (texture as AtlasTexture).atlas:
			sheets[(texture as AtlasTexture).atlas.resource_path.get_file()] = true
		var feathers: AnimatedSprite2D = parakeet.get_node("AnimatedSprite2D_Feathers")
		if not feathers.sprite_frames:
			without_frames += 1
	print("SMOKE parakeets_without_frames=%d" % without_frames)
	print("SMOKE sheets_in_use=%s" % [sheets.keys()])
	print("SMOKE OK" if parakeets.size() > 0 and without_frames == 0 else "SMOKE FAIL")
	get_tree().quit()
