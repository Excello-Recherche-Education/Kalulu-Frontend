extends Control
class_name LocalPackageDownloader

const next_scene_path: = "res://sources/menus/main/main_menu.tscn"
const res_language_resources_path: = "res://language_resources"
const user_language_resources_path: =  "user://language_resources"

@onready var progress_bar: ProgressBar = %ProgressBar
@onready var data_label: Label = %DataLabel

var current_language_path: String
var mutex: Mutex
var thread: Thread

func _ready() -> void:
	await get_tree().process_frame
	
	current_language_path = user_language_resources_path.path_join(UserDataManager.get_device_settings().language)
	
	if not DirAccess.dir_exists_absolute(current_language_path):
		mutex = Mutex.new()
		thread = Thread.new()
		if OS.request_permissions():
			thread.start(_copy_data.bind(self))
	else:
		_go_to_main_menu()


func _exit_tree() -> void:
	if thread:
		thread.wait_to_finish()


func _copy_data(this: LocalPackageDownloader) -> void:
	# Find the right language zip
	var language: = UserDataManager.get_device_settings().language
	var language_zip: String
	var language_zip_path: String
	
	# Check if a zip exists for the complete locale
	if FileAccess.file_exists(res_language_resources_path.path_join(language + ".zip")):
		language_zip = language + ".zip"
	# Check if a zip exists for the language
	elif FileAccess.file_exists(res_language_resources_path.path_join(language.split("_")[0] + ".zip")):
		language = language.split("_")[0]
		language_zip = language + ".zip"
	
	if language_zip:
		language_zip_path = res_language_resources_path.path_join(language_zip)
	
	
	# Copy the language archive from res:// to user://
	# On Android, decompressing a zip in res is extremely slow
	if not DirAccess.dir_exists_absolute(user_language_resources_path):
		DirAccess.make_dir_recursive_absolute(user_language_resources_path)
	var source_dir: = DirAccess.open(res_language_resources_path);
	source_dir.copy(language_zip_path, user_language_resources_path.path_join(language_zip))
	
	language_zip_path = user_language_resources_path.path_join(language_zip)
	
	# Create and connect the unzipper to the UI
	var unzipper: = FolderUnzipper.new()
	unzipper.file_count.connect(
		func(count: int) -> void:
			mutex.lock()
			this.progress_bar.set_deferred("max_value", count)
			mutex.unlock()
	)
	unzipper.file_copied.connect(
		func(count: int, filename: String) -> void:
			mutex.lock()
			this.data_label.set_deferred("text", filename)
			this.progress_bar.set_deferred("value", count)
			mutex.unlock()
	)
	
	# Extract the archive
	unzipper.extract(language_zip_path, user_language_resources_path, false)
	
	# Move the data to the locale folder of the user
	DirAccess.rename_absolute(user_language_resources_path.path_join(language), current_language_path)
	
	# Cleanup unnecessary files
	if FileAccess.file_exists(user_language_resources_path.path_join("__MACOSX")):
		DirAccess.remove_absolute(user_language_resources_path.path_join("__MACOSX"))
	DirAccess.remove_absolute(language_zip_path)
	
	# Go to main menu
	this.call_thread_safe("_go_to_main_menu")


func _go_to_main_menu() -> void:
	if not Database.is_open:
		Database.connect_to_db()
	get_tree().change_scene_to_file(next_scene_path)
