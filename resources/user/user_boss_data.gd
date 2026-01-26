class_name UserBossData
extends Resource
## Stores boss session analytics locally.

signal boss_data_changed()

# TODO
# Will be used to know which scores need to be synchronized with backend.
# Any score with "timestamp" greater than this variable need to be uploaded.
@export var last_synchronized_at: int = 0
@export var sessions: Array[Dictionary] = []


func start_session(timestamp: int) -> int:
	var session: Dictionary = {
		"timestamp": timestamp,
		"victory": false,
		"answers": []
	}
	sessions.append(session)
	boss_data_changed.emit()
	return sessions.size() - 1


func add_answer(session_index: int, is_real_word: bool, word_length: int, response_time_ms: int, is_correct: bool) -> void:
	if session_index < 0 or session_index >= sessions.size():
		Log.warn("UserBossData: Invalid session index %d for add_answer" % session_index)
		return
	var session: Dictionary = sessions[session_index]
	var answers: Array = session.get("answers", [])
	answers.append({
		"is_real_word": is_real_word,
		"word_length": word_length,
		"response_time_ms": response_time_ms,
		"is_correct": is_correct
	})
	session["answers"] = answers
	sessions[session_index] = session
	boss_data_changed.emit()


func finish_session(session_index: int, victory: bool) -> void:
	if session_index < 0 or session_index >= sessions.size():
		Log.warn("UserBossData: Invalid session index %d for finish_session" % session_index)
		return
	var session: Dictionary = sessions[session_index]
	session["victory"] = victory
	sessions[session_index] = session
	boss_data_changed.emit()
