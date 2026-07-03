extends GutTest

# Regression tests for Database.close(). A stale open SQLite handle on
# user://language_resources/<lang>/language.db used to prevent the folder from
# being deleted on Windows, breaking both the startup purge
# (UserDataManager.purge_user_folders_if_needed) and the language pack swap
# (PackageDownloader._copy_data).

const TEST_DIR: String = "user://test_database_close"
const TEST_DB: String = TEST_DIR + "/language.db"

var _saved_path: String
var _saved_is_open: bool


func before_each() -> void:
	# Preserve the autoload state so mutating it here cannot leak into other tests
	_saved_path = Database.db.path
	_saved_is_open = Database.is_open
	Database.close()

	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	# Create a real, valid SQLite file to open
	var seed_db: SQLite = SQLite.new()
	seed_db.path = TEST_DB
	seed_db.open_db()
	seed_db.close_db()


func after_each() -> void:
	Database.close()
	_force_delete_directory(TEST_DIR)
	# Restore the previous connection so the suite continues on a clean state
	Database.db.path = _saved_path
	if _saved_is_open:
		Database.connect_to_db()


func test_close_marks_the_database_as_closed() -> void:
	Database.db.path = TEST_DB
	Database.connect_to_db()
	assert_true(Database.is_open, "database should be open after connect_to_db")

	Database.close()

	assert_false(Database.is_open, "close() should mark the database as closed")


func test_close_is_idempotent_when_not_open() -> void:
	Database.db.path = TEST_DB
	Database.connect_to_db()
	Database.close()

	# Calling close() again must be a safe no-op, never crash
	Database.close()

	assert_false(Database.is_open, "close() should stay a no-op when already closed")


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
