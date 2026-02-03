extends GutTest


func test_add_log_creates_bucket_and_stores_entry() -> void:
	var resource: LogResource = LogResource.new()
	var payload: Dictionary = {"score": 10}
	resource.add_log(1, payload, "2024-01-01T00:00:00")
	assert_true(resource.logs.has(1))
	assert_true(resource.logs[1].has("2024-01-01T00:00:00"))
	assert_eq_deep(resource.logs[1]["2024-01-01T00:00:00"] as Dictionary, payload)


func test_add_log_duplicate_time_creates_incremented_key() -> void:
	var resource: LogResource = LogResource.new()
	resource.add_log(2, {"value": 1}, "2024-02-02T12:00:00")
	resource.add_log(2, {"value": 2}, "2024-02-02T12:00:00")
	resource.add_log(2, {"value": 3}, "2024-02-02T12:00:00")

	var lesson_logs: Dictionary = resource.logs[2]
	assert_true(lesson_logs.has("2024-02-02T12:00:00"))
	assert_true(lesson_logs.has("2024-02-02T12:00:00_2"))
	assert_true(lesson_logs.has("2024-02-02T12:00:00_3"))
	assert_eq_deep(lesson_logs["2024-02-02T12:00:00"] as Dictionary, {"value": 1})
	assert_eq_deep(lesson_logs["2024-02-02T12:00:00_2"] as Dictionary, {"value": 2})
	assert_eq_deep(lesson_logs["2024-02-02T12:00:00_3"] as Dictionary, {"value": 3})
	assert_engine_error(2, "2 warnings are expected here, 1 for each log duplicate")
