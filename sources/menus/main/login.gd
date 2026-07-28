extends Control

signal logged_in()

@onready var validator: FormValidator = %LoginFormValidator
@onready var email_field: LineEdit = %EmailField
@onready var password_field: LineEdit = %PasswordField
@onready var login_message: Label = %LoginError
@onready var device_id_container: VBoxContainer = %DeviceIDContainer
@onready var device_id_field: SpinBox = %DeviceIDField
@onready var reset_password_button: Button = %ResetPasswordButton


func _ready() -> void:
	email_field.text_changed.connect(_hide_login_error)
	password_field.text_changed.connect(_hide_login_error)
	device_id_field.value_changed.connect(_hide_login_error)


func _hide_login_error(_value: Variant) -> void:
	if login_message.is_visible():
		login_message.hide()
		reset_password_button.hide()
		reset_password_button.disabled = false


func _on_login_form_validator_control_validated(control: Control, passed: Variant, messages: PackedStringArray) -> void:
	var label: Label = find_child(control.name + "Error", true, false) as Label
	if not label:
		return
	if passed:
		label.hide()
	else:
		label.text = ". ".join(messages)
		label.show()


func _on_validate_button_pressed() -> void:
	Log.trace("Login: Validate button pressed")
	if not validator.validate():
		Log.info("Login: Validation failed for email %s" % email_field.text)
		return

	# Request server for login
	Log.info("Login: Sending login request for email %s" % email_field.text)
	var res: Dictionary = await ServerManager.login(email_field.text, password_field.text)
	if res.code == 200:
		# Login
		if UserDataManager.login(res.body as Dictionary):
			Log.info("Login: Login successful, synchronizing user data")
			# On a fresh install the language pack is not downloaded yet, and the
			# progression the server sends back can only be read against its lesson
			# count. synchronize() postpones itself in that case and the login
			# screen runs it once the package downloader has opened the database.
			await UserDataManager.user_database_synchronizer.synchronize()
			logged_in.emit()
		else:
			Log.info("Login: UserDataManager rejected server response during login")
			_show_login_error("LOGIN_SERVER_ERROR")
	else:
		Log.info("Login: Server responded with code %d for login attempt with email %s" % [res.code, email_field.text])
		_show_login_error(_translation_key_for_error(res))


func _show_login_error(translation_key: String) -> void:
	login_message.text = translation_key
	login_message.show()
	# Offer password reset only when the email exists and the password is wrong —
	# resetting is useless for any other failure (unknown account, network, server…).
	if translation_key == "LOGIN_WRONG_PASSWORD":
		reset_password_button.disabled = false
		reset_password_button.show()
	else:
		reset_password_button.hide()


func _translation_key_for_error(res: Dictionary) -> String:
	# Network failure: no HTTP response received (code stays 0 in ServerManager).
	if res.code == 0:
		return "LOGIN_NETWORK_ERROR"

	var body: Dictionary = (res.body as Dictionary) if res.body is Dictionary else {}
	var error_code: String = str(body.get("error_code", ""))
	match error_code:
		"USER_NOT_FOUND":
			return "LOGIN_USER_NOT_FOUND"
		"INVALID_PASSWORD":
			return "LOGIN_WRONG_PASSWORD"
		"MISSING_CREDENTIALS":
			return "LOGIN_MISSING_CREDENTIALS"
		"SERVER_ERROR":
			return "LOGIN_SERVER_ERROR"
		"BAD_REQUEST":
			return "LOGIN_SERVER_ERROR"

	if res.code >= 500:
		return "LOGIN_SERVER_ERROR"
	return "INVALID_EMAIL_OR_PASSWORD"


func _on_reset_password_button_pressed() -> void:
	Log.info("Login: Reset password requested for email %s" % email_field.text)
	reset_password_button.disabled = true
	var res: Dictionary = await ServerManager.reset_password(email_field.text)
	if res.code != 200:
		Log.warn("Login: Reset password request failed with code %d" % res.code)
		login_message.text = "RESET_PASSWORD_FAILED"
		login_message.show()
		reset_password_button.disabled = false
	else:
		Log.info("Login: Reset password request accepted by server")
		login_message.text = "CHECK_YOUR_EMAIL"
		login_message.show()
