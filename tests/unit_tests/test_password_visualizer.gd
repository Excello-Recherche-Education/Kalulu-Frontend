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
