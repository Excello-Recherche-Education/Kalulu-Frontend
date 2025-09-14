class_name Turtle
extends Node2D

signal pressed(gp: Dictionary)
signal animation_changed(position: Vector2)

var gp: Dictionary = {}:
	set(value):
		gp = value
		if gp and gp.has("Grapheme"):
			label.text = gp.Grapheme
		else:
			label.text = ""
var velocity: float = 0.
var direction: Vector2 = Vector2(0,-1):
	set = _set_direction
var is_moving: bool = true
var is_changing_direction: bool = false
var is_visible_on_screen: bool = false

@onready var body: Node2D = $Body
@onready var sprite: AnimatedSprite2D = $Body/AnimatedSprite2D
@onready var label: Label = $Label
@onready var head_area_collision_shape: CollisionShape2D = $Body/HeadArea/CollisionShape2D
@onready var body_area_collision_shape: CollisionShape2D = $Body/BodyArea/CollisionShape2D
@onready var highlight_fx: HighlightFX = $HighlightFX
@onready var right_fx: RightFX = $RightFX
@onready var wrong_fx: WrongFX = $WrongFX
@onready var delete_timer: Timer = $DeleteTimer
@onready var audio_stream_player: AudioStreamPlayer2D = $AudioStreamPlayer2D


func _process(delta: float) -> void:
	if is_moving:
		position += velocity * delta * direction


func _set_direction(new_direction: Vector2) -> void:
	
	is_changing_direction = true
	
	# Get the angle difference between the old and new direction
	var angle_to: float = rad_to_deg(direction.angle_to(new_direction))

	# Calculate the new angle of the body - this allows to get the closest angle for tweening
	var angle: float = body.rotation_degrees + rad_to_deg(direction.angle_to(new_direction))

	# Changes the direction
	direction = new_direction
	
	# Play turn animations	
	if angle_to > 0:
		sprite.play("swim_right")
	else:
		sprite.play("swim_left")

	# Tween the rotation of the body
	var tween: Tween = create_tween()
	tween.tween_property(body, "rotation_degrees", angle, sprite.sprite_frames.get_frame_count(sprite.animation) /sprite.sprite_frames.get_animation_speed(sprite.animation))
	await tween.finished
	
	is_changing_direction = false

#region Actions

func highlight(value: bool = true) -> void:
	if value:
		highlight_fx.play()
	else:
		highlight_fx.stop()


func right() -> void:
	is_moving = false
	sprite.play("victory")
	right_fx.play()
	await right_fx.finished


func wrong() -> void:
	is_moving = false
	wrong_fx.play()
	await wrong_fx.finished


func disappear() -> void:
	is_moving = false
	head_area_collision_shape.set_deferred("disabled", true)
	body_area_collision_shape.set_deferred("disabled", true)
	await get_tree().create_timer(randf_range(0., 0.2)).timeout
	sprite.play("disappear")
	var tween: Tween = create_tween()
	tween.tween_property(label, "modulate:a", 0, sprite.sprite_frames.get_frame_count(sprite.animation) /sprite.sprite_frames.get_animation_speed(sprite.animation))

#endregion

#region Connections

func _on_swipe_detector_swipe(start_position: Vector2, end_position: Vector2) -> void:
	if not is_moving or is_changing_direction:
		return
	
	# Change the direction toward the swipe
	direction = start_position.direction_to(end_position)
	
	if not audio_stream_player.playing:
		audio_stream_player.play()


func _on_swipe_detector_pressed() -> void:
	pressed.emit(gp)


func _on_animated_sprite_2d_animation_changed() -> void:
	if is_visible_on_screen:
		animation_changed.emit(global_position)


func _on_animated_sprite_2d_animation_finished() -> void:
	if sprite.animation in ["swim_left", "swim_right"]:
		sprite.play("swim")
	elif sprite.animation == "disappear":
		var coroutine: Coroutine = Coroutine.new()
		audio_stream_player.play()
		if audio_stream_player.playing:
			coroutine.add_future(audio_stream_player.finished)
		if right_fx.is_playing:
			coroutine.add_future(right_fx.finished)
		if wrong_fx.is_playing:
			coroutine.add_future(wrong_fx.finished)
		
		await coroutine.join_all()
		queue_free()


func _on_visible_on_screen_notifier_2d_screen_entered() -> void:
	is_visible_on_screen = true


func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	is_visible_on_screen = false
	delete_timer.start()


func _on_delete_timer_timeout() -> void:
	if not is_visible_on_screen:
		queue_free()


func _on_body_area_area_entered(_area: Area2D) -> void:
	disappear()

#endregion
