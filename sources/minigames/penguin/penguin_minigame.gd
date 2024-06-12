extends Minigame

# Namespace
const Penguin: = preload("res://sources/minigames/penguin/penguin.gd")

const penguin_scene: PackedScene = preload("res://sources/minigames/penguin/penguin.tscn")

const silent_phoneme: = "#"

@onready var main_penguin: Penguin = $GameRoot/Penguin
@onready var penguins_positions: Control = $GameRoot/PenguinsPositions

var current_word_progression: int = 0: set = _set_current_word_progression
var max_word_progression: int = 0
var penguins: Array[Penguin] = []


# Find words with silent GPs
func _find_stimuli_and_distractions() -> void:
	var words_list: Array[Dictionary] = Database.get_words_with_silent_gp_for_lesson(lesson_nb)
	
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
			var minimal_stimuli : int = floori(current_lesson_stimuli_number/2.0)
			if stimuli.size() < minimal_stimuli:
				while stimuli.size() < minimal_stimuli:
					stimuli.append(current_lesson_words.pick_random())
		
		# Gets other stimuli from previous errors or lessons
		var spaces_left : int = max_progression - stimuli.size()
		if previous_lesson_words.size() >= spaces_left:
			for i in spaces_left:
				stimuli.append(previous_lesson_words[i])
		else:
			stimuli.append_array(previous_lesson_words)
		
		# If there are not enough stimuli, fill the rest with current lesson
		if current_lesson_words:
			while stimuli.size() < max_progression:
				stimuli.append(current_lesson_words.pick_random())
	
	# Shuffle the stimuli
	stimuli.shuffle()
	
	# Find the GPs and distractors for each word
	for stimulus: Dictionary in stimuli:
		stimulus.GPs = Database.get_GP_from_word(stimulus.ID as int)


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
	for penguin: Penguin in penguins:
		penguin.queue_free()
	penguins.clear()
	
	var stimulus: = _get_current_stimulus()
	
	var i: = 1
	for GP: Dictionary in stimulus.GPs:
		# Instantiate a new penguin TODO Animations
		var penguin: Penguin = penguin_scene.instantiate()
		penguins_positions.get_node("Pos" + str(i)).add_child(penguin)
		penguin.gp = GP
		penguin.pressed.connect(_on_snowball_thrown.bind(penguin))
		
		penguins.append(penguin)
		
		i += 1
		
		if GP.Phoneme == silent_phoneme:
			max_word_progression += 1
	current_word_progression = 0


func _highlight() -> void:
	for penguin: Penguin in penguins:
		if self._is_silent(penguin.gp) and not penguin.is_pressed:
			penguin.highlight()


func _stop_highlight() -> void:
	for penguin: Penguin in penguins:
		penguin.highlight(false)


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

func _on_snowball_thrown(pos: Vector2, penguin: Penguin) -> void:
	# Disables all penguins
	for p: Penguin in penguins:
		p.set_button_enabled(false)
	
	# Throw the snowball
	await main_penguin.throw(pos)
	
	# Checks if the GP pressed is silent
	if _is_silent(penguin.gp):
		main_penguin.happy()
		penguin.happy()
		await penguin.right()
		
		current_word_progression += 1
	else:
		main_penguin.sad()
		penguin.sad()
		await penguin.wrong()
		
		current_lives -= 1
	
	# Re-enables all penguins
	for p: Penguin in penguins:
		p.set_button_enabled(true)
	
	main_penguin.idle()


func _on_current_progression_changed() -> void:
	if current_progression >= max_progression:
		return
	_setup_word_progression()

#endregion
