extends GutTest

# A language pack asset is named after the database text it belongs to, and that
# name has to survive a case insensitive filesystem. Every pack declares
# grapheme-phoneme pairs that differ only by case -- "e-E" against "e-e" in
# French, "r-R" against "r-r" in Spanish -- and those are different sounds.
# macOS and Windows fold case, so naming the two files after the pairs
# themselves let one overwrite the other whenever a pack was built, zipped or
# unzipped there: the wrong phoneme played on a Mac and nothing at all on a
# tablet. Database._text_to_file_name spells an uppercase letter out instead.

# Every phoneme the five shipped packs use, as of 2026-09-16. The encoding has
# to keep these apart with case folded -- that is the whole point of it.
const PACK_PHONEMES: Array[String] = [
	"#", "%", "1", "2", "5", "8", "9", "@", "C", "E", "J", "K", "L", "N", "O",
	"R", "S", "Y", "Z", "a", "aj", "aw", "b", "d", "dZ", "e", "ej", "ew", "f",
	"g", "gw", "h", "i", "ij", "iw", "j", "j5", "k", "ks", "kw", "l", "m", "n",
	"o", "oj", "ow", "p", "r", "s", "t", "tC", "u", "v", "w", "w5", "wa", "waj",
	"x", "y", "z", "§", "ã", "ãj", "ãw", "õ", "ē", "ī", "ū",
]
# The pairs a case insensitive filesystem actually collapsed, per pack.
const COLLIDING_PAIRS: Array = [
	["e", "E", "e", "e"],
	["ai", "E", "ai", "e"],
	["au", "o", "au", "O"],
	["et", "E", "et", "e"],
	["o", "O", "o", "o"],
	["r", "R", "r", "r"],
	["é", "E", "é", "e"],
	["ó", "O", "ó", "o"],
]
# The throwaway language the resolver tests write their files into, and the real
# language they put back afterwards.
const TEST_LOCALE: String = "zz_TEST"

var _saved_language: String


func _gp(grapheme: String, phoneme: String) -> Dictionary:
	return {"Grapheme": grapheme, "Phoneme": phoneme}


func test_lowercase_text_is_left_alone() -> void:
	assert_eq(Database.get_gp_file_name(_gp("ou", "u")), "ou-u")
	assert_eq(Database.get_gp_file_name(_gp("ill", "j")), "ill-j")


func test_an_uppercase_phoneme_is_spelled_out() -> void:
	assert_eq(Database.get_gp_file_name(_gp("e", "E")), "e-cap.e")
	assert_eq(Database.get_gp_file_name(_gp("d", "dZ")), "d-cap.dz")


func test_a_symbol_phoneme_becomes_a_word() -> void:
	# "e-%" is the French schwa, the sound of the "e" in "le".
	assert_eq(Database.get_gp_file_name(_gp("e", "%")), "e-pcent")
	assert_eq(Database.get_gp_file_name(_gp("e", "#")), "e-sharp")
	assert_eq(Database.get_gp_file_name(_gp("on", "§")), "on-para")


func test_a_colliding_pair_gets_two_distinct_names() -> void:
	for pair: Array in COLLIDING_PAIRS:
		var left: String = Database.get_gp_file_name(_gp(pair[0] as String, pair[1] as String))
		var right: String = Database.get_gp_file_name(_gp(pair[2] as String, pair[3] as String))
		assert_ne(left.to_lower(), right.to_lower(),
				"%s-%s and %s-%s must not share a file name once case is folded"
				% [pair[0], pair[1], pair[2], pair[3]])


func test_every_pack_phoneme_keeps_a_unique_name_with_case_folded() -> void:
	var seen: Dictionary[String, String] = {}
	for phoneme: String in PACK_PHONEMES:
		var name: String = Database.get_gp_file_name(_gp("x", phoneme)).to_lower()
		assert_false(seen.has(name),
				"phonemes %s and %s both encode to %s" % [seen.get(name, ""), phoneme, name])
		seen[name] = phoneme


func test_a_sound_path_uses_the_encoded_name() -> void:
	assert_true(Database.get_gp_sound_path(_gp("e", "E")).ends_with("/e-cap.e.mp3"),
			"got " + Database.get_gp_sound_path(_gp("e", "E")))
	assert_true(Database.get_gp_look_and_learn_image_path(_gp("e", "%")).ends_with("/e-pcent.png"),
			"got " + Database.get_gp_look_and_learn_image_path(_gp("e", "%")))
	assert_true(Database.get_gp_look_and_learn_video_path(_gp("r", "R")).ends_with("/r-cap.r.ogv"),
			"got " + Database.get_gp_look_and_learn_video_path(_gp("r", "R")))


func test_word_and_syllable_paths_use_the_encoded_name() -> void:
	# "Colombia" and "colombia" are two entries of the Spanish packs.
	assert_true(Database.get_word_sound_path({"Word": "Colombia"}).ends_with("/cap.colombia.mp3"),
			"got " + Database.get_word_sound_path({"Word": "Colombia"}))
	assert_true(Database.get_word_sound_path({"Word": "colombia"}).ends_with("/colombia.mp3"),
			"got " + Database.get_word_sound_path({"Word": "colombia"}))
	assert_true(Database.get_syllable_sound_path({"Grapheme": "ma"}).ends_with("/ma.mp3"),
			"got " + Database.get_syllable_sound_path({"Grapheme": "ma"}))


func test_the_display_name_stays_readable() -> void:
	# get_gp_name feeds labels and menu buttons, so it must not be encoded.
	assert_eq(Database.get_gp_name(_gp("e", "E")), "e-E")
	assert_eq(Database.get_gp_name(_gp("e", "%")), "e-%")


# --- the fallback that lets an updated app read a pack downloaded before it ---
func before_each() -> void:
	_saved_language = Database.language
	Database.language = TEST_LOCALE
	DirAccess.make_dir_recursive_absolute(
			Database.get_language_folder() + Database.LANGUAGE_SOUNDS)


func after_each() -> void:
	var folder: String = Database.BASE_PATH + TEST_LOCALE
	_delete_recursively(folder)
	Database.language = _saved_language


func _delete_recursively(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			_delete_recursively(path.path_join(entry))
		else:
			DirAccess.remove_absolute(path.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


func _write_sound(file_name: String) -> void:
	var file: FileAccess = FileAccess.open(
			Database.get_language_sound_folder() + file_name, FileAccess.WRITE)
	assert_not_null(file, "could not create the fixture " + file_name)
	file.store_string("not really an mp3")
	file.close()


func test_the_encoded_name_is_found() -> void:
	_write_sound("e-cap.e.mp3")
	var path: String = Database.resolve_gp_asset_path(
			_gp("e", "E"), Database.LANGUAGE_SOUNDS, Database.SOUND_EXTENSION)
	assert_true(path.ends_with("/e-cap.e.mp3"), "got '" + path + "'")


func test_an_older_pack_still_resolves_through_the_legacy_name() -> void:
	# A pack downloaded before the encoding names the file after the pair itself.
	_write_sound("e-E.mp3")
	var path: String = Database.resolve_gp_asset_path(
			_gp("e", "E"), Database.LANGUAGE_SOUNDS, Database.SOUND_EXTENSION)
	assert_true(path.ends_with("/e-E.mp3"), "got '" + path + "'")


func test_the_encoded_name_wins_when_a_pack_holds_both() -> void:
	_write_sound("e-E.mp3")
	_write_sound("e-cap.e.mp3")
	var path: String = Database.resolve_gp_asset_path(
			_gp("e", "E"), Database.LANGUAGE_SOUNDS, Database.SOUND_EXTENSION)
	assert_true(path.ends_with("/e-cap.e.mp3"), "got '" + path + "'")


func test_nothing_on_disk_resolves_to_nothing() -> void:
	var path: String = Database.resolve_gp_asset_path(
			_gp("e", "E"), Database.LANGUAGE_SOUNDS, Database.SOUND_EXTENSION)
	assert_eq(path, "", "a GP with no file must resolve to an empty path")
