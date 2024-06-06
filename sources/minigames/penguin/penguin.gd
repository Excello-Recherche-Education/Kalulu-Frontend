extends Node2D


@onready var animation_player: AnimationPlayer = $AnimationPlayer

func idle():
	if randf() < 0.8:
		animation_player.play("idle")
	else:
		animation_player.play("idle2")


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "idle" or anim_name == "idle2":
		idle()
