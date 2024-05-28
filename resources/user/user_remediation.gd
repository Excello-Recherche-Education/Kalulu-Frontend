extends Resource
class_name UserRemediation

signal score_changed()

const min_score: int = -3

# Defines the score for each GP for the syllables and words minigames
# Key is the ID of the GP
# Value is the score of the GP
var gp_score: Dictionary = {}


func add_score(ID: int) -> void:
	var score: int = gp_score.get(ID)
	if not score:
		return
	
	score += 1
	if score >= 0:
		gp_score.erase(ID)
	else:
		gp_score[ID] = score
	score_changed.emit()


func lower_score(ID: int) -> void:
	var score: int = gp_score.get(ID)
	if score <= min_score:
		return
		
	gp_score[ID] -= 1
	score_changed.emit()
