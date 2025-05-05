@tool
extends Node2D

@export var texture: Texture:
	set = _set_texture

@onready var sprite: Sprite2D = %Sprite


func _ready() -> void:
	if texture:
		_set_texture(texture)


func _set_texture(p_texture: Texture) -> void:
	texture = p_texture
	sprite.texture = p_texture
	
	sprite.position.y = -sprite.texture.get_height() / 2.0
