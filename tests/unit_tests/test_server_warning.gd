extends GutTest
## The warning shown when the app is not on the production server, and the way back.
##
## A teacher whose device had been switched to DEV took it for an account that had
## disappeared, because nothing on screen said which server was in use. These hold the
## warning to the address actually in force, and the reset to forgetting a custom URL --
## the custom URL is what decides, so a reset that kept it would change nothing.

const SERVER_WARNING_SCENE: PackedScene = preload("res://sources/ui/server_warning.tscn")
const DEV_URL: String = "https://dev.api.kalulu.org/dev/"

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
		server.load_configuration()
	else:
		server.set_environment(1)
		DirAccess.remove_absolute(ServerManagerClass.CONFIG_PATH)


func _warning() -> ServerWarning:
	var warning: ServerWarning = SERVER_WARNING_SCENE.instantiate()
	add_child_autofree(warning)
	return warning


func test_only_the_production_address_counts_as_production() -> void:
	var prod: String = ServerManagerClass.production_url()
	assert_true(ServerManagerClass.is_production_url(prod))
	assert_true(ServerManagerClass.is_production_url(prod.trim_suffix("/")),
		"a trailing slash is not a different server")
	assert_true(ServerManagerClass.is_production_url(" " + prod.to_upper() + " "),
		"nor is the case of a hand-typed address")
	assert_false(ServerManagerClass.is_production_url(DEV_URL))
	assert_false(ServerManagerClass.is_production_url("https://example.test/prod/"))
	assert_false(ServerManagerClass.is_production_url(""))


func test_a_custom_url_over_the_prod_setting_is_not_production() -> void:
	var server: ServerManagerClass = ServerManager as ServerManagerClass
	server._apply_environment(1, "https://example.test/prod/")

	assert_false(server.is_on_production())


func test_reset_forgets_the_custom_url_and_saves_prod() -> void:
	var server: ServerManagerClass = ServerManager as ServerManagerClass
	server.set_environment(0, "https://example.test/api/")

	server.reset_to_production()

	assert_true(server.is_on_production())
	assert_eq(server.custom_environment_url, "")
	var config: ConfigFile = ConfigFile.new()
	assert_eq(config.load(ServerManagerClass.CONFIG_PATH), OK)
	assert_eq(int(config.get_value("environment", "current", -1) as int), 1)
	assert_eq(str(config.get_value("environment", "custom_url", "?")), "")


func test_the_warning_is_hidden_on_production() -> void:
	(ServerManager as ServerManagerClass)._apply_environment(1, "")

	assert_false(_warning().visible)


func test_the_warning_names_the_server_in_use_off_production() -> void:
	(ServerManager as ServerManagerClass)._apply_environment(0, "")

	var warning: ServerWarning = _warning()

	assert_true(warning.visible)
	assert_eq(warning.address_label.text, "dev.api.kalulu.org")


func test_resetting_a_signed_out_device_goes_back_to_production_and_hides() -> void:
	if EntryFlow.has_connection_token():
		pending("this device is signed in, where the reset asks for an adult first")
		return
	(ServerManager as ServerManagerClass)._apply_environment(0, "")
	var warning: ServerWarning = _warning()

	warning.reset_button.pressed.emit()

	assert_true((ServerManager as ServerManagerClass).is_on_production())
	assert_false(warning.visible)
