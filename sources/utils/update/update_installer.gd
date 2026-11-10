class_name UpdateInstaller
extends RefCounted
## Puts a downloaded release in place of the running app, for the builds that
## were downloaded from GitHub rather than installed from a store.
##
## On a computer the release is a zip of the same files the app is made of, so
## installing it is a swap: unpack it next to the app, move each old file aside,
## move each new one in, and start the new one. Every OS involved lets a running
## program's files be renamed -- Windows included, which only refuses to delete
## or overwrite them -- so nothing has to wait for the app to quit. What was moved
## aside is deleted on the next launch, by `remove_leftovers`.
##
## A swap that fails half-way puts back everything it had moved: the app the
## reader started from is never left broken. Anything that makes the swap unsafe
## -- a folder the user may not write to, a copy macOS is running from a read-only
## mount, an app renamed since it was unpacked -- is caught beforehand by
## `blocker`, and the caller sends the reader to the download in their browser
## instead.
##
## On Android the release is a zip around the APK: it is unpacked and handed to
## the system installer, which asks the user to confirm. The APK presets declare
## REQUEST_INSTALL_PACKAGES for that; the Play build never comes here.
##
## Nothing here touches the network or the scene tree, so it runs on a worker
## thread, and the tests drive it on folders of their own.

enum Platform {
	OTHER,
	WINDOWS,
	LINUX,
	MACOS,
	ANDROID,
}

## The folder a release is unpacked into, beside the app so the final moves are
## renames on one volume rather than copies.
const STAGING_DIR_NAME: String = ".kalulu-update"
## Appended to what an update moved aside. The cleanup deletes only names carrying
## it, so it can never reach a file of the user's.
const OLD_SUFFIX: String = ".kalulu-old"
const PROBE_FILE_NAME: String = ".kalulu-update-probe"
## Where the APK is put for the system installer. `user://` is the app's internal
## files folder on Android, which Godot's FileProvider shares with the installer.
const ANDROID_APK_PATH: String = "user://updates/kalulu-update.apk"
## What the app is called inside each platform's release zip, as Kalulu-Main's
## release pipeline exports it. The CI workflow's builds use other names, so they
## are sent to the browser rather than updated in place.
const RELEASED_APP_NAMES: Dictionary[Platform, String] = {
	Platform.WINDOWS: "Kalulu-Windows.exe",
	Platform.LINUX: "Kalulu-Linux",
	Platform.MACOS: "Kalulu.app",
}
## Every file a release zip may hold, besides the app itself: what must be there,
## and patterns for what may. Anything else refuses the whole release. The zip is
## unpacked over a folder that is often the user's Downloads or Desktop, and an
## unexpected name in it -- a README, a `__MACOSX` folder -- would move one of the
## user's own files aside, to be deleted at the next launch.
const RELEASED_REQUIRED_ENTRIES: Dictionary[Platform, PackedStringArray] = {
	Platform.WINDOWS: ["Kalulu-Windows.exe"],
	Platform.LINUX: ["Kalulu-Linux", "Kalulu-Linux.pck"],
	Platform.MACOS: ["Kalulu.app"],
}
const RELEASED_OPTIONAL_PATTERNS: Dictionary[Platform, PackedStringArray] = {
	Platform.WINDOWS: ["libgdsqlite.windows.*.dll"],
	Platform.LINUX: ["libgdsqlite.linux.*.so"],
	Platform.MACOS: [],
}

var platform: Platform = Platform.OTHER
## The running program, as the OS reports it.
var executable_path: String = ""
## What happened along the way, for the log. Collected rather than logged because
## `install` runs on a worker thread and Log is not safe to call from one.
var notes: PackedStringArray = []
## What the last successful swap moved, as [destination, aside] pairs (aside empty
## for an entry that did not exist before), so `revert_last_swap` can undo it.
var last_swap: Array[PackedStringArray] = []


## The installer for the build that is running.
static func for_running_build() -> UpdateInstaller:
	var installer: UpdateInstaller = UpdateInstaller.new()
	installer.platform = platform_for(func(feature: String) -> bool: return OS.has_feature(feature))
	installer.executable_path = OS.get_executable_path()
	return installer


static func platform_for(has_feature: Callable) -> Platform:
	if has_feature.call("android"):
		return Platform.ANDROID
	if has_feature.call("windows"):
		return Platform.WINDOWS
	if has_feature.call("linuxbsd"):
		return Platform.LINUX
	if has_feature.call("macos"):
		return Platform.MACOS
	return Platform.OTHER


func is_desktop() -> bool:
	return platform in [Platform.WINDOWS, Platform.LINUX, Platform.MACOS]


## The entry in `install_dir()` that is the app itself: the executable on Windows
## and Linux, the `.app` bundle on macOS. "" when it cannot be worked out.
func app_entry_name() -> String:
	if platform == Platform.MACOS:
		var bundle: String = macos_bundle_path()
		return bundle.get_file() if not bundle.is_empty() else ""
	return executable_path.get_file()


## The folder the app's files sit in.
func install_dir() -> String:
	if platform == Platform.MACOS:
		var bundle: String = macos_bundle_path()
		return bundle.get_base_dir() if not bundle.is_empty() else ""
	return executable_path.get_base_dir()


## `/somewhere/Kalulu.app` for `/somewhere/Kalulu.app/Contents/MacOS/Kalulu`, or ""
## when the executable is not inside a bundle.
func macos_bundle_path() -> String:
	var bundle: String = executable_path.get_base_dir().get_base_dir().get_base_dir()
	if not bundle.ends_with(".app") or not executable_path.get_base_dir().ends_with("Contents/MacOS"):
		return ""
	return bundle


## Why the app cannot install an update by itself, or "" when it can. The reason
## is for the log, not for the reader, who is offered the browser download either way.
func blocker() -> String:
	if platform == Platform.ANDROID:
		return ""
	if not is_desktop():
		return "platform not supported"
	if executable_path.begins_with("//") or executable_path.begins_with("\\\\"):
		# A network share: other computers may be running these very files, and
		# swapping them would pull their data file from under them mid-lesson.
		return "running from a network share"
	if app_entry_name().is_empty() or install_dir().is_empty():
		return "cannot tell which files are the app (%s)" % executable_path
	if app_entry_name() != RELEASED_APP_NAMES.get(platform, ""):
		# Renamed since it was unpacked, or not a released build at all. The release
		# would land beside it rather than over it -- and on Linux the program finds
		# its data file by its own name, so a renamed one would not even start.
		return "the app is called %s, a release installs %s" % [app_entry_name(), RELEASED_APP_NAMES.get(platform, "")]
	if platform == Platform.MACOS and "/AppTranslocation/" in executable_path:
		# Started from where it was downloaded without being moved: macOS runs it
		# from a read-only copy, and replacing that copy would change nothing.
		return "running from a translocated copy"
	if not _can_write_in(install_dir()):
		return "cannot write in %s" % install_dir()
	if platform == Platform.WINDOWS and _windows_tool("tar.exe").is_empty() \
			and _windows_tool("WindowsPowerShell/v1.0/powershell.exe").is_empty():
		return "no tool to unpack a zip"
	return ""


## Whether the download is the file the release announced. An empty answer means
## it is; otherwise it says what is wrong.
static func check_download(path: String, expected_size: int, expected_sha256: String) -> String:
	if not FileAccess.file_exists(path):
		return "the download is missing"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return "cannot read the download (%s)" % error_string(FileAccess.get_open_error())
	var size: int = file.get_length()
	file.close()
	if expected_size > 0 and size != expected_size:
		return "the download is %d bytes, %d expected" % [size, expected_size]
	if not expected_sha256.is_empty():
		var sha256: String = FileAccess.get_sha256(path).to_lower()
		if sha256 != expected_sha256.to_lower():
			return "the download's SHA-256 is %s, %s expected" % [sha256, expected_sha256]
	return ""


## Checks the download against what the release announced, then installs it. The
## two together, so the hashing of up to 90 MB happens on the caller's worker
## thread rather than freezing the screen.
func install_verified(zip_path: String, expected_size: int, expected_sha256: String) -> Dictionary:
	var problem: String = check_download(zip_path, expected_size, expected_sha256)
	if not problem.is_empty():
		return _failure(problem)
	return install(zip_path)


## Installs the release in `zip_path`. Returns a Dictionary with `error` ("" on
## success) and `launch` -- the path to start: the new program on a computer, the
## APK on Android.
func install(zip_path: String) -> Dictionary:
	if platform == Platform.ANDROID:
		return _prepare_apk(zip_path)
	var reason: String = blocker()
	if not reason.is_empty():
		return _failure(reason)
	var staging: String = install_dir().path_join(STAGING_DIR_NAME)
	if DirAccess.dir_exists_absolute(staging):
		remove_tree(staging)
	var error: Error = DirAccess.make_dir_recursive_absolute(staging)
	if error != OK:
		return _failure("cannot create %s (%s)" % [staging, error_string(error)])
	var outcome: Dictionary = _stage_and_swap(zip_path, staging)
	remove_tree(staging)
	return outcome


func _stage_and_swap(zip_path: String, staging: String) -> Dictionary:
	if not unpack(zip_path, staging):
		return _failure("could not unpack %s" % zip_path)
	var entries: PackedStringArray = _entries_of(staging)
	var app_name: String = app_entry_name()
	var entries_problem: String = unexpected_entries(entries)
	if not entries_problem.is_empty():
		return _failure(entries_problem)
	var new_app: String = staging.path_join(app_name)
	if platform == Platform.MACOS:
		var signature_problem: String = macos_signature_problem(new_app, macos_bundle_path())
		if not signature_problem.is_empty():
			return _failure(signature_problem)
	elif platform == Platform.LINUX:
		# Unpacking tools do not all keep the executable bit.
		FileAccess.set_unix_permissions(new_app, _executable_permissions())
	var moved: Array[PackedStringArray] = []
	var swap_error: String = swap(staging, install_dir(), entries, moved)
	if not swap_error.is_empty():
		return _failure(swap_error)
	last_swap = moved
	return {"error": "", "launch": install_dir().path_join(app_name)}


## Why the unpacked release does not hold exactly the files a release of this
## platform is made of, or "" when it does.
func unexpected_entries(entries: PackedStringArray) -> String:
	var required: PackedStringArray = RELEASED_REQUIRED_ENTRIES.get(platform, PackedStringArray())
	if required.is_empty():
		return "no release layout for this platform"
	for entry: String in required:
		if not entry in entries:
			return "the release has no %s (it has %s)" % [entry, ", ".join(entries)]
	for entry: String in entries:
		if entry in required:
			continue
		var allowed: bool = false
		for pattern: String in RELEASED_OPTIONAL_PATTERNS.get(platform, PackedStringArray()):
			if entry.match(pattern):
				allowed = true
		if not allowed:
			return "the release holds an unexpected %s" % entry
	return ""


## Undoes the last swap: the new files go aside (to be deleted at the next launch)
## and the old ones come back. For when the new version would not start, so the
## reader is left with the app they had rather than one that cannot open. Returns
## "" when everything went back.
func revert_last_swap() -> String:
	var problems: String = ""
	var folder: String = install_dir()
	for index: int in range(last_swap.size() - 1, -1, -1):
		var destination: String = last_swap[index][0]
		var aside: String = last_swap[index][1]
		var rejected: String = _free_aside_path(folder, destination.get_file() + ".rejected")
		var out_error: Error = DirAccess.rename_absolute(destination, rejected)
		if out_error != OK:
			problems += "; cannot move the new %s out (%s)" % [destination, error_string(out_error)]
			continue
		if aside.is_empty():
			continue
		var back_error: Error = DirAccess.rename_absolute(aside, destination)
		if back_error != OK:
			problems += "; cannot put %s back (%s)" % [destination, error_string(back_error)]
	last_swap.clear()
	return problems


## Moves every entry of `staging` into `target`, moving aside what it replaces.
## Puts everything back and returns why when a move fails; returns "" when done.
## `moved`, when given, receives a [destination, aside] pair per entry placed.
static func swap(staging: String, target: String, entries: PackedStringArray,
		moved: Array[PackedStringArray] = []) -> String:
	var moved_aside: Array[PackedStringArray] = []
	var placed: PackedStringArray = []
	for entry: String in entries:
		var destination: String = target.path_join(entry)
		var aside_of_entry: String = ""
		if _exists(destination):
			var aside: String = _free_aside_path(target, entry)
			var aside_error: Error = DirAccess.rename_absolute(destination, aside)
			if aside_error != OK:
				return "cannot move %s aside (%s)%s" % [destination, error_string(aside_error),
						_undo_swap(staging, target, moved_aside, placed)]
			moved_aside.append(PackedStringArray([destination, aside]))
			aside_of_entry = aside
		var place_error: Error = DirAccess.rename_absolute(staging.path_join(entry), destination)
		if place_error != OK:
			return "cannot move %s into place (%s)%s" % [entry, error_string(place_error),
					_undo_swap(staging, target, moved_aside, placed)]
		placed.append(entry)
		moved.append(PackedStringArray([destination, aside_of_entry]))
	return ""


## Puts back what a failed swap had moved. Returns "" when all of it went back,
## otherwise what could not, to be added to the swap's own reason.
static func _undo_swap(staging: String, target: String, moved_aside: Array[PackedStringArray],
		placed: PackedStringArray) -> String:
	var problems: String = ""
	for index: int in range(placed.size() - 1, -1, -1):
		var entry: String = placed[index]
		DirAccess.rename_absolute(target.path_join(entry), staging.path_join(entry))
	for index: int in range(moved_aside.size() - 1, -1, -1):
		var pair: PackedStringArray = moved_aside[index]
		var error: Error = DirAccess.rename_absolute(pair[1], pair[0])
		if error != OK:
			problems += "; COULD NOT PUT %s BACK from %s (%s)" % [pair[0], pair[1], error_string(error)]
	return problems


## Where to move `entry` aside to. Normally `<entry>.kalulu-old`; when that is
## still there -- the previous update's copy, which Windows will not let go of
## while that version is running -- a numbered name next to it.
static func _free_aside_path(target: String, entry: String) -> String:
	var aside: String = target.path_join(entry + OLD_SUFFIX)
	if _exists(aside) and remove_tree(aside) != OK:
		var attempt: int = 1
		while _exists(aside + str(attempt)):
			attempt += 1
		aside += str(attempt)
	return aside


## Deletes what an earlier update moved aside, and an unpacking it left behind.
## Called at every launch; anything still in use is left for the next one.
func remove_leftovers() -> void:
	if not is_desktop():
		if platform == Platform.ANDROID and FileAccess.file_exists(ANDROID_APK_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(ANDROID_APK_PATH))
		return
	var folder: String = install_dir()
	if folder.is_empty() or not DirAccess.dir_exists_absolute(folder):
		return
	for entry: String in _entries_of(folder):
		if entry == STAGING_DIR_NAME or OLD_SUFFIX in entry:
			var path: String = folder.path_join(entry)
			var error: Error = remove_tree(path)
			Log.info("UpdateInstaller: Removing %s: %s" % [path, error_string(error)])


## Deletes a file, or a folder and everything in it. Symbolic links are removed,
## never followed: a macOS framework is full of them, and following one would
## reach files outside the tree.
static func remove_tree(path: String) -> Error:
	if _is_link(path):
		return DirAccess.remove_absolute(path)
	if not DirAccess.dir_exists_absolute(path):
		return DirAccess.remove_absolute(path) if FileAccess.file_exists(path) else OK
	var result: Error = OK
	for entry: String in _entries_of(path):
		var error: Error = remove_tree(path.path_join(entry))
		if error != OK:
			result = error
	var error: Error = DirAccess.remove_absolute(path)
	return result if result != OK else error


## Unpacks `zip_path` into `destination` with the platform's own tool. Those keep
## what a macOS bundle needs (symbolic links, permissions), and stream rather than
## holding the archive in memory -- the Windows program alone is 640 MB unpacked.
func unpack(zip_path: String, destination: String) -> bool:
	var attempts: Array[PackedStringArray] = []
	match platform:
		Platform.MACOS:
			attempts.append(PackedStringArray(["/usr/bin/ditto", "-x", "-k", zip_path, destination]))
		Platform.LINUX:
			attempts.append(PackedStringArray(["unzip", "-q", "-o", zip_path, "-d", destination]))
			attempts.append(PackedStringArray(["bsdtar", "-xf", zip_path, "-C", destination]))
			attempts.append(PackedStringArray(["python3", "-m", "zipfile", "-e", zip_path, destination]))
		Platform.WINDOWS:
			var native_zip: String = zip_path.replace("/", "\\")
			var native_destination: String = destination.replace("/", "\\")
			var tar: String = _windows_tool("tar.exe")
			if not tar.is_empty():
				attempts.append(PackedStringArray([tar, "-xf", native_zip, "-C", native_destination]))
			var powershell: String = _windows_tool("WindowsPowerShell/v1.0/powershell.exe")
			if not powershell.is_empty():
				# The paths reach PowerShell through the environment, never inside the
				# command: a folder named with a typographic apostrophe or a bracket
				# would otherwise end the string or be read as a wildcard.
				OS.set_environment("KALULU_UPDATE_ZIP", native_zip)
				OS.set_environment("KALULU_UPDATE_DESTINATION", native_destination)
				attempts.append(PackedStringArray([powershell, "-NoProfile", "-NonInteractive", "-Command",
						"Expand-Archive -LiteralPath $env:KALULU_UPDATE_ZIP -DestinationPath ([Management.Automation.WildcardPattern]::Escape($env:KALULU_UPDATE_DESTINATION)) -Force"]))
	for attempt: PackedStringArray in attempts:
		var output: Array = []
		var exit_code: int = OS.execute(attempt[0], attempt.slice(1), output, true)
		if exit_code == 0 and not _entries_of(destination).is_empty():
			return true
		notes.append("%s exited with %d: %s" % [attempt[0], exit_code, "".join(output).strip_edges().left(500)])
		# Whatever a failed tool left behind would be mixed into the next one's.
		for entry: String in _entries_of(destination):
			remove_tree(destination.path_join(entry))
	return false


## Why the unpacked bundle must not replace the running one, or "" when it may: its
## signature has to hold, and it has to come from the same developer as the app it
## replaces. Gatekeeper would not check a file the app downloaded itself, so this
## is the check it would have made.
static func macos_signature_problem(new_bundle: String, current_bundle: String) -> String:
	var output: Array = []
	var exit_code: int = OS.execute("/usr/bin/codesign", ["--verify", "--deep", "--strict", new_bundle], output, true)
	if exit_code != 0:
		return "the new app's signature does not verify: %s" % "".join(output).strip_edges().left(500)
	var current_team: String = macos_team(current_bundle)
	if current_team.is_empty():
		# The running app is not signed by a team (a local build), so there is no
		# developer to match.
		return ""
	var new_team: String = macos_team(new_bundle)
	if new_team != current_team:
		return "the new app is signed by team '%s', the running one by '%s'" % [new_team, current_team]
	return ""


## The team a bundle is signed by, or "" for an unsigned or ad hoc one.
static func macos_team(bundle: String) -> String:
	if bundle.is_empty():
		return ""
	var output: Array = []
	OS.execute("/usr/bin/codesign", ["-dv", bundle], output, true)
	for line: String in "".join(output).split("\n"):
		if line.begins_with("TeamIdentifier="):
			var team: String = line.trim_prefix("TeamIdentifier=").strip_edges()
			return "" if team == "not set" else team
	return ""


## Starts what `install` returned and says whether that worked. The caller quits
## the running app after it, on a computer.
func launch(path: String) -> Error:
	match platform:
		Platform.ANDROID:
			return OS.shell_open(ProjectSettings.globalize_path(path))
		Platform.MACOS:
			# Through Launch Services, as if opened from the Finder: `-n` because
			# the running copy, the one being replaced, has not quit yet.
			return OK if OS.create_process("/usr/bin/open", ["-n", path]) > 0 else FAILED
		Platform.WINDOWS, Platform.LINUX:
			return OK if OS.create_process(path, []) > 0 else FAILED
	return ERR_UNAVAILABLE


## Takes the APK out of the release zip, where the system installer can read it.
func _prepare_apk(zip_path: String) -> Dictionary:
	var reader: ZIPReader = ZIPReader.new()
	var error: Error = reader.open(zip_path)
	if error != OK:
		return _failure("cannot open %s (%s)" % [zip_path, error_string(error)])
	var apk_name: String = ""
	for file_name: String in reader.get_files():
		if file_name.get_extension().to_lower() == "apk" and not "/" in file_name:
			apk_name = file_name
			break
	if apk_name.is_empty():
		reader.close()
		return _failure("the release has no APK")
	var bytes: PackedByteArray = reader.read_file(apk_name)
	reader.close()
	if bytes.is_empty():
		return _failure("cannot read %s from the release" % apk_name)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ANDROID_APK_PATH.get_base_dir()))
	var file: FileAccess = FileAccess.open(ANDROID_APK_PATH, FileAccess.WRITE)
	if not file:
		return _failure("cannot write the APK (%s)" % error_string(FileAccess.get_open_error()))
	var stored: bool = file.store_buffer(bytes)
	file.close()
	if not stored:
		return _failure("cannot write the APK, the device may be full")
	return {"error": "", "launch": ANDROID_APK_PATH}


static func _failure(reason: String) -> Dictionary:
	return {"error": reason, "launch": ""}


static func _entries_of(folder: String) -> PackedStringArray:
	var dir: DirAccess = DirAccess.open(folder)
	if not dir:
		return PackedStringArray()
	dir.include_hidden = true
	dir.include_navigational = false
	var entries: PackedStringArray = dir.get_files()
	entries.append_array(dir.get_directories())
	return entries


static func _exists(path: String) -> bool:
	return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)


static func _is_link(path: String) -> bool:
	var dir: DirAccess = DirAccess.open(path.get_base_dir())
	return dir != null and dir.is_link(path.get_file())


static func _can_write_in(folder: String) -> bool:
	if not DirAccess.dir_exists_absolute(folder):
		return false
	var probe: String = folder.path_join(PROBE_FILE_NAME)
	var file: FileAccess = FileAccess.open(probe, FileAccess.WRITE)
	if not file:
		return false
	file.close()
	DirAccess.remove_absolute(probe)
	return true


## A program shipped with Windows, under `System32`, or "" when it is not there.
static func _windows_tool(relative_path: String) -> String:
	var root: String = OS.get_environment("SystemRoot")
	if root.is_empty():
		root = "C:/Windows"
	var path: String = root.replace("\\", "/").path_join("System32").path_join(relative_path)
	return path.replace("/", "\\") if FileAccess.file_exists(path) else ""


static func _executable_permissions() -> int:
	return FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER | FileAccess.UNIX_EXECUTE_OWNER \
			| FileAccess.UNIX_READ_GROUP | FileAccess.UNIX_EXECUTE_GROUP \
			| FileAccess.UNIX_READ_OTHER | FileAccess.UNIX_EXECUTE_OTHER
