class_name WordImporter
extends RefCounted
## Brings words and syllables into a language pack from a linguist's file.
##
## The additional word list is a lexicon (ORTHO, PHON, GPMATCH columns) the
## Prof Tool completes new words from. It is loaded once by the main menu and
## read by every editor screen, so it is held in a static variable: a global
## class script stays loaded across scene changes.
##
## This used to live in the Database autoload, which made every game build ship
## the Prof Tool's import code. Database keeps what describes a pack; this keeps
## what edits one.

const WORD_LIST_FILE_NAME: String = "word_list.csv"

## ORTHO -> the whole CSV row, keyed by column name.
static var word_list: Dictionary = {}


static func word_list_path() -> String:
	return Database.BASE_PATH.path_join(WORD_LIST_FILE_NAME)


## Reads the word list into `word_list`. Returns an error message for the user,
## or an empty string when the file loaded or there is no file.
static func load_word_list() -> String:
	word_list.clear()
	var path: String = word_list_path()
	if FileAccess.file_exists(path):
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		var error: Error = FileAccess.get_open_error()
		if error != OK:
			Log.error("WordImporter: Load additional word list: Cannot open file %s. Error: %s" % [path, error_string(error)])
			return ""
		if file == null:
			Log.error("WordImporter: Load additional word list: Cannot open file %s. File is null" % path)
			return ""
		var title_line: PackedStringArray = file.get_csv_line()
		if (not "ORTHO" in title_line) or (not "PHON" in title_line) or (not "GPMATCH" in title_line):
			var msg: String = "word list should have columns ORTHO, PHON and GPMATCH"
			Log.error("WordImporter: " + msg)
			return msg
		var ortho_index: int = title_line.find("ORTHO")
		while not file.eof_reached():
			var line: PackedStringArray = file.get_csv_line()
			if line.size() != title_line.size():
				return "Formatting error on: %s" % line
			var data: Dictionary = {}
			for index: int in range(line.size()):
				data[title_line[index]] = line[index]
			word_list[line[ortho_index]] = data
		file.close()
		Log.info("WordImporter: Loaded additional word list from %s (%d entries)" % [path, word_list.size()])
	else:
		Log.warn("WordImporter: Additional word list file not found: %s" % path)
	return ""


## Inserts a word or syllable from its GPMATCH spelling (`a-a.b-b`), creating
## any GP it names that the pack does not have yet. Nothing is inserted when the
## word or syllable already exists.
##
## Returns an array containing an int followed by an array of int: the word or
## syllable ID, then the IDs of its GPs in order.
static func import_from_gpmatch(ortho: String, gpmatch: String, is_word: bool = true) -> Array[Variant]:
	var db: SQLite = Database.db
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
			for index: int in range(gp_ids.size()):
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
			for index: int in range(gp_ids.size()):
				var gp_id: int = gp_ids[index]
				db.insert_row("GPsInSyllables", {
					SyllableID = word_id,
					GPID = gp_id,
					Position = index
				})
	else:
		word_id = db.query_result[0].ID
	return [word_id, gp_ids]
