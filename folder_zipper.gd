extends ZIPPacker
class_name FolderZipper


func write_folder_recursive(abs_path: String, rel_path: String) -> Error:
	var dir = DirAccess.open(abs_path + "/" + rel_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				var error: = write_folder_recursive(abs_path, rel_path + "/" + file_name)
				if error != OK:
					return error
			else:
				var error: = start_file(rel_path + "/" + file_name)
				if error != OK:
					return error
				var file: = FileAccess.open(abs_path + "/" + rel_path + "/" + file_name, FileAccess.READ)
				write_file(file.get_buffer(file.get_length()))
			file_name = dir.get_next()
	else:
		return DirAccess.get_open_error()
	return OK
