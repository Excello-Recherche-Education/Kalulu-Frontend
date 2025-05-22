extends Resource
class_name UserRemediation

signal score_changed()

# Defines the minimal score a GP can get, it doesn't go below that point
const min_score: int = -3

# Defines the score from which the GP should be presented for remediation
const remediation_score: int = -2

# Defines the score for each GP
# Key is the ID of the GP
# Value is the score of the GP
@export
var gps_scores: Dictionary[int, int] = {}


# Gets the score of a GP if it is below or equals to the remediation score
func get_gp_score(ID: int) -> int:
	if gps_scores.has(ID):
		return gps_scores[ID] if gps_scores[ID] <= remediation_score else 0
	return 0


# Updates the global scores from a minigame scores
func update_gp_scores(minigame_scores: Dictionary) -> void:
	if not minigame_scores:
		return
	Logger.trace("UserRemediation: Update GP Scores: " + str(minigame_scores))
	for ID: int in minigame_scores.keys():
		var new_gp_score: int = 0
		if gps_scores.has(ID):
			new_gp_score += gps_scores[ID]
		new_gp_score += minigame_scores[ID]
		
		if new_gp_score >= 0:
			gps_scores.erase(ID)
		else:
			gps_scores[ID] = maxi(min_score, new_gp_score)
	
	score_changed.emit()
