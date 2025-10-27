class_name UserDifficulty
extends Resource

signal difficulty_changed()

# Stores the user history for all the minigames
# Key -> minigame_name: String
# Value -> UserMinigameHistory
@export var minigames_histories: Dictionary = {} 


# Gets the difficulty of the user for the given minigame
func get_difficulty(minigame_name: String) -> int:
	return minigames_histories.get(minigame_name, UserMinigameHistory.new()).difficulty


# Adds a game to the minigame history of the user and update difficulty if needed
func add_game(minigame_name: String, minigame_won: bool) -> void:
	var history: UserMinigameHistory = minigames_histories.get(minigame_name, UserMinigameHistory.new())
	history.add_game(minigame_won)
	minigames_histories[minigame_name] = history
	difficulty_changed.emit()
