@tool
extends Control
class_name Minigame

@export var minigame_name: = "Minigame"

@export var lesson_nb: = 10
@export var minigame_number: = 1

@export_group("Difficulty")
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

@export_group("Speechs")
@export var intro_kalulu_speech: AudioStream
@export var help_kalulu_speech: AudioStream
@export var win_kalulu_speech: AudioStream
@export var lose_kalulu_speech: AudioStream = preload("res://language_resources/fr/minigames/kalulu/kalulu_lose_minigame_all.mp3")

@onready var minigame_ui: = $MinigameUI
@onready var audio_player: = $AudioStreamPlayer
@onready var fireworks: = $Fireworks

# Game root shall contain all the game tree.
# This node is pausable unlike the others, so the pause button can stop the game but not other essential processes.
@onready var game_root: = $GameRoot

# Minigame selection garden sub menu
const MinigameSelection: = preload("res://sources/lesson_screen/minigame_selection.gd")
const minigame_selection_scene: = preload("res://sources/lesson_screen/minigame_selection.tscn")

# Sounds
const win_sound_fx: = preload("res://assets/sfx/sfx_game_over_win.mp3")
const lose_sound_fx: = preload("res://assets/sfx/sfx_game_over_lose.mp3")

# Lesson
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
		if current_lives < previous_lives:
			consecutive_errors += previous_lives - current_lives
		
		if previous_lives == max_number_of_lives and current_lives < previous_lives:
			_first_error_hint()
		elif consecutive_errors == 2:
			_two_errors_hint()
		
		if minigame_ui:
			minigame_ui.set_number_of_lives(value)
		if value == 0 and previous_lives != 0:
			_lose()

# Progression
var current_progression: = 0 : set = set_current_progression
var current_number_of_hints: = 0
var consecutive_errors: = 0


# ------------ Initialisation ------------


func _ready() -> void:
	if not Engine.is_editor_hint():
		minigame_ui.set_master_volume_slider(UserDataManager.get_master_volume())
		minigame_ui.set_music_volume_slider(UserDataManager.get_music_volume())
		minigame_ui.set_voice_volume_slider(UserDataManager.get_voice_volume())
		minigame_ui.set_effects_volume_slider(UserDataManager.get_effects_volume())
		
		# Stop the current music
		MusicManager.stop()
	
	_reset_logs()
	_initialize()


func _initialize() -> void:
	if not Engine.is_editor_hint():
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
	await OpeningCurtain.open()
	
	minigame_ui.play_kalulu_speech(intro_kalulu_speech)
	await minigame_ui.kalulu_speech_ended


# Launch the minigame
func _start() -> void:
	return


# ------------ End ------------


func _reset() -> void:
	await OpeningCurtain.close()
	
	get_tree().paused = false
	get_tree().reload_current_scene()


func _win() -> void:
	UserDataManager.student_progression.game_completed(lesson_nb, minigame_number)
	
	audio_player.stream = win_sound_fx
	audio_player.play()
	
	fireworks.start()
	await fireworks.finished
	
	minigame_ui.play_kalulu_speech(win_kalulu_speech)
	await minigame_ui.kalulu_speech_ended
	
	_go_back_to_the_garden()


func _lose() -> void:
	audio_player.stream = lose_sound_fx
	audio_player.play()
	await audio_player.finished
	
	minigame_ui.play_kalulu_speech(lose_kalulu_speech)
	await minigame_ui.kalulu_speech_ended
	
	_reset()


# ------------ Logs ------------


func _save_logs() -> void:
	LessonLogger.save_logs(logs, UserDataManager.get_student_folder(), minigame_name, lesson_nb, Time.get_time_string_from_system())
	_reset_logs()


func _reset_logs() -> void:
	logs = {
		"answers": []
	}


func _log_new_response(response: Dictionary, current_stimulus: Dictionary) -> void:
	var response_log: = {
		"reponse": response,
		"awaited_response": current_stimulus,
		"is_right": response == current_stimulus,
		"minigame": minigame_name,
		"number_of_hints": current_number_of_hints,
		"current_progression": current_progression,
		"max_progression": max_progression,
		"current_lives": current_lives,
		"max_number_of_lives": max_number_of_lives,
	}
	
	logs["answers"].append(response_log)


# ------------ UI Callbacks ------------


func _go_back_to_the_garden() -> void:
	get_tree().paused = false
	await OpeningCurtain.close()
	
	_save_logs()
	
	var minigame_selection: MinigameSelection = minigame_selection_scene.instantiate()
	minigame_selection.lesson_number = lesson_nb
	
	get_tree().root.add_child(minigame_selection)
	get_tree().current_scene = minigame_selection
	queue_free()


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


func _highlight() -> void:
	pass


func _first_error_hint() -> void:
	minigame_ui.play_kalulu_speech(help_kalulu_speech)


func _two_errors_hint() -> void:
	_highlight()


# ------------ Setter getters ------------


func set_current_progression(p_current_progression: int) -> void:
	var previous_progression: = current_progression
	current_progression = p_current_progression
	
	consecutive_errors = 0
	
	if minigame_ui:
		minigame_ui.set_progression(p_current_progression)
	if p_current_progression == max_progression and previous_progression != max_progression:
		await _win()
	else:
		@warning_ignore("redundant_await")
		await _on_current_progression_changed()


# ------------ Connections ------------


func _on_minigame_ui_garden_button_pressed() -> void:
	_go_back_to_the_garden()


func _on_minigame_ui_stimulus_button_pressed() -> void:
	get_tree().paused = true
	minigame_ui.lock()
	
	await minigame_ui.repeat_stimulus_animation(true)
	
	@warning_ignore("redundant_await")
	await _play_stimulus()
	
	await minigame_ui.repeat_stimulus_animation(false)
	
	minigame_ui.unlock()
	get_tree().paused = false


func _on_minigame_ui_pause_button_pressed() -> void:
	_pause_game()


func _on_minigame_ui_kalulu_button_pressed() -> void:
	_play_kalulu()


func _on_minigame_ui_restart_button_pressed() -> void:
	_reset()


func _on_minigame_ui_back_to_menu_pressed() -> void:
	_go_back_to_the_garden()


func _on_minigame_ui_master_volume_changed(volume) -> void:
	UserDataManager.set_master_volume(volume)


func _on_minigame_ui_music_volume_changed(volume) -> void:
	UserDataManager.set_music_volume(volume)


func _on_minigame_ui_voice_volume_changed(volume) -> void:
	UserDataManager.set_voice_volume(volume)


func _on_minigame_ui_effects_volume_changed(volume) -> void:
	UserDataManager.set_effects_volume(volume)


func _on_current_progression_changed() -> void:
	pass
