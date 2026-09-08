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


func before_each() -> void:
	assert_ne(NFC_NAME, NFD_NAME,
		"the fixtures must be in different normalization forms or these tests prove nothing")
	DirAccess.make_dir_recursive_absolute(TEST_DIR)


func after_each() -> void:
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


func _write_file(file_name: String) -> void:
	var file: FileAccess = FileAccess.open(TEST_DIR.path_join(file_name), FileAccess.WRITE)
	assert_not_null(file, "could not create the fixture %s" % file_name)
	if file:
		file.store_string("not really an mp3")
		file.close()
