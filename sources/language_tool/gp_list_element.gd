extends MarginContainer

signal delete_pressed()

enum Type {
	Silent,
	Vowel,
	Consonant,
}

@onready var grapheme_label: = $%Grapheme
@onready var phoneme_label: = $%Phoneme
@onready var type_label: = $%Type
@onready var grapheme_edit: = $%GraphemeEdit
@onready var phoneme_edit: = $%PhonemeEdit
@onready var type_edit: = $%TypeEdit
@onready var tab_container: = $%TabContainer


var grapheme: = "":
	set = set_grapheme
var phoneme: = "":
	set = set_phoneme
var type: = Type.Silent:
	set = set_type
var undo_redo: UndoRedo


func set_grapheme(p_grapheme: String) -> void:
	grapheme = p_grapheme
	if grapheme_label:
		grapheme_label.text = grapheme
	if grapheme_edit:
		grapheme_edit.text = grapheme


func set_phoneme(p_phoneme: String) -> void:
	phoneme = p_phoneme
	if phoneme_label:
		phoneme_label.text = phoneme
	if phoneme_edit:
		phoneme_edit.text = phoneme


func set_type(p_type: Type) -> void:
	type = p_type
	if type_label:
		type_label.text = Type.keys()[type]
	if type_edit:
		type_edit.selected = type


func _ready() -> void:
	set_grapheme(grapheme)
	set_phoneme(phoneme)
	set_type(type)


func _on_edit_button_pressed() -> void:
	edit_mode()


func _on_validate_button_pressed() -> void:
	undo_redo.create_action("validated")
	undo_redo.add_do_property(self, "grapheme", grapheme_edit.text)
	undo_redo.add_do_property(self, "phoneme", phoneme_edit.text)
	undo_redo.add_do_property(self, "type", type_edit.selected)
	undo_redo.add_undo_property(self, "grapheme", grapheme)
	undo_redo.add_undo_property(self, "phoneme", phoneme)
	undo_redo.add_undo_property(self, "type", type)
	undo_redo.commit_action()
	tab_container.current_tab = 0


func edit_mode() -> void:
	tab_container.current_tab = 1


func _on_minus_button_pressed() -> void:
	delete_pressed.emit()
