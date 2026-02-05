@tool
class_name DeviceButton
extends TextureButton

@export_range(1, 99) var number: int:
	set(value):
		if number > 99:
			Log.warn("DeviceBbutton: Number %d should not be higher than 99" % number)
		elif number < 1:
			Log.warn("DeviceBbutton: Number %d should not be lower than 1" % number)
		number = value
		if label:
			label.text = str(value)
@export var background_color: Color:
	set(value):
		background_color = value
		if background:
			background.self_modulate = background_color

@onready var background: TextureRect = $Background
@onready var label: Label = $Label


func _ready() -> void:
	label.text = str(number)
	background.self_modulate = background_color
