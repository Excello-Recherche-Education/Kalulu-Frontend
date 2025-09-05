class_name KeyboardSpacer
extends MarginContainer

var screen_scale: float
var last_margin: int = -1


func _ready() -> void:
	screen_scale = DisplayServer.screen_get_scale()
	set_process(OS.has_feature("mobile"))


func _process(_delta: float) -> void:
	var margin: int = DisplayServer.virtual_keyboard_get_height()
	if OS.get_name() == "Android":
		margin = int(margin * screen_scale)
	margin = maxi(floori(margin), 0)
	if margin != last_margin:
		self["theme_override_constants/margin_bottom"] = margin
		last_margin = margin
