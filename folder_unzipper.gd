extends ZIPReader
class_name FolderUnzipper

signal file_count(count: int)
signal file_copied(count: int, name: String)
signal finished()

func extract(zip_path: String, extract_path: String, extract_in_subfolder: bool = true) -> String:
	open(zip_path)
	var extract_folder: String = extract_path.path_join(zip_path.get_file().get_basename()) if extract_in_subfolder else extract_path
	
	var all_files: PackedStringArray = get_files()
	file_count.emit(all_files.size())
	
	var copied_file: int = 0
	var first_folder: String
	for sub_path: String in all_files:
		if not first_folder:
			first_folder = sub_path.split("/")[0]
		var file_name: String = extract_folder.path_join(sub_path)
		var folder_name: String = file_name.get_base_dir()
		if not DirAccess.dir_exists_absolute(folder_name):
			DirAccess.make_dir_recursive_absolute(folder_name)
		var file: FileAccess = FileAccess.open(file_name, FileAccess.WRITE)
		if file != null:
			file.store_buffer(read_file(sub_path))
			file.close()
		copied_file += 1
		file_copied.emit(copied_file, file_name)
	
	close()
	
	finished.emit()
	return first_folder
