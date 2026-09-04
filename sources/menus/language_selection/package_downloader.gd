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
	KALULU_BLOCKED,
}

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
	"DOWNLOAD_KALULU_BLOCKED",
]

## What to do about the server's answer for the language pack URL.
enum PackUrlOutcome {
	USE,       ## The answer carries a URL to download from.
	SIGN_OUT,  ## The server rejected the token.
	OFFLINE,   ## Nothing answered, so carry on with what is on disk.
	FAILED,    ## The server answered something unusable.
}

var language: String
var current_language_path: String
var mutex: Mutex
var thread: Thread
var server_language_version: Dictionary = {}
var current_language_version: Dictionary = {}
# What the internet probe found this attempt. A network that blocks Kalulu while
# leaving the rest of the internet alone gets past the probe and only fails at the
# API, so the probe's answer is half of the diagnosis and has to outlive it.
var internet_reachable: bool = false

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
	_start()


## Checks the pack and downloads it if need be.
##
## Separate from _ready so a failure can be tried again without leaving the
## screen -- which for a device with no usable pack is the only recoverable
## place to be.
func _start() -> void:
	# This screen is reached with the curtain in either state, so it raises it
	# itself rather than trusting whoever sent it here. A device that is already
	# signed in comes from the splash, which never lowered it; a teacher who has
	# just typed their password comes from the welcome screen, which lowers it
	# before leaving and has nothing on the way here to raise it again. Without
	# this the download, the extraction and every error popup happen behind a
	# closed curtain, and a pack that takes a minute to install looks like a
	# freeze. Started rather than awaited: the check below has no reason to wait
	# on an animation, and a pack that is already up to date hands over while the
	# curtain is still rising, which is what the signed-in path already does.
	OpeningCurtain.open()
	
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
	internet_reachable = await ServerManager.check_internet_access()
	if not internet_reachable:
		_continue_without_the_server(_no_server_error())
		return
	
	# Gets the info of the language pack on the server
	var res: Dictionary = await ServerManager.get_language_pack_url(language)
	Log.trace("PackageDownloader: Language pack info received with code %d" % res.code)
	match outcome_for_pack_url(res.code as int):
		PackUrlOutcome.USE:
			server_language_version = Time.get_datetime_dict_from_datetime_string(res.body.last_modified as String, false)
			Log.trace("PackageDownloader: Server language version parsed as %s" % str(server_language_version))
		PackUrlOutcome.SIGN_OUT:
			UserDataManager.logout()
			Log.warn("PackageDownloader: Authentication failed while fetching language pack URL")
			_show_error(DownloadError.DISCONNECTED)
			return
		PackUrlOutcome.OFFLINE:
			Log.warn("PackageDownloader: No answer from the server while fetching the language pack URL")
			_continue_without_the_server(_no_server_error())
			return
		_:
			Log.warn("PackageDownloader: Unusable response %d while fetching language pack URL" % res.code)
			_continue_without_the_server(DownloadError.DOWNLOAD_FAILED)
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


## What the answer for the language pack URL means, given its HTTP code.
##
## Extracted so all four answers can be checked without a server, and so the two that
## used to be wrong stay frozen. Both signed the device out, and logout() clears the
## token from disk: a device could then not be signed back in from the network it was
## on, which put the pack already installed out of reach with it.
##
## Only 401 is about the account. The backend says so itself -- core/auth.py catches
## nothing around its database call on purpose, "so an outage must surface as a 500,
## not be mistaken for an invalid token" -- and this end was undoing that by treating
## the 500 as a rejected token anyway. Code 0 is not even an answer: no HTTP response
## came back at all, which is the network, and is what a school firewall produces.
static func outcome_for_pack_url(code: int) -> PackUrlOutcome:
	if code == 200:
		return PackUrlOutcome.USE
	if code == 401:
		return PackUrlOutcome.SIGN_OUT
	if code == 0:
		return PackUrlOutcome.OFFLINE
	return PackUrlOutcome.FAILED


## Carries on with what is on disk, the server's answer being unusable.
##
## Reached from three failures -- no internet, no answer, and an answer that is not a
## pack URL -- because they have the same consequence here: the pack cannot be checked
## for an update, so the installed one is all there is. A device that already has a
## usable pack does not care which of the three it was, and none of them is a reason
## to strand it.
##
## `no_pack_error` is what to report when there is nothing installed to fall back on,
## and it is the one thing the three do not share: a network story for the first two,
## the server's own for the third.
func _continue_without_the_server(no_pack_error: DownloadError) -> void:
	if DirAccess.dir_exists_absolute(current_language_path):
		if is_language_directory_valid(current_language_path):
			Log.trace("PackageDownloader: No server, but a valid language directory is installed at %s" % current_language_path)
			_go_to_next_scene()
		else:
			Log.warn("PackageDownloader: No server and language directory %s is invalid" % current_language_path)
			_show_error(DownloadError.INVALID_LOCAL_PACK)
		return
	Log.warn("PackageDownloader: No server and no language directory to fall back on")
	_show_error(no_pack_error)


## Which of the two no-server errors this is, so the popup can say something true.
##
## "You are not connected to the internet" is the wrong instruction for a device that
## is online and being filtered: it sends the adult to the router, where there is
## nothing to find. ServerManager owns the distinction; this only maps it.
func _no_server_error() -> DownloadError:
	var failure: ServerManagerClass.ConnectionFailure = ServerManagerClass.diagnosis_for(
			internet_reachable,
			(ServerManager as ServerManagerClass).last_internet_result_code)
	Log.info("PackageDownloader: No server, diagnosed %s" % ServerManagerClass.ConnectionFailure.keys()[failure])
	if failure == ServerManagerClass.ConnectionFailure.KALULU_BLOCKED:
		return DownloadError.KALULU_BLOCKED
	return DownloadError.NO_INTERNET


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
	_release_extraction_thread()


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
	if EntryFlow.scene_when_offline().is_empty():
		# Nothing to fall back on: no connection and no usable pack, so there is no
		# screen to send the device to -- the child's access-code screen comes
		# straight back here. Say what is wrong and what would fix it, and make the
		# button another go rather than a way out that does not exist.
		if error == DownloadError.KALULU_BLOCKED:
			# The generic notice asks for an internet connection this device already
			# has, so it would read as nonsense and point at the wrong thing to fix.
			error_popup.title_text = "KALULU_BLOCKED_TITLE"
			error_popup.content_text = "DOWNLOAD_KALULU_BLOCKED"
		elif error == DownloadError.DOWNLOAD_FAILED:
			# The server answered, badly. Asking for internet would send the reader
			# looking at a connection that is doing its job.
			error_popup.title_text = "SERVER_UNAVAILABLE_TITLE"
			error_popup.content_text = "NO_LANGUAGE_PACK_SERVER_ERROR"
		else:
			error_popup.title_text = "NO_LANGUAGE_PACK_TITLE"
			error_popup.content_text = "NO_LANGUAGE_PACK_POPUP"
		error_popup.confirm_text_override = "TRY_AGAIN"
		error_popup.acknowledge_only = true
	else:
		# The same dialog is reused for every error, so anything set for the case
		# above has to be put back.
		error_popup.title_text = ""
		error_popup.content_text = ERROR_MESSAGES[error]
		error_popup.confirm_text_override = ""
		error_popup.acknowledge_only = false
	error_popup.show()


func _go_to_offline_scene() -> void:
	var next_scene: String = EntryFlow.scene_when_offline()
	if next_scene.is_empty():
		# Nowhere to go: without a usable pack the child's access-code screen sends
		# the device straight back here, so leaving would bounce between the two
		# screens forever. Stay and try again -- each attempt costs a tap on the
		# error, so it cannot spin on its own.
		Log.warn("PackageDownloader: No usable language pack and nowhere to go; trying again")
		_retry()
		return
	get_tree().change_scene_to_file(next_scene)


## Runs the check again after a failure the user has acknowledged.
func _retry() -> void:
	if thread and thread.is_alive():
		# Starting over on top of a running extraction would have two of them writing
		# the same folder, and waiting for it here would freeze the screen that is
		# drawing its progress. So put the notice back rather than returning to
		# nothing: on a device with no usable pack this is the only way forward, and
		# a dialog that closes onto a dead screen leaves nothing left to press.
		Log.trace("PackageDownloader: Extraction still running, leaving the notice up")
		error_popup.show()
		return
	# The finished worker is joined before its reference can be replaced by the next
	# attempt. The engine warns when a Thread is destroyed without it -- "A Thread
	# object is being destroyed without its completion having been realized" -- and
	# leaks it until the process ends.
	_release_extraction_thread()
	error_label.hide()
	_start()


## Joins the extraction thread, if there is one, and lets go of it.
##
## Costs nothing once the worker has returned, and blocks until it does otherwise --
## which is what leaving the scene needs, since the worker writes to its nodes.
func _release_extraction_thread() -> void:
	if not thread:
		return
	thread.wait_to_finish()
	thread = null


func _go_to_next_scene() -> void:
	if not Database.is_open:
		Database.connect_to_db()
	
	if not server_language_version.is_empty():
		UserDataManager.set_language_version(language, server_language_version)
	
	var next_scene: String = EntryFlow.device_scene()
	Log.trace("PackageDownloader: Handing over to %s" % next_scene)
	get_tree().change_scene_to_file(next_scene)


func _on_http_request_request_completed(result_code: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	# The pack comes from S3, not from api.kalulu.org, so a network can block this
	# leg alone. The result code was being thrown away, which left a download that
	# never got a response looking like an HTTP 0 in the log.
	Log.trace("PackageDownloader: Download completed with result %s and HTTP code %d" % [
			(ServerManager as ServerManagerClass).http_result_name(result_code), response_code])
	if response_code == 200:
		mutex = Mutex.new()
		# Nothing should be holding a worker by now, but this is the one line that
		# replaces the reference, so it is where the invariant is worth stating.
		_release_extraction_thread()
		thread = Thread.new()
		download_label.hide()
		copy_label.show()
		# Close the language database on the main thread before the extraction
		# thread swaps the language_resources folder. On Windows the OS locks
		# open files, so an open language.db would make the removal of the
		# previous pack fail (ERROR_REPLACING_PACKAGE). It is reopened in
		# _go_to_next_scene once the swap is done.
		Database.close()
		Log.trace("PackageDownloader: Starting extraction thread")
		thread.start(_copy_data.bind(self))
	else:
		Log.warn("PackageDownloader: Download failed with HTTP code %d" % response_code)
		error_label.show()


func _on_disconnected_popup_accepted() -> void:
	_go_to_offline_scene()
