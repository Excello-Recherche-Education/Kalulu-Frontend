extends Node2D
class_name CrabHole

signal stimulus_hit(stimulus: Dictionary)
signal crab_despawned(stimulus: Dictionary)

const crab_class: = preload("res://sources/minigames/crabs/crab/crab.tscn")

@onready var hole_back: = $HoleBack
@onready var hole_front: = $HoleFront
@onready var mask: = $Mask
@onready var timer: = $Timer
@onready var crab_audio_stream_player: = $CrabAudioStreamPlayer2D

var crab: Crab
var crab_hit: = false
var crab_spawned: = false


func spawn_crab(stimulus: Dictionary) -> void:
	crab_spawned = true
	
	crab = crab_class.instantiate()
	mask.add_child(crab)
	
	crab.connect("crab_hit", _crab_hit)
	
	crab.position = Vector2(0, 200)
	crab.set_stimulus(stimulus)
	
	crab_audio_stream_player.start_playing()
	
	var first_tween: = create_tween()
	first_tween.tween_property(crab, "position", Vector2(0.0, 100.0), randf_range(0.25, 2.0))
	await first_tween.finished
	first_tween.kill()
	
	crab_audio_stream_player.stop_playing()
	
	timer.start(randf_range(0.25, 1.5))
	await timer.timeout
	
	crab_audio_stream_player.start_playing()
	
	var second_tween: = create_tween()
	second_tween.tween_property(crab, "position", Vector2(0.0, -50.0), 0.25)
	await second_tween.finished
	second_tween.kill()
	
	crab_audio_stream_player.stop_playing()
	
	crab_hit = false
	crab.set_button_active(true)
	
	timer.start(randf_range(1.0, 2.5))
	await timer.timeout
	
	crab.set_button_active(false)
	
	var final_tween: = create_tween()
	if crab_hit:
		final_tween.tween_property(crab, "position", Vector2(0.0, -200.0), 0.5)
		final_tween.parallel().tween_property(crab, "rotation_degrees", 540.0, 0.5)
	else:
		crab_audio_stream_player.start_playing()
	final_tween.tween_property(crab, "position", Vector2(0.0, 200.0), 0.25)
	await final_tween.finished
	
	crab_audio_stream_player.stop_playing()
	
	crab.queue_free()
	
	crab_spawned = false
	
	emit_signal("crab_despawned", stimulus)


func _crab_hit(stimulus: Dictionary) -> void:
	crab_hit = true
	crab.set_button_active(false)
	if not timer.is_stopped():
		timer.start(0.4)
	emit_signal("stimulus_hit", stimulus)
