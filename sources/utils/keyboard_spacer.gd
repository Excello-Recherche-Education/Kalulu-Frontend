extends MarginContainer
class_name KeyboardSpacer

var screen_scale: float

func _ready():
	screen_scale = DisplayServer.screen_get_scale()


func _process(delta):
	if OS.has_feature("mobile"):
		var margin = DisplayServer.virtual_keyboard_get_height()
		if OS.get_name() == "Android":
			margin *= screen_scale
		self["theme_override_constants/margin_bottom"] = max(floori(margin), 0)
