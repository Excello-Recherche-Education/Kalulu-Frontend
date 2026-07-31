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
