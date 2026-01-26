class_name SettingsTeacherSettings
extends Control

const MAIN_MENU_PATH: String = "res://sources/menus/main/main_menu.tscn"
const LOGIN_MENU_PATH: String = "res://sources/menus/login/login.tscn"
const DEVICE_SELECTION_SCENE_PATH: String = "res://sources/menus/device_selection/device_selection.tscn"
const DEVICE_TAB_SCENE: PackedScene = preload("res://sources/menus/settings/device_tab.tscn")
const PASSWORD_VISUALIZER_SCENE: PackedScene = preload("res://sources/menus/components/password_visualizer.tscn")
const EXPORT_COLUMNS: int = 2
const EXPORT_MAX_ROWS: int = 18
const EXPORT_TITLE_FONT_SIZE: int = 44
const EXPORT_SECTION_FONT_SIZE: int = 32
const EXPORT_TEXT_FONT_SIZE: int = 28
const EXPORT_STUDENTS_PER_COLUMN: int = 16
const EXPORT_STUDENTS_PER_PAGE: int = EXPORT_STUDENTS_PER_COLUMN * EXPORT_COLUMNS

var last_device_id: int = -1

@onready var devices_tab_container: TabContainer = %DevicesTabContainer
@onready var lesson_unlocks: LessonUnlocks = $LessonUnlocks
@onready var delete_popup: ConfirmPopup = %DeletePopup
@onready var loading_popup: LoadingPopup = %LoadingPopup
@onready var account_type_option_button: OptionButton = %AccountTypeOptionButton
@onready var education_method_option_button: OptionButton = %EducationMethodOptionButton
@onready var add_device_button: Button = %AddDeviceButton
@onready var add_student_button: Button = %AddStudentButton
@onready var label_internet_mandatory: Label = %LabelInternetMandatory
@onready var add_device_popup: CanvasLayer = %AddDevicePopup
@onready var add_student_popup: CanvasLayer = %AddStudentPopup
@onready var delete_student_popup: CanvasLayer = %DeleteStudentPopup
@onready var export_codes_file_dialog: FileDialog = %ExportCodesFileDialog


func _ready() -> void:
	refresh_devices_tabs()
	
	# Internet mandatory to add student because only the server can ensure the student code is not a duplicate
	if await ServerManager.check_internet_access():
		add_device_button.show()
		add_student_button.show()
		label_internet_mandatory.hide()
	else:
		add_device_button.hide()
		add_student_button.hide()
		label_internet_mandatory.show()
	
	OpeningCurtain.open()
	lesson_unlocks.teacher_settings = self
	
	account_type_option_button.select(UserDataManager.teacher_settings.account_type)
	education_method_option_button.select(UserDataManager.teacher_settings.education_method)
	
	UserDataManager.user_database_synchronizer.loading_popup = loading_popup
	UserDataManager.user_database_synchronizer.account_type_option_button = account_type_option_button
	UserDataManager.user_database_synchronizer.education_method_option_button = education_method_option_button

	export_codes_file_dialog.set_title(tr("EXPORT_STUDENT_CODES"))
	export_codes_file_dialog.set_ok_button_text(tr("EXPORT_STUDENT_CODES"))
	export_codes_file_dialog.filters = []
	export_codes_file_dialog.add_filter("*.pdf", "pdf")
	export_codes_file_dialog.file_selected.connect(_on_export_codes_file_selected)
	Log.info("SettingsTeacherSettings: Export codes dialog configured")


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


func refresh_devices_tabs() -> void:
	for child: Node in devices_tab_container.get_children(false):
		child.queue_free()
	
	if not UserDataManager.teacher_settings:
		Log.error("SettingsTeacherSettings: Teacher settings not found")
		return
	
	for device: int in UserDataManager.teacher_settings.students.keys():
		var device_tab: DeviceTab
		device_tab = DEVICE_TAB_SCENE.instantiate()
		devices_tab_container.add_child(device_tab)
		await get_tree().process_frame # Not optional or an auto-rename bug will occur on the tabs (especiallly if there are a lot of them)
		device_tab.device_id = device
		(device_tab as DeviceTab).students = UserDataManager.teacher_settings.students[device] as Array[StudentData]
		device_tab.name = tr("DEVICE_NUMBER").format({"number": device})
		device_tab.student_pressed.connect(_on_student_pressed)
		device_tab.refresh()
		
		last_device_id = device


func _on_back_button_pressed() -> void:
	await OpeningCurtain.close()
	if not UserDataManager.get_device_settings().device_id:
		get_tree().change_scene_to_file(DEVICE_SELECTION_SCENE_PATH)
	else:
		get_tree().change_scene_to_file(LOGIN_MENU_PATH)


func _on_delete_button_pressed() -> void:
	delete_popup.show()


func _on_delete_popup_accepted() -> void:
	var res: Dictionary = await ServerManager.delete_account()
	if res.code == 200:
		UserDataManager.delete_teacher_data()
		UserDataManager.logout()
		get_tree().change_scene_to_file(MAIN_MENU_PATH)


func _on_logout_button_pressed() -> void:
	await OpeningCurtain.close()
	UserDataManager.logout()
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


func _on_devices_tab_container_tab_changed(tab: int) -> void:
	var device_tab: DeviceTab = devices_tab_container.get_tab_control(tab) as DeviceTab
	if not device_tab:
		Log.error("SettingsTeacherSettings: DeviceTab not found for tab " + str(tab))
		return
	lesson_unlocks.device = device_tab.device_id


func _on_student_pressed(code: int) -> void:
	lesson_unlocks.student = code
	lesson_unlocks.show()


func _on_add_student_button_pressed() -> void:
	add_student_popup.show()


func _on_add_student_popup_accepted() -> void:
	var current_tab: DeviceTab = devices_tab_container.get_current_tab_control() as DeviceTab
	if not current_tab:
		Log.error("SettingsTeacherSettings: DeviceTab not found")
		return
	var res: Dictionary = await ServerManager.add_student({"device": current_tab.device_id})
	if res.code == 200:
		UserDataManager.update_configuration(res.body as Dictionary)
		current_tab.students = UserDataManager.teacher_settings.students[current_tab.device_id]
		current_tab.refresh()
	else:
		Log.error("SettingsTeacherSettings: Request to add student failed. Error code " + str(res.code))


func _on_add_device_button_pressed() -> void:
	add_device_popup.show()


func _on_add_device_popup_accepted() -> void:
	var res: Dictionary = await ServerManager.add_student({"device": last_device_id + 1})
	if res.code == 200:
		UserDataManager.update_configuration(res.body as Dictionary)
		refresh_devices_tabs()
		await get_tree().create_timer(1).timeout
		var count: int = devices_tab_container.get_tab_count()
		devices_tab_container.current_tab = count -1


func _on_lesson_unlocks_student_deleted(_code: int) -> void:
	delete_student_popup.show()


func _on_delete_student_popup_accepted() -> void:
	var current_tab: DeviceTab = devices_tab_container.get_current_tab_control() as DeviceTab
	if not current_tab:
		return
	var res: Dictionary = await ServerManager.remove_student(int(lesson_unlocks.student))
	if res.code == 200:
		lesson_unlocks.hide()
		UserDataManager.update_configuration(res.body as Dictionary)
		await get_tree().create_timer(1).timeout
		if UserDataManager.teacher_settings.students.has(current_tab.device_id):
			current_tab.students = UserDataManager.teacher_settings.students[current_tab.device_id]
			current_tab.refresh()
		else:
			refresh_devices_tabs()


func update_student_name(student_code: int, student_name: String) -> void:
	for device: DeviceTab in devices_tab_container.get_children(false):
		for student_panel: StudentPanel in device.students_container.get_children(false):
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

	var students_container: VBoxContainer = VBoxContainer.new()
	students_container.set("theme_override_constants/separation", 8)
	section.add_child(students_container)

	var sorted_students: Array[StudentData] = students.duplicate()
	sorted_students.sort_custom(func(a: StudentData, b: StudentData) -> bool:
		return a.name.naturalnocasecmp_to(b.name) < 0
	)

	for student_index: int in range(sorted_students.size()):
		var student_data: StudentData = sorted_students[student_index]
		Log.info("SettingsTeacherSettings: Adding student row for %s (%s)" % [student_data.name, str(student_data.code)])
		students_container.add_child(_build_student_row(student_data))
		if student_index < sorted_students.size() - 1:
			students_container.add_child(_build_student_separator())

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
