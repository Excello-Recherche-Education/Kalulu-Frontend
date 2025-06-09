extends Control

const BASE_PATH: String = "user://language_resources/"
const SAVE_FILE_PATH: String = "user://prof_tool_save.tres"
var save_file: ProfToolSave

@onready var language_select_button: OptionButton = %LanguageSelectButton
@onready var new_language_container: PanelContainer = %NewLanguageContainer
@onready var line_edit: LineEdit = %LineEdit
@onready var file_dialog: FileDialog = $FileDialog
@onready var file_dialog_export: FileDialog = $FileDialogExport
@onready var add_word_list_button: Button = $VBoxContainer/AddWordListButton
@onready var error_label: Label = %ErrorLabel
@onready var tab_container: TabContainer = $CenterContainer/TabContainer


func _ready() -> void:
	MusicManager.stop()
	Database.load_additional_word_list()
	_update_add_word_list_button()
	if not ResourceLoader.exists(SAVE_FILE_PATH):
		save_file = ProfToolSave.new()
		save_file.resource_path = SAVE_FILE_PATH
		ResourceSaver.save(save_file, SAVE_FILE_PATH)
	save_file = load(SAVE_FILE_PATH)
	_display_available_languages()
	tab_container.current_tab = Globals.main_menu_selected_tab
	tab_container.tab_changed.connect(_on_tab_container_tab_changed)


func _display_available_languages() -> void:
	for item: int in range(1, language_select_button.item_count):
		language_select_button.remove_item(item)
	var available_languages: Array[String] = _get_available_languages()
	var ind: int = 1
	for available_language: String in available_languages:
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


func _on_game_sounds_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/language_tool/in_game_sounds.tscn")


func _on_pseudowords_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/language_tool/fish_word_list.tscn")


func _on_speeches_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/language_tool/kalulu_speeches.tscn")


func _on_exercises_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/language_tool/lesson_exercises.tscn")


func _on_export_filename_selected(filename: String) -> void:
	var version_file: FileAccess = FileAccess.open(BASE_PATH.path_join(Database.language).path_join("version.txt"), FileAccess.WRITE)
	version_file.store_line(Time.get_datetime_string_from_system(true, false))
	version_file.close()
	
	var summary_file: FileAccess = FileAccess.open(BASE_PATH.path_join(Database.language).path_join("summary.txt"), FileAccess.WRITE)
	var sentences_by_lesson: Dictionary = Database.get_sentences_by_lessons()
	for index: int in Database.get_lessons_count():
		
		var lesson: int = index +1
		
		summary_file.store_line("Lesson %s --------------------" % lesson)
		summary_file.store_line("\t \t Words ---")
		var words: String = ""
		for e: Dictionary in Database.get_words_for_lesson(lesson, true):
			words += e.Word + ", "
		summary_file.store_line(words.trim_suffix(", "))
		summary_file.store_line("\n")
		summary_file.store_line("\t \t Syllables ---")
		var syllables: String = ""
		for e: Dictionary in Database.get_syllables_for_lesson(lesson, true):
			syllables += e.Grapheme + ", "
		summary_file.store_line(syllables.trim_suffix(", "))
		summary_file.store_line("\n")
		summary_file.store_line("\t \t Sentences ---")
		for e: Dictionary in Database.get_sentences(lesson, true, sentences_by_lesson):
			summary_file.store_line(e.Sentence as String)
		summary_file.store_line("\n\n")
	summary_file.close()
	
	_create_gp_csv()
	_create_words_csv()
	_create_syllable_csv()
	_create_sentence_csv()
	
	var folder_zipper: FolderZipper = FolderZipper.new()
	folder_zipper.compress(BASE_PATH.path_join(Database.language), filename)

#region Database integrity check
var integrity_checking: bool = false
@onready var check_box_log: CheckBox = $CheckIntegrityButton/CheckBoxLog
var integrity_log_path: String = "user://database-integrity-log.txt"
var total_integrity_warnings: int = 0

func _check_db_integrity() -> void:
	if integrity_checking:
		return
	integrity_checking = true
	error_label.text = "Database integrity check started."
	total_integrity_warnings = 0
	await get_tree().process_frame
	if check_box_log.button_pressed:
		if FileAccess.file_exists(integrity_log_path):
			DirAccess.remove_absolute(integrity_log_path)
	
	var sentences_list: Dictionary = Database.get_sentences_by_lessons()
	if sentences_list.is_empty():
		if !log_message("No sentence found in database"):
					return
	var lesson_id: int
	var known_words_list: Dictionary = {}
	var known_gps_list: Array[Dictionary] = []
	var gp_known: bool = false
	for index: int in Database.get_lessons_count():
		lesson_id = index +1
		error_label.text = "Database integrity checks lesson " + str(lesson_id)
		await get_tree().process_frame
		Logger.trace("ProfToolMenu: Lesson_id = " + str(lesson_id))
		
		var new_gps_for_lesson: Array = Database.get_gps_for_lesson(lesson_id, false, true, false, false, true)
		for new_gp: Dictionary in new_gps_for_lesson:
			if !new_gp.has("ID"):
				if !log_message("GP with no ID in lesson " + str(lesson_id)):
					return
			if !new_gp.has("Grapheme"):
				if !log_message("GP (ID " + str(new_gp.ID) + ") with no Grapheme in lesson " + str(lesson_id)):
					return
			if !new_gp.has("Phoneme"):
				if !log_message("GP (ID " + str(new_gp.ID) + ") with no Phoneme in lesson " + str(lesson_id)):
					return
			var exists: bool = known_gps_list.any(func(d: Dictionary) -> bool: return d == new_gp)
			if exists:
				if !log_message("GP ID " + str(new_gp.ID) + " already exists in lesson " + str(lesson_id)):
					return
			else:
				known_gps_list.push_back(new_gp)
		
		var new_words_for_lesson: Array = Database.get_words_for_lesson(lesson_id, true, 1, 99, true)
		for new_word: Dictionary in new_words_for_lesson:
			if !new_word.has("ID"):
				if !log_message("Word with no ID in lesson ID " + str(lesson_id)):
					return
			if !new_word.has("GPs"):
				if !log_message("Word with no GPs (key) at lesson ID " + str(lesson_id) + " and word ID " + str(new_word.ID)):
					return
			if !new_word.has("Word"):
				if !log_message("Word with no Word (key) at lesson ID " + str(lesson_id) + " and word ID " + str(new_word.ID)):
					return
			for gp: Dictionary in new_word.GPs:
				if !gp.has("ID"):
					if !log_message("GP with no ID (key) at lesson ID " + str(lesson_id) + " in word " + (new_word.Word as String) + " (ID " + str(new_word.ID) + ")"):
						return
				gp_known = false
				for known_gp: Dictionary in known_gps_list:
					if known_gp.ID == gp.ID:
						gp_known = true
						break
				if !gp_known:
					if !log_message("Word " + (new_word.Word as String) + " with unknown GP (ID " + str(gp.ID) + ") at lesson ID " + str(lesson_id) + " and word ID " + str(new_word.ID)):
						return
			if known_words_list.has(new_word.Word):
				if !log_message('Word  "' + (new_word.Word as String) + '" is introduced in lesson ID ' + str(lesson_id) + " but it already was introduced in lesson ID " + str(known_words_list[new_word.Word])):
					return
			known_words_list[new_word.Word] = lesson_id
		
		if sentences_list.has(lesson_id):
			for sentence: Dictionary in sentences_list[lesson_id]:
				if !sentence.has("ID"):
					if !log_message("Sentence with no ID in lesson ID " + str(lesson_id)):
						return
				if !sentence.has("Sentence"):
					if !log_message("Sentence with no Sentence (key) at lesson ID " + str(lesson_id) + " and sentence ID " + str(sentence.ID)):
						return
				var word_count: int = ((sentence.Sentence) as String).replace("!", " ").replace("?", " ").replace(".", " ").replace(",", " ").replace(";", " ").replace(":", " ").replace("'", " ").replace("  ", " ").trim_suffix(" ").split(" ", false).size()
				var word_list: Array[Dictionary] = Database.get_words_in_sentence(sentence.ID as int)
				if word_list.size() != word_count:
					if !log_message('Sentence "' + (sentence.Sentence as String) + '" has incoherent words count: ' + str(word_list.size())):
						return
				for word: Dictionary in word_list:
					if !word.has("ID"):
						if !log_message("Word with no ID in lesson ID " + str(lesson_id) + " and sentence ID " + str(sentence.ID)):
							return
					if !word.has("Word"):
						if !log_message("Word with no Word (key) at lesson ID " + str(lesson_id) + ", sentence ID " + str(sentence.ID) + " and word ID " + str(word.ID)):
							return
					if !known_words_list.has(word.Word):
						if !log_message('Word "' + (word.Word as String) + '" is used in lesson ID ' + str(lesson_id) + ", sentence ID " + str(sentence.ID) + ", but it has not been introduced yet."):
							return
		else:
			continue #No sentence in this lesson
	
	error_label.text = "Database integrity checks all GP sounds file names."
	var all_gps: Array = Database.get_gps_for_lesson(Database.get_lessons_count() + 1, false, false, false, true, true)
	for gp: Dictionary in all_gps:
		var gp_sound_path: String = Database.get_gp_sound_path(gp)
		var result: Dictionary = file_exists_case_sensitive(gp_sound_path)
		match result.status:
			FileCheckResult.OK:
				pass # Nothing
			FileCheckResult.ERROR_CASE_MISMATCH:
				if !log_message("GP " + Database.get_gp_name(gp) + " sound file exists, but its name does not match the expected casing"):
					return
			FileCheckResult.ERROR_NOT_FOUND:
				if !log_message("GP " + Database.get_gp_name(gp) + " sound file does not exists"):
					return
	
	error_label.text = "Database integrity check finished. " + str(total_integrity_warnings) + " warnings found."
	integrity_checking = false
	if check_box_log.button_pressed:
		var file_path: String = ProjectSettings.globalize_path(integrity_log_path)
		Logger.trace("ProfToolMenu: Logs saved at " + file_path)
		OS.shell_open(file_path)
#endregion

func log_message(message: String) -> bool:
	total_integrity_warnings += 1
	if check_box_log.button_pressed:
		var file: FileAccess
		if FileAccess.file_exists(integrity_log_path):
			file = FileAccess.open(integrity_log_path, FileAccess.READ_WRITE)
			file.seek_end() # Se placer à la fin pour ajouter
		else:
			file = FileAccess.open(integrity_log_path, FileAccess.WRITE_READ)
		if file:
			file.seek_end()
			file.store_line(message)
			file.close()
		else:
			Logger.warn("ProfToolMenu: Integrity log file not found")
		return true
	else:
		error_label.text = message
		integrity_checking = false
		return false

enum FileCheckResult {
	OK,
	ERROR_NOT_FOUND,
	ERROR_CASE_MISMATCH
}

func file_exists_case_sensitive(path: String) -> Dictionary:
	var result: Dictionary = {
		"status": FileCheckResult.OK,
		"exists": false
	}

	if not FileAccess.file_exists(path):
		result.status = FileCheckResult.ERROR_NOT_FOUND
		return result

	var dir_path: String = path.get_base_dir()
	var file_name: String = path.get_file()

	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		result.status = FileCheckResult.ERROR_NOT_FOUND
		return result

	dir.list_dir_begin()
	while true:
		var test_name: String = dir.get_next()
		if test_name == "":
			break
		if !dir.current_is_dir():
			if test_name == file_name:
				result.exists = true
				result.status = FileCheckResult.OK
				dir.list_dir_end()
				return result
			elif test_name.to_lower() == file_name.to_lower():
				result.status = FileCheckResult.ERROR_CASE_MISMATCH
	dir.list_dir_end()

	if result.status != FileCheckResult.ERROR_CASE_MISMATCH:
		result.status = FileCheckResult.ERROR_NOT_FOUND

	return result

func _get_available_languages() -> Array[String]:
	var available_languages: Array[String] = []
	var dir: DirAccess = DirAccess.open(BASE_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if FileAccess.file_exists(BASE_PATH.path_join(file_name).path_join("language.db")):
					available_languages.append(file_name)
			file_name = dir.get_next()
	return available_languages


func _on_language_select_button_item_selected(index: int) -> void:
	if index == 0:
		new_language_container.show()
		line_edit.grab_focus()
		return
	
	save_file.selected_language = language_select_button.get_item_text(index)
	ResourceSaver.save(save_file, SAVE_FILE_PATH)
	Database.language = save_file.selected_language


func _on_validate_language_pressed() -> void:
	if not line_edit.text:
		return
		
	DirAccess.make_dir_recursive_absolute(BASE_PATH.path_join(line_edit.text))
	var file: FileAccess = FileAccess.open("res://model_database.db", FileAccess.READ)
	var dest: FileAccess = FileAccess.open(BASE_PATH.path_join(line_edit.text).path_join("language.db"), FileAccess.WRITE)
	dest.store_buffer(file.get_buffer(file.get_length()))
	file.close()
	dest.close()
	save_file.selected_language = line_edit.text
	ResourceSaver.save(save_file, SAVE_FILE_PATH)
	get_tree().reload_current_scene()


func _word_list_file_selected(file_path: String) -> void:
	if FileAccess.file_exists(file_path):
		DirAccess.copy_absolute(file_path, Database.get_additional_word_list_path())
		var msg: String = Database.load_additional_word_list()
		error_label.text = msg
		# Check that the words we have in database have the correct gpmatch, if not update them
		var query: String = "SELECT Words.ID as WordId, Word, group_concat(Grapheme, ' ') as Graphemes, group_concat(Phoneme, ' ') as Phonemes, group_concat(GPs.ID, ' ') as GPIDs, Words.Exception 
				FROM Words 
				INNER JOIN ( SELECT * FROM GPsInWords ORDER BY GPsInWords.Position ) GPsInWords ON Words.ID = GPsInWords.WordID 
				INNER JOIN GPs ON GPs.ID = GPsInWords.GPID
				GROUP BY Words.ID"
		Database.db.query(query)
		var results: Array[Dictionary] = Database.db.query_result
		var word_list_element: WordListElement = (load("res://sources/language_tool/word_list_element.tscn") as PackedScene).instantiate()
		for result: Dictionary in results:
			var same: bool = true
			var master_gpmatch: String = Database.additional_word_list[result.Word].GPMATCH
			var master_gplist: PackedStringArray = master_gpmatch.trim_prefix("(").trim_suffix(")").split(".")
			var graphemes: PackedStringArray = (result.Graphemes as String).split(" ")
			var phonemes: PackedStringArray = (result.Phonemes as String).split(" ")
			if master_gplist.size() != graphemes.size():
				same = false
			else:
				for index: int in master_gplist.size():
					same = same and (graphemes[index] + "-" + phonemes[index] == master_gplist[index])
			if not same:
				Database.db.delete_rows("Words", "ID=%s" % result.WordId)
				word_list_element._add_from_additional_word_list(result.Word as String)


func _on_add_word_list_button_pressed() -> void:
	file_dialog.filters = []
	file_dialog.add_filter("*.csv", "csv")
	
	for connection: Dictionary in file_dialog.file_selected.get_connections():
		(connection["signal"] as Signal).disconnect(connection["callable"] as Callable)
	
	file_dialog.file_selected.connect(_word_list_file_selected)
	
	file_dialog.show()
	_update_add_word_list_button()




func _on_import_language_button_pressed() -> void:
	file_dialog.filters = []
	file_dialog.add_filter("*.zip", "zip")
	
	for connection: Dictionary in file_dialog.file_selected.get_connections():
		(connection["signal"] as Signal).disconnect(connection["callable"] as Callable)
	
	file_dialog.file_selected.connect(_language_data_selected)
	
	file_dialog.show()


func _on_export_button_pressed() -> void:
	file_dialog_export.filters = []
	file_dialog_export.add_filter("*.zip", "zip")
	
	for connection: Dictionary in file_dialog_export.file_selected.get_connections():
		(connection["signal"] as Signal).disconnect(connection["callable"] as Callable)
	
	file_dialog_export.file_selected.connect(_on_export_filename_selected)
	
	file_dialog_export.show()


func _language_data_selected(file_path: String) -> void:
	if FileAccess.file_exists(file_path):
		var folder_unzipper: FolderUnzipper = FolderUnzipper.new()
		folder_unzipper.extract(file_path, BASE_PATH, false)
	get_tree().reload_current_scene()


func _create_gp_csv() -> void:
	var gp_list_file: FileAccess = FileAccess.open(BASE_PATH.path_join(Database.language).path_join("gp_list.csv"), FileAccess.WRITE)
	gp_list_file.store_csv_line(["Grapheme", "Phoneme", "Type", "Exception"])
	var query: String = "Select * FROM GPs ORDER BY GPs.Grapheme"
	Database.db.query(query)
	var result: Array[Dictionary] = Database.db.query_result
	var types_text: Array[String] = ["Silent", "Vowel", "Consonant"]
	for element: Dictionary in result:
		gp_list_file.store_csv_line([element.Grapheme, element.Phoneme, types_text[element.Type], element.Exception])


func _create_words_csv() -> void:
	var gp_list_file: FileAccess = FileAccess.open(BASE_PATH.path_join(Database.language).path_join("words_list.csv"), FileAccess.WRITE)
	gp_list_file.store_csv_line(["ORTHO", "GPMATCH", "LESSON", "READING", "WRITING"])
	var query: String = "SELECT Words.ID as WordId, Word, group_concat(Grapheme, ' ') as Graphemes, group_concat(Phoneme, ' ') as Phonemes, group_concat(GPs.ID, ' ') as GPIDs, Words.Exception, Reading, Writing 
			FROM Words 
			INNER JOIN ( SELECT * FROM GPsInWords ORDER BY GPsInWords.Position ) GPsInWords ON Words.ID = GPsInWords.WordID 
			INNER JOIN GPs ON GPs.ID = GPsInWords.GPID
			GROUP BY Words.ID"
	Database.db.query(query)
	var result: Array[Dictionary] = Database.db.query_result
	for element: Dictionary in result:
		var gpmatch: String = "("
		var graphemes: PackedStringArray = (element.Graphemes as String).split(" ")
		var phonemes: PackedStringArray = (element.Phonemes as String).split(" ")
		for index: int in graphemes.size() - 1:
			gpmatch += graphemes[index] + "-" + phonemes[index] + "."
		var index: int = graphemes.size() - 1
		gpmatch += graphemes[index] + "-" + phonemes[index] + ")"
		var lesson: int = -1
		@warning_ignore("unsafe_method_access")
		for gp_id: String in element.GPIDs.split(' '):
			var gp_id_lesson: int = Database.get_min_lesson_for_gp_id(int(gp_id))
			if gp_id_lesson < 0:
				lesson = -1
				break
			lesson = maxi(lesson, gp_id_lesson)
		gp_list_file.store_csv_line([element.Word, gpmatch, lesson, element.Reading, element.Writing])


func _create_syllable_csv() -> void:
	var gp_list_file: FileAccess = FileAccess.open(BASE_PATH.path_join(Database.language).path_join("syllables_list.csv"), FileAccess.WRITE)
	gp_list_file.store_csv_line(["ORTHO", "GPMATCH", "LESSON", "READING", "WRITING"])
	var query: String = "SELECT Syllables.ID as SyllableId, Syllable, group_concat(Grapheme, ' ') as Graphemes, group_concat(Phoneme, ' ') as Phonemes, group_concat(GPs.ID, ' ') as GPIDs, Syllables.Exception, Reading, Writing 
			FROM Syllables 
			INNER JOIN ( SELECT * FROM GPsInSyllables ORDER BY GPsInSyllables.Position ) GPsInSyllables ON Syllables.ID = GPsInSyllables.SyllableID 
			INNER JOIN GPs ON GPs.ID = GPsInSyllables.GPID
			GROUP BY Syllables.ID"
	Database.db.query(query)
	var result: Array[Dictionary] = Database.db.query_result
	for element: Dictionary in result:
		var gpmatch: String = "("
		var graphemes: PackedStringArray = (element.Graphemes as String).split(" ")
		var phonemes: PackedStringArray = (element.Phonemes as String).split(" ")
		for index: int in graphemes.size() - 1:
			gpmatch += graphemes[index] + "-" + phonemes[index] + "."
		var i: int = graphemes.size() - 1
		gpmatch += graphemes[i] + "-" + phonemes[i] + ")"
		var lesson: int = -1
		@warning_ignore("unsafe_method_access")
		for gp_id: String in element.GPIDs.split(' '):
			var gp_id_lesson: int = Database.get_min_lesson_for_gp_id(int(gp_id))
			if gp_id_lesson < 0:
				lesson = -1
				break
			lesson = maxi(lesson, gp_id_lesson)
		gp_list_file.store_csv_line([element.Syllable, gpmatch, lesson, element.Reading, element.Writing])


func _create_sentence_csv() -> void:
	var gp_list_file: FileAccess = FileAccess.open(BASE_PATH.path_join(Database.language).path_join("sentences_list.csv"), FileAccess.WRITE)
	gp_list_file.store_csv_line(["Sentence", "Lesson"])
	var query: String = "SELECT Sentences.ID as SentenceId, Sentence, group_concat(Word, ' ') as Words, group_concat(Word, ' ') as Words, group_concat(Words.ID, ' ') as WordIDs, Sentences.Exception 
			FROM Sentences 
			INNER JOIN ( SELECT * FROM WordsInSentences ORDER BY WordsInSentences.Position ) WordsInSentences ON Sentences.ID = WordsInSentences.SentenceID 
			INNER JOIN Words ON Words.ID = WordsInSentences.WordID
			GROUP BY Sentences.ID"
	Database.db.query(query)
	var result: Array[Dictionary] = Database.db.query_result
	for element: Dictionary in result:
		var lesson: int = -1
		@warning_ignore("unsafe_method_access")
		for word_id: String in element.WordIDs.split(' '):
			var ind: int = Database.get_min_lesson_for_word_id(int(word_id))
			if ind < 0:
				lesson = -1
				break
			lesson = maxi(lesson, ind)
		gp_list_file.store_csv_line([element.Sentence, lesson])


func _on_open_folder_button_pressed() -> void:
	OS.shell_show_in_file_manager(ProjectSettings.globalize_path(BASE_PATH))


func _on_tab_container_tab_changed(tab: int) -> void:
	Globals.main_menu_selected_tab = tab


#region Book Generation
func create_book() -> void:
	var lang_path: String = BASE_PATH.path_join(Database.language)
	var file_names: Dictionary[String, String] = {
		"word": "words_list.csv",
		"syllable": "syllables_list.csv",
		"sentence": "sentences_list.csv",
	}

	var columns: Dictionary[String, PackedStringArray] = {}
	var all_headers: Array[String] = []
	var headers_seen: Dictionary[String, bool] = {}

	for category: String in file_names.keys():
		var file_path: String = lang_path.path_join(file_names[category])
		var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
		if file == null:
			Logger.error("ProfToolMenu: Erreur d'ouverture : " + file_path)
			continue

		if file.eof_reached():
			file.close()
			continue

		var headers_line: String = read_csv_record(file)
		var raw_headers: PackedStringArray = parse_csv_line(headers_line)
		var header_map: Dictionary[String, String] = {} # Original -> Normalized
		
		# On mesure combien de lignes ont déjà été ajoutées
		var current_row_count: int = 0
		if columns.has("Categorie"):
			current_row_count = columns["Categorie"].size()

		for header: String in raw_headers:
			var normalized: String = normalize_header(header)
			header_map[header] = normalized

			if normalized != "Writing" and normalized != "Reading" and normalized != "Categorie" and not headers_seen.has(normalized):
				headers_seen[normalized] = true
				all_headers.append(normalized)
				var filler: PackedStringArray
				filler.resize(current_row_count)
				for index: int in range(current_row_count):
					filler[index] = ""  # Valeur vide pour rattraper
				columns[normalized] = filler

		# Init colonne "Categorie" si pas encore
		if not columns.has("Categorie"):
			var filler: PackedStringArray
			filler.resize(current_row_count)
			for index: int in range(current_row_count):
				filler[index] = ""
			columns["Categorie"] = filler

		while not file.eof_reached():
			var line: String = read_csv_record(file)
			if line.strip_edges() == "":
				continue

			var values: PackedStringArray = parse_csv_line(line)
			if values.size() != raw_headers.size():
				Logger.warn("ProfToolMenu: Ligne malformée ignorée : %s" % values)
				continue

			var row_dict: Dictionary[String, String] = {}
			for index: int in range(values.size()):
				var original: String = raw_headers[index]
				var normalized: String = header_map.get(original, original)
				row_dict[normalized] = values[index]

			# Ligne principale
			add_row(columns, row_dict, category, all_headers)

			if row_dict.get("Writing", "0") == "1":
				add_row(columns, row_dict, "writing", all_headers)

			if row_dict.get("Reading", "0") == "1":
				add_row(columns, row_dict, "reading", all_headers)

		file.close()

	# Forcer "Lesson" en tête
	var ordered_headers: Array[String] = all_headers.duplicate()
	if "Lesson" in ordered_headers:
		ordered_headers.erase("Lesson")
		ordered_headers = ["Lesson"] + ordered_headers

	# Ajouter Categorie à la fin
	ordered_headers.append("Categorie")

	# Écriture du fichier final
	var output_path: String = lang_path.path_join("booklet.csv")
	var output_file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if output_file == null:
		Logger.error("ProfToolMenu: Impossible d'écrire : " + output_path)
		return

	output_file.store_line(escape_csv_line(PackedStringArray(ordered_headers)))
	
	var row_count: int = (columns["Categorie"] as PackedStringArray).size()  # Toutes les colonnes sont synchronisées
	for index: int in range(row_count):
		var row: PackedStringArray = []
		for header: String in ordered_headers:
			row.append(columns[header][index] as String)
		output_file.store_line(escape_csv_line(row))

	output_file.close()
	
	error_label.text = "📘 Export des données du livret terminé vers : " + output_path
	Logger.trace("ProfToolMenu: " + error_label.text)

# Fonction qui ajoute une ligne au dictionnaire
func add_row(dict: Dictionary[String, PackedStringArray], row_data: Dictionary[String, String], categorie: String, all_headers: Array) -> void:
	# Nombre de lignes déjà enregistrées (doit être égal pour chaque colonne)
	var current_size: int = 0
	if dict.has("Categorie"):
		current_size= dict["Categorie"].size()

	# S'assurer que toutes les colonnes existantes reçoivent une valeur
	for header: String in all_headers:
		if not dict.has(header):
			var filler: PackedStringArray
			filler.resize(current_size) # rattrape les lignes précédentes
			for index: int in range(current_size):
				filler[index] = ""
			dict[header] = filler
		dict[header].append(row_data.get(header, "") as String)

	# Colonne spéciale : Categorie
	if not dict.has("Categorie"):
		var filler: PackedStringArray
		filler.resize(current_size)
		for index: int in range(current_size):
			filler[index] = ""
		dict["Categorie"] = filler

	dict["Categorie"].append(categorie)


# Parse une ligne CSV même si elle contient des virgules et guillemets
func parse_csv_line(line: String) -> PackedStringArray:
	var result: PackedStringArray = []
	var current: String = ""
	var in_quotes: bool = false
	var index: int = 0

	while index < line.length():
		var character: String = line[index]
		if character == "\"":
			if in_quotes and index + 1 < line.length() and line[index + 1] == "\"":
				current += "\""  # escaped quote
				index += 1
			else:
				in_quotes = !in_quotes
		elif character == "," and not in_quotes:
			result.append(current)
			current = ""
		else:
			current += character
		index += 1

	result.append(current)
	return result

# Transforme une ligne pour l'écriture CSV, avec échappement
func escape_csv_line(fields: PackedStringArray) -> String:
	var output: String = ""
	for index: int in range(fields.size()):
		var field: String = fields[index]
		if field.find("\"") != -1 or field.find(",") != -1 or field.find("\n") != -1:
			field = "\"" + field.replace("\"", "\"\"") + "\""
		output += field
		if index < fields.size() - 1:
			output += ","
	return output

# Normalise les noms de colonnes (ex: writing page -> Writing page)
func normalize_header(header_name: String) -> String:
	return header_name.strip_edges()[0].to_upper() + header_name.strip_edges().substr(1, -1).to_lower()

# Lit une "ligne logique" complète d’un CSV (même si elle est sur plusieurs lignes à cause des guillemets)
func read_csv_record(file: FileAccess) -> String:
	var record: String = ""
	var open_quotes: bool = false

	while not file.eof_reached():
		var line: String = file.get_line()
		if record != "":
			record += "\n"
		record += line

		var quote_count: int = 0
		for c: String in line:
			if c == "\"":
				quote_count += 1

		open_quotes = (quote_count % 2 != 0)

		if not open_quotes:
			break

	return record


#endregion
