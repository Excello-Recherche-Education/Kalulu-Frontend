extends Node2D
class_name Lilypad

signal frog_land()
signal frog_fall()

@onready var animation_player: = $AnimationPlayer
@onready var sprite: = $Sprite2D
@onready var label: = $Label

var stimulus: Dictionary:
	set(value):
		stimulus = value
		label.text = stimulus["Grapheme"]
var is_distractor: = true:
	set(value):
		is_distractor = value
		if is_distractor:
			label.set("theme_override_colors/font_color", Color.BLACK)
		else:
			label.set("theme_override_colors/font_color", Color.WHITE)


func _ready() -> void:
	sprite.material.set_shader_parameter("dissolve_amount", 1.0)


func frog_landed() -> bool:
	if is_distractor:
		frog_fall.emit()
		return false
	else:
		frog_land.emit()
		return true


func appear() -> void:
	sprite.material.set_shader_parameter("dissolve_amount", 0.0)
	label.visible = true


func disappear() -> void:
	animation_player.play("flood")
	await animation_player.animation_finished
