extends GutTest
## The bosses are editable rows of the student progress table.
##
## A boss stands between two gardens, and the teacher's table shows it where the
## child meets it: after the last lesson of the garden it closes. Marking one
## completed is the point of the feature -- it finishes every garden up to that
## boss and opens the one after it, which is the only way to move a child past a
## gate without making them play it.

const SCENE: String = "res://sources/menus/settings/lesson_unlocks.tscn"
const LOCKED: StudentProgression.Status = StudentProgression.Status.LOCKED
const UNLOCKED: StudentProgression.Status = StudentProgression.Status.UNLOCKED
const COMPLETED: StudentProgression.Status = StudentProgression.Status.COMPLETED

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


func _any_student() -> Dictionary:
	var settings: TeacherSettings = UserDataManager.teacher_settings
	if not settings:
		return {}
	for device: int in settings.students.keys():
		for student: StudentData in settings.students[device]:
			return {"device": device, "code": student.code}
	return {}


## Opens a student, which is what points the rows at a progression.
func _open_student() -> bool:
	var student: Dictionary = _any_student()
	if student.is_empty():
		pending("needs a registered student")
		return false
	overlay.device = student.device
	overlay.student = student.code
	if not overlay.progression:
		pending("needs a student with progression data")
		return false
	return true


func _boss_rows() -> Array[Node]:
	return overlay.boss_rows_store.get_children()


## The first gate the pack defines, or -1 when it defines none.
func _first_gate() -> int:
	var gates: Array[int] = StudentProgression.get_boss_gate_lessons()
	return gates[0] if not gates.is_empty() else -1


func _row_for_gate(gate_lesson: int) -> BossUnlock:
	for row: BossUnlock in _boss_rows():
		if row.gate_lesson == gate_lesson and not row.is_final:
			return row
	return null


func _final_row() -> BossUnlock:
	for row: BossUnlock in _boss_rows():
		if row.is_final:
			return row
	return null


func _lesson_row(lesson_number: int) -> LessonUnlock:
	for row: LessonUnlock in overlay.lesson_rows_store.get_children():
		if row.lesson_number == lesson_number:
			return row
	return null


# --- The rows themselves ---------------------------------------------------------
func test_there_is_a_row_per_gate_plus_the_final_boss() -> void:
	if _needs_pack():
		return
	overlay.prepare_lesson_rows()

	var gates: Array[int] = StudentProgression.get_boss_gate_lessons()
	assert_gt(gates.size(), 0, "the pack should place some bosses between its gardens")
	assert_eq(_boss_rows().size(), gates.size() + 1,
		"one row per gate, and one more for the final boss")
	for gate_lesson: int in gates:
		assert_not_null(_row_for_gate(gate_lesson),
			"the boss closing lesson %d should have a row" % gate_lesson)
	assert_not_null(_final_row(), "the final boss should have a row")


func test_a_boss_row_sits_right_after_the_lesson_it_closes() -> void:
	# The order is the whole point of interleaving them: a boss listed at the bottom
	# of the table would say nothing about which garden it closes.
	if _needs_pack():
		return
	overlay.prepare_lesson_rows()
	var gate_lesson: int = _first_gate()
	if gate_lesson < 0:
		pending("needs a pack with at least one gate")
		return
	var boss_row: BossUnlock = _row_for_gate(gate_lesson)

	var cells: Array[Node] = overlay.lessons_grid.get_children()
	var badge_position: int = cells.find(boss_row.boss_icon)
	assert_gt(badge_position, 0, "the boss row should be in the grid")
	# Four columns, so the cell four places earlier is the previous row's first.
	var gate_row: LessonUnlock = _lesson_row(gate_lesson)
	assert_not_null(gate_row, "lesson %d should have a row" % gate_lesson)
	if gate_row and badge_position >= 4:
		assert_eq(cells[badge_position - 4], gate_row.lesson_badge,
			"the boss should follow lesson %d" % gate_lesson)


func test_the_final_boss_row_is_last() -> void:
	if _needs_pack():
		return
	overlay.prepare_lesson_rows()

	var cells: Array[Node] = overlay.lessons_grid.get_children()
	assert_eq(cells[cells.size() - 4], _final_row().boss_icon,
		"the final boss closes the table")


func test_a_boss_row_wears_no_grapheme_and_names_itself() -> void:
	if _needs_pack():
		return
	overlay.prepare_lesson_rows()
	var gate_lesson: int = _first_gate()
	if gate_lesson < 0:
		pending("needs a pack with at least one gate")
		return

	assert_eq(_row_for_gate(gate_lesson).boss_label.text, tr("BOSS"))
	assert_eq(_final_row().boss_label.text, tr("FINAL_BOSS"))
	assert_null(_final_row().garden_animal.texture,
		"the final boss stands past every garden, so it borrows no animal")


# --- Editing ---------------------------------------------------------------------
func test_marking_a_boss_completed_finishes_every_garden_before_it() -> void:
	if _needs_pack():
		return
	if not _open_student():
		return
	var gate_lesson: int = _first_gate()
	if gate_lesson < 0:
		pending("needs a pack with at least one gate")
		return

	_row_for_gate(gate_lesson)._on_status_item_selected(COMPLETED)

	for lesson_number: int in range(1, gate_lesson + 1):
		assert_true(overlay.progression.is_lesson_completed(lesson_number),
			"lesson %d should be finished" % lesson_number)
	assert_true(overlay.progression.is_boss_completed(gate_lesson),
		"the boss should be recorded as beaten")


func test_marking_a_boss_completed_opens_the_next_garden() -> void:
	# The reason a teacher reaches for this: an unbeaten gate holds the child back
	# however many lessons are marked done behind it.
	if _needs_pack():
		return
	if not _open_student():
		return
	var gate_lesson: int = _first_gate()
	if gate_lesson < 0 or not overlay.progression.unlocks.has(gate_lesson + 1):
		pending("needs a gate with a lesson after it")
		return

	_row_for_gate(gate_lesson)._on_status_item_selected(COMPLETED)

	assert_eq(overlay.progression.unlocks[gate_lesson + 1]["look_and_learn"] as int,
		UNLOCKED as int, "the next garden's first lesson should be playable")
	assert_false(overlay.progression.is_lesson_blocked_by_boss(gate_lesson + 1),
		"and it should no longer be held back by the boss")


func test_leaving_a_boss_unbeaten_holds_the_next_garden_back() -> void:
	if _needs_pack():
		return
	if not _open_student():
		return
	var gate_lesson: int = _first_gate()
	if gate_lesson < 0 or not overlay.progression.unlocks.has(gate_lesson + 1):
		pending("needs a gate with a lesson after it")
		return
	var boss_row: BossUnlock = _row_for_gate(gate_lesson)
	boss_row._on_status_item_selected(COMPLETED)

	boss_row._on_status_item_selected(UNLOCKED)

	assert_true(overlay.progression.is_lesson_completed(gate_lesson),
		"the garden it closes stays finished")
	assert_false(overlay.progression.is_boss_completed(gate_lesson),
		"but the victory is given back")
	assert_true(overlay.progression.is_lesson_blocked_by_boss(gate_lesson + 1),
		"so the next garden is out of reach again")


func test_locking_a_boss_leaves_its_own_garden_unfinished() -> void:
	if _needs_pack():
		return
	if not _open_student():
		return
	var gate_lesson: int = _first_gate()
	if gate_lesson < 0:
		pending("needs a pack with at least one gate")
		return
	var boss_row: BossUnlock = _row_for_gate(gate_lesson)
	boss_row._on_status_item_selected(COMPLETED)

	boss_row._on_status_item_selected(LOCKED)

	assert_false(overlay.progression.is_lesson_completed(gate_lesson),
		"the garden goes back to unfinished, which is what puts the boss out of reach")
	assert_false(overlay.progression.is_boss_completed(gate_lesson))


func test_each_offered_state_reads_back_as_itself() -> void:
	if _needs_pack():
		return
	if not _open_student():
		return
	var gate_lesson: int = _first_gate()
	if gate_lesson < 0:
		pending("needs a pack with at least one gate")
		return
	var boss_row: BossUnlock = _row_for_gate(gate_lesson)

	for index: int in boss_row.status_option_button.item_count:
		var state: int = boss_row.status_option_button.get_item_id(index)
		boss_row._on_status_item_selected(index)
		assert_eq(boss_row.boss_state() as int, state,
			"state %d should read back as itself" % state)


func test_finishing_a_lesson_past_a_gate_clears_that_gate() -> void:
	# Without this a teacher who sets a late lesson as the frontier would hand the
	# child a game blocked at the first boss they never played.
	if _needs_pack():
		return
	if not _open_student():
		return
	var gate_lesson: int = _first_gate()
	if gate_lesson < 0 or not overlay.progression.unlocks.has(gate_lesson + 1):
		pending("needs a gate with a lesson after it")
		return
	var lesson_row: LessonUnlock = _lesson_row(gate_lesson + 1)
	assert_not_null(lesson_row)
	if not lesson_row:
		return

	lesson_row._on_status_item_selected(lesson_row.status_option_button.item_count - 1)
	overlay._on_row_edited()

	assert_true(overlay.progression.is_boss_completed(gate_lesson),
		"the gate the finished lesson sits behind must have been passed")
	assert_eq(_row_for_gate(gate_lesson).boss_state() as int, COMPLETED as int,
		"and the row should say so")


func test_pulling_an_early_lesson_back_takes_the_later_bosses_with_it() -> void:
	if _needs_pack():
		return
	if not _open_student():
		return
	var gate_lesson: int = _first_gate()
	if gate_lesson < 1:
		pending("needs a pack with at least one gate")
		return
	_row_for_gate(gate_lesson)._on_status_item_selected(COMPLETED)
	var first_lesson_row: LessonUnlock = overlay.lesson_rows_store.get_child(0)

	first_lesson_row._on_status_item_selected(LessonUnlock.State.LOOK_AND_LEARN)
	overlay._on_row_edited()

	assert_false(overlay.progression.is_boss_completed(gate_lesson),
		"a boss cannot stay beaten when its garden was never finished")
	assert_eq(_row_for_gate(gate_lesson).boss_state() as int, LOCKED as int)


func test_the_final_boss_is_beaten_by_marking_its_row_completed() -> void:
	if _needs_pack():
		return
	if not _open_student():
		return
	var final_row: BossUnlock = _final_row()
	assert_not_null(final_row)
	if not final_row:
		return

	final_row._on_status_item_selected(COMPLETED)

	assert_true(overlay.progression.is_final_boss_completed(),
		"the treasure should be unlocked")
	for gate_lesson: int in StudentProgression.get_boss_gate_lessons():
		assert_true(overlay.progression.is_boss_completed(gate_lesson),
			"and every gate before it cleared")
	assert_eq(final_row.boss_state() as int, COMPLETED as int)


func test_giving_the_final_boss_back_leaves_the_reading_done() -> void:
	if _needs_pack():
		return
	if not _open_student():
		return
	var final_row: BossUnlock = _final_row()
	if not final_row:
		return
	final_row._on_status_item_selected(COMPLETED)

	final_row._on_status_item_selected(UNLOCKED)

	assert_false(overlay.progression.is_final_boss_completed())
	assert_true(overlay.progression.is_lesson_completed(final_row.gate_lesson),
		"the last lesson stays finished, so the treasure is still in reach")
	assert_eq(final_row.boss_state() as int, UNLOCKED as int)


func test_a_boss_row_is_inert_before_a_student_is_chosen() -> void:
	if _needs_pack():
		return
	overlay.prepare_lesson_rows()

	for row: BossUnlock in _boss_rows():
		assert_true(row.status_option_button.disabled,
			"there is no progression to edit yet")
