extends GutTest
## Keeps the turtles minigame's decorative crab off the crabs minigame's sheet.
##
## The crab that sits on the island is decoration: the turtles minigame plays
## idle_claws and victory_claws on it, and autoplays idle. It used to get those
## by slicing the whole 6401x4801 crab spritesheet into 48 frames -- 30.7 Mpx,
## 56% of this minigame's texture weight, for a crab drawn at 240 px.
##
## The three animations it can actually reach are extracted into their own atlas
## now. Pointing the node back at the shared sheet would look like reuse and cost
## the 30.7 Mpx back, so this says otherwise.

const MINIGAME_SCENE: String = "res://sources/minigames/turtles/turtles_minigame.tscn"
const DECOR_FRAMES: String = "res://sources/minigames/turtles/crab_decor_animations.tres"
const SHARED_CRAB_SHEET: String = "res://assets/minigames/crabs/graphic/crab_spritesheet.png"

## What the turtles minigame plays: idle_claws from its setup, victory_claws on a
## win, and idle from the node's autoplay.
const REACHABLE_ANIMATIONS: Array[String] = ["idle", "idle_claws", "victory_claws"]

const FRAME_SIZE: float = 288.0
const DRAWN_SIZE: float = 240.0
const MAX_TEXTURE_SIZE: int = 4096


func _decor() -> SpriteFrames:
	return load(DECOR_FRAMES) as SpriteFrames


func test_the_minigame_does_not_pull_in_the_shared_crab_sheet() -> void:
	var found: Array[String] = []
	for dependency: String in ResourceLoader.get_dependencies(MINIGAME_SCENE):
		var parts: PackedStringArray = dependency.split("::")
		found.append(parts[parts.size() - 1])
	assert_does_not_have(found, SHARED_CRAB_SHEET,
		"the decorative crab should draw from its own atlas, not the crabs minigame's sheet")


func test_the_atlas_holds_exactly_the_animations_that_can_be_reached() -> void:
	var frames: SpriteFrames = _decor()
	assert_not_null(frames, "%s should load" % DECOR_FRAMES)
	if not frames:
		return
	var names: Array[String] = []
	for animation: StringName in frames.get_animation_names():
		names.append(String(animation))
	names.sort()
	var expected: Array[String] = REACHABLE_ANIMATIONS.duplicate()
	expected.sort()
	assert_eq(names, expected,
		"carrying animations the minigame never plays is what made this expensive")


func test_every_frame_is_stored_at_the_reduced_size() -> void:
	var frames: SpriteFrames = _decor()
	if not frames:
		return
	for animation: StringName in frames.get_animation_names():
		assert_gt(frames.get_frame_count(animation), 0, "%s should have frames" % animation)
		for index: int in frames.get_frame_count(animation):
			var texture: AtlasTexture = frames.get_frame_texture(animation, index) as AtlasTexture
			assert_not_null(texture, "%s frame %d should be an AtlasTexture" % [animation, index])
			if not texture:
				continue
			assert_eq(texture.region.size, Vector2(FRAME_SIZE, FRAME_SIZE),
				"%s frame %d is %s" % [animation, index, texture.region.size])
			assert_true(texture.atlas.resource_path.contains("crab_decor"),
				"%s frame %d draws from %s" % [animation, index, texture.atlas.resource_path])


func test_the_atlas_fits_what_old_gpus_guarantee() -> void:
	var frames: SpriteFrames = _decor()
	if not frames:
		return
	var texture: AtlasTexture = frames.get_frame_texture(&"idle_claws", 0) as AtlasTexture
	if not texture or not texture.atlas:
		return
	assert_lte(texture.atlas.get_width(), MAX_TEXTURE_SIZE, "atlas width")
	assert_lte(texture.atlas.get_height(), MAX_TEXTURE_SIZE, "atlas height")


func test_the_crab_is_still_drawn_at_the_same_size() -> void:
	# Read off the packed scene rather than bringing the whole minigame up, which
	# would want a lesson and a database behind it.
	var scene: PackedScene = load(MINIGAME_SCENE) as PackedScene
	var state: SceneState = scene.get_state()
	var scale: Vector2 = Vector2.ONE
	var found: bool = false
	for node_index: int in state.get_node_count():
		if state.get_node_name(node_index) != &"CrabAnimatedSprite2D":
			continue
		found = true
		for property_index: int in state.get_node_property_count(node_index):
			if state.get_node_property_name(node_index, property_index) == &"scale":
				scale = state.get_node_property_value(node_index, property_index)
	assert_true(found, "the scene should still have a CrabAnimatedSprite2D")
	assert_almost_eq(FRAME_SIZE * scale.x, DRAWN_SIZE, 1.0,
		"%d px frames at scale %.4f draw %.1f px; the scale has to compensate"
			% [FRAME_SIZE, scale.x, FRAME_SIZE * scale.x])
