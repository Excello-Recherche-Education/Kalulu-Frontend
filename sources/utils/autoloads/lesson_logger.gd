extends Node

# Contains the current log resource
var log_resources: Dictionary = {}


func save_logs(logs: Dictionary, folder_path: String, minigame_name: String, lesson_nb: int, time: String) -> void:
	Log.trace("LessonLogger: Saving logs for %s (lesson %d)" % [minigame_name, lesson_nb])
	# In a folder of their own, because these are named after the minigame and the
	# student folder also holds the data files UserDataManager keeps there. "boss"
	# collided with its boss.tres, so from the rename of that minigame onward every
	# boss log was dropped on the floor: the path already held a UserBossData, and
	# loading it as a LogResource failed. Any future minigame called "progression"
	# or "difficulty" would have gone the same way.
	var logs_folder: String = folder_path.path_join("logs")
	if not DirAccess.dir_exists_absolute(logs_folder):
		var dir_error: Error = DirAccess.make_dir_recursive_absolute(logs_folder)
		if dir_error != OK:
			Log.error("LessonLogger: Failed to create %s. Error: %s" % [logs_folder, error_string(dir_error)])
			return
	var file_path: String = logs_folder.path_join(minigame_name + ".tres")
	var log_resource: LogResource
	if not ResourceLoader.exists(file_path):
		Log.trace("LessonLogger: Creating new log file at " + file_path)
		log_resource = LogResource.new()
		var create_error: Error = ResourceSaver.save(log_resource, file_path, ResourceSaver.FLAG_COMPRESS)
		if create_error != OK:
			Log.error("LessonLogger: Failed to create log file %s. Error: %s" % [file_path, error_string(create_error)])
			return
	if not file_path in log_resources:
		# Cast rather than assign, so something else living at this path is a clear
		# message instead of an assignment failure three frames from the cause.
		var loaded: Resource = ResourceLoader.load(file_path)
		log_resource = loaded as LogResource
		if not log_resource:
			Log.error("LessonLogger: %s holds %s, not a LogResource; logs for %s (lesson %d) not saved"
				% [file_path, loaded.get_class() if loaded else "nothing", minigame_name, lesson_nb])
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
