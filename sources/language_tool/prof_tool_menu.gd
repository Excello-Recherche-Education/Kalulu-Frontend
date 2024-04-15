extends Control

const base_path: = "user://language_resources/"
const save_file_path: = "user://prof_tool_save.tres"
var save_file: ProfToolSave

@onready var language_select_button: = %LanguageSelectButton
@onready var new_language_container: = %NewLanguageContainer
@onready var line_edit: = %LineEdit
@onready var file_dialog: = $FileDialog
@onready var file_dialog_export: = $FileDialogExport
@onready var add_word_list_button: = $VBoxContainer/AddWordListButton
@onready var error_label: = %ErrorLabel


func _ready() -> void:
	_update_add_word_list_button()
	if not ResourceLoader.exists(save_file_path):
		save_file = ProfToolSave.new()
		save_file.resource_path = save_file_path
		ResourceSaver.save(save_file, save_file_path)
	save_file = load(save_file_path)
	_display_available_languages()


func _display_available_languages() -> void:
	for item in range(1, language_select_button.item_count):
		language_select_button.remove_item(item)
	var available_languages: = _get_available_languages()
	var ind: = 1
	for available_language in available_languages:
		language_select_button.add_item(available_language)
		if available_language == save_file.selected_language:
			Database.language = save_file.selected_language
			language_select_button.select(ind)
		ind += 1


func _update_add_word_list_button() -> void:
	if FileAccess.file_exists(Database.get_additional_word_list_path()):
		add_word_list_button.text = "Change Word List"
	else:
		add_word_list_button.text = "Add Word List"


func _on_gp_list_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/language_tool/gp_list.tscn")


func _on_word_list_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/language_tool/word_list.tscn")


func _on_syllable_list_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/language_tool/syllable_list.tscn")


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


func _on_export_filename_selected(filename: String) -> void:
	var summary_file: = FileAccess.open(base_path.path_join(Database.language).path_join("summary.txt"), FileAccess.WRITE)
	for i in Database.get_lessons_count():
		summary_file.store_line("Lesson %s --------------------" % i)
		summary_file.store_line("\t \t Words ---")
		var words: = ""
		for e in Database.get_words_for_lesson(i, true):
			words += e.Word + ", "
		summary_file.store_line(words.trim_suffix(", "))
		summary_file.store_line("\n")
		summary_file.store_line("\t \t Sentences ---")
		for e in Database.get_sentences_for_lesson(i, true):
			summary_file.store_line(e.Sentence)
		summary_file.store_line("\n\n")
	summary_file.close()
	
	_create_GP_csv()
	_create_words_csv()
	_create_syllable_csv()
	_create_sentence_csv()
	
	var folder_zipper: = FolderZipper.new()
	folder_zipper.compress(base_path.path_join(Database.language), filename)


func _get_available_languages() -> Array[String]:
	var available_languages: Array[String] = []
	var dir = DirAccess.open(base_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if FileAccess.file_exists(base_path.path_join(file_name).path_join("language.db")):
					available_languages.append(file_name)
			file_name = dir.get_next()
	return available_languages


func _on_language_select_button_item_selected(index: int) -> void:
	if index == 0:
		new_language_container.show()
		line_edit.grab_focus()
		return
	
	save_file.selected_language = language_select_button.get_item_text(index)
	ResourceSaver.save(save_file, save_file_path)
	Database.language = save_file.selected_language


func _on_line_edit_text_submitted(new_text: String) -> void:
	DirAccess.make_dir_recursive_absolute(base_path.path_join(new_text))
	var file: = FileAccess.open("res://language_resources/model_database.db", FileAccess.READ)
	var dest: = FileAccess.open(base_path.path_join(new_text).path_join("language.db"), FileAccess.WRITE)
	dest.store_buffer(file.get_buffer(file.get_length()))
	file.close()
	dest.close()
	save_file.selected_language = new_text
	ResourceSaver.save(save_file, save_file_path)
	get_tree().reload_current_scene()



func _word_list_file_selected(file_path: String) -> void:
	if FileAccess.file_exists(file_path):
		DirAccess.copy_absolute(file_path, Database.get_additional_word_list_path())
		var msg: = Database.load_additional_word_list()
		error_label.text = msg


func _on_add_word_list_button_pressed() -> void:
	file_dialog.filters = []
	file_dialog.add_filter("*.csv", "csv")
	
	for connection in file_dialog.file_selected.get_connections():
		connection["signal"].disconnect(connection["callable"])
	
	file_dialog.file_selected.connect(_word_list_file_selected)
	
	file_dialog.show()
	_update_add_word_list_button()




func _on_import_language_button_pressed() -> void:
	file_dialog.filters = []
	file_dialog.add_filter("*.zip", "zip")
	
	for connection in file_dialog.file_selected.get_connections():
		connection["signal"].disconnect(connection["callable"])
	
	file_dialog.file_selected.connect(_language_data_selected)
	
	file_dialog.show()


func _on_export_button_pressed() -> void:
	file_dialog_export.filters = []
	file_dialog_export.add_filter("*.zip", "zip")
	
	for connection in file_dialog_export.file_selected.get_connections():
		connection["signal"].disconnect(connection["callable"])
	
	file_dialog_export.file_selected.connect(_on_export_filename_selected)
	
	file_dialog_export.show()


func _language_data_selected(file_path: String) -> void:
	if FileAccess.file_exists(file_path):
		var folder_unzipper: = FolderUnzipper.new()
		folder_unzipper.extract(file_path, base_path, false)


func _create_GP_csv() -> void:
	var gp_list_file: = FileAccess.open(base_path.path_join(Database.language).path_join("gp_list.csv"), FileAccess.WRITE)
	gp_list_file.store_csv_line(["Grapheme", "Phoneme", "Type"])
	var query: = "Select * FROM GPs ORDER BY GPs.Grapheme"
	Database.db.query(query)
	var result: = Database.db.query_result
	var types_text: = ["Silent", "Vowel", "Consonant"]
	for e in result:
		gp_list_file.store_csv_line([e.Grapheme, e.Phoneme, types_text[e.Type]])


func _create_words_csv() -> void:
	var gp_list_file: = FileAccess.open(base_path.path_join(Database.language).path_join("words_list.csv"), FileAccess.WRITE)
	gp_list_file.store_csv_line(["ORTHO", "GPMATCH"])
	var query: = "SELECT Words.ID as WordId, Word, group_concat(Grapheme, ' ') as Graphemes, group_concat(Phoneme, ' ') as Phonemes, group_concat(GPs.ID, ' ') as GPIDs, Words.Exception 
			FROM Words 
			INNER JOIN ( SELECT * FROM GPsInWords ORDER BY GPsInWords.Position ) GPsInWords ON Words.ID = GPsInWords.WordID 
			INNER JOIN GPs ON GPs.ID = GPsInWords.GPID
			GROUP BY Words.ID"
	Database.db.query(query)
	var result: = Database.db.query_result
	for e in result:
		var gpmatch: = "("
		var graphemes: PackedStringArray = e.Graphemes.split(" ")
		var phonemes: PackedStringArray = e.Phonemes.split(" ")
		for i in graphemes.size() - 1:
			gpmatch += graphemes[i] + "-" + phonemes[i] + "."
		var i: = graphemes.size() - 1
		gpmatch += graphemes[i] + "-" + phonemes[i] + ")"
		gp_list_file.store_csv_line([e.Word, gpmatch])


func _create_syllable_csv() -> void:
	var gp_list_file: = FileAccess.open(base_path.path_join(Database.language).path_join("syllables_list.csv"), FileAccess.WRITE)
	gp_list_file.store_csv_line(["ORTHO", "GPMATCH"])
	var query: = "SELECT Syllables.ID as SyllableId, Syllable, group_concat(Grapheme, ' ') as Graphemes, group_concat(Phoneme, ' ') as Phonemes, group_concat(GPs.ID, ' ') as GPIDs, Syllables.Exception 
			FROM Syllables 
			INNER JOIN ( SELECT * FROM GPsInSyllables ORDER BY GPsInSyllables.Position ) GPsInSyllables ON Syllables.ID = GPsInSyllables.SyllableID 
			INNER JOIN GPs ON GPs.ID = GPsInSyllables.GPID
			GROUP BY Syllables.ID"
	Database.db.query(query)
	var result: = Database.db.query_result
	for e in result:
		var gpmatch: = "("
		var graphemes: PackedStringArray = e.Graphemes.split(" ")
		var phonemes: PackedStringArray = e.Phonemes.split(" ")
		for i in graphemes.size() - 1:
			gpmatch += graphemes[i] + "-" + phonemes[i] + "."
		var i: = graphemes.size() - 1
		gpmatch += graphemes[i] + "-" + phonemes[i] + ")"
		gp_list_file.store_csv_line([e.Syllable, gpmatch])


func _create_sentence_csv() -> void:
	var gp_list_file: = FileAccess.open(base_path.path_join(Database.language).path_join("sentences_list.csv"), FileAccess.WRITE)
	gp_list_file.store_csv_line(["Sentence"])
	var query: = "SELECT Sentences.ID as SentenceId, Sentence, group_concat(Word, ' ') as Words, group_concat(Word, ' ') as Words, group_concat(Words.ID, ' ') as WordIDs, Sentences.Exception 
			FROM Sentences 
			INNER JOIN ( SELECT * FROM WordsInSentences ORDER BY WordsInSentences.Position ) WordsInSentences ON Sentences.ID = WordsInSentences.SentenceID 
			INNER JOIN Words ON Words.ID = WordsInSentences.WordID
			GROUP BY Sentences.ID"
	Database.db.query(query)
	var result: = Database.db.query_result
	for e in result:
		gp_list_file.store_csv_line([e.Sentence])
