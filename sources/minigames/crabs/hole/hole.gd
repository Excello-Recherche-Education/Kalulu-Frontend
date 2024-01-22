extends Node2D

signal stimulus_hit(stimulus: Dictionary)
signal crab_despawned(stimulus: Dictionary)

const Crab: = preload("res://sources/minigames/crabs/crab/crab.gd")

@onready var hole_back: = $HoleBack
@onready var hole_front: = $HoleFront
@onready var mask: = $Mask
@onready var timer: = $Timer
@onready var crab_audio_stream_player: = $CrabAudioStreamPlayer2D

var crab: Crab


func spawn_crab(stimulus: Dictionary) -> void:
	crab = Crab.instantiate()
	mask.add_child(crab)
	
	crab.position = Vector2(0, 200)
	crab.stimulus = stimulus
	
	crab_audio_stream_player.start_playing()
	
	# Show the crab but not the stimulus
	var tween: = create_tween()
	tween.tween_property(crab, "position", Vector2(0.0, 100.0), randf_range(0.25, 2.0))
	await tween.finished
	
	crab_audio_stream_player.stop_playing()
	
	timer.start(randf_range(0.25, 1.5))
	await timer.timeout
	
	crab_audio_stream_player.start_playing()
	
	# The crab gets completely out
	tween = create_tween()
	tween.tween_property(crab, "position", Vector2(0.0, -50.0), 0.5)
	crab.set_button_active(true)
	if await is_button_pressed_with_limit(tween.finished):
		return
	
	crab_audio_stream_player.stop_playing()
	
	timer.start(randf_range(1.0, 2.5))
	if await is_button_pressed_with_limit(timer.timeout):
		return
	
	crab_audio_stream_player.start_playing()
	tween = create_tween()
	tween.tween_property(crab, "position", Vector2(0.0, 200.0), 0.5)
	if await is_button_pressed_with_limit(tween.finished):
		return
	
	crab.set_button_active(false)
	
	crab_audio_stream_player.stop_playing()
	
	crab.queue_free()
	crab = null
	
	crab_despawned.emit(stimulus)


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
	if is_instance_valid(crab):
		await crab.right()


func wrong() -> void:
	if is_instance_valid(crab):
		await crab.wrong()


func _on_crab_hit(stimulus: Dictionary) -> void:
	crab.set_button_active(false)
	crab_audio_stream_player.stop_playing()
	stimulus_hit.emit(stimulus)
	var tween: = create_tween()
	tween.tween_property(crab, "position", Vector2(0.0, -200.0), 0.5)
	tween.parallel().tween_property(crab, "rotation_degrees", 540.0, 0.5)
	await tween.finished
	tween = create_tween()
	tween.tween_property(crab, "position", Vector2(0.0, 200.0), 0.5)
	await tween.finished
	if not timer.is_stopped():
		timer.start(0.4)
	crab.queue_free()
	crab = null
	
	crab_despawned.emit(stimulus)
