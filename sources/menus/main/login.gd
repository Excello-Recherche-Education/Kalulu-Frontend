extends Control

@onready var language_field : OptionButton = $LanguageField
@onready var email_field : LineEdit = $EmailField
@onready var password_field : LineEdit = $PasswordField
@onready var device_id_field : LineEdit = $DeviceIDField

@onready var error_message : Label = $ErrorMessage

func _on_validate_button_pressed() -> void:
	
	# Check if all the values are given
	if not email_field.text or not password_field.text or not device_id_field.text:
		error_message.visible = true
		return
	
	# TODO Check login and password
	
	# Login
	UserDataManager.login(language_field.get_selected_language(), email_field.text, device_id_field.text)
	
	# TODO Load next scene
