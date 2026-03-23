extends GutTest


# -----------------------------
# Logs
# -----------------------------
func test_reset_logs_initializes_answers_bucket() -> void:
	var minigame: Minigame = Minigame.new()
	minigame.logs = {"anything": true}
	minigame._reset_logs()
	assert_eq_deep(minigame.logs, {"answers": []})


func test_log_new_response_adds_entry_with_right_answer_metadata() -> void:
	var minigame: Minigame = Minigame.new()
	minigame.minigame_name = Minigame.Type.jellyfish
	minigame.current_number_of_hints = 1
	minigame.current_progression = 2
	minigame.max_progression = 10
	minigame.current_lives = 3
	minigame.max_number_of_lives = 5
	minigame._reset_logs()
	var expected: Dictionary = {"id": 7}
	minigame._log_new_response(expected, expected)
	var answers: Array = minigame.logs["answers"]
	assert_eq(answers.size(), 1)
	assert_eq(answers[0]["is_right"] as bool, true)
	assert_eq(answers[0]["minigame"] as String, "jellyfish")
	assert_eq_deep(answers[0]["reponse"] as Dictionary, expected)
	assert_eq_deep(answers[0]["awaited_response"] as Dictionary, expected)


# -----------------------------
# Confusion Matrix
# -----------------------------
func test_update_confusion_matrix_gp_score_appends_values_per_expected_id() -> void:
	var minigame: Minigame = Minigame.new()

	minigame._update_confusion_matrix_gp_score(10, 100)
	minigame._update_confusion_matrix_gp_score(10, 101)
	minigame._update_confusion_matrix_gp_score(11, 200)
	assert_eq(minigame.confusion_matrix_gp_scores[10], PackedInt32Array([100, 101]))
	assert_eq(minigame.confusion_matrix_gp_scores[11], PackedInt32Array([200]))


# -----------------------------
# Remediation
# -----------------------------
func test_update_remediation_scores_accumulate_for_same_key() -> void:
	var minigame: Minigame = Minigame.new()
	minigame._update_remediation_gp_score(1, 2)
	minigame._update_remediation_gp_score(1, 3)
	minigame._update_remediation_syllable_score(2, -1)
	minigame._update_remediation_syllable_score(2, 5)
	minigame._update_remediation_word_score(3, 4)
	minigame._update_remediation_word_score(3, 1)
	assert_eq(minigame.remediation_gp_scores[1] as int, 5)
	assert_eq(minigame.remediation_syllables_scores[2] as int, 4)
	assert_eq(minigame.remediation_words_scores[3] as int, 5)
