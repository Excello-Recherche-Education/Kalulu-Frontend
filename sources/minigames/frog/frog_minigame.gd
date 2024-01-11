extends Minigame

const lilypad_track_class: = preload("res://sources/minigames/frog/lilypad_track/lilypad_track.tscn")

@export var difficulty: = 1
@export var lesson_nb: = 4

@onready var frog: = $GameRoot/Frog
@onready var start_area: = $GameRoot/Start/Area2D
@onready var end_area: = $GameRoot/End/Area2D
@onready var river_container: = $GameRoot/RiverContainer

var lilypad_tracks: Array
var current_word: Dictionary
var current_distractors: Array
var end_areas: = []


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


func _on_current_progression_changed() -> void:
	if stimuli.size() != 0:
		await _get_new_word()
		_reset_frog()
		end_areas = []
	else:
		_win()


func _get_new_word() -> void:
	if audio_player.playing:
		await audio_player.finished
	
	await _free_tracks()
	_update_current_word()
	_create_tracks()
	await _play_current_word()
	# Await a frame so the tracks can occupy all the river container
	await get_tree().process_frame
	_start_tracks()


func _free_tracks() -> void:
	if lilypad_tracks.size() != 0:
		for track in lilypad_tracks:
			track.disappear()
		await lilypad_tracks[lilypad_tracks.size() - 1].disappeared
		for track in lilypad_tracks:
			track.queue_free()
		lilypad_tracks = []


func _update_current_word() -> void:
	current_word = stimuli.pop_front()
	current_distractors = distractions.pop_front()


func _create_tracks() -> void:
	lilypad_tracks = []
	for i in range(current_word.GPs.size()):
		var track: = lilypad_track_class.instantiate()
		river_container.add_child(track)
		lilypad_tracks.append(track)
		
		var track_stimuli: = [current_word.GPs[i]]
		track_stimuli.append_array(current_distractors[i])
		var are_distractors: = [false]
		for _j in range(track_stimuli.size() - 1):
			are_distractors.append(true)
		track.stimuli = track_stimuli
		track.are_they_distractors = are_distractors
		track.top_to_bottom = i % 2
	
	lilypad_tracks[current_word.GPs.size() - 1].cleared.connect(_on_last_lilypad_cleared)


func _play_current_word() -> void:
	audio_player.stream = Database.get_audio_stream_for_word(current_word.Word)
	audio_player.play()
	if audio_player.playing:
		await audio_player.finished


func _start_tracks() -> void:
	for track in lilypad_tracks:
		track.ready_to_spawn = true


func _reset_frog() -> void:
	frog._reset()
	frog.global_position = start_area.global_position


func _on_frog_flooded() -> void:
	_reset_frog()
	
	current_lives -= 1
	
	for track in lilypad_tracks:
		track.restart()


func _on_last_lilypad_cleared() -> void:
	frog.can_jump = false
	
	await get_tree().create_timer(1.0).timeout
	
	frog.can_jump = true
	frog._jump(Vector2.RIGHT)


func _on_end_area_area_entered(area: Area2D) -> void:
	if not area in end_areas:
		end_areas.append(area)
		var all_cleared: = true
		for track in lilypad_tracks:
			all_cleared = all_cleared and track.is_cleared
		
		if all_cleared:
			current_progression += 1
