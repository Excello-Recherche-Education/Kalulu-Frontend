class_name StudentProgression
extends Resource

signal unlocks_changed()

enum Status{
	Locked,
	Unlocked,
	Completed,
}

@export var version: String = ProjectSettings.get_setting("application/config/version")
@export var unlocks: Dictionary = {}
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
