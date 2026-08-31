extends GutTest
## The screen that closes registration.
##
## Its whole job is answering "where are my codes?", so both answers are worth
## pinning: the folder when the sheet was saved, and where to find them later
## when it was not.

const SCENE: String = "res://sources/menus/register/account_created.tscn"
const REFERENCE_VIEWPORT: Vector2i = Vector2i(2560, 1800)

var original_path: String


func before_each() -> void:
	original_path = AccountCreated.saved_codes_path


func after_each() -> void:
	# It is static, so it outlives the screen and would leak into the next test.
	AccountCreated.saved_codes_path = original_path


func _mounted(saved_path: String) -> AccountCreated:
	AccountCreated.saved_codes_path = saved_path
	var viewport: SubViewport = SubViewport.new()
	viewport.size = REFERENCE_VIEWPORT
	add_child_autofree(viewport)
	var screen: AccountCreated = (load(SCENE) as PackedScene).instantiate()
	viewport.add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	return screen


func test_it_says_the_account_was_created() -> void:
	var screen: AccountCreated = await _mounted("")

	var headline: Label = screen.get_node("Content/Headline")
	assert_eq(headline.text, "ACCOUNT_CREATED")
	assert_eq(headline.theme_type_variation, MenuTheme.VARIATION_TITLE)
	assert_ne(tr(headline.text), headline.text, "the headline should be translated")


func test_the_badge_is_where_the_mockup_puts_it() -> void:
	var screen: AccountCreated = await _mounted("")

	var badge: Panel = screen.get_node("Content/Badge")
	assert_almost_eq(badge.global_position.y, float(Design.BADGE_TOP), 2.0)
	assert_eq(badge.size, Vector2(Design.BADGE_SIZE, Design.BADGE_SIZE))
	assert_almost_eq(badge.global_position.x + badge.size.x / 2.0,
		REFERENCE_VIEWPORT.x / 2.0, 2.0, "it should be centred")

	var box: StyleBoxFlat = badge.get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(box.bg_color, Color.WHITE, "a white disc")
	assert_eq(box.corner_radius_top_left, floori(float(Design.BADGE_SIZE) / 2), "and round, not square")
	assert_eq((screen.get_node("%Tick") as TextureRect).self_modulate, Design.PURPLE,
		"the tick artwork is white, so it is tinted to read on the disc")


func test_a_saved_sheet_names_its_folder_and_offers_to_open_it() -> void:
	var screen: AccountCreated = await _mounted("user://Codes.pdf")
	var link: Button = screen.get_node("%OpenFolderButton")

	assert_true(link.is_visible_in_tree(), "the folder should be offered")
	assert_false((screen.get_node("%CodesNote") as Label).is_visible_in_tree(),
		"and not alongside the fallback message")
	assert_false(link.text.contains("{folder}"), "the folder should have been filled in")
	assert_false(link.text.contains("user://"),
		"a Godot URI is not a folder a teacher can go and find")
	assert_string_contains(link.text,
		ProjectSettings.globalize_path("user://").trim_suffix("/"),
		"it should name the real folder")
	assert_eq(link.mouse_default_cursor_shape, Control.CURSOR_POINTING_HAND,
		"it should look like something to click")


func test_no_saved_sheet_points_at_the_settings_instead() -> void:
	var screen: AccountCreated = await _mounted("")

	var note: Label = screen.get_node("%CodesNote")
	assert_true(note.is_visible_in_tree(), "the teacher still has to be told where they are")
	assert_eq(note.text, "CODES_AVAILABLE_IN_SETTINGS")
	assert_ne(tr(note.text), note.text, "and told in their own language")
	assert_false((screen.get_node("%OpenFolderButton") as Button).is_visible_in_tree(),
		"there is no folder to open")


func test_only_one_of_the_two_messages_is_ever_shown() -> void:
	for saved_path: String in ["", "user://Codes.pdf", "content://com.android.providers.downloads.documents/document/42"]:
		var screen: AccountCreated = await _mounted(saved_path)
		var showing: int = 0
		for path: String in ["%CodesNote", "%OpenFolderButton"]:
			if (screen.get_node(path) as Control).is_visible_in_tree():
				showing += 1
		assert_eq(showing, 1, "exactly one message for saved_codes_path '%s'" % saved_path)


func test_a_document_uri_is_not_paraded_as_a_folder() -> void:
	# What Android's own picker hands back addresses the document rather than
	# describing a folder. The sheet was saved, and the picker said so at the time,
	# but there is nothing here to name -- so this screen falls back to saying the
	# codes can be had again rather than printing a URI at the teacher.
	var uri: String = "content://com.android.externalstorage.documents/document/primary%3ACodes.pdf"
	var screen: AccountCreated = await _mounted(uri)

	var note: Label = screen.get_node("%CodesNote")
	assert_true(note.is_visible_in_tree(), "it should fall back to the settings note")
	assert_eq(note.text, "CODES_AVAILABLE_IN_SETTINGS")
	assert_false((screen.get_node("%OpenFolderButton") as Button).is_visible_in_tree(),
		"there is no folder to open")


func test_the_folder_is_only_offered_where_one_can_be_opened() -> void:
	# Android and iOS sandbox their storage and have no file manager to hand off
	# to; the web export has no local filesystem at all.
	assert_eq(AccountCreated.can_show_folder(),
		not OS.has_feature("mobile") and not OS.has_feature("web"))


func test_next_leads_on_to_the_language_pack() -> void:
	assert_true(ResourceLoader.exists(AccountCreated.NEXT_SCENE_PATH),
		"the screen after this one should exist")
	var screen: AccountCreated = await _mounted("")
	var next: Button = screen.get_node("%NextButton")

	assert_false(next.disabled, "Next is the only way forward, so it must be available")
	assert_almost_eq(next.global_position.x + next.size.x,
		REFERENCE_VIEWPORT.x - Design.PAGE_MARGIN, 2.0,
		"it sits where every other screen puts it")
	assert_almost_eq(next.global_position.y + next.size.y,
		REFERENCE_VIEWPORT.y - Design.PAGE_MARGIN_BOTTOM, 2.0)


func test_registration_ends_here_rather_than_at_the_downloader() -> void:
	var register: GDScript = load("res://sources/menus/register/register.gd")
	assert_eq(register.NEXT_SCENE_PATH, SCENE,
		"the wizard should hand over to the confirmation")


func test_the_saved_path_does_not_survive_into_a_second_registration() -> void:
	# It is static, so a second run in the same session would otherwise point at
	# the first run's folder.
	AccountCreated.saved_codes_path = "user://stale.pdf"
	var wizard: Control = (load("res://sources/menus/register/register.tscn")
		as PackedScene).instantiate()
	add_child_autofree(wizard)
	await get_tree().process_frame

	assert_eq(AccountCreated.saved_codes_path, "",
		"starting the wizard should clear it")
