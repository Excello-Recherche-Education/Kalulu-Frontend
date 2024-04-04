extends TextureButton

@export var completed: = false:
	set = _set_completed

const completed_up: = preload("res://assets/lesson_screen/button_completed_up.png")
const completed_down: = preload("res://assets/lesson_screen/button_completed_down.png")

const progress_up: = preload("res://assets/lesson_screen/button_progress_up.png")
const progress_down: = preload("res://assets/lesson_screen/button_progress_down.png")


func _set_completed(value: bool) -> void:
	completed = value
	
	if completed:
		texture_normal = completed_up
		texture_pressed = completed_down
	else:
		texture_normal = progress_up
		texture_pressed = progress_down
