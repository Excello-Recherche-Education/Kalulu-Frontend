class_name BossButton
extends LessonButton

@export var icon_texture: Texture2D:
	set = _set_icon_texture

@onready var icon: TextureRect = %Icon


func _ready() -> void:
	super()
	if label:
		label.hide()
	_set_icon_texture(icon_texture)


func _set_icon_texture(value: Texture2D) -> void:
	icon_texture = value
	if icon:
		icon.texture = value
