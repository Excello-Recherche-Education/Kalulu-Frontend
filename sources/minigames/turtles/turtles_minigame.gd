extends WordsMinigame
class_name TurtlesMinigame

signal can_spawn_turtle()

const turtle_scene: PackedScene = preload("res://sources/minigames/turtles/turtle.tscn")

# Defines the maximum number of turtles visible on screen
const max_turtle_count: int = 5

# Defines the minimum distance between turtles when spawning them
const min_distance: int = 500


class DifficultySettings:
	var stimuli_ratio: = 0.75
	var velocity: float = 250.
	var spawn_rate: float = 4.
	
	func _init(p_stimuli_ratio: float, p_velocity: float, p_spawn_rate: float) -> void:
		stimuli_ratio = p_stimuli_ratio
		velocity = p_velocity
		spawn_rate = p_spawn_rate


var difficulty_settings: Array[DifficultySettings] = [
	DifficultySettings.new(.75, 250., 4.),
	DifficultySettings.new(.66, 300., 3.5),
	DifficultySettings.new(.33, 350., 3.),
	DifficultySettings.new(.25, 400., 2.5),
	DifficultySettings.new(.25, 450., 2.)
]


@onready var water: Water = $GameRoot/Water
@onready var island: Island = $GameRoot/Island
@onready var turtles: Control = %Turtles
@onready var spawn_location: PathFollow2D = $GameRoot/SpawnPath/SpawnLocation
@onready var spawn_timer: Timer = $GameRoot/SpawnTimer

var settings: DifficultySettings
var turtle_count: int = 0:
	set(value):
		if turtle_count >= max_turtle_count and value < max_turtle_count:
			can_spawn_turtle.emit()
		turtle_count = value

# Find and set the parameters of the minigame, like the number of lives or the victory conditions.
func _setup_minigame() -> void:
	super._setup_minigame()
	
	# Setups the current settings
	settings = difficulty_settings[difficulty]
	if not settings:
		return
	
	# Setups the island for the first word
	island.stimulus = self._get_current_stimulus()
	
	# Setups the timer
	spawn_timer.wait_time = settings.spawn_rate


func _play_turtle_phoneme(gp: Dictionary) -> void:
	if gp and gp.has("Phoneme"):
		await audio_player.play_phoneme(gp.Phoneme)


func _clear_turtles() -> void:
	for turtle: Turtle in turtles.get_children():
		turtle.disappear()


#region Connections

func _on_spawn_timer_timeout() -> void:
	# Checks if there are too many turtle, and wait for one to despawn
	if turtle_count >= max_turtle_count:
		await can_spawn_turtle
	
	# Spawn a turtle
	var turtle: Turtle = turtle_scene.instantiate()
	
	# Pick a position to spawn the turtle
	var position_found: bool = false
	while not position_found:
		spawn_location.progress_ratio = randf()
		var all_position_ok: bool = true
		# Check if there are other turtles nearby
		for other_turtle: Turtle in turtles.get_children():
			if other_turtle.position.distance_squared_to(spawn_location.position) < min_distance * min_distance:
				all_position_ok = false
				break
		position_found = all_position_ok
	
	turtle.position = spawn_location.position
	turtle.velocity = settings.velocity
	
	turtle.pressed.connect(_play_turtle_phoneme)
	turtle.animation_changed.connect(water.spawn_water_ring)
	turtle.tree_exited.connect(
		func() -> void:
			turtle_count -= 1
	)
	
	turtles.add_child(turtle)
	
	# Set the direction of the turtle
	turtle.direction = Vector2.DOWN.rotated(spawn_location.rotation).normalized()
	
	# Define if the turtle is a stimulus or a distraction
	var is_stimulus: = randf() < settings.stimuli_ratio
	if is_stimulus:
		turtle.gp = _get_GP()
	else:
		turtle.gp = _get_distractor()
	
	# Increment the count
	turtle_count += 1
	
	# Restarts timer
	spawn_timer.start()


func _on_island_area_entered(area: Area2D) -> void:
	# Get the turtle that landed on the island
	var turtle: = area.owner as Turtle
	if not turtle:
		return
	
	# Disable the island collisions
	island.set_enabled(false)
	
	# Check if the turtle is a distractor or the awaited GP
	if _is_GP_right(turtle.gp):
		# Stop the spawning
		spawn_timer.stop()
	
		#_stop_highlight()
		
		# Play the right animation
		turtle.right()
		
		# Clear all the turtles
		_clear_turtles()
		
		# Update the island
		island.progress = current_word_progression + 1
		
		# Play the GP
		await audio_player.play_phoneme(_get_GP().Phoneme)
		
		# Update the word progression
		current_word_progression += 1
	else:
		# Play the wrong animation
		turtle.wrong()
		
		# Clear the turtle
		turtle.disappear()
		
		# Play the GP
		await audio_player.play_phoneme(turtle.gp.Phoneme)
		
		# Update the lives
		current_lives -= 1
	
	# Re-enable the island collisions
	island.set_enabled(true)


func _on_current_word_progression_changed() -> void:
	super()
	
	# Spawn a turtle and restarts the timer
	_on_spawn_timer_timeout()


func _on_current_progression_changed() -> void:
	# Stop the spawning
	spawn_timer.stop()
	
	# Replay the stimulus
	await get_tree().create_timer(time_between_words/2).timeout
	audio_player.play_word(_get_previous_stimulus().Word)
	await get_tree().create_timer(time_between_words/2).timeout
	
	# Starts a new round
	super()
	
	# Reset island
	island.stimulus = self._get_current_stimulus()
	
	# Restarts the spawning
	spawn_timer.start()

#endregion
