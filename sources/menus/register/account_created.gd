class_name AccountCreated
extends Control
## Confirms the account was created, and says where the codes went.
##
## The last thing registration does. It exists mostly to answer one question the
## teacher will have straight afterwards: where are the codes? If the sheet was
## saved it names the folder, and offers to open it on the platforms that have a
## file manager to hand off to. If it was not, it says where to find them later.

const NEXT_SCENE_PATH: String = "res://sources/menus/language_selection/package_downloader.tscn"

## The file the code sheet was written to, or "" when it was not saved.
##
## Static because this screen is reached by a scene change: the recap step writes
## the sheet and then the wizard replaces itself with this screen, so there is no
## instance to hand the path to. Cleared when registration starts, so a second
## run in the same session cannot inherit the first one's folder.
static var saved_codes_path: String = ""

@onready var tick: TextureRect = %Tick
@onready var codes_note: Label = %CodesNote
@onready var open_folder_button: Button = %OpenFolderButton
@onready var next_button: Button = %NextButton


## Whether this platform can be asked to show a folder.
##
## Android and iOS sandbox the app's storage and have no file manager to hand off
## to; the web export has no local filesystem at all.
static func can_show_folder() -> bool:
	return not OS.has_feature("mobile") and not OS.has_feature("web")


func _ready() -> void:
	# The artwork is a white tick; on the white badge it takes the brand purple.
	tick.self_modulate = Design.PURPLE
	next_button.pressed.connect(_on_next_pressed)
	open_folder_button.pressed.connect(_on_open_folder_pressed)
	_show_where_the_codes_are()


func _show_where_the_codes_are() -> void:
	if saved_codes_path.is_empty():
		Log.info("AccountCreated: The codes were not saved; pointing at the settings")
		codes_note.text = "CODES_AVAILABLE_IN_SETTINGS"
		codes_note.show()
		open_folder_button.hide()
		return

	# Globalized: the dialog normally hands back a real path, but a res:// or
	# user:// one would be shown to the teacher as a URI they cannot act on.
	var folder: String = ProjectSettings.globalize_path(saved_codes_path).get_base_dir()
	var wording: String = tr("CODES_SAVED_IN_FOLDER").format({"folder": folder})
	if can_show_folder():
		Log.info("AccountCreated: The codes are in %s, which can be opened" % folder)
		open_folder_button.text = wording
		open_folder_button.show()
		codes_note.hide()
	else:
		# Still worth naming, even when it cannot be opened from here.
		Log.info("AccountCreated: The codes are in %s; this platform cannot open it" % folder)
		codes_note.text = wording
		codes_note.show()
		open_folder_button.hide()


func _on_open_folder_pressed() -> void:
	Log.info("AccountCreated: Showing %s in the file manager" % saved_codes_path)
	# Points at the file rather than the folder: a file manager asked for a file
	# opens its folder with the file picked out, which is more use than the folder
	# alone.
	OS.shell_show_in_file_manager(ProjectSettings.globalize_path(saved_codes_path))


func _on_next_pressed() -> void:
	# The curtain is deliberately left alone on this leg: registration hands over
	# with it open and the package downloader never opens it, so closing it here
	# would hand the downloader a black screen.
	next_button.disabled = true
	var error: Error = get_tree().change_scene_to_file(NEXT_SCENE_PATH)
	if error != OK:
		Log.error(error_string(error))
		next_button.disabled = false
