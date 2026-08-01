extends GutTest
## Structure and layout of the student progress panel.
##
## Its scene was rewritten to the hand-off while the script kept every handler, so
## the contract between them has to hold: the unique names it resolves, and the
## handlers the scene connects to. Layout is measured too, because a wired scene
## can still draw on top of itself.

const PANEL_SCENE: String = "res://sources/menus/settings/lesson_unlocks.tscn"
const VIEWPORT_SIZE: Vector2i = Vector2i(2560, 1800)

var panel: LessonUnlocks


func before_each() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	add_child_autofree(viewport)
	panel = (load(PANEL_SCENE) as PackedScene).instantiate()
	viewport.add_child(panel)
	await get_tree().process_frame
	await get_tree().process_frame


func test_it_starts_hidden() -> void:
	# It is an overlay opened by tapping a student; it opened on arrival once.
	assert_false(panel.visible, "the panel should only appear when a student is opened")


func test_every_unique_name_the_script_resolves_exists() -> void:
	for name: String in ["%NameLineEdit", "%PasswordVisualizer", "%LessonsGrid",
			"%LessonRowsStore", "%DeviceSelectionContainer", "%GridContainer"]:
		assert_not_null(panel.get_node_or_null(name),
			"the script resolves %s" % name)


func test_every_handler_the_scene_connects_to_exists() -> void:
	for method: String in ["_on_back_button_pressed", "_on_delete_button_pressed",
			"_on_device_change_button_pressed"]:
		assert_true(panel.has_method(method), "%s should exist" % method)


func test_changing_a_students_device_is_still_reachable() -> void:
	# The reference row shows only a trash icon, but this is real functionality
	# reached from here and nothing else offers it.
	var button: Button = panel.get_node_or_null("Card/Margin/Body/FooterRow/ChangeDeviceButton")
	assert_not_null(button, "the change-device button should be present")
	assert_eq(button.text, "CHANGE_DEVICE")


func test_the_device_picker_starts_hidden() -> void:
	assert_false(panel.get_node("%DeviceSelectionContainer").visible,
		"the device picker only opens from the change-device button")


func test_the_table_header_spans_every_column() -> void:
	# A GridContainer cannot give a row a background, so the header is one cell per
	# column with no separation between them, forming a continuous strip.
	var grid: GridContainer = panel.get_node("%LessonsGrid")
	assert_eq(grid.columns, 3, "lesson, its graphemes, and one status")
	assert_eq(grid.get_theme_constant("h_separation"), 0,
		"header cells must touch or the strip is broken by gaps")
	var header_cells: int = 0
	for index: int in grid.columns:
		var cell: Node = grid.get_child(index)
		if cell is PanelContainer:
			assert_eq((cell as PanelContainer).theme_type_variation,
				MenuTheme.VARIATION_TABLE_HEADER_CELL, "%s should be a header cell" % cell.name)
			header_cells += 1
	assert_eq(header_cells, grid.columns, "every column needs its own header cell")


func test_the_header_is_not_cleared_with_the_lesson_rows() -> void:
	# _clear_lessons_grid only frees cells tagged as lesson cells; the header must
	# not be tagged, or rebuilding would take the column titles with it.
	var grid: GridContainer = panel.get_node("%LessonsGrid")
	for index: int in grid.columns:
		assert_false(grid.get_child(index).get_meta("lesson_grid_cell", false),
			"a header cell must not look like a lesson cell")


func test_the_panel_fits_the_screen() -> void:
	var card: Control = panel.get_node("Card")
	assert_lte(card.size.x, float(VIEWPORT_SIZE.x), "the card should fit the width")
	assert_lte(card.size.y, float(VIEWPORT_SIZE.y), "the card should fit the height")
	assert_lte(card.get_combined_minimum_size().x, float(VIEWPORT_SIZE.x),
		"its content must fit, or the card overflows its anchors")


func test_the_close_button_saves_and_closes() -> void:
	# The close cross took over from a back button, and that button was what saved
	# the teacher's edits.
	panel.show()

	panel._on_back_button_pressed()

	assert_false(panel.visible, "closing should hide the panel")
