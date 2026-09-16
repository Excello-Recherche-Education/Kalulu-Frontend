extends GutTest
## Reading the machine's own proxy setting, and deciding whether to offer the field.
##
## The parsers take text rather than running anything, which is what makes them worth
## testing: the platform commands need the platform, but their output is a string and
## every shape below has been seen in the wild. The value they produce is what a
## teacher is shown already filled in, so a parser that quietly returns the wrong
## host is worse than one that returns nothing.

const PROXY_SETTINGS: GDScript = preload("res://sources/ui/proxy_settings.gd")


# --- Every shape a proxy setting is written in -------------------------------------
func test_a_host_and_port_is_the_ordinary_case() -> void:
	assert_eq(SystemProxy.parse("proxy.ac-normandie.fr:3128"),
		{"host": "proxy.ac-normandie.fr", "port": 3128})


func test_a_full_url_is_stripped_back_to_the_pair() -> void:
	assert_eq(SystemProxy.parse("http://proxy.ecole.fr:8080/"),
		{"host": "proxy.ecole.fr", "port": 8080})


func test_credentials_in_the_url_are_dropped_rather_than_carried() -> void:
	# They belong to whoever configured the machine. Keeping them would copy a
	# password out of the OS keystore into a plain file in the user directory.
	assert_eq(SystemProxy.parse("http://alice:secret@proxy.ecole.fr:8080"),
		{"host": "proxy.ecole.fr", "port": 8080})


func test_a_bare_hostname_is_given_the_usual_proxy_port() -> void:
	# 8080 and not 80: a hostname written in a proxy setting is a proxy, not a
	# web server.
	assert_eq(SystemProxy.parse("proxy.ecole.fr"),
		{"host": "proxy.ecole.fr", "port": SystemProxy.DEFAULT_PORT})


func test_windows_scheme_lists_are_read_https_first() -> void:
	# Windows stores one entry per scheme when they differ, and HTTPS is what Kalulu
	# speaks -- taking the first entry would send it through the plain-HTTP proxy.
	assert_eq(SystemProxy.parse("http=proxy-a.ecole.fr:3128;https=proxy-b.ecole.fr:3129"),
		{"host": "proxy-b.ecole.fr", "port": 3129})


func test_an_http_only_list_is_still_better_than_nothing() -> void:
	assert_eq(SystemProxy.parse("http=proxy.ecole.fr:3128"),
		{"host": "proxy.ecole.fr", "port": 3128})


func test_nonsense_is_refused_rather_than_guessed_at() -> void:
	for value: String in ["", "   ", "://", "proxy.ecole.fr:0", "proxy.ecole.fr:99999"]:
		assert_eq(SystemProxy.parse(value), {}, "'%s' is not a proxy" % value)


# --- What the operating systems actually print --------------------------------------
func test_macos_is_read_only_when_the_proxy_is_switched_on() -> void:
	# The host stays in the dictionary after the proxy is turned off, so reading it
	# alone would offer a proxy the machine has stopped using.
	var enabled: String = """<dictionary> {
HTTPSEnable : 1
HTTPSProxy : proxy.ecole.fr
HTTPSPort : 3128
}"""
	assert_eq(SystemProxy.parse_scutil(enabled), "proxy.ecole.fr:3128")

	var disabled: String = """<dictionary> {
HTTPSEnable : 0
HTTPSProxy : proxy.ecole.fr
HTTPSPort : 3128
}"""
	assert_eq(SystemProxy.parse_scutil(disabled), "")


func test_a_mac_with_no_proxy_at_all_reads_as_none() -> void:
	# The shape this machine prints, and the shape most of them print.
	assert_eq(SystemProxy.parse_scutil("""<dictionary> {
ExceptionsList : <array> {
	0 : *.local
}
FTPPassive : 1
}"""), "")


func test_windows_is_read_only_when_the_proxy_is_switched_on() -> void:
	var enabled: String = """
HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings
	ProxyEnable    REG_DWORD    0x1
	ProxyServer    REG_SZ    proxy.ecole.fr:3128
"""
	assert_eq(SystemProxy.parse_windows_registry(enabled), "proxy.ecole.fr:3128")
	assert_eq(SystemProxy.parse_windows_registry(enabled.replace("0x1", "0x0")), "",
		"a proxy switched off for the day is not a proxy to use")


func test_the_environment_is_asked_for_each_name_in_turn() -> void:
	var fake: Dictionary = {"http_proxy": "proxy.ecole.fr:3128"}
	var getter: Callable = func(key: String) -> String: return str(fake.get(key, ""))
	assert_eq(SystemProxy.from_environment(getter), "proxy.ecole.fr:3128")

	var empty: Callable = func(_key: String) -> String: return ""
	assert_eq(SystemProxy.from_environment(empty), "")


func test_https_wins_over_http_in_the_environment_too() -> void:
	var fake: Dictionary = {
		"http_proxy": "plain.ecole.fr:3128", "https_proxy": "secure.ecole.fr:3129"}
	var getter: Callable = func(key: String) -> String: return str(fake.get(key, ""))
	assert_eq(SystemProxy.from_environment(getter), "secure.ecole.fr:3129")


# --- When the field is shown at all --------------------------------------------------
func test_the_field_stays_hidden_on_a_machine_with_no_proxy_and_no_proxy_shaped_failure() -> void:
	# The default, and the case that matters most: a box labelled "server address"
	# under a failure message is an invitation to type something into it, and typing
	# something into it is how a working connection gets broken.
	for cause: int in [ServerManagerClass.ConnectionFailure.NONE,
			ServerManagerClass.ConnectionFailure.NO_NETWORK,
			ServerManagerClass.ConnectionFailure.DNS_FILTERED,
			ServerManagerClass.ConnectionFailure.CLOCK_SKEW]:
		assert_false(ServerManagerClass.proxy_is_worth_offering(cause, false, false),
			"%s is not answered by a proxy" % ServerManagerClass.ConnectionFailure.keys()[cause])


func test_the_field_appears_for_the_failures_a_proxy_could_explain() -> void:
	for cause: int in [ServerManagerClass.ConnectionFailure.KALULU_BLOCKED,
			ServerManagerClass.ConnectionFailure.TLS_INTERCEPTED,
			ServerManagerClass.ConnectionFailure.PROXY_REQUIRED,
			ServerManagerClass.ConnectionFailure.PROXY_AVAILABLE]:
		assert_true(ServerManagerClass.proxy_is_worth_offering(cause, false, false),
			"%s could be a proxy" % ServerManagerClass.ConnectionFailure.keys()[cause])


func test_a_machine_that_has_a_proxy_is_always_shown_the_field() -> void:
	# There is something true to say and something already filled in, whatever the
	# failure turned out to be.
	assert_true(ServerManagerClass.proxy_is_worth_offering(
		ServerManagerClass.ConnectionFailure.NO_NETWORK, true, false))


func test_a_proxy_already_in_use_can_always_be_switched_off_again() -> void:
	# Otherwise a proxy accepted once and later removed from the network leaves the
	# app permanently unable to connect, with no control anywhere to undo it.
	assert_true(ServerManagerClass.proxy_is_worth_offering(
		ServerManagerClass.ConnectionFailure.NO_NETWORK, false, true))


# --- What the field reads and writes --------------------------------------------------
func test_the_field_shows_the_pair_the_way_it_reads_it_back() -> void:
	# Round trip, because the field is both filled in by us and typed into by a
	# teacher, and the two have to agree on the shape.
	var written: String = PROXY_SETTINGS._format("proxy.ecole.fr", 3128)
	assert_eq(written, "proxy.ecole.fr:3128")
	assert_eq(SystemProxy.parse(written), {"host": "proxy.ecole.fr", "port": 3128})


func test_no_proxy_shows_an_empty_field_rather_than_a_placeholder_pair() -> void:
	assert_eq(PROXY_SETTINGS._format("", 0), "")


# --- The setting has to survive the next launch --------------------------------------
func test_a_saved_proxy_is_still_on_disk_after_the_configuration_is_read_back() -> void:
	# The environment and the proxy share one file, and reading the environment saves
	# it. Read in the wrong order, the save writes the proxy back at its defaults: the
	# launch that does it notices nothing -- the values it uses came out of the copy
	# already in memory -- and the next one comes up with no proxy at all, on exactly
	# the machines that cannot connect without one.
	var server: ServerManagerClass = ServerManager as ServerManagerClass
	var saved_host: String = server.proxy_host
	var saved_port: int = server.proxy_port
	var saved_enabled: bool = server.proxy_enabled

	server.set_proxy("proxy.ecole.fr", 3128, true)
	# A fresh launch, which is the only situation the bug shows in: the members are at
	# their defaults and the file is the only place the proxy still exists. With them
	# already filled in, the save during the read writes the right values by accident
	# and the test cannot fail.
	server.proxy_host = ""
	server.proxy_port = 0
	server.proxy_enabled = false
	server.load_configuration()

	assert_eq(server.proxy_host, "proxy.ecole.fr", "it should come back into the node")
	assert_eq(server.proxy_port, 3128)
	assert_true(server.proxy_enabled)

	var written: ConfigFile = ConfigFile.new()
	assert_eq(written.load(ServerManagerClass.CONFIG_PATH), OK)
	assert_eq(str(written.get_value("network", "proxy_host", "")), "proxy.ecole.fr",
		"and it should still be in the file the next launch will read")
	assert_true(bool(written.get_value("network", "proxy_enabled", false)))

	server.set_proxy(saved_host, saved_port, saved_enabled)


# --- Every way out of the app has to take the same route -------------------------------
func test_the_language_pack_download_is_routed_through_the_proxy_too() -> void:
	# Structural, because Godot offers no way to read a proxy back off an HTTPRequest.
	# The pack is an archive of tens of megabytes fetched straight from S3 through the
	# download screen's own node, so ServerManager applying the proxy to its own two
	# requests is not enough: the API would answer through the proxy while the pack
	# alone kept failing directly, and a fresh install with nothing on disk would have
	# nowhere to go.
	var source: String = FileAccess.get_file_as_string(
			"res://sources/menus/language_selection/package_downloader.gd")
	assert_false(source.is_empty(), "the download screen should be readable")
	var applied: int = source.find("apply_proxy_to(http_request)")
	var requested: int = source.find("http_request.request(")
	assert_ne(applied, -1, "the pack download should be put on the proxy as well")
	assert_true(applied < requested,
		"and before the request, not after it")


# --- What counts as the proxy working ------------------------------------------------
func test_a_proxy_is_only_trusted_when_the_answer_is_ours() -> void:
	# The damaging case, and the reason this is not just a status-code check: a
	# filtering proxy or a captive portal answers 200 with its own HTML for any
	# address. Believed, it gets switched on and written to disk, and from then on
	# every API call comes back as that page -- a successful code over an empty body,
	# read as a server error, which is not a network message and therefore hides the
	# one control that could undo it.
	assert_true(ServerManagerClass.proxy_probe_succeeded(
		HTTPRequest.RESULT_SUCCESS, 200, '{"status": "ok"}'))
	assert_false(ServerManagerClass.proxy_probe_succeeded(
		HTTPRequest.RESULT_SUCCESS, 200, "<html><body>Access blocked</body></html>"),
		"a block page is not the server answering")
	assert_false(ServerManagerClass.proxy_probe_succeeded(
		HTTPRequest.RESULT_SUCCESS, 200, ""),
		"and neither is nothing at all")
	assert_false(ServerManagerClass.proxy_probe_succeeded(
		HTTPRequest.RESULT_CANT_CONNECT, 0, ""))
	assert_false(ServerManagerClass.proxy_probe_succeeded(
		HTTPRequest.RESULT_SUCCESS, 407, "proxy authentication required"))


func test_a_colon_with_no_number_after_it_is_a_mistake_and_not_a_hostname() -> void:
	# It used to leave the whole value as the host: "proxy.ecole.fr:abc" was accepted,
	# saved, and dialled as a machine of that name -- a typo that came back as an
	# unexplained connection failure instead of the message under the field.
	for value: String in ["proxy.ecole.fr:abc", "proxy.ecole.fr:", "proxy.ecole.fr:80a"]:
		assert_eq(SystemProxy.parse(value), {}, "'%s' names no port" % value)


func test_a_bracketed_address_keeps_the_colons_that_are_its_own() -> void:
	# Only the colon after the bracket can be a port.
	assert_eq(SystemProxy.parse("[::1]:3128"), {"host": "[::1]", "port": 3128})


func test_gnome_is_only_read_when_it_says_a_proxy_is_in_use() -> void:
	# The manual host stays in the settings after the mode is switched to "none", so
	# reading it alone finds an address the user explicitly turned off -- and after any
	# direct failure Kalulu would switch it on and write it to disk. The same pairing
	# the macOS and Windows readers already do.
	assert_eq(SystemProxy.parse_gnome("'manual'", "'secure.ecole.fr'", "3129",
		"'plain.ecole.fr'", "3128"), "secure.ecole.fr:3129")
	assert_eq(SystemProxy.parse_gnome("'none'", "'secure.ecole.fr'", "3129",
		"'plain.ecole.fr'", "3128"), "", "switched off is switched off")
	assert_eq(SystemProxy.parse_gnome("'auto'", "'secure.ecole.fr'", "3129",
		"'plain.ecole.fr'", "3128"), "",
		"auto names a configuration script, which nothing here can run")
	assert_eq(SystemProxy.parse_gnome("'manual'", "''", "0", "''", "0"), "",
		"manual with no host is no proxy either")
	assert_eq(SystemProxy.parse_gnome("'manual'", "'secure.ecole.fr'", "0", "''", "0"),
		"secure.ecole.fr", "and a port of zero is no port at all")


func test_gnome_s_secure_proxy_is_the_one_this_app_needs() -> void:
	# GNOME keeps a setting per scheme and every address Kalulu speaks to is https, so
	# reading the http one finds the wrong server where the two differ and nothing at
	# all where only the secure one is set. The same preference the macOS reader and
	# the environment reader already apply.
	assert_eq(SystemProxy.parse_gnome("'manual'", "'secure.ecole.fr'", "3129",
		"'plain.ecole.fr'", "3128"), "secure.ecole.fr:3129",
		"the secure one wins where both are set")
	assert_eq(SystemProxy.parse_gnome("'manual'", "''", "0", "'plain.ecole.fr'", "3128"),
		"plain.ecole.fr:3128",
		"and the http one still serves where it is the only one configured")
