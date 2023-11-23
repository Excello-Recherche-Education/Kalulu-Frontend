extends MarginContainer

signal delete_pressed()
signal new_GP_asked(grapheme: String)

@onready var word_label: = $%Word
@onready var graphemes_label: = $%Graphemes
@onready var word_edit: = $%WordEdit
@onready var graphemes_edit: = $%GraphemesEdit
@onready var tab_container: = $TabContainer
@onready var popup_menu: = $%Popup

var word: = "":
	set = set_word
var graphemes: = "":
	set = set_graphemes
var phonemes: = "":
	set = set_phonemes
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
	Database.db.query_with_bindings("Select * FROM GPs WHERE Grapheme=?", [graphemes_array[grapheme_ind]])
	var results: = Database.db.query_result
	if results.is_empty():
		popup_menu.no_gp_mode()
	else:
		popup_menu.gp_mode()
	for result in results:
		var is_already_selected: bool = result.Grapheme == graphemes_array[grapheme_ind] and grapheme_ind < phonemes_array.size() and result.Phoneme == phonemes_array[grapheme_ind]
		popup_menu.add_item(result.ID, result.Grapheme + "-" + result.Phoneme, is_already_selected)
		


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
		Database.db.query_with_bindings("SELECT Words.ID as WordId, Word, group_concat(Grapheme, ' ') as Graphemes, group_concat(Phoneme, ' ') as Phonemes, group_concat(GPsInWords.ID, ' ') as GPsInWordsIDs 
			FROM Words 
			INNER JOIN ( SELECT * FROM GPsInWords ORDER BY GPsInWords.Position ) GPsInWords ON Words.ID = GPsInWords.WordID 
			INNER JOIN GPs ON GPS.ID = GPsInWords.GPID
			WHERE Words.ID = ? 
			GROUP BY Words.ID", [id])
		if not Database.db.query_result.is_empty():
			var e = Database.db.query_result[0]
			if word != e.Word:
				Database.db.update_rows("Words", "ID=%s" % id, {Word=word})
			if graphemes != e.Graphemes or phonemes != e.Phonemes:
				var gps_in_words_ids: Array = Array(e.GPsInWordsIDs.split(" "))
				while gps_in_words_ids.size() > gp_ids.size():
					Database.db.delete_rows("GPsInWords", "ID=%s" % int(gps_in_words_ids.pop_back()))
				for i in gps_in_words_ids.size():
					var gps_in_words_id: = int(gps_in_words_ids[i])
					Database.db.update_rows("GPsInWords", "ID=%s" % gps_in_words_id, {WordID=id, GPID=gp_ids[i], Position=i})
				for i in range(gps_in_words_ids.size(), gp_ids.size()):
					Database.db.insert_row("GPsInWords", {WordID=id, GPID=gp_ids[i], Position=i})
			return
			
	Database.db.query_with_bindings("SELECT * FROM Words WHERE Word=?", [word])
	if Database.db.query_result.is_empty():
		Database.db.insert_row("Words", {Word=word})
		id = Database.db.last_insert_rowid
		for i in gp_ids.size():
			Database.db.insert_row("GPsInWords", {WordID=id, GPID=gp_ids[i], Position=i})
