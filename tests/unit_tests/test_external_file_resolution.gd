extends GutTest

# The language databases store words in composed form (NFC: "e-acute" is one
# code point) while the pack's audio files are frequently named in decomposed
# form (NFD: "e" + U+0301). macOS resolves the two interchangeably, so the
# mismatch is invisible there; Android, iOS, Windows and Linux match filenames
# byte for byte and find nothing. Database.resolve_external_file_path walks the
# normalization forms so callers do not have to.
#
# words_minigame used to call FileAccess.file_exists directly, which silently
# dropped every accented word from the stimuli pool off macOS.

const TEST_DIR: String = "user://test_external_file_resolution"
# These two differ only in normalization form, which no editor shows you and
# which a well-meaning tool can silently collapse. If they ever come out equal
# every assertion below would still pass while testing nothing, so before_each
# asserts they are distinct rather than trusting the bytes to survive.
const NFC_NAME: String = "numéro.mp3"      # numero, e-acute as U+00E9
const NFD_NAME: String = "numéro.mp3"     # numero, e + U+0301
## A pack of its own, so the getters below are exercised on the paths they build
## themselves rather than on one the test assembles.
const FIXTURE_LANGUAGE: String = "test_nfd_pack"
## The schema Database expects, so redirecting the language opens a real database
## instead of warning that there is none.
const MODEL_DATABASE: String = "res://model_database.db"
## The letters, written as code points rather than as characters: a cedilla typed
## into this file is one normalization form or the other depending on what last
## saved it, and which one is the whole point here.
const NFC_CEDILLA: String = "\u00e7"
const NFD_CEDILLA: String = "c\u0327"
const NFC_A_GRAVE: String = "\u00e0"
const NFD_A_GRAVE: String = "a\u0300"

## True while the pack is redirected, so a failed assertion cannot leave the whole
## suite pointed at the fixture.
var _pack_redirected: bool = false
var _saved_language: String = ""
var _saved_db_path: String = ""
var _saved_is_open: bool = false


func before_each() -> void:
	assert_ne(NFC_NAME, NFD_NAME,
		"the fixtures must be in different normalization forms or these tests prove nothing")
	DirAccess.make_dir_recursive_absolute(TEST_DIR)


func after_each() -> void:
	if _pack_redirected:
		_restore_the_pack()
	var dir: DirAccess = DirAccess.open(TEST_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				dir.remove(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	DirAccess.remove_absolute(TEST_DIR)


func test_the_fallback_produces_exactly_the_form_the_packs_use() -> void:
	# The filesystem tests below cannot fail on macOS, where lookups are
	# normalization-insensitive and the first rung of the ladder always hits.
	# This one is pure string work, so it holds the fallback honest everywhere:
	# if the normalizer's mapping for e-acute regressed, the NFD rung would be
	# looking for a name no pack contains.
	assert_eq(UnicodeNormalizer.to_nfd_basic(NFC_NAME), NFD_NAME,
		"to_nfd_basic should turn the database's composed name into the pack's decomposed one")


func test_a_decomposed_file_is_found_from_its_composed_name() -> void:
	# The database asks for the composed name; only the decomposed file exists.
	_write_file(NFD_NAME)

	assert_true(Database.external_file_exists(TEST_DIR.path_join(NFC_NAME)),
		"an NFD-named file should be found when asked for by its NFC name")


func test_resolving_returns_a_path_that_can_be_opened() -> void:
	_write_file(NFD_NAME)

	var resolved: String = Database.resolve_external_file_path(TEST_DIR.path_join(NFC_NAME))

	assert_true(FileAccess.file_exists(resolved),
		"the resolved path should be openable as-is, got %s" % resolved)


func test_an_exact_match_is_returned_untouched() -> void:
	# The common case: no accent, or a pack already in composed form. It must
	# not be rewritten on the way through.
	_write_file(NFC_NAME)

	assert_eq(Database.resolve_external_file_path(TEST_DIR.path_join(NFC_NAME)),
		TEST_DIR.path_join(NFC_NAME),
		"a path that already exists should come back unchanged")


func test_a_missing_file_resolves_to_nothing() -> void:
	# 615 of the fr_FR database entries have no recording at all, so absence is
	# the normal case, not an error: it must report it rather than invent a path.
	assert_eq(Database.resolve_external_file_path(TEST_DIR.path_join("absent.mp3")), "",
		"a file that exists in no normalization form should resolve to an empty String")
	assert_false(Database.external_file_exists(TEST_DIR.path_join("absent.mp3")))


# --- The getters that build their own pack path have to walk the ladder too ------
## The ladder was written for the word sounds and the greeting, and everything that
## names a file after something a person typed needs it just as much: a cedilla
## reaches the filesystem as one code point and the packs ship the file as two.
## Both fixtures below are what the fr_FR pack actually contains.
func test_a_decomposed_look_and_learn_image_is_found_from_its_composed_grapheme() -> void:
	_redirect_the_pack()
	var image: Image = Image.create(2, 2, false, Image.FORMAT_RGB8)
	image.fill(Color.WHITE)
	var pack_path: String = Database.get_language_folder() + Database.LOOK_AND_LEARN_IMAGES
	DirAccess.make_dir_recursive_absolute(pack_path)
	assert_eq(image.save_png(pack_path + NFD_CEDILLA + "-s" + Database.IMAGE_EXTENSION), OK,
		"could not write the fixture image")

	# What the database hands over is the composed grapheme.
	var found: Texture = Database.get_gp_look_and_learn_image(
			{"Grapheme": NFC_CEDILLA, "Phoneme": "s"})

	assert_not_null(found,
		"a decomposed picture should be found from the composed grapheme -- without "
		+ "this that lesson opens with no illustration on every platform but macOS")


func test_a_decomposed_tracing_file_is_found_from_its_composed_letter() -> void:
	_redirect_the_pack()
	var pack_path: String = Database.BASE_PATH.path_join(Database.language).path_join(
			Database.TRACING_DATA_FOLDER)
	DirAccess.make_dir_recursive_absolute(pack_path)
	var file: FileAccess = FileAccess.open(pack_path + NFD_A_GRAVE + "_lower.csv",
			FileAccess.WRITE)
	assert_not_null(file, "could not write the fixture tracing")
	if file:
		file.store_string("140.5 108.0,42.5 -411.0\n")
		file.close()
	var manager: TracingManager = autofree(TracingManager.new()) as TracingManager

	var tracings: Dictionary = manager._get_letter_tracings(NFC_A_GRAVE)

	assert_false((tracings["lower"] as Array).is_empty(),
		"a decomposed tracing should be found from the composed letter -- without "
		+ "this there is nothing for the child to trace on any accented letter")


## Points Database at a pack of this test's own, database and all.
##
## The getters build their paths from Database.language, so redirecting it is the
## only way to exercise the path they really use. The model database is copied in
## because the language setter reconnects, and a missing file warns.
func _redirect_the_pack() -> void:
	_saved_language = Database.language
	_saved_db_path = Database.db.path
	_saved_is_open = Database.is_open
	_pack_redirected = true
	Database.close()
	var pack_root: String = Database.BASE_PATH.path_join(FIXTURE_LANGUAGE)
	DirAccess.make_dir_recursive_absolute(pack_root)
	var model: PackedByteArray = FileAccess.get_file_as_bytes(MODEL_DATABASE)
	assert_gt(model.size(), 0, "the model database should be readable")
	var seed_file: FileAccess = FileAccess.open(pack_root.path_join("language.db"),
			FileAccess.WRITE)
	assert_not_null(seed_file, "could not seed the fixture database")
	if seed_file:
		seed_file.store_buffer(model)
		seed_file.close()
	Database.language = FIXTURE_LANGUAGE


## Puts the real pack back, whether the test passed or not.
func _restore_the_pack() -> void:
	_pack_redirected = false
	Database.close()
	_force_delete(Database.BASE_PATH.path_join(FIXTURE_LANGUAGE))
	Database.language = _saved_language
	Database.db.path = _saved_db_path
	if _saved_is_open:
		Database.connect_to_db()


## Removes a folder and everything under it, which DirAccess will not do on its own.
func _force_delete(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			_force_delete(path.path_join(entry))
		else:
			dir.remove(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write_file(file_name: String) -> void:
	var file: FileAccess = FileAccess.open(TEST_DIR.path_join(file_name), FileAccess.WRITE)
	assert_not_null(file, "could not create the fixture %s" % file_name)
	if file:
		file.store_string("not really an mp3")
		file.close()
