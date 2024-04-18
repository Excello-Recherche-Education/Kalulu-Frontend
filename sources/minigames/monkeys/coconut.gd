extends Node2D
class_name Coconut


@onready var label: Label = $Label


var text: String :
	set(value):
		text = value
		if label:
			label.text = text
