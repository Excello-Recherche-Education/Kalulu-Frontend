extends Area2D

@onready var label : Label = $Label
@onready var collision: CollisionPolygon2D = $CollisionPolygon2D

var stimulus: Dictionary = {}:
	set(value):
		stimulus = value
		progress = 0

var progress: int = 0:
	set(value):
		progress = value
		_update_label()


func set_enabled(is_enabled: bool) -> void:
	collision.set_deferred("disabled", !is_enabled)


func _update_label() -> void:
	label.text = ""
	for index: int in stimulus.GPsCount:
		if progress > index or progress == stimulus.GPsCount:
			label.text += stimulus.GPs[index].Grapheme
		else:
			label.text += "_"
