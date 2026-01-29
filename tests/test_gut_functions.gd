extends GutTest


func test_equal() -> void:
	assert_eq(1, 1)


func test_not_equal() -> void:
	assert_ne('hello', 'goodbye')


func test_true() -> void:
	assert_true(true)


func test_false() -> void:
	assert_false(false)
