extends Control

signal drowned()
signal jumped()

@onready var animation_player: = $AnimationPlayer
@onready var sprite: = $Sprite


func jump_to(destination: Vector2) -> void:
	animation_player.play("jump")
	
	var tween: = create_tween()
	tween.tween_property(self, "global_position", destination, animation_player.get_animation("jump").length)


func drown() -> void:
	animation_player.play("drown")


func _on_animation_player_animation_finished(animation_name: StringName) -> void:
	if animation_name == "drown":
		drowned.emit()
	
	if animation_name == "jump":
		animation_player.play("idle_side_1")
		jumped.emit()
	
	if animation_name == "idle_front_1":
		var r: = randf()
		if r <= 0.5:
			animation_player.play("idle_front_1")
		else:
			animation_player.play("idle_front_2")
	
	if animation_name == "idle_front_2":
		animation_player.play("idle_front_1")
	
	if animation_name == "idle_side_1":
		var r: = randf()
		if r <= 0.5:
			animation_player.play("idle_side_1")
		else:
			animation_player.play("idle_side_2")
	
	if animation_name == "idle_side_2":
		animation_player.play("idle_side_1")
