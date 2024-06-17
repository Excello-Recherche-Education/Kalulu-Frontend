extends Minigame

# Namespace
const Penguin: = preload("res://sources/minigames/penguin/penguin.gd")
const PenguinLabel: = preload("res://sources/minigames/penguin/penguin_label.gd")

const label_scene: PackedScene = preload("res://sources/minigames/penguin/penguin_label.tscn")

const silent_phoneme: = "#"

@onready var main_penguin: Penguin = $GameRoot/Penguin
@onready var labels_container: HBoxContainer = $GameRoot/Control/LabelsContainer
@onready var penguins_positions: Control = $GameRoot/PenguinsPositions

var current_word_progression: int = 0: set = _set_current_word_progression
var max_word_progression: int = 0

var labels: Array[Label] = []

# Find words with silent GPs
func _find_stimuli_and_distractions() -> void:
	var sentences_list: Array = Database.get_sentences_for_lesson_with_silent_GPs(lesson_nb)
	
	if sentences_list.is_empty():
		return
	var current_lesson_sentences: = []
	var previous_lesson_sentences: = []
	
	for sentence: Dictionary in sentences_list:
		if sentence.LessonNb == lesson_nb:
			current_lesson_sentences.append(sentence)
		else:
			previous_lesson_sentences.append(sentence)
	
	# Shuffle everything
	current_lesson_sentences.shuffle()
	previous_lesson_sentences.shuffle()
	
	# If there is no previous stimuli, only adds from current lesson
	if previous_lesson_sentences.is_empty():
		while stimuli.size() < max_progression:
			stimuli.append(current_lesson_sentences.pick_random())
	else:
		if not current_lesson_sentences.is_empty():
			# If there are more stimuli in current lesson than needed
			if current_lesson_sentences.size() >= current_lesson_stimuli_number:
				for i in current_lesson_stimuli_number:
					stimuli.append(current_lesson_sentences[i])
			else:
				stimuli.append_array(current_lesson_sentences)
			
			# If there are not enough stimuli from current lesson, we want at least half the target number of stimuli
			var minimal_stimuli : int = floori(current_lesson_stimuli_number/2.0)
			if stimuli.size() < minimal_stimuli:
				while stimuli.size() < minimal_stimuli:
					stimuli.append(current_lesson_sentences.pick_random())
		
		# Gets other stimuli from previous errors or lessons
		var spaces_left : int = max_progression - stimuli.size()
		if previous_lesson_sentences.size() >= spaces_left:
			for i in spaces_left:
				stimuli.append(previous_lesson_sentences[i])
		else:
			stimuli.append_array(previous_lesson_sentences)
		
		# If there are not enough stimuli, fill the rest with current lesson
		if current_lesson_sentences:
			while stimuli.size() < max_progression:
				stimuli.append(current_lesson_sentences.pick_random())
	
	# Shuffle the stimuli
	stimuli.shuffle()
	
	print(stimuli)
	
	# Find the GPs and distractors for each word
	for sentence: Dictionary in stimuli:
		sentence.GPs = Database.get_GPs_from_sentence(sentence.ID as int)


# Launch the minigame
func _start() -> void:
	if stimuli.is_empty():
		_win()
		return
	_setup_word_progression()


# Setups the word progression for current progression
func _setup_word_progression() -> void:
	max_word_progression = 0
	
	# Make penguins go away TODO Animations
	for label: PenguinLabel in labels:
		label.queue_free()
	labels.clear()
	
	var stimulus: = _get_current_stimulus()
	
	for GP: Dictionary in stimulus.GPs:
		# Instantiate a new penguin TODO Animations
		var label: PenguinLabel = label_scene.instantiate()
		label.gp = GP
		
		labels_container.add_child(label)
		
		label.pressed.connect(_on_snowball_thrown.bind(label))
		
		labels.append(label)
		
		if GP.Phoneme == silent_phoneme:
			max_word_progression += 1
	current_word_progression = 0


func _highlight() -> void:
	pass
	#for penguin: Penguin in penguins:
	#	if self._is_silent(penguin.gp) and not penguin.is_pressed:
	#		penguin.highlight()


func _stop_highlight() -> void:
	pass
	#for penguin: Penguin in penguins:
	#	penguin.highlight(false)


# Get the current stimulus which needs to be found to increase progression
func _get_current_stimulus() -> Dictionary:
	if stimuli.size() == 0:
		return {}
	return stimuli[current_progression % stimuli.size()]


func _is_silent(gp: Dictionary) -> bool:
	return gp.Phoneme == silent_phoneme


func _set_current_word_progression(p_current_word_progression: int) -> void:
	current_word_progression = p_current_word_progression
	if current_word_progression == max_word_progression:
		current_progression += 1

#region Connections

func _on_snowball_thrown(pos: Vector2, label: PenguinLabel) -> void:
	# Disables all penguins TODO
	#for p: Penguin in penguins:
	#	p.set_button_enabled(false)
	
	# Throw the snowball
	await main_penguin.throw(pos)
	
	# Checks if the GP pressed is silent
	if _is_silent(label.gp):
		main_penguin.happy()
		#penguin.happy()
		#await penguin.right()
		
		current_word_progression += 1
	else:
		main_penguin.sad()
		#penguin.sad()
		#await penguin.wrong()
		
		current_lives -= 1
	
	# Re-enables all penguins TODO
	#for p: Penguin in penguins:
	#	p.set_button_enabled(true)
	
	main_penguin.idle()


func _on_current_progression_changed() -> void:
	if current_progression >= max_progression:
		return
	_setup_word_progression()

#endregion
