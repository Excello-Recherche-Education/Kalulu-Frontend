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
			await UserDataManager.user_database_synchronizer.synchronize()
			logged_in.emit()
		else:
			Log.info("Login: UserDataManager rejected server response during login")
			login_message.show()
			reset_password_button.show()
	else:
		Log.info("Login: Server responded with code %d for login attempt with email %s" % [res.code, email_field.text])
		login_message.show()
		reset_password_button.show()


func _on_reset_password_button_pressed() -> void:
	Log.info("Login: Reset password requested for email %s" % email_field.text)
	var res: Dictionary = await ServerManager.reset_password(email_field.text)
	if res.code != 200:
		Log.warn("Login: Reset password request failed with code %d" % res.code)
		login_message.text = "CHECK_YOUR_EMAIL"
	else:
		Log.info("Login: Reset password request accepted by server")
