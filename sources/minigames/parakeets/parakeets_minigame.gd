extends Minigame

const Parakeet: = preload("res://sources/minigames/parakeets/parakeet.gd")

enum State {
	Locked,
	Idle,
	Selected1,
	Selected2,
}

enum Audio {
	Fly,
	Happy,
	Turn,
	Win,
}

const audio_streams: = [
	preload("res://assets/minigames/parakeets/audio/parakeet_fly.mp3"),
	preload("res://assets/minigames/parakeets/audio/parakeet_happy_short.mp3"),
	preload("res://assets/minigames/parakeets/audio/parakeet_turn_over.mp3"),
	preload("res://assets/minigames/parakeets/audio/parakeet_win.mp3"),
]

@export var difficulty: = 1
@export var lesson_nb: = 4
@export var fly_duration: = 3.0

@onready var branches: = $GameRoot/TreeTrunk/Branches
@onready var possible_start_positions_parent: = $GameRoot/FlyFrom
@onready var parakeets_node: = $GameRoot/Parakeets
@onready var nest_positions: Array[Vector2] = [
	$GameRoot/TreeTrunk/Branches/TreeBranch5/TreeNestBack/TreeNestFront/Position1.global_position,
	$GameRoot/TreeTrunk/Branches/TreeBranch5/TreeNestBack/TreeNestFront/Position2.global_position
	]
@onready var fly_away_positions: Array[Vector2] = [$GameRoot/FlyAway/Position1.global_position, $GameRoot/FlyAway/Position2.global_position]

var possible_branch_positions: Array[Vector2]
var parakeets: Array[Parakeet]
var selected: Array[Parakeet]
var state: = State.Locked

const difficulty_settings: = {
	0 : {"pairs_count": 2},
	1 : {"pairs_count": 3},
	2 : {"pairs_count": 4},
	3 : {"pairs_count": 5},
	4 : {"pairs_count": 6},
}


# Find and set the parameters of the minigame, like the number of lives or the victory conditions.
func _setup_minigame() -> void:
	super._setup_minigame()
	
	# Progression management
	current_progression = 0
	
	var max_difficulty: = 0
	for d in difficulty_settings.keys():
		if d > max_difficulty:
			max_difficulty = d
	
	if difficulty > max_difficulty:
		difficulty = max_difficulty
	
	var settings: Dictionary = difficulty_settings[difficulty]
	
	var pairs_count: int = min(settings.pairs_count, stimuli.size())
	var possible_start_positions: Array = possible_start_positions_parent.get_children()
	possible_start_positions.shuffle()
	var stimuli2: = stimuli.duplicate()
	stimuli2.shuffle()
	max_progression = pairs_count
	for i in pairs_count:
		var new_parakeet1: Parakeet = Parakeet.instantiate()
		var new_parakeet2: Parakeet = Parakeet.instantiate()
		parakeets_node.add_child(new_parakeet1)
		parakeets_node.add_child(new_parakeet2)
		new_parakeet1.global_position = possible_start_positions[2 * i].global_position
		new_parakeet2.global_position = possible_start_positions[2 * i + 1].global_position
		parakeets.append_array([new_parakeet1, new_parakeet2])
		var stimulus: Dictionary = stimuli2.pop_back()
		var stimulus_up: = stimulus.duplicate()
		stimulus_up.label = stimulus_up.Grapheme.to_upper()
		new_parakeet1.stimulus = stimulus
		new_parakeet2.stimulus = stimulus_up
		new_parakeet1.pressed.connect(_on_parakeet_pressed.bind(new_parakeet1))
		new_parakeet2.pressed.connect(_on_parakeet_pressed.bind(new_parakeet2))


# Find the stimuli and distractions of the minigame.
func _find_stimuli_and_distractions() -> void:
	var before: = Database.get_GP_before_lesson(lesson_nb)
	var current: = Database.get_GP_for_lesson(lesson_nb)
	before.append_array(current)
	stimuli = Database.copy_without_double_graphemes(before)


func _start() -> void:
	var possible_positions: Array[Vector2] = []
	for branch in branches.get_children():
		for child in branch.get_children():
			if "Position" in child.name:
				possible_positions.append(child.global_position)
	possible_positions.shuffle()
	await _flying_arrival(possible_positions)
	_present_parakeets()


func _on_parakeet_pressed(parakeet: Parakeet) -> void:
	match state:
		State.Selected2, State.Locked:
			return
		
		State.Selected1:
			state = State.Locked
			if parakeet in selected:
				selected.erase(parakeet)
				await _turn(parakeet, true)
				state = State.Idle
			else:
				selected.append(parakeet)
				await _turn(parakeet, false)
				state = State.Selected2
				_on_selected_two()
		
		State.Idle:
			state = State.Locked
			selected.append(parakeet)
			await _turn(parakeet, false)
			state = State.Selected1


func _on_selected_two() -> void:
	if selected[0].stimulus.Grapheme.to_upper() == selected[1].stimulus.Grapheme.to_upper():
		_correct()
	else:
		_wrong()


func _correct() -> void:
	if selected[0].global_position.x > selected[1].global_position.x:
		var buffer: = selected[0]
		selected[0] = selected[1]
		selected[1] = buffer

	await _make_selected_happy()
	
	await _fly_to(nest_positions)
	
	await _make_selected_coo()
	
	await _fly_to(fly_away_positions)
	
	current_progression += 1
	state = State.Idle
	selected.clear()


func _wrong() -> void:
	await _make_selected_sad()
	
	current_lives -= 1
	
	for parakeet in selected:
		parakeet.idle()
	await _parakeets_to_front(selected)
	await _present_parakeets()
	
	selected.clear()


func _parakeets_to_front(exceptions: Array[Parakeet] = []) -> void:
	var coroutine: = Coroutine.new()
	for parakeet in parakeets:
		if parakeet in exceptions:
			continue
		
		coroutine.add_future(_turn.bind(parakeet, false))
	await coroutine.join_all()


func _present_parakeets() -> void:
	await get_tree().create_timer(3).timeout
	var coroutine: = Coroutine.new()
	for parakeet in parakeets:
		coroutine.add_future(_turn.bind(parakeet, true))
	await coroutine.join_all()
	state = State.Idle


func _make_selected_happy() -> void:
	for parakeet in selected:
		parakeet.happy()
	audio_player.stream = audio_streams[Audio.Happy]
	audio_player.play()
	await audio_player.finished


func _make_selected_sad() -> void:
	var coroutine: = Coroutine.new()
	for parakeet in selected:
		coroutine.add_future(parakeet.sad)
	await coroutine.join_all()


func _make_selected_coo() -> void:
	for parakeet in selected:
		parakeet.idle()
	audio_player.stream = audio_streams[Audio.Win]
	audio_player.play()
	await audio_player.finished


func _fly_to(targets: Array[Vector2]) -> void:
	var coroutine: = Coroutine.new()
	audio_player.stream = audio_streams[Audio.Fly]
	audio_player.play()
	coroutine.add_future(audio_player.finished)
	coroutine.add_future(selected[0].fly_to.bind(targets[0], fly_duration))
	coroutine.add_future(selected[1].fly_to.bind(targets[1], fly_duration))
	await coroutine.join_all()


func _turn(parakeet: Parakeet, to_back: bool) -> void:
	audio_player.stream = audio_streams[Audio.Turn]
	audio_player.play()
	if to_back:
		await parakeet.turn_to_back()
	else:
		await parakeet.turn_to_front()


func _flying_arrival(to: Array[Vector2]) -> void:
	assert(parakeets.size() <= to.size(), "Some parakeets don't have a destination")
	var coroutine: = Coroutine.new()
	audio_player.stream = audio_streams[Audio.Fly]
	audio_player.play()
	coroutine.add_future(audio_player.finished)
	for i in parakeets.size():
		coroutine.add_future(parakeets[i].fly_to.bind(to[i], fly_duration))
	await coroutine.join_all()
	for parakeet in parakeets:
		parakeet.idle()
