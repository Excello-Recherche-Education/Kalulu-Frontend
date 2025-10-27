@tool
class_name CaterpillarBody
extends Node2D

var gp: Dictionary = {}:
	set(value):
		gp = value
		if gp.has("Grapheme"):
			label.text = gp.Grapheme
		else:
			label.text = ""

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var label: Label = $Label
@onready var right_FX: RightFX = $RightFX


func _ready() -> void:
	walk()


func idle() -> void:
	animated_sprite.play("idle")


func walk() -> void:
	animated_sprite.play("walk")


func right() -> void:
	right_FX.play()
	await right_FX.finished
