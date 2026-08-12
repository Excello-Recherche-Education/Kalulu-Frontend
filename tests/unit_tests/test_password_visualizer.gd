extends GutTest
## How an access code is displayed outside the keypad.
##
## Used in settings, in the boss-minigame adult gate, and in the printable code
## sheet. The sheet is the risky one: it is drawn on white paper, so a white glyph
## there would be invisible.

const VISUALIZER_SCENE: String = "res://sources/menus/components/password_visualizer.tscn"


func _visualizer(code: String, backgrounds: bool = true) -> PasswordVisualizer:
	var instance: PasswordVisualizer = (load(VISUALIZER_SCENE) as PackedScene).instantiate()
	add_child_autofree(instance)
	instance.show_backgrounds = backgrounds
	instance.password = code
	return instance


func test_it_shows_one_glyph_per_symbol() -> void:
	var visualizer: PasswordVisualizer = _visualizer("142")

	for index: int in 3:
		assert_not_null(visualizer.icons[index].texture, "slot %d should show a glyph" % index)


func test_a_chip_takes_its_symbol_colour_with_a_white_glyph() -> void:
	var visualizer: PasswordVisualizer = _visualizer("142")

	for index: int in 3:
		var digit: String = "142"[index]
		var box: StyleBox = visualizer.panels[index].get_theme_stylebox("panel")
		assert_eq((box as StyleBoxFlat).bg_color, Design.code_color(digit),
			"chip %d should take symbol %s's colour" % [index, digit])
		assert_eq(visualizer.icons[index].modulate, Color.WHITE,
			"the glyph on a coloured chip should be white")


func test_the_printable_sheet_colours_the_glyph_instead() -> void:
	# Regression risk: the code sheet is exported onto white paper with no chips
	# behind the symbols. The old artwork carried its own colour, so it survived;
	# a bare white glyph would come out invisible.
	var visualizer: PasswordVisualizer = _visualizer("142", false)

	for index: int in 3:
		var digit: String = "142"[index]
		assert_eq(visualizer.icons[index].modulate, Design.code_color(digit),
			"without a chip, symbol %s must colour the glyph itself" % digit)
		assert_ne(visualizer.icons[index].modulate, Color.WHITE,
			"a white glyph on white paper cannot be seen")


func test_an_empty_slot_stays_white() -> void:
	var visualizer: PasswordVisualizer = _visualizer("1")

	var filled: StyleBox = visualizer.panels[0].get_theme_stylebox("panel")
	var empty: StyleBox = visualizer.panels[1].get_theme_stylebox("panel")
	assert_eq((filled as StyleBoxFlat).bg_color, Design.code_color("1"))
	assert_eq((empty as StyleBoxFlat).bg_color, Color.WHITE)
	assert_null(visualizer.icons[1].texture, "an empty slot shows no glyph")


func test_it_uses_the_same_artwork_as_the_keypad() -> void:
	# A code has to look identical wherever it appears, or a child cannot match
	# the sheet in their hand to the buttons on screen.
	var visualizer: PasswordVisualizer = _visualizer("3")

	assert_eq(visualizer.icons[0].texture, Design.code_symbol_texture("3"))


func test_clearing_the_code_empties_every_slot() -> void:
	var visualizer: PasswordVisualizer = _visualizer("142")

	visualizer.password = ""

	for index: int in 3:
		assert_null(visualizer.icons[index].texture, "slot %d should be empty" % index)
		var box: StyleBox = visualizer.panels[index].get_theme_stylebox("panel")
		assert_eq((box as StyleBoxFlat).bg_color, Color.WHITE)


# --- Glyph size inside a chip -------------------------------------------------
func _sized_visualizer(code: String, glyph: int, chip: int) -> PasswordVisualizer:
	var instance: PasswordVisualizer = (load(VISUALIZER_SCENE) as PackedScene).instantiate()
	add_child_autofree(instance)
	instance.key_size = glyph
	instance.chip_size = chip
	instance.password = code
	await get_tree().process_frame
	await get_tree().process_frame
	return instance


func test_a_pinned_chip_draws_its_glyph_at_the_size_asked_for() -> void:
	# Regression: the glyph filled its chip corner to corner, so the shape ran into
	# the coloured edge and stopped being easy to tell apart. key_size looked like
	# it should have handled that, but a PanelContainer fits its only child to its
	# own rect and custom_minimum_size is a floor, not a cap -- the panel stretched
	# the glyph straight back out. The room has to come from the chip's stylebox.
	#
	# Measured on the student card rather than on a bare visualizer: a card sizes
	# the row down to its minimum, which is what makes the pinned sizes the real
	# ones. Left to itself the row keeps the size its own scene was saved at.
	var card: Control = (load("res://sources/menus/settings/student_panel.tscn")
		as PackedScene).instantiate()
	add_child_autofree(card)
	await get_tree().process_frame
	var visualizer: PasswordVisualizer = card.find_children("*", "PasswordVisualizer",
		true, false)[0] as PasswordVisualizer
	visualizer.password = "123"
	await get_tree().process_frame
	await get_tree().process_frame

	var chip: PanelContainer = visualizer.panels[0]
	var glyph: TextureRect = visualizer.icons[0]
	assert_eq(chip.size, Vector2(Design.CODE_CHIP_SIZE, Design.CODE_CHIP_SIZE),
		"the chip should be the size it was pinned to")
	assert_eq(glyph.size, Vector2(Design.CODE_CHIP_GLYPH_SIZE, Design.CODE_CHIP_GLYPH_SIZE),
		"and the glyph the size it was asked for, not the chip's")
	assert_lt(glyph.size.x, chip.size.x,
		"the shape has to be smaller than the colour it sits on")
	assert_almost_eq(glyph.global_position.x - chip.global_position.x,
		chip.global_position.x + chip.size.x - (glyph.global_position.x + glyph.size.x), 1.0,
		"and centred, so the padding is even on both sides")


func test_both_pinned_sizes_leave_the_shape_room() -> void:
	# The student card and the progress panel show codes at different sizes; the
	# padding follows the sizes rather than being a fixed number of pixels.
	for pair: Array in [[Design.CODE_CHIP_GLYPH_SIZE, Design.CODE_CHIP_SIZE], [76, 151]]:
		var visualizer: PasswordVisualizer = await _sized_visualizer("123",
			pair[0] as int, pair[1] as int)
		assert_eq(visualizer._chip_padding(),
			floori(float((pair[1] as int) - (pair[0] as int)) / 2),
			"padding for a %d glyph in a %d chip" % [pair[0], pair[1]])


func test_a_chip_that_was_never_pinned_is_left_alone() -> void:
	# The keypad and the adult gate let their chips stretch to fill the row, and
	# they already read correctly -- there is no chip size to take a share of.
	var visualizer: PasswordVisualizer = await _sized_visualizer("123", 200, 0)

	assert_eq(visualizer._chip_padding(), 0, "an unpinned chip should not be inset")


func test_a_glyph_bigger_than_its_chip_does_not_invert_the_padding() -> void:
	var visualizer: PasswordVisualizer = await _sized_visualizer("123", 200, 68)

	assert_eq(visualizer._chip_padding(), 0,
		"a glyph larger than its chip should just fill it, not push the padding negative")
