extends TextureRect
class_name MinigameLayout

signal pressed()

@onready var icon: TextureRect = $TextureRect
@onready var area: Area2D = $Area2D
@onready var right_fx: RightFX = $TextureRect/RightFX

var is_disabled: bool = false

func _ready() -> void:
	area.connect("input_event", _on_click)

func _on_click(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("left_click") and not is_disabled:
		pressed.emit()

func right() -> void:
	right_fx.play()
