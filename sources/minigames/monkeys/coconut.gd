extends Node2D

@onready var label: = $Label


var text: String :
	set(value):
		text = value
		if label:
			label.text = text
