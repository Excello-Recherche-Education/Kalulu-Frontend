extends GutTest

# The brain screen's chest has two textures of different sizes (the opened one is
# taller — the carrots stick out of the box), so TreasureChest keeps them aligned on
# the chest's base rather than on the rect's top-left corner: opening the chest grows
# it upward instead of moving it and squashing it into the closed one's box. It also
# moves the pivot down to that base so the attract animation rocks the chest on the
# ground. Both are pure geometry, so they are pinned down here.

# Authored values of Brain/Treasure in sources/brain/brain.tscn.
const AUTHORED_POSITION: Vector2 = Vector2(1735, 1341)
const AUTHORED_SIZE: Vector2 = Vector2(518, 440)
const AUTHORED_SCALE: Vector2 = Vector2(0.2, 0.2)
const TOLERANCE: Vector2 = Vector2(0.01, 0.01)


# Rebuilds the authored node instead of instantiating the whole brain scene, so the
# geometry is checked on its own.
func _make_chest() -> TreasureChest:
	var chest: TreasureChest = TreasureChest.new()
	var chest_button: Button = Button.new()
	chest_button.name = "TreasureButton"
	chest_button.disabled = true
	chest.add_child(chest_button)
	var sparkles: GPUParticles2D = GPUParticles2D.new()
	sparkles.name = "Sparkles"
	sparkles.top_level = true
	chest.add_child(sparkles)
	var hand: Sprite2D = Sprite2D.new()
	hand.name = "PointingHand"
	hand.top_level = true
	hand.centered = false
	hand.hide()
	hand.modulate.a = 0.0
	chest.add_child(hand)
	chest.texture = TreasureChest.CLOSED_TEXTURE
	chest.position = AUTHORED_POSITION
	chest.size = AUTHORED_SIZE
	chest.scale = AUTHORED_SCALE
	add_child_autofree(chest)
	return chest


# The rect the chest actually covers in its parent's space, pivot and scale included.
func _visible_rect(chest: TreasureChest) -> Rect2:
	var chest_transform: Transform2D = chest.get_transform()
	var top_left: Vector2 = chest_transform * Vector2.ZERO
	return Rect2(top_left, chest_transform * chest.size - top_left)


# Where the chest stands: the middle of its bottom edge.
func _visible_base(chest: TreasureChest) -> Vector2:
	var rect: Rect2 = _visible_rect(chest)
	return Vector2(rect.position.x + rect.size.x * 0.5, rect.end.y)


func test_moving_the_pivot_to_the_base_does_not_move_the_closed_chest() -> void:
	var chest: TreasureChest = _make_chest()
	var rect: Rect2 = _visible_rect(chest)
	assert_almost_eq(rect.position, AUTHORED_POSITION, TOLERANCE)
	assert_almost_eq(rect.size, AUTHORED_SIZE * AUTHORED_SCALE, TOLERANCE)


func test_pivot_sits_on_the_bottom_centre_so_the_chest_rocks_on_its_base() -> void:
	var chest: TreasureChest = _make_chest()
	assert_eq(chest.pivot_offset, Vector2(AUTHORED_SIZE.x * 0.5, AUTHORED_SIZE.y))


func test_opening_the_chest_keeps_it_standing_on_the_same_spot() -> void:
	var chest: TreasureChest = _make_chest()
	var closed_base: Vector2 = _visible_base(chest)
	chest.set_opened(true)
	assert_almost_eq(_visible_base(chest), closed_base, TOLERANCE)


func test_opening_the_chest_does_not_squash_the_opened_texture() -> void:
	var chest: TreasureChest = _make_chest()
	chest.set_opened(true)
	var opened_size: Vector2 = TreasureChest.OPENED_TEXTURE.get_size()
	assert_eq(chest.size, opened_size)
	assert_almost_eq(_visible_rect(chest).size, opened_size * AUTHORED_SCALE, TOLERANCE)


func test_closing_the_chest_again_restores_the_authored_rect() -> void:
	var chest: TreasureChest = _make_chest()
	chest.set_opened(true)
	chest.set_opened(false)
	var rect: Rect2 = _visible_rect(chest)
	assert_almost_eq(rect.position, AUTHORED_POSITION, TOLERANCE)
	assert_almost_eq(rect.size, AUTHORED_SIZE * AUTHORED_SCALE, TOLERANCE)


func test_attract_runs_the_sparkles_and_reports_itself() -> void:
	var chest: TreasureChest = _make_chest()
	assert_false(chest.is_attracting())
	assert_false(chest.sparkles.emitting)
	chest.start_attract()
	assert_true(chest.is_attracting())
	assert_true(chest.sparkles.emitting)
	assert_almost_eq(chest.sparkles.global_position, chest.get_visible_center(), TOLERANCE)


func test_stopping_the_attract_restores_the_authored_transform() -> void:
	var chest: TreasureChest = _make_chest()
	chest.start_attract()
	# Stand in for the tweens mid-swing: stopping must leave nothing behind.
	chest.rotation = TreasureChest.ROCK_ANGLE
	chest.scale = AUTHORED_SCALE * TreasureChest.PULSE_RATIO
	chest.stop_attract()
	assert_false(chest.is_attracting())
	assert_false(chest.sparkles.emitting)
	assert_eq(chest.rotation, 0.0)
	assert_eq(chest.scale, AUTHORED_SCALE)


func test_stopping_the_attract_before_it_started_is_harmless() -> void:
	var chest: TreasureChest = _make_chest()
	chest.stop_attract()
	assert_false(chest.is_attracting())
	assert_eq(chest.scale, AUTHORED_SCALE)


# A disabled Control still hands its cursor shape to the viewport, so a chest that
# cannot be opened yet must not be left holding the hand cursor.
func test_a_chest_that_cannot_be_opened_keeps_the_plain_cursor() -> void:
	var chest: TreasureChest = _make_chest()
	chest.set_clickable(false)
	assert_true(chest.button.disabled)
	assert_eq(chest.button.mouse_default_cursor_shape, Control.CURSOR_ARROW)


func test_a_chest_that_can_be_opened_shows_the_hand_cursor() -> void:
	var chest: TreasureChest = _make_chest()
	chest.set_clickable(true)
	assert_false(chest.button.disabled)
	assert_eq(chest.button.mouse_default_cursor_shape, Control.CURSOR_POINTING_HAND)


func test_the_hand_cursor_is_taken_back_when_the_chest_locks_again() -> void:
	var chest: TreasureChest = _make_chest()
	chest.set_clickable(true)
	chest.set_clickable(false)
	assert_eq(chest.button.mouse_default_cursor_shape, Control.CURSOR_ARROW)


# -----------------------------
# Pointing hand
# -----------------------------
func test_the_pointing_hand_stays_hidden_while_the_delay_runs() -> void:
	var chest: TreasureChest = _make_chest()
	chest.start_attract()
	assert_false(chest.pointing_hand.visible)
	assert_eq(chest.pointing_hand.modulate.a, 0.0)


# The texture's top-left corner marks the spot being pointed at, so it must land on the
# middle of the chest's resting right side — clear of the chest, with the finger aiming
# back into it.
func test_the_pointing_hand_is_anchored_on_the_chest_right_side() -> void:
	var chest: TreasureChest = _make_chest()
	chest.start_attract()
	var resting: Vector2 = AUTHORED_POSITION + Vector2(AUTHORED_SIZE.x, AUTHORED_SIZE.y * 0.5) * AUTHORED_SCALE
	assert_almost_eq(chest.pointing_hand.position, resting, TOLERANCE)


# The chest is animated under it, but the hand itself must not move.
func test_the_pointing_hand_ignores_the_breathing_scale() -> void:
	var chest: TreasureChest = _make_chest()
	chest.start_attract()
	var anchored: Vector2 = chest.pointing_hand.position
	chest.scale = AUTHORED_SCALE * TreasureChest.PULSE_RATIO
	chest.rotation = TreasureChest.ROCK_ANGLE
	chest.stop_attract()
	chest.start_attract()
	assert_almost_eq(chest.pointing_hand.position, anchored, TOLERANCE)


func test_stopping_the_attract_takes_the_pointing_hand_away() -> void:
	var chest: TreasureChest = _make_chest()
	chest.start_attract()
	# Stand in for the tween having faded the hand all the way in.
	chest.pointing_hand.show()
	chest.pointing_hand.modulate.a = 1.0
	chest.stop_attract()
	assert_false(chest.pointing_hand.visible)
	assert_eq(chest.pointing_hand.modulate.a, 0.0)
