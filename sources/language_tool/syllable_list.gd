extends "res://sources/language_tool/word_list.gd"


func _on_list_title_import_path_selected(path: String) -> void:
	var file: = FileAccess.open(path, FileAccess.READ)
	var line: = file.get_csv_line()
	if line.size() < 2 or line[0] != "ORTHO" or line[1] != "GPMATCH":
		error_label.text = "Column names should be ORTHO, GPMATCH"
		return
	while not file.eof_reached():
		line = file.get_csv_line()
		if line.size() < 2:
			continue
		if _e._already_in_database(line[0]) >= 0:
			continue
		var is_word: bool = _e.table == "Words"
		Database._import_word_from_csv(line[0], line[1], is_word)
	get_tree().reload_current_scene()
