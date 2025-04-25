extends Step

@onready var conditions_label : RichTextLabel = %ConditionsLabel
@onready var accept : CheckBox = %Accept
@onready var accept_error : Label = %AcceptError


func _on_back() -> bool:
	accept.button_pressed = false
	return true


func _on_next() -> bool:
	if not accept.button_pressed:
		accept_error.show()
		return false
	return true


func _on_validate_button_pressed() -> void:
	if _on_next():
		next.emit(self)


func _on_accept_pressed() -> void:
	accept_error.hide()
