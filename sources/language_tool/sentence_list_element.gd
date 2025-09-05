class_name SentenceListElement
extends WordListElement

signal not_found(text: String)

const WORD_LIST_ELEMENT_SCENE: PackedScene = preload("res://sources/language_tool/word_list_element.tscn")

var words_not_founds: PackedStringArray


func _ready() -> void:
	super()
	graphemes_label.hide()


func update_lesson() -> void:
	var highest_min_lesson: int = -1

	# Iterate over each word ID (gp_id)
	for word_id: int in gp_ids:
		# Get the minimum lesson in which this word appears
		var min_lesson_for_word: int = Database.get_min_lesson_for_word_id(word_id)

		# If word not found in any lesson, invalidate the result and stop
		if min_lesson_for_word < 0:
			highest_min_lesson = -1
			break

		# Keep track of the highest minimum lesson required
		highest_min_lesson = max(highest_min_lesson, min_lesson_for_word)

	# Update the global lesson value
	lesson = highest_min_lesson


func _add_from_additional_word_list(new_text: String) -> int:
	var punc: String = "'!()[]{};:'\"\\,<>./?@#$%^&*_~"
	var new_text_clean: String = new_text.to_lower()
	for chara: String in punc:
		new_text_clean = new_text_clean.replace(chara, " ")
	var word_list_element: WordListElement = WORD_LIST_ELEMENT_SCENE.instantiate()
	var all_found: bool = true
	words_not_founds.clear()
	var word_ids: Array[int] = []
	for word_element: String in new_text_clean.split(" ", false):
		var word_id: int = word_list_element._try_to_complete_from_word(word_element)
		word_ids.append(word_id)
		if word_id < 0:
			all_found = false
			words_not_founds.append(word_element)
	gps_updated.emit()
	word_list_element.free()
	if all_found:
		gp_ids = word_ids
		unvalidated_gp_ids = gp_ids
		
		Database.db.insert_row("Sentences", {
			Sentence = new_text,
		})
		id = Database.db.last_insert_rowid
		for index: int in range(word_ids.size()):
			var word_id: int = word_ids[index]
			Database.db.insert_row("WordsInSentences", {
				WordID = word_id,
				SentenceID = id,
				Position = index
			})
		return id
	var not_found_text: String = "Not found:"
	for word_not_found: String in words_not_founds:
		not_found_text += " " + word_not_found 
	not_found.emit(not_found_text)
	return -1


func get_graphemes(p_gp_ids: Array[int]) -> String:
	var res: Array[String] = []
	for gp_id: int in p_gp_ids:
		res.append(sub_elements_list[gp_id].grapheme)
	return " ".join(res)
