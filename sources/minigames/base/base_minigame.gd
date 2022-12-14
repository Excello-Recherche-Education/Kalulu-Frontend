extends Node2D
class_name Minigame

@export var minigame_name: = "Minigame"
@export var lives: = 5

var lesson: String
var minigame_difficulty: int
var lesson_difficulty: int

var logs: = {}

var stimuli: = {}
var distractions: = {}


func _ready() -> void:
	_find_stimuli_and_distractions()
	
	_start()


func _find_stimuli_and_distractions() -> void:
	return


func _start() -> void:
	return


func _save_logs() -> void:
	LessonLogger.save_logs(logs, GameGlobals.teacher_id, GameGlobals.user_id, minigame_name, lesson, Time.get_time_string_from_system())
	
	_reset_logs()


func _reset_logs() -> void:
	logs = {}


func _back_to_the_garden() -> void:
	return


func _play_stimulus() -> void:
	return


func _pause_game() -> void:
	return


func _play_kalulu() -> void:
	return


# ------------ UI ------------


func _on_minigame_ui_garden_button_pressed() -> void:
	_back_to_the_garden()


func _on_minigame_ui_stimulus_button_pressed() -> void:
	_play_stimulus()


func _on_minigame_ui_pause_button_pressed() -> void:
	_pause_game()


func _on_minigame_ui_kalulu_button_pressed() -> void:
	_play_kalulu()
