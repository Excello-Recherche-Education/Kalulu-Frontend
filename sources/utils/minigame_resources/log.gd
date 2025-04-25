extends Resource
class_name LogResource

@export var logs: Dictionary = {} # int : Dictionary {String : Dictionary}


func add_log(lesson_nb: int, new_log: Dictionary, time: String) -> void:
	if not logs.has(lesson_nb):
		logs[lesson_nb] = {}
	
	var lesson_logs: Dictionary = logs[lesson_nb]
	if not lesson_logs.has(time):
		logs[lesson_nb][time] = new_log
	else:
		var index: int = 2
		while lesson_logs.has(time + "_" + str(index)):
			index += 1
		logs[lesson_nb][time + "_" + str(index)] = new_log
