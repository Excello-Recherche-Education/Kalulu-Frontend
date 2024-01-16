extends "res://sources/language_tool/word_list_element.gd"


func update_lesson() -> void:
	var m: = -1
	for gp_id in gp_ids:
		var i: = Database.get_min_lesson_for_word_id(gp_id)
		m = max(m, i)
	lesson = m
