extends GutTest
## The proxy panel on screen: when it appears, what it accepts, and what it explains.
##
## The static half of the rule is checked in test_system_proxy.gd. This is the part
## that needs the scene: that the panel is actually wired into both screens that show
## a network failure, that a typed address reaches [ServerManagerClass], and that the
## help button has something to say -- it exists because "proxy" is the one word on
## the panel a teacher cannot be expected to know.

const PROXY_SETTINGS_SCENE: String = "res://sources/ui/proxy_settings.tscn"
const WELCOME_SCENE: String = "res://sources/menus/welcome/welcome.tscn"
const REGISTER_SCENE: String = "res://sources/menus/register/register.tscn"

var panel: ProxySettings
## ServerManager is an autoload and its proxy is written to disk, so a test that set
## one and walked away would leave this machine's Kalulu pointed at a proxy that does
## not exist.
var saved_host: String
var saved_port: int
var saved_enabled: bool
var saved_system_proxy: Dictionary


func before_each() -> void:
	var server: ServerManagerClass = ServerManager as ServerManagerClass
	saved_host = server.proxy_host
	saved_port = server.proxy_port
	saved_enabled = server.proxy_enabled
	saved_system_proxy = server.system_proxy
	# Whether this machine happens to have a proxy must not decide what these assert.
	server.system_proxy = {}
	server.set_proxy("", 0, false)

	panel = (load(PROXY_SETTINGS_SCENE) as PackedScene).instantiate() as ProxySettings
	add_child_autofree(panel)
	await get_tree().process_frame


func after_each() -> void:
	var server: ServerManagerClass = ServerManager as ServerManagerClass
	server.system_proxy = saved_system_proxy
	server.set_proxy(saved_host, saved_port, saved_enabled)


# --- Whether it is there at all ------------------------------------------------
func test_it_starts_hidden() -> void:
	# Before any diagnosis there is nothing for it to be about.
	assert_false(panel.visible, "nothing has failed yet")


func test_a_failure_a_proxy_cannot_explain_leaves_it_hidden() -> void:
	panel.refresh(ServerManagerClass.ConnectionFailure.CLOCK_SKEW)
	assert_false(panel.visible, "a wrong clock is not a proxy problem")


func test_a_failure_a_proxy_could_explain_brings_it_up_filled_in() -> void:
	var server: ServerManagerClass = ServerManager as ServerManagerClass
	server.proxy_host = "proxy.ecole.fr"
	server.proxy_port = 3128
	panel.refresh(ServerManagerClass.ConnectionFailure.KALULU_BLOCKED)
	assert_true(panel.visible, "a blocked network could be a proxy")
	assert_eq(panel.address_field.text, "proxy.ecole.fr:3128",
		"the address is already there, so there is nothing to type")


func test_filling_it_in_is_not_read_as_switching_it_on() -> void:
	# The checkbox reflects state; setting it with a signal would save a proxy the
	# teacher never asked for, on a connection that may be perfectly fine.
	var server: ServerManagerClass = ServerManager as ServerManagerClass
	server.proxy_host = "proxy.ecole.fr"
	server.proxy_port = 3128
	panel.refresh(ServerManagerClass.ConnectionFailure.KALULU_BLOCKED)
	assert_false(panel.use_proxy.button_pressed)
	assert_false(server.proxy_enabled, "showing the panel must not have set anything")


# --- What it does with what is typed ---------------------------------------------
func test_a_typed_address_reaches_the_server_manager() -> void:
	var server: ServerManagerClass = ServerManager as ServerManagerClass
	watch_signals(panel)
	panel.refresh(ServerManagerClass.ConnectionFailure.KALULU_BLOCKED)
	panel.address_field.text = "proxy.ecole.fr:3128"
	panel.use_proxy.button_pressed = true
	await get_tree().process_frame

	assert_true(server.proxy_enabled)
	assert_eq(server.proxy_host, "proxy.ecole.fr")
	assert_eq(server.proxy_port, 3128)
	assert_signal_emitted(panel, "proxy_changed")


func test_an_address_that_makes_no_sense_is_refused_on_the_field() -> void:
	# Said under the box it is about, rather than in a dialog over it: the correction
	# happens in that box.
	var server: ServerManagerClass = ServerManager as ServerManagerClass
	panel.refresh(ServerManagerClass.ConnectionFailure.KALULU_BLOCKED)
	panel.address_field.text = "://"
	panel.use_proxy.button_pressed = true
	await get_tree().process_frame

	assert_eq(panel.address_field.error, "PROXY_ADDRESS_INVALID")
	assert_false(server.proxy_enabled, "nothing usable was given, so nothing was set")
	assert_false(panel.use_proxy.button_pressed, "and the switch goes back")


func test_switching_it_off_keeps_the_address_for_next_time() -> void:
	# It was hard to obtain. Clearing it with the switch means finding it again.
	var server: ServerManagerClass = ServerManager as ServerManagerClass
	panel.refresh(ServerManagerClass.ConnectionFailure.KALULU_BLOCKED)
	panel.address_field.text = "proxy.ecole.fr:3128"
	panel.use_proxy.button_pressed = true
	await get_tree().process_frame
	panel.use_proxy.button_pressed = false
	await get_tree().process_frame

	assert_false(server.proxy_enabled)
	assert_eq(server.proxy_host, "proxy.ecole.fr", "the address survives the switch")


# --- The help ---------------------------------------------------------------------
func test_the_help_button_explains_the_word_nobody_is_expected_to_know() -> void:
	panel.refresh(ServerManagerClass.ConnectionFailure.KALULU_BLOCKED)
	panel.help_button.pressed.emit()
	await get_tree().process_frame
	assert_true(panel.help_popup.visible, "the help should open")
	assert_eq(panel.help_popup.title_text, "PROXY_HELP_TITLE")
	assert_eq(panel.help_popup.content_text, "PROXY_HELP_BODY")


func test_everything_the_panel_says_is_translated() -> void:
	# A key with no row in the CSV shows the key itself, in capitals, under the field.
	# That has already happened once on the registration screen.
	for key: String in ["USE_PROXY", "PROXY_APPLY", "PROXY_ADDRESS_PLACEHOLDER",
			"PROXY_ADDRESS_INVALID", "PROXY_HELP_TITLE", "PROXY_HELP_BODY"]:
		assert_ne(tr(key), key, "%s is not in kalulu_localization.csv" % key)


func test_the_help_says_what_to_do_when_the_option_is_not_needed() -> void:
	# The likeliest reader is somebody who is not behind a proxy at all and has opened
	# this looking for a fix. Leaving without telling her to leave it alone is how a
	# working connection gets broken.
	var body: String = tr("PROXY_HELP_BODY")
	assert_string_contains(body.to_lower(), "décochée")


# --- There is always a way to switch it back off --------------------------------------
func test_a_proxy_in_use_keeps_its_switch_on_screen_whatever_the_message_says() -> void:
	# A proxy that starts answering with its own pages turns every request into a
	# server error, which is not a network message. Gate the panel on the message
	# alone and the only control that could undo the proxy disappears exactly when it
	# is needed, with no way back.
	var welcome: Control = (load(WELCOME_SCENE) as PackedScene).instantiate()
	add_child_autofree(welcome)
	await get_tree().process_frame

	var server: ServerManagerClass = ServerManager as ServerManagerClass
	welcome._show_login_error("LOGIN_WRONG_PASSWORD")
	assert_false((welcome.get_node("%ProxyPanel") as Control).visible,
		"with no proxy in use it stays out of the way")

	server.set_proxy("proxy.ecole.fr", 3128, true)
	welcome._show_login_error("LOGIN_SERVER_ERROR")
	assert_true((welcome.get_node("%ProxyPanel") as Control).visible,
		"but a proxy in use must always be reachable")


# --- Both screens that show a network failure carry it -----------------------------
func test_the_login_screen_has_one() -> void:
	var welcome: Control = (load(WELCOME_SCENE) as PackedScene).instantiate()
	add_child_autofree(welcome)
	await get_tree().process_frame
	assert_not_null(welcome.get_node_or_null("%ProxyPanel") as ProxySettings,
		"signing in is one of the two places a blocked network stops a teacher")


func test_the_registration_wizard_has_one_too() -> void:
	# The other, and the one that matters more: a blocked network stops registration
	# at the email step, so a notice only reachable at the end is never reached.
	var wizard: Control = (load(REGISTER_SCENE) as PackedScene).instantiate()
	add_child_autofree(wizard)
	await get_tree().process_frame
	assert_not_null(wizard.get_node_or_null("%ProxyPanel") as ProxySettings,
		"creating an account is where this was first reported")
	for step: Step in wizard.current_steps:
		if is_instance_valid(step) and not step.is_inside_tree():
			step.free()
