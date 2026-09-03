class_name SettingsTeacherSettings
extends Control

## Items in the overflow menu, in the order the PopupMenu lists them.
enum OverflowItem {
	CHANGE_LANGUAGE,
	LOGOUT,
	DELETE_ACCOUNT,
}

# Both exits below run after the account is logged out or deleted, so the device
# no longer holds a token and the welcome screen is where it belongs.
const SIGNED_OUT_SCENE_PATH: String = EntryFlow.WELCOME_SCENE_PATH
const LOGIN_MENU_PATH: String = "res://sources/menus/login/login.tscn"
const SPLASH_SCREEN_PATH: String = "res://sources/menus/splash_screen/splash_screen.tscn"
const DEVICE_SELECTION_SCENE_PATH: String = "res://sources/menus/device_selection/device_selection.tscn"
const STUDENT_PANEL_SCENE: PackedScene = preload("res://sources/menus/settings/student_panel.tscn")
## The tick that fills the light-graphics box in. A path rather than a preload, for
## the same reason the box itself exists: nothing on this screen should carry
## artwork it might not draw.
const TICK_ICON_PATH: String = "res://assets/menus/icons/done.svg"
## What the server answers with when the account has used up every student code.
##
## Matched on the message because that is all the server sends: the status is a
## plain 400, the same as every other rejection. Should the wording ever change,
## the teacher gets the generic failure instead of the wrong explanation.
const STUDENT_LIMIT_ERROR: String = "Maximum student limit reached"

var last_device_id: int = -1
## Device whose students are on screen, or -1 before the first is chosen.
var selected_device: int = -1

@onready var device_pills: HBoxContainer = %DevicePills
@onready var device_pills_scroll: ScrollContainer = %DevicePillsScroll
@onready var students_container: GridContainer = %StudentsContainer
@onready var lesson_unlocks: LessonUnlocks = $LessonUnlocks
@onready var delete_popup: ConfirmPopup = %DeletePopup
@onready var change_language_popup: ChangeLanguagePopup = %ChangeLanguagePopup
@onready var change_language_error_popup: ConfirmPopup = %ChangeLanguageErrorPopup
@onready var loading_popup: LoadingPopup = %LoadingPopup
@onready var account_type_option_button: OptionButton = %AccountTypeOptionButton
@onready var education_method_option_button: OptionButton = %EducationMethodOptionButton
@onready var add_device_button: Button = %AddDeviceButton
@onready var add_student_button: Button = %AddStudentButton
@onready var label_internet_mandatory: Label = %LabelInternetMandatory
@onready var add_device_popup: CanvasLayer = %AddDevicePopup
@onready var add_student_popup: CanvasLayer = %AddStudentPopup
@onready var add_student_error_popup: ConfirmPopup = %AddStudentErrorPopup
@onready var delete_student_popup: CanvasLayer = %DeleteStudentPopup
@onready var export_codes_file_dialog: FileDialog = %ExportCodesFileDialog
@onready var menu_button: Button = %MenuButton
@onready var overflow_menu: PopupMenu = %OverflowMenu
@onready var light_graphics_check: Button = %LightGraphicsCheck
@onready var light_graphics_label: Label = %LightGraphicsLabel


func _ready() -> void:
	refresh_devices()
	light_graphics_label.gui_input.connect(_on_light_graphics_label_gui_input)
	_read_light_graphics()
	
	# Internet mandatory to add student because only the server can ensure the student code is not a duplicate
	if await ServerManager.check_internet_access():
		add_device_button.show()
		add_student_button.show()
		label_internet_mandatory.hide()
	else:
		add_device_button.hide()
		add_student_button.hide()
		label_internet_mandatory.show()
	
	# Built here rather than on the first student tap: it costs about two seconds
	# and this screen is already loading, so the tap itself stays instant.
	lesson_unlocks.prepare_lesson_rows()

	OpeningCurtain.open()
	lesson_unlocks.teacher_settings = self
	
	account_type_option_button.select(UserDataManager.teacher_settings.account_type)
	education_method_option_button.select(UserDataManager.teacher_settings.education_method)
	
	UserDataManager.user_database_synchronizer.loading_popup = loading_popup

	MobileFileDialog.configure_save(export_codes_file_dialog, tr("EXPORT_STUDENT_CODES"),
			CodeSheet.FILE_EXTENSION, CodeSheet.MIME_TYPE)
	export_codes_file_dialog.file_selected.connect(_on_export_codes_file_selected)
	Log.info("SettingsTeacherSettings: Export codes dialog configured")


func _exit_tree() -> void:
	# The synchronizer outlives this scene: clear the popup reference so a
	# later background synchronization does not call into a freed node.
	if UserDataManager.user_database_synchronizer.loading_popup == loading_popup:
		UserDataManager.user_database_synchronizer.loading_popup = null


func _on_account_type_option_button_item_selected(index: int) -> void:
	if TeacherSettings.AccountType.values().has(index):
		UserDataManager.teacher_settings.account_type = index as TeacherSettings.AccountType
		UserDataManager.teacher_settings.last_modified = Time.get_datetime_string_from_system(true)
		UserDataManager.save_teacher_settings()
	else:
		Log.warn("SettingsTeacherSettings: Cannot assign index %d to AccountType" % index)


func _on_education_method_option_button_item_selected(index: int) -> void:
	if TeacherSettings.EducationMethod.values().has(index):
		UserDataManager.teacher_settings.education_method = index as TeacherSettings.EducationMethod
		UserDataManager.teacher_settings.last_modified = Time.get_datetime_string_from_system(true)
		UserDataManager.save_teacher_settings()
	else:
		Log.warn("SettingsTeacherSettings: Cannot assign index %d to EducationMethod" % index)


## Empties a container now, rather than at the end of the frame.
##
## queue_free defers, and both callers refill the container in the same call, so
## the new children would be appended after the old ones instead of replacing
## them. For the pills that is not just a flicker: show_device presses
## get_child(index) with an index into the new device list, so with a stale pill
## still in front of them it pressed the wrong one -- adding a second device left
## device 1 highlighted over device 2's students. The student grid meanwhile laid
## out both sets of cards for a frame.
##
## Safe to free outright: neither container is rebuilt from one of its own
## children's signals.
func _clear_now(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.free()


## Rebuilds the device pills and shows the selected device's students.
func refresh_devices() -> void:
	_clear_now(device_pills)

	if not UserDataManager.teacher_settings:
		Log.error("SettingsTeacherSettings: Teacher settings not found")
		return

	var devices: Array = UserDataManager.teacher_settings.students.keys()
	devices.sort()
	var group: ButtonGroup = ButtonGroup.new()
	for device: int in devices:
		var pill: Button = Button.new()
		pill.text = tr("DEVICE_NUMBER").format({"number": device})
		pill.theme_type_variation = MenuTheme.VARIATION_TAB_PILL
		pill.custom_minimum_size = Vector2(Design.PILL_WIDTH, Design.PILL_HEIGHT)
		pill.toggle_mode = true
		pill.button_group = group
		pill.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		pill.focus_mode = Control.FOCUS_NONE
		pill.pressed.connect(show_device.bind(device))
		device_pills.add_child(pill)
		last_device_id = device

	# Keep the device already on screen selected across a refresh, so adding a
	# student does not bounce the teacher back to the first device.
	if not devices.has(selected_device):
		selected_device = devices[0] if devices else -1
	show_device(selected_device)


## Brings the pill at `index` into view, so the selected device is on screen.
##
## Only ever called when the selection changes, never on its own, so scrolling
## away from the selected device stays where the teacher left it.
func _scroll_to_selected_pill(index: int) -> void:
	# Waited for unconditionally: ensure_control_visible works off real geometry,
	# and a pill that has just been built has none until the row is laid out --
	# which is every time the settings are opened, since refresh_devices runs from
	# _ready. A pill's size is already its minimum by then, so it is no use as a
	# signal for whether the row has been positioned.
	#
	# Two of these overlapping cannot fight: the later call started later, so it
	# resumes later and has the last word.
	await get_tree().process_frame
	await get_tree().process_frame

	if index < 0 or index >= device_pills.get_child_count():
		return
	var pill: Control = device_pills.get_child(index) as Control
	if pill:
		device_pills_scroll.ensure_control_visible(pill)


## Fills the students grid with the students of `device`.
func show_device(device: int) -> void:
	selected_device = device
	var devices: Array = UserDataManager.teacher_settings.students.keys() if UserDataManager.teacher_settings else []
	devices.sort()
	var index: int = devices.find(device)
	for pill_index: int in device_pills.get_child_count():
		var pill: Button = device_pills.get_child(pill_index) as Button
		if pill:
			pill.set_pressed_no_signal(pill_index == index)
	_scroll_to_selected_pill(index)

	_clear_now(students_container)
	if device < 0 or not UserDataManager.teacher_settings:
		return
	lesson_unlocks.device = device

	var students: Array = UserDataManager.teacher_settings.students.get(device, [])
	var student_count: int = 1
	for student: StudentData in students:
		var panel: StudentPanel = STUDENT_PANEL_SCENE.instantiate()
		panel.student_count = student_count
		panel.student_data = student
		panel.pressed.connect(_on_student_pressed.bind(student.code))
		students_container.add_child(panel)
		student_count += 1


func _on_back_button_pressed() -> void:
	await OpeningCurtain.close()
	if not UserDataManager.get_device_settings().device_id:
		get_tree().change_scene_to_file(DEVICE_SELECTION_SCENE_PATH)
	else:
		get_tree().change_scene_to_file(LOGIN_MENU_PATH)


func _on_menu_button_pressed() -> void:
	# Dropped just under the button rather than at the pointer, so it lands in
	# the same place however it was opened.
	var below: Vector2 = menu_button.global_position + Vector2(0, menu_button.size.y)
	overflow_menu.position = Vector2i((get_window().position as Vector2) + below)
	overflow_menu.reset_size()
	overflow_menu.popup()


#region Light graphics

## Puts the light-graphics box in the position the device is actually in.
##
## Read here rather than authored in the scene: it is a device setting, so the same
## build opens with the box ticked or empty depending on the tablet.
func _read_light_graphics() -> void:
	light_graphics_check.button_pressed = UserDataManager.get_light_graphics()
	_refresh_light_graphics()


## Draws the box as ticked or empty.
##
## A toggling Button rather than a CheckBox, which is what the one other checkbox in
## the app does: a CheckBox draws its state as a themed icon beside its own text,
## and the design calls for a filled square with the wording separate. And the
## square is outlined pale here because this one sits on the navy page rather than
## on a white card, which is what the theme variation is drawn for.
func _refresh_light_graphics() -> void:
	var light: bool = light_graphics_check.button_pressed
	light_graphics_check.icon = load(TICK_ICON_PATH) as Texture2D if light else null
	var outline: StyleBoxFlat = MenuTheme.outline_stylebox(Color.WHITE, Design.BUTTON_RADIUS,
		Design.CHECKBOX_BORDER)
	for state: String in ["normal", "pressed", "focus"]:
		light_graphics_check.add_theme_stylebox_override(state, outline)
	var hovered: StyleBoxFlat = MenuTheme.outline_stylebox(Color.WHITE, Design.BUTTON_RADIUS,
		Design.CHECKBOX_BORDER)
	hovered.bg_color = Color(1.0, 1.0, 1.0, 0.15)
	for state: String in ["hover", "hover_pressed"]:
		light_graphics_check.add_theme_stylebox_override(state, hovered)


## Turns the decorative artwork off, or back on.
##
## Takes effect the next time a screen is built, which for a teacher leaving these
## settings means the very next one: the gardens and the minigames read the setting
## as they load. Nothing already on screen changes, and nothing needs restarting.
func _on_light_graphics_check_pressed() -> void:
	UserDataManager.set_light_graphics(light_graphics_check.button_pressed)
	_refresh_light_graphics()


## The wording toggles the box too, so the whole row is the target rather than a
## 120-pixel square next to it.
func _on_light_graphics_label_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		return
	light_graphics_label.accept_event()
	light_graphics_check.button_pressed = not light_graphics_check.button_pressed
	_on_light_graphics_check_pressed()

#endregion

func _on_overflow_menu_id_pressed(id: int) -> void:
	match id:
		OverflowItem.CHANGE_LANGUAGE:
			_on_change_language_button_pressed()
		OverflowItem.LOGOUT:
			_on_logout_button_pressed()
		OverflowItem.DELETE_ACCOUNT:
			_on_delete_button_pressed()
		_:
			Log.warn("SettingsTeacherSettings: Unknown overflow menu item %d" % id)


func _on_delete_button_pressed() -> void:
	delete_popup.show()


func _on_delete_popup_accepted() -> void:
	var res: Dictionary = await ServerManager.delete_account()
	if res.code == 200:
		UserDataManager.delete_teacher_data()
		UserDataManager.logout()
		get_tree().change_scene_to_file(SIGNED_OUT_SCENE_PATH)


func _on_logout_button_pressed() -> void:
	await OpeningCurtain.close()
	UserDataManager.logout()
	get_tree().change_scene_to_file(SIGNED_OUT_SCENE_PATH)


func _on_change_language_button_pressed() -> void:
	var current_language: String = UserDataManager.get_language()
	change_language_popup.show_for_current_language(current_language)


func _on_change_language_popup_accepted(new_language: String) -> void:
	if not new_language:
		Log.warn("SettingsTeacherSettings: Change language cancelled - no language selected")
		return
	var current_language: String = UserDataManager.get_language()
	if new_language == current_language:
		Log.info("SettingsTeacherSettings: Change language skipped - selected language matches current (%s)" % current_language)
		return
	Log.warn("SettingsTeacherSettings: Change language from %s to %s" % [current_language, new_language])

	var res: Dictionary = await ServerManager.reset_language(new_language)
	if res.code != 200:
		Log.error("SettingsTeacherSettings: Reset language request failed. Error code %d" % res.code)
		change_language_error_popup.show()
		return

	# Server confirmed: wipe all local teacher data, apply new language, and restart from splash.
	UserDataManager.delete_teacher_data()
	if UserDataManager.teacher_settings:
		UserDataManager.teacher_settings.server_language_validated = false
	UserDataManager.set_language(new_language, true)
	UserDataManager.logout()
	get_tree().change_scene_to_file(SPLASH_SCREEN_PATH)


func _on_student_pressed(code: int) -> void:
	lesson_unlocks.student = code
	lesson_unlocks.show()


func _on_add_student_button_pressed() -> void:
	add_student_popup.show()


func _on_add_student_popup_accepted() -> void:
	if selected_device < 0:
		Log.error("SettingsTeacherSettings: No device selected")
		return
	var res: Dictionary = await ServerManager.add_student({"device": selected_device})
	if res.code == 200:
		UserDataManager.update_configuration(res.body as Dictionary)
		show_device(selected_device)
	else:
		_report_add_student_failure(res)


## How many students the account has, across every device.
func get_student_count() -> int:
	if not UserDataManager.teacher_settings:
		return 0
	var total: int = 0
	for device_students: Variant in UserDataManager.teacher_settings.students.values():
		total += (device_students as Array).size()
	return total


## Tells the teacher why the student was not added.
##
## Adding a device adds its first student, so both ways in end up here and both
## can run into the same ceiling.
func _report_add_student_failure(res: Dictionary) -> void:
	Log.error("SettingsTeacherSettings: Request to add student failed. Error code %s, body %s"
		% [str(res.code), str(res.body)])
	var body: Dictionary = res.body as Dictionary if res.body is Dictionary else {}

	if body.get("error", "") == STUDENT_LIMIT_ERROR:
		add_student_error_popup.title_text = "MAXIMUM_STUDENTS_REACHED"
		# The number comes from the account rather than from a copy of the
		# server's limit kept here: a student's code is what the child taps to
		# log in, so the ceiling is however many codes exist, and an account that
		# has just been refused one is sitting exactly on it. A second copy of
		# that number here could only ever drift.
		add_student_error_popup.content_text = tr("MAXIMUM_STUDENTS_REACHED_POPUP").format(
			{"number": get_student_count()})
	else:
		add_student_error_popup.title_text = ""
		add_student_error_popup.content_text = "ADD_STUDENT_FAILED"
	add_student_error_popup.show()


func _on_add_device_button_pressed() -> void:
	add_device_popup.show()


func _on_add_device_popup_accepted() -> void:
	var res: Dictionary = await ServerManager.add_student({"device": last_device_id + 1})
	if res.code == 200:
		UserDataManager.update_configuration(res.body as Dictionary)
		# Show the device just created rather than leaving the teacher on the old
		# one wondering whether anything happened.
		selected_device = last_device_id + 1
		refresh_devices()
	else:
		# This path used to fail in complete silence, which is how a full account
		# looked like a broken button.
		_report_add_student_failure(res)


func _on_lesson_unlocks_student_deleted(_code: int) -> void:
	delete_student_popup.show()


func _on_delete_student_popup_accepted() -> void:
	if selected_device < 0:
		return
	var res: Dictionary = await ServerManager.remove_student(int(lesson_unlocks.student))
	if res.code == 200:
		lesson_unlocks.hide()
		UserDataManager.update_configuration(res.body as Dictionary)
		# Deleting the last student on a device removes the device too, so the
		# pills have to be rebuilt rather than just the grid.
		if UserDataManager.teacher_settings.students.has(selected_device):
			show_device(selected_device)
		else:
			refresh_devices()


func update_student_name(student_code: int, student_name: String) -> void:
	for student_panel: StudentPanel in students_container.get_children(false):
		if student_panel.student_data.code == student_code:
			student_panel.name_label.text = student_name
			return
	Log.warn("SettingsTeacherSettings: update_student_name: student not found with code " + str(student_code))

#region Synchronization

func _on_dashboard_button_pressed() -> void:
	var res: Dictionary = await ServerManager.get_dashboard()
	if res.code == 200:
		if res.has("body") and res.body is Dictionary:
			if (res.body as Dictionary).has("url"):
				OS.shell_open(res.body.url as String)
				return
		Log.error("SettingsTeacherSettings: Request to get Dashboard link has an invalid content")
	else:
		Log.error("SettingsTeacherSettings: Request to get Dashboard link failed. Error code " + str(res.code))


func _on_synchronize_button_pressed() -> void:
	UserDataManager.user_database_synchronizer.synchronize()


func _on_loading_popup_ok() -> void:
	loading_popup.hide()


func _on_loading_popup_cancel() -> void:
	Log.warn("SettingsTeacherSettings: User wanted to cancel synchronization but it is impossible to interrupt.")


func _on_export_codes_button_pressed() -> void:
	if not UserDataManager.teacher_settings:
		Log.warn("SettingsTeacherSettings: Cannot export student codes without teacher settings")
		return

	Log.info("SettingsTeacherSettings: Opening export codes dialog")
	MobileFileDialog.open(export_codes_file_dialog, CodeSheet.DEFAULT_FILE_NAME)


func _on_export_codes_file_selected(path: String) -> void:
	Log.info("SettingsTeacherSettings: Exporting the student codes to %s" % path)
	await CodeSheet.export_to_pdf(self, UserDataManager.teacher_settings, path)



#endregion
