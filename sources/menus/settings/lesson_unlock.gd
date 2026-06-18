class_name LessonUnlock
extends Node

signal unlocks_changed()

@export var lesson_number: int:
	set = _set_lesson_number
@export var lesson_gps: String:
	set = _set_lesson_gps
@export var unlocks: Dictionary = {}

@onready var lesson_label: Label = %LessonLabel
@onready var gps_label: Label = %GPsLabel
@onready var look_and_learn_option_button: OptionButton = %LookAndLearnOptionButton
@onready var exercise_option_button_1: OptionButton = %ExerciseOptionButton1
@onready var exercise_option_button_2: OptionButton = %ExerciseOptionButton2
@onready var exercise_option_button_3: OptionButton = %ExerciseOptionButton3


func _ready() -> void:
	for status: String in StudentProgression.Status:
		look_and_learn_option_button.add_item(tr(status))
		exercise_option_button_1.add_item(tr(status))
		exercise_option_button_2.add_item(tr(status))
		exercise_option_button_3.add_item(tr(status))

	reload()


func get_grid_cells() -> Array[Control]:
	return [
		lesson_label,
		gps_label,
		look_and_learn_option_button,
		exercise_option_button_1,
		exercise_option_button_2,
		exercise_option_button_3,
	]


func reload() -> void:
	_set_lesson_number(lesson_number)
	_set_lesson_gps(lesson_gps)


func _set_lesson_number(value: int) -> void:
	lesson_number = value

	if not lesson_label:
		return

	lesson_label.text = str(lesson_number)

	look_and_learn_option_button.select(unlocks[lesson_number]["look_and_learn"] as int)
	# A lesson can have 1–3 minigames, so only populate the buttons that map to a
	# real game and disable the surplus ones (the grid keeps all three cells).
	var games: Array = unlocks[lesson_number]["games"]
	var exercise_buttons: Array[OptionButton] = [exercise_option_button_1, exercise_option_button_2, exercise_option_button_3]
	for index: int in range(exercise_buttons.size()):
		var button: OptionButton = exercise_buttons[index]
		if index < games.size():
			button.disabled = false
			button.select(games[index] as int)
		else:
			button.disabled = true
			button.select(-1)


func _set_lesson_gps(value: String) -> void:
	lesson_gps = value
	if not gps_label:
		return

	gps_label.text = value


func _on_look_and_learn_option_button_item_selected(index: int) -> void:
	unlocks[lesson_number]["look_and_learn"] = index

	if index == StudentProgression.Status.LOCKED:
		if lesson_number == 1:
			unlocks[lesson_number]["look_and_learn"] = StudentProgression.Status.UNLOCKED
		else:
			unlocks[lesson_number - 1]["look_and_learn"] = StudentProgression.Status.UNLOCKED
			_set_lesson_games(lesson_number - 1, StudentProgression.Status.LOCKED)

		_set_lesson_games(lesson_number, StudentProgression.Status.LOCKED)

		for lesson: int in unlocks.keys():
			if lesson > lesson_number:
				unlocks[lesson]["look_and_learn"] = StudentProgression.Status.LOCKED
				_set_lesson_games(lesson, StudentProgression.Status.LOCKED)

	elif index == StudentProgression.Status.UNLOCKED:
		_set_lesson_games(lesson_number, StudentProgression.Status.LOCKED)
		for lesson: int in unlocks.keys():
			if lesson < lesson_number:
				unlocks[lesson]["look_and_learn"] = StudentProgression.Status.COMPLETED
				_set_lesson_games(lesson, StudentProgression.Status.COMPLETED)
			elif lesson > lesson_number:
				unlocks[lesson]["look_and_learn"] = StudentProgression.Status.LOCKED
				_set_lesson_games(lesson, StudentProgression.Status.LOCKED)
	elif index == StudentProgression.Status.COMPLETED:
		_set_lesson_games(lesson_number, StudentProgression.Status.UNLOCKED)
		for lesson: int in unlocks.keys():
			if lesson < lesson_number:
				unlocks[lesson]["look_and_learn"] = StudentProgression.Status.COMPLETED
				_set_lesson_games(lesson, StudentProgression.Status.COMPLETED)
			elif lesson > lesson_number:
				unlocks[lesson]["look_and_learn"] = StudentProgression.Status.LOCKED
				_set_lesson_games(lesson, StudentProgression.Status.LOCKED)
	unlocks_changed.emit()


# Sets every minigame of a lesson to the same status, respecting the lesson's
# actual minigame count (1–3) rather than assuming a fixed three.
func _set_lesson_games(lesson: int, status: StudentProgression.Status) -> void:
	var games: Array = unlocks[lesson]["games"]
	for game_index: int in range(games.size()):
		games[game_index] = status
