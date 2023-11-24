extends Label

signal gp_dropped(before: bool, data: Dictionary)

var gp_id: = -1
var grapheme: = "":
	set = set_grapheme
var phoneme: = "":
	set = set_phoneme
var is_being_dragged: = false


func set_grapheme(p_grapheme: String) -> void:
	grapheme = p_grapheme
	text = "%s-%s" % [grapheme, phoneme]


func set_phoneme(p_phoneme: String) -> void:
	phoneme = p_phoneme
	text = "%s-%s" % [grapheme, phoneme]


func _get_drag_data(_at_position: Vector2) -> Variant:
	is_being_dragged = true
	set_drag_preview(self.duplicate())
	return {
		gp_id = gp_id,
		grapheme = grapheme,
		phoneme = phoneme,
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data.has("gp_id") and data.gp_id != gp_id


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not data.has("gp_id"):
		return
	var before: = at_position.x < size.x / 2
	gp_dropped.emit(before, data)


func _notification(what: int) -> void:
	if is_being_dragged and what == NOTIFICATION_DRAG_END:
		is_being_dragged = false
		if is_drag_successful():
			queue_free()
