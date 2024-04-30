extends Area2D
class_name Island

@onready var label : Label = $Label

var stimulus: Dictionary:
	set(value):
		label.text = "_".repeat(stimulus.Word.length())
