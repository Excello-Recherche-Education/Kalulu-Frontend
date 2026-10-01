extends GutTest
## Reading user://environment.cfg at launch, and when that read writes it back.
##
## Every launch reads this file before the first frame. Rewriting it when nothing had
## changed was a disk write on every cold start, so the read now saves only when it
## had something to correct. A key no version of the app writes is the probe: the
## save rebuilds the file from the node's own fields, so a rewrite drops it.

const MARKER_SECTION: String = "test"
const MARKER_KEY: String = "survives_an_unchanged_read"

var _original_bytes: PackedByteArray = PackedByteArray()
var _had_original: bool = false


func before_each() -> void:
	_had_original = FileAccess.file_exists(ServerManagerClass.CONFIG_PATH)
	if _had_original:
		_original_bytes = FileAccess.get_file_as_bytes(ServerManagerClass.CONFIG_PATH)


func after_each() -> void:
	var server: ServerManagerClass = ServerManager as ServerManagerClass
	if _had_original:
		var file: FileAccess = FileAccess.open(ServerManagerClass.CONFIG_PATH, FileAccess.WRITE)
		file.store_buffer(_original_bytes)
		file.close()
		# Put the node back to what the restored file says.
		server.load_configuration()
	else:
		# What a launch with no file would have ended on, without the warning that
		# reading a missing file logs. Saving is unavoidable, so the file goes again.
		server.set_environment(1)
		DirAccess.remove_absolute(ServerManagerClass.CONFIG_PATH)


func _write_config(custom_url: String) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("environment", "current", 1)
	config.set_value("environment", "custom_url", custom_url)
	config.set_value("network", "proxy_host", "")
	config.set_value("network", "proxy_port", 0)
	config.set_value("network", "proxy_enabled", false)
	config.set_value(MARKER_SECTION, MARKER_KEY, true)
	assert_eq(config.save(ServerManagerClass.CONFIG_PATH), OK)


func _read_back() -> ConfigFile:
	var config: ConfigFile = ConfigFile.new()
	assert_eq(config.load(ServerManagerClass.CONFIG_PATH), OK)
	return config


func test_an_unchanged_file_is_not_written_back_at_launch() -> void:
	_write_config("")

	(ServerManager as ServerManagerClass).load_configuration()

	assert_true(_read_back().has_section_key(MARKER_SECTION, MARKER_KEY),
		"a rewrite would have dropped the key the node does not know about")


func test_a_custom_url_the_read_normalises_is_saved_in_its_normal_form() -> void:
	_write_config("https://example.test/api")

	(ServerManager as ServerManagerClass).load_configuration()

	var written: ConfigFile = _read_back()
	assert_eq(str(written.get_value("environment", "custom_url", "")), "https://example.test/api/")
	assert_false(written.has_section_key(MARKER_SECTION, MARKER_KEY),
		"the file should have been rewritten from the node's fields")


func test_a_missing_file_is_created_on_prod() -> void:
	DirAccess.remove_absolute(ServerManagerClass.CONFIG_PATH)

	(ServerManager as ServerManagerClass).load_configuration()

	assert_eq(int(_read_back().get_value("environment", "current", -1) as int), 1)
	# The missing file is logged as a warning, which is expected here. This must run
	# inside the test: GUT checks for unhandled errors before after_each.
	for tracked_error: GutTrackedError in get_errors():
		tracked_error.handled = true
