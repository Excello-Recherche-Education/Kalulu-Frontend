extends Node2D
class_name Minigame

@export var minigame_name: = "Minigame"
@export var max_number_of_lives: = 5 :
	set(value): _set_max_lives(value)
	get: return _max_number_of_lives
@export var start_kalulu_speech: AudioStream
@export var win_kalulu_speech: AudioStream
@export var lose_kalulu_speech: AudioStream = preload("res://resources/minigames/kalulu/kalulu_lose_minigame_all.mp3")

@onready var minigame_ui: = $MinigameUI
@onready var opening_curtain: = $OpeningCurtain

# Game root shall contain all the game tree.
# This node is pausable unlike the others, so the pause button can stop the game but not other essential processes.
@onready var game_root: = $GameRoot

# Lesson
var lesson: String
var minigame_difficulty: int
var lesson_difficulty: int

# Logs
var logs: = {}

# Stimuli
var stimuli: = []
var distractions: = []

# Lives
var _max_number_of_lives : = 0
var current_lives: = 0 :
	set(value): _set_current_lives(value)
	get: return _current_lives
var _current_lives: = 0

# Progression
var max_progression: = 0 :
	set(value): _set_max_progression(value)
	get: return _max_progression
var _max_progression: = 0
var current_progression: = 0 :
	set(value): _set_current_progression(value)
	get: return _current_progression
var _current_progression: = 0


# ------------ Initialisation ------------


func _ready() -> void:
	_initialize()


func _initialize() -> void:
	_setup_minigame()
	
	_find_stimuli_and_distractions()
	
	_start()


# Find and set the parameters of the minigame, like the number of lives or the victory conditions.
func _setup_minigame() -> void:
	current_lives = max_number_of_lives



# Find the stimuli and distractions of the minigame.
func _find_stimuli_and_distractions() -> void:
	return


# Launch the minigame
func _start() -> void:
	opening_curtain.play("open")
	await opening_curtain.animation_finished


# ------------ End ------------


func _reset() -> void:
	_initialize()


func _win() -> void:
	minigame_ui.play_kalulu_speech(win_kalulu_speech)
	await minigame_ui.kalulu_speech_end
	
	


# ------------ Logs ------------


func _save_logs() -> void:
	LessonLogger.save_logs(logs, GameGlobals.teacher_id, GameGlobals.user_id, minigame_name, lesson, Time.get_time_string_from_system())
	_reset_logs()


func _reset_logs() -> void:
	logs = {}


# ------------ UI ------------

# Callbacks

func _go_back_to_the_garden() -> void:
	return


func _play_stimulus() -> void:
	return


func _pause_game() -> void:
	get_tree().paused = not get_tree().paused


func _play_kalulu() -> void:
	return

# Connections

func _on_minigame_ui_garden_button_pressed() -> void:
	_go_back_to_the_garden()


func _on_minigame_ui_stimulus_button_pressed() -> void:
	_play_stimulus()


func _on_minigame_ui_pause_button_pressed() -> void:
	_pause_game()


func _on_minigame_ui_kalulu_button_pressed() -> void:
	_play_kalulu()


# ------------ setters/getters ------------


func _set_max_lives(value: int) -> void:
	_max_number_of_lives = value
	if minigame_ui:
		minigame_ui.set_maximum_number_of_lives(value)


func _set_current_lives(value: int) -> void:
	_current_lives = value
	if minigame_ui:
		minigame_ui.set_number_of_lives(value)


func _set_max_progression(value: int) -> void:
	_max_progression = value
	if minigame_ui:
		minigame_ui.set_max_progression(value)


func _set_current_progression(value: int) -> void:
	_current_progression = value
	if minigame_ui:
		minigame_ui.set_current_progression(value)
