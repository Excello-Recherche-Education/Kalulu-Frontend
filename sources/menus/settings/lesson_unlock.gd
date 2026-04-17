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
	exercise_option_button_1.select(unlocks[lesson_number]["games"][0] as int)
	exercise_option_button_2.select(unlocks[lesson_number]["games"][1] as int)
	exercise_option_button_3.select(unlocks[lesson_number]["games"][2] as int)


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
			unlocks[lesson_number - 1]["games"][0] = StudentProgression.Status.LOCKED
			unlocks[lesson_number - 1]["games"][1] = StudentProgression.Status.LOCKED
			unlocks[lesson_number - 1]["games"][2] = StudentProgression.Status.LOCKED
		
		unlocks[lesson_number]["games"][0] = StudentProgression.Status.LOCKED
		unlocks[lesson_number]["games"][1] = StudentProgression.Status.LOCKED
		unlocks[lesson_number]["games"][2] = StudentProgression.Status.LOCKED
		
		for lesson: int in unlocks.keys():
			if lesson > lesson_number:
				unlocks[lesson]["look_and_learn"] = StudentProgression.Status.LOCKED
				unlocks[lesson]["games"][0] = StudentProgression.Status.LOCKED
				unlocks[lesson]["games"][1] = StudentProgression.Status.LOCKED
				unlocks[lesson]["games"][2] = StudentProgression.Status.LOCKED
	
	elif index == StudentProgression.Status.UNLOCKED:
		unlocks[lesson_number]["games"][0] = StudentProgression.Status.LOCKED
		unlocks[lesson_number]["games"][1] = StudentProgression.Status.LOCKED
		unlocks[lesson_number]["games"][2] = StudentProgression.Status.LOCKED
		for lesson: int in unlocks.keys():
			if lesson < lesson_number:
				unlocks[lesson]["look_and_learn"] = StudentProgression.Status.COMPLETED
				unlocks[lesson]["games"][0] = StudentProgression.Status.COMPLETED
				unlocks[lesson]["games"][1] = StudentProgression.Status.COMPLETED
				unlocks[lesson]["games"][2] = StudentProgression.Status.COMPLETED
			elif lesson > lesson_number:
				unlocks[lesson]["look_and_learn"] = StudentProgression.Status.LOCKED
				unlocks[lesson]["games"][0] = StudentProgression.Status.LOCKED
				unlocks[lesson]["games"][1] = StudentProgression.Status.LOCKED
				unlocks[lesson]["games"][2] = StudentProgression.Status.LOCKED
	elif index == StudentProgression.Status.COMPLETED:
		unlocks[lesson_number]["games"][0] = StudentProgression.Status.UNLOCKED
		unlocks[lesson_number]["games"][1] = StudentProgression.Status.UNLOCKED
		unlocks[lesson_number]["games"][2] = StudentProgression.Status.UNLOCKED
		for lesson: int in unlocks.keys():
			if lesson < lesson_number:
				unlocks[lesson]["look_and_learn"] = StudentProgression.Status.COMPLETED
				unlocks[lesson]["games"][0] = StudentProgression.Status.COMPLETED
				unlocks[lesson]["games"][1] = StudentProgression.Status.COMPLETED
				unlocks[lesson]["games"][2] = StudentProgression.Status.COMPLETED
			elif lesson > lesson_number:
				unlocks[lesson]["look_and_learn"] = StudentProgression.Status.LOCKED
				unlocks[lesson]["games"][0] = StudentProgression.Status.LOCKED
				unlocks[lesson]["games"][1] = StudentProgression.Status.LOCKED
				unlocks[lesson]["games"][2] = StudentProgression.Status.LOCKED
	unlocks_changed.emit()
