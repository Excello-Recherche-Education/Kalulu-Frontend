extends Minigame
class_name HearAndSequentialsStepsMinigame

# TODO Remove when the jellyfish_minigame branch is merged and rebased
@export var difficulty: = 1
@export var lesson_nb: = 4

var current_word_progression: int = 0: set = _set_current_word_progression
var max_word_progression: int = 0

# Find the stimuli and distractions of the minigame.
func _find_stimuli_and_distractions() -> void:
	var words_list: = Database.get_words_for_lesson(lesson_nb)
	words_list.shuffle()
	for i in max_progression:
		var word = words_list[i].Word
		var GPs: = Database.get_GP_from_word(word)
		stimuli.append({
			Word = word,
			GPs = GPs,
		})
		var grapheme_distractions: = []
		for GP in GPs:
			grapheme_distractions.append(Database.get_distractors_for_grapheme(GP.Grapheme, lesson_nb))
		distractions.append(grapheme_distractions)
	
	print(stimuli)
	print(distractions)


# Launch the minigame
func _start() -> void:
	_setup_word_progression()


# Setups the word progression for current progression
func _setup_word_progression() -> void:
	var stimulus: = _get_current_stimulus()
	max_word_progression = stimulus.GPs.size()
	current_word_progression = 0
	
	_play_stimulus()


func _set_current_word_progression(p_current_word_progression: int) -> void:
	current_word_progression = p_current_word_progression
	
	if current_word_progression == max_word_progression:
		current_progression += 1
	else:
		@warning_ignore("redundant_await")
		await _on_current_word_progression_changed()


# Get the current stimulus which needs to be found to increase progression
func _get_current_stimulus() -> Dictionary:
	if stimuli.size() == 0:
		return {}
	return stimuli[current_progression % stimuli.size()]


# Get the current GP to find
func _get_GP() -> Dictionary:
	var stimulus: = _get_current_stimulus()
	if not stimulus or not stimulus.has("GPs"):
		return {}
	return stimulus.GPs[current_word_progression]


# Get a random distractor for the current GP
func _get_distractor() -> Dictionary:
	return distractions[current_progression][current_word_progression].pick_random()


# Check if the provided GP is the expected answer
func _is_GP_right(gp: Dictionary) -> bool:
	return gp == _get_GP()


# TODO Revoir après merge
func _play_current_GP() -> void:
	audio_player.stream = Database.get_audio_stream_for_phoneme(_get_GP().Phoneme)
	audio_player.play()
	if audio_player.playing:
		await audio_player.finished


# ------------- UI Callbacks ------------- #


# TODO Revoir après merge
func _play_stimulus() -> void:
	audio_player.stream = Database.get_audio_stream_for_word(_get_current_stimulus().Word)
	audio_player.play()
	if audio_player.playing:
		await audio_player.finished


# -------------- CONNECTIONS -------------- #


func _on_current_word_progression_changed() -> void:
	pass


func _on_current_progression_changed() -> void:
	if current_progression >= max_progression:
		return
	_setup_word_progression()
