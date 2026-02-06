class_name Ant
extends Area2D

@onready var anchor: Node2D = $Anchor
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D


func idle() -> void:
	animated_sprite_2d.play("idle")


func walk() -> void:
	animated_sprite_2d.play("walk")


func success() -> void:
	animated_sprite_2d.play("success")


func defeat() -> void:
	animated_sprite_2d.play("defeat")
	await animated_sprite_2d.animation_finished
	await get_tree().create_timer(1.0).timeout
	animated_sprite_2d.play_backwards("defeat")
	await animated_sprite_2d.animation_finished
	idle()


func idle_boss() -> void:
	animated_sprite_2d.play("idle")
	animated_sprite_2d.stop()


func victory_boss() -> void:
	animated_sprite_2d.play("success")
