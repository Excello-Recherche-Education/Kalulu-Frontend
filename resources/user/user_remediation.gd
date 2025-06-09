extends Resource
class_name UserRemediation

signal score_changed()

# Defines the minimal score a GP can get, it doesn't go below that point
const MIN_SCORE: int = -3

# Defines the score from which the GP should be presented for remediation
const REMEDIATION_SCORE: int = -2

# Defines the score for each GP
# Key is the ID of the GP
# Value is the score of the GP
@export
var gps_scores: Dictionary[int, int] = {}


# Gets the score of a GP if it is below or equals to the remediation score
func get_gp_score(id: int) -> int:
	if gps_scores.has(id):
		return gps_scores[id] if gps_scores[id] <= REMEDIATION_SCORE else 0
	return 0


# Updates the global scores from a minigame scores
func update_gp_scores(minigame_scores: Dictionary) -> void:
	if not minigame_scores:
		return
	Logger.trace("UserRemediation: Update GP Scores: " + str(minigame_scores))
	for id: int in minigame_scores.keys():
		var new_gp_score: int = 0
		if gps_scores.has(id):
			new_gp_score += gps_scores[id]
		new_gp_score += minigame_scores[id]
		
		if new_gp_score >= 0:
			gps_scores.erase(id)
		else:
			gps_scores[id] = maxi(MIN_SCORE, new_gp_score)
	
	score_changed.emit()
