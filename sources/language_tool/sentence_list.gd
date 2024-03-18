extends "res://sources/language_tool/word_list.gd"

@onready var not_found_label: = %NotFoundLabel


func create_sub_elements_list() -> void:
	super()
	new_gp.sub_elements_list = sub_elements_list.duplicate()
	sub_elements_list.clear()
	Database.db.query("Select Words.ID as ID, Words.Word as Word, group_concat(GPs.Phoneme, '') as Phonemes
	FROM Words
	INNER JOIN GPsInWords ON GPsInWords.WordID = Words.ID
	INNER JOIN GPs ON GPs.ID = GPsInWords.GPID
	GROUP BY Words.ID
	ORDER BY Words.Word")
	for e in Database.db.query_result:
		sub_elements_list[e.ID] = {
			grapheme = e.Word,
			phoneme = e.Phonemes
		}


func get_lesson_for_element(id: int) -> int:
	return Database.get_min_lesson_for_sentence_id(id) + 1


func _on_list_title_new_search(new_text: String) -> void:
	for e in elements_container.get_children():
		var found: = false
		for word in e.word.split(" "):
			if word.begins_with(new_text):
				found = true
				break
		e.visible = found


func _ready() -> void:
	super()
	connect_not_found()


func connect_not_found() -> void:
	for element in elements_container.get_children():
		if not element.not_found.is_connected(_on_not_found):
			element.not_found.connect(_on_not_found)


func _on_plus_button_pressed() -> void:
	super()
	connect_not_found()


func _on_not_found(text: String) -> void:
	not_found_label.text = text
