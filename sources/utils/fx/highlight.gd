@tool
class_name HighlightFX
extends Control

var is_playing: bool = false

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func play() -> void:
	is_playing = true
	animation_player.play("highlight")


func stop() -> void:
	is_playing = false
	animation_player.play("stop")
