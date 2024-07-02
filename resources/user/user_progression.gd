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
	var number_of_lessons: = Database.get_lessons_count()
	
	if unlocks.size() != number_of_lessons:
		for i in number_of_lessons:
			unlocks[i + 1] = {
				"look_and_learn": Status.Locked,
				"games": [
					Status.Locked,
					Status.Locked,
					Status.Locked,
				]
			}
		
		unlocks[1]["look_and_learn"] = Status.Unlocked


func get_max_unlocked_lesson() -> int:
	var max_unlocked_level: = 1
	for i in range(unlocks.size()):
		if unlocks[i + 1]["look_and_learn"] >= Status.Unlocked:
			max_unlocked_level = i
		else:
			break
	
	return max_unlocked_level


func look_and_learn_completed(lesson_number: int) -> void:
	unlocks[lesson_number]["look_and_learn"] = Status.Completed
	
	for i in range(3):
		unlocks[lesson_number]["games"][i] = Status.Unlocked
	
	unlocks_changed.emit()


func game_completed(lesson_number: int, game_number: int) -> void:
	unlocks[lesson_number]["games"][game_number] = Status.Completed
	
	var all_completed: = true
	for i in range(3):
		all_completed = all_completed and unlocks[lesson_number]["games"][i] == Status.Completed
	
	if all_completed and unlocks.has(lesson_number + 1):
		unlocks[lesson_number + 1]["look_and_learn"] = Status.Unlocked
		unlocks_changed.emit()
