extends GutTest
## Keeps the reading Kalulu out of the brain screen's steady state.
##
## kalulu_animator_reading.tscn is a 7500x7501 sheet of lossless art -- 286 MB of
## texture memory, measured. It used to be a `const preload` on BrainReward, which
## means it was pulled in the moment anything so much as referenced the class, and
## the sprite was built and hidden in setup(), so the brain screen carried all of
## it for an animation that only plays once the final boss is beaten.
##
## Turning that const back into a preload would look like a tidy-up and would cost
## the 286 MB back with nothing to show for it. This is what says otherwise.

const SCENE_PATH: String = "res://sources/kalulu_animator_reading.tscn"
## Every animation the reward sequence plays, between brain_reward.gd and the
## auto-cycling in kalulu_animator.gd.
const REQUIRED_ANIMATIONS: Array[String] = [
	"Show", "Talk", "Idle", "Hide", "Idle_blink",
	"Talk_blink", "Talk_ear_bend", "Talk_ear_wiggle",
]


## A BrainReward with just enough of its runtime for the Kalulu lifecycle, and
## without _build_runtime()'s database lookup for the victory speech.
func _reward() -> BrainReward:
	var reward: BrainReward = BrainReward.new()
	add_child_autofree(reward)
	var overlay: CanvasLayer = CanvasLayer.new()
	reward._overlay_layer = overlay
	reward.add_child(overlay)
	return reward


func test_the_reading_scene_is_referenced_by_path_not_preloaded() -> void:
	var constants: Dictionary = (BrainReward as Script).get_script_constant_map()
	assert_false(constants.has("READING_KALULU_SCENE"),
		"a preloaded PackedScene const would pin 286 MB whenever BrainReward is referenced")
	assert_true(constants.has("READING_KALULU_SCENE_PATH"),
		"the reading scene should be named by path so it can be loaded on demand")
	assert_true(constants.get("READING_KALULU_SCENE_PATH") is String,
		"READING_KALULU_SCENE_PATH should be a String, not a preloaded resource")
	assert_eq(constants.get("READING_KALULU_SCENE_PATH"), SCENE_PATH,
		"and it should point at the reading animator scene")


func test_nothing_is_built_until_a_reward_asks_for_it() -> void:
	var reward: BrainReward = _reward()
	assert_null(reward._reading_kalulu,
		"the brain screen should not hold the reading Kalulu before a reward plays")


func test_building_it_gives_a_kalulu_that_can_play_the_whole_sequence() -> void:
	var reward: BrainReward = _reward()
	await reward._build_reading_kalulu()

	var kalulu: AnimatedSprite2D = reward._reading_kalulu
	assert_not_null(kalulu, "the reading Kalulu should be built on demand")
	if not kalulu:
		return
	assert_eq(kalulu.get_parent(), reward._overlay_layer,
		"it should be added to the overlay layer, above the click catcher")
	assert_eq(kalulu.position, Vector2(1280, 900), "and placed where the reward expects it")
	assert_not_null(kalulu.sprite_frames, "it should carry its frames")
	if not kalulu.sprite_frames:
		return
	for animation: String in REQUIRED_ANIMATIONS:
		assert_true(kalulu.sprite_frames.has_animation(StringName(animation)),
			"the reward sequence plays '%s', so it has to be there" % animation)


func test_building_twice_reuses_the_one_that_is_already_there() -> void:
	var reward: BrainReward = _reward()
	await reward._build_reading_kalulu()
	var first: AnimatedSprite2D = reward._reading_kalulu
	await reward._build_reading_kalulu()
	assert_eq(reward._reading_kalulu, first,
		"a second call should not stack up another 286 MB of Kalulu")


func test_dismissing_releases_it() -> void:
	var reward: BrainReward = _reward()
	await reward._build_reading_kalulu()
	assert_not_null(reward._reading_kalulu, "built before dismissing")

	await reward._hide_kalulu()
	assert_null(reward._reading_kalulu,
		"dismissing should drop the reference so the texture can be freed")
	# Let the queued free run before teardown, so it does not race GUT's autofree.
	await get_tree().process_frame


func test_it_can_be_rebuilt_for_a_replay() -> void:
	# The chest is replayable once open, so a freed Kalulu has to come back.
	var reward: BrainReward = _reward()
	await reward._build_reading_kalulu()
	await reward._hide_kalulu()
	await get_tree().process_frame
	await reward._build_reading_kalulu()
	assert_not_null(reward._reading_kalulu, "a replay should build the Kalulu again")
	await get_tree().process_frame


func test_hiding_when_nothing_was_built_is_harmless() -> void:
	var reward: BrainReward = _reward()
	await reward._hide_kalulu()
	assert_null(reward._reading_kalulu, "_hide_kalulu() should no-op rather than crash")
	await get_tree().process_frame
