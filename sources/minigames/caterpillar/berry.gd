extends Area2D
class_name Berry

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var label: Label = $Label
@onready var highlight_fx: = $HighlightFX
@onready var wrong_fx: = $WrongFX

var gp: Dictionary: 
	set(value):
		gp = value
		if gp.has("Grapheme"):
			label.text = gp.Grapheme

var is_eaten: bool = false: 
	set(value):
		is_eaten = value
		if is_eaten:
			collision_shape.set_deferred("disabled", true)

var is_old: bool  = false:
	set(value):
		is_old = value
		if is_old:
			collision_shape.set_deferred("disabled", true)


func wrong() -> void:
	wrong_fx.play()
	await wrong_fx.finished

func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free()
