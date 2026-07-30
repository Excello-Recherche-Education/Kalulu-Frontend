extends GutTest
## Behaviour of the access-code keypad.

const KEYPAD_SCENE: String = "res://sources/ui/code_keypad.tscn"

var keypad: CodeKeypad


func before_each() -> void:
	keypad = (load(KEYPAD_SCENE) as PackedScene).instantiate()
	add_child_autofree(keypad)


func test_it_lays_the_keys_out_in_the_designed_order() -> void:
	# Grouped by shape rather than by digit, so this is worth pinning.
	assert_eq(keypad.keys.size(), 6, "there should be one key per symbol")
	var order: Array[String] = []
	for key: Node in keypad.key_grid.get_children():
		for digit: String in keypad.keys:
			if keypad.keys[digit] == key:
				order.append(digit)
	assert_eq(order, ["1", "4", "3", "5", "6", "2"] as Array[String],
		"keys should follow Design.CODE_KEYPAD_ORDER")


func test_each_key_takes_its_symbol_colour() -> void:
	for digit: String in keypad.keys:
		var box: StyleBox = keypad.keys[digit].get_theme_stylebox("normal")
		assert_eq((box as StyleBoxFlat).bg_color, Design.code_color(digit),
			"key %s should use its symbol colour" % digit)


func test_it_builds_one_slot_per_code_symbol() -> void:
	assert_eq(keypad.slots.size(), Design.CODE_LENGTH)
	for glyph: TextureRect in keypad.slot_glyphs:
		assert_null(glyph.texture, "slots should start empty")


func test_pressing_keys_builds_the_code() -> void:
	watch_signals(keypad)

	keypad.keys["4"].pressed.emit()

	assert_eq(keypad.code, "4")
	assert_signal_emitted_with_parameters(keypad, "code_changed", ["4"])
	assert_not_null(keypad.slot_glyphs[0].texture, "the first slot should fill")


func test_a_full_code_is_announced_once() -> void:
	watch_signals(keypad)

	keypad.toggle_digit("1")
	keypad.toggle_digit("2")
	keypad.toggle_digit("3")

	assert_eq(keypad.code, "123")
	assert_signal_emit_count(keypad, "code_entered", 1, "a full code should be announced once")
	assert_signal_emitted_with_parameters(keypad, "code_entered", ["123"])


func test_a_symbol_cannot_be_used_twice() -> void:
	# Access codes are distinct-digit permutations, so pressing a key that is
	# already in the code takes it back out.
	keypad.toggle_digit("1")
	keypad.toggle_digit("2")

	var changed: bool = keypad.toggle_digit("1")

	assert_true(changed, "pressing a used key should still change the code")
	assert_eq(keypad.code, "2", "the repeated symbol should be removed")


func test_used_keys_are_dimmed() -> void:
	keypad.toggle_digit("3")

	assert_lt(keypad.keys["3"].modulate.r, 1.0, "a used key should be dimmed")
	assert_eq(keypad.keys["5"].modulate, Color.WHITE, "an unused key stays bright")

	keypad.toggle_digit("3")

	assert_eq(keypad.keys["3"].modulate, Color.WHITE, "releasing a key should undim it")


func test_a_full_code_refuses_more_symbols() -> void:
	keypad.toggle_digit("1")
	keypad.toggle_digit("2")
	keypad.toggle_digit("3")

	var changed: bool = keypad.toggle_digit("4")

	assert_false(changed, "a full code should refuse another symbol")
	assert_eq(keypad.code, "123")


func test_unknown_digits_are_refused() -> void:
	assert_false(keypad.toggle_digit("9"), "9 is not a symbol")
	assert_false(keypad.toggle_digit(""), "the empty string is not a symbol")
	assert_eq(keypad.code, "")


func test_a_filled_slot_shows_the_symbol_colour() -> void:
	# Matches the code chips in the registration summary and progress panel.
	keypad.toggle_digit("5")

	var box: StyleBox = keypad.slots[0].get_theme_stylebox("panel")
	assert_eq((box as StyleBoxFlat).bg_color, Design.code_color("5"),
		"a filled slot should take the symbol's colour")
	var empty: StyleBox = keypad.slots[1].get_theme_stylebox("panel")
	assert_eq((empty as StyleBoxFlat).bg_color, Color.WHITE, "an empty slot stays white")


func test_removing_a_slot_shifts_the_rest_down() -> void:
	keypad.toggle_digit("1")
	keypad.toggle_digit("2")
	keypad.toggle_digit("3")

	keypad.remove_at(0)

	assert_eq(keypad.code, "23", "the first symbol should be gone")
	assert_eq(keypad.keys["1"].modulate, Color.WHITE, "its key should be usable again")
	assert_null(keypad.slot_glyphs[2].texture, "the last slot should now be empty")


func test_removing_an_empty_slot_does_nothing() -> void:
	watch_signals(keypad)
	keypad.toggle_digit("1")

	keypad.remove_at(2)

	assert_eq(keypad.code, "1")
	assert_signal_emit_count(keypad, "code_changed", 1, "no spurious change should be emitted")


func test_clear_empties_without_announcing_a_code() -> void:
	keypad.toggle_digit("1")
	keypad.toggle_digit("2")
	watch_signals(keypad)

	keypad.clear()

	assert_eq(keypad.code, "")
	assert_signal_emitted_with_parameters(keypad, "code_changed", [""])
	assert_signal_not_emitted(keypad, "code_entered", "clearing is not entering a code")
	for glyph: TextureRect in keypad.slot_glyphs:
		assert_null(glyph.texture, "every slot should be empty again")


func test_every_available_code_can_be_entered() -> void:
	# The keypad has to be able to produce any code the backend hands out.
	for value: int in TeacherSettings.AVAILABLE_CODES:
		keypad.clear()
		for digit: String in str(value).split("", false):
			keypad.toggle_digit(digit)
		assert_eq(keypad.code, str(value), "code %d should be enterable" % value)
