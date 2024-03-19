extends Control
class_name RightFX

signal finished()

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func play() -> void:
	animation_player.play("right")


func _on_animation_player_animation_finished(animation_name: StringName) -> void:
	if animation_name == "right":
		finished.emit()
