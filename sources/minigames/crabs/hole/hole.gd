extends Node2D
class_name Hole

signal stimulus_hit(stimulus: Dictionary)
signal crab_despawned(is_stimulus: bool)
signal stop()
signal crab_out(hole: Hole)

const CRAB_SCENE: PackedScene = preload("res://sources/minigames/crabs/crab/crab.tscn")

@onready var hole_back: Sprite2D = $HoleBack
@onready var hole_front: Sprite2D = $HoleFront
@onready var mask: Sprite2D = %Mask
@onready var sand_vfx: SandVFX = $SandVFX
@onready var timer: Timer = $Timer
@onready var crab_audio_stream_player: HoleAudioStreamPlayer = $CrabAudioStreamPlayer2D

var crab: Crab
var crab_x : float
var stimulus_heard: bool = false:
	set(value):
		stimulus_heard = value
		_set_crab_button_active(stimulus_heard and crab_visible)
var crab_visible: bool = false:
	set(value):
		crab_visible = value
		_set_crab_button_active(stimulus_heard and crab_visible)
var is_stimulus: bool = false


func _process(_delta : float) -> void:
	if not crab:
		if sand_vfx.is_playing:
			sand_vfx.stop()
		
		if crab_audio_stream_player.is_playing:
			crab_audio_stream_player.stop_playing()
		
		return
	
	# Handles the sounds and VFX when the crab is not out yet
	if crab.position.y > -crab.size.y:
		if crab_visible:
			crab_visible = false
		
		if not sand_vfx.is_playing:
			sand_vfx.start()
		
		if not crab_audio_stream_player.is_playing:
			crab_audio_stream_player.start_playing()
	# Handles the sounds and VFX when the crab is out
	else:
		if not crab_visible:
			crab_visible = true
		
		if sand_vfx.is_playing:
			sand_vfx.stop()
		
		if crab_audio_stream_player.is_playing:
			crab_audio_stream_player.stop_playing()


func spawn_crab(gp: Dictionary, p_is_stimulus: bool) -> void:
	
	self.is_stimulus = p_is_stimulus
	
	# Instantiate a new crab
	crab = CRAB_SCENE.instantiate()
	mask.add_child(crab)
	
	crab.hide_label()
	
	crab_x = -crab.size.x / 2
	crab.position = Vector2(crab_x, crab.size.y / 2)
	crab.stimulus = gp
	
	# Show the crab but not the stimulus
	var tween: Tween = create_tween()
	tween.tween_property(crab, "position", Vector2(crab_x, -crab.size.y/7), randf_range(0.25, 2.0))
	if await is_button_pressed_with_limit(tween.finished):
		return
	
	# Wait a bit before going out
	timer.start(randf_range(0.25, 1.5))
	if await is_button_pressed_with_limit(timer.timeout):
		return
	
	# The crab gets completely out
	crab.show_label()
	crab_out.emit()
	tween = create_tween()
	tween.tween_property(crab, "position", Vector2(crab_x, -crab.size.y), 0.5)
	if await is_button_pressed_with_limit(tween.finished):
		return
	
	timer.start(randf_range(1.0, 2.5))
	if await is_button_pressed_with_limit(timer.timeout):
		return
	
	# The crab disappears in the hole
	tween = create_tween()
	tween.tween_property(crab, "position", Vector2(crab_x, crab.size.y / 2), 0.5)
	if await is_button_pressed_with_limit(tween.finished):
		return
	
	# Destroy the crab
	crab.queue_free()
	crab = null
	
	# Emit the despawned signal
	crab_despawned.emit(p_is_stimulus)


func is_button_pressed_with_limit(future : Signal) -> bool:
	var coroutine: Coroutine = Coroutine.new()
	coroutine.add_future(crab.is_button_pressed)
	coroutine.add_future(_is_stopped)
	coroutine.add_future(future)
	await coroutine.join_either()
	
	# If the crab is pressed
	if coroutine.return_value[0]:
		await _on_crab_hit(crab.stimulus)
		return true
	
	# If the crab is stopped
	if coroutine.return_value[1]:
		
		# Make the crab disappear in the hole
		var tween: Tween = create_tween()
		tween.tween_property(crab, "position", Vector2(crab_x, crab.size.y / 2), 0.5)
		await tween.finished
		
		crab.queue_free()
		crab = null
		
		return true
	return false


func highlight() -> void:
	crab.highlight()


func right() -> void:
	crab.right()


func wrong() -> void:
	crab.wrong()


func _set_crab_button_active(is_active : bool) -> void:
	if crab:
		crab.set_button_active(is_active)


# ------------ Connections ------------


func _on_crab_hit(stimulus: Dictionary) -> void:
	
	crab.reparent(self)
	
	# Emit the stimulus
	stimulus_hit.emit(stimulus)
	
	# Move the crab up and rotate
	var tween: Tween = create_tween()
	tween.tween_property(crab, "position", Vector2(crab_x, -crab.size.y * 1.5), 1)
	tween.parallel().tween_property(crab.body, "rotation_degrees", 900.0, 1)
	await tween.finished

	crab.reparent(mask)
	
	# Make the crab disappear in the hole
	tween = create_tween()
	tween.tween_property(crab, "position", Vector2(crab_x, crab.size.y / 2), 0.5)
	await tween.finished
	
	crab.queue_free()
	crab = null


func on_stimulus_heard(is_heard : bool) -> void:
	stimulus_heard = is_heard


func _is_stopped() -> bool:
	await stop
	return true
