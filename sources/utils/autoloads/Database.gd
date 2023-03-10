extends Node


const db_path: = "res://language_resources/fr/fr.db"
@onready var db: = SQLite.new()


func _ready() -> void:
	db.path = db_path
	db.open_db()
	_update_gps_with_type()


func _exit_tree() -> void:
	db.close_db()


func get_GP_for_lesson(lesson_nb: int) -> Array:
	db.query_with_bindings("Select Grapheme, Phoneme, LessonNb FROM GPs INNER JOIN Lessons ON Lessons.GPID = GPs.ID AND Lessons.LessonNb == ?", [lesson_nb])
	return db.query_result


func get_GP_before_lesson(lesson_nb: int) -> Array:
	db.query_with_bindings("Select Grapheme, Phoneme, LessonNb FROM GPs INNER JOIN Lessons ON Lessons.GPID = GPs.ID AND Lessons.LessonNb < ?", [lesson_nb])
	return db.query_result


func get_GP_from_word(word: String) -> Array:
	db.query_with_bindings("SELECT Grapheme, Phoneme FROM Words INNER JOIN GPsInWords ON Words.ID = GPsInWords.WordID AND Words.Word=? INNER JOIN GPs WHERE GPS.ID = GPsInWords.GPID ORDER BY Position", [word])
	return db.query_result


func get_words_containing_grapheme(grapheme: String) -> Array:
	db.query_with_bindings("SELECT Word FROM Words INNER JOIN GPsInWords INNER JOIN GPs on Words.ID = GPsInWords.WordID AND GPs.Grapheme=? AND GPS.ID = GPsInWords.GPID", [grapheme])
	return db.query_result


func get_words_for_lesson(lesson_nb: int) -> Array:
	db.query_with_bindings("SELECT DISTINCT Word FROM Words INNER JOIN GPsInWords INNER JOIN GPs INNER JOIN Lessons on Words.ID = GPsInWords.WordID AND GPS.ID = GPsInWords.GPID AND Lessons.GPID = GPs.ID AND Lessons.LessonNb <= ?", [lesson_nb])
	return db.query_result


func get_grapheme_distrators_for_grapheme(grapheme: String, lesson_nb: int) -> Array:
	db.query_with_bindings("SELECT DISTINCT distractor.Grapheme From GPs stimuli INNER JOIN GPs distractor INNER JOIN Lessons ON stimuli.Grapheme=? AND distractor.type = stimuli.type AND distractor.Grapheme != stimuli.Grapheme AND Lessons.GPID = distractor.ID AND Lessons.LessonNb <= ?", [grapheme, lesson_nb])
	return db.query_result


func copy_without_double_graphemes(input: Array) -> Array:
	var output: = []
	var graphemes: = {}
	for val in input:
		if not graphemes.has(val.Grapheme):
			output.append(val)
			graphemes[val.Grapheme] = true
	return output


# Import data from previous Kalulu version

func _import_gps() -> void:
	var file = FileAccess.open("res://data3/gp_list.json", FileAccess.READ)
	var dict = JSON.parse_string(file.get_line())
	for e in dict.values():
		var g = e.GRAPHEME
		var p = e.PHONEME
		db.query_with_bindings("SELECT * FROM GPs WHERE Grapheme=? AND Phoneme=?", [g, p])
		if db.query_result.is_empty():
			db.insert_row("GPs", {Grapheme=g, Phoneme=p})
		db.query_with_bindings("SELECT * FROM GPs WHERE Grapheme=? AND Phoneme=?", [g, p])
		print(db.query_result)


func _update_gps_with_type() -> void:
	var file = FileAccess.open("res://gp_list.json", FileAccess.READ)
	var dict = JSON.parse_string(file.get_line())
	for e in dict.values():
		var g = e.GRAPHEME
		var p = e.PHONEME
		db.query_with_bindings("SELECT * FROM GPs WHERE Grapheme=? AND Phoneme=?", [g, p])
		var id = db.query_result[0].ID
		var type = 0
		if e.CV == "V":
			type = 1
		elif e.CV == "C":
			type = 2
		db.query_with_bindings("UPDATE GPs SET Type=? WHERE id=?", [type, id])


func _import_words() -> void:
	var file = FileAccess.open("res://data3/words_list.json", FileAccess.READ)
	var dict = JSON.parse_string(file.get_line())
	for e in dict.values():
		db.query_with_bindings("SELECT * FROM Words WHERE Word=?", [e.GRAPHEME])
		if db.query_result.is_empty():
			db.insert_row("Words", {Word=e.GRAPHEME})
		db.query_with_bindings("SELECT * FROM Words WHERE Word=?", [e.GRAPHEME])
		var word_id = db.query_result[0]["ID"]
		var GP_list_str: String = e.GPMATCH
		var GP_list: = GP_list_str.split(".")
		for i in GP_list.size():
			var GP_str = GP_list[i]
			var GP = GP_str.split("-")
			db.query_with_bindings("SELECT * FROM GPs WHERE Grapheme=? AND Phoneme=?", [GP[0], GP[1]])
			var GP_id = db.query_result[0]["ID"]
			db.insert_row("GPsInWords", {
				WordID = word_id,
				GPID = GP_id,
				Position = i,
			})


func _import_lessons() -> void:
	var file = FileAccess.open("res://data3/gp_list.json", FileAccess.READ)
	var dict = JSON.parse_string(file.get_line())
	for e in dict.values():
		var g = e.GRAPHEME
		var p = e.PHONEME
		db.query_with_bindings("SELECT * FROM GPs WHERE Grapheme=? AND Phoneme=?", [g, p])
		var GP_id = db.query_result[0]["ID"]
		var lesson_nb: = int(e.LESSON)
		db.insert_row("Lessons", {
			GPID = GP_id,
			LessonNb = lesson_nb
		})
