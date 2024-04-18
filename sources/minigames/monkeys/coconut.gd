extends Node2D
class_name Coconut


@onready var label: Label = $Label
@onready var highlight_fx: HighlightFX = $HighlightFX


var text: String :
	set(value):
		text = value
		if label:
			label.text = text


func highlight() -> void:
	highlight_fx.play()
