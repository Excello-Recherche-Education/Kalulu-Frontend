extends Node2D
class_name Hole

signal stimulus_hit(stimulus: Dictionary)
signal crab_despawned()

const crab_scene: = preload("res://sources/minigames/crabs/crab/crab.tscn")

@onready var hole_back: = $HoleBack
@onready var hole_front: = $HoleFront
@onready var mask: = $Mask
@onready var sand_vfx: SandVFX = $SandVFX
@onready var timer: = $Timer
@onready var crab_audio_stream_player: = $CrabAudioStreamPlayer2D

var crab: Crab

var stimulus_heard: bool = false:
	set(value):
		stimulus_heard = value
		_set_crab_button_active(stimulus_heard and crab_visible)

var crab_visible: bool = false:
	set(value):
		crab_visible = value
		_set_crab_button_active(stimulus_heard and crab_visible)


func spawn_crab(stimulus: Dictionary) -> void:
	# Instantiate a new crab
	crab = crab_scene.instantiate()
	mask.add_child(crab)
	
	var crab_x : float = -crab.size.x / 2
	
	crab.position = Vector2(crab_x, 100)
	crab.stimulus = stimulus
	
	# Show the crab but not the stimulus
	sand_vfx.start()
	crab_audio_stream_player.start_playing()
	var tween: = create_tween()
	tween.tween_property(crab, "position", Vector2(crab_x, 20), randf_range(0.25, 2.0))
	await tween.finished
	crab_audio_stream_player.stop_playing()
	
	timer.start(randf_range(0.25, 1.5))
	await timer.timeout
	
	# The crab gets completely out
	sand_vfx.stop()
	crab_audio_stream_player.start_playing()
	tween = create_tween()
	tween.tween_property(crab, "position", Vector2(crab_x, -130.0), 0.5)
	crab_visible = true
	if await is_button_pressed_with_limit(tween.finished):
		return
	crab_audio_stream_player.stop_playing()
	
	timer.start(randf_range(1.0, 2.5))
	if await is_button_pressed_with_limit(timer.timeout):
		return
	
	# The crab disappears in the hole
	crab_audio_stream_player.start_playing()
	tween = create_tween()
	tween.tween_property(crab, "position", Vector2(crab_x, 100.0), 0.5)
	if await is_button_pressed_with_limit(tween.finished):
		return
	sand_vfx.play()
	crab_audio_stream_player.stop_playing()
	
	crab.queue_free()
	crab = null
	crab_despawned.emit()


func despawn_crab() -> void:
	var crab_x : float = -crab.size.x / 2
	
	crab_visible = false
	crab_audio_stream_player.stop_playing()
	
	# Move the crab up and rotate
	var tween: = create_tween()
	tween.tween_property(crab, "position", Vector2(crab_x, -180), 0.5)
	tween.parallel().tween_property(crab.body, "rotation_degrees", 540.0, 0.5)
	await tween.finished

	# Make the crab disappear in the hole
	tween = create_tween()
	tween.tween_property(crab, "position", Vector2(crab_x, 100.0), 0.5)
	await tween.finished
	sand_vfx.play()
	
	# No idea what this does
	if not timer.is_stopped():
		timer.start(0.4)
	
	crab.queue_free()
	crab = null
	
	crab_despawned.emit()


func is_button_pressed_with_limit(future) -> bool:
	var coroutine: = Coroutine.new()
	coroutine.add_future(crab.is_button_pressed)
	coroutine.add_future(future)
	await coroutine.join_either()
	if coroutine.return_value[0]:
		await _on_crab_hit(crab.stimulus)
		return true
	return false


func _set_crab_button_active(is_active : bool):
	if crab:
		crab.set_button_active(is_active)


func right() -> void:
	crab.right()
	despawn_crab()


func wrong() -> void:
	crab.wrong()
	despawn_crab()


func _on_crab_hit(stimulus: Dictionary) -> void:
	stimulus_hit.emit(stimulus)


func on_stimulus_heard(is_heard : bool):
	stimulus_heard = is_heard
