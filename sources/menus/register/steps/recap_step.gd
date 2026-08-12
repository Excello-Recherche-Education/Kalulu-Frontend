@tool
class_name RecapStep
extends Step
## What the account is about to be, and the one chance to keep the codes.
##
## Confirm stays disabled until the teacher has asked for the code sheet. The
## codes are the only way a child logs in, and past this screen the sheet is
## several taps deep in Settings -- so the wizard asks for the export while it is
## still the obvious thing to do. Asking is enough: whether the save dialog was
## then seen through is the teacher's business, and refusing to continue over it
## would trap them on the last step.

const DEVICE_RECAP_SCENE: PackedScene = preload("res://sources/menus/register/steps/device_recap.tscn")

var codes_requested: bool = false
## What the sheet said when it was last asked for, so a later change invalidates it.
##
## Every answer above this step can still be changed, and two of them reach the
## paper: the number of students, which draws new codes, and a child's name, which
## is printed beside their code. Either one leaves the teacher holding a sheet that
## no longer describes the account. This is what makes that detectable.
var exported_sheet: String = ""
## True while the sheet is being drawn, which happens over several frames.
var drawing_the_sheet: bool = false

@onready var recap_container: VBoxContainer = %RecapContainer
@onready var email: Label = %Email
@onready var account_type: Label = %AccountType
@onready var education_method: Label = %EducationMethod
@onready var devices_count: Label = %DevicesCount
@onready var students_count: Label = %StudentsCount
@onready var save_all_codes_button: Button = %SaveAllCodesButton
@onready var export_codes_file_dialog: FileDialog = %ExportCodesFileDialog
@onready var validate_button: Button = $RightMargin/RightContainer/ValidateButton
@onready var back_button: Button = $LeftMargin/LeftContainer/BackButton


func _ready() -> void:
	show_question_board_as_card()
	export_codes_file_dialog.set_title(tr("EXPORT_STUDENT_CODES"))
	export_codes_file_dialog.set_ok_button_text(tr("EXPORT_STUDENT_CODES"))
	export_codes_file_dialog.filters = []
	export_codes_file_dialog.add_filter("*.pdf", "pdf")
	_refresh_validate()


func on_enter() -> void:
	super.on_enter()

	var teacher_settings: TeacherSettings = data as TeacherSettings
	if not teacher_settings:
		return

	email.text = tr("SUMMARY_EMAIL").format({"mail": teacher_settings.email})
	account_type.text = tr("SUMMARY_TYPE").format({"type":
		tr((TeacherSettings.AccountType.keys()[teacher_settings.account_type] as String).to_upper())})

	if teacher_settings.account_type == TeacherSettings.AccountType.TEACHER:
		education_method.text = tr("SUMMARY_METHOD").format({"method":
			tr((TeacherSettings.EducationMethod.keys()[teacher_settings.education_method] as String).to_upper())})
		education_method.show()

		students_count.text = tr("SUMMARY_NUMBER_OF_STUDENTS").format({"number":
			teacher_settings.get_number_of_students()})
		students_count.show()
	else:
		education_method.hide()
		students_count.hide()

	devices_count.text = tr("SUMMARY_NUMBER_OF_DEVICES").format({"number":
		teacher_settings.students.size()})
	devices_count.show()

	for child: Node in recap_container.get_children(false):
		child.queue_free()

	var devices: Array = teacher_settings.students.keys()
	devices.sort()
	for device: int in devices:
		var device_recap: DeviceRecap = DEVICE_RECAP_SCENE.instantiate()

		if teacher_settings.account_type == TeacherSettings.AccountType.TEACHER:
			device_recap.title = tr("DEVICE_NUMBER").format({"number": device})
		else:
			device_recap.title = tr("PLAYERS")
		device_recap.students = teacher_settings.students[device]

		recap_container.add_child(device_recap)

	_invalidate_a_stale_export()
	_refresh_validate()


## What the sheet would say about the account as it stands.
func sheet_fingerprint() -> String:
	var teacher_settings: TeacherSettings = data as TeacherSettings
	if not teacher_settings:
		return ""
	return CodeSheet.content_fingerprint(teacher_settings)


## Asks for the sheet again when it no longer says what the account says.
##
## Compares the whole sheet rather than watching for the ways it can go stale: the
## wizard lets every earlier answer be revisited, and there is no single place that
## knows a code was redrawn or a child renamed.
func _invalidate_a_stale_export() -> void:
	if not codes_requested or exported_sheet == sheet_fingerprint():
		return
	Log.info("Register/RecapStep: The sheet no longer matches the account; asking again")
	codes_requested = false
	# The confirmation screen would otherwise point at a PDF that describes an
	# account the teacher no longer has, which is worse than naming no folder at all.
	AccountCreated.saved_codes_path = ""


## Confirm only opens up once the code sheet has been asked for, and shuts again
## while one is being drawn.
func _refresh_validate() -> void:
	validate_button.disabled = not codes_requested or drawing_the_sheet


func _on_save_all_codes_button_pressed() -> void:
	# Counted here rather than once the file is written: the teacher has been
	# shown the sheet exists and made the choice, and a cancelled save dialog must
	# not leave them stuck on this step.
	codes_requested = true
	exported_sheet = sheet_fingerprint()
	_refresh_validate()
	export_codes_file_dialog.current_file = "Codes.pdf"
	export_codes_file_dialog.show()


func _on_export_codes_file_selected(path: String) -> void:
	# The account does not exist on the server yet, so the sheet is printed from
	# the registration data rather than from UserDataManager.
	Log.info("Register/RecapStep: Saving the student codes to %s" % path)
	# The step is held shut for as long as the drawing takes. A page is rendered
	# inside this step over two frames, and there is a page per device, so a school's
	# worth of them is seconds -- during which anything that takes this step out of
	# the tree loses the file outright: the pages have nowhere left to render, and the
	# PDF is only written once they have all been captured. Leaving the one screen
	# that insisted on the export, without the export, is the outcome to avoid.
	_hold_the_step_shut(true)
	var error: Error = await CodeSheet.export_to_pdf(self, data as TeacherSettings, path)
	# Handed to the confirmation screen, which offers to open the folder. Only on
	# success: pointing at a file that was never written would be worse than
	# saying nothing.
	if error == OK:
		AccountCreated.saved_codes_path = CodeSheet.pdf_path(path)
	# Released whether or not it worked. A failed export the teacher cannot walk away
	# from would strand them on the last step of registration.
	_hold_the_step_shut(false)


## Shuts or reopens everything on this step that could interrupt the drawing.
##
## Confirm submits and then changes scene; Previous takes the step out of the tree;
## and asking for the sheet again would start a second drawing over the first.
func _hold_the_step_shut(held: bool) -> void:
	drawing_the_sheet = held
	save_all_codes_button.disabled = held
	back_button.disabled = held
	_refresh_validate()
