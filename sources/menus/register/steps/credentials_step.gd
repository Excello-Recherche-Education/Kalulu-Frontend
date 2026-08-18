@tool
extends Step

@onready var api_email_field_error: Label = %APIEmailFieldError


func _on_validate_button_pressed() -> void:
	api_email_field_error.hide()
	
	# Validate the fields
	if not form_validator.validate():
		Log.warn("CredentialsStep: Validation failed (" + str(self) + "). Validator messages = %s" % form_validator.get_messages())
		return
	
	# Writes data in object
	if not form_binder.write():
		Log.warn("CredentialsStep: Impossible to write data in object (" + str(self) + ")")
		return
	
	var res: Dictionary = await ServerManager.check_email((data as TeacherSettings).email as String)
	if res.code != 200:
		api_email_field_error.show()
		return
	
	if _on_next():
		next.emit(self)
