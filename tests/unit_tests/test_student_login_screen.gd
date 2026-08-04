extends GutTest
## Wiring of the child's access-code screen.
##
## Instantiated detached: entering a tree makes the screen load speeches, start
## music and possibly change scene, none of which belongs in a unit test.

const LOGIN_SCENE: String = "res://sources/menus/login/login.tscn"

var screen: Control


func before_each() -> void:
	screen = (load(LOGIN_SCENE) as PackedScene).instantiate()
	autofree(screen)


func test_the_screen_has_every_part_its_script_drives() -> void:
	for path: String in ["Background", "Header/DeviceNumber", "Header/Subtitle", "CodeKeypad",
			"BackButton", "Footer/KaluluButton", "Footer/TeacherButton",
			"Footer/BuildVersionValue", "Kalulu", "MusicStreamPlayer", "AdultCheck"]:
		assert_not_null(screen.get_node_or_null(path), "%s should be in the scene" % path)


func test_it_uses_the_redesigned_keypad() -> void:
	var keypad: Node = screen.get_node("CodeKeypad")
	assert_true(keypad is CodeKeypad, "the screen should use the redesigned keypad")
	assert_true(keypad.has_signal("code_entered"),
			"login.gd listens for code_entered, not the old password_entered")


func test_the_code_entered_handler_the_scene_connects_exists() -> void:
	# The scene wires code_entered to a method by name; a rename on either side
	# fails silently and the child could never log in.
	assert_true(screen.has_method("_on_code_keypad_code_entered"),
			"the handler the scene connects to should exist")


func test_the_teacher_gate_is_the_adult_check() -> void:
	# It used to be: tap plus then bar, then hold Settings for five seconds, with
	# the procedure spelled out in the help text beside it. It is now the same
	# adult check the sign-up tab and the boss minigame ask -- one step, and
	# nothing to memorise.
	var login: GDScript = load("res://sources/menus/login/login.gd")
	assert_false("TEACHER_PASSWORD" in login, "the two-symbol gate code should be gone")

	var screen: Control = (load(LOGIN_SCENE) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	assert_null(screen.get_node_or_null("Footer/TeacherButton/TeacherTimer"),
		"the five-second timer should have gone with the hold it measured")
	var popup: AdultCheckPopup = screen.get_node_or_null("%AdultCheck")
	assert_not_null(popup, "the screen should carry the adult check")
	assert_false(popup.visible, "which stays out of the way until asked for")


func test_pressing_settings_asks_the_adult_check() -> void:
	var screen: Control = (load(LOGIN_SCENE) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var popup: AdultCheckPopup = screen.get_node("%AdultCheck")

	screen._on_teacher_button_pressed()
	await get_tree().process_frame

	assert_true(popup.visible, "the check should be on screen")
	for digit: String in popup.challenge.code.split("", false):
		assert_string_contains(popup.prompt_label.text,
			tr(Design.code_symbol_name(digit)),
			"the instruction should name symbol %s" % digit)


func test_the_gate_code_reads_back_before_the_keypad_is_full() -> void:
	# The gate compares the partial code, so tapping two symbols has to leave
	# them readable without code_entered having fired.
	var keypad: CodeKeypad = (load("res://sources/ui/code_keypad.tscn") as PackedScene).instantiate()
	add_child_autofree(keypad)
	await get_tree().process_frame
	watch_signals(keypad)

	keypad.toggle_digit("4")
	keypad.toggle_digit("2")

	assert_eq(keypad.code, "42", "two taps should read back as the gate code")
	assert_signal_not_emitted(keypad, "code_entered",
			"a two-symbol code is not a complete one")


func test_the_help_text_describes_the_gate_that_exists() -> void:
	# It used to spell out the two symbols and the five-second hold. Leaving that
	# in place would tell the teacher to do something that no longer works.
	var help: String = tr("TEACHER_SETTINGS_HELP")

	assert_ne(help, "TEACHER_SETTINGS_HELP", "the help should be translated")
	assert_false(help.contains("5"), "there is no five-second hold to describe")
	for symbol: String in [tr("PLUS"), tr("BAR")]:
		assert_false(help.contains(symbol),
			"the help should not still name %s as the way in" % symbol)


func test_the_screen_is_styled_by_the_menu_theme() -> void:
	assert_eq(screen.theme.resource_path, MenuTheme.THEME_PATH)
	assert_eq(screen.get_node("Header/DeviceNumber").theme_type_variation,
			MenuTheme.VARIATION_TITLE)
	assert_eq(screen.get_node("Footer/TeacherButton").theme_type_variation,
			MenuTheme.VARIATION_PRIMARY_BUTTON)


func test_the_title_names_the_device() -> void:
	assert_eq(screen.get_node("Header/DeviceNumber").text, "LOG_IN_TO_DEVICE")
	assert_string_contains(tr("LOG_IN_TO_DEVICE"), "{number}",
			"the title should take the device number")
