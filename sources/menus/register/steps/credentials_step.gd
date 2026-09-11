@tool
class_name CredentialsStep
extends Step

@onready var api_email_field_error: Label = %APIEmailFieldError


## Whether the server's answer is about this address, or about getting to the server.
##
## 400 is the only one the backend uses for the address itself -- already registered,
## or malformed. Every other answer, and every non-answer, says nothing about it, and
## they all used to end up under the field as "already used": a blocked network sent
## teachers off to invent a second address, and a third, each failing the same way.
static func is_about_the_address(code: int) -> bool:
	return code == 400


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
	if is_about_the_address(res.code as int):
		# The address is taken, or malformed: the field's own problem, and the one this
		# message was written for.
		api_email_field_error.show()
		return
	if res.code != 200:
		# Anything else is the network or the server, and neither says a word about
		# this address. Claiming it was already used -- which is what every non-200
		# used to do here -- sends the teacher off to invent a second address, and a
		# third, each failing the same way.
		Log.warn("CredentialsStep: Could not check the email address, code %d" % res.code)
		request_failed.emit(res.code as int)
		return
	
	if _on_next():
		next.emit(self)
