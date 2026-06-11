class_name PackageDownloader
extends Control

enum DownloadError {
	DISCONNECTED,
	NO_INTERNET,
	DOWNLOAD_FAILED,
	INVALID_LOCAL_PACK,
	EXTRACTION_FAILED,
	INVALID_PACKAGE,
	REPLACE_FAILED,
}

const MAIN_MENU_SCENE_PATH: String = "res://sources/menus/main/main_menu.tscn"
const DEVICE_SELECTION_SCENE_PATH: String = "res://sources/menus/device_selection/device_selection.tscn"
const LOGIN_SCENE_PATH: String = "res://sources/menus/login/login.tscn"
const USER_LANGUAGE_RESOURCES_PATH: String = "user://language_resources"
# Translation key shown in the error popup for each DownloadError value
const ERROR_MESSAGES: Array[String] = [
	"DISCONNECTED_ERROR",
	"NO_INTERNET_ACCESS",
	"ERROR_DOWNLOADING",
	"INVALID_LANGUAGE_DIRECTORY",
	"ERROR_EXTRACTING_PACKAGE",
	"ERROR_INVALID_PACKAGE",
	"ERROR_REPLACING_PACKAGE",
]

var language: String
var current_language_path: String
var mutex: Mutex
var thread: Thread
var server_language_version: Dictionary = {}
var current_language_version: Dictionary = {}

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


func _ready() -> void:
	await get_tree().process_frame
	
	language = UserDataManager.get_device_settings().language
	Log.trace("PackageDownloader: Starting with device language %s" % language)
	
	# Check the teacher settings, if we are logged in (this scene should not be accessible otherwise)
	var teacher_settings: TeacherSettings = UserDataManager.teacher_settings
	if not teacher_settings:
		UserDataManager.logout()
		_show_error(DownloadError.DISCONNECTED)
		return
	
	if teacher_settings.server_language_validated:
		language = teacher_settings.language
		Log.trace("PackageDownloader: Using language from teacherSettings: %s" % language)
	current_language_path = USER_LANGUAGE_RESOURCES_PATH.path_join(language)
	current_language_version = UserDataManager.get_device_settings().language_versions.get(language, {})
	
	Log.trace("PackageDownloader: Checking internet access")
	if not await ServerManager.check_internet_access():
		# Offline mode, if a pack is already downloaded, go to next scene
		if DirAccess.dir_exists_absolute(current_language_path):
			if is_language_directory_valid(current_language_path):
				Log.trace("PackageDownloader: Offline but valid language directory found at %s" % current_language_path)
				_go_to_next_scene()
			else:
				Log.warn("PackageDownloader: Offline and language directory %s is invalid" % current_language_path)
				_show_error(DownloadError.INVALID_LOCAL_PACK)
		else:
			Log.warn("PackageDownloader: Offline with no language directory available")
			_show_error(DownloadError.NO_INTERNET)
		return
	
	# Gets the info of the language pack on the server
	var res: Dictionary = await ServerManager.get_language_pack_url(language)
	Log.trace("PackageDownloader: Language pack info received with code %d" % res.code)
	if res.code == 200:
		server_language_version = Time.get_datetime_dict_from_datetime_string(res.body.last_modified as String, false)
		Log.trace("PackageDownloader: Server language version parsed as %s" % str(server_language_version))
	# Authentication failed, disconnect the user
	elif res.code == 401:
		UserDataManager.logout()
		Log.warn("PackageDownloader: Authentication failed while fetching language pack URL")
		_show_error(DownloadError.DISCONNECTED)
		return
	else:
		UserDataManager.logout()
		Log.warn("PackageDownloader: Unexpected response %d while fetching language pack URL" % res.code)
		_show_error(DownloadError.DOWNLOAD_FAILED)
		return
	
	# If the language pack is not already downloaded or an update is needed
	if not DirAccess.dir_exists_absolute(current_language_path) or current_language_version != server_language_version:
		Log.trace("PackageDownloader: A new version of the language pack has been detected.\n    Current version = " + str(current_language_version) + "\n    Server version = " + str(server_language_version))
		
		checking_label.hide()
		download_label.show()
		download_bar.show()
		download_info.show()
		extract_bar.show()
		extract_info.show()
		
		# Create the language_resources folder
		if not DirAccess.dir_exists_absolute(USER_LANGUAGE_RESOURCES_PATH):
			DirAccess.make_dir_recursive_absolute(USER_LANGUAGE_RESOURCES_PATH)

		# Download the pack. The previous pack is kept on disk so the app can
		# still run offline if the download fails; it is only removed during
		# extraction, once the new pack has been fully downloaded.
		http_request.set_download_file(USER_LANGUAGE_RESOURCES_PATH.path_join(language + ".zip"))
		Log.trace("PackageDownloader: Downloading pack from %s" % res.body.url)
		var request_error: Error = http_request.request(res.body.url as String)
		if request_error != OK:
			Log.error("PackageDownloader: Cannot start language pack download: %s" % error_string(request_error))
			_show_error(DownloadError.DOWNLOAD_FAILED)
	else:
		download_bar.value = 1
		extract_bar.value = 1
		Log.trace("PackageDownloader: Language pack already up to date, moving to next scene")
		_go_to_next_scene()


# Check that folder is not empty and contains a file language.db
func is_language_directory_valid(path: String) -> bool:
	var dir: DirAccess = DirAccess.open(path)
	var error: Error = DirAccess.get_open_error()
	if error != OK:
		Log.error("PackageDownloader: Is language directory valid: Cannot open directory %s. Error: %s" % [path, error_string(error)])
		return false
	if not dir:
		Log.error("PackageDownloader: Is language directory valid: Cannot open directory %s. dir is null" % path)
		return false
	
	if dir.list_dir_begin() != OK:
		dir.list_dir_end()
		return false
	
	var file_name: String = dir.get_next()
	dir.list_dir_end()
	return file_name != "" and dir.file_exists("language.db")


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
	if not FileAccess.file_exists(USER_LANGUAGE_RESOURCES_PATH.path_join(language + ".zip")):
		Log.warn("PackageDownloader: No downloaded archive found for %s" % language)
		this.call_thread_safe("_show_error", DownloadError.EXTRACTION_FAILED)
		return
	
	Log.trace("PackageDownloader: Extracting downloaded package")
	
	var language_zip: String = language + ".zip"
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
	
	# Extract to a temporary directory so the current pack stays usable if
	# the extraction fails or is interrupted
	var temp_extract_path: String = USER_LANGUAGE_RESOURCES_PATH.path_join(language + "_tmp")
	if DirAccess.dir_exists_absolute(temp_extract_path):
		Utils.delete_directory_recursive(ProjectSettings.globalize_path(temp_extract_path))

	var subfolder: String = unzipper.extract(language_zip_path, temp_extract_path, false)
	if subfolder == "":
		Log.error("PackageDownloader: Extraction failed for %s" % language_zip_path)
		this.call_thread_safe("_show_error", DownloadError.EXTRACTION_FAILED)
		return

	# Check the new pack before replacing the current one
	var new_pack_path: String = temp_extract_path.path_join(subfolder)
	if not is_language_directory_valid(new_pack_path):
		Log.error("PackageDownloader: Extracted package at %s is invalid, keeping the current language pack" % new_pack_path)
		Utils.delete_directory_recursive(ProjectSettings.globalize_path(temp_extract_path))
		DirAccess.remove_absolute(language_zip_path)
		this.call_thread_safe("_show_error", DownloadError.INVALID_PACKAGE)
		return

	# Replace the previous pack, now that the new one is fully extracted
	if DirAccess.dir_exists_absolute(current_language_path):
		Log.trace("PackageDownloader: Removing previous language directory")
		Utils.delete_directory_recursive(ProjectSettings.globalize_path(current_language_path))
		if DirAccess.dir_exists_absolute(current_language_path):
			# Keep the temporary directory so the new pack is not lost
			Log.error("PackageDownloader: Cannot remove the previous language directory, aborting swap")
			this.call_thread_safe("_show_error", DownloadError.REPLACE_FAILED)
			return

	var error: Error = DirAccess.rename_absolute(new_pack_path, current_language_path)
	if error != OK:
		# Keep the temporary directory so the data is not lost; the next
		# launch will detect the missing pack and download it again
		Log.error("PackageDownloader: Error " + error_string(error) + " while renaming folder from %s to %s" % [new_pack_path, current_language_path])
		this.call_thread_safe("_show_error", DownloadError.REPLACE_FAILED)
		return
	Log.trace("PackageDownloader: Package extracted to %s" % current_language_path)

	# Cleanup unnecessary files
	Utils.delete_directory_recursive(ProjectSettings.globalize_path(temp_extract_path))
	DirAccess.remove_absolute(language_zip_path)
	Log.trace("PackageDownloader: Removed temporary archive %s" % language_zip_path)

	# Go to main menu
	this.call_thread_safe("_go_to_next_scene")


func _show_error(error: DownloadError) -> void:
	Log.warn("PackageDownloader: Displaying error %d (%s)" % [error, ERROR_MESSAGES[error]])
	error_popup.content_text = ERROR_MESSAGES[error]
	error_popup.show()


func _go_to_main_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _go_to_next_scene() -> void:
	if not Database.is_open:
		Database.connect_to_db()
	
	if not server_language_version.is_empty():
		UserDataManager.set_language_version(language, server_language_version)
	
	# Check if we have a valid device id
	if not UserDataManager.get_device_settings().device_id:
		Log.trace("PackageDownloader: No device id found, going to device selection")
		get_tree().change_scene_to_file(DEVICE_SELECTION_SCENE_PATH)
	# Go directly to the login scene
	else:
		Log.trace("PackageDownloader: Device id found, going to login scene")
		get_tree().change_scene_to_file(LOGIN_SCENE_PATH)


func _on_http_request_request_completed(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	Log.trace("PackageDownloader: Download completed with HTTP code %d" % response_code)
	if response_code == 200:
		mutex = Mutex.new()
		thread = Thread.new()
		download_label.hide()
		copy_label.show()
		Log.trace("PackageDownloader: Starting extraction thread")
		thread.start(_copy_data.bind(self))
	else:
		Log.warn("PackageDownloader: Download failed with HTTP code %d" % response_code)
		error_label.show()


func _on_disconnected_popup_accepted() -> void:
	_go_to_main_menu()
