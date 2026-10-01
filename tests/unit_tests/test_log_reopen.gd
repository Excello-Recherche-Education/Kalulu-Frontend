extends GutTest
## Opening the session's log file again when the first attempt failed.
##
## The old-log cleanup runs after the first frame, so on a device whose storage the
## old logs had filled, the session's file can fail to open before the cleanup frees
## the space. It is then opened again, and must not lose what was logged meanwhile.
##
## A fresh copy of the script rather than the Log autoload: reopening the autoload's
## file would truncate the log this very test run is writing.

const LOG_SCRIPT: GDScript = preload("res://sources/utils/autoloads/log.gd")
const TEST_LOG_PATH: String = "user://test_log_reopen.txt"

var _log: Node


func before_each() -> void:
	DirAccess.remove_absolute(TEST_LOG_PATH)
	_log = LOG_SCRIPT.new()
	_log.set("log_file_base_path", TEST_LOG_PATH)


func after_each() -> void:
	var log_file: FileAccess = _log.get("log_file") as FileAccess
	if log_file:
		log_file.close()
	_log.free()
	DirAccess.remove_absolute(TEST_LOG_PATH)


func test_what_was_logged_before_the_file_opened_is_written_into_it() -> void:
	_log.set("all_logs", PackedStringArray(["10:00:00 [INFO] logged while the file was closed"]))

	_log.call("_reopen_log_file")

	assert_not_null(_log.get("log_file"), "the file should be open now")
	var written: String = FileAccess.get_file_as_string(TEST_LOG_PATH)
	assert_string_contains(written, "logged while the file was closed")
	assert_string_contains(written, "Log file opened once old logs were cleared")
