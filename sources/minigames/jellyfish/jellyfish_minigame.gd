extends Minigame

const jellyfish_scene: = preload("res://sources/minigames/jellyfish/jellyfish.tscn")

class DifficultySettings:
	var spawn_time: = 4.0
	var stimuli_ratio: = 0.6
	var velocity: = 150
	
	func _init(p_spawn_time: float, p_stimuli_ratio: float, p_velocity: int) -> void:
		spawn_time = p_spawn_time
		stimuli_ratio = p_stimuli_ratio
		velocity = p_velocity


var difficulty_settings: = {
	0: DifficultySettings.new(4, 0.6, 150),
	1: DifficultySettings.new(3, 0.5, 175),
	2: DifficultySettings.new(2, 0.4, 200),
	3: DifficultySettings.new(1, 0.3, 250),
	4: DifficultySettings.new(1, 0.2, 300),
}

@export var lesson_nb: = 10
@export var difficulty: = 0

var blocking_jellyfish: Array[Control] = []

@onready var spawning_space: Control = %SpawningSpace
@onready var spawn_timer: = $SpawnTimer


# Find the stimuli and distractions of the minigame.
func _find_stimuli_and_distractions() -> void:
	stimuli = Database.get_GP_for_lesson(lesson_nb, true)
	distractions = Database.get_GP_before_lesson(lesson_nb, true)


# Launch the minigame
func _start() -> void:
	super()
	
	audio_player.stream = Database.get_audio_stream_for_phoneme(stimuli[0].Phoneme)
	audio_player.play()
	spawn_timer.start()


func _on_spawn_timer_timeout() -> void:
	_spawn()
	spawn_timer.wait_time = _get_difficulty_settings().spawn_time


func _process(delta: float) -> void:
	for jellyfish: Control in spawning_space.get_children():
		jellyfish.position.y -= _get_difficulty_settings().velocity * delta
		if jellyfish in blocking_jellyfish and jellyfish.position.y + jellyfish.size.y < spawning_space.size.y:
			blocking_jellyfish.erase(jellyfish)
		if jellyfish.position.y + jellyfish.size.y < 0:
			jellyfish.queue_free()


func _get_difficulty_settings() -> DifficultySettings:
	return difficulty_settings[difficulty]


func _spawn() -> void:
	var new_jellyfish: = jellyfish_scene.instantiate()
	spawning_space.add_child(new_jellyfish)
	var is_stimulus: = randf() < _get_difficulty_settings().stimuli_ratio
	new_jellyfish.stimulus = stimuli[0] if is_stimulus else distractions[randi() % distractions.size()]
	var permitted_range: = 0
	var left_border: = 0
	# blocking jellyfish is supposed to be ordered
	for blocking in blocking_jellyfish:
		permitted_range += max(0, blocking.position.x - left_border - new_jellyfish.size.x)
		left_border = blocking.position.x + blocking.size.x
	permitted_range += max(0, spawning_space.size.x - left_border)
	if permitted_range <= 0:
		new_jellyfish.queue_free()
		return
	var random_spawn: = randi_range(0, permitted_range - 1)
	left_border = 0
	# blocking jellyfish is supposed to be ordered
	for blocking in blocking_jellyfish:
		var local_permitted_range = max(0, blocking.position.x - left_border - new_jellyfish.size.x)
		if local_permitted_range <= random_spawn:
			random_spawn -= local_permitted_range
		else:
			break
		left_border = blocking.position.x + blocking.size.x
	new_jellyfish.position.x = left_border + random_spawn
	new_jellyfish.position.y = spawning_space.size.y
	var found_ind: = -1
	for i in blocking_jellyfish.size():
		var blocking: = blocking_jellyfish[i]
		if blocking.position.x > new_jellyfish.position.x:
			found_ind = i
			break
	if found_ind < 0:
		found_ind = blocking_jellyfish.size()
	blocking_jellyfish.insert(found_ind, new_jellyfish)
	new_jellyfish.pressed.connect(_on_jellyfish_pressed.bind(new_jellyfish))


func _on_jellyfish_pressed(jellyfish: Control) -> void:
	# already clicked
	if jellyfish.get_parent() != spawning_space:
		return
	var jellyfish_position: = jellyfish.global_position
	spawning_space.remove_child(jellyfish)
	spawning_space.add_sibling(jellyfish)
	jellyfish.global_position = jellyfish_position
	var is_right: = false
	if jellyfish.stimulus in stimuli:
		is_right = true
		jellyfish.happy()
		jellyfish.right()
		current_progression += 1
	else:
		jellyfish.hit()
		jellyfish.wrong()
		current_lives -= 1
		audio_player.stream = Database.get_audio_stream_for_phoneme(jellyfish.stimulus.Phoneme)
		audio_player.play()
		
	await get_tree().create_timer(1).timeout
	jellyfish.delete()
	if jellyfish in blocking_jellyfish:
		blocking_jellyfish.erase(jellyfish)
	if not is_right:
		_play_stimulus()


func _on_current_progression_changed() -> void:
	if current_progression > 0:
		audio_player.stream = Database.get_audio_stream_for_phoneme(stimuli[current_progression % stimuli.size()].Phoneme)
		audio_player.play()


func _play_stimulus() -> void:
	audio_player.stream = Database.get_audio_stream_for_phoneme(stimuli[current_progression % stimuli.size()].Phoneme)
	audio_player.play()
	if audio_player.playing:
		await audio_player.finished
