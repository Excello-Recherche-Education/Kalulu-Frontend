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

@onready var recap_container: VBoxContainer = %RecapContainer
@onready var email: Label = %Email
@onready var account_type: Label = %AccountType
@onready var education_method: Label = %EducationMethod
@onready var devices_count: Label = %DevicesCount
@onready var students_count: Label = %StudentsCount
@onready var save_all_codes_button: Button = %SaveAllCodesButton
@onready var export_codes_file_dialog: FileDialog = %ExportCodesFileDialog
@onready var validate_button: Button = $RightMargin/RightContainer/ValidateButton


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

	_refresh_validate()


## Confirm only opens up once the code sheet has been asked for.
func _refresh_validate() -> void:
	validate_button.disabled = not codes_requested


func _on_save_all_codes_button_pressed() -> void:
	# Counted here rather than once the file is written: the teacher has been
	# shown the sheet exists and made the choice, and a cancelled save dialog must
	# not leave them stuck on this step.
	codes_requested = true
	_refresh_validate()
	export_codes_file_dialog.current_file = "Codes.pdf"
	export_codes_file_dialog.show()


func _on_export_codes_file_selected(path: String) -> void:
	# The account does not exist on the server yet, so the sheet is printed from
	# the registration data rather than from UserDataManager.
	Log.info("Register/RecapStep: Saving the student codes to %s" % path)
	await CodeSheet.export_to_pdf(self, data as TeacherSettings, path)
