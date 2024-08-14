extends Control

@onready var button: Button = $Button


func _on_button_pressed():
	var res = await ServerManager.login("sarrazyndylan@gmail.com", "kalulu")
	print(res)
