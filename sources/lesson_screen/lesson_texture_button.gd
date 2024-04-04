@tool
extends "res://sources/lesson_screen/lesson_button.gd"

@export var texture: Texture:
	set = _set_texture

@onready var texture_rect: TextureRect = $TextureRect


func _ready() -> void:
	_set_texture(texture)


func _set_texture(value: Texture) -> void:
	texture = value
	if texture_rect:
		texture_rect.texture = texture
