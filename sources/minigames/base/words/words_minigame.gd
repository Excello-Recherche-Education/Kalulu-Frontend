class_name WordsMinigame
extends Minigame

# Define the maximum number of GP inside each word
@export var max_number_of_gps: int = 6
# Define the size of the distractor queue for each GP
@export var distractors_queue_size: int = 6
# Define the time of visibility of a found word between rounds
@export var time_between_words: float = 3.

var current_word_progression: int = 0: set = _set_current_word_progression
var max_word_progression: int = 0
var current_gp_distractors_queue: Array[Dictionary] = []
var current_word_has_errors: bool = false


# Find the stimuli and distractions of the minigame.
func _find_stimuli_and_distractions() -> void:
	# Get the currently known words list
	var words_list: Array[Dictionary] = Database.get_words_for_lesson(lesson_nb, false, 2, max_number_of_gps)
	if words_list.is_empty():
		return
	
	var current_lesson_words: Array[Dictionary] = []
	var previous_lesson_words: Array[Dictionary] = []
	
	for word: Dictionary in words_list:
		if not FileAccess.file_exists(Database.get_word_sound_path(word)):
			continue
		
		if word.LessonNb == lesson_nb:
			current_lesson_words.append(word)
		else:
			previous_lesson_words.append(word)
	
	# Shuffle everything
	current_lesson_words.shuffle()
	previous_lesson_words.shuffle()
	
	# Sort for remediation based on GP
	current_lesson_words.sort_custom(_sort_scoring)
	previous_lesson_words.sort_custom(_sort_scoring)
	
	# If there is no previous stimuli, only adds from current lesson
	if previous_lesson_words.is_empty():
		while stimuli.size() < max_progression:
			stimuli.append(current_lesson_words.pick_random())
	else:
		if not current_lesson_words.is_empty():
			# If there are more stimuli in current lesson than needed
			if current_lesson_words.size() >= current_lesson_stimuli_number:
				for index: int in range(current_lesson_stimuli_number):
					stimuli.append(current_lesson_words[index])
			else:
				stimuli.append_array(current_lesson_words)
			
			# If there are not enough stimuli from current lesson, we want at least half the target number of stimuli
			var minimal_stimuli: int = floori(current_lesson_stimuli_number/2.0)
			if stimuli.size() < minimal_stimuli:
				while stimuli.size() < minimal_stimuli:
					stimuli.append(current_lesson_words.pick_random())
		
		# Gets other stimuli from previous errors or lessons
		var spaces_left: int = max_progression - stimuli.size()
		if previous_lesson_words.size() >= spaces_left:
			for index: int in range(spaces_left):
				stimuli.append(previous_lesson_words[index])
		else:
			stimuli.append_array(previous_lesson_words)
		
		# If there are not enough stimuli, fill the rest with current lesson or previous lesson
		if current_lesson_words:
			while stimuli.size() < max_progression:
				if current_lesson_words:
					stimuli.append(current_lesson_words.pick_random())
				else:
					stimuli.append(previous_lesson_words.pick_random())
	
	# Shuffle the stimuli
	stimuli.shuffle()
	
	# Find the GPs and distractors for each word
	for stimulus: Dictionary in stimuli:
		stimulus.GPs = Database.get_gp_from_word(stimulus.ID as int)
		var grapheme_distractions: Array = []
		for gp: Dictionary in stimulus.GPs:
			grapheme_distractions.append(Database.get_distractors_for_grapheme(gp.ID as int, lesson_nb))
		distractions.append(grapheme_distractions)


# Launch the minigame
func _start() -> void:
	super()
	if stimuli.is_empty():
		Logger.error("WordsMinigame: Cannot start game because stimuli is empty")
		_win()
		return
	_setup_word_progression()


# Find and set the parameters of the minigame, like the number of lives or the victory conditions.
func _setup_minigame() -> void:
	super()


# Setups the word progression for current progression
func _setup_word_progression() -> void:
	var stimulus: Dictionary = _get_current_stimulus()
	var gps: Array = stimulus.GPs as Array
	max_word_progression = gps.size()
	current_word_progression = 0
	
	_play_stimulus()


func _set_current_word_progression(p_current_word_progression: int) -> void:
	current_word_progression = p_current_word_progression
	
	consecutive_errors = 0
	is_highlighting = false
	
	if current_word_progression == max_word_progression:
		current_progression += 1
	else:
		@warning_ignore("redundant_await")
		await _on_current_word_progression_changed()


func _reset_distractors_queue() -> void:
	var current_distractors: Array = distractions[current_progression][current_word_progression] as Array
	
	current_gp_distractors_queue = current_distractors.duplicate()
	current_gp_distractors_queue.shuffle()
	while current_gp_distractors_queue.size() > distractors_queue_size:
		current_gp_distractors_queue.pop_front()


# Gets the previous stimulus which is already found
func _get_previous_stimulus() -> Dictionary:
	if stimuli.size() == 0 or current_progression == 0:
		return {}
	return stimuli[(current_progression-1) % stimuli.size()]


# Get the current stimulus which needs to be found to increase progression
func _get_current_stimulus() -> Dictionary:
	if stimuli.size() == 0:
		return {}
	return stimuli[current_progression % stimuli.size()]


# Get the distractors for current word
func _get_current_distractors() -> Array:
	return distractions[current_progression]


# Get the current GP to find
func _get_gp() -> Dictionary:
	var stimulus: Dictionary = _get_current_stimulus()
	if not stimulus or not stimulus.has("GPs") or current_word_progression >= (stimulus.GPs as Array).size():
		return {}
	return stimulus.GPs[current_word_progression]


# Get a random distractor for the current GP
func _get_distractor() -> Dictionary:
	if current_gp_distractors_queue.is_empty():
		_reset_distractors_queue()
		
	if current_gp_distractors_queue:
		return current_gp_distractors_queue.pop_front()
	
	return {}


# Check if the provided GP is the expected answer
func _is_gp_right(gp: Dictionary) -> bool:
	return gp == _get_gp()


# Log the response and score
func _log_new_response_and_score(gp: Dictionary) -> void:
	# Logs the answer
	_log_new_response(gp, self._get_gp())
	
	if gp.has("ID"): # GP can be an empty dictionary (empty word)
		_update_confusion_matrix_gp_score(self._get_gp().ID as int, gp.ID as int)
	else:
		Logger.trace("WordsMinigame: Confusion matrix cannot be updated because word is empty") # Empty word is normal, it just does not update the confusion matrix
	
	# Handles Remediation GP scoring
	if self._is_gp_right(gp):
		if not is_highlighting:
			_update_remediation_gp_score(gp.ID as int, 1)
	else:
		if gp:
			_update_remediation_gp_score(gp.ID as int, -1)
			current_word_has_errors = true
		_update_remediation_gp_score(self._get_gp().ID as int, -1)

# ------------- UI Callbacks ------------- #

func _play_stimulus() -> void:
	await audio_player.play_word(_get_current_stimulus().Word as String)

# -------------- CONNECTIONS -------------- #

func _on_current_word_progression_changed() -> void:
	_reset_distractors_queue()


func _on_current_progression_changed() -> void:
	if current_word_has_errors:
		_update_remediation_word_score(_get_current_stimulus().ID as int, -1)
		current_word_has_errors = false
	else:
		_update_remediation_word_score(_get_current_stimulus().ID as int, 1)
	if current_progression >= max_progression:
		return
	_setup_word_progression()
