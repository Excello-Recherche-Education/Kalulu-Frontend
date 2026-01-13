class_name Firework
extends Node2D

signal finished()

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D


func play(color: Color, sprite_scale: float) -> void:
	apply_scale(Vector2(sprite_scale, sprite_scale))
	animated_sprite_2d.self_modulate = color
	animated_sprite_2d.play("default")
	await animated_sprite_2d.animation_finished
	finished.emit()
