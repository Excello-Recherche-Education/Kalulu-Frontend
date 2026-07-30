extends GutTest
## The launch routing decision.
##
## EntryFlow reads global state (UserDataManager, Database), so each test puts
## that state back the way it found it.

var saved_teacher_settings: TeacherSettings


func before_each() -> void:
	saved_teacher_settings = UserDataManager.teacher_settings


func after_each() -> void:
	UserDataManager.teacher_settings = saved_teacher_settings


func test_every_scene_it_can_route_to_exists() -> void:
	# A typo in one of these paths would only show up as a black screen on
	# launch, so check them rather than trusting the strings.
	for path: String in [EntryFlow.SPLASH_SCENE_PATH, EntryFlow.GREETING_SCENE_PATH,
			EntryFlow.WELCOME_SCENE_PATH, EntryFlow.SIGNED_IN_SCENE_PATH]:
		assert_true(ResourceLoader.exists(path), "%s should exist" % path)


func test_the_splash_is_the_projects_main_scene() -> void:
	# The splash is shown on every launch, including for a device that is
	# already signed in.
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"),
		EntryFlow.SPLASH_SCENE_PATH,
		"the project should still boot on the splash")


func test_a_device_with_no_teacher_has_no_token() -> void:
	UserDataManager.teacher_settings = null

	assert_false(EntryFlow.has_connection_token(),
		"a device with no teacher settings is not signed in")


func test_a_teacher_without_a_token_is_not_signed_in() -> void:
	# Teacher settings exist from the moment registration starts; only a token
	# means the server accepted the account.
	var settings: TeacherSettings = TeacherSettings.new()
	settings.token = ""
	UserDataManager.teacher_settings = settings

	assert_false(EntryFlow.has_connection_token(),
		"an empty token should not count as signed in")


func test_a_teacher_with_a_token_is_signed_in() -> void:
	var settings: TeacherSettings = TeacherSettings.new()
	settings.token = "a-token"
	UserDataManager.teacher_settings = settings

	assert_true(EntryFlow.has_connection_token())


func test_a_signed_out_device_goes_to_the_welcome_screen() -> void:
	UserDataManager.teacher_settings = null

	assert_eq(EntryFlow.scene_after_greeting(), EntryFlow.WELCOME_SCENE_PATH)


func test_a_signed_in_device_skips_the_welcome_screen() -> void:
	# It goes through the language check, which ends at the access-code screen
	# once the pack is up to date.
	var settings: TeacherSettings = TeacherSettings.new()
	settings.token = "a-token"
	UserDataManager.teacher_settings = settings

	assert_eq(EntryFlow.scene_after_greeting(), EntryFlow.SIGNED_IN_SCENE_PATH)


func test_the_greeting_is_skipped_without_a_language_pack() -> void:
	# On a fresh install there is no pack, so there is no speech to play and
	# nothing to look at; the splash goes straight on.
	if Database.is_open:
		pending("needs a closed database; a language pack is installed here")
		return
	UserDataManager.teacher_settings = null

	assert_false(EntryFlow.greeting_speech_available())
	assert_eq(EntryFlow.scene_after_splash(), EntryFlow.WELCOME_SCENE_PATH,
		"with no greeting to play the splash should route past it")


func test_backing_out_of_registration_returns_to_the_welcome_screen() -> void:
	# Registration is only reachable from the Sign Up tab, so the first step's
	# Previous has to lead back there rather than to the old main menu.
	var register: GDScript = load("res://sources/menus/register/register.gd")
	assert_eq(register.BACK_SCENE_PATH, EntryFlow.WELCOME_SCENE_PATH)


func test_signing_out_lands_on_the_welcome_screen() -> void:
	# Logging out and deleting an account both drop the token, so neither can
	# land somewhere that assumes the device is still signed in.
	var settings: GDScript = load("res://sources/menus/settings/teacher_settings.gd")
	assert_eq(settings.SIGNED_OUT_SCENE_PATH, EntryFlow.WELCOME_SCENE_PATH)


func test_the_greeting_scene_has_the_parts_its_script_expects() -> void:
	# Instantiated detached on purpose: the greeting starts speaking and then
	# changes scene as soon as it enters a tree, which would tear this run down.
	var greeting: Control = (load(EntryFlow.GREETING_SCENE_PATH) as PackedScene).instantiate()
	autofree(greeting)

	for path: String in ["Background", "Plants", "Kalulu", "Kalulu/Moon", "Kalulu/Sprite",
			"Kalulu/Wordmark", "Kalulu/Title", "SpeechPlayer", "ContinueButton"]:
		assert_not_null(greeting.get_node_or_null(path), "%s should be in the scene" % path)

	var sprite: AnimatedSprite2D = greeting.get_node("Kalulu/Sprite")
	assert_true(sprite.sprite_frames.has_animation("Talk"), "Kalulu should be able to talk")
	assert_true(sprite.sprite_frames.has_animation("Idle"), "Kalulu should be able to idle")


func test_tapping_the_greeting_is_possible_anywhere() -> void:
	# The old main menu made its whole screen a transparent "Play" button; the
	# greeting keeps that affordance so it can always be skipped.
	var greeting: Control = (load(EntryFlow.GREETING_SCENE_PATH) as PackedScene).instantiate()
	autofree(greeting)
	var button: Button = greeting.get_node("ContinueButton")

	assert_eq(button.anchor_right, 1.0, "the skip target should span the screen")
	assert_eq(button.anchor_bottom, 1.0, "the skip target should span the screen")


func test_the_greeting_uses_the_speech_the_title_screen_always_used() -> void:
	# The old main menu played title_screen / tuto_welcome_oneshot. Naming a
	# different clip here would silently disable the greeting for everyone,
	# since a missing file just skips the screen.
	assert_eq(EntryFlow.greeting_speech_path(),
		Database.get_kalulu_speech_path("title_screen", "tuto_welcome_oneshot"),
		"the greeting should be the title screen's welcome speech")
