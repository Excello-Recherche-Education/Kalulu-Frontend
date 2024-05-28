extends Resource
class_name UserRemediation

signal score_changed()

const min_score: int = -3

# Defines the score for each GP for the syllables and words minigames
# Key is the ID of the GP
# Value is the score of the GP
var gps_scores: Dictionary = {}


func update_scores(scores: Dictionary) -> void:
	print(scores)
	if not scores:
		return
	
	for ID : int in scores.keys():
		var new_score: = 0
		if gps_scores.has(ID):
			new_score += gps_scores[ID]
		new_score += scores[ID]
		
		if new_score >= 0:
			gps_scores.erase(ID)
		else:
			gps_scores[ID] = max(min_score, new_score)
	
	score_changed.emit()
