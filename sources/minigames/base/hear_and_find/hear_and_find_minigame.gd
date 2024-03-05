extends Minigame
class_name HearAndFindMinigame

func _find_stimuli_and_distractions() -> void:
	var current_lesson_stimuli = []
	var previous_lesson_stimuli = []
	
	var all_GPs = Database.get_GP_before_and_for_lesson(lesson_nb, false)
	var all_syllables = Database.get_syllables_for_lesson(lesson_nb, false)
	
	# Find the GPs for current lesson
	for gp in all_GPs:
		# Adds the vowels (Type = 1)
		if gp.Type == 1:
			if gp.LessonNb == lesson_nb:
				current_lesson_stimuli.append(gp)
			else:
				previous_lesson_stimuli.append(gp)
	
	# Find the syllables for current lesson
	for syllable in all_syllables:
		if syllable.LessonNb == lesson_nb:
			current_lesson_stimuli.append(syllable)
		else:
			previous_lesson_stimuli.append(syllable)
	
	# If there is no previous stimuli, only adds from current lesson
	if previous_lesson_stimuli.is_empty():
		while stimuli.size() < max_progression:
			stimuli.append(current_lesson_stimuli[randi() % current_lesson_stimuli.size()])
	else:
		# Calculate the number of stimuli to add from this lesson (70% of the maximum progression)
		@warning_ignore("narrowing_conversion")
		var number_of_stimuli: int = max_progression * stimuli_ratio
		while stimuli.size() < number_of_stimuli:
			stimuli.append(current_lesson_stimuli[randi() % current_lesson_stimuli.size()])
		
		# Gets other stimuli from previous errors or lessons
		# TODO Handle previous errors
		while stimuli.size() < max_progression:
			stimuli.append(previous_lesson_stimuli[randi() % previous_lesson_stimuli.size()])
	
	# Shuffle the stimuli
	stimuli.shuffle()
	
	# For each stimuli get the distractors
	for stimulus in stimuli:
		var stimulus_distractors := []
		
		var GPs : Array
		if stimulus.has("GPs") and stimulus.GPs and stimulus.GPs.size() == 2:
			GPs = stimulus.GPs
		
		# Difficulty 1 
		# Any previously learned item w/ all letters different
		for gp in all_GPs:
				if gp.Grapheme != stimulus.Grapheme and gp.Phoneme != stimulus.Phoneme:
					stimulus_distractors.append(gp)
		if GPs:
			for syllable in all_syllables:
				if syllable.GPs[0] not in GPs and syllable.GPs[1] not in GPs:
					stimulus_distractors.append(syllable)
			
		
		# Higher difficulties only changes syllables distractors
		if difficulty > 1 and GPs:
			for syllable in all_syllables:
				# Difficulty 2-3
				# If the item has 2 GP ('cha'), distractors should have only a single letter change ('la' or 'che')
				if (syllable.GPs[0] == stimulus.GPs[0] and syllable.GPs[1] != stimulus.GPs[1]) or (syllable.GPs[0] != stimulus.GPs[0] and syllable.GPs[1] == stimulus.GPs[1]):
					stimulus_distractors.append(syllable)
				
				# Difficulty 4-5
				# If the item has 2 GP, inversed TARGET, i.e., for 'il', 'li' is a distractor
				if difficulty > 3 and syllable.GPs[0] == stimulus.GPs[1] and syllable.GPs[1] == stimulus.GPs[0]:
					stimulus_distractors.append(syllable)
		
		# Adds fake distractors (allow to have empty jellyfishes) if there are less than 4 distractors
		while stimulus_distractors.size() < 4:
			stimulus_distractors.append({})
	
		distractions.append(stimulus_distractors)


func _get_current_stimulus() -> Dictionary :
	if stimuli.size() == 0:
		return {}
	return stimuli[current_progression % stimuli.size()]


func _play_current_stimulus_phoneme()-> void:
	var current_stimulus: = _get_current_stimulus()
	if not current_stimulus or not current_stimulus.has("Phoneme"):
		return
	await audio_player.play_phoneme(current_stimulus.Phoneme)
