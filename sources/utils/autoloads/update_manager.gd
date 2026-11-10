class_name UpdateManagerClass
extends Node
## Finds out whether a newer Kalulu has been released, and gets it for the reader
## in whatever way this build allows.
##
## The answer comes from Kalulu-Frontend's GitHub releases (see AppRelease for why
## a release only counts once its Pre-release badge is gone). No Kalulu server is
## involved, so a release needs no backend change to be announced, and a device
## with no account -- or on the DEV server -- is told all the same.
##
## What the reader is then offered depends on where the build came from
## (UpdateChannel): a store build opens its store page; a downloaded build fetches
## the release, checks it, and installs it itself where the platform and the
## folder allow, or else opens the download in the browser.
##
## The check runs once per launch at most, a few seconds after start so it does
## not compete with the splash. Its answer is kept for CHECK_INTERVAL_SECONDS: a
## school whose devices share one address shares GitHub's 60 requests an hour,
## and a classroom launching together must not exhaust it.

## A newer release is available, or has stopped being (null).
signal release_changed(release: AppRelease)
## The in-app install moved on. `stage` is one of InstallStage; `fraction` is the
## download's progress, from 0 to 1, or -1 when its size is unknown.
signal install_progressed(stage: InstallStage, fraction: float)
## The in-app install stopped short. `reason` is for the log; the reader is
## offered the browser download instead.
signal install_failed(reason: String)

## What the reader is offered for an available release.
enum Action {
	NONE,
	OPEN_STORE,
	INSTALL_IN_APP,
	OPEN_DOWNLOAD,
}
enum InstallStage {
	DOWNLOADING,
	INSTALLING,
	## The new version is starting; this one is about to quit.
	RESTARTING,
	## Android's installer has been opened and is waiting on the reader.
	SYSTEM_INSTALLER,
}

const CACHE_PATH: String = "user://update_check.cfg"
const DOWNLOAD_DIR: String = "user://updates"
const CHECK_INTERVAL_SECONDS: int = 6 * 3600
## How long to wait before asking again after a check that failed.
const RETRY_INTERVAL_SECONDS: int = 3600
const FIRST_CHECK_DELAY_SECONDS: float = 4.0
const CHECK_TIMEOUT_SECONDS: float = 20.0
## Debug builds only: read the releases from here instead of GitHub, to test the
## whole flow against a local server.
const FEED_OVERRIDE_ENVIRONMENT: String = "KALULU_UPDATE_FEED_URL"

## The newer release, when there is one.
var available: AppRelease = null
var channel: UpdateChannel.Kind = UpdateChannel.Kind.NONE
var is_installing: bool = false
var _check_request: HTTPRequest = null
var _download_request: HTTPRequest = null
var _download_path: String = ""
var _download_asset: Dictionary = {}
var _install_thread: Thread = null
var _installer: UpdateInstaller = null
var _current_version: String = ""


func _ready() -> void:
	_current_version = Utils.get_application_config_version()
	channel = UpdateChannel.current()
	if not is_enabled():
		return
	_installer = UpdateInstaller.for_running_build()
	if UpdateChannel.may_install_itself():
		_installer.remove_leftovers()
	_remove_downloads()
	var cache: ConfigFile = _load_cache()
	_offer(AppRelease.from_dictionary(cache.get_value("release", "data", {}) as Dictionary))
	if not _is_due(cache):
		return
	await get_tree().create_timer(FIRST_CHECK_DELAY_SECONDS).timeout
	check()


## Whether this build looks for updates at all. Not the web build, which is always
## current, and not the editor, unless a test feed is set.
func is_enabled() -> bool:
	if channel == UpdateChannel.Kind.NONE:
		return false
	if OS.has_feature("editor") and _feed_override().is_empty():
		return false
	return true


## Asks GitHub for the releases, unless a check is already under way.
func check() -> void:
	if _check_request or not is_enabled():
		return
	_check_request = HTTPRequest.new()
	_check_request.timeout = CHECK_TIMEOUT_SECONDS
	add_child(_check_request)
	(ServerManager as ServerManagerClass).apply_proxy_to(_check_request)
	_check_request.request_completed.connect(_on_check_completed)
	var url: String = _feed_url()
	Log.info("UpdateManager: Looking for a release newer than %s at %s" % [_current_version, url])
	var error: Error = _check_request.request(url, PackedStringArray([
		"Accept: application/vnd.github+json",
		"X-GitHub-Api-Version: 2022-11-28",
		"User-Agent: Kalulu/%s" % _current_version,
	]))
	if error != OK:
		Log.warn("UpdateManager: Could not start the update check (%s)" % error_string(error))
		_end_check(false)


func _on_check_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		# Offline, filtered, or GitHub's hourly limit: none of it is the reader's
		# business, and the answer from the last check still stands.
		Log.info("UpdateManager: Update check failed (result %d, HTTP %d)" % [result, response_code])
		_end_check(false)
		return
	var json: JSON = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		Log.warn("UpdateManager: The release list is not JSON: %s" % json.get_error_message())
		_end_check(false)
		return
	var newest: AppRelease = AppRelease.newest_from_github_list(json.data)
	Log.info("UpdateManager: Newest release is %s, this is %s" % [newest.version if newest else "none", _current_version])
	var cache: ConfigFile = _load_cache()
	cache.set_value("release", "data", newest.to_dictionary() if newest else {})
	_save_check_time(cache, true)
	_end_check(true)
	_offer(newest)


func _end_check(succeeded: bool) -> void:
	if not succeeded:
		_save_check_time(_load_cache(), false)
	if _check_request:
		_check_request.queue_free()
		_check_request = null


## Makes `release` the one on offer when it is newer than this build.
func _offer(release: AppRelease) -> void:
	var newer: AppRelease = release if release and AppRelease.compare_versions(release.version, _current_version) > 0 else null
	var changed: bool = (newer == null) != (available == null) \
			or (newer and available and newer.version != available.version)
	available = newer
	if changed:
		release_changed.emit(available)


## What the reader can do about the available release.
func action() -> Action:
	if not available:
		return Action.NONE
	match channel:
		UpdateChannel.Kind.GOOGLE_PLAY, UpdateChannel.Kind.APP_STORE, UpdateChannel.Kind.MAC_APP_STORE:
			return Action.OPEN_STORE
		UpdateChannel.Kind.DIRECT:
			return Action.INSTALL_IN_APP if _can_install_in_app() else Action.OPEN_DOWNLOAD
	return Action.NONE


func _can_install_in_app() -> bool:
	if not UpdateChannel.may_install_itself() or not _installer:
		return false
	if available.asset_for(UpdateChannel.current_asset_prefix()).is_empty():
		return false
	var blocker: String = _installer.blocker()
	if not blocker.is_empty():
		Log.info("UpdateManager: Not installing in the app: %s" % blocker)
		return false
	return true


## Opens this build's store on Kalulu's page. False when no address would open.
func open_store() -> bool:
	for url: String in UpdateChannel.store_urls(channel):
		if OS.shell_open(url) == OK:
			Log.info("UpdateManager: Opened %s" % url)
			return true
		Log.warn("UpdateManager: Could not open %s" % url)
	return false


## Opens the release's download for this platform in the browser, or its page when
## it has none for it. False when nothing would open.
func open_download() -> bool:
	var url: String = UpdateChannel.RELEASES_PAGE_URL
	if available:
		var asset: Dictionary = available.asset_for(UpdateChannel.current_asset_prefix())
		url = str(asset.get("url", "")) if not asset.is_empty() else available.page_url
		if url.is_empty():
			url = UpdateChannel.RELEASES_PAGE_URL
	var error: Error = OS.shell_open(url)
	Log.info("UpdateManager: Opening %s: %s" % [url, error_string(error)])
	return error == OK


## Downloads the release, checks it, installs it and restarts into it -- or, on
## Android, hands it to the system installer.
func start_install() -> void:
	if is_installing or action() != Action.INSTALL_IN_APP:
		return
	_download_asset = available.asset_for(UpdateChannel.current_asset_prefix())
	is_installing = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DOWNLOAD_DIR))
	_download_path = DOWNLOAD_DIR.path_join(str(_download_asset["name"]))
	_download_request = HTTPRequest.new()
	_download_request.use_threads = true
	_download_request.download_file = _download_path
	add_child(_download_request)
	(ServerManager as ServerManagerClass).apply_proxy_to(_download_request)
	_download_request.request_completed.connect(_on_download_completed)
	Log.info("UpdateManager: Downloading %s" % _download_asset["url"])
	var error: Error = _download_request.request(str(_download_asset["url"]),
			PackedStringArray(["User-Agent: Kalulu/%s" % _current_version]))
	if error != OK:
		_fail("could not start the download (%s)" % error_string(error))
		return
	install_progressed.emit(InstallStage.DOWNLOADING, 0.0)


## Stops a download under way. Once the files are being swapped it is too late,
## and this does nothing.
func cancel_install() -> void:
	if not is_installing or not _download_request:
		return
	Log.info("UpdateManager: Download cancelled")
	_download_request.cancel_request()
	_finish_download()
	_remove_downloads()
	is_installing = false


func _process(_delta: float) -> void:
	if not _download_request:
		return
	var total: int = _download_request.get_body_size()
	if total <= 0:
		total = int(_download_asset.get("size", 0))
	var fraction: float = clampf(float(_download_request.get_downloaded_bytes()) / total, 0.0, 1.0) if total > 0 else -1.0
	install_progressed.emit(InstallStage.DOWNLOADING, fraction)


func _on_download_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_finish_download()
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_fail("the download failed (result %d, HTTP %d)" % [result, response_code])
		return
	var problem: String = UpdateInstaller.check_download(_download_path,
			int(_download_asset.get("size", 0)), str(_download_asset.get("sha256", "")))
	if not problem.is_empty():
		_fail(problem)
		return
	install_progressed.emit(InstallStage.INSTALLING, 1.0)
	_install_thread = Thread.new()
	_install_thread.start(_installer.install.bind(ProjectSettings.globalize_path(_download_path)))
	while _install_thread.is_alive():
		await get_tree().process_frame
	var outcome: Dictionary = _install_thread.wait_to_finish()
	_install_thread = null
	for note: String in _installer.notes:
		Log.info("UpdateInstaller: " + note)
	_installer.notes.clear()
	# The zip has served its purpose either way. On Android the APK taken out of
	# it stays, for the system installer to read; the next launch removes it.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_download_path))
	if not str(outcome.get("error", "")).is_empty():
		_fail(str(outcome["error"]))
		return
	var launch_path: String = str(outcome["launch"])
	var launch_error: Error = _installer.launch(launch_path)
	if launch_error != OK:
		_fail("could not start %s (%s)" % [launch_path, error_string(launch_error)])
		return
	if _installer.platform == UpdateInstaller.Platform.ANDROID:
		Log.info("UpdateManager: Android's installer opened on %s" % launch_path)
		is_installing = false
		install_progressed.emit(InstallStage.SYSTEM_INSTALLER, 1.0)
		return
	Log.info("UpdateManager: Version %s installed, restarting into %s" % [available.version, launch_path])
	install_progressed.emit(InstallStage.RESTARTING, 1.0)
	# A moment for the reader to see that it worked, and for the new process to
	# start before this one's window goes.
	await get_tree().create_timer(1.5).timeout
	get_tree().quit()


func _finish_download() -> void:
	if _download_request:
		_download_request.queue_free()
		_download_request = null


func _fail(reason: String) -> void:
	Log.warn("UpdateManager: In-app update failed: %s" % reason)
	_finish_download()
	_remove_downloads()
	is_installing = false
	install_failed.emit(reason)


## Deletes downloaded releases. Kept only while installing: a release is up to
## 90 MB, and a device that never finishes an update must not keep collecting them.
func _remove_downloads() -> void:
	var folder: String = ProjectSettings.globalize_path(DOWNLOAD_DIR)
	if not DirAccess.dir_exists_absolute(folder):
		return
	for file_name: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file_name))


func _exit_tree() -> void:
	if _install_thread and _install_thread.is_started():
		_install_thread.wait_to_finish()


## Whether the last check is old enough to ask again: CHECK_INTERVAL_SECONDS after
## one that answered, RETRY_INTERVAL_SECONDS after one that failed.
func _is_due(cache: ConfigFile) -> bool:
	return is_check_due(Time.get_unix_time_from_system(),
			float(cache.get_value("check", "succeeded_at", 0.0)),
			float(cache.get_value("check", "attempted_at", 0.0)),
			str(cache.get_value("check", "app_version", "")) != _current_version)


## The scheduling rule on its own, so it can be tested without a clock. A new app
## version always checks: what was cached was measured against the old one.
static func is_check_due(now: float, succeeded_at: float, attempted_at: float, app_changed: bool) -> bool:
	if app_changed:
		return true
	# A clock set back would otherwise put the next check years away.
	if succeeded_at > now or attempted_at > now:
		return true
	if now - attempted_at < RETRY_INTERVAL_SECONDS:
		return false
	return now - succeeded_at >= CHECK_INTERVAL_SECONDS


func _load_cache() -> ConfigFile:
	var cache: ConfigFile = ConfigFile.new()
	if FileAccess.file_exists(CACHE_PATH):
		cache.load(CACHE_PATH)
	return cache


func _save_check_time(cache: ConfigFile, succeeded: bool) -> void:
	var now: float = Time.get_unix_time_from_system()
	cache.set_value("check", "attempted_at", now)
	if succeeded:
		cache.set_value("check", "succeeded_at", now)
		cache.set_value("check", "app_version", _current_version)
	var error: Error = cache.save(CACHE_PATH)
	if error != OK:
		Log.warn("UpdateManager: Could not save %s (%s)" % [CACHE_PATH, error_string(error)])


func _feed_url() -> String:
	var override: String = _feed_override()
	return override if not override.is_empty() else UpdateChannel.RELEASES_API_URL


func _feed_override() -> String:
	if not OS.is_debug_build():
		return ""
	return OS.get_environment(FEED_OVERRIDE_ENVIRONMENT)
