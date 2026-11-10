class_name UpdateNotice
extends PanelContainer
## Says that a newer Kalulu is out, and gets it with one button.
##
## Placed, like ServerWarning, on the two screens a launch opens on: the welcome
## screen and the child's access-code screen. A card rather than a dialog, because
## on the child's screen nobody who can act on it may be looking, and a dialog a
## child has to get rid of is one they tap away without reading.
##
## What the button does is UpdateManager's call: open the store, install in the
## app, or open the download in the browser. On a signed-in device it first asks
## for an adult, for the same reason ServerWarning does -- the access-code screen is
## the child's, and a tap there would download and restart the app.
##
## The cross hides the card until the next launch.

const PANEL_PADDING: int = 32

## Set by the cross, for the rest of this launch. Static so it survives the
## change between the welcome and access-code screens.
static var dismissed: bool = false

@onready var title_label: Label = %Title
@onready var body_label: Label = %Body
@onready var update_button: Button = %UpdateButton
@onready var close_button: TextureButton = %CloseButton
@onready var adult_check: AdultCheckPopup = %AdultCheck
@onready var dialog: ConfirmPopup = %UpdateDialog


func _ready() -> void:
	_style()
	update_button.pressed.connect(_on_update_pressed)
	close_button.pressed.connect(_on_close_pressed)
	adult_check.passed.connect(_act)
	dialog.accepted.connect(_on_dialog_accepted)
	dialog.refused.connect(_on_dialog_refused)
	var manager: UpdateManagerClass = UpdateManager as UpdateManagerClass
	manager.release_changed.connect(_on_release_changed)
	manager.install_progressed.connect(_on_install_progressed)
	manager.install_failed.connect(_on_install_failed)
	# Both cards sit in the same corner. The server warning is the rarer and more
	# urgent of the two, so it keeps the corner and this one goes under it.
	var warning: Control = get_parent().get_node_or_null("ServerWarning") as Control
	if warning:
		warning.visibility_changed.connect(_stack_under.bind(warning))
		warning.resized.connect(_stack_under.bind(warning))
		_stack_under.call_deferred(warning)
	refresh()


func _stack_under(warning: Control) -> void:
	if not is_instance_valid(warning):
		return
	var top: float = Design.SCREEN_MARGIN
	if warning.visible:
		top = warning.position.y + warning.size.y + PANEL_PADDING
	offset_top = top


## Shows the card when a newer release is on offer, and says which.
func refresh() -> void:
	var manager: UpdateManagerClass = UpdateManager as UpdateManagerClass
	visible = manager.available != null and not dismissed
	if visible:
		body_label.text = tr("UPDATE_NOTICE_TEXT").format({
			"version": manager.available.version,
			"current": Utils.get_application_config_version(),
		})


func _style() -> void:
	var panel: StyleBoxFlat = MenuTheme.flat_stylebox(Color.WHITE, Design.CARD_RADIUS)
	panel.set_content_margin_all(PANEL_PADDING)
	add_theme_stylebox_override("panel", panel)
	for label: Label in [title_label, body_label]:
		label.add_theme_color_override("font_color", Design.NAVY)
	title_label.add_theme_font_override("font", load(Design.FONT_BOLD_PATH) as Font)
	update_button.add_theme_font_size_override("font_size", Design.FONT_SIZE_LABEL)
	close_button.self_modulate = Design.NAVY


func _on_release_changed(_release: AppRelease) -> void:
	refresh()


func _on_close_pressed() -> void:
	Log.info("UpdateNotice: Dismissed until the next launch")
	dismissed = true
	hide()


func _on_update_pressed() -> void:
	if EntryFlow.has_connection_token():
		Log.info("UpdateNotice: Asking the adult check before updating")
		adult_check.open()
		return
	_act()


## Does what this build can do about the update.
func _act() -> void:
	var manager: UpdateManagerClass = UpdateManager as UpdateManagerClass
	var action: UpdateManagerClass.Action = manager.action()
	Log.info("UpdateNotice: Update requested, action %s" % UpdateManagerClass.Action.keys()[action])
	match action:
		UpdateManagerClass.Action.OPEN_STORE:
			if not manager.open_store():
				_show_message(tr("UPDATE_STORE_FAILED"))
		UpdateManagerClass.Action.OPEN_DOWNLOAD:
			_open_download()
		UpdateManagerClass.Action.INSTALL_IN_APP:
			_ask_to_install()


func _ask_to_install() -> void:
	var manager: UpdateManagerClass = UpdateManager as UpdateManagerClass
	var key: String = "UPDATE_INSTALL_CONFIRM_MOBILE" if OS.has_feature("android") else "UPDATE_INSTALL_CONFIRM"
	dialog.title_text = tr("UPDATE_NOTICE_TITLE")
	dialog.content_text = tr(key).format({"version": manager.available.version})
	dialog.acknowledge_only = false
	dialog.confirm_text_override = "UPDATE_INSTALL"
	dialog.cancel_text_override = ""
	_set_dialog_closable(true)
	dialog.set_meta("step", "confirm")
	dialog.show()


func _on_dialog_accepted() -> void:
	match str(dialog.get_meta("step", "")):
		"confirm":
			dialog.set_meta("step", "installing")
			# Only Cancel while downloading: there is nothing left to confirm.
			dialog.confirm_button.visible = false
			(UpdateManager as UpdateManagerClass).start_install()
		"failed":
			dialog.hide()
			_open_download()
		_:
			dialog.hide()


func _on_dialog_refused() -> void:
	if str(dialog.get_meta("step", "")) == "installing":
		(UpdateManager as UpdateManagerClass).cancel_install()
	dialog.hide()


func _on_install_progressed(stage: UpdateManagerClass.InstallStage, fraction: float) -> void:
	if not dialog.visible:
		return
	match stage:
		UpdateManagerClass.InstallStage.DOWNLOADING:
			dialog.content_text = tr("UPDATE_DOWNLOADING").format({
				"percent": str(roundi(fraction * 100.0)) if fraction >= 0.0 else "…"})
		UpdateManagerClass.InstallStage.INSTALLING:
			# The files are being swapped: cancelling now could not be honoured.
			_set_dialog_closable(false)
			dialog.content_text = tr("UPDATE_INSTALLING")
		UpdateManagerClass.InstallStage.RESTARTING:
			_set_dialog_closable(false)
			dialog.content_text = tr("UPDATE_RESTARTING")
		UpdateManagerClass.InstallStage.SYSTEM_INSTALLER:
			_show_message(tr("UPDATE_CONFIRM_ON_DEVICE"))


func _on_install_failed(_reason: String) -> void:
	dialog.title_text = tr("UPDATE_NOTICE_TITLE")
	dialog.content_text = tr("UPDATE_FAILED")
	dialog.acknowledge_only = false
	dialog.confirm_text_override = "UPDATE_DOWNLOAD_IN_BROWSER"
	dialog.cancel_text_override = "CLOSE"
	_set_dialog_closable(true)
	dialog.set_meta("step", "failed")
	dialog.show()


func _open_download() -> void:
	if (UpdateManager as UpdateManagerClass).open_download():
		_show_message(tr("UPDATE_BROWSER_TEXT"))
	else:
		_show_message(tr("UPDATE_STORE_FAILED"))


## A message with only OK to press.
func _show_message(text: String) -> void:
	dialog.title_text = tr("UPDATE_NOTICE_TITLE")
	dialog.content_text = text
	dialog.confirm_text_override = ""
	dialog.cancel_text_override = ""
	dialog.acknowledge_only = true
	_set_dialog_closable(true)
	dialog.cancel_button.visible = false
	dialog.set_meta("step", "message")
	dialog.show()


## Shows or hides every way out of the dialog: its buttons and its cross.
func _set_dialog_closable(closable: bool) -> void:
	dialog.set_buttons_visible(closable)
	if dialog.close_button:
		dialog.close_button.visible = closable
