@tool
extends Node2D
class_name CaterpillarHead

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	idle()


func idle():
	if randf() < 0.8:
		animated_sprite.play("idle1")
	else:
		animated_sprite.play("idle2")


func eat():
	animated_sprite.play("eat")


func spit():
	animated_sprite.play("spit")


func _on_animation_finished():
	idle()
