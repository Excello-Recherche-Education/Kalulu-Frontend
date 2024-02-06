@tool
extends Minigame

@export var difficulty: = 1
@export var lesson_nb: = 15

const hole_class: = preload("res://sources/minigames/crabs/hole/hole.tscn")
const difficulty_settings: = {
	0: {"crab_rows": [2, 1]},
	1 : {"crab_rows": [3, 2]},
	2 : {"crab_rows": [4, 3]},
	3 : {"crab_rows": [4, 3, 2]},
	4 : {"crab_rows": [4, 3, 4]},
}

@onready var crab_zone: = $GameRoot/CrabZone

var holes: = []


# ------------ Initialisation ------------

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
	var top_left: Vector2 = crab_zone.position
	var bottom_right: Vector2 = top_left + crab_zone.size
	for i in range(settings["crab_rows"].size()):
		var fi: = float(i + 1.0) / float(settings["crab_rows"].size() + 1.0)
		var y: float = (1.0 - fi) * top_left.y + fi * bottom_right.y
		for j in range(settings["crab_rows"][i]):
			var fj: = float(j + 1.0) / float(settings["crab_rows"][i] + 1.0)
			var x: float = fj * top_left.x + (1.0 - fj) * bottom_right.x
			
			var hole: = hole_class.instantiate()
			game_root.add_child(hole)
			hole.position = Vector2(x, y)
			
			hole.stimulus_hit.connect(_on_hole_stimulus_hit.bind(hole))
			hole.crab_despawned.connect(_on_hole_crab_despawned)
			
			holes.append(hole)


func _find_stimuli_and_distractions() -> void:
	stimuli = Database.get_GP_for_lesson(lesson_nb, true)
	var all_distractions: = Database.get_GP_before_lesson(lesson_nb, true)
	all_distractions.shuffle()
	
	var number_of_distractions: int = min((max_progression - 1) / 2, all_distractions.size())
	var current_distractions: = all_distractions.slice(0, number_of_distractions)
	
	stimuli.append_array(current_distractions)
	distractions = stimuli.duplicate()


# Launch the minigame
func _start() -> void:
	super()
	
	_on_hole_timer_timeout(stimuli[current_progression % stimuli.size()])
	audio_player.stream = Database.get_audio_stream_for_phoneme(stimuli[current_progression % stimuli.size()].Phoneme)
	audio_player.play()
	
	for i in range(int(3.0 * holes.size() / 4.0)):
		_on_hole_crab_despawned(stimuli[randi() % stimuli.size()])
		
		await get_tree().create_timer(0.1).timeout


# ------------ Crabs ------------


func _on_hole_stimulus_hit(stimulus: Dictionary, hole: Node2D) -> void:
	_log_new_response(stimulus, stimuli[current_progression % stimuli.size()])
	if stimulus == stimuli[current_progression % stimuli.size()]:
		hole.right()
		current_progression += 1
	else:
		audio_player.stream = Database.get_audio_stream_for_phoneme(stimulus.Phoneme)
		audio_player.play()
		hole.wrong()
		current_lives -= 1


func _on_hole_crab_despawned(stimulus: Dictionary) -> void:
	await get_tree().create_timer(randf_range(0.1, 2.0)).timeout
	
	_on_hole_timer_timeout(stimulus)


func _on_hole_timer_timeout(stimulus: Dictionary) -> void:
	var holes_range: = range(holes.size())
	holes_range.shuffle()
	
	var hole_found: = false
	while not hole_found:
		for i in holes_range:
			if not holes[i].crab:
				holes[i].spawn_crab(stimuli[randi() % stimuli.size()])
				hole_found = true
				
				break
		
		if not hole_found:
			await get_tree().create_timer(randf_range(0.1, 0.5)).timeout


func _on_current_progression_changed() -> void:
	if current_progression > 0:
		audio_player.stream = Database.get_audio_stream_for_phoneme(stimuli[current_progression % stimuli.size()].Phoneme)
		audio_player.play()


func _play_stimulus() -> void:
	audio_player.stream = Database.get_audio_stream_for_phoneme(stimuli[current_progression % stimuli.size()].Phoneme)
	audio_player.play()
	if audio_player.playing:
		await audio_player.finished
