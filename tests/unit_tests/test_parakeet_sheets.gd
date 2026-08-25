extends GutTest
## Holds the parakeet spritesheets to the size they are actually drawn at.
##
## The three colour sheets used to be 6401x6401 -- 800 px frames for a bird shown
## at 320 px, 41 Mpx each, and over the 4096 px limit older GPUs guarantee. They
## are 384 px frames now, with the sprites scaled up by the same factor so the
## bird lands on exactly the same pixels.
##
## Two things would quietly undo that. Re-exporting a sheet at its old size, since
## the SpriteFrames address it by hardcoded pixel regions and nothing would
## complain until the frames were visibly wrong. And giving parakeet.tscn a
## default `sprite_frames` again, which loads a sheet for a colour the round is
## not even using -- the scene leaves it unset so _ready() assigns the one colour
## that is wanted.

const PARAKEET_SCENE_PATH: String = "res://sources/minigames/parakeets/parakeet.tscn"

## The size the bird is drawn at, from the scene's own scales; the minigame never
## touches them.
const DRAWN_SIZE: float = 320.0
const FRAME_SIZE: float = 384.0

## Old GPUs are only guaranteed 4096 px in a dimension.
const MAX_TEXTURE_SIZE: int = 4096

const COLOUR_ANIMATIONS: Array[String] = [
	"res://sources/minigames/parakeets/red_parakeet_animations.tres",
	"res://sources/minigames/parakeets/green_parakeet_animations.tres",
	"res://sources/minigames/parakeets/yellow_parakeet_animation.tres",
]
const COLOUR_FEATHERS: Array[String] = [
	"res://sources/minigames/parakeets/red_parakeet_feathers_animations.tres",
	"res://sources/minigames/parakeets/green_parakeet_feathers_animations.tres",
	"res://sources/minigames/parakeets/yellow_parakeet_feathers_animations.tres",
]


func _parakeet() -> Parakeet:
	var scene: PackedScene = load(PARAKEET_SCENE_PATH) as PackedScene
	var parakeet: Parakeet = scene.instantiate() as Parakeet
	add_child_autofree(parakeet)
	return parakeet


func test_the_scene_carries_no_default_sheet() -> void:
	# Checked on the packed scene, because instantiating runs _ready() which
	# assigns one straight away.
	var scene: PackedScene = load(PARAKEET_SCENE_PATH) as PackedScene
	var state: SceneState = scene.get_state()
	for node_index: int in state.get_node_count():
		if state.get_node_type(node_index) != &"AnimatedSprite2D":
			continue
		for property_index: int in state.get_node_property_count(node_index):
			assert_ne(String(state.get_node_property_name(node_index, property_index)), "sprite_frames",
				"%s should leave sprite_frames unset, so only the round's colour is loaded"
					% state.get_node_name(node_index))


func test_every_colour_is_sliced_at_the_reduced_frame_size() -> void:
	for path: String in COLOUR_ANIMATIONS + COLOUR_FEATHERS:
		var frames: SpriteFrames = load(path) as SpriteFrames
		assert_not_null(frames, "%s should load" % path)
		if not frames:
			continue
		for animation: StringName in frames.get_animation_names():
			for index: int in frames.get_frame_count(animation):
				var texture: AtlasTexture = frames.get_frame_texture(animation, index) as AtlasTexture
				assert_not_null(texture, "%s/%s frame %d should be an AtlasTexture" % [path, animation, index])
				if not texture:
					continue
				assert_eq(texture.region.size, Vector2(FRAME_SIZE, FRAME_SIZE),
					"%s/%s frame %d is %s; the sheets are stored at %d px per frame"
						% [path.get_file(), animation, index, texture.region.size, FRAME_SIZE])


func test_no_sheet_exceeds_what_old_gpus_guarantee() -> void:
	for path: String in COLOUR_ANIMATIONS:
		var frames: SpriteFrames = load(path) as SpriteFrames
		if not frames:
			continue
		var texture: AtlasTexture = frames.get_frame_texture(&"idle_front", 0) as AtlasTexture
		assert_not_null(texture, "%s should have an idle_front frame" % path)
		if not texture or not texture.atlas:
			continue
		assert_lte(texture.atlas.get_width(), MAX_TEXTURE_SIZE,
			"%s is %d px wide" % [texture.atlas.resource_path.get_file(), texture.atlas.get_width()])
		assert_lte(texture.atlas.get_height(), MAX_TEXTURE_SIZE,
			"%s is %d px tall" % [texture.atlas.resource_path.get_file(), texture.atlas.get_height()])


func test_all_three_colours_carry_the_same_animations() -> void:
	# The sheets are downscaled one colour at a time, so a missed one would show
	# up here rather than as a bird that renders at the wrong size in one round.
	var reference: SpriteFrames = load(COLOUR_ANIMATIONS[0]) as SpriteFrames
	var expected: Array = []
	for animation: StringName in reference.get_animation_names():
		expected.append("%s:%d" % [animation, reference.get_frame_count(animation)])
	expected.sort()

	for path: String in COLOUR_ANIMATIONS:
		var frames: SpriteFrames = load(path) as SpriteFrames
		var actual: Array = []
		for animation: StringName in frames.get_animation_names():
			actual.append("%s:%d" % [animation, frames.get_frame_count(animation)])
		actual.sort()
		assert_eq(actual, expected, "%s should match the other colours" % path.get_file())


func test_the_bird_still_lands_on_the_same_pixels() -> void:
	var parakeet: Parakeet = _parakeet()
	parakeet.color = Parakeet.Colors.GREEN

	for node_name: String in ["AnimatedSprite2D", "AnimatedSprite2D_Feathers"]:
		var sprite: AnimatedSprite2D = parakeet.get_node(node_name)
		assert_not_null(sprite.sprite_frames, "%s should get frames from _ready()" % node_name)
		if not sprite.sprite_frames:
			continue
		var texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
		var drawn: float = texture.get_size().x * sprite.get_global_transform().get_scale().x
		assert_almost_eq(drawn, DRAWN_SIZE, 1.0,
			"%s draws at %.1f px; the scale has to compensate for the frame size" % [node_name, drawn])


func test_setting_the_colour_before_entering_the_tree_still_works() -> void:
	# This is what parakeets_minigame.gd does, so the default colour's sheet is
	# never loaded on the way to the round's colour.
	var scene: PackedScene = load(PARAKEET_SCENE_PATH) as PackedScene
	var parakeet: Parakeet = scene.instantiate() as Parakeet
	parakeet.color = Parakeet.Colors.YELLOW
	add_child_autofree(parakeet)

	var sprite: AnimatedSprite2D = parakeet.get_node("AnimatedSprite2D")
	assert_not_null(sprite.sprite_frames, "_ready() should apply the colour set before add_child")
	if not sprite.sprite_frames:
		return
	var texture: AtlasTexture = sprite.sprite_frames.get_frame_texture(sprite.animation, 0) as AtlasTexture
	assert_true(texture.atlas.resource_path.contains("yellow"),
		"the sheet in use should be the colour that was set, not the scene's default")
