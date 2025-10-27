class_name WordListElement
extends MarginContainer

signal delete_pressed()
signal new_gp_asked(i: int)
signal validated()
signal gps_updated()

const GP_LIST_BUTTON_SCENE: PackedScene = preload("res://sources/language_tool/gp_list_button.tscn")
const PLUS_BUTTON_SCENE: PackedScene = preload("res://sources/language_tool/plus_button.tscn")

@export var table: String = "Words"
@export var table_graph_column: String = "Word"
@export var sub_table: String = "GPs"
@export var sub_table_graph_column: String = "Grapheme"
@export var sub_table_phon_column: String = "Phoneme"
@export var relational_table: String = "GPsInWords"
@export var sub_table_id: String = "GPID"

var word: String = "":
	set = set_word
var lesson: int = 0:
	set = set_lesson
var undo_redo: UndoRedo:
	get:
		if not undo_redo:
			undo_redo = UndoRedo.new()
		return undo_redo
var id: int = -1
var gp_ids: Array[int] = []:
	set = set_gp_ids
var unvalidated_gp_ids: Array[int] = []
var exception: int = 0:
	set = set_exception
var reading: int = 0:
	set = set_reading
var writing: int = 0:
	set = set_writing
var sub_elements_list: Dictionary = {}

@onready var word_label: Label = %Word
@onready var graphemes_label: Label = %Graphemes
@onready var word_edit: LineEdit = %WordEdit
@onready var tab_container: TabContainer = $TabContainer
@onready var lesson_label: Label = %Lesson
@onready var exception_checkbox: CheckBox = %ExceptionCheckBox
@onready var exception_edit_checkbox: CheckBox = %ExceptionEditCheckBox
@onready var reading_checkbox: CheckBox = %ReadingCheckBox
@onready var writing_checkbox: CheckBox = %WritingCheckBox
@onready var reading_edit_checkbox: CheckBox = %ReadingEditCheckBox
@onready var writing_edit_checkbox: CheckBox = %WritingEditCheckBox
@onready var graphemes_edit_container: HBoxContainer = %GraphemesEditContainer
@onready var add_gp_button: MarginContainer = %AddGPButton
@onready var remove_gp_button: MarginContainer = %RemoveGPButton2


func set_exception(p_exception: bool) -> void:
	exception = p_exception
	if exception_checkbox:
		exception_checkbox.button_pressed = bool(exception)
	if exception_edit_checkbox:
		exception_edit_checkbox.button_pressed = bool(exception)


func set_reading(p_reading: bool) -> void:
	reading = p_reading
	if reading_checkbox:
		reading_checkbox.button_pressed = bool(reading)
	if reading_edit_checkbox:
		reading_edit_checkbox.button_pressed = bool(reading)


func set_writing(p_writing: bool) -> void:
	writing = p_writing
	if writing_checkbox:
		writing_checkbox.button_pressed = bool(writing)
	if writing_edit_checkbox:
		writing_edit_checkbox.button_pressed = bool(writing)


func set_word(p_word: String) -> void:
	word = p_word
	if word_label:
		word_label.text = word
	if word_edit:
		word_edit.text = word


func set_gp_ids(p_gp_ids: Array[int]) -> void:
	gp_ids = p_gp_ids
	if graphemes_label:
		graphemes_label.text = get_gps(gp_ids)


func set_graphemes_edit(p_gp_ids: Array[int]) -> void:
	if graphemes_edit_container:
		for child: Node in graphemes_edit_container.get_children():
			graphemes_edit_container.remove_child(child)
			child.queue_free()
		for ind_gp_id: int in range(p_gp_ids.size()):
			var gp_id: int = p_gp_ids[ind_gp_id]
			add_gp_list_button(gp_id, ind_gp_id)


func add_gp_list_button(gp_id: int, ind_gp_id: int) -> void:
	var gp_list_button: GPListButton = GP_LIST_BUTTON_SCENE.instantiate()
	gp_list_button.set_gp_list(sub_elements_list)
	graphemes_edit_container.add_child(gp_list_button)
	graphemes_edit_container.move_child(gp_list_button, 2 * ind_gp_id)
	gp_list_button.select_id(gp_id)
	gp_list_button.gp_selected.connect(_on_gp_list_button_selected.bind(gp_list_button))
	gp_list_button.new_selected.connect(_on_gp_list_button_new_selected.bind(gp_list_button))
	var plus_button: PlusButton = PLUS_BUTTON_SCENE.instantiate()
	plus_button.size = Vector2(50, 50)
	graphemes_edit_container.add_child(plus_button)
	graphemes_edit_container.move_child(plus_button, 2 * ind_gp_id + 1)
	plus_button.pressed.connect(_on_add_gp_button_pressed.bind(gp_list_button))


func _on_gp_list_button_selected(gp_id: int, element: Node) -> void:
	var ind_gp_id: int = int(element.get_index() / 2.0)
	unvalidated_gp_ids[ind_gp_id] = gp_id
	word_edit.text = get_graphemes(unvalidated_gp_ids)


func _on_gp_list_button_new_selected(element: Node) -> void:
	var ind_gp_id: int = int(element.get_index() / 2.0)
	new_gp_asked.emit(ind_gp_id)


func get_graphemes(p_gp_ids: Array[int]) -> String:
	var res: String = ""
	for gp_id: int in p_gp_ids:
		res += sub_elements_list[gp_id].grapheme
	return res


func get_gps(p_gp_ids: Array[int]) -> String:
	var res: String = ""
	for gp_id: int in p_gp_ids:
		res += sub_elements_list[gp_id].grapheme
		res += "-"
		res += sub_elements_list[gp_id].phoneme
		res += " "
	return res


func set_lesson(p_lesson: int) -> void:
	lesson = p_lesson
	if lesson_label:
		lesson_label.text = str(p_lesson)


func _ready() -> void:
	set_word(word)
	set_gp_ids(gp_ids)
	set_lesson(lesson)
	set_exception(exception)
	set_reading(reading)
	set_writing(writing)
	(%WordEditLabel as Label).text = table_graph_column + ": "
	(%GPsEditLabel as Label).text = sub_table + ": "


func _on_edit_button_pressed() -> void:
	edit_mode()


func edit_mode() -> void:
	set_graphemes_edit(gp_ids)
	tab_container.current_tab = 1


func _on_minus_button_pressed() -> void:
	delete_pressed.emit()


func _on_validate_button_pressed() -> void:
	undo_redo.create_action("validated")
	undo_redo.add_do_property(self, "gp_ids", unvalidated_gp_ids.duplicate())
	undo_redo.add_do_property(self, "word", word_edit.text)
	undo_redo.add_do_property(self, "exception", int(exception_edit_checkbox.button_pressed))
	undo_redo.add_do_property(self, "reading", int(reading_edit_checkbox.button_pressed))
	undo_redo.add_do_property(self, "writing", int(writing_edit_checkbox.button_pressed))
	undo_redo.add_undo_property(self, "gp_ids", gp_ids.duplicate())
	undo_redo.add_undo_property(self, "word", word)
	undo_redo.add_undo_property(self, "exception", int(exception_checkbox.button_pressed))
	undo_redo.add_undo_property(self, "reading", int(reading_checkbox.button_pressed))
	undo_redo.add_undo_property(self, "writing", int(writing_checkbox.button_pressed))
	
	undo_redo.commit_action()
	tab_container.current_tab = 0
	update_lesson()
	validated.emit()


func update_lesson() -> void:
	var index: int = -1
	for gp_id: int in gp_ids:
		var min_index: int = Database.get_min_lesson_for_gp_id(gp_id)
		if min_index < 0:
			index = -1
			break
		index = maxi(index, min_index)
	lesson = index


func gp_ids_from_string(p_gp_ids: String) -> Array[int]:
	var res: Array[int] = []
	var pack: PackedStringArray = p_gp_ids.split(" ")
	res.resize(pack.size())
	for index: int in range(pack.size()):
		res[index] = int(pack[index])
	return res


func set_gp_ids_from_string(p_gp_ids: String) -> void:
	gp_ids = gp_ids_from_string(p_gp_ids)
	unvalidated_gp_ids = gp_ids.duplicate()


func insert_in_database() -> void:
	if id < 0:
		Database.db.query_with_bindings("SELECT * FROM %s WHERE %s=?" % [table, table_graph_column], [word])
		if not Database.db.query_result.is_empty():
			id = Database.db.query_result[0].ID
	
	if id >= 0:
		var query: String = "SELECT %s, group_concat(%s, ' ') as %ss, group_concat(%s, ' ') as %ss, group_concat(%s.ID, ' ') as %sIDs, group_concat(%s.ID, ' ') as %sIDs, %s.Exception, %s.Reading, %s.Writing
			FROM %s 
			INNER JOIN ( SELECT * FROM %s ORDER BY %s.Position ) %s ON %s.ID = %s.%sID 
			INNER JOIN %s ON %s.ID = %s.%s
			WHERE %s.ID = ? 
			GROUP BY %s.ID" % [table_graph_column, sub_table_graph_column, sub_table_graph_column,
				sub_table_phon_column, sub_table_phon_column,
				relational_table, relational_table, sub_table, sub_table, table, table, table,
				table,
				relational_table, relational_table, relational_table, table, relational_table, table_graph_column,
				sub_table, sub_table, relational_table, sub_table_id,
				table,
				table]
		Database.db.query_with_bindings(query, [id])
		Log.trace("WordListElement: Sending query to insert in database: %s" % query)
		if not Database.db.query_result.is_empty():
			var element: Dictionary = Database.db.query_result[0]
			if word != element[table_graph_column] or exception != element.Exception or reading != element.Reading or writing != element.Writing:
				Database.db.update_rows(table, "ID=%s" % id, {table_graph_column: word, "Exception": exception, "Reading": reading, "Writing": writing})
			if " ".join(gp_ids) != element[sub_table + "IDs"]:
				var gps_in_words_ids: Array[String] = Array((element[relational_table + "IDs"] as String).split(" "))
				while gps_in_words_ids.size() > gp_ids.size():
					Database.db.delete_rows(relational_table, "ID=%s" % int(gps_in_words_ids.pop_back() as String))
				for index: int in range(gps_in_words_ids.size()):
					var gps_in_words_id: int = int(gps_in_words_ids[index])
					Database.db.update_rows(relational_table, "ID=%s" % gps_in_words_id, {
						table_graph_column + "ID": id,
						sub_table_id: gp_ids[index],
						"Position": index
						})
				for index: int in range(gps_in_words_ids.size(), gp_ids.size()):
					Database.db.insert_row(relational_table, {
						table_graph_column + "ID": id,
						sub_table_id: gp_ids[index],
						"Position": index
						})
			return
		else:
			Database.db.query_with_bindings("SELECT * FROM %s WHERE %s=?" % [table, table_graph_column], [word])
			if not Database.db.query_result.is_empty():
				var element: Dictionary = Database.db.query_result[0]
				id = element.ID
				if word != element[table_graph_column] or exception != element.Exception or reading != element.Reading or writing != element.writing:
					Database.db.update_rows(table, "ID=%s" % id, {table_graph_column: word, "Exception": exception, "Reading": reading, "Writing": writing})
				for index: int in range(gp_ids.size()):
					Database.db.insert_row(relational_table, {
						table_graph_column + "ID": id,
						sub_table_id: gp_ids[index],
						"Position": index
						})
			
	Database.db.query_with_bindings("SELECT * FROM %s WHERE %s=?" % [table, table_graph_column], [word])
	if Database.db.query_result.is_empty():
		Database.db.insert_row(table, {table_graph_column: word})
		id = Database.db.last_insert_rowid
		for index: int in range(gp_ids.size()):
			Database.db.insert_row(relational_table, {
						table_graph_column + "ID": id,
						sub_table_id: gp_ids[index],
						"Position": index
					})


func _already_in_database(text: String) -> int:
	var query: String = "SELECT %s.ID, %s, group_concat(%s, ' ') as %ss, group_concat(%s, ' ') as %ss, group_concat(%s.ID, ' ') as %sIDs 
	FROM %s 
	INNER JOIN ( SELECT * FROM %s ORDER BY %s.Position ) %s ON %s.ID = %s.%sID 
	INNER JOIN %s ON %s.ID = %s.%s
	WHERE %s.%s = ? 
	GROUP BY %s.ID" % [table, table_graph_column, sub_table_graph_column, sub_table_graph_column,
		sub_table_phon_column, sub_table_phon_column,
		relational_table, relational_table,
		table,
		relational_table, relational_table, relational_table, table, relational_table, table_graph_column,
		sub_table, sub_table, relational_table, sub_table_id,
		table, table_graph_column,
		table]
	Database.db.query_with_bindings(query, [text])
	if not Database.db.query_result.is_empty():
		var element: Dictionary = Database.db.query_result[0]
		id = element.ID
		return id
	return -1


func _add_from_additional_word_list(new_text: String) -> int:
	if new_text in Database.additional_word_list:
		var is_word: bool = table == "Words"
		# res contains an int, followed by an array of int
		var res: Array[Variant] = Database._import_word_from_csv(new_text, Database.additional_word_list[new_text].GPMATCH as String, is_word)
		gps_updated.emit()
		id = res[0]
		gp_ids = res[1]
		unvalidated_gp_ids = gp_ids
		return id
	return -1


func _try_to_complete_from_word(new_text: String) -> int:
	var index: int = _already_in_database(new_text)
	if index >= 0:
		Log.trace("WordListElement: Already in DB " + new_text)
		return index
	
	index = _add_from_additional_word_list(new_text)
	if index >= 0:
		return index
	return -1


func _on_word_edit_text_submitted(new_text: String) -> void:
	if _try_to_complete_from_word(new_text) >= 0:
		_on_validate_button_pressed()
		update_lesson()


func _on_remove_gp_button_2_pressed() -> void:
	if graphemes_edit_container.get_child_count() < 2:
		return
	unvalidated_gp_ids.pop_back()
	graphemes_edit_container.get_child(graphemes_edit_container.get_child_count() - 1).queue_free()
	graphemes_edit_container.get_child(graphemes_edit_container.get_child_count() - 2).queue_free()
	word_edit.text = get_graphemes(unvalidated_gp_ids)


func _process(_delta: float) -> void:
	add_gp_button.visible = graphemes_edit_container.get_child_count() <= 0
	remove_gp_button.visible = graphemes_edit_container.get_child_count() > 0


func new_gp_asked_added(ind: int, gp_id: int) -> void:
	unvalidated_gp_ids[ind] = gp_id
	set_graphemes_edit(unvalidated_gp_ids)
	word_edit.text = get_graphemes(unvalidated_gp_ids)


func _on_add_gp_button_pressed(element: Node) -> void:
	var ind_gp_id: int = int(element.get_index() / 2.0)
	var gp_id: int = sub_elements_list.keys()[0]
	unvalidated_gp_ids.insert(ind_gp_id + 1, gp_id)
	add_gp_list_button(gp_id, ind_gp_id + 1)


func _on_empty_add_gp_button_pressed() -> void:
	var gp_id: int = sub_elements_list.keys()[0]
	unvalidated_gp_ids.append(gp_id)
	add_gp_list_button(gp_id, unvalidated_gp_ids.size() - 1)
