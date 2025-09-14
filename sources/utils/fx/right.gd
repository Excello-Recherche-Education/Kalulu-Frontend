@tool
class_name RightFX
extends Control

signal finished()

var is_playing: bool = false

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D


func play() -> void:
	is_playing = true
	animation_player.play("right")
	audio_player.play()


func _on_animation_player_animation_finished(animation_name: StringName) -> void:
	if animation_name == "right":
		is_playing = false
		finished.emit()
