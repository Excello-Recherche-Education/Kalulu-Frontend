extends Node

enum LogLevel {
	TRACE,
	DEBUG,
	INFO,
	WARNING,
	ERROR,
	ALERT,
	PANIC,
	NONE
}

const FILE_BASE_NAME: String = "Kalulu_Log"
const LOG_PATH: String = "user://Logs/"
const LOG_MAX_SIZE_BYTES: int = 1 * 1024
const MAX_LOG_ENTRIES_IN_RAM: int = 13985
const MAX_LOG_ENTRIES_THRESHOLD: int = 100

var current_level: LogLevel = LogLevel.INFO
var log_file_base_path: String
var log_file_path: String
var log_file: FileAccess
var initialized: bool = false
var all_logs: PackedStringArray = []
var log_rotation_index: int = 1


func _ready() -> void:
	delete_old_logs()
	_init_log_file()
	if Engine.is_editor_hint() or OS.has_feature("editor"):
		current_level = LogLevel.TRACE # In-editor: full logs
	elif OS.has_feature("debug"):
		current_level = LogLevel.DEBUG # Exported: debug mode
	else:
		current_level = LogLevel.INFO # Exported: release mode
	initialized = true
	_log_internal(LogLevel.INFO, "--- Logging started at " + Time.get_datetime_string_from_system() + " ---")
	_log_internal(LogLevel.INFO, "--- Logging set at level " + str(current_level) + " ---")


func delete_old_logs(days_threshold: float = 10) -> void:
	var dir: DirAccess = DirAccess.open(LOG_PATH)
	var err: Error = DirAccess.get_open_error()
	if err == ERR_DOES_NOT_EXIST:
		var create_err: Error = DirAccess.make_dir_recursive_absolute(LOG_PATH)
		if create_err != OK:
			push_error("Log: Could not create Logs directory for cleanup. Error: %s" % error_string(create_err))
			return
		dir = DirAccess.open(LOG_PATH)
		err = DirAccess.get_open_error()
	if err != OK:
		push_error("Log: Could not open Logs directory for cleanup. Error: %s" % error_string(err))
		return
	if not dir:
		push_warning("Log: Could not open Logs directory for cleanup.")
		return
	
	var now: float = Time.get_unix_time_from_system()
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		var base: String = file_name.get_basename()
		if base.begins_with(FILE_BASE_NAME + "_"):
			var date_part: String = base.substr(FILE_BASE_NAME.length() + 1)
			# Truncate at YYYY-MM-DD-HH-MM-SS (19 char)
			if date_part.length() >= 19:
				date_part = date_part.substr(0, 19)
				var parts: PackedStringArray = date_part.split("-")
				if parts.size() == 6:
					var date_dict: Dictionary[String, int] = {
						"year": int(parts[0]),
						"month": int(parts[1]),
						"day": int(parts[2]),
						"hour": int(parts[3]),
						"minute": int(parts[4]),
						"second": int(parts[5]),
					}
					var file_time: int = Time.get_unix_time_from_datetime_dict(date_dict)
					var age_days: float = float(now - file_time) / (60.0 * 60.0 * 24.0)
					if age_days > days_threshold:
						var full_path: String = LOG_PATH + file_name
						err = dir.remove(full_path)
						if err != OK:
							push_warning("Log: Failed to delete old log: " + full_path)
						else:
							print("Log: Deleted old log:", full_path)
		file_name = dir.get_next()
	dir.list_dir_end()


func _init_log_file(path_override: String = "") -> void:
	# Ensure Logs directory exists
	var logs_dir: DirAccess = DirAccess.open(LOG_PATH)
	if logs_dir == null:
		DirAccess.make_dir_recursive_absolute(LOG_PATH)
	
	if log_file_base_path == "":
		var now: Dictionary = Time.get_datetime_dict_from_system()
		var filename: String = "%s_%04d-%02d-%02d-%02d-%02d-%02d.txt" % [
			FILE_BASE_NAME,
			now.year, now.month, now.day,
			now.hour, now.minute, now.second
		]
		log_file_base_path = LOG_PATH + filename
		log_rotation_index = 1
	if path_override == "":
		log_file_path = _build_rotated_log_path()
	else:
		log_file_path = path_override
	
	log_file = FileAccess.open(log_file_path, FileAccess.WRITE)
	var err: Error = FileAccess.get_open_error()
	if err != OK:
		push_error("Log: Init Log File: Cannot open file %s. Error: %s" % [log_file_path, error_string(err)])
		return
	if log_file == null:
		push_error("Log: Init Log File: Could not open log file at " + log_file_path)
		return


# Internal log function (renamed to avoid conflict)
func _log_internal(level: LogLevel, message: String) -> void:
	if initialized and level < current_level: # If not initialized, no logs are filtered
		return
	
	var prefix: String = "[LOG]"
	match level:
		LogLevel.TRACE: prefix = "[TRACE]"
		LogLevel.DEBUG: prefix = "[DEBUG]"
		LogLevel.INFO: prefix = "[INFO]"
		LogLevel.WARNING: prefix = "[WARNING]"
		LogLevel.ERROR: prefix = "[ERROR]"
		LogLevel.ALERT: prefix = "[ALERT]"
		LogLevel.PANIC: prefix = "[PANIC]"
	
	var time_str: String = Time.get_time_string_from_system()
	var log_message: String = "%s %s %s" % [time_str, prefix, message]
	all_logs.append(log_message)
	if all_logs.size() > MAX_LOG_ENTRIES_IN_RAM + MAX_LOG_ENTRIES_THRESHOLD:
		# Delete old logs
		var overflow: int = all_logs.size() - MAX_LOG_ENTRIES_IN_RAM
		all_logs = all_logs.slice(overflow)
	_log_to_file(log_message)
	match level:
		LogLevel.DEBUG:
			print_debug(log_message)
		LogLevel.WARNING:
			push_warning(log_message)
		LogLevel.ERROR:
			push_error(log_message)
		LogLevel.ALERT:
			OS.alert(log_message)
		LogLevel.PANIC:
			OS.crash(log_message)
		_:
			print(log_message)


func _log_to_file(message: String) -> void:
	if log_file:
		_rotate_log_file_if_needed(message)
		log_file.store_line(message)
		log_file.flush()


func _rotate_log_file_if_needed(message: String) -> void:
	if log_file == null:
		return
	var current_size: int = log_file.get_length()
	var message_size: int = message.to_utf8_buffer().size() + 1
	if current_size + message_size <= LOG_MAX_SIZE_BYTES:
		return
	var previous_log_path: String = log_file_path
	_bump_rotation_index()
	var next_log_path: String = _build_rotated_log_path()
	log_file.store_line("Log rotation: next logs are in file \"%s\"." % next_log_path)
	log_file.flush()
	log_file.close()
	_init_log_file(next_log_path)
	if log_file:
		log_file.store_line("Log continuation from file \"%s\"." % previous_log_path)
		log_file.flush()


func _build_rotated_log_path() -> String:
	var base_name: String = log_file_base_path.get_basename()
	var extension: String = log_file_base_path.get_extension()
	var suffix: String = _rotation_suffix(log_rotation_index)
	var path: String = base_name + suffix
	if extension != "":
		path += "." + extension
	while FileAccess.file_exists(path):
		_bump_rotation_index()
		suffix = _rotation_suffix(log_rotation_index)
		path = base_name + suffix
		if extension != "":
			path += "." + extension
	return path


func _rotation_suffix(index: int) -> String:
	if index <= 1:
		return ""
	if index <= 999:
		return "_%s" % str(index).pad_zeros(3)
	return "_%d" % index


func _bump_rotation_index() -> void:
	if log_rotation_index < 999:
		log_rotation_index += 1
	elif log_rotation_index == 999:
		log_rotation_index = 1000
		alert(tr("LOG_TOO_MUCH_ROTATION"))
	else:
		log_rotation_index += 1


# trace can be used everywhere, in order to have a full log of all that is hapenning
func trace(msg: String) -> void: _log_internal(LogLevel.TRACE, msg)


# debug should only be used in a dev environment to track a specific bug.
func debug(msg: String) -> void: _log_internal(LogLevel.DEBUG, msg)


# info can carry important information(s) that should always be logged but that are not problematic
func info(msg: String) -> void: _log_internal(LogLevel.INFO, msg)


# warning should be used when a behaviour is not normal, but this is not blocking or it could be ignored
func warn(msg: String) -> void: _log_internal(LogLevel.WARNING, msg)


# error should be used everytime the program does something that is problematic and could potentially harm the user experience
func error(msg: String) -> void: _log_internal(LogLevel.ERROR, msg)


# alert will displays a modal dialog box using the host platform's implementation. The engine execution is blocked until the dialog is closed.
func alert(msg: String) -> void: _log_internal(LogLevel.ALERT, msg)


# panic will crash the app and should only be used for testing the system's crash handler, not for any other purpose.
func panic(msg: String) -> void: _log_internal(LogLevel.PANIC, msg)
