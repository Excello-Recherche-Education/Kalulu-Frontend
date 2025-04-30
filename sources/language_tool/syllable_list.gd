extends "res://sources/language_tool/word_list.gd"


func _on_list_title_import_path_selected(path: String, match_to_file: bool) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var line: PackedStringArray = file.get_csv_line()
	if line.size() < 2 or line[0] != "ORTHO" or line[1] != "GPMATCH":
		error_label.text = "Column names should be ORTHO, GPMATCH"
		return
	var all_data: Dictionary = {}
	while not file.eof_reached():
		line = file.get_csv_line()
		if line.size() < 2:
			continue
		all_data[line[0]] = true
		if _element._already_in_database(line[0]) >= 0:
			continue
		var is_word: bool = _element.table == "Words"
		Database._import_word_from_csv(line[0], line[1], is_word)
	get_tree().reload_current_scene()
	
	# delete elements that are not in file
	if match_to_file:
		var query: String = "Select * FROM Syllables"
		Database.db.query(query)
		var result: Array[Dictionary] = Database.db.query_result
		for element: Dictionary in result:
			if not element.Syllable in all_data:
				Database.db.delete_rows("Syllables", "ID=%s" % element.ID)
