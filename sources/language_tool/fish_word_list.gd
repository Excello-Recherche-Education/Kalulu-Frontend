extends Control

const element_scene: = preload("res://sources/language_tool/fish_word_list_element.tscn")

@onready var elements_container: = %ElementsContainer

var word_list: Array


func _ready() -> void:
	var query: = "SELECT name FROM sqlite_master WHERE type='table' AND name='Pseudowords'"
	Database.db.query(query)
	if Database.db.query_result.is_empty():
		Database.db.query("CREATE TABLE 'Pseudowords' (
			'ID'	INTEGER NOT NULL UNIQUE,
			'Pseudoword'	TEXT,
			'WordID'	INTEGER NOT NULL,
			PRIMARY KEY('ID' AUTOINCREMENT),
			FOREIGN KEY('WordID') REFERENCES 'Words'('ID') ON UPDATE CASCADE ON DELETE CASCADE
		)")

	
	query = "SELECT ID, Word FROM Words WHERE Words.Exception = 0"
	Database.db.query(query)
	word_list = Database.db.query_result.duplicate()
	
	query = "SELECT Pseudowords.ID, Pseudowords.Pseudoword, Pseudowords.WordID, Words.Word FROM Pseudowords
	INNER JOIN Words ON Words.ID = Pseudowords.WordID"
	
	Database.db.query(query)
	
	for word in Database.db.query_result.duplicate():
		var element: = element_scene.instantiate()
		elements_container.add_child(element)
		element.set_word_list(word_list)
		element.word_id = word.WordID
		element.pseudoword = word.Pseudoword
	
	_reorder_by("lesson_nb")


func _reorder_by(property_name: String) -> void:
	var c: = elements_container.get_children()
	c.sort_custom(sorting_function.bind(property_name))
	for e in elements_container.get_children():
		elements_container.remove_child(e)
	for e in c:
		elements_container.add_child(e)


func sorting_function(a, b, property_name) -> bool:
	return a.get(property_name) < b.get(property_name)


func _on_list_title_add_pressed() -> void:
	var element: = element_scene.instantiate()
	elements_container.add_child(element)
	element.set_word_list(word_list)


func _on_list_title_back_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/language_tool/prof_tool_menu.tscn")


func _on_list_title_new_search(new_text: String) -> void:
	for element in elements_container.get_children():
		element.visible = element.word.begins_with(new_text)


func _on_list_title_save_pressed() -> void:
	var query: = "SELECT Pseudowords.ID, Pseudowords.Pseudoword, Pseudowords.WordID, Words.Word FROM Pseudowords
	INNER JOIN Words ON Words.ID = Pseudowords.WordID"
	
	Database.db.query(query)
	var db_word_list: = Database.db.query_result.duplicate()
	
	# delete elements that are in the DB but not in the list
	for word in db_word_list:
		var found: = false
		for element in elements_container.get_children():
			if element.word_id == word.ID:
				found = true
				break
		if not found:
			Database.db.delete_rows("Pseudowords", "ID=%s" % word.ID)
	
	for element in elements_container.get_children():
		var found: = false
		for word in db_word_list:
			if element.word_id == word.ID:
				found = true
				if element.pseudoword != word.Pseudoword:
					Database.db.update_rows("Pseudowords", "Pseudoword", element.pseudoword)
				break
		if not found:
			Database.db.insert_row("Pseudowords", {
				WordID = element.word_id,
				Pseudoword = element.pseudoword,
			})
	
	_reorder_by("lesson_nb")
