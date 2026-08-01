class_name LessonUnlocks
extends Control

signal student_deleted(code: int)

const DEVICE_BUTTON_SCENE: PackedScene = preload("res://sources/menus/main/device_button.tscn")
const LESSON_UNLOCK_SCENE: PackedScene = preload("res://sources/menus/settings/lesson_unlock.tscn")

@export var device: int:
	set = _on_device_changed
@export var student: int:
	set = _on_student_changed

var progression: StudentProgression
var teacher_settings: SettingsTeacherSettings = null
# Snapshot taken when a student is loaded, so closing the panel without editing
# anything does not bump `last_modified`. A stale bump makes the local copy look
# newer than the server's and gets it pushed on the next synchronization.
var _unlocks_on_open: Dictionary = {}
var _highest_boss_on_open: int = 0

@onready var lessons_grid: GridContainer = %LessonsGrid
@onready var lesson_rows_store: Node = %LessonRowsStore
@onready var name_line_edit: LineEdit = %NameLineEdit
@onready var device_selection_container: PanelContainer = %DeviceSelectionContainer
@onready var container: GridContainer = %GridContainer


func _ready() -> void:
	name_line_edit.connect("text_submitted", _on_name_changed)
	device_selection_container.hide()


## Builds the lesson rows ahead of any student being chosen.
##
## The rows are the expensive part: a lesson is six controls, four of them
## dropdowns that populate themselves, so sixty lessons cost about two seconds.
## They depend only on the language pack, so settings calls this while it is
## already loading and opening a student stays instant.
func prepare_lesson_rows() -> void:
	if not Database.is_open:
		Log.trace("LessonUnlocks: Database closed, lesson rows will be built on first use")
		return
	var lessons: Array = _query_lessons()
	if lesson_rows_store.get_child_count() != lessons.size():
		_build_lesson_rows(lessons)


func _query_lessons() -> Array:
	Database.db.query("SELECT LessonNb, group_concat(Grapheme || '-' || Phoneme, ' ') GPs FROM Lessons
INNER JOIN GPsInLessons ON GPsInLessons.LessonID = Lessons.ID
INNER JOIN GPs ON GPsInLessons.GPID = GPs.ID
GROUP BY LessonNb
ORDER BY LessonNb")
	return Database.db.query_result


func _create_lessons() -> void:
	if not progression:
		Log.trace("LessonUnlocks: User selected a student with no progression data")
		return

	var lessons: Array = _query_lessons()
	if lesson_rows_store.get_child_count() != lessons.size():
		_build_lesson_rows(lessons)
	_apply_progression()


func _build_lesson_rows(lessons: Array) -> void:
	_clear_lessons_grid()
	for element: Dictionary in lessons:
		var student_unlock: LessonUnlock = LESSON_UNLOCK_SCENE.instantiate()
		student_unlock.lesson_gps = element.GPs
		student_unlock.lesson_number = element.LessonNb
		student_unlock.unlocks = progression.unlocks if progression else {}
		lesson_rows_store.add_child(student_unlock)
		# Refill rather than rebuild: a teacher changing one dropdown used to pay
		# for the whole grid again.
		student_unlock.unlocks_changed.connect(_apply_progression)
		_add_row_to_grid(student_unlock)


## Points every row at the current student's progression and refreshes it.
func _apply_progression() -> void:
	if not progression:
		return
	for row: LessonUnlock in lesson_rows_store.get_children():
		row.unlocks = progression.unlocks
		row.reload()


func _clear_lessons_grid() -> void:
	# Freed rather than queued: a rebuild in the same frame would otherwise add
	# its rows alongside the old ones, and the grid doubled on every open.
	for child: Node in lessons_grid.get_children():
		if child.get_meta("lesson_grid_cell", false):
			lessons_grid.remove_child(child)
			child.free()
	for child: Node in lesson_rows_store.get_children():
		lesson_rows_store.remove_child(child)
		child.free()


func _add_row_to_grid(lesson_unlock: LessonUnlock) -> void:
	for cell: Control in lesson_unlock.get_grid_cells():
		cell.set_meta("lesson_grid_cell", true)
		cell.reparent(lessons_grid)


func _on_device_changed(value: int)-> void:
	device = value


func _on_student_changed(value: int)-> void:
	student = value
	progression = UserDataManager.get_student_progression_for_code(device, student)
	if progression:
		_unlocks_on_open = progression.unlocks.duplicate(true)
		_highest_boss_on_open = progression.highest_boss_defeated
	else:
		_unlocks_on_open = {}
		_highest_boss_on_open = 0
	_create_lessons()
	(%PasswordVisualizer as PasswordVisualizer).password = str(value)
	Log.info("LessonUnlocks: Loaded student %d for device %d" % [student, device])
	var all_students: Array = UserDataManager.teacher_settings.students[device]
	for student_data: StudentData in all_students:
		if student_data.code == value:
			name_line_edit.text = student_data.name
			break


func _on_back_button_pressed() -> void:
	if not progression:
		hide()
		return
	var highest_unlocked_lesson: int = _get_highest_unlocked_lesson()
	var new_highest_boss: int = max(progression.highest_boss_defeated, highest_unlocked_lesson - 1)
	# Only touch the timestamp when the teacher actually changed something. Note
	# that lowering the progression is a legitimate edit: it is saved and pushed
	# like any other, because the timestamp genuinely moves forward.
	if progression.unlocks == _unlocks_on_open and new_highest_boss == _highest_boss_on_open:
		Log.trace("LessonUnlocks: Progression unchanged for student %d on device %d, nothing to save" % [student, device])
		hide()
		return
	progression.highest_boss_defeated = new_highest_boss
	progression.last_modified = Time.get_datetime_string_from_system(true)
	UserDataManager.save_student_progression_for_code(device, student, progression)
	Log.info("LessonUnlocks: Saved progression for student %d on device %d" % [student, device])
	_unlocks_on_open = progression.unlocks.duplicate(true)
	_highest_boss_on_open = progression.highest_boss_defeated
	hide()


func _get_highest_unlocked_lesson() -> int:
	var highest_unlocked_lesson: int = 0
	for lesson_number: int in progression.unlocks.keys():
		if progression.unlocks[lesson_number]["look_and_learn"] >= StudentProgression.Status.UNLOCKED:
			highest_unlocked_lesson = max(highest_unlocked_lesson, lesson_number)
	return highest_unlocked_lesson


func _on_delete_button_pressed() -> void:
	Log.warn("LessonUnlocks: Delete requested for student %d on device %d" % [student, device])
	student_deleted.emit(int(student))


func _on_device_change_button_pressed() -> void:
	Log.trace("LessonUnlocks: Device change requested for student %d" % student)
	_device_selection_refresh()
	device_selection_container.show()


func _on_name_changed(new_name: String) -> void:
	UserDataManager.teacher_settings.update_student_name(student, new_name)
	teacher_settings.update_student_name(student, new_name)
	Log.info("LessonUnlocks: Updated student %d name to %s" % [student, new_name])


func _device_selection_refresh() -> void:
	if not UserDataManager.teacher_settings:
		return
	
	for child: Node in container.get_children():
		child.queue_free()
	
	for device_id: int in UserDataManager.teacher_settings.students.keys():
		var button: DeviceButton = DEVICE_BUTTON_SCENE.instantiate()
		button.number = device_id
		button.background_color = Globals.device_colors[(device_id - 1) % Globals.device_colors.size()]
		container.add_child(button)
		button.pressed.connect(_device_button_pressed.bind(device_id))


func _device_button_pressed(device_id: int) -> void:
	device_selection_container.hide()
	UserDataManager.teacher_settings.update_student_device(student, device_id)
	await teacher_settings.refresh_devices_tabs()
	device = device_id
	Log.info("LessonUnlocks: Updated student %d to device %d" % [student, device_id])
	var res_set: Dictionary = await ServerManager.set_student_data(student, {"device_id": device_id})
	if not res_set.success:
		Log.trace("LessonUnlocks: Device was updated locally for the student, but the network update failed.")
