extends GutTest
## Where the settings screen's parts actually land.
##
## The structural tests next door check the scene is wired up; these check it is
## laid out. Both bugs this file guards against were reported from a screenshot,
## not caught by a test, because a scene can be perfectly wired and still put
## things on top of each other.
##
## Measured inside a fixed 2560x1800 viewport -- the project's reference size --
## so nothing outside the scene influences the result.

const SETTINGS_SCENE: String = "res://sources/menus/settings/teacher_settings.tscn"
const VIEWPORT_SIZE: Vector2i = Vector2i(2560, 1800)
## Left and right insets of the card in the hand-off.
const PAGE_LEFT: float = 349.0
const PAGE_RIGHT_INSET: float = 312.0

var screen: Control


func before_each() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	add_child_autofree(viewport)
	screen = (load(SETTINGS_SCENE) as PackedScene).instantiate()
	viewport.add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame


func _right_of(node: Control) -> float:
	return node.global_position.x + node.size.x


func test_the_page_content_fits_the_width_it_is_given() -> void:
	# The bug this catches: a row whose minimum width exceeds the page's anchored
	# width makes Godot grow the page past its own anchors and centre the
	# overflow. The page slides left, and the title ends up under the back button.
	# Nothing errors -- it just looks broken.
	var available: float = VIEWPORT_SIZE.x - PAGE_LEFT - PAGE_RIGHT_INSET
	for path: String in ["Page/TitleRow", "Page/ControlsRow", "Page/Card"]:
		var row: Control = screen.get_node(path)
		assert_lte(row.get_combined_minimum_size().x, available,
			"%s must fit in the page, or the page overflows its anchors" % path)


func test_the_page_sits_where_the_reference_puts_the_card() -> void:
	var page: Control = screen.get_node("Page")
	assert_almost_eq(page.global_position.x, PAGE_LEFT, 2.0)
	assert_almost_eq(_right_of(page), VIEWPORT_SIZE.x - PAGE_RIGHT_INSET, 2.0)


func test_the_title_does_not_collide_with_the_back_button() -> void:
	var back: Control = screen.get_node("BackButton")
	var gear: Control = screen.get_node("Page/TitleRow/Gear")
	var title: Control = screen.get_node("Page/TitleRow/Title")

	assert_gt(gear.global_position.x, _right_of(back),
		"the title's icon should start clear of the back button")
	assert_gt(title.global_position.x, _right_of(back),
		"the title should start clear of the back button")


func test_the_action_icons_sit_at_the_right_edge_of_the_page() -> void:
	# They are pushed right by an expanding spacer, so this also catches the
	# spacer being squeezed to nothing by an over-wide row.
	var actions: Control = screen.get_node("Page/ControlsRow/Actions")
	assert_almost_eq(_right_of(actions), VIEWPORT_SIZE.x - PAGE_RIGHT_INSET, 4.0,
		"the icon row should end at the page's right edge")


func test_the_sound_button_is_the_same_size_as_the_other_icons() -> void:
	# It is a TextureButton, so without ignore_texture_size its artwork sets a
	# 140px floor -- which is exactly what overflowed the row.
	var actions: Control = screen.get_node("Page/ControlsRow/Actions")
	for child: Node in actions.get_children():
		var button: Control = child as Control
		if button:
			assert_almost_eq(button.get_combined_minimum_size().x,
				float(Design.ROUND_BUTTON_SMALL), 1.0,
				"%s should be a round icon button's width" % button.name)


## Adds `count` pills of the size refresh_devices builds them at.
##
## Deliberately not through refresh_devices: that reads UserDataManager's live
## teacher settings, and substituting those logs the real device out on disk.
## What is under test here is the row's layout, which only needs the pills.
func _replace_pills(count: int) -> Array[Button]:
	var row: HBoxContainer = screen.get_node("%DevicePills")
	# refresh_devices has already built a pill per device of whatever account this
	# machine is signed in to, so start from an empty row to get a fixed count.
	# Freed rather than queue_freed: the row is measured in this same frame.
	for child: Node in row.get_children():
		row.remove_child(child)
		child.free()
	var pills: Array[Button] = []
	for index: int in count:
		var pill: Button = Button.new()
		pill.text = "Appareil %d" % index
		pill.custom_minimum_size = Vector2(Design.PILL_WIDTH, Design.PILL_HEIGHT)
		pill.theme_type_variation = MenuTheme.VARIATION_TAB_PILL
		row.add_child(pill)
		pills.append(pill)
	return pills


func _fill_with_pills(count: int) -> Array[Button]:
	var pills: Array[Button] = _replace_pills(count)
	await get_tree().process_frame
	await get_tree().process_frame
	return pills


func test_the_device_row_scrolls_sideways_only() -> void:
	var scroll: ScrollContainer = screen.get_node("%DevicePillsScroll")
	var row: HBoxContainer = screen.get_node("%DevicePills")

	assert_eq(row.get_parent(), scroll, "the pills should live inside the scroller")
	assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO,
		"the row should scroll sideways, and show a bar only when it has to")
	assert_eq(scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED,
		"the row is one pill tall, so it should never scroll vertically")


func test_a_long_device_list_does_not_overflow_the_card() -> void:
	# Regression, reported from a screenshot of an account with tens of devices:
	# the pills were a bare HBoxContainer, so its minimum width ran to thousands
	# of pixels, Godot grew it past its anchors and centred the overflow. The row
	# then spilled off both edges of the screen with no way to reach either end.
	await _fill_with_pills(50)
	var scroll: ScrollContainer = screen.get_node("%DevicePillsScroll")
	var row: HBoxContainer = screen.get_node("%DevicePills")
	var available: float = VIEWPORT_SIZE.x - PAGE_LEFT - PAGE_RIGHT_INSET

	assert_lte(scroll.get_combined_minimum_size().x, available,
		"however many devices there are, the row must still fit the page")
	assert_lte(screen.get_node("Page/Card").get_combined_minimum_size().x, available,
		"the card must not be widened by the device list")
	assert_gt(row.size.x, scroll.size.x,
		"with 50 devices the row should be wider than its window, so there is "
		+ "something to scroll")
	assert_almost_eq(_right_of(scroll), VIEWPORT_SIZE.x - PAGE_RIGHT_INSET - 80.0, 4.0,
		"the scroller should end at the card's inner right edge")


func test_the_selected_device_is_brought_into_view() -> void:
	var pills: Array[Button] = await _fill_with_pills(50)
	var scroll: ScrollContainer = screen.get_node("%DevicePillsScroll")

	await screen._scroll_to_selected_pill(45)
	# ensure_control_visible sets the scroll offset straight away, but the row is
	# only moved on the next layout pass, so the pill has not moved yet.
	await get_tree().process_frame

	var pill: Button = pills[45]
	assert_gte(pill.global_position.x, scroll.global_position.x - 1.0,
		"the selected device should not be off the left of the row")
	assert_lte(pill.global_position.x + pill.size.x,
		scroll.global_position.x + scroll.size.x + 1.0,
		"the selected device should not be off the right of the row")


func test_the_selected_device_is_in_view_on_the_first_open() -> void:
	# refresh_devices runs from _ready, so on the first open the pills exist but
	# have not been laid out. ensure_control_visible works off real geometry, and
	# called too early it scrolls to nowhere -- which is the case that matters,
	# since it is the one the teacher sees every time they open the settings.
	var pills: Array[Button] = _replace_pills(50)

	await screen._scroll_to_selected_pill(45)
	await get_tree().process_frame

	var scroll: ScrollContainer = screen.get_node("%DevicePillsScroll")
	var pill: Button = pills[45]
	assert_gt(scroll.scroll_horizontal, 0,
		"the row should have scrolled to reach the 46th device")
	assert_lte(pill.global_position.x + pill.size.x,
		scroll.global_position.x + scroll.size.x + 1.0,
		"the selected device should be on screen without the teacher scrolling")


func test_scrolling_away_from_the_selection_is_left_alone() -> void:
	# The selected pill is only chased when the selection changes, so a teacher
	# looking through their devices does not get yanked back.
	await _fill_with_pills(50)
	var scroll: ScrollContainer = screen.get_node("%DevicePillsScroll")

	scroll.scroll_horizontal = 4000
	await get_tree().process_frame
	var scrolled_to: int = scroll.scroll_horizontal
	await get_tree().process_frame

	assert_eq(scroll.scroll_horizontal, scrolled_to,
		"nothing should scroll the row back on its own")


func test_the_mouse_wheel_scrolls_the_device_row() -> void:
	# With no vertical bar to claim it, the wheel has to drive the horizontal one,
	# or the row is only reachable by dragging -- fine on a tablet, not on a desktop.
	await _fill_with_pills(50)
	var scroll: ScrollContainer = screen.get_node("%DevicePillsScroll")
	var before: int = scroll.scroll_horizontal

	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = scroll.global_position + scroll.size * 0.5
	# Local coordinates: a headless run has a 64x64 window, so the canvas
	# transform would otherwise put the event somewhere else entirely.
	scroll.get_viewport().push_input(wheel, true)
	await get_tree().process_frame

	assert_gt(scroll.scroll_horizontal, before,
		"the wheel should move the row when there is nowhere to scroll vertically")


func test_the_student_details_overlay_starts_hidden() -> void:
	# Regression: it opened over the screen on arrival, empty, because the
	# rebuild dropped `visible = false` from the instance.
	var overlay: Control = screen.get_node("LessonUnlocks")
	assert_false(overlay.visible,
		"the student details overlay should only appear when a student is opened")


func test_nothing_overlaps_the_back_button() -> void:
	# The back button is drawn over the page, so anything the page puts in that
	# corner is unreachable.
	var back: Control = screen.get_node("BackButton")
	var back_rect: Rect2 = Rect2(back.global_position, back.size)
	for path: String in ["Page/TitleRow/Gear", "Page/TitleRow/Title",
			"Page/ControlsRow/AccountTypeGroup", "Page/Card"]:
		var node: Control = screen.get_node(path)
		assert_false(back_rect.intersects(Rect2(node.global_position, node.size)),
			"%s should not sit under the back button" % path)


# --- Replacing the pills, not stacking them ------------------------------------
func test_a_rebuilt_pill_row_holds_only_the_new_pills() -> void:
	# Regression: the old pills were queue_freed, which defers to the end of the
	# frame, and the new ones were appended in the same call. show_device then
	# pressed get_child(index) with an index into the new device list, so a stale
	# pill in front of them shifted it -- adding a second device left device 1
	# highlighted while the grid showed device 2's students.
	var row: HBoxContainer = screen.get_node("%DevicePills")
	_replace_pills(1)
	await get_tree().process_frame
	assert_eq(row.get_child_count(), 1, "one device to start with")

	# What refresh_devices does: clear, then refill, in one call.
	screen._clear_now(row)
	var rebuilt: Array[Button] = _replace_pills_without_clearing(2)

	assert_eq(row.get_child_count(), 2,
		"the row should hold the new pills alone, with no frame of overlap")
	for index: int in rebuilt.size():
		assert_eq(row.get_child(index), rebuilt[index],
			"child %d should be the pill just built for it" % index)


func test_clearing_a_container_empties_it_at_once() -> void:
	var row: HBoxContainer = screen.get_node("%DevicePills")
	_replace_pills(3)
	await get_tree().process_frame
	assert_gt(row.get_child_count(), 0, "there is something to clear")

	screen._clear_now(row)

	assert_eq(row.get_child_count(), 0,
		"emptied immediately, so whatever refills it starts from nothing")


## Adds `count` pills without clearing what is already there.
func _replace_pills_without_clearing(count: int) -> Array[Button]:
	var row: HBoxContainer = screen.get_node("%DevicePills")
	var pills: Array[Button] = []
	for index: int in count:
		var pill: Button = Button.new()
		pill.text = "Appareil %d" % (index + 1)
		pill.custom_minimum_size = Vector2(Design.PILL_WIDTH, Design.PILL_HEIGHT)
		row.add_child(pill)
		pills.append(pill)
	return pills
