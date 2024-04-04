extends Resource
class_name LogResource

@export var logs: = {}


func add_log(lesson_nb: int, new_log: Dictionary, time: String) -> void:
	if not logs.has(lesson_nb):
		logs[lesson_nb] = {}
	
	if not logs[lesson_nb].has(time):
		logs[lesson_nb][time] = new_log
	else:
		var i: = 2
		while logs[lesson_nb].has(time + "_" + str(i)):
			i += 1
		logs[lesson_nb][time + "_" + str(i)] = new_log
