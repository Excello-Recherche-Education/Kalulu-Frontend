extends WordList

var not_found_list: String = ""
@onready var export_not_found_button: Button = %ExportNotFoundButton
@onready var file_dialog_export: FileDialog = $FileDialogExport


func create_sub_elements_list() -> void:
	super()
	@warning_ignore("unsafe_property_access")
	new_gp.sub_elements_list = sub_elements_list.duplicate()
	sub_elements_list.clear()
	Database.db.query("Select Words.ID as ID, Words.Word as Word, group_concat(GPs.Phoneme, '') as Phonemes
	FROM Words
	INNER JOIN GPsInWords ON GPsInWords.WordID = Words.ID
	INNER JOIN GPs ON GPs.ID = GPsInWords.GPID
	GROUP BY Words.ID
	ORDER BY Words.Word")
	for result: Dictionary in Database.db.query_result:
		sub_elements_list[result.ID] = {
			grapheme = result.Word,
			phoneme = result.Phonemes
		}


func get_lesson_for_element(id: int) -> int:
	return Database.get_min_lesson_for_sentence_id(id) + 1


func _on_list_title_new_search(new_text: String) -> void:
	for element: WordListElement in elements_container.get_children():
		var found: bool = false
		for word: String in element.word.split(" "):
			if word.begins_with(new_text):
				found = true
				break
		element.visible = found


func _ready() -> void:
	super()
	connect_not_found()


func connect_not_found() -> void:
	for element: WordListElement in elements_container.get_children(): 
		if element is SentenceListElement and not (element as SentenceListElement).not_found.is_connected(_on_not_found):
			(element as SentenceListElement).not_found.connect(_on_not_found)
	if _element is SentenceListElement and not (_element as SentenceListElement).not_found.is_connected(_on_not_found_csv):
		(_element as SentenceListElement).not_found.connect(_on_not_found_csv)


func _on_plus_button_pressed() -> void:
	super()
	connect_not_found()


func _on_not_found(text: String) -> void:
	error_label.text = text


func _on_not_found_csv(text: String) -> void:
	not_found_list += text + "\n"


func _on_list_title_import_path_selected(path: String, match_to_file: bool) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var line: PackedStringArray = file.get_csv_line()
	if line.size() < 1 or line[0] != "Sentence":
		error_label.text = "Column name should be Sentence"
		return
	var inserted_one: bool = false
	var not_found_one: bool = false
	var all_data: Dictionary = {}
	while not file.eof_reached():
		line = file.get_csv_line()
		if line.size() < 1 or line[0] == "":
			continue
			
		all_data[line[0]] = true
		var id: int = _element._already_in_database(line[0])
		if id >= 0:
			continue
		
		id = _element._add_from_additional_word_list(line[0])
		if id >= 0:
			inserted_one = true
		else:
			not_found_one = true
	
	# delete elements that are not in file
	if match_to_file:
		var query: String = "Select * FROM Sentences"
		Database.db.query(query)
		var result: Array[Dictionary] = Database.db.query_result
		for element: Dictionary in result:
			if not element.Sentence in all_data:
				Database.db.delete_rows("Sentences", "ID=%s" % element.ID)
				inserted_one = true
		
	if inserted_one:
		get_tree().reload_current_scene()
	elif not_found_one:
		export_not_found_button.show()


func _on_export_not_found_button_pressed() -> void:
	file_dialog_export.filters = []
	file_dialog_export.add_filter("*.txt", "txt")
	Utils.disconnect_all(file_dialog_export.file_selected)
	file_dialog_export.file_selected.connect(_on_export_filename_selected)
	file_dialog_export.show()


func _on_export_filename_selected(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(not_found_list)
	file.close()
