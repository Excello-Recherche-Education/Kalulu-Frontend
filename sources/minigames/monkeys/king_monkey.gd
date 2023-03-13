extends Node2D

@onready var animation_player: = $AnimationPlayer
@onready var coconut: = $Marker2D/Coconut
@onready var catch_position: = $CatchPosition


func catch(p_coconut: Node2D):
	p_coconut.hide()
	coconut.text = p_coconut.text
	animation_player.play("catch")
	await animation_player.animation_finished
	animation_player.play("idle")


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "idle":
		if randf() < 0.25:
			animation_player.play("idle_blink")
		else:
			animation_player.play("idle")
	elif anim_name == "idle_blink":
		animation_player.play("idle")


func start_right() -> void:
	animation_player.play("start_right")
	await animation_player.animation_finished


func finish_right() -> void:
	animation_player.play("finish_right")
	await animation_player.animation_finished
	animation_player.play("idle")


func start_wrong() -> void:
	animation_player.play("start_wrong")
	await animation_player.animation_finished


func finish_wrong() -> void:
	animation_player.play("finish_wrong")
	await animation_player.animation_finished
	animation_player.play("idle")


func read() -> void:
	animation_player.play("read")
	await animation_player.animation_finished
