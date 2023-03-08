@tool
extends Control
class_name Minigame

@export var minigame_name: = "Minigame"

@export var max_number_of_lives: = 0 :
	set(value):
		max_number_of_lives = value
		if minigame_ui:
			minigame_ui.set_maximum_number_of_lives(value)

@export var max_progression: = 0 :
	set(value):
		max_progression = value
		if minigame_ui:
			minigame_ui.set_max_progression(value)

@export var help_kalulu_speech: AudioStream
@export var win_kalulu_speech: AudioStream
@export var lose_kalulu_speech: AudioStream = preload("res://assets/minigames/kalulu/kalulu_lose_minigame_all.mp3")

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
var current_lives: = 0 :
	set(value):
		var previous_lives: = current_lives
		current_lives = value
		if minigame_ui:
			minigame_ui.set_number_of_lives(value)
		if value == 0 and previous_lives != 0:
			_lose()

# Progression
var current_progression: = 0 :
	set(value):
		var previous_progression: = current_progression
		current_progression = value
		if minigame_ui:
			minigame_ui.set_current_progression(value)
		if value == max_progression and previous_progression != max_progression:
			_win()


# ------------ Initialisation ------------


func _ready() -> void:
	minigame_ui.set_master_volume_slider(UserDataManager.get_master_volume())
	minigame_ui.set_music_volume_slider(UserDataManager.get_music_volume())
	minigame_ui.set_voice_volume_slider(UserDataManager.get_voice_volume())
	minigame_ui.set_effects_volume_slider(UserDataManager.get_effects_volume())
	
	_initialize()


func _initialize() -> void:
	_find_stimuli_and_distractions()
	
	_setup_minigame()
	
	if not Engine.is_editor_hint():
		await _curtains_and_kalulu()
		_start()


# Find and set the parameters of the minigame, like the number of lives or the victory conditions.
func _setup_minigame() -> void:
	max_progression = max_progression
	max_number_of_lives = max_number_of_lives
	current_lives = max_number_of_lives



# Find the stimuli and distractions of the minigame.
func _find_stimuli_and_distractions() -> void:
	return


# Open the curtains and Kalulu explains
func _curtains_and_kalulu() -> void:
	opening_curtain.play("open")
	await opening_curtain.animation_finished
	
	minigame_ui.play_kalulu_speech(help_kalulu_speech)
	await minigame_ui.kalulu_speech_ended


# Launch the minigame
func _start() -> void:
	return


# ------------ End ------------


func _reset() -> void:
	opening_curtain.play("close")
	await opening_curtain.animation_finished
	
	get_tree().paused = false
	get_tree().reload_current_scene()


func _win() -> void:
	minigame_ui.play_kalulu_speech(win_kalulu_speech)
	await minigame_ui.kalulu_speech_ended
	
	_reset()


func _lose() -> void:
	minigame_ui.play_kalulu_speech(lose_kalulu_speech)
	await minigame_ui.kalulu_speech_ended
	
	_reset()


# ------------ Logs ------------


func _save_logs() -> void:
	LessonLogger.save_logs(logs, UserDataManager.get_student_folder(), minigame_name, lesson, Time.get_time_string_from_system())
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
	var pause: = not get_tree().paused
	get_tree().paused = pause
	minigame_ui.show_center_menu(pause)


func _play_kalulu() -> void:
	get_tree().paused = true
	minigame_ui.play_kalulu_speech(help_kalulu_speech)
	await minigame_ui.kalulu_speech_ended
	get_tree().paused = false


# Connections


func _on_minigame_ui_garden_button_pressed() -> void:
	_go_back_to_the_garden()


func _on_minigame_ui_stimulus_button_pressed() -> void:
	_play_stimulus()


func _on_minigame_ui_pause_button_pressed() -> void:
	_pause_game()


func _on_minigame_ui_kalulu_button_pressed() -> void:
	_play_kalulu()


func _on_minigame_ui_restart_button_pressed() -> void:
	_reset()


func _on_minigame_ui_master_volume_changed(volume) -> void:
	UserDataManager.set_master_volume(volume)


func _on_minigame_ui_music_volume_changed(volume) -> void:
	UserDataManager.set_music_volume(volume)


func _on_minigame_ui_voice_volume_changed(volume) -> void:
	UserDataManager.set_voice_volume(volume)


func _on_minigame_ui_effects_volume_changed(volume) -> void:
	UserDataManager.set_effects_volume(volume)
