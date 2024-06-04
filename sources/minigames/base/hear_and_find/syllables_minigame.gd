extends Minigame
class_name SyllablesMinigame

signal stimulus_heard(is_heard : bool)
signal stimulus_found()

# Time before a new stimulus when the previous one is found
@export var between_stimuli_time : float = 2.
# Time before the current stimulus is repeated
@export var stimulus_repeat_time : float = 15

@onready var stimulus_timer: Timer = $StimulusTimer

# Define if the current stimulus have been heard by the player. The stimuli can't be pressed if this is false
var is_stimulus_heard: bool = false:
	set(value):
		is_stimulus_heard = value
		stimulus_heard.emit(value)


func _start() -> void:
	stimulus_timer.wait_time = stimulus_repeat_time
	await _play_current_stimulus_phoneme()


# Find the stimuli and distractions of the minigame.
# For this type of minigame, only vowels and syllables are allowed
func _find_stimuli_and_distractions() -> void:
	var current_lesson_stimuli: Array[Dictionary] = []
	var previous_lesson_stimuli: Array[Dictionary] = []
	
	var all_GPs: = Database.get_GP_for_lesson(lesson_nb, false, false, true, true)
	var all_syllables: = Database.get_syllables_for_lesson(lesson_nb, false)
	
	# Find the GPs for current lesson
	for gp: Dictionary in all_GPs:
		if gp.LessonNb == lesson_nb:
			current_lesson_stimuli.append(gp)
		else:
			previous_lesson_stimuli.append(gp)
	
	# Find the syllables for current lesson
	for syllable: Dictionary in all_syllables:
		if syllable.LessonNb == lesson_nb:
			current_lesson_stimuli.append(syllable)
		else:
			previous_lesson_stimuli.append(syllable)
	
	# Shuffle everything
	current_lesson_stimuli.shuffle()
	previous_lesson_stimuli.shuffle()
	
	# Sort for remediation TODO Voir si il faut aussi trier les stimuli de la lesson actuelle
	current_lesson_stimuli.sort_custom(_sort_scoring)
	previous_lesson_stimuli.sort_custom(_sort_scoring)
	
	# If there is no previous stimuli, only adds from current lesson
	if previous_lesson_stimuli.is_empty():
		while stimuli.size() < max_progression:
			stimuli.append(current_lesson_stimuli.pick_random())
	else:
		
		# If there are more stimuli in current lesson than needed
		if current_lesson_stimuli.size() >= current_lesson_stimuli_number:
			for i in current_lesson_stimuli_number:
				stimuli.append(current_lesson_stimuli[i])
		else:
			stimuli.append_array(current_lesson_stimuli)
		
		# We if there are not enough stimuli from current lesson, we want at least half the target number of stimuli
		@warning_ignore("integer_division")
		var minimal_stimuli : int = current_lesson_stimuli_number/2
		if stimuli.size() < minimal_stimuli:
			while stimuli.size() < minimal_stimuli:
				stimuli.append(current_lesson_stimuli.pick_random())
		
		# Gets other stimuli from previous errors or lessons
		var spaces_left : int = max_progression - stimuli.size()
		if previous_lesson_stimuli.size() >= spaces_left:
			for i in spaces_left:
				stimuli.append(previous_lesson_stimuli[i])
		else:
			stimuli.append_array(previous_lesson_stimuli)
		
		# If there are not enough stimuli, fill the rest with current lesson
		while stimuli.size() < max_progression:
			stimuli.append(current_lesson_stimuli.pick_random())
	
	# Shuffle the stimuli
	stimuli.shuffle()
	
	# For each stimuli get the distractors
	for stimulus: Dictionary in stimuli:
		var stimulus_distractors := []
		
		var GPs : Array
		if stimulus.has("GPs") and stimulus.GPs and stimulus.GPs.size() == 2:
			GPs = stimulus.GPs
		
		# Difficulty 1 
		# Any previously learned item w/ all letters different
		for gp: Dictionary in all_GPs:
				if gp.Grapheme != stimulus.Grapheme and gp.Phoneme != stimulus.Phoneme and (not gp.OtherPhonemes or not gp.OtherPhonemes.has(stimulus.Phoneme)):
					stimulus_distractors.append(gp)
		if GPs:
			for syllable: Dictionary in all_syllables:
				if syllable.GPs.size() < 2:
					continue
				if syllable.GPs[0] not in GPs and syllable.GPs[1] not in GPs:
					stimulus_distractors.append(syllable)
			
		
		# Higher difficulties only changes syllables distractors
		if difficulty > 1 and GPs:
			for syllable: Dictionary in all_syllables:
				# Difficulty 2-3
				# If the item has 2 GP ('cha'), distractors should have only a single letter change ('la' or 'che')
				if (syllable.GPs[0] == stimulus.GPs[0] and syllable.GPs[1] != stimulus.GPs[1]) or (syllable.GPs[0] != stimulus.GPs[0] and syllable.GPs[1] == stimulus.GPs[1]):
					stimulus_distractors.append(syllable)
				
				# Difficulty 4-5
				# If the item has 2 GP, inversed TARGET, i.e., for 'il', 'li' is a distractor
				if difficulty > 3 and syllable.GPs[0] == stimulus.GPs[1] and syllable.GPs[1] == stimulus.GPs[0]:
					stimulus_distractors.append(syllable)
		
		# Adds fake distractors (allow to have empty texts) if there are less than 4 distractors
		while stimulus_distractors.size() < 4:
			stimulus_distractors.append({})
	
		distractions.append(stimulus_distractors)


# Get the current stimulus which needs to be found to increase progression
func _get_current_stimulus() -> Dictionary:
	if stimuli.size() == 0:
		return {}
	return stimuli[current_progression % stimuli.size()]


func _is_stimulus_found() -> bool:
	await stimulus_found
	return true


func _is_stimulus_right(stimulus : Dictionary) -> bool:
	var current_stimulus := _get_current_stimulus()
	return stimulus == current_stimulus


# Play the phoneme of the current stimulus
func _play_current_stimulus_phoneme() -> void:
	var current_stimulus: = _get_current_stimulus()
	if not current_stimulus or not current_stimulus.has("Phoneme"):
		return
	
	is_stimulus_heard = true
	await audio_player.play_phoneme(current_stimulus.Phoneme)
	stimulus_timer.start()


func _await_for_future_or_stimulus_found(future : Signal) -> bool:
	var coroutine: = Coroutine.new()
	coroutine.add_future(_is_stimulus_found)
	coroutine.add_future(future)
	await coroutine.join_either()
	
	# If the stimulus was found BEFORE the future
	if coroutine.return_value[0]:
		return true
	return false

# ------------ Connections ------------


func _on_stimulus_pressed(stimulus : Dictionary, _node : Node) -> bool:
	if not is_stimulus_heard:
		return false
	
	# Stop the repeat timer
	stimulus_timer.stop()
	
	# Log the answer
	_log_new_response(stimulus, _get_current_stimulus())
	
	# Checks the answer and update scores
	if _is_stimulus_right(stimulus):
		if not is_highlighting:
			# Checks if the stimulus is a simple GP or syllable and update the score
			if stimulus.has("GPs"):
				for gp in stimulus.GPs:
					_update_score(gp.ID, 1)
			else:
				_update_score(stimulus.ID, 1)
		else:
			# Handles highlight
			is_highlighting = false
		
		stimulus_found.emit()
	else:
		
		var stimulus_gps : Array[Dictionary]
		var right_answer_gps : Array[Dictionary]
		
		if stimulus.has("GPs"):
			stimulus_gps = stimulus.GPs
		else:
			stimulus_gps = [stimulus]
		
		var right_answer: = _get_current_stimulus()
		if right_answer.has("GPs"):
			right_answer_gps = right_answer.GPs
		else:
			right_answer_gps = [right_answer]
		
		# Handles the right answer GPs
		for i in right_answer_gps.size():
			if i <= stimulus_gps.size() and stimulus_gps[i] == right_answer_gps[i]:
				continue
			_update_score(right_answer_gps[i].ID, -1)
		
		# Handles the pressed stimulus Gps
		for i in stimulus_gps.size():
			if i <= right_answer_gps.size() and stimulus_gps[i] == right_answer_gps[i]:
				continue
			_update_score(stimulus_gps[i].ID, -1)
	
	print(scores)
	
	return true


func _on_stimulus_timer_timeout() -> void:
	_play_current_stimulus_phoneme()


func _on_stimulus_found() -> void:
	pass


#region UI Callbacks

func _on_current_progression_changed() -> void:
	if current_progression > 0:
		is_stimulus_heard = false
		await get_tree().create_timer(between_stimuli_time).timeout
		_play_current_stimulus_phoneme()


func _play_stimulus() -> void:
	await _play_current_stimulus_phoneme()

#endregion
