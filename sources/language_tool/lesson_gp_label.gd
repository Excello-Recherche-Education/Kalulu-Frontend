class_name LessonGPLabel
extends Label

signal gp_dropped(before: bool, data: Dictionary)

var gp_id: int = -1
var grapheme: String = "":
	set = set_grapheme
var phoneme: String = "":
	set = set_phoneme
var is_being_dragged: bool = false


func set_grapheme(p_grapheme: String) -> void:
	grapheme = p_grapheme
	text = "%s-%s" % [grapheme, phoneme]


func set_phoneme(p_phoneme: String) -> void:
	phoneme = p_phoneme
	text = "%s-%s" % [grapheme, phoneme]


func _get_drag_data(_at_position: Vector2) -> Variant:
	is_being_dragged = true
	set_drag_preview(self.duplicate() as Control)
	return {
		gp_id = gp_id,
		grapheme = grapheme,
		phoneme = phoneme,
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary:
		return (data as Dictionary).has("gp_id") and data.gp_id != gp_id
	else:
		Logger.error("LessonGPLabel: Can not drop data that is not of type Dictionary")
		return false


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not data is Dictionary:
		Logger.error("LessonGPLabel: drop data failed because data is not of type Dictionary")
	if not (data as Dictionary).has("gp_id"):
		return
	var before: bool = at_position.x < size.x / 2
	gp_dropped.emit(before, data)


func _notification(what: int) -> void:
	if is_being_dragged and what == NOTIFICATION_DRAG_END:
		is_being_dragged = false
		if is_drag_successful():
			queue_free()
