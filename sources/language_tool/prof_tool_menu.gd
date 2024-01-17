extends Control


func _on_gp_list_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/language_tool/gp_list.tscn")


func _on_word_list_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/language_tool/word_list.tscn")


func _on_sentence_list_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/language_tool/sentence_list.tscn")


func _on_lesson_list_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/language_tool/lessons_list.tscn")


func _on_tracing_builder_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/language_tool/tracing_builder.tscn")


func _on_data_loader_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/language_tool/gp_image_and_sound_descriptions.tscn")


func _on_data_loader_button_2_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/language_tool/gp_video_descriptions.tscn")


func _on_export_button_pressed() -> void:
	var sentences_by_lesson: = {}
	var sentences: = Database.get_sentences()
	for sentence in sentences:
		var lesson_nb: = Database.get_min_lesson_for_sentence_id(sentence.ID)
		var a = sentences_by_lesson.get(lesson_nb, [])
		a.append(sentence)
		sentences_by_lesson[lesson_nb] = a
	
	for i in Database.get_lessons_count():
		print("Lesson %s --------------------" % i)
		print("\t \t Words ---")
		var words: = ""
		for e in Database.get_words_for_lesson(i, true):
			words += e.Word + ", "
		print(words.trim_suffix(", "))
		print("\n")
		print("\t \t Sentences ---")
		for e in sentences_by_lesson.get(i, []):
			print(e.Sentence)
		print("\n\n")
