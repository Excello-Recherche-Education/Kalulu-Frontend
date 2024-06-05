extends Resource
class_name UserDifficulty

signal difficulty_changed()

const min_difficulty: = 0
const max_difficulty: = 4
const consecutive_wins_to_promote: = 2
const consecutive_losses_to_demote: = 2

class UserMinigameHistory:
	var difficulty: int = 0
	var consecutives_losses: int = 0
	var consecutives_wins: int = 0
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
			if consecutives_losses <= consecutive_losses_to_demote:
				consecutives_losses = 0
				if difficulty != min_difficulty:
					difficulty -= 1


# Stores the user difficulty for all the minigames
@export
var minigames_histories: Dictionary = {}


# Gets the difficulty of the user for the given minigame
func get_difficulty(minigame_name: String) -> int:
	return minigames_histories.get(minigame_name, UserMinigameHistory.new()).difficulty


# Adds a game to the minigame history of the user and update difficulty if needed
func add_game(minigame_name: String, minigame_won: bool) -> void:
	var history : UserMinigameHistory = minigames_histories.get(minigame_name, UserMinigameHistory.new())
	history.add_game(minigame_won)
	minigames_histories[minigame_name] = history
	difficulty_changed.emit()
