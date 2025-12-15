extends Node

# Contains the current log resource
var log_resources: Dictionary = {}


func save_logs(logs: Dictionary, folder_path: String, minigame_name: String, lesson_nb: int, time: String) -> void:
	Log.trace("LessonLogger: Saving logs for %s (lesson %d)" % [minigame_name, lesson_nb])
	var file_path: String = folder_path + "/" + minigame_name + ".tres"
	var log_resource: LogResource
	if not ResourceLoader.exists(file_path):
		Log.trace("LessonLogger: Creating new log file at " + file_path)
		log_resource = LogResource.new()
		var create_error: Error = ResourceSaver.save(log_resource, file_path, ResourceSaver.FLAG_COMPRESS)
		if create_error != OK:
			Log.error("LessonLogger: Failed to create log file %s. Error: %s" % [file_path, error_string(create_error)])
			return
	if not file_path in log_resources:
		log_resource = ResourceLoader.load(file_path)
		if not log_resource:
			Log.error("LessonLogger: Failed to load log resource from " + file_path)
			return
		log_resources[file_path] = log_resource
	else:
		log_resource = log_resources[file_path]
	log_resource.add_log(lesson_nb, logs, time)
	var save_error: Error = ResourceSaver.save(log_resource, file_path, ResourceSaver.FLAG_COMPRESS)
	if save_error != OK:
		Log.error("LessonLogger: Failed to save logs for %s (lesson %d). Error: %s" % [minigame_name, lesson_nb, error_string(save_error)])
		return
	Log.trace("LessonLogger: Saved logs for %s (lesson %d) at %s" % [minigame_name, lesson_nb, file_path])
