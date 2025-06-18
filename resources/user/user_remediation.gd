extends Resource
class_name UserRemediation

signal score_changed()

# Defines the minimal score a GP can get, it doesn't go below that point
const MIN_SCORE: int = -3
# Defines the maximal score a GP can get, it doesn't go above that point
const MAX_SCORE: int = 0
# Defines the score from which the GP should be presented for remediation
const REMEDIATION_SCORE: int = -2

#region GP Scores

# Key is the ID of the GP
# Value is the score of the GP
@export
var gps_scores: Dictionary[int, int] = {}

@export
var gp_last_modified: String = ""

# Gets the score of a GP if it is below or equals to the remediation score
func get_gp_score(id: int) -> int:
	if gps_scores.has(id):
		return gps_scores[id] if gps_scores[id] <= REMEDIATION_SCORE else 0
	return 0

# Updates the gp scores from a minigame scores
func update_gp_scores(minigame_scores: Dictionary) -> void:
	if not minigame_scores:
		return
	Logger.trace("UserRemediation: Update GP Scores: " + str(minigame_scores))
	for id: int in minigame_scores.keys():
		var new_gp_score: int = 0
		if gps_scores.has(id):
			new_gp_score += gps_scores[id]
		new_gp_score += minigame_scores[id]
		
		if new_gp_score >= MAX_SCORE:
			gps_scores.erase(id)
		else:
			gps_scores[id] = maxi(MIN_SCORE, new_gp_score)
	
	gp_last_modified = Time.get_datetime_string_from_system(true)
	score_changed.emit()

func set_gp_scores(new_scores: Dictionary[int, int]) -> void:
	gps_scores = new_scores

func set_gp_last_modified(new_date: String) -> void:
	gp_last_modified = new_date

#endregion

#region Syllables Scores

# Key is the ID of the syllable
# Value is the score of the syllable
@export
var syllables_scores: Dictionary[int, int] = {}

@export
var syllables_last_modified: String = ""

# Gets the score of a syllable if it is below or equals to the remediation score
func get_syllable_score(id: int) -> int:
	if syllables_scores.has(id):
		return syllables_scores[id] if syllables_scores[id] <= REMEDIATION_SCORE else 0
	return 0

# Updates the syllables scores from a minigame scores
func update_syllables_scores(minigame_scores: Dictionary) -> void:
	if not minigame_scores:
		return
	Logger.trace("UserRemediation: Update Syllable Scores: " + str(minigame_scores))
	for id: int in minigame_scores.keys():
		var new_syllable_score: int = 0
		if syllables_scores.has(id):
			new_syllable_score += syllables_scores[id]
		new_syllable_score += minigame_scores[id]
		
		if new_syllable_score >= MAX_SCORE:
			syllables_scores.erase(id)
		else:
			syllables_scores[id] = maxi(MIN_SCORE, new_syllable_score)
	
	syllables_last_modified = Time.get_datetime_string_from_system(true)
	score_changed.emit()

func set_syllables_scores(new_scores: Dictionary[int, int]) -> void:
	syllables_scores = new_scores

func set_syllables_last_modified(new_date: String) -> void:
	syllables_last_modified = new_date

#endregion

#region Words Scores

# Key is the ID of the word
# Value is the score of the word
@export
var words_scores: Dictionary[int, int] = {}

@export
var words_last_modified: String = ""

# Gets the score of a word if it is below or equals to the remediation score
func get_word_score(id: int) -> int:
	if words_scores.has(id):
		return words_scores[id] if words_scores[id] <= REMEDIATION_SCORE else 0
	return 0

# Updates the words scores from a minigame scores
func update_words_scores(minigame_scores: Dictionary) -> void:
	if not minigame_scores:
		return
	Logger.trace("UserRemediation: Update Syllable Scores: " + str(minigame_scores))
	for id: int in minigame_scores.keys():
		var new_word_score: int = 0
		if words_scores.has(id):
			new_word_score += words_scores[id]
		new_word_score += minigame_scores[id]
		
		if new_word_score >= MAX_SCORE:
			words_scores.erase(id)
		else:
			words_scores[id] = maxi(MIN_SCORE, new_word_score)
	
	words_last_modified = Time.get_datetime_string_from_system(true)
	score_changed.emit()

func set_words_scores(new_scores: Dictionary[int, int]) -> void:
	words_scores = new_scores

func set_words_last_modified(new_date: String) -> void:
	words_last_modified = new_date

#endregion
