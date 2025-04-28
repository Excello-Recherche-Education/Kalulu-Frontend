extends Control
class_name CodeKeyboard

signal button_pressed(key : String, password : Array[String])
signal password_entered(password : String)

const button_sound: AudioStreamMP3 = preload("res://assets/menus/login/ui_play_button.mp3")

@onready var password_visualizer : PasswordVisualizer = %PasswordVisualizer
@onready var buttons: GridContainer = %Buttons
@onready var sound_player: AudioStreamPlayer = $ButtonSoundPlayer

var password : Array[String] = []

func _ready() -> void:
	for button: TextureButton in buttons.get_children(false):
		button.pressed.connect(_on_button_pressed.bind(button))


func _on_button_pressed(button : TextureButton) -> void:
	if password.size() == 3:
		return
	
	# Gets the pressed key
	var key : String = button.name
	password.append(key)
	
	# Sound effect
	sound_player.play()
	
	# Disables button
	button.set_modulate(Color(0.5,0.5,0.5))
	button.set_disabled(true)
	
	# Updates the visualizer
	password_visualizer.password = "".join(password)
	
	# Emit the key pressed signal
	button_pressed.emit(key, password)
	
	# Emit the password entered signal
	if password.size() == 3:
		var code: String = ""
		for char_: String in password:
			code += char_
		password_entered.emit(code)


func get_password() -> Array[String]:
	return password


func get_password_as_string() -> String:
	return "".join(password)


func reset_password() -> void:
	password = []
	
	for button: TextureButton in buttons.get_children(false):
		button.set_modulate(Color(1,1,1))
		button.set_disabled(false)
	
	password_visualizer.password = ""
