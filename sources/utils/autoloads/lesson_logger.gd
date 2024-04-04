extends Node

const log_resource_class: = preload("res://sources/utils/minigame_resources/log.gd")

# Contains the current log resource
var log_resources: = {}


func save_logs(logs: Dictionary, folder_path: String, minigame_name: String, lesson_nb: int, time: String) -> void:
	var file_path: = folder_path + minigame_name + ".tres"
	
	if not ResourceLoader.exists(file_path):
		var log_resource: LogResource = log_resource_class.new()
		ResourceSaver.save(log_resource, file_path, ResourceSaver.FLAG_COMPRESS)
	
	if not file_path in log_resources:
		var log_resource: = ResourceLoader.load(file_path)
		log_resources[file_path] = log_resource
	
	log_resources[file_path].add_log(lesson_nb, logs, time)
	
	ResourceSaver.save(log_resources[file_path], file_path, ResourceSaver.FLAG_COMPRESS)
