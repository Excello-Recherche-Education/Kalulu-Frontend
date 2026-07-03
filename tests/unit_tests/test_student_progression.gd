extends GutTest


const LOCKED: StudentProgression.Status = StudentProgression.Status.LOCKED
const UNLOCKED: StudentProgression.Status = StudentProgression.Status.UNLOCKED
const COMPLETED: StudentProgression.Status = StudentProgression.Status.COMPLETED


# Builds an unlocks dictionary with everything LOCKED. `minigame_counts` gives the
# number of minigames per lesson (index 0 → lesson 1), so we can cover the new
# 1–3 minigames-per-lesson case without touching the database.
func _make_unlocks(minigame_counts: Array[int]) -> Dictionary:
	var unlocks: Dictionary = {}
	for lesson_index: int in range(minigame_counts.size()):
		var games: Array = []
		for _game_index: int in range(minigame_counts[lesson_index]):
			games.append(LOCKED)
		unlocks[lesson_index + 1] = {
			"look_and_learn": LOCKED,
			"games": games,
		}
	return unlocks


# -----------------------------
# Look-and-learn frontier
# -----------------------------
func test_complete_look_and_learn_unlocks_only_first_minigame() -> void:
	var unlocks: Dictionary = _make_unlocks([3, 3])
	StudentProgression.apply_manual_progression(unlocks, 1, StudentProgression.LOOK_AND_LEARN_SLOT, COMPLETED)
	assert_eq(unlocks[1]["look_and_learn"] as int, COMPLETED as int)
	assert_eq_deep(unlocks[1]["games"], [UNLOCKED, LOCKED, LOCKED])
	assert_eq(unlocks[2]["look_and_learn"] as int, LOCKED as int)
	assert_eq_deep(unlocks[2]["games"], [LOCKED, LOCKED, LOCKED])


func test_unlock_look_and_learn_locks_every_minigame() -> void:
	var unlocks: Dictionary = _make_unlocks([2])
	StudentProgression.apply_manual_progression(unlocks, 1, StudentProgression.LOOK_AND_LEARN_SLOT, UNLOCKED)
	assert_eq(unlocks[1]["look_and_learn"] as int, UNLOCKED as int)
	assert_eq_deep(unlocks[1]["games"], [LOCKED, LOCKED])


func test_lesson_one_look_and_learn_cannot_be_locked() -> void:
	var unlocks: Dictionary = _make_unlocks([2])
	StudentProgression.apply_manual_progression(unlocks, 1, StudentProgression.LOOK_AND_LEARN_SLOT, LOCKED)
	assert_eq(unlocks[1]["look_and_learn"] as int, UNLOCKED as int)
	assert_eq_deep(unlocks[1]["games"], [LOCKED, LOCKED])


# -----------------------------
# Minigame frontier (sequential)
# -----------------------------
func test_unlock_minigame_completes_all_earlier_steps() -> void:
	var unlocks: Dictionary = _make_unlocks([3])
	StudentProgression.apply_manual_progression(unlocks, 1, 2, UNLOCKED)
	assert_eq(unlocks[1]["look_and_learn"] as int, COMPLETED as int)
	assert_eq_deep(unlocks[1]["games"], [COMPLETED, COMPLETED, UNLOCKED])


func test_complete_minigame_unlocks_next_minigame() -> void:
	var unlocks: Dictionary = _make_unlocks([3])
	StudentProgression.apply_manual_progression(unlocks, 1, 0, COMPLETED)
	assert_eq(unlocks[1]["look_and_learn"] as int, COMPLETED as int)
	assert_eq_deep(unlocks[1]["games"], [COMPLETED, UNLOCKED, LOCKED])


func test_complete_last_minigame_unlocks_next_lesson() -> void:
	var unlocks: Dictionary = _make_unlocks([2, 2])
	StudentProgression.apply_manual_progression(unlocks, 1, 1, COMPLETED)
	assert_eq(unlocks[1]["look_and_learn"] as int, COMPLETED as int)
	assert_eq_deep(unlocks[1]["games"], [COMPLETED, COMPLETED])
	assert_eq(unlocks[2]["look_and_learn"] as int, UNLOCKED as int)
	assert_eq_deep(unlocks[2]["games"], [LOCKED, LOCKED])


func test_lock_minigame_moves_frontier_back_and_locks_following() -> void:
	var unlocks: Dictionary = _make_unlocks([3])
	StudentProgression.apply_manual_progression(unlocks, 1, 1, LOCKED)
	assert_eq(unlocks[1]["look_and_learn"] as int, COMPLETED as int)
	assert_eq_deep(unlocks[1]["games"], [UNLOCKED, LOCKED, LOCKED])


# -----------------------------
# Variable minigame counts (1, 2 or 3 per lesson)
# -----------------------------
func test_single_minigame_lesson_completion_unlocks_next_lesson() -> void:
	var unlocks: Dictionary = _make_unlocks([1, 2])
	StudentProgression.apply_manual_progression(unlocks, 1, 0, COMPLETED)
	assert_eq(unlocks[1]["look_and_learn"] as int, COMPLETED as int)
	assert_eq_deep(unlocks[1]["games"], [COMPLETED])
	assert_eq(unlocks[2]["look_and_learn"] as int, UNLOCKED as int)
	assert_eq_deep(unlocks[2]["games"], [LOCKED, LOCKED])


func test_editing_later_lesson_completes_all_previous_lessons() -> void:
	var unlocks: Dictionary = _make_unlocks([1, 3, 2])
	StudentProgression.apply_manual_progression(unlocks, 3, StudentProgression.LOOK_AND_LEARN_SLOT, UNLOCKED)
	# Lessons 1 and 2 fully completed, lesson 3 look-and-learn in progress.
	assert_eq(unlocks[1]["look_and_learn"] as int, COMPLETED as int)
	assert_eq_deep(unlocks[1]["games"], [COMPLETED])
	assert_eq(unlocks[2]["look_and_learn"] as int, COMPLETED as int)
	assert_eq_deep(unlocks[2]["games"], [COMPLETED, COMPLETED, COMPLETED])
	assert_eq(unlocks[3]["look_and_learn"] as int, UNLOCKED as int)
	assert_eq_deep(unlocks[3]["games"], [LOCKED, LOCKED])


func test_unknown_slot_leaves_progression_untouched() -> void:
	var unlocks: Dictionary = _make_unlocks([2])
	StudentProgression.apply_manual_progression(unlocks, 1, 5, COMPLETED)
	assert_eq(unlocks[1]["look_and_learn"] as int, LOCKED as int)
	assert_eq_deep(unlocks[1]["games"], [LOCKED, LOCKED])
