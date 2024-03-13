@tool
extends HearAndFindMinigame

const hole_scene: = preload("res://sources/minigames/crabs/hole/hole.tscn")

class DifficultySettings:
	var stimuli_ratio: = 0.75
	var rows: = [2, 1]
	
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

@onready var crab_zone: = $GameRoot/CrabZone

var holes: Array[Hole] = []


# ------------ Initialisation ------------


# Find and set the parameters of the minigame, like the number of lives or the victory conditions.
func _setup_minigame() -> void:
	super._setup_minigame()
	
	var settings: = _get_difficulty_settings()
	
	# Spawns the good amount of holes and places them
	var top_left: Vector2 = crab_zone.position
	var bottom_right: Vector2 = top_left + crab_zone.size
	for i in range(settings.rows.size()):
		var fi: = float(i + 1.0) / float(settings.rows.size() + 1.0)
		var y: float = (1.0 - fi) * top_left.y + fi * bottom_right.y
		for j in range(settings.rows[i]):
			var fj: = float(j + 1.0) / float(settings.rows[i] + 1.0)
			var x: float = fj * top_left.x + (1.0 - fj) * bottom_right.x
			
			var hole: Hole = hole_scene.instantiate()
			game_root.add_child(hole)
			hole.position = Vector2(x, y)
			
			if not Engine.is_editor_hint():
				hole.stimulus_hit.connect(_on_hole_stimulus_hit.bind(hole))
				hole.crab_despawned.connect(_on_hole_crab_despawned)
				stimulus_heard.connect(hole.on_stimulus_heard)
				
			holes.append(hole)


# Launch the minigame
func _start() -> void:
	super()
	# Spawn a set amount of crabs in random holes
	for i in range(int(3.0 * holes.size() / 4.0)):
		_on_hole_crab_despawned()
		await get_tree().create_timer(0.1).timeout


func _get_difficulty_settings() -> DifficultySettings:
	return difficulty_settings[difficulty]


# ------------ Crabs ------------


func _on_hole_stimulus_hit(stimulus: Dictionary, hole: Hole) -> void:
	if not is_stimulus_heard:
		return
	
	# Logs the response
	_log_new_response(stimulus, _get_current_stimulus())
	
	var is_right: = _is_stimulus_right(stimulus)
	if is_right:
		hole.right()
		current_progression += 1
	else:
		hole.wrong()
		current_lives -= 1
		
		# Play the pressed crab phoneme
		if stimulus and stimulus.Phoneme:
			await audio_player.play_phoneme(stimulus.Phoneme)


func _on_hole_crab_despawned() -> void:
	await get_tree().create_timer(randf_range(0.1, 2.0)).timeout
	
	_on_hole_timer_timeout()


func _on_hole_timer_timeout() -> void:
	var holes_range: = range(holes.size())
	holes_range.shuffle()
	
	var hole_found: = false
	while not hole_found:
		for i in holes_range:
			if not holes[i].crab:
				# Define if the crab is a stimulus or a distraction
				var is_stimulus: = randf() < _get_difficulty_settings().stimuli_ratio
				if is_stimulus:
					holes[i].spawn_crab(_get_current_stimulus())
				else:
					var current_distractors : Array = distractions[current_progression % distractions.size()]
					holes[i].spawn_crab(current_distractors.pick_random())
				hole_found = true
				
				break
		
		if not hole_found:
			await get_tree().create_timer(randf_range(0.1, 0.5)).timeout
