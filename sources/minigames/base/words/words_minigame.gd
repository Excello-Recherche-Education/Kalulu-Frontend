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
		# Through the ladder rather than the canonical name alone: a pack installed
		# before the names were encoded still holds the raw one, and a word with no
		# sound is dropped from the pool entirely.
		if Database.resolve_word_sound_path(word).is_empty():
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
		
		# If there are not enough stimuli, fill the rest with current lesson or previous lesson.
		# The inner test is the one that matters; an outer copy of it used to wrap this
		# loop, which meant a lesson whose every word lacks a recording skipped the fill
		# entirely and left the pool shorter than max_progression. SyllablesMinigame has
		# never had that wrapper.
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
		Log.error("WordsMinigame: Cannot start game because stimuli is empty")
		_win()
		return
	_setup_word_progression()


# Find and set the parameters of the minigame, like the number of lives or the victory conditions.
func _setup_minigame() -> void:
	Log.trace("WordsMinigame: SetupMinigame")
	super()


# Sets up the word progression for the current progression
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


## Which distractor set belongs to a progression, or -1 when there are none.
##
## There is one set per stimulus, and _get_current_stimulus wraps with a modulo so a
## pool shorter than max_progression repeats rather than running out. The distractors
## were read straight, so the moment the pool did come out short the game went out of
## range partway through and stopped on a dead screen. CrabsMinigame and
## JellyfishMinigame both wrap where this one did not.
##
## Static and given the count, so the rule can be checked without standing up a
## minigame or installing a language pack.
static func distractor_index(progression: int, distractor_count: int) -> int:
	if distractor_count <= 0:
		return -1
	return progression % distractor_count


## Refills the queue of wrong graphemes offered for the GP being asked for.
func _reset_distractors_queue() -> void:
	# Emptied first, so a guard below leaves the previous GP's distractors nowhere to
	# be picked up from. _get_distractor answers {} on an empty queue, which the
	# minigames already draw as a blank.
	current_gp_distractors_queue = []
	var index: int = distractor_index(current_progression, distractions.size())
	if index < 0:
		return
	var word_distractors: Array = distractions[index] as Array
	if current_word_progression >= word_distractors.size():
		return
	
	# assign() rather than duplicate(): it copies into the typed array instead of
	# replacing it, so a distractor list that reached here untyped is converted
	# rather than refused outright.
	current_gp_distractors_queue.assign(word_distractors[current_word_progression] as Array)
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
	var index: int = distractor_index(current_progression, distractions.size())
	return distractions[index] if index >= 0 else []


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
		Log.trace("WordsMinigame: Confusion matrix cannot be updated because word is empty") # Empty word is normal, it just does not update the confusion matrix
	
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
	var finished_stimulus: Dictionary = _get_previous_stimulus()
	if finished_stimulus.is_empty():
		Log.error("WordsMinigame: Finished stimulus is empty")
		return
	if current_word_has_errors:
		_update_remediation_word_score(finished_stimulus.ID as int, -1)
		current_word_has_errors = false
	else:
		_update_remediation_word_score(finished_stimulus.ID as int, 1)
	if current_progression >= max_progression:
		return
	_setup_word_progression()
