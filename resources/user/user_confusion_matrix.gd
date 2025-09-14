class_name UserConfusionMatrix
extends Resource
## Confusion matrix: for each expected answer (int key),
## we keep the history of the answers actually given (PackedInt32Array),
## limited to HISTORY_LENGTH entries (FIFO).

signal score_changed()

const HISTORY_LENGTH: int = 5

#region utils

func append_and_trim(target: Dictionary[int, PackedInt32Array], expected_id: int, additions: PackedInt32Array) -> void:
	var stored: PackedInt32Array = PackedInt32Array()
	if target.has(expected_id):
		stored = target[expected_id]

	# Add
	if additions.size() > 0:
		stored.append_array(additions)

	# Trim
	if stored.size() > HISTORY_LENGTH:
		var keep_from: int = max(0, stored.size() - HISTORY_LENGTH)
		var trimmed: PackedInt32Array= PackedInt32Array()
		for index: int in range(keep_from, stored.size()):
			trimmed.append(stored[index])
		stored = trimmed

	# Update
	if stored.is_empty():
		target.erase(expected_id)
	else:
		target[expected_id] = stored

#endregion

#region GP Scores

# Key is the ID of the expected answer
# Value is a PackedInt32Array whose entries are the IDs of the answers
@export var gp_scores: Dictionary[int, PackedInt32Array] = {}
@export var gp_last_modified: String = ""


# Gets (a copy of) the data of a GP
func get_gp_scores(id: int) -> PackedInt32Array:
	if gp_scores.has(id):
		# Return a copy to avoid mutations
		return PackedInt32Array(gp_scores[id])
	return PackedInt32Array()


# Updates the confusion matrix from a minigame scores
func update_gp_scores(minigame_scores: Dictionary[int, PackedInt32Array]) -> void:
	if not minigame_scores or minigame_scores.is_empty():
		return
	Logger.trace("UserConfusionMatrix: Update GP scores: %s" % [str(minigame_scores)])
	for expected_id: int in minigame_scores.keys():
		var given_list: PackedInt32Array = minigame_scores[expected_id]
		append_and_trim(gp_scores, expected_id, given_list)
	set_gp_last_modified(Time.get_datetime_string_from_system(true))
	score_changed.emit()


func set_gp_scores(new_scores: Dictionary[int, PackedInt32Array]) -> void:
	var cleaned: Dictionary[int, PackedInt32Array] = {}
	for expected_id: int in new_scores.keys():
		var arr: PackedInt32Array = new_scores[expected_id]
		append_and_trim(cleaned, expected_id, arr) # auto-trim
	gp_scores = cleaned
	set_gp_last_modified(Time.get_datetime_string_from_system(true))


func set_gp_last_modified(new_date: String) -> void:
	gp_last_modified = new_date

#endregion
