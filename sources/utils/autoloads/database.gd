@tool
extends Node

const _SYMBOLS_TO_STRING: Dictionary[String, String] = {
	"#" : "sharp",
	"@" : "at",
	"*" : "star",
	"$" : "usd",
	"%" : "pcent",
	"§" : "para"
}
const BASE_PATH: String =  "user://language_resources/"
const LOOK_AND_LEARN_IMAGES: String = "/look_and_learn/images/"
const LOOK_AND_LEARN_SOUNDS: String = "/look_and_learn/sounds/"
const LOOK_AND_LEARN_VIDEOS: String = "/look_and_learn/video/"
const LANGUAGE_SOUNDS: String = "/language_sounds/"
const KALULU_FOLDER: String = "/kalulu/"
const ADDITIONAL_WORD_LIST_PATH: String = "word_list.csv"
const VIDEO_EXTENSION: String = ".ogv"
const IMAGE_EXTENSION: String = ".png"
const SOUND_EXTENSION: String = ".mp3"

var language: String:
	set(value):
		language = value
		db_path = BASE_PATH + language + "/language.db"
		words_path = BASE_PATH + language + "/words/"

var db_path: String = BASE_PATH + language + "/language.db":
	set(value):
		db_path = value
		if db:
			db.path = db_path
			db.foreign_keys = true
			connect_to_db()

var words_path: String = BASE_PATH + language + "/words/"
var additional_word_list: Dictionary = {}

@onready var db: SQLite = SQLite.new()
var is_open: bool = false


func _exit_tree() -> void:
	db.close_db()


func connect_to_db() -> void:
	if is_open:
		db.close_db()
	if FileAccess.file_exists(db.path):
		is_open = db.open_db()


func get_additional_word_list_path() -> String:
	return BASE_PATH.path_join(ADDITIONAL_WORD_LIST_PATH)


func load_additional_word_list() -> String:
	additional_word_list.clear()
	var word_list_path: String = get_additional_word_list_path()
	if FileAccess.file_exists(word_list_path):
		var file: FileAccess = FileAccess.open(word_list_path, FileAccess.READ)
		var title_line: PackedStringArray = file.get_csv_line()
		if (not "ORTHO" in title_line) or (not "PHON" in title_line) or (not "GPMATCH" in title_line):
			var msg: String = "word list should have columns ORTHO, PHON and GPMATCH"
			Logger.error("Database: " + msg)
			return msg
		var ortho_index: int = title_line.find("ORTHO")
		while not file.eof_reached():
			var line: PackedStringArray = file.get_csv_line()
			if line.size() != title_line.size():
				return "Formatting error on: %s" % line
			var data: Dictionary = {}
			for index: int in line.size():
				data[title_line[index]] = line[index]
			additional_word_list[line[ortho_index]] = data
		file.close()
	return ""


func get_exercice_for_lesson(lesson_nb: int) -> Array[int]:
	var query: String = "Select Exercise1, Exercise2, Exercise3 FROM LessonsExercises
	INNER JOIN Lessons ON Lessons.ID = LessonsExercises.LessonID
	WHERE LessonNB == " + str(lesson_nb)
	db.query(query)
	
	#var answer: Array[String] = []
	#for res in Database.db.query_result:
	#	Database.db.query("Select Type FROM ExerciseTypes WHERE ID == " + str(res.Exercise1))
	#	answer.append(Database.db.query_result[0].Type)
	#	Database.db.query("Select Type FROM ExerciseTypes WHERE ID == " + str(res.Exercise2))
	#	answer.append(Database.db.query_result[0].Type)
	#	Database.db.query("Select Type FROM ExerciseTypes WHERE ID == " + str(res.Exercise3))
	#	answer.append(Database.db.query_result[0].Type)
	#return answer
	
	var result: Array[int] = []
	for element: Dictionary in db.query_result:
		result.append(element.Exercise1)
		result.append(element.Exercise2)
		result.append(element.Exercise3)
	
	return result


func get_gps_for_lesson(lesson_nb: int, distinct: bool, only_new: bool = false, only_vowels: bool = false, with_other_phonemes: bool = false, include_exceptions: bool = false) -> Array:
	
	var parameters: Array = []
	var symbol: String = "<=" if not only_new else "=="
	var query: String = "SELECT g.ID, g.Grapheme, g.Phoneme, "
	
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
	
	var conditions: Array = []
	if not include_exceptions:
		conditions.append("Exception = 0")
	if only_vowels:
		conditions.append("Type = 1")
	
	if conditions.size() > 0:
		query += " WHERE " + " AND ".join(conditions)
	
	if distinct:
		query += " GROUP BY Grapheme"
	
	query += " ORDER BY LessonNb ASC"
	
	db.query_with_bindings(query, parameters)
	
	var result: Array[Dictionary] = db.query_result
	
	if with_other_phonemes:
		for gp: Dictionary in result:
			if gp.OtherPhonemes:
				var phonemes: String = gp.OtherPhonemes
				gp.OtherPhonemes = phonemes.split(",")
	
	return result


func get_gps_from_syllable(syllable_ID: int) -> Array[Dictionary]:
	db.query_with_bindings("SELECT GPs.ID, GPs.Grapheme, GPs.Phoneme, GPs.Type FROM Syllables INNER JOIN GPsInSyllables ON Syllables.ID = GPsInSyllables.SyllableID AND Syllables.ID=? INNER JOIN GPs WHERE GPs.ID = GPsInSyllables.GPID ORDER BY Position", [syllable_ID])
	return db.query_result


func get_gp_from_word(ID: int) -> Array:
	db.query_with_bindings("SELECT GPs.* FROM Words INNER JOIN GPsInWords ON Words.ID = GPsInWords.WordID AND Words.ID=? INNER JOIN GPs WHERE GPs.ID = GPsInWords.GPID ORDER BY Position", [ID])
	return db.query_result


func get_gps_from_sentence(sentenceID: int) -> Array[Dictionary]:
	db.query_with_bindings("SELECT GPs.ID, GPs.Grapheme, GPs.Phoneme, GPs.Type, GPsInWords.WordID, GPsInWords.Position AS GPPosition, WordsInSentences.Position AS WordPosition FROM GPs
INNER JOIN GPsInWords ON GPsInWords.GPID = GPs.ID
INNER JOIN WordsInSentences ON WordsInSentences.WordID = GPsInWords.WordID
INNER JOIN Sentences ON Sentences.ID = WordsInSentences.SentenceID
WHERE Sentences.ID = ?
ORDER BY WordPosition ASC, GPPosition ASC", [sentenceID])
	return db.query_result


func get_words_containing_grapheme(grapheme: String) -> Array[Dictionary]:
	db.query_with_bindings("SELECT Word FROM Words INNER JOIN GPsInWords INNER JOIN GPs on Words.ID = GPsInWords.WordID AND GPs.Grapheme=? AND GPs.ID = GPsInWords.GPID", [grapheme])
	return db.query_result


func get_syllables_for_lesson(lesson_nb: int, only_new: bool = false) -> Array[Dictionary]:
	var query: String = "SELECT Syllables.ID, Syllables.Syllable as Grapheme, VerifiedCount.LessonNb FROM Syllables
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
	
	var res: Array[Dictionary] = db.query_result
	for syllable: Dictionary in res:
		syllable.GPs = get_gps_from_syllable(syllable.ID as int)
		var phonemes: Array[String] = []
		for gp: Dictionary in syllable.GPs:
			phonemes.append(gp.Phoneme)
		syllable.Phoneme = "-".join(phonemes)
	
	return res


func get_words_for_lesson(lesson_nb: int, only_new: bool = false, min_length: int = 2, max_length: int = 99, include_exception: bool = false) -> Array[Dictionary]:
	var parameters: Array = []
	var query: String = "SELECT DISTINCT Words.ID, Words.Word, Words.Exception, VerifiedCount.Count as GPsCount, MaxLessonNb as LessonNb, VerifiedCount.gpsid as GPs_IDs
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
	
	query += " WHERE TotalCount.Count <= ? and TotalCount.Count >= ?"

	if not include_exception:
		query += " and Words.Exception = false"

	query += " ORDER BY LessonNb, GPsCount ASC"
	parameters.append(max_length)
	parameters.append(min_length)
	
	db.query_with_bindings(query, parameters)
	var res: Array[Dictionary] = db.query_result
	
	# Parse the GPs IDs
	for word: Dictionary in res:
		var word_gps: Array = []
		var word_gps_id: String = word.GPs_IDs
		for gp_id: String in word_gps_id.split(","):
			word_gps.append({ID = int(gp_id)})
		word.GPs = word_gps
		word.erase("GPs_IDs")
	
	return res


func get_words_with_silent_gp_for_lesson(lesson_nb: int, only_new: bool = false, min_length: int = 2, max_length: int = 6) -> Array[Dictionary]:
	var parameters: Array = []
	var query: String = "SELECT Words.ID, Words.Word, MaxLessonNb as LessonNb
FROM Words
	 INNER JOIN 
	(SELECT WordID, count() as Count FROM GPsInWords 
		INNER JOIN GPsInLessons ON GPsInLessons.GPID = GPsInWords.GPID 
		GROUP BY WordID 
		) TotalCount ON TotalCount.WordID = Words.ID 
	INNER JOIN 
	(SELECT WordID, count() as Count, max(LessonNb) as MaxLessonNb, group_concat(GPs.Phoneme) as gpphoneme FROM GPsInWords 
		INNER JOIN GPsInLessons ON GPsInLessons.GPID = GPsInWords.GPID 
		INNER JOIN Lessons ON Lessons.ID = GPsInLessons.LessonID  AND Lessons.LessonNb <= ?
		INNER JOIN GPs ON GPs.ID = GPsInWords.GPID
		GROUP BY WordID 
		) VerifiedCount ON VerifiedCount.WordID = Words.ID AND VerifiedCount.Count = TotalCount.Count"
	parameters.append(lesson_nb)
	
	if only_new:
		query += " INNER JOIN GPsInWords ON GPsInWords.WordID = Words.ID 
			INNER JOIN GPsInLessons ON GPsInLessons.GPID = GPsInWords.GPID 
			INNER JOIN Lessons ON Lessons.ID = GPsInLessons.LessonID  AND Lessons.LessonNb = ?"
		parameters.append(lesson_nb)
	
	query += " WHERE TotalCount.Count <= ? and TotalCount.Count >= ?
	AND VerifiedCount.gpphoneme LIKE '%#%' 
	ORDER BY LessonNb, VerifiedCount.Count ASC"
	parameters.append(max_length)
	parameters.append(min_length)
	
	db.query_with_bindings(query, parameters)
	return db.query_result


func get_sentences_by_lessons() -> Dictionary:
	var sentences_by_lesson: Dictionary = {}
	
	db.query("SELECT * FROM Sentences")
	var sentences: Array[Dictionary] = db.query_result
	
	for sentence: Dictionary in sentences:
		var lesson_nb: int = get_min_lesson_for_sentence_id(sentence.ID as int)
		var a: Array = sentences_by_lesson.get(lesson_nb, [])
		a.append(sentence)
		sentences_by_lesson[lesson_nb] = a
	return sentences_by_lesson


func get_sentences(p_lesson_nb: int, only_new: bool = false, sentences_by_lesson: Dictionary = {}) -> Array:
	if sentences_by_lesson.is_empty():
		sentences_by_lesson = get_sentences_by_lessons()
	
	if only_new:
		return sentences_by_lesson.get(p_lesson_nb, [])
	
	var ret: Array = []
	for index: int in p_lesson_nb:
		ret.append_array(sentences_by_lesson.get(index, []) as Array)
	return ret


func get_sentences_for_lesson(lesson_nb: int, min_length: int = 2, max_length:int = 5) -> Array[Dictionary]:
	var query: String = "SELECT Sentences.*, VerifiedCount.MaxLessonNb AS LessonNb FROM Sentences
INNER JOIN 
	(SELECT SentenceID, count() as WordsCount FROM WordsInSentences 
	GROUP BY SentenceID 
	) WordCount ON WordCount.SentenceID = Sentences.ID
INNER JOIN 
	(SELECT SentenceID, count() as Count FROM GPsInWords 
		INNER JOIN WordsInSentences ON GPsInWords.WordID = WordsInSentences.WordID
		INNER JOIN Sentences ON WordsInSentences.SentenceID = Sentences.ID
		INNER JOIN GPsInLessons ON GPsInLessons.GPID = GPsInWords.GPID 
	GROUP BY SentenceID 
	) TotalCount ON TotalCount.SentenceID = Sentences.ID 
INNER JOIN 
	(SELECT SentenceID, count() as Count, max(LessonNb) as MaxLessonNb FROM GPsInWords 
		INNER JOIN GPsInLessons ON GPsInLessons.GPID = GPsInWords.GPID 
		INNER JOIN WordsInSentences ON GPsInWords.WordID = WordsInSentences.WordID
		INNER JOIN Sentences ON WordsInSentences.SentenceID = Sentences.ID
		INNER JOIN Lessons ON Lessons.ID = GPsInLessons.LessonID  AND Lessons.LessonNb <= ?
		INNER JOIN GPs ON GPs.ID = GPsInWords.GPID
	GROUP BY SentenceID 
	) VerifiedCount ON VerifiedCount.SentenceID = Sentences.ID AND VerifiedCount.Count = TotalCount.Count
WHERE Sentences.Exception = 0
	AND WordsCount >=? 
	AND WordsCount <=?
	ORDER BY LessonNb"

	db.query_with_bindings(query, [lesson_nb, min_length, max_length])
	return db.query_result


func get_sentences_for_lesson_with_silent_gps(lesson_nb: int, min_length: int = 2, max_length:int = 5) -> Array[Dictionary]:
	var query: String = "SELECT Sentences.*, VerifiedCount.MaxLessonNb AS LessonNb FROM Sentences
INNER JOIN 
	(SELECT SentenceID, count() as WordsCount FROM WordsInSentences 
	GROUP BY SentenceID 
	) WordCount ON WordCount.SentenceID = Sentences.ID
INNER JOIN 
	(SELECT SentenceID, count() as Count FROM GPsInWords 
		INNER JOIN WordsInSentences ON GPsInWords.WordID = WordsInSentences.WordID
		INNER JOIN Sentences ON WordsInSentences.SentenceID = Sentences.ID
		INNER JOIN GPsInLessons ON GPsInLessons.GPID = GPsInWords.GPID 
	GROUP BY SentenceID 
	) TotalCount ON TotalCount.SentenceID = Sentences.ID 
INNER JOIN 
	(SELECT SentenceID, count() as Count, max(LessonNb) as MaxLessonNb, group_concat(GPs.Phoneme) as SentencePhoneme FROM GPsInWords 
		INNER JOIN GPsInLessons ON GPsInLessons.GPID = GPsInWords.GPID 
		INNER JOIN WordsInSentences ON GPsInWords.WordID = WordsInSentences.WordID
		INNER JOIN Sentences ON WordsInSentences.SentenceID = Sentences.ID
		INNER JOIN Lessons ON Lessons.ID = GPsInLessons.LessonID  AND Lessons.LessonNb <= ?
		INNER JOIN GPs ON GPs.ID = GPsInWords.GPID
	GROUP BY SentenceID 
	) VerifiedCount ON VerifiedCount.SentenceID = Sentences.ID AND VerifiedCount.Count = TotalCount.Count
WHERE Sentences.Exception = 0
	AND WordsCount >=? 
	AND WordsCount <=? 
	AND VerifiedCount.SentencePhoneme LIKE '%#%'"

	db.query_with_bindings(query, [lesson_nb, min_length, max_length])
	return db.query_result


func get_pseudowords_for_lesson(p_lesson_nb: int) -> Array[Dictionary]:
	var query: String = "SELECT * FROM Pseudowords
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


func get_distractors_for_grapheme(id: int, lesson_nb: int) -> Array[Dictionary]:
	db.query_with_bindings("SELECT DISTINCT distractor.Grapheme, distractor.ID, distractor.Phoneme From GPs stimuli 
	INNER JOIN GPs distractor 
	INNER JOIN Lessons 
	INNER JOIN GPsInLessons
	ON stimuli.ID=? AND distractor.type = stimuli.type 
	AND distractor.exception = false
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
	var minimum: int = -1
	for result: Dictionary in db.query_result:
		var index: int = Database.get_min_lesson_for_gp_id(result.GPID as int)
		if index < 0:
			minimum = -1
			break
		minimum = maxi(minimum, index)
	return minimum


func get_min_lesson_for_sentence_id(sentence_id: int) -> int:
	db.query_with_bindings("SELECT MAX(Lessons.LessonNb) as i FROM Lessons
	INNER JOIN GPsInLessons ON Lessons.ID = GPsInLessons.LessonID
	INNER JOIN WordsInSentences ON WordsInSentences.SentenceID = ?
	INNER JOIN GPsInWords ON GPsInWords.GPID = GPsInLessons.GPID AND GPsInWords.WordID = WordsInSentences.WordID", [sentence_id])
	if not db.query_result[0].i:
		return -1
	return db.query_result[0].i


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
	var full_path: String = BASE_PATH.path_join(language).path_join(path)
	if not FileAccess.file_exists(full_path):
		return null
	return load(full_path)


func get_audio_stream_for_word(ID: int) -> AudioStream:
	var gps: Array = get_gp_from_word(ID)
	var file_name: String = _phoneme_to_string(gps[0].Phoneme as String)
	for index: int in range(1, gps.size()):
		var gp: Dictionary = gps[index]
		file_name += "-" + _phoneme_to_string(gp.Phoneme as String)
	file_name += ".mp3"
	return load(words_path + file_name)


func get_audio_stream_for_phoneme(phoneme: String) -> AudioStream:
	var phoneme_array: PackedStringArray = phoneme.split("-")
	var path: String = words_path + _phoneme_to_string(phoneme_array[0])
	for index: int in range(1, phoneme_array.size()):
		path += "-" + _phoneme_to_string(phoneme_array[index])
	path += ".mp3"
	
	if FileAccess.file_exists(path) and ResourceLoader.exists(path):
		return load(path)
	return null


func get_gp_look_and_learn_image(gp: Dictionary) -> Texture:
	var path: String = get_gp_look_and_learn_image_path(gp)
	if FileAccess.file_exists(path):
		if ResourceLoader.exists(path):
			return load(path)
		else:
			var image: Image = Image.load_from_file(path)
			var texture: ImageTexture = ImageTexture.create_from_image(image)
			return texture
	
	return null


func get_gp_look_and_learn_sound(gp: Dictionary) -> AudioStream:
	var path: String = get_gp_look_and_learn_sound_path(gp)
	if FileAccess.file_exists(path):
		if ResourceLoader.exists(path):
			return load(path)
		else:
			var file: FileAccess = FileAccess.open(path, FileAccess.READ)
			var sound: AudioStreamMP3 = AudioStreamMP3.new()
			sound.data = file.get_buffer(file.get_length())
			return sound
	
	return null


func get_gp_look_and_learn_video(gp: Dictionary) -> VideoStream:
	var path: String = get_gp_look_and_learn_video_path(gp)
	if FileAccess.file_exists(path):
		var video: VideoStream = load(path)
		return video
	
	return null


func get_gp_name(gp: Dictionary) -> String:
	var result: String = ""
	if gp.has("Grapheme"):
		result += gp["Grapheme"]
	if gp.has("Phoneme"):
		if result != "":
			result += "-"
		result += gp["Phoneme"]
	return result


func get_gp_look_and_learn_image_path(gp: Dictionary) -> String:
	return BASE_PATH + language + LOOK_AND_LEARN_IMAGES + get_gp_name(gp) + IMAGE_EXTENSION


func get_gp_look_and_learn_sound_path(gp: Dictionary) -> String:
	return BASE_PATH + language + LOOK_AND_LEARN_SOUNDS + get_gp_name(gp) + SOUND_EXTENSION


func get_gp_look_and_learn_video_path(gp: Dictionary) -> String:
	return BASE_PATH + language + LOOK_AND_LEARN_VIDEOS + get_gp_name(gp) + VIDEO_EXTENSION


func get_gp_sound_path(gp: Dictionary) -> String:
	return BASE_PATH + language + LANGUAGE_SOUNDS + Database.get_gp_name(gp) + SOUND_EXTENSION


func get_syllable_sound_path(syllable: Dictionary) -> String:
	return BASE_PATH + language + LANGUAGE_SOUNDS + syllable.Grapheme + SOUND_EXTENSION


func get_word_sound_path(word: Dictionary) -> String:
	return BASE_PATH + language + LANGUAGE_SOUNDS + word.Word + SOUND_EXTENSION


func get_kalulu_speech_path(speech_category: String, speech_name: String) -> String:
	return BASE_PATH + language + LANGUAGE_SOUNDS + KALULU_FOLDER + speech_category + "_" + speech_name + SOUND_EXTENSION


func load_external_sound(path: String) -> AudioStreamMP3:
	if not FileAccess.file_exists(path):
		return null
	
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var audio_stream: AudioStreamMP3 = AudioStreamMP3.new()
	audio_stream.data = file.get_buffer(file.get_length())
	file.close()
	
	return audio_stream


func _phoneme_to_string(phoneme: String) -> String:
	if _SYMBOLS_TO_STRING.has(phoneme):
		return _SYMBOLS_TO_STRING[phoneme]
	elif phoneme == phoneme.to_lower():
		return phoneme
	else:
		return "cap." + phoneme.to_lower()

# Returns an array containing an int followed by an array of int
func _import_word_from_csv(ortho: String, gpmatch: String, is_word: bool = true) -> Array[Variant]:
	var gp_list: PackedStringArray = gpmatch.trim_prefix("(").trim_suffix(")").split(".")
	var gp_ids: Array[int] = []
	for gp: String in gp_list:
		var split: PackedStringArray = gp.split("-")
		var grapheme: String = split[0]
		var phoneme: String = split[1]
		db.query_with_bindings("SELECT * FROM GPs WHERE Grapheme = ? AND Phoneme = ?", [grapheme, phoneme])
		var gp_id: int = -1
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
	var word_id: int = -1
	if db.query_result.is_empty():
		if is_word:
			db.insert_row("Words", {
				Word = ortho,
			})
			word_id = db.last_insert_rowid
			for index: int in gp_ids.size():
				var gp_id: int = gp_ids[index]
				db.insert_row("GPsInWords", {
					WordID = word_id,
					GPID = gp_id,
					Position = index
				})
		else:
			db.insert_row("Syllables", {
				Syllable = ortho,
			})
			word_id = db.last_insert_rowid
			for index: int in gp_ids.size():
				var gp_id: int = gp_ids[index]
				db.insert_row("GPsInSyllables", {
					SyllableID = word_id,
					GPID = gp_id,
					Position = index
				})
	else:
		word_id = db.query_result[0].ID
	return [word_id, gp_ids]
