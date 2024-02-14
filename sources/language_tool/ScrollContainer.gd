extends ScrollContainer


func _ready() -> void:
	get_v_scroll_bar().custom_minimum_size = Vector2(50, 50)
