@tool
extends Minigame

const Monkey: = preload("res://sources/minigames/monkeys/monkey.gd")

const difficulty_settings: = {
	0 : {"distractors_count": 1},
	1 : {"distractors_count": 2},
	2 : {"distractors_count": 3},
	3 : {"distractors_count": 4},
	4 : {"distractors_count": 5},
}

@export var difficulty: = 1
@export var lesson_nb: = 4
@export var throw_to_king_duration: = 1.2
@export var throw_to_monkey_duration: = 0.4

@onready var monkeys_node: = $GameRoot/Monkeys
@onready var possible_positions_parent: = $GameRoot/PalmTreeMonkeys
@onready var king: = $GameRoot/PlamTreeKing/KingMonkey
@onready var word_label: = $GameRoot/TextPlank/MarginContainer/Label
@onready var parabola_summit: = $GameRoot/ParabolaSummit
@onready var text_plank: = $GameRoot/TextPlank

var monkeys: Array[Monkey] = []
var _current_letter: = 0: set = _set_current_letter


# Find and set the parameters of the minigame, like the number of lives or the victory conditions.
func _setup_minigame() -> void:
	super._setup_minigame()
	
	var max_difficulty: = 0
	for d in difficulty_settings.keys():
		if d > max_difficulty:
			max_difficulty = d
	
	if difficulty > max_difficulty:
		difficulty = max_difficulty
	
	var settings: Dictionary = difficulty_settings[difficulty]
	
	var possible_positions: = possible_positions_parent.get_children()
	for i in settings.distractors_count + 1:
		var monkey: Monkey = Monkey.instantiate()
		monkeys_node.add_child(monkey)
		monkey.global_position = possible_positions[i].global_position
		monkey.dragged_into.connect(_on_coconut_drag_end)
		monkeys.append(monkey)
		monkey.pressed.connect(_on_monkey_pressed.bind(monkey))
		monkey.dragged_into_self.connect(_on_monkey_pressed.bind(monkey))
	
	# Will set up first word and monkeys
	current_progression = 0
	
	monkeys_node.set_drag_forwarding(Callable(), _monkeys_can_drop_data, _monkeys_drop_data)



func _on_current_progression_changed() -> void:
	word_label.text = "_".repeat(stimuli[current_progression].Word.length())
	await _set_current_letter(0)


func _set_current_letter(p_current_letter: int) -> void:
	_current_letter = p_current_letter
	if _current_letter >= stimuli[current_progression].GPs.size():
		var coroutine: = Coroutine.new()
		for monkey in monkeys:
			coroutine.add_future(monkey.talk)
		audio_player.stream = Database.get_audio_stream_for_word(stimuli[current_progression].Word)
		audio_player.play()
		if audio_player.playing:
			coroutine.add_future(audio_player.finished)
		await coroutine.join()
		await set_current_progression(current_progression + 1)
		return
	
	var ind_good: = randi_range(0, monkeys.size() - 1)
	var grapheme_distractions: Array = distractions[current_progression][_current_letter]
	grapheme_distractions.shuffle()
	for i in monkeys.size():
		var monkey: = monkeys[i]
		if i == ind_good:
			monkey.stimulus = stimuli[current_progression].GPs[_current_letter]
		elif i < ind_good:
			monkey.stimulus = grapheme_distractions[min(i, grapheme_distractions.size() - 1)]
		else:
			monkey.stimulus = grapheme_distractions[min(i - 1, grapheme_distractions.size() - 1)]
		monkey.stunned = false



# Find the stimuli and distractions of the minigame.
func _find_stimuli_and_distractions() -> void:
	var words_list: = Database.get_words_for_lesson(lesson_nb)
	words_list.shuffle()
	stimuli = []
	distractions = []
	for i in max_progression:
		var word = words_list[i].Word
		var GPs: = Database.get_GP_from_word(word)
		stimuli.append({
			Word = word,
			GPs = GPs,
		})
		var grapheme_distractions: = []
		for GP in GPs:
			grapheme_distractions.append(Database.get_distractors_for_grapheme(GP.Grapheme, lesson_nb))
		distractions.append(grapheme_distractions)


func _start() -> void:
	await say_word_and_grab_coconuts()
	lock(false)


func say_word_and_grab_coconuts() -> void:
	if current_progression >= stimuli.size():
		return
	
	var coroutine: = Coroutine.new()
	audio_player.stream = Database.get_audio_stream_for_word(stimuli[current_progression].Word)
	audio_player.play()
	if audio_player.playing:
		coroutine.add_future(audio_player.finished)
	for monkey in monkeys:
		coroutine.add_future(monkey.grab)
	await coroutine.join()


func _monkeys_drop_data(at_position: Vector2, data) -> void:
	_on_coconut_drag_end(at_position - data.start_position, data.monkey)


func _monkeys_can_drop_data(_at_position: Vector2, _data) -> bool:
	return true


func _on_coconut_drag_end(vector: Vector2, monkey: Monkey) -> void:
	if vector.x < 0:
		monkey_throw_to_king(monkey)


func monkey_throw_to_king(monkey: Monkey) -> void:
	lock()
	await monkey.start_throw()
	monkey.finish_throw()
	var coconut: = monkey.coconut.duplicate()
	game_root.add_child(coconut)
	coconut.text = monkey.coconut.text
	coconut.global_transform = monkey.coconut.global_transform
	var tween: = create_tween()
	tween.set_parallel()
	tween.tween_property(coconut, "global_position:x", (coconut.global_position.x + king.catch_position.global_position.x) / 2, throw_to_king_duration / 2).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(coconut, "global_position:y", parabola_summit.global_position.y, throw_to_king_duration / 2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	tween = create_tween()
	tween.set_parallel()
	tween.tween_property(coconut, "global_position:x", king.catch_position.global_position.x, throw_to_king_duration / 2).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(coconut, "global_position:y", king.catch_position.global_position.y, throw_to_king_duration / 2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	await king.catch(coconut)
	
	var coroutine: = Coroutine.new()
	coroutine.add_future(king.read)
	coroutine.add_future(monkey_talk.bind(monkey))
	await coroutine.join()
	
	if monkey.stimulus == stimuli[current_progression].GPs[_current_letter]:
		await king.start_right()
		king.finish_right()
		tween = create_tween()
		coconut.show()
		coconut.global_transform = king.coconut.global_transform
		tween.tween_property(coconut, "global_position:y", text_plank.global_position.y, throw_to_monkey_duration).set_trans(Tween.TRANS_LINEAR)
		await tween.finished
		coconut.queue_free()
		word_label.text = ""
		for i in _current_letter + 1:
			word_label.text += stimuli[current_progression].GPs[i].Grapheme
		word_label.text += "_".repeat(stimuli[current_progression].Word.length() - word_label.text.length())
		await _set_current_letter(_current_letter + 1)
		await say_word_and_grab_coconuts()
	else:
		await king.start_wrong()
		king.finish_wrong()
		coconut.show()
		coconut.global_transform = king.coconut.global_transform
		tween = create_tween()
		tween.tween_property(coconut, "global_position", monkey.hit_position.global_position, throw_to_monkey_duration).set_trans(Tween.TRANS_LINEAR)
		await tween.finished
		await monkey.hit(coconut)
	lock(false)


func lock(p_value: = true) -> void:
	for monkey in monkeys:
		monkey.locked = p_value


func _on_monkey_pressed(monkey: Monkey) -> void:
	lock()
	monkey_talk(monkey)
	lock(false)


func monkey_talk(monkey: Monkey) -> void:
	var coroutine: = Coroutine.new()
	coroutine.add_future(monkey.talk)
	audio_player.stream = Database.get_audio_stream_for_phoneme(monkey.stimulus.Phoneme)
	audio_player.play()
	if audio_player.playing:
		coroutine.add_future(audio_player.finished)
	await coroutine.join()
