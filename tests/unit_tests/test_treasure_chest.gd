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
	var sparkles: GPUParticles2D = GPUParticles2D.new()
	sparkles.name = "Sparkles"
	sparkles.top_level = true
	chest.add_child(sparkles)
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
