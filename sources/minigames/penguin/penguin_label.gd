extends Label
signal pressed(pos: Vector2)

@onready var highlight_fx: HighlightFX = %HighlightFX
@onready var right_fx: RightFX = %RightFX
@onready var wrong_fx: WrongFX = %WrongFX
@onready var button: Button = $Button

var gp: Dictionary
var capitalized: bool = false
var is_pressed: bool = false

func _ready() -> void:
	if gp:
		if capitalized:
			text = (gp.Grapheme as String).capitalize()
		else:
			text = gp.Grapheme


func set_button_enabled(is_enabled: bool) -> void:
	button.disabled = !is_enabled

#region Particles

func right() -> void:
	right_fx.play()
	set("theme_override_colors/font_color",Color.GREEN)
	await right_fx.finished


func wrong() -> void:
	wrong_fx.play()
	set("theme_override_colors/font_color",Color.RED)
	await wrong_fx.finished

func highlight(value: bool = true) -> void:
	if value:
		highlight_fx.play()
	else:
		highlight_fx.stop()

#endregion

func _on_button_pressed() -> void:
	if is_pressed:
		return
	pressed.emit(get_global_mouse_position())
	is_pressed = true
