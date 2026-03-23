extends GutTest


func test_append_and_trim_adds_and_trims() -> void:
	var matrix: UserConfusionMatrix = UserConfusionMatrix.new()
	var target: Dictionary[int, PackedInt32Array] = {}
	matrix.append_and_trim(target, 1, PackedInt32Array([1, 2, 3, 4, 5, 6, 7]))
	assert_eq_deep(target[1], PackedInt32Array([3, 4, 5, 6, 7]))


func test_append_and_trim_removes_empty_entries() -> void:
	var matrix: UserConfusionMatrix = UserConfusionMatrix.new()
	var target: Dictionary[int, PackedInt32Array] = {1: PackedInt32Array()}
	matrix.append_and_trim(target, 1, PackedInt32Array())
	assert_false(target.has(1))


func test_get_gp_scores_returns_copy() -> void:
	var matrix: UserConfusionMatrix = UserConfusionMatrix.new()
	matrix.gp_scores = {1: PackedInt32Array([10, 20])}
	var scores: PackedInt32Array = matrix.get_gp_scores(1)
	scores.append(30)
	assert_eq_deep(matrix.gp_scores[1], PackedInt32Array([10, 20]))


func test_get_gp_scores_missing_returns_empty_array() -> void:
	var matrix: UserConfusionMatrix = UserConfusionMatrix.new()
	assert_eq_deep(matrix.get_gp_scores(99), PackedInt32Array())


func test_update_gp_scores_ignores_empty_input() -> void:
	var matrix: UserConfusionMatrix = UserConfusionMatrix.new()
	matrix.gp_scores = {1: PackedInt32Array([2])}
	matrix.gp_last_modified = "before"
	matrix.update_gp_scores({})
	assert_eq_deep(matrix.gp_scores, {1: PackedInt32Array([2])})
	assert_eq(matrix.gp_last_modified, "before")


func test_update_gp_scores_appends_trims_and_emits_signal() -> void:
	var matrix: UserConfusionMatrix = UserConfusionMatrix.new()
	matrix.gp_scores = {1: PackedInt32Array([1, 2, 3, 4])}
	watch_signals(matrix)
	matrix.update_gp_scores({1: PackedInt32Array([5, 6])})
	assert_eq_deep(matrix.gp_scores[1], PackedInt32Array([2, 3, 4, 5, 6]))
	assert_signal_emitted(matrix, "score_changed")
	assert_ne(matrix.gp_last_modified, "")


func test_set_gp_scores_trims_and_sets_last_modified() -> void:
	var matrix: UserConfusionMatrix = UserConfusionMatrix.new()
	matrix.set_gp_scores({1: PackedInt32Array([1, 2, 3, 4, 5, 6]), 2: PackedInt32Array()})
	assert_eq_deep(matrix.gp_scores, {1: PackedInt32Array([2, 3, 4, 5, 6])})
	assert_ne(matrix.gp_last_modified, "")


func test_set_gp_last_modified_updates_value() -> void:
	var matrix: UserConfusionMatrix = UserConfusionMatrix.new()
	matrix.set_gp_last_modified("2014-01-14")
	assert_eq(matrix.gp_last_modified, "2014-01-14")
