class_name MobileFileDialog
extends Object
## Turns Godot's FileDialog into something that can be used with a thumb.
##
## The engine's dialog is an editor tool wearing a game's theme: a Favorites and
## Recent sidebar down the left, nine header buttons the size of a fingernail, and
## a file list at the engine's default 16px. The teacher meets it when they export
## the sheet of student codes, and they do that from a tablet at least as often as
## from a laptop, where none of it can be hit.
##
## Nothing here is drawn. Godot 4.7 reworked FileDialog and exposes nearly all of
## that chrome as properties, so this only switches off what answers no question,
## scales up what is left, and hands the whole job to the platform's own picker
## wherever there is one. A dialog rebuilt from scratch would have had to
## re-implement navigation, filtering and the overwrite warning to arrive here.
##
## Which platforms hand it off matters, because the fallback is not a rare path:
## Android has a native picker through the Storage Access Framework, and so do the
## three desktops. iOS and the web export have none -- the engine leaves the feature
## unimplemented on both -- and fall back to the dialog configured below without
## saying anything. So every iPad, iPhone and browser sees exactly what is here.

## How wide the one navigation button is drawn, in design units.
##
## The only control here the theme has nothing to say about: it is an icon button,
## sized by its icon, and the icons are the engine's own 16px ones. On the 2560-wide
## design canvas this is around 7mm across on a 6" phone, the target size Android
## and iOS both ask for. Everything else in the dialog is text, and the theme in
## force already sizes text for this canvas -- which is why the dialog is drawn at
## that theme's scale and not blown up on top of it. It was, at 2.0, and the result
## was 58-pixel text at 116: the buttons ran into the edges of the window and the
## file list was squeezed into a three-row strip.
const NAVIGATION_BUTTON_SIZE: float = 140.0

## Marks a dialog that has already been opened once, so open() can tell a first
## appearance from a return to one.
const OPENED_BEFORE: StringName = &"mobile_file_dialog_opened"

## Marks a dialog whose list has been wired for tapping, so configuring one twice
## cannot leave it navigating twice per tap.
const TAP_WIRED: StringName = &"mobile_file_dialog_tap_wired"

## How much of the dialog's own panel is left showing around everything inside it.
##
## The stylebox a theme hands an AcceptDialog has content margins of very nearly
## nothing -- 0, 0, 0, 2 -- and AcceptDialog insets its contents by exactly those,
## so the file list and the buttons ran into the edges of the window and there was
## no seam left between the window and the game drawn behind it.
const PANEL_INSET: float = 48.0

## The share of the screen the dialog covers when it opens.
##
## Generous on purpose: the interface inside it is drawn at INTERFACE_SCALE, and a
## window sized for the unscaled version would clip its own file list.
const SCREEN_RATIO: float = 0.66


## Prepares `dialog` to save one kind of file, and to be operated by hand.
##
## `title` is used for both the window and its confirm button, so the button says
## what it does rather than "Save". `mime_type` is the one Android's picker filters
## on; `extension` is what every other platform reads.
static func configure_save(dialog: FileDialog, title: String, extension: String, mime_type: String) -> void:
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.title = title
	dialog.ok_button_text = title
	dialog.filters = []
	dialog.add_filter("*.%s" % extension, extension, mime_type)
	# After the filter, not before: the format menu is only worth hiding once it is
	# known to hold a single entry.
	configure(dialog)


## Strips `dialog` down and scales up what is left of it.
static func configure(dialog: FileDialog) -> void:
	# ACCESS_FILESYSTEM rather than the default ACCESS_RESOURCES, which costs both
	# halves of the job: res:// lives inside the .pck in an exported build and
	# cannot be written to, and it is also the one access mode Android's native
	# picker refuses -- it would need FEATURE_NATIVE_DIALOG_FILE_EXTRA, which
	# Android does not implement, so the dialog would silently stay the custom one.
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	# Wherever the platform has one: Android's Storage Access Framework and the three
	# desktop file managers, all of them better than anything worth rebuilding here.
	# The engine only takes it up where FEATURE_NATIVE_DIALOG_FILE is implemented, so
	# iOS and the web export fall through to what follows.
	#
	# One cost comes with that, accepted rather than fought: macOS opens its save
	# panel collapsed -- a name field and a menu of recent folders, no file list, no
	# way into a folder until the chevron beside the name is clicked. Godot builds a
	# bare NSSavePanel and never touches its expanded state, so there is nothing to
	# set from here; macOS remembers the expanded state per app once somebody has
	# clicked it once.
	dialog.use_native_dialog = true

	_switch_off_features(dialog)
	# A list rather than the default grid of thumbnails: both are comfortable to hit,
	# but only the list shows a long folder name in full.
	dialog.display_mode = FileDialog.DISPLAY_LIST
	# The title bar is drawn by the embedder in a fixed size of its own, so on a
	# phone it is an unreadable strip with a close button too small to aim at. What
	# goes with it is a second way to cancel, and the dialog's own Cancel button is
	# right there.
	dialog.borderless = true

	_hide_chrome_without_a_flag(dialog)
	_translate_engine_labels(dialog)
	_open_folders_on_a_single_tap(dialog)


## Opens `dialog` on `file_name`.
static func open(dialog: FileDialog, file_name: String) -> void:
	dialog.current_file = file_name
	# Documents on the first opening: on Android and iOS it is the folder their Files
	# app opens on, and on a desktop it is where somebody looks for a thing they
	# saved -- either way better than wherever the process happens to be standing.
	# Only the first, though: after that the dialog stays wherever the teacher
	# browsed to, which is the point of their being able to browse at all.
	if not dialog.has_meta(OPENED_BEFORE):
		dialog.set_meta(OPENED_BEFORE, true)
		var documents: String = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
		if not documents.is_empty():
			dialog.current_dir = documents
	# Here rather than in configure(): the theme a screen puts on its root reaches
	# the dialog's own controls a frame after they are added, so anything read at
	# _ready() comes back as the project theme's instead of the one actually in
	# force -- 32 pixels where the settings screen draws 58. By the time a teacher
	# has pressed the button that opens this, it has long settled.
	_match_the_theme_in_force(dialog)
	_frame_the_window(dialog)
	dialog.popup_centered_ratio(SCREEN_RATIO)
	# The name field takes focus by itself, and on a phone focus is what raises the
	# on-screen keyboard: it would cover the folder list before the teacher has
	# chosen anything, which is the complaint KeyboardSpacer exists for elsewhere.
	# The name is already filled in, so the list is the better place to land, and
	# tapping the name still brings the keyboard up -- at the moment it is wanted.
	if OS.has_feature("mobile"):
		var files: ItemList = file_list(dialog)
		if files:
			files.grab_focus()


## Switches off everything that does not help answer "where, and under what name".
##
## All nine of these are Godot 4.7 properties; on 4.6 and earlier the script will
## not compile, which is the warning we would want.
static func _switch_off_features(dialog: FileDialog) -> void:
	dialog.favorites_enabled = false
	dialog.recent_list_enabled = false
	dialog.hidden_files_toggle_enabled = false
	dialog.layout_toggle_enabled = false
	dialog.file_sort_options_enabled = false
	dialog.file_filter_toggle_enabled = false
	dialog.folder_creation_enabled = false
	dialog.deleting_enabled = false
	# The one kept. Writing over last year's sheet is worth a question.
	dialog.overwrite_warning_enabled = true


## Hides the leftovers no customization flag covers.
##
## Reached through get_vbox(), which FileDialog offers for exactly this, and then
## by position, because the controls inside are unnamed. The layout is the
## engine's own, read off Godot 4.7.1: the box holds a header row, then an
## HSplitContainer whose second half is the pane around the file list.
##
## Those positions are the fragile part of this file, which is why
## test_mobile_file_dialog.gd asserts each one is the control it is taken to be. If
## an engine upgrade moves them, that test says so, instead of the dialog quietly
## keeping its clutter.
static func _hide_chrome_without_a_flag(dialog: FileDialog) -> void:
	var header: HBoxContainer = _child(dialog.get_vbox(), 0) as HBoxContainer
	if header:
		# 0 back, 1 forward, 3 the "Path:" caption, 4 the drive list, 6 the
		# shortcuts box, 7 refresh. Two are left standing: 2, the button that goes
		# up a folder, and 5, the path itself, which is the only thing that says
		# where you are. 8 and 9 are the favourite and new-folder buttons, already
		# gone with their flags.
		for position: int in [0, 1, 3, 4, 6, 7]:
			var control: Control = _child(header, position) as Control
			if control:
				control.visible = false

	var pane: VBoxContainer = _pane(dialog)
	if not pane:
		return
	# 0 is the "Directories & Files:" caption and the row of toggles it sat with,
	# every one of which is off by now.
	var caption: Control = _child(pane, 0) as Control
	if caption:
		caption.visible = false
	# The name row's format menu is a list of one: a question with a single answer,
	# taking up a third of the row.
	var file_row: Control = _name_row(dialog)
	if file_row and dialog.filters.size() <= 1:
		for child: Node in file_row.get_children():
			if child is OptionButton:
				(child as OptionButton).visible = false


## Makes one tap open a folder.
##
## The engine goes into a folder on the list's item_activated, which is a
## double-click. That is not a gesture a touch screen has, and not one anybody
## guesses with a mouse either: a single tap on a folder appears to do nothing at
## all, and the dialog reads as something that cannot be browsed -- there is no
## ".." row to suggest otherwise, only the one button up in the corner.
##
## So selection is forwarded to activation, for folders alone. Activating a file in
## save mode confirms the save outright, and a tap on last year's sheet should put
## its name in the field rather than write over it.
static func _open_folders_on_a_single_tap(dialog: FileDialog) -> void:
	# In this one mode picking a folder is the answer, not a way through to one.
	if dialog.file_mode == FileDialog.FILE_MODE_OPEN_DIR:
		return
	var files: ItemList = file_list(dialog)
	if not files or dialog.has_meta(TAP_WIRED):
		return
	dialog.set_meta(TAP_WIRED, true)
	files.item_selected.connect(func(index: int) -> void:
		var selected: String = dialog.current_dir.path_join(files.get_item_text(index))
		if DirAccess.dir_exists_absolute(selected):
			files.item_activated.emit(index))


## Puts the engine's own two English words into the teacher's language.
##
## FileDialog builds its Cancel button and its "File:" caption from string literals
## of its own, and Godot only translates those for the editor. Nothing in the
## project's dictionary matches them, so on a French build they are the two English
## words in an otherwise French dialog. Both are said well enough by keys the sheet
## already carries, which is why this adds no rows to it.
static func _translate_engine_labels(dialog: FileDialog) -> void:
	var cancel: Button = _cancel_button(dialog)
	if cancel:
		cancel.text = TranslationServer.translate("CANCEL")
	# "Nom", rather than a translation of "File:": the colon and the space before it
	# differ by language and would have to be assembled here, and on a dialog whose
	# only job is saving there is nothing else the field could be naming.
	var caption: Label = _child(_name_row(dialog), 0) as Label
	if caption:
		caption.text = TranslationServer.translate("NAME")


## The dialog's Cancel button. AcceptDialog offers an accessor for the other one
## only, so this picks it out from beside it.
static func _cancel_button(dialog: FileDialog) -> Button:
	var confirm: Button = dialog.get_ok_button()
	for sibling: Node in confirm.get_parent().get_children():
		if sibling is Button and sibling != confirm:
			return sibling as Button
	return null


## Gives the window an edge, so it reads as a window rather than as a rectangle of
## colour laid over the screen.
##
## Three things do that here: room between the panel and its contents, a border
## around it, and corners. The border width and colour are taken from the confirm
## button and the radius from the name field, rather than chosen, so the window is
## edged the way everything else on the screen is edged -- and follows the theme if
## that ever changes.
static func _frame_the_window(dialog: FileDialog) -> void:
	var panel: StyleBoxFlat = dialog.get_theme_stylebox(&"panel", &"AcceptDialog") as StyleBoxFlat
	if not panel:
		return
	# Duplicated and never edited in place: that stylebox is the theme's own, and
	# every other dialog in the game is drawn with the very same instance.
	var framed: StyleBoxFlat = panel.duplicate() as StyleBoxFlat
	framed.set_content_margin_all(PANEL_INSET)

	var button: StyleBoxFlat = dialog.get_ok_button().get_theme_stylebox(&"normal") as StyleBoxFlat
	if button and button.border_width_top > 0:
		framed.set_border_width_all(button.border_width_top)
		framed.border_color = button.border_color
	var field: StyleBoxFlat = dialog.get_line_edit().get_theme_stylebox(&"normal") as StyleBoxFlat
	if field:
		framed.set_corner_radius_all(field.corner_radius_top_left)

	dialog.add_theme_stylebox_override(&"panel", framed)


## Brings the two controls the theme does not reach up to the size of the rest.
##
## The file list is one: no theme here gives ItemList a size or a colour of its own,
## so it takes whatever the theme's default is and the engine's 65% grey, which left
## the one part of the dialog a teacher actually reads as the one part that was hard
## to. Both are taken from the confirm button rather than written down here, so the
## rows match whichever theme the screen turned out to be using, and can never come
## out smaller than the text around them.
##
## The other is the navigation button, which has no text to be sized by at all.
static func _match_the_theme_in_force(dialog: FileDialog) -> void:
	var confirm: Button = dialog.get_ok_button()
	var text_size: int = confirm.get_theme_font_size(&"font_size")

	var files: ItemList = file_list(dialog)
	if files:
		files.add_theme_font_size_override(&"font_size", text_size)
		files.add_theme_color_override(&"font_color", confirm.get_theme_color(&"font_color"))
		# The engine pins each row's icon to the size of its own 16px glyph, and
		# ItemList multiplies that by icon_scale, so this is what keeps the folder
		# marks level with the names beside them.
		var glyph: Texture2D = dialog.get_theme_icon(&"file", &"FileDialog")
		if glyph and glyph.get_width() > 0:
			files.icon_scale = float(text_size) / float(glyph.get_width())

	var up: Button = _child(_child(dialog.get_vbox(), 0), 2) as Button
	if up:
		up.custom_minimum_size = Vector2(NAVIGATION_BUTTON_SIZE, NAVIGATION_BUTTON_SIZE)
		# Both, because icon_max_width is a ceiling and will not lift a small icon:
		# on its own it left a 32-pixel arrow adrift in the middle of the button.
		up.add_theme_constant_override(&"icon_max_width", int(NAVIGATION_BUTTON_SIZE * 0.7))
		up.expand_icon = true


## The list of files and folders inside `dialog`, or null if it is not laid out the
## way this file expects. Public because the test asserts against it.
static func file_list(dialog: FileDialog) -> ItemList:
	return _child(_pane(dialog), 1) as ItemList


## The row the file name is typed into, or null on an unexpected layout.
static func _name_row(dialog: FileDialog) -> HBoxContainer:
	return _child(_pane(dialog), 3) as HBoxContainer


## The half of the split holding the file list, or null on an unexpected layout.
static func _pane(dialog: FileDialog) -> VBoxContainer:
	var split: HSplitContainer = _child(dialog.get_vbox(), 1) as HSplitContainer
	return _child(split, 1) as VBoxContainer


## `parent`'s child at `position`, or null rather than an error when it is absent.
static func _child(parent: Node, position: int) -> Node:
	if not parent or position >= parent.get_child_count():
		return null
	return parent.get_child(position)
