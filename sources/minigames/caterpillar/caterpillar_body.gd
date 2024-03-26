@tool
extends Node2D
class_name CaterpillarBody

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func idle():
	animated_sprite.play("idle")


func walk():
	animated_sprite.play("walk")
