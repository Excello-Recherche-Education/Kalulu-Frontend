extends GutTest
## How far the on-screen keyboard pushes a form up, and when it does not.
##
## The keyboard itself only exists on a phone, so what is checked here is the
## arithmetic and the moving, with the keyboard's height handed in. Whether
## DisplayServer is reporting one is the one part a desktop cannot rehearse.

const SPACER_SCENE: String = "res://sources/utils/keyboard_spacer.tscn"
const VIEWPORT_SIZE: Vector2i = Vector2i(2560, 1800)
## Tall enough that the field below sits where the keyboard would be.
const KEYBOARD: float = 800.0

var viewport: SubViewport
var spacer: KeyboardSpacer
var form: VBoxContainer
var field: LineEdit


func before_each() -> void:
	viewport = SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	# Focus is a viewport-wide notion, so the field has to be in one that
	# handles input rather than in a bare off-screen render target.
	viewport.handle_input_locally = true
	viewport.gui_disable_input = false
	add_child_autofree(viewport)

	spacer = (load(SPACER_SCENE) as PackedScene).instantiate()
	viewport.add_child(spacer)
	form = VBoxContainer.new()
	form.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	spacer.add_child(form)
	field = LineEdit.new()
	field.custom_minimum_size = Vector2(600, 120)
	form.add_child(field)
	# The form is pinned to the top of the spacer by a margin, exactly as the
	# sign-up steps pin theirs -- the layout the old bottom-margin spacer could
	# not move at all.
	spacer.add_theme_constant_override(&"margin_top", 1200)
	spacer.authored_margin_top = 1200
	await get_tree().process_frame
	await get_tree().process_frame


func test_a_closed_keyboard_asks_for_no_lift() -> void:
	assert_eq(spacer.lift_for(0.0, field), 0.0, "a closed keyboard should move nothing")


func test_a_field_above_the_keyboard_is_left_alone() -> void:
	# Same keyboard, a field near the top: nothing is covered, so nothing moves.
	spacer.add_theme_constant_override(&"margin_top", 0)
	spacer.authored_margin_top = 0
	await get_tree().process_frame

	assert_eq(spacer.lift_for(KEYBOARD, field), 0.0,
		"a field the keyboard does not reach should not move")


func test_a_covered_field_rises_just_clear_of_the_keyboard() -> void:
	var lift: float = spacer.lift_for(KEYBOARD, field)
	assert_gt(lift, 0.0, "a field under the keyboard should be lifted")

	var keyboard_top: float = float(VIEWPORT_SIZE.y) - KEYBOARD
	assert_almost_eq(field.get_global_rect().end.y - lift,
		keyboard_top - KeyboardSpacer.CLEARANCE, 1.0,
		"the field should end up exactly the clearance above the keyboard")


func test_the_lift_never_pushes_the_field_off_the_top() -> void:
	# A keyboard taking all but a sliver of the screen: lifting the field clear
	# of it would put it above the top edge, which helps nobody.
	var lift: float = spacer.lift_for(float(VIEWPORT_SIZE.y) - 100.0, field)
	assert_almost_eq(field.get_global_rect().position.y - lift,
		float(KeyboardSpacer.CLEARANCE), 1.0,
		"the field should stop against the top of the screen")


func test_focus_outside_the_spacer_moves_nothing() -> void:
	var elsewhere: LineEdit = LineEdit.new()
	viewport.add_child(elsewhere)
	await get_tree().process_frame

	assert_eq(spacer.lift_for(KEYBOARD, elsewhere), 0.0,
		"a keyboard opened for somebody else's field should not move this form")
	assert_eq(spacer.lift_for(KEYBOARD, null), 0.0, "no focus, no lift")


func test_applying_a_lift_moves_the_form_up_without_resizing_it() -> void:
	var before: Rect2 = form.get_global_rect()
	spacer.apply_lift(300.0)
	await get_tree().process_frame

	var after: Rect2 = form.get_global_rect()
	assert_almost_eq(after.position.y, before.position.y - 300.0, 1.0,
		"the form should move up by the lift")
	assert_almost_eq(after.size.y, before.size.y, 1.0,
		"the form should keep the height the scene gave it")


func test_the_lift_is_measured_from_where_the_scene_put_the_form() -> void:
	# Regression: asking again while a lift is already in force used to measure
	# the field where the previous lift had left it, so every frame added a
	# little more and the form crept off the top of the screen.
	var first: float = spacer.lift_for(KEYBOARD, field)
	spacer.apply_lift(first)
	await get_tree().process_frame

	assert_almost_eq(spacer.lift_for(KEYBOARD, field), first, 1.0,
		"the answer should not depend on the lift already applied")


func test_a_lift_is_announced_so_the_rest_of_the_screen_can_follow() -> void:
	watch_signals(spacer)
	spacer.apply_lift(250.0)
	assert_signal_emitted_with_parameters(spacer, "lift_changed", [250.0])


func test_the_authored_margins_come_back_when_the_keyboard_closes() -> void:
	spacer.apply_lift(300.0)
	spacer.apply_lift(0.0)
	await get_tree().process_frame

	assert_eq(spacer.get_theme_constant(&"margin_top"), 1200,
		"the scene's own top margin should be restored")
	assert_eq(spacer.get_theme_constant(&"margin_bottom"), 0,
		"and nothing should be left reserved at the bottom")
