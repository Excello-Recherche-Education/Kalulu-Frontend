@tool
extends SyllablesMinigame

const HOLE_SCENE: PackedScene = preload("res://sources/minigames/crabs/hole/hole.tscn")

class DifficultySettings:
	var stimuli_ratio: float = 0.75
	var rows: Array[int] = [2, 1]
	
	func _init(p_stimuli_ratio: float, p_rows: Array[int]) -> void:
		stimuli_ratio = p_stimuli_ratio
		rows = p_rows

var difficulty_settings: Array[DifficultySettings] = [
	DifficultySettings.new(0.75, [2, 1]),
	DifficultySettings.new(0.66, [3, 2]),
	DifficultySettings.new(0.33, [4, 3]),
	DifficultySettings.new(0.25, [4, 3, 2]),
	DifficultySettings.new(0.25, [4, 3, 4])
]

@onready var crab_zone: Control = $GameRoot/CrabZone

var holes: Array[Hole] = []
var stimulus_spawned: bool = false


# ------------ Initialisation ------------


# Find and set the parameters of the minigame, like the number of lives or the victory conditions.
func _setup_minigame() -> void:
	super._setup_minigame()

	var difficulty: DifficultySettings = _get_difficulty_settings()

	# Define the rectangular zone where holes will be placed
	var zone_top_left: Vector2 = crab_zone.position
	var zone_bottom_right: Vector2 = zone_top_left + crab_zone.size

	# Loop through each row defined by the difficulty settings
	for row_index: int in range(difficulty.rows.size()):
		# Compute vertical placement ratio (between 0 and 1, skipping the edges)
		var vertical_ratio: float = float(row_index + 1) / float(difficulty.rows.size() + 1)
		var hole_y: float = lerp(zone_top_left.y, zone_bottom_right.y, vertical_ratio)

		# Get the number of holes to place in this row
		var holes_in_row: int = difficulty.rows[row_index]

		# Loop through each hole in the current row
		for column_index: int in range(holes_in_row):
			# Compute horizontal placement ratio (between 0 and 1, skipping the edges)
			var horizontal_ratio: float = float(column_index + 1) / float(holes_in_row + 1)
			var hole_x: float = lerp(zone_bottom_right.x, zone_top_left.x, horizontal_ratio)

			# Instantiate and position the hole
			var hole: Hole = HOLE_SCENE.instantiate()
			game_root.add_child(hole)
			hole.position = Vector2(hole_x, hole_y)

			if not Engine.is_editor_hint():
				hole.crab_out.connect(_on_hole_crab_out.bind(hole))
				hole.stimulus_hit.connect(_on_stimulus_pressed.bind(hole))
				hole.crab_despawned.connect(_on_hole_crab_despawned)
				stimulus_heard.connect(hole.on_stimulus_heard)

			holes.append(hole)
 

# Launch the minigame
func _start() -> void:
	super()
	_spawn_crabs()


func _get_difficulty_settings() -> DifficultySettings:
	return difficulty_settings[difficulty]


func _highlight() -> void:
	for hole: Hole in holes:
		if hole.crab and hole.crab_visible and _is_stimulus_right(hole.crab.stimulus):
			hole.highlight()


func _on_stimulus_pressed(stimulus: Dictionary, node: Node) -> bool:
	if not super(stimulus, node):
		return false
	
	var hole: Hole = node as Hole
	if not hole:
		return false
	
	var is_right: bool = _is_stimulus_right(stimulus)
	if is_right:
		hole.right()
		current_progression += 1
		stimulus_spawned = false
	else:
		hole.wrong()
		current_lives -= 1
		
		# Spawn another crab
		_on_hole_crab_despawned(false)
		
		# Play the pressed crab syllable
		if stimulus:
			await audio_player.play_syllable(stimulus)
		
		await get_tree().create_timer(1).timeout
		_play_current_stimulus_phoneme()
	
	return true


func _on_current_progression_changed() -> void:
	# Play the new stimulus
	super()
	# Restarts the spawning of crabs
	_spawn_crabs()


# ------------ Crabs ------------

# Spawn a set amount of crabs in random holes
func _spawn_crabs() -> void:
	for index: int in range(int(3.0 * holes.size() / 4.0)):
		_on_hole_crab_despawned(false)
		await get_tree().create_timer(0.1).timeout


func _on_hole_crab_out(hole: Hole) -> void:
	if is_highlighting and _is_stimulus_right(hole.crab.stimulus):
		hole.highlight()


func _on_hole_crab_despawned(is_stimulus: bool) -> void:
	if is_stimulus:
		stimulus_spawned = false
	
	if await _await_for_future_or_stimulus_found(get_tree().create_timer(randf_range(0.1, 2.0)).timeout):
		return
	_on_hole_timer_timeout()


func _on_hole_timer_timeout() -> void:
	var holes_range: Array = range(holes.size())
	holes_range.shuffle()
	
	var hole_found: bool = false
	while not hole_found:
		for index: int in holes_range:
			if not holes[index].crab:
				# Define if the crab is a stimulus or a distraction
				# Only one crab with the correct stimulus can be showned at a time
				var is_stimulus: bool = not stimulus_spawned and randf() < _get_difficulty_settings().stimuli_ratio
				if is_stimulus:
					stimulus_spawned = true
					holes[index].spawn_crab(_get_current_stimulus(), true)
				else:
					var current_distractors: Array = distractions[current_progression % distractions.size()]
					holes[index].spawn_crab(current_distractors.pick_random() as Dictionary, false)
				hole_found = true
				break
		
		if not hole_found:
			if await _await_for_future_or_stimulus_found(get_tree().create_timer(randf_range(0.1, 0.5)).timeout):
				hole_found = true


func _on_stimulus_found() -> void:
	# Despawn all the crabs
	for hole: Hole in holes:
		hole.stop.emit()
