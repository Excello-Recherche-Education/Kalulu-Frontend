@tool
extends TextureButton

@export_range(1, 99) var number: int:
	set(value):
		number = value
		if $Label:
			$Label.text = str(value)

@export var background_color: Color:
	set(value):
		background_color = value
		if $Background:
			$Background.self_modulate = background_color

func _ready() -> void:
	$Label.text = str(number)
	$Background.self_modulate = background_color
