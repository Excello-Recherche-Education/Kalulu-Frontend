extends ZIPPacker
class_name FolderZipper


func write_folder_recursive(abs_path: String, rel_path: String) -> Error:
	var full_path: String = abs_path.path_join(rel_path)
	var dir: DirAccess = DirAccess.open(full_path)
	if not dir:
		return DirAccess.get_open_error()

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		# Ignore "." et ".."
		if file_name != "." and file_name != "..":
			var current_rel_path: String = rel_path.path_join(file_name)
			var current_full_path: String = full_path.path_join(file_name)

			if dir.current_is_dir():
				var error: Error = write_folder_recursive(abs_path, current_rel_path)
				if error != OK:
					return error
			else:
				var error: Error = start_file(current_rel_path)
				if error != OK:
					return error

				var file: FileAccess = FileAccess.open(current_full_path, FileAccess.READ)
				if file:
					write_file(file.get_buffer(file.get_length()))
					file.close()
				else:
					return FileAccess.get_open_error()

		file_name = dir.get_next()
	dir.list_dir_end()
	return OK


func compress(path: String, output_name: String) -> void:
	open(output_name, ZIPPacker.APPEND_CREATE)
	path = path.simplify_path()
	var err: Error = write_folder_recursive(path.get_base_dir(), path.get_file())
	if err != OK:
		Logger.error("FolderZipper: Error " + error_string(err) + " while compressing folder: %s" % path)
	close()
