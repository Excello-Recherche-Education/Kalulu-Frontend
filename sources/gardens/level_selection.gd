extends Control
class_name LevelSelection

@export var lesson_number: int:
	set = _set_lesson_number


func _ready() -> void:
	await OpeningCurtain.open()


func _set_lesson_number(value: int) -> void:
	lesson_number = value
