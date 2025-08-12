extends Control
class_name PackageDownloader

const MAIN_MENU_SCENE_PATH: String = "res://sources/menus/main/main_menu.tscn"
const DEVICE_SELECTION_SCENE_PATH: String = "res://sources/menus/device_selection/device_selection.tscn"
const LOGIN_SCENE_PATH: String = "res://sources/menus/login/login.tscn"
const USER_LANGUAGE_RESOURCES_PATH: String = "user://language_resources"

const ERROR_MESSAGES: Array[String] = [
	"DISCONNECTED_ERROR",
	"NO_INTERNET_ACCESS",
	"ERROR_DOWNLOADING",
	"INVALID_LANGUAGE_DIRECTORY",
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

var server_language_version: Dictionary = {}
var current_language_version: Dictionary = {}

func _ready() -> void:
	await get_tree().process_frame
	
	Logger.trace("PackageDownloader: Starting with device language %s" % UserDataManager.get_device_settings().language)
	
	# Check the teacher settings, if we are logged in (this scene should not be accessible otherwise)
	var teacher_settings: TeacherSettings = UserDataManager.teacher_settings
	if not teacher_settings:
		UserDataManager.logout()
		_show_error(0)
		return
	
	device_language = UserDataManager.get_device_settings().language
	current_language_path = USER_LANGUAGE_RESOURCES_PATH.path_join(device_language)
	current_language_version = UserDataManager.get_device_settings().language_versions.get(device_language, {})
	
	Logger.trace("PackageDownloader: Checking internet access")
	if not await ServerManager.check_internet_access():
		# Offline mode, if a pack is already downloaded, go to next scene
		if DirAccess.dir_exists_absolute(current_language_path):
			if is_language_directory_valid(current_language_path):
				_go_to_next_scene()
			else:
				_show_error(3)
		else:
			_show_error(1)
		return
	
	# Gets the info of the language pack on the server
	var res: Dictionary = await ServerManager.get_language_pack_url(device_language)
	Logger.trace("PackageDownloader: Language pack info received with code %d" % res.code)
	if res.code == 200:
		server_language_version = Time.get_datetime_dict_from_datetime_string(res.body.last_modified as String, false)
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
	if not DirAccess.dir_exists_absolute(current_language_path) or current_language_version != server_language_version:
		Logger.trace("A new version of the language pack has been detected.\n    Current version = " + str(current_language_version) + "\n    Server version = " + str(server_language_version))
		
		checking_label.hide()
		download_label.show()
		download_bar.show()
		download_info.show()
		extract_bar.show()
		extract_info.show()
		
		# Create the language_resources folder
		if not DirAccess.dir_exists_absolute(USER_LANGUAGE_RESOURCES_PATH):
			DirAccess.make_dir_recursive_absolute(USER_LANGUAGE_RESOURCES_PATH)
			
		# Delete the files from old language pack
		if DirAccess.dir_exists_absolute(current_language_path):
			Utils.clean_dir(current_language_path)
		
		# Download the pack
		http_request.set_download_file(USER_LANGUAGE_RESOURCES_PATH.path_join(device_language + ".zip"))
		Logger.trace("PackageDownloader: Downloading pack from %s" % res.body.url)
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
		dir.list_dir_end()
		return false

	var file_name: String = dir.get_next()
	dir.list_dir_end()
	return file_name != "" && dir.file_exists("language.db")


func _process(_delta: float) -> void:
	if http_request.get_body_size() > 0:
		var maximum: int = int(http_request.get_body_size()/1024.0)
		var current: int = int(http_request.get_downloaded_bytes()/1024.0)
		download_bar.max_value = maximum
		download_bar.value = current
		download_info.text = str(current) + "KB/" + str(maximum) + "KB"


func _exit_tree() -> void:
	if thread:
		thread.wait_to_finish()


func _copy_data(this: PackageDownloader) -> void:
	# Check if a zip exists for the complete locale
	if not FileAccess.file_exists(USER_LANGUAGE_RESOURCES_PATH.path_join(device_language + ".zip")):
		return
	
	Logger.trace("PackageDownloader: Extracting downloaded package")
	
	var language_zip: String = device_language + ".zip"
	var language_zip_path: String = USER_LANGUAGE_RESOURCES_PATH.path_join(language_zip)
	
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
	Utils.delete_directory_recursive(ProjectSettings.globalize_path(current_language_path))
	
	# Extract the archive
	var subfolder: String = unzipper.extract(language_zip_path, USER_LANGUAGE_RESOURCES_PATH, false)
	if subfolder == "":
		Logger.error("PackageDownloader: Extraction failed for %s" % language_zip_path)
		return
	
	# Move the data to the locale folder of the user
	var error: Error = DirAccess.rename_absolute(USER_LANGUAGE_RESOURCES_PATH.path_join(subfolder), current_language_path)
	if error != OK:
		Logger.error("PackageDownloader: Error " + error_string(error) + " while renaming folder from %s to %s" % [USER_LANGUAGE_RESOURCES_PATH.path_join(subfolder), current_language_path])
	else:
		Logger.trace("PackageDownloader: Package extracted to %s" % current_language_path)
	
	# Cleanup unnecessary files
	DirAccess.remove_absolute(language_zip_path)
	Logger.trace("PackageDownloader: Removed temporary archive %s" % language_zip_path)
	
	# Go to main menu
	this.call_thread_safe("_go_to_next_scene")


func _show_error(error: int) -> void:
	error_popup.content_text = ERROR_MESSAGES[error]
	error_popup.show()
	


func _go_to_main_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _go_to_next_scene() -> void:
	if not Database.is_open:
		Database.connect_to_db()
	
	if not server_language_version.is_empty():
		UserDataManager.set_language_version(device_language, server_language_version)
	
	# Check if we have a valid device id
	if not UserDataManager.get_device_settings().device_id:
		get_tree().change_scene_to_file(DEVICE_SELECTION_SCENE_PATH)
	# Go directly to the login scene
	else:
		get_tree().change_scene_to_file(LOGIN_SCENE_PATH)


func _on_http_request_request_completed(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	Logger.trace("PackageDownloader: Download completed with HTTP code %d" % response_code)
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
