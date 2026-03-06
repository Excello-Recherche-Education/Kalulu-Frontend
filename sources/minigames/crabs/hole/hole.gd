class_name Hole
extends Node2D

signal stimulus_hit(stimulus: Dictionary)
signal crab_despawned(is_stimulus: bool)
signal stop()
signal crab_out(hole: Hole)

const CRAB_SCENE: PackedScene = preload("res://sources/minigames/crabs/crab/crab.tscn")

var crab: Crab
var crab_x: float
var stimulus_heard: bool = false:
	set(value):
		stimulus_heard = value
		_set_crab_button_active(stimulus_heard and crab_visible)
var crab_visible: bool = false:
	set(value):
		crab_visible = value
		_set_crab_button_active(stimulus_heard and crab_visible)
var _movement_tween: Tween
var _crab_moving: bool = false
var _sand_hole_y: float

@onready var hole_back: Sprite2D = $HoleBack
@onready var hole_front: Sprite2D = $HoleFront
@onready var mask: Sprite2D = %Mask
@onready var sand_vfx: SandVFX = $SandVFX
@onready var timer: Timer = $Timer
@onready var crab_audio_stream_player: HoleAudioStreamPlayer = $CrabAudioStreamPlayer2D


func _ready() -> void:
	# Store the editor-placed Y as the fixed "hole mouth" position for sand bursts
	_sand_hole_y = sand_vfx.position.y


func _process(_delta: float) -> void:
	if not crab:
		if crab_audio_stream_player.is_playing:
			crab_audio_stream_player.stop_playing()
		return

	if _crab_moving:
		if not crab_audio_stream_player.is_playing:
			crab_audio_stream_player.start_playing()
		# Keep sand VFX at the crab's leg position (bottom of the Control rect in Hole space)
		sand_vfx.position.y = mask.position.y + crab.position.y + crab.size.y
	else:
		if crab_audio_stream_player.is_playing:
			crab_audio_stream_player.stop_playing()


func spawn_crab(gp: Dictionary, is_stimulus: bool) -> void:
	# Instantiate a new crab
	crab = CRAB_SCENE.instantiate()
	mask.add_child(crab)

	# Show the label immediately so the letter is visible as the crab emerges
	crab.show_label()

	crab_x = -crab.size.x / 2
	crab.position = Vector2(crab_x, crab.size.y / 2)
	crab.stimulus = gp

	# The letter is clickable as soon as the crab starts emerging
	crab_visible = true
	_crab_moving = true

	# One burst at the hole mouth, then loop follows the legs (via _process position update)
	sand_vfx.position.y = _sand_hole_y
	sand_vfx.start()

	# Show the crab (letter already visible)
	_movement_tween = create_tween()
	_movement_tween.tween_property(crab, "position", Vector2(crab_x, -crab.size.y/7), randf_range(0.25, 2.0))
	if await is_button_pressed_with_limit(_movement_tween.finished):
		return

	# Wait a bit before going fully out
	timer.start(randf_range(0.25, 1.5))
	if await is_button_pressed_with_limit(timer.timeout):
		return

	# The crab gets completely out — emit crab_out here for highlight timing
	crab_out.emit()
	_movement_tween = create_tween()
	_movement_tween.tween_property(crab, "position", Vector2(crab_x, -crab.size.y), 0.5)
	if await is_button_pressed_with_limit(_movement_tween.finished):
		return

	# Crab is fully out — stop emergence FX
	sand_vfx.stop()
	_crab_moving = false
	timer.start(randf_range(1.0, 2.5))
	if await is_button_pressed_with_limit(timer.timeout):
		return

	# Disable the button before the crab retreats into the hole
	crab_visible = false
	_crab_moving = true
	_movement_tween = create_tween()
	_movement_tween.tween_property(crab, "position", Vector2(crab_x, crab.size.y / 2), 0.5)
	if await is_button_pressed_with_limit(_movement_tween.finished):
		return

	# One burst at the hole mouth as the crab disappears
	sand_vfx.position.y = _sand_hole_y
	sand_vfx.play()

	# Destroy the crab
	crab.queue_free()
	crab = null

	# Emit the despawned signal
	crab_despawned.emit(is_stimulus)


func is_button_pressed_with_limit(future: Signal) -> bool:
	var coroutine: Coroutine = Coroutine.new()
	coroutine.add_future(crab.is_button_pressed)
	coroutine.add_future(_is_stopped)
	coroutine.add_future(future)
	await coroutine.join_either()

	# If the crab is pressed
	if coroutine.return_value[0]:
		# Stop any ongoing movement so the crab halts immediately
		if _movement_tween:
			_movement_tween.kill()
		timer.stop()
		await _on_crab_hit(crab.stimulus)
		return true

	# If the crab is stopped
	if coroutine.return_value[1]:
		if _movement_tween:
			_movement_tween.kill()
		timer.stop()
		sand_vfx.stop()

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


func _set_crab_button_active(is_active: bool) -> void:
	if crab:
		crab.set_button_active(is_active)

# ------------ Connections ------------

func _on_crab_hit(stimulus: Dictionary) -> void:

	# Prevent further clicks while the hit sequence plays
	crab_visible = false
	_crab_moving = true

	# Stop any looping sand FX
	sand_vfx.stop()

	# Emit the stimulus
	stimulus_hit.emit(stimulus)

	# Make the crab disappear in the hole
	var tween: Tween = create_tween()
	tween.tween_property(crab, "position", Vector2(crab_x, crab.size.y / 2), 0.5)
	await tween.finished

	# One burst at the hole mouth as the crab disappears
	sand_vfx.position.y = _sand_hole_y
	sand_vfx.play()

	crab.queue_free()
	crab = null


func on_stimulus_heard(is_heard: bool) -> void:
	stimulus_heard = is_heard


func _is_stopped() -> bool:
	await stop
	return true
