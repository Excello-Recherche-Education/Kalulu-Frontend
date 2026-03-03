@tool
class_name HighlightFX
extends Control

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func play() -> void:
	animation_player.play("highlight")


func stop() -> void:
	animation_player.play("stop")
