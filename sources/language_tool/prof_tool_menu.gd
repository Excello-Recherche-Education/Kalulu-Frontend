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
@onready var tab_container: TabContainer = $CenterContainer/TabContainer


func _ready() -> void:
	MusicManager.stop()
	Database.load_additional_word_list()
	_update_add_word_list_button()
	if not ResourceLoader.exists(save_file_path):
		save_file = ProfToolSave.new()
		save_file.resource_path = save_file_path
		ResourceSaver.save(save_file, save_file_path)
	save_file = load(save_file_path)
	_display_available_languages()
	tab_container.current_tab = Globals.main_menu_selected_tab
	tab_container.tab_changed.connect(_on_tab_container_tab_changed)


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


func _on_game_sounds_button_pressed():
	get_tree().change_scene_to_file("res://sources/language_tool/in_game_sounds.tscn")


func _on_pseudowords_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/language_tool/fish_word_list.tscn")


func _on_speeches_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/language_tool/kalulu_speeches.tscn")


func _on_exercises_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/language_tool/lesson_exercises.tscn")


func _on_export_filename_selected(filename: String) -> void:
	var version_file: = FileAccess.open(base_path.path_join(Database.language).path_join("version.txt"), FileAccess.WRITE)
	version_file.store_line(Time.get_datetime_string_from_system(true, false))
	version_file.close()
	
	var summary_file: = FileAccess.open(base_path.path_join(Database.language).path_join("summary.txt"), FileAccess.WRITE)
	var sentences_by_lesson: = Database.get_sentences_by_lessons()
	for i in Database.get_lessons_count():
		
		var lesson: int = i +1
		
		summary_file.store_line("Lesson %s --------------------" % lesson)
		summary_file.store_line("\t \t Words ---")
		var words: = ""
		for e in Database.get_words_for_lesson(lesson, true):
			words += e.Word + ", "
		summary_file.store_line(words.trim_suffix(", "))
		summary_file.store_line("\n")
		summary_file.store_line("\t \t Syllables ---")
		var syllables: = ""
		for e in Database.get_syllables_for_lesson(lesson, true):
			syllables += e.Grapheme + ", "
		summary_file.store_line(syllables.trim_suffix(", "))
		summary_file.store_line("\n")
		summary_file.store_line("\t \t Sentences ---")
		for e in Database.get_sentences(lesson, true, sentences_by_lesson):
			summary_file.store_line(e.Sentence)
		summary_file.store_line("\n\n")
	summary_file.close()
	
	_create_GP_csv()
	_create_words_csv()
	_create_syllable_csv()
	_create_sentence_csv()
	
	var folder_zipper: = FolderZipper.new()
	folder_zipper.compress(base_path.path_join(Database.language), filename)

#region Database integrity check
var integrity_checking: bool = false
@onready var check_box_log: CheckBox = $CheckIntegrityButton/CheckBoxLog
var integrity_log_path: String = "user://database-integrity-log.txt"
var total_integrity_warnings: int = 0

func _check_db_integrity():
	if integrity_checking:
		return
	integrity_checking = true
	error_label.text = "Database integrity check started."
	total_integrity_warnings = 0
	await get_tree().process_frame
	if check_box_log.button_pressed:
		if FileAccess.file_exists(integrity_log_path):
			DirAccess.remove_absolute(integrity_log_path)
	
	var sentences_list = Database.get_sentences_by_lessons()
	if sentences_list.is_empty():
		if !log_message("No sentence found in database"):
					return
	var lesson_id: int
	var known_words_list: Dictionary = {}
	var known_GPs_list: Array[Dictionary] = []
	var GPKnown: bool = false
	for i in Database.get_lessons_count():
		lesson_id = i +1
		error_label.text = "Database integrity checks lesson " + str(lesson_id)
		await get_tree().process_frame
		print("Lesson_id = " + str(lesson_id))
		
		var new_GPs_for_lesson: Array = Database.get_GP_for_lesson(lesson_id, false, true, false, false, true)
		for new_GP: Dictionary in new_GPs_for_lesson:
			if !new_GP.has("ID"):
				if !log_message("GP with no ID in lesson " + str(lesson_id)):
					return
			if !new_GP.has("Grapheme"):
				if !log_message("GP (ID " + str(new_GP.ID) + ") with no Grapheme in lesson " + str(lesson_id)):
					return
			if !new_GP.has("Phoneme"):
				if !log_message("GP (ID " + str(new_GP.ID) + ") with no Phoneme in lesson " + str(lesson_id)):
					return
			var exists = known_GPs_list.any(func(d): return d == new_GP)
			if exists:
				if !log_message("GP ID " + str(new_GP.ID) + " already exists in lesson " + str(lesson_id)):
					return
			else:
				known_GPs_list.push_back(new_GP)
		
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
			for GP: Dictionary in new_word.GPs:
				if !GP.has("ID"):
					if !log_message("GP with no ID (key) at lesson ID " + str(lesson_id) + " in word " + new_word.Word + " (ID " + str(new_word.ID) + ")"):
						return
				GPKnown = false
				for knownGP: Dictionary in known_GPs_list:
					if knownGP.ID == GP.ID:
						GPKnown = true
						break
				if !GPKnown:
					if !log_message("Word " + new_word.Word + " with unknown GP (ID " + str(GP.ID) + ") at lesson ID " + str(lesson_id) + " and word ID " + str(new_word.ID)):
						return
			if known_words_list.has(new_word.Word):
				if !log_message('Word  "' + new_word.Word + '" is introduced in lesson ID ' + str(lesson_id) + " but it already was introduced in lesson ID " + str(known_words_list[new_word.Word])):
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
				var word_count = ((sentence.Sentence) as String).replace("!", " ").replace("?", " ").replace(".", " ").replace(",", " ").replace(";", " ").replace(":", " ").replace("'", " ").replace("  ", " ").trim_suffix(" ").split(" ", false).size()
				var word_list = Database.get_words_in_sentence(sentence.ID)
				if word_list.size() != word_count:
					if !log_message('Sentence "' + sentence.Sentence + '" has incoherent words count: ' + str(word_list.size())):
						return
				for word: Dictionary in word_list:
					if !word.has("ID"):
						if !log_message("Word with no ID in lesson ID " + str(lesson_id) + " and sentence ID " + str(sentence.ID)):
							return
					if !word.has("Word"):
						if !log_message("Word with no Word (key) at lesson ID " + str(lesson_id) + ", sentence ID " + str(sentence.ID) + " and word ID " + str(word.ID)):
							return
					if !known_words_list.has(word.Word):
						if !log_message('Word "' + word.Word + '" is used in lesson ID ' + str(lesson_id) + ", sentence ID " + str(sentence.ID) + ", but it has not been introduced yet."):
							return
		else:
			continue #No sentence in this lesson
	
	error_label.text = "Database integrity check finished. " + str(total_integrity_warnings) + " warnings found."
	integrity_checking = false
	if check_box_log.button_pressed:
		var file_path = ProjectSettings.globalize_path(integrity_log_path)
		print("Log saved at " + file_path)
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
			push_warning("Log file not found")
		return true
	else:
		error_label.text = message
		integrity_checking = false
		return false

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


func _on_validate_language_pressed() -> void:
	if not line_edit.text:
		return
		
	DirAccess.make_dir_recursive_absolute(base_path.path_join(line_edit.text))
	var file: = FileAccess.open("res://model_database.db", FileAccess.READ)
	var dest: = FileAccess.open(base_path.path_join(line_edit.text).path_join("language.db"), FileAccess.WRITE)
	dest.store_buffer(file.get_buffer(file.get_length()))
	file.close()
	dest.close()
	save_file.selected_language = line_edit.text
	ResourceSaver.save(save_file, save_file_path)
	get_tree().reload_current_scene()


func _word_list_file_selected(file_path: String) -> void:
	if FileAccess.file_exists(file_path):
		DirAccess.copy_absolute(file_path, Database.get_additional_word_list_path())
		var msg: = Database.load_additional_word_list()
		error_label.text = msg
		# Check that the words we have in database have the correct gpmatch, if not update them
		var query: = "SELECT Words.ID as WordId, Word, group_concat(Grapheme, ' ') as Graphemes, group_concat(Phoneme, ' ') as Phonemes, group_concat(GPs.ID, ' ') as GPIDs, Words.Exception 
				FROM Words 
				INNER JOIN ( SELECT * FROM GPsInWords ORDER BY GPsInWords.Position ) GPsInWords ON Words.ID = GPsInWords.WordID 
				INNER JOIN GPs ON GPs.ID = GPsInWords.GPID
				GROUP BY Words.ID"
		Database.db.query(query)
		var result: = Database.db.query_result
		var word_list_element = load("res://sources/language_tool/word_list_element.tscn").instantiate()
		for e in result:
			var is_same: = true
			var master_gpmatch = Database.additional_word_list[e.Word].GPMATCH
			var master_gplist: PackedStringArray = master_gpmatch.trim_prefix("(").trim_suffix(")").split(".")
			var graphemes: PackedStringArray = e.Graphemes.split(" ")
			var phonemes: PackedStringArray = e.Phonemes.split(" ")
			if master_gplist.size() != graphemes.size():
				is_same = false
			else:
				for i in master_gplist.size():
					is_same = is_same and (graphemes[i] + "-" + phonemes[i] == master_gplist[i])
			if not is_same:
				Database.db.delete_rows("Words", "ID=%s" % e.WordId)
				word_list_element._add_from_additional_word_list(e.Word)


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
	get_tree().reload_current_scene()


func _create_GP_csv() -> void:
	var gp_list_file: = FileAccess.open(base_path.path_join(Database.language).path_join("gp_list.csv"), FileAccess.WRITE)
	gp_list_file.store_csv_line(["Grapheme", "Phoneme", "Type", "Exception"])
	var query: = "Select * FROM GPs ORDER BY GPs.Grapheme"
	Database.db.query(query)
	var result: = Database.db.query_result
	var types_text: = ["Silent", "Vowel", "Consonant"]
	for e in result:
		gp_list_file.store_csv_line([e.Grapheme, e.Phoneme, types_text[e.Type], e.Exception])


func _create_words_csv() -> void:
	var gp_list_file: = FileAccess.open(base_path.path_join(Database.language).path_join("words_list.csv"), FileAccess.WRITE)
	gp_list_file.store_csv_line(["ORTHO", "GPMATCH", "LESSON", "READING", "WRITING"])
	var query: = "SELECT Words.ID as WordId, Word, group_concat(Grapheme, ' ') as Graphemes, group_concat(Phoneme, ' ') as Phonemes, group_concat(GPs.ID, ' ') as GPIDs, Words.Exception, Reading, Writing 
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
		var lesson: = -1
		for gp_id in e.GPIDs.split(' '):
			var gp_id_lesson: = Database.get_min_lesson_for_gp_id(int(gp_id))
			if gp_id_lesson < 0:
				lesson = -1
				break
			lesson = max(lesson, gp_id_lesson)
		gp_list_file.store_csv_line([e.Word, gpmatch, lesson, e.Reading, e.Writing])


func _create_syllable_csv() -> void:
	var gp_list_file: = FileAccess.open(base_path.path_join(Database.language).path_join("syllables_list.csv"), FileAccess.WRITE)
	gp_list_file.store_csv_line(["ORTHO", "GPMATCH", "LESSON", "READING", "WRITING"])
	var query: = "SELECT Syllables.ID as SyllableId, Syllable, group_concat(Grapheme, ' ') as Graphemes, group_concat(Phoneme, ' ') as Phonemes, group_concat(GPs.ID, ' ') as GPIDs, Syllables.Exception, Reading, Writing 
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
		var lesson: = -1
		for gp_id in e.GPIDs.split(' '):
			var gp_id_lesson: = Database.get_min_lesson_for_gp_id(int(gp_id))
			if gp_id_lesson < 0:
				lesson = -1
				break
			lesson = max(lesson, gp_id_lesson)
		gp_list_file.store_csv_line([e.Syllable, gpmatch, lesson, e.Reading, e.Writing])


func _create_sentence_csv() -> void:
	var gp_list_file: = FileAccess.open(base_path.path_join(Database.language).path_join("sentences_list.csv"), FileAccess.WRITE)
	gp_list_file.store_csv_line(["Sentence", "Lesson"])
	var query: = "SELECT Sentences.ID as SentenceId, Sentence, group_concat(Word, ' ') as Words, group_concat(Word, ' ') as Words, group_concat(Words.ID, ' ') as WordIDs, Sentences.Exception 
			FROM Sentences 
			INNER JOIN ( SELECT * FROM WordsInSentences ORDER BY WordsInSentences.Position ) WordsInSentences ON Sentences.ID = WordsInSentences.SentenceID 
			INNER JOIN Words ON Words.ID = WordsInSentences.WordID
			GROUP BY Sentences.ID"
	Database.db.query(query)
	var result: = Database.db.query_result
	for e in result:
		var lesson: = -1
		for word_id in e.WordIDs.split(' '):
			var i: = Database.get_min_lesson_for_word_id(int(word_id))
			if i < 0:
				lesson = -1
				break
			lesson = max(lesson, i)
		gp_list_file.store_csv_line([e.Sentence, lesson])


func _on_open_folder_button_pressed() -> void:
	OS.shell_show_in_file_manager(ProjectSettings.globalize_path(base_path))


func _on_tab_container_tab_changed(tab: int) -> void:
	Globals.main_menu_selected_tab = tab


#region Book Generation
func create_book():
	var lang_path = base_path.path_join(Database.language)
	var file_names = {
		"word": "words_list.csv",
		"syllable": "syllables_list.csv",
		"sentence": "sentences_list.csv",
	}

	var columns := {}  # Dictionary<String, PackedStringArray>
	var all_headers: Array = []
	var headers_seen := {}

	for category in file_names.keys():
		var file_path = lang_path.path_join(file_names[category])
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file == null:
			push_error("Erreur d'ouverture : " + file_path)
			continue

		if file.eof_reached():
			file.close()
			continue

		var headers_line = read_csv_record(file)
		var raw_headers = parse_csv_line(headers_line)
		var header_map = {}  # Original -> Normalized
		
		# On mesure combien de lignes ont déjà été ajoutées
		var current_row_count := 0
		if columns.has("Categorie"):
			current_row_count = columns["Categorie"].size()

		for header in raw_headers:
			var normalized = normalize_header(header)
			header_map[header] = normalized

			if normalized != "Writing" and normalized != "Reading" and normalized != "Categorie" and not headers_seen.has(normalized):
				headers_seen[normalized] = true
				all_headers.append(normalized)
				var filler := PackedStringArray()
				filler.resize(current_row_count)
				for i in range(current_row_count):
					filler[i] = ""  # Valeur vide pour rattraper
				columns[normalized] = filler

		# Init colonne "Categorie" si pas encore
		if not columns.has("Categorie"):
			var filler := PackedStringArray()
			filler.resize(current_row_count)
			for i in range(current_row_count):
				filler[i] = ""
			columns["Categorie"] = filler

		while not file.eof_reached():
			var line = read_csv_record(file)
			if line.strip_edges() == "":
				continue

			var values = parse_csv_line(line)
			if values.size() != raw_headers.size():
				push_warning("⚠️ Ligne malformée ignorée : ", values)
				continue

			var row_dict := {}
			for i in range(values.size()):
				var original = raw_headers[i]
				var normalized = header_map.get(original, original)
				row_dict[normalized] = values[i]

			# Ligne principale
			add_row(columns, row_dict, category, all_headers)

			if row_dict.get("Writing", "0") == "1":
				add_row(columns, row_dict, "writing", all_headers)

			if row_dict.get("Reading", "0") == "1":
				add_row(columns, row_dict, "reading", all_headers)

		file.close()

	# Forcer "Lesson" en tête
	var ordered_headers = all_headers.duplicate()
	if "Lesson" in ordered_headers:
		ordered_headers.erase("Lesson")
		ordered_headers = ["Lesson"] + ordered_headers

	# Ajouter Categorie à la fin
	ordered_headers.append("Categorie")

	# Écriture du fichier final
	var output_path = lang_path.path_join("booklet.csv")
	var output_file = FileAccess.open(output_path, FileAccess.WRITE)
	if output_file == null:
		push_error("Impossible d'écrire : " + output_path)
		return

	output_file.store_line(escape_csv_line(PackedStringArray(ordered_headers)))
	
	var row_count = columns["Categorie"].size()  # Toutes les colonnes sont synchronisées
	for i in range(row_count):
		var row: PackedStringArray = []
		for header in ordered_headers:
			row.append(columns[header][i])
		output_file.store_line(escape_csv_line(row))

	output_file.close()
	
	error_label.text = "📘 Export des données du livret terminé vers : " + output_path
	print(error_label.text)

# Fonction qui ajoute une ligne au dictionnaire
func add_row(dict, row_data: Dictionary, categorie: String, all_headers: Array):
	# Nombre de lignes déjà enregistrées (doit être égal pour chaque colonne)
	var current_size := 0
	if dict.has("Categorie"):
		current_size= dict["Categorie"].size()

	# S'assurer que toutes les colonnes existantes reçoivent une valeur
	for header in all_headers:
		if not dict.has(header):
			var filler := PackedStringArray()
			filler.resize(current_size) # rattrape les lignes précédentes
			for i in range(current_size):
				filler[i] = ""
			dict[header] = filler
		dict[header].append(row_data.get(header, ""))

	# Colonne spéciale : Categorie
	if not dict.has("Categorie"):
		var filler := PackedStringArray()
		filler.resize(current_size)
		for i in range(current_size):
			filler[i] = ""
		dict["Categorie"] = filler

	dict["Categorie"].append(categorie)


# Parse une ligne CSV même si elle contient des virgules et guillemets
func parse_csv_line(line: String) -> PackedStringArray:
	var result: PackedStringArray = []
	var current = ""
	var in_quotes = false
	var i = 0

	while i < line.length():
		var char = line[i]
		if char == "\"":
			if in_quotes and i + 1 < line.length() and line[i + 1] == "\"":
				current += "\""  # escaped quote
				i += 1
			else:
				in_quotes = !in_quotes
		elif char == "," and not in_quotes:
			result.append(current)
			current = ""
		else:
			current += char
		i += 1

	result.append(current)
	return result

# Transforme une ligne pour l'écriture CSV, avec échappement
func escape_csv_line(fields: PackedStringArray) -> String:
	var output = ""
	for i in range(fields.size()):
		var field = fields[i]
		if field.find("\"") != -1 or field.find(",") != -1 or field.find("\n") != -1:
			field = "\"" + field.replace("\"", "\"\"") + "\""
		output += field
		if i < fields.size() - 1:
			output += ","
	return output

# Normalise les noms de colonnes (ex: writing page -> Writing page)
func normalize_header(name: String) -> String:
	return name.strip_edges()[0].to_upper() + name.strip_edges().substr(1, -1).to_lower()

# Lit une "ligne logique" complète d’un CSV (même si elle est sur plusieurs lignes à cause des guillemets)
func read_csv_record(file: FileAccess) -> String:
	var record := ""
	var open_quotes := false

	while not file.eof_reached():
		var line = file.get_line()
		if record != "":
			record += "\n"
		record += line

		var quote_count = 0
		for c in line:
			if c == "\"":
				quote_count += 1

		open_quotes = (quote_count % 2 != 0)

		if not open_quotes:
			break

	return record


#endregion
