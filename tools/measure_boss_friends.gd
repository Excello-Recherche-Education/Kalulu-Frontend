extends Node2D

## Offline measurement tool for the boss minigame's animal friends.
##
## Instantiates the eight animal scenes exactly the way boss_minigame.gd used
## to, lets layout and _ready() settle, and dumps the resulting global
## transform of every sprite that is actually visible. That output is the
## ground truth tools/generate_boss_friends_atlas.py and boss_friends.tscn are
## built from -- the animals nest Controls with their own pivots and scales
## (and the jellyfish is resized at runtime by SpriteControl), so composing
## those transforms by hand is not reliable.
##
## Run with:
##   godot --headless --path <project> res://tools/measure_boss_friends.tscn

const OUTPUT_PATH: String = "res://tools/boss_friends_measured.json"

const MONKEY_SCENE_PATH: String = "res://sources/minigames/monkeys/monkey.tscn"
const TURTLE_SCENE_PATH: String = "res://sources/minigames/turtles/turtle.tscn"
const TURTLE_FRIEND_SPRITE_FRAMES_PATH: String = "res://sources/minigames/turtles/purple_turtle_animations.tres"
const PENGUIN_SCENE_PATH: String = "res://sources/minigames/penguin/penguin.tscn"
const FROG_SCENE_PATH: String = "res://sources/minigames/frog/frog.tscn"
const CRAB_SCENE_PATH: String = "res://sources/minigames/crabs/crab/crab.tscn"
const PARAKEET_SCENE_PATH: String = "res://sources/minigames/parakeets/parakeet.tscn"
const ANT_SCENE_PATH: String = "res://sources/minigames/ants/ant.tscn"
const JELLYFISH_SCENE_PATH: String = "res://sources/minigames/jellyfish/jellyfish.tscn"


func _ready() -> void:
	# Mirror the two containers of boss_minigame.tscn, including their offsets,
	# so every transform we read back is already relative to GameRoot.
	var friends: Node2D = Node2D.new()
	friends.name = "Friends"
	friends.position = Vector2(1676, 1280)
	add_child(friends)

	var behind: Node2D = Node2D.new()
	behind.name = "Friends_Behind_Frame"
	add_child(behind)

	var roots: Dictionary = {}

	var monkey: Node = (load(MONKEY_SCENE_PATH) as PackedScene).instantiate()
	monkey.position = Vector2(125, 62)
	monkey.scale = Vector2(0.7, 0.7)
	friends.add_child(monkey)
	roots["monkey"] = monkey

	var turtle: Node = (load(TURTLE_SCENE_PATH) as PackedScene).instantiate()
	turtle.position = Vector2(-220, 120)
	turtle.rotation = 1.5707964
	turtle.scale = Vector2(0.18, 0.18)
	friends.add_child(turtle)
	turtle.sprite_frames = load(TURTLE_FRIEND_SPRITE_FRAMES_PATH)
	roots["turtle"] = turtle

	var penguin: Node = (load(PENGUIN_SCENE_PATH) as PackedScene).instantiate()
	penguin.position = Vector2(28, 114)
	penguin.scale = Vector2(0.3, 0.3)
	friends.add_child(penguin)
	roots["penguin"] = penguin

	var frog: Node = (load(FROG_SCENE_PATH) as PackedScene).instantiate()
	frog.offset_left = -43.999985
	frog.offset_top = 112.0
	frog.offset_right = -43.999985
	frog.offset_bottom = 112.0
	frog.scale = Vector2(0.4, 0.4)
	friends.add_child(frog)
	roots["frog"] = frog

	var crab: Node = (load(CRAB_SCENE_PATH) as PackedScene).instantiate()
	crab.offset_left = -220.0
	crab.offset_top = 32.0
	crab.offset_right = 148.0
	crab.offset_bottom = 352.0
	crab.scale = Vector2(0.45, 0.45)
	friends.add_child(crab)
	roots["crab"] = crab

	var parakeet: Node = (load(PARAKEET_SCENE_PATH) as PackedScene).instantiate()
	parakeet.position = Vector2(124, -103)
	parakeet.scale = Vector2(0.09, 0.09)
	friends.add_child(parakeet)
	roots["parakeet"] = parakeet

	var ant: Node = (load(ANT_SCENE_PATH) as PackedScene).instantiate()
	ant.position = Vector2(228, 132)
	ant.scale = Vector2(0.17, 0.17)
	friends.add_child(ant)
	roots["ant"] = ant

	var jellyfish: Node = (load(JELLYFISH_SCENE_PATH) as PackedScene).instantiate()
	jellyfish.offset_left = 1449.0001
	jellyfish.offset_top = 1301.0001
	jellyfish.offset_right = 1849.0001
	jellyfish.offset_bottom = 1701.0001
	jellyfish.scale = Vector2(0.45, 0.45)
	jellyfish.boss = true
	behind.add_child(jellyfish)
	roots["jellyfish"] = jellyfish

	# Let _ready(), Control layout and SpriteControl's resize all settle.
	for _i: int in range(5):
		await get_tree().process_frame

	for name: String in roots:
		roots[name].idle_boss()

	for _i: int in range(3):
		await get_tree().process_frame

	var result: Dictionary = {}
	for name: String in roots:
		result[name] = _measure(roots[name] as Node)

	var file: FileAccess = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	print("wrote ", OUTPUT_PATH)
	get_tree().quit()


func _measure(root: Node) -> Array:
	var out: Array = []
	for node: Node in _descendants(root):
		var frame_size: Vector2 = Vector2.ZERO
		var animation: String = ""
		if node is AnimatedSprite2D:
			var animated: AnimatedSprite2D = node
			if not animated.sprite_frames:
				continue
			animation = String(animated.animation)
			var texture: Texture2D = animated.sprite_frames.get_frame_texture(animated.animation, 0)
			if not texture:
				continue
			frame_size = texture.get_size()
		elif node is Sprite2D:
			var sprite: Sprite2D = node
			if not sprite.texture:
				continue
			frame_size = sprite.texture.get_size()
		else:
			continue

		var item: CanvasItem = node
		if not item.is_visible_in_tree():
			continue

		var transform: Transform2D = item.get_global_transform()
		out.append({
			"path": String(root.get_path_to(node)),
			"type": node.get_class(),
			"animation": animation,
			"frame_size": [frame_size.x, frame_size.y],
			"position": [transform.origin.x, transform.origin.y],
			"rotation": transform.get_rotation(),
			"scale": [transform.get_scale().x, transform.get_scale().y],
			"skew": transform.get_skew(),
			"offset": [node.offset.x, node.offset.y],
			"centered": node.centered,
			"flip_h": node.flip_h,
			"flip_v": node.flip_v,
			"z_index": item.z_index,
			"modulate": item.modulate.to_html(),
			"self_modulate": item.self_modulate.to_html(),
			"texture": _texture_path(node),
		})
	return out


func _texture_path(node: Node) -> String:
	if node is AnimatedSprite2D:
		var animated: AnimatedSprite2D = node
		var texture: Texture2D = animated.sprite_frames.get_frame_texture(animated.animation, 0)
		if texture is AtlasTexture:
			var atlas: AtlasTexture = texture
			return atlas.atlas.resource_path if atlas.atlas else ""
		return texture.resource_path
	var sprite: Sprite2D = node
	return sprite.texture.resource_path if sprite.texture else ""


func _descendants(node: Node) -> Array:
	var out: Array = []
	for child: Node in node.get_children():
		out.append(child)
		out.append_array(_descendants(child))
	return out
