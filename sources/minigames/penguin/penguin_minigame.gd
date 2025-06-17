@tool
extends Minigame

# Namespace
const LABEL_SCENE: PackedScene = preload("res://sources/minigames/penguin/penguin_label.tscn")


@onready var penguin: Penguin = $GameRoot/Penguin
@onready var labels_container: HFlowContainer = $GameRoot/Control/LabelsContainer

var current_word_progression: int = 0: set = _set_current_word_progression
var max_word_progression: int = 0

var labels: Array[PenguinLabel] = []

# Find words with silent GPs
func _find_stimuli_and_distractions() -> void:
	var sentences_list: Array = Database.get_sentences_for_lesson_with_silent_gps(lesson_nb)
	
	if sentences_list.is_empty():
		return
	var current_lesson_sentences: Array[Dictionary] = []
	var previous_lesson_sentences: Array[Dictionary] = []
	
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
				for index: int in current_lesson_stimuli_number:
					stimuli.append(current_lesson_sentences[index])
			else:
				stimuli.append_array(current_lesson_sentences)
			
			# If there are not enough stimuli from current lesson, we want at least half the target number of stimuli
			var minimal_stimuli: int = floori(current_lesson_stimuli_number/2.0)
			if stimuli.size() < minimal_stimuli:
				while stimuli.size() < minimal_stimuli:
					stimuli.append(current_lesson_sentences.pick_random())
		
		# Gets other stimuli from previous errors or lessons
		var spaces_left: int = max_progression - stimuli.size()
		if previous_lesson_sentences.size() >= spaces_left:
			for index: int in spaces_left:
				stimuli.append(previous_lesson_sentences[index])
		else:
			stimuli.append_array(previous_lesson_sentences)
		
		# If there are not enough stimuli, fill the rest with current lesson
		if current_lesson_sentences:
			while stimuli.size() < max_progression:
				stimuli.append(current_lesson_sentences.pick_random())
	
	# Shuffle the stimuli
	stimuli.shuffle()
	
	# Find the GPs and distractors for each word
	for sentence: Dictionary in stimuli:
		sentence.GPs = Database.get_gps_from_sentence(sentence.ID as int)
		
	Logger.trace("PenguinMinigame: Stimuli: %s" % str(stimuli))


# Launch the minigame
func _start() -> void:
	super()
	if stimuli.is_empty():
		_win()
		return
	_setup_word_progression()


# Setups the word progression for current progression
func _setup_word_progression() -> void:
	max_word_progression = 0
	
	for node: Node in labels_container.get_children():
		node.queue_free()
	labels.clear()
	
	var stimulus: Dictionary = _get_current_stimulus()
	
	var first_gp: bool = true
	var last_word_id: int
	var word_container: HBoxContainer
	
	for gp: Dictionary in stimulus.GPs:
		if gp.WordID != last_word_id:
			last_word_id = gp.WordID
			word_container = HBoxContainer.new()
			labels_container.add_child(word_container)
		
		var label: PenguinLabel = LABEL_SCENE.instantiate()
		if first_gp:
			label.capitalized = true
			first_gp = false
		label.gp = gp
		word_container.add_child(label)
		
		label.pressed.connect(_on_snowball_thrown.bind(label))
		
		labels.append(label)
		
		if gp.Type == 0:
			max_word_progression += 1
	
	current_word_progression = 0


func _highlight() -> void:
	for label: PenguinLabel in labels:
		if self._is_silent(label.gp) and not label.is_pressed:
			label.highlight()


func _stop_highlight() -> void:
	for label: PenguinLabel in labels:
		label.highlight(false)


# Get the current stimulus which needs to be found to increase progression
func _get_current_stimulus() -> Dictionary:
	if stimuli.size() == 0:
		return {}
	return stimuli[current_progression % stimuli.size()]


func _is_silent(gp: Dictionary) -> bool:
	return gp.Type == 0


func _set_current_word_progression(p_current_word_progression: int) -> void:
	current_word_progression = p_current_word_progression
	if current_word_progression == max_word_progression:
		current_progression += 1

#region Connections

func _on_snowball_thrown(pos: Vector2, label: PenguinLabel) -> void:
	# Disables all labels
	for p_label: PenguinLabel in labels:
		p_label.set_button_enabled(false)
	
	# Throw the snowball
	await penguin.throw(pos)
	
	# Checks if the GP pressed is silent
	if _is_silent(label.gp):
		penguin.happy()
		_update_score(label.gp.ID as int, 1)
		await label.right()
		
		current_word_progression += 1
	else:
		penguin.sad()
		_update_score(label.gp.ID as int, -1)
		await label.wrong()
		
		current_lives -= 1
	
	# Re-enables all labels
	for p_label: PenguinLabel in labels:
		p_label.set_button_enabled(true)
	
	penguin.idle()


func _on_current_progression_changed() -> void:
	if current_progression >= max_progression:
		return
	_setup_word_progression()

#endregion
