extends GutTest
## The student card shown on a device in settings.

const PANEL_SCENE: String = "res://sources/menus/settings/student_panel.tscn"

var panel: StudentPanel


func before_each() -> void:
	panel = (load(PANEL_SCENE) as PackedScene).instantiate()
	var student: StudentData = StudentData.new()
	student.code = 142
	panel.student_count = 1
	panel.student_data = student
	add_child_autofree(panel)
	await get_tree().process_frame


func test_the_card_is_the_designed_size() -> void:
	# It used to be an 822x500 dark board; the hand-off's card is a third of that
	# and three fit across the settings card.
	assert_eq(panel.custom_minimum_size, Vector2(Design.STUDENT_CARD_SIZE))


func test_the_card_is_the_off_white_surface() -> void:
	# It sits on the white settings card, so it has to be a shade off white to
	# read as a separate surface.
	var container: PanelContainer = panel.get_node("StudentContainer")
	assert_eq(container.theme_type_variation, MenuTheme.VARIATION_STUDENT_CARD)


func test_it_shows_the_code_as_chips_at_the_designed_size() -> void:
	var visualizer: PasswordVisualizer = panel.password_visualizer
	assert_eq(visualizer.chip_size, Design.CODE_CHIP_SIZE)
	assert_eq(visualizer.key_size, Design.CODE_CHIP_GLYPH_SIZE)
	assert_eq(visualizer.get_theme_constant("separation"), Design.CODE_CHIP_GAP)
	for index: int in 3:
		assert_eq(visualizer.panels[index].custom_minimum_size,
			Vector2(Design.CODE_CHIP_SIZE, Design.CODE_CHIP_SIZE),
			"chip %d should be pinned to the chip size" % index)


func test_pinned_chips_do_not_stretch_across_the_card() -> void:
	# The chips live in an HBoxContainer; left expanding they would spread out to
	# fill the card instead of staying a compact row of three.
	for chip: PanelContainer in panel.password_visualizer.panels:
		assert_eq(chip.size_flags_horizontal, Control.SIZE_SHRINK_CENTER,
			"a pinned chip should not expand")


func test_it_shows_the_students_code() -> void:
	assert_eq(panel.password_visualizer.password, "142")
	for index: int in 3:
		assert_not_null(panel.password_visualizer.icons[index].texture,
			"chip %d should show its symbol" % index)


func test_a_named_student_shows_their_name() -> void:
	var named: StudentPanel = (load(PANEL_SCENE) as PackedScene).instantiate()
	var student: StudentData = StudentData.new()
	student.code = 123
	student.name = "Amina"
	named.student_data = student
	add_child_autofree(named)
	await get_tree().process_frame

	assert_eq(named.name_label.text, "Amina")


func test_an_unnamed_student_is_numbered() -> void:
	assert_string_contains(panel.name_label.text, "1",
		"an unnamed student should be shown by number")


func test_the_whole_card_opens_the_student() -> void:
	# Tapping anywhere on the card opens that student's progress; a small button
	# in a corner would be a poor target on a tablet.
	var button: Button = panel.get_node("DetailsButton")
	assert_eq(button.anchor_right, 1.0, "the target should span the card")
	assert_eq(button.anchor_bottom, 1.0, "the target should span the card")

	watch_signals(panel)
	button.pressed.emit()
	assert_signal_emitted(panel, "pressed")


func test_the_cards_decoration_does_not_block_the_tap() -> void:
	# The label and chips are drawn over the button, so they must let taps past.
	for path: String in ["StudentContainer", "StudentContainer/MarginContainer",
			"StudentContainer/MarginContainer/VBoxContainer"]:
		var node: Control = panel.get_node(path)
		assert_eq(node.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"%s should let the tap through" % path)
