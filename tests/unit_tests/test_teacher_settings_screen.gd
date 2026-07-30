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


func before_each() -> void:
	screen = (load(SETTINGS_SCENE) as PackedScene).instantiate()
	autofree(screen)


func test_every_unique_name_the_script_looks_up_exists() -> void:
	for name: String in ["%DevicesTabContainer", "%DeletePopup", "%ChangeLanguagePopup",
			"%ChangeLanguageErrorPopup", "%LoadingPopup", "%AccountTypeOptionButton",
			"%EducationMethodOptionButton", "%AddDeviceButton", "%AddStudentButton",
			"%LabelInternetMandatory", "%AddDevicePopup", "%AddStudentPopup",
			"%DeleteStudentPopup", "%ExportCodesFileDialog", "%MenuButton",
			"%OverflowMenu"]:
		assert_not_null(screen.get_node_or_null(name),
			"the script resolves %s at _ready" % name)


func test_no_dialog_is_on_screen_at_load() -> void:
	# Regression: the rebuild dropped `visible = false` from the instanced
	# dialogs. A ConfirmPopup is a CanvasLayer, which defaults to visible, so all
	# seven drew at once on top of the screen and settings was unusable.
	for name: String in ["%ChangeLanguagePopup", "%ChangeLanguageErrorPopup", "%DeletePopup",
			"%AddStudentPopup", "%AddDevicePopup", "%DeleteStudentPopup", "%LoadingPopup"]:
		var dialog: CanvasLayer = screen.get_node(name)
		assert_false(dialog.visible, "%s should start hidden" % name)


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
			"_on_devices_tab_container_tab_changed", "_on_lesson_unlocks_student_deleted",
			"_on_change_language_popup_accepted", "_on_delete_popup_accepted",
			"_on_add_student_popup_accepted", "_on_add_device_popup_accepted",
			"_on_delete_student_popup_accepted", "_on_loading_popup_cancel",
			"_on_loading_popup_ok"]:
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
	for name: String in ["%AccountTypeOptionButton", "%EducationMethodOptionButton"]:
		var field: OptionButton = screen.get_node(name)
		assert_false(field.fit_to_longest_item,
			"%s must not size to its longest item or its label stops wrapping" % name)


func test_the_screen_uses_the_menu_theme() -> void:
	assert_eq(screen.theme.resource_path, MenuTheme.THEME_PATH)
	assert_eq(screen.get_node("Page/Card").theme_type_variation, MenuTheme.VARIATION_CARD)
	assert_eq(screen.get_node("%MenuButton").theme_type_variation,
		MenuTheme.VARIATION_ICON_BUTTON_LIGHT)
	assert_eq(screen.get_node("%AddStudentButton").theme_type_variation,
		MenuTheme.VARIATION_ICON_BUTTON_DARK,
		"card actions sit on white, so they take the dark circle")


func test_the_dialogs_carry_their_headings() -> void:
	for pair: Array in [["%AddStudentPopup", "ADD_A_NEW_STUDENT"],
			["%AddDevicePopup", "ADD_A_NEW_DEVICE"],
			["%DeleteStudentPopup", "DELETE_STUDENT"],
			["%DeletePopup", "DELETE_ACCOUNT"]]:
		var popup: ConfirmPopup = screen.get_node(pair[0] as String)
		assert_eq(popup.title_text, pair[1], "%s should have a heading" % pair[0])
		assert_false(popup.content_text.is_empty(), "%s should have a message" % pair[0])
