class_name Turtle
extends Node2D

signal pressed(gp: Dictionary)
signal animation_changed(position: Vector2)

const TURTLE_BACK_RIGHT: CompressedTexture2D = preload("res://assets/minigames/turtles/graphic/turtle_back_right.png")
const TURTLE_BACK_WRONG: CompressedTexture2D = preload("res://assets/minigames/turtles/graphic/turtle_back_wrong.png")
# Only used when a turtle lands on the island, so they're instantiated on
# demand instead of sitting idle inside every spawned turtle.
const RIGHT_FX_SCENE: PackedScene = preload("res://sources/utils/fx/right.tscn")
const WRONG_FX_SCENE: PackedScene = preload("res://sources/utils/fx/wrong.tscn")
const RIGHT_STARS_SCENE: PackedScene = preload("res://sources/utils/fx/right_stars.tscn")

# Set by the minigame after the random color is picked, so only one of the three
# 6400x4800 turtle spritesheets is ever in memory.
@export var sprite_frames: SpriteFrames:
	set(value):
		sprite_frames = value
		if sprite and value:
			sprite.sprite_frames = value
			sprite.play("swim")

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
var right_fx: RightFX
var right_stars: RightStarsFX
var wrong_fx: WrongFX

@onready var body: Node2D = $Body
@onready var body_back: Sprite2D = $Body/AnimatedSprite2D/Sprite2D_Back
@onready var sprite: AnimatedSprite2D = %AnimatedSprite2D
@onready var label: Label = $Label
@onready var head_area_collision_shape: CollisionShape2D = $Body/HeadArea/CollisionShape2D
@onready var body_area_collision_shape: CollisionShape2D = $Body/BodyArea/CollisionShape2D
@onready var highlight_fx: HighlightFX = %HighlightFX
@onready var back_fx: Control = $BackFX
@onready var front_fx: Control = $FrontFX
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


func _ensure_right_fx() -> void:
	if right_fx:
		return
	right_fx = RIGHT_FX_SCENE.instantiate()
	right_fx.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	right_fx.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	right_fx.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back_fx.add_child(right_fx)
	right_stars = RIGHT_STARS_SCENE.instantiate()
	front_fx.add_child(right_stars)


func _ensure_wrong_fx() -> void:
	if wrong_fx:
		return
	wrong_fx = WRONG_FX_SCENE.instantiate()
	wrong_fx.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	wrong_fx.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrong_fx.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back_fx.add_child(wrong_fx)


func right() -> void:
	is_moving = false
	change_font_color_after_collision()
	body_back.texture = TURTLE_BACK_RIGHT
	sprite.play("victory")
	await sprite.animation_finished
	sprite.play_backwards("victory")
	_ensure_right_fx()
	right_fx.play()
	right_stars.play()
	await sprite.animation_finished
	await right_fx.finished


func wrong() -> void:
	is_moving = false
	change_font_color_after_collision()
	body_back.texture = TURTLE_BACK_WRONG
	_ensure_wrong_fx()
	wrong_fx.play()
	sprite.play("defeat")
	await sprite.animation_finished
	sprite.play_backwards("defeat")
	await sprite.animation_finished


func change_font_color_after_collision() -> void:
	label.label_settings = label.label_settings.duplicate()
	label.label_settings.font_color = Minigame.LABEL_COLOR_NEUTRAL


func disappear(fast: bool = false) -> void:
	is_moving = false
	head_area_collision_shape.set_deferred("disabled", true)
	body_area_collision_shape.set_deferred("disabled", true)
	var speed_scale: float = 3.0 if fast else 1.0
	if fast:
		sprite.speed_scale = speed_scale
	else:
		await get_tree().create_timer(randf_range(0.1, 0.2)).timeout
	sprite.play("disappear")
	var fade_duration: float = sprite.sprite_frames.get_frame_count(sprite.animation) / sprite.sprite_frames.get_animation_speed(sprite.animation) / speed_scale
	var tween: Tween = create_tween()
	tween.tween_property(label, "modulate:a", 0, fade_duration)
	var tween2: Tween = create_tween()
	tween2.tween_property(body_back, "modulate:a", 0, fade_duration)

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
	disappear(true)

#endregion

func idle_boss() -> void:
	sprite.play("swim")
	sprite.stop()


func victory_boss() -> void:
	sprite.play("swim")
