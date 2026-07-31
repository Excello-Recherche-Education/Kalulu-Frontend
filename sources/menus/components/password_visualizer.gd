@tool
class_name PasswordVisualizer
extends HBoxContainer

signal symbol_pressed(index: int)

## Shows an access code as one coloured chip per symbol.
##
## The artwork is now the bare glyph (Design.code_symbol_texture) and the colour
## comes from Design.code_color, so a code looks the same here as on the keypad.
## Which of the two carries the colour depends on `show_backgrounds`: a chip gets
## a coloured panel and a white glyph, while a code drawn without chips -- the
## printable code sheet -- gets a coloured glyph instead, because a white one on
## white paper is invisible.

## Size of the glyph inside a chip.
@export var key_size: int = 200:
	set(value):
		key_size = value
		for icon: TextureRect in icons:
			icon.custom_minimum_size.x = key_size
			icon.custom_minimum_size.y = key_size
## Size of the chip itself. Zero lets the chips stretch to fill the row, which is
## what the large code displays want; a value pins them, as on a student card.
@export var chip_size: int = 0:
	set(value):
		chip_size = value
		_apply_chip_size()
## Space between chips.
@export var chip_separation: int = 46:
	set(value):
		chip_separation = value
		if is_node_ready():
			add_theme_constant_override("separation", chip_separation)
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
	_panels_ready()
	for panel_index: int in range(panels.size()):
		var panel: PanelContainer = panels[panel_index]
		panel.gui_input.connect(_on_panel_gui_input.bind(panel_index))

	_draw_password()
	_update_panel_styles()
	for icon: TextureRect in icons:
		icon.custom_minimum_size.x = key_size
		icon.custom_minimum_size.y = key_size
	add_theme_constant_override("separation", chip_separation)
	_apply_chip_size()


func _apply_chip_size() -> void:
	_panels_ready()
	for panel: PanelContainer in panels:
		if not panel:
			continue
		if chip_size > 0:
			panel.custom_minimum_size = Vector2(chip_size, chip_size)
			# Stop expanding, or the row stretches the chips back out.
			panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		else:
			panel.custom_minimum_size = Vector2.ZERO
			panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _on_panel_gui_input(event: InputEvent, panel_index: int) -> void:
	if not event is InputEventMouseButton:
		return

	var mouse_button_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_button_event.pressed:
		return

	if mouse_button_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if panel_index >= password.length():
		return

	symbol_pressed.emit(panel_index)


func _draw_password() -> void:

	if not icons:
		icons = [%Icon1, %Icon2, %Icon3]
	_panels_ready()

	for icon: TextureRect in icons:
		icon.texture = null

	if not password:
		_update_panel_styles()
		return

	var index: int = 0
	for value: String in password.split(""):
		if index >= 3:
			Log.error("PasswordVisualizer: A password cannot be more than 3 characters long")
			return

		if Design.CODE_COLORS.has(value):
			icons[index].texture = Design.code_symbol_texture(value)
			icons[index].modulate = Color.WHITE if show_backgrounds else Design.code_color(value)
		index += 1

	_update_panel_styles()


func _panels_ready() -> void:
	if not panels:
		panels = [%Panel1, %Panel2, %Panel3]


func _update_panel_styles() -> void:
	_panels_ready()

	var digits: PackedStringArray = password.split("", false) if password else PackedStringArray()
	for index: int in panels.size():
		var panel: PanelContainer = panels[index]
		if not panel:
			continue
		panel.theme_type_variation = &""
		if not show_backgrounds:
			panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			continue
		# An empty slot stays white; a filled one takes its symbol's colour, the
		# same chip the keypad and the registration summary show.
		var filled: bool = index < digits.size()
		var background: Color = Design.code_color(digits[index]) if filled else Color.WHITE
		panel.add_theme_stylebox_override("panel",
			MenuTheme.flat_stylebox(background, Design.CODE_SLOT_RADIUS))
