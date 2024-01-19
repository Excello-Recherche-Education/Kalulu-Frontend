extends Minigame

@export var difficulty: = 3
@export var lesson_nb: = 4

@onready var sentence: = %Sentence
@onready var ants_spawn: = %AntsSpawn
@onready var ants_start: = %AntsStart
@onready var ants_end: = %AntsEnd
@onready var ants: = %Ants
@onready var words: = %Words

const blank_class: = preload("res://sources/minigames/ants/blank.tscn")
const ant_class: = preload("res://sources/minigames/ants/ant.tscn")
const word_class: = preload("res://sources/minigames/ants/word.tscn")

var current_sentence: String
var answersed: = []
var answers: = []


func _find_stimuli_and_distractions() -> void:
	#var sentences_list: = Database.get_sentences_for_lesson(lesson_nb)
	var sentences_list: = [
		{Sentence = "Il est beau le bateau"},
		{Sentence = "Il est beau le lavabo"},
		{Sentence = "Il est laid le bidet"},
	]
	sentences_list.shuffle()
	stimuli = []
	distractions = []
	for i in max_progression:
		var stimulus: String = sentences_list[i].Sentence
		stimuli.append(stimulus)


func _start() -> void:
	_get_new_sentence()


func _get_new_sentence() -> void:
	if audio_player.playing:
		await audio_player.finished
	
	await _next_sentence()
	await _play_current_sentence()
	await _start_ants()


func _next_sentence() -> void:
	var nodes: = []
	nodes.append_array(sentence.get_children())
	nodes.append_array(ants.get_children())
	nodes.append_array(words.get_children())
	for node in nodes:
		node.queue_free()
	
	await get_tree().process_frame
	
	current_sentence = stimuli.pop_front()
	var current_words: = current_sentence.split(" ")
	
	var number_of_blanks: int = maxi(2, mini(difficulty, current_words.size()))
	var blanks: = range(current_words.size())
	blanks.shuffle()
	while blanks.size() > number_of_blanks:
		blanks.pop_back()
	
	answers = []
	answersed = []
	for i in range(current_words.size()):
		if i in blanks:
			var blank: = blank_class.instantiate()
			blank.stimulus = current_words[i]
			sentence.add_child(blank)
			
			var ant: = ant_class.instantiate()
			ants.add_child(ant)
			ant.global_position = ants_spawn.global_position
			
			var word: = word_class.instantiate()
			words.add_child(word)
			
			word.stimulus = current_words[i]
			word.current_anchor = ant
			
			answersed.append(false)
			answers.append(false)
			
			word.answer.connect(_on_word_answer.bind(word))
			word.no_answer.connect(_on_word_no_answer.bind(word))
		else:
			var label: = Label.new()
			sentence.add_child(label)
			
			label.text = current_words[i] + " "
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.set("theme_override_font_sizes/font_size", 72)


func _play_current_sentence() -> void:
	#audio_player.stream = Database.get_audio_stream_for_sentence(current_sentence)
	audio_player.play()
	if audio_player.playing:
		await audio_player.finished


func _start_ants() -> void:
	var number_of_ants: = ants.get_child_count()
	for i in range(number_of_ants):
		var ant: = ants.get_child(i)
		var tween: = create_tween()
		var k: = float(i) / float(number_of_ants - 1)
		tween.tween_property(ant, "global_position", k * ants_start.global_position + (1.0 - k) * ants_end.global_position, 2.0)
		await tween.finished
	
	for word in words.get_children():
		word.disabled = false


func _on_current_progression_changed() -> void:
	if stimuli.size() != 0:
		await _get_new_sentence()
	else:
		_win()


func _on_word_answer(answer: bool, word: TextureButton) -> void:
	answers[word.get_index()] = answer
	answersed[word.get_index()] = true
	
	var all_answered: = true
	for a in answersed:
		if not a:
			all_answered = false
			break
	
	if all_answered:
		var is_right: = true
		for a in answers:
			if not a:
				is_right = false
				break
		
		if is_right:
			current_progression += 1
		else:
			current_lives -= 1
			
			for i in range(ants.get_child_count()):
				answersed[i] = false
				words.get_child(i).current_anchor = ants.get_child(i)


func _on_word_no_answer(word: TextureButton) -> void:
	answersed[word.get_index()] = false
