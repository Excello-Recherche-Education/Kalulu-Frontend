@tool
extends Minigame

# Namespace
const Ant: = preload("res://sources/minigames/ants/ant.gd")

const blank_class: = preload("res://sources/minigames/ants/blank.tscn")
const ant_class: = preload("res://sources/minigames/ants/ant.tscn")
const word_class: = preload("res://sources/minigames/ants/word.tscn")

const label_settings: = preload("res://resources/themes/minigames_label_settings.tres")

@onready var sentence: HFlowContainer = %Sentence
@onready var ants_spawn: Node2D = %AntsSpawn
@onready var ants_start: Node2D = %AntsStart
@onready var ants_end: Node2D = %AntsEnd
@onready var ants_despawn: Node2D = %AntsDespawn
@onready var ants: Node2D = %Ants
@onready var words: Node2D = %Words

var current_sentence: Dictionary
var answered: = []
var answers: = []


func _find_stimuli_and_distractions() -> void:
	var sentences_list: Array = Database.get_sentences_for_lesson(lesson_nb, difficulty + 2, 50)
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
	if not previous_lesson_sentences:
		if current_lesson_sentences.size() >= max_progression:
			for i in max_progression:
				stimuli.append(current_lesson_sentences[i])
		else:
			while stimuli.size() < max_progression:
				stimuli.append(current_lesson_sentences.pick_random())
	else:
		if current_lesson_sentences:
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
	_on_current_progression_changed() 


func _get_new_sentence() -> void:
	if audio_player.playing:
		await audio_player.finished
	
	await _next_sentence()
	await _play_current_sentence()
	await _start_ants()


func _next_sentence() -> void:
	var nodes: = []
	nodes.append_array(sentence.get_children())
	nodes.append_array(words.get_children())
	for node in nodes:
		node.queue_free()
		
	for i in ants.get_child_count():
		var ant: Ant = ants.get_child(i)
		ant.walk()
		var tween: = create_tween()
		tween.tween_property(ant, "global_position", ants_despawn.global_position, 1.0)
		await tween.finished
		ant.queue_free()
	
	await get_tree().process_frame
	
	current_sentence = stimuli.pop_front()
	
	var current_words: PackedStringArray = current_sentence.Sentence.replace("'", " ' ").replace("-", " - ").split(" ")
	
	var inds_to_remove: = []
	for i in range(1, current_words.size()):
		var word: = current_words[i]
		if word in ["?", "!", ":"]:
			current_words[i - 1] += " " + word
			inds_to_remove.append(i)
		
		if word in ["'", "-", "¿", "¡"]:
			current_words[i - 1] += word
			inds_to_remove.append(i)
	
	inds_to_remove.reverse()
	for ind in inds_to_remove:
		current_words.remove_at(ind)
	
	var number_of_blanks: int = maxi(2, mini(difficulty, current_words.size()))
	var blanks: = range(current_words.size())
	blanks.shuffle()
	while blanks.size() > number_of_blanks:
		blanks.pop_back()
	
	answers = []
	answered = []
	for i in range(current_words.size()):
		var current_word: = current_words[i]
		if i in blanks:
			var blank: = blank_class.instantiate()
			blank.stimulus = current_word
			sentence.add_child(blank)
			
			var ant: = ant_class.instantiate()
			ants.add_child(ant)
			ant.global_position = ants_spawn.global_position
			
			var word: = word_class.instantiate()
			words.add_child(word)
			
			word.stimulus = current_word
			word.current_anchor = ant
			word.current_anchor.set_monitorable(false)
			
			answered.append(false)
			answers.append(false)
			
			word.answer.connect(_on_word_answer.bind(word))
			word.no_answer.connect(_on_word_no_answer.bind(word))
		else:
			var label: = Label.new()
			sentence.add_child(label)
			
			label.text = current_word + " "
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.label_settings = label_settings


func _play_current_sentence() -> void:
	#audio_player.stream = Database.get_audio_stream_for_sentence(current_sentence)
	#audio_player.play()
	if audio_player.playing:
		await audio_player.finished


func _start_ants() -> void:
	var number_of_ants: = ants.get_child_count()
	for i in range(number_of_ants):
		var ant: Ant = ants.get_child(i)
		
		ant.walk()
		
		var tween: = create_tween()
		var k: = float(i) / float(number_of_ants - 1)
		tween.tween_property(ant, "global_position", k * ants_start.global_position + (1.0 - k) * ants_end.global_position, 1.0)
		await tween.finished
		
		ant.idle()
	
	for word in words.get_children():
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
	
	var all_answered: = true
	for a in answered:
		if not a:
			all_answered = false
			break
	
	if all_answered:
		var is_right: = true
		for a in answers:
			if not a:
				is_right = false
				break
		
		for word_i in words.get_children():
			word_i.current_anchor.set_monitorable(true)
			word_i.disabled = true
		
		if is_right:
			for i in range(words.get_child_count() - 1):
				words.get_child(i).right()
			await words.get_child(words.get_child_count() - 1).right()
			
			current_progression += 1
		else:
			for i in range(words.get_child_count() - 1):
				words.get_child(i).wrong()
			await words.get_child(words.get_child_count() - 1).wrong()
			
			current_lives -= 1
			
			for i in range(ants.get_child_count()):
				answered[i] = false
				words.get_child(i).current_anchor = ants.get_child(i)
				ants.get_child(i).set_monitorable(false)
		
			for word_i in words.get_children():
				word_i.disabled = false


func _on_word_no_answer(word: TextureButton) -> void:
	answered[word.get_index()] = false
