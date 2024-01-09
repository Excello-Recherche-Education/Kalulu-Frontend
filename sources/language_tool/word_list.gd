extends Control

@export var element_scene: = preload("res://sources/language_tool/word_list_element.tscn")

@onready var elements_container: = %ElementsContainer
@onready var save_button: = %SaveButton
@onready var new_gp_layer: = $NewGPLayer
@onready var new_gp: = %NewGP
@onready var back_button: = %BackButton

var undo_redo: = UndoRedo.new()
var in_new_gp_mode: = false:
	set = set_in_new_gp_mode
var _e


func _ready() -> void:
	_e = element_scene.instantiate()
	
	Database.db.query(_get_query())
	
	var results: = Database.db.query_result
	for e in results:
		var element: = element_scene.instantiate()
		element.word = e[_e.table_graph_column]
		element.graphemes = e[_e.sub_table_graph_column + "s"]
		element.phonemes = e[_e.sub_table_phon_column + "s"]
		element.id = e[_e.table_graph_column + "Id"]
		element.set_gp_ids_from_string(_e.sub_table_id + "s")
		elements_container.add_child(element)
		element.undo_redo = undo_redo
		element.delete_pressed.connect(_on_element_delete_pressed.bind(element))
		element.new_GP_asked.connect(_on_element_new_GP_asked)


func _get_query() -> String:
	return "SELECT %s.ID as %sId, %s, group_concat(%s, ' ') as %ss, group_concat(%s, ' ') as %ss, group_concat(%s.ID, ' ') as %ss 
			FROM %s 
			INNER JOIN ( SELECT * FROM %s ORDER BY %s.Position ) %s ON %s.ID = %s.%sID 
			INNER JOIN %s ON %s.ID = %s.%s
			GROUP BY %s.ID" % [_e.table, _e.table_graph_column,
				_e.table_graph_column, _e.sub_table_graph_column, _e.sub_table_graph_column,
				_e.sub_table_phon_column, _e.sub_table_phon_column,
				_e.sub_table, _e.sub_table_id,
				_e.table,
				_e.relational_table, _e.relational_table, _e.relational_table, _e.table, _e.relational_table, _e.table_graph_column,
				_e.sub_table, _e.sub_table, _e.relational_table, _e.sub_table_id,
				_e.table]


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_undo"):
		undo_redo.undo()
	elif event.is_action_pressed("ui_redo"):
		undo_redo.redo()


func _on_element_delete_pressed(element: Control) -> void:
	undo_redo.create_action("delete")
	undo_redo.add_do_method(elements_container.remove_child.bind(element))
	undo_redo.add_undo_method(elements_container.add_child.bind(element))
	undo_redo.add_undo_method(elements_container.move_child.bind(element, element.get_index()))
	undo_redo.commit_action()


func _on_plus_button_pressed() -> void:
	undo_redo.create_action("add")
	var element: = element_scene.instantiate()
	element.word = ""
	element.graphemes = ""
	element.undo_redo = undo_redo
	element.delete_pressed.connect(_on_element_delete_pressed.bind(element))
	element.new_GP_asked.connect(_on_element_new_GP_asked)
	undo_redo.add_do_method(elements_container.add_child.bind(element))
	undo_redo.add_do_method(elements_container.move_child.bind(element, 0))
	undo_redo.add_undo_method(elements_container.remove_child.bind(element))
	undo_redo.commit_action()
	element.edit_mode()


func _process(_delta: float) -> void:
	save_button.visible = undo_redo.has_undo()
	back_button.visible = not undo_redo.has_undo()


func _on_element_new_GP_asked(grapheme: String) -> void:
	in_new_gp_mode = true
	new_gp[_e.sub_table_graph_column.to_lower()] = grapheme
	new_gp.edit_mode()


func set_in_new_gp_mode(p_in_new_gp_mode: bool) -> void:
	in_new_gp_mode = p_in_new_gp_mode
	new_gp_layer.visible = in_new_gp_mode


func _on_gp_list_element_validated() -> void:
	new_gp.insert_in_database()
	in_new_gp_mode = false


func _on_save_button_pressed() -> void:
	for element in elements_container.get_children():
		element.insert_in_database()
	Database.db.query(_get_query())
	var result: = Database.db.query_result
	for e in result:
		var found: = false
		for element in elements_container.get_children():
			if element.graphemes == e[_e.sub_table_graph_column + "s"] and element.phonemes == e[_e.sub_table_phon_column + "s"] and element.word == e[_e.table_graph_column]:
				found = true
				break
		if not found:
			Database.db.delete_rows(_e.table, "ID=%s" % e[_e.table_graph_column + "Id"])
	undo_redo.clear_history()



func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/language_tool/prof_tool_menu.tscn")
