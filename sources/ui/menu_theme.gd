class_name MenuTheme
extends Object
## Builds the Theme shared by the redesigned menus out of the Design tokens.
##
## The built resource is committed at THEME_PATH so the Godot editor styles
## these scenes while they are being edited. It is generated, never hand
## edited -- that is what keeps it from drifting away from Design. After
## changing a token, regenerate it with:
##
##     godot --headless --path . --script sources/ui/menu_theme_generator.gd
##
## Screens assign the resource on their root Control and then style children by
## setting theme_type_variation to one of the VARIATION_* names below, so a
## screen normally needs no styling code of its own.

const THEME_PATH: String = "res://resources/themes/menu_theme.tres"
const CHEVRON_DOWN_PATH: String = "res://assets/menus/icons/chevron_down.svg"
# Label variations. The defaults are for the navy page background; the CARD_*
# ones are for text sitting on a white surface.
const VARIATION_TITLE: StringName = &"Title"
const VARIATION_HEADING: StringName = &"Heading"
const VARIATION_CAPTION: StringName = &"Caption"
const VARIATION_FIELD_LABEL: StringName = &"FieldLabel"
const VARIATION_ERROR: StringName = &"ErrorLabel"
const VARIATION_CARD_TITLE: StringName = &"CardTitle"
const VARIATION_CARD_HEADING: StringName = &"CardHeading"
const VARIATION_CARD_BODY: StringName = &"CardBody"
# Button variations.
const VARIATION_PRIMARY_BUTTON: StringName = &"PrimaryButton"
const VARIATION_SECONDARY_BUTTON: StringName = &"SecondaryButton"
const VARIATION_CARD_SECONDARY_BUTTON: StringName = &"CardSecondaryButton"
const VARIATION_INLINE_BUTTON: StringName = &"InlineButton"
const VARIATION_TAB_PILL: StringName = &"TabPill"
# Circular icon buttons: pale on the navy page, navy on a white card.
const VARIATION_ICON_BUTTON_LIGHT: StringName = &"IconButtonLight"
const VARIATION_ICON_BUTTON_DARK: StringName = &"IconButtonDark"
# Panel variations.
const VARIATION_CARD: StringName = &"Card"
const VARIATION_STUDENT_CARD: StringName = &"StudentCard"
# A settings dropdown is shorter than a sign-up field.
const VARIATION_FIELD_COMPACT: StringName = &"FieldCompact"
# Small grey label on a white surface, as above a student's code chips.
const VARIATION_CARD_LABEL: StringName = &"CardLabel"


## A filled, rounded rectangle.
static func flat_stylebox(color: Color, radius: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	return box


## A rounded rectangle drawn as an outline only, with a transparent centre.
static func outline_stylebox(color: Color, radius: int, width: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color.TRANSPARENT
	box.set_corner_radius_all(radius)
	box.set_border_width_all(width)
	box.border_color = color
	return box


## The Theme used by every redesigned menu screen.
static func build() -> Theme:
	var theme: Theme = Theme.new()
	var regular: Font = load(Design.FONT_REGULAR_PATH)
	var bold: Font = load(Design.FONT_BOLD_PATH)

	theme.default_font = regular
	theme.default_font_size = Design.FONT_SIZE_BODY

	_build_labels(theme, regular, bold)
	_build_buttons(theme, regular)
	_build_fields(theme, regular)
	_build_panels(theme)
	return theme


static func _build_labels(theme: Theme, regular: Font, bold: Font) -> void:
	# Plain Label is body copy on the navy background.
	theme.set_font("font", "Label", regular)
	theme.set_font_size("font_size", "Label", Design.FONT_SIZE_BODY)
	theme.set_color("font_color", "Label", Color.WHITE)

	_add_label(theme, VARIATION_TITLE, bold, Design.FONT_SIZE_TITLE, Color.WHITE)
	_add_label(theme, VARIATION_HEADING, bold, Design.FONT_SIZE_HEADING, Color.WHITE)
	_add_label(theme, VARIATION_FIELD_LABEL, regular, Design.FONT_SIZE_LABEL, Color.WHITE)
	_add_label(theme, VARIATION_CAPTION, regular, Design.FONT_SIZE_CAPTION, Color.WHITE)
	_add_label(theme, VARIATION_ERROR, regular, Design.FONT_SIZE_BODY, Design.ERROR)
	_add_label(theme, VARIATION_CARD_TITLE, bold, Design.FONT_SIZE_TITLE, Design.GREY_DARK)
	_add_label(theme, VARIATION_CARD_HEADING, bold, Design.FONT_SIZE_HEADING, Design.GREY_DARK)
	_add_label(theme, VARIATION_CARD_BODY, regular, Design.FONT_SIZE_BODY, Design.GREY_DARK)
	_add_label(theme, VARIATION_CARD_LABEL, regular, Design.FONT_SIZE_LABEL, Design.GREY_DARK)


static func _build_buttons(theme: Theme, regular: Font) -> void:
	# Filled purple call to action. Disabled is a flat grey with a white label,
	# which is how the mockups show an unavailable "Next".
	_add_button(theme, VARIATION_PRIMARY_BUTTON, regular, Color.WHITE, {
		"normal": flat_stylebox(Design.PURPLE, Design.BUTTON_RADIUS),
		"hover": flat_stylebox(Design.PURPLE.lightened(0.1), Design.BUTTON_RADIUS),
		"pressed": flat_stylebox(Design.PURPLE.darkened(0.15), Design.BUTTON_RADIUS),
		"disabled": flat_stylebox(Design.GREY_LIGHT, Design.BUTTON_RADIUS),
	})

	# Outlined button on the navy page background.
	_add_button(theme, VARIATION_SECONDARY_BUTTON, regular, Color.WHITE, {
		"normal": outline_stylebox(Design.GREY_LIGHT, Design.BUTTON_RADIUS, Design.BUTTON_BORDER),
		"hover": flat_stylebox(Color(1, 1, 1, 0.12), Design.BUTTON_RADIUS),
		"pressed": flat_stylebox(Color(1, 1, 1, 0.2), Design.BUTTON_RADIUS),
		"disabled": outline_stylebox(Design.GREY, Design.BUTTON_RADIUS, Design.BUTTON_BORDER),
	})

	# Outlined button on a white card: navy outline and navy label.
	_add_button(theme, VARIATION_CARD_SECONDARY_BUTTON, regular, Design.NAVY, {
		"normal": outline_stylebox(Design.NAVY, Design.BUTTON_RADIUS, Design.BUTTON_BORDER),
		"hover": flat_stylebox(Design.NAVY.lerp(Color.WHITE, 0.9), Design.BUTTON_RADIUS),
		"pressed": flat_stylebox(Design.NAVY.lerp(Color.WHITE, 0.8), Design.BUTTON_RADIUS),
		"disabled": outline_stylebox(Design.GREY_LIGHT, Design.BUTTON_RADIUS, Design.BUTTON_BORDER),
	})

	# Text-only button, used for "Forgot Password?" and similar affordances.
	_add_button(theme, VARIATION_INLINE_BUTTON, regular, Color.WHITE, {
		"normal": StyleBoxEmpty.new(),
		"hover": StyleBoxEmpty.new(),
		"pressed": StyleBoxEmpty.new(),
		"disabled": StyleBoxEmpty.new(),
	})
	theme.set_font_size("font_size", VARIATION_INLINE_BUTTON, Design.FONT_SIZE_BODY)

	# Fully rounded tab, used for the device tabs in Settings. Pressed is the
	# selected state, so it takes the brand purple.
	var pill_radius: int = Design.PILL_HEIGHT / 2
	_add_button(theme, VARIATION_TAB_PILL, regular, Color.WHITE, {
		"normal": flat_stylebox(Design.NAVY, pill_radius),
		"hover": flat_stylebox(Design.NAVY.lightened(0.1), pill_radius),
		"pressed": flat_stylebox(Design.PURPLE, pill_radius),
		"disabled": flat_stylebox(Design.GREY_LIGHT, pill_radius),
	})
	_set_content_margins(theme, VARIATION_TAB_PILL, Design.PILL_PADDING,
		_vertical_margin(regular, Design.FONT_SIZE_BODY, Design.PILL_HEIGHT))
	theme.set_font_size("font_size", VARIATION_TAB_PILL, Design.FONT_SIZE_BODY)

	# Circular icon buttons. The icon assets are white, so each variation tints
	# them to read against its own circle.
	_add_icon_button(theme, VARIATION_ICON_BUTTON_LIGHT, Design.LAVENDER, Design.PURPLE)
	_add_icon_button(theme, VARIATION_ICON_BUTTON_DARK, Design.NAVY, Color.WHITE)


static func _build_fields(theme: Theme, regular: Font) -> void:
	var margin: float = _vertical_margin(regular, Design.FONT_SIZE_INPUT, Design.FIELD_HEIGHT)
	var normal: StyleBoxFlat = _field_stylebox(margin)
	var focus: StyleBoxFlat = _field_stylebox(margin)
	focus.set_border_width_all(Design.BUTTON_BORDER)
	focus.border_color = Design.PURPLE

	for type: String in ["LineEdit", "OptionButton"]:
		theme.set_font("font", type, regular)
		theme.set_font_size("font_size", type, Design.FONT_SIZE_INPUT)
		theme.set_color("font_color", type, Design.GREY_DARK)
		theme.set_stylebox("normal", type, normal)
		theme.set_stylebox("focus", type, focus)

	theme.set_color("font_placeholder_color", "LineEdit", Design.GREY_LIGHT)
	theme.set_color("font_uneditable_color", "LineEdit", Design.GREY)
	theme.set_color("caret_color", "LineEdit", Design.PURPLE)
	theme.set_color("selection_color", "LineEdit", Design.PURPLE.lerp(Color.WHITE, 0.6))
	theme.set_stylebox("read_only", "LineEdit", _field_stylebox(margin, Design.GREY_LIGHTER))

	# An OptionButton is a Button underneath, so it needs the pressed/hover/
	# disabled slots too or it falls back to the engine's default grey boxes.
	theme.set_stylebox("hover", "OptionButton", normal)
	theme.set_stylebox("pressed", "OptionButton", normal)
	theme.set_stylebox("disabled", "OptionButton", _field_stylebox(margin, Design.GREY_LIGHTER))
	theme.set_color("font_hover_color", "OptionButton", Design.GREY_DARK)
	theme.set_color("font_pressed_color", "OptionButton", Design.GREY_DARK)
	theme.set_color("font_disabled_color", "OptionButton", Design.GREY)
	theme.set_icon("arrow", "OptionButton", load(CHEVRON_DOWN_PATH) as Texture2D)

	var compact: float = _vertical_margin(regular, Design.FONT_SIZE_INPUT,
		Design.COMPACT_FIELD_HEIGHT)
	theme.set_type_variation(VARIATION_FIELD_COMPACT, "OptionButton")
	for state: String in ["normal", "hover", "pressed"]:
		theme.set_stylebox(state, VARIATION_FIELD_COMPACT, _field_stylebox(compact))
	theme.set_stylebox("disabled", VARIATION_FIELD_COMPACT,
		_field_stylebox(compact, Design.GREY_LIGHTER))
	theme.set_stylebox("focus", VARIATION_FIELD_COMPACT, StyleBoxEmpty.new())

	# The drop-down list itself, so an open OptionButton stays on brand.
	theme.set_font("font", "PopupMenu", regular)
	theme.set_font_size("font_size", "PopupMenu", Design.FONT_SIZE_INPUT)
	theme.set_color("font_color", "PopupMenu", Design.GREY_DARK)
	theme.set_color("font_hover_color", "PopupMenu", Design.PURPLE)
	theme.set_stylebox("panel", "PopupMenu", flat_stylebox(Color.WHITE, Design.FIELD_RADIUS))
	theme.set_stylebox("hover", "PopupMenu", flat_stylebox(Design.LAVENDER, 0))


static func _build_panels(theme: Theme) -> void:
	theme.set_type_variation(VARIATION_CARD, "PanelContainer")
	theme.set_stylebox("panel", VARIATION_CARD, flat_stylebox(Color.WHITE, Design.CARD_RADIUS))
	# A student's card sits on the white settings card, so it needs to be a shade
	# off white to read as a separate surface.
	theme.set_type_variation(VARIATION_STUDENT_CARD, "PanelContainer")
	theme.set_stylebox("panel", VARIATION_STUDENT_CARD,
		flat_stylebox(Color("f7f7f7"), Design.STUDENT_CARD_RADIUS))


static func _field_stylebox(vertical_margin: float, color: Color = Color.WHITE) -> StyleBoxFlat:
	var box: StyleBoxFlat = flat_stylebox(color, Design.FIELD_RADIUS)
	box.content_margin_left = Design.FIELD_PADDING
	box.content_margin_right = Design.FIELD_PADDING
	box.content_margin_top = vertical_margin
	box.content_margin_bottom = vertical_margin
	return box


## Padding that makes a control holding one line of `size` text exactly
## `target_height` tall, so heights come from the tokens instead of from
## per-scene custom_minimum_size values.
static func _vertical_margin(font: Font, size: int, target_height: int) -> float:
	return maxf(0.0, (target_height - font.get_height(size)) / 2.0)


static func _add_label(theme: Theme, variation: StringName, font: Font, size: int, color: Color) -> void:
	theme.set_type_variation(variation, "Label")
	theme.set_font("font", variation, font)
	theme.set_font_size("font_size", variation, size)
	theme.set_color("font_color", variation, color)


static func _add_button(theme: Theme, variation: StringName, font: Font, color: Color,
		styleboxes: Dictionary[String, StyleBox]) -> void:
	theme.set_type_variation(variation, "Button")
	theme.set_font("font", variation, font)
	theme.set_font_size("font_size", variation, Design.FONT_SIZE_INPUT)
	theme.set_color("font_color", variation, color)
	theme.set_color("font_hover_color", variation, color)
	theme.set_color("font_pressed_color", variation, color)
	theme.set_color("font_focus_color", variation, color)
	theme.set_color("font_disabled_color", variation, Color.WHITE)
	for state: String in styleboxes:
		theme.set_stylebox(state, variation, styleboxes[state])
	theme.set_stylebox("focus", variation, StyleBoxEmpty.new())


## A round icon button: `circle` behind, `ink` for the glyph.
static func _add_icon_button(theme: Theme, variation: StringName, circle: Color,
		ink: Color) -> void:
	var radius: int = Design.ROUND_BUTTON_SMALL / 2
	theme.set_type_variation(variation, "Button")
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var fill: Color = circle
		if state == "hover":
			fill = circle.lerp(Design.PURPLE, 0.15)
		elif state == "pressed":
			fill = circle.darkened(0.15)
		elif state == "disabled":
			fill = circle.lerp(Design.GREY_LIGHT, 0.6)
		theme.set_stylebox(state, variation, flat_stylebox(fill, radius))
	theme.set_stylebox("focus", variation, StyleBoxEmpty.new())
	for state: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color",
			"icon_focus_color"]:
		theme.set_color(state, variation, ink)
	theme.set_color("icon_disabled_color", variation, ink.lerp(Design.GREY_LIGHT, 0.6))
	theme.set_constant("icon_max_width", variation, Design.FIELD_ICON_SIZE)


static func _set_content_margins(theme: Theme, variation: StringName, horizontal: float,
		vertical: float) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var box: StyleBox = theme.get_stylebox(state, variation)
		if not box:
			continue
		box.content_margin_left = horizontal
		box.content_margin_right = horizontal
		box.content_margin_top = vertical
		box.content_margin_bottom = vertical
