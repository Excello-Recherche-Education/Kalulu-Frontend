extends Minigame

const BLANK_SCENE: PackedScene = preload("res://sources/minigames/ants/blank.tscn")
const ANT_SCENE: PackedScene = preload("res://sources/minigames/ants/ant.tscn")
const WORD_SCENE: PackedScene = preload("res://sources/minigames/ants/word.tscn")
const LABEL_SETTINGS: LabelSettings = preload("res://resources/themes/minigames_label_settings_ants.tres")
const LINE_HEIGHT: float = 159.0 # Matches sentence_text_box.png and blank row height
const SPAWN_SPACING: float = 600.0
const REFERENCE_DURATION: float = 1.3985 # Ants travel duration

var current_sentence: Dictionary = {}
var answer_input_done: Array[bool] = []
var answers: Dictionary[String, String] = {} # Expected, current

@onready var sentence_container: HFlowContainer = %Sentence
@onready var sentence_background: HFlowContainer = %SentenceBackground
@onready var ants_spawn: Node2D = %AntsSpawn
@onready var ants_start: Node2D = %AntsStart
@onready var ants_end: Node2D = %AntsEnd
@onready var ants_despawn: Node2D = %AntsDespawn
@onready var ants: Node2D = %Ants
@onready var words: Node2D = %Words


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
			for index: int in range(max_progression):
				stimuli.append(current_lesson_sentences[index])
		else:
			while stimuli.size() < max_progression:
				stimuli.append(current_lesson_sentences.pick_random())
	else:
		if current_lesson_sentences:
			# If there are more stimuli in current lesson than needed
			if current_lesson_sentences.size() >= current_lesson_stimuli_number:
				for index: int in range(current_lesson_stimuli_number):
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
			for index: int in range(spaces_left):
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
	Log.trace("AntsMinigame: stimuli = " + str(stimuli))


func _start() -> void:
	super()
	fireworks.set_colors([Color("#ffd366"), Color("#ffbf94"), Color("#f5a8c8")])
	_on_current_progression_changed()
	sentence_background.show()


func _get_new_sentence() -> void:
	if audio_player.playing:
		await audio_player.finished
	
	await _next_sentence()
	shuffle_children(ants)
	await _start_ants()


func _next_sentence() -> void:
	Log.trace("Ants Minigame: Next sentence")
	for word: Word in words.get_children():
		word.set_process(false)
	var nodes: Array[Node] = []
	for ant: Ant in ants.get_children():
		ant.walk()
		var tween: Tween = create_tween()
		tween.tween_property(ant, "global_position", ants_despawn.global_position, 1.0)
		await tween.finished
		ant.queue_free()
		await ant.tree_exited
	
	nodes.append_array(sentence_container.get_children())
	nodes.append_array(words.get_children())
	for node: Node in nodes:
		node.queue_free()
	
	await get_tree().process_frame
	
	current_sentence = stimuli.pop_front()
	Log.info("Ants Minigame: Selected sentence = %s" % current_sentence)
	
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

	if not current_words.is_empty() and current_words[-1].ends_with(".") and current_words[-1].length() > 1:
		current_words[-1] = current_words[-1].left(-1)
		current_words.append(".")
	
	var non_blankable_tokens: PackedStringArray = ["."]
	var number_of_blanks: int = maxi(2, mini(difficulty, current_words.size()))
	var blanks: Array[int] = []
	for index: int in range(current_words.size()):
		if current_words[index] not in non_blankable_tokens:
			blanks.append(index)
	blanks.shuffle()
	number_of_blanks = mini(number_of_blanks, blanks.size())
	while blanks.size() > number_of_blanks:
		blanks.pop_back()
	
	answers.clear()
	answer_input_done = []
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
			
			answer_input_done.append(false)
			answers[current_word] = ""
			
			word.answer.connect(_on_word_answer.bind(word))
			word.no_answer.connect(_on_word_no_answer.bind(word))
		else:
			var label: Label = Label.new()
			sentence_container.add_child(label)

			if current_word == ".":
				label.text = current_word + "  "
			else:
				label.text = " " + current_word + "  "
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.label_settings = LABEL_SETTINGS
			label.custom_minimum_size.y = LINE_HEIGHT
	
	await setup_sentence_background()


func setup_sentence_background() -> void:
	await get_tree().process_frame
	var number_of_lines: int = sentence_container.get_line_count()
	var children: Array[Node] = sentence_background.get_children()
	if children.is_empty():
		Log.error("Ants Minigame: sentence_background has no child, but it should always at least keep 1")
		return
	if number_of_lines == children.size():
		return
	while number_of_lines < sentence_background.get_children().size():
		var child: Node = sentence_background.get_child(-1) # Get last child
		child.queue_free()
		await get_tree().process_frame
	if number_of_lines == children.size():
		return
	var template: Node = children[0]
	while number_of_lines > sentence_background.get_children().size():
		var new_child: Node = template.duplicate()
		sentence_background.add_child(new_child)
		await get_tree().process_frame


func _start_ants() -> void:
	var total_ants: int = ants.get_child_count()
	if total_ants == 0:
		return

	var spawn_position: Vector2 = ants_spawn.global_position
	var start_position: Vector2 = ants_start.global_position
	var end_position: Vector2 = ants_end.global_position
	var denominator: float = maxf(1.0, float(total_ants - 1)) # Avoid division by zero when there is only one ant

	# Spawn the ants in a line off-screen in the same order as their on-screen targets:
	# ant 0 heads to the leftmost target, so it must also be leftmost in the spawn line.
	# This keeps their relative order constant while they all move right, preventing crossings.
	for ant_index: int in range(total_ants):
		var ant: Ant = ants.get_child(ant_index)
		var offset: float = -float(total_ants - 1 - ant_index) * SPAWN_SPACING
		ant.global_position = spawn_position + Vector2(offset, 0.0)

	# Constant speed derived from ant 0's travel, so the leftmost ant stops first
	# and each subsequent ant stops shortly after as it reaches its own target.
	var ant0: Ant = ants.get_child(0)
	var reference_distance: float = maxf(1.0, ant0.global_position.distance_to(start_position))
	var speed: float = reference_distance / REFERENCE_DURATION

	var tweens: Array[Tween] = []
	for ant_index: int in range(total_ants):
		var ant: Ant = ants.get_child(ant_index)
		ant.walk()

		var position_ratio: float = float(ant_index) / denominator
		var target_position: Vector2 = lerp(start_position, end_position, position_ratio)
		var duration: float = ant.global_position.distance_to(target_position) / speed

		var tween: Tween = create_tween()
		tween.tween_property(ant, "global_position", target_position, duration)
		tween.tween_callback(ant.idle)
		tweens.append(tween)

	# Wait for the last ant (longest travel) to reach its position.
	await tweens[tweens.size() - 1].finished

	# Reactivate all words once ants have reached their positions
	for word: Word in words.get_children():
		word.set_disabled(false)


func shuffle_children(parent: Node) -> void:
	var children: Array[Node] = parent.get_children()
	children.shuffle()
	for child: Node in children:
		child.get_parent().remove_child(child)
	for child: Node in children:
		parent.add_child(child)


func _on_current_progression_changed() -> void:
	if stimuli.size() != 0:
		await _get_new_sentence()
	else:
		_win()


func _on_word_answer(stimulus: String, expected_stimulus: String, word: Button) -> void:
	_log_new_response({"Word": stimulus}, {"Word": expected_stimulus})
	
	answers[expected_stimulus] = stimulus
	answer_input_done[word.get_index()] = true
	
	var all_answered: bool = true
	for answer: bool in answer_input_done:
		if not answer:
			all_answered = false
			break
	
	if all_answered:
		var is_right: bool = true
		var word_id: int = -1
		for key: String in answers.keys():
			word_id = Database.get_word_id_from_text(key)
			if key != answers[key]:
				is_right = false
				if word_id != -1:
					_update_remediation_word_score(word_id, -1)
				word_id = Database.get_word_id_from_text(answers[key])
				if word_id != -1:
					_update_remediation_word_score(word_id, -1)
			else:
				if word_id != -1:
					_update_remediation_word_score(word_id, 1)
		
		for word_i: Word in words.get_children():
			@warning_ignore("unsafe_method_access")
			word_i.current_anchor.set_monitorable(true)
			word_i.set_disabled(true)
		
		if is_right:
			for ant: Ant in ants.get_children():
				ant.success()
			for index: int in range(words.get_child_count() - 1):
				(words.get_child(index) as Word).right()
			await (words.get_child(words.get_child_count() - 1) as Word).right()
			
			current_progression += 1
		else:
			for ant: Ant in ants.get_children():
				ant.defeat()
			for index: int in range(words.get_child_count() - 1):
				(words.get_child(index) as Word).wrong()
			await (words.get_child(words.get_child_count() - 1) as Word).wrong()
			
			current_lives -= 1
			
			for index: int in range(ants.get_child_count()):
				answer_input_done[index] = false
				@warning_ignore("UNSAFE_PROPERTY_ACCESS")
				words.get_child(index).current_anchor = ants.get_child(index)
				@warning_ignore("UNSAFE_METHOD_ACCESS")
				ants.get_child(index).set_monitorable(false)
		
			for word_i: Word in words.get_children():
				word_i.set_disabled(false)


func _on_word_no_answer(word: Button) -> void:
	answer_input_done[word.get_index()] = false
