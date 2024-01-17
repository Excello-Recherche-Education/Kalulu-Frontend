extends Minigame

@export var difficulty: = 1
@export var lesson_nb: = 4

@onready var start: = %Start
@onready var end: = %End

@onready var frog_spawn_point: = %FrogSpawnPoint
@onready var frog_despawn_point: = %FrogDespawnPoint

@onready var lilypad_tracks_container: = %LilypadTracksContainer
@onready var frog: = %Frog

const lilypad_track_class: = preload("res://sources/minigames/frog/lilypad_track.tscn")

var current_word: Dictionary
var current_distractors: Array


func _find_stimuli_and_distractions() -> void:
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
			grapheme_distractions.append(Database.get_distractors_for_grapheme(GP.Grapheme, lesson_nb))
		distractions.append(grapheme_distractions)


func _start() -> void:
	_get_new_word()


func _get_new_word() -> void:
	if audio_player.playing:
		await audio_player.finished
	
	await _free_tracks()
	_update_current_word()
	_create_tracks()
	await _play_current_word()
	_start_tracks()


func _free_tracks() -> void:
	for track in lilypad_tracks_container.get_children():
		await track.delete()
	
	for track in lilypad_tracks_container.get_children():
		track.queue_free()


func _update_current_word() -> void:
	current_word = stimuli.pop_front()
	current_distractors = distractions.pop_front()


func _create_tracks() -> void:
	for i in range(current_word.GPs.size()):
		var track: = lilypad_track_class.instantiate()
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
	for track in lilypad_tracks_container.get_children():
		await track.reset()
		track.start()
	
	lilypad_tracks_container.get_child(0).is_enabled = true


func _play_current_word() -> void:
	audio_player.stream = Database.get_audio_stream_for_word(current_word.Word)
	audio_player.play()
	if audio_player.playing:
		await audio_player.finished


func _reset_frog() -> void:
	frog.global_position = frog_spawn_point.global_position
	frog.jump_to(start.global_position)
	await frog.jumped


func _on_track_lilypad_in_center(lilypad: Control, track: Control) -> void:
	frog.jump_to(lilypad.global_position)
	await frog.jumped
	
	if lilypad.is_distractor:
		lilypad.disappear()
		frog.drown()
		await frog.drowned
		
		current_lives -= 1
		
		_start_tracks()
		await _reset_frog()
	else:
		track.stop()
		track.is_cleared = true
		
		var all_cleared: = true
		for other_track in lilypad_tracks_container.get_children():
			if not other_track.is_cleared:
				all_cleared = false
				
				other_track.is_enabled = true
				break
		
		if all_cleared:
			frog.jump_to(end.global_position)
			await frog.jumped
			
			frog.jump_to(frog_despawn_point.global_position)
			await frog.jumped
			
			await _free_tracks()
			
			current_progression += 1


func _on_current_progression_changed() -> void:
	if stimuli.size() != 0:
		await _reset_frog()
		await _get_new_word()
	else:
		_win()
