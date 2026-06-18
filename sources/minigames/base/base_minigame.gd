class_name Minigame
extends Control

enum Type {
	JELLYFISH,
	CRABS,
	PARAKEETS,
	MONKEY,
	CATERPILLAR,
	FROG,
	TURTLES,
	ANTS,
	PENGUIN,
	FISH,
}

# String names used for file paths, database keys, and speech lookups.
# Kept separate from enum member names so renaming members doesn't affect runtime behaviour.
const TYPE_NAMES: Array[String] = [
	"jellyfish",
	"crabs",
	"parakeets",
	"monkey",
	"caterpillar",
	"frog",
	"turtles",
	"ants",
	"penguin",
	"fish",
]
const WIN_SOUND_FX: AudioStreamMP3 = preload("res://assets/sfx/sfx_game_over_win.mp3")
const LOSE_SOUND_FX: AudioStreamMP3 = preload("res://assets/sfx/sfx_game_over_lose.mp3")
const LABEL_COLOR_NEUTRAL: Color = Color("#e6f3e0")
const LABEL_COLOR_WIN: Color = Color("#009344")
const LABEL_COLOR_LOSE: Color = Color("#be1e2d")

static var transition_data: Dictionary = {}

@export var minigame_name: Type
@export var lesson_nb: int = 1
@export_range(0, 4) var difficulty: int = 0
@export_range(0, 1) var current_lesson_stimuli_ratio: float = 0.7
@export var minigame_number: int = 0
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

# Logs
var logs: Dictionary = {}
# Scores for the remediation engine
var remediation_gp_scores: Dictionary = {}
var remediation_syllables_scores: Dictionary = {}
var remediation_words_scores: Dictionary = {}
# Scores for the confusion matrix engine
var confusion_matrix_gp_scores: Dictionary[int, PackedInt32Array] = {}
# Final boss state
var is_final_boss: bool = false
# Stimuli
var stimuli: Array = []
var distractions: Array = []
# Hidden lives counter — used ONLY to compute the next run's difficulty.
#
# The player never sees this value and can never "lose" a regular minigame because of it:
# every run ends with the win screen once `current_progression` reaches `max_progression`.
# Starts at `max_number_of_lives` and individual minigames decrement it with `current_lives -= 1`
# each time the child makes a mistake. It is allowed to go negative — that's the whole point.
#
# At end of game, `_win()` reads this value:
#   - `current_lives >= 0` (fewer mistakes than allowed) → counted as a win, difficulty may go up
#   - `current_lives <  0` (more mistakes than allowed)  → counted as a loss, difficulty may go down
#
# The counter is also reused (as a convenient proxy for "how many recent mistakes") to drive
# the in-game hint system (Kalulu help speech and highlighting). That side effect IS visible to
# the player, but the raw lives number is not — do not add any UI that exposes it.
var current_lives: int = 0:
	set(value):
		var previous_lives: int = current_lives
		current_lives = value
		if current_lives != previous_lives:
			Log.trace("BaseMinigame: Lives changed from %d to %d (max %d) for %s" % [previous_lives, current_lives, max_number_of_lives, TYPE_NAMES[minigame_name]])
		if current_lives < previous_lives:
			consecutive_errors += previous_lives - current_lives
		var help_speech_threshold: int = max_number_of_lives - errors_before_help_speech
		if previous_lives > help_speech_threshold and current_lives <= help_speech_threshold:
			_play_kalulu_help_speech()
		if consecutive_errors == errors_before_highlight:
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

@onready var minigame_ui: MinigameUI = $MinigameUI
@onready var audio_player: MinigameAudioStreamPlayer = $AudioStreamPlayer
@onready var fireworks: Fireworks = $Fireworks
# Game root shall contain all the game tree.
# This node is pausable unlike the others, so the pause button can stop the game but not other essential processes.
@onready var game_root: Control = $GameRoot
# Expected number of stimuli from current lesson
@onready var current_lesson_stimuli_number: int = floori(max_progression * current_lesson_stimuli_ratio)

#region Initialisation

func _ready() -> void:
	gardens_data = transition_data
	minigame_number = transition_data.get("minigame_number", minigame_number)
	lesson_nb = transition_data.get("current_lesson_number", lesson_nb)
	is_final_boss = transition_data.get("is_final_boss", false) as bool
	
	# Difficulty
	if (UserDataManager as UserDataManagerClass)._student_difficulty:
		difficulty = UserDataManager.get_difficulty_for_minigame(TYPE_NAMES[minigame_name] as String)
	
	intro_kalulu_speech = Database.load_external_sound(Database.get_kalulu_speech_path(TYPE_NAMES[minigame_name] as String, "intro"))
	help_kalulu_speech = Database.load_external_sound(Database.get_kalulu_speech_path(TYPE_NAMES[minigame_name] as String, "help"))
	win_kalulu_speech = Database.load_external_sound(Database.get_kalulu_speech_path(TYPE_NAMES[minigame_name] as String, "end"))
	lose_kalulu_speech = Database.load_external_sound(Database.get_kalulu_speech_path("minigame", "lose"))
	
	if not Engine.is_editor_hint():
		# Stop the current music
		(MusicManager as MusicManagerClass).stop()
	
	_reset_logs()
	_initialize()


func _initialize() -> void:
	if not Engine.is_editor_hint():
		_find_stimuli_and_distractions()
	
	# Await so minigames whose setup is a coroutine (e.g. staged instantiation,
	# particle shader warmup) finish before the curtain opens and _start() runs.
	@warning_ignore("redundant_await")
	await _setup_minigame()
	
	Log.info("BaseMinigame: Initialize %s (lesson %d, minigame #%d, difficulty %d)" % [TYPE_NAMES[minigame_name], lesson_nb, minigame_number, difficulty])
	
	if not Engine.is_editor_hint():
		await _curtains_and_kalulu()
		_start()


# Find and set the parameters of the minigame, like the number of lives or the victory conditions.
func _setup_minigame() -> void:
	Log.trace("BaseMinigame: SetupMinigame")
	max_progression = max_progression
	max_number_of_lives = max_number_of_lives
	current_lives = max_number_of_lives


# Find the stimuli and distractions of the minigame.
func _find_stimuli_and_distractions() -> void:
	Log.error("BaseMinigame: Minigame type " + str(minigame_name) + " has not implemented the function _find_stimuli_and_distractions()")
	return


# Opens the curtains and Kalulu explains
func _curtains_and_kalulu() -> void:
	await (OpeningCurtain as OpeningCurtainClass).open()
	
	# Checks if intro needs to be played
	if not UserDataManager.is_speech_played(TYPE_NAMES[minigame_name] as String):
		minigame_ui.play_kalulu_speech(intro_kalulu_speech)
		await minigame_ui.kalulu_speech_ended
		UserDataManager.mark_speech_as_played(TYPE_NAMES[minigame_name] as String)
#endregion

#region Timer
var _start_time: float = 0.0
var _elapsed_paused: float = 0.0
var _pause_start: float = 0.0
var _is_paused: bool = false


# Launch the minigame
func _start() -> void:
	Log.info("BaseMinigame: Start minigame=%s lesson=%d difficulty=%d" % [TYPE_NAMES[minigame_name], lesson_nb, difficulty])
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
	await (OpeningCurtain as OpeningCurtainClass).close()
	get_tree().reload_current_scene()


func _win() -> void:
	# Lock the UI
	minigame_ui.lock()
	
	_submit_student_level_time()
	
	if gardens_data:
		gardens_data.minigame_completed = true
	
	if UserDataManager.student_progression:
		if gardens_data.has("boss_gate_lesson"):
			gardens_data.boss_completed = UserDataManager.student_progression.boss_completed(gardens_data.boss_gate_lesson as int)
			gardens_data.first_clear = gardens_data.boss_completed
			if not is_final_boss:
				UserDataManager.student_progression.reset_boss_failure_streak()
		else:
			gardens_data.first_clear = UserDataManager.student_progression.game_completed(lesson_nb, minigame_number)
	
	update_scores()
	
	Log.info("BaseMinigame: %s won in %d seconds with progression %d/%d and %d/%d lives" % [TYPE_NAMES[minigame_name], _get_elapsed_time_seconds(), current_progression, max_progression, current_lives, max_number_of_lives])

	# Hidden difficulty check — see the `current_lives` declaration above.
	# The player always reaches this branch (no visible loss), but if they used up more than
	# `max_number_of_lives` mistakes (`current_lives` ended strictly negative), this run is
	# reported to the difficulty system as a loss so the next session eases up.
	var counted_as_win: bool = current_lives >= 0
	UserDataManager.update_difficulty_for_minigame(TYPE_NAMES[minigame_name] as String, counted_as_win)
	
	audio_player.stream = WIN_SOUND_FX
	audio_player.play()
	
	fireworks.play()
	await fireworks.finished
	
	minigame_ui.play_kalulu_speech(win_kalulu_speech)
	await minigame_ui.kalulu_speech_ended
	
	_go_back_to_the_garden()


func update_scores() -> void:
	# Remediation
	if remediation_gp_scores:
		UserDataManager.update_remediation_gp_scores(remediation_gp_scores)
	if remediation_syllables_scores:
		UserDataManager.update_remediation_syllables_scores(remediation_syllables_scores)
	if remediation_words_scores:
		UserDataManager.update_remediation_words_scores(remediation_words_scores)
	
	# Confusion Matrix
	if confusion_matrix_gp_scores:
		UserDataManager.update_confusion_matrix_gp_scores(confusion_matrix_gp_scores)


func _lose() -> void:
	# Lock the UI
	minigame_ui.lock()
	
	_submit_student_level_time()
	
	if gardens_data:
		gardens_data.minigame_completed = false
	
	update_scores()
	
	Log.info("BaseMinigame: %s Lose in %d seconds with progression %d/%d and %d/%d lives" % [TYPE_NAMES[minigame_name], _get_elapsed_time_seconds(), current_progression, max_progression, current_lives, max_number_of_lives])
	
	# Difficulty
	UserDataManager.update_difficulty_for_minigame(TYPE_NAMES[minigame_name] as String, false)
	
	audio_player.stream = LOSE_SOUND_FX
	audio_player.play()
	await audio_player.finished
	
	minigame_ui.play_kalulu_speech(lose_kalulu_speech)
	await minigame_ui.kalulu_speech_ended
	if gardens_data.has("boss_gate_lesson") and not is_final_boss and UserDataManager.student_progression:
		var is_blocked: bool = UserDataManager.student_progression.register_boss_failure()
		if is_blocked:
			if has_method("show_adult_block"):
				call("show_adult_block")
			else:
				Log.error("BaseMinigame: Adult block requested but no handler exists for %s" % TYPE_NAMES[minigame_name])
			return
	
	_reset()


func _submit_student_level_time() -> void:
	if gardens_data.has("boss_gate_lesson"):
		return
	UserDataManager.add_level_time(lesson_nb, minigame_number, _get_elapsed_time_seconds())


func _get_elapsed_time_seconds() -> int:
	return int(Time.get_ticks_msec() / 1000.0 - _start_time - _elapsed_paused)

#endregion

#region Logs

func _save_logs() -> void:
	var logs_size: int = -1
	if logs.has("answers") and logs.get("answers", []) is Array:
		logs_size = (logs.get("answers", []) as Array).size()
	Log.info("BaseMinigame: Saving logs for %s with %d answer(s)" % [TYPE_NAMES[minigame_name], logs_size])
	LessonLogger.save_logs(logs, UserDataManager.get_student_folder(), TYPE_NAMES[minigame_name] as String, lesson_nb, Time.get_time_string_from_system())
	_reset_logs()


func _reset_logs() -> void:
	logs = {"answers": []}


func _log_new_response(response: Dictionary, current_stimulus: Dictionary) -> void:
	var response_log: Dictionary = {
		"reponse": response,
		"awaited_response": current_stimulus,
		"is_right": response == current_stimulus,
		"minigame": TYPE_NAMES[minigame_name],
		"number_of_hints": current_number_of_hints,
		"current_progression": current_progression,
		"max_progression": max_progression,
		"current_lives": current_lives,
		"max_number_of_lives": max_number_of_lives,
	}
	Log.trace("BaseMinigame: Log new response minigame=%s response=%s expected=%s right=%s progression=%d/%d lives=%d/%d" % [
				TYPE_NAMES[minigame_name],
				str(response),
				str(current_stimulus),
				str(response_log.is_right),
				current_progression,
				max_progression,
				current_lives,
				max_number_of_lives])
	
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


# Updates the remediation score of a GP defined by his ID
func _update_remediation_gp_score(id: int, score: int) -> void:
	var new_remediation_gp_score: int = 0
	if remediation_gp_scores.has(id):
		new_remediation_gp_score += remediation_gp_scores[id]
	new_remediation_gp_score += score
	remediation_gp_scores[id] = new_remediation_gp_score


# Updates the remediation score of a syllable defined by his ID
func _update_remediation_syllable_score(id: int, score: int) -> void:
	var new_remediation_syllable_score: int = 0
	if remediation_syllables_scores.has(id):
		new_remediation_syllable_score += remediation_syllables_scores[id]
	new_remediation_syllable_score += score
	remediation_syllables_scores[id] = new_remediation_syllable_score


# Updates the remediation score of a word defined by his ID
func _update_remediation_word_score(id: int, score: int) -> void:
	var new_remediation_word_score: int = 0
	if remediation_words_scores.has(id):
		new_remediation_word_score += remediation_words_scores[id]
	new_remediation_word_score += score
	remediation_words_scores[id] = new_remediation_word_score

#endregion

#region Confusion Matrix

func _update_confusion_matrix_gp_score(expected_id: int, selected_id: int) -> void:
	var stored: PackedInt32Array = PackedInt32Array()
	if confusion_matrix_gp_scores.has(expected_id):
		stored = confusion_matrix_gp_scores[expected_id]
	stored.append(selected_id)
	confusion_matrix_gp_scores[expected_id] = stored

#endregion

#region UI Callbacks

func _go_back_to_the_garden() -> void:
	get_tree().paused = false
	await (OpeningCurtain as OpeningCurtainClass).close()
	
	_save_logs()
	
	Gardens.transition_data = gardens_data
	SceneLoader.change_scene("res://sources/gardens/gardens.tscn")


func _play_stimulus() -> void:
	return


func _set_root_timers_paused(paused: bool) -> void:
	for child: Node in get_children():
		if child is Timer:
			(child as Timer).paused = paused


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
	Log.trace("BaseMinigame: Progression changed from %d to %d/%d for %s" % [previous_progression, current_progression, max_progression, TYPE_NAMES[minigame_name]])
	
	consecutive_errors = 0
	is_highlighting = false
	
	if minigame_ui:
		minigame_ui.set_progression(p_current_progression)
	if p_current_progression == max_progression and previous_progression != max_progression:
		await _win()
	else:
		await _on_current_progression_changed()

#endregion

#region Connections

func _on_minigame_ui_back_button_pressed() -> void:
	_go_back_to_the_garden()
	update_scores()


func _on_minigame_ui_stimulus_button_pressed() -> void:
	game_root.process_mode = Node.PROCESS_MODE_DISABLED
	set_process(false)
	set_physics_process(false)
	_set_root_timers_paused(true)
	minigame_ui.lock()

	@warning_ignore("redundant_await")
	await _play_stimulus()

	minigame_ui.unlock()
	_set_root_timers_paused(false)
	set_process(true)
	set_physics_process(true)
	game_root.process_mode = Node.PROCESS_MODE_PAUSABLE


func _on_minigame_ui_kalulu_button_pressed() -> void:
	minigame_ui.play_kalulu_speech(help_kalulu_speech)


func _on_minigame_ui_restart_button_pressed() -> void:
	_reset()


func _on_current_progression_changed() -> void:
	# Make Godot understand that this function is a coroutine even if it does nothing, to avoid warning
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		await (main_loop as SceneTree).create_timer(0).timeout

#endregion
