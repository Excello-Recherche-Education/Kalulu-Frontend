extends MarginContainer

signal delete_pressed()
signal new_GP_asked(grapheme: String)
signal validated()

@export var table: = "Words"
@export var table_graph_column: = "Word"
@export var sub_table: = "GPs"
@export var sub_table_graph_column: = "Grapheme"
@export var sub_table_phon_column: = "Phoneme"
@export var relational_table: = "GPsInWords"
@export var sub_table_id: = "GPID"

@onready var word_label: = %Word
@onready var graphemes_label: = %Graphemes
@onready var word_edit: = %WordEdit
@onready var graphemes_edit: = %GraphemesEdit
@onready var tab_container: = $TabContainer
@onready var popup_menu: = %Popup
@onready var lesson_label: = %Lesson

var word: = "":
	set = set_word
var graphemes: = "":
	set = set_graphemes
var phonemes: = "":
	set = set_phonemes
var lesson: = 0:
	set = set_lesson
var undo_redo: UndoRedo:
	get:
		if not undo_redo:
			undo_redo = UndoRedo.new()
		return undo_redo
var id: = -1
var gp_ids: Array[int] = []
var prev_caret_position: int = 0
var unvalidated_graphemes: = ""
var unvalidated_phonemes: = ""
var unvalidated_gp_ids: Array[int] = []


func set_word(p_word: String) -> void:
	word = p_word
	if word_label:
		word_label.text = word
	if word_edit:
		word_edit.text = word


func set_graphemes(p_graphemes: String) -> void:
	graphemes = p_graphemes
	if graphemes_label:
		_set_graphemes_label()
	if graphemes_edit:
		graphemes_edit.text = graphemes
	unvalidated_graphemes = graphemes


func set_lesson(p_lesson: int) -> void:
	lesson = p_lesson
	if lesson_label:
		lesson_label.text = str(p_lesson)


func _set_graphemes_label() -> void:
	var graphemes_array: = graphemes.split(" ", false)
	var phonemes_array: = phonemes.split(" ", false)
	graphemes_label.text = ""
	for i in graphemes_array.size():
		if i > 0:
			graphemes_label.text += " "
		graphemes_label.text += graphemes_array[i]
		if i < phonemes_array.size():
			graphemes_label.text += "-" + phonemes_array[i]


func set_phonemes(p_phonemes: String) -> void:
	phonemes = p_phonemes
	if graphemes_label:
		_set_graphemes_label()
	unvalidated_phonemes = phonemes


func _ready() -> void:
	set_word(word)
	set_graphemes(graphemes)
	set_lesson(lesson)
	popup_menu.button.text = "Add new %s" % sub_table


func _on_edit_button_pressed() -> void:
	edit_mode()


func edit_mode() -> void:
	tab_container.current_tab = 1


func _on_minus_button_pressed() -> void:
	delete_pressed.emit()


func _on_validate_button_pressed() -> void:
	popup_menu.clear(-1)
	undo_redo.create_action("validated")
	undo_redo.add_do_property(self, "graphemes", unvalidated_graphemes)
	undo_redo.add_do_property(self, "phonemes", unvalidated_phonemes)
	undo_redo.add_do_property(self, "gp_ids", unvalidated_gp_ids.duplicate())
	undo_redo.add_do_property(self, "word", word_edit.text)
	undo_redo.add_undo_property(self, "graphemes", graphemes)
	undo_redo.add_undo_property(self, "phonemes", phonemes)
	undo_redo.add_undo_property(self, "gp_ids", gp_ids.duplicate())
	undo_redo.add_undo_property(self, "word", word)
	undo_redo.commit_action()
	tab_container.current_tab = 0
	update_lesson()
	validated.emit()


func update_lesson() -> void:
	var m: = -1
	for gp_id in gp_ids:
		var i: = Database.get_min_lesson_for_gp_id(gp_id)
		m = max(m, i)
	lesson = m


func _get_selected_grapheme(graphemes_array: PackedStringArray) -> int:
	var graphemes_count: = []
	graphemes_count.resize(graphemes_array.size())
	var grapheme_ind: = 0
	for i in graphemes_array.size():
		if i == 0:
			graphemes_count[i] = graphemes_array[i].length()
		else:
			graphemes_count[i] = graphemes_count[i-1] + 1 + graphemes_array[i].length()
		if graphemes_count[i] >= graphemes_edit.caret_column:
			grapheme_ind = i
			break
	return grapheme_ind


func _on_popup_gp_selected(ind: int, gp_id: int, text: String) -> void:
	var graphemes_array: PackedStringArray = graphemes_edit.text.split(" ", false)
	var phonemes_array: PackedStringArray = unvalidated_phonemes.split(" ", false)
	if ind >= graphemes_array.size():
		return
	#var grapheme_ind: = _get_selected_grapheme(graphemes_array)
	var gp_array: PackedStringArray = text.split("-")
	graphemes_array[ind] = gp_array[0]
	if phonemes_array.size() <= ind:
		phonemes_array.resize(ind + 1)
	if unvalidated_gp_ids.size() <= ind:
		unvalidated_gp_ids.resize(ind + 1)
	phonemes_array[ind] = gp_array[1]
	unvalidated_gp_ids[ind] = gp_id
	unvalidated_graphemes = " ".join(graphemes_array)
	unvalidated_phonemes = " ".join(phonemes_array)
	graphemes_edit.grab_focus()
	graphemes_edit.caret_column = prev_caret_position


func _on_graphemes_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		return
	prev_caret_position = graphemes_edit.caret_column
	var graphemes_array: PackedStringArray = graphemes_edit.text.split(" ", false)
	if graphemes_array.is_empty():
		return
	var phonemes_array: PackedStringArray = unvalidated_phonemes.split(" ", false)
	var grapheme_ind: int = _get_selected_grapheme(graphemes_array)
	if phonemes_array.size() > graphemes_array.size():
		phonemes_array.remove_at(grapheme_ind + 1)
		unvalidated_gp_ids.remove_at(grapheme_ind + 1)
		unvalidated_graphemes = " ".join(graphemes_array)
		unvalidated_phonemes = " ".join(phonemes_array)
	popup_menu.show()
	popup_menu.position = graphemes_edit.global_position + Vector2(0, graphemes_edit.size.y)
	popup_menu.size = Vector2(graphemes_edit.size.x, 0)
	popup_menu.clear(grapheme_ind)
	Database.db.query_with_bindings("Select * FROM %s WHERE %s=?" % [sub_table, sub_table_graph_column], [graphemes_array[grapheme_ind]])
	var results: = Database.db.query_result
	if results.is_empty():
		popup_menu.no_gp_mode()
	else:
		popup_menu.gp_mode()
	for result in results:
		var is_already_selected: bool = result[sub_table_graph_column] == graphemes_array[grapheme_ind] and grapheme_ind < phonemes_array.size() and result[sub_table_phon_column] == phonemes_array[grapheme_ind]
		popup_menu.add_item(result.ID, result[sub_table_graph_column] + "-" + result[sub_table_phon_column], is_already_selected)
		


func _on_graphemes_edit_focus_entered() -> void:
	popup_menu.show()


func _on_graphemes_edit_focus_exited() -> void:
	popup_menu.hide()


func _on_popup_focus_changed(p_has_focus: bool) -> void:
	popup_menu.visible = p_has_focus


func _on_popup_new_gp_asked() -> void:
	var graphemes_array: PackedStringArray = graphemes_edit.text.split(" ", false)
	var grapheme: = ""
	if popup_menu.grapheme_ind < graphemes_array.size():
		grapheme = graphemes_array[popup_menu.grapheme_ind]
	new_GP_asked.emit(grapheme)


func gp_ids_from_string(p_gp_ids: String) -> Array[int]:
	var res: Array[int] = []
	var s: = p_gp_ids.split(" ")
	res.resize(s.size())
	for i in s.size():
		res[i] = int(s[i])
	return res


func set_gp_ids_from_string(p_gp_ids: String) -> void:
	gp_ids = gp_ids_from_string(p_gp_ids)
	unvalidated_gp_ids = gp_ids.duplicate()


func insert_in_database() -> void:
	if id >= 0:
		var query: = "SELECT %s, group_concat(%s, ' ') as %ss, group_concat(%s, ' ') as %ss, group_concat(%s.ID, ' ') as %sIDs 
			FROM %s 
			INNER JOIN ( SELECT * FROM %s ORDER BY %s.Position ) %s ON %s.ID = %s.%sID 
			INNER JOIN %s ON %s.ID = %s.%s
			WHERE %s.ID = ? 
			GROUP BY %s.ID" % [table_graph_column, sub_table_graph_column, sub_table_graph_column,
				sub_table_phon_column, sub_table_phon_column,
				relational_table, relational_table,
				table,
				relational_table, relational_table, relational_table, table, relational_table, table_graph_column,
				sub_table, sub_table, relational_table, sub_table_id,
				table,
				table]
		Database.db.query_with_bindings(query, [id])
		print(query)
		if not Database.db.query_result.is_empty():
			var e = Database.db.query_result[0]
			if word != e[table_graph_column]:
				Database.db.update_rows(table, "ID=%s" % id, {table_graph_column: word})
			if graphemes != e[sub_table_graph_column + "s"] or phonemes != e[sub_table_phon_column + "s"]:
				var gps_in_words_ids: Array = Array(e[relational_table + "IDs"].split(" "))
				while gps_in_words_ids.size() > gp_ids.size():
					Database.db.delete_rows(relational_table, "ID=%s" % int(gps_in_words_ids.pop_back()))
				for i in gps_in_words_ids.size():
					var gps_in_words_id: = int(gps_in_words_ids[i])
					Database.db.update_rows(relational_table, "ID=%s" % gps_in_words_id, {
						table_graph_column + "ID": id,
						sub_table_id: gp_ids[i],
						"Position": i
						})
				for i in range(gps_in_words_ids.size(), gp_ids.size()):
					Database.db.insert_row(relational_table, {
						table_graph_column + "ID": id,
						sub_table_id: gp_ids[i],
						"Position": i
						})
			return
			
	Database.db.query_with_bindings("SELECT * FROM %s WHERE %s=?" % [table, table_graph_column], [word])
	if Database.db.query_result.is_empty():
		Database.db.insert_row(table, {table_graph_column: word})
		id = Database.db.last_insert_rowid
		for i in gp_ids.size():
			Database.db.insert_row(relational_table, {
						table_graph_column + "ID": id,
						sub_table_id: gp_ids[i],
						"Position": i
					})


func _already_in_database(text: String) -> int:
	var query: = "SELECT ID, %s, group_concat(%s, ' ') as %ss, group_concat(%s, ' ') as %ss, group_concat(%s.ID, ' ') as %sIDs 
	FROM %s 
	INNER JOIN ( SELECT * FROM %s ORDER BY %s.Position ) %s ON %s.ID = %s.%sID 
	INNER JOIN %s ON %s.ID = %s.%s
	WHERE %s.%s = ? 
	GROUP BY %s.ID" % [table_graph_column, sub_table_graph_column, sub_table_graph_column,
		sub_table_phon_column, sub_table_phon_column,
		relational_table, relational_table,
		table,
		relational_table, relational_table, relational_table, table, relational_table, table_graph_column,
		sub_table, sub_table, relational_table, sub_table_id,
		table, table_graph_column,
		table]
	Database.db.query_with_bindings(query, [text])
	if not Database.db.query_result.is_empty():
		var e = Database.db.query_result[0]
		graphemes_edit.text = e[sub_table_graph_column + "s"]
		id = e.ID
		return id
	return -1


func _add_from_additional_word_list(new_text: String) -> int:
	if new_text in Database.additional_word_list:
		var res: = Database._import_word_from_csv(new_text, Database.additional_word_list[new_text].GPMATCH)
		id = res[0]
		gp_ids = res[1]
		unvalidated_gp_ids = gp_ids
		graphemes = " ".join(Database.additional_word_list[new_text].GPMATCH.trim_prefix('(').trim_suffix(')').split('.'))
		return id
	return -1


func _try_to_complete_from_word(new_text: String) -> int:
	var id: = _already_in_database(new_text)
	if id >= 0:
		return id
	
	id = _add_from_additional_word_list(new_text)
	if id >= 0:
		return id
	
	return -1


func _on_word_edit_text_submitted(new_text: String) -> void:
	if _try_to_complete_from_word(new_text) >= 0:
		_on_validate_button_pressed()
		update_lesson()
		
	graphemes_edit.grab_focus()
