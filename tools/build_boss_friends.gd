extends Node

## Builds the boss minigame's slim friend resources from the generated atlases.
##
## Consumes tools/boss_friends_manifest.json (written by
## generate_boss_friends_atlas.py) and tools/boss_friends_measured.json (written
## by measure_boss_friends.tscn) and emits, for each friend, a SpriteFrames
## holding only the frames the boss plays, plus the two scenes that replace the
## eight animal scenes the boss used to instantiate.
##
## Run with:
##   godot --headless --path <project> res://tools/build_boss_friends.tscn

const MANIFEST_PATH: String = "res://tools/boss_friends_manifest.json"
const MEASURED_PATH: String = "res://tools/boss_friends_measured.json"
const FRAMES_DIR: String = "res://sources/minigames/boss/friends"
const SCRIPT_PATH: String = "res://sources/minigames/boss/boss_friends.gd"
const FRONT_SCENE_PATH: String = "res://sources/minigames/boss/boss_friends.tscn"
const BEHIND_SCENE_PATH: String = "res://sources/minigames/boss/boss_friends_behind.tscn"
# Origins of the two containers in boss_minigame.tscn that the friends live
# under, so the measured global transforms become local ones.
const FRONT_ORIGIN: Vector2 = Vector2(1676, 1280)
const BEHIND_ORIGIN: Vector2 = Vector2.ZERO
# node name, friend key, node path inside the original animal scene. The order
# is the order the friends were added as children, which is their draw order.
const FRONT_FRIENDS: Array = [
	["Monkey", "monkey", "AnimatedSprite2D"],
	["Turtle", "turtle", "Body/AnimatedSprite2D"],
	["TurtleBack", "turtle", "Body/AnimatedSprite2D/Sprite2D_Back"],
	["Penguin", "penguin", "AnimatedSprite2D"],
	["Frog", "frog", "AnimatedSprite2D"],
	["Crab", "crab", "Body/AnimatedSprite2D"],
	["Parakeet", "parakeet", "AnimatedSprite2D"],
	["Ant", "ant", "AnimatedSprite2D"],
]
const BEHIND_FRIENDS: Array = [
	["Jellyfish", "jellyfish", "SpriteControl/AnimatedSprite2D_Body"],
]

var _manifest: Dictionary = {}
var _measured: Dictionary = {}


func _ready() -> void:
	_manifest = _read_json(MANIFEST_PATH)
	_measured = _read_json(MEASURED_PATH)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FRAMES_DIR))
	for name: String in _manifest:
		_build_sprite_frames(name)

	_build_scene(FRONT_SCENE_PATH, "BossFriends", FRONT_FRIENDS, FRONT_ORIGIN)
	_build_scene(BEHIND_SCENE_PATH, "BossFriendsBehind", BEHIND_FRIENDS, BEHIND_ORIGIN)
	get_tree().quit()


func _read_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("build_boss_friends: cannot read %s" % path)
		get_tree().quit(1)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Array:
		# The atlas manifest is a list; key it by friend name for lookups.
		var by_name: Dictionary = {}
		for entry: Dictionary in parsed:
			by_name[entry.name] = entry
		return by_name
	return parsed


func _build_sprite_frames(name: String) -> void:
	var entry: Dictionary = _manifest[name]
	var atlas: Texture2D = load(entry.texture)
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")

	for animation: Dictionary in entry.animations:
		var animation_name: StringName = StringName(animation.name)
		frames.add_animation(animation_name)
		frames.set_animation_loop(animation_name, bool(animation.loop))
		frames.set_animation_speed(animation_name, float(animation.speed))
		for frame_index: int in range(int(animation.count)):
			var region: Array = entry.regions[int(animation.first_index) + frame_index]
			var texture: AtlasTexture = AtlasTexture.new()
			texture.atlas = atlas
			texture.region = Rect2(region[0], region[1], region[2], region[3])
			frames.add_frame(animation_name, texture)

	var path: String = "%s/%s_boss_animations.tres" % [FRAMES_DIR, name]
	var error: int = ResourceSaver.save(frames, path)
	if error != OK:
		push_error("build_boss_friends: failed to save %s (%d)" % [path, error])
	else:
		print("saved ", path)


func _measurement(friend: String, sprite_path: String) -> Dictionary:
	for entry: Dictionary in _measured[friend]:
		if String(entry.path) == sprite_path:
			return entry
	push_error("build_boss_friends: no measurement for %s/%s" % [friend, sprite_path])
	get_tree().quit(1)
	return {}


func _build_scene(path: String, root_name: String, friends: Array, origin: Vector2) -> void:
	var root: Node2D = Node2D.new()
	root.name = root_name
	root.set_script(load(SCRIPT_PATH))

	for spec: Array in friends:
		var node_name: String = spec[0]
		var friend: String = spec[1]
		var sprite_path: String = spec[2]
		var measured: Dictionary = _measurement(friend, sprite_path)

		var node: Node2D
		# The atlases store each frame smaller than the source sheet did, so the
		# node has to draw it that much bigger to land on the same pixels. A
		# plain Sprite2D decoration keeps its original texture, and its ratio is 1.
		var ratio: Vector2 = Vector2.ONE
		if String(measured.type) == "AnimatedSprite2D":
			var entry: Dictionary = _manifest[friend]
			var frames: SpriteFrames = load("%s/%s_boss_animations.tres" % [FRAMES_DIR, friend])
			var animated: AnimatedSprite2D = AnimatedSprite2D.new()
			animated.sprite_frames = frames
			animated.animation = StringName(measured.animation)
			node = animated
			ratio = Vector2(
				float(entry.frame_size[0]) / float(entry.source_frame_size[0]),
				float(entry.frame_size[1]) / float(entry.source_frame_size[1])
			)
		else:
			var sprite: Sprite2D = Sprite2D.new()
			sprite.texture = load(measured.texture)
			node = sprite

		node.name = node_name
		node.position = Vector2(measured.position[0], measured.position[1]) - origin
		node.rotation = float(measured.rotation)
		node.scale = Vector2(measured.scale[0], measured.scale[1]) / ratio
		node.centered = bool(measured.centered)
		node.offset = Vector2(measured.offset[0], measured.offset[1]) * ratio
		node.flip_h = bool(measured.flip_h)
		node.flip_v = bool(measured.flip_v)
		root.add_child(node)
		node.owner = root

	var packed: PackedScene = PackedScene.new()
	if packed.pack(root) != OK:
		push_error("build_boss_friends: failed to pack %s" % path)
		return
	var error: int = ResourceSaver.save(packed, path)
	if error != OK:
		push_error("build_boss_friends: failed to save %s (%d)" % [path, error])
	else:
		print("saved ", path, " (", root.get_child_count(), " sprites)")
