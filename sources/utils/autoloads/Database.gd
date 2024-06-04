@tool
extends Node

const _symbols_to_string = {
	"#" : "sharp",
	"@" : "at",
	"*" : "star",
	"$" : "usd",
	"%" : "pcent",
	"§" : "para"
}
const base_path: =  "user://language_resources/"
const look_and_learn_images: = "/look_and_learn/images/"
const look_and_learn_sounds: = "/look_and_learn/sounds/"
const look_and_learn_videos: = "/look_and_learn/video/"
const language_sounds: = "/language_sounds/"
const kalulu_folder: = "/kalulu/"
const tracing_data_folder: = "tracing_data/"
const additional_word_list_path: = "word_list.csv"
const video_extension: = ".ogv"
const image_extension: = ".png"
const sound_extension: = ".mp3"

var language: String = "fr":
	set(value):
		language = value
		db_path = base_path + language + "/language.db"
		words_path = base_path + language + "/words/"
var db_path: = base_path + language + "/language.db":
	set(value):
		db_path = value
		if db:
			db.close_db()
			db.path = db_path
			db.foreign_keys = true
			db.open_db()
			
			#_init_db()
			
var words_path: = base_path + language + "/words/"
var additional_word_list: Dictionary

@onready var db: = SQLite.new()


func _exit_tree() -> void:
	db.close_db()


func _init_db() -> void:
	# load_additional_word_list()
	# db_path = db_path
	#_import_words_csv()
	#_import_look_and_learn_data()
	_import_syllables()


func get_additional_word_list_path() -> String:
	return base_path.path_join(additional_word_list_path)


func load_additional_word_list() -> String:
	additional_word_list.clear()
	var word_list_path: = get_additional_word_list_path()
	if FileAccess.file_exists(word_list_path):
		var file: = FileAccess.open(word_list_path, FileAccess.READ)
		var title_line: = file.get_csv_line()
		if (not "ORTHO" in title_line) or (not "PHON" in title_line) or (not "GPMATCH" in title_line):
			var msg: = "word list should have columns ORTHO, PHON and GPMATCH"
			push_error(msg)
			return msg
		var ortho_index: = title_line.find("ORTHO")
		while not file.eof_reached():
			var line: = file.get_csv_line()
			if line.size() != title_line.size():
				return "Formatting error on: %s" % line
			var data: = {}
			for i in line.size():
				data[title_line[i]] = line[i]
			additional_word_list[line[ortho_index]] = data
		file.close()
	return ""


func get_exercice_for_lesson(lesson_nb: int) -> Array[String]:
	var query: = "Select Exercise1, Exercise2, Exercise3 FROM LessonsExercises
	INNER JOIN Lessons ON Lessons.ID = LessonsExercises.LessonID
	WHERE LessonNB == " + str(lesson_nb)
	Database.db.query(query)
	
	var answer: Array[String]
	for res in Database.db.query_result:
		Database.db.query("Select Type FROM ExerciseTypes WHERE ID == " + str(res.Exercise1))
		answer.append(Database.db.query_result[0].Type)
		Database.db.query("Select Type FROM ExerciseTypes WHERE ID == " + str(res.Exercise2))
		answer.append(Database.db.query_result[0].Type)
		Database.db.query("Select Type FROM ExerciseTypes WHERE ID == " + str(res.Exercise3))
		answer.append(Database.db.query_result[0].Type)
	
	return answer


func get_GP_for_lesson(lesson_nb: int, distinct: bool, only_new: bool = false, only_vowels: bool = false, with_other_phonemes: bool = false) -> Array:
	
	var parameters := []
	var symbol: = "<=" if not only_new else "=="
	var query: = "SELECT g.ID, Grapheme, Phoneme, "
	
	if with_other_phonemes:
		query += "(SELECT group_concat(Phoneme) FROM GPs g2 
		INNER JOIN GPsInLessons ON GPsInLessons.GPID = g2.ID 
		INNER JOIN Lessons ON Lessons.ID = GPsInLessons.LessonID AND Lessons.LessonNb " + symbol + " ?
		WHERE g.Grapheme = g2.Grapheme AND g.Phoneme != g2.Phoneme)
	AS OtherPhonemes, "
		parameters.append(lesson_nb)
	
	query += "Type, LessonNb FROM GPs g
	INNER JOIN GPsInLessons ON GPsInLessons.GPID = g.ID 
	INNER JOIN Lessons ON Lessons.ID = GPsInLessons.LessonID AND Lessons.LessonNb " + symbol + " ?"
	parameters.append(lesson_nb)
	
	if only_vowels:
		query += " WHERE Type = 1"
	
	if distinct:
		query += " GROUP BY Grapheme"
	
	query += " ORDER BY LessonNb ASC"
	
	db.query_with_bindings(query, parameters)
	
	var result: = db.query_result
	
	if with_other_phonemes:
		for GP in result:
			if GP.OtherPhonemes:
				GP.OtherPhonemes = GP.OtherPhonemes.split(",")
	
	return result


func get_GPs_from_syllable(syllable_ID: int) -> Array:
	db.query_with_bindings("SELECT GPs.ID, GPs.Grapheme, GPs.Phoneme, GPs.Type FROM Syllables INNER JOIN GPsInSyllables ON Syllables.ID = GPsInSyllables.SyllableID AND Syllables.ID=? INNER JOIN GPs WHERE GPs.ID = GPsInSyllables.GPID ORDER BY Position", [syllable_ID])
	return db.query_result


func get_GP_from_word(ID: int) -> Array:
	db.query_with_bindings("SELECT GPs.* FROM Words INNER JOIN GPsInWords ON Words.ID = GPsInWords.WordID AND Words.ID=? INNER JOIN GPs WHERE GPS.ID = GPsInWords.GPID ORDER BY Position", [ID])
	return db.query_result


func get_words_containing_grapheme(grapheme: String) -> Array:
	db.query_with_bindings("SELECT Word FROM Words INNER JOIN GPsInWords INNER JOIN GPs on Words.ID = GPsInWords.WordID AND GPs.Grapheme=? AND GPS.ID = GPsInWords.GPID", [grapheme])
	return db.query_result


func get_syllables_for_lesson(lesson_nb: int, only_new: = false) -> Array[Dictionary]:
	var query: = "SELECT Syllables.ID, Syllables.Syllable as Grapheme, VerifiedCount.LessonNb FROM Syllables
	 INNER JOIN 
	(SELECT SyllableID, count() as Count FROM GPsInSyllables 
		INNER JOIN GPsInLessons ON GPsInLessons.GPID = GPsInSyllables.GPID 
		GROUP BY SyllableID 
		) TotalCount ON TotalCount.SyllableID = Syllables.ID 
	INNER JOIN 
	(SELECT SyllableID, count() as Count, max(LessonNb) AS LessonNb FROM GPsInSyllables 
		INNER JOIN GPsInLessons ON GPsInLessons.GPID = GPsInSyllables.GPID 
		INNER JOIN Lessons ON Lessons.ID = GPsInLessons.LessonID  AND Lessons.LessonNb <= ?
		GROUP BY SyllableID 
		) VerifiedCount ON VerifiedCount.SyllableID = Syllables.ID AND VerifiedCount.Count = TotalCount.Count"
	if only_new:
		query += " INNER JOIN GPsInSyllables ON GPsInSyllables.SyllableID = Syllables.ID 
			INNER JOIN GPsInLessons ON GPsInLessons.GPID = GPsInSyllables.GPID 
			INNER JOIN Lessons ON Lessons.ID = GPsInLessons.LessonID  AND Lessons.LessonNb = ?"
		db.query_with_bindings(query, [lesson_nb, lesson_nb])
	else:
		db.query_with_bindings(query, [lesson_nb])
	
	var res : = db.query_result
	for syllable: Dictionary in res:
		syllable.GPs = get_GPs_from_syllable(syllable.ID)
		var phonemes: Array[String] = []
		for GP: Dictionary in syllable.GPs:
			phonemes.append(GP.Phoneme)
		syllable.Phoneme = "-".join(phonemes)
	
	return res


func get_words_for_lesson(lesson_nb: int, only_new: = false, min_length: = 2, max_length: = 99) -> Array:
	var parameters: Array = []
	var query: = "SELECT Words.ID, Words.Word, VerifiedCount.Count as GPsCount, MaxLessonNb as LessonNb, VerifiedCount.gpsid as GPs_IDs
FROM Words
	 INNER JOIN 
	(SELECT WordID, count() as Count FROM GPsInWords 
		INNER JOIN GPsInLessons ON GPsInLessons.GPID = GPsInWords.GPID 
		GROUP BY WordID 
		) TotalCount ON TotalCount.WordID = Words.ID 
	INNER JOIN 
	(SELECT WordID, count() as Count, max(LessonNb) as MaxLessonNb, group_concat(GPsInWords.GPID) as gpsid FROM GPsInWords 
		INNER JOIN GPsInLessons ON GPsInLessons.GPID = GPsInWords.GPID 
		INNER JOIN Lessons ON Lessons.ID = GPsInLessons.LessonID  AND Lessons.LessonNb <= ?
		GROUP BY WordID 
		) VerifiedCount ON VerifiedCount.WordID = Words.ID AND VerifiedCount.Count = TotalCount.Count"
	parameters.append(lesson_nb)
	
	if only_new:
		query += " INNER JOIN GPsInWords ON GPsInWords.WordID = Words.ID 
			INNER JOIN GPsInLessons ON GPsInLessons.GPID = GPsInWords.GPID 
			INNER JOIN Lessons ON Lessons.ID = GPsInLessons.LessonID  AND Lessons.LessonNb = ?"
		parameters.append(lesson_nb)
	
	query += " WHERE TotalCount.Count <= ? and TotalCount.Count >= ?
	ORDER BY LessonNb, GPsCount ASC"
	parameters.append(max_length)
	parameters.append(min_length)
	
	db.query_with_bindings(query, parameters)
	var res: = db.query_result
	
	# Parse the GPs IDs
	for word: Dictionary in res:
		word.GPs = []
		for GPID in word.GPs_IDs.split(","):
			word.GPs.append({ID = int(GPID)})
		word.erase("GPs_IDs")
	
	return res


func get_sentences_by_lessons() -> Dictionary:
	var sentences_by_lesson: = {}
	var sentences: = get_sentences()
	for sentence in sentences:
		var lesson_nb: = get_min_lesson_for_sentence_id(sentence.ID)
		var a = sentences_by_lesson.get(lesson_nb, [])
		a.append(sentence)
		sentences_by_lesson[lesson_nb] = a
	return sentences_by_lesson


func get_sentences_for_lesson(p_lesson_nb: int, only_new: = false, sentences_by_lesson: = {}) -> Array:
	if sentences_by_lesson.is_empty():
		sentences_by_lesson = get_sentences_by_lessons()
	
	if only_new:
		return sentences_by_lesson.get(p_lesson_nb, [])
	
	var ret: Array = []
	for i in p_lesson_nb:
		ret.append_array(sentences_by_lesson.get(i, []))
	return ret





func get_pseudowords_for_lesson(p_lesson_nb: int) -> Array:
	var query: = "SELECT * FROM Pseudowords
	 INNER JOIN Words ON Words.ID = Pseudowords.WordID 
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
	db.query_with_bindings(query, [p_lesson_nb])
	return db.query_result


func get_distractors_for_grapheme(id: int, lesson_nb: int) -> Array:
	db.query_with_bindings("SELECT DISTINCT distractor.* From GPs stimuli 
	INNER JOIN GPs distractor 
	INNER JOIN Lessons 
	INNER JOIN GPsInLessons
	ON stimuli.ID=? AND distractor.type = stimuli.type 
	AND distractor.Grapheme != stimuli.Grapheme 
	AND distractor.Phoneme != stimuli.Phoneme
	AND CASE WHEN length(distractor.Grapheme) < length(stimuli.Grapheme) 
		THEN stimuli.Grapheme NOT LIKE  distractor.Grapheme || '%'
		ELSE true
	END
	AND GPsInLessons.GPID = distractor.ID
	AND Lessons.ID = GPsInLessons.LessonID AND Lessons.LessonNb <= ?", [id, lesson_nb])
	return db.query_result


func get_min_lesson_for_gp_id(gp_id: int) -> int:
	db.query_with_bindings("SELECT Lessons.LessonNb as i FROM Lessons
	INNER JOIN GPsInLessons ON Lessons.ID = GPsInLessons.LessonID AND GPsInLessons.GPID = ?", [gp_id])
	if db.query_result.is_empty():
		return -1
	return db.query_result[0].i


func get_min_lesson_for_word_id(word_id: int) -> int:
	db.query_with_bindings("SELECT * FROM Words 
	INNER JOIN GPsInWords ON GPsInWords.WordID=Words.ID
	WHERE Words.ID=? 
	ORDER BY Position", [word_id])
	var m: = -1
	for result in db.query_result:
		var i: = Database.get_min_lesson_for_gp_id(result.GPID)
		if i < 0:
			m = -1
			break
		m = max(m, i)
	return m


func get_min_lesson_for_sentence_id(sentence_id: int) -> int:
	db.query_with_bindings("SELECT MAX(Lessons.LessonNb) as i FROM Lessons
	INNER JOIN GPsInLessons ON Lessons.ID = GPsInLessons.LessonID
	INNER JOIN WordsInSentences ON WordsInSentences.SentenceID = ?
	INNER JOIN GPsInWords ON GPsInWords.GPID = GPsInLessons.GPID AND GPsInWords.WordID = WordsInSentences.WordID", [sentence_id])
	if not db.query_result[0].i:
		return -1
	return db.query_result[0].i


func get_sentences() -> Array[Dictionary]:
	db.query("SELECT * FROM Sentences")
	return db.query_result


func get_words_in_sentence(sentence_id: int) -> Array[Dictionary]:
	db.query_with_bindings("SELECT * FROM WordsInSentences
	INNER JOIN Words ON Words.ID = WordsInSentences.WordID
	WHERE SentenceID = ?
	ORDER BY WordsInSentences.Position", [sentence_id])
	return db.query_result


func get_lessons_count() -> int:
	db.query("SELECT MAX(Lessons.LessonNb) as i FROM Lessons")
	if db.query_result.is_empty() or not db.query_result[0].i:
		return 0
	return db.query_result[0].i


func get_audio_stream_for_path(path: String) -> AudioStream:
	var full_path : String = base_path.path_join(language).path_join(path)
	if not FileAccess.file_exists(full_path):
		return null
	return load(full_path)


func get_audio_stream_for_word(ID: int) -> AudioStream:
	var GPs: = get_GP_from_word(ID)
	var file_name: = _phoneme_to_string(GPs[0].Phoneme)
	for i in range(1, GPs.size()):
		var GP = GPs[i]
		file_name += "-" + _phoneme_to_string(GP.Phoneme)
	file_name += ".mp3"
	return load(words_path + file_name)


func get_audio_stream_for_phoneme(phoneme: String) -> AudioStream:
	var phoneme_array := phoneme.split("-")
	var path: = words_path + _phoneme_to_string(phoneme_array[0])
	for i in range(1, phoneme_array.size()):
		path += "-" + _phoneme_to_string(phoneme_array[i])
	path += ".mp3"
	
	if FileAccess.file_exists(path) and ResourceLoader.exists(path):
		return load(path)
	return null


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


func get_syllable_sound_path(syllable: Dictionary) -> String:
	return base_path + language + language_sounds + syllable.Syllable + sound_extension


func get_word_sound_path(word: Dictionary) -> String:
	return base_path + language + language_sounds + word.Word + sound_extension


func get_kalulu_speech_path(speech_category: String, speech_name: String) -> String:
	return base_path + language + language_sounds + kalulu_folder + speech_category + "_" + speech_name + sound_extension


func load_external_sound(path: String) -> AudioStreamMP3:
	if not FileAccess.file_exists(path):
		return null
	
	var file: = FileAccess.open(path, FileAccess.READ)
	var audio_stream: = AudioStreamMP3.new()
	audio_stream.data = file.get_buffer(file.get_length())
	file.close()
	
	return audio_stream


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


func _import_look_and_learn_data() -> void:
	var file = FileAccess.open("res://data3/gp_list.json", FileAccess.READ)
	var dict = JSON.parse_string(file.get_line())
	for e in dict.values():
		var file_path: = "res://data3/".path_join(look_and_learn_images).path_join(e.IMAGE) + image_extension
		DirAccess.copy_absolute(file_path, get_gp_look_and_learn_image_path({
			Grapheme = e.GRAPHEME,
			Phoneme = e.PHONEME,
		}))
		file_path = base_path.path_join(language).path_join(look_and_learn_sounds).path_join(e.AUDIO) + sound_extension
		DirAccess.copy_absolute(file_path, get_gp_look_and_learn_sound_path({
			Grapheme = e.GRAPHEME,
			Phoneme = e.PHONEME,
		}))
		file_path = (base_path.path_join(language).path_join(look_and_learn_videos).trim_suffix("/") + "s").path_join(e.FILENAME) + "_wide" + video_extension
		DirAccess.copy_absolute(file_path, get_gp_look_and_learn_video_path({
			Grapheme = e.GRAPHEME,
			Phoneme = e.PHONEME,
		}))


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


func _import_syllables() -> void:
	var file = FileAccess.open("res://data3/words_list.json", FileAccess.READ)
	var dict = JSON.parse_string(file.get_line())
	
	for e in dict.values():
		if e.NB_GRAPHEME == 2 and e.NB_LETTER <= 3:
			
			# Inserts syllable
			db.query_with_bindings("SELECT * FROM Syllables WHERE Syllable=?", [e.GRAPHEME])
			if db.query_result.is_empty():
				db.insert_row("Syllables", {Syllable=e.GRAPHEME})
			
			# Inserts GPs in syllable
			db.query_with_bindings("SELECT * FROM Syllables WHERE Syllable=?", [e.GRAPHEME])
			var syllable_id = db.query_result[0]["ID"]
			
			# Checks if GPsInSyllables is already inserted
			db.query_with_bindings("SELECT ID FROM GPsInSyllables WHERE SyllableID=?", [syllable_id])
			if db.query_result.is_empty():
				var GP_list_str: String = e.GPMATCH
				var GP_list: = GP_list_str.split(".")
				
				for i in GP_list.size():
					var GP_str = GP_list[i]
					var GP = GP_str.split("-")
					
					# Checks if GP exists
					db.query_with_bindings("SELECT * FROM GPs WHERE Grapheme=? AND Phoneme=?", [GP[0], GP[1]])
					if db.query_result.is_empty():
						push_error("GP not found for " + GP_str)
						continue
					
					var GP_id = db.query_result[0]["ID"]
					db.insert_row("GPsInSyllables", {
						SyllableID = syllable_id,
						GPID = GP_id,
						Position = i,
					})


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


func _import_words_csv() -> void:
	var file = FileAccess.open("res://data3/Copy of Manulex-infra-2.csv", FileAccess.READ)
	file.get_line()
	while not file.eof_reached():
		var line: = file.get_csv_line()
		_import_word_from_csv(line[0], line[2])


func _import_word_from_csv(ortho: String, gpmatch: String, is_word: = true) -> Array:
	var gp_list: = gpmatch.trim_prefix("(").trim_suffix(")").split(".")
	var gp_ids: Array[int] = []
	for gp in gp_list:
		var split: = gp.split("-")
		var grapheme: = split[0]
		var phoneme: = split[1]
		db.query_with_bindings("SELECT * FROM GPs WHERE Grapheme = ? AND Phoneme = ?", [grapheme, phoneme])
		var gp_id: = -1
		if db.query_result.is_empty():
			db.insert_row("GPs", {
				Grapheme = grapheme,
				Phoneme = phoneme,
			})
			gp_id = db.last_insert_rowid
		else:
			gp_id = db.query_result[0].ID
		gp_ids.append(gp_id)
	if is_word:
		db.query_with_bindings("SELECT * FROM Words WHERE Word = ?", [ortho])
	else:
		db.query_with_bindings("SELECT * FROM Syllables WHERE Syllable = ?", [ortho])
	var word_id: = -1
	if db.query_result.is_empty():
		if is_word:
			db.insert_row("Words", {
				Word = ortho,
			})
			word_id = db.last_insert_rowid
			for i in gp_ids.size():
				var gp_id: int = gp_ids[i]
				db.insert_row("GPsInWords", {
					WordID = word_id,
					GPID = gp_id,
					Position = i
				})
		else:
			db.insert_row("Syllables", {
				Syllable = ortho,
			})
			word_id = db.last_insert_rowid
			for i in gp_ids.size():
				var gp_id: int = gp_ids[i]
				db.insert_row("GPsInSyllables", {
					SyllableID = word_id,
					GPID = gp_id,
					Position = i
				})
	else:
		word_id = db.query_result[0].ID
	return [word_id, gp_ids]
