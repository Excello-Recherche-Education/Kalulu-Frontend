class_name CodeSheet
extends Object
## Builds the printable sheet of student access codes and writes it as a PDF.
##
## Kept apart from the screens that offer it, because two of them do: the
## settings screen, for an account that exists, and the last step of
## registration, for one that does not exist yet. So it works from a
## TeacherSettings handed to it rather than from UserDataManager's live one.
##
## The sheet is rendered rather than drawn: each page is laid out as a Control,
## captured through a SubViewport and embedded in a minimal PDF as a JPEG. That
## needs a host node in the tree to render inside, which is why the entry point
## takes one.

const PASSWORD_VISUALIZER_SCENE: PackedScene = preload("res://sources/menus/components/password_visualizer.tscn")
const COLUMNS: int = 2
const TITLE_FONT_SIZE: int = 44
const SECTION_FONT_SIZE: int = 32
const TEXT_FONT_SIZE: int = 28
const STUDENTS_PER_COLUMN: int = 16
const STUDENTS_PER_PAGE: int = STUDENTS_PER_COLUMN * COLUMNS
const PAGE_SIZE: Vector2 = Vector2(1920, 1080)
const PAGE_MARGIN: int = 40
const STUDENT_RULE_COLOR: Color = Color("c7c7c7")
const DEVICE_RULE_COLOR: Color = Color("8c8c8c")


## Renders the sheet for `settings` and writes it to `path` as a PDF.
##
## `host` only has to be in the tree: the pages are rendered inside it and
## removed again.
static func export_to_pdf(host: Node, settings: TeacherSettings, path: String) -> Error:
	if not settings:
		Log.warn("CodeSheet: Nothing to export without teacher settings")
		return ERR_INVALID_PARAMETER

	var pages: Array[Control] = build_pages(settings)
	Log.info("CodeSheet: Prepared %d page(s)" % pages.size())
	var images: Array[Image] = []
	for page: Control in pages:
		var viewport: SubViewport = SubViewport.new()
		viewport.disable_3d = true
		viewport.transparent_bg = true
		viewport.size = page.size
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		viewport.add_child(page)
		host.add_child(viewport)
		await host.get_tree().process_frame
		await host.get_tree().process_frame

		Log.info("CodeSheet: Captured page %d/%d" % [images.size() + 1, pages.size()])
		images.append(viewport.get_texture().get_image())
		viewport.queue_free()

	var export_path: String = pdf_path(path)

	Log.info("CodeSheet: Writing %s" % export_path)
	var save_error: Error = save_pdf(export_path, images)
	if save_error != OK:
		Log.error("CodeSheet: Failed to save the PDF: %s" % error_string(save_error))
	else:
		Log.info("CodeSheet: PDF saved")
	return save_error


## Everything the sheet would print, as one comparable string.
##
## It lives here, beside the code that draws a row, because it has to cover every
## field a row shows: the recap keeps this when the teacher exports and compares it
## later to tell whether the sheet in their hands is still the truth. A field added
## to a row has to be added here too, and sitting in the same file is the only
## reminder there will be.
static func content_fingerprint(settings: TeacherSettings) -> String:
	var lines: PackedStringArray = []
	var devices: Array = settings.students.keys()
	devices.sort()
	for device_id: int in devices:
		for student: StudentData in settings.students[device_id] as Array[StudentData]:
			# The name goes last: it is the one field a person types, so it is the one
			# that could otherwise be mistaken for a separator.
			lines.append("%d:%d:%s" % [device_id, student.code, printed_name(student)])
	# Sorted so the answer depends on what is printed and not on the order the
	# students happen to be held in. Each line carries its own code, so two children
	# swapping names still comes out different.
	lines.sort()
	return "\n".join(lines)


## The text a row shows in its name cell.
##
## A student with no name yet is printed by number instead, so the teacher still
## has something to write next to.
static func printed_name(student_data: StudentData) -> String:
	return student_data.name if student_data.name \
		else TranslationServer.translate("STUDENT_NUM").format({"number": student_data.code})


## The path the sheet will actually be written to.
##
## Exposed because the caller wants to tell the teacher where it went, and it
## would be wrong about the name if it guessed.
static func pdf_path(path: String) -> String:
	return path if path.ends_with(".pdf") else path + ".pdf"


## One Control per printed page, laid out and ready to be rendered.
static func build_pages(settings: TeacherSettings) -> Array[Control]:
	var pages: Array[Control] = []
	var devices: Array = settings.students.keys()
	devices.sort()
	Log.info("CodeSheet: Building the sheet for %d device(s)" % devices.size())

	for device_id: int in devices:
		var students: Array[StudentData] = settings.students[device_id] as Array[StudentData]
		for start_index: int in range(0, students.size(), STUDENTS_PER_PAGE):
			var end_index: int = mini(start_index + STUDENTS_PER_PAGE, students.size())
			var page: Dictionary = _create_page()
			var columns: Array[VBoxContainer] = page["columns"]
			var page_students: Array[StudentData] = students.slice(start_index, end_index)
			for column_index: int in range(columns.size()):
				var column_start: int = column_index * STUDENTS_PER_COLUMN
				if column_start >= page_students.size():
					break
				var column_end: int = mini(column_start + STUDENTS_PER_COLUMN, page_students.size())
				columns[column_index].add_child(
					_build_device_section(device_id, page_students.slice(column_start, column_end)))
			pages.append(page["canvas"])

	return pages


static func _create_page() -> Dictionary:
	var canvas: Control = Control.new()
	canvas.name = "CodeSheetPage"
	canvas.size = PAGE_SIZE

	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_inset(panel, PAGE_MARGIN)
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = Color.WHITE
	panel.set("theme_override_styles/panel", background)
	canvas.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_inset(margin, PAGE_MARGIN)
	panel.add_child(margin)

	var column_stack: VBoxContainer = VBoxContainer.new()
	column_stack.set("theme_override_constants/separation", 24)
	margin.add_child(column_stack)

	var title: Label = Label.new()
	title.text = TranslationServer.translate("STUDENT_CODES")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set("theme_override_font_sizes/font_size", TITLE_FONT_SIZE)
	title.set("theme_override_colors/font_color", Color.BLACK)
	column_stack.add_child(title)

	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.set("theme_override_constants/separation", 40)
	column_stack.add_child(row)

	var columns: Array[VBoxContainer] = []
	for _column_index: int in range(COLUMNS):
		var column: VBoxContainer = VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.set("theme_override_constants/separation", 18)
		row.add_child(column)
		columns.append(column)

	return {"canvas": canvas, "columns": columns}


static func _inset(control: Control, by: int) -> void:
	control.offset_left = by
	control.offset_top = by
	control.offset_right = -by
	control.offset_bottom = -by


static func _build_device_section(device_id: int, students: Array[StudentData]) -> VBoxContainer:
	var section: VBoxContainer = VBoxContainer.new()
	section.set("theme_override_constants/separation", 10)

	var device_label: Label = Label.new()
	device_label.text = TranslationServer.translate("DEVICE_NUMBER").format({"number": device_id})
	device_label.set("theme_override_font_sizes/font_size", SECTION_FONT_SIZE)
	device_label.set("theme_override_colors/font_color", Color.BLACK)
	section.add_child(device_label)

	# Named for the printed sheet: the screens' grid of student cards is a
	# different node with a similar job.
	var student_rows: VBoxContainer = VBoxContainer.new()
	student_rows.set("theme_override_constants/separation", 8)
	section.add_child(student_rows)

	var sorted_students: Array[StudentData] = students.duplicate()
	sorted_students.sort_custom(func(first: StudentData, second: StudentData) -> bool:
		return first.name.naturalnocasecmp_to(second.name) < 0
	)

	for student_index: int in range(sorted_students.size()):
		student_rows.add_child(_build_student_row(sorted_students[student_index]))
		if student_index < sorted_students.size() - 1:
			student_rows.add_child(_build_rule(STUDENT_RULE_COLOR, 2))

	section.add_child(_build_rule(DEVICE_RULE_COLOR, 4))
	return section


static func _build_student_row(student_data: StudentData) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.set("theme_override_constants/separation", 12)

	var name_label: Label = Label.new()
	name_label.text = printed_name(student_data)
	name_label.set("theme_override_font_sizes/font_size", TEXT_FONT_SIZE)
	name_label.set("theme_override_colors/font_color", Color.BLACK)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var visualizer: PasswordVisualizer = PASSWORD_VISUALIZER_SCENE.instantiate() as PasswordVisualizer
	visualizer.key_size = 32
	visualizer.password = str(student_data.code)
	# On white paper the chips would be white on white, so the glyphs are drawn
	# in their own colour instead.
	visualizer.show_backgrounds = false
	row.add_child(visualizer)

	return row


static func _build_rule(color: Color, thickness: int) -> HSeparator:
	var separator: HSeparator = HSeparator.new()
	separator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var line: StyleBoxLine = StyleBoxLine.new()
	line.color = color
	line.thickness = thickness
	separator.set("theme_override_styles/separator", line)
	return separator


## Writes `images` as one page each into a minimal PDF at `path`.
static func save_pdf(path: String, images: Array[Image]) -> Error:
	if images.is_empty():
		Log.error("CodeSheet: No pages to write")
		return ERR_CANT_CREATE

	var jpg_pages: Array[PackedByteArray] = []
	for page: Image in images:
		var jpg_data: PackedByteArray = page.save_jpg_to_buffer(0.9)
		if jpg_data.is_empty():
			Log.error("CodeSheet: Failed to encode a page as JPEG")
			return ERR_CANT_CREATE
		jpg_pages.append(jpg_data)

	var pdf_data: PackedByteArray = PackedByteArray()
	var xref_offsets: Array[int] = [0]

	_append_string(pdf_data, "%PDF-1.4\n")
	_add_object(pdf_data, xref_offsets, "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
	var page_count: int = images.size()
	var kids_entries: PackedStringArray = []
	for page_index: int in range(page_count):
		kids_entries.append("%d 0 R" % (3 + page_index * 3))
	_add_object(pdf_data, xref_offsets,
		"2 0 obj\n<< /Type /Pages /Kids [%s] /Count %d >>\nendobj\n"
			% [" ".join(kids_entries), page_count])

	for page_index: int in range(page_count):
		var page: Image = images[page_index]
		var jpg_data: PackedByteArray = jpg_pages[page_index]
		var width: int = page.get_width()
		var height: int = page.get_height()
		var page_object_id: int = 3 + page_index * 3
		var image_object_id: int = page_object_id + 1
		var content_object_id: int = page_object_id + 2
		var image_name: String = "Im%d" % page_index

		_add_object(pdf_data, xref_offsets,
			"%d 0 obj\n<< /Type /Page /Parent 2 0 R /Resources << /XObject << /%s %d 0 R >> /ProcSet [/PDF /ImageC] >> /MediaBox [0 0 %d %d] /Contents %d 0 R >>\nendobj\n"
				% [page_object_id, image_name, image_object_id, width, height, content_object_id])

		var image_header: String = "%d 0 obj\n<< /Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length %d >>\nstream\n" % [image_object_id, width, height, jpg_data.size()]
		_add_object_with_stream(pdf_data, xref_offsets, image_header, jpg_data)

		var content_bytes: PackedByteArray = ("q\n%d 0 0 %d 0 0 cm\n/%s Do\nQ\n"
			% [width, height, image_name]).to_utf8_buffer()
		_add_object_with_stream(pdf_data, xref_offsets,
			"%d 0 obj\n<< /Length %d >>\nstream\n" % [content_object_id, content_bytes.size()],
			content_bytes)

	var xref_offset: int = pdf_data.size()
	var xref_lines: PackedStringArray = ["xref", "0 %d" % xref_offsets.size(),
		"0000000000 65535 f "]
	for offset: int in xref_offsets.slice(1, xref_offsets.size()):
		xref_lines.append("%010d 00000 n " % offset)
	_append_string(pdf_data, "\n".join(xref_lines) + "\n")
	_append_string(pdf_data, "trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%EOF\n"
		% [xref_offsets.size(), xref_offset])

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		Log.error("CodeSheet: Could not open %s for writing" % path)
		return ERR_CANT_OPEN
	file.store_buffer(pdf_data)
	file.close()
	Log.info("CodeSheet: Wrote %d bytes" % pdf_data.size())
	return OK


static func _add_object(pdf_data: PackedByteArray, offsets: Array[int], object_text: String) -> void:
	offsets.append(pdf_data.size())
	_append_string(pdf_data, object_text)


static func _add_object_with_stream(pdf_data: PackedByteArray, offsets: Array[int],
		header: String, stream_data: PackedByteArray) -> void:
	offsets.append(pdf_data.size())
	_append_string(pdf_data, header)
	pdf_data.append_array(stream_data)
	_append_string(pdf_data, "\nendstream\nendobj\n")


static func _append_string(pdf_data: PackedByteArray, text: String) -> void:
	pdf_data.append_array(text.to_utf8_buffer())
