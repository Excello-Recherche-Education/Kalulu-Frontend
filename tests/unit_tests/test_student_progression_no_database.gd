extends GutTest

# Regression tests for the progression wipe that happened on a fresh install.
# Every integrity rule in StudentProgression is expressed relative to
# Database.get_lessons_count(). Wiping user:// also removes the language pack, so
# the first synchronization ran with a closed database: it reported 0 lessons,
# which was read as "every lesson is out of range". The whole progression was
# erased — including the copy the server had just sent back — and the emptied
# result was then pushed to the server on the next synchronization.

const COMPLETED: StudentProgression.Status = StudentProgression.Status.COMPLETED

var _saved_path: String
var _saved_is_open: bool


func before_each() -> void:
	# Preserve the autoload state so closing the database here cannot leak into
	# the other suites.
	_saved_path = Database.db.path
	_saved_is_open = Database.is_open
	Database.close()


func after_each() -> void:
	Database.db.path = _saved_path
	if _saved_is_open:
		Database.connect_to_db()


# Every guarded path warns when the database is missing — Database when the
# lesson count is asked for, StudentProgression when it refuses to prune. Those
# warnings are the signal that would have exposed this bug in production, so
# acknowledge them instead of letting GUT report them as unexpected errors. This
# must run inside the test itself: GUT checks for unhandled errors before
# after_each().
func _accept_missing_database_warnings() -> void:
	for tracked_error: GutTrackedError in get_errors():
		tracked_error.handled = true


# Mirrors what the server sends back for a student who finished the whole game.
func _make_completed_unlocks(lesson_count: int) -> Dictionary[int, Dictionary]:
	var unlocks: Dictionary[int, Dictionary] = {}
	for lesson_number: int in range(1, lesson_count + 1):
		unlocks[lesson_number] = {
			"games": [COMPLETED, COMPLETED, COMPLETED],
			"look_and_learn": COMPLETED,
			"last_duration": PackedInt32Array([0, 0, 0]),
			"total_duration": PackedInt32Array([0, 0, 0]),
		}
	return unlocks


func test_lesson_database_is_reported_unavailable_when_closed() -> void:
	assert_false(StudentProgression.is_lesson_database_available())
	_accept_missing_database_warnings()


func test_integrity_check_keeps_every_lesson_when_the_database_is_closed() -> void:
	var progression: StudentProgression = StudentProgression.new()
	var result: Dictionary = progression.ensure_data_integrity(_make_completed_unlocks(60))
	assert_eq(result.size(), 60)
	assert_eq(result[60]["look_and_learn"] as int, COMPLETED as int)
	_accept_missing_database_warnings()


func test_assigning_unlocks_keeps_them_when_the_database_is_closed() -> void:
	var progression: StudentProgression = StudentProgression.new()
	progression.unlocks = _make_completed_unlocks(60)
	assert_eq(progression.unlocks.size(), 60)
	assert_eq_deep(progression.unlocks[1]["games"], [COMPLETED, COMPLETED, COMPLETED])
	_accept_missing_database_warnings()


func test_highest_boss_defeated_is_not_clamped_when_the_database_is_closed() -> void:
	var progression: StudentProgression = StudentProgression.new()
	# 61 is the "final boss beaten" marker for a 60-lesson pack. It used to be
	# clamped to 1, because the final boss value was computed as 0 + 1.
	progression.highest_boss_defeated = 61
	assert_eq(progression.highest_boss_defeated, 61)
	_accept_missing_database_warnings()


func test_init_unlocks_does_not_replace_loaded_data_when_the_database_is_closed() -> void:
	var progression: StudentProgression = StudentProgression.new()
	progression.unlocks = _make_completed_unlocks(60)
	progression.init_unlocks()
	assert_eq(progression.unlocks.size(), 60)
	assert_eq(progression.unlocks[30]["look_and_learn"] as int, COMPLETED as int)
	_accept_missing_database_warnings()
