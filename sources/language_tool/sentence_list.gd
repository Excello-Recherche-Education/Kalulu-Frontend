extends "res://sources/language_tool/word_list.gd"


func get_lesson_for_element(id: int) -> int:
	return Database.get_min_lesson_for_sentence_id(id) + 1
