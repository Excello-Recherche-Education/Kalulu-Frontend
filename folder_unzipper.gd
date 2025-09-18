class_name FolderUnzipper
extends ZIPReader

signal file_count(count: int)
signal file_copied(count: int, name: String)
signal finished()


func guess_path_type(path: String) -> String:
	if path.ends_with("/"):
		return "directory"
	elif "." in path.get_file():
		return "file"
	else:
		return "directory"


func extract(zip_path: String, extract_path: String, extract_in_subfolder: bool = true) -> String:
	Log.trace("FolderUnzipper: Extracting %s to %s" % [zip_path, extract_path])
	var err: Error = open(zip_path)
	if err != OK:
		Log.error("FolderUnzipper: Error " + error_string(err) + " while opening file: %s" % zip_path)
		close()
		return ""
	var extract_folder: String = extract_path.path_join(zip_path.get_file().get_basename()) if extract_in_subfolder else extract_path
	
	var all_files: PackedStringArray = get_files()
	file_count.emit(all_files.size())
	Log.trace("FolderUnzipper: %d files found" % all_files.size())
	
	var copied_file: int = 0
	var first_folder: String = ""
	for sub_path: String in all_files:
		if not first_folder:
			first_folder = sub_path.split("/")[0]
		var file_name: String = extract_folder.path_join(sub_path)
		var folder_name: String = file_name.get_base_dir()
		if not DirAccess.dir_exists_absolute(folder_name):
			DirAccess.make_dir_recursive_absolute(folder_name)
		if guess_path_type(file_name) == "directory":
			continue
		var file: FileAccess = FileAccess.open(file_name, FileAccess.WRITE)
		var error: Error = FileAccess.get_open_error()
		if error != OK:
			Log.error("FolderUnzipper: Extract: Cannot open file %s. Error: %s" % [file_name, error_string(error)])
			close()
			return first_folder
		if file == null:
			Log.error("FolderUnzipper: Extract: Cannot open file %s. File is null" % file_name)
			close()
			return first_folder
		if file != null:
			file.store_buffer(read_file(sub_path))
			file.close()
		Log.trace("FolderUnzipper: Copied %s" % file_name)
		copied_file += 1
		file_copied.emit(copied_file, file_name)
	
	close()
	finished.emit()
	Log.trace("FolderUnzipper: Extraction finished in %s" % extract_folder)
	return first_folder
