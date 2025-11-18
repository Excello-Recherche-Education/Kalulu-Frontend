class_name KingMonkey
extends Node2D

var blink_counter: int = 0
var blink_delay: int = 3
var blink_random: int = 3
var catch_animation_name: String = "catch"
var catch_time: float = 1.0
var throw_time: float = 1.0
var coconut: Coconut = null

@onready var catch_position: Marker2D = $CatchPosition
@onready var read_position: Marker2D = $ReadPosition
@onready var throw_position: Marker2D = $ThrowPosition
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	catch_time = Utils.get_animation_duration(animated_sprite_2d, catch_animation_name)
	throw_time = Utils.get_animation_duration(animated_sprite_2d, catch_animation_name)


func catch(p_coconut: Coconut) -> void:
	animated_sprite_2d.play(catch_animation_name)
	coconut = p_coconut
	var start: Vector2 = p_coconut.global_position
	var end: Vector2 = read_position.global_position
	var height: float = 200.0
	var tween: Tween = create_tween()
	tween.tween_method(
		func(time: float) -> void:
			p_coconut.global_position = _parabola(start, end, height, time),
		0.0,
		1.0,
		catch_time
	).set_trans(Tween.TRANS_LINEAR)
	animated_sprite_2d.play_backwards(catch_animation_name)
	await animated_sprite_2d.animation_finished
	animated_sprite_2d.play("idle")


func _parabola(start: Vector2, end: Vector2, height: float, time: float) -> Vector2:
	var point: Vector2 = start.lerp(end, time)
	point.y -= height * 4.0 * time * (1.0 - time) 
	return point


func play(animation: String) -> void:
	Log.trace("KingMonkey: Play animation %s" % animation)
	if animation == "start_right":
		if coconut:
			var tween: Tween = create_tween()
			tween.tween_property(coconut, "global_position", throw_position.global_position, throw_time/2)
		else:
			Log.warn("KingMonkey: play animation start_right with no coconut")
	animated_sprite_2d.play(animation)
	await animated_sprite_2d.animation_finished
	animated_sprite_2d.play("idle")


func _on_animated_sprite_2d_animation_finished() -> void:
	match animated_sprite_2d.animation:
		"idle":
			blink_counter -= 1
			if blink_counter <= 0:
				blink_counter = blink_delay + randi_range(0, blink_random)
				animated_sprite_2d.play("idle_blink")
			else:
				animated_sprite_2d.play("idle")
		"idle_blink":
			animated_sprite_2d.play("idle")
