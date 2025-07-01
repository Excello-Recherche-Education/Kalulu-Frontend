@tool
extends CanvasLayer

signal animation_finished(animation_name: StringName)

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var is_closed: bool = false

func open() -> void:
	if is_closed:
		is_closed = false
		animation_player.play("open")
		await animation_player.animation_finished


func close() -> void:
	if not is_closed:
		is_closed = true
		animation_player.play("close")
		await animation_player.animation_finished


func _on_animation_player_animation_finished(animation_name: StringName) -> void:
	animation_finished.emit(animation_name)
