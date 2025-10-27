class_name FishWordListElement
extends MarginContainer

@export var word_id: int = 1:
	set = set_word_id
@export var pseudoword: String = "":
	set = set_pseudoword
@export var lesson_nb: int = -1:
	set = set_lesson_nb
@export var pseudoword_id: int = -1

var is_in_line_edit_changed: bool = false
var word: String = ""

@onready var option_button: OptionButton = %OptionButton
@onready var line_edit: LineEdit = %LineEdit
@onready var lesson_label: Label = %LessonLabel


func set_word_id(p_word_id: int) -> void:
	word_id = p_word_id
	if option_button:
		option_button.select(option_button.get_item_index(word_id))
	lesson_nb = Database.get_min_lesson_for_word_id(word_id)
	word = option_button.get_item_text(option_button.get_item_index(word_id))


func set_pseudoword(p_pseudoword: String) -> void:
	pseudoword = p_pseudoword
	if line_edit and not is_in_line_edit_changed:
		line_edit.text = pseudoword


func set_lesson_nb(p_lesson_nb: int) -> void:
	lesson_nb = p_lesson_nb
	if lesson_label:
		lesson_label.text = str(lesson_nb)


func set_word_list(word_list: Array) -> void:
	for word_dic: Dictionary in word_list:
		option_button.add_item(word_dic.Word as String, word_dic.ID as int)


func _on_option_button_item_selected(index: int) -> void:
	word_id = option_button.get_item_id(index)


func _on_line_edit_text_changed(new_text: String) -> void:
	is_in_line_edit_changed = true
	pseudoword = new_text
	is_in_line_edit_changed = false


func _on_button_pressed() -> void:
	queue_free()
