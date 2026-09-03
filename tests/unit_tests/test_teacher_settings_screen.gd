extends GutTest
## Structure of the settings screen after its rebuild.
##
## The scene was re-laid-out wholesale while its script kept every handler, so
## what matters is that the contract between them survived: the unique names the
## script looks up, and the signals it expects to receive. Both fail quietly --
## a missing unique name errors at _ready, a dropped connection just makes a
## button do nothing.
##
## Instantiated detached: _ready does a network check and touches
## UserDataManager.teacher_settings.

const SETTINGS_SCENE: String = "res://sources/menus/settings/teacher_settings.tscn"

var screen: Control
## Built on demand by _live_screen and shared by every test that needs one.
var live_screen: SettingsTeacherSettings
## The light-graphics setting is written to the device, so it is put back after.
var _light_on_open: bool = false


func before_each() -> void:
	screen = (load(SETTINGS_SCENE) as PackedScene).instantiate()
	autofree(screen)
	_light_on_open = UserDataManager.get_light_graphics()


func after_each() -> void:
	UserDataManager.set_light_graphics(_light_on_open)


func after_all() -> void:
	if live_screen:
		live_screen.free()


func test_every_unique_name_the_script_looks_up_exists() -> void:
	for unique_name: String in ["%DevicePills", "%StudentsContainer", "%DeletePopup", "%ChangeLanguagePopup",
			"%ChangeLanguageErrorPopup", "%LoadingPopup", "%AccountTypeOptionButton",
			"%EducationMethodOptionButton", "%AddDeviceButton", "%AddStudentButton",
			"%LabelInternetMandatory", "%AddDevicePopup", "%AddStudentPopup",
			"%DeleteStudentPopup", "%ExportCodesFileDialog", "%MenuButton",
			"%OverflowMenu", "%AddStudentErrorPopup", "%LightGraphicsCheck",
			"%LightGraphicsLabel"]:
		assert_not_null(screen.get_node_or_null(unique_name),
			"the script resolves %s at _ready" % unique_name)


func test_no_dialog_is_on_screen_at_load() -> void:
	# Regression: the rebuild dropped `visible = false` from the instanced
	# dialogs. A ConfirmPopup is a CanvasLayer, which defaults to visible, so all
	# seven drew at once on top of the screen and settings was unusable.
	for node_name: String in ["%ChangeLanguagePopup", "%ChangeLanguageErrorPopup", "%DeletePopup",
			"%AddStudentPopup", "%AddDevicePopup", "%DeleteStudentPopup", "%LoadingPopup",
			"%AddStudentErrorPopup"]:
		var dialog: CanvasLayer = screen.get_node(node_name)
		assert_false(dialog.visible, "%s should start hidden" % node_name)


func test_the_lesson_unlocks_panel_is_still_a_direct_child() -> void:
	# Looked up as $LessonUnlocks, not by unique name, so its position matters.
	assert_not_null(screen.get_node_or_null("LessonUnlocks"))


func test_every_handler_the_scene_connects_to_exists() -> void:
	# A typo here is silent: the connection is made to a missing method and the
	# control simply stops working.
	for method: String in ["_on_back_button_pressed", "_on_account_type_option_button_item_selected",
			"_on_education_method_option_button_item_selected", "_on_synchronize_button_pressed",
			"_on_dashboard_button_pressed", "_on_menu_button_pressed",
			"_on_overflow_menu_id_pressed", "_on_export_codes_button_pressed",
			"_on_add_student_button_pressed", "_on_add_device_button_pressed",
			"_on_lesson_unlocks_student_deleted",
			"_on_change_language_popup_accepted", "_on_delete_popup_accepted",
			"_on_add_student_popup_accepted", "_on_add_device_popup_accepted",
			"_on_delete_student_popup_accepted", "_on_loading_popup_cancel",
			"_on_loading_popup_ok", "_on_light_graphics_check_pressed"]:
		assert_true(screen.has_method(method), "%s should exist" % method)


func test_the_rare_and_destructive_actions_moved_into_the_menu() -> void:
	# They used to be permanent buttons in a sidebar next to everyday ones,
	# which put "Delete account" a single tap from "Synchronize".
	var menu: PopupMenu = screen.get_node("%OverflowMenu")
	assert_eq(menu.item_count, 3)
	assert_eq(menu.get_item_text(SettingsTeacherSettings.OverflowItem.CHANGE_LANGUAGE),
		"CHANGE_LANGUAGE")
	assert_eq(menu.get_item_text(SettingsTeacherSettings.OverflowItem.LOGOUT), "LOGOUT")
	assert_eq(menu.get_item_text(SettingsTeacherSettings.OverflowItem.DELETE_ACCOUNT),
		"DELETE_ACCOUNT")


func test_the_menu_items_are_indexed_by_the_enum_the_handler_matches_on() -> void:
	var menu: PopupMenu = screen.get_node("%OverflowMenu")
	for item: int in [SettingsTeacherSettings.OverflowItem.CHANGE_LANGUAGE,
			SettingsTeacherSettings.OverflowItem.LOGOUT,
			SettingsTeacherSettings.OverflowItem.DELETE_ACCOUNT]:
		assert_eq(menu.get_item_id(item), item,
			"item %d should carry its own id, since the handler matches on it" % item)


func test_the_sound_button_still_carries_its_volume_sliders() -> void:
	# It is a component, not a plain icon button; replacing it with one would
	# have quietly removed the four volume controls.
	var volume: Node = screen.get_node("Page/ControlsRow/Actions/VolumeButton")
	for slider: String in ["%MasterVolumeSlider", "%MusicVolumeSlider", "%VoiceVolumeSlider",
			"%EffectsVolumeSlider"]:
		assert_not_null(volume.get_node_or_null(slider),
			"the sound button should still own %s" % slider)


func test_the_dropdowns_keep_their_options() -> void:
	var account: OptionButton = screen.get_node("%AccountTypeOptionButton")
	var method: OptionButton = screen.get_node("%EducationMethodOptionButton")
	assert_eq(account.item_count, TeacherSettings.AccountType.size())
	assert_eq(method.item_count, TeacherSettings.EducationMethod.size())


func test_the_dropdowns_still_wrap_their_labels() -> void:
	# fit_to_longest_item defeats autowrap, and these options are long once
	# translated, so it has to stay off.
	for node_name: String in ["%AccountTypeOptionButton", "%EducationMethodOptionButton"]:
		var field: OptionButton = screen.get_node(node_name)
		assert_false(field.fit_to_longest_item,
			"%s must not size to its longest item or its label stops wrapping" % node_name)


func test_the_screen_uses_the_menu_theme() -> void:
	assert_eq(screen.theme.resource_path, MenuTheme.THEME_PATH)
	assert_eq(screen.get_node("Page/Card").theme_type_variation, MenuTheme.VARIATION_CARD)
	assert_eq(screen.get_node("%MenuButton").theme_type_variation,
		MenuTheme.VARIATION_ICON_BUTTON_LIGHT)
	assert_eq(screen.get_node("%AddStudentButton").theme_type_variation,
		MenuTheme.VARIATION_ICON_BUTTON_DARK,
		"card actions sit on white, so they take the dark circle")


func test_devices_are_pills_rather_than_tabs() -> void:
	# The hand-off shows a row of pills, purple for the selected one, over a
	# single grid of students -- not a TabContainer with a tab strip.
	var pills: HBoxContainer = screen.get_node("%DevicePills")
	assert_eq(pills.get_theme_constant("separation"), Design.PILL_GAP)
	var grid: GridContainer = screen.get_node("%StudentsContainer")
	assert_eq(grid.columns, Design.STUDENT_CARD_COLUMNS, "three student cards per row")
	assert_eq(grid.get_theme_constant("h_separation"), Design.STUDENT_CARD_GAP)


func test_the_settings_dropdowns_are_the_shorter_kind() -> void:
	# Settings' dropdowns are 88 tall in the hand-off, where a sign-up field is
	# 128; without the compact variation the theme makes them the taller one.
	for name: String in ["%AccountTypeOptionButton", "%EducationMethodOptionButton"]:
		var field: OptionButton = screen.get_node(name)
		assert_eq(field.theme_type_variation, MenuTheme.VARIATION_FIELD_COMPACT,
			"%s should use the compact field" % name)
		assert_eq(field.custom_minimum_size.y, float(Design.COMPACT_FIELD_HEIGHT))


func test_the_dialogs_carry_their_headings() -> void:
	for pair: Array in [["%AddStudentPopup", "ADD_A_NEW_STUDENT"],
			["%AddDevicePopup", "ADD_A_NEW_DEVICE"],
			["%DeleteStudentPopup", "DELETE_STUDENT"],
			["%DeletePopup", "DELETE_ACCOUNT"]]:
		var popup: ConfirmPopup = screen.get_node(pair[0] as String)
		assert_eq(popup.title_text, pair[1], "%s should have a heading" % pair[0])
		assert_false(popup.content_text.is_empty(), "%s should have a message" % pair[0])


## A screen with _ready actually run, for the tests that drive its handlers.
##
## before_each leaves its copy detached on purpose, but the handlers reach the
## dialogs through @onready lookups, which stay null until the screen is in a
## tree. Built once and shared: _ready starts a connectivity check and
## ServerManager owns a single HTTPRequest, so one screen per test would stack
## requests on top of each other and the engine would refuse the later ones.
func _live_screen() -> SettingsTeacherSettings:
	if not live_screen:
		live_screen = (load(SETTINGS_SCENE) as PackedScene).instantiate()
		add_child(live_screen)
		await get_tree().process_frame
	# Clear whatever the previous test left showing, so an assertion that the
	# dialog is up cannot pass on the back of another test's work.
	live_screen.add_student_error_popup.hide()
	live_screen.add_student_error_popup.title_text = ""
	live_screen.add_student_error_popup.content_text = ""
	return live_screen


# The screen logs the rejection as well as showing it, which is exactly what is
# being asked for here. Acknowledge it so GUT does not report it as an unexpected
# error. Must run inside the test: GUT checks for unhandled errors before
# after_each().
func _accept_the_logged_failure() -> void:
	for tracked_error: GutTrackedError in get_errors():
		tracked_error.handled = true


func test_a_full_account_is_told_why_no_more_students_can_be_added() -> void:
	# The server answers a plain 400 with {"error": "Maximum student limit
	# reached"} once every student code is taken. Both ways of adding a student
	# run into it -- adding a device adds its first student -- and the add-device
	# path used to swallow the failure whole, so a full account looked like a
	# broken button.
	var live: SettingsTeacherSettings = await _live_screen()

	live._report_add_student_failure({
		"success": false,
		"code": 400,
		"body": {"error": SettingsTeacherSettings.STUDENT_LIMIT_ERROR},
	})

	_accept_the_logged_failure()
	var popup: ConfirmPopup = live.add_student_error_popup
	assert_true(popup.visible, "the teacher should be told, not just the log")
	assert_eq(popup.title_text, "MAXIMUM_STUDENTS_REACHED")
	assert_false(popup.content_text.contains("{number}"),
		"the count should have been filled in, not left as a placeholder")
	assert_false(popup.content_text == "MAXIMUM_STUDENTS_REACHED_POPUP",
		"the message has to be translated here, because it is formatted")
	assert_string_contains(popup.content_text, str(live.get_student_count()),
		"the message should quote how many students the account has")


func test_any_other_add_student_failure_still_says_something() -> void:
	# Matching on the server's wording means a change to it must not go back to
	# failing silently -- it should fall back to the general message.
	var live: SettingsTeacherSettings = await _live_screen()

	live._report_add_student_failure({"success": false, "code": 500, "body": {}})

	_accept_the_logged_failure()
	var popup: ConfirmPopup = live.add_student_error_popup
	assert_true(popup.visible)
	assert_eq(popup.content_text, "ADD_STUDENT_FAILED",
		"an unrecognised failure should get the general message")
	assert_true(popup.title_text.is_empty(),
		"the general message reads as one sentence, so it needs no heading")


func test_a_body_that_is_not_a_dictionary_does_not_break_the_report() -> void:
	# ServerManager leaves `body` as whatever JSON came back, which for a gateway
	# error is a bare string rather than an object.
	var live: SettingsTeacherSettings = await _live_screen()

	live._report_add_student_failure({"success": false, "code": 502, "body": "Bad Gateway"})

	_accept_the_logged_failure()
	assert_true(live.add_student_error_popup.visible)
	assert_eq(live.add_student_error_popup.content_text, "ADD_STUDENT_FAILED")


func test_the_error_notice_only_offers_a_way_out_of_itself() -> void:
	# There is nothing to decide, so a Cancel beside Confirm would only make the
	# reader look for the difference between them.
	var live: SettingsTeacherSettings = await _live_screen()
	var popup: ConfirmPopup = live.add_student_error_popup

	assert_true(popup.acknowledge_only, "the error notice should be acknowledge-only")
	assert_false(popup.cancel_button.visible, "there should be no second button")
	assert_true(popup.confirm_button.visible, "there should be a way to dismiss it")
	assert_eq(popup.confirm_button.text, ConfirmPopup.ACKNOWLEDGE_TEXT)


func test_the_students_are_counted_across_every_device() -> void:
	# The limit message quotes this number rather than a copy of the server's,
	# which could only drift; an account that has just been refused a student is
	# sitting exactly on the ceiling.
	if not UserDataManager.teacher_settings:
		pending("needs a signed-in teacher")
		return
	var live: SettingsTeacherSettings = await _live_screen()

	var counted: int = 0
	for device_students: Variant in UserDataManager.teacher_settings.students.values():
		counted += (device_students as Array).size()

	assert_eq(live.get_student_count(), counted, "every device's students should be counted")


# --- The light-graphics box -----------------------------------------------------
## The box, read back from the device as _ready does.
##
## The whole screen is not rebuilt per test: _ready starts a connectivity check and
## ServerManager owns a single HTTPRequest, so the second screen's check is refused.
## _read_light_graphics is the function _ready calls, so calling it is the same test.
func _reopened_box(light: bool) -> Button:
	var live: SettingsTeacherSettings = await _live_screen()
	UserDataManager.set_light_graphics(light)
	live._read_light_graphics()
	return live.light_graphics_check


func test_the_box_is_a_box_and_not_a_menu_entry() -> void:
	# It was a checkable item in the overflow menu, where a teacher had to open the
	# menu to find out whether it was on. A box on the page shows its own state.
	assert_not_null(screen.get_node_or_null("Page/FooterRow/LightGraphicsCheck"),
		"the box belongs at the bottom of the page, under the card")
	var box: Button = screen.get_node("%LightGraphicsCheck")
	assert_true(box.toggle_mode, "it has to hold its position to show it")
	var menu: PopupMenu = screen.get_node("%OverflowMenu")
	for index: int in menu.item_count:
		assert_false(menu.is_item_checkable(index),
			"nothing in the menu is a switch any more")


func test_the_box_shows_the_position_the_device_is_in() -> void:
	# A device setting, so the same build opens ticked on one tablet and empty on
	# the next. Authoring the box's state in the scene would show one of them.
	var box: Button = await _reopened_box(true)

	assert_true(box.button_pressed)
	assert_not_null(box.icon, "a ticked box is filled in")


func test_an_untouched_device_opens_with_an_empty_box() -> void:
	var box: Button = await _reopened_box(false)

	assert_false(box.button_pressed)
	assert_null(box.icon)


func test_ticking_the_box_turns_the_artwork_off() -> void:
	var live: SettingsTeacherSettings = await _live_screen()
	UserDataManager.set_light_graphics(false)
	live._read_light_graphics()

	live.light_graphics_check.button_pressed = true
	live._on_light_graphics_check_pressed()

	assert_true(UserDataManager.get_light_graphics())
	assert_false(HeavyGraphics.enabled())
	assert_not_null(live.light_graphics_check.icon)


func test_clearing_the_box_brings_the_artwork_back() -> void:
	var live: SettingsTeacherSettings = await _live_screen()
	UserDataManager.set_light_graphics(true)
	live._read_light_graphics()

	live.light_graphics_check.button_pressed = false
	live._on_light_graphics_check_pressed()

	assert_false(UserDataManager.get_light_graphics())
	assert_true(HeavyGraphics.enabled())
	assert_null(live.light_graphics_check.icon)


func test_the_wording_beside_the_box_is_part_of_the_target() -> void:
	# A 120-pixel square is a small thing to hit on a tablet.
	var live: SettingsTeacherSettings = await _live_screen()
	UserDataManager.set_light_graphics(false)
	live._read_light_graphics()
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true

	live._on_light_graphics_label_gui_input(click)

	assert_true(live.light_graphics_check.button_pressed)
	assert_true(UserDataManager.get_light_graphics())
