extends MarginContainer

@export var lesson_number: int:
	set = _set_lesson_number

@onready var lesson_label: Label = %LessonLabel
@onready var look_and_learn_option_button: OptionButton = %LookAndLearnOptionButton
@onready var exercise_option_button_1: OptionButton = %ExerciseOptionButton1
@onready var exercise_option_button_2: OptionButton = %ExerciseOptionButton2
@onready var exercise_option_button_3: OptionButton = %ExerciseOptionButton3


func _ready() -> void:
	for status in UserProgression.Status:
		look_and_learn_option_button.add_item(status)
		exercise_option_button_1.add_item(status)
		exercise_option_button_2.add_item(status)
		exercise_option_button_3.add_item(status)
	
	_set_lesson_number(lesson_number)


func reload() -> void:
	_set_lesson_number(lesson_number)


func _set_lesson_number(value: int) -> void:
	lesson_number = value
	
	if not lesson_label:
		return
	
	lesson_label.text = str(lesson_number)
	
	var lesson_unlocks: Dictionary = UserDataManager.student_progression.unlocks[lesson_number]
	look_and_learn_option_button.select(lesson_unlocks["look_and_learn"])
	exercise_option_button_1.select(lesson_unlocks["games"][0])
	exercise_option_button_2.select(lesson_unlocks["games"][1])
	exercise_option_button_3.select(lesson_unlocks["games"][2])


func _on_look_and_learn_option_button_item_selected(index: int) -> void:
	UserDataManager.student_progression.unlocks[lesson_number]["look_and_learn"] = index
	UserDataManager._save_student_progression()


func _on_exercise_option_button_1_item_selected(index: int) -> void:
	UserDataManager.student_progression.unlocks[lesson_number]["games"][0] = index
	UserDataManager._save_student_progression()


func _on_exercise_option_button_2_item_selected(index: int) -> void:
	UserDataManager.student_progression.unlocks[lesson_number]["games"][1] = index
	UserDataManager._save_student_progression()


func _on_exercise_option_button_3_item_selected(index: int) -> void:
	UserDataManager.student_progression.unlocks[lesson_number]["games"][2] = index
	UserDataManager._save_student_progression()
