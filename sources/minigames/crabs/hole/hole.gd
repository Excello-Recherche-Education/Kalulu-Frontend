extends Node2D
class_name Hole

signal stimulus_hit(stimulus: Dictionary)
signal crab_despawned()

const crab_scene: = preload("res://sources/minigames/crabs/crab/crab.tscn")

@onready var hole_back: = $HoleBack
@onready var hole_front: = $HoleFront
@onready var mask: = $Mask
@onready var timer: = $Timer
@onready var crab_audio_stream_player: = $CrabAudioStreamPlayer2D

var crab: Crab


func spawn_crab(stimulus: Dictionary) -> void:
	# Instantiate a new crab
	crab = crab_scene.instantiate()
	mask.add_child(crab)
	
	var crab_x : float = -crab.size.x / 2
	
	crab.position = Vector2(crab_x, 100)
	crab.stimulus = stimulus
	
	# Show the crab but not the stimulus
	crab_audio_stream_player.start_playing()
	var tween: = create_tween()
	tween.tween_property(crab, "position", Vector2(crab_x, 20), randf_range(0.25, 2.0))
	await tween.finished
	crab_audio_stream_player.stop_playing()
	
	timer.start(randf_range(0.25, 1.5))
	await timer.timeout
	
	# The crab gets completely out
	crab_audio_stream_player.start_playing()
	tween = create_tween()
	tween.tween_property(crab, "position", Vector2(crab_x, -130.0), 0.5)
	crab.set_button_active(true)
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
	crab_audio_stream_player.stop_playing()
	
	crab.queue_free()
	crab = null
	crab_despawned.emit()


func is_button_pressed_with_limit(future):
	var coroutine: = Coroutine.new()
	coroutine.add_future(crab.is_button_pressed)
	coroutine.add_future(future)
	await coroutine.join_either()
	if coroutine.return_value[0]:
		await _on_crab_hit(crab.stimulus)
		return true
	return false


func right() -> void:
	await crab.right()


func wrong() -> void:
	await crab.wrong()


func _on_crab_hit(stimulus: Dictionary) -> void:
	
	var crab_x : float = -crab.size.x / 2
	
	crab.set_button_active(false)
	crab_audio_stream_player.stop_playing()
	
	stimulus_hit.emit(stimulus)
	
	# Move the crab up and rotate
	var tween: = create_tween()
	tween.tween_property(crab, "position", Vector2(crab_x, -180), 0.5)
	# TODO FIX
	tween.parallel().tween_property(crab.animated_sprite, "rotation_degrees", 540.0, 0.5)
	await tween.finished

	# Make the crab disappear in the hole
	tween = create_tween()
	tween.tween_property(crab, "position", Vector2(crab_x, 100.0), 0.5)
	await tween.finished
	
	# No idea what this does
	if not timer.is_stopped():
		timer.start(0.4)
	
	crab.queue_free()
	crab = null
	
	crab_despawned.emit()
