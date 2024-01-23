extends Control

signal logged_in

@onready var language_field : OptionButton = $Form/LanguageField
@onready var email_field : LineEdit = $Form/EmailField
@onready var password_field : LineEdit = $Form/PasswordField
@onready var device_id_field : SpinBox = $Form/DeviceIDField

@onready var field_missing_message : Label = $Form/FieldMissingError
@onready var login_message : Label = $Form/LoginError

func _on_validate_button_pressed() -> void:
	
	# Check if all the values are given
	if not email_field.text or not password_field.text or not device_id_field.value:
		field_missing_message.visible = true
		return
	
	# TODO Check login and password
	
	# Login
	if UserDataManager.login(language_field.get_selected_language(), email_field.text, password_field.text, device_id_field.value):
		logged_in.emit()
	else:
		login_message.visible = true
