class_name BossButton
extends LessonButton

@export var icon_texture: Texture2D:
	set = _set_icon_texture
@export var completed_icon_texture: Texture2D:
	set = _set_completed_icon_texture

@onready var icon: TextureRect = %Icon


func _ready() -> void:
	super()
	if label:
		label.hide()
	_refresh_icon()


func _set_icon_texture(value: Texture2D) -> void:
	icon_texture = value
	_refresh_icon()


func _set_completed_icon_texture(value: Texture2D) -> void:
	completed_icon_texture = value
	_refresh_icon()


func _set_completed(value: bool) -> void:
	super(value)
	_refresh_icon()


func _refresh_icon() -> void:
	if not icon:
		return
	if completed and completed_icon_texture:
		icon.texture = completed_icon_texture
	else:
		icon.texture = icon_texture
