extends GutTest
## Every registration step still loads after the base step was restyled.
##
## All nine steps are inherited scenes of base_step.tscn and address its nodes by
## name, path and unique_id. Restyling the base is therefore only safe as long as
## its node structure is untouched, and a break would not show up as an error --
## the override would silently land on the wrong node, or vanish. Hence loading
## each one and checking the parts the wizard drives.

const STEP_SCENES: Array[String] = [
	"res://sources/menus/register/steps/language/language_step.tscn",
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
	var step: Step = (load("res://sources/menus/register/steps/base_step.tscn") as PackedScene).instantiate()
	autofree(step)

	var previous: Button = step.get_node("LeftMargin/LeftContainer/BackButton")
	var next: Button = step.get_node("RightMargin/RightContainer/ValidateButton")
	assert_eq(previous.theme_type_variation, MenuTheme.VARIATION_SECONDARY_BUTTON)
	assert_eq(next.theme_type_variation, MenuTheme.VARIATION_PRIMARY_BUTTON)
	assert_eq(previous.custom_minimum_size, Vector2(Design.BUTTON_SIZE))
	assert_eq(next.custom_minimum_size, Vector2(Design.BUTTON_SIZE))


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
