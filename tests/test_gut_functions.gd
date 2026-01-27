extends GutTest


func test_equal() -> void:
	# this test will pass because 1 does equal 1
	assert_eq(1, 1)


func test_not_equal() -> void:
	# this test will fail because those strings are not equal
	assert_ne('hello', 'goodbye')


func test_true() -> void:
	# this test will fail because those strings are not equal
	assert_true(true)


func test_false() -> void:
	# this test will fail because those strings are not equal
	assert_false(false)
