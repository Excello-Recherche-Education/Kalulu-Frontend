class_name StudentProgression
extends Resource

signal unlocks_changed()

enum Status{
	Locked,
	Unlocked,
	Completed,
}

@export var version: String = ProjectSettings.get_setting("application/config/version")
@export var unlocks: Dictionary = {}:
	set(value):
		unlocks = check_data_integrity(value)
@export var level_times: Dictionary[int, PackedInt32Array] = {}  # Level ID, Last number of seconds for minigames 0, 1 and 2
@export var level_total_times: Dictionary[int, PackedInt32Array] = {}  # Level ID, Total number of seconds for minigames 0, 1 and 2
@export var last_modified: String


func _init() -> void:
	init_unlocks()


# Make sure the unlocks are correct
func init_unlocks() -> void:
	if not unlocks:
		unlocks = {}
	
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
					]
				}
		
		while unlocks.size() > number_of_lessons:
			unlocks.erase(unlocks.size())
		
	# Make sure that the first garden is always accessible
	if unlocks[1]["look_and_learn"] == Status.Locked:
		unlocks[1]["look_and_learn"] = Status.Unlocked


func check_data_integrity(data: Dictionary) -> Dictionary:
	var result: Dictionary = data.duplicate(true)

	# Check missin keys
	var min_key: int = 1
	var max_key: int = 1
	if result.size() > 0:
		if result.keys()[0] is int:
			min_key = result.keys().min() as int
			max_key = result.keys().max() as int
		else:
			Log.error("StudentProgression: Received keys with wrong datatype")

	for index: int in range(min_key, max_key + 1):
		if not result.has(index):
			Log.warn("StudentProgression: Garden %d missing → added with default values." % index)
			result[index] = {
				"games": [0, 0, 0],
				"look_and_learn": 0,
				"last_duration": 0.0,
				"total_duration": 0.0
			}

	# Check internal structure
	for index: int in result.keys():
		var garden: Dictionary = result[index]

		# Check missing keys
		if not garden.has("games"):
			Log.warn("Garden %d : Add missing key 'games'." % index)
			garden["games"] = [0, 0, 0]
		if not garden.has("look_and_learn"):
			Log.warn("Garden %d : Add missing key 'look_and_learn'." % index)
			garden["look_and_learn"] = 0
		if not garden.has("last_duration"):
			garden["last_duration"] = 0.0
		if not garden.has("total_duration"):
			garden["total_duration"] = 0.0

		# Check array "games"
		if typeof(garden["games"]) != TYPE_ARRAY or (garden["games"] as Array).size() != 3:
			Log.warn("Garden %d : invalid format for 'games' → reset." % index)
			garden["games"] = [0, 0, 0]

		# Check value outside of 0/1/2
		for game_index: int in range(3):
			if garden["games"][game_index] not in [0, 1, 2]:
				garden["games"][game_index] = 0
		if garden["look_and_learn"] not in [0, 1, 2]:
			garden["look_and_learn"] = 0

	# Check progression rules
	for index: int in range(min_key, max_key + 1):
		var garden: Dictionary = result[index]
		var prev_completed: bool = false

		# Check previous garden is completed
		if result.has(index - 1):
			var prev: Dictionary = result[index - 1]
			prev_completed = (
				prev["look_and_learn"] == 2 and
				(prev["games"] as Array).all(func(x: int) -> bool: return x == 2)
			)
		else:
			# First garden (key 1) is always unlocked
			prev_completed = true

		# Case : previous garden not completed
		if not prev_completed:
			for game_index: int in range(3):
				if garden["games"][game_index] != 0 or garden["look_and_learn"] != 0:
					Log.warn("Garden %d : invalid progression (previous not finished) → reset." % index)
					garden["games"] = [0, 0, 0]
					garden["look_and_learn"] = 0
					break
			continue

		# Case : lesson completed → games unlocked if needed
		if garden["look_and_learn"] == 2:
			for game_index: int in range(3):
				if garden["games"][game_index] == 0:
					garden["games"][game_index] = 1
					Log.warn("Garden %d : game %d unlocked because lesson is completed" % [index, game_index + 1])

		# Case : previous garden completed → lesson unlocked if needed
		elif garden["look_and_learn"] == 0:
			garden["look_and_learn"] = 1
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
	unlocks_changed.emit()
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
	unlocks_changed.emit()
	return true


func add_level_time(lesson_number: int, game_number: int, time_spent: int) -> void:
	Log.trace("StudentProgression: Add time to level %d, minigame %d. Time added: %s" % [lesson_number, game_number, time_spent])
	if game_number > 2:
		Log.error("StudentProgression: Cannot log a level time for a minigame number superior to 2")
		return
	
	if level_times.has(lesson_number):
		if level_times[lesson_number].size() != 3:
			level_times[lesson_number] = [0, 0, 0]
	else:
		level_times.set(lesson_number, PackedInt32Array([0, 0, 0]))
	level_times[lesson_number][game_number] = time_spent
	
	if level_total_times.has(lesson_number):
		if level_total_times[lesson_number].size() != 3:
			level_total_times[lesson_number] = PackedInt32Array([0, 0, 0])
	else:
		level_total_times.set(lesson_number, PackedInt32Array([0, 0, 0]))
	level_total_times[lesson_number][game_number] += time_spent
	last_modified = Time.get_datetime_string_from_system(true)
