extends "res://sources/lesson_screen/lesson_button.gd"

@export var images: Array[Texture]
@export var text: String:
	set = _set_text
@export var display_text: bool = false:
	set = _set_display_text

@onready var images_container: HBoxContainer = $MarginContainer/ImagesContainer
@onready var label: Label = $Label


func _ready() -> void:
	load_images()
	_set_text(text)
	_set_display_text(display_text)


func load_images() -> void:
	for image in images_container.get_children():
		image.queue_free()
	
	for image in images:
		var texture_rect: = TextureRect.new()
		texture_rect.texture = image
		
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		images_container.add_child(texture_rect)


func _set_text(value: String) -> void:
	text = value
	if label:
		label.text = text


func _set_display_text(value: bool) -> void:
	display_text = value
	if label:
		label.visible = display_text
