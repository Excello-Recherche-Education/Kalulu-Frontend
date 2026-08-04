extends Control
## The single entry screen: log in, or prove you are an adult and register.
##
## Replaces the old two-step entry, where the main menu hid the form behind a
## Play button and sign-up lived in a separate adult_check scene. Both are now
## one screen behind a Login | Sign Up switch, which is the point of the
## redesign: fewer screens between opening the app and having an account.
##
## The adult check is the same challenge as before -- reproduce three named
## symbols, in order -- just inline on the Sign Up tab instead of on its own
## scene.

const LANGUAGE_CHECK_SCENE_PATH: String = "res://sources/menus/language_selection/language_check.tscn"
const REGISTER_SCENE_PATH: String = "res://sources/menus/register/register.tscn"
const LOGIN_TAB: int = 0
const SIGN_UP_TAB: int = 1

var adult_challenge: AdultChallenge = AdultChallenge.new()
## True while a request to the server is outstanding.
##
## ServerManager owns one HTTPRequest and one set of result fields, and every
## caller awaits the same request_completed signal. A second request started
## before the first answers is refused as busy, resets the result the first one is
## waiting on, and leaves both reading whichever reply arrives -- so a perfectly
## good login can come back as a server error. Disabling the button was not
## enough: the password field still submits on Enter.
var request_in_flight: bool = false

@onready var toggle: SegmentedToggle = %Toggle
@onready var login_panel: FormValidator = %LoginPanel
@onready var sign_up_panel: Control = %SignUpPanel
@onready var email_field: MenuTextField = %EmailField
@onready var password_field: MenuTextField = %PasswordField
@onready var login_error: Label = %LoginError
@onready var reset_password_button: Button = %ResetPasswordButton
@onready var next_button: Button = %NextButton
@onready var adult_prompt: Label = %AdultPrompt
@onready var keypad: CodeKeypad = %Keypad


func _ready() -> void:
	Log.info("Welcome: Loaded")
	# Declared here rather than in the scene: the typed-array-of-rule-resources
	# syntax is easy to get subtly wrong in a .tscn, and MenuTextField rebuilds
	# its validator when `rules` is assigned.
	email_field.rules = [RequiredRule.new(), EmailRule.new()]
	password_field.rules = [RequiredRule.new()]

	toggle.selection_changed.connect(_on_tab_changed)
	next_button.pressed.connect(_on_next_pressed)
	reset_password_button.pressed.connect(_on_reset_password_pressed)
	email_field.text_changed.connect(_clear_login_error)
	password_field.text_changed.connect(_clear_login_error)
	password_field.text_submitted.connect(_on_password_submitted)
	keypad.code_entered.connect(_on_adult_code_entered)

	_new_adult_challenge()
	_show_tab(LOGIN_TAB)
	OpeningCurtain.open()


func _show_tab(tab: int) -> void:
	login_panel.visible = tab == LOGIN_TAB
	sign_up_panel.visible = tab == SIGN_UP_TAB
	# The keypad completing is itself the action to take, so the Sign Up tab has
	# no Next button -- matching the mockups.
	next_button.visible = tab == LOGIN_TAB


func _on_tab_changed(index: int) -> void:
	Log.trace("Welcome: Switched to %s tab" % ("login" if index == LOGIN_TAB else "sign up"))
	_hide_login_error()
	if index == SIGN_UP_TAB:
		# A fresh challenge each visit, so the answer cannot be memorised from a
		# previous attempt.
		_new_adult_challenge()
	_show_tab(index)


# --- Login -------------------------------------------------------------------
func _on_password_submitted(_text: String) -> void:
	_on_next_pressed()


func _on_next_pressed() -> void:
	if request_in_flight:
		Log.trace("Welcome: Ignoring a login while one is already in flight")
		return
	if not login_panel.validate():
		Log.info("Welcome: Login form did not validate")
		return

	request_in_flight = true
	next_button.disabled = true
	Log.info("Welcome: Sending login request for %s" % email_field.text)
	var response: Dictionary = await ServerManager.login(email_field.text, password_field.text)
	if response.code != 200:
		Log.info("Welcome: Server refused login with code %d" % response.code)
		_show_login_error(_translation_key_for_error(response))
		_end_request()
		return

	if not UserDataManager.login(response.body as Dictionary):
		Log.info("Welcome: UserDataManager rejected the server response")
		_show_login_error("LOGIN_SERVER_ERROR")
		_end_request()
		return

	Log.info("Welcome: Login successful, synchronizing")
	# On a fresh install the language pack is not downloaded yet, and the
	# progression the server returns can only be read against its lesson count.
	# synchronize() postpones itself in that case and the login screen runs it
	# once the package downloader has opened the database.
	await UserDataManager.user_database_synchronizer.synchronize()
	await OpeningCurtain.close()
	var error: Error = get_tree().change_scene_to_file(LANGUAGE_CHECK_SCENE_PATH)
	if error != OK:
		Log.error(error_string(error))
		_end_request()


## Lets the screen be used again after a request has finished.
func _end_request() -> void:
	request_in_flight = false
	next_button.disabled = false


func _show_login_error(translation_key: String) -> void:
	login_error.text = translation_key
	login_error.show()
	# Only offered once a login has actually failed on the password, which is the
	# one failure a reset can fix: an unknown account, a network drop or a server
	# error are not helped by resetting, and the network cases could not send the
	# mail anyway.
	reset_password_button.visible = translation_key == "LOGIN_WRONG_PASSWORD"
	reset_password_button.disabled = false


func _hide_login_error() -> void:
	login_error.hide()
	reset_password_button.hide()
	reset_password_button.disabled = false


func _clear_login_error(_text: String) -> void:
	if login_error.visible:
		_hide_login_error()


func _translation_key_for_error(response: Dictionary) -> String:
	# A network failure never gets an HTTP response, so ServerManager leaves the
	# code at 0.
	if response.code == 0:
		return "LOGIN_NETWORK_ERROR"

	var body: Dictionary = (response.body as Dictionary) if response.body is Dictionary else {}
	match str(body.get("error_code", "")):
		"USER_NOT_FOUND":
			return "LOGIN_USER_NOT_FOUND"
		"INVALID_PASSWORD":
			return "LOGIN_WRONG_PASSWORD"
		"MISSING_CREDENTIALS":
			return "LOGIN_MISSING_CREDENTIALS"
		"SERVER_ERROR", "BAD_REQUEST":
			return "LOGIN_SERVER_ERROR"

	if response.code >= 500:
		return "LOGIN_SERVER_ERROR"
	return "INVALID_EMAIL_OR_PASSWORD"


func _on_reset_password_pressed() -> void:
	# Reachable only after the form validated and the server replied "wrong
	# password", so the address is known good and needs no checking here.
	if request_in_flight:
		Log.trace("Welcome: Ignoring a reset while a request is already in flight")
		return

	Log.info("Welcome: Password reset requested for %s" % email_field.text)
	request_in_flight = true
	reset_password_button.disabled = true
	var response: Dictionary = await ServerManager.reset_password(email_field.text)
	if response.code != 200:
		Log.warn("Welcome: Password reset failed with code %d" % response.code)
		login_error.text = "RESET_PASSWORD_FAILED"
		login_error.show()
		_end_request()
		return
	Log.info("Welcome: Password reset accepted")
	login_error.text = "CHECK_YOUR_EMAIL"
	login_error.show()
	# The button stays disabled: the mail has been sent, and asking again would
	# only send another.
	request_in_flight = false


# --- Sign up (adult check) ---------------------------------------------------
func _new_adult_challenge() -> void:
	adult_challenge.renew()
	adult_prompt.text = adult_challenge.prompt("ADULT_CHECK_PROMPT")
	if is_node_ready():
		keypad.clear()


func _on_adult_code_entered(code: String) -> void:
	if not adult_challenge.accepts(code):
		Log.info("Welcome: Adult check failed")
		_new_adult_challenge()
		return

	Log.info("Welcome: Adult check passed, going to registration")
	await OpeningCurtain.close()
	var error: Error = get_tree().change_scene_to_file(REGISTER_SCENE_PATH)
	if error != OK:
		Log.error(error_string(error))
