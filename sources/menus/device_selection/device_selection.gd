extends Control

# Namespace
const DeviceButton:= preload("res://sources/menus/main/device_button.gd")
const device_button_scene: PackedScene = preload("res://sources/menus/main/device_button.tscn")

const login_scene_path: String = "res://sources/menus/login/login.tscn"

@export var colors: Array[Color] = []

@onready var container: GridContainer = %GridContainer

func _ready() -> void:
	_refresh()

func _refresh() -> void:
	if not UserDataManager.teacher_settings:
		return
	
	for child: Node in container.get_children():
		child.queue_free()
	
	for device: int in UserDataManager.teacher_settings.students.keys():
		var button: DeviceButton = device_button_scene.instantiate()
		button.number = device
		button.background_color = colors[device-1 % colors.size()]
		container.add_child(button)
		button.pressed.connect(_device_button_pressed.bind(device))
	OpeningCurtain.open()

func _device_button_pressed(device: int) -> void:
	Logger.trace("DeviceSelection: User selected device %d" % device)
	if UserDataManager.set_device_id(device):
		get_tree().change_scene_to_file(login_scene_path)
