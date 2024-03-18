extends "res://sources/language_tool/word_list.gd"


func get_lesson_for_element(id: int) -> int:
	return Database.get_min_lesson_for_sentence_id(id) + 1


func _on_list_title_new_search(new_text: String) -> void:
	for e in elements_container.get_children():
		var found: = false
		for word in e.word.split(" "):
			if word.begins_with(new_text):
				found = true
				break
		e.visible = found
