@tool
extends Control
class_name Minigame

const Gardens: = preload("res://sources/gardens/gardens.gd")

enum Type {
	jellyfish,
	crabs,
	parakeets,
	monkey,
	caterpillar,
	frog,
	turtles,
	ants,
	penguin,
	fish
}


@export var minigame_name: Type

@export var lesson_nb: = 1
@export_range(0, 4) var difficulty: = 0
@export_range(0, 1) var current_lesson_stimuli_ratio : float = 0.7
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

@onready var minigame_ui: = $MinigameUI
@onready var audio_player: MinigameAudioStreamPlayer = $AudioStreamPlayer
@onready var fireworks: = $Fireworks

# Game root shall contain all the game tree.
# This node is pausable unlike the others, so the pause button can stop the game but not other essential processes.
@onready var game_root: = $GameRoot

# Expected number of stimuli from current lesson
@onready var current_lesson_stimuli_number: int = floori(max_progression * current_lesson_stimuli_ratio)

# Sounds
const win_sound_fx: = preload("res://assets/sfx/sfx_game_over_win.mp3")
const lose_sound_fx: = preload("res://assets/sfx/sfx_game_over_lose.mp3")

# Lesson
var minigame_difficulty: int
var lesson_difficulty: int

# Logs
var logs: = {}

# Scores for the remediation engine
var scores: = {} 

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
var is_highlighting: bool = false:
	set(value):
		is_highlighting = value
		if is_highlighting:
			_highlight()
		else:
			_stop_highlight()

# Speeches
var intro_kalulu_speech: AudioStreamMP3
var help_kalulu_speech: AudioStreamMP3
var win_kalulu_speech: AudioStreamMP3
var lose_kalulu_speech: AudioStreamMP3

# data to go back to the right place in gardens
var gardens_data: Dictionary
static var transition_data: Dictionary

#region Initialisation

func _ready() -> void:
	gardens_data = transition_data
	minigame_number = transition_data.get("minigame_number", minigame_number)
	lesson_nb = transition_data.get("current_lesson_number", lesson_nb)
	#transition_data = {}
	
	# Difficulty
	if UserDataManager._student_difficulty:
		difficulty = UserDataManager.get_difficulty_for_minigame(Type.keys()[minigame_name])
	
	intro_kalulu_speech = Database.load_external_sound(Database.get_kalulu_speech_path(Type.keys()[minigame_name], "intro"))
	help_kalulu_speech = Database.load_external_sound(Database.get_kalulu_speech_path(Type.keys()[minigame_name], "help"))
	win_kalulu_speech = Database.load_external_sound(Database.get_kalulu_speech_path(Type.keys()[minigame_name], "end"))
	lose_kalulu_speech = Database.load_external_sound(Database.get_kalulu_speech_path("minigame", "lose"))
	
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

#endregion

#region Ending

func _reset() -> void:
	await OpeningCurtain.close()
	
	get_tree().paused = false
	get_tree().reload_current_scene()


func _win() -> void:
	if UserDataManager.student_progression:
		UserDataManager.student_progression.game_completed(lesson_nb, minigame_number)
	
	# Remediation
	if scores:
		UserDataManager.update_remediation_scores(scores)
	
	# Difficulty
	UserDataManager.update_difficulty_for_minigame(Type.keys()[minigame_name], true)
	
	audio_player.stream = win_sound_fx
	audio_player.play()
	
	fireworks.start()
	await fireworks.finished
	
	minigame_ui.play_kalulu_speech(win_kalulu_speech)
	await minigame_ui.kalulu_speech_ended
	
	_go_back_to_the_garden()


func _lose() -> void:
	# Remediation
	if scores:
		UserDataManager.update_remediation_scores(scores)
	
	# Difficulty
	UserDataManager.update_difficulty_for_minigame(Type.keys()[minigame_name], false)
	
	audio_player.stream = lose_sound_fx
	audio_player.play()
	await audio_player.finished
	
	minigame_ui.play_kalulu_speech(lose_kalulu_speech)
	await minigame_ui.kalulu_speech_ended
	
	_reset()

#endregion

#region Logs

func _save_logs() -> void:
	LessonLogger.save_logs(logs, UserDataManager.get_student_folder(), Type.keys()[minigame_name], lesson_nb, Time.get_time_string_from_system())
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
		"minigame": Type.keys()[minigame_name],
		"number_of_hints": current_number_of_hints,
		"current_progression": current_progression,
		"max_progression": max_progression,
		"current_lives": current_lives,
		"max_number_of_lives": max_number_of_lives,
	}
	
	logs["answers"].append(response_log)

#endregion

#region Remediation

# Calculates the stimulus remediation score
func _get_stimulus_score(stimulus: Dictionary) -> int:
	var score: int = 0
	if stimulus.has("GPs"):
		for gp: Dictionary in stimulus.GPs:
			score += UserDataManager.get_GP_remediation_score(gp.ID)
	return score


# Sorting function to sort arrays of stimuli based on their remediation score
func _sort_scoring(stimulus1: Dictionary, stimulus2: Dictionary) -> bool:
	return _get_stimulus_score(stimulus2) > _get_stimulus_score(stimulus1)


# Updates the score of a GP defined by his ID
func _update_score(ID: int, score: int) -> void:
	var new_score: = 0
	if scores.has(ID):
		new_score += scores[ID]
	new_score += score
	scores[ID] = new_score

#endregion

#region UI Callbacks

func _go_back_to_the_garden() -> void:
	get_tree().paused = false
	await OpeningCurtain.close()
	
	_save_logs()
	
	Gardens.transition_data = gardens_data
	get_tree().change_scene_to_file("res://sources/gardens/gardens.tscn")


func _play_stimulus() -> void:
	return


func _pause_game() -> void:
	var pause: = not get_tree().paused
	get_tree().paused = pause
	minigame_ui.show_center_menu(pause)


func _play_kalulu() -> void:
	minigame_ui.play_kalulu_speech(help_kalulu_speech)
	await minigame_ui.kalulu_speech_ended


func _highlight() -> void:
	pass


func _stop_highlight() -> void:
	pass


func _first_error_hint() -> void:
	minigame_ui.play_kalulu_speech(help_kalulu_speech)


func _two_errors_hint() -> void:
	is_highlighting = true

#endregion

#region Setters

func set_current_progression(p_current_progression: int) -> void:
	var previous_progression: = current_progression
	current_progression = p_current_progression
	
	consecutive_errors = 0
	is_highlighting = false
	
	if minigame_ui:
		minigame_ui.set_progression(p_current_progression)
	if p_current_progression == max_progression and previous_progression != max_progression:
		await _win()
	else:
		@warning_ignore("redundant_await")
		await _on_current_progression_changed()

#endregion

#region Connections

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

#endregion
