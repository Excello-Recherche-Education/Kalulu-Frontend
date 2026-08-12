extends GutTest
## The printable sheet of student access codes.
##
## Built from a TeacherSettings handed in rather than from UserDataManager's live
## one, because the last step of registration prints it for an account that does
## not exist on the server yet.


func _settings_with(devices: int, students_per_device: int) -> TeacherSettings:
	var settings: TeacherSettings = TeacherSettings.new()
	var code: int = 0
	for device: int in range(1, devices + 1):
		var students: Array[StudentData] = []
		for _index: int in students_per_device:
			var student: StudentData = StudentData.new()
			student.code = TeacherSettings.AVAILABLE_CODES[code]
			students.append(student)
			code += 1
		settings.students[device] = students
	return settings


func _free_pages(pages: Array[Control]) -> void:
	for page: Control in pages:
		page.free()


func test_it_prints_the_settings_it_is_given() -> void:
	# Not UserDataManager's: at registration time there is no account there yet.
	var pages: Array[Control] = CodeSheet.build_pages(_settings_with(1, 3))

	assert_eq(pages.size(), 1, "three students fit on one page")
	assert_eq(pages[0].size, CodeSheet.PAGE_SIZE)
	_free_pages(pages)


func test_a_device_spills_onto_as_many_pages_as_it_needs() -> void:
	var per_page: int = CodeSheet.STUDENTS_PER_PAGE
	var pages: Array[Control] = CodeSheet.build_pages(_settings_with(1, per_page + 1))

	assert_eq(pages.size(), 2, "one student past a full page starts another")
	_free_pages(pages)


func test_every_device_gets_its_own_pages() -> void:
	var pages: Array[Control] = CodeSheet.build_pages(_settings_with(3, 2))

	assert_eq(pages.size(), 3, "devices are not packed together onto one page")
	_free_pages(pages)


func test_an_empty_account_prints_nothing() -> void:
	var pages: Array[Control] = CodeSheet.build_pages(TeacherSettings.new())

	assert_eq(pages.size(), 0)
	_free_pages(pages)


func test_the_codes_are_drawn_in_colour_for_white_paper() -> void:
	# On paper the chips would be white on white, so the glyphs take the colour
	# instead of sitting on it.
	var pages: Array[Control] = CodeSheet.build_pages(_settings_with(1, 1))
	var visualizers: Array[Node] = pages[0].find_children("*", "PasswordVisualizer", true, false)

	assert_gt(visualizers.size(), 0, "the sheet should show the codes")
	for node: Node in visualizers:
		assert_false((node as PasswordVisualizer).show_backgrounds,
			"a chip background would print as white on white")
	_free_pages(pages)


func test_writing_with_no_pages_fails_rather_than_leaving_an_empty_file() -> void:
	var path: String = "user://code_sheet_test_should_not_exist.pdf"
	var empty: Array[Image] = []

	assert_ne(CodeSheet.save_pdf(path, empty), OK)
	# It says so in the log as well, which is the point. Acknowledge that so GUT
	# does not report it as an unexpected error; must run inside the test, since
	# GUT checks for unhandled errors before after_each().
	for tracked_error: GutTrackedError in get_errors():
		tracked_error.handled = true
	assert_false(FileAccess.file_exists(path), "nothing should have been written")


func test_it_writes_a_pdf_that_starts_like_one() -> void:
	var path: String = "user://code_sheet_test.pdf"
	var page: Image = Image.create(64, 64, false, Image.FORMAT_RGB8)
	page.fill(Color.WHITE)

	assert_eq(CodeSheet.save_pdf(path, [page] as Array[Image]), OK)

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "the file should be there")
	assert_eq(file.get_buffer(5).get_string_from_ascii(), "%PDF-",
		"a reader identifies a PDF by its first bytes")
	file.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
