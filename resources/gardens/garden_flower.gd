@tool
extends Node2D

@export var texture: Texture:
	set = _set_texture

@onready var sprite: Sprite2D = %Sprite


func _ready():
	if texture:
		_set_texture(texture)


func _set_texture(p_texture: Texture) -> void:
	texture = p_texture
	sprite.texture = p_texture
	
	sprite.position.y = -sprite.texture.get_height() / 2


func _on_area_2d_input_event(viewport, event, shape_idx):
	if event.is_action_pressed("left_click"):
		print("CLICKKKKK")
