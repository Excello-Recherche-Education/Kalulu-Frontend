extends Control
class_name WrongFX

signal finished()

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

var is_playing: bool = false


func play() -> void:
	is_playing = true
	animation_player.play("wrong")
	audio_player.play()


func _on_animation_player_animation_finished(animation_name: StringName) -> void:
	if animation_name == "wrong":
		is_playing = false
		finished.emit()
