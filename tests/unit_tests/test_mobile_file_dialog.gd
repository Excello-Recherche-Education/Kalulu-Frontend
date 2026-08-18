extends GutTest
## The configuration that makes Godot's FileDialog usable with a thumb.
##
## Most of what MobileFileDialog does is set properties, which would not be worth
## testing. This part is: to hide the chrome the engine exposes no flag for, it
## reaches into FileDialog's own internals by position. Those positions were read
## off Godot 4.7.1 and nothing in the engine promises to keep them.
##
## So these tests are aimed at an engine upgrade rather than at the file they
## cover. When they fail, either the dialog has quietly grown its clutter back, or
## it has lost a control the teacher needs to move around with.

const FIXTURE_DIR: String = "user://mobile_file_dialog_test"
const FIXTURE_FOLDER: String = "Classe CP"
const FIXTURE_SHEET: String = "Codes_2025.pdf"

var dialog: FileDialog


func after_all() -> void:
	var root: String = ProjectSettings.globalize_path(FIXTURE_DIR)
	DirAccess.remove_absolute(root.path_join(FIXTURE_SHEET))
	DirAccess.remove_absolute(root.path_join(FIXTURE_FOLDER))
	DirAccess.remove_absolute(root)


func before_each() -> void:
	dialog = FileDialog.new()
	add_child_autofree(dialog)
	MobileFileDialog.configure_save(dialog, "Export", CodeSheet.FILE_EXTENSION, CodeSheet.MIME_TYPE)


func _header() -> HBoxContainer:
	return dialog.get_vbox().get_child(0) as HBoxContainer


func _name_row() -> HBoxContainer:
	return dialog.get_vbox().get_child(1).get_child(1).get_child(3) as HBoxContainer


## A real folder holding a real folder and a real PDF.
##
## The tap tells one from the other by asking the filesystem, so nothing here can
## be faked with an ItemList built by hand.
func _fixture() -> String:
	var root: String = ProjectSettings.globalize_path(FIXTURE_DIR)
	DirAccess.make_dir_recursive_absolute(root.path_join(FIXTURE_FOLDER))
	var sheet: FileAccess = FileAccess.open(FIXTURE_DIR.path_join(FIXTURE_SHEET), FileAccess.WRITE)
	sheet.store_string("%PDF-1.4\n")
	sheet.close()
	return root


func _listed(files: ItemList, item_name: String) -> int:
	for index: int in files.item_count:
		if files.get_item_text(index) == item_name:
			return index
	return -1


## The dialog only refreshes its list while it is on screen.
func _shown_in(directory: String) -> ItemList:
	MobileFileDialog.open(dialog, CodeSheet.DEFAULT_FILE_NAME)
	dialog.current_dir = directory
	await get_tree().process_frame
	await get_tree().process_frame
	return MobileFileDialog.file_list(dialog)


func test_it_saves_to_the_filesystem_and_offers_the_job_to_the_platform() -> void:
	# ACCESS_RESOURCES, the default, cannot be written to in an exported build and
	# is also refused by Android's native picker.
	assert_eq(dialog.access, FileDialog.ACCESS_FILESYSTEM)
	assert_true(dialog.use_native_dialog,
		"Android and the three desktops have their own; iOS and the web fall back to this one")
	assert_eq(dialog.file_mode, FileDialog.FILE_MODE_SAVE_FILE)


func test_the_filter_carries_a_mime_type_for_android() -> void:
	# Android's picker filters on the MIME type and ignores the extension.
	assert_string_contains(dialog.filters[0], CodeSheet.MIME_TYPE)


func test_nothing_is_left_that_asks_a_question_the_teacher_has_not_got() -> void:
	for feature: String in ["favorites_enabled", "recent_list_enabled", "hidden_files_toggle_enabled",
			"layout_toggle_enabled", "file_sort_options_enabled", "file_filter_toggle_enabled",
			"folder_creation_enabled", "deleting_enabled"]:
		assert_false(dialog.get(feature) as bool, "%s should be off" % feature)
	assert_true(dialog.overwrite_warning_enabled, "writing over last year's sheet is worth a question")


func test_the_two_controls_needed_to_move_around_survive() -> void:
	var up: Control = _header().get_child(2) as Control
	var path: Control = _header().get_child(5) as Control
	assert_true(up is Button, "position 2 should be the button that goes up")
	assert_true(up.visible, "the only way up must stay")
	assert_true(path is LineEdit, "position 5 should be the path")
	assert_true(path.visible, "the only thing that says where you are must stay")


func test_the_editor_furniture_around_them_is_hidden() -> void:
	for position: int in [0, 1, 3, 4, 6, 7]:
		var control: Control = _header().get_child(position) as Control
		assert_false(control.visible, "header control %d should be hidden" % position)


func test_the_button_that_was_kept_really_does_go_up() -> void:
	# The strongest guard on those positions: hiding the neighbours of the wrong
	# control would leave the teacher with no way to leave a folder at all.
	var start: String = OS.get_user_data_dir()
	dialog.current_dir = start
	(_header().get_child(2) as Button).pressed.emit()

	assert_ne(dialog.current_dir, start, "it should have moved")
	assert_true(start.begins_with(dialog.current_dir), "and moved towards the root, not away")


func test_the_file_list_is_found_where_the_layout_says_it_is() -> void:
	assert_not_null(MobileFileDialog.file_list(dialog))


func test_the_list_is_never_smaller_or_dimmer_than_the_text_around_it() -> void:
	# The regression this is here for: the size used to be written down in
	# MobileFileDialog, which meant it could be -- and was -- smaller than the theme
	# the screen turned out to be using. On the settings screen that theme draws at
	# 58 and the hardcoded figure was 24, so the one part of the dialog a teacher
	# reads was a third the size of everything around it, in 65% grey.
	var confirm: Button = dialog.get_ok_button()
	MobileFileDialog.open(dialog, CodeSheet.DEFAULT_FILE_NAME)
	var files: ItemList = MobileFileDialog.file_list(dialog)

	assert_eq(files.get_theme_font_size("font_size"), confirm.get_theme_font_size("font_size"),
		"the rows read like the button under them, in whichever theme is in force")
	assert_eq(files.get_theme_color("font_color"), confirm.get_theme_color("font_color"),
		"no theme here gives ItemList a colour, so it falls back to the engine's grey")


func test_the_row_icons_keep_up_with_the_names_beside_them() -> void:
	# The engine pins them to the size of its own 16px glyph, whatever the text does.
	MobileFileDialog.open(dialog, CodeSheet.DEFAULT_FILE_NAME)
	var files: ItemList = MobileFileDialog.file_list(dialog)
	var glyph: Texture2D = dialog.get_theme_icon("file", "FileDialog")

	assert_almost_eq(files.icon_scale * glyph.get_width(),
		float(dialog.get_ok_button().get_theme_font_size("font_size")), 1.0)


func test_the_navigation_button_is_sized_by_hand_having_no_text_to_size_it() -> void:
	MobileFileDialog.open(dialog, CodeSheet.DEFAULT_FILE_NAME)
	var up: Button = _header().get_child(2) as Button

	assert_eq(up.custom_minimum_size.x, MobileFileDialog.NAVIGATION_BUTTON_SIZE)
	assert_true(up.expand_icon, "icon_max_width is a ceiling and will not lift a small icon")


func test_the_caption_above_the_list_is_hidden_with_its_toggles() -> void:
	var caption: Control = dialog.get_vbox().get_child(1).get_child(1).get_child(0) as Control
	assert_false(caption.visible, "a caption and a row of switched-off toggles")


func test_the_name_can_still_be_typed_but_the_format_cannot_be_chosen() -> void:
	var typed: int = 0
	var offered: int = 0
	for child: Node in _name_row().get_children():
		if child is LineEdit and (child as LineEdit).visible:
			typed += 1
		if child is OptionButton and (child as OptionButton).visible:
			offered += 1
	assert_eq(typed, 1, "the name is the one thing this row is for")
	assert_eq(offered, 0, "a menu of one format asks a question with a single answer")


func test_a_second_format_gets_its_menu_back() -> void:
	var choice: FileDialog = FileDialog.new()
	add_child_autofree(choice)
	choice.add_filter("*.pdf", "pdf", "application/pdf")
	choice.add_filter("*.csv", "csv", "text/csv")
	MobileFileDialog.configure(choice)

	var offered: int = 0
	for child: Node in (choice.get_vbox().get_child(1).get_child(1).get_child(3) as HBoxContainer).get_children():
		if child is OptionButton and (child as OptionButton).visible:
			offered += 1
	assert_eq(offered, 1, "with two formats the menu is a real question")


func test_the_two_words_the_engine_supplies_are_not_left_in_english() -> void:
	# FileDialog writes "Cancel" and "File:" itself, from literals Godot only
	# translates for the editor, and the project dictionary has no entry for either.
	var confirm: Button = dialog.get_ok_button()
	var cancel: Button = null
	for sibling: Node in confirm.get_parent().get_children():
		if sibling is Button and sibling != confirm:
			cancel = sibling as Button
	assert_not_null(cancel, "there is a Cancel button beside the confirm one")
	assert_eq(cancel.text, TranslationServer.translate("CANCEL"))

	var caption: Label = _name_row().get_child(0) as Label
	assert_eq(caption.text, TranslationServer.translate("NAME"),
		"a colon placed by language is not worth assembling here")


func test_the_list_can_take_the_focus_that_would_otherwise_raise_a_keyboard() -> void:
	# On a phone the name field takes focus on opening, and focus is what brings the
	# on-screen keyboard up over the list. open() hands focus to the list instead,
	# which only works while the list accepts it.
	var files: ItemList = MobileFileDialog.file_list(dialog)
	assert_ne(files.focus_mode, Control.FOCUS_NONE, "the list has to be able to hold focus")
	files.grab_focus()
	assert_eq(dialog.gui_get_focus_owner(), files as Control)


func test_the_window_is_given_room_and_an_edge_so_it_reads_as_a_window() -> void:
	# The theme's stylebox insets an AcceptDialog's contents by 0, 0, 0, 2, which put
	# the file list and the buttons hard against the edges of the window: nothing
	# separated it from whatever the screen was drawing behind it.
	MobileFileDialog.open(dialog, CodeSheet.DEFAULT_FILE_NAME)

	# With no theme type given, so the dialog's own override is what comes back:
	# naming a type skips local overrides and would return the theme's copy.
	var framed: StyleBoxFlat = dialog.get_theme_stylebox("panel") as StyleBoxFlat
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		assert_eq(framed.get_margin(side), MobileFileDialog.PANEL_INSET,
			"room on every side, not just where the theme happened to leave some")
	assert_gt(framed.border_width_top, 0, "and an edge, taken from the confirm button")


func test_the_theme_own_stylebox_is_left_exactly_as_it_was_found() -> void:
	# It is one instance, shared with every ConfirmPopup in the game. Editing it in
	# place instead of duplicating it would re-style all of them from here.
	var from_theme: StyleBoxFlat = dialog.get_theme_stylebox("panel", "AcceptDialog") as StyleBoxFlat
	var untouched: float = from_theme.get_margin(SIDE_LEFT)

	MobileFileDialog.open(dialog, CodeSheet.DEFAULT_FILE_NAME)

	assert_ne(dialog.get_theme_stylebox("panel"), from_theme as StyleBox,
		"the dialog should be drawn with a copy of its own")
	assert_eq(from_theme.get_margin(SIDE_LEFT), untouched, "and the original should be unchanged")


func test_it_is_drawn_at_the_scale_of_the_theme_and_not_blown_up_on_top_of_it() -> void:
	# It was scaled 2x once. The screens that show it carry a theme whose text is
	# already sized for this canvas, so that doubled 58 pixels to 116: the buttons ran
	# into the edges of the window and the file list came out a three-row strip.
	assert_eq(dialog.content_scale_factor, 1.0)
	assert_true(dialog.borderless, "the title bar is drawn at a fixed size of the embedder's")
	assert_eq(dialog.display_mode, FileDialog.DISPLAY_LIST, "a list shows a long name in full")


func test_one_tap_on_a_folder_goes_into_it() -> void:
	# The engine navigates on item_activated, which is a double click: no gesture at
	# all on a touch screen, and nothing anybody guesses with a mouse either. Without
	# this the dialog looks like something that cannot be browsed -- there is not
	# even a ".." row to hint otherwise.
	var fixture: String = _fixture()
	var files: ItemList = await _shown_in(fixture)
	var folder: int = _listed(files, FIXTURE_FOLDER)
	assert_ne(folder, -1, "the folder should be in the list")

	files.item_selected.emit(folder)

	assert_eq(dialog.current_dir, fixture.path_join(FIXTURE_FOLDER), "one tap should be enough")


func test_one_tap_on_a_file_takes_its_name_rather_than_writing_over_it() -> void:
	# Activating a file in save mode confirms the save outright, so the same
	# forwarding must not apply to it: tapping last year's sheet offers its name.
	var files: ItemList = await _shown_in(_fixture())
	var sheet: int = _listed(files, FIXTURE_SHEET)
	assert_ne(sheet, -1, "the PDF should be in the list, the filter matches it")

	files.item_selected.emit(sheet)

	assert_eq(dialog.get_line_edit().text, FIXTURE_SHEET, "its name should be offered")
	assert_true(dialog.visible, "and nothing should have been written yet")


func test_it_opens_on_documents_the_first_time_and_stays_put_after() -> void:
	MobileFileDialog.open(dialog, CodeSheet.DEFAULT_FILE_NAME)
	assert_eq(dialog.current_dir, OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS),
		"the folder a teacher looks in for something they saved")

	var fixture: String = _fixture()
	dialog.current_dir = fixture
	MobileFileDialog.open(dialog, CodeSheet.DEFAULT_FILE_NAME)

	assert_eq(dialog.current_dir, fixture, "a second export returns where the first one went")
