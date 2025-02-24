extends Resource
class_name UserProgression

signal unlocks_changed()

enum Status{
	Locked,
	Unlocked,
	Completed,
}

@export var version: = 1.0
@export var unlocks: = {}


func _init() -> void:
	init_unlocks()

# Make sure the unlocks are correct
func init_unlocks() -> bool:
	var has_changes: bool = false
	
	if not unlocks:
		unlocks = {}
	
	# Verifiy the lessons
	var number_of_lessons: = Database.get_lessons_count()
	if unlocks.size() != number_of_lessons:
		for i in number_of_lessons:
			if not unlocks.has(i+1):
				unlocks[i + 1] = {
					"look_and_learn": Status.Locked,
					"games": [
						Status.Locked,
						Status.Locked,
						Status.Locked,
					]
				}
		
		while unlocks.size() > number_of_lessons:
			unlocks.erase(unlocks.size())
		
		has_changes = true
	
	# Make sure that the first garden is always accessible
	if unlocks[1]["look_and_learn"] == Status.Locked:
		unlocks[1]["look_and_learn"] = Status.Unlocked
		has_changes = true
	
	return has_changes


func get_max_unlocked_lesson() -> int:
	var max_unlocked_level: = 1
	for i in range(unlocks.size()):
		if unlocks[i + 1]["look_and_learn"] >= Status.Unlocked:
			max_unlocked_level = i
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
	
	for i in range(3):
		unlocks[lesson_number]["games"][i] = Status.Unlocked
	
	unlocks_changed.emit()
	return true

# Return true if the progression is saved or false if the game was already completed
func game_completed(lesson_number: int, game_number: int) -> bool:
	# If the game is already completed, do nothing
	if unlocks[lesson_number]["games"][game_number] == Status.Completed:
		return false
	
	
	unlocks[lesson_number]["games"][game_number] = Status.Completed
	
	var all_completed: = true
	for i in range(3):
		all_completed = all_completed and unlocks[lesson_number]["games"][i] == Status.Completed
	
	if all_completed and unlocks.has(lesson_number + 1):
		unlocks[lesson_number + 1]["look_and_learn"] = Status.Unlocked
	
	unlocks_changed.emit()
	return true
