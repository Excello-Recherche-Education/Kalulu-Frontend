extends GutTest
## Keeps minigame logs out of the way of the student's data files.
##
## LessonLogger names its files after the minigame. The student folder also holds
## what UserDataManager keeps there -- progression.tres, difficulty.tres,
## speeches.tres, boss.tres -- so "boss" landed on the boss session data. From the
## rename of that minigame onward, every boss log was silently dropped: the path
## already held a UserBossData, loading it as a LogResource failed, and the only
## sign was an assignment error three frames from the cause.
##
## Logs live in a subfolder now, so no minigame name can collide with a data file,
## whatever either is called later.

const LOGS_SUBFOLDER: String = "logs"

## The names UserDataManager keeps in the student folder. A minigame called any of
## these would have hit exactly the same bug.
const STUDENT_DATA_FILES: Array[String] = [
	"progression.tres", "difficulty.tres", "speeches.tres",
	"remediation.tres", "confusion_matrix.tres", "boss.tres",
]

var _folder: String = ""


func before_each() -> void:
	_folder = "user://test_lesson_logger"
	DirAccess.make_dir_recursive_absolute(_folder)
	LessonLogger.log_resources.clear()


func after_each() -> void:
	# Leaving these behind would make the next run read a stale cache from disk.
	var logs: String = _folder.path_join(LOGS_SUBFOLDER)
	for directory: String in [logs, _folder]:
		var dir: DirAccess = DirAccess.open(directory)
		if not dir:
			continue
		for file: String in dir.get_files():
			dir.remove(file)
		DirAccess.remove_absolute(directory)
	LessonLogger.log_resources.clear()


func test_logs_are_written_to_their_own_subfolder() -> void:
	LessonLogger.save_logs({"answers": [1, 2]}, _folder, "boss", 50, "10:00:00")
	var expected: String = _folder.path_join(LOGS_SUBFOLDER).path_join("boss.tres")
	assert_true(FileAccess.file_exists(expected), "logs should be written to %s" % expected)
	assert_false(FileAccess.file_exists(_folder.path_join("boss.tres")),
		"logs must not be written beside the student's data files")


func test_the_log_survives_a_round_trip() -> void:
	LessonLogger.save_logs({"answers": ["a"]}, _folder, "boss", 50, "10:00:00")
	LessonLogger.log_resources.clear()
	var loaded: LogResource = ResourceLoader.load(
		_folder.path_join(LOGS_SUBFOLDER).path_join("boss.tres"), "", ResourceLoader.CACHE_MODE_IGNORE) as LogResource
	assert_not_null(loaded, "the saved file should load as a LogResource")
	if not loaded:
		return
	assert_true(loaded.logs.has(50), "lesson 50 should be in the log")
	if loaded.logs.has(50):
		assert_true((loaded.logs[50] as Dictionary).has("10:00:00"), "the entry should be keyed by time")


func test_no_minigame_name_can_land_on_a_student_data_file() -> void:
	# The names are what they are today; the subfolder is what makes them safe.
	for data_file: String in STUDENT_DATA_FILES:
		var minigame_name: String = data_file.get_basename()
		LessonLogger.save_logs({"answers": []}, _folder, minigame_name, 1, "10:00:00")
		assert_true(FileAccess.file_exists(_folder.path_join(LOGS_SUBFOLDER).path_join(data_file)),
			"a minigame called '%s' should log to the subfolder" % minigame_name)
		assert_false(FileAccess.file_exists(_folder.path_join(data_file)),
			"a minigame called '%s' must not write over %s" % [minigame_name, data_file])


func test_something_else_at_the_path_is_reported_rather_than_assigned() -> void:
	# What the collision used to produce, so the next one says so plainly.
	var logs_folder: String = _folder.path_join(LOGS_SUBFOLDER)
	DirAccess.make_dir_recursive_absolute(logs_folder)
	var intruder: Resource = Resource.new()
	assert_eq(ResourceSaver.save(intruder, logs_folder.path_join("boss.tres")), OK, "wrote the intruder")

	LessonLogger.save_logs({"answers": [1]}, _folder, "boss", 50, "10:00:00")
	assert_false(LessonLogger.log_resources.has(logs_folder.path_join("boss.tres")),
		"a resource that is not a LogResource should not be cached as one")
	_mark_errors_handled()


# The Log.error is the behaviour under test, not a surprise. Must run inside the
# test: GUT checks for unhandled errors before after_each().
func _mark_errors_handled() -> void:
	for tracked_error: GutTrackedError in get_errors():
		tracked_error.handled = true
