extends Resource
class_name UserMinigameHistory

const min_difficulty: = 0
const max_difficulty: = 4
const consecutive_wins_to_promote: = 2
const consecutive_losses_to_demote: = 2

@export
var difficulty: int = 0
@export
var consecutives_losses: int = 0
@export
var consecutives_wins: int = 0
@export
var history : Array[bool] = []

func add_game(is_won: bool) -> void:
	history.append(is_won)
	if is_won:
		consecutives_losses = 0
		consecutives_wins += 1
		if consecutives_wins >= consecutive_wins_to_promote:
			consecutives_wins = 0
			if difficulty != max_difficulty:
				difficulty += 1
	else:
		consecutives_wins = 0
		consecutives_losses += 1
		if consecutives_losses >= consecutive_losses_to_demote:
			consecutives_losses = 0
			if difficulty != min_difficulty:
				difficulty -= 1
