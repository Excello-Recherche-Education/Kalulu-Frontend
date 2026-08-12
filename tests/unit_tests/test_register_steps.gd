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


func test_every_field_fills_the_content_column() -> void:
	# The mockups give each field the whole centre column and let the title above
	# ask the question, instead of putting a label beside every field. A leftover
	# label both repeats the title and pushes the field off centre, so measuring
	# the fields is enough to catch one.
	for path: String in STEP_SCENES:
		var viewport: SubViewport = SubViewport.new()
		viewport.size = REFERENCE_VIEWPORT
		add_child_autofree(viewport)
		var step: Step = (load(path) as PackedScene).instantiate()
		viewport.add_child(step)
		await get_tree().process_frame
		await get_tree().process_frame

		var expected_left: float = (REFERENCE_VIEWPORT.x - Design.CONTENT_WIDTH) / 2.0
		for field: Control in _fields_of(step):
			assert_almost_eq(field.size.x, float(Design.CONTENT_WIDTH), 2.0,
				"%s: %s should fill the content column" % [path.get_file(), field.name])
			assert_almost_eq(field.global_position.x, expected_left, 2.0,
				"%s: %s should start at the column's left edge" % [path.get_file(), field.name])
			assert_almost_eq(field.size.y, float(Design.FIELD_HEIGHT), 2.0,
				"%s: %s should be a field height tall" % [path.get_file(), field.name])


func _fields_of(step: Step) -> Array[Control]:
	var fields: Array[Control] = []
	# Owned nodes only: a SpinBox builds a LineEdit of its own and a dropdown's
	# PopupMenu keeps a hidden one for type-ahead search, and neither is a field
	# the layout is meant to place.
	for node: Node in (step.get_node("%FormContainer") as Control).find_children("*", "", true, true):
		if node is LineEdit or node is OptionButton or node is SpinBox:
			fields.append(node as Control)
	return fields


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


# --- Conditions step ----------------------------------------------------------
const CONDITIONS_STEP: String = "res://sources/menus/register/steps/general_conditions_step.tscn"


func _mounted_conditions_step() -> Step:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = REFERENCE_VIEWPORT
	add_child_autofree(viewport)
	var step: Step = (load(CONDITIONS_STEP) as PackedScene).instantiate()
	viewport.add_child(step)
	await get_tree().process_frame
	await get_tree().process_frame
	return step


func test_the_conditions_sit_on_a_card_under_a_heading() -> void:
	# Regression: the terms were white text straight on the background with no
	# heading and no card, where the mockup puts them on a white card titled
	# "Conditions". The card is the base step's question board reused, and the
	# base blanks that panel's stylebox -- a local override beats a type
	# variation, so the Card variation alone would not have shown.
	var step: Step = await _mounted_conditions_step()

	var card: PanelContainer = step.get_node("PanelContainer")
	var box: StyleBox = card.get_theme_stylebox("panel")
	assert_true(box is StyleBoxFlat, "the terms should sit on a real card")
	assert_eq((box as StyleBoxFlat).bg_color, Color.WHITE, "the card should be white")
	assert_almost_eq(card.global_position.y, float(Design.STEP_CARD_TOP), 2.0)
	assert_almost_eq(card.global_position.y + card.size.y, float(Design.STEP_CARD_BOTTOM), 2.0)
	assert_almost_eq(card.global_position.x, float(Design.PAGE_MARGIN), 2.0)
	assert_almost_eq(card.size.x, REFERENCE_VIEWPORT.x - 2.0 * Design.PAGE_MARGIN, 2.0)

	var title: Label = step.get_node("Title")
	assert_eq(title.text, "CONDITIONS", "the card should be titled")
	assert_eq(title.theme_type_variation, MenuTheme.VARIATION_TITLE)
	assert_lt(title.global_position.y + title.size.y, card.global_position.y,
		"the heading belongs above the card, not inside it")


func test_the_terms_are_legible_on_the_card() -> void:
	# White on white would have been the obvious way to get this wrong.
	var step: Step = await _mounted_conditions_step()
	var terms: RichTextLabel = step.get_node("%ConditionsLabel")

	assert_eq(terms.get_theme_color("default_color"), Design.GREY_DARK,
		"dark text, because the card is white")
	assert_gt(terms.size.y, 400.0, "the terms should get most of the card")


func test_the_tick_box_fills_in_when_the_terms_are_accepted() -> void:
	var step: Step = await _mounted_conditions_step()
	var box: Button = step.get_node("%Accept")
	var label: Label = step.get_node("%AcceptLabel")

	assert_eq(box.custom_minimum_size, Vector2(Design.CHECKBOX_SIZE, Design.CHECKBOX_SIZE))
	assert_true(box.toggle_mode, "it has to hold its state")
	assert_null(box.icon, "no tick before it is ticked")
	assert_eq(label.get_theme_color("font_color"), Design.GREY_DARK)
	# Outlined, not filled: a pale filled square all but disappears against the
	# white card, which is what made the box hard to find in the first place.
	for state: String in ["normal", "pressed"]:
		var style: StyleBoxFlat = box.get_theme_stylebox(state) as StyleBoxFlat
		assert_eq(style.border_color, Color.BLACK, "the %s box is outlined in black" % state)
		assert_eq(style.border_width_left, Design.CHECKBOX_BORDER)
		assert_eq(style.bg_color.a, 0.0, "and empty, so only the outline shows")
	assert_eq(box.get_theme_color("icon_pressed_color"), Design.SUCCESS,
		"the tick inside it is green")

	box.button_pressed = true
	step._on_accept_pressed()

	assert_not_null(box.icon, "the tick should appear once accepted")
	assert_eq(label.get_theme_color("font_color"), Design.PURPLE,
		"the wording turns purple with the box, as in the mockup")


func test_going_back_clears_the_tick_and_its_mark() -> void:
	# button_pressed does not emit pressed, so an untick done in code has to
	# repaint the box itself or the tick stays drawn on an unticked box.
	var step: Step = await _mounted_conditions_step()
	var box: Button = step.get_node("%Accept")
	box.button_pressed = true
	step._on_accept_pressed()

	step._on_back()

	assert_false(box.button_pressed)
	assert_null(box.icon, "the tick should go with the state")
	assert_eq((step.get_node("%AcceptLabel") as Label).get_theme_color("font_color"),
		Design.GREY_DARK)


func test_the_wizard_will_not_move_on_until_the_terms_are_accepted() -> void:
	var step: Step = await _mounted_conditions_step()
	var error: Label = step.get_node("%AcceptError")

	assert_false(step._on_next(), "an unticked box should hold the wizard here")
	assert_true(error.visible, "and say why")

	(step.get_node("%Accept") as Button).button_pressed = true
	step._on_accept_pressed()

	assert_true(step._on_next())
	assert_false(error.visible)


func test_the_previous_button_is_translated() -> void:
	# Regression: the base step's label was the literal "PREVIOUS", which is not
	# a key, so every step showed the English word next to a translated "Next".
	var step: Step = (load(BASE_STEP) as PackedScene).instantiate()
	autofree(step)
	var previous: Button = step.get_node("LeftMargin/LeftContainer/BackButton")

	assert_ne(tr(previous.text), previous.text,
		"the back button's label should be a translation key, not a word")


func test_clicking_the_wording_ticks_the_box() -> void:
	# The sentence is part of the control, not a caption beside it: a 90px square
	# is a small target next to the words that explain what it means.
	var step: Step = await _mounted_conditions_step()
	var box: Button = step.get_node("%Accept")
	var label: Label = step.get_node("%AcceptLabel")

	assert_eq(label.mouse_filter, Control.MOUSE_FILTER_STOP,
		"a Label ignores the mouse by default, so it would never see the click")
	assert_eq(label.mouse_default_cursor_shape, Control.CURSOR_POINTING_HAND,
		"and it should look clickable")

	_click(step, label)
	assert_true(box.button_pressed, "clicking the wording should tick the box")
	assert_not_null(box.icon, "and mark it")

	_click(step, label)
	assert_false(box.button_pressed, "clicking it again should untick it")
	assert_null(box.icon)


## Clicks the centre of `target`, the way a finger would.
func _click(step: Step, target: Control) -> void:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = target.global_position + target.size * 0.5
	# Local coordinates: a headless run has a 64x64 window, so the canvas
	# transform would otherwise put the event somewhere else entirely.
	step.get_viewport().push_input(click, true)


# --- Recap step ---------------------------------------------------------------
const RECAP_STEP: String = "res://sources/menus/register/steps/recap_step.tscn"


## The recap, filled in with an account of `devices` devices, mounted and laid out.
func _mounted_recap_step(devices: int) -> RecapStep:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = REFERENCE_VIEWPORT
	add_child_autofree(viewport)
	var step: RecapStep = (load(RECAP_STEP) as PackedScene).instantiate()
	viewport.add_child(step)

	var settings: TeacherSettings = TeacherSettings.new()
	settings.email = "teacher@example.org"
	settings.account_type = TeacherSettings.AccountType.TEACHER
	var code: int = 0
	for device: int in range(1, devices + 1):
		var students: Array[StudentData] = []
		for _index: int in 4:
			var student: StudentData = StudentData.new()
			student.code = TeacherSettings.AVAILABLE_CODES[code]
			students.append(student)
			code += 1
		settings.students[device] = students
	step.data = settings
	step.on_enter()
	await get_tree().process_frame
	await get_tree().process_frame
	return step


func test_the_recap_sits_on_a_card_under_a_heading() -> void:
	# Regression: the summary was white text straight on the background with no
	# card, and no way to keep the codes.
	var step: RecapStep = await _mounted_recap_step(1)

	var card: PanelContainer = step.get_node("PanelContainer")
	var box: StyleBox = card.get_theme_stylebox("panel")
	assert_true(box is StyleBoxFlat, "the summary should sit on a real card")
	assert_eq((box as StyleBoxFlat).bg_color, Color.WHITE)
	assert_almost_eq(card.global_position.y, float(Design.STEP_CARD_TOP), 2.0)
	assert_almost_eq(card.global_position.y + card.size.y, float(Design.STEP_CARD_BOTTOM), 2.0)

	assert_eq((step.get_node("Title") as Label).text, "REGISTRATION_SUMMARY")
	assert_eq((step.get_node("%Email") as Label).get_theme_color("font_color"),
		Design.GREY_DARK, "dark text, because the card is white")


func test_the_recap_offers_to_save_the_codes() -> void:
	var step: RecapStep = await _mounted_recap_step(1)
	var save: Button = step.get_node("%SaveAllCodesButton")

	assert_true(save.is_visible_in_tree(), "the export has to be on this screen")
	assert_eq(save.text, "SAVE_ALL_CODES")
	assert_eq(save.theme_type_variation, MenuTheme.VARIATION_PRIMARY_BUTTON,
		"it is the action the mockup highlights")
	var card: PanelContainer = step.get_node("PanelContainer")
	assert_almost_eq(save.global_position.x + save.size.x,
		card.global_position.x + card.size.x - Design.STEP_CARD_PADDING.x, 4.0,
		"the mockup puts it at the card's right edge")


func test_confirm_waits_until_the_codes_have_been_asked_for() -> void:
	# The codes are the only way a child logs in, and past this screen the sheet
	# is several taps deep in Settings.
	var step: RecapStep = await _mounted_recap_step(1)
	var confirm: Button = step.get_node("RightMargin/RightContainer/ValidateButton")

	assert_true(confirm.disabled, "Confirm should not be available yet")
	assert_eq((confirm.get_theme_stylebox("disabled") as StyleBoxFlat).bg_color,
		Design.GREY_LIGHT, "and should look unavailable, as the mockup shows it")

	step._on_save_all_codes_button_pressed()
	step.export_codes_file_dialog.hide()

	assert_false(confirm.disabled, "asking for the sheet should open Confirm up")


func test_cancelling_the_save_dialog_still_lets_the_teacher_continue() -> void:
	# Asking is what counts. Whether the save was seen through is the teacher's
	# business, and holding the wizard over it would trap them on the last step.
	var step: RecapStep = await _mounted_recap_step(1)

	step._on_save_all_codes_button_pressed()
	step.export_codes_file_dialog.hide()

	assert_true(step.codes_requested)
	assert_false((step.get_node("RightMargin/RightContainer/ValidateButton") as Button).disabled)


func test_the_students_are_shown_as_the_same_cards_as_everywhere_else() -> void:
	var step: RecapStep = await _mounted_recap_step(2)
	var sections: Array[Node] = (step.get_node("%RecapContainer") as Control).get_children()

	assert_eq(sections.size(), 2, "one section per device")
	var grid: GridContainer = (sections[0] as Node).get_node("%StudentsContainer")
	assert_eq(grid.columns, Design.STUDENT_CARD_COLUMNS, "three cards per row, as in settings")
	assert_eq(grid.get_theme_constant("h_separation"), Design.STUDENT_CARD_GAP)
	assert_eq((grid.get_child(0) as Control).size, Vector2(Design.STUDENT_CARD_SIZE),
		"the same student card the rest of the app uses")


func test_the_recap_can_be_scrolled_when_there_are_more_students_than_fit() -> void:
	var step: RecapStep = await _mounted_recap_step(4)
	var scroll: ScrollContainer = step.get_node("%RecapScroll")
	var card: PanelContainer = step.get_node("PanelContainer")

	assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED,
		"the cards wrap, so there is nothing to scroll sideways")
	assert_lte(scroll.global_position.y + scroll.size.y,
		card.global_position.y + card.size.y + 1.0, "the scroller stays inside the card")
	assert_gt((step.get_node("%RecapContainer") as Control).size.y, scroll.size.y,
		"four devices should give it something to scroll")


# --- An export only counts for the codes it printed -----------------------------
## Walks a two-device teacher account to its recap, filling both device steps.
func _wizard_at_the_recap() -> Control:
	var wizard: Control = (load("res://sources/menus/register/register.tscn")
		as PackedScene).instantiate()
	add_child_autofree(wizard)
	await get_tree().process_frame

	wizard._go_to_step(1)
	wizard.register_data.account_type = TeacherSettings.AccountType.TEACHER
	await wizard._on_step_completed(wizard.current_steps[1])
	wizard._go_to_step(3)
	wizard.register_data.devices_count = 2
	await wizard._on_step_completed(wizard.current_steps[3])

	for step_index: int in [4, 5]:
		wizard._go_to_step(step_index)
		var device_step: StudentsCountStep = wizard.current_steps[step_index]
		device_step.students_count_field.value = 2
		device_step._on_next()

	wizard._go_to_step(wizard.current_steps.size() - 1)
	return wizard


func test_going_back_through_a_students_step_keeps_its_codes() -> void:
	# Regression: the step used to rebuild that device's students from scratch, and
	# a code is drawn at random -- so simply passing back through the question
	# reissued every code on the device, invalidating a sheet already printed.
	var wizard: Control = await _wizard_at_the_recap()
	var recap: RecapStep = wizard.current_steps[wizard.current_steps.size() - 1]
	var before: String = recap.sheet_fingerprint()

	wizard._go_to_step(4)
	var device_step: StudentsCountStep = wizard.current_steps[4]
	# What the step reconciles against: re-entering must show the count the teacher
	# gave, or moving on would trim the device down to the field's default.
	assert_eq(device_step.students_count_field.value, 2.0,
		"the question comes back answered")
	device_step._on_next()

	assert_eq(recap.sheet_fingerprint(), before,
		"the answer did not change, so neither should the codes")


func test_asking_for_one_more_student_leaves_the_others_alone() -> void:
	# Only the difference is drawn: the students already entered keep their codes,
	# so a teacher who miscounted does not have to reprint the whole device.
	var wizard: Control = await _wizard_at_the_recap()
	var kept: String = _codes_of(wizard, 1)

	wizard._go_to_step(4)
	var device_step: StudentsCountStep = wizard.current_steps[4]
	device_step.students_count_field.value = 3
	device_step._on_next()

	var students: Array[StudentData] = wizard.register_data.students[1]
	assert_eq(students.size(), 3, "the third student was added")
	assert_eq("%d,%d" % [students[0].code, students[1].code], kept,
		"and the first two kept the codes they were given")


func test_asking_for_fewer_students_gives_their_codes_back() -> void:
	# The pool is one fixed set for the whole account, so a code stops being taken
	# the moment its student goes.
	var wizard: Control = await _wizard_at_the_recap()
	var students: Array[StudentData] = wizard.register_data.students[1]
	var kept: int = students[0].code
	var dropped: int = students[1].code

	wizard._go_to_step(4)
	var device_step: StudentsCountStep = wizard.current_steps[4]
	device_step.students_count_field.value = 1
	device_step._on_next()

	students = wizard.register_data.students[1]
	assert_eq(students.size(), 1, "the device is down to one student")
	assert_eq(students[0].code, kept, "who keeps the code they were given")
	var still_taken: Array[int] = []
	for device: int in wizard.register_data.students:
		for student: StudentData in wizard.register_data.students[device]:
			still_taken.append(student.code)
	assert_false(still_taken.has(dropped), "the code of the student who went is free again")


func test_answering_the_device_question_the_same_way_changes_nothing() -> void:
	var wizard: Control = await _wizard_at_the_recap()
	var recap: RecapStep = wizard.current_steps[wizard.current_steps.size() - 1]
	var before: String = recap.sheet_fingerprint()
	var step_count: int = wizard.current_steps.size()

	wizard._go_to_step(3)
	await wizard._on_step_completed(wizard.current_steps[3])

	assert_true(is_instance_valid(recap), "the steps it already walked should not be rebuilt")
	assert_eq(wizard.current_steps.size(), step_count, "and the queue still fits the answer")
	assert_eq((wizard.current_steps[wizard.current_steps.size() - 1] as RecapStep).sheet_fingerprint(),
		before, "nobody's code changed")


func test_asking_for_fewer_devices_drops_the_ones_removed() -> void:
	# Regression: the wizard freed the extra device's step but left its students in
	# the registration data, so the recap counted a device the teacher had just
	# removed -- and the account would have been created with it.
	var wizard: Control = await _wizard_at_the_recap()
	assert_eq(wizard.register_data.students.size(), 2, "two devices to start with")

	wizard._go_to_step(3)
	wizard.register_data.devices_count = 1
	await wizard._on_step_completed(wizard.current_steps[3])
	var device_step: StudentsCountStep = wizard.current_steps[4]
	device_step.students_count_field.value = 2
	device_step._on_next()

	assert_eq(wizard.register_data.students.size(), 1, "only the device still asked for is left")
	assert_false(wizard.register_data.students.has(2),
		"the device that went took its students with it")


func test_a_parent_revisiting_the_child_question_keeps_their_codes() -> void:
	# The parent's own step is a device step, and the wizard clears the data of the
	# device steps it removes -- so this pins that completing that question does not
	# wipe the children it just created.
	var wizard: Control = (load("res://sources/menus/register/register.tscn")
		as PackedScene).instantiate()
	add_child_autofree(wizard)
	await get_tree().process_frame

	wizard._go_to_step(1)
	wizard.register_data.account_type = TeacherSettings.AccountType.PARENT
	await wizard._on_step_completed(wizard.current_steps[1])
	wizard._go_to_step(2)
	var children_step: StudentsCountStep = wizard.current_steps[2]
	children_step.students_count_field.value = 2
	children_step._on_next()
	await wizard._on_step_completed(children_step)
	var before: String = _codes_of(wizard, 1)
	assert_eq((wizard.register_data.students[1] as Array).size(), 2,
		"two children were created")

	wizard._go_to_step(2)
	(wizard.current_steps[2] as StudentsCountStep)._on_next()
	await wizard._on_step_completed(wizard.current_steps[2])

	assert_eq(_codes_of(wizard, 1), before, "and they keep the codes they were given")


func test_a_saved_sheet_stops_counting_once_a_child_is_renamed() -> void:
	# The sheet prints each child's name next to their code, so it is how a parent
	# knows whose code is whose. Renaming one afterwards leaves the codes untouched
	# but the paper wrong, and the confirmation screen would still point at it.
	var original_path: String = AccountCreated.saved_codes_path
	var wizard: Control = await _wizard_at_the_recap()
	var recap_index: int = wizard.current_steps.size() - 1
	var recap: RecapStep = wizard.current_steps[recap_index]
	(wizard.register_data.students[1] as Array[StudentData])[0].name = "Amina"
	recap._on_save_all_codes_button_pressed()
	recap.export_codes_file_dialog.hide()
	AccountCreated.saved_codes_path = "user://Codes.pdf"

	(wizard.register_data.students[1] as Array[StudentData])[0].name = "Aminata"
	wizard._go_to_step(recap_index)

	assert_false(recap.codes_requested, "the sheet names the wrong child, so it has to be asked again")
	assert_true(recap.validate_button.disabled, "and Confirm should close again")
	assert_eq(AccountCreated.saved_codes_path, "",
		"the confirmation screen must not point at a sheet that names the wrong child")
	AccountCreated.saved_codes_path = original_path


func test_a_saved_sheet_stops_counting_once_two_children_swap_names() -> void:
	# The codes and the names are both still there, only paired the other way round
	# -- and a sheet that hands each child the other one's code is the worst version
	# of this, because everything on it looks right.
	var wizard: Control = await _wizard_at_the_recap()
	var recap_index: int = wizard.current_steps.size() - 1
	var recap: RecapStep = wizard.current_steps[recap_index]
	var students: Array[StudentData] = wizard.register_data.students[1]
	students[0].name = "Amina"
	students[1].name = "Bakary"
	recap._on_save_all_codes_button_pressed()
	recap.export_codes_file_dialog.hide()

	students[0].name = "Bakary"
	students[1].name = "Amina"
	wizard._go_to_step(recap_index)

	assert_false(recap.codes_requested, "the sheet pairs the codes with the wrong children")


func test_a_saved_sheet_survives_a_child_being_given_a_name_it_already_had() -> void:
	# Retyping the same name must not cost the parent another export.
	var wizard: Control = await _wizard_at_the_recap()
	var recap_index: int = wizard.current_steps.size() - 1
	var recap: RecapStep = wizard.current_steps[recap_index]
	(wizard.register_data.students[1] as Array[StudentData])[0].name = "Amina"
	recap._on_save_all_codes_button_pressed()
	recap.export_codes_file_dialog.hide()

	(wizard.register_data.students[1] as Array[StudentData])[0].name = "Amina"
	wizard._go_to_step(recap_index)

	assert_true(recap.codes_requested, "nothing the sheet prints changed")


## The codes on one device, in order, as a string that is easy to compare.
func _codes_of(wizard: Control, device: int) -> String:
	var codes: PackedStringArray = []
	for student: StudentData in wizard.register_data.students[device]:
		codes.append(str(student.code))
	return ",".join(codes)


func test_a_saved_sheet_stops_counting_once_the_codes_change() -> void:
	# Regression: the wizard reuses this step, so codes_requested survived the trip
	# and Confirm stayed enabled. The teacher could submit without exporting again,
	# keeping a printed sheet whose codes no longer log anybody in.
	var original_path: String = AccountCreated.saved_codes_path
	var wizard: Control = await _wizard_at_the_recap()
	var recap: RecapStep = wizard.current_steps[wizard.current_steps.size() - 1]
	recap._on_save_all_codes_button_pressed()
	recap.export_codes_file_dialog.hide()
	AccountCreated.saved_codes_path = "user://Codes.pdf"
	assert_false(recap.validate_button.disabled, "Confirm opens up once the sheet is asked for")

	wizard._go_to_step(4)
	var device_step: StudentsCountStep = wizard.current_steps[4]
	device_step.students_count_field.value = 3
	device_step._on_next()
	wizard._go_to_step(wizard.current_steps.size() - 1)

	assert_false(recap.codes_requested, "the sheet no longer matches, so it has to be asked again")
	assert_true(recap.validate_button.disabled, "and Confirm should close again")
	assert_eq(AccountCreated.saved_codes_path, "",
		"the confirmation screen must not point at a sheet of codes that will not work")
	AccountCreated.saved_codes_path = original_path


func test_a_saved_sheet_survives_a_trip_that_leaves_the_codes_alone() -> void:
	# Going back without changing an answer touches nothing, so the teacher should
	# not be made to export again for it.
	var original_path: String = AccountCreated.saved_codes_path
	var wizard: Control = await _wizard_at_the_recap()
	var recap_index: int = wizard.current_steps.size() - 1
	var recap: RecapStep = wizard.current_steps[recap_index]
	recap._on_save_all_codes_button_pressed()
	recap.export_codes_file_dialog.hide()
	AccountCreated.saved_codes_path = "user://Codes.pdf"

	wizard._go_to_step(recap_index - 1)
	wizard._go_to_step(recap_index)
	wizard._go_to_step(4)
	(wizard.current_steps[4] as StudentsCountStep)._on_next()
	wizard._go_to_step(recap_index)

	assert_true(recap.codes_requested, "nothing changed, so the sheet still stands")
	assert_false(recap.validate_button.disabled)
	assert_eq(AccountCreated.saved_codes_path, "user://Codes.pdf")
	AccountCreated.saved_codes_path = original_path
