extends GutTest
## The promise the code sheet's save makes: a file exists afterwards, always.
##
## What this guards is a teacher on a managed school tablet pressing the button
## and getting nothing -- no file, no message, nothing they could report. The
## order the saver works in is what fixes that, so the order is what is tested:
## drawn and kept first, offered to the teacher second, and every step after the
## first allowed to fail without taking the sheet with it.
##
## The drawing itself is not exercised here and cannot be: it renders each page
## through a SubViewport, and a headless run has no rendering server to hand one
## back. So the placement is driven with bytes of its own -- which is the shape
## the saver already works in, precisely because the drawing and the writing fail
## for unrelated reasons.
##
## Nothing here can exercise Android's own picker either. What it can do is check
## that everything around a picker survives it: a cancel, a folder that refuses
## the file, and a device where nothing can be chosen at all.

## Somewhere to stand in for the system's Documents folder, so a test never
## writes into the folder of whoever is running it.
const DOCUMENTS_STAND_IN: String = "user://code_sheet_saver_documents"
## A path no platform will accept, for the folder-refuses-the-file case.
const IMPOSSIBLE_PATH: String = "/code_sheet_saver_no_such_root/Codes.pdf"
## Stands in for a drawn sheet. Not a real PDF: nothing here reads it back.
const DRAWN_SHEET: String = "%PDF-1.4 stand-in for a drawn sheet\n"

var host: Node
var dialog: FileDialog
var saver: CodeSheetSaver
## What the next answered dialog picks, read by the helpers at the bottom.
var _path_to_choose: String = ""


func before_each() -> void:
	# The saver renders inside its host and has to be in the tree itself, to hear
	# the application lose focus.
	host = Node.new()
	add_child_autofree(host)
	dialog = FileDialog.new()
	add_child_autofree(dialog)
	MobileFileDialog.configure_save(dialog, "Export", CodeSheet.FILE_EXTENSION,
			CodeSheet.MIME_TYPE)
	# Never the platform's own picker here. Run with a window rather than headless
	# -- which is the only way the drawing test below can run at all -- and macOS
	# puts up a real NSSavePanel that sits there until a person answers it: the run
	# reports every test as passed and then never exits. What the platform hand-off
	# does is test_mobile_file_dialog.gd's business; this file is about what happens
	# around whichever dialog comes up.
	dialog.use_native_dialog = false
	saver = CodeSheetSaver.new(host, dialog)
	saver.documents_target = DOCUMENTS_STAND_IN.path_join(CodeSheet.DEFAULT_FILE_NAME)
	host.add_child(saver)
	DirAccess.make_dir_recursive_absolute(DOCUMENTS_STAND_IN)
	# Static, so it would otherwise leak from one test into the next.
	CodeSheetSaver.platform_picker_blocked = false
	_remove(CodeSheet.KEPT_FILE_PATH)
	_remove(saver.documents_target)


func after_each() -> void:
	# Freed after the test, but not before the next one puts its own dialog up --
	# and a second exclusive window over the same parent is an engine error. So the
	# dialog is taken down here rather than left to the free.
	dialog.hide()


func after_all() -> void:
	_remove(CodeSheet.KEPT_FILE_PATH)
	_remove(DOCUMENTS_STAND_IN.path_join(CodeSheet.DEFAULT_FILE_NAME))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DOCUMENTS_STAND_IN))


func test_a_teacher_who_chooses_nowhere_still_has_the_kept_sheet() -> void:
	# The whole point of the reordering. A cancelled dialog used to mean nothing
	# had ever been drawn, so the teacher walked away with nothing at all.
	var outcome: CodeSheetSaver.Outcome = await _place_and_cancel()

	assert_true(outcome.cancelled, "the teacher said no, which is theirs to decide")
	assert_eq(outcome.placed_path, "", "so there is no copy of their own")
	assert_true(outcome.has_a_sheet(), "but the sheet was written before any of this")
	assert_eq(outcome.best_path(), CodeSheet.KEPT_FILE_PATH,
		"and the kept copy is the one worth telling them about")
	assert_false(outcome.could_not_place, "a cancel is not the device refusing anything")


func test_a_cancelled_dialog_is_not_mistaken_for_a_blocked_one() -> void:
	# The two look alike from out here and are told apart by whether the picker
	# ever took the foreground. Getting it wrong would make one cancel skip the
	# picker for the rest of the session.
	await _place_and_cancel()

	assert_false(CodeSheetSaver.platform_picker_blocked,
		"the picker did come up; the teacher just closed it")


func test_the_chosen_folder_gets_the_sheet() -> void:
	var chosen: String = "user://code_sheet_saver_chosen.pdf"
	_remove(chosen)

	var outcome: CodeSheetSaver.Outcome = await _place_and_choose(chosen)

	assert_eq(outcome.placed_path, chosen, "the teacher's copy goes where they said")
	assert_eq(outcome.best_path(), chosen, "and that is the one to tell them about")
	assert_eq(FileAccess.get_file_as_string(chosen), DRAWN_SHEET,
		"written from the bytes already drawn, rather than drawn a second time")
	_remove(chosen)


func test_a_folder_that_refuses_the_file_costs_a_copy_and_not_the_sheet() -> void:
	# A chosen folder can turn the write down on any platform: a sandbox, a
	# read-only card, a tablet's shared storage.
	var outcome: CodeSheetSaver.Outcome = await _place_and_choose(IMPOSSIBLE_PATH)

	_accept_the_logged_refusal()
	assert_eq(outcome.placed_path, saver.documents_target,
		"Documents is tried next rather than giving up on the teacher's copy")
	assert_true(FileAccess.file_exists(saver.documents_target))
	assert_false(outcome.could_not_place, "somewhere took it in the end")


func test_a_device_that_shows_no_picker_gets_the_sheet_put_in_documents() -> void:
	# What a locked-down tablet does: nothing comes up to choose with, so the
	# saver has to choose for the teacher.
	CodeSheetSaver.platform_picker_blocked = true

	var outcome: CodeSheetSaver.Outcome = await _place(DRAWN_SHEET.to_utf8_buffer())

	assert_false(dialog.visible, "a picker known to be blocked is not put up again")
	assert_eq(outcome.placed_path, saver.documents_target,
		"and the sheet goes where a Files app can find it")
	assert_false(outcome.cancelled, "nobody cancelled: there was nothing to cancel")
	assert_true(outcome.placed_unasked, "and the teacher was never asked where")


func test_a_sheet_the_device_placed_itself_says_where_it_went() -> void:
	# The teacher chose nothing -- there was nothing to choose with -- so they cannot
	# be told it went where they chose. Naming Documents is the only thing that tells
	# them where to look, and this is exactly the case a blocked tablet lands in.
	CodeSheetSaver.platform_picker_blocked = true

	var outcome: CodeSheetSaver.Outcome = await _place(DRAWN_SHEET.to_utf8_buffer())

	assert_true(outcome.placed_unasked, "nobody was asked, so nobody chose")
	assert_eq(CodeSheetSaver.report_for(outcome),
		TranslationServer.translate("CODE_SHEET_SAVED_AT").format(
			{"path": ProjectSettings.globalize_path(outcome.placed_path)})
		if AccountCreated.can_show_folder()
		else TranslationServer.translate("CODE_SHEET_SAVED_IN_DOCUMENTS"),
		"a path where one can be acted on, and the folder's name where it cannot")


func test_a_folder_the_teacher_chose_is_not_reported_as_the_device_s_doing() -> void:
	var chosen: String = "user://code_sheet_saver_chosen_report.pdf"
	_remove(chosen)

	var outcome: CodeSheetSaver.Outcome = await _place_and_choose(chosen)

	assert_false(outcome.placed_unasked, "they were asked, and they answered")
	_remove(chosen)


# --- The watchdog only has a say about the wait it was started for ---------------
## It cannot be called off: a SceneTreeTimer that is already running keeps running,
## so a watchdog outlives the export that started it. What stops it speaking for the
## next one is the generation it was handed.
func test_a_watchdog_says_nothing_about_a_later_export_than_its_own() -> void:
	# The teacher exports, picks quickly, and exports again inside the grace period.
	# Without the generation the first export's timer would call the second one's
	# picker blocked -- while it is on screen -- and skip the picker for the rest of
	# the session.
	assert_false(CodeSheetSaver.picker_never_opened(1, 2, false, false),
		"the wait it was started for is over; this one is somebody else's")
	assert_true(CodeSheetSaver.picker_never_opened(2, 2, false, false),
		"its own wait, unsettled, and the app never left: nothing came up")
	assert_false(CodeSheetSaver.picker_never_opened(2, 2, true, false),
		"already answered")
	assert_false(CodeSheetSaver.picker_never_opened(2, 2, false, true),
		"the app lost focus, which is what a picker opening looks like")


func test_each_wait_is_a_generation_of_its_own() -> void:
	# The counter is what the watchdog checks against, so a second wait has to move
	# it. Both waits are answered, so neither is left hanging.
	var before: int = saver._wait_generation
	await _place_and_cancel()
	var after_one: int = saver._wait_generation
	await _place_and_cancel()

	assert_eq(after_one, before + 1, "the first wait counted up")
	assert_eq(saver._wait_generation, before + 2, "and so did the second")


func test_a_device_that_refuses_everything_still_keeps_the_sheet() -> void:
	CodeSheetSaver.platform_picker_blocked = true
	saver.documents_target = IMPOSSIBLE_PATH

	var outcome: CodeSheetSaver.Outcome = await _place(DRAWN_SHEET.to_utf8_buffer())

	_accept_the_logged_refusal()
	assert_true(outcome.could_not_place, "nowhere outside the app would take it")
	assert_true(outcome.has_a_sheet(), "but the app's own folder always does")
	assert_eq(CodeSheetSaver.report_for(outcome),
		TranslationServer.translate("CODE_SHEET_KEPT_IN_APP_ONLY"),
		"and the teacher is told so, rather than left guessing")


func test_nothing_is_kept_when_there_was_nothing_to_draw() -> void:
	# The one failure that leaves no sheet at all, and so the only one where the
	# teacher has to be told the export did not happen.
	var outcome: CodeSheetSaver.Outcome = await saver.save(null)

	_accept_the_logged_refusal()
	assert_false(outcome.has_a_sheet())
	assert_ne(outcome.error, OK, "the failure is reported rather than swallowed")
	assert_eq(CodeSheetSaver.report_for(outcome),
		TranslationServer.translate("CODE_SHEET_FAILED"))
	assert_false(FileAccess.file_exists(CodeSheet.KEPT_FILE_PATH),
		"and no empty file is left behind to be printed by mistake")


func test_a_second_press_does_not_start_a_second_drawing() -> void:
	# Two presses used to mean two sets of pages rendering inside the same screen.
	# Set rather than raced: a save in flight is exactly this flag, and racing a
	# real one would be a test of the scheduler.
	saver.busy = true

	var second: CodeSheetSaver.Outcome = await saver.save(_settings())

	assert_eq(second.error, ERR_BUSY, "the second press is answered by the first")
	assert_false(FileAccess.file_exists(CodeSheet.KEPT_FILE_PATH),
		"and nothing is drawn or written on its behalf")


func test_a_real_drawing_ends_up_in_the_kept_copy() -> void:
	# The one test that goes through the drawing itself, and so the one that only
	# runs where there is a rendering server to draw with -- a desktop, not CI.
	# It is what says the stand-in the rest of this file uses is a fair one.
	if DisplayServer.get_name() == "headless":
		pending("no rendering server: a SubViewport hands back no texture to save")
		return
	saver.drawing_finished.connect(_cancel_the_dialog_later, CONNECT_ONE_SHOT)

	var outcome: CodeSheetSaver.Outcome = await saver.save(_settings())
	await get_tree().process_frame

	assert_true(outcome.has_a_sheet(), "a drawing that worked is a sheet that exists")
	assert_eq(FileAccess.get_file_as_string(CodeSheet.KEPT_FILE_PATH).substr(0, 8),
		"%PDF-1.4", "and what was written is a PDF")


func test_a_press_takes_over_a_wait_that_is_going_nowhere() -> void:
	# The wait can only be reached with the picker gone -- it holds the screen while
	# it is up -- so a press arriving during one means the picker answered nothing,
	# which Android manages by handing back a result code its own callback ignores.
	# Left alone, that wait would keep the button dead for the rest of the session.
	saver.busy = true
	saver._waiting_for_a_folder = true
	# Collected in an array rather than a captured bool: a lambda captures locals
	# by value, so assigning to one inside it would never reach the test.
	var settled: Array[bool] = []
	saver._placement_settled.connect(func() -> void: settled.append(true))

	# Nothing to draw, so this press comes straight back -- the takeover is what is
	# being watched, not what the press goes on to do.
	var outcome: CodeSheetSaver.Outcome = await saver.save(null)

	_accept_the_logged_refusal()
	assert_eq(settled.size(), 1, "the wait that was going nowhere is let go of")
	assert_ne(outcome.error, ERR_BUSY, "and the new press is the one that goes ahead")
	assert_false(saver.busy, "with nothing left holding the button down afterwards")


func test_the_page_count_is_passed_on_so_a_screen_can_show_it() -> void:
	# Several frames a page and a page a device: a screen with nothing to show for
	# that is the other half of "the button does not work".
	var reported: Array[int] = []
	saver.drawing_progressed.connect(func(page: int, _page_count: int) -> void:
		reported.append(page))

	saver._on_page_drawn(1, 3)
	saver._on_page_drawn(2, 3)

	assert_eq(reported, [1, 2] as Array[int], "one report per page, in order")


func test_what_the_teacher_is_told_follows_where_the_sheet_went() -> void:
	var outcome: CodeSheetSaver.Outcome = CodeSheetSaver.Outcome.new()
	outcome.kept_path = CodeSheet.KEPT_FILE_PATH

	assert_eq(CodeSheetSaver.report_for(outcome),
		TranslationServer.translate("CODE_SHEET_IN_THE_FILES_APP" if OS.has_feature("ios")
			else "CODE_SHEET_KEPT_IN_APP"),
		"a kept copy alone is worth a word on how to get at it")

	outcome.placed_path = "content://com.android.providers.downloads/document/42"
	assert_eq(CodeSheetSaver.report_for(outcome),
		TranslationServer.translate("CODE_SHEET_SAVED"),
		"a document URI names no folder, so it is confirmed rather than quoted")

	outcome.placed_path = "user://code_sheet_saver_report.pdf"
	var expected: String = TranslationServer.translate("CODE_SHEET_SAVED_AT").format(
			{"path": ProjectSettings.globalize_path(outcome.placed_path)}) \
		if AccountCreated.can_show_folder() else TranslationServer.translate("CODE_SHEET_SAVED")
	assert_eq(CodeSheetSaver.report_for(outcome), expected,
		"a real path is named wherever a teacher could act on one")


func test_every_wording_the_report_uses_is_translated() -> void:
	# A missing row shows the teacher the key instead of the sentence, in a dialog
	# that only appears on the devices this whole change is for.
	for key: String in ["CODE_SHEET_FAILED", "CODE_SHEET_SAVED", "CODE_SHEET_SAVED_AT",
			"CODE_SHEET_SAVED_IN_DOCUMENTS", "CODE_SHEET_KEPT_IN_APP",
			"CODE_SHEET_KEPT_IN_APP_ONLY", "CODE_SHEET_IN_THE_FILES_APP",
			"PREPARING_CODE_SHEET"]:
		for language: String in TranslationServer.get_loaded_locales():
			var translation: Translation = TranslationServer.get_translation_object(language)
			if not translation:
				continue
			assert_ne(translation.get_message(key), "",
				"%s should be translated into %s" % [key, language])


## Registration data for one device, enough to draw a sheet from.
func _settings() -> TeacherSettings:
	var settings: TeacherSettings = TeacherSettings.new()
	settings.account_type = TeacherSettings.AccountType.TEACHER
	var students: Array[StudentData] = []
	for index: int in 2:
		var student: StudentData = StudentData.new()
		student.code = TeacherSettings.AVAILABLE_CODES[index]
		students.append(student)
	settings.students[1] = students
	return settings


## Runs the placement on `pdf_data`, from an outcome that already has its kept copy.
##
## Stands in for save()'s second half. The first half is the drawing, which needs
## a rendering server -- see the note at the top of this file.
func _place(pdf_data: PackedByteArray) -> CodeSheetSaver.Outcome:
	var outcome: CodeSheetSaver.Outcome = CodeSheetSaver.Outcome.new()
	assert_eq(CodeSheet.write_pdf(CodeSheet.KEPT_FILE_PATH, pdf_data), OK,
		"the app's own folder is the one write that has to work")
	outcome.kept_path = CodeSheet.KEPT_FILE_PATH
	await saver._place_a_copy(pdf_data, outcome)
	# Settling the picker resumes this from inside the dialog's own signal, so
	# without a frame here the test body -- and GUT's tidying up after it -- would
	# run while that dialog is still emitting, which it is not allowed to be freed
	# during.
	await get_tree().process_frame
	return outcome


## Places the sheet, answering the dialog the way a teacher closing it would.
##
## The answer is sent deferred because the placement is one call: the dialog does
## not exist yet when it starts, and the end of the frame is the first moment it
## is up and waiting.
func _place_and_cancel() -> CodeSheetSaver.Outcome:
	_emit_cancel.call_deferred()
	return await _place(DRAWN_SHEET.to_utf8_buffer())


## Places the sheet, answering the dialog by choosing `path`.
func _place_and_choose(path: String) -> CodeSheetSaver.Outcome:
	_path_to_choose = path
	_emit_choice.call_deferred()
	return await _place(DRAWN_SHEET.to_utf8_buffer())


## Answers the dialog after the drawing, from inside the drawing's own signal:
## deferring is what lets the save get as far as putting the dialog up first.
func _cancel_the_dialog_later() -> void:
	_emit_cancel.call_deferred()


func _emit_cancel() -> void:
	dialog.canceled.emit()


func _emit_choice() -> void:
	dialog.file_selected.emit(_path_to_choose)


## A refused write is logged as an error, which is the point of it; acknowledge it
## so GUT does not report it as an unexpected one. Must run inside the test body:
## GUT checks for unhandled errors before after_each().
func _accept_the_logged_refusal() -> void:
	for tracked_error: GutTrackedError in get_errors():
		tracked_error.handled = true


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
