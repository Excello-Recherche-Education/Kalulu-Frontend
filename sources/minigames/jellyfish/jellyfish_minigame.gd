extends HearAndFindMinigame

const jellyfish_scene: = preload("res://sources/minigames/jellyfish/jellyfish.tscn")

class DifficultySettings:
	var spawn_time: = 4.0
	var stimuli_ratio: = 0.75
	var velocity: = 150
	
	func _init(p_spawn_time: float, p_stimuli_ratio: float, p_velocity: int) -> void:
		spawn_time = p_spawn_time
		stimuli_ratio = p_stimuli_ratio
		velocity = p_velocity

var difficulty_settings: Array[DifficultySettings] = [
	DifficultySettings.new(4, 0.75, 150),
	DifficultySettings.new(3, 0.66, 175),
	DifficultySettings.new(2, 0.33, 200),
	DifficultySettings.new(1, 0.25, 250),
	DifficultySettings.new(1, 0.25, 300)
]


@onready var spawning_space: Control = %SpawningSpace
@onready var spawn_timer: Timer = $GameRoot/SpawnTimer

var blocking_jellyfish: Array[Jellyfish] = []
var is_highlighting: bool = false

func _start() -> void:
	super()
	spawn_timer.start()


func _process(delta: float) -> void:
	for jellyfish: Jellyfish in spawning_space.get_children():
		# Moves the jellyfish upward
		if jellyfish.is_idle():
			jellyfish.position.y -= _get_difficulty_settings().velocity * delta
		
		# Handles the blocking array
		if jellyfish in blocking_jellyfish and jellyfish.position.y + jellyfish.size.y < spawning_space.size.y:
			blocking_jellyfish.erase(jellyfish)
			
		# Destroy the jellyfish when it leaves the screen
		if jellyfish.position.y + jellyfish.size.y < 0:
			jellyfish.queue_free()


func _highlight() -> void:
	is_highlighting = true
	for jellyfish: Jellyfish in spawning_space.get_children():
		if jellyfish.stimulus and _is_stimulus_right(jellyfish.stimulus):
			jellyfish.highlight()


func _stop_highlight() -> void:
	is_highlighting = false
	for jellyfish: Jellyfish in spawning_space.get_children():
		jellyfish.stop_highlight()


func _spawn() -> void:
	# Instantiate a new jellyfish
	var new_jellyfish : Jellyfish = jellyfish_scene.instantiate()
	spawning_space.add_child(new_jellyfish)
	
	# Find the right size for the jellyfish
	var jellyfish_width: = new_jellyfish.size.x * new_jellyfish.scale.x
	
	# Check if there is enough space to spawn the jellyfish and find a spot
	var permitted_range: = 0.
	var left_border: = 0.
	# Blocking jellyfish is supposed to be ordered
	for blocking in blocking_jellyfish:
		permitted_range += max(0, blocking.position.x - left_border - jellyfish_width)
		left_border = blocking.position.x + blocking.size.x
	permitted_range += max(0, spawning_space.size.x - left_border)
	if permitted_range <= 0:
		new_jellyfish.queue_free()
		return
	
	# Define if the jellyfish is a stimulus or a distraction
	var is_stimulus: = randf() < _get_difficulty_settings().stimuli_ratio
	if is_stimulus:
		new_jellyfish.stimulus = _get_current_stimulus()
		if is_highlighting:
			new_jellyfish.highlight()
	else:
		var current_distractors : Array = distractions[current_progression % distractions.size()]
		new_jellyfish.stimulus = current_distractors.pick_random()
	
	# Randomize the spawn and adds the jellyfish into the scene
	var random_spawn: = randf_range(0, permitted_range - 1)
	left_border = 0
	# Blocking jellyfish is supposed to be ordered
	for blocking in blocking_jellyfish:
		var local_permitted_range: float = max(0, blocking.position.x - left_border - jellyfish_width)
		if local_permitted_range <= random_spawn:
			random_spawn -= local_permitted_range
		else:
			break
		left_border = blocking.position.x + blocking.size.x
	new_jellyfish.position.x = left_border + random_spawn
	new_jellyfish.position.y = spawning_space.size.y
	
	# Insert the new jellyfish on the right spot in the blocking array
	var found_ind: = -1
	for i in blocking_jellyfish.size():
		var blocking: = blocking_jellyfish[i]
		if blocking.position.x > new_jellyfish.position.x:
			found_ind = i
			break
	if found_ind < 0:
		found_ind = blocking_jellyfish.size()
	blocking_jellyfish.insert(found_ind, new_jellyfish)
	
	# Connects the new jellyfish with the pressed signal
	new_jellyfish.pressed.connect(_on_stimulus_pressed.bind(new_jellyfish))


func _get_difficulty_settings() -> DifficultySettings:
	return difficulty_settings[difficulty]


func _on_current_progression_changed() -> void:
	# Play the new stimulus
	super()
	# Restarts the spawning of jellyfishes
	spawn_timer.start()


# ------------ Connections ------------


func _on_spawn_timer_timeout() -> void:
	_spawn()
	spawn_timer.wait_time = _get_difficulty_settings().spawn_time


func _on_stimulus_pressed(stimulus: Dictionary, node: Node) -> bool:
	if not super(stimulus, node):
		return false
	
	var jellyfish: = node as Jellyfish
	if not jellyfish:
		return false
	
	# Disconnect the jellyfish
	jellyfish.pressed.disconnect(_on_stimulus_pressed)
	
	# Check if the stimulus is right
	var is_right: = _is_stimulus_right(jellyfish.stimulus)
	if is_right:
		jellyfish.happy()
		jellyfish.right()
		current_progression += 1
		_stop_highlight()
	else:
		jellyfish.hit()
		await jellyfish.wrong()
		current_lives -= 1
		
		# Play the pressed jellyfish phoneme
		if jellyfish.stimulus and jellyfish.stimulus.Phoneme:
			await audio_player.play_phoneme(jellyfish.stimulus.Phoneme)
		
		# Remove the jellyfish
		await jellyfish.delete()
	
	# Handle the blocking array
	if jellyfish in blocking_jellyfish:
		blocking_jellyfish.erase(jellyfish)
	
	# Replay the current stimulus
	if not is_right:
		_play_current_stimulus_phoneme()
	
	return true


func _on_stimulus_found() -> void:
	print("CLEAR")
	
	spawn_timer.stop()
	# Clear all the jellyfishes
	for jellyfish: Jellyfish in spawning_space.get_children():
		jellyfish.delete()
