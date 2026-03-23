class_name Frog
extends Control

signal jumped()

const JUMP_SOUNDS: Array[AudioStreamMP3] = [
	preload("res://assets/minigames/frog/audio/frog_jump_random_01.mp3"),
	preload("res://assets/minigames/frog/audio/frog_jump_random_02.mp3"),
	preload("res://assets/minigames/frog/audio/frog_jump_random_03.mp3"),
	preload("res://assets/minigames/frog/audio/frog_jump_random_04.mp3"),
	preload("res://assets/minigames/frog/audio/frog_jump_random_05.mp3"),
]
const FROG_SOUNDS: Array[AudioStreamMP3] = [
	preload("res://assets/minigames/frog/audio/frog_random_01.mp3"),
	preload("res://assets/minigames/frog/audio/frog_random_02.mp3"),
	preload("res://assets/minigames/frog/audio/frog_random_03.mp3"),
	preload("res://assets/minigames/frog/audio/frog_random_04.mp3"),
	preload("res://assets/minigames/frog/audio/frog_random_05.mp3"),
]
const FROG_SPLASH: AudioStreamMP3 = preload("res://assets/minigames/frog/audio/frog_splash.mp3")
const FROG_BUBBLE: AudioStreamMP3 = preload("res://assets/minigames/frog/audio/frog_bubble.mp3")
const JUMP_HEIGHT: float = 220.0

var blink_counter: int = 0
var blink_delay: int = 3
var blink_random: int = 3
var last_valid_position: Vector2

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D


func jump_to(destination: Vector2) -> void:
	animated_sprite.play("jump")
	var start: Vector2 = global_position
	var end: Vector2 = destination
	var duration: float = Utils.get_animation_duration(animated_sprite, "jump")
	# Apex is above the higher of the two points (smaller Y is higher in 2D)
	var apex_y: float = min(start.y, end.y) - JUMP_HEIGHT
	var tween: Tween = create_tween()
	tween.tween_method(
		func(time: float) -> void:
			# X: strictly linear over the whole jump
			var horizontal: float = lerpf(start.x, end.x, time)
			# Y: fast takeoff, slow near apex, then accelerating fall
			var vertical: float
			var weight: float
			if time < 0.5:
				weight = time / 0.5
				weight = ease(weight, -2.5) # ease-out: strong impulse at start
				vertical = lerpf(start.y, apex_y, weight)
			else:
				weight = (time - 0.5) / 0.5
				weight = ease(weight, 2.5) # ease-in: accelerates on descent
				vertical = lerpf(apex_y, end.y, weight)
			global_position = Vector2(horizontal, vertical),
		0.0,
		1.0,
		duration
	).set_trans(Tween.TRANS_LINEAR)
	_play_jump_sound()


func defeat() -> void:
	animated_sprite.play("flip_sad")
	await animated_sprite.animation_finished
	animated_sprite.play("defeat")
	audio_player.stream = FROG_SPLASH
	audio_player.play()
	await animated_sprite.animation_finished
	await audio_player.finished


func success() -> void:
	animated_sprite.play("success")
	last_valid_position = global_position


func win() -> void:
	await flip_happy()
	animated_sprite.play("idle_front")


func flip_happy() -> void:
	animated_sprite.play("flip_happy")
	await animated_sprite.animation_finished


func _play_jump_sound() -> void:
	audio_player.stream = JUMP_SOUNDS[randi() % JUMP_SOUNDS.size()]
	audio_player.play()


func play_frog_sound() -> void:
	var rand: float = randf()
	if rand <= 0.75:
		audio_player.stream = FROG_SOUNDS[randi() % FROG_SOUNDS.size()]
		audio_player.play()


func appear() -> void:
	global_position = last_valid_position
	animated_sprite.play("appear")
	audio_player.stream = FROG_BUBBLE
	audio_player.play()
	await animated_sprite.animation_finished
	await flip_happy()
	animated_sprite.play("idle_side")


func _on_animated_sprite_2d_animation_finished() -> void:
	match animated_sprite.animation:
		"idle_front":
			blink_counter -= 1
			if blink_counter <= 0:
				blink_counter = blink_delay + randi_range(0, blink_random)
				animated_sprite.play("idle_front_blink") 
			else: 
				animated_sprite.play("idle_front")
		"idle_front_blink":
			animated_sprite.play("idle_front")
		"idle_side":
			blink_counter -= 1
			if blink_counter <= 0:
				blink_counter = blink_delay + randi_range(0, blink_random)
				animated_sprite.play("idle_side_blink") 
			else: 
				animated_sprite.play("idle_side")
		"idle_side_blink":
			animated_sprite.play("idle_side")
		"success":
			animated_sprite.play("idle_side")
		"jump":
			animated_sprite.play("idle_side")
			jumped.emit()


func idle_boss() -> void:
	animated_sprite.play("idle_front")
	animated_sprite.stop()


func victory_boss() -> void:
	animated_sprite.play("idle_front")
