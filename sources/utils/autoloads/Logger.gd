extends Node

enum LogLevel {
	TRACE,
	DEBUG,
	INFO,
	WARNING,
	ERROR,
	NONE
}

var current_level: LogLevel = LogLevel.INFO
var log_file_path: String
var log_file: FileAccess
var initialized: bool = false

const logPath: String = "user://Logs/"

func _ready() -> void:
	delete_old_logs()
	_init_log_file()
	if Engine.is_editor_hint() or OS.has_feature("editor"):
		current_level = LogLevel.TRACE # In-editor: full logs
	elif OS.has_feature("debug"):
		current_level = LogLevel.DEBUG # Exported: debug mode
	else:
		current_level = LogLevel.INFO  # Exported: release mode
	initialized = true
	_log_internal(LogLevel.INFO, "--- Logging started at " + Time.get_datetime_string_from_system() + " ---")
	_log_internal(LogLevel.INFO, "--- Logging set at level " + str(current_level) + " ---")

func delete_old_logs(days_threshold: float = 10) -> void:
	var dir: DirAccess = DirAccess.open(logPath)
	if dir == null:
		push_warning("Logger: Could not open Logs directory for cleanup.")
		return

	var now: float = Time.get_unix_time_from_system()
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.begins_with("Kalulu_Log_") and file_name.ends_with(".txt"):
			var parts: PackedStringArray = file_name.get_basename().replace("Kalulu_Log_", "").split("-")
			if parts.size() >= 6:
				var date_dict: Dictionary = {
					"year": parts[0].to_int(),
					"month": parts[1].to_int(),
					"day": parts[2].to_int(),
					"hour": parts[3].to_int(),
					"minute": parts[4].to_int(),
					"second": parts[5].to_int()
				}
				var file_time: int = Time.get_unix_time_from_datetime_dict(date_dict)
				var age_days: float = float(now - file_time) / (60.0 * 60.0 * 24.0)
				if age_days > days_threshold:
					var full_path: String = logPath + file_name
					var err: Error = dir.remove(full_path)
					if err != OK:
						push_warning("Logger: Failed to delete old log: " + full_path)
					else:
						print("Logger: Deleted old log:", full_path)
		file_name = dir.get_next()
	dir.list_dir_end()

func _init_log_file() -> void:
	# Ensure Logs directory exists
	var logs_dir: DirAccess = DirAccess.open(logPath)
	if logs_dir == null:
		DirAccess.make_dir_recursive_absolute(logPath)

	var now: Dictionary = Time.get_datetime_dict_from_system()
	var filename: String = "Kalulu_Log_%04d-%02d-%02d-%02d-%02d-%02d.txt" % [
		now.year, now.month, now.day,
		now.hour, now.minute, now.second
	]
	log_file_path = logPath + filename

	log_file = FileAccess.open(log_file_path, FileAccess.WRITE)
	if log_file == null:
		push_error("Logger: Could not open log file at " + log_file_path)

# Internal log function (renamed to avoid conflict)
func _log_internal(level: LogLevel, message: String) -> void:
	if initialized && level < current_level: # If not initialized, no logs are filtered
		return

	var prefix: String = "[LOG]"
	match level:
		LogLevel.TRACE: prefix = "[TRACE]"
		LogLevel.DEBUG: prefix = "[DEBUG]"
		LogLevel.INFO: prefix = "[INFO]"
		LogLevel.WARNING: prefix = "[WARNING]"
		LogLevel.ERROR: prefix = "[ERROR]"

	var time_str: String = Time.get_time_string_from_system()
	var log_message: String = "%s %s %s" % [time_str, prefix, message]

	match level:
		LogLevel.WARNING:
			push_warning(log_message)
		LogLevel.ERROR:
			push_error(log_message)
		_:
			print(log_message)

	_log_to_file(log_message)

func _log_to_file(message: String) -> void:
	if log_file:
		log_file.store_line(message)
		log_file.flush()

# Sugar functions
func trace(msg: String) -> void: _log_internal(LogLevel.TRACE, msg)
func debug(msg: String) -> void: _log_internal(LogLevel.DEBUG, msg)
func info(msg: String) -> void: _log_internal(LogLevel.INFO, msg)
func warn(msg: String) -> void: _log_internal(LogLevel.WARNING, msg)
func error(msg: String) -> void: _log_internal(LogLevel.ERROR, msg)
