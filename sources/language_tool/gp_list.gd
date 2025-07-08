extends Control

var element_scene: PackedScene = preload("res://sources/language_tool/gp_list_element.tscn")

@onready var elements_container: VBoxContainer = %ElementsContainer
@onready var error_label: Label = %ErrorLabel

var undo_redo: UndoRedo = UndoRedo.new()


func _ready() -> void:
	var query: String = "Select * FROM GPs ORDER BY GPs.Grapheme"
	Database.db.query(query)
	var result: Array[Dictionary] = Database.db.query_result
	for element_dico: Dictionary in result:
		var new_element: GPListElement = element_scene.instantiate()
		new_element.grapheme = element_dico.Grapheme
		new_element.phoneme = element_dico.Phoneme
		new_element.type = element_dico.Type
		new_element.exception = element_dico.Exception
		new_element.undo_redo = undo_redo
		new_element.id = element_dico.ID
		elements_container.add_child(new_element)
		new_element.delete_pressed.connect(_on_element_delete_pressed.bind(new_element))
	
	for pseudo_button: Label in [%Grapheme, %Phoneme, %Type]:
		pseudo_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_undo"):
		undo_redo.undo()
	elif event.is_action_pressed("ui_redo"):
		undo_redo.redo()


func _on_plus_button_pressed() -> void:
	undo_redo.create_action("add")
	var element: GPListElement = element_scene.instantiate()
	element.grapheme = ""
	element.phoneme = ""
	element.type = GPListElement.Type.Silent
	element.exception = false
	element.undo_redo = undo_redo
	element.delete_pressed.connect(_on_element_delete_pressed.bind(element))
	undo_redo.add_do_method(elements_container.add_child.bind(element))
	undo_redo.add_do_method(elements_container.move_child.bind(element, 0))
	undo_redo.add_undo_method(elements_container.remove_child.bind(element))
	undo_redo.commit_action()
	element.edit_mode()


func _on_save_button_pressed() -> void:
	for element: GPListElement in elements_container.get_children():
		element.insert_in_database()
	var query: String = "Select * FROM GPs"
	Database.db.query(query)
	var result: Array[Dictionary] = Database.db.query_result
	for res: Dictionary in result:
		var found: bool = false
		for element: GPListElement in elements_container.get_children():
			if element.grapheme == res.Grapheme and element.phoneme == res.Phoneme and element.type == res.Type and element.exception == res.Exception:
				found = true
				break
		if not found:
			Database.db.delete_rows("GPs", "ID=%s" % res.ID)
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
	Utils.reorder_children_by_property(elements_container, property_name)


func sorting_function(a_node: Node, b_node: Node, property_name: String) -> bool:
	return a_node.get(property_name) < b_node.get(property_name)


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
	for element: GPListElement in elements_container.get_children():
		element.visible = element.grapheme.begins_with(new_text)


func _on_list_title_save_pressed() -> void:
	_on_save_button_pressed()


func _on_list_title_import_path_selected(path: String, match_to_file: bool) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var line: PackedStringArray = file.get_csv_line()
	if line.size() < 4 or line[0] != "Grapheme" or line[1] != "Phoneme" or line[2] != "Type" or line[3] != "Exception":
		error_label.text = "Column names should be Grapheme, Phoneme, Type, Exception"
		return
	var types_text: Array[String] = ["Silent", "Vowel", "Consonant"]
	var all_data: Dictionary = {}
	while not file.eof_reached():
		line = file.get_csv_line()
		if line.size() < 4:
			continue
		var type: int = types_text.find(line[2])
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
				Exception = line[3]
			})
	get_tree().reload_current_scene()
	
	if match_to_file:
		var query: String = "Select * FROM GPs ORDER BY GPs.Grapheme"
		Database.db.query(query)
		var result: Array[Dictionary] = Database.db.query_result
		for element: Dictionary in result:
			if not [element.Grapheme, element.Phoneme, element.Type] in all_data:
				Database.db.delete_rows("GPs", "ID=%s" % element.ID)
