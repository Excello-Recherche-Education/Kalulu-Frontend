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
	super()
	if stimuli.is_empty():
		_win()
		return
	stimulus_timer.wait_time = stimulus_repeat_time
	await _play_current_stimulus_phoneme()


# Find the stimuli and distractions of the minigame.
# For this type of minigame, only vowels and syllables are allowed
func _find_stimuli_and_distractions() -> void:
	var all_syllables: = Database.get_syllables_for_lesson(lesson_nb, false)
	if not all_syllables:
		return
	
	var current_lesson_stimuli: Array[Dictionary] = []
	var previous_lesson_stimuli: Array[Dictionary] = []
	
	# Find the syllables for current lesson
	for syllable: Dictionary in all_syllables:
		if syllable.LessonNb == lesson_nb:
			current_lesson_stimuli.append(syllable)
		else:
			previous_lesson_stimuli.append(syllable)
	
	
	# Shuffle everything
	current_lesson_stimuli.shuffle()
	previous_lesson_stimuli.shuffle()
	
	# Sort for remediation
	current_lesson_stimuli.sort_custom(_sort_scoring)
	previous_lesson_stimuli.sort_custom(_sort_scoring)
	
	# If there is no previous stimuli, only adds from current lesson
	if previous_lesson_stimuli.is_empty():
		while stimuli.size() < max_progression:
			stimuli.append(current_lesson_stimuli.pick_random())
	else:
		if current_lesson_stimuli:
			# If there are more stimuli in current lesson than needed
			if current_lesson_stimuli.size() >= current_lesson_stimuli_number:
				for index: int in current_lesson_stimuli_number:
					stimuli.append(current_lesson_stimuli[index])
			else:
				stimuli.append_array(current_lesson_stimuli)
			
			# If there are not enough stimuli from current lesson, we want at least half the target number of stimuli
			@warning_ignore("integer_division")
			var minimal_stimuli : int = current_lesson_stimuli_number/2
			if stimuli.size() < minimal_stimuli:
				while stimuli.size() < minimal_stimuli:
					stimuli.append(current_lesson_stimuli.pick_random())
		
		# Gets other stimuli from previous errors or lessons
		var spaces_left : int = max_progression - stimuli.size()
		if previous_lesson_stimuli.size() >= spaces_left:
			for index: int in spaces_left:
				stimuli.append(previous_lesson_stimuli[index])
		else:
			stimuli.append_array(previous_lesson_stimuli)
		
		# If there are not enough stimuli, fill the rest with current lesson or previous lesson
		while stimuli.size() < max_progression:
			if current_lesson_stimuli:
				stimuli.append(current_lesson_stimuli.pick_random())
			else:
				stimuli.append(previous_lesson_stimuli.pick_random())
	
	# Shuffle the stimuli
	stimuli.shuffle()
	
	# For each stimuli get the distractors
	for stimulus: Dictionary in stimuli:
		var stimulus_distractors: Array[Dictionary] = []
		
		# Difficulty 1
		# Any previously learned item w/ all letters different
		for syllable: Dictionary in all_syllables:
			if syllable.Phoneme != stimulus.Phoneme:
				var gp_found_in_stimuli: = false
				for gp: Dictionary in syllable.GPs:
					if gp in stimulus.GPs:
						gp_found_in_stimuli = true
						break
			
				if not gp_found_in_stimuli:
					stimulus_distractors.append(syllable)
		
		# Higher difficulties only changes syllables distractors
		var stimulus_GPs: Array[Dictionary] = stimulus.GPs
		if difficulty > 1 and stimulus_GPs.size() == 2:
			for syllable: Dictionary in all_syllables:
				var syllable_GPs: Array[Dictionary] = syllable.GPs
				if syllable_GPs.size() != 2:
					continue
				
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
	var current_stimulus: Dictionary = _get_current_stimulus()
	return stimulus == current_stimulus


# Play the phoneme of the current stimulus
func _play_current_stimulus_phoneme() -> void:
	var current_stimulus: = _get_current_stimulus()
	if not current_stimulus or not current_stimulus.has("Phoneme"):
		return
	
	is_stimulus_heard = true
	if current_stimulus.has("GPs"):
		await audio_player.play_word(current_stimulus.Grapheme as String)
	else:
		await audio_player.play_gp(current_stimulus)
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
			for gp: Dictionary in stimulus.GPs:
				_update_score(gp.ID as int, 1)
		else:
			# Handles highlight
			is_highlighting = false
		
		_on_stimulus_found()
		stimulus_found.emit()
	else:
		var right_answer_GPs: Array[Dictionary] = _get_current_stimulus().GPs
		
		var stimulus_GPs: Array[Dictionary]
		if stimulus.has("GPs"):
			stimulus_GPs = stimulus.GPs
		
		# Handles the right answer GPs
		# RA os - stimulus à
		for index: int in right_answer_GPs.size():
			if not stimulus_GPs or (index < stimulus_GPs.size() and stimulus_GPs[index] == right_answer_GPs[index]):
				continue
			_update_score(right_answer_GPs[index].ID as int, -1)
		
		# Handles the pressed stimulus Gps
		if stimulus_GPs:
			for index: int in stimulus_GPs.size():
				if index < right_answer_GPs.size() and stimulus_GPs[index] == right_answer_GPs[index]:
					continue
				_update_score(stimulus_GPs[index].ID as int, -1)
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
