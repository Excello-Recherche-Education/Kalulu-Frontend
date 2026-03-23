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

@onready var lessons_grid: GridContainer = %LessonsGrid
@onready var lesson_rows_store: Node = %LessonRowsStore
@onready var name_line_edit: LineEdit = %NameLineEdit
@onready var device_selection_container: PanelContainer = %DeviceSelectionContainer
@onready var container: GridContainer = %GridContainer


func _ready() -> void:
	name_line_edit.connect("text_submitted", _on_name_changed)
	device_selection_container.hide()


func _create_lessons() -> void:
	_clear_lessons_grid()

	Database.db.query("SELECT LessonNb, group_concat(Grapheme || '-' || Phoneme, ' ') GPs FROM Lessons
INNER JOIN GPsInLessons ON GPsInLessons.LessonID = Lessons.ID
INNER JOIN GPs ON GPsInLessons.GPID = GPs.ID
GROUP BY LessonNb
ORDER BY LessonNb")
	for element: Dictionary in Database.db.query_result:
		var student_unlock: LessonUnlock = LESSON_UNLOCK_SCENE.instantiate()
		student_unlock.lesson_gps = element.GPs
		student_unlock.lesson_number = element.LessonNb
		if not progression:
			Log.trace("LessonUnlocks: User selected a student with no progression data")
			return
		student_unlock.unlocks = progression.unlocks
		lesson_rows_store.add_child(student_unlock)
		student_unlock.unlocks_changed.connect(_create_lessons)
		_add_row_to_grid(student_unlock)


func _clear_lessons_grid() -> void:
	for child: Node in lesson_rows_store.get_children():
		child.queue_free()
	for child: Node in lessons_grid.get_children():
		if child.get_meta("lesson_grid_cell", false):
			child.queue_free()


func _add_row_to_grid(lesson_unlock: LessonUnlock) -> void:
	for cell: Control in lesson_unlock.get_grid_cells():
		cell.set_meta("lesson_grid_cell", true)
		cell.reparent(lessons_grid)


func _on_device_changed(value: int)-> void:
	device = value


func _on_student_changed(value: int)-> void:
	student = value
	progression = UserDataManager.get_student_progression_for_code(device, student)
	_create_lessons()
	(%PasswordVisualizer as PasswordVisualizer).password = str(value)
	Log.info("LessonUnlocks: Loaded student %d for device %d" % [student, device])
	var all_students: Array = UserDataManager.teacher_settings.students[device]
	for student_data: StudentData in all_students:
		if student_data.code == value:
			name_line_edit.text = student_data.name
			break


func _on_back_button_pressed() -> void:
	var highest_unlocked_lesson: int = _get_highest_unlocked_lesson()
	progression.highest_boss_defeated = max(progression.highest_boss_defeated, highest_unlocked_lesson - 1)
	progression.last_modified = Time.get_datetime_string_from_system(true)
	UserDataManager.save_student_progression_for_code(device, student, progression)
	Log.info("LessonUnlocks: Saved progression for student %d on device %d" % [student, device])
	hide()


func _get_highest_unlocked_lesson() -> int:
	var highest_unlocked_lesson: int = 0
	for lesson_number: int in progression.unlocks.keys():
		if progression.unlocks[lesson_number]["look_and_learn"] >= StudentProgression.Status.Unlocked:
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
