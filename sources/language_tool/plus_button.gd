extends MarginContainer

signal pressed()

@onready var texture_rect: = $TextureRect
@onready var base_margin: int = get("theme_override_constants/margin_bottom")


func _on_texture_rect_mouse_entered() -> void:
	set("theme_override_constants/margin_bottom", 10)
	set("theme_override_constants/margin_top", 10)
	set("theme_override_constants/margin_left", 10)
	set("theme_override_constants/margin_right", 10)
	texture_rect.custom_minimum_size = Vector2(200, 200)


func _on_texture_rect_mouse_exited() -> void:
	set("theme_override_constants/margin_bottom", base_margin)
	set("theme_override_constants/margin_top", base_margin)
	set("theme_override_constants/margin_left", base_margin)
	set("theme_override_constants/margin_right", base_margin)
	texture_rect.custom_minimum_size = Vector2(120, 120)
	texture_rect.size = Vector2.ZERO
	size = Vector2.ZERO


func _on_texture_rect_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		pressed.emit()
		
