class_name StudentProgression
extends Resource

signal progression_changed()

enum Status{
	Locked,
	Unlocked,
	Completed,
}

@export var version: String = ProjectSettings.get_setting("application/config/version")
@export var unlocks: Dictionary[int, Dictionary] = {}:
	set(value):
		unlocks = ensure_data_integrity(value)
@export var last_modified: String


func _init() -> void:
	init_unlocks()


# Make sure the unlocks are correct
func init_unlocks() -> void:
	if not unlocks:
		unlocks = {} # Triggers ensure_data_integrity(), that will fill the default values
	
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
	if unlocks[1]["look_and_learn"] == Status.Locked:
		unlocks[1]["look_and_learn"] = Status.Unlocked


func ensure_data_integrity(data: Dictionary[int, Dictionary]) -> Dictionary:
	var is_init: bool = data.is_empty()
	var result: Dictionary[int, Dictionary] = data.duplicate(true)
	var number_of_lessons: int = Database.get_lessons_count()
	# Check too much keys
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
				Log.warn("Garden %d : Add missing key 'games'." % index)
			garden["games"] = [Status.Locked, Status.Locked, Status.Locked]
		if not garden.has("look_and_learn"):
			if not is_init:
				Log.warn("Garden %d : Add missing key 'look_and_learn'." % index)
			garden["look_and_learn"] = Status.Locked
		if not garden.has("last_duration"):
			garden["last_duration"] = PackedInt32Array([0, 0, 0])
		if not garden.has("total_duration"):
			garden["total_duration"] = PackedInt32Array([0, 0, 0])

		# Check array "games"
		if typeof(garden["games"]) != TYPE_ARRAY or (garden["games"] as Array).size() != 3:
			if not is_init:
				Log.warn("Garden %d : invalid format for 'games' → reset." % index)
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

		# Case : previous garden not completed
		if not prev_completed:
			for game_index: int in range(3):
				if garden["games"][game_index] != Status.Locked or garden["look_and_learn"] != Status.Locked:
					if not is_init:
						Log.warn("Garden %d : invalid progression (previous not finished) → reset." % index)
					garden["games"] = [Status.Locked, Status.Locked, Status.Locked]
					garden["look_and_learn"] = Status.Locked
					break
			continue

		# Case : lesson completed → games unlocked if needed
		if garden["look_and_learn"] == Status.Completed:
			for game_index: int in range(3):
				if garden["games"][game_index] == Status.Locked:
					garden["games"][game_index] = Status.Unlocked
					if not is_init:
						Log.warn("Garden %d : game %d unlocked because lesson is completed" % [index, game_index + 1])

		# Case : previous garden completed → lesson unlocked if needed
		elif garden["look_and_learn"] == Status.Locked:
			garden["look_and_learn"] = Status.Unlocked
			if not is_init:
				Log.warn("Garden %d : lesson unlocked because previous garden is completed" % index)

	return result


func get_max_unlocked_lesson_index() -> int:
	var max_unlocked_level: int = 1
	for index: int in range(unlocks.size()):
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
	
	if all_completed and unlocks.has(lesson_number + 1):
		unlocks[lesson_number + 1]["look_and_learn"] = Status.Unlocked
	
	last_modified = Time.get_datetime_string_from_system(true)
	progression_changed.emit()
	return true


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
