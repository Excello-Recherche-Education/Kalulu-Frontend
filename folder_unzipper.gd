class_name FolderUnzipper
extends ZIPReader

signal file_count(count: int)
signal file_copied(count: int, name: String)
signal finished()


func _is_directory_path(path: String) -> bool:
	return path.ends_with("/")


func extract(zip_path: String, extract_path: String, extract_in_subfolder: bool = true) -> String:
	Log.trace("FolderUnzipper: Extracting %s to %s" % [zip_path, extract_path])
	var err: Error = open(zip_path)
	if err != OK:
		Log.error("FolderUnzipper: Error %s while opening %s" % [error_string(err), zip_path])
		close()
		return ""
	
	var extract_folder: String = extract_path.path_join(zip_path.get_file().get_basename()) if extract_in_subfolder else extract_path
	
	var all_files: PackedStringArray = get_files()
	file_count.emit(all_files.size())
	Log.trace("FolderUnzipper: %d files found" % all_files.size())
	
	var copied_file: int = 0
	var first_folder: String = ""
	var last_sub_path: String = ""
	
	for sub_path: String in all_files:
		last_sub_path = sub_path
		if _is_directory_path(sub_path):
			first_folder = sub_path.trim_suffix("/")
			break
	
	if not first_folder and last_sub_path != "":
		first_folder = last_sub_path.split("/")[0]
	
	for sub_path: String in all_files:
		if _is_directory_path(sub_path):
			continue
		
		var file_name: String = extract_folder.path_join(sub_path)
		file_name = Utils.get_safe_file_path(file_name)
		
		var folder_name: String = file_name.get_base_dir()
		if not DirAccess.dir_exists_absolute(folder_name):
			var mkdir_err: Error = DirAccess.make_dir_recursive_absolute(folder_name)
			if mkdir_err != OK:
				Log.error("FolderUnzipper: Cannot create directory %s. Error: %s" % [folder_name, error_string(mkdir_err)])
				continue
		
		var file: FileAccess = FileAccess.open(file_name, FileAccess.WRITE)
		var error: Error = FileAccess.get_open_error()
		
		if error != OK or file == null:
			Log.error("FolderUnzipper: Extract: Cannot open file %s. Error: %s" % [file_name, error_string(error)])
			continue
		
		var data: PackedByteArray = read_file(sub_path)
		if typeof(data) != TYPE_PACKED_BYTE_ARRAY or data.is_empty():
			Log.warn("FolderUnzipper: Empty or invalid data for %s" % sub_path)
			file.close()
			continue
		
		file.store_buffer(data)
		file.close()
		
		Log.trace("FolderUnzipper: Copied %s" % file_name)
		copied_file += 1
		file_copied.emit(copied_file, file_name)
	
	close()
	finished.emit()
	Log.trace("FolderUnzipper: Extraction finished in %s" % extract_folder)
	return first_folder
