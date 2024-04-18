@tool
extends WordsMinigame

const monkey_scene: = preload("res://sources/minigames/monkeys/monkey.tscn")
const audio_streams: = [
	preload("res://assets/minigames/monkeys/audio/monkey_sendcoco.mp3"),
	preload("res://assets/minigames/monkeys/audio/monkey_sendcoco_right.mp3"),
	preload("res://assets/minigames/monkeys/audio/monkey_sendcoco_wrong.mp3"),
]

enum Audio {
	SendToKing,
	SendToPlank,
	SendToMonkey,
}


class DifficultySettings:
	var distractors_count: = 1
	
	func _init(p_distractors_count: int) -> void:
		distractors_count = p_distractors_count


var difficulty_settings: Array[DifficultySettings] = [
	DifficultySettings.new(1),
	DifficultySettings.new(2),
	DifficultySettings.new(3),
	DifficultySettings.new(4),
	DifficultySettings.new(5)
]


@export var time_between_words: float = 3.
@export var throw_to_king_duration: = 1.2
@export var throw_to_monkey_duration: = 0.4
@export var throw_to_plank_duration: = 0.8

@onready var monkeys_node: Control = $GameRoot/Monkeys
@onready var possible_positions_parent: TextureRect = $GameRoot/PalmTreeMonkeys
@onready var king: KingMonkey = $GameRoot/PlamTreeKing/KingMonkey
@onready var word_label: RichTextLabel = $GameRoot/TextPlank/MarginContainer/Label
@onready var parabola_summit: Control = $GameRoot/ParabolaSummit
@onready var text_plank: TextureRect = $GameRoot/TextPlank

var monkeys: Array[Monkey] = []
var is_locked: bool = true: 
	set(value):
		is_locked = value
		for monkey in monkeys:
			monkey.locked = value


# Find and set the parameters of the minigame, like the number of lives or the victory conditions.
func _setup_minigame() -> void:
	super()
	
	var settings: DifficultySettings = difficulty_settings[difficulty]
	
	var possible_positions: = possible_positions_parent.get_children()
	for i in settings.distractors_count + 1:
		var monkey: Monkey = monkey_scene.instantiate()
		monkeys_node.add_child(monkey)
		monkeys.append(monkey)
		
		monkey.global_position = possible_positions[i].global_position
		
		monkey.pressed.connect(_on_monkey_pressed.bind(monkey))
		monkey.dragged_into_self.connect(_on_monkey_pressed.bind(monkey))
	
	monkeys_node.set_drag_forwarding(
		func(at_position: Vector2):
			return null,
		func(_at_position: Vector2, _data): 
			return true,
		func(at_position: Vector2, data):
			if (at_position - data.start_position).x < 0:
				_on_coconut_thrown(data.monkey)
	)
	
	_reset_plank_label()


func _reset_plank_label() -> void:
	word_label.text = "_".repeat(_get_current_stimulus().Word.length())


func _play_monkey_stimulus(monkey: Monkey) -> void:
	var coroutine: = Coroutine.new()
	
	coroutine.add_future(monkey.talk)
	
	audio_player.play_phoneme(monkey.stimulus.Phoneme)
	if audio_player.playing:
		coroutine.add_future(audio_player.finished)
	
	await coroutine.join_all()


func _get_coconut_from_monkey_to_king(monkey: Monkey) -> Node2D:
	await monkey.play("start_throw")
	monkey.play("finish_throw")
	
	audio_player.stream = audio_streams[Audio.SendToKing]
	audio_player.play()
	
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
	return coconut

#region Connections

func _on_monkey_pressed(monkey: Monkey) -> void:
	is_locked = true
	await _play_monkey_stimulus(monkey)
	is_locked = false


func _on_coconut_thrown(monkey: Monkey) -> void:
	# Log the answer
	_log_new_response(monkey.stimulus, stimuli[current_progression])
	
	is_locked = true
	var coconut: = await _get_coconut_from_monkey_to_king(monkey)
	
	# All monkeys talk but the sound is from a specific monkey
	var coroutine: = Coroutine.new()
	coroutine.add_future(king.play.bind("read"))
	coroutine.add_future(_play_monkey_stimulus.bind(monkey))
	await coroutine.join_all()
	
	if _is_GP_right(monkey.stimulus):
		
		await king.play("start_right")
	
		audio_player.stream = audio_streams[Audio.SendToPlank]
		audio_player.play()
		
		king.play("finish_right")
		var tween: = create_tween()
		coconut.show()
		coconut.global_transform = king.coconut.global_transform
		tween.tween_property(coconut, "global_position:y", text_plank.global_position.y, throw_to_plank_duration).set_trans(Tween.TRANS_LINEAR)
		await tween.finished
		coconut.queue_free()
		
		word_label.text = ""
		for i in current_word_progression +1:
			word_label.text += stimuli[current_progression].GPs[i].Grapheme
		word_label.text += "_".repeat(stimuli[current_progression].Word.length() - word_label.text.length())
	
		current_word_progression += 1
	else:
		await king.play("start_wrong")
	
		audio_player.stream = audio_streams[Audio.SendToMonkey]
		audio_player.play()
		
		king.play("finish_wrong")
		coconut.show()
		coconut.global_transform = king.coconut.global_transform
		var tween: = create_tween()
		tween.tween_property(coconut, "global_position", monkey.hit_position.global_position, throw_to_monkey_duration).set_trans(Tween.TRANS_LINEAR)
		await tween.finished
		await monkey.hit(coconut)
		current_lives -= 1
		coconut.queue_free()
	is_locked = false


func _on_current_word_progression_changed() -> void:
	super()
	
	var ind_good: = randi_range(0, monkeys.size() - 1)
	for i in monkeys.size():
		var monkey: = monkeys[i]
		if i == ind_good:
			monkey.stimulus = _get_GP()
		else:
			monkey.stimulus = _get_distractor()
		monkey.stunned = false
	
	var coroutine: = Coroutine.new()
	if audio_player.playing:
		coroutine.add_future(audio_player.finished)
	for monkey in monkeys:
		coroutine.add_future(monkey.play.bind("grab"))
	await coroutine.join_all()
	
	is_locked = false


func _on_current_progression_changed() -> void:
	# Replay the stimulus
	await get_tree().create_timer(time_between_words/2).timeout
	var coroutine: = Coroutine.new()
	for monkey in monkeys:
		coroutine.add_future(monkey.talk)
	audio_player.play_word(_get_previous_stimulus().Word)
	if audio_player.playing:
		coroutine.add_future(audio_player.finished)
	await coroutine.join_all()
	await get_tree().create_timer(time_between_words/2).timeout
	
	# Starts a new round
	super()
	
	_reset_plank_label()

#endregion
