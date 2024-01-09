@tool
extends Resource
class_name GardensLayout


class Flower:
	var color: = 0
	var type: = 0
	var position: = Vector2i.ZERO
	
	func _init(p_color: int, p_type: int, p_position: Vector2i) -> void:
		color = p_color
		type = p_type
		position = p_position
	
	static func from_dict(d: Dictionary) -> Flower:
		return Flower.new(d.color, d.type, d.position)
	
	func to_dict() -> Dictionary:
		return {
			color = color,
			type = type,
			position = position,
		}


class LessonButton:
	var is_boss: = false
	var position: = Vector2i.ZERO
	
	func _init(p_is_boss: int, p_position: Vector2i) -> void:
		is_boss = p_is_boss
		position = p_position
	
	static func from_dict(d: Dictionary) -> LessonButton:
		return LessonButton.new(d.is_boss, d.position)
	
	func to_dict() -> Dictionary:
		return {
			is_boss = is_boss,
			position = position,
		}


class PathMiddle:
	var position: = Vector2i.ZERO
	
	func _init(p_position: Vector2i) -> void:
		position = p_position
	
	static func from_dict(d: Dictionary) -> PathMiddle:
		return PathMiddle.new(d.position)
	
	func to_dict() -> Dictionary:
		return {
			position = position,
		}


enum FirstOrLast {
	First,
	Neither,
	Last
}


class Garden:
	var color: = 0
	var flowers: Array[Flower] = []
	var lesson_buttons: Array[LessonButton] = []
	var path_middles: Array[PathMiddle] = []
	var is_first_or_last: = FirstOrLast.Neither
	
	func _init(p_color: int, p_flowers: Array[Flower], p_lesson_buttons: Array[LessonButton],
		p_path_middles: Array[PathMiddle], p_is_first_or_last: FirstOrLast) -> void:
		color = p_color
		flowers = p_flowers
		lesson_buttons = p_lesson_buttons
		path_middles = p_path_middles
		is_first_or_last = p_is_first_or_last
	
	
	static func from_dict(d: Dictionary) -> Garden:
		var flowers: Array[Flower] = []
		for flower_dict in d.flowers:
			flowers.append(Flower.from_dict(flower_dict))
		var lesson_buttons: Array[LessonButton] = []
		for lesson_button_dict in d.lesson_buttons:
			lesson_buttons.append(LessonButton.from_dict(lesson_button_dict))
		var path_middles: Array[PathMiddle] = []
		for path_middle_dict in d.path_middles:
			path_middles.append(PathMiddle.from_dict(path_middle_dict))
		return Garden.new(d.color, flowers, lesson_buttons, path_middles, d.is_first_or_last)
	
	
	func to_dict() -> Dictionary:
		var flowers_dict: Array[Dictionary] = []
		for flower in flowers:
			flowers_dict.append(flower.to_dict())
		var lesson_buttons_dict: Array[Dictionary] = []
		for lesson_button in lesson_buttons:
			lesson_buttons_dict.append(lesson_button.to_dict())
		var path_middles_dict: Array[Dictionary] = []
		for path_middle in path_middles:
			path_middles_dict.append(path_middle.to_dict())
		return {
			color = color,
			flowers = flowers_dict,
			lesson_buttons = lesson_buttons_dict,
			path_middles = path_middles_dict,
			is_first_or_last = is_first_or_last
		}


@export var gardens_export: Array[Dictionary] = []:
	set = set_gardens_export
var gardens: Array[Garden] = []:
	set = set_gardens


func set_gardens_export(p_gardens_export: Array[Dictionary]) -> void:
	gardens_export = p_gardens_export
	gardens.clear()
	for garden_dict in gardens_export:
		gardens.append(Garden.from_dict(garden_dict))


func set_gardens(p_gardens: Array[Garden]) -> void:
	gardens = p_gardens
	gardens_export.clear()
	for garden in gardens:
		gardens_export.append(garden.to_dict())

