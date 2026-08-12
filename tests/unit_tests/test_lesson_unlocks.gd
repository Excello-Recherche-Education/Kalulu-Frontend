extends GutTest
## The student progression panel builds its rows once and refills them.
##
## Opening a student used to take seconds: the panel rebuilt all sixty lesson
## rows -- six controls each, four of them self-populating dropdowns -- every
## time, and rebuilt them again on every dropdown edit. It also cleared the old
## rows with queue_free() while adding the new ones immediately, so the grid
## doubled on each open and got slower as it went.
##
## Asserted through node identity and counts rather than timings, which are too
## machine-dependent to gate a build on.

const SCENE: String = "res://sources/menus/settings/lesson_unlocks.tscn"

var overlay: LessonUnlocks


func before_each() -> void:
	overlay = (load(SCENE) as PackedScene).instantiate()
	add_child_autofree(overlay)
	await get_tree().process_frame


func _needs_pack() -> bool:
	if Database.is_open:
		return false
	pending("needs an installed language pack to read the lesson list")
	return true


func _row_ids() -> Array[int]:
	var ids: Array[int] = []
	for row: Node in overlay.lesson_rows_store.get_children():
		ids.append(row.get_instance_id())
	return ids


func test_preparing_builds_a_row_per_lesson() -> void:
	if _needs_pack():
		return
	overlay.prepare_lesson_rows()

	var lessons: int = overlay._query_lessons().size()
	assert_gt(lessons, 0, "the pack should define some lessons")
	assert_eq(overlay.lesson_rows_store.get_child_count(), lessons,
		"one row per lesson")


func test_preparing_twice_does_not_duplicate_the_rows() -> void:
	if _needs_pack():
		return
	overlay.prepare_lesson_rows()
	var before: Array[int] = _row_ids()

	overlay.prepare_lesson_rows()

	assert_eq(_row_ids(), before, "the rows should be reused, not rebuilt")


func test_preparing_works_before_any_student_is_chosen() -> void:
	# This is the point of preparing: settings does it while it is already
	# loading, long before a student is tapped.
	if _needs_pack():
		return
	assert_null(overlay.progression)

	overlay.prepare_lesson_rows()

	assert_gt(overlay.lesson_rows_store.get_child_count(), 0,
		"rows should build with no student loaded")
	assert_gt(overlay.lessons_grid.get_child_count(), 0,
		"and their cells should be in the grid")


func test_opening_a_student_refills_the_rows_instead_of_rebuilding() -> void:
	if _needs_pack():
		return
	var student: Dictionary = _any_student()
	if student.is_empty():
		pending("needs a registered student")
		return
	overlay.prepare_lesson_rows()
	var before: Array[int] = _row_ids()
	var cells_before: int = overlay.lessons_grid.get_child_count()

	overlay.device = student.device
	overlay.student = student.code

	assert_eq(_row_ids(), before, "opening a student should reuse the rows")
	assert_eq(overlay.lessons_grid.get_child_count(), cells_before,
		"and must not add more cells to the grid")


func test_opening_students_repeatedly_does_not_grow_the_grid() -> void:
	# The accumulation bug: queue_free() is deferred, so the rebuild in the same
	# frame added its rows next to the old ones.
	if _needs_pack():
		return
	var student: Dictionary = _any_student()
	if student.is_empty():
		pending("needs a registered student")
		return
	overlay.device = student.device
	overlay.student = student.code
	var rows: int = overlay.lesson_rows_store.get_child_count()
	var cells: int = overlay.lessons_grid.get_child_count()

	for _attempt: int in 3:
		overlay.student = student.code

	assert_eq(overlay.lesson_rows_store.get_child_count(), rows,
		"the row count should be stable across opens")
	assert_eq(overlay.lessons_grid.get_child_count(), cells,
		"the grid should not grow on every open")


func test_a_dropdown_edit_refreshes_rather_than_rebuilds() -> void:
	# unlocks_changed used to be wired to the full rebuild, so a teacher adjusting
	# one lesson paid for the whole grid again.
	if _needs_pack():
		return
	var student: Dictionary = _any_student()
	if student.is_empty():
		pending("needs a registered student")
		return
	overlay.device = student.device
	overlay.student = student.code
	var before: Array[int] = _row_ids()

	var row: LessonUnlock = overlay.lesson_rows_store.get_child(0)
	row.unlocks_changed.emit()

	assert_eq(_row_ids(), before, "an edit should not rebuild the rows")


func _rows() -> Array[Node]:
	var student: Dictionary = _any_student()
	if student.is_empty():
		pending("needs a registered student")
		return []
	overlay.device = student.device
	overlay.student = student.code
	return overlay.lesson_rows_store.get_children()


func test_a_lesson_offers_one_state_per_step_plus_locked_and_finished() -> void:
	# A lesson has one to three minigames, so it offers three to six states.
	if _needs_pack():
		return
	var rows: Array[Node] = _rows()
	if rows.is_empty():
		return

	for row: LessonUnlock in rows:
		var games: int = (row.unlocks[row.lesson_number]["games"] as Array).size()
		assert_between(games, 1, LessonUnlock.MAX_EXERCISES,
			"lesson %d should have one to three minigames" % row.lesson_number)
		# locked + look-and-learn + one per exercise + finished
		assert_eq(row.status_option_button.item_count, games + 3,
			"lesson %d offers locked, look-and-learn, %d exercises and finished"
				% [row.lesson_number, games])


func test_each_offered_state_reads_back_as_itself() -> void:
	if _needs_pack():
		return
	var rows: Array[Node] = _rows()
	if rows.size() < 2:
		pending("needs at least two lessons")
		return
	var row: LessonUnlock = rows[1]

	for index: int in row.status_option_button.item_count:
		var state: int = row.status_option_button.get_item_id(index)
		row._on_status_item_selected(index)
		assert_eq(row.lesson_state(), state,
			"state %d should read back as itself" % state)


func test_being_on_an_exercise_means_the_steps_before_it_are_finished() -> void:
	# "Exercise 2" means exercise 1 is finished and the look-and-learn with it.
	if _needs_pack():
		return
	var rows: Array[Node] = _rows()
	if rows.is_empty():
		return
	var row: LessonUnlock = rows[0]
	if row.status_option_button.item_count < 5:
		pending("needs a lesson with at least two exercises")
		return

	row._on_status_item_selected(row.status_option_button.item_count - 2)

	var entry: Dictionary = row.unlocks[row.lesson_number]
	assert_eq(entry["look_and_learn"], StudentProgression.Status.COMPLETED,
		"the look-and-learn should be finished")
	var games: Array = entry["games"]
	for index: int in games.size() - 1:
		assert_eq(games[index], StudentProgression.Status.COMPLETED,
			"exercise %d should be finished" % (index + 1))
	assert_eq(games[games.size() - 1], StudentProgression.Status.UNLOCKED,
		"the last exercise should be the one now playable")


func test_finishing_a_lesson_puts_the_next_one_on_its_look_and_learn() -> void:
	# The rule that ties the lessons together.
	if _needs_pack():
		return
	var rows: Array[Node] = _rows()
	if rows.size() < 2:
		pending("needs at least two lessons")
		return

	var first: LessonUnlock = rows[0]
	first._on_status_item_selected(first.status_option_button.item_count - 1)

	assert_eq(first.lesson_state(), LessonUnlock.State.FINISHED)
	assert_eq((rows[1] as LessonUnlock).lesson_state(), LessonUnlock.State.LOOK_AND_LEARN,
		"finishing a lesson must open the next one's look-and-learn")


func test_finishing_a_later_lesson_finishes_the_ones_before_it() -> void:
	if _needs_pack():
		return
	var rows: Array[Node] = _rows()
	if rows.size() < 3:
		pending("needs at least three lessons")
		return

	var third: LessonUnlock = rows[2]
	third._on_status_item_selected(third.status_option_button.item_count - 1)

	for index: int in 3:
		assert_eq((rows[index] as LessonUnlock).lesson_state(), LessonUnlock.State.FINISHED,
			"lesson %d should be finished" % (index + 1))


func test_locking_a_lesson_locks_the_ones_after_it() -> void:
	if _needs_pack():
		return
	var rows: Array[Node] = _rows()
	if rows.size() < 4:
		pending("needs at least four lessons")
		return
	(rows[3] as LessonUnlock)._on_status_item_selected(
		(rows[3] as LessonUnlock).status_option_button.item_count - 1)

	(rows[1] as LessonUnlock)._on_status_item_selected(LessonUnlock.State.LOCKED)

	for index: int in range(1, 4):
		assert_eq((rows[index] as LessonUnlock).lesson_state(), LessonUnlock.State.LOCKED,
			"lesson %d should be locked" % (index + 1))


func _any_student() -> Dictionary:
	var settings: TeacherSettings = UserDataManager.teacher_settings
	if not settings:
		return {}
	for device: int in settings.students.keys():
		for student: StudentData in settings.students[device]:
			return {"device": device, "code": student.code}
	return {}


# --- Each row is marked with the garden the lesson belongs to --------------------
func test_every_row_carries_its_garden() -> void:
	if _needs_pack():
		return
	overlay.prepare_lesson_rows()

	var rows: Array[Node] = overlay.lesson_rows_store.get_children()
	var distribution: Array[int] = Gardens.compute_lessons_distribution(rows.size())
	for row: LessonUnlock in rows:
		assert_eq(row.garden_index,
			Gardens.garden_index_for_lesson(row.lesson_number, distribution),
			"lesson %d should sit in the garden the gardens screen puts it in" % row.lesson_number)
		assert_not_null(row.garden_animal.texture,
			"lesson %d should show its garden's animal" % row.lesson_number)


func test_the_rows_take_their_colours_from_their_own_garden() -> void:
	# Regression guard for the obvious way to build this: one style box authored in
	# the scene is shared between every instance of it, so all sixty rows would come
	# out the colour of whichever garden was painted last.
	if _needs_pack():
		return
	overlay.prepare_lesson_rows()

	var seen: Dictionary[int, Color] = {}
	for row: LessonUnlock in overlay.lesson_rows_store.get_children():
		var fill: StyleBoxFlat = row.lesson_badge.get_theme_stylebox("panel") as StyleBoxFlat
		assert_not_null(fill, "lesson %d should have a badge to sit in" % row.lesson_number)
		if not fill:
			continue
		assert_eq(fill.bg_color, GardenIdentity.badge_color(row.garden_index),
			"lesson %d should wear its own garden's colour" % row.lesson_number)
		seen[row.garden_index] = fill.bg_color
	assert_gt(seen.size(), 1, "sixty lessons span more than one garden")


func test_the_badges_are_round() -> void:
	if _needs_pack():
		return
	overlay.prepare_lesson_rows()

	var row: LessonUnlock = overlay.lesson_rows_store.get_child(0)
	for badge: Panel in [row.lesson_badge, row.grapheme_badge]:
		var fill: StyleBoxFlat = badge.get_theme_stylebox("panel") as StyleBoxFlat
		assert_eq(fill.corner_radius_top_left, floori(float(LessonUnlock.BADGE_DIAMETER) / 2.0),
			"a corner radius of half the side is what makes the square a circle")
		assert_eq(badge.custom_minimum_size.x, badge.custom_minimum_size.y,
			"and it has to be square to begin with")


func test_a_row_shows_one_grapheme_rather_than_the_whole_lesson() -> void:
	if _needs_pack():
		return
	overlay.prepare_lesson_rows()

	for row: LessonUnlock in overlay.lesson_rows_store.get_children():
		assert_false(row.grapheme_label.text.contains(" "),
			"lesson %d should name one grapheme, not the list" % row.lesson_number)
		assert_false(row.grapheme_label.text.contains("-"),
			"lesson %d should show the grapheme without its phoneme" % row.lesson_number)
		assert_false(row.grapheme_label.text.is_empty(),
			"lesson %d should name a grapheme" % row.lesson_number)


func test_the_first_grapheme_is_cut_out_of_the_joined_pairs() -> void:
	assert_eq(LessonUnlock.first_grapheme("a-a à-a â-a"), "a")
	assert_eq(LessonUnlock.first_grapheme("e-%"), "e")
	assert_eq(LessonUnlock.first_grapheme("ll-l l-l"), "ll")
	assert_eq(LessonUnlock.first_grapheme(""), "", "a lesson with no pairs shows nothing")


func test_the_grapheme_fits_inside_its_badge() -> void:
	# The badge is a fixed circle, so the longest grapheme the pack teaches has to
	# fit in it -- there is no room for it to grow into.
	if _needs_pack():
		return
	overlay.prepare_lesson_rows()

	var longest: String = ""
	for row: LessonUnlock in overlay.lesson_rows_store.get_children():
		if row.grapheme_label.text.length() > longest.length():
			longest = row.grapheme_label.text
	var label: Label = (overlay.lesson_rows_store.get_child(0) as LessonUnlock).grapheme_label
	var font: Font = label.get_theme_font("font")
	var size: int = label.get_theme_font_size("font_size")
	var width: float = font.get_string_size(longest, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	assert_lt(width, float(LessonUnlock.BADGE_DIAMETER),
		"\"%s\" is the longest grapheme and it has to fit the badge" % longest)
