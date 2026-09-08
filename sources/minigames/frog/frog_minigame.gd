class_name FrogMinigame
extends WordsMinigame

const RIVER_SCENE_PATH: String = "res://sources/minigames/frog/river.tscn"
const FROG_SCENE_PATH: String = "res://sources/minigames/frog/frog.tscn"
const LILYPAD_TRACK_SCENE_PATH: String = "res://sources/minigames/frog/lilypad_track.tscn"

var difficulty_settings: Array[DifficultySettings] = [
	DifficultySettings.new(0.75, 100., 200.),
	DifficultySettings.new(0.66, 150., 250.),
	DifficultySettings.new(0.33, 200., 300.),
	DifficultySettings.new(0.25, 250., 350.),
	DifficultySettings.new(0.25, 300., 400.)
]
var river: River
var frog: Frog
var lilypad_track_scene: PackedScene

@onready var start: Control = %Start
@onready var end: Control = %End
@onready var frog_spawn_point: Control = %FrogSpawnPoint
@onready var frog_despawn_point: Control = %FrogDespawnPoint
@onready var lilypad_tracks_container: HBoxContainer = %LilypadTracksContainer


func _setup_minigame() -> void:
	super()
	await _instantiate_subscenes()


func _instantiate_subscenes() -> void:
	var background_node: Control = $GameRoot/Background
	var game_root_node: Control = $GameRoot

	await get_tree().process_frame
	if not is_inside_tree():
		return

	# The river is the same kind of decoration as the turtles' sea: a painted
	# background under a drift shader, with rings on top. See HeavyGraphics.
	var river_scene: PackedScene = HeavyGraphics.load_resource(RIVER_SCENE_PATH) as PackedScene
	if river_scene:
		river = river_scene.instantiate()
		river.name = "River"
		background_node.add_child(river)
		background_node.move_child(river, 0)

	await get_tree().process_frame
	if not is_inside_tree():
		return

	frog = (load(FROG_SCENE_PATH) as PackedScene).instantiate()
	frog.name = "Frog"
	frog.offset_left = 360.0
	frog.offset_top = 900.0
	frog.offset_right = 360.0
	frog.offset_bottom = 900.0
	game_root_node.add_child(frog)

	await get_tree().process_frame
	if not is_inside_tree():
		return

	lilypad_track_scene = load(LILYPAD_TRACK_SCENE_PATH) as PackedScene


func _setup_word_progression() -> void:
	super()
	_create_tracks()
	_start_tracks()


func _start() -> void:
	super()
	fireworks.set_colors([Color("#bca4ff"), Color("#f5a8c8"), Color("#ffbf94")])
	frog.last_valid_position = frog.global_position


func _highlight() -> void:
	for track: LilypadTrack in lilypad_tracks_container.get_children():
		if track.is_enabled:
			track.is_highlighting = true
			break


func _reset_frog() -> void:
	frog.global_position = frog_spawn_point.global_position
	frog.last_valid_position = start.global_position
	frog.jump_to(start.global_position)
	await frog.jumped

#region Tracks management

func _free_tracks() -> void:
	var tracks: Array = lilypad_tracks_container.get_children()
	var tracks_count: int = tracks.size()
	for index: int in tracks_count:
		var track: LilypadTrack = tracks[index]
		if index == tracks_count - 1:
			await track.reset()
		else:
			track.reset()
	for track: LilypadTrack in lilypad_tracks_container.get_children():
		track.queue_free()
		await track.tree_exited


func _create_tracks() -> void:
	var current_word: Dictionary = _get_current_stimulus()
	var current_distractors: Array = _get_current_distractors()
	for index: int in range((current_word.GPs as Array).size()):
		var track: LilypadTrack = lilypad_track_scene.instantiate()
		lilypad_tracks_container.add_child(track)
		track.difficulty_settings = difficulty_settings[difficulty]
		track.gp = current_word.GPs[index]
		track.distractors = current_distractors[index]
		track.distractors_queue_size = distractors_queue_size
		track.lilypad_in_center.connect(_on_track_lilypad_in_center.bind(track))


func _start_tracks() -> void:
	var tracks: Array[Node] = lilypad_tracks_container.get_children()
	var last_valid_index: int = -1
	for index: int in tracks.size():
		if index >= current_word_progression:
			last_valid_index = index
	if last_valid_index == -1:
		return
	for index: int in tracks.size():
		if index < current_word_progression:
			continue
		var track: LilypadTrack = tracks[index]
		if index == last_valid_index:
			await track.reset()
		else:
			track.reset()
	var is_first_track_enabled: bool = false
	for index: int in tracks.size():
		if index < current_word_progression:
			continue
		if not is_first_track_enabled:
			(tracks[index] as LilypadTrack).is_enabled = true
			is_first_track_enabled = true
	for index: int in tracks.size():
		if index < current_word_progression:
			continue
		(tracks[index] as LilypadTrack).start()

#endregion

#region Connections

func _on_track_lilypad_in_center(lilypad: Lilypad, track: LilypadTrack) -> void:
	_log_new_response_and_score(lilypad.stimulus)
	# Disable the tracks
	track.stop()
	frog.jump_to(lilypad.global_position)
	await frog.jumped
	if river:
		river.spawn_water_ring(lilypad.global_position)
	if lilypad.is_distractor:
		await lilypad.wrong()
		await audio_player.play_gp(lilypad.stimulus)
		lilypad.disappear()
		await frog.defeat()
		current_lives -= 1
		_start_tracks()
		await frog.appear()
	else:
		track.is_highlighting = false
		track.is_cleared = true
		track.is_enabled = false
		frog.success()
		await lilypad.right()
		await audio_player.play_gp(lilypad.stimulus)
		current_word_progression += 1


func _on_current_word_progression_changed() -> void:
	# Enables the next track
	frog.play_frog_sound()
	for track: LilypadTrack in lilypad_tracks_container.get_children():
		if not track.is_cleared:
			track.is_enabled = true
			break


func _on_current_progression_changed() -> void:
	var is_final_word: bool = current_progression >= max_progression
	frog.jump_to(end.global_position)
	await frog.jumped
	frog.win()
	for track: LilypadTrack in lilypad_tracks_container.get_children():
		track.right()
	await audio_player.play_word(_get_previous_stimulus().Word as String)
	if is_final_word:
		super()
		return
	await frog.flip_happy()
	frog.jump_to(frog_despawn_point.global_position)
	await frog.jumped
	await _free_tracks()
	await _reset_frog()
	super()


func set_current_progression(p_current_progression: int) -> void:
	var previous_progression: int = current_progression
	current_progression = p_current_progression
	Log.debug("BaseMinigame: Progression changed from %d to %d/%d for %s" % [previous_progression, current_progression, max_progression, TYPE_NAMES[minigame_name]])

	consecutive_errors = 0
	is_highlighting = false

	if minigame_ui:
		minigame_ui.set_progression(p_current_progression)
	if p_current_progression == max_progression and previous_progression != max_progression:
		await _on_current_progression_changed()
		await _win()
	else:
		await _on_current_progression_changed()

#endregion

class DifficultySettings:
	var stimuli_ratio: float = 0.75
	var pads_speed_disabled: float = 100.0
	var pads_speed: float = 200.0
	
	
	func _init(p_stimuli_ratio: float, p_pads_speed_disabled: float, p_pads_speed: float) -> void:
		stimuli_ratio = p_stimuli_ratio
		pads_speed_disabled = p_pads_speed_disabled
		pads_speed = p_pads_speed
