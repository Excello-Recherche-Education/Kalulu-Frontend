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


func test_completing_a_lesson_completes_the_ones_before_it() -> void:
	# Progression is one linear timeline, so a later lesson being finished means
	# the earlier ones are too. That is why an edit refreshes every row.
	if _needs_pack():
		return
	var student: Dictionary = _any_student()
	if student.is_empty():
		pending("needs a registered student")
		return
	overlay.device = student.device
	overlay.student = student.code
	if overlay.lesson_rows_store.get_child_count() < 3:
		pending("needs at least three lessons")
		return

	var third: LessonUnlock = overlay.lesson_rows_store.get_child(2)
	third._on_status_item_selected(StudentProgression.Status.COMPLETED)

	for index: int in 3:
		var row: LessonUnlock = overlay.lesson_rows_store.get_child(index)
		assert_eq(row.lesson_status(), StudentProgression.Status.COMPLETED,
			"lesson %d should be completed" % (index + 1))


func test_locking_a_lesson_locks_the_ones_after_it() -> void:
	if _needs_pack():
		return
	var student: Dictionary = _any_student()
	if student.is_empty():
		pending("needs a registered student")
		return
	overlay.device = student.device
	overlay.student = student.code
	if overlay.lesson_rows_store.get_child_count() < 4:
		pending("needs at least four lessons")
		return
	overlay.lesson_rows_store.get_child(3)._on_status_item_selected(
		StudentProgression.Status.COMPLETED)

	overlay.lesson_rows_store.get_child(1)._on_status_item_selected(
		StudentProgression.Status.LOCKED)

	for index: int in range(1, 4):
		var row: LessonUnlock = overlay.lesson_rows_store.get_child(index)
		assert_eq(row.lesson_status(), StudentProgression.Status.LOCKED,
			"lesson %d should be locked" % (index + 1))


func test_a_lesson_reads_back_the_status_it_was_given() -> void:
	if _needs_pack():
		return
	var student: Dictionary = _any_student()
	if student.is_empty():
		pending("needs a registered student")
		return
	overlay.device = student.device
	overlay.student = student.code
	if overlay.lesson_rows_store.get_child_count() < 2:
		pending("needs at least two lessons")
		return
	var second: LessonUnlock = overlay.lesson_rows_store.get_child(1)

	for status: StudentProgression.Status in [StudentProgression.Status.COMPLETED,
			StudentProgression.Status.UNLOCKED, StudentProgression.Status.LOCKED]:
		second._on_status_item_selected(status)
		assert_eq(second.lesson_status(), status,
			"a lesson set to %d should read back as %d" % [status, status])
		assert_eq(second.status_option_button.selected, status as int,
			"and its dropdown should show it")


func _any_student() -> Dictionary:
	var settings: TeacherSettings = UserDataManager.teacher_settings
	if not settings:
		return {}
	for device: int in settings.students.keys():
		for student: StudentData in settings.students[device]:
			return {"device": device, "code": student.code}
	return {}
