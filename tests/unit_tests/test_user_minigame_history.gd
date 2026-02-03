extends GutTest


func test_defaults() -> void:
	var history: UserMinigameHistory = UserMinigameHistory.new()
	assert_eq(history.difficulty, UserMinigameHistory.MIN_DIFFICULTY)
	assert_eq(history.consecutives_losses, 0)
	assert_eq(history.consecutives_wins, 0)
	assert_eq(history.history.size(), 0)


func test_add_game_win_updates_history_and_counters() -> void:
	var history: UserMinigameHistory = UserMinigameHistory.new()
	history.consecutives_losses = 1
	history.add_game(true)
	assert_eq(history.history, [true])
	assert_eq(history.consecutives_losses, 0)
	assert_eq(history.consecutives_wins, 1)
	assert_eq(history.difficulty, UserMinigameHistory.MIN_DIFFICULTY)


func test_add_game_loss_updates_history_and_counters() -> void:
	var history: UserMinigameHistory = UserMinigameHistory.new()
	history.consecutives_wins = 1
	history.add_game(false)
	assert_eq(history.history, [false])
	assert_eq(history.consecutives_wins, 0)
	assert_eq(history.consecutives_losses, 1)
	assert_eq(history.difficulty, UserMinigameHistory.MIN_DIFFICULTY)


func test_wins_promote_and_reset_wins() -> void:
	var history: UserMinigameHistory = UserMinigameHistory.new()
	for _win: int in history.CONSECUTIVE_WINS_TO_PROMOTE:
		history.add_game(true)
	assert_eq(history.difficulty, UserMinigameHistory.MIN_DIFFICULTY + 1)
	assert_eq(history.consecutives_wins, 0)
	assert_eq(history.consecutives_losses, 0)
	assert_eq(history.history, [true, true])


func test_two_losses_demote_and_reset_losses() -> void:
	var history: UserMinigameHistory = UserMinigameHistory.new()
	history.difficulty = UserMinigameHistory.MIN_DIFFICULTY + 2
	for _loss: int in history.CONSECUTIVE_LOSSES_TO_DEMOTE:
		history.add_game(false)
	assert_eq(history.difficulty, UserMinigameHistory.MIN_DIFFICULTY + 1)
	assert_eq(history.consecutives_losses, 0)
	assert_eq(history.consecutives_wins, 0)
	assert_eq(history.history, [false, false])


func test_wins_do_not_exceed_max_difficulty() -> void:
	var history: UserMinigameHistory = UserMinigameHistory.new()
	history.difficulty = UserMinigameHistory.MAX_DIFFICULTY
	history.consecutives_wins = UserMinigameHistory.CONSECUTIVE_WINS_TO_PROMOTE - 1
	history.add_game(true)
	assert_eq(history.difficulty, UserMinigameHistory.MAX_DIFFICULTY)
	assert_eq(history.consecutives_wins, 0)
	assert_eq(history.consecutives_losses, 0)
	assert_eq(history.history, [true])


func test_losses_do_not_go_below_min_difficulty() -> void:
	var history: UserMinigameHistory = UserMinigameHistory.new()
	history.difficulty = UserMinigameHistory.MIN_DIFFICULTY
	history.consecutives_losses = UserMinigameHistory.CONSECUTIVE_LOSSES_TO_DEMOTE - 1
	history.add_game(false)
	assert_eq(history.difficulty, UserMinigameHistory.MIN_DIFFICULTY)
	assert_eq(history.consecutives_losses, 0)
	assert_eq(history.consecutives_wins, 0)
	assert_eq(history.history, [false])


func test_mixed_results_track_consecutive_counters() -> void:
	var history: UserMinigameHistory = UserMinigameHistory.new()
	history.add_game(true)
	for _loss: int in history.CONSECUTIVE_LOSSES_TO_DEMOTE:
		history.add_game(false)
	assert_eq(history.history, [true, false, false])
	assert_eq(history.consecutives_wins, 0)
	assert_eq(history.consecutives_losses, 0)
	assert_eq(history.difficulty, UserMinigameHistory.MIN_DIFFICULTY)
	history.add_game(false)
	for _win: int in history.CONSECUTIVE_WINS_TO_PROMOTE:
		history.add_game(true)
	assert_eq(history.consecutives_wins, 0)
	assert_eq(history.consecutives_losses, 0)
	assert_eq(history.difficulty, UserMinigameHistory.MIN_DIFFICULTY + 1)


func test_extended_history() -> void:
	var history: UserMinigameHistory = UserMinigameHistory.new()
	history.add_game(true)
	history.add_game(false)
	history.add_game(false)
	history.add_game(true)
	history.add_game(true)
	history.add_game(false)
	history.add_game(true)
	history.add_game(false)
	history.add_game(true)
	assert_eq(history.history, [true, false, false, true, true, false, true, false, true])
