extends Node
class_name Logger

const log_resource_class: = preload("res://sources/utils/minigame_resources/log.gd")

var log_resources: = {}


func save_logs(logs: Dictionary, teacher_id: String, user_id: String, minigame_name: String, lesson: String, time: String) -> void:
	var file_path: = "user://" + teacher_id + "/" + user_id + "/" + minigame_name + ".tres"
	
	if not ResourceLoader.exists(file_path):
		var log_resource: LogResource = log_resource_class.instance()
		ResourceSaver.save(log_resource, file_path, ResourceSaver.FLAG_COMPRESS)
	
	if not file_path in log_resources:
		var log_resource: = ResourceLoader.load(file_path)
		log_resources[file_path] = log_resource
	
	if not log_resources[file_path].has(lesson):
		log_resources[file_path][lesson] = {}
	
	if not log_resources[file_path][lesson].has(time):
		log_resources[file_path][lesson][time] = logs
	else:
		var i: = 0
		while log_resources[file_path][lesson].has(time + "_" + str(i)):
			i += 1
		log_resources[file_path][lesson][time + "_" + str(i)] = logs
	
	ResourceSaver.save(log_resources[file_path], file_path, ResourceSaver.FLAG_COMPRESS)
