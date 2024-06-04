extends Resource
class_name UserRemediation

signal score_changed()

# Defines the minimal score a GP can get, it doesn't go below that point
const min_score: int = -3

# Defines the score from which the GP should be presented for remediation
const remediation_score: int = -2

# Defines the score for each GP for the syllables and words minigames
# Key is the ID of the GP
# Value is the score of the GP
var gps_scores: Dictionary = { 2: -2}


# Gets the score of a GP if it is below or equals to the remediation score
func get_score(ID: int) -> int:
	if gps_scores.has(ID):
		return gps_scores[ID] if gps_scores[ID] <= remediation_score else 0
	return 0


# Updates the global scores from a minigame scores
func update_scores(minigame_scores: Dictionary) -> void:
	print(minigame_scores)
	if not minigame_scores:
		return
	
	for ID : int in minigame_scores.keys():
		var new_score: = 0
		if gps_scores.has(ID):
			new_score += gps_scores[ID]
		new_score += minigame_scores[ID]
		
		if new_score >= 0:
			gps_scores.erase(ID)
		else:
			gps_scores[ID] = max(min_score, new_score)
	
	score_changed.emit()
