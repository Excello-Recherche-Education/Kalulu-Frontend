@tool
class_name CodeKeypad
extends VBoxContainer
## The coloured symbol keypad used to enter an access code, plus its slots.
##
## Serves both places a code is typed: the child's login screen, and the adult
## check that gates sign-up. A code is three symbols and never repeats one, so a
## key already in the code is dimmed and tapping it takes the symbol back out.
##
## Slots and keys are built from the Design tokens rather than laid out in the
## scene, so the keypad's order and colours have one definition. The layout is
## Design.CODE_KEYPAD_ORDER, which groups the symbols by shape rather than by
## digit and so is not 1..6.

signal code_changed(code: String)
signal code_entered(code: String)

@export var code_length: int = Design.CODE_LENGTH:
	set(value):
		code_length = maxi(1, value)
		if is_node_ready():
			_build()

var code: String = ""
var slots: Array[PanelContainer] = []
var slot_glyphs: Array[TextureRect] = []
var keys: Dictionary[String, Button] = {}

@onready var slot_row: HBoxContainer = %Slots
@onready var key_grid: GridContainer = %Keys


func _ready() -> void:
	_build()


## Empties the code without emitting code_entered.
func clear() -> void:
	code = ""
	_refresh()
	code_changed.emit(code)


## Adds `digit` to the code, or takes it back out if already present.
##
## Returns true when the digit changed the code. Ignored once the code is full,
## and for a digit outside 1..6.
func toggle_digit(digit: String) -> bool:
	if not Design.CODE_COLORS.has(digit):
		return false

	var at: int = code.find(digit)
	if at >= 0:
		code = code.erase(at, 1)
	elif code.length() >= code_length:
		return false
	else:
		code += digit

	_refresh()
	code_changed.emit(code)
	if code.length() == code_length:
		code_entered.emit(code)
	return true


## Removes the symbol shown in slot `index`, if it holds one.
func remove_at(index: int) -> void:
	if index < 0 or index >= code.length():
		return
	code = code.erase(index, 1)
	_refresh()
	code_changed.emit(code)


func _build() -> void:
	if not is_node_ready():
		return
	_build_slots()
	_build_keys()
	_refresh()


func _build_slots() -> void:
	for slot: PanelContainer in slots:
		slot.queue_free()
	slots.clear()
	slot_glyphs.clear()
	slot_row.add_theme_constant_override("separation", Design.CODE_SLOT_GAP)

	for index: int in code_length:
		var slot: PanelContainer = PanelContainer.new()
		slot.custom_minimum_size = Vector2(Design.CODE_SLOT_SIZE, Design.CODE_SLOT_SIZE)
		slot.gui_input.connect(_on_slot_gui_input.bind(index))

		# Centred at a fixed size rather than filling the slot: a PanelContainer
		# stretches its child, which would blow the glyph up to the full 239.
		var centre: CenterContainer = CenterContainer.new()
		centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(centre)
		centre.add_child(_new_glyph())

		slot_row.add_child(slot)
		slots.append(slot)
		slot_glyphs.append(centre.get_child(0) as TextureRect)


func _build_keys() -> void:
	for key: Button in keys.values():
		key.queue_free()
	keys.clear()
	key_grid.columns = 3
	key_grid.add_theme_constant_override("h_separation", Design.CODE_KEY_GAP.x)
	key_grid.add_theme_constant_override("v_separation", Design.CODE_KEY_GAP.y)

	for digit: String in Design.CODE_KEYPAD_ORDER:
		var key: Button = Button.new()
		key.custom_minimum_size = Design.CODE_KEY_SIZE
		key.focus_mode = Control.FOCUS_NONE
		# The glyph goes in a centred child, not in Button.icon: with no text a
		# Button pins its icon to the left edge, which is how the symbols ended up
		# small and off to one side.
		var centre: CenterContainer = CenterContainer.new()
		centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var glyph: TextureRect = _new_glyph()
		glyph.texture = Design.code_symbol_texture(digit)
		centre.add_child(glyph)
		key.add_child(centre)
		var color: Color = Design.code_color(digit)
		for state: String in ["normal", "hover", "focus"]:
			key.add_theme_stylebox_override(state,
				MenuTheme.flat_stylebox(color, Design.CODE_KEY_RADIUS))
		key.add_theme_stylebox_override("pressed",
			MenuTheme.flat_stylebox(color.darkened(0.2), Design.CODE_KEY_RADIUS))
		key.pressed.connect(_on_key_pressed.bind(digit))
		key_grid.add_child(key)
		keys[digit] = key


func _refresh() -> void:
	var digits: PackedStringArray = code.split("", false)
	for index: int in slots.size():
		var glyph: TextureRect = slot_glyphs[index]
		var filled: bool = index < digits.size()
		# A filled slot takes the symbol's colour with a white glyph, the same
		# chip the registration summary and the student progress panel show.
		var background: Color = Design.code_color(digits[index]) if filled else Color.WHITE
		slots[index].add_theme_stylebox_override("panel",
			MenuTheme.flat_stylebox(background, Design.CODE_SLOT_RADIUS))
		glyph.texture = Design.code_symbol_texture(digits[index]) if filled else null

	# Dim a key whose symbol is already in the code: it cannot be used twice.
	for digit: String in keys:
		keys[digit].modulate = Color(0.55, 0.55, 0.55) if digit in code else Color.WHITE


## A symbol glyph at the designed size, ready to be centred.
func _new_glyph() -> TextureRect:
	var glyph: TextureRect = TextureRect.new()
	glyph.custom_minimum_size = Vector2(Design.CODE_SYMBOL_SIZE, Design.CODE_SYMBOL_SIZE)
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return glyph


func _on_key_pressed(digit: String) -> void:
	toggle_digit(digit)


func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		remove_at(index)
