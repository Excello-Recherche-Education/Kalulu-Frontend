extends Control

signal button_pressed

@onready var buttons: GridContainer = %Buttons
@onready var sound_player := $ButtonSoundPlayer

func _ready():
	for button in buttons.get_children(false):
		button.connect("pressed", _on_button_pressed.bind(button))

func _on_button_pressed(button : TextureButton):
	sound_player.play()
	
	button.set_modulate(Color(0.5,0.5,0.5))
	button.set_disabled(true)
	
	emit_signal("button_pressed", button.name)

func reset_buttons():
	for button in buttons.get_children(false):
		button.set_modulate(Color(1,1,1))
		button.set_disabled(false)
