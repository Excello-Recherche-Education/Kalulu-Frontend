class_name Frog
extends Control

signal drowned()
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

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var sprite: Sprite2D = $Sprite


func jump_to(destination: Vector2) -> void:
	animation_player.play("jump")
	
	var tween: Tween = create_tween()
	tween.tween_property(self, "global_position", destination, animation_player.get_animation("jump").length)


func drown() -> void:
	animation_player.play("drown")


func _play_jump_sound() -> void:
	audio_player.stream = JUMP_SOUNDS[randi() % JUMP_SOUNDS.size()]
	audio_player.play()


func _play_frog_sound() -> void:
	var rand: float = randf()
	if rand <= 0.75:
		audio_player.stream = FROG_SOUNDS[randi() % FROG_SOUNDS.size()]
		audio_player.play()


func _on_animation_player_animation_finished(animation_name: StringName) -> void:
	if animation_name == "drown":
		drowned.emit()
	
	if animation_name == "jump":
		animation_player.play("idle_side_1")
		jumped.emit()
	
	if animation_name == "idle_front_1":
		var rand: float = randf()
		if rand <= 0.5:
			animation_player.play("idle_front_1")
		else:
			animation_player.play("idle_front_2")
	
	if animation_name == "idle_front_2":
		animation_player.play("idle_front_1")
	
	if animation_name == "idle_side_1":
		var rand: float = randf()
		if rand <= 0.5:
			animation_player.play("idle_side_1")
		else:
			animation_player.play("idle_side_2")
	
	if animation_name == "idle_side_2":
		animation_player.play("idle_side_1")
