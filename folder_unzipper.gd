extends ZIPReader
class_name FolderUnzipper


func extract(zip_path: String, extract_path: String, extract_in_subfolder: = true) -> void:
	open(zip_path)
	var extract_folder: = extract_path.path_join(zip_path.get_file().get_basename()) if extract_in_subfolder else extract_path
	for sub_path in get_files():
		var file_name: = extract_folder.path_join(sub_path)
		var folder_name: = file_name.get_base_dir()
		if not DirAccess.dir_exists_absolute(folder_name):
			DirAccess.make_dir_recursive_absolute(folder_name)
		var file: = FileAccess.open(file_name, FileAccess.WRITE)
		if file == null:
			continue
		file.store_buffer(read_file(sub_path))
	close()
