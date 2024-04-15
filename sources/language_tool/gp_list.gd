extends Control

var element_scene: = preload("res://sources/language_tool/gp_list_element.tscn")

@onready var elements_container: = %ElementsContainer
@onready var error_label: = %ErrorLabel

var undo_redo: = UndoRedo.new()


func _ready() -> void:
	var query: = "Select * FROM GPs ORDER BY GPs.Grapheme"
	Database.db.query(query)
	var result: = Database.db.query_result
	for e in result:
		var element: = element_scene.instantiate()
		element.grapheme = e.Grapheme
		element.phoneme = e.Phoneme
		element.type = e.Type
		element.undo_redo = undo_redo
		element.id = e.ID
		elements_container.add_child(element)
		element.delete_pressed.connect(_on_element_delete_pressed.bind(element))
	
	for pseudo_button in [%Grapheme, %Phoneme, %Type]:
		pseudo_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_undo"):
		undo_redo.undo()
	elif event.is_action_pressed("ui_redo"):
		undo_redo.redo()


func _on_plus_button_pressed() -> void:
	undo_redo.create_action("add")
	var element: = element_scene.instantiate()
	element.grapheme = ""
	element.phoneme = ""
	element.type = 0
	element.undo_redo = undo_redo
	element.delete_pressed.connect(_on_element_delete_pressed.bind(element))
	undo_redo.add_do_method(elements_container.add_child.bind(element))
	undo_redo.add_do_method(elements_container.move_child.bind(element, 0))
	undo_redo.add_undo_method(elements_container.remove_child.bind(element))
	undo_redo.commit_action()
	element.edit_mode()


func _on_save_button_pressed() -> void:
	for element in elements_container.get_children():
		element.insert_in_database()
	var query: = "Select * FROM GPs"
	Database.db.query(query)
	var result: = Database.db.query_result
	for e in result:
		var found: = false
		for element in elements_container.get_children():
			if element.grapheme == e.Grapheme and element.phoneme == e.Phoneme and element.type == e.Type:
				found = true
				break
		if not found:
			Database.db.delete_rows("GPs", "ID=%s" % e.ID)
	undo_redo.clear_history()


func _on_element_delete_pressed(element: Control) -> void:
	undo_redo.create_action("delete")
	undo_redo.add_do_method(elements_container.remove_child.bind(element))
	undo_redo.add_undo_method(elements_container.add_child.bind(element))
	undo_redo.add_undo_method(elements_container.move_child.bind(element, element.get_index()))
	undo_redo.commit_action()


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/language_tool/prof_tool_menu.tscn")



func _on_grapheme_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		_reorder_by("grapheme")


func _reorder_by(property_name: String) -> void:
	var c: = elements_container.get_children()
	c.sort_custom(sorting_function.bind(property_name))
	for e in elements_container.get_children():
		elements_container.remove_child(e)
	for e in c:
		elements_container.add_child(e)


func sorting_function(a, b, property_name) -> bool:
	return a.get(property_name) < b.get(property_name)


func _on_type_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		_reorder_by("type")


func _on_phoneme_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		_reorder_by("phoneme")


func _on_list_title_add_pressed() -> void:
	_on_plus_button_pressed()


func _on_list_title_back_pressed() -> void:
	_on_back_button_pressed()


func _on_list_title_new_search(new_text: String) -> void:
	for e in elements_container.get_children():
		e.visible = e.grapheme.begins_with(new_text)


func _on_list_title_save_pressed() -> void:
	_on_save_button_pressed()


func _on_list_title_import_path_selected(path: String, match_to_file: bool) -> void:
	var file: = FileAccess.open(path, FileAccess.READ)
	var line: = file.get_csv_line()
	if line.size() < 3 or line[0] != "Grapheme" or line[1] != "Phoneme" or line[2] != "Type":
		error_label.text = "Column names should be Grapheme, Phoneme, Type"
		return
	var types_text: = ["Silent", "Vowel", "Consonant"]
	var insert_count: = 0
	var all_data: = {}
	while not file.eof_reached():
		line = file.get_csv_line()
		if line.size() < 3:
			continue
		var type: = types_text.find(line[2])
		if type < 0:
			error_label.text = "Type should be Silent, Vowel or Consonant"
		Database.db.query_with_bindings("SELECT * FROM GPs WHERE Grapheme = ?
		AND Phoneme = ? AND Type = ?", [line[0], line[1], type])
		all_data[[line[0], line[1], type]] = true
		if Database.db.query_result.is_empty():
			Database.db.insert_row("GPs", {
				Grapheme = line[0],
				Phoneme = line[1],
				Type = type,
			})
			insert_count += 1
	get_tree().reload_current_scene()
	
	if match_to_file:
		var query: = "Select * FROM GPs ORDER BY GPs.Grapheme"
		Database.db.query(query)
		var result: = Database.db.query_result
		for e in result:
			if not [e.Grapheme, e.Phoneme, e.Type] in all_data:
				Database.db.delete_rows("GPs", "ID=%s" % e.ID)
