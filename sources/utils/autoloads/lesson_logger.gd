extends Node

# Contains the current log resource
var log_resources: Dictionary = {}


func save_logs(logs: Dictionary, folder_path: String, minigame_name: String, lesson_nb: int, time: String) -> void:
	var file_path: String = folder_path + minigame_name + ".tres"
	
	var log_resource: LogResource
	if not ResourceLoader.exists(file_path):
		log_resource = LogResource.new()
		ResourceSaver.save(log_resource, file_path, ResourceSaver.FLAG_COMPRESS)
	
	if not file_path in log_resources:
		log_resource = ResourceLoader.load(file_path)
		log_resources[file_path] = log_resource
	else:
		log_resource = log_resources[file_path]
	
	log_resource.add_log(lesson_nb, logs, time)
	
	ResourceSaver.save(log_resource, file_path, ResourceSaver.FLAG_COMPRESS)
