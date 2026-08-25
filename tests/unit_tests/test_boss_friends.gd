extends GutTest
## Holds the boss minigame's animal friends to the slim atlases they were moved to.
##
## These friends used to be the animal scenes of the other minigames, instantiated
## eight at a time. That dragged in every spritesheet those scenes reference --
## 335 MB of texture memory, measured -- to draw eight small sprites that never
## move and that the boss immediately stops on frame 0. Low-end hardware could not
## take it. Only the frames the boss plays are kept now, in atlases sized for how
## small the friends are really drawn.
##
## Nothing about that is self-evident from reading the scenes, and re-pointing a
## friend at an original spritesheet -- or dropping the atlases and going back to
## the animal scenes -- would look perfectly reasonable and quietly cost the
## 335 MB back. This is what says otherwise.

const FRONT_SCENE_PATH: String = "res://sources/minigames/boss/boss_friends.tscn"
const BEHIND_SCENE_PATH: String = "res://sources/minigames/boss/boss_friends_behind.tscn"

## Where a friend's frames are allowed to come from.
const ATLAS_DIRECTORY: String = "res://assets/minigames/boss/friends/"

## Generous next to the 7.2 Mpx the atlases actually hold, and nowhere near the
## 198 Mpx of source spritesheets the animal scenes pulled in.
const PIXEL_BUDGET: int = 12_000_000

const FRONT_FRIENDS: Array[String] = [
	"Monkey", "Turtle", "TurtleBack", "Penguin", "Frog", "Crab", "Parakeet", "Ant",
]
const BEHIND_FRIENDS: Array[String] = ["Jellyfish"]


func _friends(scene_path: String) -> BossFriends:
	var scene: PackedScene = load(scene_path) as PackedScene
	if not scene:
		return null
	var friends: BossFriends = scene.instantiate() as BossFriends
	if friends:
		add_child_autofree(friends)
	return friends


func _animated_sprites(friends: BossFriends) -> Array[AnimatedSprite2D]:
	var sprites: Array[AnimatedSprite2D] = []
	for child: Node in friends.get_children():
		if child is AnimatedSprite2D:
			sprites.append(child as AnimatedSprite2D)
	return sprites


func test_both_friend_scenes_hold_the_expected_roster() -> void:
	for spec: Array in [[FRONT_SCENE_PATH, FRONT_FRIENDS], [BEHIND_SCENE_PATH, BEHIND_FRIENDS]]:
		var scene_path: String = spec[0]
		var expected: Array = spec[1]
		var friends: BossFriends = _friends(scene_path)
		assert_not_null(friends, "%s should load as a BossFriends" % scene_path)
		if not friends:
			continue
		var names: Array[String] = []
		for child: Node in friends.get_children():
			names.append(String(child.name))
		assert_eq(names, expected, "%s should hold exactly the friends the boss draws" % scene_path)


func test_every_friend_draws_from_a_boss_atlas() -> void:
	# The whole point of the change: not one frame may come from an original
	# minigame spritesheet.
	for scene_path: String in [FRONT_SCENE_PATH, BEHIND_SCENE_PATH]:
		var friends: BossFriends = _friends(scene_path)
		if not friends:
			continue
		for sprite: AnimatedSprite2D in _animated_sprites(friends):
			assert_not_null(sprite.sprite_frames, "%s should have frames" % sprite.name)
			if not sprite.sprite_frames:
				continue
			for animation: StringName in sprite.sprite_frames.get_animation_names():
				for index: int in sprite.sprite_frames.get_frame_count(animation):
					var texture: Texture2D = sprite.sprite_frames.get_frame_texture(animation, index)
					var atlas: AtlasTexture = texture as AtlasTexture
					assert_not_null(atlas,
						"%s/%s frame %d should be an AtlasTexture" % [sprite.name, animation, index])
					if not atlas or not atlas.atlas:
						continue
					assert_true(atlas.atlas.resource_path.begins_with(ATLAS_DIRECTORY),
						"%s/%s frame %d draws from %s, which is not a boss friends atlas" % [
							sprite.name, animation, index, atlas.atlas.resource_path])


func test_the_friend_atlases_stay_within_budget() -> void:
	var areas: Dictionary = {}
	for scene_path: String in [FRONT_SCENE_PATH, BEHIND_SCENE_PATH]:
		var friends: BossFriends = _friends(scene_path)
		if not friends:
			continue
		for sprite: AnimatedSprite2D in _animated_sprites(friends):
			if not sprite.sprite_frames:
				continue
			for animation: StringName in sprite.sprite_frames.get_animation_names():
				for index: int in sprite.sprite_frames.get_frame_count(animation):
					var atlas: AtlasTexture = sprite.sprite_frames.get_frame_texture(animation, index) as AtlasTexture
					if not atlas or not atlas.atlas:
						continue
					# Keyed by path, so a sheet shared between animations counts once.
					areas[atlas.atlas.resource_path] = atlas.atlas.get_width() * atlas.atlas.get_height()

	var total: int = 0
	for path: String in areas:
		total += int(areas[path])
	assert_lt(total, PIXEL_BUDGET,
		"the friend atlases total %d pixels across %d sheets, over the budget" % [total, areas.size()])


func test_victory_plays_a_celebration_for_every_friend_that_has_one() -> void:
	var friends: BossFriends = _friends(FRONT_SCENE_PATH)
	assert_not_null(friends, "the front friends should load")
	if not friends:
		return

	friends.victory()
	for sprite: AnimatedSprite2D in _animated_sprites(friends):
		var expected: StringName = BossFriends.VICTORY_ANIMATIONS.get(sprite.name, &"")
		if expected.is_empty():
			continue
		assert_true(sprite.sprite_frames.has_animation(expected),
			"%s should carry its '%s' celebration" % [sprite.name, expected])
		assert_eq(String(sprite.animation), String(expected),
			"victory() should put %s on '%s'" % [sprite.name, expected])
		assert_true(sprite.is_playing(), "victory() should start %s animating" % sprite.name)


func test_idle_puts_every_friend_back_on_its_first_frame() -> void:
	var friends: BossFriends = _friends(FRONT_SCENE_PATH)
	if not friends:
		return

	friends.victory()
	friends.idle()
	for sprite: AnimatedSprite2D in _animated_sprites(friends):
		assert_false(sprite.is_playing(), "idle() should stop %s" % sprite.name)
		assert_eq(sprite.frame, 0, "idle() should rewind %s to its first frame" % sprite.name)


func test_every_named_celebration_belongs_to_a_friend() -> void:
	# Guards the other direction: a renamed node would leave a dead entry behind,
	# and that friend would silently stop celebrating.
	var names: Array[String] = []
	for scene_path: String in [FRONT_SCENE_PATH, BEHIND_SCENE_PATH]:
		var friends: BossFriends = _friends(scene_path)
		if not friends:
			continue
		for child: Node in friends.get_children():
			names.append(String(child.name))

	for friend_name: StringName in BossFriends.VICTORY_ANIMATIONS:
		assert_has(names, String(friend_name),
			"VICTORY_ANIMATIONS names '%s', which is not a friend in either scene" % friend_name)
