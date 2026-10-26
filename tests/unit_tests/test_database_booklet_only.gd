extends GutTest

# The game leaves out of its pools every word, syllable and sentence a language
# pack marks BookletOnly (schema version 2): the printed booklets use word forms
# the game has no recording for. A pack downloaded before version 2 has no such
# column, and the same queries must still work on it and offer everything.

const TEST_DIR: String = "user://test_database_booklet_only"
const TEST_DB: String = TEST_DIR + "/language.db"
const MODEL_DB: String = "res://model_database.db"

var _saved_path: String
var _saved_is_open: bool


func before_each() -> void:
	_saved_path = Database.db.path
	_saved_is_open = Database.is_open
	Database.close()
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	_seed_language_database()


func after_each() -> void:
	Database.close()
	_delete_test_directory()
	Database.db.path = _saved_path
	if _saved_is_open:
		Database.connect_to_db()


# One lesson teaching l and a; in it the game's words "la" and "lala", the
# booklet-only word "alla", a syllable of each kind, a sentence of each kind and
# a pseudoword tied to each word.
func _seed_language_database() -> void:
	DirAccess.remove_absolute(TEST_DB)
	assert_eq(DirAccess.copy_absolute(MODEL_DB, TEST_DB), OK, "the model database must be copyable")
	var seed_db: SQLite = SQLite.new()
	seed_db.path = TEST_DB
	seed_db.open_db()
	for statement: String in [
		"INSERT INTO Lessons (ID, LessonNb) VALUES (1, 1)",
		"INSERT INTO LessonsExercises (LessonID, Exercise1, Exercise2, Exercise3) VALUES (1, 1, 0, 0)",
		"INSERT INTO GPs (ID, Grapheme, Phoneme, Type) VALUES (1, 'l', 'l', 2), (2, 'a', 'a', 1)",
		"INSERT INTO GPsInLessons (GPID, LessonID) VALUES (1, 1), (2, 1)",
		"INSERT INTO Words (ID, Word, BookletOnly) VALUES (1, 'la', 0), (2, 'lala', 0), (3, 'alla', 1)",
		"INSERT INTO GPsInWords (WordID, GPID, Position) VALUES (1, 1, 0), (1, 2, 1), (2, 1, 0), (2, 2, 1), (2, 1, 2), (2, 2, 3), (3, 2, 0), (3, 1, 1), (3, 1, 2), (3, 2, 3)",
		"INSERT INTO Syllables (ID, Syllable, BookletOnly) VALUES (1, 'la', 0), (2, 'al', 1)",
		"INSERT INTO GPsInSyllables (SyllableID, GPID, Position) VALUES (1, 1, 0), (1, 2, 1), (2, 2, 0), (2, 1, 1)",
		"INSERT INTO Sentences (ID, Sentence, BookletOnly) VALUES (1, 'La lala.', 0), (2, 'Alla la.', 1)",
		"INSERT INTO WordsInSentences (SentenceID, WordID, Position) VALUES (1, 1, 0), (1, 2, 1), (2, 3, 0), (2, 1, 1)",
		"INSERT INTO Pseudowords (Pseudoword, WordID) VALUES ('lalo', 2), ('allo', 3)",
	]:
		assert_true(seed_db.query(statement), "seeding: %s" % statement)
	seed_db.close_db()


# Turns the fixture into a pack from before version 2.
func _drop_booklet_only_columns() -> void:
	var seed_db: SQLite = SQLite.new()
	seed_db.path = TEST_DB
	seed_db.open_db()
	for table: String in ["Words", "Syllables", "Sentences"]:
		assert_true(seed_db.query('ALTER TABLE "%s" DROP COLUMN "BookletOnly"' % table), "dropping %s.BookletOnly" % table)
	seed_db.query("PRAGMA user_version = 1")
	seed_db.close_db()


func _open() -> void:
	Database.db.path = TEST_DB
	Database.connect_to_db()
	assert_true(Database.is_open, "the fixture must open")


func _texts(rows: Array, key: String) -> Array[String]:
	var texts: Array[String] = []
	for row: Dictionary in rows:
		texts.append(row[key] as String)
	texts.sort()
	return texts


# get_syllables_for_lesson(only_new) returns a syllable once per GP of it the
# lesson teaches, which this test is not about.
func _distinct_texts(rows: Array, key: String) -> Array[String]:
	var texts: Array[String] = []
	for text: String in _texts(rows, key):
		if not texts.has(text):
			texts.append(text)
	return texts


func test_a_version_2_pack_is_seen_to_mark_booklet_only_entries() -> void:
	_open()
	assert_true(Database.has_booklet_only)


func test_booklet_only_words_are_left_out() -> void:
	_open()
	assert_eq(_texts(Database.get_words_for_lesson(1), "Word"), ["la", "lala"] as Array[String])
	assert_eq(_texts(Database.get_words_for_lesson(1, true), "Word"), ["la", "lala"] as Array[String])


func test_booklet_only_syllables_are_left_out() -> void:
	_open()
	assert_eq(_texts(Database.get_syllables_for_lesson(1), "Grapheme"), ["la"] as Array[String])
	assert_eq(_distinct_texts(Database.get_syllables_for_lesson(1, true), "Grapheme"), ["la"] as Array[String])


func test_booklet_only_sentences_are_left_out() -> void:
	_open()
	assert_eq(_texts(Database.get_sentences_for_lesson(1, 1, 5), "Sentence"), ["La lala."] as Array[String])
	assert_eq(_texts(Database.get_sentences(2), "Sentence"), ["La lala."] as Array[String])


func test_pseudowords_of_booklet_only_words_are_left_out() -> void:
	_open()
	assert_eq(_texts(Database.get_pseudowords_for_lesson(1), "Pseudoword"), ["lalo"] as Array[String])


func test_a_pack_from_before_version_2_offers_everything() -> void:
	_drop_booklet_only_columns()
	_open()
	assert_false(Database.has_booklet_only)
	assert_eq(_texts(Database.get_words_for_lesson(1), "Word"), ["alla", "la", "lala"] as Array[String])
	assert_eq(_texts(Database.get_syllables_for_lesson(1), "Grapheme"), ["al", "la"] as Array[String])
	assert_eq(_texts(Database.get_sentences_for_lesson(1, 1, 5), "Sentence"), ["Alla la.", "La lala."] as Array[String])
	assert_eq(_texts(Database.get_sentences(2), "Sentence"), ["Alla la.", "La lala."] as Array[String])
	assert_eq(_texts(Database.get_pseudowords_for_lesson(1), "Pseudoword"), ["allo", "lalo"] as Array[String])


func _delete_test_directory() -> void:
	var dir: DirAccess = DirAccess.open(TEST_DIR)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)
	DirAccess.remove_absolute(TEST_DIR)
