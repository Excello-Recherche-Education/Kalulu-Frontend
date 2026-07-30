extends GutTest
## Behaviour of the redesigned text field.

const FIELD_SCENE: String = "res://sources/ui/menu_text_field.tscn"
const EMAIL_ICON: String = "res://assets/menus/icons/email.svg"

var field: MenuTextField


func before_each() -> void:
	field = _make_field()


func _make_field() -> MenuTextField:
	var instance: MenuTextField = (load(FIELD_SCENE) as PackedScene).instantiate()
	add_child_autofree(instance)
	return instance


func test_placeholder_reaches_the_line_edit() -> void:
	field.placeholder = "EMAIL"
	assert_eq(field.input.placeholder_text, "EMAIL")


func test_text_proxies_the_line_edit() -> void:
	field.text = "hello@example.org"

	assert_eq(field.input.text, "hello@example.org", "the proxy should write through")
	assert_eq(field.text, "hello@example.org", "the proxy should read back")


func test_the_error_line_is_hidden_until_there_is_an_error() -> void:
	assert_false(field.error_label.visible, "a fresh field shows no error")

	field.error = "INVALID_EMAIL"

	assert_true(field.error_label.visible, "setting an error should reveal the line")
	assert_eq(field.error_label.text, "INVALID_EMAIL")

	field.error = ""

	assert_false(field.error_label.visible, "clearing an error should hide the line")


func test_editing_retires_a_stale_error() -> void:
	# The message describes text the user has since changed.
	field.error = "INVALID_EMAIL"

	field.input.text = "a"
	field.input.text_changed.emit("a")

	assert_eq(field.error, "", "editing should clear the error")
	assert_false(field.error_label.visible)


func test_it_forwards_the_line_edit_signals() -> void:
	watch_signals(field)

	field.input.text_changed.emit("abc")
	field.input.text_submitted.emit("abc")

	assert_signal_emitted_with_parameters(field, "text_changed", ["abc"])
	assert_signal_emitted_with_parameters(field, "text_submitted", ["abc"])


func test_a_password_field_starts_masked() -> void:
	field.is_password = true

	assert_true(field.is_masked(), "a password field should start masked")
	assert_true(field.trailing.visible, "the reveal toggle should be shown")
	assert_eq(field.trailing.mouse_filter, Control.MOUSE_FILTER_STOP,
		"the reveal toggle has to be clickable")


func test_the_reveal_toggle_flips_masking_and_its_icon() -> void:
	field.is_password = true
	var masked_icon: Texture2D = field.trailing.texture_normal

	field.trailing.pressed.emit()

	assert_false(field.is_masked(), "pressing reveal should unmask the text")
	assert_ne(field.trailing.texture_normal, masked_icon,
		"the icon should show the new state")

	field.trailing.pressed.emit()

	assert_true(field.is_masked(), "pressing again should mask the text")
	assert_eq(field.trailing.texture_normal, masked_icon, "and restore the icon")


func test_a_decorative_icon_does_not_swallow_taps() -> void:
	# Tapping anywhere on an email field should focus it, so the envelope must
	# not be a click target.
	field.icon = load(EMAIL_ICON)

	assert_true(field.trailing.visible)
	assert_eq(field.trailing.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"a decorative icon must let the tap through to the field")


func test_a_field_without_an_icon_hides_the_trailing_slot() -> void:
	assert_false(field.trailing.visible, "no icon means no trailing slot")


func test_an_icon_reserves_padding_so_text_cannot_run_under_it() -> void:
	var plain: float = field.input.get_theme_stylebox("normal").content_margin_right

	field.icon = load(EMAIL_ICON)

	var padded: float = field.input.get_theme_stylebox("normal").content_margin_right
	assert_gt(padded, plain, "an icon should widen the right padding")
	assert_eq(padded, float(Design.FIELD_PADDING * 2 + Design.FIELD_ICON_SIZE),
		"padding should be sized from the token, not the 2x texture width")


func test_a_validator_fills_the_error_line_through_the_form() -> void:
	# The component replaces the old "find a Label called <name>Error"
	# convention, so this is the behaviour that matters most.
	var form: FormValidator = FormValidator.new()
	add_child_autofree(form)
	var validated: MenuTextField = (load(FIELD_SCENE) as PackedScene).instantiate()
	validated.rules = [EmailRule.new()]
	form.add_child(validated)
	await get_tree().process_frame

	validated.text = "not-an-email"
	var passed: bool = form.validate()

	assert_false(passed, "an invalid address should fail the form")
	assert_true(validated.error_label.visible, "the field should surface its own error")
	assert_false(validated.error.is_empty(), "the error text should be filled in")

	validated.text = "someone@example.org"
	passed = form.validate()

	assert_true(passed, "a valid address should pass the form")
	assert_false(validated.error_label.visible, "passing should clear the error")


func test_rules_are_wrapped_in_a_line_edit_validator() -> void:
	# Regression guard: a plain Validator reads no value from the control, so
	# every rule would fail whatever the user typed.
	var validated: MenuTextField = (load(FIELD_SCENE) as PackedScene).instantiate()
	validated.rules = [EmailRule.new()]
	add_child_autofree(validated)
	await get_tree().process_frame

	var attached: ControlValidator = null
	for child: Node in validated.input.get_children():
		if child is ControlValidator:
			attached = child as ControlValidator
	assert_not_null(attached, "the validator should hang off the LineEdit")
	assert_true(attached.validator is LineEditValidator,
		"rules must be wrapped in a LineEditValidator, not a bare Validator")
