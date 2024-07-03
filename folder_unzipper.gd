extends ZIPReader
class_name FolderUnzipper

signal file_count(count: int)
signal file_copied(count: int, name: String)
signal finished()

func extract(zip_path: String, extract_path: String, extract_in_subfolder: = true) -> void:
	open(zip_path)
	var extract_folder: = extract_path.path_join(zip_path.get_file().get_basename()) if extract_in_subfolder else extract_path
	
	var all_files: = get_files()
	file_count.emit(all_files.size())
	
	var copied_file: = 0
	for sub_path in all_files:
		var file_name: = extract_folder.path_join(sub_path)
		var folder_name: = file_name.get_base_dir()
		if not DirAccess.dir_exists_absolute(folder_name):
			DirAccess.make_dir_recursive_absolute(folder_name)
		var file: = FileAccess.open(file_name, FileAccess.WRITE)
		if file != null:
			file.store_buffer(read_file(sub_path))
		copied_file += 1
		file_copied.emit(copied_file, file_name)
	close()
	finished.emit()
