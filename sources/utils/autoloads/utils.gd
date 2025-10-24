extends Node


func reorder_children_by_property(container: Node, property_name: String) -> void:
	var children: Array[Node] = container.get_children()
	children.sort_custom(Utils.sort_by_property.bind(property_name))
	for element: Node in container.get_children():
		container.remove_child(element)
	for element: Node in children:
		container.add_child(element)


func sort_by_property(node_a: Node, node_b: Node, property_name: String) -> bool:
	return node_a.get(property_name) < node_b.get(property_name)


func disconnect_all(signals: Signal) -> void:
	for connection: Dictionary in signals.get_connections():
		(connection["signal"] as Signal).disconnect(connection["callable"] as Callable)


func clean_dir(path: String) -> Error:
	var dir: DirAccess = DirAccess.open(path)
	var error: Error = DirAccess.get_open_error()
	if error != OK:
		return error
	if dir == null:
		return ERR_FILE_BAD_PATH
	for file: String in dir.get_files():
		dir.remove(file)
	for subfolder: String in dir.get_directories():
		error = clean_dir(path.path_join(subfolder))
		if error != OK:
			return error
		dir.remove(subfolder)
	return OK


func delete_directory_recursive(path: String) -> void:
	var err: Error = clean_dir(path)
	if err != OK:
		Log.error("Utils: Error " + error_string(err) + " while cleaning folder: %s" % path)
		return
	err = DirAccess.remove_absolute(path)
	if err != OK:
		Log.error("Utils: Error " + error_string(err) + " while deleting folder: %s" % path)
	else:
		Log.info("Utils: Folder deleted: %s" % path)


## Returns -1 if version_a is lower than version_b, 0 if they are equals, and 1 if version_a is greater than version_b
func compare_versions(version_a: String, version_b: String) -> int:
	var va: PackedStringArray = version_a.split(".")
	var vb: PackedStringArray = version_b.split(".")
	
	for index: int in range(3):
		var ai: int = int(va[index]) if index < va.size() else 0
		var bi: int = int(vb[index]) if index < vb.size() else 0
		if ai < bi:
			return -1
		elif ai > bi:
			return 1
	return 0


func get_safe_file_path(file_path: String) -> String:
	var dir: String = file_path.get_base_dir()
	var file: String = file_path.get_file()
	var base: String = file.get_basename()
	var ext: String = file.get_extension()
	
	var reserved_names: Array[String] = [
		"CON", "PRN", "AUX", "NUL",
		"COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
		"LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"
	]
	
	var invalid_chars: Array[String] = ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]
	for chara: String in invalid_chars:
		base = base.replace(chara, "_")
	
	var modified: bool = false
	if base.to_upper() in reserved_names:
		base = "_" + base
		modified = true
	
	var new_name: String = "%s.%s" % [base, ext] if ext != "" else base
	var new_path: String = dir.path_join(new_name) if dir != "" else new_name
	
	if modified or new_path != file_path:
		Log.trace("Utils: GetSafeFilePath: Renamed invalid file path: '%s' → '%s'" % [file_path, new_path])
	
	return new_path
