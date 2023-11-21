extends MarginContainer

signal delete_pressed()

@onready var word_label: = $%Word
@onready var graphemes_label: = $%Graphemes
@onready var word_edit: = $%WordEdit
@onready var graphemes_edit: = $%GraphemesEdit
@onready var tab_container: = $TabContainer

var word: = "":
	set = set_word
var graphemes: = "":
	set = set_graphemes
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
		graphemes_label.text = graphemes
	if graphemes_edit:
		graphemes_edit.text = graphemes


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


func _on_graphemes_edit_text_changed(new_text: String) -> void:
	pass # Replace with function body.
