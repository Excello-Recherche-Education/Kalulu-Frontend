extends MarginContainer

signal delete_pressed()

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
var undo_redo: UndoRedo


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


func _set_graphemes_label() -> void:
	var graphemes_array: = graphemes.split(" ")
	var phonemes_array: = phonemes.split(" ")
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
	undo_redo.create_action("validated")
	undo_redo.add_do_property(self, "graphemes", graphemes_edit.text)
	undo_redo.add_do_property(self, "word", word_edit.text)
	undo_redo.add_undo_property(self, "graphemes", graphemes)
	undo_redo.add_undo_property(self, "word", word)
	undo_redo.commit_action()
	tab_container.current_tab = 0


func _process(_delta: float) -> void:
	if graphemes_edit.has_focus():
		var graphemes_array: PackedStringArray = graphemes_edit.text.split(" ")
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
		popup_menu.show()
		popup_menu.position = graphemes_edit.global_position + Vector2(0, graphemes_edit.size.y)
		popup_menu.size = Vector2(graphemes_edit.size.x, 0)
		popup_menu.clear()
		Database.db.query_with_bindings("Select Grapheme, Phoneme FROM GPs WHERE Grapheme=?", [graphemes_array[grapheme_ind]])
		for result in Database.db.query_result:
			popup_menu.add_item(result.Grapheme + "-" + result.Phoneme, false)
	elif not graphemes_edit.has_focus():
		popup_menu.hide()
	else:
		graphemes_edit.get_window().grab_focus()


