extends CanvasLayer

signal animation_finished(animation_name: StringName)

@onready var animation_player: = $AnimationPlayer


func play(animation_name: String) -> void:
	animation_player.play(animation_name)


func _on_animation_player_animation_finished(animation_name: StringName) -> void:
	emit_signal("animation_finished", animation_name)
