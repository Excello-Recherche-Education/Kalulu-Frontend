extends Step


@onready var password := %password
@onready var password_confirm := %password_confirm

func _on_validate_button_pressed():
	
	if password.text != password_confirm.text:
		print("Make sure the password is the same in both fields")
		return
	
	super._on_validate_button_pressed()
