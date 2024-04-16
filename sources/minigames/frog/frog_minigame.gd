extends WordsMinigame
class_name FrogMinigame


const lilypad_track_scene: = preload("res://sources/minigames/frog/lilypad_track.tscn")


class DifficultySettings:
	var targetsPerLane: = 1
	var padsSpeedDisabled: = 100.0
	var padsSpeed: = 200.0
	
	func _init(p_targetsPerLane: int, p_padsSpeedDisabled: float, p_padsSpeed: float) -> void:
		targetsPerLane = p_targetsPerLane
		padsSpeedDisabled = p_padsSpeedDisabled
		padsSpeed = p_padsSpeed


var difficulty_settings: Array[DifficultySettings] = [
	DifficultySettings.new(1, 100., 200.),
	DifficultySettings.new(2, 150., 250.),
	DifficultySettings.new(2, 200., 300.),
	DifficultySettings.new(3, 250., 350.),
	DifficultySettings.new(3, 300., 400.)
]


@onready var start: = %Start
@onready var end: = %End

@onready var frog_spawn_point: = %FrogSpawnPoint
@onready var frog_despawn_point: = %FrogDespawnPoint

@onready var lilypad_tracks_container: = %LilypadTracksContainer
@onready var frog: = %Frog


# TODO Remove
func _old_find_stimuli_and_distractions() -> void:
	var words_list: = Database.get_words_for_lesson(lesson_nb)
	words_list.shuffle()
	stimuli = []
	distractions = []
	for i in max_progression:
		var word = words_list[i].Word
		var GPs: = Database.get_GP_from_word(word)
		stimuli.append({
			Word = word,
			GPs = GPs,
		})
		var grapheme_distractions: = []
		for GP in GPs:
			var distractors: = Database.get_distractors_for_grapheme(GP.Grapheme, lesson_nb)
			distractors.shuffle()
			while distractors.size() > 4:
				distractors.pop_front()
			grapheme_distractions.append(distractors)
		distractions.append(grapheme_distractions)


func _setup_word_progression() -> void:
	await _free_tracks()
	super()
	_create_tracks()
	_start_tracks()


func _highlight() -> void:
	for track: LilypadTrack in lilypad_tracks_container.get_children():
		track.is_highlighting = true


func _reset_frog() -> void:
	frog.global_position = frog_spawn_point.global_position
	frog.jump_to(start.global_position)
	await frog.jumped

#region Tracks management

func _free_tracks() -> void:
	for track: LilypadTrack in lilypad_tracks_container.get_children():
		await track.reset()
	
	for track: LilypadTrack in lilypad_tracks_container.get_children():
		track.queue_free()
		# Waits for the track to be properly freed
		await track.tree_exited


func _create_tracks() -> void:
	var current_word: = _get_current_stimulus()
	var current_distractors: = _get_current_distractors()
	
	for i in range(current_word.GPs.size()):
		var track: LilypadTrack = lilypad_track_scene.instantiate()
		track.name = str(i) + "_" + current_word.GPs[i].Grapheme
		lilypad_tracks_container.add_child(track)
		
		track.top_to_bottom = i % 2
		
		var track_stimuli: = []
		track_stimuli.append(current_word.GPs[i])
		track_stimuli.append_array(current_distractors[i])
		track.stimuli = track_stimuli
		
		var are_distractors: = []
		are_distractors.append(false)
		for j in range(current_distractors[i].size()):
			are_distractors.append(true)
		track.are_distractors = are_distractors
		
		track.lilypad_in_center.connect(_on_track_lilypad_in_center.bind(track))


func _start_tracks() -> void:
	for track: LilypadTrack in lilypad_tracks_container.get_children():
		await track.reset()
		track.start()
	lilypad_tracks_container.get_child(0).is_enabled = true

#endregion

#region Connections

func _on_track_lilypad_in_center(lilypad: Lilypad, track: LilypadTrack) -> void:
	frog.jump_to(lilypad.global_position)
	await frog.jumped
	
	_log_new_response(lilypad.stimulus, track.stimuli[0])
	
	if lilypad.is_distractor:
		await lilypad.wrong()
		
		lilypad.disappear()
		frog.drown()
		await frog.drowned
		
		current_lives -= 1
		current_word_progression = 0
		
		_start_tracks()
		await _reset_frog()
	else:
		track.stop()
		track.is_cleared = true
		current_word_progression += 1


func _on_current_word_progression_changed() -> void:
	# Enables the next track
	for track: LilypadTrack in lilypad_tracks_container.get_children():
		if not track.is_cleared:
			track.is_enabled = true
			break


func _on_current_progression_changed() -> void:
	# Makes the frog jumps to the rock on the right
	frog.jump_to(end.global_position)
	await frog.jumped
	
	# Play the animation on each pad
	for track: LilypadTrack in lilypad_tracks_container.get_children():
		track.right()
	
	# Makes the frog jumps out of screen
	frog.jump_to(frog_despawn_point.global_position)
	await frog.jumped
	
	# Resets the frog position
	await _reset_frog()
	
	# Setups the next word
	super()

#endregion
