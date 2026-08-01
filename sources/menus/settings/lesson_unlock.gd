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

	# Each present minigame dropdown edits its own slot; surplus ones stay
	# disabled (see _set_lesson_number) so they never emit.
	var exercise_buttons: Array[OptionButton] = [exercise_option_button_1, exercise_option_button_2, exercise_option_button_3]
	for slot: int in range(exercise_buttons.size()):
		exercise_buttons[slot].item_selected.connect(_on_exercise_option_button_item_selected.bind(slot))

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

	# A student's progression can predate a pack that added lessons, and rows are
	# now refreshed for each student rather than rebuilt, so a missing lesson must
	# not take the panel down.
	if not unlocks.has(lesson_number):
		Log.trace("LessonUnlock: No progression entry for lesson %d" % lesson_number)
		return

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
	StudentProgression.apply_manual_progression(unlocks, lesson_number, StudentProgression.LOOK_AND_LEARN_SLOT, index as StudentProgression.Status)
	unlocks_changed.emit()


func _on_exercise_option_button_item_selected(index: int, slot: int) -> void:
	StudentProgression.apply_manual_progression(unlocks, lesson_number, slot, index as StudentProgression.Status)
	unlocks_changed.emit()
