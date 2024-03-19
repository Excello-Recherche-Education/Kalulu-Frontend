extends Control
class_name HighlightFX

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var is_playing : bool = false

func play() -> void:
	is_playing = true
	animation_player.play("highlight")


func stop() -> void:
	is_playing = false
	animation_player.play("stop")
