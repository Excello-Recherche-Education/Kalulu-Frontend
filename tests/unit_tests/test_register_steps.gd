extends GutTest
## Every registration step still loads after the base step was restyled.
##
## All nine steps are inherited scenes of base_step.tscn and address its nodes by
## name, path and unique_id. Restyling the base is therefore only safe as long as
## its node structure is untouched, and a break would not show up as an error --
## the override would silently land on the wrong node, or vanish. Hence loading
## each one and checking the parts the wizard drives.

const BASE_STEP: String = "res://sources/menus/register/steps/base_step.tscn"
const LANGUAGE_STEP: String = "res://sources/menus/register/steps/language/language_step.tscn"
# The mockups are drawn at the project's own reference resolution, so their
# measurements can be checked directly.
const REFERENCE_VIEWPORT: Vector2i = Vector2i(2560, 1800)
const STEP_SCENES: Array[String] = [
	LANGUAGE_STEP,
	"res://sources/menus/register/steps/account_type_step.tscn",
	"res://sources/menus/register/steps/teacher/method_step.tscn",
	"res://sources/menus/register/steps/teacher/devices_count_step.tscn",
	"res://sources/menus/register/steps/teacher/students_count_step.tscn",
	"res://sources/menus/register/steps/parent/players_count_step.tscn",
	"res://sources/menus/register/steps/parent/player_step.tscn",
	"res://sources/menus/register/steps/credentials_step.tscn",
	"res://sources/menus/register/steps/general_conditions_step.tscn",
	"res://sources/menus/register/steps/recap_step.tscn",
]


func test_every_step_scene_loads() -> void:
	for path: String in STEP_SCENES:
		assert_true(ResourceLoader.exists(path), "%s should exist" % path)
		var scene: PackedScene = load(path) as PackedScene
		assert_not_null(scene, "%s should load" % path.get_file())


func test_every_step_keeps_the_nodes_the_wizard_drives() -> void:
	for path: String in STEP_SCENES:
		var step: Step = (load(path) as PackedScene).instantiate()
		autofree(step)
		for node_path: String in ["%QuestionLabel", "%InfoLabel", "%FormValidator",
				"%FormBinder", "%FormContainer"]:
			assert_not_null(step.get_node_or_null(node_path),
				"%s should still have %s" % [path.get_file(), node_path])


func test_every_step_keeps_its_footer_buttons() -> void:
	for path: String in STEP_SCENES:
		var step: Step = (load(path) as PackedScene).instantiate()
		autofree(step)
		var previous: Button = step.get_node_or_null("LeftMargin/LeftContainer/BackButton")
		var next: Button = step.get_node_or_null("RightMargin/RightContainer/ValidateButton")
		assert_not_null(previous, "%s should have a Previous button" % path.get_file())
		assert_not_null(next, "%s should have a Next button" % path.get_file())


func test_the_footer_buttons_use_the_redesigned_styles() -> void:
	# Checked on the base rather than every step: a step that overrides its own
	# button, like the recap, is entitled to look different.
	var step: Step = (load(BASE_STEP) as PackedScene).instantiate()
	autofree(step)

	var previous: Button = step.get_node("LeftMargin/LeftContainer/BackButton")
	var next: Button = step.get_node("RightMargin/RightContainer/ValidateButton")
	assert_eq(previous.theme_type_variation, MenuTheme.VARIATION_SECONDARY_BUTTON)
	assert_eq(next.theme_type_variation, MenuTheme.VARIATION_PRIMARY_BUTTON)
	assert_eq(previous.custom_minimum_size, Vector2(Design.BUTTON_SIZE))
	assert_eq(next.custom_minimum_size, Vector2(Design.BUTTON_SIZE))


func test_nothing_covers_the_footer_buttons() -> void:
	# Regression: the form column was a full-width band pinned to the bottom of
	# the screen, left over from the wooden board it used to sit on. Its
	# MarginContainers default to MOUSE_FILTER_PASS, which still captures the
	# hit, so drawn last over the footer they swallowed every click on Previous
	# and Next. Nothing about that was visible -- the buttons still lit up on
	# hover -- so it takes pushing a real event to see it.
	for path: String in STEP_SCENES:
		var viewport: SubViewport = SubViewport.new()
		viewport.size = REFERENCE_VIEWPORT
		add_child_autofree(viewport)
		var step: Step = (load(path) as PackedScene).instantiate()
		viewport.add_child(step)
		await get_tree().process_frame
		await get_tree().process_frame

		for node_path: String in ["LeftMargin/LeftContainer/BackButton",
				"RightMargin/RightContainer/ValidateButton"]:
			var button: Button = step.get_node_or_null(node_path)
			if not button or not button.is_visible_in_tree():
				continue
			# Local coordinates on purpose: a headless run has a 64x64 window, so
			# the canvas transform would put the event somewhere else entirely.
			var motion: InputEventMouseMotion = InputEventMouseMotion.new()
			motion.position = button.global_position + button.size * 0.5
			viewport.push_input(motion, true)

			var hovered: Control = viewport.gui_get_hovered_control()
			assert_eq(hovered, button, "%s: %s should be the control under its own centre, not %s"
				% [path.get_file(), button.name,
				hovered.name if hovered else "nothing"])


func test_the_question_sits_on_the_background_rather_than_on_a_panel() -> void:
	# Regression: the question used to be on a wooden board, and dropping that
	# variation left the PanelContainer drawing Godot's default blue-grey square
	# panel -- a big rectangle across the top of every step.
	var step: Step = (load(BASE_STEP) as PackedScene).instantiate()
	autofree(step)

	var board: PanelContainer = step.get_node("PanelContainer")
	assert_true(board.get_theme_stylebox("panel") is StyleBoxEmpty,
		"the question board should draw nothing")


func test_the_content_is_placed_where_the_mockups_put_it() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = REFERENCE_VIEWPORT
	add_child_autofree(viewport)
	var step: Step = (load(LANGUAGE_STEP) as PackedScene).instantiate()
	viewport.add_child(step)
	await get_tree().process_frame
	await get_tree().process_frame

	# One field, so the column is exactly one field tall and sits at the height
	# every step mockup shares.
	var field: Control = step.get_node("%LanguageField")
	assert_almost_eq(field.global_position.y, float(Design.STEP_FORM_TOP), 2.0,
		"the field column should start at the mockups' height")
	assert_almost_eq(field.size.x, float(Design.CONTENT_WIDTH), 2.0,
		"the field should fill the content column")
	assert_almost_eq(field.global_position.x + field.size.x / 2.0,
		REFERENCE_VIEWPORT.x / 2.0, 2.0, "the field should be centred")
	assert_almost_eq(field.size.y, float(Design.FIELD_HEIGHT), 2.0)

	# The question block hangs above the field rather than being centred with it,
	# which is what keeps the field at the same height on every step however long
	# the question runs. Measured on the block, not the title: the title is its
	# top child, and the note under it may or may not be there.
	var block: Control = (step.get_node("%QuestionLabel") as Label).get_parent()
	assert_almost_eq(block.global_position.y + block.size.y,
		float(Design.STEP_FORM_TOP - Design.STEP_QUESTION_GAP), 2.0,
		"the question block should end one gap above the field")
	assert_eq((step.get_node("%QuestionLabel") as Label).horizontal_alignment,
		HORIZONTAL_ALIGNMENT_CENTER, "the question should be centred over the field")

	var previous: Button = step.get_node("LeftMargin/LeftContainer/BackButton")
	assert_almost_eq(previous.global_position.x, float(Design.PAGE_MARGIN), 2.0)
	assert_almost_eq(previous.global_position.y + previous.size.y,
		REFERENCE_VIEWPORT.y - Design.PAGE_MARGIN_BOTTOM, 2.0)


func test_the_language_step_asks_its_question_only_once() -> void:
	# The field used to carry a "Language" label of its own to its left, which
	# repeated the title and pushed the field off centre. The mockups have the
	# title do the asking and give the field the whole column.
	var step: Step = (load(LANGUAGE_STEP) as PackedScene).instantiate()
	autofree(step)

	assert_eq(step.question, "SELECT_A_LANGUAGE",
		"the title should ask for a language, not just name the field")
	assert_null(step.find_child("LanguageLabel", true, false),
		"the field should not repeat the title next to itself")


func test_the_steps_the_wizard_branches_on_still_carry_their_names() -> void:
	# register.gd matches step_name to decide which steps to append next. Only
	# the four branch points need a name -- the rest just move on, and leaving
	# theirs blank is fine -- but losing one of these four would silently drop a
	# whole branch of the flow.
	var seen: Array[String] = []
	for path: String in STEP_SCENES:
		var step: Step = (load(path) as PackedScene).instantiate()
		autofree(step)
		seen.append(step.step_name)

	for branch: String in ["language", "type", "devices", "players"]:
		assert_has(seen, branch,
			"the wizard branches on '%s', so a step must carry it" % branch)
