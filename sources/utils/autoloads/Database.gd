extends Node

const _symbols_to_string = {
	"#" : "sharp",
	"@" : "at",
	"*" : "star",
	"$" : "usd",
	"%" : "pcent",
	"§" : "para"
}
const base_path: =  "res://language_resources/"

const look_and_learn_images: = "/look_and_learn/images/"
const look_and_learn_sounds: = "/look_and_learn/sounds/"
const look_and_learn_videos: = "/look_and_learn/video/"
const video_extension: = ".ogv"
const image_extension: = ".png"
const sound_extension: = ".mp3"

var language: = "french":
	set(value):
		language = value
		db_path = base_path + language + "/language.db"
		words_path = base_path + language + "/words/"
var db_path: = base_path + language + "/language.db"
var words_path: = base_path + language + "/words/"

@onready var db: = SQLite.new()


func _ready() -> void:
	db.path = db_path
	db.foreign_keys = true
	db.open_db()
	#_import_lessons()


func _exit_tree() -> void:
	db.close_db()


func get_GP_for_lesson(lesson_nb: int, distinct: bool) -> Array:
	var query: = "Select Grapheme, Phoneme, LessonNb FROM GPs 
	INNER JOIN GPsInLessons ON GPsInLessons.GPID = GPs.ID 
	INNER JOIN Lessons ON Lessons.ID = GPsInLessons.LessonID AND Lessons.LessonNb == ?"
	if distinct:
		query += "GROUP BY Grapheme"
	db.query_with_bindings(query, [lesson_nb])
	return db.query_result


func get_GP_before_lesson(lesson_nb: int, distinct: bool) -> Array:
	var query: = "Select Grapheme, Phoneme, LessonNb FROM GPs 
	INNER JOIN GPsInLessons ON GPsInLessons.GPID = GPs.ID 
	INNER JOIN Lessons ON Lessons.ID = GPsInLessons.LessonID AND Lessons.LessonNb < ?"
	if distinct:
		query += "GROUP BY Grapheme"
	db.query_with_bindings(query, [lesson_nb])
	return db.query_result


func get_GP_before_and_for_lesson(lesson_nb: int, distinct: bool) -> Array:
	var query: = "Select Grapheme, Phoneme, LessonNb FROM GPs 
	INNER JOIN GPsInLessons ON GPsInLessons.GPID = GPs.ID 
	INNER JOIN Lessons ON Lessons.ID = GPsInLessons.LessonID AND Lessons.LessonNb <= ?"
	if distinct:
		query += "GROUP BY Grapheme"
	db.query_with_bindings(query, [lesson_nb])
	return db.query_result


func get_GP_from_word(word: String) -> Array:
	db.query_with_bindings("SELECT Grapheme, Phoneme FROM Words INNER JOIN GPsInWords ON Words.ID = GPsInWords.WordID AND Words.Word=? INNER JOIN GPs WHERE GPS.ID = GPsInWords.GPID ORDER BY Position", [word])
	return db.query_result


func get_words_containing_grapheme(grapheme: String) -> Array:
	db.query_with_bindings("SELECT Word FROM Words INNER JOIN GPsInWords INNER JOIN GPs on Words.ID = GPsInWords.WordID AND GPs.Grapheme=? AND GPS.ID = GPsInWords.GPID", [grapheme])
	return db.query_result


func get_words_for_lesson(lesson_nb: int, only_new: = false) -> Array:
	var query: = "SELECT * FROM Words
	 INNER JOIN 
	(SELECT WordID, count() as Count FROM GPsInWords 
		INNER JOIN GPsInLessons ON GPsInLessons.GPID = GPsInWords.GPID 
		GROUP BY WordID 
		) TotalCount ON TotalCount.WordID = Words.ID 
	INNER JOIN 
	(SELECT WordID, count() as Count FROM GPsInWords 
		INNER JOIN GPsInLessons ON GPsInLessons.GPID = GPsInWords.GPID 
		INNER JOIN Lessons ON Lessons.ID = GPsInLessons.LessonID  AND Lessons.LessonNb <= ? 
		GROUP BY WordID 
		) VerifiedCount ON VerifiedCount.WordID = Words.ID AND VerifiedCount.Count = TotalCount.Count"
	if only_new:
		query += " INNER JOIN GPsInWords ON GPsInWords.WordID = Words.ID 
			INNER JOIN GPsInLessons ON GPsInLessons.GPID = GPsInWords.GPID 
			INNER JOIN Lessons ON Lessons.ID = GPsInLessons.LessonID  AND Lessons.LessonNb = ?"
		db.query_with_bindings(query, [lesson_nb, lesson_nb])
	else:
		db.query_with_bindings(query, [lesson_nb])
	return db.query_result


func get_distractors_for_grapheme(grapheme: String, lesson_nb: int) -> Array:
	db.query_with_bindings("SELECT DISTINCT distractor.Grapheme, distractor.Phoneme From GPs stimuli 
	INNER JOIN GPs distractor 
	INNER JOIN Lessons 
	INNER JOIN GPsInLessons
	ON stimuli.Grapheme=? AND distractor.type = stimuli.type 
	AND distractor.Grapheme != stimuli.Grapheme 
	AND GPsInLessons.GPID = distractor.ID
	AND Lessons.ID = GPsInLessons.LessonID AND Lessons.LessonNb <= ?", [grapheme, lesson_nb])
	return db.query_result


func get_min_lesson_for_gp_id(gp_id: int) -> int:
	db.query_with_bindings("SELECT Lessons.LessonNb as i FROM Lessons
	INNER JOIN GPsInLessons ON Lessons.ID = GPsInLessons.LessonID AND GPsInLessons.GPID = ?", [gp_id])
	if db.query_result.is_empty():
		return -1
	return db.query_result[0].i


func get_min_lesson_for_word_id(word_id: int) -> int:
	db.query_with_bindings("SELECT MAX(Lessons.LessonNb) as i FROM Lessons
	INNER JOIN GPsInLessons ON Lessons.ID = GPsInLessons.LessonID
	INNER JOIN GPsInWords ON GPsInWords.GPID = GPsInLessons.GPID AND GPsInWords.WordID = ?", [word_id])
	return db.query_result[0].i


func get_min_lesson_for_sentence_id(sentence_id: int) -> int:
	db.query_with_bindings("SELECT MAX(Lessons.LessonNb) as i FROM Lessons
	INNER JOIN GPsInLessons ON Lessons.ID = GPsInLessons.LessonID
	INNER JOIN WordsInSentences ON WordsInSentences.SentenceID = ?
	INNER JOIN GPsInWords ON GPsInWords.GPID = GPsInLessons.GPID AND GPsInWords.WordID = WordsInSentences.WordID", [sentence_id])
	return db.query_result[0].i


func get_sentences() -> Array[Dictionary]:
	db.query("SELECT * FROM Sentences")
	return db.query_result


func get_lessons_count() -> int:
	db.query("SELECT MAX(Lessons.LessonNb) as i FROM Lessons")
	return db.query_result[0].i


func get_audio_stream_for_word(word: String) -> AudioStream:
	var GPs: = get_GP_from_word(word)
	var file_name: = _phoneme_to_string(GPs[0].Phoneme)
	for i in range(1, GPs.size()):
		var GP = GPs[i]
		file_name += "-" + _phoneme_to_string(GP.Phoneme)
	file_name += ".mp3"
	return load(words_path + file_name)


func get_audio_stream_for_phoneme(phoneme: String) -> AudioStream:
	var file_name: = _phoneme_to_string(phoneme)
	file_name += ".mp3"
	return load(words_path + file_name)


func get_gp_look_and_learn_image(gp: Dictionary) -> Texture:
	var path: = get_gp_look_and_learn_image_path(gp)
	if FileAccess.file_exists(path):
		if ResourceLoader.exists(path):
			return load(path)
		else:
			var image: = Image.load_from_file(path)
			var texture: = ImageTexture.create_from_image(image)
			return texture
	
	return null


func get_gp_look_and_learn_sound(gp: Dictionary) -> AudioStream:
	var path: = get_gp_look_and_learn_sound_path(gp)
	if FileAccess.file_exists(path):
		if ResourceLoader.exists(path):
			return load(path)
		else:
			var sound: = AudioStreamOggVorbis.load_from_file(path)
			return sound
	
	return AudioStreamOggVorbis.new()


func get_gp_look_and_learn_video(gp: Dictionary) -> VideoStream:
	var path: = get_gp_look_and_learn_video_path(gp)
	if FileAccess.file_exists(path):
		var video: = load(path)
		return video
	
	return null


func get_gp_look_and_learn_image_path(gp: Dictionary) -> String:
	return base_path + language + look_and_learn_images + gp["Grapheme"] + "-" + gp["Phoneme"] + image_extension


func get_gp_look_and_learn_sound_path(gp: Dictionary) -> String:
	return base_path + language + look_and_learn_sounds + gp["Grapheme"] + "-" + gp["Phoneme"] + sound_extension


func get_gp_look_and_learn_video_path(gp: Dictionary) -> String:
	return base_path + language + look_and_learn_videos + gp["Grapheme"] + "-" + gp["Phoneme"] + video_extension


func _phoneme_to_string(phoneme: String) -> String:
	if _symbols_to_string.has(phoneme):
		return _symbols_to_string[phoneme]
	elif phoneme == phoneme.to_lower():
		return phoneme
	else:
		return "cap." + phoneme.to_lower()


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
	var file = FileAccess.open("res://new_gp_list.json", FileAccess.READ)
	var dict = JSON.parse_string(file.get_line())
	for e in dict.values():
		var g = e.GRAPHEME
		var p = e.PHONEME
		db.query_with_bindings("SELECT * FROM GPs WHERE Grapheme=? AND Phoneme=?", [g, p])
		var GP_id = db.query_result[0]["ID"]
		var lesson_nb: = int(e.LESSON)
		db.query_with_bindings("SELECT * FROM Lessons WHERE LessonNb=?", [lesson_nb])
		var lesson_id: = -1
		if db.query_result.is_empty():
			db.insert_row("Lessons", {
				LessonNb = lesson_nb
			})
			lesson_id = db.last_insert_rowid
		else:
			lesson_id = db.query_result[0]["ID"]
		db.insert_row("GPsInLessons", {
			GPID = GP_id,
			LessonID = lesson_id,
		})


func _remove_unusable_words() -> void:
	var file = FileAccess.open("res://words_list.json", FileAccess.READ)
	var dict = JSON.parse_string(file.get_line())
	for e in dict.values():
		if e.USABLE_WORD_GAME == "0":
			db.query_with_bindings("SELECT * FROM Words WHERE Word=?", [e.GRAPHEME])
			if not db.query_result.is_empty():
				var word_id = db.query_result[0]["ID"]
				db.delete_rows("Words", "ID=%s" % word_id)
		
