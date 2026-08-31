extends GutTest
## Holds the crab and jellyfish spritesheets to the size they are drawn at.
##
## Both stored 800 px frames for characters drawn far smaller, and both sat over
## the 4096 px limit older GPUs guarantee. They are stored at the size they are
## actually drawn now, repacked so no grid slot is wasted, with the sprites scaled
## up to match.
##
## The sizes below are not arbitrary, and that is the point of writing them down:
##
## The crab composes down through a Control at 0.24 and a sprite at 1.8, and no
## minigame rescales it, so 346 px is fixed.
##
## The jellyfish is the awkward one. SpriteControl resizes its sprites to fill a
## 400 px box at runtime, and jellyfish.gd then scales the whole node by
## SCALES[colour] times up to 1.2 at random -- so a pink one can reach 1.5, i.e.
## 600 px, and 720 with the canvas stretched up on a 4K display. Measuring one
## instance tells you nothing about the maximum, which is how a first attempt at
## this ended up sizing the sheets from a low random draw.

const CRAB_SCENE: String = "res://sources/minigames/crabs/crab/crab.tscn"
const CRAB_FRAMES: String = "res://sources/minigames/crabs/crab/crab_animations.tres"
const CRAB_FRAME_SIZE: float = 416.0
const CRAB_DRAWN: float = 346.0
const JELLYFISH_SCENE: String = "res://sources/minigames/jellyfish/jellyfish.tscn"
const JELLYFISH_FRAME_SIZE: float = 720.0
## SpriteControl fills this box, whatever the frame size.
const JELLYFISH_BOX: float = 400.0
const JELLYFISH_SHEETS: Array[String] = [
	"res://sources/minigames/jellyfish/blue_jellyfish_animations_body.tres",
	"res://sources/minigames/jellyfish/blue_jellyfish_animations_arms.tres",
	"res://sources/minigames/jellyfish/pink_jellyfish_animations_body.tres",
	"res://sources/minigames/jellyfish/pink_jellyfish_animations_arms.tres",
]
const MAX_TEXTURE_SIZE: int = 4096


func _assert_frames(path: String, expected: float) -> void:
	var frames: SpriteFrames = load(path) as SpriteFrames
	assert_not_null(frames, "%s should load" % path)
	if not frames:
		return
	for animation: StringName in frames.get_animation_names():
		assert_gt(frames.get_frame_count(animation), 0, "%s/%s should have frames" % [path.get_file(), animation])
		for index: int in frames.get_frame_count(animation):
			var texture: AtlasTexture = frames.get_frame_texture(animation, index) as AtlasTexture
			assert_not_null(texture, "%s/%s frame %d" % [path.get_file(), animation, index])
			if not texture:
				continue
			assert_eq(texture.region.size, Vector2(expected, expected),
				"%s/%s frame %d is %s" % [path.get_file(), animation, index, texture.region.size])
			assert_lte(texture.atlas.get_width(), MAX_TEXTURE_SIZE,
				"%s is %d px wide" % [texture.atlas.resource_path.get_file(), texture.atlas.get_width()])
			assert_lte(texture.atlas.get_height(), MAX_TEXTURE_SIZE,
				"%s is %d px tall" % [texture.atlas.resource_path.get_file(), texture.atlas.get_height()])


func test_the_crab_sheet_is_stored_at_the_reduced_size() -> void:
	_assert_frames(CRAB_FRAMES, CRAB_FRAME_SIZE)


func test_the_crab_is_still_drawn_at_the_same_size() -> void:
	var crab: Node = (load(CRAB_SCENE) as PackedScene).instantiate()
	add_child_autofree(crab)
	await get_tree().process_frame

	var sprite: AnimatedSprite2D = crab.get_node("Body/AnimatedSprite2D")
	assert_not_null(sprite.sprite_frames, "the crab should have frames")
	if not sprite.sprite_frames:
		return
	var texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
	var drawn: float = texture.get_size().x * sprite.get_global_transform().get_scale().x
	assert_almost_eq(drawn, CRAB_DRAWN, 2.0,
		"the crab draws at %.1f px; the scale has to compensate for the frame size" % drawn)


func test_every_jellyfish_sheet_is_stored_at_the_reduced_size() -> void:
	for path: String in JELLYFISH_SHEETS:
		_assert_frames(path, JELLYFISH_FRAME_SIZE)


func test_all_four_jellyfish_sheets_agree() -> void:
	# They are repacked one at a time, so a missed one would leave a colour or a
	# layer at the old size.
	var reference: Array = []
	for path: String in JELLYFISH_SHEETS:
		var frames: SpriteFrames = load(path) as SpriteFrames
		var shape: Array = []
		for animation: StringName in frames.get_animation_names():
			shape.append("%s:%d" % [animation, frames.get_frame_count(animation)])
		shape.sort()
		if reference.is_empty():
			reference = shape
		assert_eq(shape, reference, "%s should match the other layers" % path.get_file())


func test_the_jellyfish_draws_to_its_box_whatever_the_frame_size() -> void:
	# SpriteControl sets scale = size / texture size, so the drawn result is
	# independent of how much resolution the sheet stores. This is what makes the
	# frame size safe to change without touching the scene.
	var jellyfish: Node = (load(JELLYFISH_SCENE) as PackedScene).instantiate()
	add_child_autofree(jellyfish)
	await get_tree().process_frame
	await get_tree().process_frame

	var control: Control = jellyfish.get_node("SpriteControl")
	for node_name: String in ["AnimatedSprite2D_Body", "AnimatedSprite2D_Arms"]:
		var sprite: AnimatedSprite2D = control.get_node(node_name)
		assert_not_null(sprite.sprite_frames, "%s should have frames" % node_name)
		if not sprite.sprite_frames:
			continue
		var texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
		if not texture:
			continue
		assert_almost_eq(texture.get_size().x * sprite.scale.x, JELLYFISH_BOX, 1.0,
			"%s should fill the %d px box, not %.1f px"
				% [node_name, JELLYFISH_BOX, texture.get_size().x * sprite.scale.x])


func test_the_sheets_cover_the_largest_a_jellyfish_can_get() -> void:
	# SCALES[PINK] times the 1.2 random factor, times the 1.2 canvas stretch.
	var largest: float = JELLYFISH_BOX * 1.25 * 1.2 * 1.2
	assert_gte(JELLYFISH_FRAME_SIZE, largest,
		"a pink jellyfish at full scale on a 4K display reaches %.0f px" % largest)
