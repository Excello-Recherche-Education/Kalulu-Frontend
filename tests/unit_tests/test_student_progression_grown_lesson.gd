extends GutTest

# Regression tests for a language pack that gives a lesson more minigames than it
# had when the student played it. The extra slots start LOCKED, so the lesson can
# no longer read as completed, and the sequential rules used to treat that as a
# hole in the progression and reset every following lesson. A student who had
# finished all 60 lessons was sent back to lesson 1 by two extra minigames added
# to lesson 1.

const TEST_DIR: String = "user://test_progression_grown_lesson"
const TEST_DB: String = TEST_DIR + "/language.db"
const MODEL_DB: String = "res://model_database.db"
const LESSON_COUNT: int = 5
const MINIGAMES_PER_LESSON: int = 3
const LOCKED: StudentProgression.Status = StudentProgression.Status.LOCKED
const UNLOCKED: StudentProgression.Status = StudentProgression.Status.UNLOCKED
const COMPLETED: StudentProgression.Status = StudentProgression.Status.COMPLETED

var _saved_path: String
var _saved_is_open: bool


func before_each() -> void:
	# Preserve the autoload state so pointing it at the fixture cannot leak into
	# the other suites.
	_saved_path = Database.db.path
	_saved_is_open = Database.is_open
	Database.close()

	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	_seed_language_database()
	Database.db.path = TEST_DB
	Database.connect_to_db()
	# The boss gates are cached per lesson count; drop the cache so the fixture is
	# not judged against whatever pack ran before.
	StudentProgression.cached_boss_gate_lessons_total = -1
	StudentProgression.cached_boss_gate_lessons = []


func after_each() -> void:
	Database.close()
	_delete_test_directory()
	Database.db.path = _saved_path
	if _saved_is_open:
		Database.connect_to_db()


# A copy of the model database — empty of lessons, but with the exercise types
# already defined — filled with just enough lessons for the integrity check:
# LESSON_COUNT lessons of MINIGAMES_PER_LESSON minigames each.
func _seed_language_database() -> void:
	DirAccess.remove_absolute(TEST_DB)
	var copy_error: Error = DirAccess.copy_absolute(MODEL_DB, TEST_DB)
	assert_eq(copy_error, OK, "the model database must be copyable")

	var seed_db: SQLite = SQLite.new()
	seed_db.path = TEST_DB
	seed_db.open_db()
	for lesson_number: int in range(1, LESSON_COUNT + 1):
		seed_db.query("INSERT INTO Lessons (ID, LessonNb) VALUES (%d, %d)" % [lesson_number, lesson_number])
		seed_db.query("INSERT INTO LessonsExercises (LessonID, Exercise1, Exercise2, Exercise3) VALUES (%d, 1, 2, 3)" % lesson_number)
	seed_db.close_db()


func _delete_test_directory() -> void:
	var dir: DirAccess = DirAccess.open(TEST_DIR)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)
	DirAccess.remove_absolute(TEST_DIR)


# The integrity check warns about every repair it makes, which is exactly what we
# are asking it to do here. Acknowledge those warnings so GUT does not report them
# as unexpected errors. This must run inside the test: GUT checks for unhandled
# errors before after_each().
func _accept_integrity_warnings() -> void:
	for tracked_error: GutTrackedError in get_errors():
		tracked_error.handled = true


func _make_lesson(slot_count: int, status: StudentProgression.Status, look_and_learn: StudentProgression.Status) -> Dictionary:
	var games: Array = []
	for _index: int in range(slot_count):
		games.append(status)
	return {
		"look_and_learn": look_and_learn,
		"games": games,
		"last_duration": _make_durations(slot_count),
		"total_duration": _make_durations(slot_count),
	}


func _make_durations(slot_count: int) -> PackedInt32Array:
	var durations: PackedInt32Array = PackedInt32Array()
	durations.resize(slot_count)
	return durations


# The shape a real student hit: the pack used to give lesson 1 a single minigame
# and lesson 2 two, and now gives three to every lesson.
func _make_grown_pack_unlocks() -> Dictionary[int, Dictionary]:
	var unlocks: Dictionary[int, Dictionary] = {}
	unlocks[1] = _make_lesson(1, COMPLETED, COMPLETED)
	unlocks[2] = _make_lesson(2, COMPLETED, COMPLETED)
	for lesson_number: int in range(3, LESSON_COUNT + 1):
		unlocks[lesson_number] = _make_lesson(MINIGAMES_PER_LESSON, COMPLETED, COMPLETED)
	return unlocks


func test_the_fixture_reports_the_expected_lesson_count() -> void:
	assert_eq(Database.get_lessons_count(), LESSON_COUNT)
	assert_eq(StudentProgression.get_minigame_count_for_lesson(1), MINIGAMES_PER_LESSON)


func test_a_lesson_that_gained_minigames_does_not_reset_the_following_lessons() -> void:
	var progression: StudentProgression = StudentProgression.new()
	var result: Dictionary = progression.ensure_data_integrity(_make_grown_pack_unlocks())
	for lesson_number: int in range(3, LESSON_COUNT + 1):
		assert_eq(result[lesson_number]["look_and_learn"] as int, COMPLETED as int,
				"lesson %d look-and-learn must survive" % lesson_number)
		assert_eq_deep(result[lesson_number]["games"], [COMPLETED, COMPLETED, COMPLETED])
	_accept_integrity_warnings()


func test_a_grown_lesson_keeps_its_progress_and_offers_the_new_minigame() -> void:
	var progression: StudentProgression = StudentProgression.new()
	var result: Dictionary = progression.ensure_data_integrity(_make_grown_pack_unlocks())
	# Lesson 1 had one minigame, done. Slot 1 is the next to play, slot 2 waits.
	assert_eq(result[1]["look_and_learn"] as int, COMPLETED as int)
	assert_eq_deep(result[1]["games"], [COMPLETED, UNLOCKED, LOCKED])
	# Lesson 2 had two minigames, both done, and keeps them. Its new third slot
	# stays locked until lesson 1 is finished again — the sequential order is
	# preserved, the student is just no longer sent back to the start.
	assert_eq(result[2]["look_and_learn"] as int, COMPLETED as int)
	assert_eq_deep(result[2]["games"], [COMPLETED, COMPLETED, LOCKED])
	_accept_integrity_warnings()


func test_a_genuine_gap_still_resets_the_following_lessons() -> void:
	# Lesson 1 also grew, but nothing in it was ever completed, so lesson 2 is
	# unreachable and the repair must still fire.
	var unlocks: Dictionary[int, Dictionary] = _make_grown_pack_unlocks()
	unlocks[1] = _make_lesson(1, LOCKED, LOCKED)
	var progression: StudentProgression = StudentProgression.new()
	var result: Dictionary = progression.ensure_data_integrity(unlocks)
	assert_eq(result[2]["look_and_learn"] as int, LOCKED as int)
	assert_eq_deep(result[2]["games"], [LOCKED, LOCKED, LOCKED])
	_accept_integrity_warnings()


func test_a_lesson_that_lost_minigames_is_unaffected() -> void:
	# Shrinking cannot create a hole: the remaining slots keep their status.
	var unlocks: Dictionary[int, Dictionary] = _make_grown_pack_unlocks()
	unlocks[1] = _make_lesson(MINIGAMES_PER_LESSON + 2, COMPLETED, COMPLETED)
	var progression: StudentProgression = StudentProgression.new()
	var result: Dictionary = progression.ensure_data_integrity(unlocks)
	assert_eq_deep(result[1]["games"], [COMPLETED, COMPLETED, COMPLETED])
	assert_eq(result[LESSON_COUNT]["look_and_learn"] as int, COMPLETED as int)
	_accept_integrity_warnings()


# The check must be idempotent, because it runs again on the result it produced:
# _load_student_progression() calls init_unlocks() on every load, and the resized
# lesson no longer looks resized. A rule that only holds on the pass that performs
# the resize repairs nothing — the next load undoes it.
func test_the_integrity_check_is_idempotent_after_a_lesson_grew() -> void:
	var progression: StudentProgression = StudentProgression.new()
	var first_pass: Dictionary = progression.ensure_data_integrity(_make_grown_pack_unlocks())
	var second_pass: Dictionary = progression.ensure_data_integrity(_as_typed_unlocks(first_pass))
	var third_pass: Dictionary = progression.ensure_data_integrity(_as_typed_unlocks(second_pass))

	for lesson_number: int in range(3, LESSON_COUNT + 1):
		assert_eq(second_pass[lesson_number]["look_and_learn"] as int, COMPLETED as int,
				"lesson %d must survive a reload" % lesson_number)
		assert_eq_deep(second_pass[lesson_number]["games"], [COMPLETED, COMPLETED, COMPLETED])
	assert_eq_deep(second_pass, first_pass)
	assert_eq_deep(third_pass, second_pass)
	_accept_integrity_warnings()


func _as_typed_unlocks(unlocks: Dictionary) -> Dictionary[int, Dictionary]:
	var typed: Dictionary[int, Dictionary] = {}
	for lesson_number: int in unlocks.keys():
		typed[lesson_number] = unlocks[lesson_number]
	return typed
