class_name Penguin
extends Node2D

const SNOWBALL_SCENE: PackedScene = preload("res://sources/minigames/penguin/snowball.tscn")

var throw_position: Vector2

@onready var snowball_start: Marker2D = $AnimatedSprite2D/Snowball_Start
@onready var audiostream_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _create_snowball() -> void:
	var snowball: Snowball = SNOWBALL_SCENE.instantiate()
	snowball.position = snowball_start.global_position
	snowball.target_position = throw_position - snowball_start.global_position
	audiostream_player.play()
	get_parent().add_child(snowball)

#region Animations

func idle() -> void:
	animated_sprite.play("idle")


func happy() -> void:
	animated_sprite.play("happy")
	await animated_sprite.animation_finished
	animated_sprite.play("happy")
	await animated_sprite.animation_finished


func sad() -> void:
	animated_sprite.play("sad")
	await animated_sprite.animation_finished
	animated_sprite.play("sad", -1.0)
	await animated_sprite.animation_finished


func throw(pos: Vector2) -> void:
	throw_position = pos
	animated_sprite.play("flip_right")
	await animated_sprite.animation_finished
	_create_snowball()
	animated_sprite.play("throw")
	await animated_sprite.animation_finished
	animated_sprite.play("flip_left")
	await animated_sprite.animation_finished
	idle()

#endregion

func idle_boss() -> void:
	animated_sprite.play("idle")
	animated_sprite.stop()


func victory_boss() -> void:
	animated_sprite.play("happy")
