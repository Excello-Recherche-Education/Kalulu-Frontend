@tool
extends Control
class_name SpriteControl

@export var sprites: Array[CanvasItem]:
	set = set_sprites


func set_sprites(p_sprites: Array[CanvasItem]) -> void:
	for p_sprite in p_sprites:
		if p_sprite:
			if p_sprite is Sprite2D:
				if not p_sprite.texture:
					return
			elif p_sprite is AnimatedSprite2D:
				if not p_sprite.sprite_frames:
					return
			else:
				return
	sprites = p_sprites
	_resize_sprites()


func _on_resized() -> void:
	_resize_sprites()


func _resize_sprites() -> void:
	for sprite in sprites:
		if sprite is Sprite2D:
			if sprite.texture:
				sprite.centered = false
				sprite.scale = size / sprite.texture.get_size()
		elif sprite is AnimatedSprite2D:
			if sprite.sprite_frames:
				var texture: Texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
				sprite.centered = false
				sprite.scale = size / texture.get_size()


func _ready() -> void:
	resized.connect(_on_resized)
	_resize_sprites()
