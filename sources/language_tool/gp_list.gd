extends Control

var element_scene: = preload("res://sources/language_tool/gp_list_element.tscn")

@onready var elements_container: = %ElementsContainer
@onready var save_button: = %SaveButton
@onready var back_button: = %BackButton

var undo_redo: = UndoRedo.new()


func _ready() -> void:
	var query: = "Select * FROM GPs"
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


func _process(_delta: float) -> void:
	save_button.visible = undo_redo.has_undo()
	back_button.visible = not undo_redo.has_undo()


func _on_element_delete_pressed(element: Control) -> void:
	undo_redo.create_action("delete")
	undo_redo.add_do_method(elements_container.remove_child.bind(element))
	undo_redo.add_undo_method(elements_container.add_child.bind(element))
	undo_redo.add_undo_method(elements_container.move_child.bind(element, element.get_index()))
	undo_redo.commit_action()


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/language_tool/prof_tool_menu.tscn")
