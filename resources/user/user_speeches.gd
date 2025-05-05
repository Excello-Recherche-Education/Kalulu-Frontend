extends Resource
class_name UserSpeeches

signal speeches_changed

# Contains the list of speeches already played
@export var speeches_played: Array[String] = []

func add_speech(speech: String) -> void:
	if not speeches_played.has(speech):
		speeches_played.append(speech)
		speeches_changed.emit()

func is_speech_played(speech: String) -> bool:
	return speeches_played.has(speech)
