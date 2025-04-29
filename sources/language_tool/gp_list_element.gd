extends MarginContainer
class_name GPListElement

signal delete_pressed()
signal validated()

enum Type {
	Silent,
	Vowel,
	Consonant,
}

@onready var exception_checkbox: CheckBox = %ExceptionCheckBox
@onready var exception_edit_checkbox: CheckBox = %ExceptionEditCheckBox
@onready var grapheme_label: Label = $%Grapheme
@onready var phoneme_label: Label = $%Phoneme
@onready var type_label: Label = $%Type
@onready var grapheme_edit: LineEdit = $%GraphemeEdit
@onready var phoneme_edit: LineEdit = $%PhonemeEdit
@onready var type_edit: OptionButton = $%TypeEdit
@onready var tab_container: TabContainer = $%TabContainer



var grapheme: String = "":
	set = set_grapheme
var phoneme: String = "":
	set = set_phoneme
var type: GPListElement.Type = Type.Silent:
	set = set_type
var exception: bool = false:
	set = set_exception
var id: int = -1
var undo_redo: UndoRedo:
	get:
		if not undo_redo:
			undo_redo = UndoRedo.new()
		return undo_redo


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

func set_exception(p_exception: bool) -> void:
	exception = p_exception
	if exception_checkbox:
		exception_checkbox.button_pressed = bool(exception)
	if exception_edit_checkbox:
		exception_edit_checkbox.button_pressed = bool(exception)


func _ready() -> void:
	set_grapheme(grapheme)
	set_phoneme(phoneme)
	set_type(type)
	set_exception(exception)


func _on_edit_button_pressed() -> void:
	edit_mode()


func _on_validate_button_pressed() -> void:
	undo_redo.create_action("validated")
	undo_redo.add_do_property(self, "exception", int(exception_edit_checkbox.button_pressed))
	undo_redo.add_do_property(self, "grapheme", grapheme_edit.text)
	undo_redo.add_do_property(self, "phoneme", phoneme_edit.text)
	undo_redo.add_do_property(self, "type", type_edit.selected)
	undo_redo.add_undo_property(self, "exception", int(exception_checkbox.button_pressed))
	undo_redo.add_undo_property(self, "grapheme", grapheme)
	undo_redo.add_undo_property(self, "phoneme", phoneme)
	undo_redo.add_undo_property(self, "type", type)
	undo_redo.commit_action()
	tab_container.current_tab = 0
	validated.emit()


func edit_mode() -> void:
	tab_container.current_tab = 1


func _on_minus_button_pressed() -> void:
	delete_pressed.emit()


func insert_in_database() -> void:
	if id >= 0:
		Database.db.query_with_bindings("SELECT * FROM GPs WHERE ID=?", [id])
		if not Database.db.query_result.is_empty():
			var element: Dictionary = Database.db.query_result[0]
			if grapheme != element.Grapheme or phoneme != element.Phoneme or type != element.Type or exception != element.Exception:
				Logger.trace("GPListElement: UPDATING %s" % element.Grapheme)
				Database.db.update_rows("GPs", "ID=%s" % id, {Grapheme=grapheme, Phoneme=phoneme, Type=type, Exception=exception})
			return
			
	Database.db.query_with_bindings("SELECT * FROM GPs WHERE Grapheme=? AND Phoneme=? AND Type=?", [grapheme, phoneme, type])
	if Database.db.query_result.is_empty():
		Database.db.insert_row("GPs", {Grapheme=grapheme, Phoneme=phoneme, Type=type, Exception=exception})
		id = Database.db.last_insert_rowid
