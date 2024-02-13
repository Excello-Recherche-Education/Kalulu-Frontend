extends Control

const base_path: = "user://language_resources/"
const save_file_path: = "user://prof_tool_save.tres"
var save_file: ProfToolSave

@onready var language_select_button: = %LanguageSelectButton
@onready var new_language_container: = %NewLanguageContainer
@onready var line_edit: = %LineEdit
@onready var file_dialog: = $FileDialog
@onready var add_word_list_button: = $AddWordListButton


func _ready() -> void:
	_update_add_word_list_button()
	if not ResourceLoader.exists(save_file_path):
		save_file = ProfToolSave.new()
		save_file.resource_path = save_file_path
		ResourceSaver.save(save_file, save_file_path)
	save_file = load(save_file_path)
	
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


func _on_export_button_pressed() -> void:
	for i in Database.get_lessons_count():
		print("Lesson %s --------------------" % i)
		print("\t \t Words ---")
		var words: = ""
		for e in Database.get_words_for_lesson(i, true):
			words += e.Word + ", "
		print(words.trim_suffix(", "))
		print("\n")
		print("\t \t Sentences ---")
		for e in Database.get_sentences_for_lesson(i, true):
			print(e.Sentence)
		print("\n\n")
	var folder_zipper: = FolderZipper.new()
	folder_zipper.compress("user://language_resources/", "user://language_export.zip")


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
			else:
				continue
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
	DirAccess.copy_absolute("res://language_resources/model_database.db", base_path.path_join(new_text).path_join("language.db"))
	save_file.selected_language = new_text
	ResourceSaver.save(save_file, save_file_path)
	get_tree().reload_current_scene()



func _word_list_file_selected(file_path: String) -> void:
	if FileAccess.file_exists(file_path):
		DirAccess.copy_absolute(file_path, Database.get_additional_word_list_path())
		Database.load_additional_word_list()


func _on_add_word_list_button_pressed() -> void:
	file_dialog.filters = []
	file_dialog.add_filter("*.csv", "csv")
	
	for connection in file_dialog.file_selected.get_connections():
		connection["signal"].disconnect(connection["callable"])
	
	file_dialog.file_selected.connect(_word_list_file_selected)
	
	file_dialog.show()
	_update_add_word_list_button()


