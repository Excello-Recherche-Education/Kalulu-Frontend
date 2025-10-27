class_name FolderZipper
extends ZIPPacker


func write_folder_recursive(abs_path: String, rel_path: String) -> Error:
	var full_path: String = abs_path.path_join(rel_path)
	var dir: DirAccess = DirAccess.open(full_path)
	if not dir:
		close()
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
					close()
					return error
			else:
				Log.trace("FolderZipper: Adding %s" % current_rel_path)
				var error: Error = start_file(current_rel_path)
				if error != OK:
					close()
					return error
				
				var file: FileAccess = FileAccess.open(current_full_path, FileAccess.READ)
				error = FileAccess.get_open_error()
				if error != OK:
					Log.error("FolderZipper: Extract: Cannot open file %s. Error: %s" % [current_full_path, error_string(error)])
					close()
					return error
				if file:
					write_file(file.get_buffer(file.get_length()))
					file.close()
					close_file()
				else:
					close()
					return FileAccess.get_open_error() # Should never happen because error = OK
		
		file_name = dir.get_next()
	dir.list_dir_end()
	return OK


func compress(path: String, output_name: String) -> void:
	Log.trace("FolderZipper: Compressing %s into %s" % [path, output_name])
	var err: Error = open(output_name, ZIPPacker.APPEND_CREATE)
	if err != OK:
		Log.error("FolderZipper: Error " + error_string(err) + " while opening archive: %s" % output_name)
		close()
		return
	path = path.simplify_path()
	err = write_folder_recursive(path.get_base_dir(), path.get_file())
	if err != OK:
		Log.error("FolderZipper: Error " + error_string(err) + " while compressing folder: %s" % path)
	close()
	Log.trace("FolderZipper: Compression completed -> %s" % output_name)
