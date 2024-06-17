extends Label
signal pressed(pos: Vector2)

var gp: Dictionary


func _ready() -> void:
	if gp:
		text = gp.Grapheme

func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		pressed.emit(get_global_mouse_position())
