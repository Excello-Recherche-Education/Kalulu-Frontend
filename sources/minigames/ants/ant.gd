extends Area2D
class_name Ant

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var anchor: Node2D = $Anchor


func idle() -> void:
	animation_player.play("idle_1")


func walk() -> void:
	animation_player.play("walk_1")


func _on_animation_player_animation_finished(animation_name: StringName) -> void:
	if animation_name == "idle_1":
		var r: float = randf()
		if r <= 0.5:
			animation_player.play("idle_2")
		else:
			animation_player.play("idle_1")
	
	if animation_name == "idle_2":
		animation_player.play("idle_1")
	
	if animation_name == "walk_1":
		var r: float = randf()
		if r <= 0.5:
			animation_player.play("walk_2")
		else:
			animation_player.play("walk_1")
	
	if animation_name == "walk_2":
		animation_player.play("walk_1")
