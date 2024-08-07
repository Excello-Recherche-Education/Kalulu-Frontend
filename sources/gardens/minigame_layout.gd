extends TextureRect
signal pressed()

@onready var icon: TextureRect = $TextureRect
@onready var area: Area2D = $Area2D

var is_disabled: bool = false

func _ready():
	area.connect("input_event", _on_click)

func _on_click(viewport, event, shape_idx):
	if event.is_action_pressed("left_click") and not is_disabled:
		pressed.emit()
