class_name StudentProgression
extends Resource

signal progression_changed()

enum Status{
	Locked,
	Unlocked,
	Completed,
}

static var cached_boss_gate_lessons: Array[int] = []
static var cached_boss_gate_lessons_total: int = -1

@export var version: String = Utils.get_application_config_version()
@export var unlocks: Dictionary[int, Dictionary] = {}:
	set(value):
		unlocks = ensure_data_integrity(value)
@export var highest_boss_defeated: int = 0:
	set(value):
		highest_boss_defeated = _sanitize_highest_boss(value)
@export var boss_failure_streak: int = 0
@export var boss_blocked: bool = false
@export var last_modified: String


func _init() -> void:
	init_unlocks()


# Make sure the unlocks are correct
func init_unlocks() -> void:
	if not unlocks:
		unlocks = {} # Triggers ensure_data_integrity(), that will fill the default values
	else:
		unlocks = unlocks # Force ensure_data_integrity()
	_sanitize_boss_progression()
	
	# Verify the lessons
	var number_of_lessons: int = Database.get_lessons_count()
	if unlocks.size() != number_of_lessons:
		for index: int in range(number_of_lessons):
			if not unlocks.has(index+1):
				unlocks[index + 1] = {
					"look_and_learn": Status.Locked,
					"games": [
						Status.Locked,
						Status.Locked,
						Status.Locked,
					],
					"last_duration": PackedInt32Array([0, 0, 0]),
					"total_duration": PackedInt32Array([0, 0, 0])
				}
		
	# Make sure that the first garden is always accessible
	if unlocks.has(1):
		if unlocks[1]["look_and_learn"] == Status.Locked:
			unlocks[1]["look_and_learn"] = Status.Unlocked
	_sanitize_boss_progression()


func ensure_data_integrity(data: Dictionary[int, Dictionary]) -> Dictionary:
	var is_init: bool = data.is_empty()
	var result: Dictionary[int, Dictionary] = data.duplicate(true)
	var number_of_lessons: int = Database.get_lessons_count()
	# Check for extra keys
	for key: int in result.keys():
		if key > number_of_lessons:
			result.erase(key)
	# Check missing keys
	var min_key: int = 1
	var max_key: int = number_of_lessons
	for index: int in range(min_key, max_key + 1):
		if not result.has(index):
			if not is_init:
				Log.warn("StudentProgression: Garden %d missing → added with default values." % index)
			result[index] = {
				"games": [Status.Locked, Status.Locked, Status.Locked],
				"look_and_learn": Status.Locked,
				"last_duration": PackedInt32Array([0, 0, 0]),
				"total_duration": PackedInt32Array([0, 0, 0])
			}
	# Check internal structure
	for index: int in result.keys():
		var garden: Dictionary = result[index]
		# Check missing keys
		if not garden.has("games"):
			if not is_init:
				Log.warn("StudentProgression: Garden %d: Add missing key 'games'." % index)
			garden["games"] = [Status.Locked, Status.Locked, Status.Locked]
		if not garden.has("look_and_learn"):
			if not is_init:
				Log.warn("StudentProgression: Garden %d: Add missing key 'look_and_learn'." % index)
			garden["look_and_learn"] = Status.Locked
		if not garden.has("last_duration"):
			garden["last_duration"] = PackedInt32Array([0, 0, 0])
		if not garden.has("total_duration"):
			garden["total_duration"] = PackedInt32Array([0, 0, 0])

		# Check array "games"
		if typeof(garden["games"]) != TYPE_ARRAY or (garden["games"] as Array).size() != 3:
			if not is_init:
				Log.warn("StudentProgression: Garden %d: invalid format for 'games' → reset." % index)
			garden["games"] = [Status.Locked, Status.Locked, Status.Locked]

		# Check value outside of possible enum values
		for game_index: int in range(3):
			if garden["games"][game_index] not in [Status.Locked, Status.Unlocked, Status.Completed]:
				garden["games"][game_index] = Status.Locked
		if garden["look_and_learn"] not in [Status.Locked, Status.Unlocked, Status.Completed]:
			garden["look_and_learn"] = Status.Locked

	# Check progression rules
	for index: int in range(min_key, max_key + 1):
		var garden: Dictionary = result[index]
		var prev_completed: bool = false

		# Check previous garden is completed
		if result.has(index - 1):
			var prev: Dictionary = result[index - 1]
			prev_completed = (
				prev["look_and_learn"] == Status.Completed and
				(prev["games"] as Array).all(func(x: int) -> bool: return x == Status.Completed)
			)
		else:
			# First garden (key 1) is always unlocked
			prev_completed = true

		# Case: previous garden not completed
		if not prev_completed:
			for game_index: int in range(3):
				if garden["games"][game_index] != Status.Locked or garden["look_and_learn"] != Status.Locked:
					if not is_init:
						Log.warn("StudentProgression: Garden %d: invalid progression (previous not finished) → reset." % index)
					garden["games"] = [Status.Locked, Status.Locked, Status.Locked]
					garden["look_and_learn"] = Status.Locked
					break
			continue

		# Case: lesson completed → unlock games if needed
		if garden["look_and_learn"] == Status.Completed:
			for game_index: int in range(3):
				if garden["games"][game_index] == Status.Locked:
					garden["games"][game_index] = Status.Unlocked
					if not is_init:
						Log.warn("StudentProgression: Garden %d: game %d unlocked because lesson is completed" % [index, game_index + 1])

		# Case: previous garden completed → unlock lesson if needed
		elif garden["look_and_learn"] == Status.Locked:
			garden["look_and_learn"] = Status.Unlocked
			if not is_init:
				Log.warn("StudentProgression: Garden %d: lesson unlocked because previous garden is completed" % index)

	_sanitize_boss_progression()
	return result


static func get_boss_gate_lessons() -> Array[int]:
	var total_lessons: int = Database.get_lessons_count()
	if cached_boss_gate_lessons_total == total_lessons:
		return cached_boss_gate_lessons.duplicate()
	var gates: Array[int] = []
	if total_lessons <= 0:
		return gates
	var boundary_lessons: Array[int] = _get_garden_boundary_lessons(total_lessons)
	var last_boss_pseudowords: int = 0
	for lesson_number: int in range(1, total_lessons + 1):
		var total_pseudowords: int = Database.get_pseudowords_for_lesson(lesson_number).size()
		var new_pseudowords: int = total_pseudowords - last_boss_pseudowords
		if new_pseudowords >= 30 and boundary_lessons.has(lesson_number):
			gates.append(lesson_number)
			last_boss_pseudowords = total_pseudowords
	cached_boss_gate_lessons_total = total_lessons
	cached_boss_gate_lessons = gates.duplicate()
	return gates


static func _get_garden_boundary_lessons(total_lessons: int) -> Array[int]:
	var boundaries: Array[int] = []
	var layout: GardensLayout = Gardens.get_session_layout(total_lessons)
	var distribution: Array[int] = Gardens.get_lessons_distribution(total_lessons, layout.gardens)
	var lesson_index: int = 0
	for count: int in distribution:
		if count <= 0:
			continue
		lesson_index += count
		if lesson_index < total_lessons:
			boundaries.append(lesson_index)
	return boundaries


func _sanitize_boss_progression() -> void:
	highest_boss_defeated = _sanitize_highest_boss(highest_boss_defeated)


func _sanitize_highest_boss(value: int) -> int:
	var gate_lessons: Array[int] = get_boss_gate_lessons()
	if gate_lessons.is_empty():
		return 0
	gate_lessons.sort()
	var sanitized: int = 0
	for gate_lesson: int in gate_lessons:
		if gate_lesson <= value:
			sanitized = gate_lesson
		else:
			break
	return sanitized


func is_boss_completed(gate_lesson: int) -> bool:
	if not get_boss_gate_lessons().has(gate_lesson):
		return false
	return gate_lesson <= highest_boss_defeated


func is_lesson_blocked_by_boss(lesson_number: int) -> bool:
	var gate_lessons: Array[int] = get_boss_gate_lessons()
	gate_lessons.sort()
	for gate: int in gate_lessons:
		if gate >= lesson_number:
			break
		if gate > highest_boss_defeated:
			return true
	return false


func get_max_unlocked_lesson_index() -> int:
	var max_unlocked_level: int = 1
	for index: int in range(unlocks.size()):
		if is_lesson_blocked_by_boss(index + 1):
			break
		if unlocks[index + 1]["look_and_learn"] >= Status.Unlocked:
			max_unlocked_level = index
		else:
			break
	
	return max_unlocked_level


func is_lesson_completed(lesson_number: int) -> bool:
	return unlocks[lesson_number]["look_and_learn"] == Status.Completed and unlocks[lesson_number]["games"][0] == Status.Completed and unlocks[lesson_number]["games"][1] == Status.Completed and unlocks[lesson_number]["games"][2] == Status.Completed


# Return true if the progression is saved or false if the look and learn was already completed
func look_and_learn_completed(lesson_number: int) -> bool:
	if unlocks[lesson_number]["look_and_learn"] == Status.Completed:
		return false
	
	unlocks[lesson_number]["look_and_learn"] = Status.Completed
	
	for index: int in range(3):
		unlocks[lesson_number]["games"][index] = Status.Unlocked
	
	last_modified = Time.get_datetime_string_from_system(true)
	progression_changed.emit()
	return true


# Return true if the progression is saved or false if the game was already completed
func game_completed(lesson_number: int, game_number: int) -> bool:
	# If the game is already completed, do nothing
	if unlocks[lesson_number]["games"][game_number] == Status.Completed:
		return false
	
	unlocks[lesson_number]["games"][game_number] = Status.Completed
	
	var all_completed: bool = true
	for index: int in range(3):
		all_completed = all_completed and unlocks[lesson_number]["games"][index] == Status.Completed
	
	if all_completed:
		if unlocks.has(lesson_number + 1):
			unlocks[lesson_number + 1]["look_and_learn"] = Status.Unlocked
	
	last_modified = Time.get_datetime_string_from_system(true)
	progression_changed.emit()
	return true


func boss_completed(lesson_number: int) -> bool:
	if not get_boss_gate_lessons().has(lesson_number):
		return false
	if lesson_number <= highest_boss_defeated:
		return false
	highest_boss_defeated = lesson_number
	if boss_failure_streak != 0:
		boss_failure_streak = 0
	last_modified = Time.get_datetime_string_from_system(true)
	progression_changed.emit()
	return true


func register_boss_failure() -> bool:
	if boss_blocked:
		return true
	boss_failure_streak = max(0, boss_failure_streak) + 1
	if boss_failure_streak >= 2:
		boss_blocked = true
	last_modified = Time.get_datetime_string_from_system(true)
	progression_changed.emit()
	return boss_blocked


func reset_boss_failure_streak() -> void:
	if boss_failure_streak == 0:
		return
	boss_failure_streak = 0
	last_modified = Time.get_datetime_string_from_system(true)
	progression_changed.emit()


func clear_boss_block() -> void:
	if not boss_blocked and boss_failure_streak == 0:
		return
	boss_blocked = false
	boss_failure_streak = 0
	last_modified = Time.get_datetime_string_from_system(true)
	progression_changed.emit()


func add_level_time(lesson_number: int, game_number: int, time_spent: int) -> void:
	Log.trace("StudentProgression: Add time to level %d, minigame %d. Time added: %s" % [lesson_number, game_number, time_spent])
	if game_number > 2:
		Log.error("StudentProgression: Cannot log a level time for a minigame number superior to 2")
		return
	
	if not unlocks.has(lesson_number):
		Log.error("StudentProgression: Cannot log a level time for lesson %d because it does not exists in progression data" % lesson_number)
		return
	
	if not (unlocks[lesson_number] as Dictionary).has("last_duration") or not (unlocks[lesson_number]["last_duration"] as PackedInt32Array).size() > game_number:
		Log.error("StudentProgression: Cannot log a last_duration for lesson %d, game %d, because it does not exists" % [lesson_number, game_number])
	else:
		unlocks[lesson_number]["last_duration"][game_number] = time_spent
	
	if not (unlocks[lesson_number] as Dictionary).has("total_duration") or not (unlocks[lesson_number]["total_duration"] as PackedInt32Array).size() > game_number:
		Log.error("StudentProgression: Cannot log a total_duration for lesson %d, game %d, because it does not exists" % [lesson_number, game_number])
	else:
		unlocks[lesson_number]["total_duration"][game_number] += time_spent
	
	last_modified = Time.get_datetime_string_from_system(true)
	progression_changed.emit()
