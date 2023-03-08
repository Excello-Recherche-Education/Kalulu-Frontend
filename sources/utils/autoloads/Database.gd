extends Node


const db_path: = "res://language_resources/fr/fr.db"
@onready var db: = SQLite.new()


func _ready() -> void:
	db.path = db_path
	db.open_db()


func _exit_tree() -> void:
	db.close_db()


func get_GP_for_lesson(lesson_nb: int) -> Array:
	db.query_with_bindings("Select Grapheme, Phoneme FROM GPs INNER JOIN Lessons ON Lessons.GPID = GPs.ID AND Lessons.LessonNb <= ?", [lesson_nb])
	return db.query_result


func get_GP_from_word(word: String) -> Array:
	db.query_with_bindings("SELECT Grapheme, Phoneme FROM Words INNER JOIN GPsInWords ON Words.ID = GPsInWords.WordID AND Words.Word=? INNER JOIN GPs WHERE GPS.ID = GPsInWords.GPID ORDER BY Position", [word])
	return db.query_result


func get_words_containing_grapheme(grapheme: String) -> Array:
	db.query_with_bindings("SELECT Word FROM Words INNER JOIN GPsInWords INNER JOIN GPs on Words.ID = GPsInWords.WordID AND GPs.Grapheme=? AND GPS.ID = GPsInWords.GPID", [grapheme])
	return db.query_result


# Import data from previous Kalulu version

func _import_gps(db) -> void:
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


func _import_words(db) -> void:
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


func _import_lessons(db) -> void:
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
