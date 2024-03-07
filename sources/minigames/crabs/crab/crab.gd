@tool
extends MarginContainer
class_name Crab

signal crab_hit(stimulus: Dictionary)

@onready var animated_sprite: = %AnimatedSprite2D
@onready var label: = %AutoSizeLabel.get_node("Label")
@onready var button: = $Button
@onready var right_fx: = %RightFX
@onready var wrong_fx: = %WrongFX


var stimulus: Dictionary:
	set = _set_stimulus


func _ready() -> void:
	set_button_active(false)
	animated_sprite.play("idle1")


func set_button_active(active: bool) -> void:
	button.disabled = not active


func is_button_pressed() -> bool:
	await button.pressed
	return true


func right() -> void:
	right_fx.play()
	await right_fx.finished


func wrong() -> void:
	wrong_fx.play()
	await wrong_fx.finished


func _set_stimulus(value: Dictionary) -> void:
	stimulus = value
	if stimulus.has("Grapheme"):
		label.text = stimulus.Grapheme


func _on_button_pressed() -> void:
	crab_hit.emit(stimulus)
	animated_sprite.play("hit")


func _on_animated_sprite_2d_animation_finished() -> void:
	match animated_sprite.animation:
		"idle1", "idle2":
			if randf() < 0.5 :
				animated_sprite.play("idle1") 
			else : 
				animated_sprite.play("idle2")
		"hit":
			animated_sprite.play("hurt")
