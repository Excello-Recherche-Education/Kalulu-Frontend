@tool
class_name GardenLayout
extends Resource

enum FirstOrLast {
	First,
	Neither,
	Last
}

@export var color: int = 0
@export var lesson_buttons_export: Array[Dictionary] = []:
	set = set_lesson_buttons_export
@export var is_first_or_last: FirstOrLast = FirstOrLast.Neither

var lesson_buttons: Array[GardenLayoutLessonButton] = []:
	set = set_lesson_buttons


func set_lesson_buttons_export(p_lesson_buttons_export: Array[Dictionary]) -> void:
	lesson_buttons_export = p_lesson_buttons_export
	lesson_buttons.clear()
	for lesson_button_dict: Dictionary in lesson_buttons_export:
		lesson_buttons.append(GardenLayoutLessonButton.from_dict(lesson_button_dict))


func set_lesson_buttons(p_lesson_buttons: Array[GardenLayoutLessonButton]) -> void:
	lesson_buttons = p_lesson_buttons
	lesson_buttons_export.clear()
	for lesson_button: GardenLayoutLessonButton in lesson_buttons:
		lesson_buttons_export.append(lesson_button.to_dict())


class GardenLayoutLessonButton:
	var position: Vector2i = Vector2i.ZERO
	var path_out_position: Vector2i = Vector2i.ZERO


	func _init(p_position: Vector2i = Vector2i.ZERO, p_path_out_position: Vector2i = Vector2i.ZERO) -> void:
		position = p_position
		path_out_position = p_path_out_position


	static func from_dict(d: Dictionary) -> GardenLayoutLessonButton:
		return GardenLayoutLessonButton.new(d.position as Vector2i, d.path_out_position as Vector2i)


	func to_dict() -> Dictionary:
		return {
			position = position,
			path_out_position = path_out_position
		}
