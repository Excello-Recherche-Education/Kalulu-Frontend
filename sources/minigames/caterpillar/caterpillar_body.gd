@tool
extends Node2D
class_name CaterpillarBody

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var label: Label = $Label
@onready var right_FX:= $RightFX

var gp: Dictionary:
	set(value):
		gp = value
		if gp.has("Grapheme"):
			label.text = gp.Grapheme
		else:
			label.text = ""


func idle():
	animated_sprite.play("idle")


func walk():
	animated_sprite.play("walk")


func right() -> void:
	right_FX.play()
	await right_FX.finished
