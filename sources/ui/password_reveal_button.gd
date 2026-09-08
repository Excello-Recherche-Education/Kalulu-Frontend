class_name PasswordRevealButton
extends TextureButton
## Eye button that shows or hides what a LineEdit is masking.
##
## MenuTextField has this built into its trailing slot, and a screen built from
## that component needs nothing here. This is the same control for the plain
## LineEdits that predate it -- the registration form -- so both screens behave
## and look alike without the register step having to be rebuilt around
## MenuTextField, whose validator plumbing differs from the one that form uses.
##
## Drop it as a child of the LineEdit it serves: a Control child is drawn inside
## its parent's rect, so it finds its field by itself and anchors itself to the
## field's trailing edge, leaving the scene nothing to lay out.
##
## Deliberately not a @tool script, unlike MenuTextField. It masks its field and
## overrides that field's stylebox, and the field belongs to the scene it was
## dropped into rather than to a scene of its own -- so running in the editor
## would bake both into whatever scene is open the next time it is saved. The
## cost is that the editor shows an empty slot where the eye will be.

## Where the eye icons live. MenuTextField reads these too, so the assets are
## named in one place.
const SHOW_PASSWORD_PATH: String = "res://assets/menus/icons/show_password.svg"
const HIDE_PASSWORD_PATH: String = "res://assets/menus/icons/hide_password.svg"

## The field to mask. Left empty it takes its parent, which is how it is meant
## to be used; the export is for the rare scene that has to place the button
## somewhere else.
@export var field: LineEdit


func _ready() -> void:
	if not field:
		field = get_parent() as LineEdit
	if not field:
		Log.error("PasswordRevealButton: no LineEdit to reveal (" + str(self) + ")")
		return

	# The icon assets are white so they can be tinted per context; in a field
	# the mockups show them in the light grey used for placeholder text.
	self_modulate = Design.GREY_LIGHT
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	toggle_mode = false
	_anchor_to_field_edge()
	_reserve_room()

	field.secret = true
	# A masked field always wants the password keyboard: the ordinary one arms
	# its shift key for the first character, which has to be switched off by
	# hand before every password.
	field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
	_refresh_icon()

	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)


## True while the field is masking its contents.
func is_masked() -> bool:
	return field != null and field.secret


## Pins the button inside the field's trailing edge, one padding in.
func _anchor_to_field_edge() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.5
	anchor_bottom = 0.5
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BOTH
	offset_left = -float(Design.FIELD_PADDING + Design.FIELD_ICON_SIZE)
	offset_right = -float(Design.FIELD_PADDING)
	offset_top = -Design.FIELD_ICON_SIZE / 2.0
	offset_bottom = Design.FIELD_ICON_SIZE / 2.0


## Widens the field's right padding so long text does not run under the icon.
##
## Sized from the token rather than from the texture: the icons are imported at
## twice their on-screen size, so texture width would over-reserve by half.
func _reserve_room() -> void:
	var box: StyleBox = field.get_theme_stylebox("normal", "LineEdit").duplicate()
	box.content_margin_right = Design.FIELD_PADDING * 2 + Design.FIELD_ICON_SIZE
	field.add_theme_stylebox_override("normal", box)


## The icon shows the current state, as in the mockups: a struck-through eye
## while the text is masked, a plain eye once it is revealed.
func _refresh_icon() -> void:
	texture_normal = load(HIDE_PASSWORD_PATH if is_masked() else SHOW_PASSWORD_PATH) as Texture2D


func _on_pressed() -> void:
	if not field:
		return
	field.secret = not field.secret
	_refresh_icon()
