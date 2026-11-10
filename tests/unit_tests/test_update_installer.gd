extends GutTest
## UpdateInstaller, on real folders: the swap, its undoing, the cleanup, and the
## checks that keep it from touching an app it should not.

var root: String = ""


func before_each() -> void:
	root = OS.get_user_data_dir().path_join("test_update_installer_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(root)


func after_each() -> void:
	UpdateInstaller.remove_tree(root)


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _zip(zip_path: String, files: Dictionary) -> void:
	var packer: ZIPPacker = ZIPPacker.new()
	assert_eq(packer.open(zip_path), OK)
	for file_name: String in files:
		packer.start_file(file_name)
		packer.write_file((files[file_name] as String).to_utf8_buffer())
		packer.close_file()
	packer.close()


## An installer for a Linux-style app at `<root>/app/Kalulu-Linux`.
func _linux_installer() -> UpdateInstaller:
	var installer: UpdateInstaller = UpdateInstaller.new()
	installer.platform = UpdateInstaller.Platform.LINUX
	installer.executable_path = root.path_join("app/Kalulu-Linux")
	_write(installer.executable_path, "old program")
	_write(root.path_join("app/Kalulu-Linux.pck"), "old data")
	_write(root.path_join("app/notes of the user.txt"), "mine")
	return installer


func test_swap_moves_the_old_files_aside_and_the_new_ones_in() -> void:
	_write(root.path_join("target/a"), "old a")
	_write(root.path_join("staging/a"), "new a")
	_write(root.path_join("staging/b"), "new b")
	var error: String = UpdateInstaller.swap(root.path_join("staging"), root.path_join("target"), ["a", "b"])
	assert_eq(error, "")
	assert_eq(_read(root.path_join("target/a")), "new a")
	assert_eq(_read(root.path_join("target/b")), "new b")
	assert_eq(_read(root.path_join("target/a" + UpdateInstaller.OLD_SUFFIX)), "old a")


func test_a_failed_swap_puts_everything_back() -> void:
	_write(root.path_join("target/a"), "old a")
	_write(root.path_join("target/b"), "old b")
	_write(root.path_join("staging/a"), "new a")
	# "b" is announced but missing from the staging folder, so its move fails
	# after "a" has already been swapped.
	var error: String = UpdateInstaller.swap(root.path_join("staging"), root.path_join("target"), ["a", "b"])
	assert_ne(error, "")
	assert_false("COULD NOT PUT" in error, error)
	assert_eq(_read(root.path_join("target/a")), "old a")
	assert_eq(_read(root.path_join("target/b")), "old b")
	assert_eq(_read(root.path_join("staging/a")), "new a")
	assert_false(FileAccess.file_exists(root.path_join("target/a" + UpdateInstaller.OLD_SUFFIX)))
	assert_false(FileAccess.file_exists(root.path_join("target/b" + UpdateInstaller.OLD_SUFFIX)))


func test_an_aside_still_in_use_gets_a_numbered_name() -> void:
	var target: String = root.path_join("target")
	DirAccess.make_dir_recursive_absolute(target.path_join("a" + UpdateInstaller.OLD_SUFFIX + "/locked"))
	_write(target.path_join("a" + UpdateInstaller.OLD_SUFFIX + "/locked/file"), "x")
	# A folder the cleanup cannot delete stands in for a file Windows keeps locked.
	if OS.has_feature("windows"):
		pass_test("permissions cannot lock a folder on Windows")
		return
	OS.execute("chmod", ["555", target.path_join("a" + UpdateInstaller.OLD_SUFFIX + "/locked")])
	_write(target.path_join("a"), "old a")
	_write(root.path_join("staging/a"), "new a")
	assert_eq(UpdateInstaller.swap(root.path_join("staging"), target, ["a"]), "")
	assert_eq(_read(target.path_join("a")), "new a")
	assert_eq(_read(target.path_join("a" + UpdateInstaller.OLD_SUFFIX + "1")), "old a")
	OS.execute("chmod", ["755", target.path_join("a" + UpdateInstaller.OLD_SUFFIX + "/locked")])


func test_install_replaces_the_app_and_leaves_the_users_files_alone() -> void:
	if OS.has_feature("windows"):
		pass_test("this test unpacks with the Unix tools")
		return
	var installer: UpdateInstaller = _linux_installer()
	assert_eq(installer.blocker(), "")
	var zip_path: String = root.path_join("Kalulu-Linux-9.9.9.zip")
	_zip(zip_path, {"Kalulu-Linux": "new program", "Kalulu-Linux.pck": "new data", "libnew.so": "new library"})
	var outcome: Dictionary = installer.install(zip_path)
	assert_eq(outcome["error"], "", "notes: %s" % ", ".join(installer.notes))
	assert_eq(outcome["launch"], root.path_join("app/Kalulu-Linux"))
	assert_eq(_read(root.path_join("app/Kalulu-Linux")), "new program")
	assert_eq(_read(root.path_join("app/Kalulu-Linux.pck")), "new data")
	assert_eq(_read(root.path_join("app/libnew.so")), "new library")
	assert_eq(_read(root.path_join("app/notes of the user.txt")), "mine")
	assert_ne(FileAccess.get_unix_permissions(root.path_join("app/Kalulu-Linux")) & FileAccess.UNIX_EXECUTE_OWNER, 0,
			"the program can be run")
	assert_false(DirAccess.dir_exists_absolute(root.path_join("app/" + UpdateInstaller.STAGING_DIR_NAME)))

	installer.remove_leftovers()
	assert_false(FileAccess.file_exists(root.path_join("app/Kalulu-Linux" + UpdateInstaller.OLD_SUFFIX)))
	assert_false(FileAccess.file_exists(root.path_join("app/Kalulu-Linux.pck" + UpdateInstaller.OLD_SUFFIX)))
	assert_eq(_read(root.path_join("app/notes of the user.txt")), "mine")


func test_a_release_without_the_app_changes_nothing() -> void:
	if OS.has_feature("windows"):
		pass_test("this test unpacks with the Unix tools")
		return
	var installer: UpdateInstaller = _linux_installer()
	var zip_path: String = root.path_join("other.zip")
	_zip(zip_path, {"Something-Else": "?"})
	var outcome: Dictionary = installer.install(zip_path)
	assert_ne(outcome["error"], "")
	assert_eq(_read(root.path_join("app/Kalulu-Linux")), "old program")
	assert_false(FileAccess.file_exists(root.path_join("app/Something-Else")))


func test_a_corrupt_archive_changes_nothing() -> void:
	if OS.has_feature("windows"):
		pass_test("this test unpacks with the Unix tools")
		return
	var installer: UpdateInstaller = _linux_installer()
	var zip_path: String = root.path_join("broken.zip")
	_write(zip_path, "this is not a zip")
	var outcome: Dictionary = installer.install(zip_path)
	assert_ne(outcome["error"], "")
	assert_eq(_read(root.path_join("app/Kalulu-Linux")), "old program")
	assert_false(DirAccess.dir_exists_absolute(root.path_join("app/" + UpdateInstaller.STAGING_DIR_NAME)))


func test_a_renamed_app_is_not_updated_in_place() -> void:
	var installer: UpdateInstaller = UpdateInstaller.new()
	installer.platform = UpdateInstaller.Platform.LINUX
	installer.executable_path = root.path_join("app/My-Kalulu")
	_write(installer.executable_path, "old program")
	assert_ne(installer.blocker(), "")


func test_a_folder_the_user_cannot_write_to_is_not_updated_in_place() -> void:
	if OS.has_feature("windows"):
		pass_test("permissions cannot lock a folder on Windows")
		return
	var installer: UpdateInstaller = _linux_installer()
	OS.execute("chmod", ["555", root.path_join("app")])
	assert_ne(installer.blocker(), "")
	OS.execute("chmod", ["755", root.path_join("app")])
	assert_eq(installer.blocker(), "")


func test_a_translocated_mac_app_is_not_updated_in_place() -> void:
	var installer: UpdateInstaller = UpdateInstaller.new()
	installer.platform = UpdateInstaller.Platform.MACOS
	installer.executable_path = "/private/var/folders/xx/AppTranslocation/1234/d/Kalulu.app/Contents/MacOS/Kalulu"
	assert_eq(installer.macos_bundle_path(), "/private/var/folders/xx/AppTranslocation/1234/d/Kalulu.app")
	assert_eq(installer.app_entry_name(), "Kalulu.app")
	assert_ne(installer.blocker(), "")


func test_the_mac_bundle_is_found_from_its_executable() -> void:
	var installer: UpdateInstaller = UpdateInstaller.new()
	installer.platform = UpdateInstaller.Platform.MACOS
	installer.executable_path = "/Applications/Kalulu.app/Contents/MacOS/Kalulu"
	assert_eq(installer.install_dir(), "/Applications")
	assert_eq(installer.app_entry_name(), "Kalulu.app")
	installer.executable_path = "/usr/local/bin/kalulu"
	assert_eq(installer.macos_bundle_path(), "")
	assert_ne(installer.blocker(), "")


func test_a_download_must_match_what_the_release_announced() -> void:
	var path: String = root.path_join("download.zip")
	_write(path, "content")
	var sha256: String = FileAccess.get_sha256(path)
	assert_eq(UpdateInstaller.check_download(path, 7, sha256), "")
	assert_eq(UpdateInstaller.check_download(path, 7, sha256.to_upper()), "")
	assert_eq(UpdateInstaller.check_download(path, 0, ""), "", "nothing announced, nothing to compare")
	assert_ne(UpdateInstaller.check_download(path, 8, sha256), "")
	assert_ne(UpdateInstaller.check_download(path, 7, "0".repeat(64)), "")
	assert_ne(UpdateInstaller.check_download(root.path_join("missing.zip"), 0, ""), "")


func test_removing_a_tree_never_follows_a_link_out_of_it() -> void:
	if OS.has_feature("windows"):
		pass_test("symbolic links need privileges on Windows")
		return
	_write(root.path_join("outside/precious"), "keep me")
	_write(root.path_join("tree/inside/file"), "x")
	OS.execute("ln", ["-s", root.path_join("outside"), root.path_join("tree/inside/link")])
	assert_true(DirAccess.dir_exists_absolute(root.path_join("tree/inside/link")), "the link was made")
	assert_eq(UpdateInstaller.remove_tree(root.path_join("tree")), OK)
	assert_false(DirAccess.dir_exists_absolute(root.path_join("tree")))
	assert_eq(_read(root.path_join("outside/precious")), "keep me")


## The whole macOS path on a real bundle: unpacked by ditto with its symbolic
## links, its signature checked, swapped in.
func test_a_mac_bundle_is_replaced_with_its_links_and_signature_intact() -> void:
	if not OS.has_feature("macos"):
		pass_test("needs ditto and codesign")
		return
	var old_bundle: String = root.path_join("Applications/Kalulu.app")
	var new_bundle: String = root.path_join("build/Kalulu.app")
	for bundle: String in [old_bundle, new_bundle]:
		DirAccess.make_dir_recursive_absolute(bundle.path_join("Contents/MacOS"))
		DirAccess.copy_absolute("/usr/bin/true", bundle.path_join("Contents/MacOS/Kalulu"))
		_write(bundle.path_join("Contents/Info.plist"), "<?xml version=\"1.0\" encoding=\"UTF-8\"?><plist version=\"1.0\"><dict><key>CFBundleExecutable</key><string>Kalulu</string><key>CFBundleIdentifier</key><string>org.example.kalulu-test</string></dict></plist>")
		_write(bundle.path_join("Contents/Resources/version.txt"), "old" if bundle == old_bundle else "new")
	OS.execute("ln", ["-s", "Resources", new_bundle.path_join("Contents/Current")])
	var output: Array = []
	assert_eq(OS.execute("/usr/bin/codesign", ["--force", "--sign", "-", new_bundle], output, true), 0, str(output))
	var zip_path: String = root.path_join("Kalulu-macOS-9.9.9.zip")
	assert_eq(OS.execute("/usr/bin/ditto", ["-c", "-k", "--keepParent", new_bundle, zip_path]), 0)

	var installer: UpdateInstaller = UpdateInstaller.new()
	installer.platform = UpdateInstaller.Platform.MACOS
	installer.executable_path = old_bundle.path_join("Contents/MacOS/Kalulu")
	assert_eq(installer.blocker(), "")
	var outcome: Dictionary = installer.install(zip_path)
	assert_eq(outcome["error"], "", "notes: %s" % ", ".join(installer.notes))
	assert_eq(outcome["launch"], old_bundle)
	assert_eq(_read(old_bundle.path_join("Contents/Resources/version.txt")), "new")
	var dir: DirAccess = DirAccess.open(old_bundle.path_join("Contents"))
	assert_true(dir.is_link("Current"), "the symbolic link survived the unpacking")
	assert_eq(OS.execute("/usr/bin/codesign", ["--verify", "--deep", "--strict", old_bundle]), 0)
	installer.remove_leftovers()
	assert_false(DirAccess.dir_exists_absolute(old_bundle + UpdateInstaller.OLD_SUFFIX))


func test_a_mac_bundle_with_a_broken_signature_is_refused() -> void:
	if not OS.has_feature("macos"):
		pass_test("needs codesign")
		return
	var bundle: String = root.path_join("Kalulu.app")
	DirAccess.make_dir_recursive_absolute(bundle.path_join("Contents/MacOS"))
	DirAccess.copy_absolute("/usr/bin/true", bundle.path_join("Contents/MacOS/Kalulu"))
	_write(bundle.path_join("Contents/Info.plist"), "<?xml version=\"1.0\" encoding=\"UTF-8\"?><plist version=\"1.0\"><dict><key>CFBundleExecutable</key><string>Kalulu</string><key>CFBundleIdentifier</key><string>org.example.kalulu-test</string></dict></plist>")
	_write(bundle.path_join("Contents/Resources/data"), "signed")
	OS.execute("/usr/bin/codesign", ["--force", "--sign", "-", bundle])
	assert_eq(UpdateInstaller.macos_signature_problem(bundle, ""), "")
	_write(bundle.path_join("Contents/Resources/data"), "tampered")
	assert_ne(UpdateInstaller.macos_signature_problem(bundle, ""), "")


func test_checks_are_spaced_out() -> void:
	var hour: float = 3600.0
	var now: float = 1_000_000.0
	assert_true(UpdateManagerClass.is_check_due(now, 0.0, 0.0, false), "never checked")
	assert_false(UpdateManagerClass.is_check_due(now, now - hour, now - hour, false), "checked an hour ago")
	assert_true(UpdateManagerClass.is_check_due(now, now - 7 * hour, now - 7 * hour, false), "checked seven hours ago")
	assert_false(UpdateManagerClass.is_check_due(now, now - 7 * hour, now - 0.5 * hour, false), "failed half an hour ago")
	assert_true(UpdateManagerClass.is_check_due(now, now - 7 * hour, now - 2 * hour, false), "failed two hours ago")
	assert_true(UpdateManagerClass.is_check_due(now, now - hour, now - hour, true), "the app was updated since")
	assert_true(UpdateManagerClass.is_check_due(now, now + 100 * hour, now + 100 * hour, false), "the clock went back")
