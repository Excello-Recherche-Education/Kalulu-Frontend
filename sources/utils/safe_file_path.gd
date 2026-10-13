class_name SafeFilePath
extends RefCounted
## Makes a pack file name one every platform can store.
##
## Windows refuses a handful of characters and a list of device names (CON,
## NUL, COM1...), so a name holding one is rewritten the same way when a pack
## is unzipped and when a file is looked up later -- both sides must agree.
## Part of the pack-format code shared by the game and the Prof Tool, so it
## depends on nothing but Log.

const RESERVED_FILE_NAMES: Array[String] = [
	"CON", "PRN", "AUX", "NUL",
	"COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
	"LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"
]
const INVALID_FILE_CHARS: Array[String] = ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]


static func from(file_path: String) -> String:
	var dir: String = file_path.get_base_dir()
	var file: String = file_path.get_file()
	var base: String = file.get_basename()
	var ext: String = file.get_extension()
	
	for chara: String in INVALID_FILE_CHARS:
		base = base.replace(chara, "_")
	
	var modified: bool = false
	if base.to_upper() in RESERVED_FILE_NAMES:
		base = "_" + base
		modified = true
	
	var new_name: String = "%s.%s" % [base, ext] if ext != "" else base
	var new_path: String = dir.path_join(new_name) if dir != "" else new_name
	
	if modified or new_path != file_path:
		Log.trace("SafeFilePath: Renamed invalid file path: '%s' → '%s'" % [file_path, new_path])
	
	return new_path
