extends Control
class_name Minigame

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

@export var lesson_nb: int = 1
@export_range(0, 4) var difficulty: int = 0
@export_range(0, 1) var current_lesson_stimuli_ratio: float = 0.7
@export var minigame_number: int = 1

@export_category("Difficulty")
@export var max_number_of_lives: int = 0:
	set(value):
		max_number_of_lives = value

@export var max_progression: int = 0:
	set(value):
		max_progression = value
		if minigame_ui:
			minigame_ui.set_max_progression(value)

@export_category("Hints")
@export var errors_before_help_speech: int = 2
@export var errors_before_highlight: int = 3

@onready var minigame_ui: MinigameUI = $MinigameUI
@onready var audio_player: MinigameAudioStreamPlayer = $AudioStreamPlayer
@onready var fireworks: Fireworks = $Fireworks

# Game root shall contain all the game tree.
# This node is pausable unlike the others, so the pause button can stop the game but not other essential processes.
@onready var game_root: Control = $GameRoot

# Expected number of stimuli from current lesson
@onready var current_lesson_stimuli_number: int = floori(max_progression * current_lesson_stimuli_ratio)

# Sounds
const WIN_SOUND_FX: AudioStreamMP3 = preload("res://assets/sfx/sfx_game_over_win.mp3")
const LOSE_SOUND_FX: AudioStreamMP3 = preload("res://assets/sfx/sfx_game_over_lose.mp3")

# Lesson
var minigame_difficulty: int
var lesson_difficulty: int

# Logs
var logs: Dictionary = {}

# Scores for the remediation engine
var gp_scores: Dictionary = {}
var syllables_scores: Dictionary = {}
var words_scores: Dictionary = {}

# Stimuli
var stimuli: Array = []
var distractions: Array = []

# Lives
var current_lives: int = 0:
	set(value):
		var previous_lives: int = current_lives
		current_lives = value
		
		if current_lives < previous_lives:
			consecutive_errors += previous_lives - current_lives
		
		if current_lives <= max_number_of_lives - errors_before_help_speech:
			_play_kalulu_help_speech()
		elif consecutive_errors == errors_before_highlight:
			is_highlighting = true

# Progression
var current_progression: int = 0: set = set_current_progression
var current_number_of_hints: int = 0
var consecutive_errors: int = 0
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
var gardens_data: Dictionary = {}
static var transition_data: Dictionary = {}

#region Initialisation

func _ready() -> void:
	gardens_data = transition_data
	minigame_number = transition_data.get("minigame_number", minigame_number)
	lesson_nb = transition_data.get("current_lesson_number", lesson_nb)
	#transition_data = {}
	
	# Difficulty
	if UserDataManager._student_difficulty:
		difficulty = UserDataManager.get_difficulty_for_minigame(Type.keys()[minigame_name] as String)
	
	intro_kalulu_speech = Database.load_external_sound(Database.get_kalulu_speech_path(Type.keys()[minigame_name] as String, "intro"))
	help_kalulu_speech = Database.load_external_sound(Database.get_kalulu_speech_path(Type.keys()[minigame_name] as String, "help"))
	win_kalulu_speech = Database.load_external_sound(Database.get_kalulu_speech_path(Type.keys()[minigame_name] as String, "end"))
	lose_kalulu_speech = Database.load_external_sound(Database.get_kalulu_speech_path("minigame", "lose"))
	
	if not Engine.is_editor_hint():
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
	Logger.error("Minigame type " + str(minigame_name) + " has not implemented the function _find_stimuli_and_distractions()")
	return


# Opens the curtains and Kalulu explains
func _curtains_and_kalulu() -> void:
	await OpeningCurtain.open()
	
	# Checks if intro needs to be played
	if not UserDataManager.is_speech_played(Type.keys()[minigame_name] as String):
		minigame_ui.play_kalulu_speech(intro_kalulu_speech)
		await minigame_ui.kalulu_speech_ended
		UserDataManager.mark_speech_as_played(Type.keys()[minigame_name] as String)
#endregion

#region Timer
var _start_time: float = 0.0
var _elapsed_paused: float = 0.0
var _pause_start: float = 0.0
var _is_paused: bool = false


# Launch the minigame
func _start() -> void:
	_start_time = Time.get_ticks_msec() / 1000.0
	_elapsed_paused = 0.0
	_is_paused = false
	return


func _notification(what: int) -> void:
	if _start_time == 0.0:
		return
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if not _is_paused:
				_pause_start = Time.get_ticks_msec() / 1000.0
				_is_paused = true

		NOTIFICATION_APPLICATION_FOCUS_IN:
			if _is_paused:
				var resumed: float = Time.get_ticks_msec() / 1000.0
				var pause_duration: float = resumed - _pause_start
				_elapsed_paused += pause_duration
				_is_paused = false
#endregion

#region Ending

func _reset() -> void:
	get_tree().paused = false
	await OpeningCurtain.close()
	get_tree().reload_current_scene()


func _win() -> void:
	
	# Lock the UI
	minigame_ui.lock()
	
	_submit_student_level_time()
	
	if gardens_data:
		gardens_data.minigame_completed = true
	
	if UserDataManager.student_progression:
		gardens_data.first_clear = UserDataManager.student_progression.game_completed(lesson_nb, minigame_number)
	
	update_remediation()
	
	# Difficulty
	if current_lives <= 0:
		UserDataManager.update_difficulty_for_minigame(Type.keys()[minigame_name] as String, false)
	else:
		UserDataManager.update_difficulty_for_minigame(Type.keys()[minigame_name] as String, true)
	
	audio_player.stream = WIN_SOUND_FX
	audio_player.play()
	
	fireworks.start()
	await fireworks.finished
	
	minigame_ui.play_kalulu_speech(win_kalulu_speech)
	await minigame_ui.kalulu_speech_ended
	
	_go_back_to_the_garden()


func update_remediation() -> void:
	if gp_scores:
		UserDataManager.update_remediation_gp_scores(gp_scores)
	if syllables_scores:
		UserDataManager.update_remediation_syllables_scores(syllables_scores)
	if words_scores:
		UserDataManager.update_remediation_words_scores(words_scores)


func _lose() -> void:
	# Lock the UI
	minigame_ui.lock()
	
	_submit_student_level_time()
	
	if gardens_data:
		gardens_data.minigame_completed = false
	
	update_remediation()
	
	# Difficulty
	UserDataManager.update_difficulty_for_minigame(Type.keys()[minigame_name] as String, false)
	
	audio_player.stream = LOSE_SOUND_FX
	audio_player.play()
	await audio_player.finished
	
	minigame_ui.play_kalulu_speech(lose_kalulu_speech)
	await minigame_ui.kalulu_speech_ended
	
	_reset()

func _submit_student_level_time() -> void:
	var elapsed_time: int = int(Time.get_ticks_msec() / 1000.0 - _start_time - _elapsed_paused)
	ServerManager.submit_student_level_time(lesson_nb, elapsed_time)

#endregion

#region Logs

func _save_logs() -> void:
	LessonLogger.save_logs(logs, UserDataManager.get_student_folder(), Type.keys()[minigame_name] as String, lesson_nb, Time.get_time_string_from_system())
	_reset_logs()


func _reset_logs() -> void:
	logs = {
		"answers": []
	}


func _log_new_response(response: Dictionary, current_stimulus: Dictionary) -> void:
	var response_log: Dictionary = {
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
	
	var answers: Array = logs["answers"]
	answers.append(response_log)

#endregion

#region Remediation

# Calculates the stimulus remediation score
func _get_stimulus_score(stimulus: Dictionary) -> int:
	var score: int = 0
	if stimulus.has("GPs"):
		for gp: Dictionary in stimulus.GPs:
			score += UserDataManager.get_gp_remediation_score(gp.ID as int)
	return score


# Sorting function to sort arrays of stimuli based on their remediation score
# If the score is lower (had more errors in the past), then the element is moved in first place
func _sort_scoring(stimulus1: Dictionary, stimulus2: Dictionary) -> bool:
	return _get_stimulus_score(stimulus1) < _get_stimulus_score(stimulus2)


# Updates the score of a GP defined by his ID
func _update_gp_score(id: int, score: int) -> void:
	var new_gp_score: int = 0
	if gp_scores.has(id):
		new_gp_score += gp_scores[id]
	new_gp_score += score
	gp_scores[id] = new_gp_score

# Updates the score of a syllable defined by his ID
func _update_syllable_score(id: int, score: int) -> void:
	var new_syllable_score: int = 0
	if syllables_scores.has(id):
		new_syllable_score += syllables_scores[id]
	new_syllable_score += score
	syllables_scores[id] = new_syllable_score

# Updates the score of a syllable defined by his ID
func _update_word_score(id: int, score: int) -> void:
	var new_word_score: int = 0
	if words_scores.has(id):
		new_word_score += words_scores[id]
	new_word_score += score
	words_scores[id] = new_word_score

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


func _pause_game() -> bool:
	var pause: bool = not get_tree().paused
	get_tree().paused = pause
	return pause


func _highlight() -> void:
	pass


func _stop_highlight() -> void:
	pass


func _play_kalulu_help_speech() -> void:
	minigame_ui.play_kalulu_speech(help_kalulu_speech)
	await minigame_ui.kalulu_speech_ended


#endregion

#region Setters

func set_current_progression(p_current_progression: int) -> void:
	var previous_progression: int = current_progression
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
	update_remediation()


func _on_minigame_ui_stimulus_button_pressed() -> void:
	_pause_game()
	minigame_ui.lock()
	
	#await minigame_ui.repeat_stimulus_animation(true)
	
	@warning_ignore("redundant_await")
	await _play_stimulus()
	
	#await minigame_ui.repeat_stimulus_animation(false)
	
	minigame_ui.unlock()
	_pause_game()


func _on_minigame_ui_kalulu_button_pressed() -> void:
	minigame_ui.play_kalulu_speech(help_kalulu_speech)


func _on_minigame_ui_restart_button_pressed() -> void:
	_reset()


func _on_current_progression_changed() -> void:
	pass

#endregion
