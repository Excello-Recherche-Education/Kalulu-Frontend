extends ZIPPacker
class_name FolderZipper


func write_folder_recursive(abs_path: String, rel_path: String) -> Error:
	var dir: DirAccess = DirAccess.open(abs_path.path_join(rel_path))
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				var error: Error = write_folder_recursive(abs_path, rel_path.path_join(file_name))
				if error != OK:
					return error
			else:
				var error: Error = start_file(rel_path.path_join(file_name))
				if error != OK:
					return error
				var file: FileAccess = FileAccess.open(abs_path.path_join(rel_path).path_join(file_name), FileAccess.READ)
				write_file(file.get_buffer(file.get_length()))
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		return DirAccess.get_open_error()
	return OK


func compress(path: String, output_name: String) -> void:
	open(output_name, ZIPPacker.APPEND_CREATE)
	path = path.simplify_path()
	var err: Error = write_folder_recursive(path.get_base_dir(), path.get_file())
	if err != OK:
		Logger.error("FolderZipper: Error " + error_string(err) + " while compressing folder: %s" % path)
	close()
