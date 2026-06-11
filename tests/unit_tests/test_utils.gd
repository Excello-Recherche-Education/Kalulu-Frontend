extends GutTest

const TEST_ROOT: String = "user://test_clean_dir"


func after_each() -> void:
	_force_delete_directory(TEST_ROOT)


func test_delete_directory_recursive_removes_hidden_files() -> void:
	# Regression test: the macOS Finder drops .DS_Store files in browsed
	# folders; deletion used to fail silently on them, breaking the
	# language pack swap in PackageDownloader
	_create_file(TEST_ROOT.path_join("visible.txt"))
	_create_file(TEST_ROOT.path_join(".hidden"))
	_create_file(TEST_ROOT.path_join("sub").path_join(".hidden_nested"))

	Utils.delete_directory_recursive(TEST_ROOT)

	assert_false(DirAccess.dir_exists_absolute(TEST_ROOT), "directory with hidden files should be fully deleted")


func test_clean_dir_keeps_root_and_removes_all_content() -> void:
	_create_file(TEST_ROOT.path_join("visible.txt"))
	_create_file(TEST_ROOT.path_join("sub").path_join("nested.txt"))

	var error: Error = Utils.clean_dir(TEST_ROOT)

	assert_eq(error, OK)
	assert_true(DirAccess.dir_exists_absolute(TEST_ROOT), "root directory should be kept")
	var dir: DirAccess = DirAccess.open(TEST_ROOT)
	dir.include_hidden = true
	assert_eq(dir.get_files().size(), 0, "all files should be removed")
	assert_eq(dir.get_directories().size(), 0, "all subdirectories should be removed")


func test_clean_dir_returns_error_on_missing_directory() -> void:
	var error: Error = Utils.clean_dir("user://test_clean_dir_does_not_exist")

	assert_ne(error, OK)


func _create_file(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "test setup should be able to create %s" % path)
	file.store_string("test")
	file.close()


# Cleanup helper independent from the code under test
func _force_delete_directory(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	dir.include_hidden = true
	for file: String in dir.get_files():
		dir.remove(file)
	for subfolder: String in dir.get_directories():
		_force_delete_directory(path.path_join(subfolder))
	DirAccess.remove_absolute(path)
