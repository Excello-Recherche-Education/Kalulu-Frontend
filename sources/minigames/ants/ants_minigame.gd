@tool
extends Minigame

const BLANK_SCENE: PackedScene = preload("res://sources/minigames/ants/blank.tscn")
const ANT_SCENE: PackedScene = preload("res://sources/minigames/ants/ant.tscn")
const WORD_SCENE: PackedScene = preload("res://sources/minigames/ants/word.tscn")

const LABEL_SETTINGS: LabelSettings = preload("res://resources/themes/minigames_label_settings.tres")

@onready var sentence_container: HFlowContainer = %Sentence
@onready var ants_spawn: Node2D = %AntsSpawn
@onready var ants_start: Node2D = %AntsStart
@onready var ants_end: Node2D = %AntsEnd
@onready var ants_despawn: Node2D = %AntsDespawn
@onready var ants: Node2D = %Ants
@onready var words: Node2D = %Words

var current_sentence: Dictionary = {}
var answered: Array[bool] = []
var answers: Array[bool] = []


func _find_stimuli_and_distractions() -> void:
	var sentences_list: Array = Database.get_sentences_for_lesson(lesson_nb, difficulty + 2, 50)
	if sentences_list.is_empty():
		return
		
	var current_lesson_sentences: Array[Dictionary] = []
	var previous_lesson_sentences: Array[Dictionary] = []

	for sentence_in_list: Dictionary in sentences_list:
		if sentence_in_list.LessonNb == lesson_nb:
			current_lesson_sentences.append(sentence_in_list)
		else:
			previous_lesson_sentences.append(sentence_in_list)

	# Shuffle everything
	current_lesson_sentences.shuffle()
	previous_lesson_sentences.shuffle()
	
	# If there is no previous stimuli, only adds from current lesson
	if not previous_lesson_sentences:
		if current_lesson_sentences.size() >= max_progression:
			for index: int in max_progression:
				stimuli.append(current_lesson_sentences[index])
		else:
			while stimuli.size() < max_progression:
				stimuli.append(current_lesson_sentences.pick_random())
	else:
		if current_lesson_sentences:
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

		# If there are not enough stimuli, fill the rest with current lesson or previous lesson
		if current_lesson_sentences:
			while stimuli.size() < max_progression:
				if current_lesson_sentences:
					stimuli.append(current_lesson_sentences.pick_random())
				else:
					stimuli.append(previous_lesson_sentences.pick_random())

	# Shuffle the stimuli
	stimuli.shuffle()


func _start() -> void:
	super()
	_on_current_progression_changed()


func _get_new_sentence() -> void:
	if audio_player.playing:
		await audio_player.finished
	
	await _next_sentence()
	await _start_ants()


func _next_sentence() -> void:
	var nodes: Array[Node] = []
	nodes.append_array(sentence_container.get_children())
	nodes.append_array(words.get_children())
	for node: Node in nodes:
		node.queue_free()
	
	for ant: Ant in ants.get_children():
		ant.walk()
		var tween: Tween = create_tween()
		tween.tween_property(ant, "global_position", ants_despawn.global_position, 1.0)
		await tween.finished
		ant.queue_free()
		await ant.tree_exited
	
	await get_tree().process_frame
	
	current_sentence = stimuli.pop_front()
	
	var current_words: PackedStringArray = (current_sentence.Sentence as String).replace("'", " ' ").replace("-", " - ").split(" ")
	
	var inds_to_remove: Array[int] = []
	for index: int in range(1, current_words.size()):
		var word: String = current_words[index]
		if word in ["?", "!", ":"]:
			current_words[index - 1] += " " + word
			inds_to_remove.append(index)
		
		if word in ["'", "-", "¿", "¡"]:
			current_words[index - 1] += word
			inds_to_remove.append(index)
	
	inds_to_remove.reverse()
	for index: int in inds_to_remove:
		current_words.remove_at(index)
	
	var number_of_blanks: int = maxi(2, mini(difficulty, current_words.size()))
	var blanks: Array = range(current_words.size())
	blanks.shuffle()
	while blanks.size() > number_of_blanks:
		blanks.pop_back()
	
	answers = []
	answered = []
	for index: int in range(current_words.size()):
		var current_word: String = current_words[index]
		if index in blanks:
			var blank: Blank = BLANK_SCENE.instantiate()
			blank.stimulus = current_word
			sentence_container.add_child(blank)
			
			var ant: Node2D = ANT_SCENE.instantiate()
			ants.add_child(ant)
			ant.global_position = ants_spawn.global_position
			
			var word: Word = WORD_SCENE.instantiate()
			words.add_child(word)
			
			word.stimulus = current_word
			word.current_anchor = ant
			@warning_ignore("UNSAFE_METHOD_ACCESS")
			word.current_anchor.set_monitorable(false)
			
			answered.append(false)
			answers.append(false)
			
			word.answer.connect(_on_word_answer.bind(word))
			word.no_answer.connect(_on_word_no_answer.bind(word))
		else:
			var label: Label = Label.new()
			sentence_container.add_child(label)
			
			label.text = current_word + " "
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.label_settings = LABEL_SETTINGS


func _start_ants() -> void:
	var total_ants: int = ants.get_child_count()

	# Animate each ant, one after another
	for ant_index: int in range(total_ants):
		var ant: Ant = ants.get_child(ant_index)

		# Start walking animation or logic
		ant.walk()

		# Create a tween to move the ant from start to end point
		var tween: Tween = create_tween()

		# Compute interpolation factor (0.0 to 1.0) based on position in the list
		var position_ratio: float = float(ant_index) / float(total_ants - 1)

		# Interpolate position from ants_start to ants_end using the ratio
		var start_position: Vector2 = ants_start.global_position
		var end_position: Vector2 = ants_end.global_position
		var target_position: Vector2 = lerp(start_position, end_position, position_ratio)

		# Animate the movement over 1 second
		tween.tween_property(ant, "global_position", target_position, 1.0)
		await tween.finished

		# Switch to idle state once movement is complete
		ant.idle()

	# Reactivate all words once ants have reached their positions
	for word: Word in words.get_children():
		word.disabled = false


func _on_current_progression_changed() -> void:
	if stimuli.size() != 0:
		await _get_new_sentence()
	else:
		_win()


func _on_word_answer(stimulus: String, expected_stimulus: String, word: TextureButton) -> void:
	_log_new_response({"Word": stimulus}, {"Word": expected_stimulus})
	
	answers[word.get_index()] = stimulus == expected_stimulus
	answered[word.get_index()] = true
	
	var all_answered: bool = true
	for answer: bool in answered:
		if not answer:
			all_answered = false
			break
	
	if all_answered:
		var is_right: bool = true
		for answer: bool in answers:
			if not answer:
				is_right = false
				break
		
		for word_i: Word in words.get_children():
			@warning_ignore("unsafe_method_access")
			word_i.current_anchor.set_monitorable(true)
			word_i.disabled = true
		
		if is_right:
			for index: int in range(words.get_child_count() - 1):
				(words.get_child(index) as Word).right()
			await (words.get_child(words.get_child_count() - 1) as Word).right()
			
			current_progression += 1
		else:
			for index: int in range(words.get_child_count() - 1):
				@warning_ignore("UNSAFE_METHOD_ACCESS")
				words.get_child(index).wrong()
			@warning_ignore("UNSAFE_METHOD_ACCESS")
			await words.get_child(words.get_child_count() - 1).wrong()
			
			current_lives -= 1
			
			for index: int in range(ants.get_child_count()):
				answered[index] = false
				@warning_ignore("UNSAFE_PROPERTY_ACCESS")
				words.get_child(index).current_anchor = ants.get_child(index)
				@warning_ignore("UNSAFE_METHOD_ACCESS")
				ants.get_child(index).set_monitorable(false)
		
			for word_i: Word in words.get_children():
				word_i.disabled = false


func _on_word_no_answer(word: TextureButton) -> void:
	answered[word.get_index()] = false
