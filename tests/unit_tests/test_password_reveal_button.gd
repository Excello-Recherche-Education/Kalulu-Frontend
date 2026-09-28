extends GutTest
## The eye toggle that the registration form hangs off its plain LineEdits.

var field: LineEdit
var reveal: PasswordRevealButton


func before_each() -> void:
	field = LineEdit.new()
	add_child_autofree(field)
	reveal = PasswordRevealButton.new()
	field.add_child(reveal)
	await get_tree().process_frame


func test_it_masks_the_field_it_is_dropped_into() -> void:
	assert_true(reveal.is_masked(), "the field should start masked")
	assert_true(field.secret)


func test_it_finds_its_field_without_being_told() -> void:
	assert_eq(reveal.field, field, "the parent LineEdit is the field")


func test_pressing_it_flips_masking_and_its_icon() -> void:
	var masked_icon: Texture2D = reveal.texture_normal

	reveal.pressed.emit()

	assert_false(reveal.is_masked(), "pressing reveal should unmask the text")
	assert_false(field.secret)
	assert_ne(reveal.texture_normal, masked_icon, "the icon should show the new state")

	reveal.pressed.emit()

	assert_true(reveal.is_masked(), "pressing again should mask the text")
	assert_eq(reveal.texture_normal, masked_icon, "and restore the icon")


func test_it_asks_for_the_password_keyboard() -> void:
	# The ordinary keyboard arms its shift key for the first character, which
	# has to be switched off by hand before every password.
	assert_eq(field.virtual_keyboard_type, LineEdit.KEYBOARD_TYPE_PASSWORD)


func test_it_reserves_room_so_text_cannot_run_under_it() -> void:
	var plain: LineEdit = LineEdit.new()
	add_child_autofree(plain)
	var bare: float = plain.get_theme_stylebox("normal", "LineEdit").content_margin_right

	var padded: float = field.get_theme_stylebox("normal").content_margin_right

	assert_gt(padded, bare, "the eye should widen the right padding")
	assert_eq(padded, float(Design.FIELD_PADDING * 2 + Design.FIELD_ICON_SIZE),
		"padding should be sized from the token, not the 2x texture width")


func test_it_sits_inside_the_trailing_edge_of_the_field() -> void:
	assert_eq(reveal.anchor_left, 1.0, "it should be pinned to the right edge")
	assert_eq(reveal.offset_right, -float(Design.FIELD_PADDING),
		"one padding in from the edge")
	assert_eq(reveal.size, Vector2(Design.FIELD_ICON_SIZE, Design.FIELD_ICON_SIZE),
		"drawn at the token size, not at texture size")
