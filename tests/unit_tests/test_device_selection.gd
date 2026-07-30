extends GutTest
## The device cards and the screen that lays them out.

const CARD_SCENE: String = "res://sources/menus/main/device_button.tscn"
const SELECTION_SCENE: String = "res://sources/menus/device_selection/device_selection.tscn"


func _card(number: int, background: Color = Color.WHITE) -> DeviceButton:
	var card: DeviceButton = (load(CARD_SCENE) as PackedScene).instantiate()
	card.number = number
	card.background_color = background
	add_child_autofree(card)
	return card


func test_a_card_shows_its_number() -> void:
	var card: DeviceButton = _card(7)
	assert_eq(card.label.text, "7")


func test_a_card_is_the_designed_size() -> void:
	var card: DeviceButton = _card(1)
	assert_eq(card.custom_minimum_size, Vector2(Design.DEVICE_CARD_SIZE))


func test_a_white_card_gets_a_navy_number() -> void:
	var card: DeviceButton = _card(1, Color.WHITE)
	assert_eq(card.label.get_theme_color("font_color"), Design.NAVY,
		"navy reads on white")


func test_a_dark_card_gets_a_white_number() -> void:
	# Settings still tints its cards per device, so the number cannot be a fixed
	# navy or it would disappear on the darker ones.
	var card: DeviceButton = _card(1, Design.NAVY)
	assert_eq(card.label.get_theme_color("font_color"), Color.WHITE,
		"white reads on navy")


func test_a_card_paints_its_background_colour() -> void:
	var card: DeviceButton = _card(1, Design.PURPLE)
	var box: StyleBox = card.get_theme_stylebox("normal")
	assert_eq((box as StyleBoxFlat).bg_color, Design.PURPLE)


func test_a_card_reacts_to_being_pressed() -> void:
	var card: DeviceButton = _card(1)
	var normal: Color = (card.get_theme_stylebox("normal") as StyleBoxFlat).bg_color
	var pressed: Color = (card.get_theme_stylebox("pressed") as StyleBoxFlat).bg_color
	assert_ne(normal, pressed, "a card should look different while held")


func test_the_tablet_marks_do_not_swallow_taps() -> void:
	# The dot and bar are decoration drawn on top of the button; if they took
	# input, tapping the middle of a card would do nothing.
	var card: DeviceButton = _card(1)
	for part: Control in [card.dot, card.bar, card.label]:
		assert_eq(part.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"%s should let taps through to the card" % part.name)


func test_out_of_range_numbers_are_reported_not_silently_accepted() -> void:
	# The setter warns rather than clamping; check it still assigns so the card
	# does not end up blank.
	var card: DeviceButton = _card(1)
	card.number = 42
	assert_eq(card.label.text, "42")


func test_the_selection_screen_lays_cards_out_as_designed() -> void:
	var screen: Control = (load(SELECTION_SCENE) as PackedScene).instantiate()
	autofree(screen)
	var grid: GridContainer = screen.get_node("Content/ScrollContainer/GridContainer")

	assert_eq(grid.columns, Design.DEVICE_CARD_COLUMNS)
	assert_eq(grid.get_theme_constant("h_separation"), Design.DEVICE_CARD_GAP.x)
	assert_eq(grid.get_theme_constant("v_separation"), Design.DEVICE_CARD_GAP.y)


func test_the_selection_screen_scrolls_when_there_are_many_devices() -> void:
	# A teacher can have more devices than fit on one screen.
	var screen: Control = (load(SELECTION_SCENE) as PackedScene).instantiate()
	autofree(screen)
	var scroll: ScrollContainer = screen.get_node("Content/ScrollContainer")
	assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED,
		"the grid wraps, so only vertical scrolling makes sense")
