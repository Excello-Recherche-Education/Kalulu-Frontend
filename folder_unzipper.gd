extends ZIPReader
class_name FolderUnzipper


func extract(path: String, extract_in_subfolder: = true) -> void:
	open(path)
	var extract_folder: = path.get_basename() if extract_in_subfolder else path.get_base_dir()
	for sub_path in get_files():
		var file_name: = extract_folder.path_join(sub_path)
		var folder_name: = file_name.get_base_dir()
		if not DirAccess.dir_exists_absolute(folder_name):
			DirAccess.make_dir_recursive_absolute(folder_name)
		var file: = FileAccess.open(file_name, FileAccess.WRITE)
		file.store_buffer(read_file(sub_path))
	close()
