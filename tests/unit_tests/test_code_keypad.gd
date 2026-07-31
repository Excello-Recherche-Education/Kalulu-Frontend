extends GutTest
## Behaviour of the access-code keypad.

const KEYPAD_SCENE: String = "res://sources/ui/code_keypad.tscn"

var keypad: CodeKeypad


func before_each() -> void:
	keypad = (load(KEYPAD_SCENE) as PackedScene).instantiate()
	add_child_autofree(keypad)


func test_it_lays_the_keys_out_in_numerical_order() -> void:
	# 1-2-3 over 4-5-6. Codes are handed out and read back as numbers, so the
	# keypad has to match; the mockups group by shape, which scrambles the digits.
	assert_eq(keypad.keys.size(), 6, "there should be one key per symbol")
	var order: Array[String] = []
	for key: Node in keypad.key_grid.get_children():
		for digit: String in keypad.keys:
			if keypad.keys[digit] == key:
				order.append(digit)
	assert_eq(order, ["1", "2", "3", "4", "5", "6"] as Array[String],
		"keys should follow Design.CODE_KEYPAD_ORDER")
	assert_eq(keypad.key_grid.columns, 3, "three per row makes it two rows of three")


func test_each_key_takes_its_symbol_colour() -> void:
	for digit: String in keypad.keys:
		var box: StyleBox = keypad.keys[digit].get_theme_stylebox("normal")
		assert_eq((box as StyleBoxFlat).bg_color, Design.code_color(digit),
			"key %s should use its symbol colour" % digit)


func test_the_symbol_artwork_is_a_bare_glyph() -> void:
	# Regression: the keypad first used symbol_0N.png, which is the older artwork
	# -- an old-palette rounded tile with the glyph already on it. Drawn on the
	# new flat colours it showed as a small mismatched square, so the glyph has to
	# be white on transparent with nothing else in it.
	for digit: String in Design.CODE_KEYPAD_ORDER:
		var texture: Texture2D = Design.code_symbol_texture(digit)
		assert_not_null(texture, "symbol %s should have artwork" % digit)
		var image: Image = texture.get_image()
		var opaque: int = 0
		var white: int = 0
		for y: int in range(0, image.get_height(), 3):
			for x: int in range(0, image.get_width(), 3):
				var pixel: Color = image.get_pixel(x, y)
				if pixel.a < 0.8:
					continue
				opaque += 1
				if minf(minf(pixel.r, pixel.g), pixel.b) > 0.85:
					white += 1
		assert_gt(opaque, 0, "symbol %s should draw something" % digit)
		assert_eq(white, opaque,
			"every opaque pixel of symbol %s should be white, not a coloured tile" % digit)


func test_symbol_glyphs_are_centred_at_the_designed_size() -> void:
	# They were left-aligned and shrunk when they lived in Button.icon, which
	# pins the icon to the left edge when the button has no text.
	for digit: String in keypad.keys:
		var key: Button = keypad.keys[digit]
		assert_eq(key.icon, null, "the glyph should not be the button's icon")
		var centre: CenterContainer = null
		for child: Node in key.get_children():
			if child is CenterContainer:
				centre = child as CenterContainer
		assert_not_null(centre, "key %s should centre its glyph" % digit)
		var glyph: TextureRect = centre.get_child(0) as TextureRect
		assert_eq(glyph.custom_minimum_size,
			Vector2(Design.CODE_SYMBOL_SIZE, Design.CODE_SYMBOL_SIZE),
			"key %s glyph should be the designed size" % digit)
		assert_eq(glyph.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"key %s glyph must not swallow the tap" % digit)


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
