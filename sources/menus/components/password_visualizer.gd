@tool
class_name PasswordVisualizer
extends HBoxContainer

const ICONS_TEXTURES: Dictionary[String, CompressedTexture2D] = {
	"1": preload("res://assets/menus/login/symbol_01.png"),
	"2": preload("res://assets/menus/login/symbol_02.png"),
	"3": preload("res://assets/menus/login/symbol_03.png"),
	"4": preload("res://assets/menus/login/symbol_04.png"),
	"5": preload("res://assets/menus/login/symbol_05.png"),
	"6": preload("res://assets/menus/login/symbol_06.png")
}

@export var key_size: int = 200:
	set(value):
		key_size = value
		for icon: TextureRect in icons:
			icon.custom_minimum_size.x = key_size
			icon.custom_minimum_size.y = key_size
@export var password: String:
	set(value):
		password = value
		_draw_password()
@export var show_backgrounds: bool = true:
	set(value):
		show_backgrounds = value
		_update_panel_styles()
@export var panel_theme_variation: StringName = &"PanelKalulu":
	set(value):
		panel_theme_variation = value
		_update_panel_styles()

@onready var icons: Array[TextureRect] = []
@onready var panels: Array[PanelContainer] = []


func _ready() -> void:
	_draw_password()
	_update_panel_styles()
	for icon: TextureRect in icons:
		icon.custom_minimum_size.x = key_size
		icon.custom_minimum_size.y = key_size


func _draw_password() -> void:
	
	if not icons:
		icons = [%Icon1, %Icon2, %Icon3]
	
	for icon: TextureRect in icons:
		icon.texture = null
	
	if not password:
		return
	
	var index: int = 0
	for value: String in password.split(""):
		if index >= 3:
			Log.error("PasswordVisualizer: A password cannot be more than 3 characters long")
			return
		
		if value in ICONS_TEXTURES:
			icons[index].texture = ICONS_TEXTURES[value]
		index += 1


func _panels_ready() -> void:
	if not panels:
		panels = [%Panel1, %Panel2, %Panel3]


func _update_panel_styles() -> void:
	_panels_ready()

	for panel: PanelContainer in panels:
		if not panel:
			continue
		if show_backgrounds:
			panel.remove_theme_stylebox_override("panel")
			panel.theme_type_variation = panel_theme_variation
		else:
			panel.theme_type_variation = &""
			panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
