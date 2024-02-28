extends Control

@onready var animation_player: = $AnimationPlayer


func play() -> void:
	animation_player.play("highlight")


func stop() -> void:
	animation_player.play("stop")
