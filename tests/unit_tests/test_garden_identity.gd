extends GutTest
## Holds GardenIdentity to what the garden scenes say.
##
## The teacher's progress table names a garden on every one of its sixty rows, and
## loading a garden scene to do it would pull in a dozen full-size textures per
## garden -- which is exactly what gardens.gd avoids. So the few fields the table
## needs are copied into GardenIdentity, and copies go stale: recolour a garden or
## give it a new animal and nothing would say the table disagrees. This is what
## says it.


## The garden, ready to be read, or null when the scene will not give one up.
func _garden(garden_index: int) -> Garden:
	var scene: PackedScene = load(Gardens.GARDEN_SCENE_PATHS[garden_index]) as PackedScene
	if not scene:
		return null
	var garden: Garden = scene.instantiate() as Garden
	if garden:
		# Added to the tree so the exported node references resolve; freed with the
		# test, because twelve gardens' worth of art is not something to hold on to.
		add_child_autofree(garden)
	return garden


func test_there_is_an_entry_for_every_garden() -> void:
	assert_eq(GardenIdentity.GARDENS.size(), Gardens.GARDEN_SCENE_PATHS.size(),
		"every garden the game builds needs an entry the table can read")
	assert_eq(GardenIdentity.GARDENS.size(), Gardens.GARDENS_COUNT,
		"and there should be as many as the gardens screen counts on")


func test_every_entry_names_the_animal_its_garden_shows() -> void:
	for garden_index: int in GardenIdentity.GARDENS.size():
		var garden: Garden = _garden(garden_index)
		assert_not_null(garden, "garden %d should load" % (garden_index + 1))
		if not garden:
			continue
		assert_false(garden.animal_sprites.is_empty(),
			"garden %d should have an animal" % (garden_index + 1))
		if garden.animal_sprites.is_empty():
			continue
		var shown: Texture2D = garden.animal_sprites[0].texture
		assert_not_null(shown, "garden %d's animal should have a texture" % (garden_index + 1))
		if not shown:
			continue
		assert_eq(GardenIdentity.animal_texture(garden_index), shown,
			"the table should show garden %d's own animal (%s)"
			% [garden_index + 1, garden.title])


func test_every_entry_uses_the_colours_its_garden_gives_a_finished_lesson() -> void:
	# The badge borrows the lesson button's pair rather than picking its own, so a
	# number in the table is the colour of the lesson the child sees -- and the pair
	# is known to be legible together, because the game already prints on it.
	for garden_index: int in GardenIdentity.GARDENS.size():
		var garden: Garden = _garden(garden_index)
		if not garden:
			continue
		_assert_same_color(GardenIdentity.badge_color(garden_index), garden.completed_lesson,
			"garden %d's badge should be its finished-lesson fill" % (garden_index + 1))
		_assert_same_color(GardenIdentity.badge_text_color(garden_index),
			garden.completed_lesson_text,
			"garden %d's badge should be written in its finished-lesson ink" % (garden_index + 1))


## Compares two colours as colours.
##
## Approximately, not exactly: the table writes them as hex and a scene file stores
## them as rounded decimals, so the two never match to the last bit.
func _assert_same_color(actual: Color, expected: Color, message: String) -> void:
	assert_true(actual.is_equal_approx(expected),
		"%s -- table says %s, garden says %s" % [message, actual.to_html(false), expected.to_html(false)])


func test_an_index_no_garden_answers_to_is_survivable() -> void:
	# A row whose garden is unknown -- a progression from a pack with more lessons
	# than the gardens can hold -- still has to draw something.
	for stray: int in [-1, GardenIdentity.GARDENS.size(), 999]:
		assert_null(GardenIdentity.animal_texture(stray),
			"there is no animal for garden index %d" % stray)
		assert_eq(GardenIdentity.badge_color(stray), Design.GREY_LIGHTER,
			"and its badge falls back to a plain one")
		assert_eq(GardenIdentity.badge_text_color(stray), Design.NAVY)
