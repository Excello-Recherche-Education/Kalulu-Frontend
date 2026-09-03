extends GutTest
## The light-graphics switch, and the promise it makes.
##
## Turning the decoration off has to mean two things: it is not drawn, and it was
## never loaded. The second is the one that matters on a cheap tablet and the one
## nothing on screen can show, because a texture named by a scene is loaded with
## that scene -- so a `texture = ExtResource(...)` put back into any of the scenes
## below would keep the memory cost while still, correctly, drawing nothing.
##
## The first test is therefore the important one: it holds the scenes to naming none
## of the artwork this switch controls. The rest check that the pieces themselves
## decline to load when asked to run light.

## The screens whose decoration is loaded on demand.
const DECORATED_SCENES: PackedStringArray = [
	"res://sources/minigames/ants/ants_minigame.tscn",
	"res://sources/minigames/boss/boss_minigame.tscn",
	"res://sources/minigames/caterpillar/caterpillar_minigame.tscn",
	"res://sources/minigames/crabs/crabs_minigame.tscn",
	"res://sources/minigames/frog/frog_minigame.tscn",
	"res://sources/minigames/jellyfish/jellyfish_minigame.tscn",
	"res://sources/minigames/monkeys/monkeys_minigame.tscn",
	"res://sources/minigames/parakeets/parakeets_minigame.tscn",
	"res://sources/minigames/penguin/penguin_minigame.tscn",
	"res://sources/minigames/turtles/turtles_minigame.tscn",
	"res://sources/minigames/turtles/water.tscn",
	"res://sources/gardens/gardens.tscn",
	"res://sources/brain/brain.tscn",
	"res://sources/menus/login/login.tscn",
	"res://sources/minigames/base/base_minigame.tscn",
	"res://sources/minigames/base/minigame_ui.tscn",
	"res://sources/minigames/base/kalulu_ingame.tscn",
]
## What none of them may name. Every one of these is reached through HeavyGraphics
## instead, from a path.
const ON_DEMAND_ARTWORK: PackedStringArray = [
	"res://assets/minigames/ants/graphics/background.png",
	"res://assets/minigames/boss/background.png",
	"res://assets/minigames/caterpillar/graphics/background.png",
	"res://assets/minigames/crabs/graphic/background.png",
	"res://assets/minigames/crabs/graphic/background_2.png",
	"res://assets/minigames/frog/graphics/background.png",
	"res://assets/minigames/jellyfish/graphic/background.png",
	"res://assets/minigames/monkeys/graphic/background.png",
	"res://assets/minigames/monkeys/graphic/background_shadows.png",
	"res://assets/minigames/parakeets/graphic/background_1.png",
	"res://assets/minigames/parakeets/graphic/background_2.png",
	"res://assets/minigames/parakeets/graphic/background_3.png",
	"res://assets/minigames/penguin/graphic/background.png",
	"res://assets/minigames/parakeets/graphic/cloud_1.png",
	"res://assets/minigames/parakeets/graphic/cloud_2.png",
	"res://assets/minigames/parakeets/graphic/cloud_3.png",
	"res://assets/minigames/turtles/graphic/turtle_background.png",
	"res://sources/minigames/turtles/turtles_water_material.tres",
	"res://sources/utils/fx/water_ring.tscn",
	"res://sources/minigames/boss/boss_friends.tscn",
	"res://sources/minigames/boss/boss_friends_behind.tscn",
	"res://sources/minigames/boss/kalulu_boss.tscn",
	"res://sources/kalulu_animator.tscn",
	"res://sources/utils/fx/firework.tscn",
	"res://sources/minigames/frog/river.tscn",
]

var _light_on_open: bool = false


func before_each() -> void:
	_light_on_open = UserDataManager.get_light_graphics()


func after_each() -> void:
	UserDataManager.set_light_graphics(_light_on_open)


## Every resource a scene declares as its own, which is what Godot loads with it.
##
## Read out of the file rather than off the loaded scene: the point is what the file
## declares, and a path sitting in a `texture_path` string -- which is how the lazy
## nodes name their picture -- is exactly the thing that is *not* a declaration.
func _declared_resources(scene_path: String) -> PackedStringArray:
	var file: FileAccess = FileAccess.open(scene_path, FileAccess.READ)
	assert_not_null(file, "%s should be readable" % scene_path)
	if not file:
		return PackedStringArray()
	var declared: PackedStringArray = PackedStringArray()
	for line: String in file.get_as_text().split("\n"):
		if not line.begins_with("[ext_resource "):
			continue
		var after_path: String = line.get_slice('path="', 1)
		if after_path.is_empty():
			continue
		declared.append(after_path.get_slice('"', 0))
	return declared


# --- The scenes declare none of it -----------------------------------------------
func test_no_decorated_scene_declares_the_artwork_it_decorates_with() -> void:
	for scene_path: String in DECORATED_SCENES:
		var declared: PackedStringArray = _declared_resources(scene_path)
		assert_gt(declared.size(), 0, "%s should declare something" % scene_path)
		for artwork: String in ON_DEMAND_ARTWORK:
			assert_false(artwork in declared,
				"%s declares %s, so it pays for it even when running light" % [scene_path, artwork])


func test_the_artwork_is_all_still_there_to_be_loaded() -> void:
	# The other half of the test above: a path that no longer resolves would make
	# the decoration silently disappear on every device rather than on a light one.
	for artwork: String in ON_DEMAND_ARTWORK:
		assert_true(ResourceLoader.exists(artwork), "%s should exist" % artwork)


# --- The switch itself -----------------------------------------------------------
func test_running_light_is_off_until_it_is_asked_for() -> void:
	UserDataManager.set_light_graphics(false)
	assert_true(HeavyGraphics.enabled(), "the full artwork is the default")


func test_asking_to_run_light_refuses_every_load() -> void:
	UserDataManager.set_light_graphics(true)

	assert_false(HeavyGraphics.enabled())
	assert_null(HeavyGraphics.load_texture(ON_DEMAND_ARTWORK[0]))
	assert_null(HeavyGraphics.load_resource("res://sources/minigames/boss/kalulu_boss.tscn"))


func test_the_full_artwork_loads_when_it_is_wanted() -> void:
	UserDataManager.set_light_graphics(false)

	assert_not_null(HeavyGraphics.load_texture(ON_DEMAND_ARTWORK[0]))
	assert_not_null(HeavyGraphics.load_resource("res://sources/minigames/boss/kalulu_boss.tscn"))


func test_an_empty_path_asks_for_nothing() -> void:
	# Which is how a lazy node that its owner fills in later stays quiet at load.
	UserDataManager.set_light_graphics(false)
	assert_null(HeavyGraphics.load_texture(""))
	assert_null(HeavyGraphics.load_resource(""))


# --- The lazy nodes --------------------------------------------------------------
func test_a_lazy_rect_draws_its_named_picture() -> void:
	UserDataManager.set_light_graphics(false)
	var rect: LazyTextureRect = LazyTextureRect.new()
	rect.texture_path = ON_DEMAND_ARTWORK[0]
	add_child_autofree(rect)

	assert_not_null(rect.texture)


func test_a_lazy_rect_draws_nothing_when_running_light() -> void:
	UserDataManager.set_light_graphics(true)
	var rect: LazyTextureRect = LazyTextureRect.new()
	rect.texture_path = ON_DEMAND_ARTWORK[0]
	add_child_autofree(rect)

	assert_null(rect.texture)


func test_a_lazy_sprite_behaves_the_same_way() -> void:
	UserDataManager.set_light_graphics(true)
	var sprite: LazySprite2D = LazySprite2D.new()
	sprite.texture_path = ON_DEMAND_ARTWORK[0]
	add_child_autofree(sprite)
	assert_null(sprite.texture)

	UserDataManager.set_light_graphics(false)
	sprite.load_from(ON_DEMAND_ARTWORK[0])
	assert_not_null(sprite.texture)


# --- The clouds ------------------------------------------------------------------
func test_a_sky_holds_one_sprite_per_cloud() -> void:
	UserDataManager.set_light_graphics(false)
	var sky: CloudManager = CloudManager.new()
	add_child_autofree(sky)
	await get_tree().process_frame

	assert_eq(sky.get_child_count(), CloudManager.CLOUD_TEXTURE_PATHS.size(),
		"the clouds are made here, not authored in the scenes that show them")


func test_a_sky_running_light_is_empty() -> void:
	UserDataManager.set_light_graphics(true)
	var sky: CloudManager = CloudManager.new()
	add_child_autofree(sky)
	await get_tree().process_frame

	assert_eq(sky.get_child_count(), 0, "no clouds, and no cloud pictures loaded")


func test_a_world_configured_after_the_fact_still_has_its_sky() -> void:
	# The gardens size their sky to the world once it is measured, which runs
	# configure_world() after _ready() and used to be the only place the clouds
	# were counted.
	UserDataManager.set_light_graphics(false)
	var sky: CloudManager = CloudManager.new()
	add_child_autofree(sky)
	await get_tree().process_frame

	sky.configure_world(8000.0, 6000.0, 3)

	assert_gt(sky.get_child_count(), 0)


func test_an_empty_sky_survives_being_configured() -> void:
	UserDataManager.set_light_graphics(true)
	var sky: CloudManager = CloudManager.new()
	add_child_autofree(sky)
	await get_tree().process_frame

	sky.configure_world(8000.0, 6000.0, 3)

	assert_eq(sky.get_child_count(), 0)


# --- The turtles' water ----------------------------------------------------------
func test_the_water_pools_its_rings_when_it_is_drawn() -> void:
	UserDataManager.set_light_graphics(false)
	var water: Water = (load("res://sources/minigames/turtles/water.tscn") as PackedScene).instantiate()
	add_child_autofree(water)
	await get_tree().process_frame

	assert_not_null(water.texture, "the sea is painted")
	assert_not_null(water.material, "and it moves")
	assert_eq(water._available_rings.size(), Water.POOL_SIZE)


func test_the_water_running_light_is_not_there_at_all() -> void:
	UserDataManager.set_light_graphics(true)
	var water: Water = (load("res://sources/minigames/turtles/water.tscn") as PackedScene).instantiate()
	add_child_autofree(water)
	await get_tree().process_frame

	assert_null(water.texture)
	assert_null(water.material)
	assert_eq(water._available_rings.size(), 0, "no ring particles were made")

	# A turtle still swims, and still asks for a ring on every stroke.
	water.spawn_water_ring(Vector2.ZERO)

	assert_eq(water.get_child_count(), 0, "and asking for one adds nothing")


# --- The teacher's switch --------------------------------------------------------
func test_the_setting_survives_being_written() -> void:
	UserDataManager.set_light_graphics(true)
	assert_true(UserDataManager.get_light_graphics())

	UserDataManager.set_light_graphics(false)
	assert_false(UserDataManager.get_light_graphics())


# --- Kalulu the helper -----------------------------------------------------------
func _kalulu() -> Node:
	var scene: PackedScene = load("res://sources/minigames/base/kalulu_ingame.tscn") as PackedScene
	var helper: Node = scene.instantiate()
	add_child_autofree(helper)
	return helper


func test_kalulu_is_waiting_when_the_device_draws_him() -> void:
	UserDataManager.set_light_graphics(false)

	assert_not_null(_kalulu().kalulu_sprite,
		"a device with room for him keeps him ready, so nothing pauses mid-game")


func test_kalulu_is_not_fetched_until_a_child_asks_for_him() -> void:
	# His sheet is 3600x4801 and this scene is in every minigame, garden and menu
	# that can call him over. Most children never tap the button.
	UserDataManager.set_light_graphics(true)

	assert_null(_kalulu().kalulu_sprite)


func test_the_first_speech_fetches_him() -> void:
	UserDataManager.set_light_graphics(true)
	var helper: Node = _kalulu()

	helper.play_kalulu_speech(null, false, false)

	assert_not_null(helper.kalulu_sprite, "and he stays from then on")
	# There is no speech to play in a test, and Kalulu says so. Acknowledged here
	# rather than in after_each: GUT checks for unhandled errors before it runs.
	for tracked_error: GutTrackedError in get_errors():
		tracked_error.handled = true


# --- The fireworks ---------------------------------------------------------------
func test_the_fireworks_are_named_by_path_rather_than_preloaded() -> void:
	# firework.png is 3200x1600 and Fireworks sits in base_minigame, so a preloaded
	# default would put it in every minigame whether or not one was ever won.
	var constants: Dictionary = (Fireworks as Script).get_script_constant_map()
	assert_true(constants.has("FIREWORK_SCENE_PATH"))
	assert_true(constants.get("FIREWORK_SCENE_PATH") is String,
		"FIREWORK_SCENE_PATH should be a String, not a preloaded resource")


func test_a_won_game_is_celebrated_when_the_device_can_afford_it() -> void:
	UserDataManager.set_light_graphics(false)
	var fireworks: Fireworks = Fireworks.new()
	add_child_autofree(fireworks)

	fireworks.play()

	assert_not_null(fireworks.firework_scene)


func test_a_light_device_finishes_the_celebration_instead_of_showing_it() -> void:
	# The callers await `finished`, so a skipped celebration still has to answer.
	UserDataManager.set_light_graphics(true)
	var fireworks: Fireworks = Fireworks.new()
	add_child_autofree(fireworks)
	watch_signals(fireworks)

	fireworks.play()

	assert_signal_emitted(fireworks, "finished")
	assert_null(fireworks.firework_scene)
	assert_eq(fireworks.get_child_count(), 0, "and nothing was spawned")


# --- The drifting stars ----------------------------------------------------------
func test_the_stars_drift_when_the_device_can_afford_them() -> void:
	UserDataManager.set_light_graphics(false)
	var stars: DecorativeParticles = DecorativeParticles.new()
	add_child_autofree(stars)
	await get_tree().process_frame

	assert_true(stars.emitting)
	assert_true(stars.visible)


func test_the_stars_stop_on_a_light_device() -> void:
	# The one piece of decoration whose cost is the GPU rather than memory: 256 live
	# particles over the whole screen, every frame.
	UserDataManager.set_light_graphics(true)
	var stars: DecorativeParticles = DecorativeParticles.new()
	add_child_autofree(stars)
	await get_tree().process_frame

	assert_false(stars.emitting)
	assert_false(stars.visible)


# --- Kalulu can still be skipped -------------------------------------------------
## The tap area that skips a speech, in the coordinates the child actually taps.
##
## This is the one that has to hold. minigame_ui pauses the whole tree while Kalulu
## talks and unpauses on speech_ended, so a skip button that cannot be hit does not
## just fail to skip -- it freezes the game until the speech runs out. Nothing on
## screen shows it: Kalulu appears exactly where he should, and the button is
## invisible by design.
func _skip_area(light: bool) -> Rect2:
	UserDataManager.set_light_graphics(light)
	var helper: Node = _kalulu()
	# On a light device he arrives with the first speech rather than at load.
	helper.play_kalulu_speech(null, false, false)
	await get_tree().process_frame
	for tracked_error: GutTrackedError in get_errors():
		tracked_error.handled = true
	return (helper.pass_button as Button).get_global_rect()


func test_the_skip_area_covers_kalulu() -> void:
	# The rect the button had while it was authored as a child of the sprite. A
	# Control resolves its anchors against its parent's anchorable rect, and only a
	# sprite reports one -- under a plain node this collapsed to 28x28.
	var area: Rect2 = await _skip_area(false)

	assert_almost_eq(area.position, Vector2(64.0, 962.0), Vector2.ONE,
		"the skip area should start where it always did")
	assert_almost_eq(area.size, Vector2(540.0, 730.0), Vector2.ONE,
		"and be the same 540x730 it always was")


func test_the_skip_area_survives_running_light() -> void:
	var area: Rect2 = await _skip_area(true)

	assert_almost_eq(area.size, Vector2(540.0, 730.0), Vector2.ONE,
		"fetching Kalulu late must not cost the child the skip button")


func test_the_skip_button_sits_on_top_of_kalulu() -> void:
	# Drawn after him, so the tap lands on the button rather than on the sprite.
	UserDataManager.set_light_graphics(false)
	var helper: Node = _kalulu()

	assert_eq(helper.pass_button.get_parent(), helper.kalulu_sprite,
		"the button belongs to the sprite, which is what gives it a rect")
	assert_eq(helper.pass_button.get_index(), helper.kalulu_sprite.get_child_count() - 1,
		"and it is the last child, so it is drawn over him")


# --- The clouds keep their place in the stack ------------------------------------
func test_the_penguins_clouds_stay_behind_the_scenery() -> void:
	# The three sprites used to be authored in the scene at z_index -3. Built here
	# instead, they carry the manager's own z, so the manager has to hold it -- or
	# the sky drifts over the penguin.
	var scene_text: String = FileAccess.open(
		"res://sources/minigames/penguin/penguin_minigame.tscn", FileAccess.READ).get_as_text()
	var clouds: String = scene_text.get_slice('[node name="Clouds"', 1).get_slice("[node", 0)
	assert_true(clouds.contains("z_index = -3"),
		"the penguin's sky belongs behind its ice and its mountains")


## Tapping to skip actually lets the game run again.
##
## The end-to-end version of the test above, because the consequence is worse than
## a dead button: minigame_ui sets get_tree().paused while Kalulu talks and clears
## it on speech_ended, so a skip that never lands leaves the whole game frozen --
## no minigame, no wheel, no way out. That is what a collapsed tap area did.
func test_tapping_kalulu_unfreezes_the_game() -> void:
	if not Database.is_open:
		pending("needs an installed language pack")
		return
	var student_on_open: String = UserDataManager.student
	# Signed in directly rather than through login_student, which would also open a
	# session and call the server. Put back at the end either way.
	if not UserDataManager.student_progression:
		UserDataManager.student = str(_any_student_code())
	if not UserDataManager.student_progression:
		pending("needs a registered student")
		return
	UserDataManager.set_light_graphics(false)
	if UserDataManager._student_speeches:
		# The intro only plays for a minigame this student has not seen.
		UserDataManager._student_speeches.speeches_played = [] as Array[String]
	Minigame.transition_data = {
		current_lesson_number = 12,
		current_garden_index = 0,
		minigame_number = 0,
		minigame_completed = false,
	}
	var game: Node = (load(
		"res://sources/minigames/jellyfish/jellyfish_minigame.tscn") as PackedScene).instantiate()
	add_child(game)
	for _index: int in 120:
		await get_tree().process_frame
	var kalulu: Node = game.get_node("MinigameUI/MainControl/Kalulu")
	if not get_tree().paused:
		game.free()
		UserDataManager.student = student_on_open
		pending("the intro speech did not run, so there is nothing to skip")
		return

	# Tap the middle of the skip area, the way a child does.
	var centre: Vector2 = (kalulu.pass_button as Button).get_global_rect().get_center()
	assert_eq(_control_at(centre), kalulu.pass_button,
		"the tap has to reach the skip button")
	_tap(centre)
	# Generous: headless frames carry a tiny delta, so Kalulu's hide animation needs
	# far more of them than it does seconds.
	for _index: int in 6000:
		await get_tree().process_frame
		if not get_tree().paused:
			break

	assert_false(get_tree().paused, "the game has to run again once Kalulu is dismissed")
	assert_false(kalulu.visible, "and his overlay has to be gone")
	get_tree().paused = false
	game.free()
	UserDataManager.student = student_on_open
	for tracked_error: GutTrackedError in get_errors():
		tracked_error.handled = true


## Whatever the viewport says is under `point`.
func _control_at(point: Vector2) -> Control:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	# Local coordinates: a headless window is 64x64, and the canvas transform would
	# otherwise put the event somewhere else entirely.
	get_viewport().push_input(motion, true)
	return get_viewport().gui_get_hovered_control()


func _tap(point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = point
		click.pressed = pressed
		get_viewport().push_input(click, true)


## The first student this account holds, for signing in with.
func _any_student_code() -> int:
	var settings: TeacherSettings = UserDataManager.teacher_settings
	if not settings:
		return 0
	for device: int in settings.students.keys():
		for student: StudentData in settings.students[device]:
			return student.code
	return 0


## Nothing else is anchored to a node that reports no rect.
##
## The same refactor put a plain slot where a sprite used to be in two other places.
## Neither holds a Control today, and neither may grow one without the trap coming
## back. Read out of the scene rather than instantiated: the brain wants a signed-in
## student before it will build.
func test_no_other_slot_has_a_control_hanging_off_it() -> void:
	for slot_path: String in ["GameRoot/KaluluBoss", "Brain/Kalulu"]:
		for scene_path: String in ["res://sources/minigames/boss/boss_minigame.tscn",
				"res://sources/brain/brain.tscn"]:
			var state: SceneState = (load(scene_path) as PackedScene).get_state()
			var found_slot: bool = false
			for index: int in state.get_node_count():
				var own_path: String = str(state.get_node_path(index)).trim_prefix("./")
				if own_path == slot_path:
					found_slot = true
					continue
				if str(state.get_node_path(index, true)).trim_prefix("./") != slot_path:
					continue
				assert_false(ClassDB.is_parent_class(state.get_node_type(index), "Control"),
					"%s in %s anchors against a node with no rect"
						% [state.get_node_name(index), scene_path])
			if found_slot:
				assert_true(found_slot, "%s is still where %s puts it" % [slot_path, scene_path])
