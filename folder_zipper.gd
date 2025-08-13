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
				Logger.trace("FolderZipper: Adding %s" % current_rel_path)
				var error: Error = start_file(current_rel_path)
				if error != OK:
					return error
				
				var file: FileAccess = FileAccess.open(current_full_path, FileAccess.READ)
				error = FileAccess.get_open_error()
				if error != OK:
					Logger.error("FolderZipper: Extract: Cannot open file %s. Error: %s" % [file_name, error_string(error)])
					return error
				if file:
					write_file(file.get_buffer(file.get_length()))
					file.close()
					close_file()
				else:
					return FileAccess.get_open_error()
		
		file_name = dir.get_next()
	dir.list_dir_end()
	return OK


func compress(path: String, output_name: String) -> void:
	Logger.trace("FolderZipper: Compressing %s into %s" % [path, output_name])
	var err: Error = open(output_name, ZIPPacker.APPEND_CREATE)
	if err != OK:
			Logger.error("FolderZipper: Error " + error_string(err) + " while opening archive: %s" % output_name)
			return
	path = path.simplify_path()
	err = write_folder_recursive(path.get_base_dir(), path.get_file())
	if err != OK:
		Logger.error("FolderZipper: Error " + error_string(err) + " while compressing folder: %s" % path)
	close()
	Logger.trace("FolderZipper: Compression completed -> %s" % output_name)
