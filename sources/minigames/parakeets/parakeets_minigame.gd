extends Minigame

enum State {
	LOCKED,
	IDLE,
	SELECTED_1,
	SELECTED_2,
}
enum Audio {
	FLY,
	HAPPY,
	TURN,
	WIN,
}

const AUDIO_STREAMS: Array[AudioStreamMP3] = [
	preload("res://assets/minigames/parakeets/audio/parakeet_fly.mp3"),
	preload("res://assets/minigames/parakeets/audio/parakeet_happy_short.mp3"),
	preload("res://assets/minigames/parakeets/audio/parakeet_turn_over.mp3"),
	preload("res://assets/minigames/parakeets/audio/parakeet_win.mp3"),
]
const DIFFICULTY_SETTINGS: Dictionary[int, Dictionary] = {
	0: {"pairs_count": 2},
	1: {"pairs_count": 3},
	2: {"pairs_count": 4},
	3: {"pairs_count": 5},
	4: {"pairs_count": 6},
}
const PARAKEET_SCENE: PackedScene = preload("res://sources/minigames/parakeets/parakeet.tscn")

@export var fly_duration: float = 3.0

var parakeets: Array[Parakeet] = []
var selected: Array[Parakeet] = []
var state: State = State.LOCKED

@onready var branches: Node2D = $GameRoot/TreeTrunk/Branches
@onready var possible_start_positions_parent: Control = $GameRoot/FlyFrom
@onready var parakeets_node: Node = $GameRoot/Parakeets
@onready var nest_position_1: Node2D = $GameRoot/TreeTrunk/Branches/TreeBranch5/Nest/Position1
@onready var nest_position_2: Node2D = $GameRoot/TreeTrunk/Branches/TreeBranch5/Nest/Position2
@onready var nest_positions: Array[Vector2] = [
	nest_position_1.global_position,
	nest_position_2.global_position
]
@onready var fly_away_position_1: Control = $GameRoot/FlyAway/Position1
@onready var fly_away_position_2: Control = $GameRoot/FlyAway/Position2
@onready var fly_away_positions: Array[Vector2] = [
	fly_away_position_1.global_position,
	fly_away_position_2.global_position
]


# Find and set the parameters of the minigame, like the number of lives or the victory conditions.
func _setup_minigame() -> void:
	super._setup_minigame()
	
	# Progression management
	current_progression = 0
	
	var max_difficulty: int = 0
	for difficulty_key: int in DIFFICULTY_SETTINGS.keys():
		if difficulty_key > max_difficulty:
			max_difficulty = difficulty_key
	
	if difficulty > max_difficulty:
		difficulty = max_difficulty
	
	var settings: Dictionary = DIFFICULTY_SETTINGS[difficulty]
	
	var pairs_count: int = min(settings.pairs_count, stimuli.size())
	var possible_start_positions: Array = possible_start_positions_parent.get_children()
	possible_start_positions.shuffle()
	var stimuli2: Array = stimuli.duplicate()
	stimuli2.shuffle()
	max_progression = pairs_count
	var color: Parakeet.Colors = randi_range(0, Parakeet.Colors.size() - 1) as Parakeet.Colors
	for index: int in range(pairs_count):
		var new_parakeet_uppercase: Parakeet = PARAKEET_SCENE.instantiate()
		var new_parakeet_lowercase: Parakeet = PARAKEET_SCENE.instantiate()
		parakeets_node.add_child(new_parakeet_uppercase)
		parakeets_node.add_child(new_parakeet_lowercase)
		new_parakeet_uppercase.color = color
		new_parakeet_lowercase.color = color
		new_parakeet_uppercase.uppercase = true
		new_parakeet_lowercase.uppercase = false
		new_parakeet_uppercase.global_position = possible_start_positions[2 * index].global_position
		new_parakeet_lowercase.global_position = possible_start_positions[2 * index + 1].global_position
		parakeets.append_array([new_parakeet_uppercase, new_parakeet_lowercase])
		var stimulus: Dictionary = stimuli2.pop_back()
		new_parakeet_uppercase.stimulus = stimulus
		new_parakeet_lowercase.stimulus = stimulus
		new_parakeet_uppercase.pressed.connect(_on_parakeet_pressed.bind(new_parakeet_uppercase))
		new_parakeet_lowercase.pressed.connect(_on_parakeet_pressed.bind(new_parakeet_lowercase))


# Find the stimuli and distractions of the minigame.
func _find_stimuli_and_distractions() -> void:
	stimuli = Database.get_gps_for_lesson(lesson_nb, true)
	# Only select stimuli with 1 letter, not more
	stimuli = stimuli.filter(func(stimulus: Dictionary) -> bool:
		return (stimulus.Grapheme as String).length() == 1)


func _start() -> void:
	super()
	fireworks.set_colors([Color("#bca4ff"), Color("#f5a8c8"), Color("#ffbf94")])
	var possible_positions: Array[Vector2] = []
	for branch: Node in branches.get_children():
		for child: Node2D in branch.get_children():
			if "Position" in child.name:
				possible_positions.append(child.global_position)
	possible_positions.shuffle()
	await _flying_arrival(possible_positions)
	_present_parakeets()


func _on_parakeet_pressed(parakeet: Parakeet) -> void:
	match state:
		State.SELECTED_2, State.LOCKED:
			return
		
		State.SELECTED_1:
			state = State.LOCKED
			if parakeet in selected:
				selected.erase(parakeet)
				await _turn(parakeet, true)
				state = State.IDLE
			else:
				selected.append(parakeet)
				await _turn(parakeet, false)
				state = State.SELECTED_2
				_log_new_response({"pair": [selected[0].stimulus, selected[1].stimulus]}, {"pair": [selected[0].stimulus, selected[0].stimulus]})
				if selected[0].stimulus.Grapheme == selected[1].stimulus.Grapheme:
					_correct()
				else:
					_wrong()
				
		State.IDLE:
			state = State.LOCKED
			selected.append(parakeet)
			await _turn(parakeet, false)
			state = State.SELECTED_1


func _correct() -> void:
	# Ensure Upper letter is on the left
	if selected[1].label.text == selected[0].label.text.to_upper():
		var buffer: Parakeet = selected[0]
		selected[0] = selected[1]
		selected[1] = buffer
	await _make_selected_happy()
	current_progression += 1
	await _fly_to(nest_positions)
	await _make_selected_coo()
	_fly_to(fly_away_positions)
	state = State.IDLE
	selected.clear()


func _wrong() -> void:
	await _make_selected_sad()
	current_lives -= 1
	
	for parakeet: Parakeet in selected:
		parakeet.idle()
	await _parakeets_to_front(selected)
	await _present_parakeets()
	
	selected.clear()


func _parakeets_to_front(exceptions: Array[Parakeet] = []) -> void:
	var coroutine: Coroutine = Coroutine.new()
	for parakeet: Parakeet in parakeets:
		if parakeet in exceptions:
			continue
		
		coroutine.add_future(_turn.bind(parakeet, false))
	await coroutine.join_all()


func _present_parakeets() -> void:
	await get_tree().create_timer(3).timeout
	var coroutine: Coroutine = Coroutine.new()
	for parakeet: Parakeet in parakeets:
		coroutine.add_future(_turn.bind(parakeet, true))
	await coroutine.join_all()
	state = State.IDLE


func _make_selected_happy() -> void:
	for parakeet: Parakeet in selected:
		parakeet.right()
		parakeet.happy()
	audio_player.stream = AUDIO_STREAMS[Audio.HAPPY]
	audio_player.play()
	await audio_player.finished


func _make_selected_sad() -> void:
	var coroutine: Coroutine = Coroutine.new()
	for parakeet: Parakeet in selected:
		parakeet.wrong()
		coroutine.add_future(parakeet.sad)
	await coroutine.join_all()


func _make_selected_coo() -> void:
	for parakeet: Parakeet in selected:
		parakeet.idle()
	audio_player.stream = AUDIO_STREAMS[Audio.WIN]
	audio_player.play()
	await audio_player.finished


func _fly_to(targets: Array[Vector2]) -> void:
	var parent: Node = selected[0].get_parent()
	parent.move_child(selected[0], parent.get_child_count() - 1)
	parent.move_child(selected[1], parent.get_child_count() - 1)
	var coroutine: Coroutine = Coroutine.new()
	audio_player.stream = AUDIO_STREAMS[Audio.FLY]
	audio_player.play()
	coroutine.add_future(audio_player.finished)
	coroutine.add_future(selected[0].fly_to.bind(targets[0], fly_duration))
	coroutine.add_future(selected[1].fly_to.bind(targets[1], fly_duration))
	await coroutine.join_all()


func _turn(parakeet: Parakeet, to_back: bool) -> void:
	if not audio_player.playing:
		audio_player.stream = AUDIO_STREAMS[Audio.TURN]
		audio_player.play()
	if to_back:
		await parakeet.turn_to_back()
	else:
		await parakeet.turn_to_front()


func _flying_arrival(to: Array[Vector2]) -> void:
	assert(parakeets.size() <= to.size(), "Some parakeets don't have a destination")
	var coroutine: Coroutine = Coroutine.new()
	audio_player.stream = AUDIO_STREAMS[Audio.FLY]
	audio_player.play()
	coroutine.add_future(audio_player.finished)
	for index: int in range(parakeets.size()):
		coroutine.add_future(parakeets[index].fly_to.bind(to[index], fly_duration))
	await coroutine.join_all()
	for parakeet: Parakeet in parakeets:
		parakeet.idle()
