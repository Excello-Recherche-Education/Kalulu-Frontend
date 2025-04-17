extends Control
class_name SegmentPointButton

signal point_down()
signal point_up()
signal minus_pressed()

@onready var index_label: Label = %IndexLabel


func _ready() -> void:
	z_index = 1000


func set_index(ind: int) -> void:
	index_label.text = str(ind)


func _on_texture_rect_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		point_down.emit()
	if event.is_action_released("left_click"):
		point_up.emit()
	if event.is_action_released("right_click"):
		minus_pressed.emit()
