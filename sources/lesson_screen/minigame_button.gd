extends MarginContainer

signal pressed

@export var texture: Texture:
	set = _set_texture

@onready var texture_button: TextureButton = %TextureButton


func _set_texture(value: Texture) -> void:
	texture = value
	texture_button.texture_normal = texture


func _on_texture_button_pressed() -> void:
	pressed.emit()
