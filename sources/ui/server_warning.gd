class_name ServerWarning
extends PanelContainer
## Says so when the app is not talking to the production server, and offers the way back.
##
## The developer settings can point the app at the DEV server or at any address, and
## that choice is saved. They sit behind ten quick taps on the version label, which
## turned out not to be hidden enough: a teacher ended up on DEV, where their account
## does not exist, and took it for an account that had disappeared. Nothing on screen
## said which server the app was using.
##
## It is placed on the two screens a launch opens on -- the welcome screen and the
## child's access-code screen -- so it is the first thing seen, every time.
##
## Going back signs a signed-in device out: its session was opened on the other
## server, which the production one has never heard of, and the account it belongs to
## is not there either. That is also why it asks for an adult first in that case --
## the access-code screen is the child's, and a tap there would end the session.

const PANEL_PADDING: int = 32

@onready var title_label: Label = %Title
@onready var body_label: Label = %Body
@onready var address_label: Label = %Address
@onready var reset_button: Button = %ResetButton
@onready var adult_check: AdultCheckPopup = %AdultCheck


func _ready() -> void:
	_style()
	reset_button.pressed.connect(_on_reset_pressed)
	adult_check.passed.connect(_reset)
	refresh()


## Shows the warning when the app is off production, and hides it otherwise.
func refresh() -> void:
	var server: ServerManagerClass = ServerManager as ServerManagerClass
	visible = not server.is_on_production()
	if visible:
		# The host alone: it is what tells DEV from PROD, and the full URL wraps over two
		# lines in a card that has to stay clear of the access-code keypad.
		address_label.text = ServerManagerClass.host_of(server.environment_url)
		Log.info("ServerWarning: Not on the production server but on %s, warning shown" % server.environment_url)


## Amber rather than the white of a card: this is the one panel on these screens that
## is about something being wrong, and it has to read as that before it is read at all.
func _style() -> void:
	var panel: StyleBoxFlat = MenuTheme.flat_stylebox(Design.WARNING, Design.CARD_RADIUS)
	panel.set_content_margin_all(PANEL_PADDING)
	add_theme_stylebox_override("panel", panel)
	for label: Label in [title_label, body_label, address_label]:
		label.add_theme_color_override("font_color", Design.NAVY)
	title_label.add_theme_font_override("font", load(Design.FONT_BOLD_PATH) as Font)
	reset_button.add_theme_font_size_override("font_size", Design.FONT_SIZE_LABEL)


func _on_reset_pressed() -> void:
	if EntryFlow.has_connection_token():
		Log.info("ServerWarning: Asking the adult check before signing the device out")
		adult_check.open()
		return
	_reset()


func _reset() -> void:
	var signed_in: bool = EntryFlow.has_connection_token()
	(ServerManager as ServerManagerClass).reset_to_production()
	if not signed_in:
		hide()
		return
	Log.info("ServerWarning: Signing the device out, its session belongs to the server it left")
	UserDataManager.logout()
	await OpeningCurtain.close()
	get_tree().change_scene_to_file(EntryFlow.WELCOME_SCENE_PATH)
