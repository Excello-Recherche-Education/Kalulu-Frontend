extends Node2D

# Namespace
const Coconut: = preload("res://sources/minigames/monkeys/coconut.gd")

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var coconut: Coconut = $Marker2D/Coconut
@onready var catch_position: Marker2D = $CatchPosition


func catch(p_coconut: Coconut) -> void:
	p_coconut.hide()
	coconut.text = p_coconut.text
	await play("catch")


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "idle":
		if randf() < 0.25:
			animation_player.play("idle_blink")
		else:
			animation_player.play("idle")
	elif anim_name == "idle_blink":
		animation_player.play("idle")


func play(animation: String) -> void:
	animation_player.play(animation)
	await animation_player.animation_finished
	animation_player.play("idle")
