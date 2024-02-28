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
	0: DifficultySettings.new(4, 0.75, 150),
	1: DifficultySettings.new(3, 0.66, 175),
	2: DifficultySettings.new(2, 0.33, 200),
	3: DifficultySettings.new(1, 0.25, 250),
	4: DifficultySettings.new(1, 0.25, 300),
}

@export var lesson_nb: = 4
@export var difficulty: = 0

var blocking_jellyfish: Array[Jellyfish] = []

@onready var spawning_space: Control = %SpawningSpace
@onready var spawn_timer: = $SpawnTimer


func _find_stimuli_and_distractions() -> void:
	
	# Gets the stimuli (only vowels for now) for the current lesson
	var current_lesson_stimuli = Database.get_vowels_for_lesson(lesson_nb)
	
	# Calculate the number of stimuli to add from this lesson (70% of the maximum progression)
	@warning_ignore("narrowing_conversion")
	var number_of_stimuli: int = max_progression * 0.7
	
	# Adds the right number of stimuli from current lesson
	while stimuli.size() < number_of_stimuli:
		stimuli.append(current_lesson_stimuli[randi() % current_lesson_stimuli.size()])
	
	# Gets other stimuli from previous errors or lessons
	var previous_lesson_stimuli = Database.get_vowels_before_lesson(lesson_nb)
	while stimuli.size() < max_progression:
		stimuli.append(previous_lesson_stimuli[randi() % previous_lesson_stimuli.size()])
	
	# Shuffle the stimuli
	stimuli.shuffle()
	
	# For each stimuli get the distractors
	var all_learned_stimuli = previous_lesson_stimuli
	all_learned_stimuli.append_array(current_lesson_stimuli)
	for stimulus in stimuli:
		var stimulus_distractors := []
		
		for distractor in all_learned_stimuli:
			if stimulus.Grapheme != distractor.Grapheme and stimulus.Phoneme != distractor.Phoneme:
				stimulus_distractors.append(distractor)
		
		# Adds fake distractors (allow to have empty jellyfishes) if there are less than 4 distractors
		while stimulus_distractors.size() < 4:
			stimulus_distractors.append({})
	
		distractions.append(stimulus_distractors)
	
	print(stimuli)
	print(distractions)


func _start() -> void:
	super()
	_play_current_stimulus_phoneme()
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


func _highlight():
	# TODO Revoir, il faut highlight les méduses jusqu'à ce que la bonne réponse soit trouvée ? Ou pendant un certain temps ? Ou on laisse comme ça ?
	for jellyfish: Jellyfish in spawning_space.get_children():
		if jellyfish.stimulus and jellyfish.stimulus.Grapheme == _get_current_stimulus().Grapheme:
			jellyfish.highlight()


func _spawn() -> void:
	# Instantiate a new jellyfish
	var new_jellyfish : Jellyfish = jellyfish_scene.instantiate()
	
	# Check if there is enough space to spawn the jellyfish and find a spot
	var permitted_range: = 0
	var left_border: = 0
	# Blocking jellyfish is supposed to be ordered
	for blocking in blocking_jellyfish:
		permitted_range += max(0, blocking.position.x - left_border - new_jellyfish.size.x)
		left_border = blocking.position.x + blocking.size.x
	permitted_range += max(0, spawning_space.size.x - left_border)
	if permitted_range <= 0:
		new_jellyfish.queue_free()
		return
	
	# Define if the jellyfish is a stimulus or a distraction
	var is_stimulus: = randf() < _get_difficulty_settings().stimuli_ratio
	if is_stimulus:
		new_jellyfish.stimulus = _get_current_stimulus()
	else:
		var current_distractors : Array = distractions[current_progression % distractions.size()]
		new_jellyfish.stimulus = current_distractors[randi() % current_distractors.size()]
	
	# Randomize the spawn and adds the jellyfish into the scene
	var random_spawn: = randi_range(0, permitted_range - 1)
	left_border = 0
	# Blocking jellyfish is supposed to be ordered
	for blocking in blocking_jellyfish:
		var local_permitted_range = max(0, blocking.position.x - left_border - new_jellyfish.size.x)
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
	new_jellyfish.pressed.connect(_on_jellyfish_pressed.bind(new_jellyfish))
	
	# Adds the jellyfish into the scene
	spawning_space.add_child(new_jellyfish)


func _get_difficulty_settings() -> DifficultySettings:
	return difficulty_settings[difficulty]


func _get_current_stimulus() -> Dictionary :
	if stimuli.size() == 0:
		return {}
	return stimuli[current_progression % stimuli.size()]


# TODO Peut être à déplacer dans un script attaché à l'AudioStreamPlayer de BaseMinigame
func _play_phoneme(phoneme : String) -> void:
	var phoneme_audiostream = Database.get_audio_stream_for_phoneme(phoneme) as AudioStream
	if not phoneme_audiostream:
		push_warning("AudioStream not found for phoneme " + phoneme)
		return
	
	audio_player.stream = phoneme_audiostream
	audio_player.play()
	
	if audio_player.playing:
		await audio_player.finished


func _play_current_stimulus_phoneme()-> void:
	var current_stimulus: = _get_current_stimulus()
	if not current_stimulus or not current_stimulus.has("Phoneme"):
		return
	
	await _play_phoneme(current_stimulus.Phoneme)


# ------------ Connections ------------


func _on_spawn_timer_timeout() -> void:
	_spawn()
	spawn_timer.wait_time = _get_difficulty_settings().spawn_time


func _on_jellyfish_pressed(jellyfish: Jellyfish) -> void:
	
	# Disconnect the jellyfish
	jellyfish.pressed.disconnect(_on_jellyfish_pressed)
	
	# Log the answer
	_log_new_response(jellyfish.stimulus, _get_current_stimulus())
	
	# Check if the stimulus is right
	var is_right: bool = jellyfish.stimulus.Grapheme == _get_current_stimulus().Grapheme
	if is_right:
		jellyfish.happy()
		jellyfish.right()
		current_progression += 1
	else:
		jellyfish.hit()
		jellyfish.wrong()
		current_lives -= 1
		
		# Play the pressed jellyfish phoneme
		if jellyfish.stimulus and jellyfish.stimulus.Phoneme:
			await _play_phoneme(jellyfish.stimulus.Phoneme)
	
	# Remove the jellyfish
	await jellyfish.delete()
	
	# Handle the blocking array
	if jellyfish in blocking_jellyfish:
		blocking_jellyfish.erase(jellyfish)
	
	# Replay the current stimulus
	if not is_right:
		_play_current_stimulus_phoneme()


# ------------ UI Callbacks ------------


func _on_current_progression_changed() -> void:
	if current_progression > 0:
		_play_current_stimulus_phoneme()


func _play_stimulus() -> void:
	await _play_current_stimulus_phoneme()
