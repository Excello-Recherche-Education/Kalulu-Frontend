extends Control
class_name PackageDownloader

const main_menu_scene_path: String = "res://sources/menus/main/main_menu.tscn"
const device_selection_scene_path: String = "res://sources/menus/device_selection/device_selection.tscn"
const login_scene_path: String = "res://sources/menus/login/login.tscn"
const user_language_resources_path: String = "user://language_resources"

const error_messages: Array[String] = [
	"DISCONECTED_ERROR",
	"NO_INTERNET_ACCESS",
	"ERROR_DOWNLOADING"
]


@onready var http_request: HTTPRequest = $HTTPRequest
@onready var checking_label: Label = %CheckingLabel
@onready var download_label: Label = %DownloadLabel
@onready var copy_label: Label = %CopyLabel
@onready var download_bar: ProgressBar = %DownloadProgressBar
@onready var download_info: Label = %DownloadInfo
@onready var extract_bar: ProgressBar = %ExtractProgressBar
@onready var extract_info: Label = %ExtractInfo
@onready var error_label: Label = %ErrorLabel
@onready var error_popup: ConfirmPopup = $ErrorPopup

var device_language: String
var current_language_path: String
var mutex: Mutex
var thread: Thread

var server_version: Dictionary

func _ready() -> void:
	await get_tree().process_frame
	
	# Check the teacher settings, if we are logged in (this scene should not be accessible otherwise)
	var teacher_settings: TeacherSettings = UserDataManager.teacher_settings
	if not teacher_settings:
		UserDataManager.logout()
		_show_error(0)
		return
	
	device_language = UserDataManager.get_device_settings().language
	current_language_path = user_language_resources_path.path_join(device_language)
	
	if not await ServerManager.check_internet_access():
		# Offline mode, if a pack is already downloaded, go to next scene
		if DirAccess.dir_exists_absolute(current_language_path) && is_language_directory_valid(current_language_path):
			_go_to_next_scene()
		else:
			_show_error(1)
		return
	
	# Check the configuration
	var server_configuration: = await ServerManager.get_configuration()
	if server_configuration.code == 401:
		UserDataManager.logout()
		_show_error(0)
		return
	elif server_configuration.code != 200:
		UserDataManager.logout()
		_show_error(2)
		return
	
	# Check if the last_updated date is superior on the server, then update the configuration
	UserDataManager.update_configuration(server_configuration.body as Dictionary)
	
	# Get the current language version
	var current_version: Dictionary = UserDataManager.get_device_settings().language_versions.get(device_language, {})
	
	# Gets the info of the language pack on the server
	var res: = await ServerManager.get_language_pack_url(device_language)
	if res.code == 200:
		server_version = Time.get_datetime_dict_from_datetime_string(res.body.last_modified as String, false)
	# Authentication failed, disconnect the user
	elif res.code == 401:
		UserDataManager.logout()
		_show_error(0)
		return
	else:
		UserDataManager.logout()
		_show_error(2)
		return
	
	# If the language pack is not already downloaded or an update is needed
	if not DirAccess.dir_exists_absolute(current_language_path) or current_version != server_version:
		
		checking_label.hide()
		download_label.show()
		download_bar.show()
		download_info.show()
		extract_bar.show()
		extract_info.show()
		
		# Create the language_resources folder
		if not DirAccess.dir_exists_absolute(user_language_resources_path):
			DirAccess.make_dir_recursive_absolute(user_language_resources_path)
			
		# Delete the files from old language pack
		if DirAccess.dir_exists_absolute(current_language_path):
			_delete_dir(current_language_path)
		
		# Download the pack
		http_request.set_download_file(user_language_resources_path.path_join(device_language + ".zip"))
		http_request.request(res.body.url as String)
	else:
		download_bar.value = 1
		extract_bar.value = 1
		_go_to_next_scene()


# Check that folder is not empty and contains a file language.db
func is_language_directory_valid(path: String) -> bool:
	var dir: DirAccess = DirAccess.open(path)
	if not dir:
		return false

	if dir.list_dir_begin() != OK:
		return false

	var file_name: String = dir.get_next()
	dir.list_dir_end()

	return file_name != "" && dir.file_exists(current_language_path + "language.db")


func _process(_delta: float) -> void:
	if http_request.get_body_size() > 0:
		@warning_ignore("integer_division")
		var maximum: int = int(http_request.get_body_size()/1024)
		@warning_ignore("integer_division")
		var current: int = int(http_request.get_downloaded_bytes()/1024)
		download_bar.max_value = maximum
		download_bar.value = current
		download_info.text = str(current) + "KB/" + str(maximum) + "KB"


func _exit_tree() -> void:
	if thread:
		thread.wait_to_finish()


func _copy_data(this: PackageDownloader) -> void:
	# Check if a zip exists for the complete locale
	if not FileAccess.file_exists(user_language_resources_path.path_join(device_language + ".zip")):
		return
	
	var language_zip: String = device_language + ".zip"
	var language_zip_path: String = user_language_resources_path.path_join(language_zip)
	
	# Create and connect the unzipper to the UI
	var unzipper: FolderUnzipper = FolderUnzipper.new()
	unzipper.file_count.connect(
		func(count: int) -> void:
			mutex.lock()
			this.extract_bar.set_deferred("max_value", count)
			mutex.unlock()
	)
	unzipper.file_copied.connect(
		func(count: int, filename: String) -> void:
			mutex.lock()
			this.extract_info.set_deferred("text", filename)
			this.extract_bar.set_deferred("value", count)
			mutex.unlock()
	)
	
	# Cleanup previous files
	delete_directory_recursive(ProjectSettings.globalize_path(current_language_path))
	
	# Extract the archive
	var subfolder: String = unzipper.extract(language_zip_path, user_language_resources_path, false)
	
	# Move the data to the locale folder of the user
	var error: Error = DirAccess.rename_absolute(user_language_resources_path.path_join(subfolder), current_language_path)
	if error != null:
		printerr("Error " + str(error) + " while renaming folder from %s to %s" % [user_language_resources_path.path_join(subfolder), current_language_path])
	
	# Cleanup unnecessary files
	DirAccess.remove_absolute(language_zip_path)
	
	# Go to main menu
	this.call_thread_safe("_go_to_next_scene")


func delete_directory_recursive(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		printerr("Le dossier n'existe pas : ", path)
		return

	if dir.list_dir_begin() != OK:
		printerr("Erreur lors de la lecture du dossier : ", path)
		return

	var err: Error
	var file_name: String = dir.get_next()
	while file_name != "":
		var full_path: String = path.path_join(file_name)
		if dir.current_is_dir():
			delete_directory_recursive(full_path)
		else:
			err = dir.remove(full_path)
			if err != OK:
				printerr("Erreur " + str(err) + " pendant la suppression du fichier : ", full_path)
		file_name = dir.get_next()

	dir.list_dir_end()

	# Supprime le dossier lui-même
	err = DirAccess.remove_absolute(path)
	if err != OK:
		printerr("Erreur " + str(err) + " pendant la suppression du dossier : ", path)
	else:
		print("✅ Dossier supprimé : ", path)



func _delete_dir(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	for file in dir.get_files():
		dir.remove(file)
	for subfolder in dir.get_directories():
		_delete_dir(path.path_join(subfolder))
		dir.remove(subfolder)


func _show_error(error: int) -> void:
	error_popup.content_text = error_messages[error]
	error_popup.show()
	

func _go_to_main_menu() -> void:
	get_tree().change_scene_to_file(main_menu_scene_path)


func _go_to_next_scene() -> void:
	if not Database.is_open:
		Database.connect_to_db()
	UserDataManager.set_language_version(device_language, server_version)
	
	# Check if we have a valid device id
	if not UserDataManager.get_device_settings().device_id:
		get_tree().change_scene_to_file(device_selection_scene_path)
	# Go directly to the login scene
	else:
		get_tree().change_scene_to_file(login_scene_path)


func _on_http_request_request_completed(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if response_code == 200:
		mutex = Mutex.new()
		thread = Thread.new()
		download_label.hide()
		copy_label.show()
		
		thread.start(_copy_data.bind(self))
	else:
		error_label.show()


func _on_disconnected_popup_accepted() -> void:
	_go_to_main_menu()
