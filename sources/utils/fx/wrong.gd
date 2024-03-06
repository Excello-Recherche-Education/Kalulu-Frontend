extends Control

signal finished()

@onready var animation_player: = $AnimationPlayer


func play() -> void:
	animation_player.play("wrong")


func _on_animation_player_animation_finished(animation_name: StringName) -> void:
	if animation_name == "wrong":
		finished.emit()
