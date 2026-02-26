extends GutTest


func _resumable_body(coroutine: Coroutine) -> Array:
	await coroutine.resume_signal
	return ["ready"]


func _frame_value(value: Variant) -> Variant:
	await get_tree().process_frame
	return value


func _instant_value(value: Variant) -> Variant:
	return value


func test_resumable_call_sets_completion_and_return_value() -> void:
	var coroutine: Coroutine = Coroutine.new()
	coroutine.resumable_call.call_deferred(Callable(self, "_resumable_body"))
	await get_tree().process_frame
	assert_false(coroutine.is_completed, "Coroutine should not be completed before resume.")
	coroutine.resume()
	await get_tree().process_frame
	assert_true(coroutine.is_completed, "Coroutine should be completed after resume.")
	assert_eq(coroutine.return_value, ["ready"], "Coroutine should return the expected value.")


func test_join_all_waits_for_all_futures() -> void:
	var coroutine: Coroutine = Coroutine.new()
	coroutine.add_future.call_deferred(Callable(self, "_frame_value").bind("a"))
	coroutine.add_future.call_deferred(Callable(self, "_frame_value").bind("b"))
	var result: Array = await coroutine.join_all()
	assert_eq(result, ["a", "b"], "join_all should return all values in order.")


func test_join_either_returns_after_first_completion() -> void:
	var coroutine: Coroutine = Coroutine.new()
	coroutine.add_future.call_deferred(Callable(self, "_instant_value").bind("fast"))
	coroutine.add_future.call_deferred(Callable(self, "_frame_value").bind("slow"))
	await get_tree().process_frame
	var partial: Array = await coroutine.join_either()
	assert_eq(partial.size(), 2, "join_either should return a slot for each future.")
	assert_eq(str(partial[0]), "fast", "join_either should return the completed value in the correct slot.")
	assert_eq(typeof(partial[1]), TYPE_NIL, "join_either should return null for unfinished futures.") # We don't use assert_null because of warning for supertype Variant
	var full: Array = await coroutine.join_all()
	assert_eq(full, ["fast", "slow"], "join_all should return all values once finished.")


func test_join_either_returns_immediately_without_futures() -> void:
	var coroutine: Coroutine = Coroutine.new()
	var result: Array = await coroutine.join_either()
	assert_eq(result, [], "join_either should return immediately when no future has been registered.")
