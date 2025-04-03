extends Button
class_name SwipeDetector

signal swipe(start_position: Vector2, end_position: Vector2)

@onready var drag_preview: = $DragPreview

var current_preview: TextureRect
var start_position: Vector2

func _ready() -> void :
	set_drag_forwarding(
		# _get_drag_data
		func(at_position: Vector2) -> Dictionary:
			current_preview = drag_preview.duplicate()
			current_preview.show()
			set_drag_preview(current_preview)
			start_position = global_position + at_position
			return {},
		# _can_drop_data
		func(_at_position: Vector2, _data: Variant) -> bool: 
			return false,
		# _drop_data
		func(_at_position: Vector2, _data: Variant) -> void:
			pass
	)


func _on_drag_preview_tree_exiting() -> void:
	if current_preview:
		swipe.emit(start_position, current_preview.global_position)


func _on_drag_preview_tree_exited() -> void:
	current_preview = null
