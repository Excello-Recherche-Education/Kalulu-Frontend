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
const PASSWORD_VISUALIZER_SCENE: PackedScene = preload("res://sources/menus/components/password_visualizer.tscn")
const EXPORT_COLUMNS: int = 2
const EXPORT_TITLE_FONT_SIZE: int = 44
const EXPORT_SECTION_FONT_SIZE: int = 32
const EXPORT_TEXT_FONT_SIZE: int = 28
const EXPORT_STUDENTS_PER_COLUMN: int = 16
const EXPORT_STUDENTS_PER_PAGE: int = EXPORT_STUDENTS_PER_COLUMN * EXPORT_COLUMNS
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


func _ready() -> void:
	refresh_devices()
	
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

	export_codes_file_dialog.set_title(tr("EXPORT_STUDENT_CODES"))
	export_codes_file_dialog.set_ok_button_text(tr("EXPORT_STUDENT_CODES"))
	export_codes_file_dialog.filters = []
	export_codes_file_dialog.add_filter("*.pdf", "pdf")
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


## Rebuilds the device pills and shows the selected device's students.
func refresh_devices() -> void:
	for child: Node in device_pills.get_children():
		child.queue_free()

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

	for child: Node in students_container.get_children():
		child.queue_free()
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
	export_codes_file_dialog.current_file = "Codes.pdf"
	export_codes_file_dialog.show()


func _on_export_codes_file_selected(path: String) -> void:
	if not UserDataManager.teacher_settings:
		Log.warn("SettingsTeacherSettings: Export canceled because teacher settings are missing")
		return

	Log.info("SettingsTeacherSettings: Export path selected: %s" % path)
	var code_pages: Array[Control] = _build_export_codes_pages()
	Log.info("SettingsTeacherSettings: Prepared %d export pages" % code_pages.size())
	var page_images: Array[Image] = []
	for page: Control in code_pages:
		var export_viewport: SubViewport = SubViewport.new()
		export_viewport.disable_3d = true
		export_viewport.transparent_bg = true
		export_viewport.size = page.size
		export_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		export_viewport.add_child(page)
		add_child(export_viewport)
		await get_tree().process_frame
		await get_tree().process_frame

		Log.info("SettingsTeacherSettings: Capturing export codes layout page %d/%d" % [page_images.size() + 1, code_pages.size()])
		page_images.append(export_viewport.get_texture().get_image())
		export_viewport.queue_free()

	var export_path: String = path
	if not export_path.ends_with(".pdf"):
		export_path += ".pdf"

	Log.info("SettingsTeacherSettings: Writing export PDF to %s" % export_path)
	var save_error: Error = _save_codes_pdf(export_path, page_images)
	if save_error != OK:
		Log.error("SettingsTeacherSettings: Failed to save export PDF. Error: %s" % error_string(save_error))
	else:
		Log.info("SettingsTeacherSettings: Export PDF saved successfully")


func _build_export_codes_pages() -> Array[Control]:
	Log.info("SettingsTeacherSettings: Building export codes layout")
	var pages: Array[Control] = []

	var teacher_settings: TeacherSettings = UserDataManager.teacher_settings
	var devices: Array = teacher_settings.students.keys()
	devices.sort()
	Log.info("SettingsTeacherSettings: Building export layout for %d devices" % devices.size())

	for device_id: int in devices:
		var students: Array[StudentData] = teacher_settings.students[device_id] as Array[StudentData]
		Log.info("SettingsTeacherSettings: Splitting device %d into pages of %d students" % [device_id, EXPORT_STUDENTS_PER_PAGE])
		for start_index: int in range(0, students.size(), EXPORT_STUDENTS_PER_PAGE):
			var end_index: int = min(start_index + EXPORT_STUDENTS_PER_PAGE, students.size())
			var current_page: Dictionary = _create_export_codes_page()
			var column_containers: Array[VBoxContainer] = current_page["columns"]
			var page_students: Array[StudentData] = students.slice(start_index, end_index)
			Log.info("SettingsTeacherSettings: Creating export page %d for device %d with %d students" % [
				pages.size() + 1,
				device_id,
				page_students.size()
			])
			for column_index: int in range(column_containers.size()):
				var column_start: int = column_index * EXPORT_STUDENTS_PER_COLUMN
				var column_end: int = min(column_start + EXPORT_STUDENTS_PER_COLUMN, page_students.size())
				if column_start >= page_students.size():
					break
				var column_students: Array[StudentData] = page_students.slice(column_start, column_end)
				var device_section: VBoxContainer = _build_device_section(device_id, column_students)
				column_containers[column_index].add_child(device_section)
			pages.append(current_page["canvas"])

	return pages


func _create_export_codes_page() -> Dictionary:
	var export_canvas: Control = Control.new()
	export_canvas.name = "ExportCodesCanvas"
	export_canvas.size = Vector2(1920, 1080)
	
	var panel: PanelContainer = PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 40
	panel.offset_top = 40
	panel.offset_right = -40
	panel.offset_bottom = -40
	panel.theme_type_variation = &"PanelKaluluBig"
	var export_panel_style: StyleBoxFlat = StyleBoxFlat.new()
	export_panel_style.bg_color = Color.WHITE
	panel.set("theme_override_styles/panel", export_panel_style)
	export_canvas.add_child(panel)

	var main_margin: MarginContainer = MarginContainer.new()
	main_margin.anchor_left = 0.0
	main_margin.anchor_top = 0.0
	main_margin.anchor_right = 1.0
	main_margin.anchor_bottom = 1.0
	main_margin.offset_left = 40
	main_margin.offset_top = 40
	main_margin.offset_right = -40
	main_margin.offset_bottom = -40
	panel.add_child(main_margin)

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.set("theme_override_constants/separation", 24)
	main_margin.add_child(main_vbox)

	var title_label: Label = Label.new()
	title_label.text = tr("STUDENT_CODES")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.set("theme_override_font_sizes/font_size", EXPORT_TITLE_FONT_SIZE)
	title_label.set("theme_override_colors/font_color", Color.BLACK)
	main_vbox.add_child(title_label)

	var content_hbox: HBoxContainer = HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.set("theme_override_constants/separation", 40)
	main_vbox.add_child(content_hbox)

	var column_containers: Array[VBoxContainer] = []
	for column_index: int in range(EXPORT_COLUMNS):
		var column: VBoxContainer = VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.set("theme_override_constants/separation", 18)
		content_hbox.add_child(column)
		column_containers.append(column)

	return {
		"canvas": export_canvas,
		"columns": column_containers
	}


func _build_device_section(device_id: int, students: Array[StudentData]) -> VBoxContainer:
	Log.info("SettingsTeacherSettings: Building device %d section with %d students" % [device_id, students.size()])
	var section: VBoxContainer = VBoxContainer.new()
	section.set("theme_override_constants/separation", 10)

	var device_label: Label = Label.new()
	device_label.text = tr("DEVICE_NUMBER").format({"number": device_id})
	device_label.set("theme_override_font_sizes/font_size", EXPORT_SECTION_FONT_SIZE)
	device_label.set("theme_override_colors/font_color", Color.BLACK)
	section.add_child(device_label)

	# Named for the printable sheet it belongs to: the screen's grid of student
	# cards is a different node with a similar job.
	var student_rows: VBoxContainer = VBoxContainer.new()
	student_rows.set("theme_override_constants/separation", 8)
	section.add_child(student_rows)

	var sorted_students: Array[StudentData] = students.duplicate()
	sorted_students.sort_custom(func(a: StudentData, b: StudentData) -> bool:
		return a.name.naturalnocasecmp_to(b.name) < 0
	)

	for student_index: int in range(sorted_students.size()):
		var student_data: StudentData = sorted_students[student_index]
		Log.info("SettingsTeacherSettings: Adding student row for %s (%s)" % [student_data.name, str(student_data.code)])
		student_rows.add_child(_build_student_row(student_data))
		if student_index < sorted_students.size() - 1:
			student_rows.add_child(_build_student_separator())

	section.add_child(_build_device_separator())
	return section


func _build_student_row(student_data: StudentData) -> HBoxContainer:
	Log.trace("SettingsTeacherSettings: Building row for student code %s" % str(student_data.code))
	var row: HBoxContainer = HBoxContainer.new()
	row.set("theme_override_constants/separation", 12)

	var name_label: Label = Label.new()
	name_label.text = student_data.name if student_data.name else tr("STUDENT_NUM").format({"number": student_data.code})
	name_label.set("theme_override_font_sizes/font_size", EXPORT_TEXT_FONT_SIZE)
	name_label.set("theme_override_colors/font_color", Color.BLACK)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var visualizer: PasswordVisualizer = PASSWORD_VISUALIZER_SCENE.instantiate() as PasswordVisualizer
	visualizer.key_size = 32
	visualizer.password = str(student_data.code)
	visualizer.show_backgrounds = false
	row.add_child(visualizer)

	return row


func _build_student_separator() -> HSeparator:
	var separator: HSeparator = HSeparator.new()
	separator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var line_style: StyleBoxLine = StyleBoxLine.new()
	line_style.color = Color("c7c7c7")
	line_style.thickness = 2
	separator.set("theme_override_styles/separator", line_style)
	return separator


func _build_device_separator() -> HSeparator:
	var separator: HSeparator = HSeparator.new()
	separator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var line_style: StyleBoxLine = StyleBoxLine.new()
	line_style.color = Color("8c8c8c")
	line_style.thickness = 4
	separator.set("theme_override_styles/separator", line_style)
	return separator


func _save_codes_pdf(path: String, images: Array[Image]) -> Error:
	if images.is_empty():
		Log.error("SettingsTeacherSettings: No pages to export")
		return ERR_CANT_CREATE

	var jpg_pages: Array[PackedByteArray] = []
	for page: Image in images:
		Log.info("SettingsTeacherSettings: Starting PDF build (%dx%d)" % [page.get_width(), page.get_height()])
		var jpg_data: PackedByteArray = page.save_jpg_to_buffer(0.9)
		if jpg_data.is_empty():
			Log.error("SettingsTeacherSettings: Failed to encode JPEG buffer for PDF")
			return ERR_CANT_CREATE
		jpg_pages.append(jpg_data)

	var pdf_data: PackedByteArray = PackedByteArray()
	var xref_offsets: Array[int] = [0]

	Log.info("SettingsTeacherSettings: Creating PDF objects")
	_append_pdf_string(pdf_data, "%PDF-1.4\n")
	_add_pdf_object(pdf_data, xref_offsets, "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
	var page_count: int = images.size()
	var kids_entries: PackedStringArray = []
	for page_index: int in range(page_count):
		var page_object_id: int = 3 + page_index * 3
		kids_entries.append("%d 0 R" % page_object_id)
	_add_pdf_object(
		pdf_data,
		xref_offsets,
		"2 0 obj\n<< /Type /Pages /Kids [%s] /Count %d >>\nendobj\n" % [" ".join(kids_entries), page_count]
	)

	for page_index: int in range(page_count):
		var page: Image = images[page_index]
		var jpg_data: PackedByteArray = jpg_pages[page_index]
		var width: int = page.get_width()
		var height: int = page.get_height()
		var page_object_id: int = 3 + page_index * 3
		var image_object_id: int = page_object_id + 1
		var content_object_id: int = page_object_id + 2
		var image_name: String = "Im%d" % page_index

		_add_pdf_object(
			pdf_data,
			xref_offsets,
			"%d 0 obj\n<< /Type /Page /Parent 2 0 R /Resources << /XObject << /%s %d 0 R >> /ProcSet [/PDF /ImageC] >> /MediaBox [0 0 %d %d] /Contents %d 0 R >>\nendobj\n"
				% [page_object_id, image_name, image_object_id, width, height, content_object_id]
		)

		var image_header: String = "%d 0 obj\n<< /Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length %d >>\nstream\n" % [image_object_id, width, height, jpg_data.size()]
		_add_pdf_object_with_stream(pdf_data, xref_offsets, image_header, jpg_data)

		var content_stream: String = "q\n%d 0 0 %d 0 0 cm\n/%s Do\nQ\n" % [width, height, image_name]
		var content_bytes: PackedByteArray = content_stream.to_utf8_buffer()
		var content_header: String = "%d 0 obj\n<< /Length %d >>\nstream\n" % [content_object_id, content_bytes.size()]
		_add_pdf_object_with_stream(pdf_data, xref_offsets, content_header, content_bytes)

	Log.info("SettingsTeacherSettings: Writing PDF xref table")
	var xref_offset: int = pdf_data.size()
	var xref_lines: PackedStringArray = []
	xref_lines.append("xref")
	xref_lines.append("0 %d" % xref_offsets.size())
	xref_lines.append("0000000000 65535 f ")
	for offset: int in xref_offsets.slice(1, xref_offsets.size()):
		xref_lines.append("%010d 00000 n " % offset)
	_append_pdf_string(pdf_data, "\n".join(xref_lines) + "\n")
	_append_pdf_string(pdf_data, "trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%EOF\n" % [xref_offsets.size(), xref_offset])

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		Log.error("SettingsTeacherSettings: Failed to open export path for writing")
		return ERR_CANT_OPEN
	Log.info("SettingsTeacherSettings: Storing PDF buffer (%d bytes)" % pdf_data.size())
	file.store_buffer(pdf_data)
	file.close()
	Log.info("SettingsTeacherSettings: PDF file written")
	return OK


func _add_pdf_object(pdf_data: PackedByteArray, offsets: Array[int], object_text: String) -> void:
	offsets.append(pdf_data.size())
	_append_pdf_string(pdf_data, object_text)


func _add_pdf_object_with_stream(pdf_data: PackedByteArray, offsets: Array[int], header: String, stream_data: PackedByteArray) -> void:
	offsets.append(pdf_data.size())
	_append_pdf_string(pdf_data, header)
	pdf_data.append_array(stream_data)
	_append_pdf_string(pdf_data, "\nendstream\nendobj\n")


func _append_pdf_string(pdf_data: PackedByteArray, text: String) -> void:
	pdf_data.append_array(text.to_utf8_buffer())

#endregion
