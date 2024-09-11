extends Control
class_name LocalPackageDownloader

const next_scene_path: = "res://sources/menus/main/main_menu.tscn"
const user_language_resources_path: =  "user://language_resources"

@onready var http_request: HTTPRequest = $HTTPRequest
@onready var download_label: Label = %DownloadLabel
@onready var copy_label: Label = %CopyLabel
@onready var download_bar: ProgressBar = %DownloadProgressBar
@onready var download_info: Label = %DownloadInfo
@onready var extract_bar: ProgressBar = %ExtractProgressBar
@onready var extract_info: Label = %ExtractInfo
@onready var error_label: Label = %ErrorLabel

var device_language: String
var current_language_path: String
var mutex: Mutex
var thread: Thread

func _ready() -> void:
	await get_tree().process_frame
	
	device_language = UserDataManager.get_device_settings().language
	current_language_path = user_language_resources_path.path_join(device_language)
	
	# If the language pack is not already downloaded 
	if not DirAccess.dir_exists_absolute(current_language_path):
		# Gets the URL of the pack on the server
		var res = await ServerManager.get_language_pack_url(device_language)
		if res.code == 200:
			if not DirAccess.dir_exists_absolute(user_language_resources_path):
				DirAccess.make_dir_recursive_absolute(user_language_resources_path)
				
			# Download the pack
			http_request.set_download_file(user_language_resources_path.path_join(device_language + ".zip"))
			http_request.request(res.body.url)
		else:
			error_label.show()
	else:
		download_bar.value = 1
		extract_bar.value = 1
		_go_to_main_menu()


func _process(delta):
	if http_request.get_body_size() > 0:
		
		var max = int(http_request.get_body_size()/1024)
		var current = int(http_request.get_downloaded_bytes()/1024)
		
		download_bar.max_value = max
		download_bar.value = current
		download_info.text = str(current) + "KB/" + str(max) + "KB"


func _exit_tree() -> void:
	if thread:
		thread.wait_to_finish()


func _copy_data(this: LocalPackageDownloader) -> void:
	# Check if a zip exists for the complete locale
	if not FileAccess.file_exists(user_language_resources_path.path_join(device_language + ".zip")):
		return
	
	var language_zip: String = device_language + ".zip"
	var language_zip_path: String = user_language_resources_path.path_join(language_zip)
	
	# Create and connect the unzipper to the UI
	var unzipper: = FolderUnzipper.new()
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
	
	# Extract the archive
	var subfolder: String = unzipper.extract(language_zip_path, user_language_resources_path, false)
	
	# Move the data to the locale folder of the user
	DirAccess.rename_absolute(user_language_resources_path.path_join(subfolder), current_language_path)
	
	# Cleanup unnecessary files
	DirAccess.remove_absolute(language_zip_path)
	
	# Go to main menu
	this.call_thread_safe("_go_to_main_menu")


func _go_to_main_menu() -> void:
	if not Database.is_open:
		Database.connect_to_db()
	get_tree().change_scene_to_file(next_scene_path)


func _on_http_request_request_completed(result, response_code, headers, body):
	if response_code == 200:
		mutex = Mutex.new()
		thread = Thread.new()
		download_label.hide()
		copy_label.show()
		if OS.request_permissions():
			thread.start(_copy_data.bind(self))
	else:
		error_label.show()
