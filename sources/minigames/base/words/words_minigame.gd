extends Minigame
class_name WordsMinigame


var current_word_progression: int = 0: set = _set_current_word_progression
var max_word_progression: int = 0

# Find the stimuli and distractions of the minigame.
func _find_stimuli_and_distractions() -> void:
	# Get the currently known words list
	var words_list: = Database.get_words_for_lesson(lesson_nb, false, 6)
	if words_list.is_empty():
		return
	var current_lesson_words: = []
	var previous_lesson_words: = []
	
	for word: Dictionary in words_list:
		if word.LessonNb == lesson_nb:
			current_lesson_words.append(word)
		else:
			previous_lesson_words.append(word)
	
	# Shuffle everything
	current_lesson_words.shuffle()
	previous_lesson_words.shuffle()
	
	# If there is no previous stimuli, only adds from current lesson
	if previous_lesson_words.is_empty():
		while stimuli.size() < max_progression:
			stimuli.append(current_lesson_words.pick_random())
	else:
		if not current_lesson_words.is_empty():
			# If there are more stimuli in current lesson than needed
			if current_lesson_words.size() >= current_lesson_stimuli_number:
				for i in current_lesson_stimuli_number:
					stimuli.append(current_lesson_words[i])
			else:
				stimuli.append_array(current_lesson_words)
			
			# If there are not enough stimuli from current lesson, we want at least half the target number of stimuli
			var minimal_stimuli : int = floori(current_lesson_stimuli_number/2)
			if stimuli.size() < minimal_stimuli:
				while stimuli.size() < minimal_stimuli:
					stimuli.append(current_lesson_words.pick_random())
		
		# Gets other stimuli from previous errors or lessons
		# TODO Handle remediation engine
		var spaces_left : int = max_progression - stimuli.size()
		if previous_lesson_words.size() >= spaces_left:
			for i in max_progression - stimuli.size():
				stimuli.append(previous_lesson_words[i])
		else:
			stimuli.append_array(previous_lesson_words)
		
		# If there are not enough stimuli, fill the rest with current lesson
		while stimuli.size() < max_progression:
			stimuli.append(current_lesson_words.pick_random())
	
	# Shuffle the stimuli
	stimuli.shuffle()
	
	# Find the GPs and distractors for each word
	for stimulus: Dictionary in stimuli:
		stimulus["GPs"] = Database.get_GP_from_word(stimulus.Word)
		var grapheme_distractions: = []
		for GP in stimulus.GPs:
			grapheme_distractions.append(Database.get_distractors_for_grapheme(GP.Grapheme, lesson_nb))
		distractions.append(grapheme_distractions)
		
		print(stimulus)


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


func _play_stimulus() -> void:
	await audio_player.play_word(_get_current_stimulus().Word)


# -------------- CONNECTIONS -------------- #


func _on_current_word_progression_changed() -> void:
	pass


func _on_current_progression_changed() -> void:
	if current_progression >= max_progression:
		return
	_setup_word_progression()
