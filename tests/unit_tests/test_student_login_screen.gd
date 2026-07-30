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
			"Footer/TeacherButton/TeacherTimer", "Footer/BuildVersionValue", "Kalulu",
			"MusicStreamPlayer"]:
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


func test_the_teacher_gate_still_needs_the_plus_and_bar() -> void:
	# The gate is: tap plus then bar, then hold Settings. The on-screen help says
	# exactly that, so the code behind it has to match the symbols named.
	var login: GDScript = load("res://sources/menus/login/login.gd")
	assert_eq(login.TEACHER_PASSWORD, "42", "the gate code should be unchanged")
	assert_eq(Design.code_symbol_name("4"), "PLUS", "4 is the plus the help text names")
	assert_eq(Design.code_symbol_name("2"), "BAR", "2 is the vertical bar it names")


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


func test_the_hold_to_open_settings_delay_is_the_one_the_help_promises() -> void:
	var timer: Timer = screen.get_node("Footer/TeacherButton/TeacherTimer")
	assert_eq(timer.wait_time, 5.0, "the help text promises five seconds")
	assert_true(timer.one_shot, "the gate should fire once, not repeatedly")


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
