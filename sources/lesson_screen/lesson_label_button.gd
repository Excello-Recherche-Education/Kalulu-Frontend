extends "res://sources/lesson_screen/lesson_button.gd"

@export var text: = "":
	set = _set_text

@onready var label: Label = $Label


func _ready() -> void:
	_set_text(text)


func _set_text(value: String) -> void:
	text = value
	if label:
		label.text = text
