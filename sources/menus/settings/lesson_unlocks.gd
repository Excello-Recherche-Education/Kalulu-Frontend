extends Control
class_name LessonUnlocks

signal student_deleted(code: int)

# Namespace
const DeviceButton:= preload("res://sources/menus/main/device_button.gd")
const device_button_scene: PackedScene = preload("res://sources/menus/main/device_button.tscn")
const StudentUnlock: = preload("res://sources/menus/settings/lesson_unlock.gd")
const student_unlock_scene: PackedScene = preload("res://sources/menus/settings/lesson_unlock.tscn")

@onready var lesson_container: VBoxContainer = %LessonContainer
@onready var name_line_edit: LineEdit = %NameLineEdit
@onready var device_selection_container: PanelContainer = %DeviceSelectionContainer
@onready var container: GridContainer = %GridContainer

var teacher_settings: SettingsTeacherSettings = null

@export var device: int:
	set = _on_device_changed
@export var student: int:
	set = _on_student_changed

var progression: UserProgression

func _ready() -> void:
	name_line_edit.connect("text_submitted", _on_name_changed)
	device_selection_container.visible = false


func _create_lessons() -> void:
	for lesson_unlock: Node in lesson_container.get_children():
		lesson_unlock.queue_free()
	
	Database.db.query("SELECT LessonNb, group_concat(Grapheme || '-' ||Phoneme, ' ') GPs FROM Lessons
INNER JOIN GPsInLessons ON GPsInLessons.LessonID = Lessons.ID
INNER JOIN GPs ON GPsInLessons.GPID = GPs.ID
GROUP BY LessonNb
ORDER BY LessonNb")
	for element: Dictionary in Database.db.query_result:
		var student_unlock: StudentUnlock = student_unlock_scene.instantiate()
		student_unlock.lesson_GPs = element.GPs
		student_unlock.lesson_number = element.LessonNb
		if not progression:
			Logger.debug("LessonUnlocks: User selected a student with no progression data")
			return
		student_unlock.unlocks = progression.unlocks
		lesson_container.add_child(student_unlock)
		
		student_unlock.unlocks_changed.connect(_create_lessons)


func _on_device_changed(value: int)-> void:
	device = value


func _on_student_changed(value: int)-> void:
	student = value
	progression = UserDataManager.get_student_progression_for_code(device, student)
	_create_lessons()
	(%PasswordVisualizer as PasswordVisualizer).password = str(value)
	var allStudent: Array = UserDataManager.teacher_settings.students[device]
	for student_data : StudentData in allStudent:
		if student_data.code == value:
			name_line_edit.text = student_data.name
			break


func _on_back_button_pressed() -> void:
	UserDataManager.save_student_progression_for_code(device, student, progression)
	hide()


func _on_delete_button_pressed() -> void:
	student_deleted.emit(int(student))


func _on_device_change_button_pressed() -> void:
	_device_selection_refresh()
	device_selection_container.visible = true


func _on_name_changed(new_name: String) -> void:
	UserDataManager.teacher_settings.update_student_name(student, new_name)
	teacher_settings.update_student_name(student, new_name)


func _device_selection_refresh() -> void:
	if not UserDataManager.teacher_settings:
		return
	
	for child: Node in container.get_children():
		child.queue_free()
	
	for device_id: int in UserDataManager.teacher_settings.students.keys():
		var button: DeviceButton = device_button_scene.instantiate()
		button.number = device_id
		button.background_color = Globals.device_colors[device_id-1 % Globals.device_colors.size()]
		container.add_child(button)
		button.pressed.connect(_device_button_pressed.bind(device_id))


func _device_button_pressed(device_id: int) -> void:
	var resSet: Dictionary = await ServerManager.set_student_data(student, {"device_id": device_id})
	if resSet.code == 200:
		device_selection_container.visible = false
		UserDataManager.teacher_settings.update_student_device(student, device_id)
		await teacher_settings.refresh_devices_tabs()
		device = device_id
