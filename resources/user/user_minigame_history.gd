class_name UserMinigameHistory
extends Resource

const MIN_DIFFICULTY: int = 0
const MAX_DIFFICULTY: int = 4
const CONSECUTIVE_WINS_TO_PROMOTE: int = 2
const CONSECUTIVE_LOSSES_TO_DEMOTE: int = 2

@export var difficulty: int = 0
@export var consecutives_losses: int = 0
@export var consecutives_wins: int = 0
@export var history: Array[bool] = []


func add_game(is_won: bool) -> void:
	history.append(is_won)
	if is_won:
		consecutives_losses = 0
		consecutives_wins += 1
		if consecutives_wins >= CONSECUTIVE_WINS_TO_PROMOTE:
			consecutives_wins = 0
			if difficulty != MAX_DIFFICULTY:
				difficulty += 1
	else:
		consecutives_wins = 0
		consecutives_losses += 1
		if consecutives_losses >= CONSECUTIVE_LOSSES_TO_DEMOTE:
			consecutives_losses = 0
			if difficulty != MIN_DIFFICULTY:
				difficulty -= 1
