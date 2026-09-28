@tool
class_name MenuTextField
extends VBoxContainer
## White rounded text field with a trailing icon and its own error line.
##
## The field owns the label that shows its error, so a screen just does
## `field.error = "..."`. When placed under a FormValidator and given a
## `validator`, it fills that label in by itself and clears it as soon as the
## user edits. That is the point of the component: the old login screen wired
## errors up by looking for a sibling Label named "<ControlName>Error", which
## broke silently whenever a node was renamed.
##
## `placeholder` holds a translation key, not display text.

signal text_changed(new_text: String)
signal text_submitted(new_text: String)

# The reveal control owns the eye artwork; the field's own trailing slot draws
# the same icons when it is acting as one.
const SHOW_PASSWORD_PATH: String = PasswordRevealButton.SHOW_PASSWORD_PATH
const HIDE_PASSWORD_PATH: String = PasswordRevealButton.HIDE_PASSWORD_PATH

@export var placeholder: String = "":
	set(value):
		placeholder = value
		if is_node_ready():
			input.placeholder_text = value
## Trailing decoration, such as the envelope on an email field. Ignored when
## `is_password` is on, which needs the icon for its reveal toggle.
@export var icon: Texture2D:
	set(value):
		icon = value
		if is_node_ready():
			_refresh_trailing()
## Masks the text and turns the trailing icon into a reveal toggle.
@export var is_password: bool = false:
	set(value):
		is_password = value
		if is_node_ready():
			_refresh_trailing()
			_apply_keyboard_type()
## The keyboard a phone should open for this field. Ignored while `is_password`
## is on, which picks its own -- see effective_keyboard_type.
@export var keyboard_type: LineEdit.VirtualKeyboardType = LineEdit.KEYBOARD_TYPE_DEFAULT:
	set(value):
		keyboard_type = value
		if is_node_ready():
			_apply_keyboard_type()
## Optional validation rules from the godot-form-validator addon.
##
## Rules rather than a whole Validator: the component always wraps a LineEdit,
## so it can pick LineEditValidator itself. Handing it a plain Validator is an
## easy mistake and a silent one -- the base class reads no value from the
## control, so every rule fails no matter what the user typed.
@export var rules: Array[ValidatorRule] = []:
	set(value):
		rules = value
		if is_node_ready() and not Engine.is_editor_hint():
			_attach_validator()

var error: String = "":
	set(value):
		error = value
		if not is_node_ready():
			return
		error_label.text = value
		error_label.visible = not value.is_empty()
var text: String:
	set(value):
		if is_node_ready():
			input.text = value
	get():
		return input.text if is_node_ready() else ""

@onready var input: LineEdit = %Input
@onready var trailing: TextureButton = %Trailing
@onready var error_label: Label = %Error


func _ready() -> void:
	input.placeholder_text = placeholder
	_apply_keyboard_type()
	# The icon assets are white so they can be tinted per context; in a field
	# the mockups show them in the light grey used for placeholder text.
	trailing.self_modulate = Design.GREY_LIGHT
	trailing.custom_minimum_size = Vector2(Design.FIELD_ICON_SIZE, Design.FIELD_ICON_SIZE)
	input.text_changed.connect(_on_input_text_changed)
	input.text_submitted.connect(_on_input_text_submitted)
	trailing.pressed.connect(_on_trailing_pressed)
	error_label.text = error
	error_label.visible = not error.is_empty()
	_refresh_trailing()

	if Engine.is_editor_hint():
		return
	_attach_validator()
	_connect_form_validator()


## Moves keyboard focus into the field.
func grab_input_focus() -> void:
	input.grab_focus()


## The keyboard a phone actually opens for this field.
##
## A password field asks for the password keyboard whatever it was given. The
## ordinary one arms its shift key for the first character -- which is right for
## a name and wrong for a password, where it has to be switched off by hand
## every single time before the first letter can be typed. Derived from
## `is_password` rather than set beside it in each scene, because a field that
## masks its contents always wants this and the one place it was forgotten is
## the login screen, the field people type into most.
func effective_keyboard_type() -> LineEdit.VirtualKeyboardType:
	return LineEdit.KEYBOARD_TYPE_PASSWORD if is_password else keyboard_type


func _apply_keyboard_type() -> void:
	input.virtual_keyboard_type = effective_keyboard_type()


## True while a password field is masking its contents.
func is_masked() -> bool:
	return input.secret


func _refresh_trailing() -> void:
	# `is_password` is the field's nature and never changes on its own;
	# input.secret is the live masking state that the toggle flips.
	input.secret = is_password
	var texture: Texture2D = _reveal_icon() if is_password else icon
	trailing.texture_normal = texture
	trailing.visible = texture != null
	trailing.toggle_mode = false
	# A decorative icon must not swallow the tap that focuses the field; only
	# the reveal toggle is interactive.
	trailing.mouse_filter = (Control.MOUSE_FILTER_STOP if is_password
		else Control.MOUSE_FILTER_IGNORE)
	_reserve_room_for_trailing(texture)


## The icon shows the current state, as in the mockups: a struck-through eye
## while the text is masked, a plain eye once it is revealed.
func _reveal_icon() -> Texture2D:
	return load(HIDE_PASSWORD_PATH if input.secret else SHOW_PASSWORD_PATH) as Texture2D


## Widens the field's right padding so long text does not run under the icon.
##
## Sized from the token rather than from the texture: the icons are imported at
## twice their on-screen size, so texture width would over-reserve by half.
func _reserve_room_for_trailing(texture: Texture2D) -> void:
	if not texture:
		input.remove_theme_stylebox_override("normal")
		return
	var box: StyleBox = input.get_theme_stylebox("normal", "LineEdit").duplicate()
	box.content_margin_right = Design.FIELD_PADDING * 2 + Design.FIELD_ICON_SIZE
	input.add_theme_stylebox_override("normal", box)


## (Re)builds the addon plumbing for the current `rules`.
##
## Rebuildable so a screen can declare its validation in code: a field's _ready
## runs before its screen's, so assigning `rules` from the screen has to take
## effect after the fact.
func _attach_validator() -> void:
	for child: Node in input.get_children():
		if child is ControlValidator:
			input.remove_child(child)
			child.queue_free()
	if rules.is_empty():
		return

	var validator: LineEditValidator = LineEditValidator.new()
	validator.rules = rules
	# The addon finds a ControlValidator through its parent, so it has to hang
	# off the LineEdit rather than off this component.
	var control_validator: ControlValidator = ControlValidator.new()
	control_validator.validator = validator
	input.add_child(control_validator)


func _connect_form_validator() -> void:
	var node: Node = get_parent()
	while node:
		if node is FormValidator:
			(node as FormValidator).control_validated.connect(_on_control_validated)
			return
		node = node.get_parent()


func _on_control_validated(control: Control, passed: bool, messages: PackedStringArray) -> void:
	if control != input:
		return
	error = "" if passed else ". ".join(messages)


func _on_input_text_changed(new_text: String) -> void:
	# An error describes text the user has since changed, so retire it.
	if not error.is_empty():
		error = ""
	text_changed.emit(new_text)


func _on_input_text_submitted(new_text: String) -> void:
	text_submitted.emit(new_text)


func _on_trailing_pressed() -> void:
	if not is_password:
		return
	input.secret = not input.secret
	trailing.texture_normal = _reveal_icon()
