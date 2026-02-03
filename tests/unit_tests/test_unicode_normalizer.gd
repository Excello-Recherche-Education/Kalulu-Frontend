extends GutTest


func test_to_nfd_basic_replaces_known_characters() -> void:
	var input: String = "éÇİx"
	var expected: String = "e\u0301C\u0327I\u0307x"
	assert_eq(UnicodeNormalizer.to_nfd_basic(input), expected)


func test_to_nfd_basic_preserves_unmapped_characters() -> void:
	var input: String = "simple"
	assert_eq(UnicodeNormalizer.to_nfd_basic(input), input)


func test_to_nfd_extended_expands_non_canonical_pairs() -> void:
	var input: String = "æøß"
	var expected: String = "aeo\u0338ss"
	assert_eq(UnicodeNormalizer.to_nfd_extended(input), expected)


func test_to_nfd_extended_applies_basic_and_extended_maps() -> void:
	var input: String = "éÆ"
	var expected: String = "e\u0301AE"
	assert_eq(UnicodeNormalizer.to_nfd_extended(input), expected)


func test_to_nfd_extended_keeps_combining_sequences() -> void:
	var input: String = "e\u0301"
	assert_eq(UnicodeNormalizer.to_nfd_extended(input), input)
