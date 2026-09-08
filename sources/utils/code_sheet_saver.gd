class_name CodeSheetSaver
extends Node
## Saves the sheet of student codes, and never comes back empty-handed.
##
## One button press crosses three things a school tablet can take away: the
## system's file picker, permission to write outside the app, and any folder the
## teacher can browse to. The complaint this exists for is that the button "does
## not work", which was all three failing without a word -- the sheet used to be
## drawn only *after* a folder had been chosen, so a picker that never came up
## left no file, no message and nothing in the log the teacher could see.
##
## So the order is inverted. The sheet is drawn and kept first, inside the app
## where nothing can refuse it, and the teacher is offered a copy of their own
## second. Everything after the first step is allowed to fail; whatever happens,
## the outcome names a file that exists.
##
## Lives as a child of the screen that owns the button: it renders the pages
## inside that screen, and it has to be in the tree to hear the application lose
## focus -- which is how it tells a picker that opened from one that never did.

## The pages are being drawn: several frames per page, during which the screen
## should hold still and say so.
signal drawing_started()
## `page` of `page_count` have been drawn.
signal drawing_progressed(page: int, page_count: int)
## The drawing is over, successfully or not. Always follows drawing_started.
signal drawing_finished()
## Emitted once the teacher has answered the picker, one way or another.
signal _placement_settled()
## Emitted once the permission request has been answered, or given up on.
signal _permission_settled()

## The permission Android gates shared storage behind, before Android 11.
##
## Only ever asked for when there is a file to put somewhere and the picker did
## not work. On Android 11 and up the request is ignored by the system -- scoped
## storage replaced it -- so this is for the older tablets, which are exactly the
## ones a school fleet is made of.
const SHARED_STORAGE_PERMISSION: String = "android.permission.WRITE_EXTERNAL_STORAGE"
## How long a platform picker is given to come up before it is taken as blocked.
##
## Only Android is watched, and there the picker is another app: the game is paused
## the moment it appears, which is both the signal that it did and the reason this
## timer cannot run out while it is up.
const PICKER_GRACE_SECONDS: float = 2.0
## How long the system's permission dialog is waited on before giving up on it.
##
## Generous, because it is a person answering, and the game is paused meanwhile so
## the wait costs nothing. It exists only so a dialog that never appears -- a
## managed device can suppress it -- does not leave this waiting forever.
const PERMISSION_WAIT_SECONDS: float = 120.0

## True once a platform picker was asked for and never appeared.
##
## Static, so it is remembered for the session and shared by both screens: a
## tablet that blocked the picker once will block it again, and the second export
## should not make the teacher sit through the grace period a second time.
static var platform_picker_blocked: bool = false

## The screen the pages are rendered inside. Has to stay in the tree while they are.
var host: Node
## The dialog the teacher chooses a folder with. Owned here: this connects and
## disconnects its signals itself, so a screen must not also listen to them.
var dialog: FileDialog
## True from the press until the outcome is in, so a second press is ignored
## rather than starting a second drawing over the first.
var busy: bool = false
## Where the sheet goes when the teacher could not be asked at all.
##
## The system's Documents folder, and a field rather than a call so a test can
## point it somewhere it is allowed to write -- pointing the real one at a
## developer's own Documents folder would be a poor way to run a test suite.
var documents_target: String = documents_file_path()
## Where the teacher said to put it, filled in by the dialog's own signals.
var _chosen_path: String = ""
## True once the picker has answered, so the watchdog knows it has nothing to do.
var _placement_is_settled: bool = false
## True while nothing but the teacher's answer is being waited on.
var _waiting_for_a_folder: bool = false
## True once a later press has taken over a wait that was going nowhere.
var _abandoned: bool = false
## True once the application lost focus after the picker was asked for -- which is
## what a picker actually opening looks like from in here.
var _left_the_game: bool = false
var _permission_answered: bool = false
var _permission_granted: bool = false


func _init(p_host: Node = null, p_dialog: FileDialog = null) -> void:
	name = "CodeSheetSaver"
	host = p_host
	dialog = p_dialog


## Draws the sheet, keeps a copy, and offers the teacher one of their own.
##
## Awaits the whole thing, the teacher's time at the picker included, and comes
## back when there is nothing left to try.
func save(settings: TeacherSettings) -> Outcome:
	var outcome: Outcome = Outcome.new()
	if busy and not _waiting_for_a_folder:
		# The pages are still being drawn, and a second set of them would render
		# over the first.
		Log.info("CodeSheetSaver: A sheet is already being drawn")
		outcome.error = ERR_BUSY
		return outcome
	if busy:
		# A folder is being waited on and yet a press got through -- which it can
		# only do with no picker in front of the teacher, since every picker holds
		# the screen behind it. So this is a wait nothing is going to answer:
		# Android's own callback ignores any result code that is neither OK nor
		# CANCELED, and a tablet short of memory can lose the picker outright.
		# Rather than leave the button dead for the rest of the session, the new
		# press takes the wait over and the old one unwinds with nothing to say.
		Log.warn("CodeSheetSaver: A second press arrived while a picker was still "
				+ "being waited on; taking that wait over")
		_abandoned = true
		_settle_placement()
	_abandoned = false
	busy = true

	drawing_started.emit()
	var pdf_data: PackedByteArray = await CodeSheet.render_pdf(host, settings, _on_page_drawn)
	drawing_finished.emit()

	if pdf_data.is_empty():
		Log.error("CodeSheetSaver: The sheet could not be drawn")
		outcome.error = ERR_CANT_CREATE
		busy = false
		return outcome

	# The one write that has to work, and the only one this asks nobody's
	# permission for. Everything below is a copy of a file that already exists.
	var kept_error: Error = CodeSheet.write_pdf(CodeSheet.KEPT_FILE_PATH, pdf_data)
	if kept_error != OK:
		Log.error("CodeSheetSaver: Even the app's own folder refused the sheet: %s"
				% error_string(kept_error))
		outcome.error = kept_error
		busy = false
		return outcome
	outcome.kept_path = CodeSheet.KEPT_FILE_PATH

	await _place_a_copy(pdf_data, outcome)
	busy = false
	return outcome


## The sentence to show the teacher about `outcome`.
##
## Here rather than at the two screens, so both say the same thing about the same
## outcome -- and so the wording follows the outcome rather than the screen.
static func report_for(outcome: Outcome) -> String:
	if not outcome.has_a_sheet():
		return TranslationServer.translate("CODE_SHEET_FAILED")
	if not outcome.placed_path.is_empty():
		# A content:// URI is a document Android's picker created for us. It names
		# no folder a teacher could act on, and they chose it themselves a moment
		# ago, so the confirmation is enough.
		if CodeSheet.is_document_uri(outcome.placed_path) \
				or not AccountCreated.can_show_folder():
			return TranslationServer.translate("CODE_SHEET_SAVED")
		return TranslationServer.translate("CODE_SHEET_SAVED_AT").format(
				{"path": ProjectSettings.globalize_path(outcome.placed_path)})
	# Only the kept copy is left, and its path is inside the app: something like
	# /data/user/0/org.../files, which says nothing to anybody. What is worth
	# saying is how to get at the sheet, and that differs by platform.
	if outcome.could_not_place:
		return TranslationServer.translate("CODE_SHEET_KEPT_IN_APP_ONLY")
	if OS.has_feature("ios"):
		# user:// *is* the app's Documents folder on iOS, which the Files app shows
		# whenever the build carries UIFileSharingEnabled.
		return TranslationServer.translate("CODE_SHEET_IN_THE_FILES_APP")
	return TranslationServer.translate("CODE_SHEET_KEPT_IN_APP")


## The sheet's place in the system's Documents folder, or "" if there is none.
##
## Documents rather than anywhere else: it is where a Files app opens, where a
## teacher looks for something to print, and -- on iOS -- the very folder user://
## already is.
static func documents_file_path() -> String:
	var documents: String = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if documents.is_empty():
		return ""
	return documents.path_join(CodeSheet.DEFAULT_FILE_NAME)


## Offers the teacher a copy wherever they can have one, and records what happened.
func _place_a_copy(pdf_data: PackedByteArray, outcome: Outcome) -> void:
	var chosen: String = await _ask_where_it_should_go()
	if _abandoned:
		# A later press took this over while it was waiting. Marked the way a press
		# that arrives mid-drawing is marked, because it comes to the same thing for
		# the screen: another attempt is in flight and this one has nothing to say.
		outcome.error = ERR_BUSY
		return

	if not chosen.is_empty():
		var target: String = CodeSheet.pdf_path(chosen)
		if await _write_outside_the_app(pdf_data, target):
			outcome.placed_path = target
			return
		# The teacher chose a folder and it turned the file away. Falling through
		# rather than reporting: Documents may still take it, and a sheet in a
		# folder they did not pick beats no sheet at all.
		Log.warn("CodeSheetSaver: %s would not take the sheet" % target)
	elif not platform_picker_blocked:
		# They were asked and said no, which is theirs to decide.
		outcome.cancelled = true
		return

	# Either nothing came up to choose with, or what was chosen refused the file.
	# Documents is the one place left worth trying without asking again.
	if not documents_target.is_empty() \
			and await _write_outside_the_app(pdf_data, documents_target):
		Log.info("CodeSheetSaver: Nothing could be chosen, so the sheet went to %s"
				% documents_target)
		outcome.placed_path = documents_target
		return

	Log.warn("CodeSheetSaver: The sheet could not be put anywhere outside the app")
	outcome.could_not_place = true


## Puts the sheet up for saving and waits for the answer, or for the silence that
## means no picker ever appeared. Returns where to write, or "" for nowhere.
func _ask_where_it_should_go() -> String:
	if platform_picker_blocked:
		# Asked once on this device and nothing came up. Skipping straight past it
		# spares the teacher another wait for a picker that is not going to appear.
		Log.info("CodeSheetSaver: This device blocked the picker before; not asking again")
		return ""

	_chosen_path = ""
	_placement_is_settled = false
	_left_the_game = false
	dialog.file_selected.connect(_on_file_selected)
	dialog.canceled.connect(_on_dialog_canceled)

	MobileFileDialog.open(dialog, CodeSheet.DEFAULT_FILE_NAME)
	_watch_for_a_picker_that_never_opened()
	_waiting_for_a_folder = true
	await _placement_settled
	_waiting_for_a_folder = false

	dialog.file_selected.disconnect(_on_file_selected)
	dialog.canceled.disconnect(_on_dialog_canceled)
	return _chosen_path


## Notices a platform picker that was asked for and never came up.
##
## Godot throws away the error the DisplayServer returns and hides its own dialog
## either way, so a picker the system refused to start is indistinguishable from
## one nobody has answered yet -- from the engine. Not from here: on Android the
## picker is a separate activity, so the application loses focus the instant it
## appears. No focus lost, nothing chosen, grace period over: it never opened.
##
## Android only. On the desktops the native dialog belongs to this same process,
## so focus never leaves and there would be no way to tell the two apart -- and a
## second dialog thrown on top of a working one is worse than the wait.
func _watch_for_a_picker_that_never_opened() -> void:
	if not OS.has_feature("android") or not dialog.use_native_dialog:
		return
	if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		return

	# The game is paused while the picker is up, so this timer stops with it: it
	# can only run out if nothing took the foreground.
	await get_tree().create_timer(PICKER_GRACE_SECONDS).timeout
	if _placement_is_settled or _left_the_game:
		return

	Log.warn("CodeSheetSaver: No picker came up in %.0f s; taking it as blocked"
			% PICKER_GRACE_SECONDS)
	platform_picker_blocked = true
	_chosen_path = ""
	_settle_placement()


## Writes the sheet to `path`, asking for permission first where that is a thing.
func _write_outside_the_app(pdf_data: PackedByteArray, path: String) -> bool:
	# A content:// document was created by the picker on the teacher's behalf and
	# comes with its own grant, so asking for a permission here would be a prompt
	# for nothing.
	if not CodeSheet.is_document_uri(path):
		await _ask_to_write_outside_the_app()
	return CodeSheet.write_pdf(path, pdf_data) == OK


## Asks Android, once, for permission to write outside the app.
##
## Returns whether the permission is held afterwards -- but the caller is expected
## to try the write regardless: on Android 11 and up the answer is always no and
## the write can still succeed, and on the desktops there is nothing to ask.
func _ask_to_write_outside_the_app() -> bool:
	if not OS.has_feature("android"):
		return true
	if OS.get_granted_permissions().has(SHARED_STORAGE_PERMISSION):
		return true

	Log.info("CodeSheetSaver: Asking for permission to write outside the app")
	_permission_answered = false
	_permission_granted = false
	var tree: SceneTree = get_tree()
	tree.on_request_permissions_result.connect(_on_permission_result)
	if not OS.request_permission(SHARED_STORAGE_PERMISSION):
		tree.on_request_permissions_result.disconnect(_on_permission_result)
		Log.info("CodeSheetSaver: The device would not even ask")
		return false

	# Paired with the answer, so a dialog a managed device suppresses does not
	# leave this waiting for a person who was never shown anything.
	var patience: SceneTreeTimer = tree.create_timer(PERMISSION_WAIT_SECONDS)
	patience.timeout.connect(_on_permission_given_up_on)
	await _permission_settled

	tree.on_request_permissions_result.disconnect(_on_permission_result)
	return _permission_granted


## Forwarded rather than emitted straight from the render loop: CodeSheet takes a
## Callable so it does not have to know what a screen does with the count.
func _on_page_drawn(page: int, page_count: int) -> void:
	drawing_progressed.emit(page, page_count)


func _on_file_selected(path: String) -> void:
	_chosen_path = path
	_settle_placement()


func _on_dialog_canceled() -> void:
	Log.info("CodeSheetSaver: The teacher chose no folder")
	_chosen_path = ""
	_settle_placement()


## Lets whoever is waiting on the picker carry on, once and once only.
func _settle_placement() -> void:
	if _placement_is_settled:
		return
	_placement_is_settled = true
	_placement_settled.emit()


func _on_permission_result(permission: String, granted: bool) -> void:
	if permission != SHARED_STORAGE_PERMISSION or _permission_answered:
		return
	Log.info("CodeSheetSaver: %s was %s"
			% [permission, "granted" if granted else "refused"])
	_permission_answered = true
	_permission_granted = granted
	_permission_settled.emit()


func _on_permission_given_up_on() -> void:
	if _permission_answered:
		return
	Log.info("CodeSheetSaver: The permission request went unanswered")
	_permission_answered = true
	_permission_granted = false
	_permission_settled.emit()


func _notification(what: int) -> void:
	# Both, because Android reports leaving for another app as either depending on
	# the version, and one of the two is all it takes to know the picker is up.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_APPLICATION_PAUSED:
		_left_the_game = true


## Where the sheet ended up, and what could not be done with it.
##
## Deliberately not just an Error: on a locked tablet the interesting outcome is
## the half-success -- the sheet exists, but only inside the app -- and that is
## what the teacher has to be told about.
class Outcome extends RefCounted:
	## The copy inside the app. Empty only when the drawing itself failed.
	var kept_path: String = ""
	## The teacher's own copy: the folder they chose, or the system's Documents
	## folder when nothing could be chosen. Empty when there is none.
	var placed_path: String = ""
	## Why there is no sheet at all. OK whenever `kept_path` is set.
	var error: Error = OK
	## The teacher dismissed the picker. Not a failure: they were asked and said no.
	var cancelled: bool = false
	## Nowhere outside the app would take the file, so only the kept copy exists.
	var could_not_place: bool = false


	## Whether there is a sheet at all, wherever it may be.
	func has_a_sheet() -> bool:
		return not kept_path.is_empty()


	## The file worth telling the teacher about: their own copy if there is one.
	func best_path() -> String:
		return placed_path if not placed_path.is_empty() else kept_path
