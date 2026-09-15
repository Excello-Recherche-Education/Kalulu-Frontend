@tool
class_name ProxySettings
extends VBoxContainer
## The proxy field, hidden until there is a reason to show it.
##
## Godot dials the internet directly whatever the machine is configured to do, so on a
## network whose only way out is a proxy every browser works and Kalulu alone does not.
## This is the way out of that, and it is deliberately the smallest one: the address is
## already filled in from the operating system's own setting, so the common case is a
## teacher reading a line and pressing a button rather than typing a hostname she has
## no way of knowing.
##
## It stays hidden the rest of the time. A box labelled "server address" on a screen
## that has just failed is an invitation to type something into it, and almost nobody
## is behind a proxy -- [method ServerManagerClass.proxy_is_worth_offering] owns that
## rule, so it can be checked without a screen.
##
## The help button is not decoration. "Proxy" is the one word on this panel that a
## teacher cannot be expected to know, and the alternative to explaining it here is a
## support mail asking what it means.

## Emitted once the proxy has been changed, for a screen that wants to offer the
## failed action again. Not connected to anything by default: whether retrying is
## sensible depends on what failed, and only the screen knows that.
signal proxy_changed()

## Recolours the panel for the white card of the registration wizard.
##
## The same panel hangs under a message on two very different surfaces: the login
## screen's navy, where a label has to be white, and the wizard's white card, where a
## white label is invisible. Rather than two scenes, the surface is declared and the
## theme variations follow it.
@export var on_card: bool = false

@onready var use_proxy: Button = %UseProxy
@onready var use_proxy_label: Label = %UseProxyLabel
@onready var help_button: Button = %HelpButton
@onready var address_field: MenuTextField = %AddressField
@onready var apply_button: Button = %ApplyButton
@onready var help_popup: ConfirmPopup = %HelpPopup


func _ready() -> void:
	_apply_surface()
	if Engine.is_editor_hint():
		return
	use_proxy.toggled.connect(_on_use_proxy_toggled)
	help_button.pressed.connect(_on_help_pressed)
	apply_button.pressed.connect(_apply)
	address_field.text_submitted.connect(_on_address_submitted)
	hide()


func _apply_surface() -> void:
	use_proxy_label.theme_type_variation = &"CardLabel" if on_card else &"FieldLabel"
	var button_variation: StringName = &"CardSecondaryButton" if on_card else &"InlineButton"
	help_button.theme_type_variation = button_variation
	apply_button.theme_type_variation = button_variation
	if on_card:
		address_field.input.add_theme_stylebox_override("normal", _card_field_style())


## An outline for the address field on the wizard's white card.
##
## The field's own box is white, which is invisible there: the address reads as a
## caption rather than as something that can be corrected, and the teacher who needs
## to correct it has nothing to aim at. Built here rather than added to the theme,
## which is shared by every screen and where this is the only surface that needs it.
static func _card_field_style() -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Design.LAVENDER
	box.border_color = Design.NAVY
	box.set_border_width_all(3)
	box.set_corner_radius_all(24)
	box.content_margin_left = 40
	box.content_margin_right = 40
	box.content_margin_top = 20
	box.content_margin_bottom = 20
	return box


## Shows or hides the panel for a given failure, and fills it in.
##
## Called with the cause every time a notice goes up, so the panel follows the
## diagnosis rather than being switched on once and left there.
func refresh(cause: ServerManagerClass.ConnectionFailure) -> void:
	var server: ServerManagerClass = ServerManager as ServerManagerClass
	# Idempotent, and normally already done by the diagnosis that produced `cause`.
	# Called again because whether the machine has a proxy is half of the rule below,
	# and a panel shown on a "not looked up yet" would be hidden from the one teacher
	# it is for.
	server.ensure_system_proxy_known()
	visible = ServerManagerClass.proxy_is_worth_offering(cause,
			not server.system_proxy.is_empty(), server.proxy_enabled)
	if not visible:
		return

	address_field.text = _format(server.proxy_host, server.proxy_port)
	# set_pressed_no_signal, or filling the panel in would be read as the teacher
	# switching the proxy on and would save a setting nobody asked for.
	use_proxy.set_pressed_no_signal(server.proxy_enabled)
	_refresh_enabled_state()


## "host:port", or "" when there is no host -- the shape the field reads and writes.
static func _format(host: String, port: int) -> String:
	if host.is_empty():
		return ""
	return "%s:%d" % [host, port] if port > 0 else host


func _on_use_proxy_toggled(_pressed: bool) -> void:
	_refresh_enabled_state()
	_apply()


func _on_address_submitted(_text: String) -> void:
	_apply()


## Offers the confirm button only while there is something to confirm.
##
## It used to be greyed out instead, which on the wizard's card left an empty outlined
## box: the variation's disabled colour is white, and the card is white. Hidden is also
## the truer state -- with the proxy switched off there is nothing to apply.
func _refresh_enabled_state() -> void:
	apply_button.visible = use_proxy.button_pressed


func _apply() -> void:
	var server: ServerManagerClass = ServerManager as ServerManagerClass
	if not use_proxy.button_pressed:
		server.set_proxy(server.proxy_host, server.proxy_port, false)
		address_field.error = ""
		proxy_changed.emit()
		return

	var parsed: Dictionary = SystemProxy.parse(address_field.text)
	if parsed.is_empty():
		# Said on the field rather than in a dialog: it is about what was typed, and
		# the correction happens in the box the message is under.
		address_field.error = "PROXY_ADDRESS_INVALID"
		use_proxy.set_pressed_no_signal(false)
		_refresh_enabled_state()
		# The field is where the correction has to happen, and on a screen this long
		# it may not be the thing under the reader's eye.
		address_field.grab_input_focus()
		return

	address_field.error = ""
	server.set_proxy(str(parsed["host"]), int(parsed["port"]), true)
	address_field.text = _format(str(parsed["host"]), int(parsed["port"]))
	proxy_changed.emit()


func _on_help_pressed() -> void:
	help_popup.title_text = "PROXY_HELP_TITLE"
	help_popup.content_text = "PROXY_HELP_BODY"
	help_popup.acknowledge_only = true
	help_popup.show()
