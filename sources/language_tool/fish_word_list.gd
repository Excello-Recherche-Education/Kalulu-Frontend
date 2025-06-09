extends Control

const ELEMENT_SCENE: PackedScene = preload("res://sources/language_tool/fish_word_list_element.tscn")

@onready var elements_container: VBoxContainer = %ElementsContainer

var word_list: Array = []


func _ready() -> void:
	var query: String = "SELECT name FROM sqlite_master WHERE type='table' AND name='Pseudowords'"
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
	
	for word: Dictionary in Database.db.query_result.duplicate():
		var element: FishWordListElement = ELEMENT_SCENE.instantiate()
		elements_container.add_child(element)
		element.set_word_list(word_list)
		element.word_id = word.WordID
		element.pseudoword = word.Pseudoword
		element.pseudoword_id = word.ID
	
	_reorder_by("lesson_nb")


func _reorder_by(property_name: String) -> void:
	var children: Array[Node] = elements_container.get_children()
	children.sort_custom(sorting_function.bind(property_name))
	for element: FishWordListElement in elements_container.get_children():
		elements_container.remove_child(element)
	for element: FishWordListElement in children:
		elements_container.add_child(element)


func sorting_function(a: Node, b: Node, property_name: String) -> bool:
	return a.get(property_name) < b.get(property_name)


func _on_list_title_add_pressed() -> void:
	var element: FishWordListElement = ELEMENT_SCENE.instantiate()
	elements_container.add_child(element)
	element.set_word_list(word_list)


func _on_list_title_back_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/language_tool/prof_tool_menu.tscn")


func _on_list_title_new_search(new_text: String) -> void:
	for element: FishWordListElement in elements_container.get_children():
		element.visible = element.word.begins_with(new_text)


func _on_list_title_save_pressed() -> void:
	var query: String = "SELECT Pseudowords.ID, Pseudowords.Pseudoword, Pseudowords.WordID, Words.Word FROM Pseudowords
	INNER JOIN Words ON Words.ID = Pseudowords.WordID"
	
	Database.db.query(query)
	var db_word_list: Array[Dictionary] = Database.db.query_result.duplicate()
	
	# delete elements that are in the DB but not in the list
	for word: Dictionary in db_word_list:
		var found: bool = false
		for element: FishWordListElement in elements_container.get_children():
			if element.pseudoword_id == word.ID:
				found = true
				break
		if not found:
			Database.db.delete_rows("Pseudowords", "ID=%s" % word.ID)
	
	for element: FishWordListElement in elements_container.get_children():
		var found: bool = false
		if element.pseudoword_id >= 0:
			var query_with_id: String = query + " WHERE Pseudowords.ID = ?"
			Database.db.query_with_bindings(query_with_id, [element.pseudoword_id])
			if not Database.db.query_result.is_empty():
				var word: Dictionary = Database.db.query_result[0]
				found = true
				if element.pseudoword != word.Pseudoword or element.word_id != word.WordID:
					Database.db.update_rows("Pseudowords", "ID = %s" % word.ID, {
						Pseudoword = element.pseudoword,
						WordID = element.word_id,
						})
		if not found:
			Database.db.insert_row("Pseudowords", {
				WordID = element.word_id,
				Pseudoword = element.pseudoword,
			})
	
	_reorder_by("lesson_nb")
