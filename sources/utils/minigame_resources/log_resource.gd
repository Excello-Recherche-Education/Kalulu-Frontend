class_name LogResource
extends Resource

@export var logs: Dictionary = {} # int: Dictionary {String: Dictionary}


func add_log(lesson_nb: int, new_log: Dictionary, time: String) -> void:
	if not logs.has(lesson_nb):
		logs[lesson_nb] = {}
		Log.trace("LogResource: Created log bucket for lesson %d" % lesson_nb)
	
	var lesson_logs: Dictionary = logs[lesson_nb]
	if not lesson_logs.has(time):
		logs[lesson_nb][time] = new_log
		Log.trace("LogResource: Added log for lesson %d at %s" % [lesson_nb, time])
	else:
		var index: int = 2
		while lesson_logs.has(time + "_" + str(index)):
			index += 1
		var new_key: String = time + "_" + str(index)
		logs[lesson_nb][new_key] = new_log
		Log.warn("LogResource: Duplicate log time %s for lesson %d. Stored as %s" % [time, lesson_nb, new_key])
