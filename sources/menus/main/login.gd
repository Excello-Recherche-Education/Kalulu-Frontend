extends Control

signal logged_in

@onready var teacher_label : Label = %TeacherLabel
@onready var parent_label : Label = %ParentLabel
@onready var validator : FormValidator = %LoginFormValidator
@onready var email_field : LineEdit = %EmailField
@onready var password_field : LineEdit = %PasswordField
@onready var device_id_container : VBoxContainer = %DeviceIDContainer
@onready var device_id_field : SpinBox = %DeviceIDField
@onready var login_message : Label = %LoginError

var account_type: TeacherSettings.AccountType

func _ready() -> void:
	email_field.text_changed.connect(_hide_login_error)
	password_field.text_changed.connect(_hide_login_error)
	device_id_field.value_changed.connect(_hide_login_error)


func show_form(is_teacher : bool) -> void:
	self.show()
	
	if is_teacher:
		device_id_container.show()
		account_type = TeacherSettings.AccountType.Teacher
		teacher_label.show()
		parent_label.hide()
	else:
		device_id_field.value = 1
		device_id_container.hide()
		account_type = TeacherSettings.AccountType.Parent
		teacher_label.hide()
		parent_label.show()


func _hide_login_error(_value: Variant) -> void:
	if login_message.visible:
		login_message.hide()


func _on_login_form_validator_control_validated(control: Control, passed: Variant, messages: PackedStringArray) -> void:
	var label: = find_child(control.name + "Error", true, false) as Label
	if not label:
		return
	if passed:
		label.hide()
	else:
		label.text = ". ".join(messages)
		label.show()


func _on_validate_button_pressed() -> void:
	# Validator
	if not validator.validate():
		return
	
	# Request server for login
	var res: = await ServerManager.login(account_type, int(device_id_field.value), email_field.text, password_field.text)
	if res.code == 200:
		# Login
		if UserDataManager.login(res.body as Dictionary):
			logged_in.emit()
		else:
			login_message.visible = true
	else:
		login_message.visible = true
